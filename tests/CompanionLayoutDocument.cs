using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;

namespace Offhand.Companion
{
    internal static class LayoutDocumentTest
    {
        private static int checks;
        private static void Check(bool value, string message)
        { checks++; if (!value) throw new Exception(message); }
        private static List<MonitorSelection.Display> Ultra(int width = 5120, int height = 1440)
        {
            return new List<MonitorSelection.Display> { new MonitorSelection.Display {
                StableId = "ultra", DeviceName = "ultra-device", Bounds = new Rectangle(0, 0, width, height), Primary = true } };
        }
        private static WorkspaceLayoutRegion Region(string id, int x, int y, int width, int height)
        { return new WorkspaceLayoutRegion { Id = id, DisplayRole = "screen", Bounds = new Rectangle(x, y, width, height) }; }
        private static WorkspaceLayoutDocument Center()
        {
            return new WorkspaceLayoutDocument { Id = "centered", Name = "Centered game", PrimaryWorkspaceId = "left",
                Displays = new List<WorkspaceLayoutBinding> { new WorkspaceLayoutBinding { Role = "screen", StableId = "ultra", Resolution = new Size(5120, 1440) } },
                Game = Region("game", 1280, 0, 2560, 1440), Workspaces = new List<WorkspaceLayoutRegion> {
                    Region("left", 0, 0, 1280, 1440), Region("right", 3840, 0, 1280, 1440) } };
        }
        private static void Reject(WorkspaceLayoutDocument document, IList<MonitorSelection.Display> displays)
        {
            bool failed = false;
            try { WorkspaceLayoutPlanner.Resolve(document, displays); }
            catch (InvalidOperationException) { failed = true; }
            Check(failed, "Invalid layout accepted");
        }
        private static Dictionary<string, string> Selection(string main, string selected)
        {
            return new Dictionary<string, string> { { "DisplayIdentityVersion", "1" }, { "MainhandIdentity", main },
                { "MonitorIdentities", selected }, { "SingleDisplaySplit", "False" } };
        }
        private static void Legacy(IDictionary<string, string> settings, List<MonitorSelection.Display> displays)
        {
            var legacy = MonitorSelection.CreatePlan(settings, displays);
            var beforeGame = legacy.MainhandBounds; var beforeWorkspace = legacy.WorkspaceBounds;
            WorkspaceLayoutDocument document; string reason;
            Check(WorkspaceLayoutPlanner.TryConvertLegacy(legacy, displays, "converted", "Converted", out document, out reason), reason);
            var resolved = WorkspaceLayoutPlanner.Resolve(document, displays);
            Check(resolved.Game.Bounds == beforeGame && resolved.Bounds == legacy.Bounds, "Legacy game/backing geometry changed");
            Check(legacy.MainhandBounds == beforeGame && legacy.WorkspaceBounds == beforeWorkspace, "Conversion mutated the native plan");
            if (legacy.MultiRegion)
            {
                Check(resolved.Workspaces.Count == legacy.Workspaces.Length && resolved.PrimaryWorkspaceId == legacy.PrimaryWorkspaceId,
                    "Legacy IDs/primary changed");
                foreach (var region in legacy.Workspaces)
                    Check(resolved.Workspaces.Single(r => r.Id == region.Id).Bounds == region.Bounds, "Legacy workspace geometry changed");
            }
            else Check(resolved.Workspaces[0].Bounds == beforeWorkspace, "Legacy workspace rectangle changed");
            displays.Reverse();
            var reordered = WorkspaceLayoutPlanner.Resolve(document, displays);
            Check(reordered.Game.Bounds == resolved.Game.Bounds && reordered.Workspaces.Select(r => r.Bounds).SequenceEqual(resolved.Workspaces.Select(r => r.Bounds)),
                "Monitor enumeration order changed resolved geometry");
            displays.Reverse();
        }
        public static void Main()
        {
            var document = Center(); var displays = Ultra();
            var plan = WorkspaceLayoutPlanner.Resolve(document, displays);
            Check(plan.Workspaces.Count == 2 && plan.DisplayIndices.Count == 1, "Same-display regions were not resolved independently");
            Check(plan.Game.Bounds == new Rectangle(1280, 0, 2560, 1440) && plan.Bounds == displays[0].Bounds, "Centered-game geometry changed");
            Check(plan.Workspaces[0].Id == "left" && plan.Workspaces[1].Id == "right", "Region IDs changed");
            document.PrimaryWorkspaceId = "right";
            Check(WorkspaceLayoutPlanner.Resolve(document, displays).PrimaryWorkspaceId == "right", "Primary workspace was inferred from order");
            var copy = document.Copy(); copy.Workspaces[0].Id = "renamed"; copy.Displays[0].StableId = "different";
            Check(document.Workspaces[0].Id == "left" && document.Displays[0].StableId == "ultra", "Draft copy aliased saved data");
            document.Workspaces[0].Bounds = new Rectangle(0, 0, 900, 1000);
            Check(plan.Workspaces[0].Bounds == new Rectangle(0, 0, 1280, 1440), "Resolved plan aliases the mutable draft");
            bool readonlyList = false;
            try { ((IList<ResolvedWorkspaceRegion>)plan.Workspaces).RemoveAt(0); }
            catch (NotSupportedException) { readonlyList = true; }
            Check(readonlyList, "Resolved workspace collection is writable");

            var stacked = Center(); stacked.Displays[0].Resolution = new Size(3440, 1440);
            stacked.Game.Bounds = new Rectangle(880, 0, 2560, 1440);
            stacked.Workspaces[0].Bounds = new Rectangle(0, 0, 880, 720);
            stacked.Workspaces[1].Bounds = new Rectangle(0, 720, 880, 720);
            Check(WorkspaceLayoutPlanner.Resolve(stacked, Ultra(3440)).Bounds == new Rectangle(0, 0, 3440, 1440), "Stacked workspaces rejected");

            var offset = Center(); offset.Displays[0].Resolution = new Size(3840, 2160);
            offset.Game.Bounds = new Rectangle(1000, 400, 1920, 1080);
            offset.Workspaces[0].Bounds = new Rectangle(0, 0, 800, 600);
            offset.Workspaces[1].Bounds = new Rectangle(0, 700, 800, 600);
            var offsetPlan = WorkspaceLayoutPlanner.Resolve(offset, Ultra(3840, 2160));
            Check(offsetPlan.Bounds == new Rectangle(0, 0, 2920, 1480), "Offset/desktop-gap authoring failed");
            Check(!offsetPlan.Game.Bounds.Contains(900, 600) && !offsetPlan.Workspaces.Any(r => r.Bounds.Contains(900, 600)),
                "Desktop gap was assigned to a visible region");

            foreach (Action<WorkspaceLayoutDocument> mutate in new Action<WorkspaceLayoutDocument>[] {
                d => d.Version = 99, d => d.Id = "bad id", d => d.Id = "newline\n", d => d.Name = "bad\nname", d => d.Name = "|cmarkup",
                d => d.Name = new string('a', 49), d => d.Game = null, d => d.Workspaces = null,
                d => d.Workspaces.Clear(), d => d.Workspaces.Add(Region("third", 0, 0, 480, 600)),
                d => d.Workspaces[1] = null, d => d.Workspaces[1].Id = "left", d => d.Workspaces[0].Id = "game",
                d => d.Workspaces[0].DisplayRole = "missing", d => d.Workspaces[0].Id = "newline\n", d => d.PrimaryWorkspaceId = "missing",
                d => d.Workspaces[0].Bounds = new Rectangle(1, 0, 1280, 1440),
                d => d.Workspaces[1].Bounds = new Rectangle(0, 0, 1280, 1440),
                d => d.Workspaces[0].Bounds = new Rectangle(-1, 0, 1280, 1440),
                d => d.Workspaces[1].Bounds = new Rectangle(int.MaxValue, 0, 1280, 1440),
                d => d.Workspaces[0].Bounds = new Rectangle(0, 0, 479, 1440),
                d => d.Workspaces[0].Bounds = new Rectangle(0, 0, 1280, 599),
                d => d.Game.Bounds = new Rectangle(1280, 0, 959, 1440),
                d => d.Game.Bounds = new Rectangle(1280, 0, 2560, 599),
                d => d.Displays = null, d => d.Displays.Clear(), d => d.Displays.Add(d.Displays[0].Copy()),
                d => d.Displays[0].Resolution = new Size(5119, 1440), d => d.Displays[0].StableId = "missing",
                d => d.Displays.Add(new WorkspaceLayoutBinding { Role = "unused", StableId = "ultra", Resolution = new Size(5120, 1440) })
            }) { var invalid = Center(); mutate(invalid); Reject(invalid, displays); }
            Reject(null, displays); Reject(Center(), null);
            var future = Center(); future.Version = 99; Reject(future, displays);
            Check(future.Version == 99 && future.Workspaces[0].Id == "left", "Future data was migrated in place");
            bool futureCopy = false; try { future.Copy(); } catch (InvalidOperationException) { futureCopy = true; }
            Check(futureCopy, "Future document was copied into the current format");
            var ambiguous = Ultra(); ambiguous.Add(ambiguous[0]); Reject(Center(), ambiguous);
            var overflow = Ultra(); overflow[0].Bounds = new Rectangle(int.MaxValue - 100, 0, 5120, 1440);
            Reject(Center(), overflow);
            var budget = Center(); budget.Displays[0].Resolution = new Size(8000, 4000);
            budget.Game.Bounds = new Rectangle(0, 0, 960, 600); budget.Workspaces.RemoveAt(1);
            budget.Workspaces[0].Bounds = new Rectangle(2500, 600, 480, 600);
            Reject(budget, Ultra(8000, 4000));
            var huge = Center(); huge.Displays[0].Resolution = new Size(20000, 1440);
            huge.Workspaces[1].Bounds = new Rectangle(19000, 0, 1000, 1440);
            Reject(huge, Ultra(20000));

            // Translation changes desktop origin only; UI pixel budgets stay fixed.
            for (int step = 0; step < 80; step++)
            {
                var translated = Ultra(); int x = -8000 + step * 113, y = -2000 + step * 47;
                translated[0].Bounds = new Rectangle(x, y, 5120, 1440);
                var result = WorkspaceLayoutPlanner.Resolve(Center(), translated);
                Check(result.Game.Bounds == new Rectangle(x + 1280, y, 2560, 1440), "Desktop translation changed the game area");
                Check(result.Workspaces[1].Bounds == new Rectangle(x + 3840, y, 1280, 1440), "Desktop translation changed the workspace");
            }

            var pair = new List<MonitorSelection.Display> {
                new MonitorSelection.Display { StableId = "game", DeviceName = "game-device", Bounds = new Rectangle(0, 0, 2560, 1440), Primary = true },
                new MonitorSelection.Display { StableId = "left", DeviceName = "left-device", Bounds = new Rectangle(-1440, -1120, 1440, 2560) } };
            Legacy(Selection("game", "game|left"), pair);
            var split = Selection("ultra", "ultra"); split["SingleDisplaySplit"] = "True";
            Legacy(split, Ultra());
            var partial = Selection("ultra", "ultra");
            foreach (var kv in new Dictionary<string, string> { { "PartialSpanEnabled", "True" }, { "PartialDisplayIdentity", "ultra" },
                { "PartialWidth", "3840" }, { "PartialWorkspaceWidth", "1280" }, { "PartialMonitorWidth", "5120" },
                { "PartialMonitorHeight", "1440" }, { "PartialEdge", "RIGHT" }, { "PartialGameSide", "LEFT" } }) partial[kv.Key] = kv.Value;
            Legacy(partial, Ultra());
            var secondary = Selection("game", "game|left");
            foreach (var kv in new Dictionary<string, string> { { "SecondaryAreaEnabled", "True" }, { "SecondaryAreaIdentity", "left" },
                { "SecondaryMonitorWidth", "1440" }, { "SecondaryMonitorHeight", "2560" }, { "SecondaryAreaX", "9" },
                { "SecondaryAreaY", "1108" }, { "SecondaryAreaWidth", "480" }, { "SecondaryAreaHeight", "600" } }) secondary[kv.Key] = kv.Value;
            Legacy(secondary, pair);
            var multi = Selection("game", "game|left");
            foreach (var kv in new Dictionary<string, string> { { "WorkspaceRegionsEnabled", "True" }, { "WorkspaceRegionVersion", "2" },
                { "WorkspaceRegionCount", "1" }, { "WorkspacePrimary", "workspace-a" }, { "WorkspaceRegion1Id", "workspace-a" },
                { "WorkspaceRegion1Identity", "left" }, { "WorkspaceRegion1MonitorWidth", "1440" }, { "WorkspaceRegion1MonitorHeight", "2560" },
                { "WorkspaceRegion1X", "9" }, { "WorkspaceRegion1Y", "1108" }, { "WorkspaceRegion1Width", "480" }, { "WorkspaceRegion1Height", "600" } }) multi[kv.Key] = kv.Value;
            Legacy(multi, pair);
            // Same-display permission remains absent from schema 2's existing path.
            var oldContract = new Dictionary<string, string>(multi); oldContract["WorkspaceRegion1Identity"] = "game";
            bool oldRejected = false; try { MonitorSelection.CreatePlan(oldContract, pair); } catch (InvalidOperationException) { oldRejected = true; }
            Check(oldRejected, "Foundation changed schema 2's distinct-display contract");
            var oversizedLegacy = new MonitorSelection.Plan { MainhandIndex = 0, WorkspaceIndex = 0,
                MainhandBounds = new Rectangle(480, 0, 16520, 1440), WorkspaceBounds = new Rectangle(0, 0, 480, 1440),
                Bounds = new Rectangle(0, 0, 17000, 1440), PartialSingle = true };
            WorkspaceLayoutDocument notConverted; string explanation;
            Check(!WorkspaceLayoutPlanner.TryConvertLegacy(oversizedLegacy, Ultra(17000), "old", "Legacy", out notConverted, out explanation)
                && notConverted == null && explanation != null, "Legacy limit mismatch silently converted");
            Check(oversizedLegacy.Bounds.Width == 17000, "Failed conversion discarded the old plan");
            var malformedLegacy = new MonitorSelection.Plan { MainhandIndex = 0, MainhandBounds = new Rectangle(1280, 0, 2560, 1440),
                Workspaces = new MonitorSelection.WorkspaceRegion[] { null } };
            Check(!WorkspaceLayoutPlanner.TryConvertLegacy(malformedLegacy, Ultra(), "old", "Legacy", out notConverted, out explanation)
                && notConverted == null, "Malformed legacy region was not refused safely");
            Console.WriteLine("PASS: {0} layout document checks; pure same-monitor planning, bounds, copies, legacy parity and refusal. No native apply or WoW access.", checks);
        }
    }
}
