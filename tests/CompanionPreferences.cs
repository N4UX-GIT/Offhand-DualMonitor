using System;
using System.IO;
namespace Offhand.Companion {
    internal static class PreferencesTest {
        private static void Check(bool value) { if (!value) throw new Exception("Preference regression"); }
        public static void Main() {
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
                Console.WriteLine("PASS: missing/malformed settings, duplicate keys, delay bounds and overflow");
            } finally { if (File.Exists(file)) File.Delete(file); Directory.Delete(root); }
        }
    }
}
