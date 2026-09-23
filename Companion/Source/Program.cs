using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Windows.Forms;

[assembly: AssemblyTitle("Offhand Companion")]
[assembly: AssemblyDescription("Dual-Monitor Multi-Display Controller for World of Warcraft")]
[assembly: AssemblyCompany("Offhand Project")]
[assembly: AssemblyProduct("Offhand")]
[assembly: AssemblyCopyright("Copyright (C) 2026 Offhand Project")]
[assembly: AssemblyVersion("2.1.2.0")]
[assembly: AssemblyFileVersion("2.1.2.0")]

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
        internal sealed class Display
        {
            internal int Index;
            internal string DeviceName;
            internal Rectangle Bounds;
            internal Rectangle WorkArea;
            internal bool Primary;
        }

        internal sealed class Plan
        {
            internal int[] Indices;
            internal int MainhandIndex;
            internal int WorkspaceIndex;
            internal bool SplitSingle;
            internal bool GameOnLeft;
            internal Rectangle Bounds;
            internal Rectangle MainhandBounds;
            internal Rectangle WorkspaceBounds;
        }

        private static string[] Tokens(string value, char separator)
        {
            return string.IsNullOrWhiteSpace(value)
                ? new string[0]
                : value.Split(new char[] { separator }, StringSplitOptions.RemoveEmptyEntries);
        }

        internal static bool HasDisconnectedSavedDisplay(string savedDevices, IList<Display> displays)
        {
            if (string.IsNullOrWhiteSpace(savedDevices)) return false;
            foreach (string requested in Tokens(savedDevices, '|'))
            {
                bool found = false;
                foreach (Display display in displays)
                    if (string.Equals(display.DeviceName, requested, StringComparison.OrdinalIgnoreCase))
                    { found = true; break; }
                if (!found) return true;
            }
            return false;
        }

        internal static Display RecoveryDisplay(string mainhandDevice, IList<Display> displays)
        {
            if (displays == null || displays.Count == 0) return null;
            if (!string.IsNullOrWhiteSpace(mainhandDevice))
                foreach (Display display in displays)
                    if (string.Equals(display.DeviceName, mainhandDevice, StringComparison.OrdinalIgnoreCase))
                        return display;
            foreach (Display display in displays) if (display.Primary) return display;
            return displays[0];
        }

        internal static bool SameDisplays(IList<Display> left, IList<Display> right)
        {
            if (ReferenceEquals(left, right)) return true;
            if (left == null || right == null || left.Count != right.Count) return false;
            for (int i = 0; i < left.Count; i++)
            {
                if (!string.Equals(left[i].DeviceName, right[i].DeviceName, StringComparison.OrdinalIgnoreCase)
                    || left[i].Bounds != right[i].Bounds
                    || left[i].WorkArea != right[i].WorkArea
                    || left[i].Primary != right[i].Primary)
                    return false;
            }
            return true;
        }

        internal static Plan CreatePlan(string savedDevices, string legacySaved, string mainhandDevice,
            bool splitSingle, bool gameOnLeft, IList<Display> displays)
        {
            if (displays == null || displays.Count == 0)
                throw new InvalidOperationException("Windows reports no connected displays.");

            var selected = new List<int>();
            string[] devices = Tokens(savedDevices, '|');
            if (savedDevices != null)
            {
                foreach (string requested in devices)
                {
                    int match = -1;
                    for (int i = 0; i < displays.Count; i++)
                    {
                        if (string.Equals(displays[i].DeviceName, requested, StringComparison.OrdinalIgnoreCase))
                        {
                            match = i;
                            break;
                        }
                    }
                    if (match < 0)
                        throw new InvalidOperationException("A saved display is disconnected (" + requested + "). Restore the WoW window or reconnect it; Offhand will not collapse the span onto the remaining screen.");
                    if (!selected.Contains(match)) selected.Add(match);
                }
            }
            else if (legacySaved != null)
            {
                foreach (string token in Tokens(legacySaved, ','))
                {
                    int index;
                    if (!int.TryParse(token, out index) || index < 0 || index >= displays.Count)
                        throw new InvalidOperationException("A previously selected display is disconnected. Review the display selection before spanning.");
                    if (!selected.Contains(index)) selected.Add(index);
                }
            }
            else
            {
                for (int i = 0; i < displays.Count; i++) selected.Add(i);
            }

            if (selected.Count == 0)
                throw new InvalidOperationException("Select displays before spanning.");
            if (selected.Count == 1 && !splitSingle)
                throw new InvalidOperationException("Select exactly two displays, or enable Single-display 32:9 split for one super-ultrawide monitor.");
            if (selected.Count > 2)
                throw new InvalidOperationException("Offhand currently supports exactly two displays, or one super-ultrawide in split mode. Select only the Mainhand and Offhand displays.");

            int mainhand = -1;
            if (!string.IsNullOrWhiteSpace(mainhandDevice))
            {
                foreach (int index in selected)
                    if (string.Equals(displays[index].DeviceName, mainhandDevice, StringComparison.OrdinalIgnoreCase)) mainhand = index;
                if (mainhand < 0)
                    throw new InvalidOperationException("The saved Mainhand display is unavailable. Select the connected game-view display before spanning.");
            }
            if (mainhand < 0)
            {
                foreach (int index in selected) if (displays[index].Primary) { mainhand = index; break; }
                if (mainhand < 0) mainhand = selected[selected.Count - 1];
            }

            Rectangle union = displays[selected[0]].Bounds;
            foreach (int index in selected) union = Rectangle.Union(union, displays[index].Bounds);
            Rectangle game = displays[mainhand].Bounds;
            int workspaceIndex = selected.Count == 2 ? selected[0] == mainhand ? selected[1] : selected[0] : mainhand;
            Rectangle workspace = displays[workspaceIndex].Bounds;
            if (selected.Count == 1)
            {
                int workspaceWidth = workspace.Width / 2;
                int gameWidth = workspace.Width - workspaceWidth;
                if (gameOnLeft)
                {
                    game = new Rectangle(workspace.Left, workspace.Top, gameWidth, workspace.Height);
                    workspace = new Rectangle(game.Right, workspace.Top, workspaceWidth, workspace.Height);
                }
                else
                {
                    workspace = new Rectangle(workspace.Left, workspace.Top, workspaceWidth, workspace.Height);
                    game = new Rectangle(workspace.Right, workspace.Top, gameWidth, workspace.Height);
                }
            }

            return new Plan { Indices = selected.ToArray(), MainhandIndex = mainhand,
                WorkspaceIndex = workspaceIndex, SplitSingle = selected.Count == 1,
                GameOnLeft = gameOnLeft, Bounds = union, MainhandBounds = game,
                WorkspaceBounds = workspace };
        }
    }

    internal static class CompanionTopologyBridge
    {
        private static string LuaString(string value)
        {
            return "\"" + (value ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
        }

        private static string RectLua(Rectangle rect, Rectangle union)
        {
            int left = rect.Left - union.Left;
            int bottom = union.Bottom - rect.Bottom;
            return string.Format("{{ x = {0}, y = {1}, width = {2}, height = {3} }}", left, bottom, rect.Width, rect.Height);
        }

        internal static bool TryWrite(string wowDir, MonitorSelection.Plan plan,
            IList<MonitorSelection.Display> displays, out string message)
        {
            message = "Display topology was not written.";
            if (string.IsNullOrEmpty(wowDir) || plan == null) return false;
            string core = Path.Combine(wowDir, "Interface", "AddOns", "Offhand", "Core");
            if (!Directory.Exists(core)) return false;
            string target = Path.Combine(core, "CompanionTopology.lua");
            string temporary = target + ".tmp";
            var selected = new StringBuilder();
            for (int i = 0; i < plan.Indices.Length; i++)
            {
                if (i > 0) selected.Append(", ");
                selected.Append(LuaString(displays[plan.Indices[i]].DeviceName));
            }
            string text =
                "-- Generated by Offhand Companion. Do not edit while the Companion is running.\r\n" +
                "OffhandCompanionTopology = {\r\n" +
                "  schema = 1, generatedAt = " + LuaString(DateTime.UtcNow.ToString("o")) + ",\r\n" +
                "  mode = " + LuaString(plan.SplitSingle ? "SPLIT_ULTRAWIDE" : "DUAL_DISPLAY") + ",\r\n" +
                "  physicalWidth = " + plan.Bounds.Width + ", physicalHeight = " + plan.Bounds.Height + ",\r\n" +
                "  mainhandDevice = " + LuaString(displays[plan.MainhandIndex].DeviceName) + ",\r\n" +
                "  selectedDevices = { " + selected + " },\r\n" +
                "  game = " + RectLua(plan.MainhandBounds, plan.Bounds) + ",\r\n" +
                "  workspace = " + RectLua(plan.WorkspaceBounds, plan.Bounds) + ",\r\n" +
                "}\r\n";
            try
            {
                File.WriteAllText(temporary, text, new UTF8Encoding(false));
                if (File.Exists(target)) File.Replace(temporary, target, null);
                else File.Move(temporary, target);
                message = string.Format("Display topology updated: game {0}x{1}, workspace {2}x{3}.",
                    plan.MainhandBounds.Width, plan.MainhandBounds.Height,
                    plan.WorkspaceBounds.Width, plan.WorkspaceBounds.Height);
                return true;
            }
            catch (Exception ex)
            {
                try { if (File.Exists(temporary)) File.Delete(temporary); } catch { }
                message = "Display topology update failed: " + ex.Message;
                return false;
            }
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

    internal static class CompanionTiming
    {
        internal static double AutoSpanDelay(string processName, string wowDir, decimal configuredDelay)
        {
            bool foreverProcess = string.Equals(processName, "WowB", StringComparison.OrdinalIgnoreCase)
                || string.Equals(processName, "WowForever", StringComparison.OrdinalIgnoreCase);
            bool foreverDirectory = !string.IsNullOrEmpty(wowDir)
                && wowDir.IndexOf("_classic_beta_", StringComparison.OrdinalIgnoreCase) >= 0;
            // Forever must reach its final window geometry before Blizzard loads
            // Edit Mode and before Offhand restores workspace coordinates.
            return foreverProcess || foreverDirectory ? 0 : (double)configuredDelay;
        }
    }

    internal static class CompanionDefaults
    {
        // Automatic window movement is opt-in so a first launch cannot unexpectedly
        // rearrange a player's WoW window before the selected displays are reviewed.
        internal const bool AutoSpanOnLaunch = false;
    }

    internal static class ForeverStateBridge
    {
        private const int MaxSavedVariablesBytes = 16 * 1024 * 1024;

        private static string ReadValidated(string path, string variable)
        {
            if (!File.Exists(path)) return null;
            var info = new FileInfo(path);
            if (info.Length <= 0 || info.Length > MaxSavedVariablesBytes) return null;
            string text = File.ReadAllText(path);
            if (text.IndexOf('\0') >= 0) return null;
            text = text.TrimStart('\uFEFF', '\r', '\n', ' ', '\t');
            if (!text.StartsWith(variable + " =", StringComparison.Ordinal)) return null;
            return text.TrimEnd() + Environment.NewLine;
        }

        private static string NewestValid(IEnumerable<string> paths, string variable)
        {
            string newest = null;
            DateTime newestWrite = DateTime.MinValue;
            foreach (string path in paths)
            {
                string valid;
                try { valid = ReadValidated(path, variable); }
                catch (IOException) { continue; }
                catch (UnauthorizedAccessException) { continue; }
                if (valid == null) continue;
                DateTime write = File.GetLastWriteTimeUtc(path);
                if (newest == null || write > newestWrite)
                {
                    newest = path;
                    newestWrite = write;
                }
            }
            return newest;
        }

        private static string Hash(string value)
        {
            using (var sha = SHA256.Create())
            {
                byte[] digest = sha.ComputeHash(Encoding.UTF8.GetBytes(value));
                var result = new StringBuilder(digest.Length * 2);
                foreach (byte b in digest) result.Append(b.ToString("x2"));
                return result.ToString();
            }
        }

        internal static bool TryRefresh(string wowDir, out string message)
        {
            message = "Forever recovery bridge was not updated.";
            if (string.IsNullOrEmpty(wowDir) || !Directory.Exists(wowDir))
            {
                message = "Forever recovery skipped: WoW directory unavailable.";
                return false;
            }

            string accountRoot = Path.Combine(wowDir, "WTF", "Account");
            string addonCore = Path.Combine(wowDir, "Interface", "AddOns", "Offhand", "Core");
            if (!Directory.Exists(accountRoot) || !Directory.Exists(addonCore))
            {
                message = "Forever recovery skipped: Offhand or WTF directory unavailable.";
                return false;
            }

            string[] all;
            try { all = Directory.GetFiles(accountRoot, "Offhand.lua", SearchOption.AllDirectories); }
            catch (IOException ex) { message = "Forever recovery cannot scan SavedVariables: " + ex.Message; return false; }
            catch (UnauthorizedAccessException ex) { message = "Forever recovery cannot scan SavedVariables: " + ex.Message; return false; }

            var accountFiles = new List<string>();
            foreach (string path in all)
            {
                var savedVariables = Directory.GetParent(path);
                var account = savedVariables == null ? null : savedVariables.Parent;
                if (savedVariables != null && account != null &&
                    savedVariables.Name.Equals("SavedVariables", StringComparison.OrdinalIgnoreCase) &&
                    account.Parent != null && account.Parent.FullName.Equals(accountRoot, StringComparison.OrdinalIgnoreCase))
                    accountFiles.Add(path);
            }

            string accountPath = NewestValid(accountFiles, "OffhandDB");
            if (accountPath == null)
            {
                message = "Forever recovery skipped: no valid account Offhand.lua found.";
                return false;
            }

            DirectoryInfo accountDirectory = Directory.GetParent(accountPath).Parent;
            var characterFiles = new List<string>();
            foreach (string path in all)
            {
                if (!path.StartsWith(accountDirectory.FullName + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)) continue;
                if (path.Equals(accountPath, StringComparison.OrdinalIgnoreCase)) continue;
                characterFiles.Add(path);
            }
            string characterPath = NewestValid(characterFiles, "OffhandCharDB");
            if (characterPath == null)
            {
                message = "Forever recovery skipped: no valid character Offhand.lua found for the newest account.";
                return false;
            }

            string accountText = ReadValidated(accountPath, "OffhandDB");
            string characterText = ReadValidated(characterPath, "OffhandCharDB");
            if (accountText == null || characterText == null)
            {
                message = "Forever recovery skipped: SavedVariables changed while being read.";
                return false;
            }

            string version = Hash(accountText + "\n" + characterText);
            string generated =
                "-- Generated by Offhand Companion from Forever SavedVariables while WoW was closed.\r\n" +
                "local interfaceVersion = select(4, GetBuildInfo())\r\n" +
                "if interfaceVersion >= 16000 and interfaceVersion < 17000 then\r\n" +
                "OffhandForeverStateBridgeVersion = \"" + version + "\"\r\n" +
                "local recoveryCVar = \"offhandForeverRecoveryVersion\"\r\n" +
                "local register = RegisterCVar or (C_CVar and C_CVar.RegisterCVar)\r\n" +
                "local getter = GetCVar or (C_CVar and C_CVar.GetCVar)\r\n" +
                "if register then pcall(register, recoveryCVar, \"\") end\r\n" +
                "local consumed = getter and tostring(getter(recoveryCVar) or \"\") == OffhandForeverStateBridgeVersion\r\n" +
                "if not consumed then\r\n" +
                accountText + characterText + "end\r\nend\r\n";
            string target = Path.Combine(addonCore, "ForeverState.lua");
            try
            {
                if (File.Exists(target) && File.ReadAllText(target) == generated)
                {
                    message = "Forever recovery snapshot is current.";
                    return true;
                }
                string temporary = target + ".tmp." + Process.GetCurrentProcess().Id;
                File.WriteAllText(temporary, generated, new UTF8Encoding(false));
                try
                {
                    if (File.Exists(target))
                        File.Replace(temporary, target, target + ".bak", true);
                    else
                        File.Move(temporary, target);
                }
                finally
                {
                    if (File.Exists(temporary)) File.Delete(temporary);
                }
                message = "Forever recovery snapshot updated from " +
                    accountDirectory.Name + " / " + Directory.GetParent(Directory.GetParent(characterPath).FullName).Name + ".";
                return true;
            }
            catch (IOException ex) { message = "Forever recovery cannot update addon state: " + ex.Message; return false; }
            catch (UnauthorizedAccessException ex) { message = "Forever recovery cannot update addon state: " + ex.Message; return false; }
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
        private ComboBox cmbMainhand;
        private CheckBox chkSingleSplit;
        private ComboBox cmbSingleSide;
        private List<MonitorSelection.Display> uiDisplays;
        private bool refreshingDisplayControls;

        private sealed class DisplayChoice
        {
            internal int Index;
            internal string DeviceName;
            internal string Label;
            public override string ToString() { return Label; }
        }

        private static List<MonitorSelection.Display> ReadDisplays()
        {
            var result = new List<MonitorSelection.Display>();
            var screens = Screen.AllScreens;
            for (int i = 0; i < screens.Length; i++)
                result.Add(new MonitorSelection.Display { Index = i, DeviceName = screens[i].DeviceName,
                    Bounds = screens[i].Bounds, WorkArea = screens[i].WorkingArea, Primary = screens[i].Primary });
            return result;
        }

        private void RefreshDisplayControls(List<MonitorSelection.Display> displays)
        {
            if (clbMonitors == null || cmbMainhand == null || displays == null
                || MonitorSelection.SameDisplays(uiDisplays, displays)) return;

            string savedDevices;
            appSettings.TryGetValue("MonitorDevices", out savedDevices);
            var wanted = new HashSet<string>((savedDevices ?? "").Split(
                new char[] { '|' }, StringSplitOptions.RemoveEmptyEntries), StringComparer.OrdinalIgnoreCase);
            string savedMainhand;
            appSettings.TryGetValue("MainhandDevice", out savedMainhand);

            refreshingDisplayControls = true;
            clbMonitors.BeginUpdate();
            cmbMainhand.BeginUpdate();
            try
            {
                uiDisplays = displays;
                clbMonitors.Items.Clear();
                cmbMainhand.Items.Clear();
                for (int i = 0; i < uiDisplays.Count; i++)
                {
                    Rectangle b = uiDisplays[i].Bounds;
                    bool selected = string.IsNullOrWhiteSpace(savedDevices) || wanted.Contains(uiDisplays[i].DeviceName);
                    clbMonitors.Items.Add(string.Format("Display {0}: {1}x{2}{3}", i + 1, b.Width, b.Height,
                        uiDisplays[i].Primary ? " (Primary)" : ""), selected);
                    cmbMainhand.Items.Add(new DisplayChoice { Index = i, DeviceName = uiDisplays[i].DeviceName,
                        Label = string.Format("Display {0} — {1}x{2}", i + 1, b.Width, b.Height) });
                }
                for (int i = 0; i < cmbMainhand.Items.Count; i++)
                {
                    var choice = (DisplayChoice)cmbMainhand.Items[i];
                    if (string.Equals(choice.DeviceName, savedMainhand, StringComparison.OrdinalIgnoreCase)
                        || (string.IsNullOrEmpty(savedMainhand) && uiDisplays[i].Primary))
                    {
                        cmbMainhand.SelectedIndex = i;
                        break;
                    }
                }
                if (cmbMainhand.SelectedIndex < 0 && cmbMainhand.Items.Count > 0)
                {
                    for (int i = 0; i < uiDisplays.Count; i++)
                        if (uiDisplays[i].Primary) { cmbMainhand.SelectedIndex = i; break; }
                    if (cmbMainhand.SelectedIndex < 0) cmbMainhand.SelectedIndex = 0;
                }
            }
            finally
            {
                cmbMainhand.EndUpdate();
                clbMonitors.EndUpdate();
                refreshingDisplayControls = false;
            }
            AddLog("Windows display topology changed; refreshed the display controls.");
        }

        private MonitorSelection.Plan GetMonitorPlan()
        {
            string devices, legacy, mainhand, split, side;
            appSettings.TryGetValue("MonitorDevices", out devices);
            appSettings.TryGetValue("Monitors", out legacy);
            appSettings.TryGetValue("MainhandDevice", out mainhand);
            appSettings.TryGetValue("SingleDisplaySplit", out split);
            appSettings.TryGetValue("SingleGameSide", out side);
            return MonitorSelection.CreatePlan(devices, legacy, mainhand,
                string.Equals(split, "True", StringComparison.OrdinalIgnoreCase),
                string.Equals(side, "LEFT", StringComparison.OrdinalIgnoreCase), ReadDisplays());
        }

        private void SaveDisplaySettingsFromControls()
        {
            if (refreshingDisplayControls || clbMonitors == null || uiDisplays == null) return;
            var devices = new List<string>();
            var legacy = new List<string>();
            for (int i = 0; i < clbMonitors.Items.Count; i++)
            {
                if (!clbMonitors.GetItemChecked(i)) continue;
                devices.Add(uiDisplays[i].DeviceName);
                legacy.Add(i.ToString());
            }
            appSettings["MonitorDevices"] = string.Join("|", devices.ToArray());
            appSettings["Monitors"] = string.Join(",", legacy.ToArray());
            var choice = cmbMainhand == null ? null : cmbMainhand.SelectedItem as DisplayChoice;
            if (choice != null) appSettings["MainhandDevice"] = choice.DeviceName;
            if (chkSingleSplit != null) appSettings["SingleDisplaySplit"] = chkSingleSplit.Checked.ToString();
            if (cmbSingleSide != null && cmbSingleSide.SelectedItem != null)
                appSettings["SingleGameSide"] = cmbSingleSide.SelectedItem.ToString().ToUpperInvariant();
            SaveConfig();
        }

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
        private Button btnCheckUpdates;
        private RichTextBox logBox;
        private readonly List<string> activityLogEntries = new List<string>();
        private NotifyIcon trayIcon;
        private ToolStripMenuItem itemAuto;
        private Timer monitorTimer;
        private ToolTip uiToolTips;

        // State
        private bool isMonitoring = true;
        private bool isExplicitExit = false;
        private bool updateCheckInProgress = false;
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
        private string lastObservedWowDir;
        private bool bridgeAttemptedWhileStopped;
        private static readonly string[] wowProcessNames = new string[] {
            "WowClassic", "Wow", "WowClassicEra", "WowForever", "WowT", "WowB", "WowClassicT", "WowClassicB"
        };

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

            AddLog("Offhand Companion v2.1.2 initialized.");
            AddLog("Monitoring active. Enable Offhand in WoW; calibrate with /offhand wizard.");
        }

        private void CheckForUpdates()
        {
            if (updateCheckInProgress) return;
            updateCheckInProgress = true;
            if (btnCheckUpdates != null) btnCheckUpdates.Enabled = false;
            AddLog("Checking GitHub for Companion updates (requested by user)...");

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
                        if (idx == -1) throw new FormatException("GitHub response did not include a release tag.");
                        int start = json.IndexOf("\"", idx + 11) + 1;
                        int end = json.IndexOf("\"", start);
                        if (start <= 0 || end <= start) throw new FormatException("GitHub release tag was malformed.");
                        string tag = json.Substring(start, end - start).TrimStart('v');
                        string cleanTag = tag.Contains("-") ? tag.Substring(0, tag.IndexOf("-")) : tag;
                        Version latest;
                        if (!Version.TryParse(cleanTag, out latest)) throw new FormatException("GitHub release version was not recognized.");
                        Version current = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;

                        CompleteUpdateCheck(new Action(() =>
                        {
                            if (latest > current)
                            {
                                AddLog("UPDATE AVAILABLE: v" + latest.ToString(3));
                                if (MessageBox.Show("Offhand Companion v" + latest.ToString(3) + " is available.\n\nOpen the official GitHub release page?", "Update Available", MessageBoxButtons.YesNo, MessageBoxIcon.Information) == DialogResult.Yes)
                                    System.Diagnostics.Process.Start("https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/latest");
                            }
                            else
                            {
                                AddLog("Companion is up to date (v" + current.ToString(3) + ").");
                                MessageBox.Show("You are running the latest published Companion version.", "No Update Available", MessageBoxButtons.OK, MessageBoxIcon.Information);
                            }
                        }));
                    }
                }
                catch (Exception ex)
                {
                    CompleteUpdateCheck(new Action(() =>
                    {
                        AddLog("Update check failed: " + ex.Message);
                        MessageBox.Show("The Companion could not check the official GitHub release page. No automatic retry will be made.", "Update Check Failed", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    }));
                }
            });
        }

        private void CompleteUpdateCheck(Action completion)
        {
            if (IsDisposed || Disposing || !IsHandleCreated) return;
            try
            {
                BeginInvoke(new Action(() =>
                {
                    updateCheckInProgress = false;
                    if (btnCheckUpdates != null) btnCheckUpdates.Enabled = true;
                    if (completion != null) completion();
                }));
            }
            catch (InvalidOperationException) { }
        }

        private void InitializeUI()
        {
            this.Text = "Offhand Companion";
            this.Size = new Size(524, 780);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.BackColor = cBg;
            this.ForeColor = cText;
            uiToolTips = new ToolTip
            {
                AutoPopDelay = 12000,
                InitialDelay = 450,
                ReshowDelay = 100,
                ShowAlways = true
            };
            this.Disposed += (s, e) => { if (uiToolTips != null) uiToolTips.Dispose(); };

            // Load Application Icon if available
            try
            {
                // The icon is already stored in the PE by /win32icon. Extracting
                // it avoids embedding a second 182 KB managed-resource copy.
                this.Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
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
            titleLabel.Size = new Size(365, 34);
            titleLabel.Font = new Font("Georgia", 22, FontStyle.Bold);
            titleLabel.ForeColor = cGold;
            titleLabel.BackColor = Color.Transparent;
            headerPanel.Controls.Add(titleLabel);

            // Subtitle
            Label subLabel = new Label();
            subLabel.Text = "Multi-Monitor Companion for World of Warcraft";
            subLabel.Location = new Point(98, 48);
            subLabel.Size = new Size(365, 18);
            subLabel.Font = new Font("Segoe UI", 8.5f);
            subLabel.ForeColor = cBrass;
            subLabel.BackColor = Color.Transparent;
            headerPanel.Controls.Add(subLabel);

            // Version
            Label verLabel = new Label();
            verLabel.Text = "v2.1.2";
            verLabel.Location = new Point(98, 66);
            verLabel.Size = new Size(100, 14);
            verLabel.Font = new Font("Segoe UI", 7.5f, FontStyle.Italic);
            verLabel.ForeColor = cMuted;
            verLabel.BackColor = Color.Transparent;
            headerPanel.Controls.Add(verLabel);

            Button btnHelp = CreateButton("?", 470, 12, 34, 34, cBtnPrimaryBg, cGoldBright, cGold);
            btnHelp.Font = new Font("Georgia", 14, FontStyle.Bold);
            btnHelp.AccessibleName = "Companion Help and Setup Guide";
            btnHelp.Click += (s, e) => { ShowHelpDialog(); };
            headerPanel.Controls.Add(btnHelp);
            uiToolTips.SetToolTip(btnHelp, "Open the complete Companion setup, daily-use, recovery, and troubleshooting guide.");

            // Status Card
            Panel statusPanel = CreateCardPanel(16, 102, 490, 140, "System Status");
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
                Location = new Point(10, 76),
                Size = new Size(470, 36),
                AutoSize = false,
                UseMnemonic = false,
                Font = new Font("Segoe UI", 8.5f),
                ForeColor = cMuted
            };
            statusPanel.Controls.Add(lblDisplayInfo);

            lblAddonReason = new Label
            {
                Text = "",
                Location = new Point(10, 114),
                Size = new Size(470, 18),
                AutoSize = false,
                UseMnemonic = false,
                Font = new Font("Segoe UI", 7.5f, FontStyle.Italic),
                ForeColor = cYellow
            };
            statusPanel.Controls.Add(lblAddonReason);

            // Configuration Card
            Panel configPanel = CreateCardPanel(16, 252, 490, 184, "Configuration");
            this.Controls.Add(configPanel);

            chkAutoSpan = new CheckBox
            {
                Text = "Automatically span WoW window on game launch",
                Location = new Point(10, 28),
                Size = new Size(460, 22),
                Font = new Font("Segoe UI", 9),
                ForeColor = cText,
                BackColor = Color.Transparent,
                Checked = CompanionDefaults.AutoSpanOnLaunch
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

            Label lblMonitors = new Label { Text = "Span displays:", Location = new Point(270, 26), Size = new Size(150, 22), ForeColor = cText, BackColor = Color.Transparent };
            configPanel.Controls.Add(lblMonitors);
            clbMonitors = new CheckedListBox { Location = new Point(270, 50), Size = new Size(210, 62), BackColor = cCard, ForeColor = cText, BorderStyle = BorderStyle.None };
            clbMonitors.CheckOnClick = true;
            uiDisplays = ReadDisplays();
            for (int i = 0; i < uiDisplays.Count; i++)
            {
                Rectangle b = uiDisplays[i].Bounds;
                clbMonitors.Items.Add(string.Format("Display {0}: {1}x{2}{3}", i + 1, b.Width, b.Height,
                    uiDisplays[i].Primary ? " (Primary)" : ""), true);
            }
            clbMonitors.ItemCheck += (s, e) => {
                if (!this.IsHandleCreated) return;
                this.BeginInvoke(new Action(() => {
                    SaveDisplaySettingsFromControls();
                }));
            };
            configPanel.Controls.Add(clbMonitors);

            Label lblMainhand = new Label { Text = "Mainhand (game):", Location = new Point(270, 112), Size = new Size(130, 20), ForeColor = cText, BackColor = Color.Transparent };
            configPanel.Controls.Add(lblMainhand);
            cmbMainhand = new ComboBox { Location = new Point(270, 134), Size = new Size(210, 22), DropDownStyle = ComboBoxStyle.DropDownList, BackColor = cCard, ForeColor = cText };
            for (int i = 0; i < uiDisplays.Count; i++)
            {
                Rectangle b = uiDisplays[i].Bounds;
                cmbMainhand.Items.Add(new DisplayChoice { Index = i, DeviceName = uiDisplays[i].DeviceName,
                    Label = string.Format("Display {0} — {1}x{2}", i + 1, b.Width, b.Height) });
            }
            configPanel.Controls.Add(cmbMainhand);

            chkSingleSplit = new CheckBox { Text = "Single-display 32:9 split", Location = new Point(10, 116), Size = new Size(245, 22), Font = new Font("Segoe UI", 9), ForeColor = cText, BackColor = Color.Transparent };
            configPanel.Controls.Add(chkSingleSplit);
            Label lblSingleSide = new Label { Text = "Game side:", Location = new Point(10, 146), Size = new Size(90, 22), ForeColor = cText, BackColor = Color.Transparent };
            configPanel.Controls.Add(lblSingleSide);
            cmbSingleSide = new ComboBox { Location = new Point(100, 144), Size = new Size(100, 22), DropDownStyle = ComboBoxStyle.DropDownList, BackColor = cCard, ForeColor = cText };
            cmbSingleSide.Items.AddRange(new object[] { "Right", "Left" });
            cmbSingleSide.SelectedIndex = 0;
            configPanel.Controls.Add(cmbSingleSide);

            uiToolTips.SetToolTip(chkAutoSpan,
                "Disabled by default. When enabled, Offhand spans each newly detected WoW window across the selected displays. Manual Span WoW Now remains available when disabled.");
            uiToolTips.SetToolTip(lblDelay,
                "Wait time before automatically spanning supported WoW clients. Forever uses immediate pre-login spanning so its UI initializes against the final desktop geometry.");
            uiToolTips.SetToolTip(numDelaySpan,
                "Automatic-span delay for non-Forever clients (0-60 seconds). Forever intentionally ignores this delay and spans immediately.");
            uiToolTips.SetToolTip(lblHotkey,
                "Choose the system-wide shortcut for Span WoW Now. Ctrl+Alt+R always restores WoW to a normal window when available.");
            uiToolTips.SetToolTip(cmbHotkey,
                "Choose the system-wide shortcut for Span WoW Now. If another application owns it, use the dashboard button or select another shortcut.");
            uiToolTips.SetToolTip(lblMonitors,
                "Select every display that should form WoW's borderless virtual desktop.");
            uiToolTips.SetToolTip(clbMonitors,
                "Select exactly two displays for normal use. If a saved display is disconnected, Offhand refuses to span rather than shrinking the UI onto the remaining screen.");
            uiToolTips.SetToolTip(cmbMainhand,
                "The display that contains the 3D game view and Blizzard combat UI. The other selected display becomes the Offhand workspace.");
            uiToolTips.SetToolTip(chkSingleSplit,
                "For one 32:9 or 32:10 super-ultrawide only: divide that display into a game half and workspace half. Leave disabled for ordinary single-monitor use.");
            uiToolTips.SetToolTip(cmbSingleSide,
                "Choose which half of a single super-ultrawide contains the game view.");

            string savedDevices;
            if (appSettings.TryGetValue("MonitorDevices", out savedDevices))
            {
                var wanted = new HashSet<string>(savedDevices.Split(new char[] { '|' }, StringSplitOptions.RemoveEmptyEntries), StringComparer.OrdinalIgnoreCase);
                for (int i = 0; i < clbMonitors.Items.Count; i++) clbMonitors.SetItemChecked(i, wanted.Contains(uiDisplays[i].DeviceName));
            }
            else if (appSettings.ContainsKey("Monitors"))
            {
                string[] saved = appSettings["Monitors"].Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
                for (int i = 0; i < clbMonitors.Items.Count; i++) clbMonitors.SetItemChecked(i, false);
                foreach (string m in saved) { int idx; if (int.TryParse(m, out idx) && idx >= 0 && idx < clbMonitors.Items.Count) clbMonitors.SetItemChecked(idx, true); }
            }

            string savedMainhand;
            appSettings.TryGetValue("MainhandDevice", out savedMainhand);
            for (int i = 0; i < cmbMainhand.Items.Count; i++)
            {
                var choice = (DisplayChoice)cmbMainhand.Items[i];
                if (string.Equals(choice.DeviceName, savedMainhand, StringComparison.OrdinalIgnoreCase)
                    || (string.IsNullOrEmpty(savedMainhand) && uiDisplays[i].Primary)) { cmbMainhand.SelectedIndex = i; break; }
            }
            if (cmbMainhand.SelectedIndex < 0 && cmbMainhand.Items.Count > 0) cmbMainhand.SelectedIndex = cmbMainhand.Items.Count - 1;
            chkSingleSplit.Checked = appSettings.ContainsKey("SingleDisplaySplit") && appSettings["SingleDisplaySplit"] == "True";
            if (appSettings.ContainsKey("SingleGameSide") && appSettings["SingleGameSide"].Equals("LEFT", StringComparison.OrdinalIgnoreCase)) cmbSingleSide.SelectedIndex = 1;

            cmbMainhand.SelectedIndexChanged += (s, e) => { SaveDisplaySettingsFromControls(); };
            chkSingleSplit.CheckedChanged += (s, e) => { cmbSingleSide.Enabled = chkSingleSplit.Checked; SaveDisplaySettingsFromControls(); };
            cmbSingleSide.SelectedIndexChanged += (s, e) => { SaveDisplaySettingsFromControls(); };
            cmbSingleSide.Enabled = chkSingleSplit.Checked;

            if (appSettings.ContainsKey("AutoSpan")) chkAutoSpan.Checked = appSettings["AutoSpan"] == "True";
            if (appSettings.ContainsKey("DelaySpan")) numDelaySpan.Value = PreferenceFile.Delay(appSettings["DelaySpan"]);

            chkAutoSpan.CheckedChanged += (s, e) => { appSettings["AutoSpan"] = chkAutoSpan.Checked.ToString(); SaveConfig(); };
            numDelaySpan.ValueChanged += (s, e) => { appSettings["DelaySpan"] = numDelaySpan.Value.ToString(); SaveConfig(); };
            numDelaySpan.KeyUp += (s, e) => { appSettings["DelaySpan"] = numDelaySpan.Value.ToString(); SaveConfig(); if (e.KeyCode == Keys.Enter) { e.Handled = true; this.ActiveControl = null; } };
            // Migrate legacy numeric monitor indices only when every saved
            // display is currently connected. Never erase evidence of a
            // disconnected display merely because Windows renumbered screens.
            if (!appSettings.ContainsKey("MonitorDevices"))
            {
                bool completeLegacySelection = true;
                string legacySelection;
                if (appSettings.TryGetValue("Monitors", out legacySelection))
                {
                    foreach (string token in legacySelection.Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries))
                    {
                        int index;
                        if (!int.TryParse(token, out index) || index < 0 || index >= uiDisplays.Count)
                        {
                            completeLegacySelection = false;
                            break;
                        }
                    }
                }
                if (completeLegacySelection) SaveDisplaySettingsFromControls();
            }


            // Action Buttons
            btnSpanNow = CreateButton("Span WoW Now", 16, 448, 158, 36, cBtnPrimaryBg, cGoldBright, cGold);
            btnSpanNow.Click += (s, e) => { InvokeSpanWindow(true); };
            this.Controls.Add(btnSpanNow);
            uiToolTips.SetToolTip(btnSpanNow, "Immediately make the detected WoW window borderless and span it across the selected displays. This also resumes spanning after Restore Window.");

            Button btnRestoreNow = CreateButton("Restore Window", 182, 448, 158, 36, cBtnBg, cText, cBorder);
            btnRestoreNow.Click += (s, e) => { InvokeRestoreWindow(true); };
            this.Controls.Add(btnRestoreNow);
            uiToolTips.SetToolTip(btnRestoreNow, "Return WoW to a bordered window filling the selected Mainhand display so off-screen UI can be recovered. Automatic spanning pauses for that WoW process until Span WoW Now is used.");

            btnToggleWatch = CreateButton("Pause Monitor", 348, 448, 158, 36, cBtnBg, cText, cBorder);
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
            uiToolTips.SetToolTip(btnToggleWatch, "Pause or resume background detection of WoW launches. Manual Span and Restore controls remain available while monitoring is paused.");

            // Activity Log Card
            Panel logPanel = CreateCardPanel(16, 496, 490, 200, "Activity Log");
            this.Controls.Add(logPanel);

            logBox = new RichTextBox
            {
                Location = new Point(4, 28),
                Size = new Size(482, 166),
                BackColor = cLogBg,
                ForeColor = cLogText,
                BorderStyle = BorderStyle.None,
                Font = new Font("Consolas", 8.5f),
                ReadOnly = true,
                DetectUrls = false,
                ScrollBars = RichTextBoxScrollBars.Vertical,
                WordWrap = true,
                TabStop = false
            };
            logPanel.Controls.Add(logBox);

            // Footer Buttons
            Button btnMinimize = CreateButton("Minimize to Tray", 16, 708, 152, 30, cBtnBg, cMuted, cBorderDim);
            btnMinimize.Click += (s, e) =>
            {
                this.Hide();
                trayIcon.ShowBalloonTip(2000, "Offhand Running in Tray", "Monitoring in background. Double-click tray icon to restore.", ToolTipIcon.Info);
            };
            this.Controls.Add(btnMinimize);
            uiToolTips.SetToolTip(btnMinimize, "Hide the dashboard while keeping the Companion and launch monitor running in the Windows notification tray.");

            btnCheckUpdates = CreateButton("Check for Updates", 182, 708, 158, 30, cBtnBg, cText, cBorder);
            btnCheckUpdates.Click += (s, e) => { CheckForUpdates(); };
            this.Controls.Add(btnCheckUpdates);
            uiToolTips.SetToolTip(btnCheckUpdates, "Contact the official GitHub Releases API once to compare versions. The Companion never checks for updates automatically.");

            Button btnExit = CreateButton("Exit Companion", 356, 708, 152, 30, cBtnDanger, Color.FromArgb(235, 130, 130), Color.FromArgb(140, 45, 45));
            btnExit.Click += (s, e) => { ExitApplication(); };
            this.Controls.Add(btnExit);
            uiToolTips.SetToolTip(btnExit, "Stop monitoring and fully exit the Companion. Closing the title-bar X only minimizes it to the tray.");

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

        private string GetHelpText()
        {
            return string.Join(Environment.NewLine, new string[] {
                "WHAT THE COMPANION DOES",
                "Offhand Companion spans WoW's ordinary Windowed-mode window borderlessly across the displays you select. On Forever it also establishes the final desktop geometry before Blizzard Edit Mode initializes and, while WoW is fully closed, prepares a guarded recovery snapshot of Offhand's SavedVariables.",
                "",
                "FIRST-TIME SETUP",
                "1. In WoW, choose standard Windowed mode (not Windowed Fullscreen).",
                "2. Start Offhand Companion before WoW.",
                "3. Select exactly two displays, then choose which one is Mainhand (game). The other becomes the Offhand workspace.",
                "   For one 32:9/32:10 super-ultrawide, select only that display, enable Single-display 32:9 split, and choose the game side.",
                "4. Leave Automatically span WoW window on game launch disabled for the first setup. Launch WoW, wait for its window, then click Span WoW Now.",
                "5. If WoW had already reached the character UI when you clicked Span, type /reload once. Then type /oh and complete the Auto-Setup Wizard.",
                "6. On Forever, open Blizzard Edit Mode, select or create the Offhand layout, place protected HUD elements on the game-view monitor, and save it.",
                "7. Arrange the map, character frame, backpack, and chat on the Offhand workspace.",
                "8. Exit WoW normally with the Companion still running. Relaunch once to verify a cold start.",
                "",
                "EVERYDAY USE",
                "Start the Companion before WoW. With auto-span disabled, click Span WoW Now after the WoW window appears. If you later enable auto-span, each newly detected WoW window is spanned automatically. The title-bar X minimizes the Companion to the tray; Exit Companion stops it.",
                "",
                "CONTROLS",
                "Automatically span on launch: Opt-in automatic spanning; disabled by default.",
                "Delay Span: Delay used by non-Forever clients. Forever spans immediately so the UI loads against its final geometry.",
                "Global Hotkey: System-wide shortcut for Span WoW Now. Ctrl+Alt+R restores the window.",
                "Span displays: Exactly two displays for normal use, or one super-ultrawide in explicit split mode.",
                "Mainhand (game): The selected display's exact rectangle becomes the 3D game viewport. The other selected display becomes the workspace.",
                "Single-display 32:9 split: Divides one super-ultrawide into equal workspace/game halves. It never activates automatically.",
                "Span WoW Now: Span immediately and resume a process previously restored.",
                "Restore Window: Fill the selected Mainhand with a safe bordered WoW window and pause auto-span for that process.",
                "Pause Monitor: Stop launch detection without disabling the manual controls.",
                "Check for Updates: Make a one-time HTTPS request to the official GitHub Releases API. Update checks never run automatically.",
                "",
                "FOREVER AND EDIT MODE",
                "Forever's protected action bars, unit frames, minimap, and Edit Mode controls belong to Blizzard Edit Mode. Offhand restores workspace panels separately. The Companion is required because WoW must already have the final multi-monitor window geometry when those protected frames initialize. It also works around Forever builds that write Offhand SavedVariables but do not reliably load them on the next cold launch.",
                "",
                "RECOVERY",
                "If UI is inaccessible, click Restore Window (or press Ctrl+Alt+R), enter WoW, and use Offhand's Gather Off-Screen UI action. Re-enter Edit Mode and save/select the Offhand layout, then click Span WoW Now and /reload once. If a saved workspace display disconnects while WoW is spanned, Companion restores a bordered WoW window that fills the surviving Mainhand and refuses another span until the topology is valid. On Forever, click Use Modern when Offhand prompts; after reconnecting and spanning the exact topology, click Restore Offhand. WoW must be fully closed before the Forever recovery snapshot can be refreshed.",
                "",
                "TROUBLESHOOTING",
                "Select exactly two displays and a connected Mainhand, or explicitly enable the one-display super-ultrawide split. If a global shortcut is unavailable, choose another or use the dashboard button. Mixed resolutions, ultrawide Mainhand displays, portrait screens, negative desktop coordinates, and stacked arrangements use Windows' exact display rectangles; make sure Windows Display Settings matches the physical arrangement. Hover any dashboard control for a concise explanation.",
                "",
                "PRIVACY & VERIFICATION",
                "The Companion does not collect telemetry, credentials, chat, or gameplay data. Network access occurs only when you click Check for Updates, and is limited to the official GitHub Releases API. Release checksums, source, and build provenance are published with official GitHub releases."
            });
        }

        private void ShowHelpDialog()
        {
            using (Form help = new Form())
            {
                help.Text = "Offhand Companion Help";
                help.StartPosition = FormStartPosition.CenterParent;
                help.Size = new Size(720, 680);
                help.MinimumSize = new Size(600, 520);
                help.BackColor = cBg;
                help.ForeColor = cText;
                help.FormBorderStyle = FormBorderStyle.Sizable;
                help.MinimizeBox = false;
                help.ShowInTaskbar = false;
                if (this.Icon != null) help.Icon = this.Icon;

                Label heading = new Label
                {
                    Text = "OFFHAND COMPANION — SETUP & HELP",
                    Dock = DockStyle.Top,
                    Height = 52,
                    Padding = new Padding(16, 14, 10, 0),
                    Font = new Font("Georgia", 14, FontStyle.Bold),
                    ForeColor = cGoldBright,
                    BackColor = cCard
                };
                Panel footer = new Panel { Dock = DockStyle.Bottom, Height = 54, BackColor = cCard };
                Button close = CreateButton("Close", 0, 0, 120, 30, cBtnPrimaryBg, cGoldBright, cGold);
                close.Anchor = AnchorStyles.Top | AnchorStyles.Right;
                close.Location = new Point(footer.ClientSize.Width - close.Width - 16, 12);
                footer.Resize += (s, e) => { close.Left = footer.ClientSize.Width - close.Width - 16; };
                close.Click += (s, e) => { help.Close(); };
                footer.Controls.Add(close);

                RichTextBox guide = new RichTextBox
                {
                    Dock = DockStyle.Fill,
                    ReadOnly = true,
                    DetectUrls = false,
                    BorderStyle = BorderStyle.None,
                    BackColor = cBg,
                    ForeColor = cText,
                    Font = new Font("Segoe UI", 10),
                    Text = GetHelpText(),
                    ScrollBars = RichTextBoxScrollBars.Vertical,
                    TabStop = true,
                    WordWrap = true
                };
                guide.SelectionStart = 0;
                guide.SelectionLength = 0;
                Panel guidePanel = new Panel { Dock = DockStyle.Fill, Padding = new Padding(16), BackColor = cBg };
                guidePanel.Controls.Add(guide);

                // Add the fill area first so the fixed header/footer always retain
                // their space when Windows recalculates docking at a new DPI.
                help.Controls.Add(guidePanel);
                help.Controls.Add(footer);
                help.Controls.Add(heading);
                help.AcceptButton = close;
                help.CancelButton = close;
                help.ShowDialog(this);
            }
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

            ToolStripMenuItem itemHelp = new ToolStripMenuItem("Help / Setup Guide");
            itemHelp.Click += (s, e) => { RestoreForm(); ShowHelpDialog(); };
            trayMenu.Items.Add(itemHelp);

            ToolStripMenuItem itemCheckUpdates = new ToolStripMenuItem("Check for Updates");
            itemCheckUpdates.Click += (s, e) => { RestoreForm(); CheckForUpdates(); };
            trayMenu.Items.Add(itemCheckUpdates);

            trayMenu.Items.Add(new ToolStripSeparator());

            ToolStripMenuItem itemSpan = new ToolStripMenuItem("Span WoW Now");
            itemSpan.Click += (s, e) => { InvokeSpanWindow(true); };
            trayMenu.Items.Add(itemSpan);

            itemAuto = new ToolStripMenuItem("Automatically Span on Launch")
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
            activityLogEntries.Insert(0, string.Format("[{0}] {1}", time, message));
            while (activityLogEntries.Count > 100) activityLogEntries.RemoveAt(activityLogEntries.Count - 1);
            logBox.Lines = activityLogEntries.ToArray();
            logBox.SelectionStart = 0;
            logBox.SelectionLength = 0;
            logBox.ScrollToCaret();
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

        private void RememberWowDirectory(string wowDir)
        {
            if (string.IsNullOrEmpty(wowDir)) return;
            lastObservedWowDir = wowDir;
            string saved;
            if (!appSettings.TryGetValue("LastWowDir", out saved) ||
                !string.Equals(saved, wowDir, StringComparison.OrdinalIgnoreCase))
            {
                appSettings["LastWowDir"] = wowDir;
                SaveConfig();
            }
        }

        private string ResolveStoppedWowDirectory()
        {
            if (!string.IsNullOrEmpty(lastObservedWowDir) && Directory.Exists(lastObservedWowDir))
                return lastObservedWowDir;
            string saved;
            if (appSettings.TryGetValue("LastWowDir", out saved) && Directory.Exists(saved))
                return saved;

            var companion = new DirectoryInfo(AppDomain.CurrentDomain.BaseDirectory.TrimEnd(
                Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
            var addon = companion.Name.Equals("Companion", StringComparison.OrdinalIgnoreCase) ? companion.Parent : null;
            var addOns = addon == null ? null : addon.Parent;
            var interfaceDirectory = addOns == null ? null : addOns.Parent;
            var wow = interfaceDirectory == null ? null : interfaceDirectory.Parent;
            if (addon != null && addOns != null && interfaceDirectory != null && wow != null &&
                addon.Name.Equals("Offhand", StringComparison.OrdinalIgnoreCase) &&
                addOns.Name.Equals("AddOns", StringComparison.OrdinalIgnoreCase) &&
                interfaceDirectory.Name.Equals("Interface", StringComparison.OrdinalIgnoreCase))
                return wow.FullName;
            return null;
        }

        private void RefreshForeverStateWhileStopped()
        {
            if (bridgeAttemptedWhileStopped) return;
            bridgeAttemptedWhileStopped = true;
            string wowDir = ResolveStoppedWowDirectory();
            if (string.IsNullOrEmpty(wowDir)) return;
            string message;
            ForeverStateBridge.TryRefresh(wowDir, out message);
            AddLog(message);
        }

        private void OnTimerTick()
        {
            bool savedDisplayDisconnected = false;
            MonitorSelection.Plan currentDisplayPlan = null;
            List<MonitorSelection.Display> currentDisplays = ReadDisplays();
            RefreshDisplayControls(currentDisplays);
            try
            {
                currentDisplayPlan = GetMonitorPlan();
                lblDisplayInfo.Text = string.Format("  Game: {0}x{1}  Workspace: {2}x{3}  ({4})",
                    currentDisplayPlan.MainhandBounds.Width, currentDisplayPlan.MainhandBounds.Height,
                    currentDisplayPlan.WorkspaceBounds.Width, currentDisplayPlan.WorkspaceBounds.Height,
                    currentDisplayPlan.SplitSingle ? "one-screen split" : "two displays");
            }
            catch (Exception ex)
            {
                lblDisplayInfo.Text = "  Display plan: " + ex.Message;
                string savedDevices;
                appSettings.TryGetValue("MonitorDevices", out savedDevices);
                savedDisplayDisconnected = MonitorSelection.HasDisconnectedSavedDisplay(savedDevices, currentDisplays);
            }

            Process proc = GetWoWProcess();

            if (proc != null)
            {
                lblWowStatus.Text = string.Format("  * WoW Running  ({0}  PID: {1})", proc.ProcessName, proc.Id);
                lblWowStatus.ForeColor = cGreen;

                AddonStatus status = TestOffhandAddonStatus(proc);
                RememberWowDirectory(status.WowDir);
                bridgeAttemptedWhileStopped = false;
                if (currentDisplayPlan != null && !spannedPids.Contains(proc.Id) && !restoredPids.Contains(proc.Id))
                {
                    IntPtr observedHandle = GetWoWWindowHandle(proc);
                    NativeMethods.RECT observedRect;
                    if (observedHandle != IntPtr.Zero && NativeMethods.GetWindowRect(observedHandle, out observedRect)
                        && observedRect.Left == currentDisplayPlan.Bounds.Left
                        && observedRect.Top == currentDisplayPlan.Bounds.Top
                        && observedRect.Width == currentDisplayPlan.Bounds.Width
                        && observedRect.Height == currentDisplayPlan.Bounds.Height)
                    {
                        spannedPids.Add(proc.Id);
                        AddLog("Detected an existing WoW span and resumed display-loss protection for this client.");
                    }
                }
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

                if (isMonitoring && savedDisplayDisconnected && spannedPids.Contains(proc.Id)
                    && !restoredPids.Contains(proc.Id)
                    && (!retryAfter.ContainsKey(proc.Id) || DateTime.Now >= retryAfter[proc.Id]))
                {
                    retryAfter[proc.Id] = DateTime.Now.AddSeconds(10);
                    AddLog("A saved display disconnected while WoW was spanned. Restoring WoW to the surviving Mainhand display...");
                    if (InvokeRestoreWindow(false, true))
                        AddLog("Missing-monitor recovery filled the surviving Mainhand display. Reconnect the workspace display before spanning again.");
                }

                if (isMonitoring && chkAutoSpan.Checked && status.Installed)
                {
                    if (!spannedPids.Contains(proc.Id) && !restoredPids.Contains(proc.Id) &&
                        (!retryAfter.ContainsKey(proc.Id) || DateTime.Now >= retryAfter[proc.Id]))
                    {
                        if (!launchTimes.ContainsKey(proc.Id)) launchTimes[proc.Id] = DateTime.Now;
                        double spanDelay = CompanionTiming.AutoSpanDelay(proc.ProcessName, status.WowDir, numDelaySpan.Value);
                        if ((DateTime.Now - launchTimes[proc.Id]).TotalSeconds < spanDelay) { retryAfter[proc.Id] = DateTime.Now.AddSeconds(1); return; }
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
                // The game window can disappear before the process finishes
                // flushing SavedVariables. Never read or replace the recovery
                // snapshot until every recognized WoW process has exited.
                if (!IsAnyWoWProcessRunning()) RefreshForeverStateWhileStopped();
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
            foreach (string name in wowProcessNames)
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

        private bool IsAnyWoWProcessRunning()
        {
            foreach (string name in wowProcessNames)
            {
                Process[] processes = Process.GetProcessesByName(name);
                if (processes.Length > 0) return true;
            }
            return false;
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

        private bool InvokeRestoreWindow(bool manual)
        {
            return InvokeRestoreWindow(manual, true);
        }

        private bool InvokeRestoreWindow(bool manual, bool fillConnectedMainhand)
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
                Rectangle desired;
                Rectangle workArea;
                if (fillConnectedMainhand)
                {
                    string mainhandDevice;
                    appSettings.TryGetValue("MainhandDevice", out mainhandDevice);
                    MonitorSelection.Display recoveryDisplay = MonitorSelection.RecoveryDisplay(mainhandDevice, ReadDisplays());
                    if (recoveryDisplay == null) throw new Exception("Windows reports no surviving display for recovery.");
                    workArea = recoveryDisplay.WorkArea.Width > 0 && recoveryDisplay.WorkArea.Height > 0
                        ? recoveryDisplay.WorkArea : recoveryDisplay.Bounds;
                    desired = workArea;
                }
                else
                {
                    desired = known ? snapshot.Bounds : new Rectangle(Screen.PrimaryScreen.WorkingArea.Location, new Size(1920, 1080));
                    workArea = Screen.FromRectangle(desired).WorkingArea;
                }
                Rectangle target = RestoreGeometry.Fit(desired, workArea);
                
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
                AddLog(fillConnectedMainhand
                    ? "Restored WoW across the selected or surviving Mainhand display. Auto-span paused until Span Now. On Forever, click Use Modern if Offhand prompts."
                    : "Restored WoW window. Auto-span paused for this client until Span Now or a new WoW launch.");
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

                List<MonitorSelection.Display> displays = ReadDisplays();
                string devices, legacy, mainhand, split, side;
                appSettings.TryGetValue("MonitorDevices", out devices);
                appSettings.TryGetValue("Monitors", out legacy);
                appSettings.TryGetValue("MainhandDevice", out mainhand);
                appSettings.TryGetValue("SingleDisplaySplit", out split);
                appSettings.TryGetValue("SingleGameSide", out side);
                MonitorSelection.Plan plan = MonitorSelection.CreatePlan(devices, legacy, mainhand,
                    string.Equals(split, "True", StringComparison.OrdinalIgnoreCase),
                    string.Equals(side, "LEFT", StringComparison.OrdinalIgnoreCase), displays);
                Rectangle plannedBounds = plan.Bounds;
                Rectangle bounds = plannedBounds;
                if (bounds.Width <= 0 || bounds.Height <= 0) throw new Exception("Invalid virtual desktop dimensions.");

                string topologyMessage;
                if (CompanionTopologyBridge.TryWrite(status.WowDir, plan, displays, out topologyMessage)) AddLog(topologyMessage);
                else AddLog(topologyMessage + " The current session may require /reload after correcting this.");

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
                        var screens = Screen.AllScreens;
                        foreach (int index in plan.Indices)
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
                AddLog(string.Format("Spanned {0}x{1}. If the character UI was already loaded, use /reload once, then run /offhand wizard.", bounds.Width, bounds.Height));
                trayIcon.ShowBalloonTip(4000, "Offhand Spanned", "Exact display geometry saved. If already in game, use /reload once.", ToolTipIcon.Info);
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











