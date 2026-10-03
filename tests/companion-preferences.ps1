$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'C# compiler unavailable' }
$testExe = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-preferences-' + [guid]::NewGuid().ToString() + '.exe')
try {
    & $compiler /nologo /target:exe /main:Offhand.Companion.PreferencesTest "/out:$testExe" /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot '..\Companion\Source\Program.cs') (Join-Path $PSScriptRoot 'CompanionPreferences.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Companion test compilation failed' }
    & $testExe
    if ($LASTEXITCODE -ne 0) { throw 'Companion preference test failed' }

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
    if ($source -notmatch 'AssemblyInformationalVersion\("2\.1\.2-beta\.18"\)' -or
        $source -notmatch 'AssemblyFileVersion\("2\.1\.2\.18"\)') {
        throw 'Companion binary metadata must identify the exact beta build.'
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
    $identify = [regex]::Match($source, 'Button btnIdentifyDisplays = CreateButton\("Identify Displays", (?<x>\d+), 82, (?<w>\d+), 27')
    $monitors = [regex]::Match($source, 'clbMonitors = new CheckedListBox \{ Location = new Point\((?<x>\d+), 50\)')
    if (-not $identify.Success -or -not $monitors.Success -or
        ([int]$identify.Groups['x'].Value + [int]$identify.Groups['w'].Value) -ge [int]$monitors.Groups['x'].Value -or
        $source -match 'RegisterHotKey|UnregisterHotKey|WM_HOTKEY|0x0312') {
        throw 'Companion display identification must not overlap the checklist or restore global hotkeys.'
    }
    $autoSpan = [regex]::Match($source, 'chkAutoSpan = new CheckBox(?s:.*?)Location = new Point\((?<x>\d+), 28\)(?s:.*?)Size = new Size\((?<w>\d+), 22\)')
    $monitorLabel = [regex]::Match($source, 'Label lblMonitors = new Label \{ Text = "Span displays:", Location = new Point\((?<x>\d+), 26\)')
    if (-not $autoSpan.Success -or -not $monitorLabel.Success -or
        ([int]$autoSpan.Groups['x'].Value + [int]$autoSpan.Groups['w'].Value) -ge [int]$monitorLabel.Groups['x'].Value) {
        throw 'Companion auto-span preference must not cover the Span displays heading.'
    }
    if ($source -notmatch 'Text = "Auto-span WoW on launch"') {
        throw 'Companion auto-span caption must remain concise enough for enlarged DPI layouts.'
    }
    $packager = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\package.ps1') -Raw
    if ($packager -notmatch 'Companion\\Linux\.md.*-Destination \$compStaging' -or
        $packager -notmatch 'Companion\\Linux\.md.*-Destination \$bundleCompanionDocs') {
        throw 'Linux compatibility documentation must ship in Companion and complete release archives.'
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
        $packager -notmatch 'A42A45CB149C66EF884308F15A79EE8905C58A94E9B4AE1A3B05B43BAF929F37' -or
        $packager -notmatch 'Canonical Companion SHA-256' -or
        $packager -notmatch 'contains a different executable than the canonical Companion build') {
        throw 'Release packaging must freeze Beta 18 by hash and require an explicit Companion-change lane.'
    }
    $storeBuilder = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Companion\Store\Build-StorePackage.ps1') -Raw
    if ($storeBuilder -notmatch "\[string\]\`$PackageVersion = '2\.1\.18\.0'") {
        throw 'The Store package default must identify the Beta 18 Companion baseline.'
    }
    $releaseWorkflow = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\.github\workflows\release.yml') -Raw
    if ($releaseWorkflow -notmatch 'Validate canonical Companion executable' -or
        $releaseWorkflow -notmatch 'Validate canonical Companion archive' -or
        $releaseWorkflow -notmatch 'COMPANION_RELEASE_TAG: v2\.1\.2-beta\.18' -or
        $releaseWorkflow -notmatch 'COMPANION_SHA256: A42A45CB149C66EF884308F15A79EE8905C58A94E9B4AE1A3B05B43BAF929F37' -or
        $releaseWorkflow -notmatch 'COMPANION_ARCHIVE_SHA256: AD49BE14A9C8ADF5A888F873CE9B99F183C4AD2924909ECDF52801F303248A93' -or
        $releaseWorkflow -notmatch "GetEntry\('Offhand\.exe'\)" -or
        $releaseWorkflow -notmatch 'ComputeHash\(\$stream\)' -or
        $releaseWorkflow -notmatch 'Restore frozen Beta 18 Companion' -or
        $releaseWorkflow -notmatch 'Attach frozen Beta 18 Companion assets' -or
        $releaseWorkflow -notmatch 'dist/Offhand-Companion\.zip' -or
        $releaseWorkflow -notmatch 'dist/Offhand\.exe' -or
        $releaseWorkflow -notmatch 'package\.ps1 -Version \$version -CompanionChanged -UseExistingCompanion') {
        throw 'Release automation must validate and attach exact frozen Beta 18 assets without rebuilding the reviewed executable.'
    }
    $pinnedCompanionUrl = 'https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/download/v2.1.2-beta.18/Offhand-Companion.zip'
    foreach ($relativePath in @(
        'Core\Init.lua',
        'UI\Options.lua',
        'README.md',
        'docs\CURSEFORGE_DESCRIPTION.md',
        'Website\index.html'
    )) {
        $publicSurface = Get-Content -LiteralPath (Join-Path $PSScriptRoot "..\$relativePath") -Raw
        if (-not $publicSurface.Contains($pinnedCompanionUrl) -or
            $publicSurface -match 'releases/latest/download/Offhand-Companion\.zip') {
            throw "$relativePath must point directly to the frozen Beta 18 Companion."
        }
    }
    $linuxGuide = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Companion\Linux.md') -Raw
    if ($linuxGuide -notmatch 'Wine/Proton runner must also match' -or
        $linuxGuide -notmatch 'Pre-launch script' -or
        $linuxGuide -notmatch 'WINEPREFIX') {
        throw 'Linux guide must document the matching prefix, matching runner, and Lutris pre-launch setup.'
    }
    Write-Output 'PASS: update checks are user initiated'
    Write-Output 'PASS: polling is restricted to known WoW process names and topology handoff failures block unsafe spans'
    Write-Output 'PASS: manual restore returns focus and border failures include actionable diagnostics'
    Write-Output 'PASS: Companion avoids startup persistence and process-token inspection'
    Write-Output 'PASS: single-instance guard prevents duplicate Companion tray processes'
    Write-Output 'PASS: DPI-scaled dashboard geometry keeps wrapped status and configuration controls separate'
    Write-Output 'PASS: addon verification paths are visible and copied into the activity log'
    Write-Output 'PASS: hotkeyless display identification does not overlap the display checklist'
    Write-Output 'PASS: Linux compatibility documentation is included by the release packager'
    Write-Output 'PASS: addon-only releases attach the published Beta 18 Companion assets by exact hash'
    Write-Output 'PASS: every public Companion download points directly to Beta 18'
    Write-Output 'PASS: release ZIPs are portable and Linux guidance covers prefix/runner matching'
    Write-Output 'PASS: all shipped Companion executables use the consistent Offhand.exe name'
    Write-Output 'PASS: release packaging preserves and verifies one canonical Companion executable'
} finally {
    if (Test-Path -LiteralPath $testExe) { Remove-Item -LiteralPath $testExe }
}
