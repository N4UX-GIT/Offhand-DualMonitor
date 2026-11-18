using System;
using System.Diagnostics;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;

namespace Offhand.Companion
{
    internal static class ClientSelectionTest
    {
        private static int checks;

        private static void Check(bool value, string label)
        {
            if (!value) throw new Exception(label);
            checks++;
        }

        private static WoWClientWindow Client(int pid, long started, int handle, string title)
        {
            return new WoWClientWindow(pid, started, new IntPtr(handle), title, "Wow");
        }

        private sealed class TestWindow : Form
        {
            protected override bool ShowWithoutActivation { get { return true; } }
        }

        internal static void ShowTestWindow()
        {
            using (var form = new TestWindow { Text = "Offhand test client" })
                Application.Run(form);
        }

        // This read-only test reopens only processes launched by the fixture. It never starts the Companion dashboard.
        internal static void NativeResolution()
        {
            var children = new System.Collections.Generic.List<Process>();
            try
            {
                var clients = new WoWClientWindow[2];
                for (int i = 0; i < clients.Length; i++)
                {
                    var child = Process.Start(new ProcessStartInfo(Assembly.GetExecutingAssembly().Location, "--test-client-window")
                        { UseShellExecute = false, CreateNoWindow = true });
                    children.Add(child);
                    var timer = Stopwatch.StartNew();
                    while (child.MainWindowHandle == IntPtr.Zero && !child.HasExited && timer.ElapsedMilliseconds < 10000)
                    {
                        Thread.Sleep(50);
                        child.Refresh();
                    }
                    Check(!child.HasExited && child.MainWindowHandle != IntPtr.Zero, "Test client opened a real window");
                    clients[i] = new WoWClientWindow(child.Id, child.StartTime.ToUniversalTime().Ticks, child.MainWindowHandle,
                        child.MainWindowTitle, child.ProcessName);
                }
                var selection = new WoWClientSelection();
                selection.Select(clients[1]);
                var chosen = selection.Resolve(clients, true);
                using (var live = CompanionForm.OpenLiveClient(chosen))
                    Check(live != null && live.Id == children[1].Id && live.MainWindowHandle == clients[1].Handle,
                        "Companion reopens exactly the selected process and window");
                using (var wrong = CompanionForm.OpenLiveClient(new WoWClientWindow(chosen.Pid, chosen.StartedUtcTicks,
                    clients[0].Handle, chosen.Title, chosen.ProcessName)))
                    Check(wrong == null, "Companion refuses a window belonging to another running PID");
                using (var wrong = CompanionForm.OpenLiveClient(new WoWClientWindow(chosen.Pid, chosen.StartedUtcTicks + 1,
                    chosen.Handle, chosen.Title, chosen.ProcessName)))
                    Check(wrong == null, "Companion refuses a PID with another creation time");
                children[1].CloseMainWindow();
                Check(children[1].WaitForExit(5000), "Selected test client exited");
                using (var stale = CompanionForm.OpenLiveClient(chosen))
                    Check(stale == null && !children[0].HasExited, "Companion never returns the sibling after the selected client exits");
                Console.WriteLine("PASS: native selected PID and HWND resolved, stale and mismatched identities refused");
            }
            finally
            {
                foreach (var child in children)
                {
                    using (child)
                    {
                        if (!child.HasExited && (!child.CloseMainWindow() || !child.WaitForExit(3000))) child.Kill();
                        child.WaitForExit();
                    }
                }
            }
        }

        internal static void Main()
        {
            var first = Client(100, 1, 50, "World of Warcraft");
            var second = Client(200, 2, 60, "World of Warcraft");
            var third = Client(300, 3, 70, "World of Warcraft");
            var none = new WoWClientWindow[0];
            var selection = new WoWClientSelection();
            Check(selection.Resolve(none, false) == null, "No window before any client starts");
            Check(first.SameWindow(selection.Resolve(new[] { first }, true)), "A single client can be used automatically");
            Check(selection.Resolve(new[] { first, second }, true) == null, "A second client requires an explicit choice");

            selection = new WoWClientSelection();
            selection.Resolve(new[] { first }, true);
            selection.Pin();
            Check(first.SameWindow(selection.Resolve(new[] { third, first, second }, true)),
                "A client spanned before its siblings launch stays pinned");
            Check(selection.Resolve(new[] { second, third }, true) == null, "A missing pinned client has no replacement");
            Check(selection.Resolve(new[] { third }, true) == null, "The last remaining sibling cannot inherit a pinned span");

            selection = new WoWClientSelection();
            selection.Resolve(new[] { first }, true);
            Check(selection.Resolve(new[] { second }, true) == null, "A different sole client cannot inherit an automatic selection");
            selection.Select(null);
            Check(selection.Resolve(new[] { first }, true) == null, "An explicit deselection stays empty");
            selection.Resolve(none, false);
            Check(selection.Resolve(new[] { first }, true) == null, "An explicit deselection survives a zero-client interval");

            selection = new WoWClientSelection();
            Check(selection.Resolve(new[] { first, second, third }, true) == null, "Three identical titles cannot pick a target");
            selection.Select(second);
            var renamed = Client(200, 2, 60, "WoW - Main");
            Check(renamed.SameWindow(selection.Resolve(new[] { third, renamed, first }, true)),
                "The chosen client survives reorder and title changes");
            Check(selection.Resolve(new[] { first }, true) == null, "Closing the chosen client never switches to the remaining client");

            foreach (var replacement in new[] {
                Client(201, 2, 60, "World of Warcraft"), // HWND in a different process
                Client(200, 4, 60, "World of Warcraft"), // recycled PID and HWND
                Client(200, 2, 61, "World of Warcraft")  // new window in the same process
            })
            {
                selection.Select(second);
                Check(selection.Resolve(new[] { replacement }, true) == null, "Reused identities require a new selection");
                selection.Select(replacement);
                Check(replacement.SameWindow(selection.Resolve(new[] { first, replacement }, true)),
                    "An explicitly reselected replacement can be used");
            }
            Console.WriteLine("PASS: " + checks + " WoW client selection checks");
        }
    }
}
