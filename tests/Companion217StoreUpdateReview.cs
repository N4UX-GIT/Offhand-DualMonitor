using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

[assembly: AssemblyTitle("Offhand Store Update Simulation")]
[assembly: AssemblyVersion("2.1.7.0")]
[assembly: AssemblyFileVersion("2.1.7.9001")]
[assembly: AssemblyInformationalVersion("2.1.7-local-test.1")]

namespace Offhand.Testing
{
    // Local-only review host. It loads the exact candidate, substitutes only
    // the Store response, and leaves the production scheduler/UI unchanged.
    internal static class Companion217StoreUpdateReview
    {
        private const string ExpectedHash = "BUILD_EXE_SHA256";
        private const BindingFlags Instance = BindingFlags.Instance | BindingFlags.NonPublic;
        private const BindingFlags Static = BindingFlags.Static | BindingFlags.NonPublic;
        private static string scenario, dataPath;

        private static async Task<T> Simulate<T>(IntPtr window, CancellationToken cancellation)
        {
            File.AppendAllText(Path.Combine(dataPath, "test-queries.log"), DateTime.UtcNow.ToString("o") + " " + scenario + Environment.NewLine);
            if (scenario == "Unavailable") throw new IOException("Simulated unavailable Store. No network request was made.");
            if (scenario == "Timeout") await Task.Delay(60000, cancellation);
            return (T)Enum.Parse(typeof(T), scenario == "NoUpdate" ? "NoUpdate" : "Available");
        }

        private static Assembly LoadCandidate()
        {
            string path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Runtime", "Offhand.exe");
            using (var sha = SHA256.Create())
            using (var stream = File.OpenRead(path))
                if (BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "") != ExpectedHash)
                    throw new InvalidDataException("This simulator requires the exact included 2.1.7.1 candidate. Extract the complete ZIP again.");
            return Assembly.LoadFrom(path);
        }

        private static Delegate QueryDelegate(Type formType, Type stateType)
        {
            var method = typeof(Companion217StoreUpdateReview).GetMethod("Simulate", Static).MakeGenericMethod(stateType);
            return Delegate.CreateDelegate(formType.GetField("storeUpdateQuery", Instance).FieldType, method);
        }

