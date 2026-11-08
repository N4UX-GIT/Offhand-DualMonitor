using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace Offhand.Companion
{
    internal static class TaskbarPresentationTest
    {
        private static int assertions;
        [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
        private static void Check(bool value, string message)
        { assertions++; if (!value) throw new Exception(message); }

        [STAThread]
        public static void Main()
        {
            string failure;
            Check(!TaskbarPresentation.TrySetFullscreen(IntPtr.Zero, true, out failure)
                && failure != null, "reject absent target without Shell mutation");
            using (var form = new Form())
            {
                form.StartPosition = FormStartPosition.Manual;
                form.Bounds = new Rectangle(100,100,640,480);
                IntPtr handle = form.Handle;
                IntPtr foreground = GetForegroundWindow();
                int style = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE);
                NativeMethods.RECT before, after;
                Check(NativeMethods.GetWindowRect(handle, out before), "read hidden target");
                IntPtr region = NativeMethods.CreateRectRgn(0,0,600,440);
                Check(NativeMethods.SetWindowRgn(handle,region,true) != 0, "install prior clipping");
                for (int i=0; i<3; i++)
                {
                    Check(TaskbarPresentation.TrySetFullscreen(handle,true,out failure), "Shell accepts fullscreen: "+failure);
                    Check(TaskbarPresentation.TrySetFullscreen(handle,false,out failure), "Shell accepts clear: "+failure);
                    Check(NativeMethods.GetWindowRect(handle,out after)
                        && before.Left==after.Left && before.Top==after.Top
                        && before.Width==after.Width && before.Height==after.Height, "notification does not resize");
                    Check(NativeMethods.GetWindowLong(handle,NativeMethods.GWL_STYLE)==style, "notification preserves style");
                    Check(!NativeMethods.IsWindowVisible(handle), "notification does not show hidden window");
                    Check(GetForegroundWindow()==foreground, "notification does not steal focus");
                    IntPtr read=NativeMethods.CreateRectRgn(0,0,0,0);
                    try { Check(NativeMethods.GetWindowRgn(handle,read)==2, "notification preserves clipping"); }
                    finally { NativeMethods.DeleteObject(read); }
                }
                form.Dispose();
                Check(!TaskbarPresentation.TrySetFullscreen(handle,false,out failure), "reject destroyed target");
            }
            Console.WriteLine("Taskbar presentation native checks passed: "+assertions+" assertions.");
        }
    }
}
