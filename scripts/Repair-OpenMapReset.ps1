# Local recovery patch for the exact OpenMap v0.7.5-beta source tested on Forever 70862.
# This tool is separate from Offhand's addon runtime and release packages.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OpenMapPath,
    [ValidateSet('Check', 'Apply', 'Restore')][string]$Mode = 'Check'
)

$ErrorActionPreference = 'Stop'
$originalHash = '14550426084949EE95C6D0B3B2F1CAAB7085D50AE5825C5A4DF83BA18792183B'
$patchedHash = '5E8D073C4A4E208233C955F093CECC397C1CC2DD07E6DD4C7A7CC3F64E4B6251'
$root = (Resolve-Path -LiteralPath $OpenMapPath).Path
$source = Join-Path $root 'Map/Window.lua'
$backup = "$source.offhand-reset-original"
$currentHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash

if ($Mode -eq 'Check') {
    if ($currentHash -eq $originalHash) { Write-Output 'Recognized original OpenMap v0.7.5-beta; reset patch is absent.' }
    elseif ($currentHash -eq $patchedHash) { Write-Output 'Verified OpenMap reset patch is installed.' }
    else { throw 'Unrecognized Window.lua. This patch does not support these source bytes.' }
    return
}

if (Get-Process -Name 'Wow*' -ErrorAction SilentlyContinue) {
    throw 'Close World of Warcraft before applying or restoring this file patch.'
}
if ($Mode -eq 'Restore') {
    if ($currentHash -eq $originalHash) { Write-Output 'Original source already installed.'; return }
    if ($currentHash -ne $patchedHash) { throw 'Refusing to overwrite changed or updated OpenMap source.' }
    if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $originalHash) {
        throw 'The original-source backup is missing or has changed.'
    }
    Copy-Item -LiteralPath $backup -Destination $source
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $originalHash) { throw 'Restore verification failed.' }
    Write-Output 'Restored original OpenMap source. Saved settings were not changed.'
    return
}
if ($currentHash -eq $patchedHash) { Write-Output 'Verified reset patch already installed; no change.'; return }
if ($currentHash -ne $originalHash) { throw 'Refusing to patch changed or updated OpenMap source.' }
if (Test-Path -LiteralPath $backup) {
    if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $originalHash) {
        throw 'Refusing to replace a different existing backup.'
    }
} else {
    Copy-Item -LiteralPath $source -Destination $backup
}

$text = [IO.File]::ReadAllText($source).Replace("`r`n", "`n")
$before = "function mod:ResetWindow()`n`tmod.db.window = false"
$after = "function mod:ResetWindow()`n`tif InCombatLockdown() then return false end`n`tmod.db.window = false"
if (-not $text.Contains($before)) { throw 'Reset function marker is missing.' }
$text = $text.Replace($before, $after)
$before = "`t`tif blizzardSize and not Maximized() then map:SetSize(blizzardSize[1], blizzardSize[2]) Refit() end`n`t`tours = false"
$after = @'
		if blizzardSize and not Maximized() then map:SetSize(blizzardSize[1], blizzardSize[2]) Refit() end
		-- Local recovery fix: a manually shown map can bypass native panel layout.
		-- An explicit reset must recover its title even when the old anchor is off screen.
		if not Maximized() then
			map:StopMovingOrSizing()
			map:ClearAllPoints()
			map:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			Save()
		end
		ours = false
'@
if (-not $text.Contains($before)) { throw 'Reset positioning marker is missing.' }
$text = $text.Replace($before, $after.Replace("`r`n", "`n"))
$bytes = [Text.UTF8Encoding]::new($false).GetBytes($text)
$sha = [Security.Cryptography.SHA256]::Create()
try { $generatedHash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '') }
finally { $sha.Dispose() }
if ($generatedHash -ne $patchedHash) { throw 'Generated patch differs from the native-tested source; no source write performed.' }
[IO.File]::WriteAllBytes($source, $bytes)
if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $patchedHash) { throw 'Patch verification failed.' }
Write-Output 'Installed the verified local OpenMap reset patch. Out of combat, use /openmap > Look > Reset size and place.'
