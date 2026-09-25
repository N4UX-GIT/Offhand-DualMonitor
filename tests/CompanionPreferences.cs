using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
namespace Offhand.Companion {
    internal static class PreferencesTest {
        private static int checkNumber;
        private static void Check(bool value) { checkNumber++; if (!value) throw new Exception("Preference regression at check " + checkNumber); }
        public static void Main() {
            Check(CompanionForm.FullVersion == "2.1.2 Beta 9");
            Check(!CompanionDefaults.AutoSpanOnLaunch);
            Check(ProcessPathResolver.Get(null) == null);
            Check(!string.IsNullOrEmpty(ProcessPathResolver.Get(Process.GetCurrentProcess())));
            var displays = new List<MonitorSelection.Display> {
                new MonitorSelection.Display { Index = 0, DeviceName = @"\\.\DISPLAY1", StableId = @"MONITOR\MAIN\A", Bounds = new Rectangle(0, 0, 3440, 1440), WorkArea = new Rectangle(0, 0, 3440, 1400), Primary = true },
                new MonitorSelection.Display { Index = 1, DeviceName = @"\\.\DISPLAY2", StableId = @"MONITOR\WORK\B", Bounds = new Rectangle(-1920, 360, 1920, 1080), WorkArea = new Rectangle(-1920, 360, 1920, 1040), Primary = false }
            };
            var plan = MonitorSelection.CreatePlan(@"MONITOR\MAIN\A|MONITOR\WORK\B", @"\\.\DISPLAY1|\\.\DISPLAY2", null, @"MONITOR\MAIN\A", @"\\.\DISPLAY1", false, false, displays);
            Check(plan.Indices.Length == 2 && plan.MainhandBounds.Width == 3440 && plan.WorkspaceBounds.Height == 1080);
            bool missingRejected = false;
            try { MonitorSelection.CreatePlan(@"MONITOR\MAIN\A|MONITOR\MISSING\C", null, null, @"MONITOR\MAIN\A", null, false, false, displays); }
            catch (InvalidOperationException) { missingRejected = true; }
            Check(missingRejected);
            Check(MonitorSelection.HasDisconnectedSavedDisplay(@"MONITOR\MAIN\A|MONITOR\MISSING\C", null, displays));
            Check(!MonitorSelection.HasDisconnectedSavedDisplay(@"MONITOR\MAIN\A|MONITOR\WORK\B", null, displays));
            Check(MonitorSelection.RecoveryDisplay(@"MONITOR\MAIN\A", @"\\.\DISPLAY2", displays) == displays[0]);
            Check(MonitorSelection.RecoveryDisplay(@"MONITOR\MISSING\C", null, displays) == displays[0]);
            Check(MonitorSelection.SameDisplays(displays, new List<MonitorSelection.Display> {
                new MonitorSelection.Display { Index = 0, DeviceName = @"\\.\DISPLAY1", StableId = @"MONITOR\MAIN\A", Bounds = new Rectangle(0, 0, 3440, 1440), WorkArea = new Rectangle(0, 0, 3440, 1400), Primary = true },
                new MonitorSelection.Display { Index = 1, DeviceName = @"\\.\DISPLAY2", StableId = @"MONITOR\WORK\B", Bounds = new Rectangle(-1920, 360, 1920, 1080), WorkArea = new Rectangle(-1920, 360, 1920, 1040), Primary = false }
            }));
            Check(!MonitorSelection.SameDisplays(displays, new List<MonitorSelection.Display> { displays[0] }));
            bool singleRejected = false;
            try { MonitorSelection.CreatePlan(@"MONITOR\MAIN\A", null, null, @"MONITOR\MAIN\A", null, false, false, displays); }
            catch (InvalidOperationException) { singleRejected = true; }
            Check(singleRejected);
            var splitPlan = MonitorSelection.CreatePlan(@"MONITOR\MAIN\A", null, null, @"MONITOR\MAIN\A", null, true, false, displays);
            Check(splitPlan.SplitSingle && splitPlan.WorkspaceBounds.Width == 1720 && splitPlan.MainhandBounds.Left == 1720);
            var reordered = new List<MonitorSelection.Display> { displays[1], displays[0] };
            var reorderedPlan = MonitorSelection.CreatePlan(@"MONITOR\MAIN\A|MONITOR\WORK\B", null, null, @"MONITOR\MAIN\A", null, false, false, reordered);
            Check(reorderedPlan.MainhandIndex == 1 && reorderedPlan.MainhandBounds.Width == 3440);
            var renumbered = new List<MonitorSelection.Display> {
                new MonitorSelection.Display { Index = 0, DeviceName = @"\\.\DISPLAY1", StableId = @"MONITOR\WORK\B", Bounds = displays[1].Bounds, WorkArea = displays[1].WorkArea, Primary = false },
                new MonitorSelection.Display { Index = 1, DeviceName = @"\\.\DISPLAY2", StableId = @"MONITOR\MAIN\A", Bounds = displays[0].Bounds, WorkArea = displays[0].WorkArea, Primary = true }
            };
            var renumberedPlan = MonitorSelection.CreatePlan(@"MONITOR\MAIN\A|MONITOR\WORK\B", @"\\.\DISPLAY1|\\.\DISPLAY2", null, @"MONITOR\MAIN\A", @"\\.\DISPLAY1", false, false, renumbered);
            Check(renumberedPlan.MainhandIndex == 1 && renumberedPlan.MainhandBounds.Width == 3440);
            var stacked = new List<MonitorSelection.Display> {
                new MonitorSelection.Display { Index = 0, DeviceName = @"\\.\DISPLAY4", Bounds = new Rectangle(-200, -1080, 1920, 1080), Primary = false },
                new MonitorSelection.Display { Index = 1, DeviceName = @"\\.\DISPLAY5", Bounds = new Rectangle(0, 0, 2560, 1440), Primary = true }
            };
            var stackedPlan = MonitorSelection.CreatePlan(null, @"\\.\DISPLAY4|\\.\DISPLAY5", null, null, @"\\.\DISPLAY5", false, false, stacked);
            Check(stackedPlan.Bounds.X == -200 && stackedPlan.Bounds.Y == -1080 && stackedPlan.Bounds.Width == 2760 && stackedPlan.Bounds.Height == 2520);
            Check(stackedPlan.MainhandBounds.Height == 1440 && stackedPlan.WorkspaceBounds.Bottom == 0);
            bool tooManyRejected = false;
            var three = new List<MonitorSelection.Display>(displays);
            three.Add(new MonitorSelection.Display { Index = 2, DeviceName = @"\\.\DISPLAY3", Bounds = new Rectangle(3440, 0, 1920, 1080) });
            try { MonitorSelection.CreatePlan(null, null, null, null, null, false, false, three); }
            catch (InvalidOperationException) { tooManyRejected = true; }
            Check(tooManyRejected);
            Check(CompanionTiming.AutoSpanDelay("WowB", @"D:\Games\World of Warcraft\_classic_beta_", 30) == 0);
            Check(CompanionTiming.AutoSpanDelay("Wow", @"D:\Games\World of Warcraft\_retail_", 30) == 30);
            string root = Path.Combine(Path.GetTempPath(), "Offhand-preferences-" + Guid.NewGuid());
            Directory.CreateDirectory(root);
            string file = Path.Combine(root, "settings.ini");
            try {
                Check(PreferenceFile.Read(file).Count == 0);
                File.WriteAllText(file, "ignored\n=invalid\n DelaySpan = -200\nHotkey=F12\nDelaySpan=500\n");
                var settings = PreferenceFile.Read(file);
                Check(settings.Count == 2 && settings["Hotkey"] == "F12");
                Check(PreferenceFile.Delay(settings["DelaySpan"]) == 60);
                Check(PreferenceFile.Delay("-200") == 0);
                Check(PreferenceFile.Delay("garbage") == 15);
                Check(PreferenceFile.Delay("99999999999999999999999999999999999999") == 15);
                Check(PreferenceFile.Delay("30") == 30);
                var leftMonitor = new System.Drawing.Rectangle(-1440, -1120, 1440, 2520);
                var fit = RestoreGeometry.Fit(new System.Drawing.Rectangle(-1800, -1500, 1920, 3000), leftMonitor);
                Check(leftMonitor.Contains(fit) && fit.Width == 1440 && fit.Height == 2520);
                var work = new System.Drawing.Rectangle(0, 0, 1920, 1040);
                var remembered = new System.Drawing.Rectangle(120, 90, 1200, 800);
                Check(RestoreGeometry.Fit(remembered, work) == remembered);
                Check(work.Contains(RestoreGeometry.Fit(new System.Drawing.Rectangle(5000, 4000, 1920, 1080), work)));

                string wow = Path.Combine(root, "_classic_beta_");
                string core = Path.Combine(wow, "Interface", "AddOns", "Offhand", "Core");
                string account = Path.Combine(wow, "WTF", "Account", "123", "SavedVariables", "Offhand.lua");
                string character = Path.Combine(wow, "WTF", "Account", "123", "Realm", "Character", "SavedVariables", "Offhand.lua");
                Directory.CreateDirectory(core);
                File.WriteAllText(Path.Combine(Path.GetDirectoryName(core), "Offhand_Forever.toc"), "## Interface: 16000\n## X-Offhand-Release: beta.9\n");
                AddonInstallCheck install = AddonInstallation.Inspect(wow);
                Check(install.Installed && install.AddonDir == Path.GetDirectoryName(core));
                Check(install.ExpectedAddonDir == Path.Combine(wow, "Interface", "AddOns", "Offhand"));
                Check(install.ReleaseTag == "beta.9" && install.Reason.Contains(install.AddonDir));

                string oldWow = Path.Combine(root, "old-client");
                string oldAddon = Path.Combine(oldWow, "Interface", "AddOns", "Offhand");
                Directory.CreateDirectory(oldAddon);
                File.WriteAllText(Path.Combine(oldAddon, "Offhand_Forever.toc"), "## Interface: 16000\n## X-Offhand-Release: beta.8\n");
                AddonInstallCheck oldInstall = AddonInstallation.Inspect(oldWow);
                Check(!oldInstall.Installed && oldInstall.ReleaseTag == "beta.8"
                    && oldInstall.Reason.Contains("requires addon beta.9"));

                string nestedWow = Path.Combine(root, "nested");
                string nestedAddon = Path.Combine(nestedWow, "Interface", "AddOns", "Offhand", "Offhand");
                Directory.CreateDirectory(nestedAddon);
                File.WriteAllText(Path.Combine(nestedAddon, "Offhand_Forever.toc"), "## Interface: 16000\n");
                AddonInstallCheck nestedInstall = AddonInstallation.Inspect(nestedWow);
                Check(!nestedInstall.Installed && nestedInstall.Reason.Contains("Nested install found"));

                string versionedWow = Path.Combine(root, "versioned");
                string versionedAddon = Path.Combine(versionedWow, "Interface", "AddOns", "Offhand-v2.1.2-beta.9");
                Directory.CreateDirectory(versionedAddon);
                File.WriteAllText(Path.Combine(versionedAddon, "Offhand_Forever.toc"), "## Interface: 16000\n");
                AddonInstallCheck versionedInstall = AddonInstallation.Inspect(versionedWow);
                Check(!versionedInstall.Installed && versionedInstall.Reason.Contains("differently named folder")
                    && versionedInstall.Reason.Contains(versionedAddon));

                string otherClient = Path.Combine(root, "_retail_");
                Directory.CreateDirectory(otherClient);
                AddonInstallCheck siblingInstall = AddonInstallation.Inspect(otherClient);
                Check(!siblingInstall.Installed && siblingInstall.Reason.Contains("different WoW client")
                    && siblingInstall.Reason.Contains(Path.Combine(otherClient, "Interface", "AddOns", "Offhand")));
                Directory.CreateDirectory(Path.GetDirectoryName(account));
                Directory.CreateDirectory(Path.GetDirectoryName(character));
                File.WriteAllText(account, "\r\nOffhandDB = { [\"profiles\"] = { [\"Default\"] = {} } }\n");
                File.WriteAllText(character, "OffhandCharDB = { [\"activeProfile\"] = \"Default\" }\n");
                string bridgeMessage;
                Check(ForeverStateBridge.TryRefresh(wow, out bridgeMessage));
                string bridge = File.ReadAllText(Path.Combine(core, "ForeverState.lua"));
                Check(bridge.Contains("OffhandForeverStateBridgeVersion = \"") &&
                    bridge.Contains("OffhandDB = {") && bridge.Contains("OffhandCharDB = {") &&
                    bridge.Contains("interfaceVersion >= 16000") &&
                    bridge.Contains("offhandForeverRecoveryVersion") &&
                    bridge.Contains("if not consumed then"));
                Check(ForeverStateBridge.TryRefresh(wow, out bridgeMessage) && bridgeMessage.Contains("current"));
                string priorBridge = bridge;
                File.WriteAllText(character, "OffhandCharDB = { [\"activeProfile\"] = \"Other\" }\n");
                Check(ForeverStateBridge.TryRefresh(wow, out bridgeMessage));
                bridge = File.ReadAllText(Path.Combine(core, "ForeverState.lua"));
                Check(bridge != priorBridge && bridge.Contains("\"Other\""));
                string topologyMessage;
                Check(CompanionTopologyBridge.TryWrite(wow, plan, displays, out topologyMessage));
                string topology = File.ReadAllText(Path.Combine(core, "CompanionTopology.lua"));
                Check(topology.Contains("mode = \"DUAL_DISPLAY\"") && topology.Contains("width = 3440") &&
                    topology.Contains("height = 1080") && topology.Contains("y = 0"));
                Console.WriteLine("PASS: safe display identities, addon layout diagnosis, missing-monitor guard, topology bridge, settings validation, restore geometry and atomic Forever state generation");
            } finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
        }
    }
}
