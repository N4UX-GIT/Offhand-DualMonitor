$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'C# compiler unavailable' }
$testExe = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-preferences-' + [guid]::NewGuid().ToString() + '.exe')
$layoutTestExe = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-layout-' + [guid]::NewGuid().ToString() + '.exe')
try {
    & $compiler /nologo /target:exe /main:Offhand.Companion.PreferencesTest "/out:$testExe" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot '..\Companion\Source\Program.cs') (Join-Path $PSScriptRoot 'CompanionPreferences.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Companion test compilation failed' }
    & $testExe
    if ($LASTEXITCODE -ne 0) { throw 'Companion preference test failed' }

    & $compiler /nologo /target:exe /main:Offhand.Companion.LayoutTest "/out:$layoutTestExe" /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot '..\Companion\Source\Program.cs') (Join-Path $PSScriptRoot 'CompanionLayout.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Companion layout test compilation failed' }
    & $layoutTestExe
    if ($LASTEXITCODE -ne 0) { throw 'Companion scaled-layout test failed' }

    $source = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Companion\Source\Program.cs') -Raw
    $constructor = [regex]::Match(
        $source,
        'public CompanionForm\(\)\s*\{(?<body>.*?)\n\s*\}\s*\n\s*private void CheckForUpdates',
        [Text.RegularExpressions.RegexOptions]::Singleline).Groups['body'].Value
    if ($constructor -match 'CheckForUpdates') {
        throw 'Companion must not contact the update service during startup.'
    }
    if ($source -notmatch 'btnCheckUpdates\.Click.*CheckForUpdates') {
        throw 'Companion update checks must remain wired to an explicit user action.'
    }
    if ($source -notmatch 'Offhand-DualMonitor/releases\?per_page=30' -or
        $source -match 'Offhand-Companion/releases' -or
        $source -notmatch 'CompanionUpdatePolicy\.SelectLatest') {
        throw 'Companion update checks must use the official repository release list and channel policy.'
    }
    if ($source -notmatch 'AssemblyInformationalVersion\("2\.1\.2-beta\.20"\)' -or
        $source -notmatch 'AssemblyFileVersion\("2\.1\.2\.20"\)') {
        throw 'Companion binary metadata must identify the exact beta build.'
    }
    $appManifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Companion\Source\app.manifest') -Raw
    if ($appManifest -notmatch '<assemblyIdentity version="2\.1\.2\.20" name="Offhand\.Companion\.App"/>') {
        throw 'Companion application manifest must identify the exact beta build.'
    }
    if ($source -match 'Process\.GetProcesses\(\)' -or
        $source -notmatch 'foreach \(string processName in wowProcessNames\)(?s:.*?)Process\.GetProcessesByName\(processName\)') {
        throw 'Companion polling must query only the allowlisted WoW process names, not enumerate the full process table.'
    }
    if ($source -notmatch 'monitorTimer\.Interval = proc == null \? 5000 : 2000' -or
        $source -notmatch 'ShowHelpDialog\(\)(?s:.*?)SuspendUiPolling\(\)(?s:.*?)finally \{ ResumeUiPolling\(\); \}') {
        throw 'Companion polling must back off while WoW is absent and pause during modal Help interaction.'
    }
    if ($source -notmatch '!CompanionTopologyBridge\.TryWrite(?s:.*?)throw new IOException') {
        throw 'Companion must refuse to span when addon topology cannot be written.'
    }
    if ($source -notmatch 'SetForegroundWindow\(handle\)' -or
        $source -notmatch 'same privilege level') {
        throw 'Manual restore must return focus to WoW and border failures must explain privilege mismatches.'
    }
    if ($source -match 'Microsoft\.Win32|Registry\.(CurrentUser|LocalMachine)|OpenProcessToken|GetTokenInformation|TokenIntegrityLevel|advapi32\.dll|--minimized') {
        throw 'Companion must not configure startup persistence or inspect process security tokens.'
    }
    if ($source -notmatch 'new System\.Threading\.Mutex\(true, @"Local\\OffhandCompanion"' -or
        $source -notmatch 'Offhand Companion is already running') {
        throw 'Companion must prevent duplicate tray processes.'
    }
    if ($source -notmatch 'private RichTextBox logBox' -or
        $source -notmatch 'logBox = new RichTextBox(?s:.*?)WordWrap = true') {
        throw 'Companion activity log must remain a word-wrapped read-only text surface.'
    }
    if ($source -notmatch 'AutoScaleDimensions = new SizeF\(96F, 96F\)' -or
        $source -notmatch 'AutoScaleMode = AutoScaleMode\.Dpi' -or
        $source -notmatch 'ClientSize = new Size\(524, 824\)' -or
        $source -notmatch 'AutoScroll = true') {
        throw 'Companion must scale its 96-DPI dashboard geometry linearly and remain scrollable at enlarged display scales.'
    }
    $displayInfo = [regex]::Match($source, 'lblDisplayInfo = new Label(?s:.*?)Location = new Point\(10, (?<y>\d+)\)(?s:.*?)Size = new Size\(470, (?<h>\d+)\)(?s:.*?)AutoSize = false')
    $addonReason = [regex]::Match($source, 'lblAddonReason = new Label(?s:.*?)Location = new Point\(10, (?<y>\d+)\)')
    if (-not $displayInfo.Success -or -not $addonReason.Success -or
        [int]$displayInfo.Groups['h'].Value -lt 54 -or
        ([int]$displayInfo.Groups['y'].Value + [int]$displayInfo.Groups['h'].Value) -gt [int]$addonReason.Groups['y'].Value) {
        throw 'Companion display-plan status must wrap at least three lines without overlapping addon diagnostics.'
    }
    if ($source -notmatch 'lblAddonReason = new Label(?s:.*?)Size = new Size\(470, 42\)(?s:.*?)AutoSize = false' -or
        $source -notmatch 'AddLog\("Addon verification: " \+ status\.Reason\)') {
        throw 'Companion must show and log the complete client-specific addon verification diagnostic.'
    }
    if ($source -notmatch 'TableLayoutPanel configLayout' -or
        $source -notmatch 'FlowLayoutPanel configLeft' -or
        $source -notmatch 'FlowLayoutPanel configRight' -or
        $source -match 'RegisterHotKey|UnregisterHotKey|WM_HOTKEY|0x0312') {
        throw 'Companion configuration must use separate measured layout columns without restoring global hotkeys.'
    }
    if ($source -notmatch 'Text = "Auto-span WoW on launch"') {
        throw 'Companion auto-span caption must remain concise enough for enlarged DPI layouts.'
    }
    $packager = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\package.ps1') -Raw
    if ($packager -match 'Companion\\Linux\.md.*-Destination \$compStaging' -or
        $packager -notmatch 'Companion\\Linux\.md.*-Destination \$bundleCompanionDocs') {
        throw 'Linux compatibility documentation must ship in the complete bundle, not the minimal Windows Companion archive.'
    }
    if ($packager -notmatch 'Companion\\PORTABLE-README\.txt' -or
        $packager -notmatch "expectedEntries = @\('LICENSE', 'Offhand\.exe', 'README\.txt'\)" -or
        $packager -match 'Companion\\build\.bat.*-Destination \$compStaging' -or
        $packager -match 'Companion\\Source.*-Destination \$compStaging') {
        throw 'The portable Companion archive must contain only the executable, generated quick-start README, and license.'
    }
    if ($packager -match 'Compress-Archive' -or $packager -notmatch 'New-PortableZip') {
        throw 'Release archives must use the portable ZIP writer rather than Windows backslash entry paths.'
    }
    if ($packager -notmatch 'Sort-Object FullName' -or
        $packager -notmatch "LastWriteTime = \[DateTimeOffset\]::Parse\('2026-01-01T00:00:00Z'\)") {
        throw 'Release archives must use deterministic entry order and timestamps.'
    }
    if ($packager -match 'Offhand-Companion\.exe' -or
        $packager -notmatch 'bundleStaging "Offhand\.exe"') {
        throw 'Every shipped Companion executable, including the complete bundle, must be named Offhand.exe.'
    }
    if ($packager -notmatch '\[switch\]\$UseExistingCompanion' -or
        $packager -notmatch '\[switch\]\$CompanionChanged' -or
        $packager -notmatch '81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB' -or
        $packager -notmatch '\[string\]\$ExpectedCompanionArchiveSha256' -or
        $packager -notmatch 'Companion archive hash.*does not match expected' -or
        $packager -notmatch 'Canonical Companion SHA-256' -or
        $packager -notmatch 'contains a different executable than the canonical Companion build') {
        throw 'Release packaging must freeze the Beta 20 candidate bytes and require an explicit Companion-change lane.'
    }
    $storeBuilder = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Companion\Store\Build-StorePackage.ps1') -Raw
    if ($storeBuilder -notmatch "\[string\]\`$PackageVersion = '2\.1\.20\.0'" -or
        $storeBuilder -notmatch '\[string\]\$CompanionPath' -or
        $storeBuilder -notmatch '\[string\]\$ExpectedCompanionSha256' -or
        $storeBuilder -notmatch 'Companion SHA-256 mismatch') {
        throw 'The Store package must default to Beta 20 and support exact reviewed executable bytes with hash enforcement.'
    }
    if ($source -notmatch 'GetCurrentPackageFullName' -or
        $source -notmatch 'StoreProductId = "9PL4PW84Q90W"' -or
        $source -notmatch 'StoreProductUri = "ms-windows-store://pdp/\?ProductId=" \+ StoreProductId' -or
        $source -notmatch 'if \(isStorePackage\)(?s:.*?)Process\.Start\(CompanionDistribution\.StoreProductUri\)(?s:.*?)return;(?s:.*?)Offhand-DualMonitor/releases\?per_page=30') {
        throw 'Companion update checks must route Store installs to Microsoft Store while portable builds retain GitHub release checks.'
    }
    $releaseWorkflow = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\.github\workflows\release.yml') -Raw
    if ($releaseWorkflow -notmatch 'Validate canonical Companion executable' -or
        $releaseWorkflow -notmatch 'Validate canonical Companion archive' -or
        $releaseWorkflow -notmatch 'COMPANION_RELEASE_TAG: v2\.1\.2-beta\.20' -or
        $releaseWorkflow -notmatch 'COMPANION_SHA256: 81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB' -or
        $releaseWorkflow -notmatch 'COMPANION_ARCHIVE_SHA256: C726444612DD740BE3F923B83704D155E21BC017F7C5FE245379B19DBECC76E3' -or
        $releaseWorkflow -notmatch "GetEntry\('Offhand\.exe'\)" -or
        $releaseWorkflow -notmatch 'ComputeHash\(\$stream\)' -or
        $releaseWorkflow -notmatch 'Restore frozen Beta 20 Companion' -or
        $releaseWorkflow -notmatch 'Attach frozen Beta 20 Companion assets' -or
        $releaseWorkflow -notmatch 'dist/Offhand-Companion\.zip' -or
        $releaseWorkflow -notmatch 'dist/Offhand\.exe' -or
        $releaseWorkflow -notmatch 'package\.ps1 -Version \$version -CompanionChanged -UseExistingCompanion') {
        throw 'Release automation must validate and attach exact frozen Beta 20 assets without rebuilding the candidate executable.'
    }
    $pinnedCompanionUrl = 'https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/download/v2.1.2-beta.20/Offhand-Companion.zip'
    foreach ($relativePath in @(
        'README.md',
        'docs\CURSEFORGE_DESCRIPTION.md',
        'Website\index.html'
    )) {
        $publicSurface = Get-Content -LiteralPath (Join-Path $PSScriptRoot "..\$relativePath") -Raw
        if (-not $publicSurface.Contains($pinnedCompanionUrl) -or
            $publicSurface -match 'releases/latest/download/Offhand-Companion\.zip') {
            throw "$relativePath must point directly to the frozen Beta 20 Companion."
        }
    }
    $addonInit = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Core\Init.lua') -Raw
    if ($addonInit -notmatch 'Offhand\.companionDownloadUrl = "https://github\.com/N4UX-GIT/Offhand-DualMonitor/releases/download/v"' -or
        $addonInit -notmatch '\.\. Offhand\.companionFullVersion \.\. "/Offhand-Companion\.zip"') {
        throw 'The addon must derive its version-matched Companion download from release metadata.'
    }
    $addonOptions = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\UI\Options.lua') -Raw
    if ($addonOptions -notmatch 'local COMPANION_DOWNLOAD_URL = Offhand\.companionDownloadUrl') {
        throw 'The addon options must use the version-matched Companion download URL.'
    }
    $linuxGuide = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Companion\Linux.md') -Raw
    if ($linuxGuide -notmatch 'Wine/Proton runner must also match' -or
        $linuxGuide -notmatch 'Pre-launch script' -or
        $linuxGuide -notmatch 'WINEPREFIX') {
        throw 'Linux guide must document the matching prefix, matching runner, and Lutris pre-launch setup.'
    }
    Write-Output 'PASS: update checks are user initiated'
    Write-Output 'PASS: update checks follow the Microsoft Store or portable GitHub distribution channel'
    Write-Output 'PASS: polling is restricted to known WoW process names and topology handoff failures block unsafe spans'
    Write-Output 'PASS: manual restore returns focus and border failures include actionable diagnostics'
    Write-Output 'PASS: Companion avoids startup persistence and process-token inspection'
    Write-Output 'PASS: single-instance guard prevents duplicate Companion tray processes'
    Write-Output 'PASS: DPI-scaled dashboard geometry keeps wrapped status and configuration controls separate'
    Write-Output 'PASS: addon verification paths are visible and copied into the activity log'
    Write-Output 'PASS: hotkeyless display identification and multi-monitor selection remain separated at enlarged DPI'
    Write-Output 'PASS: Linux compatibility documentation is included by the release packager'
    Write-Output 'PASS: addon-only releases attach the frozen Beta 20 Companion assets by exact hash'
    Write-Output 'PASS: public website/docs point to the frozen Beta 20 Companion while the addon derives its version-matched URL'
    Write-Output 'PASS: release ZIPs are portable and Linux guidance covers prefix/runner matching'
    Write-Output 'PASS: all shipped Companion executables use the consistent Offhand.exe name'
    Write-Output 'PASS: release packaging preserves and verifies one canonical Companion executable'
} finally {
    if (Test-Path -LiteralPath $testExe) { Remove-Item -LiteralPath $testExe }
    if (Test-Path -LiteralPath $layoutTestExe) { Remove-Item -LiteralPath $layoutTestExe }
}
