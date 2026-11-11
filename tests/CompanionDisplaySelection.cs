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
            ActivePathCases();
            FeedbackCases();
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
            Console.WriteLine("PASS: " + checks + " display identity, selection feedback, migration, workspace/profile, ambiguity and reconnect checks");
        }

        private static void FeedbackCases()
        {
            var pair = Pair();
            var selected = new List<int> { 0, 1 };
            Check(DisplaySelectionFeedback.Inspect(pair, selected, 0).Code == "IDENTITY_BINDINGS_PRESENT", "Complete feedback is not span authorization");
            Check(DisplaySelectionFeedback.Inspect(pair, new List<int>(), 0).Code == "NO_CHECKED_DISPLAYS", "Unchecked selection is not a Windows failure");
            Check(DisplaySelectionFeedback.Inspect(pair, selected, -1).Code == "MAINHAND_NOT_SELECTED", "Empty Mainhand is a selection error");
            Check(DisplaySelectionFeedback.Inspect(pair, new List<int> { 1 }, 0).Code == "MAINHAND_NOT_CHECKED", "Unchecked Mainhand is explicit");
            Check(DisplaySelectionFeedback.Inspect(pair, new List<int> { 0, 9 }, 0).Code == "SELECTION_UNAVAILABLE", "Stale control index is explained");
            Check(DisplaySelectionFeedback.Inspect(null, selected, 0).Code == "SELECTION_UNAVAILABLE", "Unavailable controls do not blame a driver");
            pair[1].StableId = " "; pair[1].IdentityDetail = "Active monitor target name query failed: 5";
            var missing = DisplaySelectionFeedback.Inspect(pair, selected, 0);
            Check(missing.Code == "MISSING_MONITOR_IDENTITY" && missing.Message.Contains("Display 2 (1440x2560)")
                && missing.Message.Contains("Copy Display Diagnostics"), "Missing identity identifies the affected screen and evidence action");
            Check(pair[1].StableId == " " && selected.Count == 2, "Feedback cannot repair identities or edit selection");
            pair[0].StableId = null;
            Check(DisplaySelectionFeedback.Inspect(pair, selected, 0).Message.Contains("Display 1 (2560x1440)"), "Missing Mainhand identity is not an empty dropdown");
            pair = Pair(); pair[1].StableId = "interface-a";
            Check(DisplaySelectionFeedback.Inspect(pair, selected, 0).Code == "AMBIGUOUS_MONITOR_IDENTITY", "Ambiguous identities remain distinct from missing IDs");
            pair = Pair(); pair.Add(new MonitorSelection.Display { Index = 2, DeviceName = "DISPLAY3", StableId = "interface-a" });
            Check(DisplaySelectionFeedback.Inspect(pair, selected, 0).Code == "AMBIGUOUS_MONITOR_IDENTITY", "Unchecked collision remains ambiguous");
            var failedPath = new List<DisplayIdentity.ActivePath> { new DisplayIdentity.ActivePath {
                Device = "DISPLAY1", Detail = "Active monitor target name query failed: 5" } };
            var failed = DisplayIdentity.Resolve("DISPLAY1", failedPath, new List<DisplayIdentity.Child> {
                new DisplayIdentity.Child { Identity = "STALE" } }, null);
            Check(failed.Identity == null && failed.Detail == failedPath[0].Detail, "Raw target failure retained without falling back to a stale child");

            // Exercise actual UI capture/confirmation without constructing a
            // running Companion, showing a modal, or touching public settings.
            if (RemoteDesktop.Read() != RemoteDesktop.State.Local)
                throw new Exception("Selection feedback fixture requires a local Windows session");
            GuardFeedbackCase("INTERFACE-A", "INTERFACE-B", true, true, "IDENTITY_BINDINGS_PRESENT", null);
            GuardFeedbackCase("INTERFACE-A", null, true, true, "MISSING_MONITOR_IDENTITY", "Display 2");
            GuardFeedbackCase(null, "INTERFACE-B", true, true, "MISSING_MONITOR_IDENTITY", "Display 1");
            GuardFeedbackCase("INTERFACE-A", "INTERFACE-B", false, true, "MAINHAND_NOT_SELECTED", "No Mainhand display");
            GuardFeedbackCase("INTERFACE-A", "INTERFACE-B", true, false, "NO_CHECKED_DISPLAYS", "No displays are checked");
        }

        private static void GuardFeedbackCase(string gameIdentity, string workspaceIdentity, bool mainhandSelected,
            bool checkedDisplays, string code, string expectedError)
        {
            const System.Reflection.BindingFlags fields = System.Reflection.BindingFlags.Instance
                | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic;
            var settingsField = typeof(CompanionForm).GetField("appSettings", System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.NonPublic);
            var pathField = typeof(CompanionForm).GetField("configPath", System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.NonPublic);
            object originalSettings = settingsField.GetValue(null), originalPath = pathField.GetValue(null);
            string sentinel = System.IO.Path.GetTempFileName();
            System.IO.File.WriteAllText(sentinel, "selection feedback sentinel");
            try
            {
                var settings = new Dictionary<string, string>();
                settingsField.SetValue(null, settings); pathField.SetValue(null, sentinel);
                var form = (CompanionForm)System.Runtime.Serialization.FormatterServices.GetUninitializedObject(typeof(CompanionForm));
                typeof(CompanionForm).GetField("remoteState", fields).SetValue(form, RemoteDesktop.State.Local);
                typeof(CompanionForm).GetField("classicRecovery", fields).SetValue(form, new Dictionary<int, ClassicGraphicsRecovery>());
                var pair = Pair(); pair[0].StableId = gameIdentity; pair[1].StableId = workspaceIdentity;
                pair[1].IdentityDetail = "Active monitor target name query failed: 5";
                typeof(CompanionForm).GetField("uiDisplays", fields).SetValue(form, pair);
                using (var list = new System.Windows.Forms.CheckedListBox())
                using (var combo = new System.Windows.Forms.ComboBox())
                {
                    list.Items.Add("Display 1", checkedDisplays); list.Items.Add("Display 2", checkedDisplays);
                    var choiceType = typeof(CompanionForm).GetNestedType("DisplayChoice", System.Reflection.BindingFlags.NonPublic);
                    object choice = Activator.CreateInstance(choiceType, true);
                    choiceType.GetField("Index", fields).SetValue(choice, 0);
                    choiceType.GetField("DeviceName", fields).SetValue(choice, "DISPLAY1");
                    choiceType.GetField("StableId", fields).SetValue(choice, gameIdentity);
                    choiceType.GetField("Label", fields).SetValue(choice, "Display 1");
                    combo.Items.Add(choice); if (mainhandSelected) combo.SelectedIndex = 0;
                    typeof(CompanionForm).GetField("clbMonitors", fields).SetValue(form, list);
                    typeof(CompanionForm).GetField("cmbMainhand", fields).SetValue(form, combo);
                    typeof(CompanionForm).GetMethod("SaveDisplaySettingsFromControls", fields).Invoke(form, new object[] { false });
                    var before = new Dictionary<string, string>(settings);
                    var confirm = typeof(CompanionForm).GetMethod("ConfirmStableDisplayIdentity", fields);
                    if (expectedError != null)
                    {
                        try { confirm.Invoke(form, new object[] { false }); throw new Exception("Automatic span bypassed confirmation"); }
                        catch (System.Reflection.TargetInvocationException ex)
                        {
                            Check(ex.InnerException is InvalidOperationException && ex.InnerException.Message.Contains("before automatic spanning"), "Automatic confirmation guard remains authoritative");
                        }
                    }
                    try
                    {
                        object result = confirm.Invoke(form, new object[] { true });
                        Check(expectedError == null && !(bool)result, "Valid identities must retain existing confirmation behavior");
                    }
                    catch (System.Reflection.TargetInvocationException ex)
                    {
                        Check(expectedError != null && ex.InnerException is InvalidOperationException
                            && ex.InnerException.Message.Contains(expectedError) && ex.InnerException.Message.Contains("No span was applied."),
                            "Wrong selection refusal: " + ex.InnerException.Message);
                    }
                    Same(before, settings, "Feedback must preserve pending settings");
                    Check(System.IO.File.ReadAllText(sentinel) == "selection feedback sentinel", "Feedback must not write preferences");
                    var report = typeof(CompanionForm).GetMethod("DisplaySelectionDiagnosticText", fields);
                    string text = (string)report.Invoke(form, new object[] { pair, "fixture plan rejection" });
                    Check(text.Contains("Selection status: " + code) && text.Contains("Saved plan validation: fixture plan rejection"), "Copy diagnostics preserves selection classification and planner refusal");
                    Check(text.Contains("Checked display count: " + (checkedDisplays ? 2 : 0))
                        && text.Contains("bounds=") && text.Contains(pair[1].IdentityDetail), "Diagnostics expose selection, topology and lookup reason");
                    if (workspaceIdentity == null) Check(text.Contains("identity=<missing>"), "Missing identities are explicitly marked");
                    using (var modes = new System.Windows.Forms.Label())
                    using (var warning = new System.Windows.Forms.Label())
                    using (var scale = new System.Windows.Forms.Label())
                    {
                        typeof(CompanionForm).GetField("lblColorModes", fields).SetValue(form, modes);
                        typeof(CompanionForm).GetField("lblColorWarning", fields).SetValue(form, warning);
                        typeof(CompanionForm).GetField("lblScaleInfo", fields).SetValue(form, scale);
                        typeof(CompanionForm).GetMethod("RefreshColorStatus", fields).Invoke(form, new object[] { pair, null, "fixture plan rejection" });
                        string copied = (string)typeof(CompanionForm).GetField("colorDiagnostics", fields).GetValue(form);
                        Check(copied.Contains("Selection status: " + code) && copied.Contains("fixture plan rejection")
                            && modes.Text.Contains("Copy Display Diagnostics"), "Unconfirmed layout still exposes actionable copy diagnostics");
                    }
                    if (!checkedDisplays)
                    {
                        settings["PartialSpanEnabled"] = "True";
                        text = (string)report.Invoke(form, new object[] { pair, "custom fixture rejection" });
                        Check(text.Contains("Standard selection controls: inactive") && !text.Contains("Selection status: NO_CHECKED_DISPLAYS"), "Custom plans must not be blamed on inactive standard controls");
                        settings.Remove("PartialSpanEnabled");
                        typeof(CompanionForm).GetField("remoteState", fields).SetValue(form, RemoteDesktop.State.Active);
                        text = (string)report.Invoke(form, new object[] { pair, "remote fixture rejection" });
                        Check(text.Contains("Session state: Active") && !text.Contains("Selection status: NO_CHECKED_DISPLAYS"), "Remote diagnostics must not blame inactive standard controls");
                    }
                    Check(System.IO.File.ReadAllText(sentinel) == "selection feedback sentinel", "Copy diagnostics must not write preferences");
                }
            }
            finally
            {
                settingsField.SetValue(null, originalSettings); pathField.SetValue(null, originalPath);
                System.IO.File.Delete(sentinel);
            }
        }

        private static void ActivePathCases()
        {
            Check(System.Runtime.InteropServices.Marshal.SizeOf(typeof(DisplayIdentity.TargetName)) == 420,
                "Target name native structure size");
            Check(System.Runtime.InteropServices.Marshal.OffsetOf(typeof(DisplayIdentity.TargetName), "Path").ToInt32() == 164,
                "Target monitor interface path offset");
            var paths = new List<DisplayIdentity.ActivePath> {
                new DisplayIdentity.ActivePath { Device="DISPLAY1", Identity="INTERFACE-A" },
                new DisplayIdentity.ActivePath { Device="DISPLAY2", Identity="INTERFACE-B" }
            };
            var stale = new DisplayIdentity.Child { Identity="DISABLED-TV", LegacyIdentity="OLD-TV" };
            var a = DisplayIdentity.Resolve("display1", paths, new List<DisplayIdentity.Child> { stale,
                new DisplayIdentity.Child { Identity="INTERFACE-A", LegacyIdentity="OLD-A" } }, null);
            var b = DisplayIdentity.Resolve("DISPLAY2", paths, new List<DisplayIdentity.Child> { stale,
                new DisplayIdentity.Child { Identity="INTERFACE-B", LegacyIdentity="OLD-B" } }, null);
            Check(a.Identity=="INTERFACE-A" && b.Identity=="INTERFACE-B", "Repeated stale first monitor entry cannot collapse active pair");
            Check(a.LegacyIdentity=="OLD-A" && b.LegacyIdentity=="OLD-B", "Legacy aliases must belong to the active child");
            var pair=Pair();
            pair[0].Bounds=new Rectangle(0,0,1920,1080);pair[1].Bounds=new Rectangle(1920,0,1920,1080);
            pair[0].StableId=a.Identity;pair[0].LegacyStableId=a.LegacyIdentity;
            pair[1].StableId=b.Identity;pair[1].LegacyStableId=b.LegacyIdentity;
            var plan=Plan(pair,"INTERFACE-A|INTERFACE-B","INTERFACE-A",false);
            Check(plan.Indices.Length==2 && plan.Bounds.Width==3840, "Reporter-shaped identical-resolution pair spans both displays");
            Check(Plan(pair,"OLD-A|OLD-B","OLD-A",false).Indices.Length==2,"Unique old aliases still migrate");
            b=DisplayIdentity.Resolve("DISPLAY2",paths,new List<DisplayIdentity.Child>{stale},null);
            Check(b.Identity=="INTERFACE-B" && b.LegacyIdentity==null,"Missing active child must not retain disabled TV alias");
            b=DisplayIdentity.Resolve("DISPLAY2",paths,new List<DisplayIdentity.Child>{
                new DisplayIdentity.Child { Identity="INTERFACE-B", LegacyIdentity="OLD-B" },
                new DisplayIdentity.Child { Identity="interface-b", LegacyIdentity="OTHER" }},null);
            Check(b.Identity=="INTERFACE-B" && b.LegacyIdentity==null,"Repeated matching children cannot select an arbitrary alias");
            paths.Add(new DisplayIdentity.ActivePath {Device="DISPLAY1",Identity="CLONE"});
            Check(DisplayIdentity.Resolve("DISPLAY1",paths,new List<DisplayIdentity.Child>{stale},null).Identity==null,
                "Cloned active source must not select its first target");
            paths.RemoveAt(2);paths[1].Identity="INTERFACE-A";
            pair[1].StableId=DisplayIdentity.Resolve("DISPLAY2",paths,new List<DisplayIdentity.Child>(),null).Identity;
            Reject(()=>Plan(pair,"INTERFACE-A|INTERFACE-A","INTERFACE-A",false),"same monitor identity");
            paths[1].Identity=null;
            Check(DisplayIdentity.Resolve("DISPLAY2",paths,new List<DisplayIdentity.Child>{stale},null).Identity==null,
                "Unnamed active target cannot fall back to child zero");
            Check(DisplayIdentity.Resolve("MISSING",paths,new List<DisplayIdentity.Child>{stale},null).Identity==null,
                "Missing active source cannot fall back to child zero");
            Check(DisplayIdentity.Resolve("DISPLAY1",new List<DisplayIdentity.ActivePath>(),new List<DisplayIdentity.Child>{stale},null).Identity==null,
                "Empty successful active snapshot cannot fall back");
            Check(DisplayIdentity.Resolve("DISPLAY1",null,new List<DisplayIdentity.Child>{stale},"access denied").Identity==null,
                "Transient or access failures cannot fall back");
            Check(DisplayIdentity.Resolve("DISPLAY1",null,new List<DisplayIdentity.Child>{stale},null).Identity=="DISABLED-TV",
                "Unsupported API retains unique-interface compatibility fallback");
            Check(DisplayIdentity.Resolve("DISPLAY1",null,new List<DisplayIdentity.Child>{stale,stale},null).Identity==null,
                "Unsupported API must refuse ambiguous child entries");

            // Read-only native smoke test, no window movement or preference writes.
            var devices=new List<string>();
            foreach(var screen in System.Windows.Forms.Screen.AllScreens)devices.Add(screen.DeviceName);
            var native=DisplayIdentity.Read(devices);
            foreach(string device in devices) {
                Check(native.ContainsKey(device)&&!string.IsNullOrEmpty(native[device].Detail),"Native enumeration must explain every source");
                Console.WriteLine("Native identity: "+device+"; "+native[device].Identity+"; "+native[device].Detail);
            }
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
