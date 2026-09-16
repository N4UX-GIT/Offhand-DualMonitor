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
                Console.WriteLine("PASS: missing/malformed settings, duplicate keys, delay bounds and overflow");
            } finally { if (File.Exists(file)) File.Delete(file); Directory.Delete(root); }
        }
    }
}
