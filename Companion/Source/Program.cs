using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;

[assembly: AssemblyTitle("Offhand Companion")]
[assembly: AssemblyDescription("Dual-Monitor Multi-Display Controller for World of Warcraft")]
[assembly: AssemblyCompany("Offhand Project")]
[assembly: AssemblyProduct("Offhand")]
[assembly: AssemblyCopyright("Copyright (C) 2026 Offhand Project")]
[assembly: AssemblyVersion("2.0.0.0")]
[assembly: AssemblyFileVersion("2.0.0.0")]

namespace Offhand.Companion
{
    internal static class RestoreGeometry
    {
        // Coordinates may be negative on monitors left of/above the primary.
        internal static Rectangle Fit(Rectangle desired, Rectangle workArea)
        {
            int width = Math.Max(1, Math.Min(desired.Width, workArea.Width));
            int height = Math.Max(1, Math.Min(desired.Height, workArea.Height));
            return new Rectangle(
                Math.Max(workArea.Left, Math.Min(desired.Left, workArea.Right - width)),
                Math.Max(workArea.Top, Math.Min(desired.Top, workArea.Bottom - height)), width, height);
        }
    }

    internal static class MonitorSelection
    {
        internal static int[] Resolve(string saved, int count)
        {
            var selected = new List<int>();
            if (saved == null) { for (int i = 0; i < count; i++) selected.Add(i); }
            else foreach (string token in saved.Split(','))
            {
                int index;
                if (int.TryParse(token, out index) && index >= 0 && index < count && !selected.Contains(index)) selected.Add(index);
            }
            if (selected.Count == 0) throw new InvalidOperationException("Select at least one connected monitor before spanning.");
            return selected.ToArray();
        }
    }

    internal static class PreferenceFile
    {
        internal static Dictionary<string, string> Read(string path)
        {
            var settings = new Dictionary<string, string>();
            if (!File.Exists(path)) return settings;
            foreach (var line in File.ReadAllLines(path))
            {
                var parts = line.Split(new char[] { '=' }, 2);
                if (parts.Length == 2 && parts[0].Trim().Length > 0)
                    settings[parts[0].Trim()] = parts[1].Trim();
            }
            return settings;
        }

        internal static decimal Delay(string value)
        {
            decimal delay;
            return decimal.TryParse(value, out delay) ? Math.Max(0, Math.Min(60, delay)) : 15;
        }
    }

    public static class NativeMethods
    {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
            public int Width { get { return Right - Left; } }
            public int Height { get { return Bottom - Top; } }
        }

        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool IsZoomed(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool IsIconic(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll")]
        public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

        [DllImport("kernel32.dll")]
        public static extern void SetLastError(uint dwErrCode);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

        [DllImport("user32.dll")]
        public static extern int SetWindowRgn(IntPtr hWnd, IntPtr hRgn, bool bRedraw);

        [DllImport("gdi32.dll")]
        public static extern IntPtr CreateRectRgn(int nLeftRect, int nTopRect, int nRightRect, int nBottomRect);

        [DllImport("gdi32.dll")]
        public static extern int CombineRgn(IntPtr hrgnDest, IntPtr hrgnSrc1, IntPtr hrgnSrc2, int fnCombineMode);

        [DllImport("gdi32.dll")]
        public static extern bool DeleteObject(IntPtr hObject);

        [DllImport("user32.dll")]
        public static extern bool RegisterHotKey(IntPtr hWnd, int id, int fsModifiers, int vk);
        [DllImport("user32.dll")]
        public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
        [DllImport("user32.dll")]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        [DllImport("user32.dll")]
        public static extern int GetSystemMetrics(int nIndex);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr dpiContext);

        public const int GWL_STYLE = -16;
        public const int WS_CAPTION = 0x00C00000;
        public const int WS_THICKFRAME = 0x00040000;
        public const uint SWP_NOZORDER = 0x0004;
        public const uint SWP_NOACTIVATE = 0x0010;
        public const uint SWP_FRAMECHANGED = 0x0020;
        public const uint SWP_SHOWWINDOW = 0x0040;
        public const int SW_RESTORE = 9;

        public static IntPtr FindProcessWindow(int processId)
        {
            IntPtr found = IntPtr.Zero;
            EnumWindows(delegate (IntPtr h, IntPtr p)
            {
                uint id;
                GetWindowThreadProcessId(h, out id);
                if (id == processId && IsWindowVisible(h))
                {
                    found = h;
                    return false;
                }
                return true;
            }, IntPtr.Zero);
            return found;
        }
    }

    public class AddonStatus
    {
        public bool Installed;
        public string WowDir;
        public string Reason;
    }

    public class DesktopBounds
    {
        public int X, Y, Width, Height;
    }

