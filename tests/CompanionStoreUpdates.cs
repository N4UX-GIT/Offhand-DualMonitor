using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Offhand.Companion
{
    internal static class StoreUpdatesTest
    {
        private static int count;
        private static void Check(bool condition, string reason)
        { count++; if (!condition) throw new Exception(reason); }

        private static async Task VerifyAsync(string directory)
        {
            var now = new DateTime(2026, 11, 9, 5, 0, 0, DateTimeKind.Utc);
            string path = Path.Combine(directory, "StoreUpdateCheck.ini");
            var cache = new StoreUpdateCache(path, "2.1.5.1");
            Check(cache.Cached(now) == StoreUpdateState.NotChecked, "Missing cache must not mean up-to-date");
            Check(cache.TryClaim(now), "First check should be allowed");
            Check(!cache.TryClaim(now.AddHours(23)), "Restarts must retain daily throttle");
            cache.Complete(now, StoreUpdateState.Available);
            Check(new StoreUpdateCache(path, "2.1.5.1").Cached(now.AddHours(1)) == StoreUpdateState.Available,
                "Available indicator should survive a restart");
            var upgraded = new StoreUpdateCache(path, "2.1.6.1");
            Check(upgraded.Cached(now) == StoreUpdateState.NotChecked && !upgraded.TryClaim(now.AddHours(1)),
                "Upgrade clears old badge without resetting the throttle");
            Check(cache.Cached(now.AddDays(1)) == StoreUpdateState.NotChecked, "Stale status must expire");
            Check(cache.TryClaim(now.AddDays(1)), "A resident tray app may recheck after one day");
            cache.Complete(now, StoreUpdateState.Available);
            Check(cache.Cached(now.AddDays(1)) == StoreUpdateState.NotChecked, "Old completion must not replace a later claim");
            cache.Complete(now.AddDays(1), StoreUpdateState.Unavailable);
            Check(cache.Cached(now.AddDays(1)) == StoreUpdateState.Unavailable, "Failure must not report up-to-date");
            Check(!cache.TryClaim(now.AddDays(1).AddMinutes(1)), "Failure must also be throttled");
            Check(cache.Cached(now.AddYears(-1)) == StoreUpdateState.NotChecked, "Implausible future timestamp is invalid");
            using (var locked = new FileStream(path + ".lock", FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None))
            {
                bool denied = false;
                try { cache.TryClaim(now.AddDays(2)); } catch (IOException) { denied = true; }
                Check(denied, "Concurrent claim must fail closed");
            }
            File.WriteAllText(path, "Build=2.1.5.1\nAttemptUtc=bad\nState=Available\n");
            Check(cache.Cached(now) == StoreUpdateState.NotChecked && cache.TryClaim(now), "Corrupt cache can recover");
            cache.Complete(now, StoreUpdateState.NoUpdate);
            Check(cache.Cached(now) == StoreUpdateState.NoUpdate, "Empty successful query has its own state");
            File.WriteAllText(path, new string('x', 5000));
            Check(cache.Cached(now) == StoreUpdateState.NotChecked, "Oversized cache is ignored");

            int calls = 0;
            var result = await StoreUpdateCheck.RunAsync(token => {
                calls++; return Task.FromResult(StoreUpdateState.Available);
            }, 1000, CancellationToken.None);
            Check(result == StoreUpdateState.Available && calls == 1, "Available query");
            result = await StoreUpdateCheck.RunAsync(token => Task.FromResult(StoreUpdateState.NoUpdate), 1000, CancellationToken.None);
            Check(result == StoreUpdateState.NoUpdate, "No-update query");
            result = await StoreUpdateCheck.RunAsync(token => { throw new IOException("offline"); }, 1000, CancellationToken.None);
            Check(result == StoreUpdateState.Unavailable, "Offline must be non-fatal");
            var fault = new TaskCompletionSource<StoreUpdateState>(); fault.SetException(new InvalidOperationException("Store service unavailable"));
            result = await StoreUpdateCheck.RunAsync(token => fault.Task, 1000, CancellationToken.None);
            Check(result == StoreUpdateState.Unavailable, "Async Store failure must be observed");
            var late = new TaskCompletionSource<StoreUpdateState>(); bool cancelled = false;
            var clock = Stopwatch.StartNew();
            result = await StoreUpdateCheck.RunAsync(token => { token.Register(() => cancelled = true); return late.Task; }, 50, CancellationToken.None);
            Check(result == StoreUpdateState.Unavailable && cancelled && clock.ElapsedMilliseconds < 3000,
                "Timeout must finish even if the provider ignores cancellation");
            late.SetException(new IOException("late provider fault"));
            using (var lifetime = new CancellationTokenSource())
            {
                lifetime.Cancel();
                result = await StoreUpdateCheck.RunAsync(token => { calls++; return late.Task; }, 1000, lifetime.Token);
                Check(result == StoreUpdateState.Unavailable && calls == 1, "Disposed owner must not start a query");
            }
            Check(!StoreUpdateCheck.Eligible(false), "Portable must not call Store");
#if UI_PREVIEW
            Check(!StoreUpdateCheck.Eligible(true), "UI preview must not call Store");
#else
            Check(StoreUpdateCheck.Eligible(true), "Production Store package should be eligible");
#endif
            foreach (StoreUpdateState state in Enum.GetValues(typeof(StoreUpdateState)))
            {
                Check(CompanionDistribution.UpdateButtonText(false, state) == "Check for Updates", "Portable wording is unchanged");
                Check(CompanionDistribution.UpdateButtonText(true, state) == (state == StoreUpdateState.Available ? "Update available…" : "Store Updates"), "Store action state");
            }
            Check(CompanionDistribution.StoreUpdateTip(StoreUpdateState.Unavailable).Contains("unavailable"), "Failure explanation in tooltip");
        }

        [STAThread]
        public static void Main()
        {
            string directory = Path.Combine(Path.GetTempPath(), "Offhand-StoreUpdates-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(directory);
            try
            {
                VerifyAsync(directory).GetAwaiter().GetResult();
                var staticFlags = BindingFlags.Static | BindingFlags.NonPublic;
                typeof(CompanionForm).GetField("configPath", staticFlags).SetValue(null, Path.Combine(directory, "FixtureConfig.ini"));
                typeof(CompanionForm).GetField("publicConfigPath", staticFlags).SetValue(null, Path.Combine(directory, "FixtureConfig.ini"));
                foreach (float factor in new[] { 1f, 1.25f, 1.5f, 1.75f, 2f })
                {
                    var flags = BindingFlags.Instance | BindingFlags.NonPublic;
                    var formType = typeof(CompanionForm);
                    // Do not show the form or start its OnShown scheduler. Only
                    // inject Store routing for the passive presentation checks.
                    using (var form = new CompanionForm())
                    {
                        formType.GetField("isStorePackage", flags).SetValue(form, true);
                        form.CreateControl(); form.Scale(new SizeF(factor, factor)); form.PerformLayout();
                        var button = (Button)formType.GetField("btnCheckUpdates", flags).GetValue(form);
                        var tray = (ToolStripMenuItem)formType.GetField("itemCheckUpdates", flags).GetValue(form);
                        var bounds = form.Bounds; var buttonBounds = button.Bounds;
                        var apply = formType.GetMethod("ApplyStoreUpdateState", flags);
                        foreach (StoreUpdateState state in Enum.GetValues(typeof(StoreUpdateState)))
                        {
                            apply.Invoke(form, new object[] { state });
                            Check(button.Enabled && button.AccessibleName == button.Text, "Status remains an accessible action");
                            Check(TextRenderer.MeasureText(button.Text, button.Font).Width + 12 <= button.Width,
                                "Update caption must fit at " + factor);
                            Check(form.Bounds == bounds && button.Bounds == buttonBounds, "Notification must not resize dashboard");
                            Check(tray.Text.Contains("available") == (state == StoreUpdateState.Available), "Tray agrees with passive button");
                        }
                        formType.GetField("isStorePackage", flags).SetValue(form, false);
                    }
                }
                var instanceFlags = BindingFlags.Instance | BindingFlags.NonPublic;
                var typeOfForm = typeof(CompanionForm);
                var shown = typeOfForm.GetMethod("OnShown", instanceFlags);
                using (var form = new CompanionForm())
                {
                    int queries = 0;
                    typeOfForm.GetField("storeUpdateQuery", instanceFlags).SetValue(form,
                        new Func<IntPtr, CancellationToken, Task<StoreUpdateState>>((window, token) => {
                            queries++; return Task.FromResult(StoreUpdateState.Available);
                        }));
                    shown.Invoke(form, new object[] { EventArgs.Empty });
                    Check(typeOfForm.GetField("storeUpdateTimer", instanceFlags).GetValue(form) == null, "Portable OnShown must not schedule");
                    typeOfForm.GetField("isStorePackage", instanceFlags).SetValue(form, true);
                    shown.Invoke(form, new object[] { EventArgs.Empty });
                    var timer = (System.Windows.Forms.Timer)typeOfForm.GetField("storeUpdateTimer", instanceFlags).GetValue(form);
#if UI_PREVIEW
                    Check(timer == null && queries == 0, "Preview OnShown must not schedule");
#else
                    Check(timer != null && timer.Interval == 30000 && queries == 0, "Store startup only schedules a delayed check");
                    typeof(System.Windows.Forms.Timer).GetMethod("OnTick", instanceFlags).Invoke(timer, new object[] { EventArgs.Empty });
                    Check(queries == 1 && timer.Interval > 23 * 60 * 60 * 1000, "Completed check reschedules at daily cadence");
                    var button = (Button)typeOfForm.GetField("btnCheckUpdates", instanceFlags).GetValue(form);
                    Check(button.Text == "Update available…", "Real timer completion updates passive UI");
                    typeof(System.Windows.Forms.Timer).GetMethod("OnTick", instanceFlags).Invoke(timer, new object[] { EventArgs.Empty });
                    Check(queries == 1, "Repeated timer callbacks cannot bypass cache throttle");
#endif
                    typeOfForm.GetField("isStorePackage", instanceFlags).SetValue(form, false);
                }
#if !UI_PREVIEW
                typeOfForm.GetField("configPath", staticFlags).SetValue(null, Path.Combine(directory, "Shutdown", "FixtureConfig.ini"));
                var delayed = new TaskCompletionSource<StoreUpdateState>(); bool stopped = false;
                using (var form = new CompanionForm())
                {
                    typeOfForm.GetField("isStorePackage", instanceFlags).SetValue(form, true);
                    typeOfForm.GetField("storeUpdateQuery", instanceFlags).SetValue(form,
                        new Func<IntPtr, CancellationToken, Task<StoreUpdateState>>((window, token) => {
                            token.Register(() => stopped = true); return delayed.Task;
                        }));
                    shown.Invoke(form, new object[] { EventArgs.Empty });
                    var timer = (System.Windows.Forms.Timer)typeOfForm.GetField("storeUpdateTimer", instanceFlags).GetValue(form);
                    var button = (Button)typeOfForm.GetField("btnCheckUpdates", instanceFlags).GetValue(form);
                    typeof(System.Windows.Forms.Timer).GetMethod("OnTick", instanceFlags).Invoke(timer, new object[] { EventArgs.Empty });
                    form.Dispose(); delayed.SetResult(StoreUpdateState.Available);
                    Application.DoEvents();
                    Check(stopped && button.Text == "Store Updates", "Disposed dashboard cancels work and ignores late availability");
                }
#endif
                // Real local Windows metadata binding, not a mocked Store query.
                try
                {
                    var type = Type.GetType("Windows.Services.Store.StoreContext, Windows, ContentType=WindowsRuntime", true);
                    var method = type.GetMethod("GetAppAndOptionalStorePackageUpdatesAsync");
                    var adapter = StoreUpdateRuntime.TaskAdapter(method.ReturnType.GetGenericArguments()[0]);
                    Check(adapter != null && typeof(Task).IsAssignableFrom(adapter.ReturnType), "OS async projection must bind");
                    using (var owner = new Form())
                    {
                        var handle = owner.Handle;
                        object context = type.GetMethod("GetDefault").Invoke(null, null);
                        var ownerInterface = typeof(StoreUpdateRuntime).GetNestedType("IInitializeWithWindow", BindingFlags.NonPublic);
                        ownerInterface.GetMethod("Initialize").Invoke(context, new object[] { handle });
                        Check(true, "StoreContext accepts the actual desktop owner window");
                    }
                }
                catch (Exception error)
                {
                    // Server CI can lack Store activation. Do not disguise an
                    // incorrect interface, signature or unexpected HRESULT.
                    while (error is TargetInvocationException && error.InnerException != null) error = error.InnerException;
                    if (!(error is FileNotFoundException) && !(error is TypeLoadException)
                        && !(error is PlatformNotSupportedException)
                        && error.HResult != unchecked((int)0x80040154) && error.HResult != unchecked((int)0x80070032)) throw;
                    Console.WriteLine("SKIP: native Store binding unavailable on this OS (0x" + error.HResult.ToString("X8") + ").");
                }
                Console.WriteLine("PASS: " + count + " Store update cache, timing, cancellation, routing and OS binding checks (no availability request made).");
            }
            finally { Directory.Delete(directory, true); }
        }
    }
}
