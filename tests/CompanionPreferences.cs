using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
namespace Offhand.Companion {
    internal static class PreferencesTest {
        private static int checkNumber;
        private static void Check(bool value) { checkNumber++; if (!value) throw new Exception("Preference regression at check " + checkNumber); }
        public static void Main() {
            Check(!CompanionDefaults.AutoSpanOnLaunch);
            var displays = new List<MonitorSelection.Display> {
                new MonitorSelection.Display { Index = 0, DeviceName = @"\\.\DISPLAY1", Bounds = new Rectangle(0, 0, 3440, 1440), Primary = true },
                new MonitorSelection.Display { Index = 1, DeviceName = @"\\.\DISPLAY2", Bounds = new Rectangle(-1920, 360, 1920, 1080), Primary = false }
            };
            var plan = MonitorSelection.CreatePlan(@"\\.\DISPLAY1|\\.\DISPLAY2", null, @"\\.\DISPLAY1", false, false, displays);
            Check(plan.Indices.Length == 2 && plan.MainhandBounds.Width == 3440 && plan.WorkspaceBounds.Height == 1080);
            bool missingRejected = false;
            try { MonitorSelection.CreatePlan(@"\\.\DISPLAY1|\\.\DISPLAY3", null, @"\\.\DISPLAY1", false, false, displays); }
            catch (InvalidOperationException) { missingRejected = true; }
            Check(missingRejected);
            bool singleRejected = false;
            try { MonitorSelection.CreatePlan(@"\\.\DISPLAY1", null, @"\\.\DISPLAY1", false, false, displays); }
            catch (InvalidOperationException) { singleRejected = true; }
            Check(singleRejected);
            var splitPlan = MonitorSelection.CreatePlan(@"\\.\DISPLAY1", null, @"\\.\DISPLAY1", true, false, displays);
            Check(splitPlan.SplitSingle && splitPlan.WorkspaceBounds.Width == 1720 && splitPlan.MainhandBounds.Left == 1720);
            var reordered = new List<MonitorSelection.Display> { displays[1], displays[0] };
            var reorderedPlan = MonitorSelection.CreatePlan(@"\\.\DISPLAY1|\\.\DISPLAY2", null, @"\\.\DISPLAY1", false, false, reordered);
            Check(reorderedPlan.MainhandIndex == 1 && reorderedPlan.MainhandBounds.Width == 3440);
            var stacked = new List<MonitorSelection.Display> {
                new MonitorSelection.Display { Index = 0, DeviceName = @"\\.\DISPLAY4", Bounds = new Rectangle(-200, -1080, 1920, 1080), Primary = false },
                new MonitorSelection.Display { Index = 1, DeviceName = @"\\.\DISPLAY5", Bounds = new Rectangle(0, 0, 2560, 1440), Primary = true }
            };
            var stackedPlan = MonitorSelection.CreatePlan(@"\\.\DISPLAY4|\\.\DISPLAY5", null, @"\\.\DISPLAY5", false, false, stacked);
            Check(stackedPlan.Bounds.X == -200 && stackedPlan.Bounds.Y == -1080 && stackedPlan.Bounds.Width == 2760 && stackedPlan.Bounds.Height == 2520);
            Check(stackedPlan.MainhandBounds.Height == 1440 && stackedPlan.WorkspaceBounds.Bottom == 0);
            bool tooManyRejected = false;
            var three = new List<MonitorSelection.Display>(displays);
            three.Add(new MonitorSelection.Display { Index = 2, DeviceName = @"\\.\DISPLAY3", Bounds = new Rectangle(3440, 0, 1920, 1080) });
            try { MonitorSelection.CreatePlan(null, null, null, false, false, three); }
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
                Directory.CreateDirectory(Path.GetDirectoryName(account));
                Directory.CreateDirectory(Path.GetDirectoryName(character));
                File.WriteAllText(account, "\r\nOffhandDB = { [\"profiles\"] = { [\"Default\"] = {} } }\n");
                File.WriteAllText(character, "OffhandCharDB = { [\"activeProfile\"] = \"Default\" }\n");
                string bridgeMessage;
                Check(ForeverStateBridge.TryRefresh(wow, out bridgeMessage));
                string bridge = File.ReadAllText(Path.Combine(core, "ForeverState.lua"));
                Check(bridge.Contains("OffhandForeverStateBridgeVersion = \"") &&
                    bridge.Contains("OffhandDB = {") && bridge.Contains("OffhandCharDB = {") &&
                    bridge.Contains("interfaceVersion >= 16000"));
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
                Console.WriteLine("PASS: safe display identities, missing-monitor guard, topology bridge, settings validation, restore geometry and atomic Forever state generation");
            } finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
        }
    }
}
