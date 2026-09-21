using System;
using System.IO;
namespace Offhand.Companion {
    internal static class PreferencesTest {
        private static void Check(bool value) { if (!value) throw new Exception("Preference regression"); }
        public static void Main() {
            Check(MonitorSelection.Resolve(null, 3).Length == 3);
            Check(MonitorSelection.Resolve("2,2,0,99,bad", 3).Length == 2);
            Check(CompanionTiming.AutoSpanDelay("WowB", @"D:\Games\World of Warcraft\_classic_beta_", 30) == 0);
            Check(CompanionTiming.AutoSpanDelay("Wow", @"D:\Games\World of Warcraft\_retail_", 30) == 30);
            foreach (string invalid in new string[] { "", "99", "bad" }) {
                bool rejected = false;
                try { MonitorSelection.Resolve(invalid, 3); } catch (InvalidOperationException) { rejected = true; }
                Check(rejected);
            }
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
                Console.WriteLine("PASS: settings validation, restore geometry and atomic Forever state generation");
            } finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
        }
    }
}