        private static bool Choose(out bool reset)
        {
            using (var dialog = new Form { Text = "Offhand 2.1.7: local Store update test", ClientSize = new Size(620, 290),
                AutoScaleMode = AutoScaleMode.Dpi, StartPosition = FormStartPosition.CenterScreen,
                BackColor = Color.FromArgb(20, 20, 24), ForeColor = Color.Gainsboro, Font = new Font("Segoe UI", 10),
                FormBorderStyle = FormBorderStyle.FixedDialog, MaximizeBox = false, MinimizeBox = false })
            {
                dialog.Icon = Icon.ExtractAssociatedIcon(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Runtime", "Offhand.exe"));
                var layout = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(22), ColumnCount = 1, RowCount = 5 };
                layout.RowStyles.Add(new RowStyle(SizeType.AutoSize)); layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
                layout.RowStyles.Add(new RowStyle(SizeType.AutoSize)); layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
                layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));
                var intro = new Label { AutoSize = true, Dock = DockStyle.Fill, Margin = new Padding(0, 0, 0, 16),
                    Text = "SIMULATED Store responses, using the production update controller.\r\nNo Store query or installation occurs. Game controls are disabled.\r\nYour normal Companion settings and the published Store app stay unchanged." };
                var choices = new ComboBox { Dock = DockStyle.Fill, DropDownStyle = ComboBoxStyle.DropDownList,
                    BackColor = Color.FromArgb(30, 30, 36), ForeColor = Color.Gainsboro, Margin = new Padding(0, 0, 0, 12) };
                choices.Items.AddRange(new object[] { "Update available (after 30 seconds)", "No update (after 30 seconds)",
                    "Store unavailable (after 30 seconds)", "Timeout (after about 45 seconds)" }); choices.SelectedIndex = 0;
                var clear = new CheckBox { AutoSize = true, Checked = true, Text = "Reset this scenario's test cache", Margin = new Padding(0, 0, 0, 12) };
                var note = new Label { AutoSize = true, Dock = DockStyle.Fill,
                    Text = "For the six-hour throttle test, run the same scenario again with reset unchecked.\r\nAdvanced and the Store button tooltip show the last check time. See README.txt." };
                var start = new Button { Text = "Open test dashboard", Dock = DockStyle.Right, Width = 210, DialogResult = DialogResult.OK,
                    FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(42, 34, 18), ForeColor = Color.Gold };
                layout.Controls.Add(intro); layout.Controls.Add(choices); layout.Controls.Add(clear); layout.Controls.Add(note); layout.Controls.Add(start);
                dialog.Controls.Add(layout); dialog.AcceptButton = start;
                if (dialog.ShowDialog() != DialogResult.OK) { reset = false; return false; }
                scenario = new[] { "Available", "NoUpdate", "Unavailable", "Timeout" }[choices.SelectedIndex];
                reset = clear.Checked; return true;
            }
        }

        private static void DisableGameControls(Control root, Button update)
        {
            foreach (Control child in root.Controls)
            {
                if (child is Button && child != update && child.Text != "Exit Companion"
                    && child.Text != "Minimize to Tray" && child.Text != "Show" && child.Text != "Hide"
                    && child.AccessibleRole != AccessibleRole.PageTab && child.Text != "?") child.Enabled = false;
                if (child is CheckBox || child is ComboBox || child is NumericUpDown || child is CheckedListBox) child.Enabled = false;
                DisableGameControls(child, update);
            }
        }

        [STAThread]
        public static void Main(string[] args)
        {
            Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
            try
            {
                var assembly = LoadCandidate();
                var formType = assembly.GetType("Offhand.Companion.CompanionForm", true);
                var stateType = assembly.GetType("Offhand.Companion.StoreUpdateState", true);
                if (args.Length == 1 && args[0] == "--verify")
                { QueryDelegate(formType, stateType); Console.WriteLine("Exact candidate and simulator delegate verified."); return; }
                bool created;
                using (var mutex = new Mutex(true, @"Local\OffhandCompanion217StoreUpdateReview", out created))
                {
                    if (!created) { MessageBox.Show("Close the existing Store update test dashboard first."); return; }
                    bool reset;
                    if (args.Length == 1 && args[0] == "--available") { scenario = "Available"; reset = false; }
                    else if (!Choose(out reset)) return;
                    dataPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "LocalTestData", scenario);
                    Directory.CreateDirectory(dataPath);
                    string cache = Path.Combine(dataPath, "StoreUpdateCheck.ini");
                    if (reset && File.Exists(cache)) File.Delete(cache);
                    string config = Path.Combine(dataPath, "TestConfig.ini");
                    if (!File.Exists(config)) File.WriteAllText(config,
                        "AutoSpan=False\r\nCompanionTutorialSeen=True\r\nDashboardCollapsed.SystemStatus=True\r\nDashboardCollapsed.DisplayDiagnostics=True\r\nDashboardCollapsed.ActivityLog=True\r\n");
                    formType.GetField("configPath", Static).SetValue(null, config);
                    formType.GetField("publicConfigPath", Static).SetValue(null, config);
                    using (var form = (Form)Activator.CreateInstance(formType))
                    {
                        var monitor = (System.Windows.Forms.Timer)formType.GetField("monitorTimer", Instance).GetValue(form); monitor.Stop();
                        formType.GetField("isMonitoring", Instance).SetValue(form, false);
                        formType.GetField("isStorePackage", Instance).SetValue(form, true);
                        formType.GetField("storeUpdateQuery", Instance).SetValue(form, QueryDelegate(formType, stateType));
                        form.Text = "Offhand 2.1.7: SIMULATED Store updates (" + scenario + ")";
                        form.Shown += (s, e) => formType.GetMethod("SelectDashboardPage", Instance).Invoke(form, new object[] { true });
                        var button = (Button)formType.GetField("btnCheckUpdates", Instance).GetValue(form);
                        DisableGameControls(form, button);
                        var tray = (NotifyIcon)formType.GetField("trayIcon", Instance).GetValue(form);
                        foreach (ToolStripItem item in tray.ContextMenuStrip.Items)
                            if (item.Text.Contains("Span") || item.Text.Contains("Restore") || item.Text.Contains("monitor") || item.Text.Contains("Help")) item.Enabled = false;
                        formType.GetMethod("UpdateDashboardStatusSummary", Instance).Invoke(form, null);
                        formType.GetMethod("AddLog", Instance).Invoke(form, new object[] { "LOCAL SIMULATION: " + scenario + ". Store responses are simulated; no game actions or real update queries." });
                        form.Disposed += (s, e) => { monitor.Dispose(); tray.Dispose(); };
                        Application.Run(form);
                    }
                }
            }
            catch (Exception error)
            {
                if (args.Length == 1 && args[0] == "--verify")
                { Console.Error.WriteLine(error.GetBaseException().Message); Environment.ExitCode = 1; }
                else MessageBox.Show(error.GetBaseException().Message, "Local Store update test", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }
}
