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
        [STAThread]
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
            Check(!MonitorSelection.HasStableIdentitySettings(settings), "Beta 20 requires review");
            settings["MonitorIdentities"] = "INTERFACE-A|INTERFACE-B";
            settings["MainhandIdentity"] = "INTERFACE-B";
            Check(!MonitorSelection.HasStableIdentitySettings(settings), "New strings cannot promote version 1");
            Check(settings["MonitorDevices"] == "DISPLAY1|DISPLAY2" && settings["MainhandDevice"] == "DISPLAY2",
                "Review detection must retain device preferences");
            settings["DisplayIdentityVersion"] = "2";
            Check(MonitorSelection.HasStableIdentitySettings(settings), "Reviewed current settings accepted");
            settings["MonitorIdentities"] = "INTERFACE-A|interface-a";
            Check(!MonitorSelection.HasStableIdentitySettings(settings), "Duplicate current settings rejected");
            settings["MonitorIdentities"] = "INTERFACE-A";
            Check(!MonitorSelection.HasStableIdentitySettings(settings), "Mainhand must belong to selection");
            settings["MonitorIdentities"] = "";
            Check(!MonitorSelection.HasStableIdentitySettings(settings), "Empty settings rejected");
            settings["MonitorIdentities"] = "INTERFACE-A|INTERFACE-B";
            settings["DisplayIdentityVersion"] = "99";
            Check(!MonitorSelection.HasStableIdentitySettings(settings), "Unknown schema cannot auto-span");
            settings.Remove("DisplayIdentityVersion");
            Check(!MonitorSelection.HasStableIdentitySettings(settings), "Partial save cannot auto-span");
            WorkspaceCases();
            Console.WriteLine("PASS: " + checks + " display identity, migration, workspace/profile, ambiguity and reconnect checks");
        }

        private static Dictionary<string,string> Legacy()
        {
            return new Dictionary<string,string>{{"DisplayIdentityVersion","1"},{"MonitorIdentities","OLD-A|OLD-B"},
                {"MonitorDevices","DISPLAY1|DISPLAY2"},{"MainhandIdentity","OLD-A"},{"MainhandDevice","DISPLAY1"},
                {"AutoSpan","True"},{"unrelated-preference","keep"}};
        }
        private static void Same(Dictionary<string,string> before,Dictionary<string,string> after,string label)
        {
            Check(before.Count==after.Count,label+" count");
            foreach(var value in before)Check(after.ContainsKey(value.Key)&&after[value.Key]==value.Value,label+" "+value.Key);
        }
        private static void WorkspaceCases()
        {
            var displays=Pair();displays[0].LegacyStableId="OLD-A";displays[1].LegacyStableId="OLD-B";
            var ordinary=Legacy();var before=new Dictionary<string,string>(ordinary);
            var oldPlan=MonitorSelection.CreatePlan(ordinary,displays);
            var upgraded=MonitorSelection.UpgradeIdentitySettings(ordinary,displays);
            Same(before,ordinary,"Migration must not mutate input");
            Check(MonitorSelection.HasStableIdentitySettings(upgraded),"Review promotes current schema");
            Check(upgraded["MonitorIdentities"]=="INTERFACE-A|INTERFACE-B"&&upgraded["MainhandIdentity"]=="INTERFACE-A","Canonical selected identities");
            Check(MonitorSelection.CreatePlan(upgraded,displays).MainhandBounds==oldPlan.MainhandBounds,"Legacy roles preserve geometry");
            Check(upgraded["unrelated-preference"]=="keep","Unrelated preferences retained");
            displays.Reverse();displays[0].DeviceName="DISPLAY1";displays[1].DeviceName="DISPLAY2";
            Check(MonitorSelection.CreatePlan(upgraded,displays).MainhandIndex==1,"Canonical role survives dock renumbering");
            var missing=new List<MonitorSelection.Display>{displays[0]};
            Reject(()=>MonitorSelection.CreatePlan(upgraded,missing),"disconnected");
            Check(MonitorSelection.CreatePlan(upgraded,displays).MainhandIndex==1,"Reconnect recovers existing role");
            displays=Pair();displays[0].LegacyStableId="OLD-A";displays[1].LegacyStableId="OLD-B";
            displays[1].DeviceName="display1";
            Reject(()=>MonitorSelection.CreatePlan(upgraded,displays),"display devices are ambiguous");
            displays[1].DeviceName="DISPLAY2";
            displays[1].LegacyStableId="interface-a";
            Reject(()=>Plan(displays,"INTERFACE-A|INTERFACE-B","INTERFACE-A",false),"same monitor identity");
            displays[1].LegacyStableId="OLD-A";
            Check(Plan(displays,"INTERFACE-A|INTERFACE-B","INTERFACE-B",false).Indices.Length==2,"Distinct interface IDs support matching monitors despite duplicate old IDs");
            Reject(()=>MonitorSelection.UpgradeIdentitySettings(ordinary,displays),"same monitor identity");
            Same(before,ordinary,"Ambiguous migration retained input");
            displays[1].LegacyStableId="OLD-B";displays[1].StableId=null;
            Reject(()=>MonitorSelection.UpgradeIdentitySettings(ordinary,displays),"per-monitor interface");
            displays[1].StableId="INTERFACE-B";
            var future=new Dictionary<string,string>(ordinary);future["DisplayIdentityVersion"]="99";
            Reject(()=>MonitorSelection.UpgradeIdentitySettings(future,displays),"Unsupported");
            Check(future["DisplayIdentityVersion"]=="99","Future schema preserved");
            var malformed=Legacy();malformed["DisplayIdentityVersion"]="2";malformed["MonitorIdentities"]="INTERFACE-A||INTERFACE-B";malformed["MainhandIdentity"]="INTERFACE-A";
            Check(!MonitorSelection.HasStableIdentitySettings(malformed),"Partial identity tokens cannot arm automatic spanning");

            var partial=Legacy();partial["MonitorIdentities"]="OLD-A";partial["PartialSpanEnabled"]="True";
            partial["PartialDisplayIdentity"]="OLD-A";partial["PartialMonitorWidth"]="2560";partial["PartialMonitorHeight"]="1440";
            partial["PartialWidth"]="1920";partial["PartialWorkspaceWidth"]="640";partial["PartialEdge"]="RIGHT";partial["PartialGameSide"]="LEFT";
            var partialPlan=MonitorSelection.CreatePlan(partial,displays);var migratedPartial=MonitorSelection.UpgradeIdentitySettings(partial,displays);
            Check(migratedPartial["PartialDisplayIdentity"]=="INTERFACE-A","Partial single canonical binding");
            Check(MonitorSelection.CreatePlan(migratedPartial,displays).WorkspaceBounds==partialPlan.WorkspaceBounds,"Partial single geometry retained");
            using(var editor=new PartialSpanDialog(displays,partial)) {
                editor.CreateControl();Check(editor.DisplaySelector.SelectedIndex==0&&editor.OccupiedWidth.Value==1920&&editor.WorkspaceWidth.Value==640,"Partial editor retains legacy role and geometry");
            }
            var secondary=Legacy();secondary["SecondaryAreaEnabled"]="True";secondary["SecondaryAreaIdentity"]="OLD-B";
            secondary["SecondaryMonitorWidth"]="1440";secondary["SecondaryMonitorHeight"]="2560";
            secondary["SecondaryAreaX"]="20";secondary["SecondaryAreaY"]="40";secondary["SecondaryAreaWidth"]="640";secondary["SecondaryAreaHeight"]="900";
            var secondaryPlan=MonitorSelection.CreatePlan(secondary,displays);var migratedSecondary=MonitorSelection.UpgradeIdentitySettings(secondary,displays);
            Check(migratedSecondary["SecondaryAreaIdentity"]=="INTERFACE-B","Secondary area canonical binding");
            Check(MonitorSelection.CreatePlan(migratedSecondary,displays).WorkspaceBounds==secondaryPlan.WorkspaceBounds,"Secondary area geometry retained");

            var custom=Legacy();custom["WorkspaceRegionsEnabled"]="True";custom["WorkspaceRegionVersion"]="2";
            custom["WorkspaceRegionCount"]="1";custom["WorkspacePrimary"]="a";custom["WorkspaceRegion1Id"]="a";
            custom["WorkspaceRegion1Identity"]="OLD-B";custom["WorkspaceRegion1MonitorWidth"]="1440";custom["WorkspaceRegion1MonitorHeight"]="2560";
            custom["WorkspaceRegion1X"]="20";custom["WorkspaceRegion1Y"]="40";custom["WorkspaceRegion1Width"]="640";custom["WorkspaceRegion1Height"]="900";
            custom=WorkspacePlanProfiles.Save(custom,"Original desk",null,displays);
            var originalCustom=new Dictionary<string,string>(custom);var customPlan=MonitorSelection.CreatePlan(custom,displays);
            var migrated=MonitorSelection.UpgradeIdentitySettings(custom,displays);
            Check(migrated[WorkspacePlanProfiles.Key]==custom[WorkspacePlanProfiles.Key],"Named profile snapshot bytes preserved");
            Check(migrated["WorkspaceRegion1Identity"]=="INTERFACE-B"&&migrated["WorkspaceRegion1X"]=="20","Custom binding changes without moving region");
            Check(MonitorSelection.CreatePlan(migrated,displays).WorkspaceBounds==customPlan.WorkspaceBounds,"Custom migration geometry unchanged");
            using(var editor=new WorkspaceRegionsDialog(displays,custom)) {
                editor.CreateControl();Check(editor.Game.SelectedIndex==0&&editor.Monitors[0].SelectedIndex==1,"Workspace editor resolves legacy roles");
                Check(editor.Areas[0,0].Value==20&&editor.Areas[0,1].Value==40&&editor.Areas[0,2].Value==640&&editor.Areas[0,3].Value==900,"Workspace editor retains old region instead of defaulting");
            }
            Same(originalCustom,custom,"Custom migration input");
            var loaded=WorkspacePlanProfiles.Load(migrated,custom["WorkspaceProfileID"],displays);
            Check(MonitorSelection.CreatePlan(loaded,displays).WorkspaceBounds==customPlan.WorkspaceBounds,"Old named profile remains readable");
            var resized=Pair();resized[0].LegacyStableId="OLD-A";resized[1].LegacyStableId="OLD-B";
            resized[1].Bounds=new Rectangle(-1920,0,1920,1080);
            Reject(()=>MonitorSelection.UpgradeIdentitySettings(custom,resized),"resolution changed");
            Same(originalCustom,custom,"Resolution refusal input");

            var document=WorkspaceLayoutPresets.SingleDisplay(displays[0],"centered","0123456789abcdef0123456789abcdef","Flexible desk");
            var flexible=WorkspaceLayoutSettings.Save(custom,document,displays);
            flexible[WorkspaceLayoutSettings.DocumentKey]=flexible[WorkspaceLayoutSettings.DocumentKey].Replace("INTERFACE-A","OLD-A");
            flexible["DisplayIdentityVersion"]="1";flexible["MonitorIdentities"]="OLD-A";flexible["MainhandIdentity"]="OLD-A";
            var originalFlexible=new Dictionary<string,string>(flexible);var flexiblePlan=MonitorSelection.CreatePlan(flexible,displays);
            var migratedFlexible=MonitorSelection.UpgradeIdentitySettings(flexible,displays);
            Check(migratedFlexible[WorkspaceLayoutSettings.FallbackKey]==flexible[WorkspaceLayoutSettings.FallbackKey],"Flexible downgrade snapshot preserved");
            Check(WorkspaceLayoutSettings.Read(migratedFlexible).Displays[0].StableId=="INTERFACE-A","Flexible document binding canonicalized");
            Check(MonitorSelection.CreatePlan(migratedFlexible,displays).WorkspaceBounds==flexiblePlan.WorkspaceBounds,"Flexible migration geometry unchanged");
            using(var editor=new FlexibleWorkspaceEditor(displays,flexible)) {
                editor.CreateControl();Check(editor.DisplaySelector.SelectedIndex==0&&editor.Areas[0,2].Value==flexiblePlan.MainhandBounds.Width,"Flexible editor retains legacy binding and game width");
            }
            Same(originalFlexible,flexible,"Flexible migration input");
            var restored=WorkspaceLayoutSettings.Disable(migratedFlexible);
            Check(MonitorSelection.CreatePlan(restored,displays).WorkspaceBounds==customPlan.WorkspaceBounds,"Disable retains readable legacy fallback");
            var invalidDocument=new Dictionary<string,string>(flexible);
            invalidDocument[WorkspaceLayoutSettings.DocumentKey]="{\"version\":99}";
            Reject(()=>MonitorSelection.UpgradeIdentitySettings(invalidDocument,displays),"layout");
            Check(invalidDocument[WorkspaceLayoutSettings.DocumentKey]=="{\"version\":99}","Future document bytes retained");

            int[] selected;
            var standard = CustomRegionPreferences.StandardLayout(invalidDocument, displays, out selected);
            var standardPlan = MonitorSelection.CreatePlan(standard, displays);
            Check(!standardPlan.IsCustom && standardPlan.MainhandIndex == 0 && standardPlan.WorkspaceBounds == displays[1].Bounds,
                "Reset restores full displays even when the flexible document cannot be read");
            Check(standard[WorkspacePlanProfiles.Key] == custom[WorkspacePlanProfiles.Key] &&
                standard[WorkspaceLayoutSettings.DocumentKey] == invalidDocument[WorkspaceLayoutSettings.DocumentKey] &&
                !standard.ContainsKey("WorkspaceProfileID") && standard["unrelated-preference"] == "keep",
                "Reset must preserve profiles and unrelated settings while clearing the active profile");
            Check(standard["AutoSpan"] == "False" && WorkspaceLayoutSettings.Enabled(invalidDocument),
                "Reset must keep automatic spanning off and leave its input unchanged");

            displays.Add(new MonitorSelection.Display { DeviceName = "DISPLAY3", StableId = "INTERFACE-C",
                Bounds = new Rectangle(2560, 0, 1920, 1080) });
            var multiple = new Dictionary<string,string>(migrated);
            multiple["WorkspaceRegionCount"] = "2";
            multiple["WorkspacePrimary"] = "b";
            multiple["MonitorIdentities"] += "|INTERFACE-C";
            foreach (string suffix in new[] { "X", "Y", "Width", "Height" })
                multiple["WorkspaceRegion2" + suffix] = multiple["WorkspaceRegion1" + suffix];
            multiple["WorkspaceRegion2Id"] = "b";
            multiple["WorkspaceRegion2Identity"] = "INTERFACE-C";
            multiple["WorkspaceRegion2MonitorWidth"] = "1920";
            multiple["WorkspaceRegion2MonitorHeight"] = "1080";
            standard = CustomRegionPreferences.StandardLayout(multiple, displays, out selected);
            Check(selected.Length == 2 && selected[0] == 0 && selected[1] == 2 &&
                MonitorSelection.CreatePlan(standard, displays).WorkspaceIndex == 2,
                "Reset from three monitors preserves Mainhand and the default workspace");
            displays.RemoveAt(2);
            standard = CustomRegionPreferences.StandardLayout(multiple, displays, out selected);
            Check(selected.Length == 2 && selected[1] == 1, "Reset should use the remaining selected workspace when the default is unplugged");
            displays.RemoveAt(1);
            standard = CustomRegionPreferences.StandardLayout(multiple, displays, out selected);
            Check(selected.Length == 1 && standard["MonitorIdentities"] == "INTERFACE-A" &&
                standard["SingleDisplaySplit"] == "False" && !MonitorSelection.MultiEnabled(standard),
                "Reset with one display must leave the ordinary window and keep split off");
        }
    }
}
