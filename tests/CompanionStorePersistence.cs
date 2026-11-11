using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;

namespace Offhand.Companion
{
    internal static class StorePersistenceTest
    {
        private static int checks;
        private static void Check(bool condition, string message)
        { checks++; if (!condition) throw new Exception(message); }

        private static void Exercise(string root)
        {
            Directory.CreateDirectory(root);
            string legacy = Path.Combine(root, "legacy.ini"), current = Path.Combine(root, "current.ini");
            string portable = Path.Combine(root, "portable.ini");
            File.WriteAllText(legacy, "UnknownFutureKey=kept\r\nDelaySpan=30\r\nName=ø漢字\r\n");
            File.WriteAllText(portable, "DelaySpan=15\r\n");
            byte[] original = File.ReadAllBytes(legacy);
            Check(CompanionSettingsPath.ReadSource(current, legacy, portable) == legacy, "Upgrade did not select legacy settings.");
            var settings = PreferenceFile.Read(legacy);
            bool failed = false;
            try { PreferenceFile.Write(current, settings, staged => { throw new IOException("interrupted import"); }); }
            catch (IOException ex) { failed = ex.Message.Contains("validating the new settings"); }
            Check(failed && !File.Exists(current), "Interrupted import published settings or lost diagnostics.");
            Check(CompanionSettingsPath.ReadSource(current, legacy, portable) == legacy, "Interrupted import lost the original source.");
            for (int i = 0; i < 5; i++)
            {
                settings["DelaySpan"] = i.ToString();
                PreferenceFile.Write(current, settings);
                var reloaded = PreferenceFile.Read(current);
                Check(reloaded["DelaySpan"] == i.ToString() && reloaded["UnknownFutureKey"] == "kept"
                    && reloaded["Name"] == "ø漢字", "Repeated settings saves lost data.");
            }
            Check(SpanRollback.SameBytes(original, File.ReadAllBytes(legacy)), "Legacy settings changed during import.");
            Check(CompanionSettingsPath.ReadSource(current, legacy, portable) == current, "Current Store settings were overridden by legacy data.");
            Check(CompanionSettingsPath.ReadSource(Path.Combine(root,"absent"), Path.Combine(root,"also-absent"), portable) == portable,
                "Portable fallback changed.");

            string stagedFile = current + ".pending-fallback";
            File.WriteAllText(stagedFile, "replacement");
            PreferenceFile.ReplaceExisting(stagedFile, current,
                (source, target) => { throw new IOException("The parameter is incorrect.", unchecked((int)0x80070057)); });
            Check(File.ReadAllText(current) == "replacement" && !File.Exists(stagedFile), "Error 87 compatibility publication failed.");
            foreach (int error in new[] { 5, 32, 112 })
            {
                File.WriteAllText(stagedFile, "must not be published");
                bool refused = false;
                try { PreferenceFile.ReplaceExisting(stagedFile, current,
                    (source, target) => { throw new IOException("injected rejection", unchecked((int)(0x80070000U | (uint)error))); }); }
                catch (IOException) { refused = true; }
                Check(refused && File.ReadAllText(current) == "replacement" && File.Exists(stagedFile),
                    "Non-87 failure unexpectedly used compatibility publication: " + error);
            }
            bool denied = false;
            try { PreferenceFile.ReplaceExisting(stagedFile, current,
                (source, target) => { throw new UnauthorizedAccessException("injected access denial"); }); }
            catch (UnauthorizedAccessException) { denied = true; }
            Check(denied && File.ReadAllText(current) == "replacement", "Access denial was bypassed.");
            string other = Path.Combine(root, "other"); Directory.CreateDirectory(other);
            string otherStaged = Path.Combine(other, "pending"); File.WriteAllText(otherStaged, "must stay staged");
            bool crossDirectory = false;
            try { PreferenceFile.ReplaceExisting(otherStaged, current,
                (source, target) => { throw new IOException("injected error 87", unchecked((int)0x80070057)); }); }
            catch (IOException) { crossDirectory = true; }
            Check(crossDirectory && File.Exists(otherStaged) && File.ReadAllText(current) == "replacement",
                "Compatibility publication accepted a different directory.");
            bool locked = false;
            using (var handle = new FileStream(current, FileMode.Open, FileAccess.Read, FileShare.None))
            {
                try { PreferenceFile.ReplaceExisting(stagedFile, current,
                    (source, target) => { throw new IOException("injected error 87", unchecked((int)0x80070057)); }); }
                catch (IOException) { locked = true; }
            }
            Check(locked && File.ReadAllText(current) == "replacement", "Compatibility publication damaged a locked target.");
            File.Delete(stagedFile);
            PreferenceFile.Write(current, settings);
            byte[] lastGood = File.ReadAllBytes(current);
            using (var handle = new FileStream(current, FileMode.Open, FileAccess.Read, FileShare.None))
            {
                bool rejected = false;
                try { PreferenceFile.Write(current, settings); } catch (IOException ex) { rejected = ex.Message.Contains("replacing saved settings"); }
                Check(rejected, "Locked normal write did not retain operation diagnostics.");
            }
            Check(SpanRollback.SameBytes(lastGood, File.ReadAllBytes(current)), "Failed save changed last good preferences.");
            Check(Directory.GetFiles(root, "*.pending-*").Length == 0, "Failed save leaked a staging file.");
        }

        [STAThread]
        private static void Main(string[] args)
        {
            var output = new StringBuilder();
            try
            {
                string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                string family = CompanionDistribution.PackageFamilyName();
                Check(CompanionDistribution.IsStorePackage() == (family != null), "Package identity detection disagrees.");
                Check(CompanionSettingsPath.Resolve(local, null) == Path.Combine(local,"Offhand","OffhandConfig.ini"), "Portable settings path changed.");
                Check(CompanionSettingsPath.Resolve(local, "Example_family") == Path.Combine(local,"Packages","Example_family","LocalState","OffhandConfig.ini"),
                    "Store settings path is not package-local.");
                bool invalid = false;
                try { CompanionSettingsPath.Resolve(local, "../escape"); } catch (InvalidDataException) { invalid = true; }
                Check(invalid, "Invalid package identity escaped the data directory.");
                string run = "Offhand-Persistence-" + Guid.NewGuid().ToString("N");
                Exercise(Path.Combine(args[0], run));
                if (family != null)
                {
                    string actual = CompanionSettingsPath.Resolve(local, family);
                    var config = typeof(CompanionForm).GetField("configPath", BindingFlags.NonPublic | BindingFlags.Static);
                    Check((string)config.GetValue(null) == actual, "Production config path did not use package-local data.");
                    Exercise(Path.Combine(Path.GetDirectoryName(actual), "PersistenceTests", run));
                }
                output.AppendLine("PASS: " + checks + " persistence checks; package=" + (family ?? "portable"));
                output.AppendLine("Legacy import, Unicode/unknown keys, repeated saves, interruption, locks, error-87 publication, and failure preservation verified.");
            }
            catch (Exception ex) { output.AppendLine(ex.ToString()); Environment.ExitCode = 1; }
            File.WriteAllText(Path.Combine(args[0], "store-persistence-result.txt"), output.ToString());
            Console.Write(output);
        }
    }
}
