using System;
using System.Collections.Generic;
using System.Drawing;

namespace Offhand.Companion
{
    internal static class DisplaySelectionTest
    {
        private static int checks;
        private static void Check(bool value, string label)
        {
            checks++;
            if (!value) throw new Exception(label);
        }
        private static void Reject(Action action, string expected)
        {
            try { action(); }
            catch (InvalidOperationException error)
            {
                Check(error.Message.IndexOf(expected, StringComparison.OrdinalIgnoreCase) >= 0,
                    "Wrong error: " + error.Message);
                return;
            }
            throw new Exception("Expected refusal: " + expected);
        }
        private static List<MonitorSelection.Display> Pair()
        {
            return new List<MonitorSelection.Display> {
                new MonitorSelection.Display { Index=0, DeviceName="DISPLAY1", StableId="INTERFACE-A",
                    Bounds=new Rectangle(0,0,2560,1440), Primary=true },
                new MonitorSelection.Display { Index=1, DeviceName="DISPLAY2", StableId="INTERFACE-B",
                    Bounds=new Rectangle(-1440,0,1440,2560) }
            };
        }
        private static MonitorSelection.Plan Plan(List<MonitorSelection.Display> displays,
            string identities, string mainhand, bool split)
        {
            return MonitorSelection.CreatePlan(identities, "DISPLAY1|DISPLAY2", null,
                mainhand, "DISPLAY1", split, false, displays);
        }
        internal static void Main()
        {
            var pair = Pair();
            var plan = Plan(pair, "INTERFACE-A|INTERFACE-B", "INTERFACE-B", false);
            Check(plan.Indices.Length == 2 && plan.MainhandIndex == 1, "Distinct pair/Mainhand");
            Check(plan.MainhandBounds == pair[1].Bounds, "Mainhand geometry preserved");
            pair.Reverse();
            Check(Plan(pair, "INTERFACE-A|INTERFACE-B", "INTERFACE-B", false).MainhandIndex == 0,
                "Enumeration reorder must preserve physical Mainhand");
            pair[0].DeviceName = "DISPLAY1";
            pair[1].DeviceName = "DISPLAY2";
            Check(Plan(pair, "INTERFACE-A|INTERFACE-B", "INTERFACE-B", false).MainhandIndex == 0,
                "Windows device renumbering must preserve physical Mainhand");

            pair = Pair();
            pair[1].StableId = "interface-a";
            Reject(() => Plan(pair, "INTERFACE-A|INTERFACE-A", "INTERFACE-A", false), "same monitor identity");
            Reject(() => Plan(pair, "INTERFACE-A|INTERFACE-A", "INTERFACE-A", true), "same monitor identity");
            Check(MonitorSelection.HasDisconnectedSavedDisplay("INTERFACE-A", null, pair),
                "Ambiguity must stop unattended spanning");
            Check(MonitorSelection.RecoveryDisplay("INTERFACE-A", "DISPLAY2", pair) == pair[0],
                "Ambiguous physical role recovers safely to primary");
            Reject(() => MonitorSelection.CreatePlan(null, "DISPLAY1|DISPLAY2", null,
                "INTERFACE-A", "DISPLAY1", false, false, pair), "Mainhand monitor identity is ambiguous");

            pair = Pair();
            Reject(() => Plan(pair, "INTERFACE-A|interface-a", "INTERFACE-A", false), "duplicate identities");
            Reject(() => Plan(pair, "INTERFACE-A|MISSING", "INTERFACE-A", false), "disconnected");
            Reject(() => Plan(pair, "INTERFACE-A|INTERFACE-B", "MISSING", false), "Mainhand display is unavailable");
            Reject(() => Plan(pair, "INTERFACE-A", "INTERFACE-B", true), "Mainhand display is unavailable");
            Reject(() => Plan(pair, "INTERFACE-A", "INTERFACE-A", false), "exactly two displays");
            Check(Plan(pair, "INTERFACE-A", "INTERFACE-A", true).SplitSingle, "Explicit single display split");
            pair.Add(new MonitorSelection.Display { Index=2, DeviceName="DISPLAY3", StableId="INTERFACE-C",
                Bounds=new Rectangle(2560,0,1920,1080) });
            Reject(() => Plan(pair, "INTERFACE-A|INTERFACE-B|INTERFACE-C", "INTERFACE-A", false), "exactly two displays");
            // An unchecked duplicate must not make a checked physical identity
            // appear unambiguous and permit roles to change after hotplug.
            pair[2].StableId = "INTERFACE-A";
            Reject(() => Plan(pair, "INTERFACE-A|INTERFACE-B", "INTERFACE-A", false), "same monitor identity");

            pair = Pair();
            pair[1].StableId = null;
            Reject(() => Plan(pair, "INTERFACE-A|INTERFACE-B", "INTERFACE-A", false), "disconnected");
            Check(MonitorSelection.HasDisconnectedSavedDisplay("INTERFACE-A|INTERFACE-B", null, pair),
                "Missing interface must stop unattended spanning");

            var settings = new Dictionary<string,string> {
                {"DisplayIdentityVersion","1"}, {"MonitorIdentities","OLD-ID|OLD-ID"},
                {"MainhandIdentity","OLD-ID"}, {"MonitorDevices","DISPLAY1|DISPLAY2"},
                {"MainhandDevice","DISPLAY2"}
            };
            Check(!MonitorSelection.HasCurrentIdentitySettings(settings), "Beta 20 requires review");
            settings["MonitorIdentities"] = "INTERFACE-A|INTERFACE-B";
            settings["MainhandIdentity"] = "INTERFACE-B";
            Check(!MonitorSelection.HasCurrentIdentitySettings(settings), "New strings cannot promote version 1");
            Check(settings["MonitorDevices"] == "DISPLAY1|DISPLAY2" && settings["MainhandDevice"] == "DISPLAY2",
                "Review detection must retain device preferences");
            settings["DisplayIdentityVersion"] = "2";
            Check(MonitorSelection.HasCurrentIdentitySettings(settings), "Reviewed current settings accepted");
            settings["MonitorIdentities"] = "INTERFACE-A|interface-a";
            Check(!MonitorSelection.HasCurrentIdentitySettings(settings), "Duplicate current settings rejected");
            settings["MonitorIdentities"] = "INTERFACE-A";
            Check(!MonitorSelection.HasCurrentIdentitySettings(settings), "Mainhand must belong to selection");
            settings["MonitorIdentities"] = "";
            Check(!MonitorSelection.HasCurrentIdentitySettings(settings), "Empty settings rejected");
            settings["MonitorIdentities"] = "INTERFACE-A|INTERFACE-B";
            settings["DisplayIdentityVersion"] = "99";
            Check(!MonitorSelection.HasCurrentIdentitySettings(settings), "Unknown schema cannot auto-span");
            settings.Remove("DisplayIdentityVersion");
            Check(!MonitorSelection.HasCurrentIdentitySettings(settings), "Partial save cannot auto-span");
            Console.WriteLine("PASS: " + checks + " display identity, ambiguity, role, missing-display and schema checks");
        }
    }
}