    public class CompanionForm : Form
    {
        // Warcraft Dark Interface Palette (Black / Dark Grey / Burnished Gold)
        private readonly Color cBg = Color.FromArgb(12, 12, 14);                // Obsidian black canvas (#0c0c0e)
        private readonly Color cCard = Color.FromArgb(20, 20, 24);              // Dark forged iron card (#141418)
        private readonly Color cBorder = Color.FromArgb(145, 115, 55);          // Burnished gold outer border (#917337)
        private readonly Color cBorderDim = Color.FromArgb(65, 52, 28);         // Antique bronze divider (#41341c)
        private readonly Color cText = Color.FromArgb(235, 230, 215);           // Warm parchment white (#ebe6d7)
        private readonly Color cMuted = Color.FromArgb(155, 145, 130);          // Weathered silver-grey (#9b9182)
        private readonly Color cGold = Color.FromArgb(240, 184, 54);            // Iconic Warcraft Gold (#f0b836)
        private readonly Color cGoldBright = Color.FromArgb(255, 215, 80);      // Luminous gold highlight (#ffd750)
        private readonly Color cBrass = Color.FromArgb(185, 145, 60);           // Warm brass trim (#b9913c)
        private readonly Color cGreen = Color.FromArgb(72, 204, 120);           // Active emerald green (#48cc78)
        private readonly Color cRed = Color.FromArgb(220, 75, 75);              // Crimson warning / danger (#dc4b4b)
        private readonly Color cYellow = Color.FromArgb(240, 185, 55);          // Warning amber (#f0b937)
        private readonly Color cBtnBg = Color.FromArgb(28, 28, 34);             // Dark iron button (#1c1c22)
        private readonly Color cBtnPrimaryBg = Color.FromArgb(36, 30, 20);      // Dark bronze primary button (#241e14)
        private readonly Color cBtnDanger = Color.FromArgb(44, 16, 16);          // Dark ruby danger button (#2c1010)
        private readonly Color cLogBg = Color.FromArgb(8, 8, 10);               // Deepest obsidian log (#08080a)
        private readonly Color cLogText = Color.FromArgb(195, 190, 175);        // Parchment log text (#c3beaf)

        // UI Controls
        private Label lblWowStatus;
        private Label lblAddonStatus;
        private Label lblDisplayInfo;
        private Label lblAddonReason;
        private CheckBox chkAutoSpan;
                private NumericUpDown numDelaySpan;
        private Label lblDelay;
        private ComboBox cmbHotkey;
        private Label lblHotkey;
        private CheckedListBox clbMonitors;

        private static Dictionary<string, string> appSettings = new Dictionary<string, string>();
        private static readonly string configPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Offhand", "OffhandConfig.ini");
        private string configWarning;

        private void LoadConfig()
        {
            try
            {
                // Import portable settings once; future launches are independent of CWD.
                string source = File.Exists(configPath) ? configPath :
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "OffhandConfig.ini");
                appSettings = PreferenceFile.Read(source);
            }
            catch (IOException ex) { configWarning = "Cannot read settings: " + ex.Message; }
            catch (UnauthorizedAccessException ex) { configWarning = "Cannot read settings: " + ex.Message; }
        }

