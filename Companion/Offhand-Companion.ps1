# ==============================================================================
# Offhand Companion: Multi-Monitor Desktop Controller & Background Watcher
# Native Windows GUI with System Tray, Auto-Spanning, and Addon Validation
# Classic Warcraft Theme
# ==============================================================================

Add-Type -AssemblyName System.Windows.Forms
if (-not ('Win32Key' -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win32Key {
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
}
"@
}
Add-Type -AssemblyName System.Drawing

. (Join-Path $PSScriptRoot 'Offhand-Window.ps1')

# ==============================================================================
# Suppress all PowerShell terminal windows
# OffhandNative is already available from Offhand-Window.ps1
# ==============================================================================
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class OffhandConsole {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

# Hide our own console window immediately
$consoleHwnd = [OffhandConsole]::GetConsoleWindow()
if ($consoleHwnd -ne [IntPtr]::Zero) {
    [void][OffhandConsole]::ShowWindow($consoleHwnd, 0)
}

# Hide any other PowerShell terminal windows (but not our companion GUI)
$myPid = [System.Diagnostics.Process]::GetCurrentProcess().Id
$psProcs = @(Get-Process -Name 'powershell','pwsh' -ErrorAction SilentlyContinue |
             Where-Object { $_.Id -ne $myPid -and $_.MainWindowHandle -ne [IntPtr]::Zero })
foreach ($p in $psProcs) {
    [void][OffhandNative]::ShowWindow($p.MainWindowHandle, 0)
}

# ==============================================================================
# Warcraft Dark Interface Palette (Black / Dark Grey / Burnished Gold)
# ==============================================================================
$cBg           = [System.Drawing.Color]::FromArgb(12, 12, 14)          # Obsidian black canvas (#0c0c0e)
$cCard         = [System.Drawing.Color]::FromArgb(20, 20, 24)          # Dark forged iron card (#141418)
$cBorder       = [System.Drawing.Color]::FromArgb(145, 115, 55)        # Burnished gold outer border (#917337)
$cBorderDim    = [System.Drawing.Color]::FromArgb(65, 52, 28)         # Antique bronze divider (#41341c)
$cText         = [System.Drawing.Color]::FromArgb(235, 230, 215)       # Warm parchment white (#ebe6d7)
$cMuted        = [System.Drawing.Color]::FromArgb(155, 145, 130)       # Weathered silver-grey (#9b9182)
$cGold         = [System.Drawing.Color]::FromArgb(240, 184, 54)        # Iconic Warcraft Gold (#f0b836)
$cGoldBright   = [System.Drawing.Color]::FromArgb(255, 215, 80)        # Luminous gold highlight (#ffd750)
$cBrass        = [System.Drawing.Color]::FromArgb(185, 145, 60)        # Warm brass trim (#b9913c)
$cGreen        = [System.Drawing.Color]::FromArgb(72, 204, 120)        # Active emerald green (#48cc78)
$cRed          = [System.Drawing.Color]::FromArgb(220, 75, 75)         # Crimson warning / danger (#dc4b4b)
$cYellow       = [System.Drawing.Color]::FromArgb(240, 185, 55)        # Warning amber (#f0b937)
$cBtnBg        = [System.Drawing.Color]::FromArgb(28, 28, 34)          # Dark iron button (#1c1c22)
$cBtnPrimaryBg = [System.Drawing.Color]::FromArgb(36, 30, 20)          # Dark bronze primary button (#241e14)
$cBtnDanger    = [System.Drawing.Color]::FromArgb(44, 16, 16)          # Danger button (#2c1010)
$cLogBg        = [System.Drawing.Color]::FromArgb(8, 8, 10)            # Deepest obsidian log (#08080a)
$cLogText      = [System.Drawing.Color]::FromArgb(195, 190, 175)       # Parchment log text (#c3beaf)

# ==============================================================================
# Helper: Styled Button with gold border
# ==============================================================================
function New-StyledButton {
    param($text, $x, $y, $w, $h, $bgColor, $textColor, $borderColor)
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Size = New-Object System.Drawing.Size($w, $h)
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 1
    $btn.FlatAppearance.BorderColor = if ($borderColor) { $borderColor } else { $cBorder }
    $btn.BackColor = $bgColor
    $btn.ForeColor = $textColor
    $btn.Font = New-Object System.Drawing.Font("Georgia", 9, [System.Drawing.FontStyle]::Bold)
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $btn
}

# Helper: card panel with gold border drawn via Paint
function New-CardPanel {
    param($x, $y, $w, $h, $title)
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point($x, $y)
    $panel.Size = New-Object System.Drawing.Size($w, $h)
    $panel.BackColor = $cCard

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "  " + $title.ToUpper()
    $lbl.Location = New-Object System.Drawing.Point(0, 4)
    $lbl.Size = New-Object System.Drawing.Size($w, 20)
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = $cGold
    $panel.Controls.Add($lbl)

    $panel.add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $pen = New-Object System.Drawing.Pen($cBorder, 1)
        $g.DrawRectangle($pen, 0, 0, $s.ClientSize.Width - 1, $s.ClientSize.Height - 1)
        $pen.Dispose()
        $penDim = New-Object System.Drawing.Pen($cBorderDim, 1)
        $g.DrawLine($penDim, 1, 24, $s.ClientSize.Width - 2, 24)
        $penDim.Dispose()
    })
    return $panel
}

