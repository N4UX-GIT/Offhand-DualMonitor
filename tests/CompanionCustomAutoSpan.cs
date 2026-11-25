using System;
using System.Collections.Generic;
using System.Drawing;

namespace Offhand.Companion
{
    // Auto-span for custom layouts: allowed only for the exact layout last spanned by hand on the same monitors.
    internal static class CustomAutoSpanTest
    {
        private static int assertions;
        private static void Check(bool value, string message)
        { assertions++; if (!value) throw new Exception(message); }

        private static MonitorSelection.Display D(int index, string id, int x, int y, int w, int h)
        {
            return new MonitorSelection.Display { Index = index, DeviceName = "\\\\.\\DISPLAY" + (index + 1), StableId = id,
                Bounds = new Rectangle(x, y, w, h), WorkArea = new Rectangle(x, y, w, h - 40) };
        }

        private static MonitorSelection.Plan Split(int workspaceWidth)
        {
            return new MonitorSelection.Plan { Indices = new[] { 0 }, MainhandIndex = 0, WorkspaceIndex = 0, SplitSingle = true,
                PartialSingle = true, Bounds = new Rectangle(0, 0, workspaceWidth + 2560, 1440),
                MainhandBounds = new Rectangle(workspaceWidth, 0, 2560, 1440), WorkspaceBounds = new Rectangle(0, 0, workspaceWidth, 1440) };
        }

        private static int Main()
        {
            var acer = new List<MonitorSelection.Display> { D(0, "ACR-ultrawide", 0, 0, 5120, 1440) };
            string key = CustomAutoSpan.Fingerprint(Split(1280), acer);
            Check(!string.IsNullOrEmpty(key) && key.IndexOfAny(new[] { '\r', '\n', '=' }) < 0, "one line, safe for the settings file");
            Check(key == CustomAutoSpan.Fingerprint(Split(1280), acer), "the same layout on the same monitor: the same fingerprint");
            Check(key != CustomAutoSpan.Fingerprint(Split(1440), acer), "a resized workspace: a different fingerprint");
            Check(key != CustomAutoSpan.Fingerprint(Split(1280), new List<MonitorSelection.Display> { D(0, "OTHER-monitor", 0, 0, 5120, 1440) }),
                "another monitor: a different fingerprint");
            Check(key != CustomAutoSpan.Fingerprint(Split(1280), new List<MonitorSelection.Display> { D(0, "ACR-ultrawide", 0, 0, 5120, 1440),
                D(1, "MSI", 5120, 0, 1920, 1080) }), "a monitor added: a different fingerprint");
            Check(key != CustomAutoSpan.Fingerprint(Split(1280), new List<MonitorSelection.Display> { D(0, "ACR-ultrawide", 0, 0, 3840, 1080) }),
                "the monitor's resolution changed: a different fingerprint");
            Check(CustomAutoSpan.Fingerprint(null, acer) == null, "no plan: no fingerprint");

            Check(CustomAutoSpan.Refusal(false, false, false, null, null) == null, "standard layouts auto-span as before");
            Check(CustomAutoSpan.Refusal(true, true, false, null, key) == null, "a manual span is never refused");
            Check(CustomAutoSpan.Refusal(true, false, false, null, key) != null, "custom, never spanned by hand: skipped");
            Check(CustomAutoSpan.Refusal(true, false, false, "", key) != null, "custom, empty record: skipped");
            Check(CustomAutoSpan.Refusal(true, false, false, CustomAutoSpan.Fingerprint(Split(1440), acer), key) != null,
                "custom, layout changed since the manual span: skipped");
            Check(CustomAutoSpan.Refusal(true, false, false, key, key) == null, "custom, same layout and monitors: auto-spans");
            Check(CustomAutoSpan.Refusal(true, false, true, key, key) != null, "graphics recovery stays manual-only for custom layouts");
            Check(CustomAutoSpan.Refusal(true, false, false, key, key.ToLowerInvariant()) != null || key == key.ToLowerInvariant(),
                "an exact match only");

            Console.WriteLine("CustomAutoSpan: " + assertions + " assertions passed");
            return 0;
        }
    }
}
