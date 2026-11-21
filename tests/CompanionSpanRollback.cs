using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace Offhand.Companion
{
    internal static class SpanRollbackTest
    {
        private static int assertions;
        [DllImport("gdi32.dll")] private static extern bool EqualRgn(IntPtr a, IntPtr b);
        private static void Check(bool value, string message)
        { assertions++; if (!value) throw new Exception(message); }

        private static IntPtr Shape()
        {
            IntPtr a = NativeMethods.CreateRectRgn(0, 0, 80, 120);
            IntPtr b = NativeMethods.CreateRectRgn(80, 60, 180, 120);
            try { Check(NativeMethods.CombineRgn(a, a, b, 2) != 0, "synthetic L region"); }
            finally { NativeMethods.DeleteObject(b); }
            return a;
        }

        private static void Verify(IntPtr handle, NativeMethods.RECT bounds, int style, IntPtr expected)
        {
            NativeMethods.RECT actual;
            Check(NativeMethods.GetWindowRect(handle, out actual)
                && actual.Left == bounds.Left && actual.Top == bounds.Top
                && actual.Width == bounds.Width && actual.Height == bounds.Height,
                "exact prior outer bounds: actual " + actual.Left + "," + actual.Top + " " + actual.Width + "x" + actual.Height
                + " expected " + bounds.Left + "," + bounds.Top + " " + bounds.Width + "x" + bounds.Height);
            Check(NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE) == style, "prior style");
            Check(!NativeMethods.IsWindowVisible(handle), "synthetic window remains hidden");
            IntPtr read = NativeMethods.CreateRectRgn(0,0,0,0);
            try
            {
                int type = NativeMethods.GetWindowRgn(handle, read);
                Check(expected == IntPtr.Zero ? type == 0 : type != 0 && EqualRgn(read, expected),
                    "exact prior region, including holes or absence");
            }
            finally { NativeMethods.DeleteObject(read); }
        }

        private static void CheckCustomRollback(string root)
        {
            string core = Path.Combine(root, "Interface", "AddOns", "Offhand", "Core");
            Directory.CreateDirectory(core);
            string path = Path.Combine(core, "CompanionTopology.lua");
            foreach (Point origin in new Point[] { Point.Empty, new Point(-5120, -1440) })
            foreach (string edge in new string[] { "LEFT", "RIGHT" })
            foreach (string side in new string[] { "LEFT", "RIGHT" })
            foreach (bool secondary in new bool[] {false,true})
            for (int clipped = 0; clipped < 2; clipped++)
            for (int stage = 0; stage < 5; stage++)
            // The topology is synthetic and can be wider than the host monitor.
            // A default WinForms maximum inherits Windows' local tracking limit,
            // which would clamp the fixture before rollback can be exercised.
            // Keep exact readback assertions and explicitly permit this test size.
            using (var window = new Form { MaximumSize = new Size(16384, 16384) })
            {
                var displays = new List<MonitorSelection.Display> {
                    new MonitorSelection.Display { Index=0, StableId="custom", DeviceName="custom",
                        Bounds=new Rectangle(origin, new Size(2560,1440)), Primary=true }
                };
                var settings = new Dictionary<string,string> {
                    {"DisplayIdentityVersion","1"}, {"MonitorIdentities","custom"}, {"MainhandIdentity","custom"},
                    {"PartialSpanEnabled","True"}, {"PartialDisplayIdentity","custom"},
                    {"PartialMonitorWidth","2560"}, {"PartialMonitorHeight","1440"},
                    {"PartialWidth","1920"}, {"PartialWorkspaceWidth","640"},
                    {"PartialEdge",edge}, {"PartialGameSide",side}
                };
                if(secondary) {
                    displays.Add(new MonitorSelection.Display {Index=1,StableId="secondary",DeviceName="secondary",
                        Bounds=new Rectangle(origin.X-1440,origin.Y-1114,1440,2560)});
                    settings["PartialSpanEnabled"]="False";settings["SecondaryAreaEnabled"]="True";
                    settings["MonitorIdentities"]="custom|secondary";settings["SecondaryAreaIdentity"]="secondary";
                    settings["SecondaryMonitorWidth"]="1440";settings["SecondaryMonitorHeight"]="2560";
                    settings["SecondaryAreaX"]="800";settings["SecondaryAreaY"]="1114";
                    settings["SecondaryAreaWidth"]="640";settings["SecondaryAreaHeight"]="1440";
                }
                var plan = MonitorSelection.CreatePlan(settings, displays);
                IntPtr handle = window.Handle;
                IntPtr expected = clipped == 1 ? Shape() : IntPtr.Zero;
                try {
                    if (clipped == 1) Check(NativeMethods.SetWindowRgn(handle, Shape(), false) != 0, "custom prior clipping");
                    NativeMethods.RECT prior;
                    Check(NativeMethods.GetWindowRect(handle, out prior), "custom prior bounds");
                    int style = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE);
                    byte[] original = new byte[] { 255,254,0,16,200 };
                    File.WriteAllBytes(path, original);
                    using (var rollback = new SpanRollback(path, handle)) {
                        string message; byte[] written;
                        Check(CompanionTopologyBridge.TryWrite(root, plan, displays, out message, out written), "custom production topology write: " + message);
                        rollback.TopologyWritten(written);
                        if (stage > 0) {
                            rollback.WindowChanged = true;
                            NativeMethods.SetWindowLong(handle, NativeMethods.GWL_STYLE, style & ~(NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME));
                        }
                        if (stage > 1) {
                            IntPtr region = SpanClipRegion.Create(plan, plan.Bounds);
                            if (NativeMethods.SetWindowRgn(handle, region, false) == 0) {
                                NativeMethods.DeleteObject(region);
                                throw new Exception("Could not install production custom clipping.");
                            }
                        }
                        if (stage > 2)
                            Check(NativeMethods.SetWindowPos(handle, IntPtr.Zero, plan.Bounds.X, plan.Bounds.Y,
                                plan.Bounds.Width, plan.Bounds.Height, 0x0034), "custom native resize");
                        if (stage > 3) {
                            NativeMethods.RECT actual;
                            Check(NativeMethods.GetWindowRect(handle, out actual) && actual.Left == plan.Bounds.X
                                && actual.Top == plan.Bounds.Y && actual.Width == plan.Bounds.Width
                                && actual.Height == plan.Bounds.Height, "custom applied bounds before verification failure: "
                                + actual.Left + "," + actual.Top + " " + actual.Width + "x" + actual.Height + " expected " + plan.Bounds);
                        }
                        // Fail at file, style, clipping, bounds or readback verification.
                        Check(rollback.Rollback() == null, "custom rollback after stage " + stage);
                        Check(rollback.Rollback() == null, "custom rollback remains idempotent");
                    }
                    Check(SpanRollback.SameBytes(File.ReadAllBytes(path), original), "custom raw topology bytes restored");
                    Verify(handle, prior, style, expected);
                } finally { if (expected != IntPtr.Zero) NativeMethods.DeleteObject(expected); }
            }
            Console.WriteLine("PASS: 160 single/secondary custom native rollback cases, both origins, prior clipping or none, five failure stages");
        }

        private static void CheckCustomDpiResize()
        {
            var requested = new Rectangle(-2160, -611, 4720, 2069);
            var plan = new MonitorSelection.Plan {
                Bounds = requested, MainhandBounds = new Rectangle(0, 0, 2560, 1440),
                WorkspaceBounds = new Rectangle(-2160, -611, 2160, 2069),
            };
            var observed = new ClassicGraphicsRecovery.Observation {
                Bounds = new Rectangle(-2160, -611, 6660, 3104), Client = new Size(6660, 3104),
                Region = new Rectangle(Point.Empty, requested.Size), Style = 0x140B0000, Usable = true,
            };
            Check(SpanDpiRetry.Matches(requested, observed, 96, 144), "150% custom span with capped width");
            Check(!SpanDpiRetry.Matches(requested, observed, 144, 144), "unchanged DPI does not trigger a retry");
            Check(!SpanDpiRetry.Matches(requested, observed, 0, 144), "unavailable DPI does not trigger a retry");
            observed.Bounds.Offset(1, 0);
            Check(!SpanDpiRetry.Matches(requested, observed, 96, 144), "different origin does not trigger a retry");
            observed.Bounds.Offset(-1, 0);
            observed.Bounds.Height = 3000;
            observed.Client = observed.Bounds.Size;
            Check(!SpanDpiRetry.Matches(requested, observed, 96, 144), "height must match the measured DPI ratio");
            observed.Bounds.Height = 3104;
            observed.Client = observed.Bounds.Size;
            observed.Style |= NativeMethods.WS_THICKFRAME;
            Check(!SpanDpiRetry.Matches(requested, observed, 96, 144), "changed window style does not trigger a retry");
            observed.Style = 0x140B0000;
            observed.Region = Rectangle.Empty;
            Check(!SpanDpiRetry.Matches(requested, observed, 96, 144), "missing clipping does not trigger a retry");
            observed.Region = new Rectangle(Point.Empty, requested.Size);
            Check(!SpanDpiRetry.IsExact(requested, observed, 0x140B0000), "oversized retry cannot commit");
            observed.Bounds = requested;
            Check(!SpanDpiRetry.IsExact(requested, observed, 0x140B0000),
                "exact window with an oversized client cannot commit");
            observed.Client = requested.Size;
            Check(SpanDpiRetry.IsExact(requested, observed, 0x140B0000),
                "exact window, client and region can commit");

            // A span that lands mostly on a lower-scale monitor shrinks instead of growing.
            var shrunk = new ClassicGraphicsRecovery.Observation {
                Bounds = new Rectangle(-2160, -611, 3147, 1379), Client = new Size(3147, 1379),
                Region = new Rectangle(Point.Empty, requested.Size), Style = 0x140B0000, Usable = true,
            };
            Check(SpanDpiRetry.Matches(requested, shrunk, 144, 96), "150% to 100% shrink triggers a retry");
            Check(!SpanDpiRetry.Matches(requested, shrunk, 96, 144), "a shrink does not match a scale increase");
            shrunk.Bounds.Width = 3000;
            shrunk.Client = shrunk.Bounds.Size;
            Check(!SpanDpiRetry.Matches(requested, shrunk, 144, 96), "a shrink cannot pass the scaled request");
            Check(!SpanDpiRetry.Matches(requested, observed, 144, 96), "an exact window is not a DPI shrink");

            // Every way of spanning gets the retry; only the graphics-recovery test candidate does not.
            Check(SpanDpiRetry.Allowed(false), "manual, automatic, standard, custom, remote and recovery spans retry");
            Check(!SpanDpiRetry.Allowed(true), "the graphics-recovery test candidate does not retry");
            Check(SpanDpiRetry.SameSession(false, RemoteDesktop.State.Local, false, true), "local span, same displays");
            Check(!SpanDpiRetry.SameSession(false, RemoteDesktop.State.Local, false, false), "local span, displays changed");
            Check(!SpanDpiRetry.SameSession(false, RemoteDesktop.State.Active, false, true), "local span, session went remote");
            Check(SpanDpiRetry.SameSession(true, RemoteDesktop.State.Active, true, true), "remote span, same connection");
            Check(!SpanDpiRetry.SameSession(true, RemoteDesktop.State.Active, false, true), "remote span, connection changed");
            Check(!SpanDpiRetry.SameSession(true, RemoteDesktop.State.Local, true, true), "remote span, session ended");

            using (var window = new Form())
            {
                IntPtr handle = window.Handle;
                Check(!SpanClipRegion.Matches(handle, plan, requested), "no clipping does not match");
                Check(NativeMethods.SetWindowRgn(handle, NativeMethods.CreateRectRgn(0, 0, 4720, 2069), false) != 0,
                    "install clipping with the same bounds but a different shape");
                Check(!SpanClipRegion.Matches(handle, plan, requested),
                    "matching clipping bounds alone cannot authorize a retry");
                Check(NativeMethods.SetWindowRgn(handle, SpanClipRegion.Create(plan, requested), false) != 0,
                    "install exact custom clipping");
                Check(SpanClipRegion.Matches(handle, plan, requested), "exact clipping shape matches");
            }
            Console.WriteLine("PASS: reported custom span DPI signature and exact native clipping verification");
        }

        private static void CheckRestoreDpiResize()
        {
            foreach (string scenario in new[] { "success", "same DPI", "unknown DPI", "different origin",
                "wrong size", "changed style", "clipped", "window changed", "retry rejected", "late DPI change" })
            using (var window = new NativeRestoreFixture())
            {
                IntPtr handle = window.Handle;
                NativeMethods.RECT before;
                Check(NativeMethods.GetWindowRect(handle, out before), "pre-restore DPI fixture bounds");
                int style = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE);
                int targetStyle = style | NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME;
                // Keep this replay inside small CI desktops and away from real
                // monitor seams. The 2/3 resize still includes fractional
                // rounding, just as the live 1920x968 -> 1280x645 case did.
                var target = new Rectangle(64, 48, 600, 448);
                var shrunk = new Size(400, 298);
                IntPtr clipping = Shape();
                try
                {
                    Check(NativeMethods.SetWindowRgn(handle, Shape(), false) != 0, "DPI fixture pre-restore clipping");
                    uint dpi = 144;
                    int retryCount = 0;
                    string failure = null;
                    bool retried = false;
                    uint flags = NativeMethods.SWP_NOZORDER | NativeMethods.SWP_NOACTIVATE | NativeMethods.SWP_FRAMECHANGED;
                    try
                    {
                        retried = WindowRestore.Apply(handle, target, targetStyle, stage =>
                        {
                            // Mimic WoW applying the suggested smaller rectangle
                            // during the first resize. The next call is real Win32.
                            if (stage == "bounds")
                            {
                                dpi = scenario == "same DPI" ? 144u : scenario == "unknown DPI" ? 0u : 96u;
                                Check(NativeMethods.SetWindowPos(handle, IntPtr.Zero,
                                    target.X + (scenario == "different origin" ? 1 : 0), target.Y, shrunk.Width,
                                    shrunk.Height + (scenario == "wrong size" ? 6 : 0), flags), "DPI fixture first shrink");
                                if (scenario == "changed style")
                                    NativeMethods.SetWindowLong(handle, NativeMethods.GWL_STYLE, style);
                                if (scenario == "clipped")
                                    Check(NativeMethods.SetWindowRgn(handle, Shape(), false) != 0, "DPI fixture retained clipping");
                            }
                            if (stage == "dpi-retry")
                            {
                                retryCount++;
                                if (scenario == "retry rejected")
                                    Check(NativeMethods.SetWindowPos(handle, IntPtr.Zero, target.X, target.Y,
                                        shrunk.Width, shrunk.Height, flags),
                                        "DPI fixture second shrink");
                                if (scenario == "late DPI change") dpi = 120;
                            }
                        }, _ => dpi, () => scenario != "window changed");
                    }
                    catch (IOException ex) { failure = ex.Message; }
                    bool succeeds = scenario == "success";
                    bool shouldRetry = succeeds || scenario == "retry rejected" || scenario == "late DPI change";
                    Check(retryCount == (shouldRetry ? 1 : 0), "bound restore DPI retry: " + scenario + " " + failure);
                    Check(retried == succeeds, "expected DPI restore outcome: " + scenario + " " + failure);
                    if (succeeds)
                    {
                        var restored = new NativeMethods.RECT { Left = target.Left, Top = target.Top,
                            Right = target.Right, Bottom = target.Bottom };
                        Verify(handle, restored, targetStyle, IntPtr.Zero);
                    }
                    else
                    {
                        Check(failure != null && failure.Contains("Window DPI before/after")
                            && (!shouldRetry || failure.Contains("DPI retry observed")),
                            "restore error retains actionable readback: " + scenario);
                        Verify(handle, before, style, clipping);
                    }
                }
                finally { NativeMethods.DeleteObject(clipping); }
            }
            Console.WriteLine("PASS: reverse-DPI Restore retries once, verifies exact normal size or restores prior span");
        }

        private sealed class NativeRestoreFixture : NativeWindow, IDisposable
        {
            internal NativeRestoreFixture()
            {
                // A Form can reapply its managed clipping after a native resize.
                // A hidden top-level native window keeps this a Win32-only replay.
                CreateHandle(new CreateParams { X = 80, Y = 64, Width = 540, Height = 420 });
            }

            public void Dispose()
            {
                DestroyHandle();
            }
        }

        [STAThread]
        private static void CheckStandardRespanRollback(string root)
        {
            string path = Path.Combine(root, "standard-respan.lua");
            byte[] original = { 7, 10, 12 };
            byte[] written = { 14, 15 };
            File.WriteAllBytes(path, original);
            using (var window = new Form { StartPosition = FormStartPosition.Manual, Bounds = new Rectangle(210, 110, 650, 450) })
            {
                IntPtr handle = window.Handle;
                using (var rollback = new SpanRollback(path, handle))
                {
                    Check(rollback.IsRestoredNormalWindow(), "capture an unclipped single-screen window");
                    int borders = NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME;
                    int originalStyle = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE);
                    var span = new Rectangle(50, 50, 1150, 800);
                    IntPtr clip = Shape();
                    try
                    {
                        // Model a span that succeeds and then shrinks at the span origin.
                        File.WriteAllBytes(path, written);
                        rollback.TopologyWritten(written);
                        rollback.WindowChanged = true;
                        NativeMethods.SetWindowLong(handle, NativeMethods.GWL_STYLE, originalStyle & ~borders);
                        Check(NativeMethods.SetWindowPos(handle, IntPtr.Zero, span.X, span.Y, span.Width, span.Height, 0x0034), "apply the spanned bounds");
                        Check(NativeMethods.SetWindowRgn(handle, clip, false) != 0, "apply the span clip");
                        clip = IntPtr.Zero;
                        NativeMethods.SetWindowLong(handle, NativeMethods.GWL_STYLE, originalStyle);
                        Check(NativeMethods.SetWindowPos(handle, IntPtr.Zero, span.X, span.Y, 600, 400, 0x0034), "shrink the window in place while leaving the clip");
                        Check(!rollback.IsRestoredNormalWindow(), "the shrunken window is still clipped and misplaced");
                        Check(rollback.Rollback() == null, "revert the delayed failure");
                        Check(rollback.IsRestoredNormalWindow(), "restore the prior position, size and unclipped borders");
                        Check(SpanRollback.SameBytes(File.ReadAllBytes(path), original), "restore the previous topology");
                    }
                    finally { if (clip != IntPtr.Zero) NativeMethods.DeleteObject(clip); }
                }
            }
        }

        public static void Main()
        {
            Check(Marshal.SizeOf(typeof(NativeMethods.WINDOWPLACEMENT)) == 44, "Windows SDK placement ABI");
            string root = Path.Combine(Path.GetTempPath(), "Offhand-span-rollback-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(root);
            try
            {
                // This fixture verifies that the native window is responsive.
                // Run it before the lengthy cases that do not pump UI messages.
                CheckRestoreDpiResize();
                CheckStandardRespanRollback(root);
                CheckCustomRollback(root);
                CheckCustomRestore();
                CheckCustomDpiResize();
                for (int clipped = 0; clipped < 2; clipped++)
                for (int stage = 0; stage < 5; stage++)
                using (var window = new Form())
                {
                    IntPtr handle = window.Handle;
                    IntPtr expected = clipped == 1 ? Shape() : IntPtr.Zero;
                    if (clipped == 1) Check(NativeMethods.SetWindowRgn(handle, Shape(), false) != 0, "install prior clipping");
                    NativeMethods.RECT prior;
                    Check(NativeMethods.GetWindowRect(handle, out prior), "capture prior bounds");
                    int priorStyle = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE);
                    string path = Path.Combine(root, "topology.lua");
                    byte[] original = new byte[] { 255, 254, 0, 16, 200 };
                    byte[] written = new byte[] { 1, 2, 3 };
                    File.WriteAllBytes(path, original);
                    using (var rollback = new SpanRollback(path, handle))
                    {
                        try
                        {
                            File.WriteAllBytes(path, written); rollback.TopologyWritten(written);
                            if (stage == 0) throw new IOException("injected after file write");
                            rollback.WindowChanged = true;
                            NativeMethods.SetWindowLong(handle, NativeMethods.GWL_STYLE,
                                priorStyle & ~(NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME));
                            if (stage == 1) throw new IOException("injected after style");
                            Check(NativeMethods.SetWindowRgn(handle, NativeMethods.CreateRectRgn(0,0,400,300), false) != 0, "new region");
                            if (stage == 2) throw new IOException("injected after clipping");
                            Check(NativeMethods.SetWindowPos(handle, IntPtr.Zero, 100, 120, 400, 300, 0x0034), "new bounds");
                            if (stage == 3) throw new IOException("injected after resize");
                            throw new IOException("injected verification failure");
                        }
                        catch (IOException) { Check(rollback.Rollback() == null, "complete rollback after stage " + stage); }
                        Check(rollback.Rollback() == null, "rollback is idempotent");
                    }
                    Check(SpanRollback.SameBytes(File.ReadAllBytes(path), original), "restore raw bytes without decoding");
                    Verify(handle, prior, priorStyle, expected);
                    if (expected != IntPtr.Zero) NativeMethods.DeleteObject(expected);
                }

                // Exercise the same native restore transaction used by the UI,
                // including failure after clipping has already been removed.
                for (int clipped = 0; clipped < 2; clipped++)
                foreach (string stage in new string[] { "style", "clipping", "bounds", "verification" })
                using (var window = new Form())
                {
                    IntPtr handle = window.Handle;
                    int borderless = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE)
                        & ~(NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME);
                    NativeMethods.SetWindowLong(handle, NativeMethods.GWL_STYLE, borderless);
                    IntPtr expected = clipped == 1 ? Shape() : IntPtr.Zero;
                    if (clipped == 1) Check(NativeMethods.SetWindowRgn(handle, Shape(), false) != 0, "prior restore clipping");
                    NativeMethods.RECT prior;
                    Check(NativeMethods.GetWindowRect(handle, out prior), "prior restore bounds");
                    bool failed = false;
                    try
                    {
                        WindowRestore.Apply(handle, new Rectangle(100, 120, 400, 300),
                            borderless | NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME,
                            delegate(string current) { if (current == stage) throw new IOException("injected restore " + stage); });
                    }
                    catch (IOException ex) { failed = ex.Message == "injected restore " + stage; }
                    Check(failed, "original restore failure retained after " + stage);
                    Verify(handle, prior, borderless, expected);
                    if (expected != IntPtr.Zero) NativeMethods.DeleteObject(expected);
                }

                using (var window = new Form())
                {
                    IntPtr handle = window.Handle;
                    Check(NativeMethods.SetWindowRgn(handle, Shape(), false) != 0, "successful restore prior clipping");
                    int style = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE)
                        | NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME;
                    Rectangle target = new Rectangle(100, 120, 400, 300);
                    WindowRestore.Apply(handle, target, style | NativeMethods.WS_MINIMIZE | NativeMethods.WS_MAXIMIZE);
                    NativeMethods.RECT restored;
                    Check(NativeMethods.GetWindowRect(handle, out restored), "successful restore readback");
                    Check(restored.Left == target.X && restored.Top == target.Y
                        && restored.Width == target.Width && restored.Height == target.Height, "successful restore exact bounds");
                    Verify(handle, restored, style, IntPtr.Zero);
                }

                using (var window = new Form())
                {
                    string path = Path.Combine(root, "new-topology.lua");
                    byte[] written = new byte[] { 1,2,3 };
                    using (var rollback = new SpanRollback(path, window.Handle))
                    {
                        File.WriteAllBytes(path, written); rollback.TopologyWritten(written);
                        Check(rollback.Rollback() == null && !File.Exists(path), "remove new file on failed span");
                    }
                    File.WriteAllBytes(path, new byte[] { 9 });
                    using (var rollback = new SpanRollback(path, window.Handle))
                    {
                        File.WriteAllBytes(path, written); rollback.TopologyWritten(written);
                        File.WriteAllBytes(path, new byte[] { 8 });
                        Check(rollback.Rollback().Contains("changed externally"), "external edit reported");
                        Check(File.ReadAllBytes(path)[0] == 8, "external edit preserved");
                    }
                    using (var rollback = new SpanRollback(path, window.Handle))
                    {
                        File.WriteAllBytes(path, written); rollback.TopologyWritten(written); rollback.Commit();
                        Check(rollback.Rollback() == null && SpanRollback.SameBytes(File.ReadAllBytes(path), written), "commit preserves successful topology");
                    }
                    using (var rollback = new SpanRollback(path, window.Handle))
                    {
                        File.WriteAllBytes(path, new byte[] { 7 }); rollback.TopologyWritten(new byte[] { 7 });
                        using (var locked = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.None))
                            Check(rollback.Rollback().Contains("topology"), "locked file failure is surfaced");
                    }
                    bool rejected = false;
                    try { using (var rollback = new SpanRollback(path, IntPtr.Zero)) { } }
                    catch (IOException) { rejected = true; }
                    Check(rejected, "invalid window aborts before mutation");
                    Check(Directory.GetFiles(root, "*.rollback-*").Length == 0, "temporary rollback files cleaned up");
                }
                foreach (FormWindowState state in new FormWindowState[] { FormWindowState.Minimized, FormWindowState.Maximized })
                foreach (string failureStage in new string[] { "style", "clipping", "bounds", "verification" })
                for (int clipped = 0; clipped < 2; clipped++)
                using (var window = new Form())
                {
                    window.ShowInTaskbar = false;
                    window.WindowState = state;
                    IntPtr handle = window.Handle;
                    Check(state == FormWindowState.Minimized ? NativeMethods.IsIconic(handle) : NativeMethods.IsZoomed(handle),
                        "native show-state fixture established: " + state);
                    NativeMethods.RECT prior;
                    Check(NativeMethods.GetWindowRect(handle, out prior), "show-state prior bounds");
                    var placement = new NativeMethods.WINDOWPLACEMENT();
                    placement.length = Marshal.SizeOf(typeof(NativeMethods.WINDOWPLACEMENT));
                    Check(NativeMethods.GetWindowPlacement(handle, ref placement), "show-state prior placement");
                    int style = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE);
                    IntPtr expected = clipped == 1 ? Shape() : IntPtr.Zero;
                    if (clipped == 1) Check(NativeMethods.SetWindowRgn(handle, Shape(), false) != 0,
                        "show-state prior complex clipping");
                    bool injected = false;
                    try
                    {
                        WindowRestore.Apply(handle, new Rectangle(100, 120, 400, 300), style,
                            delegate(string stage) { if (stage == failureStage) throw new IOException("show-state injected"); });
                    }
                    catch (IOException ex) { injected = ex.Message == "show-state injected"; }
                    Check(injected, "original failure retained for " + state);
                    Verify(handle, prior, style, expected);
                    Check(state == FormWindowState.Minimized ? NativeMethods.IsIconic(handle) : NativeMethods.IsZoomed(handle),
                        "native show-state restored: " + state);
                    var restored = new NativeMethods.WINDOWPLACEMENT();
                    restored.length = placement.length;
                    Check(NativeMethods.GetWindowPlacement(handle, ref restored), "show-state restored placement");
                    Check(restored.showCmd == placement.showCmd
                        && restored.ptMinPosition == placement.ptMinPosition
                        && restored.ptMaxPosition == placement.ptMaxPosition
                        && restored.rcNormalPosition.Left == placement.rcNormalPosition.Left
                        && restored.rcNormalPosition.Top == placement.rcNormalPosition.Top
                        && restored.rcNormalPosition.Right == placement.rcNormalPosition.Right
                        && restored.rcNormalPosition.Bottom == placement.rcNormalPosition.Bottom,
                        "normal/minimum/maximum placement retained after " + failureStage);
                    if (expected != IntPtr.Zero) NativeMethods.DeleteObject(expected);
                }
                Console.WriteLine("PASS: {0} span rollback assertions on synthetic native windows ({1} bit)", assertions, IntPtr.Size * 8);
            }
            finally { Directory.Delete(root, true); }
        }

        private static void CheckCustomRestore()
        {
            int cases = 0;
            foreach (Point origin in new Point[] { Point.Empty, new Point(-2560, -1440) })
            foreach (bool secondary in new bool[] { false, true })
            foreach (FormWindowState state in new FormWindowState[] {
                FormWindowState.Normal, FormWindowState.Minimized, FormWindowState.Maximized })
            foreach (string failureStage in new string[] { "style", "clipping", "bounds", "verification", null })
            using (var window = new Form())
            {
                var displays = new List<MonitorSelection.Display> {
                    new MonitorSelection.Display { Index=0, StableId="game", DeviceName="game",
                        Bounds=new Rectangle(origin, new Size(2560,1440)), Primary=true },
                    new MonitorSelection.Display { Index=1, StableId="work", DeviceName="work",
                        Bounds=new Rectangle(origin.X-1440,origin.Y-1114,1440,2560) }
                };
                var settings = new Dictionary<string,string> {
                    {"DisplayIdentityVersion","1"}, {"MainhandIdentity","game"},
                    {"MonitorIdentities",secondary ? "game|work" : "game"},
                    {"PartialSpanEnabled",(!secondary).ToString()}, {"PartialDisplayIdentity","game"},
                    {"PartialMonitorWidth","2560"}, {"PartialMonitorHeight","1440"},
                    {"PartialWidth","1920"}, {"PartialWorkspaceWidth","640"},
                    {"PartialEdge","LEFT"}, {"PartialGameSide","RIGHT"},
                    {"SecondaryAreaEnabled",secondary.ToString()}, {"SecondaryAreaIdentity","work"},
                    {"SecondaryMonitorWidth","1440"}, {"SecondaryMonitorHeight","2560"},
                    {"SecondaryAreaX","500"}, {"SecondaryAreaY","914"},
                    {"SecondaryAreaWidth","782"}, {"SecondaryAreaHeight","1290"}
                };
                var plan = MonitorSelection.CreatePlan(settings, displays);
                window.FormBorderStyle = FormBorderStyle.None;
                window.ShowInTaskbar = false;
                window.StartPosition = FormStartPosition.Manual;
                // The planner deliberately includes phantom negative-origin
                // displays. Keep the native fixture on this host's real desktop:
                // SetWindowPlacement may relocate wholly offscreen windows.
                // Negative topology and clipping remain covered independently.
                Rectangle fixtureBounds = plan.Bounds;
                bool onDesktop = false;
                foreach (Screen screen in Screen.AllScreens)
                    if (screen.Bounds.IntersectsWith(fixtureBounds)) onDesktop = true;
                if (!onDesktop) fixtureBounds.Location = Screen.PrimaryScreen.WorkingArea.Location;
                window.Bounds = fixtureBounds;
                window.WindowState = state;
                IntPtr handle = window.Handle;
                Check(NativeMethods.IsIconic(handle) == (state == FormWindowState.Minimized)
                    && NativeMethods.IsZoomed(handle) == (state == FormWindowState.Maximized),
                    "custom restore fixture show state: " + state);
                IntPtr expected = SpanClipRegion.Create(plan, plan.Bounds);
                IntPtr installed = SpanClipRegion.Create(plan, plan.Bounds);
                try
                {
                    if (NativeMethods.SetWindowRgn(handle, installed, false) == 0)
                        throw new IOException("Custom restore fixture clipping failed.");
                    installed = IntPtr.Zero; // Window owns the successful region.
                    NativeMethods.RECT prior;
                    Check(NativeMethods.GetWindowRect(handle, out prior), "custom restore prior bounds");
                    int style = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE);
                    var placement = new NativeMethods.WINDOWPLACEMENT();
                    placement.length = Marshal.SizeOf(typeof(NativeMethods.WINDOWPLACEMENT));
                    Check(NativeMethods.GetWindowPlacement(handle, ref placement), "custom restore prior placement");
                    Verify(handle, prior, style, expected);
                    var target = new Rectangle(100, 120, 400, 300);
                    int restoredStyle = (style | NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME)
                        & ~(NativeMethods.WS_MINIMIZE | NativeMethods.WS_MAXIMIZE);
                    bool injected = false;
                    try
                    {
                        WindowRestore.Apply(handle, target, restoredStyle, delegate(string stage) {
                            if (stage == failureStage) throw new IOException("custom restore injected " + stage);
                        });
                    }
                    catch (IOException ex)
                    {
                        if (failureStage == null || ex.Message != "custom restore injected " + failureStage) throw;
                        injected = true;
                    }
                    Check(injected == (failureStage != null), "custom restore expected outcome");
                    if (injected)
                    {
                        Verify(handle, prior, style, expected);
                        Check(NativeMethods.IsIconic(handle) == (state == FormWindowState.Minimized)
                            && NativeMethods.IsZoomed(handle) == (state == FormWindowState.Maximized),
                            "custom restore failure retains show state");
                        var actual = new NativeMethods.WINDOWPLACEMENT(); actual.length = placement.length;
                        Check(NativeMethods.GetWindowPlacement(handle, ref actual), "custom restore rollback placement");
                        Check(actual.showCmd == placement.showCmd
                            && actual.ptMinPosition == placement.ptMinPosition
                            && actual.ptMaxPosition == placement.ptMaxPosition
                            && actual.rcNormalPosition.Left == placement.rcNormalPosition.Left
                            && actual.rcNormalPosition.Top == placement.rcNormalPosition.Top
                            && actual.rcNormalPosition.Right == placement.rcNormalPosition.Right
                            && actual.rcNormalPosition.Bottom == placement.rcNormalPosition.Bottom,
                            "custom restore failure retains normal/minimum/maximum placement");
                    }
                    else
                    {
                        NativeMethods.RECT restored;
                        Check(NativeMethods.GetWindowRect(handle, out restored), "custom successful restore readback");
                        Check(restored.Left == target.X && restored.Top == target.Y
                            && restored.Width == target.Width && restored.Height == target.Height,
                            "custom successful restore exact target");
                        Verify(handle, restored, restoredStyle, IntPtr.Zero);
                        Check(!NativeMethods.IsIconic(handle) && !NativeMethods.IsZoomed(handle),
                            "custom successful restore returns normal state");
                    }
                    cases++;
                }
                finally
                {
                    if (installed != IntPtr.Zero) NativeMethods.DeleteObject(installed);
                    NativeMethods.DeleteObject(expected);
                }
            }
            Console.WriteLine("PASS: {0} production custom-clipping Restore cases, normal/minimized/maximized, two origins, four failure stages and success", cases);
        }
    }
}