# ==============================================================================
# Main Window
# ==============================================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Offhand Companion"
$form.Size = New-Object System.Drawing.Size(524, 628)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = $cBg
$form.ForeColor = $cText

# ==============================================================================
# HEADER â€” Logo + Title
# ==============================================================================
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(524, 90)
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(15, 15, 18)
$form.Controls.Add($headerPanel)

$headerPanel.add_Paint({
    param($s, $e)
    $pen = New-Object System.Drawing.Pen($cBorder, 2)
    $e.Graphics.DrawLine($pen, 0, $s.Height - 1, $s.Width, $s.Height - 1)
    $pen.Dispose()
})

# Logo image
$logoPicBox = New-Object System.Windows.Forms.PictureBox
$logoPicBox.Location = New-Object System.Drawing.Point(10, 8)
$logoPicBox.Size = New-Object System.Drawing.Size(74, 74)
$logoPicBox.SizeMode = "Zoom"
$logoPicBox.BackColor = [System.Drawing.Color]::Transparent

$logoCandidates = @(
    (Join-Path $PSScriptRoot "..\Media\offhand-icon.png"),
    (Join-Path $PSScriptRoot "..\Media\offhand-logo.png"),
    (Join-Path $PSScriptRoot "..\Website\assets\offhand-icon.png"),
    (Join-Path $PSScriptRoot "..\Media\offhand-banner.png")
)
foreach ($path in $logoCandidates) {
    if (Test-Path $path -ErrorAction SilentlyContinue) {
        try { $logoPicBox.Image = [System.Drawing.Image]::FromFile($path); break } catch { }
    }
}
$headerPanel.Controls.Add($logoPicBox)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "OFFHAND"
$titleLabel.Location = New-Object System.Drawing.Point(96, 12)
$titleLabel.Size = New-Object System.Drawing.Size(400, 34)
$titleLabel.Font = New-Object System.Drawing.Font("Georgia", 22, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = $cGold
$titleLabel.BackColor = [System.Drawing.Color]::Transparent
$headerPanel.Controls.Add($titleLabel)

$subLabel = New-Object System.Windows.Forms.Label
$subLabel.Text = "Multi-Monitor Companion for World of Warcraft"
$subLabel.Location = New-Object System.Drawing.Point(98, 48)
$subLabel.Size = New-Object System.Drawing.Size(400, 18)
$subLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$subLabel.ForeColor = $cBrass
$subLabel.BackColor = [System.Drawing.Color]::Transparent
$headerPanel.Controls.Add($subLabel)

$versionLabel = New-Object System.Windows.Forms.Label
$versionLabel.Text = "v1.2"
$versionLabel.Location = New-Object System.Drawing.Point(98, 66)
$versionLabel.Size = New-Object System.Drawing.Size(100, 14)
$versionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Italic)
$versionLabel.ForeColor = $cMuted
$versionLabel.BackColor = [System.Drawing.Color]::Transparent
$headerPanel.Controls.Add($versionLabel)

# ==============================================================================
# STATUS CARD
# ==============================================================================
$statusPanel = New-CardPanel -x 16 -y 102 -w 490 -h 118 -title "System Status"
$form.Controls.Add($statusPanel)