        private void SaveConfig()
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(configPath));
                var lines = new System.Collections.Generic.List<string>();
                foreach(var kv in appSettings) lines.Add(kv.Key + "=" + kv.Value);
                File.WriteAllLines(configPath, lines);
            }
            catch (IOException ex) { AddLog("Cannot save settings: " + ex.Message); }
            catch (UnauthorizedAccessException ex) { AddLog("Cannot save settings: " + ex.Message); }
        }

        private Button btnSpanNow;
        private Button btnToggleWatch;
        private ListBox logBox;
        private NotifyIcon trayIcon;
        private ToolStripMenuItem itemAuto;
        private Timer monitorTimer;

        // State
        private bool isMonitoring = true;
        private bool isExplicitExit = false;
        private readonly HashSet<int> spannedPids = new HashSet<int>();
        private readonly HashSet<int> restoredPids = new HashSet<int>();
        private sealed class WindowSnapshot
        {
            internal IntPtr Handle;
            internal Rectangle Bounds;
            internal int Style;
        }
        private readonly Dictionary<int, WindowSnapshot> originalWindows = new Dictionary<int, WindowSnapshot>();
        private readonly Dictionary<int, DateTime> retryAfter = new Dictionary<int, DateTime>();
        private readonly Dictionary<int, DateTime> launchTimes = new Dictionary<int, DateTime>();

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == 0x0312) { if (m.WParam.ToInt32() == 1) InvokeSpanWindow(true); else if (m.WParam.ToInt32() == 2) InvokeRestoreWindow(true); }
            base.WndProc(ref m);
        }

        private void UpdateHotkey()
        {
            NativeMethods.UnregisterHotKey(this.Handle, 1);
            int modifier = 0;
            int key = 0;
            string sel = cmbHotkey.SelectedItem as string;
            if (string.IsNullOrEmpty(sel)) sel = "Ctrl+Alt+S";
            
            if (sel == "Ctrl+Alt+S") { modifier = 0x0002 | 0x0001; key = (int)Keys.S; } // Alt is 1, Ctrl is 2
            else if (sel == "Ctrl+Shift+S") { modifier = 0x0002 | 0x0004; key = (int)Keys.S; } // Ctrl is 2, Shift is 4
            else if (sel == "Alt+S") { modifier = 0x0001; key = (int)Keys.S; }
            else if (sel == "F10") { modifier = 0; key = (int)Keys.F10; }
            else if (sel == "F11") { modifier = 0; key = (int)Keys.F11; }
            else if (sel == "F12") { modifier = 0; key = (int)Keys.F12; }
            
            if (NativeMethods.RegisterHotKey(this.Handle, 1, modifier | 0x4000, key))
                AddLog("Global Hotkey Registered: " + sel + " to Span Now.");
            else
                AddLog("Hotkey unavailable: " + sel + ". Choose another shortcut; Span Now still works.");
            NativeMethods.UnregisterHotKey(this.Handle, 2);
            if (NativeMethods.RegisterHotKey(this.Handle, 2, 0x0002 | 0x0001 | 0x4000, (int)Keys.R))
                AddLog("Ctrl+Alt+R hotkey registered to Restore window.");
            else
                AddLog("Ctrl+Alt+R unavailable. The Restore Window button still works.");
        }

        public CompanionForm()
        {
            LoadConfig();
            InitializeUI();
            InitializeTray();
            InitializeTimer();
            UpdateHotkey();
            if (configWarning != null) AddLog(configWarning);

            AddLog("Offhand Companion v2.0.0 initialized.");
            AddLog("Monitoring active. Enable Offhand in WoW; calibrate with /offhand wizard.");
            
            CheckForUpdates();
        }

        private void CheckForUpdates()
        {
            System.Threading.ThreadPool.QueueUserWorkItem(_ =>
            {
                try
                {
                    System.Net.ServicePointManager.SecurityProtocol = System.Net.SecurityProtocolType.Tls12;
                    using (System.Net.WebClient wc = new System.Net.WebClient())
                    {
                        wc.Headers.Add("User-Agent", "Offhand-Companion");
                        string json = wc.DownloadString("https://api.github.com/repos/N4UX-GIT/Offhand-DualMonitor/releases/latest");
                        
                        int idx = json.IndexOf("\"tag_name\":");
                        if (idx != -1)
                        {
                            int start = json.IndexOf("\"", idx + 11) + 1;
                            int end = json.IndexOf("\"", start);
                            string tag = json.Substring(start, end - start).TrimStart('v');
                            
                            string cleanTag = tag.Contains("-") ? tag.Substring(0, tag.IndexOf("-")) : tag;
                            Version latest = new Version(cleanTag + (cleanTag.Split('.').Length == 3 ? ".0" : ""));
                            Version current = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
                            
                            if (latest > current)
                            {
                                this.BeginInvoke(new Action(() => {
                                    AddLog("UPDATE AVAILABLE: A new version is out!");
                                    if (MessageBox.Show("A new version of Offhand is available!\n\nWould you like to download it now?", "Update Available", MessageBoxButtons.YesNo, MessageBoxIcon.Information) == DialogResult.Yes)
                                    {
                                        System.Diagnostics.Process.Start("https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/latest");
                                    }
                                }));
                            }
                        }
                    }
                }
                catch { }
            });
        }

        private void InitializeUI()
        {
            this.Text = "Offhand Companion";
            this.Size = new Size(524, 700);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.BackColor = cBg;
            this.ForeColor = cText;

            // Load Application Icon if available
            try
            {
                using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("Offhand.Companion.Resources.offhand-logo.ico"))
                {
                    if (stream != null) this.Icon = new Icon(stream);
                }
            }
            catch { }

            // Header Panel
            Panel headerPanel = new Panel();
            headerPanel.Location = new Point(0, 0);
            headerPanel.Size = new Size(524, 90);
            headerPanel.BackColor = Color.FromArgb(15, 15, 18);
            headerPanel.Paint += (s, e) =>
            {
                using (Pen pen = new Pen(cBorder, 2))
                {
                    e.Graphics.DrawLine(pen, 0, headerPanel.Height - 1, headerPanel.Width, headerPanel.Height - 1);
                }
            };
            this.Controls.Add(headerPanel);

            // Header Logo
            PictureBox logoBox = new PictureBox();
            logoBox.Location = new Point(10, 8);
            logoBox.Size = new Size(74, 74);
            logoBox.SizeMode = PictureBoxSizeMode.Zoom;
            logoBox.BackColor = Color.Transparent;

            try
            {
                using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("Offhand.Companion.Resources.offhand-logo.png"))
                {
                    if (stream != null)
                    {
                        logoBox.Image = Image.FromStream(stream);
                    }
                }
            }
            catch { }

            if (logoBox.Image == null)
            {
                // Fallback to disk asset if running unpackaged
                string[] diskFallbacks = new string[] {
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, @"..\Media\offhand-icon.png"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, @"..\Media\offhand-logo.png"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, @"Media\offhand-icon.png"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, @"Media\offhand-logo.png"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, @"..\Website\assets\offhand-icon.png")
                };
                foreach (string path in diskFallbacks)
                {
                    if (File.Exists(path))
                    {
                        try { logoBox.Image = Image.FromFile(path); break; } catch { }
                    }
                }
            }
            headerPanel.Controls.Add(logoBox);

            // Title
            Label titleLabel = new Label();
            titleLabel.Text = "OFFHAND";
            titleLabel.Location = new Point(96, 12);
            titleLabel.Size = new Size(400, 34);
            titleLabel.Font = new Font("Georgia", 22, FontStyle.Bold);
            titleLabel.ForeColor = cGold;
            titleLabel.BackColor = Color.Transparent;
            headerPanel.Controls.Add(titleLabel);

            // Subtitle
            Label subLabel = new Label();
            subLabel.Text = "Multi-Monitor Companion for World of Warcraft";
            subLabel.Location = new Point(98, 48);
            subLabel.Size = new Size(400, 18);
            subLabel.Font = new Font("Segoe UI", 8.5f);
            subLabel.ForeColor = cBrass;
            subLabel.BackColor = Color.Transparent;
            headerPanel.Controls.Add(subLabel);

            // Version
            Label verLabel = new Label();
            verLabel.Text = "v2.0.0";
            verLabel.Location = new Point(98, 66);
            verLabel.Size = new Size(100, 14);
            verLabel.Font = new Font("Segoe UI", 7.5f, FontStyle.Italic);
            verLabel.ForeColor = cMuted;
            verLabel.BackColor = Color.Transparent;
            headerPanel.Controls.Add(verLabel);

            // Status Card
            Panel statusPanel = CreateCardPanel(16, 102, 490, 118, "System Status");
            this.Controls.Add(statusPanel);

            lblWowStatus = new Label
            {
                Text = "  WoW Process: Checking...",
                Location = new Point(0, 30),
                Size = new Size(490, 20),
                Font = new Font("Segoe UI", 9, FontStyle.Bold),
                ForeColor = cMuted
            };
            statusPanel.Controls.Add(lblWowStatus);

            lblAddonStatus = new Label
            {
                Text = "  Offhand Addon: Checking...",
                Location = new Point(0, 54),
                Size = new Size(490, 20),
                Font = new Font("Segoe UI", 9, FontStyle.Bold),
                ForeColor = cMuted
            };
            statusPanel.Controls.Add(lblAddonStatus);

            lblDisplayInfo = new Label
            {
                Text = "  Virtual Desktop: Checking...",
                Location = new Point(0, 78),
                Size = new Size(490, 18),
                Font = new Font("Segoe UI", 8.5f),
                ForeColor = cMuted
            };
            statusPanel.Controls.Add(lblDisplayInfo);

            lblAddonReason = new Label
            {
                Text = "",
                Location = new Point(0, 98),
                Size = new Size(490, 16),
                Font = new Font("Segoe UI", 7.5f, FontStyle.Italic),
                ForeColor = cYellow
            };
            statusPanel.Controls.Add(lblAddonReason);

            // Configuration Card
            Panel configPanel = CreateCardPanel(16, 230, 490, 126, "Configuration");
            this.Controls.Add(configPanel);

            chkAutoSpan = new CheckBox
            {
                Text = "Automatically span WoW window on game launch",
                Location = new Point(10, 28),
                Size = new Size(460, 22),
                Font = new Font("Segoe UI", 9),
                ForeColor = cText,
                BackColor = Color.Transparent,
                Checked = true
            };
            chkAutoSpan.CheckedChanged += (s, e) =>
            {
                if (itemAuto != null) itemAuto.Checked = chkAutoSpan.Checked;
                AddLog("Auto-Span on launch: " + chkAutoSpan.Checked);
            };
            configPanel.Controls.Add(chkAutoSpan);

            lblDelay = new Label { Text = "Delay Span (Seconds):", Location = new Point(10, 56), Size = new Size(130, 22), ForeColor = cText, BackColor = Color.Transparent };
            configPanel.Controls.Add(lblDelay);
            numDelaySpan = new NumericUpDown { Location = new Point(140, 54), Size = new Size(60, 22), Minimum = 0, Maximum = 60, Value = 15, BackColor = cCard, ForeColor = cText };
                        configPanel.Controls.Add(numDelaySpan);

            lblHotkey = new Label { Text = "Global Hotkey:", Location = new Point(10, 84), Size = new Size(130, 22), ForeColor = cText, BackColor = Color.Transparent };
            configPanel.Controls.Add(lblHotkey);
            cmbHotkey = new ComboBox { Location = new Point(140, 82), Size = new Size(160, 22), DropDownStyle = ComboBoxStyle.DropDownList, BackColor = cCard, ForeColor = cText };
            cmbHotkey.Items.AddRange(new object[] { "Ctrl+Alt+S", "Ctrl+Shift+S", "Alt+S", "F10", "F11", "F12" });
            cmbHotkey.SelectedIndex = 0;
            if (appSettings.ContainsKey("Hotkey") && cmbHotkey.Items.Contains(appSettings["Hotkey"])) cmbHotkey.SelectedItem = appSettings["Hotkey"];
            
            cmbHotkey.SelectedIndexChanged += (s, e) => { 
                appSettings["Hotkey"] = cmbHotkey.SelectedItem.ToString(); 
                SaveConfig(); 
                UpdateHotkey();
            };
            configPanel.Controls.Add(cmbHotkey);

            Label lblMonitors = new Label { Text = "Span Monitors:", Location = new Point(310, 26), Size = new Size(130, 22), ForeColor = cText, BackColor = Color.Transparent };
            configPanel.Controls.Add(lblMonitors);
            clbMonitors = new CheckedListBox { Location = new Point(310, 54), Size = new Size(160, 60), BackColor = cCard, ForeColor = cText, BorderStyle = BorderStyle.None };
            clbMonitors.CheckOnClick = true;
            for (int i = 0; i < Screen.AllScreens.Length; i++)
            {
                clbMonitors.Items.Add("Display " + (i + 1), true);
            }
            clbMonitors.ItemCheck += (s, e) => {
                if (!this.IsHandleCreated) return;
                this.BeginInvoke(new Action(() => {
                    List<string> selected = new List<string>();
                    for (int i = 0; i < clbMonitors.Items.Count; i++) if (clbMonitors.GetItemChecked(i)) selected.Add(i.ToString());
                    appSettings["Monitors"] = string.Join(",", selected.ToArray());
                    SaveConfig();
                }));
            };
            configPanel.Controls.Add(clbMonitors);

            if (appSettings.ContainsKey("Monitors"))
            {
                string[] saved = appSettings["Monitors"].Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
                for (int i = 0; i < clbMonitors.Items.Count; i++) clbMonitors.SetItemChecked(i, false);
                foreach (string m in saved) { int idx; if (int.TryParse(m, out idx) && idx >= 0 && idx < clbMonitors.Items.Count) clbMonitors.SetItemChecked(idx, true); }
            }

            if (appSettings.ContainsKey("AutoSpan")) chkAutoSpan.Checked = appSettings["AutoSpan"] == "True";
            if (appSettings.ContainsKey("DelaySpan")) numDelaySpan.Value = PreferenceFile.Delay(appSettings["DelaySpan"]);

            chkAutoSpan.CheckedChanged += (s, e) => { appSettings["AutoSpan"] = chkAutoSpan.Checked.ToString(); SaveConfig(); };
            numDelaySpan.ValueChanged += (s, e) => { appSettings["DelaySpan"] = numDelaySpan.Value.ToString(); SaveConfig(); };
            numDelaySpan.KeyUp += (s, e) => { appSettings["DelaySpan"] = numDelaySpan.Value.ToString(); SaveConfig(); if (e.KeyCode == Keys.Enter) { e.Handled = true; this.ActiveControl = null; } };


            // Action Buttons
                        btnSpanNow = CreateButton("Span WoW Now", 16, 368, 158, 36, cBtnPrimaryBg, cGoldBright, cGold);
            btnSpanNow.Click += (s, e) => { InvokeSpanWindow(true); };
            this.Controls.Add(btnSpanNow);

            Button btnRestoreNow = CreateButton("Restore Window", 182, 368, 158, 36, cBtnBg, cText, cBorder);
            btnRestoreNow.Click += (s, e) => { InvokeRestoreWindow(true); };
            this.Controls.Add(btnRestoreNow);

            btnToggleWatch = CreateButton("Pause Monitor", 348, 368, 158, 36, cBtnBg, cText, cBorder);
            btnToggleWatch.Click += (s, e) =>
            {
                isMonitoring = !isMonitoring;
                if (isMonitoring)
                {
                    btnToggleWatch.Text = "Pause Monitor";
                    btnToggleWatch.ForeColor = cText;
                    AddLog("Background auto-watcher resumed.");
                }
                else
                {
                    btnToggleWatch.Text = "Resume Monitor";
                    btnToggleWatch.ForeColor = cYellow;
                    AddLog("Background auto-watcher PAUSED by user.");
                }
            };
            this.Controls.Add(btnToggleWatch);

            // Activity Log Card
            Panel logPanel = CreateCardPanel(16, 416, 490, 200, "Activity Log");
            this.Controls.Add(logPanel);

            logBox = new ListBox
            {
                Location = new Point(4, 28),
                Size = new Size(482, 166),
                BackColor = cLogBg,
                ForeColor = cLogText,
                BorderStyle = BorderStyle.None,
                Font = new Font("Consolas", 8.5f)
            };
            logPanel.Controls.Add(logBox);

            // Footer Buttons
            Button btnMinimize = CreateButton("Minimize to Tray", 16, 628, 152, 30, cBtnBg, cMuted, cBorderDim);
            btnMinimize.Click += (s, e) =>
            {
                this.Hide();
                trayIcon.ShowBalloonTip(2000, "Offhand Running in Tray", "Monitoring in background. Double-click tray icon to restore.", ToolTipIcon.Info);
            };
            this.Controls.Add(btnMinimize);

            Button btnExit = CreateButton("Exit Companion", 356, 628, 152, 30, cBtnDanger, Color.FromArgb(235, 130, 130), Color.FromArgb(140, 45, 45));
            btnExit.Click += (s, e) => { ExitApplication(); };
            this.Controls.Add(btnExit);

            this.FormClosing += (s, e) =>
            {
                if (!isExplicitExit && e.CloseReason == CloseReason.UserClosing)
                {
                    e.Cancel = true;
                    this.Hide();
                    trayIcon.ShowBalloonTip(1500, "Offhand Minimized", "Running in System Tray. Right-click or double-click to control.", ToolTipIcon.Info);
                }
            };
        }

        private Panel CreateCardPanel(int x, int y, int w, int h, string title)
        {
            Panel panel = new Panel
            {
                Location = new Point(x, y),
                Size = new Size(w, h),
                BackColor = cCard
            };

            Label lblTitle = new Label
            {
                Text = "  " + title.ToUpper(),
                Location = new Point(0, 4),
                Size = new Size(w, 20),
                Font = new Font("Segoe UI", 8.5f, FontStyle.Bold),
                ForeColor = cGold
            };
            panel.Controls.Add(lblTitle);

            panel.Paint += (s, e) =>
            {
                using (Pen pen = new Pen(cBorder, 1))
                {
                    e.Graphics.DrawRectangle(pen, 0, 0, panel.ClientSize.Width - 1, panel.ClientSize.Height - 1);
                }
                using (Pen penDim = new Pen(cBorderDim, 1))
                {
                    e.Graphics.DrawLine(penDim, 1, 24, panel.ClientSize.Width - 2, 24);
                }
            };

            return panel;
        }

        private Button CreateButton(string text, int x, int y, int w, int h, Color bg, Color fg, Color border)
        {
            Button btn = new Button
            {
                Text = text,
                Location = new Point(x, y),
                Size = new Size(w, h),
                FlatStyle = FlatStyle.Flat,
                BackColor = bg,
                ForeColor = fg,
                Font = new Font("Georgia", 9, FontStyle.Bold),
                Cursor = Cursors.Hand
            };
            btn.FlatAppearance.BorderSize = 1;
            btn.FlatAppearance.BorderColor = border;
            return btn;
        }

        private void InitializeTray()
        {
            trayIcon = new NotifyIcon
            {
                Text = "Offhand Companion",
                Visible = true
            };

            // Programmatic icon or loaded icon
            if (this.Icon != null)
            {
                trayIcon.Icon = this.Icon;
            }
            else
            {
                using (Bitmap bmp = new Bitmap(16, 16))
                using (Graphics g = Graphics.FromImage(bmp))
                using (SolidBrush brush = new SolidBrush(Color.FromArgb(90, 184, 255)))
                using (Font font = new Font("Georgia", 9, FontStyle.Bold))
                {
                    g.Clear(Color.FromArgb(8, 10, 18));
                    g.DrawString("A", font, brush, 1, 0);
                    trayIcon.Icon = Icon.FromHandle(bmp.GetHicon());
                }
            }

            ContextMenuStrip trayMenu = new ContextMenuStrip
            {
                BackColor = cCard,
                ForeColor = cText
            };

            ToolStripMenuItem itemOpen = new ToolStripMenuItem("Open Dashboard");
            itemOpen.Click += (s, e) => { RestoreForm(); };
            trayMenu.Items.Add(itemOpen);

            trayMenu.Items.Add(new ToolStripSeparator());

            ToolStripMenuItem itemSpan = new ToolStripMenuItem("Span WoW Now");
            itemSpan.Click += (s, e) => { InvokeSpanWindow(true); };
            trayMenu.Items.Add(itemSpan);

            itemAuto = new ToolStripMenuItem("Auto-Span Enabled")
            {
                Checked = chkAutoSpan.Checked
            };
            itemAuto.Click += (s, e) =>
            {
                chkAutoSpan.Checked = !chkAutoSpan.Checked;
                itemAuto.Checked = chkAutoSpan.Checked;
            };
            trayMenu.Items.Add(itemAuto);

            trayMenu.Items.Add(new ToolStripSeparator());

            ToolStripMenuItem itemExit = new ToolStripMenuItem("Exit");
            itemExit.Click += (s, e) => { ExitApplication(); };
            trayMenu.Items.Add(itemExit);

            trayIcon.ContextMenuStrip = trayMenu;
            trayIcon.DoubleClick += (s, e) => { RestoreForm(); };
        }

        private void RestoreForm()
        {
            this.Show();
            this.WindowState = FormWindowState.Normal;
            this.Activate();
        }

        private void ExitApplication()
        {
            NativeMethods.UnregisterHotKey(this.Handle, 1);
            NativeMethods.UnregisterHotKey(this.Handle, 2);
            isExplicitExit = true;
            if (monitorTimer != null) monitorTimer.Stop();
            if (trayIcon != null) trayIcon.Visible = false;
            this.Close();
            Application.Exit();
        }

        private void AddLog(string message)
        {
            if (logBox == null) { configWarning = message; return; }
            string time = DateTime.Now.ToString("HH:mm:ss");
            logBox.Items.Insert(0, string.Format("[{0}] {1}", time, message));
            while (logBox.Items.Count > 100)
            {
                logBox.Items.RemoveAt(logBox.Items.Count - 1);
            }
        }

        private void InitializeTimer()
        {
            monitorTimer = new Timer
            {
                Interval = 2000
            };
            monitorTimer.Tick += (s, e) => { OnTimerTick(); };
            monitorTimer.Start();
        }

        private void OnTimerTick()
        {
            try
            {
                DesktopBounds vs = GetDesktopBounds();
                lblDisplayInfo.Text = string.Format("  Virtual Desktop: {0} x {1} px  (Offset X:{2}, Y:{3})", vs.Width, vs.Height, vs.X, vs.Y);
            }
            catch
            {
                lblDisplayInfo.Text = "  Virtual Desktop: physical coordinates unavailable";
            }

            Process proc = GetWoWProcess();

            if (proc != null)
            {
                lblWowStatus.Text = string.Format("  * WoW Running  ({0}  PID: {1})", proc.ProcessName, proc.Id);
                lblWowStatus.ForeColor = cGreen;

                AddonStatus status = TestOffhandAddonStatus(proc);
                if (status.Installed)
                {
                    lblAddonStatus.Text = "  * Offhand Addon: INSTALLED";
                    lblAddonStatus.ForeColor = cGreen;
                    lblAddonReason.Text = "  Confirm Offhand is enabled in the current WoW session.";
                }
                else
                {
                    lblAddonStatus.Text = "  o Offhand Addon: NOT VERIFIED";
                    lblAddonStatus.ForeColor = cRed;
                    lblAddonReason.Text = "  " + status.Reason;
                }

                if (isMonitoring && chkAutoSpan.Checked && status.Installed)
                {
                    if (!spannedPids.Contains(proc.Id) && !restoredPids.Contains(proc.Id) &&
                        (!retryAfter.ContainsKey(proc.Id) || DateTime.Now >= retryAfter[proc.Id]))
                    {
                        if (!launchTimes.ContainsKey(proc.Id)) launchTimes[proc.Id] = DateTime.Now;
                        if ((DateTime.Now - launchTimes[proc.Id]).TotalSeconds < (double)numDelaySpan.Value) { retryAfter[proc.Id] = DateTime.Now.AddSeconds(1); return; }
                        AddLog(string.Format("New WoW launch detected (PID: {0}). Preparing auto-span...", proc.Id));
                        retryAfter[proc.Id] = DateTime.Now.AddSeconds(10);
                        if (InvokeSpanWindow(false))
                        {
                            spannedPids.Add(proc.Id);
                        }
                    }
                }
            }
            else
            {
                lblWowStatus.Text = "  o WoW Process: Not running";
                lblWowStatus.ForeColor = cMuted;
                lblAddonStatus.Text = "  o Offhand Addon: Waiting for WoW...";
                lblAddonStatus.ForeColor = cMuted;
                lblAddonReason.Text = "";
            }

            // Clean dead PIDs
            var pidsToCheck = new HashSet<int>(spannedPids);
            pidsToCheck.UnionWith(restoredPids);
            pidsToCheck.UnionWith(launchTimes.Keys);
            foreach (int pid in pidsToCheck)
            {
                try
                {
                    Process.GetProcessById(pid);
                }
                catch
                {
                    spannedPids.Remove(pid);
                    restoredPids.Remove(pid);
                    originalWindows.Remove(pid);
                    launchTimes.Remove(pid);
                    retryAfter.Remove(pid);
                    AddLog(string.Format("WoW process (PID: {0}) closed.", pid));
                }
            }
        }

        private Process GetWoWProcess()
        {
            List<Process> candidates = new List<Process>();
            string[] names = new string[] { "WowClassic", "Wow", "WowClassicEra", "WowForever", "WowT", "WowB", "WowClassicT", "WowClassicB" };
            foreach (string name in names)
            {
                candidates.AddRange(Process.GetProcessesByName(name));
            }
            // Remove background/zombie processes that don't have a UI window
            candidates.RemoveAll(p => p.MainWindowHandle == IntPtr.Zero);
            
            if (candidates.Count > 0)
            {
                return candidates[0];
            }
            return null;
        }

        private AddonStatus TestOffhandAddonStatus(Process proc)
        {
            AddonStatus result = new AddonStatus { Installed = false, Reason = "Launch exactly one WoW client." };
            if (proc == null) return result;

            try
            {
                string mainModule = proc.MainModule.FileName;
                result.WowDir = Path.GetDirectoryName(mainModule);
                if (string.IsNullOrEmpty(result.WowDir))
                {
                    result.Reason = "Client path unavailable.";
                    return result;
                }

                string addonDir = Path.Combine(result.WowDir, @"Interface\AddOns\Offhand");
                string[] manifests = new string[] { "Offhand.toc", "Offhand_Vanilla.toc" };
                
                bool exists = false;
                if (Directory.Exists(addonDir))
                {
                    foreach (string m in manifests)
                    {
                        if (File.Exists(Path.Combine(addonDir, m))) { exists = true; break; }
                    }
                }

                if (exists)
                {
                    result.Installed = true;
                    result.Reason = "Installed; confirm enabled in WoW. Live addon state is unavailable.";
                }
                else
                {
                    result.Reason = "Install Offhand in this client's Interface\\AddOns folder.";
                }
            }
            catch
            {
                result.Reason = "Cannot verify the addon installation for this client.";
            }

            return result;
        }

        private IntPtr GetWoWWindowHandle(Process proc)
        {
            if (proc == null) return IntPtr.Zero;
            proc.Refresh();
            IntPtr handle = proc.MainWindowHandle;
            if (handle == IntPtr.Zero)
            {
                handle = NativeMethods.FindProcessWindow(proc.Id);
            }
            uint ownerPid;
            NativeMethods.GetWindowThreadProcessId(handle, out ownerPid);
            if (ownerPid != proc.Id) return IntPtr.Zero;
            return handle;
        }

        private DesktopBounds GetDesktopBounds()
        {
            IntPtr prevDpi = NativeMethods.SetThreadDpiAwarenessContext((IntPtr)(-4));
            try
            {
                var screens = Screen.AllScreens;
                string saved;
                appSettings.TryGetValue("Monitors", out saved);
                var selected = MonitorSelection.Resolve(saved, screens.Length);
                Rectangle bounds = screens[selected[0]].Bounds;
                foreach (int index in selected) bounds = Rectangle.Union(bounds, screens[index].Bounds);
                return new DesktopBounds { X = bounds.X, Y = bounds.Y, Width = bounds.Width, Height = bounds.Height };
            }
            finally
            {
                if (prevDpi != IntPtr.Zero)
                {
                    NativeMethods.SetThreadDpiAwarenessContext(prevDpi);
                }
            }
        }

        private bool InvokeRestoreWindow(bool manual)
        {
            try
            {
                Process proc = GetWoWProcess();
                if (proc == null) throw new Exception("Launch exactly one WoW client first.");
                IntPtr handle = GetWoWWindowHandle(proc);
                if (handle == IntPtr.Zero) throw new Exception("WoW window is not ready.");

                if (NativeMethods.IsZoomed(handle) || NativeMethods.IsIconic(handle))
                {
                    NativeMethods.ShowWindow(handle, NativeMethods.SW_RESTORE);
                }

                int oldStyle = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE);
                NativeMethods.RECT oldRect;
                if (!NativeMethods.GetWindowRect(handle, out oldRect)) throw new Exception("Could not read WoW window bounds.");
                WindowSnapshot snapshot;
                bool known = originalWindows.TryGetValue(proc.Id, out snapshot) && snapshot.Handle == handle;
                int newStyle = (known ? snapshot.Style : oldStyle) | NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME;
                Rectangle desired = known ? snapshot.Bounds : new Rectangle(Screen.PrimaryScreen.WorkingArea.Location, new Size(1920, 1080));
                Rectangle target = RestoreGeometry.Fit(desired, Screen.FromRectangle(desired).WorkingArea);
                
                NativeMethods.SetLastError(0);
                int previousStyle = NativeMethods.SetWindowLong(handle, NativeMethods.GWL_STYLE, newStyle);
                if (previousStyle == 0 && Marshal.GetLastWin32Error() != 0)
                    throw new Exception("Windows rejected restoring the window borders.");
                
                uint flags = NativeMethods.SWP_NOZORDER | NativeMethods.SWP_NOACTIVATE | NativeMethods.SWP_FRAMECHANGED | NativeMethods.SWP_SHOWWINDOW;
                try
                {
                    NativeMethods.SetWindowRgn(handle, IntPtr.Zero, true);
                    if (!NativeMethods.SetWindowPos(handle, IntPtr.Zero, target.X, target.Y, target.Width, target.Height, flags))
                        throw new Exception("Windows rejected restoring the window bounds.");
                    NativeMethods.RECT actual;
                    if (!NativeMethods.GetWindowRect(handle, out actual) || actual.Left != target.X || actual.Top != target.Y || actual.Width != target.Width || actual.Height != target.Height)
                        throw new Exception("WoW did not accept the restore. Select Windowed mode and retry.");
                }
                catch
                {
                    NativeMethods.SetWindowRgn(handle, IntPtr.Zero, true);
                    NativeMethods.SetWindowLong(handle, NativeMethods.GWL_STYLE, oldStyle);
                    NativeMethods.SetWindowPos(handle, IntPtr.Zero, oldRect.Left, oldRect.Top, oldRect.Width, oldRect.Height, flags);
                    throw;
                }
                
                spannedPids.Remove(proc.Id);
                restoredPids.Add(proc.Id);
                AddLog("Restored WoW window. Auto-span paused for this client until Span Now or a new WoW launch.");
                return true;
            }
            catch (Exception ex)
            {
                AddLog(ex.Message);
                if (manual) MessageBox.Show(ex.Message, "Offhand", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return false;
            }
        }

        private bool InvokeSpanWindow(bool manual)
        {
            try
            {
                Process proc = GetWoWProcess();
                if (proc == null) throw new Exception("Launch exactly one WoW client first.");

                AddonStatus status = TestOffhandAddonStatus(proc);
                if (!status.Installed) throw new Exception(status.Reason);

                IntPtr handle = GetWoWWindowHandle(proc);
                if (handle == IntPtr.Zero) throw new Exception("WoW window is not ready. Retry after it opens.");

                DesktopBounds bounds = GetDesktopBounds();
                if (bounds.Width <= 0 || bounds.Height <= 0) throw new Exception("Invalid virtual desktop dimensions.");

                if (NativeMethods.IsZoomed(handle) || NativeMethods.IsIconic(handle))
                {
                    NativeMethods.ShowWindow(handle, NativeMethods.SW_RESTORE);
                }

                NativeMethods.RECT oldRect;
                if (!NativeMethods.GetWindowRect(handle, out oldRect)) throw new Exception("Could not read WoW window bounds.");

                int oldStyle = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE);
                int newStyle = oldStyle & ~(NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME);
                if (newStyle != oldStyle)
                {
                    NativeMethods.SetLastError(0);
                    int res = NativeMethods.SetWindowLong(handle, NativeMethods.GWL_STYLE, newStyle);
                    if (res == 0 && Marshal.GetLastWin32Error() != 0)
                    {
                        throw new Exception("Could not remove WoW window borders.");
                    }
                }

                try
                {
                    IntPtr combinedRgn = IntPtr.Zero;
                    IntPtr previousDpi = NativeMethods.SetThreadDpiAwarenessContext((IntPtr)(-4));
                    try
                    {
                        string saved;
                        appSettings.TryGetValue("Monitors", out saved);
                        var screens = Screen.AllScreens;
                        foreach (int index in MonitorSelection.Resolve(saved, screens.Length))
                        {
                            Rectangle b = screens[index].Bounds;
                            IntPtr rgn = NativeMethods.CreateRectRgn(b.Left - bounds.X, b.Top - bounds.Y, b.Right - bounds.X, b.Bottom - bounds.Y);
                            if (rgn == IntPtr.Zero) throw new Exception("Could not create monitor clipping region.");
                            if (combinedRgn == IntPtr.Zero) combinedRgn = rgn;
                            else
                            {
                                try { if (NativeMethods.CombineRgn(combinedRgn, combinedRgn, rgn, 2) == 0) throw new Exception("Could not combine monitor regions."); }
                                finally { NativeMethods.DeleteObject(rgn); }
                            }
                        }
                        if (NativeMethods.SetWindowRgn(handle, combinedRgn, true) == 0) throw new Exception("Could not apply monitor clipping region.");
                        combinedRgn = IntPtr.Zero; // Windows owns the region after success.
                    }
                    finally
                    {
                        if (combinedRgn != IntPtr.Zero) NativeMethods.DeleteObject(combinedRgn);
                        if (previousDpi != IntPtr.Zero) NativeMethods.SetThreadDpiAwarenessContext(previousDpi);
                    }

                    uint flags = NativeMethods.SWP_NOZORDER | NativeMethods.SWP_NOACTIVATE | NativeMethods.SWP_FRAMECHANGED | NativeMethods.SWP_SHOWWINDOW;
                    if (!NativeMethods.SetWindowPos(handle, IntPtr.Zero, bounds.X, bounds.Y, bounds.Width, bounds.Height, flags))
                    {
                        throw new Exception("Windows rejected the requested span.");
                    }

                    NativeMethods.RECT actual;
                    if (!NativeMethods.GetWindowRect(handle, out actual) ||
                        actual.Left != bounds.X || actual.Top != bounds.Y ||
                        actual.Width != bounds.Width || actual.Height != bounds.Height)
                    {
                        throw new Exception("WoW did not accept the requested bounds. Select Windowed mode and retry.");
                    }
                }
                catch
                {
                    NativeMethods.SetWindowRgn(handle, IntPtr.Zero, true);
                    NativeMethods.SetWindowLong(handle, NativeMethods.GWL_STYLE, oldStyle);
                    NativeMethods.SetWindowPos(handle, IntPtr.Zero, oldRect.Left, oldRect.Top, oldRect.Width, oldRect.Height, 0x0074);
                    throw;
                }

                WindowSnapshot original;
                if (!originalWindows.TryGetValue(proc.Id, out original) || original.Handle != handle)
                    originalWindows[proc.Id] = new WindowSnapshot { Handle = handle, Style = oldStyle,
                        Bounds = new Rectangle(oldRect.Left, oldRect.Top, oldRect.Width, oldRect.Height) };
                restoredPids.Remove(proc.Id);
                spannedPids.Add(proc.Id);
                AddLog(string.Format("Spanned {0}x{1}. Calibrate with /offhand wizard.", bounds.Width, bounds.Height));
                trayIcon.ShowBalloonTip(3000, "Offhand Spanned", "Window spanned. Use /offhand wizard to calibrate.", ToolTipIcon.Info);
                return true;
            }
            catch (Exception ex)
            {
                AddLog(ex.Message);
                if (manual)
                {
                    MessageBox.Show(ex.Message, "Offhand", MessageBoxButtons.OK, MessageBoxIcon.Information);
                }
                return false;
            }
        }

        [STAThread]
        public static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new CompanionForm());
        }
    }
}











