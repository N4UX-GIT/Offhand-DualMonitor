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