$lblWowStatus = New-Object System.Windows.Forms.Label
$lblWowStatus.Text = "  WoW Process: Checking..."
$lblWowStatus.Location = New-Object System.Drawing.Point(0, 30)
$lblWowStatus.Size = New-Object System.Drawing.Size(490, 20)
$lblWowStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblWowStatus.ForeColor = $cMuted
$statusPanel.Controls.Add($lblWowStatus)

$lblAddonStatus = New-Object System.Windows.Forms.Label
$lblAddonStatus.Text = "  Offhand Addon: Checking..."
$lblAddonStatus.Location = New-Object System.Drawing.Point(0, 54)
$lblAddonStatus.Size = New-Object System.Drawing.Size(490, 20)
$lblAddonStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblAddonStatus.ForeColor = $cMuted
$statusPanel.Controls.Add($lblAddonStatus)

$lblDisplayInfo = New-Object System.Windows.Forms.Label
$lblDisplayInfo.Text = "  Virtual Desktop: Checking..."
$lblDisplayInfo.Location = New-Object System.Drawing.Point(0, 78)
$lblDisplayInfo.Size = New-Object System.Drawing.Size(490, 18)
$lblDisplayInfo.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblDisplayInfo.ForeColor = $cMuted
$statusPanel.Controls.Add($lblDisplayInfo)

$lblAddonReason = New-Object System.Windows.Forms.Label
$lblAddonReason.Text = ""
$lblAddonReason.Location = New-Object System.Drawing.Point(0, 98)
$lblAddonReason.Size = New-Object System.Drawing.Size(490, 16)
$lblAddonReason.Font = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Italic)
$lblAddonReason.ForeColor = $cYellow
$statusPanel.Controls.Add($lblAddonReason)

# ==============================================================================
# CONFIGURATION CARD
# ==============================================================================
$configPanel = New-CardPanel -x 16 -y 230 -w 490 -h 54 -title "Configuration"
$form.Controls.Add($configPanel)

$chkAutoSpan = New-Object System.Windows.Forms.CheckBox
$chkAutoSpan.Text = "Automatically span WoW window on game launch"
$chkAutoSpan.Location = New-Object System.Drawing.Point(10, 28)
$chkAutoSpan.Size = New-Object System.Drawing.Size(460, 22)
$chkAutoSpan.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$chkAutoSpan.ForeColor = $cText
$chkAutoSpan.BackColor = [System.Drawing.Color]::Transparent
$chkAutoSpan.Checked = $true
$configPanel.Controls.Add($chkAutoSpan)

# ==============================================================================
# ACTION BUTTONS
# ==============================================================================
$btnSpanNow = New-StyledButton -text "Span WoW Window Now" -x 16 -y 296 -w 238 -h 36 `
    -bgColor $cBtnPrimaryBg -textColor $cGoldBright -borderColor $cGold
$form.Controls.Add($btnSpanNow)

$btnToggleWatch = New-StyledButton -text "Pause Monitoring" -x 262 -y 296 -w 244 -h 36 `
    -bgColor $cBtnBg -textColor $cText -borderColor $cBorder
$form.Controls.Add($btnToggleWatch)

# ==============================================================================
# ACTIVITY LOG CARD
# ==============================================================================
$logPanel = New-CardPanel -x 16 -y 344 -w 490 -h 200 -title "Activity Log"
$form.Controls.Add($logPanel)

$logBox = New-Object System.Windows.Forms.ListBox
$logBox.Location = New-Object System.Drawing.Point(4, 28)
$logBox.Size = New-Object System.Drawing.Size(482, 166)
$logBox.BackColor = $cLogBg
$logBox.ForeColor = $cLogText
$logBox.BorderStyle = "None"
$logBox.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$logPanel.Controls.Add($logBox)

