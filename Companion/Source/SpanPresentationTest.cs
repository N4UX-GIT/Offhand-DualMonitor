// Compiled only into the isolated graininess candidate, never the public binary.
using System;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;

namespace Offhand.Companion
{
    internal enum SpanTestMode { Baseline, Resize, NoClip, Bordered }

    internal static class SpanPresentationTest
    {
        internal static SpanTestMode Mode = SpanTestMode.Baseline;
        internal static bool KeepBorders { get { return Mode == SpanTestMode.Bordered; } }
        internal static bool Clip { get { return Mode == SpanTestMode.Baseline || Mode == SpanTestMode.Resize; } }
        internal static bool Resize { get { return Mode == SpanTestMode.Resize; } }
        internal static string LogPath;

        internal static SpanTestMode Parse(string[] args)
        {
            if (args.Length == 0) return SpanTestMode.Baseline;
            if (args.Length != 1) throw new ArgumentException("Use one --span-test=baseline|resize|no-clip|bordered option.");
            switch (args[0])
            {
                case "--span-test=baseline": return SpanTestMode.Baseline;
                case "--span-test=resize": return SpanTestMode.Resize;
                case "--span-test=no-clip": return SpanTestMode.NoClip;
                case "--span-test=bordered": return SpanTestMode.Bordered;
                default: throw new ArgumentException("Unknown span test mode: " + args[0]);
            }
        }

        internal static void Initialize(string[] args)
        {
            Mode = Parse(args);
            string directory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Offhand", "GraininessTest2");
            Directory.CreateDirectory(directory);
            LogPath = Path.Combine(directory, DateTime.UtcNow.ToString("yyyyMMdd-HHmmss-fff") + "-" + Mode + ".log");
            Log("Graininess test2: " + Mode + "; borders=" + KeepBorders + "; clip=" + Clip + "; resize=" + Resize);
        }

        internal static void Log(string message)
        {
            if (LogPath == null) return;
            try { File.AppendAllText(LogPath, DateTime.UtcNow.ToString("o") + " " + message + Environment.NewLine); }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }

        internal static string ConfigPath
        {
            get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Offhand", "GraininessTest2", "OffhandConfig.ini"); }
        }

        internal static void ImportConfig()
        {
            string source = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Offhand", "OffhandConfig.ini");
            Directory.CreateDirectory(Path.GetDirectoryName(ConfigPath));
            if (!File.Exists(ConfigPath) && File.Exists(source)) File.Copy(source, ConfigPath);
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct POINT { internal int X, Y; }
        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool GetClientRect(IntPtr window, out NativeMethods.RECT rect);
        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool ClientToScreen(IntPtr window, ref POINT point);
        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool AdjustWindowRectEx(ref NativeMethods.RECT rect, uint style, bool menu, uint exStyle);
        [DllImport("user32.dll")]
        private static extern uint GetDpiForWindow(IntPtr window);
        [DllImport("user32.dll")]
        private static extern IntPtr GetMenu(IntPtr window);

        internal static Rectangle AddInsets(Rectangle client, int left, int top, int right, int bottom)
        {
            return Rectangle.FromLTRB(checked(client.Left + left), checked(client.Top + top),
                checked(client.Right + right), checked(client.Bottom + bottom));
        }

        internal static Rectangle OuterBounds(IntPtr window, Rectangle client, int style)
        {
            if (!KeepBorders) return client;
            NativeMethods.RECT rect = new NativeMethods.RECT { Right = client.Width, Bottom = client.Height };
            if (!AdjustWindowRectEx(ref rect, unchecked((uint)style), GetMenu(window) != IntPtr.Zero,
                unchecked((uint)NativeMethods.GetWindowLong(window, -20))))
                throw new InvalidOperationException("Could not calculate bordered client bounds.");
            return AddInsets(client, rect.Left, rect.Top, rect.Right - client.Width, rect.Bottom - client.Height);
        }

        internal static Rectangle ClientBounds(IntPtr window)
        {
            NativeMethods.RECT rect;
            POINT origin = new POINT();
            if (!GetClientRect(window, out rect) || !ClientToScreen(window, ref origin))
                throw new InvalidOperationException("Could not measure the WoW client area.");
            return new Rectangle(origin.X, origin.Y, rect.Width, rect.Height);
        }

        internal static string Describe(IntPtr window, string stage)
        {
            NativeMethods.RECT outer;
            if (!NativeMethods.GetWindowRect(window, out outer)) return stage + ": window unavailable";
            string dpi;
            try { dpi = GetDpiForWindow(window).ToString(); }
            catch (EntryPointNotFoundException) { dpi = "unavailable"; }
            try
            {
                return string.Format("{0}: outer=({1},{2} {3}x{4}); client={5}; style=0x{6:X8}; DPI={7}",
                    stage, outer.Left, outer.Top, outer.Width, outer.Height, ClientBounds(window),
                    NativeMethods.GetWindowLong(window, NativeMethods.GWL_STYLE), dpi);
            }
            catch (InvalidOperationException ex) { return stage + ": " + ex.Message; }
        }
    }
}
