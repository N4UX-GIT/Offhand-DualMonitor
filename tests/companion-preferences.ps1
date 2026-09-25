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
    if ($source -notmatch 'AssemblyInformationalVersion\("2\.1\.2-beta\.10"\)' -or
        $source -notmatch 'AssemblyFileVersion\("2\.1\.2\.10"\)') {
        throw 'Companion binary metadata must identify the exact beta build.'
    }
    if ($source -match 'GetProcessesByName' -or $source -notmatch 'Process\[\] processes = Process\.GetProcesses\(\)') {
        throw 'Companion polling must enumerate the process table once instead of querying every WoW process name separately.'
    }
    if ($source -notmatch 'monitorTimer\.Interval = proc == null \? 5000 : 2000' -or
        $source -notmatch 'ShowHelpDialog\(\)(?s:.*?)SuspendUiPolling\(\)(?s:.*?)finally \{ ResumeUiPolling\(\); \}') {
        throw 'Companion polling must back off while WoW is absent and pause during modal Help interaction.'
    }
    if ($source -notmatch '!CompanionTopologyBridge\.TryWrite(?s:.*?)throw new IOException') {
        throw 'Companion must refuse to span when addon topology cannot be written.'
    }
    if ($source -notmatch 'private RichTextBox logBox' -or
        $source -notmatch 'logBox = new RichTextBox(?s:.*?)WordWrap = true') {
        throw 'Companion activity log must remain a word-wrapped read-only text surface.'
    }
    if ($source -notmatch 'lblDisplayInfo = new Label(?s:.*?)Size = new Size\(470, 36\)(?s:.*?)AutoSize = false') {
        throw 'Companion display-plan status must retain enough fixed-width height to wrap disconnect errors.'
    }
    if ($source -notmatch 'lblAddonReason = new Label(?s:.*?)Size = new Size\(470, 42\)(?s:.*?)AutoSize = false' -or
        $source -notmatch 'AddLog\("Addon verification: " \+ status\.Reason\)') {
        throw 'Companion must show and log the complete client-specific addon verification diagnostic.'
    }
    $hotkey = [regex]::Match($source, 'cmbHotkey = new ComboBox \{ Location = new Point\((?<x>\d+), 82\), Size = new Size\((?<w>\d+), 22\)')
    $monitors = [regex]::Match($source, 'clbMonitors = new CheckedListBox \{ Location = new Point\((?<x>\d+), 50\)')
    if (-not $hotkey.Success -or -not $monitors.Success -or
        ([int]$hotkey.Groups['x'].Value + [int]$hotkey.Groups['w'].Value) -ge [int]$monitors.Groups['x'].Value) {
        throw 'Companion hotkey selector must not overlap the display checklist.'
    }
    $packager = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\package.ps1') -Raw
    if ($packager -notmatch 'Companion\\Linux\.md.*-Destination \$compStaging' -or
        $packager -notmatch 'Companion\\Linux\.md.*-Destination \$bundleCompanionDocs') {
        throw 'Linux compatibility documentation must ship in Companion and complete release archives.'
    }
    if ($packager -match 'Compress-Archive' -or $packager -notmatch 'New-PortableZip') {
        throw 'Release archives must use the portable ZIP writer rather than Windows backslash entry paths.'
    }
    if ($packager -match 'Offhand-Companion\.exe' -or
        $packager -notmatch 'bundleStaging "Offhand\.exe"') {
        throw 'Every shipped Companion executable, including the complete bundle, must be named Offhand.exe.'
    }
    $linuxGuide = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Companion\Linux.md') -Raw
    if ($linuxGuide -notmatch 'Wine/Proton runner must also match' -or
        $linuxGuide -notmatch 'Pre-launch script' -or
        $linuxGuide -notmatch 'WINEPREFIX') {
        throw 'Linux guide must document the matching prefix, matching runner, and Lutris pre-launch setup.'
    }
    Write-Output 'PASS: update checks are user initiated'
    Write-Output 'PASS: idle polling is throttled and topology handoff failures block unsafe spans'
    Write-Output 'PASS: long display-plan and activity-log text uses wrapped surfaces'
    Write-Output 'PASS: addon verification paths are visible and copied into the activity log'
    Write-Output 'PASS: hotkey selector does not overlap the display checklist'
    Write-Output 'PASS: Linux compatibility documentation is included by the release packager'
    Write-Output 'PASS: release ZIPs are portable and Linux guidance covers prefix/runner matching'
    Write-Output 'PASS: all shipped Companion executables use the consistent Offhand.exe name'
} finally {
    if (Test-Path -LiteralPath $testExe) { Remove-Item -LiteralPath $testExe }
}