# ==============================================================================
# FOOTER BUTTONS
# ==============================================================================
$btnMinimize = New-StyledButton -text "Minimize to Tray" -x 16 -y 556 -w 152 -h 30 `
    -bgColor $cBtnBg -textColor $cMuted -borderColor $cBorderDim
$form.Controls.Add($btnMinimize)

$btnExit = New-StyledButton -text "Exit Companion" -x 356 -y 556 -w 152 -h 30 `
    -bgColor $cBtnDanger -textColor ([System.Drawing.Color]::FromArgb(235, 130, 130)) `
    -borderColor ([System.Drawing.Color]::FromArgb(140, 45, 45))
$form.Controls.Add($btnExit)

# ==============================================================================
# LOGGING HELPER
# ==============================================================================
function Add-Log {
    param($msg)
    $time = (Get-Date).ToString("HH:mm:ss")
    $logBox.Items.Insert(0, "[$time] $msg")
    while ($logBox.Items.Count -gt 100) {
        $logBox.Items.RemoveAt($logBox.Items.Count - 1)
    }
}

# ==============================================================================
# SYSTEM TRAY ICON
# ==============================================================================
$trayIcon = New-Object System.Windows.Forms.NotifyIcon
$trayIcon.Text = "Offhand Companion"
$trayIcon.Visible = $true

$bmp = New-Object System.Drawing.Bitmap 16, 16
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(8, 10, 18))
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 184, 255))
$fontIcon = New-Object System.Drawing.Font("Georgia", 9, [System.Drawing.FontStyle]::Bold)
$g.DrawString("A", $fontIcon, $brush, 1, 0)
$g.Dispose(); $brush.Dispose(); $fontIcon.Dispose()
$hIcon = $bmp.GetHicon()
$trayIcon.Icon = [System.Drawing.Icon]::FromHandle($hIcon)

$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$trayMenu.BackColor = $cCard
$trayMenu.ForeColor = $cText
$itemOpen = $trayMenu.Items.Add("Open Dashboard")
$trayMenu.Items.Add("-")
$itemSpan = $trayMenu.Items.Add("Span WoW Now")
$itemAuto = $trayMenu.Items.Add("Auto-Span Enabled")
$itemAuto.Checked = $true
$trayMenu.Items.Add("-")
$itemExit = $trayMenu.Items.Add("Exit")
$trayIcon.ContextMenuStrip = $trayMenu

$trayIcon.add_DoubleClick({
    $form.Show(); $form.WindowState = "Normal"; $form.Activate()
})
$itemOpen.add_Click({
    $form.Show(); $form.WindowState = "Normal"; $form.Activate()
})
$itemAuto.add_Click({
    $chkAutoSpan.Checked = -not $chkAutoSpan.Checked
    $itemAuto.Checked = $chkAutoSpan.Checked
})

# ==============================================================================
# SPAN LOGIC
# ==============================================================================
function Invoke-SpanWindow {
    param([bool]$manual = $false)
    try {
        $bounds = Invoke-OffhandSpan (Get-WoWProcess)
        Add-Log "Spanned $($bounds.Width)x$($bounds.Height). Calibrate with /OFFHAND wizard."
        $trayIcon.ShowBalloonTip(3000, "Offhand Spanned", "Window spanned. Use /OFFHAND wizard to calibrate.", "Info")
        return $true
    } catch {
        Add-Log $_.Exception.Message
        if ($manual) {
            [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "OFFHAND", "OK", "Information")
        }
        return $false
    }
}

# ==============================================================================
# BACKGROUND WATCHER TIMER
# ==============================================================================
$isMonitoring = $true
$spannedPids  = @{}
$retryAfter   = @{}
$processSeenTime = @{}

$hotkeyTimer = New-Object System.Windows.Forms.Timer
$hotkeyTimer.Interval = 50
$hotkeyTimer.add_Tick({
    if ($chkHotkey.Checked) {
        $ctrl = [Win32Key]::GetAsyncKeyState(0x11)
        $alt = [Win32Key]::GetAsyncKeyState(0x12)
        $s = [Win32Key]::GetAsyncKeyState(0x53)
        if ($ctrl -lt 0 -and $alt -lt 0 -and $s -lt 0) {
            if (-not $script:hotkeyTriggered) {
                $script:hotkeyTriggered = $true
                Add-Log "Global Hotkey (Ctrl+Alt+S) pressed. Triggering span manually."
                Invoke-SpanWindow -manual $true
            }
        } else {
            $script:hotkeyTriggered = $false
        }
    }
})


$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000

$timer.add_Tick({
    try {
        $vs = Get-OFFHANDDesktopBounds
        $lblDisplayInfo.Text = "  Virtual Desktop: $($vs.Width) x $($vs.Height) px  (Offset X:$($vs.X), Y:$($vs.Y))"
    } catch {
        $lblDisplayInfo.Text = "  Virtual Desktop: physical coordinates unavailable"
    }

    $proc = Get-WoWProcess
    if ($proc) {
        $lblWowStatus.Text = "  â— WoW Running  ($($proc.ProcessName)  PID: $($proc.Id))"
        $lblWowStatus.ForeColor = $cGreen

        $status = Test-OffhandAddonStatus -proc $proc
        if ($status.Installed) {
            $lblAddonStatus.Text = "  â— Offhand Addon: INSTALLED"
            $lblAddonStatus.ForeColor = $cGreen
            $lblAddonReason.Text = "  Confirm OFFHAND is enabled in the current WoW session."
        } else {
            $lblAddonStatus.Text = "  â—‹ Offhand Addon: NOT VERIFIED"
            $lblAddonStatus.ForeColor = $cRed
            $lblAddonReason.Text = "  $($status.Reason)"
        }

        if ($isMonitoring -and $chkAutoSpan.Checked -and $status.Installed) {
            if (-not $processSeenTime.ContainsKey($proc.Id)) {
                $processSeenTime[$proc.Id] = Get-Date
                Add-Log "New WoW process detected. Waiting $($numDelay.Value) seconds before spanning..."
            }
            if (-not $spannedPids.ContainsKey($proc.Id) -and
                (-not $retryAfter.ContainsKey($proc.Id) -or (Get-Date) -ge $retryAfter[$proc.Id])) {
                $timeWaited = ((Get-Date) - $processSeenTime[$proc.Id]).TotalSeconds
                if ($timeWaited -ge [double]$numDelay.Value) {
                    Add-Log "Delay complete. Spanning window now..."
                    $retryAfter[$proc.Id] = (Get-Date).AddSeconds(10)
                    if (Invoke-SpanWindow -manual $false) { $spannedPids[$proc.Id] = $true }
                }
            }
        }
    } else {
        $lblWowStatus.Text = "  â—‹ WoW Process: Not running"
        $lblWowStatus.ForeColor = $cMuted
        $lblAddonStatus.Text = "  â—‹ Offhand Addon: Waiting for WoW..."
        $lblAddonStatus.ForeColor = $cMuted
        $lblAddonReason.Text = ""
    }

    $keys = @($spannedPids.Keys)
    foreach ($k in $keys) {
        if (-not (Get-Process -Id $k -ErrorAction SilentlyContinue)) {
            $spannedPids.Remove($k); $retryAfter.Remove($k)
            Add-Log "WoW process (PID: $k) closed."
        }
    }
})

# ==============================================================================
# UI EVENT HANDLERS
# ==============================================================================
$btnSpanNow.add_Click({ Invoke-SpanWindow -manual $true })

$btnToggleWatch.add_Click({
    $isMonitoring = -not $isMonitoring
    if ($isMonitoring) {
        $btnToggleWatch.Text = "Pause Monitoring"
        $btnToggleWatch.ForeColor = $cText
        Add-Log "Background auto-watcher resumed."
    } else {
        $btnToggleWatch.Text = "Resume Monitoring"
        $btnToggleWatch.ForeColor = $cYellow
        Add-Log "Background auto-watcher PAUSED by user."
    }
})

$chkAutoSpan.add_CheckedChanged({
    $itemAuto.Checked = $chkAutoSpan.Checked
    Add-Log "Auto-Span on launch: $($chkAutoSpan.Checked)"
})

$btnMinimize.add_Click({
    $form.Hide()
    $trayIcon.ShowBalloonTip(2000, "Offhand Running in Tray",
        "Monitoring in background. Double-click tray icon to restore.", "Info")
})

$btnExit.add_Click({
    $timer.Stop(); $trayIcon.Visible = $false
    $form.Close(); [System.Windows.Forms.Application]::Exit()
})

$itemSpan.add_Click({ Invoke-SpanWindow -manual $true })

$itemExit.add_Click({
    $timer.Stop(); $trayIcon.Visible = $false
    $form.Close(); [System.Windows.Forms.Application]::Exit()
})

$form.add_FormClosing({
    param($sender, $e)
    if ($e.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) {
        $e.Cancel = $true
        $form.Hide()
        $trayIcon.ShowBalloonTip(1500, "Offhand Minimized",
            "Running in System Tray. Right-click or double-click to control.", "Info")
    }
})

# ==============================================================================
# LAUNCH
# ==============================================================================
Add-Log "Offhand Companion v1.2 initialized."
Add-Log "Monitoring active. Enable OFFHAND in WoW; calibrate with /OFFHAND wizard."
$timer.Start()
$hotkeyTimer.Start()

[System.Windows.Forms.Application]::Run($form)







