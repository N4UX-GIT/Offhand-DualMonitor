using System;
using System.Diagnostics;
using System.IO;

namespace Offhand.Companion
{
    internal static class ForeverRecoveryTest
    {
        private delegate bool RefreshBridge(string directory, out string message);

        private static void Check(bool condition, string message)
        {
            if (!condition) throw new Exception(message);
        }

        private static string LuaString(string value)
        {
            return "\"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
        }

        private static void Write(string path, string value)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            File.WriteAllText(path, value);
        }

        public static void Main(string[] args)
        {
#if PACKAGED_COMPANION
            var assembly = System.Reflection.Assembly.LoadFrom(args[2]);
            var bridgeType = assembly.GetType("Offhand.Companion.ForeverStateBridge", true);
            var method = bridgeType.GetMethod("TryRefresh",
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static,
                null, new[] { typeof(string), typeof(string).MakeByRefType() }, null);
            var refresh = (RefreshBridge)
                Delegate.CreateDelegate(typeof(RefreshBridge), method);
#else
            RefreshBridge refresh = ForeverStateBridge.TryRefresh;
#endif
            string root = Path.Combine(Path.GetTempPath(), "Offhand-recovery-" + Guid.NewGuid().ToString("N"));
            try
            {
                string wow = Path.Combine(root, "wow");
                string core = Path.Combine(wow, "Interface", "AddOns", "Offhand", "Core");
                Directory.CreateDirectory(core);
                string account = Path.Combine(wow, "WTF", "Account", "TestAccount");
                string moon = Path.Combine(account, "Realm", "Moon", "SavedVariables", "Offhand.lua");
                string naux = Path.Combine(account, "Realm", "Naux", "SavedVariables", "Offhand.lua");
                Write(Path.Combine(account, "SavedVariables", "Offhand.lua"),
                    "OffhandDB = { foreverPersistenceRevision = 5, profiles = { Default = {}, Moon = {}, Naux = {} } }\n");
                Write(moon, "OffhandCharDB = { characterGUID = \"Player-Moon\", activeProfile = \"Moon\" }\n");
                Write(naux, "OffhandCharDB = { characterGUID = \"Player-Naux\", activeProfile = \"Naux\" }\n");
                File.SetLastWriteTimeUtc(naux, DateTime.UtcNow.AddMinutes(1));
                Write(Path.Combine(account, "Realm", "Invalid", "SavedVariables", "Offhand.lua"), "malformed fixture");
                Write(Path.Combine(account, "Realm", "InvalidType", "SavedVariables", "Offhand.lua"), "OffhandCharDB = false\n");
                Write(Path.Combine(account, "Nested", "Offhand.lua"), "OffhandCharDB = { marker = \"INVALID_DEPTH\" }");
                string otherAccount = Path.Combine(wow, "WTF", "Account", "OtherAccount", "SavedVariables", "Offhand.lua");
                Write(otherAccount, "OffhandDB = { marker = \"OTHER_ACCOUNT\" }");
                File.SetLastWriteTimeUtc(otherAccount, DateTime.UtcNow.AddDays(-1));
                Write(Path.Combine(wow, "WTF", "Account", "OtherAccount", "Realm", "Other", "SavedVariables", "Offhand.lua"),
                    "OffhandCharDB = { characterGUID = \"Player-Other\", marker = \"OTHER_CHARACTER\" }");

                string message;
                Check(refresh(wow, out message), message);
                string bridgePath = Path.Combine(core, "ForeverState.lua");
                string bridge = File.ReadAllText(bridgePath);
                Check(bridge.Contains("schema = 1") && bridge.Contains("local OffhandCharDB"), "Missing scoped payload");
                Check(bridge.Contains("Player-Moon") && bridge.Contains("Player-Naux"), "Lost a character record");
                Check(!bridge.Contains("OTHER_CHARACTER") && !bridge.Contains("OTHER_ACCOUNT")
                    && !bridge.Contains("INVALID_DEPTH"), "Recovery crossed the selected account or path boundary");
                Check(refresh(wow, out message) && message.Contains("current"), "Unchanged bridge rewritten");

                foreach (string name in new[] { "Moon", "Naux", "LateIdentity", "Unknown", "NoIdentity", "Consumed", "Retail" })
                {
                    string driver = Path.Combine(root, name + ".lua");
                    string identity = name == "NoIdentity" || name == "LateIdentity" ? "nil" : LuaString("Player-" + name);
                    string expected = name == "LateIdentity" ? "Moon" : name == "Moon" || name == "Naux" ? name : "Default";
                    File.WriteAllText(driver,
                        "local cvars = {}\n" +
                        "RegisterCVar = function(k,v) if cvars[k] == nil then cvars[k] = v end end\n" +
                        "SetCVar = function(k,v) cvars[k] = tostring(v) end\n" +
                        "GetCVar = function(k) " + (name == "Consumed" ? "if k == 'offhandForeverRecoveryVersion' then return OffhandForeverStateBridgeVersion end " : "") + "return cvars[k] end\n" +
                        "GetBuildInfo = function() return '1.60.1', '70959', '', " + (name == "Retail" ? "120000" : "16001") + " end\n" +
                        "UnitGUID = function() return " + identity + " end\n" +
                        "UnitName = function() return " + LuaString(name) + " end\n" +
                        "OffhandCharDB = { activeProfile = 'Default' }; local disk = OffhandCharDB\n" +
                        "OffhandDB = {}; Offhand = { isForever = " + (name == "Retail" ? "false" : "true") + ", foreverDiskSavedVariables = { account = OffhandDB, character = disk } }\n" +
                        "assert(loadfile(" + LuaString(bridgePath) + "))()\n" +
                        (name == "LateIdentity" ? "UnitGUID = function() return 'Player-Moon' end\n" : "") +
                        "assert(loadfile(" + LuaString(args[1]) + "))('Offhand', Offhand)\n" +
                        "Offhand:InitializeConfig()\n" +
                        "assert(OffhandCharDB.activeProfile == " + LuaString(expected) + ", 'wrong recovery profile')\n" +
                        (expected == "Default" ? "assert(OffhandCharDB == disk, 'discarded current disk character')\n" : "assert(OffhandCharDB.characterGUID == " + LuaString("Player-" + expected) + ")\n") +
                        (name != "Retail" ? "assert(OffhandForeverCharacterRecovery == nil, 'retained other characters in memory')\n" : "") +
                        "print('PASS: generated bridge " + name + "')\n");
                    var start = new ProcessStartInfo(args[0], "\"" + driver + "\"")
                    { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true };
                    using (var process = Process.Start(start))
                    {
                        string output = process.StandardOutput.ReadToEnd();
                        string error = process.StandardError.ReadToEnd();
                        process.WaitForExit();
                        Check(process.ExitCode == 0 && output.Contains("PASS: generated bridge " + name),
                            "Generated Lua recovery failed for " + name + ": " + output + error);
                        Console.Write(output);
                    }
                }

                string previous = bridge;
                File.AppendAllText(moon, "-- changed character snapshot\n");
                Check(refresh(wow, out message), message);
                Check(File.ReadAllText(bridgePath) != previous && File.ReadAllText(bridgePath + ".bak") == previous,
                    "Changed character state did not update atomically with a backup");
                File.Delete(moon);
                File.Delete(naux);
                Check(refresh(wow, out message), "Account-only recovery failed");
                Check(!File.ReadAllText(bridgePath).Contains("Player-Moon"), "Removed character retained in new bridge");
                Console.WriteLine("PASS: multi-character Companion generation, Lua execution, account boundaries and atomic updates");
            }
            finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
        }
    }
}
