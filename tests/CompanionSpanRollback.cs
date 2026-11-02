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
                && actual.Width == bounds.Width && actual.Height == bounds.Height, "exact prior outer bounds");
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
            for (int clipped = 0; clipped < 2; clipped++)
            for (int stage = 0; stage < 5; stage++)
            using (var window = new Form())
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
            Console.WriteLine("PASS: 80 custom native rollback cases, both edges/sides/origins, prior clipping or none, five failure stages");
        }

        [STAThread]
        public static void Main()
        {
            Check(Marshal.SizeOf(typeof(NativeMethods.WINDOWPLACEMENT)) == 44, "Windows SDK placement ABI");
            string root = Path.Combine(Path.GetTempPath(), "Offhand-span-rollback-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(root);
            try
            {
                CheckCustomRollback(root);
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
    }
}
