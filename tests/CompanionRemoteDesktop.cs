using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Windows.Forms;

namespace Offhand.Companion
{
    internal static class CompanionRemoteDesktopTest
    {
        private static int checks;

        private static void Check(bool condition, string label)
        {
            if (!condition) throw new Exception(label);
            checks++;
        }

        private static void Refuses(Action action)
        {
            try { action(); }
            catch (InvalidOperationException) { checks++; return; }
            throw new Exception("Expected the Remote Desktop selection to be refused.");
        }

        private static List<MonitorSelection.Display> Displays()
        {
            return new List<MonitorSelection.Display> {
                new MonitorSelection.Display { Index = 0, DeviceName = @"\\.\DISPLAY17",
                    Bounds = new Rectangle(0, 0, 1920, 1200), Primary = true },
                new MonitorSelection.Display { Index = 1, DeviceName = @"\\.\DISPLAY18",
                    Bounds = new Rectangle(-1920, 0, 1920, 1080), StableId = "SECONDARY" }
            };
        }

        private static void CheckPlanning()
        {
            var displays = Displays();
            for (int mainhand = 0; mainhand < 2; mainhand++)
            {
                var plan = RemoteDesktop.CreatePlan(displays, mainhand, 1 - mainhand);
                Check(plan.MainhandIndex == mainhand && plan.WorkspaceIndex == 1 - mainhand, "Explicit display roles");
                Check(plan.MainhandBounds == displays[mainhand].Bounds, "Mainhand geometry");
                Check(plan.Bounds == new Rectangle(-1920, 0, 3840, 1200), "Mixed-height negative-origin union");
                Check(plan.TopologySchema == 1 && !plan.IsCustom && !plan.SplitSingle, "Ordinary dual-display topology");
            }
            Refuses(() => RemoteDesktop.CreatePlan(displays, 0, 0));
            Refuses(() => RemoteDesktop.CreatePlan(displays, -1, 0));
            Refuses(() => RemoteDesktop.CreatePlan(displays, 0, 2));
            displays[1].DeviceName = displays[0].DeviceName.ToLowerInvariant();
            Refuses(() => RemoteDesktop.CreatePlan(displays, 0, 1));
            displays = Displays();
            displays[1].Bounds = displays[0].Bounds;
            Refuses(() => RemoteDesktop.CreatePlan(displays, 0, 1));
        }

        private static void CheckConnection()
        {
            var confirmed = Displays();
            var current = Displays();
            var active = RemoteDesktop.State.Active;
            Check(RemoteDesktop.SameConnection(active, true, 3, 3, confirmed, current), "Fresh connection and displays");
            Check(!RemoteDesktop.SameConnection(active, true, 3, 4, confirmed, current), "Reconnect even with identical displays");
            Check(!RemoteDesktop.SameConnection(active, false, 3, 3, confirmed, current), "Missing change notifications");
            Check(!RemoteDesktop.SameConnection(RemoteDesktop.State.Local, true, 3, 3, confirmed, current), "Console switch");
            Check(!RemoteDesktop.SameConnection(RemoteDesktop.State.Unavailable, true, 3, 3, confirmed, current), "Disconnected session");
            current[1].Bounds = new Rectangle(-1920, 40, 1920, 1080);
            Check(!RemoteDesktop.SameConnection(active, true, 3, 3, confirmed, current), "Display position changed");
            current.RemoveAt(1);
            Check(!RemoteDesktop.SameConnection(active, true, 3, 3, confirmed, current), "Display removed");
            foreach (int reason in new[] { 1, 2, 3, 4, 6 }) Check(RemoteDesktop.ConnectionChanged(reason), "Session transition");
            Check(!RemoteDesktop.ConnectionChanged(8), "Unlock does not itself change connection");
        }

        private static void CheckDialog()
        {
            using (var dialog = new RemoteDisplayDialog(Displays()))
            {
                var combos = dialog.Controls[0].Controls.OfType<ComboBox>().ToArray();
                var span = (Button)dialog.AcceptButton;
                Check(!span.Enabled && dialog.Mainhand == -1, "No implicit Mainhand");
                combos[0].SelectedIndex = 1;
                Check(span.Enabled && dialog.Mainhand == 1 && dialog.Workspace == 0, "Second screen as Mainhand");
                combos[1].SelectedIndex = 1;
                Check(!span.Enabled, "Duplicate selection cannot be confirmed");
                combos[0].SelectedIndex = 0;
                Check(span.Enabled && dialog.Mainhand == 0 && dialog.Workspace == 1, "First screen as Mainhand");
                Check(((Button)dialog.CancelButton).DialogResult == DialogResult.Cancel, "Cancel closes without confirmation");
            }
        }

        private static void CheckTopologyOwnership()
        {
            string root = Path.Combine(Path.GetTempPath(), "Offhand-rdp-topology-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(root);
            string path = Path.Combine(root, "CompanionTopology.lua");
            try
            {
                File.WriteAllText(path, "physical topology");
                var snapshot = new TopologySnapshot(path);
                File.WriteAllText(path, "remote topology");
                snapshot.RecordWrite(File.ReadAllBytes(path));
                snapshot.Restore();
                Check(File.ReadAllText(path) == "physical topology", "Restore the original topology");

                snapshot = new TopologySnapshot(path);
                File.WriteAllText(path, "remote topology");
                snapshot.RecordWrite(File.ReadAllBytes(path));
                File.WriteAllText(path, "newer external topology");
                try { snapshot.Restore(); throw new Exception("Expected external ownership refusal"); }
                catch (IOException) { }
                Check(File.ReadAllText(path) == "newer external topology", "Preserve external writes");

                File.Delete(path);
                snapshot = new TopologySnapshot(path);
                File.WriteAllText(path, "remote topology");
                snapshot.RecordWrite(File.ReadAllBytes(path));
                snapshot.Restore();
                Check(!File.Exists(path), "No prior topology to restore");
            }
            finally
            {
                File.Delete(path);
                Directory.Delete(root);
            }
        }

        private static void CheckWatcher()
        {
            int invalidations = 0;
            using (var watcher = new RemoteDesktopWatcher(() => invalidations++))
            {
                Check(watcher.Handle != IntPtr.Zero, "Hidden window created");
                var dispatch = typeof(RemoteDesktopWatcher).GetMethod("WndProc", BindingFlags.Instance | BindingFlags.NonPublic);
                dispatch.Invoke(watcher, new object[] { Message.Create(watcher.Handle, RemoteDesktop.SessionChange, new IntPtr(3), IntPtr.Zero) });
                dispatch.Invoke(watcher, new object[] { Message.Create(watcher.Handle, 0x007E, IntPtr.Zero, IntPtr.Zero) });
                dispatch.Invoke(watcher, new object[] { Message.Create(watcher.Handle, RemoteDesktop.SessionChange, new IntPtr(8), IntPtr.Zero) });
                Check(invalidations == 2, "Reconnect and display changes invalidate the span, unlock does not");
                Console.WriteLine("Windows session query: " + RemoteDesktop.Read() + "; session notification registration: " + watcher.Registered);
            }
        }

        [STAThread]
        private static void Main()
        {
            CheckPlanning();
            CheckConnection();
            CheckDialog();
            CheckTopologyOwnership();
            CheckWatcher();
            Console.WriteLine("PASS: " + checks + " Remote Desktop planning, connection, picker and topology checks.");
        }
    }
}
