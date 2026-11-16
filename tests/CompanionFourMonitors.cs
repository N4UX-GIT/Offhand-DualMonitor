using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;
namespace Offhand.Companion
{
    // Four monitors: the game plus Workspaces A, B and C on separate displays.
    internal static class FourMonitorTest
    {
        [DllImport("gdi32.dll")]
        private static extern bool PtInRegion(IntPtr region, int x, int y);

        private static int checks;
        private static void Check(bool value, string message) { checks++; if (!value) throw new Exception(message); }
        private static void Rejects(Func<object> action, string fragment, string message)
        {
            string error = null;
            try { action(); } catch (InvalidOperationException ex) { error = ex.Message; }
            Check(error != null && error.Contains(fragment), message + " (got: " + (error ?? "no error") + ")");
        }
        private static List<MonitorSelection.Display> Displays(int count)
        {
            var all = new List<MonitorSelection.Display> {
                new MonitorSelection.Display{Index=0,StableId="game",DeviceName="game",Bounds=new Rectangle(0,0,3840,2160),Primary=true},
                new MonitorSelection.Display{Index=1,StableId="left",DeviceName="left",Bounds=new Rectangle(-1080,240,1080,1920)},
                new MonitorSelection.Display{Index=2,StableId="right",DeviceName="right",Bounds=new Rectangle(3840,720,2560,1440)},
                new MonitorSelection.Display{Index=3,StableId="far",DeviceName="far",Bounds=new Rectangle(6400,720,2560,1440)}};
            return all.GetRange(0, count);
        }
        private static Dictionary<string, string> Settings(int workspaces)
        {
            var s = new Dictionary<string, string>{{"WorkspaceRegionsEnabled","True"},{"WorkspaceRegionVersion","2"},
                {"WorkspaceRegionCount",workspaces.ToString()},{"WorkspacePrimary","left"},{"MainhandIdentity","game"}};
            string[] names = { "left", "right", "far" };
            int[,] size = { { 1080, 1920 }, { 2560, 1440 }, { 2560, 1440 } };
            var identities = new List<string> { "game" };
            for (int i = 0; i < workspaces; i++)
            {
                string p = "WorkspaceRegion" + (i + 1);
                s[p + "Id"] = names[i]; s[p + "Identity"] = names[i]; s[p + "X"] = "0"; s[p + "Y"] = "0";
                s[p + "Width"] = size[i, 0].ToString(); s[p + "Height"] = size[i, 1].ToString();
                s[p + "MonitorWidth"] = s[p + "Width"]; s[p + "MonitorHeight"] = s[p + "Height"];
                identities.Add(names[i]);
            }
            s["MonitorIdentities"] = string.Join("|", identities.ToArray());
            return s;
        }
        [STAThread]
        public static void Main(string[] args)
        {
            if (args.Length != 2) throw new Exception("Usage: fixture <wow directory> <repository>");
            Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
            Check(WorkspaceLayoutPlanner.MaximumWorkspaces == 3 && WorkspaceLayoutPlanner.MaximumDisplays == 4, "Four-monitor limits");

            // Planner: three workspaces on four monitors.
            var four = Displays(4);
            var plan = MonitorSelection.CreatePlan(Settings(3), four);
            Check(plan.MultiRegion && plan.Workspaces.Length == 3 && plan.Indices.Length == 4, "Three-workspace plan lost regions");
            Check(plan.Bounds == Rectangle.FromLTRB(-1080, 0, 8960, 2160), "Span bounds cover all four monitors: " + plan.Bounds);
            IntPtr clip = SpanClipRegion.Create(plan, plan.Bounds);
            try
            {
                foreach (Rectangle area in MonitorSelection.VisibleRectangles(plan))
                    Check(PtInRegion(clip, area.X - plan.Bounds.X + 1, area.Y - plan.Bounds.Y + 1),
                        "Native clip omitted a planned region");
                Check(!PtInRegion(clip, 1, 1), "Native clip included unused desktop");
            }
            finally { NativeMethods.DeleteObject(clip); }

            Rejects(() => MonitorSelection.CreatePlan(Settings(3), Displays(3)), "disconnected", "Missing Workspace C display");
            string reason;
            WorkspaceLayoutDocument document;
            Check(WorkspaceLayoutPlanner.TryConvertLegacy(plan, four, Guid.NewGuid().ToString("N"), "Four monitors", out document, out reason),
                "Could not convert the full layout: " + reason);
            var flexible = WorkspaceLayoutSettings.Save(Settings(3), document, four);
            var flexiblePlan = MonitorSelection.CreatePlan(flexible, four);
            Check(flexiblePlan.TopologySchema == 3 && flexiblePlan.Workspaces.Length == 3 && flexiblePlan.Indices.Length == 4,
                "Flexible layout document lost a workspace or display on reload");
            var restored = WorkspaceLayoutSettings.Disable(flexible);
            Check(MonitorSelection.CreatePlan(restored, four).Workspaces[2].DisplayIndex == 3,
                "Flexible layout fallback lost Workspace C");

            var tooMany = Settings(3); tooMany["WorkspaceRegionCount"] = "4";
            Rejects(() => MonitorSelection.CreatePlan(tooMany, four), "one to three", "Four workspaces rejected");
            var duplicate = Settings(3); duplicate["WorkspaceRegion3Identity"] = "right";
            duplicate["WorkspaceRegion3Width"] = "2560"; duplicate["MonitorIdentities"] = "game|left|right|right";
            Rejects(() => MonitorSelection.CreatePlan(duplicate, four), "", "Two workspaces on one monitor rejected");

            // Topology file: three regions written and verified as current.
            string addon = Path.Combine(args[0], "Interface", "AddOns", "Offhand");
            string core = Path.Combine(addon, "Core");
            Directory.CreateDirectory(core);
            File.WriteAllText(Path.Combine(core, "CompanionTopology.lua"), "OffhandCompanionTopology = nil\r\n");
            string message; byte[] bytes;
            // An addon that predates four-monitor support must refuse Workspace C.
            foreach (string toc in Directory.GetFiles(args[1], "*.toc"))
            {
                var lines = new List<string>();
                foreach (string line in File.ReadAllLines(toc))
                    if (!line.StartsWith("## X-Offhand-Max-Workspaces:")) lines.Add(line);
                File.WriteAllLines(Path.Combine(addon, Path.GetFileName(toc)), lines.ToArray());
            }
            Check(AddonInstallation.SupportedWorkspaceCount(args[0]) == 2, "Older addon is treated as two workspaces");
            Check(!CompanionTopologyBridge.TryWrite(args[0], plan, four, out message, out bytes)
                && message.Contains("Update Offhand") && bytes == null
                && File.ReadAllText(Path.Combine(core, "CompanionTopology.lua")) == "OffhandCompanionTopology = nil\r\n",
                "Older addon refuses a three-workspace topology without altering the bridge");
            Check(CompanionTopologyBridge.TryWrite(args[0], MonitorSelection.CreatePlan(Settings(2), four), four, out message, out bytes),
                "Older addon still accepts two workspaces: " + message);
            foreach (string toc in Directory.GetFiles(args[1], "*.toc"))
                File.Copy(toc, Path.Combine(addon, Path.GetFileName(toc)), true);
            Check(AddonInstallation.SupportedWorkspaceCount(args[0]) == 3, "Updated addon declares three workspaces");
            Check(CompanionTopologyBridge.TryWrite(args[0], plan, four, out message, out bytes), "Topology write failed: " + message);
            Check(CompanionTopologyBridge.IsCurrent(args[0], plan, four), "Three-region topology is not current");
            string text = File.ReadAllText(Path.Combine(core, "CompanionTopology.lua"));
            Check(text.Contains("id = \"left\"") && text.Contains("id = \"right\"") && text.Contains("id = \"far\""), "All three regions written");
            Check(text.Contains("[\"far\"] = { device = \"far\""), "Workspace C scaling metadata written");
            Check(CompanionTopologyBridge.TryWrite(args[0], flexiblePlan, four, out message, out bytes)
                && CompanionTopologyBridge.IsCurrent(args[0], flexiblePlan, four), "Schema 3 four-monitor bridge: " + message);
            File.WriteAllText(Path.Combine(args[0], "schema2.lua"), text);
            File.WriteAllBytes(Path.Combine(args[0], "schema3.lua"), bytes);

            string foreverToc = Path.Combine(addon, "Offhand_Forever.toc");
            File.WriteAllText(foreverToc, File.ReadAllText(foreverToc).Replace("X-Offhand-Max-Workspaces", "X-Old-Workspace-Limit"));
            Check(AddonInstallation.SupportedWorkspaceCount(args[0]) == 2
                && !CompanionTopologyBridge.IsCurrent(args[0], flexiblePlan, four)
                && !CompanionTopologyBridge.TryWrite(args[0], plan, four, out message),
                "A partial update must not advertise or write a four-monitor bridge");

            // Dialog: Workspace C follows B, and the saved count is restored.
            using (var dialog = new WorkspaceRegionsDialog(four, Settings(3)))
            {
                Check(dialog.Second.Checked && dialog.Third.Checked && dialog.ActiveCount() == 3, "Saved three-workspace plan restored");
                var proposed = dialog.Proposed();
                Check(proposed["WorkspaceRegionCount"] == "3" && proposed["WorkspaceRegion3Identity"] == "far", "Workspace C proposed");
                Check(proposed["MonitorIdentities"] == "game|left|right|far", "All four monitors selected");
                Check(MonitorSelection.CreatePlan(proposed, four).Workspaces.Length == 3, "Proposed plan builds");
                dialog.Primary.SelectedIndex = 2;
                Check(dialog.Proposed()["WorkspacePrimary"] == "far", "Workspace C can be the default");
                dialog.Second.Checked = false;
                Check(dialog.ActiveCount() == 1 && dialog.Proposed()["WorkspaceRegionCount"] == "1", "C is not used without B");
                Check(dialog.Primary.SelectedIndex == 0, "Default resets when its workspace is removed");
                Check(!dialog.Third.Enabled && dialog.Primary.Items.Count == 1,
                    "Workspace C is unavailable while B is off");
                dialog.Second.Checked = true;
                Check(dialog.ActiveCount() == 3 && dialog.Primary.Items.Count == 3,
                    "Re-enabling B restores the draft C settings");
            }
            using (var dialog = new WorkspaceRegionsDialog(four, Settings(2)))
            {
                Check(dialog.Second.Checked && !dialog.Third.Checked && dialog.ActiveCount() == 2, "Two-workspace plan unchanged");
                Check(dialog.Proposed()["WorkspaceRegionCount"] == "2", "Two-workspace proposal unchanged");
                dialog.Third.Checked = true;
                Check(dialog.ActiveCount() == 3 && dialog.Monitors[2].SelectedIndex == 3, "Adding C picks the free fourth monitor");
                Check(dialog.Proposed()["WorkspaceRegionCount"] == "3", "Adding Workspace C");
            }
            // Only three monitors connected: Workspace C is refused with a clear message.
            var three = Displays(3);
            using (var dialog = new WorkspaceRegionsDialog(three, Settings(2)))
            {
                dialog.Third.Checked = true;
                Rejects(() => dialog.Proposed(), "fourth connected monitor", "Workspace C needs a fourth monitor");
            }
            // Saved workspace profiles keep Workspace C.
            foreach (string key in new[] { "WorkspaceRegion3Id", "WorkspaceRegion3Identity", "WorkspaceRegion3X", "WorkspaceRegion3Height", "WorkspaceRegion3MonitorWidth" })
                Check(WorkspacePlanProfiles.PlanKey(key), "Profiles keep " + key);
            Check(!WorkspacePlanProfiles.PlanKey("WorkspaceRegion4Id"), "Profiles still reject a fourth workspace");
            var profileSettings = Settings(3);
            profileSettings["WorkspacePrimary"] = "far";
            var saved = WorkspacePlanProfiles.Save(profileSettings, "Four monitors", null, four);
            var loaded = WorkspacePlanProfiles.Load(saved, saved["WorkspaceProfileID"], four);
            var loadedPlan = MonitorSelection.CreatePlan(loaded, four);
            Check(loadedPlan.Workspaces.Length == 3 && loadedPlan.PrimaryWorkspaceId == "far"
                && loadedPlan.WorkspaceIndex == 3, "Profile reload lost Workspace C or its default selection");
            Console.WriteLine("PASS: four-monitor Companion plan, topology and editor (" + checks + " checks)");
        }
    }
}
