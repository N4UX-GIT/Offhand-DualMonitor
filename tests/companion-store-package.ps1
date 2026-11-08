param(
    [Parameter(Mandatory=$true)][string]$PackagePath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompanionSha256,
    [Parameter(Mandatory=$true)][string]$ExpectedPackageVersion,
    [string]$ExpectedIdentityName = 'N4UX.OffhandCompanion'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $PackagePath).Path)
try {
    $names = @($zip.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
    $expected = @('Offhand.exe','AppxManifest.xml','AppxBlockMap.xml','[Content_Types].xml',
        'Assets/StoreLogo.png','Assets/Square44x44Logo.png','Assets/Square150x150Logo.png',
        'Assets/Wide310x150Logo.png','Assets/Square310x310Logo.png')
    if ((@($names | Sort-Object) -join '|') -ne (@($expected | Sort-Object) -join '|')) {
        throw ('Unexpected MSIX entries: ' + ($names -join ', '))
    }
    $reader = [IO.StreamReader]::new($zip.GetEntry('AppxManifest.xml').Open())
    try { [xml]$manifest = $reader.ReadToEnd() } finally { $reader.Dispose() }
    $ns = [Xml.XmlNamespaceManager]::new($manifest.NameTable)
    $ns.AddNamespace('f','http://schemas.microsoft.com/appx/manifest/foundation/windows10')
    $ns.AddNamespace('desktop','http://schemas.microsoft.com/appx/manifest/desktop/windows10')
    $identity = $manifest.SelectSingleNode('/f:Package/f:Identity',$ns)
    if ($identity.Name -ne $ExpectedIdentityName -or $identity.Version -ne $ExpectedPackageVersion -or
        $identity.ProcessorArchitecture -ne 'x64' -or $identity.Publisher -ne 'CN=E7BD7796-76DA-40C2-B114-9DD85609CD7F') {
        throw 'Unexpected Store package identity, version, architecture or publisher.'
    }
    $family = $manifest.SelectSingleNode('/f:Package/f:Dependencies/f:TargetDeviceFamily',$ns)
    if ($family.Name -ne 'Windows.Desktop' -or $family.MinVersion -ne '10.0.17763.0') { throw 'Unexpected target device family.' }
    $apps = @($manifest.SelectNodes('/f:Package/f:Applications/f:Application',$ns))
    if ($apps.Count -ne 1 -or $apps[0].Executable -ne 'Offhand.exe' -or $apps[0].EntryPoint -ne 'Windows.FullTrustApplication') {
        throw 'Unexpected Store entry point.'
    }
    $capabilities = @($manifest.SelectNodes('/f:Package/f:Capabilities/*',$ns) | ForEach-Object { $_.GetAttribute('Name') } | Sort-Object)
    if (($capabilities -join '|') -ne 'internetClient|runFullTrust') { throw 'Unexpected capabilities.' }
    $startup = @($manifest.SelectNodes('//desktop:StartupTask',$ns))
    if ($startup.Count -ne 1 -or $startup[0].Enabled -ne 'false' -or $startup[0].TaskId -ne 'OffhandCompanionStartup') {
        throw 'Startup must remain opt-in and Windows-managed.'
    }
    $stream = $zip.GetEntry('Offhand.exe').Open()
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $embeddedHash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','') }
    finally { $stream.Dispose(); $sha.Dispose() }
    if ($embeddedHash -ne $ExpectedCompanionSha256.ToUpperInvariant()) { throw 'Store executable differs from the reviewed portable candidate.' }
    Write-Output "PASS: MSIX file boundaries, identity, target family, capabilities, startup policy and exact executable parity ($embeddedHash)"
} finally { $zip.Dispose() }
