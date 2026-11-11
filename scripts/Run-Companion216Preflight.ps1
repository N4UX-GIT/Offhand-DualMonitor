param(
    [Parameter(Mandatory=$true)][string]$PlanPath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedPlanSha256,
    [Parameter(Mandatory=$true)][string]$ExpectedUserSid
)
$ErrorActionPreference='Stop'
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if(!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Windows package deployment and Microsoft WACK require administrator rights.'}
if($principal.Identity.User.Value-ne $ExpectedUserSid){throw 'Run as the same Windows user.'}
if((Get-FileHash -LiteralPath $PlanPath).Hash-ne $ExpectedPlanSha256){throw 'The reviewed validation plan changed.'}
$plan=Get-Content -LiteralPath $PlanPath -Raw|ConvertFrom-Json
$qa=[IO.Path]::GetFullPath($plan.output)
if(!(Test-Path -LiteralPath $qa -PathType Container)){throw 'Prepared validation directory is missing.'}
$name='N4UX.OffhandCompanion.UpgradeValidation216'
if(Get-AppxPackage -Name $name){throw 'Existing validation package will not be replaced.'}
foreach($item in $plan.files){if((Get-FileHash -LiteralPath $item.path).Hash-ne $item.sha256){throw ('Prepared input changed: '+$item.path)}}
$original=Get-AppxPackage -Name N4UX.OffhandCompanion
if(!$original -or $original.Version.ToString()-ne '2.1.500.0'){throw 'Installed Store baseline changed; review before testing.'}
$originalExe=Join-Path $original.InstallLocation 'Offhand.exe'
$originalExeHash=(Get-FileHash -LiteralPath $originalExe).Hash
$paths=@((Join-Path $env:LOCALAPPDATA 'Offhand/OffhandConfig.ini'),
    (Join-Path $env:LOCALAPPDATA "Packages/$($original.PackageFamilyName)/LocalState/OffhandConfig.ini"),
    (Join-Path $env:LOCALAPPDATA "Packages/$($original.PackageFamilyName)/LocalCache/Local/Offhand/OffhandConfig.ini"))
function Read-PreferenceState {
    @($paths|ForEach-Object{if(Test-Path -LiteralPath $_){(Get-FileHash -LiteralPath $_).Hash}else{'absent'}})-join '|'
}
$preferences=Read-PreferenceState
$state=[ordered]@{phase='starting';startedUtc=[DateTime]::UtcNow.ToString('o');
    originalPackage=$original.PackageFullName;productionPackageInstalled=$false;certificateImport=$false;developerModeChange=$false}
function Save-State {$state|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $qa 'preflight-state.json') -Encoding UTF8}
function Assert-Original {
    $current=Get-AppxPackage -Name N4UX.OffhandCompanion
    if(!$current -or $current.PackageFullName-ne $original.PackageFullName -or
        (Get-FileHash -LiteralPath $originalExe).Hash-ne $originalExeHash -or (Read-PreferenceState)-ne $preferences){
        throw 'The real installed app/preferences changed during testing. No original preferences will be overwritten.'
    }
}
function Probe([string]$phase,[string]$hash) {
    $package=Get-AppxPackage -Name $name
    if(!$package -or $package.Name-ne $name){throw 'Expected private validation identity is absent.'}
    $binary=Join-Path $package.InstallLocation 'Offhand.exe'
    if((Get-FileHash -LiteralPath $binary).Hash-ne $hash){throw 'Installed validation payload hash differs.'}
    $output=Join-Path $qa $phase
    New-Item -ItemType Directory -Path $output|Out-Null
    $arguments='"'+$binary+'" "'+$hash+'" "'+$output+'" "'+$phase+'" "'+$name+'"'
    Invoke-CommandInDesktopPackage -PackageFamilyName $package.PackageFamilyName -AppId OffhandCompanion -Command $plan.probe -Args $arguments -PreventBreakaway
    $result=Join-Path $output 'result.json';$deadline=[DateTime]::UtcNow.AddSeconds(60)
    while(!(Test-Path -LiteralPath $result) -and [DateTime]::UtcNow-lt $deadline){Start-Sleep -Milliseconds 250}
    if(!(Test-Path -LiteralPath $result)){throw ('Payload probe timed out: '+$phase)}
    $record=Get-Content -LiteralPath $result -Raw|ConvertFrom-Json
    if($record.result-ne 'PASS'){throw ('Payload probe failed: '+$phase+' '+$record.error)}
    $state[$phase]=$record
    Assert-Original;Save-State
}
Save-State
try {
    Add-AppxPackage -Path $plan.privateBaseline -AllowUnsigned -ForceTargetApplicationShutdown
    $package=Get-AppxPackage -Name $name
    if(!$package -or $package.Version.ToString()-ne '2.1.500.0'){throw 'Private baseline installation failed.'}
    $state['privateFamily']=$package.PackageFamilyName;$state['phase']='baseline';Save-State
    Probe 'baseline' $plan.baselineExeSha256
    $config=Join-Path $env:LOCALAPPDATA "Packages/$($package.PackageFamilyName)/LocalState/OffhandConfig.ini"
    $beforeUpgrade=(Get-FileHash -LiteralPath $config).Hash
    Add-AppxPackage -Path $plan.privateCandidate -AllowUnsigned -ForceTargetApplicationShutdown
    $package=Get-AppxPackage -Name $name
    if(!$package -or $package.Version.ToString()-ne '2.1.600.0'){throw 'Private package upgrade failed.'}
    if((Get-FileHash -LiteralPath $config).Hash-ne $beforeUpgrade){throw 'Private package upgrade changed existing settings bytes.'}
    $state['phase']='upgraded';$state['upgradeRetainedPreferences']=$true;Save-State
    Probe 'upgrade-first' $plan.candidateExeSha256
    Probe 'upgrade-relaunch' $plan.candidateExeSha256
    $state['phase']='wack-running';Save-State
    & $plan.wack test -appxpackagepath $plan.productionMsix -noinstallappx -reportoutputpath (Join-Path $qa 'wack-report.xml') *> (Join-Path $qa 'wack-console.log')
    $state['wackExitCode']=$LASTEXITCODE
    $state['wackReportExists']=Test-Path -LiteralPath (Join-Path $qa 'wack-report.xml')
    if($LASTEXITCODE-ne 0 -or !$state.wackReportExists){throw 'WACK did not complete successfully; inspect its report.'}
    foreach($item in $plan.files){if((Get-FileHash -LiteralPath $item.path).Hash-ne $item.sha256){throw 'An exact preflight input changed.'}}
    Assert-Original;$state['phase']='completed'
}catch{$state['phase']='failed';$state['error']=$_.Exception.ToString()}
finally {
    try {
        $validation=Get-AppxPackage -Name $name
        if($validation){
            if($validation.Name-ne $name -or $validation.PackageFamilyName-eq $original.PackageFamilyName){throw 'Refusing to remove an unexpected package.'}
            Remove-AppxPackage -Package $validation.PackageFullName
        }
        $state['privatePackageRemoved']=!(Get-AppxPackage -Name $name)
    }catch{$state['cleanupError']=$_.Exception.Message}
    try {Assert-Original;$state['originalAppAndPreferencesUnchanged']=$true}
    catch{$state['originalAppAndPreferencesUnchanged']=$false;$state['preservationError']=$_.Exception.Message}
    $state['finishedUtc']=[DateTime]::UtcNow.ToString('o');Save-State
}
