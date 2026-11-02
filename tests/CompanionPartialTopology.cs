using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;

namespace Offhand.Companion
{
    // Characterization only: bypass the existing full-display planner with
    // explicit hypothetical plans. No partial mode is exposed in production.
    internal static class PartialTopologyTest
    {
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
                var plan = new MonitorSelection.Plan {
                    Indices = new int[] { 0 }, MainhandIndex = 0, WorkspaceIndex = 0,
                    SplitSingle = true, GameOnLeft = gameLeft, Bounds = occupied,
                    MainhandBounds = new Rectangle(occupied.X + (gameLeft ? 0 : 640), occupied.Y, 3440, 1440),
                    WorkspaceBounds = new Rectangle(occupied.X + (gameLeft ? 3440 : 0), occupied.Y, 640, 1440)
                };
                var displays = new List<MonitorSelection.Display> {
                    new MonitorSelection.Display { Index = 0, DeviceName = "partial-fixture", StableId = "fixture",
                        Bounds = monitor, WorkArea = monitor, Primary = true }
                };
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
