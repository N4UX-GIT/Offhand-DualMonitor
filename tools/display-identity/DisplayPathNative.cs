using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace OffhandIdentityDiagnostic
{
    public sealed class ActivePathRecord
    {
        public int SourceNameResult, TargetNameResult, AdapterNameResult;
        public string SourceDeviceName, TargetMonitorName, TargetMonitorPath, TargetAdapterPath;
        public uint OutputTechnology;
        public bool TargetAvailable;
    }

    public sealed class ActivePathCapture
    {
        public int? BufferSizeResult, QueryResult;
        public string CaptureIssue;
        public readonly List<ActivePathRecord> Paths = new List<ActivePathRecord>();
    }

    public static class DisplayPathNative
    {
        private const uint OnlyActivePaths = 2;
        private const int InsufficientBuffer = 122;
        private const uint SourceNameRequest = 1, TargetNameRequest = 2, AdapterNameRequest = 4;

        [StructLayout(LayoutKind.Sequential)]
        private struct Luid { internal uint Low; internal int High; }
        [StructLayout(LayoutKind.Sequential)]
        private struct Header { internal uint Type, Size; internal Luid Adapter; internal uint Id; }
        [StructLayout(LayoutKind.Sequential)]
        private struct Source { internal Luid Adapter; internal uint Id, ModeIndex, Status; }
        [StructLayout(LayoutKind.Sequential)]
        private struct Target
        {
            internal Luid Adapter;
            internal uint Id, ModeIndex, Technology, Rotation, Scaling, RefreshNumerator, RefreshDenominator, Scanline;
            internal int Available;
            internal uint Status;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct Path { internal Source Source; internal Target Target; internal uint Flags; }
        [StructLayout(LayoutKind.Explicit, Size = 64)]
        private struct Mode { [FieldOffset(0)] internal uint Type; }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct SourceName
        {
            internal Header Header;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] internal string Name;
        }
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct TargetName
        {
            internal Header Header;
            internal uint Flags, Technology;
            internal ushort EdidManufacturer, EdidProduct;
            internal uint ConnectorInstance;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] internal string Name;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] internal string Path;
        }
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct AdapterName
        {
            internal Header Header;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] internal string Path;
        }

        [DllImport("user32.dll", ExactSpelling = true)]
        private static extern int GetDisplayConfigBufferSizes(uint flags, out uint pathCount, out uint modeCount);
        [DllImport("user32.dll", ExactSpelling = true)]
        private static extern int QueryDisplayConfig(uint flags, ref uint pathCount, [Out] Path[] paths,
            ref uint modeCount, [Out] Mode[] modes, IntPtr topology);
        [DllImport("user32.dll", EntryPoint = "DisplayConfigGetDeviceInfo", ExactSpelling = true)]
        private static extern int GetSourceName(ref SourceName name);
        [DllImport("user32.dll", EntryPoint = "DisplayConfigGetDeviceInfo", ExactSpelling = true)]
        private static extern int GetTargetName(ref TargetName name);
        [DllImport("user32.dll", EntryPoint = "DisplayConfigGetDeviceInfo", ExactSpelling = true)]
        private static extern int GetAdapterName(ref AdapterName name);

        private static ActivePathRecord ReadPath(Path path)
        {
            var source = new SourceName { Header = new Header { Type = SourceNameRequest,
                Size = (uint)Marshal.SizeOf(typeof(SourceName)), Adapter = path.Source.Adapter, Id = path.Source.Id } };
            var target = new TargetName { Header = new Header { Type = TargetNameRequest,
                Size = (uint)Marshal.SizeOf(typeof(TargetName)), Adapter = path.Target.Adapter, Id = path.Target.Id } };
            var adapter = new AdapterName { Header = new Header { Type = AdapterNameRequest,
                Size = (uint)Marshal.SizeOf(typeof(AdapterName)), Adapter = path.Target.Adapter } };
            int sourceResult = GetSourceName(ref source);
            int targetResult = GetTargetName(ref target);
            int adapterResult = GetAdapterName(ref adapter);
            return new ActivePathRecord {
                SourceNameResult = sourceResult, TargetNameResult = targetResult, AdapterNameResult = adapterResult,
                SourceDeviceName = sourceResult == 0 ? source.Name : null,
                TargetMonitorName = targetResult == 0 ? target.Name : null,
                TargetMonitorPath = targetResult == 0 ? target.Path : null,
                TargetAdapterPath = adapterResult == 0 ? adapter.Path : null,
                OutputTechnology = path.Target.Technology, TargetAvailable = path.Target.Available != 0
            };
        }

        public static ActivePathCapture Read()
        {
            var capture = new ActivePathCapture();
            // A topology change between these calls can invalidate the first buffer size.
            for (int attempt = 0; attempt < 3; attempt++)
            {
                uint pathCount, modeCount;
                capture.QueryResult = null;
                capture.BufferSizeResult = GetDisplayConfigBufferSizes(OnlyActivePaths, out pathCount, out modeCount);
                if (capture.BufferSizeResult != 0) return capture;
                if (pathCount > 256 || modeCount > 1024)
                {
                    capture.CaptureIssue = "Display configuration exceeded the diagnostic buffer limits.";
                    return capture;
                }

                var paths = new Path[Math.Max(1u, pathCount)];
                var modes = new Mode[Math.Max(1u, modeCount)];
                capture.QueryResult = QueryDisplayConfig(OnlyActivePaths, ref pathCount, paths, ref modeCount, modes, IntPtr.Zero);
                if (capture.QueryResult == InsufficientBuffer) continue;
                if (capture.QueryResult != 0) return capture;
                for (int i = 0; i < pathCount; i++) capture.Paths.Add(ReadPath(paths[i]));
                return capture;
            }
            capture.CaptureIssue = "Display configuration changed repeatedly during capture.";
            return capture;
        }
    }
}
