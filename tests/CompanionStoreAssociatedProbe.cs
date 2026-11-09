using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace Offhand.Testing
{
    // Read-only Store integration probe, launched with Microsoft's supported
    // Invoke-CommandInDesktopPackage debugger. No candidate installation.
    internal static class StoreAssociatedProbe
    {
        private const BindingFlags Instance = BindingFlags.Instance | BindingFlags.NonPublic;
        private const BindingFlags Static = BindingFlags.Static | BindingFlags.NonPublic;
        private static MethodInfo realQuery;
        private static int calls;
        private static string failure, queryResult;
        private static long queryMilliseconds;

        private static async Task<T> Query<T>(IntPtr window, CancellationToken token)
        {
            calls++; var clock = Stopwatch.StartNew();
            try
            {
                var task = (Task<T>)realQuery.Invoke(null, new object[] { window, token });
                T result = await task; queryResult = result.ToString(); return result;
            }
            catch (Exception error)
            {
                while (error is TargetInvocationException && error.InnerException != null) error = error.InnerException;
                failure = error.GetType().Name + " 0x" + error.HResult.ToString("X8"); throw;
            }
            finally { queryMilliseconds = clock.ElapsedMilliseconds; }
        }

        [STAThread]
        public static void Main(string[] args)
        {
            if (args.Length != 2) return;
            string output = Path.GetFullPath(args[0]); string mode = args[1];
            Directory.CreateDirectory(output);
            var receipt = new System.Collections.Generic.Dictionary<string, object>();
            Action save = () => File.WriteAllText(Path.Combine(output, "result.json"), new JavaScriptSerializer().Serialize(receipt));
            receipt["mode"] = mode; receipt["startedUtc"] = DateTime.UtcNow.ToString("o");
            try
            {
                Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
                string candidate = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Offhand.exe");
                using (var sha = SHA256.Create()) using (var stream = File.OpenRead(candidate))
                    if (BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "") != "95811DBB7020A20E2541AE123E69FE80721C83A0FD52D0EE5557DD6D54DCCC2A")
                        throw new InvalidDataException("Candidate hash mismatch.");
                var assembly = Assembly.LoadFrom(candidate);
                var distribution = assembly.GetType("Offhand.Companion.CompanionDistribution", true);
                string family = (string)distribution.GetMethod("PackageFamilyName", Static).Invoke(null, null);
                receipt["packageFamily"] = family;
                if (family != "N4UX.OffhandCompanion_bwe0ea6astzt8") throw new InvalidOperationException("Expected Store package identity is absent.");
                var packageType = Type.GetType("Windows.ApplicationModel.Package, Windows, ContentType=WindowsRuntime", true);
                object current = packageType.GetProperty("Current").GetValue(null, null);
                object identity = current.GetType().GetProperty("Id").GetValue(current, null);
                receipt["packageFullName"] = identity.GetType().GetProperty("FullName").GetValue(identity, null);
                string data = Path.Combine(output, "isolated-data"); Directory.CreateDirectory(data);
                var formType = assembly.GetType("Offhand.Companion.CompanionForm", true);
                var stateType = assembly.GetType("Offhand.Companion.StoreUpdateState", true);
                formType.GetField("configPath", Static).SetValue(null, Path.Combine(data, "TestConfig.ini"));
                formType.GetField("publicConfigPath", Static).SetValue(null, Path.Combine(data, "TestConfig.ini"));
                realQuery = assembly.GetType("Offhand.Companion.StoreUpdateRuntime", true).GetMethod("QueryAsync", Static);
                using (var form = (Form)Activator.CreateInstance(formType))
                {
                    var monitor = (System.Windows.Forms.Timer)formType.GetField("monitorTimer", Instance).GetValue(form); monitor.Stop();
                    formType.GetField("isMonitoring", Instance).SetValue(form, false);
                    var observer = typeof(StoreAssociatedProbe).GetMethod("Query", Static).MakeGenericMethod(stateType);
                    var provider = formType.GetField("storeUpdateQuery", Instance);
                    provider.SetValue(form, Delegate.CreateDelegate(provider.FieldType, observer));
                    var button = (Button)formType.GetField("btnCheckUpdates", Instance).GetValue(form);
                    Disable(form, button);
                    var tray = (NotifyIcon)formType.GetField("trayIcon", Instance).GetValue(form);
                    foreach (ToolStripItem item in tray.ContextMenuStrip.Items) item.Enabled = false;
                    form.Text = "Offhand 2.1.5: REAL Store query probe (isolated settings)";
                    receipt["storeRouting"] = formType.GetField("isStorePackage", Instance).GetValue(form);
                    save();
                    var elapsed = Stopwatch.StartNew();
                    using (var timer = new System.Windows.Forms.Timer { Interval = 1000 })
                    {
                        timer.Tick += (s, e) =>
                        {
                            if (elapsed.Elapsed.TotalSeconds < 50) return;
                            timer.Stop();
                            receipt["queryCount"] = calls; receipt["queryResult"] = queryResult;
                            receipt["failure"] = failure; receipt["queryMilliseconds"] = queryMilliseconds;
                            receipt["buttonText"] = button.Text; receipt["buttonDescription"] = button.AccessibleDescription;
                            string cache = Path.Combine(data, "StoreUpdateCheck.ini");
                            receipt["cache"] = File.Exists(cache) ? File.ReadAllText(cache) : "absent";
                            receipt["finishedUtc"] = DateTime.UtcNow.ToString("o"); save();
                            formType.GetField("isExplicitExit", Instance).SetValue(form, true); form.Close();
                        };
                        timer.Start(); Application.Run(form);
                    }
                    monitor.Dispose(); tray.Dispose();
                }
            }
            catch (Exception error)
            {
                receipt["fatalError"] = error.GetBaseException().GetType().Name + " 0x" + error.GetBaseException().HResult.ToString("X8"); save();
            }
        }

        private static void Disable(Control root, Button update)
        {
            foreach (Control child in root.Controls)
            {
                if (child is Button || child is CheckBox || child is ComboBox || child is NumericUpDown || child is CheckedListBox) child.Enabled = false;
                Disable(child, update);
            }
        }
    }
}
