using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;

namespace Offhand.Companion
{
    // Exercise production planning and the exact generated-file contract.
    internal static class PartialTopologyTest
    {
        [DllImport("gdi32.dll")] private static extern bool PtInRegion(IntPtr region, int x, int y);
        public static void Main(string[] args)
        {
            // Gesture sequences must produce layouts accepted by the production
            // planner, including edge snapping and the physical minimums.
            foreach (bool right in new bool[] { false, true })
            foreach (bool gameLeft in new bool[] { false, true }) {
                var selection = new PartialRegionSelection(2560, 2240, 640, right, gameLeft);
                selection.ResizeOccupied(right ? 960 : 1600);
                if (selection.Width != 1600 || selection.WorkspaceWidth != 640)
                    throw new Exception("Occupied divider did not retain workspace and minimum game width.");
                selection.ResizeWorkspace(gameLeft ? selection.Left + selection.Width : selection.Left);
                if (selection.WorkspaceWidth != 480) throw new Exception("Workspace divider lost minimum width.");
                selection.ResizeOccupied(right ? -100 : 3000);
                if (selection.Width != 2560) throw new Exception("Occupied divider escaped the monitor.");
                selection.ResizeWorkspace(gameLeft ? -100 : 3000);
                if (selection.WorkspaceWidth != 1600) throw new Exception("Workspace divider lost minimum game width.");
                selection.Move(right ? -4000 : 4000, right);
                if (selection.OccupiedRight == right) throw new Exception("Moving occupied area did not snap to opposite edge.");
                var monitor = new Rectangle(-2560,-1440,2560,1440);
                var overlaySettings = new Dictionary<string,string> {
                    {"DisplayIdentityVersion","1"}, {"MonitorIdentities","editor"}, {"MainhandIdentity","editor"},
                    {"PartialSpanEnabled","True"}, {"PartialDisplayIdentity","editor"},
                    {"PartialMonitorWidth","2560"}, {"PartialMonitorHeight","1440"},
                    {"PartialWidth",selection.Width.ToString()}, {"PartialWorkspaceWidth",selection.WorkspaceWidth.ToString()},
                    {"PartialEdge",selection.OccupiedRight ? "RIGHT" : "LEFT"}, {"PartialGameSide",gameLeft ? "LEFT" : "RIGHT"}
                };
                var result = MonitorSelection.CreatePlan(overlaySettings, new List<MonitorSelection.Display> {
                    new MonitorSelection.Display { Index=0, StableId="editor", DeviceName="editor", Bounds=monitor }
                });
                if (result.Bounds != monitor || result.MainhandBounds.Width != 960 || result.WorkspaceBounds.Width != 1600)
                    throw new Exception("Visual selection did not round-trip through production planning.");
            }
            var move = new PartialRegionSelection(2560,1920,640,false,false);
            move.Move(0,false);
            if (move.OccupiedRight) throw new Exception("Stationary drag changed the monitor edge.");
            move.Move(400,false);
            if (!move.OccupiedRight || move.Left != 640) throw new Exception("Partial occupied rectangle did not snap right.");
            move.Move(0,false);
            if (move.OccupiedRight || move.Left != 0) throw new Exception("Dragging back did not restore the initial edge.");
            Console.WriteLine("PASS: visual selection gestures, size guardrails, edge snapping and production planner round trips");
            string root = args[0];
            string core = Path.Combine(root, "Interface", "AddOns", "Offhand", "Core");
            Directory.CreateDirectory(core);
            int count = 0;
            foreach (Point origin in new Point[] { Point.Empty, new Point(-5120, -1440) })
            foreach (bool occupiedRight in new bool[] { false, true })
            foreach (bool gameLeft in new bool[] { false, true })
            {
                Rectangle monitor = new Rectangle(origin, new Size(5120, 1440));
                Rectangle occupied = new Rectangle(origin.X + (occupiedRight ? 1040 : 0), origin.Y, 4080, 1440);
                var displays = new List<MonitorSelection.Display> {
                    new MonitorSelection.Display { Index = 0, DeviceName = "partial-fixture", StableId = "fixture",
                        Bounds = monitor, WorkArea = monitor, Primary = true }
                };
                var settings = new Dictionary<string,string> {
                    {"DisplayIdentityVersion","1"}, {"MonitorIdentities","fixture"}, {"MainhandIdentity","fixture"},
                    {"PartialSpanEnabled","True"}, {"PartialDisplayIdentity","fixture"},
                    {"PartialMonitorWidth","5120"}, {"PartialMonitorHeight","1440"},
                    {"PartialWidth","4080"}, {"PartialWorkspaceWidth","640"},
                    {"PartialEdge",occupiedRight ? "RIGHT" : "LEFT"}, {"PartialGameSide",gameLeft ? "LEFT" : "RIGHT"}
                };
                var plan = MonitorSelection.CreatePlan(settings, displays);
                if (!plan.PartialSingle || plan.Bounds != occupied
                    || plan.MainhandBounds.Width != 3440 || plan.WorkspaceBounds.Width != 640)
                    throw new Exception("Partial production plan bounds mismatch.");
                foreach (Rectangle visible in MonitorSelection.VisibleRectangles(plan))
                    if (!occupied.Contains(visible)) throw new Exception("Reserved pixels included in visible geometry.");
                IntPtr region = SpanClipRegion.Create(plan, plan.Bounds);
                try {
                    if (!PtInRegion(region, 0, 0) || !PtInRegion(region, 4079, 1439)
                        || PtInRegion(region, -1, 0) || PtInRegion(region, 4080, 0) || PtInRegion(region, 0, 1440))
                        throw new Exception("Native partial clipping includes reserved pixels or excludes occupied pixels.");
                } finally { NativeMethods.DeleteObject(region); }
                foreach (string key in new string[] { "PartialWidth", "PartialWorkspaceWidth", "PartialMonitorWidth", "PartialMonitorHeight", "PartialEdge", "PartialGameSide", "PartialDisplayIdentity" })
                {
                    var bad = new Dictionary<string,string>(settings); bad[key] = "invalid";
                    bool rejected = false;
                    try { MonitorSelection.CreatePlan(bad, displays); } catch (InvalidOperationException) { rejected = true; }
                    if (!rejected) throw new Exception("Malformed partial preference accepted: " + key);
                }
                foreach (string badWidth in new string[] { "0", "-2147483648", "2147483647", "-1", "5121", "1439", "640" })
                {
                    var bad = new Dictionary<string,string>(settings); bad["PartialWidth"] = badWidth;
                    bool rejected = false;
                    try { MonitorSelection.CreatePlan(bad, displays); } catch (InvalidOperationException) { rejected = true; }
                    if (!rejected) throw new Exception("Unsafe occupied width accepted: " + badWidth);
                }
                var equal = new Dictionary<string,string>(settings); equal["PartialSpanEnabled"] = "False"; equal["SingleDisplaySplit"] = "True";
                if (MonitorSelection.CreatePlan(equal, displays).Bounds != monitor) throw new Exception("Equal-half fallback changed.");
                var equalPlan = MonitorSelection.CreatePlan(equal, displays);
                if (equalPlan.PartialSingle || equalPlan.WorkspaceBounds.Width != 2560 || equalPlan.MainhandBounds.Width != 2560)
                    throw new Exception("Leaving custom mode retained partial geometry in the equal-half plan.");
                var dualDisplays = new List<MonitorSelection.Display>(displays) {
                    new MonitorSelection.Display { Index=1, StableId="second", DeviceName="second", Bounds=new Rectangle(origin.X-1920, origin.Y, 1920, 1440) }
                };
                var dual = new Dictionary<string,string>(settings);
                dual["MonitorIdentities"] = "fixture|second";
                bool multipleRejected = false;
                try { MonitorSelection.CreatePlan(dual, dualDisplays); } catch (InvalidOperationException) { multipleRejected = true; }
                if (!multipleRejected) throw new Exception("Custom mode accepted multiple selected physical displays.");
                dual["PartialSpanEnabled"] = "False";
                var dualPlan = MonitorSelection.CreatePlan(dual, dualDisplays);
                if (dualPlan.PartialSingle || dualPlan.Bounds != Rectangle.Union(monitor, dualDisplays[1].Bounds)
                    || dualPlan.MainhandBounds != monitor || dualPlan.WorkspaceBounds != dualDisplays[1].Bounds)
                    throw new Exception("Leaving custom mode retained partial geometry in the two-display plan.");
                if (MonitorSelection.CreatePlan(settings, displays).Bounds != occupied)
                    throw new Exception("Returning to custom mode lost its saved geometry.");
                foreach (Size changedSize in new Size[] {new Size(5121,1440), new Size(5120,1441)}) {
                    var changedDisplays = new List<MonitorSelection.Display> {
                        new MonitorSelection.Display { Index=0, StableId="fixture", DeviceName="partial-fixture", Bounds=new Rectangle(origin, changedSize) }
                    };
                    bool changedRejected = false;
                    try { MonitorSelection.CreatePlan(settings, changedDisplays); } catch (InvalidOperationException) { changedRejected = true; }
                    if (!changedRejected) throw new Exception("Custom plan accepted a changed physical monitor resolution.");
                }
                var renamed = new List<MonitorSelection.Display> {new MonitorSelection.Display { Index=0, StableId="fixture", DeviceName="renumbered", Bounds=monitor }};
                if (MonitorSelection.CreatePlan(settings, renamed).Bounds != occupied) throw new Exception("Stable identity did not survive renumbering.");
                foreach (string badWorkspace in new string[] {"0", "479", "4080", "3440", "-2147483648", "2147483647"}) {
                    var bad = new Dictionary<string,string>(settings); bad["PartialWorkspaceWidth"] = badWorkspace;
                    bool rejected = false; try { MonitorSelection.CreatePlan(bad, displays); } catch (InvalidOperationException) { rejected = true; }
                    if (!rejected) throw new Exception("Unsafe workspace width accepted: " + badWorkspace);
                }
                string message;
                byte[] written;
                if (!CompanionTopologyBridge.TryWrite(root, plan, displays, out message, out written))
                    throw new Exception(message);
                if (!CompanionTopologyBridge.IsCurrent(root, plan, displays)
                    || !SpanRollback.SameBytes(written, File.ReadAllBytes(Path.Combine(core, "CompanionTopology.lua"))))
                    throw new Exception("Written partial fixture does not match its actual plan bytes.");
                File.WriteAllBytes(Path.Combine(root, (++count).ToString() + ".lua"), written);
            }
            Console.WriteLine("PASS: {0} generated schema 1 partial-plan fixtures, both edges/sides and negative origins", count);
        }
    }
}
