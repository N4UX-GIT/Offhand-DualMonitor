using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace OffhandIdentityDiagnostic
{
    public sealed class DisplayRecord
    {
        public string DeviceName;
        public bool Primary;
        public int X, Y, Width, Height;
        public bool LegacyQuerySucceeded;
        public string LegacyMonitorName;
        public string LegacyId;
        public string LegacyIdSource;
        public bool InterfaceQuerySucceeded;
        public string InterfaceId;
    }

    public static class NativeCapture
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct DisplayDevice
        {
            public int cb;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
            public uint StateFlags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
        }

        [DllImport("user32.dll", EntryPoint = "EnumDisplayDevicesW", CharSet = CharSet.Unicode, ExactSpelling = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool EnumDisplayDevices(string deviceName, uint index,
            ref DisplayDevice device, uint flags);

        public static DisplayRecord[] Read()
        {
            var result = new List<DisplayRecord>();
            foreach (Screen screen in Screen.AllScreens)
            {
                var legacy = new DisplayDevice();
                legacy.cb = Marshal.SizeOf(typeof(DisplayDevice));
                bool legacyOk = EnumDisplayDevices(screen.DeviceName, 0, ref legacy, 0);
                var current = new DisplayDevice();
                current.cb = Marshal.SizeOf(typeof(DisplayDevice));
                bool currentOk = EnumDisplayDevices(screen.DeviceName, 0, ref current, 1);
                string legacyId = null;
                string source = "missing";
                if (legacyOk && !string.IsNullOrWhiteSpace(legacy.DeviceID))
                {
                    legacyId = legacy.DeviceID.Trim();
                    source = "DeviceID";
                }
                else if (legacyOk && !string.IsNullOrWhiteSpace(legacy.DeviceKey))
                {
                    legacyId = legacy.DeviceKey.Trim();
                    source = "DeviceKey (Beta 20 fallback)";
                }
                result.Add(new DisplayRecord {
                    DeviceName = screen.DeviceName,
                    Primary = screen.Primary,
                    X = screen.Bounds.X,
                    Y = screen.Bounds.Y,
                    Width = screen.Bounds.Width,
                    Height = screen.Bounds.Height,
                    LegacyQuerySucceeded = legacyOk,
                    LegacyMonitorName = legacyOk ? legacy.DeviceString : null,
                    LegacyId = legacyId,
                    LegacyIdSource = source,
                    InterfaceQuerySucceeded = currentOk,
                    InterfaceId = currentOk && !string.IsNullOrWhiteSpace(current.DeviceID)
                        ? current.DeviceID.Trim() : null
                });
            }
            return result.ToArray();
        }
    }
}
