using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using System.Threading;
using System.Threading.Tasks;
using System.Globalization;
using Timer = System.Windows.Forms.Timer;

#if UI_PREVIEW && (RDP_TEST || HDR_DPI_DIAGNOSTICS_TEST || GRAININESS_TEST || FOREVER_GRAPHICS_RECOVERY_TEST || RETAIL_GRAPHICS_RECOVERY_TEST || CLASSIC_GRAPHICS_RECOVERY_TEST)
#error UI preview requires its own isolated build configuration.
#endif

#if HDR_DPI_DIAGNOSTICS_TEST && (GRAININESS_TEST || FOREVER_GRAPHICS_RECOVERY_TEST || RETAIL_GRAPHICS_RECOVERY_TEST || CLASSIC_GRAPHICS_RECOVERY_TEST)
#error Diagnostics and rendering/recovery experiments require separate builds.
#endif
#if GRAININESS_TEST && (FOREVER_GRAPHICS_RECOVERY_TEST || RETAIL_GRAPHICS_RECOVERY_TEST || CLASSIC_GRAPHICS_RECOVERY_TEST)
#error Graininess and graphics recovery are separate experimental configurations.
#endif
#if (FOREVER_GRAPHICS_RECOVERY_TEST && RETAIL_GRAPHICS_RECOVERY_TEST) || (FOREVER_GRAPHICS_RECOVERY_TEST && CLASSIC_GRAPHICS_RECOVERY_TEST) || (RETAIL_GRAPHICS_RECOVERY_TEST && CLASSIC_GRAPHICS_RECOVERY_TEST)
#error Select exactly one graphics recovery client scope.
#endif

#if RDP_TEST && (HDR_DPI_DIAGNOSTICS_TEST || GRAININESS_TEST || FOREVER_GRAPHICS_RECOVERY_TEST || RETAIL_GRAPHICS_RECOVERY_TEST || CLASSIC_GRAPHICS_RECOVERY_TEST)
#error RDP test packaging must use the ordinary Companion runtime.
#endif

#if UI_PREVIEW
[assembly: AssemblyTitle("Offhand Companion UI Preview")]
#elif RDP_TEST
[assembly: AssemblyTitle("Offhand Companion RDP Test 1")]
#elif HDR_DPI_DIAGNOSTICS_TEST
[assembly: AssemblyTitle("Offhand Companion HDR DPI DIAGNOSTICS TEST 3")]
#elif FOREVER_GRAPHICS_RECOVERY_TEST
[assembly: AssemblyTitle("Offhand Companion FOREVER GRAPHICS TEST 5")]
#elif RETAIL_GRAPHICS_RECOVERY_TEST
[assembly: AssemblyTitle("Offhand Companion RETAIL GRAPHICS TEST 4")]
#elif CLASSIC_GRAPHICS_RECOVERY_TEST
[assembly: AssemblyTitle("Offhand Companion CLASSIC GRAPHICS TEST 3")]
#else
[assembly: AssemblyTitle("Offhand Companion")]
#endif
[assembly: AssemblyDescription("Dual-Monitor Multi-Display Controller for World of Warcraft")]
[assembly: AssemblyCompany("Offhand Project")]
[assembly: AssemblyProduct("Offhand Companion")]
[assembly: AssemblyCopyright("Copyright (C) 2026 Offhand Project")]
#if HDR_DPI_DIAGNOSTICS_TEST || GRAININESS_TEST || FOREVER_GRAPHICS_RECOVERY_TEST || RETAIL_GRAPHICS_RECOVERY_TEST || CLASSIC_GRAPHICS_RECOVERY_TEST
[assembly: AssemblyVersion("2.1.2.0")]
#elif RDP_TEST
[assembly: AssemblyVersion("2.1.3.0")]
#else
[assembly: AssemblyVersion("2.1.5.0")]
#endif
#if UI_PREVIEW
[assembly: AssemblyFileVersion("2.1.5.8004")]
[assembly: AssemblyInformationalVersion("2.1.5")]
#elif RDP_TEST
[assembly: AssemblyFileVersion("2.1.3.7001")]
[assembly: AssemblyInformationalVersion("2.1.3-beta.6")]
#elif HDR_DPI_DIAGNOSTICS_TEST
[assembly: AssemblyFileVersion("2.1.2.2005")]
[assembly: AssemblyInformationalVersion("2.1.2-beta.20")]
#elif GRAININESS_TEST
[assembly: AssemblyFileVersion("2.1.2.2002")]
// Keep the public compatibility/writer identity parseable. Experimental
// identity belongs in FileVersion, the title, logs and package filename.
[assembly: AssemblyInformationalVersion("2.1.2-beta.20")]
#elif FOREVER_GRAPHICS_RECOVERY_TEST || RETAIL_GRAPHICS_RECOVERY_TEST || CLASSIC_GRAPHICS_RECOVERY_TEST
[assembly: AssemblyFileVersion("2.1.2.20")]
[assembly: AssemblyInformationalVersion("2.1.2-beta.20")]
#else
[assembly: AssemblyFileVersion("2.1.5.1")]
[assembly: AssemblyInformationalVersion("2.1.5")]
#endif

namespace Offhand.Companion
{
    internal sealed class CompanionReleaseVersion : IComparable<CompanionReleaseVersion>
    {
        internal Version Core;
        internal int? Beta;

        internal static bool TryParse(string value, out CompanionReleaseVersion result)
        {
            result = null;
            if (string.IsNullOrWhiteSpace(value)) return false;
            string normalized = value.Trim().TrimStart('v', 'V');
            string[] parts = normalized.Split(new char[] { '-' }, 2);
            Version core;
            if (!Version.TryParse(parts[0], out core)) return false;
            int? beta = null;
            if (parts.Length == 2)
            {
                const string prefix = "beta.";
                if (!parts[1].StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return false;
                int number;
                if (!int.TryParse(parts[1].Substring(prefix.Length), out number) || number < 0) return false;
                beta = number;
            }
            result = new CompanionReleaseVersion { Core = core, Beta = beta };
            return true;
        }

        public int CompareTo(CompanionReleaseVersion other)
        {
            if (other == null) return 1;
            int core = Core.CompareTo(other.Core);
            if (core != 0) return core;
            if (!Beta.HasValue) return other.Beta.HasValue ? 1 : 0;
            if (!other.Beta.HasValue) return -1;
            return Beta.Value.CompareTo(other.Beta.Value);
        }

        internal string Display
        {
            get { return "v" + Core.ToString(3) + (Beta.HasValue ? " Beta " + Beta.Value : ""); }
        }
    }

    internal sealed class GitHubReleaseInfo
    {
        public string tag_name { get; set; }
        public string html_url { get; set; }
        public string body { get; set; }
        public bool draft { get; set; }
        public bool prerelease { get; set; }
    }

    internal sealed class CompanionUpdateRelease
    {
        internal CompanionReleaseVersion Version;
        internal string Url;
    }

    internal static class CompanionUpdatePolicy
    {
        private static readonly Regex CompanionVersionMarker = new Regex(
            @"<!--\s*offhand-companion-version:\s*(?<version>[^\s>]+)\s*-->",
            RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

        internal static CompanionUpdateRelease SelectLatest(string json, CompanionReleaseVersion current)
        {
            if (current == null) throw new ArgumentNullException("current");
            GitHubReleaseInfo[] releases = new JavaScriptSerializer().Deserialize<GitHubReleaseInfo[]>(json);
            if (releases == null) throw new FormatException("GitHub returned no release list.");

            CompanionUpdateRelease latest = null;
            CompanionUpdateRelease legacyFallback = null;
            foreach (GitHubReleaseInfo release in releases)
            {
                if (release == null || release.draft) continue;
                if (!current.Beta.HasValue && release.prerelease) continue;

                Match marker = CompanionVersionMarker.Match(release.body ?? string.Empty);
                CompanionReleaseVersion version;
                bool hasMarker = marker.Success;
                string versionText = hasMarker ? marker.Groups["version"].Value : release.tag_name;
                if (!CompanionReleaseVersion.TryParse(versionText, out version)) continue;

                string url = release.html_url;
                if (string.IsNullOrWhiteSpace(url) && !string.IsNullOrWhiteSpace(release.tag_name))
                    url = "https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/tag/" + Uri.EscapeDataString(release.tag_name);
                CompanionUpdateRelease candidate = new CompanionUpdateRelease { Version = version, Url = url };
                if (hasMarker)
                {
                    if (latest == null || version.CompareTo(latest.Version) > 0) latest = candidate;
                }
                else if (legacyFallback == null || version.CompareTo(legacyFallback.Version) > 0)
                {
                    legacyFallback = candidate;
                }
            }

            // Releases created before Beta 19 do not carry the Companion marker.
            // Use their tags only while the repository has no marked releases.
            if (latest == null) latest = legacyFallback;
            if (latest == null)
                throw new FormatException("No published Companion release metadata was found.");
            return latest;
        }
    }

    internal static class CompanionDistribution
    {
        internal const string WebsiteUrl = "https://offhand-wow.onrender.com/";
        internal const string DiscordUrl = "https://discord.gg/J2P3SM6pAY";
        internal const string CurseForgeUrl = "https://www.curseforge.com/wow/addons/offhand";

        internal const string StoreProductId = "9PL4PW84Q90W";
        internal const string StoreProductUri = "ms-windows-store://pdp/?ProductId=" + StoreProductId;

        private const int ErrorInsufficientBuffer = 122;
        private const int AppModelErrorNoPackage = 15700;

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
        private static extern int GetCurrentPackageFullName(ref int packageFullNameLength,
            StringBuilder packageFullName);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
        private static extern int GetCurrentPackageFamilyName(ref int length, StringBuilder familyName);

        internal static string PackageFamilyName()
        {
            try
            {
                int length = 0;
                int result = GetCurrentPackageFamilyName(ref length, null);
                if (result == AppModelErrorNoPackage) return null;
                if (result != ErrorInsufficientBuffer || length <= 0)
                    throw new IOException("Cannot locate Microsoft Store settings (Windows error " + result + ").");
                var family = new StringBuilder(length);
                result = GetCurrentPackageFamilyName(ref length, family);
                if (result != 0) throw new IOException("Cannot locate Microsoft Store settings (Windows error " + result + ").");
                return family.ToString();
            }
            catch (EntryPointNotFoundException) { return null; }
            catch (DllNotFoundException) { return null; }
        }

        internal static bool IsStorePackage()
        {
            try
            {
                int length = 0;
                int result = GetCurrentPackageFullName(ref length, null);
                if (result == AppModelErrorNoPackage) return false;
                if (result != ErrorInsufficientBuffer || length <= 0) return false;

                var packageFullName = new StringBuilder(length);
                result = GetCurrentPackageFullName(ref length, packageFullName);
                return result == 0 && packageFullName.Length > 0;
            }
            catch (EntryPointNotFoundException) { return false; }
            catch (DllNotFoundException) { return false; }
        }

        internal static string UpdateButtonText(bool storePackage)
        {
            return storePackage ? "Store Updates" : "Check for Updates";
        }

        internal static string UpdateButtonText(bool storePackage, StoreUpdateState state)
        {
            return storePackage && state == StoreUpdateState.Available ? "Update available…" : UpdateButtonText(storePackage);
        }

        internal static string StoreUpdateTip(StoreUpdateState state)
        {
            string status = state == StoreUpdateState.Available ? "A Companion update is available. "
                : state == StoreUpdateState.NoUpdate ? "The last Store check found no update. "
                : state == StoreUpdateState.Unavailable ? "The automatic Store check was unavailable. " : "";
            return status + "Open Microsoft Store to check and install updates when convenient. The Companion never installs an update itself.";
        }

        internal static string UpdateMenuText(bool storePackage)
        {
            return storePackage ? "Check Microsoft Store for Updates" : "Check for Updates";
        }

        internal static string UpdateHelpText(bool storePackage)
        {
            return storePackage
                ? "Store Updates: Companion quietly checks Microsoft Store after startup, at most once daily. Update available means the Store reported an update. Click to open the official Store page and install when convenient. The Companion does not contact GitHub."
                : "Check for Updates: Make a one-time HTTPS request to the official GitHub Releases API. Update checks never run automatically.";
        }

        internal static string PrivacyNetworkText(bool storePackage)
        {
            return storePackage
                ? "The Companion does not collect telemetry, credentials, chat, or gameplay data. It does not configure Windows startup persistence or inspect process security tokens. Store installations quietly ask Microsoft's Windows Store service about available Companion updates after startup, at most once daily. A local cache stores the check time, build and result. Clicking Store Updates or Update available opens the official Store page; Microsoft Store manages downloading and installation."
                : "The Companion does not collect telemetry, credentials, chat, or gameplay data. It does not configure Windows startup persistence or inspect process security tokens. The Companion itself contacts the official GitHub Releases API only when you click Check for Updates. Release checksums, source, and build provenance are published with official GitHub releases.";
        }
    }

    internal enum StoreUpdateState { NotChecked, NoUpdate, Available, Unavailable }

    // Separate from layout preferences. A failed cache write skips the query,
    // so restarting the app cannot turn an unavailable Store into rapid retries.
    internal sealed class StoreUpdateCache
    {
        internal static readonly TimeSpan Interval = TimeSpan.FromDays(1);
        private readonly string path;
        private readonly string version;
        internal StoreUpdateCache(string path, string version) { this.path = path; this.version = version; }

        private Dictionary<string, string> Read()
        {
            if (File.Exists(path) && new FileInfo(path).Length > 4096) return new Dictionary<string, string>();
            return PreferenceFile.Read(path);
        }

        private static bool TryTime(IDictionary<string, string> values, DateTime now, out DateTime attempted)
        {
            string text;
            attempted = default(DateTime);
            return values.TryGetValue("AttemptUtc", out text)
                && DateTime.TryParseExact(text, "o", CultureInfo.InvariantCulture,
                    DateTimeStyles.RoundtripKind, out attempted)
                && attempted.Kind == DateTimeKind.Utc && attempted <= now + Interval;
        }

        internal StoreUpdateState Cached(DateTime now)
        {
            var values = Read(); DateTime attempted; string state, savedVersion; StoreUpdateState parsed;
            if (TryTime(values, now, out attempted) && now - attempted < Interval
                && values.TryGetValue("Build", out savedVersion) && savedVersion == version
                && values.TryGetValue("State", out state) && Enum.TryParse(state, out parsed)
                && Enum.IsDefined(typeof(StoreUpdateState), parsed)) return parsed;
            return StoreUpdateState.NotChecked;
        }

        internal TimeSpan UntilDue(DateTime now)
        {
            DateTime attempted;
            return TryTime(Read(), now, out attempted) && now - attempted < Interval
                ? attempted + Interval - now : TimeSpan.Zero;
        }

        internal bool TryClaim(DateTime now)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            using (var gate = new FileStream(path + ".lock", FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None))
            {
                if (UntilDue(now) > TimeSpan.Zero) return false;
                PreferenceFile.Write(path, new Dictionary<string, string> {
                    { "Build", version }, { "AttemptUtc", now.ToString("o", CultureInfo.InvariantCulture) },
                    { "State", StoreUpdateState.NotChecked.ToString() } });
                return true;
            }
        }

        internal void Complete(DateTime attempted, StoreUpdateState state)
        {
            using (var gate = new FileStream(path + ".lock", FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None))
            {
                var values = Read(); string saved;
                string savedVersion;
                if (!values.TryGetValue("Build", out savedVersion) || savedVersion != version
                    || !values.TryGetValue("AttemptUtc", out saved)
                    || saved != attempted.ToString("o", CultureInfo.InvariantCulture)) return;
                values["State"] = state.ToString();
                PreferenceFile.Write(path, values);
            }
        }
    }

    internal static class StoreUpdateCheck
    {
        private static void Observe(Task task)
        {
            task.ContinueWith(t => { var observed = t.Exception; },
                TaskContinuationOptions.OnlyOnFaulted | TaskContinuationOptions.ExecuteSynchronously);
        }
        internal static bool Eligible(bool storePackage)
        {
#if UI_PREVIEW || RDP_TEST || HDR_DPI_DIAGNOSTICS_TEST || GRAININESS_TEST || FOREVER_GRAPHICS_RECOVERY_TEST || RETAIL_GRAPHICS_RECOVERY_TEST || CLASSIC_GRAPHICS_RECOVERY_TEST
            return false;
#else
            return storePackage;
#endif
        }

        internal static async Task<StoreUpdateState> RunAsync(
            Func<CancellationToken, Task<StoreUpdateState>> query, int timeoutMilliseconds, CancellationToken lifetime)
        {
            using (var cancellation = CancellationTokenSource.CreateLinkedTokenSource(lifetime))
            {
                Task<StoreUpdateState> pending = null;
                try
                {
                    lifetime.ThrowIfCancellationRequested();
                    pending = query(cancellation.Token);
                    if (await Task.WhenAny(pending, Task.Delay(timeoutMilliseconds, lifetime)) != pending)
                    {
                        cancellation.Cancel();
                        // A provider that ignores cancellation must not block shutdown or
                        // publish a late result. Observe eventual faults without UI work.
                        Observe(pending);
                        return StoreUpdateState.Unavailable;
                    }
                    lifetime.ThrowIfCancellationRequested();
                    return await pending;
                }
                catch (Exception)
                {
                    if (pending != null) Observe(pending);
                    return StoreUpdateState.Unavailable;
                }
            }
        }
    }

    internal static class StoreUpdateRuntime
    {
        [ComImport, Guid("3E68D4BD-7135-4D10-8018-9FB6D9F33FA1"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IInitializeWithWindow { void Initialize(IntPtr owner); }

        // Bind only the OS-provided WinRT metadata and framework async bridge.
        // This keeps portable/Wine builds free of a mandatory Windows SDK runtime
        // dependency. No package download or install API is invoked here.
        internal static MethodInfo TaskAdapter(Type resultType)
        {
            var bridge = Assembly.Load("System.Runtime.WindowsRuntime, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089");
            foreach (var method in bridge.GetType("System.WindowsRuntimeSystemExtensions").GetMethods())
            {
                var parameters = method.GetParameters();
                if (method.Name == "AsTask" && method.IsGenericMethodDefinition
                    && method.GetGenericArguments().Length == 1 && parameters.Length == 2
                    && parameters[0].ParameterType.IsGenericType
                    && parameters[0].ParameterType.GetGenericTypeDefinition().FullName == "Windows.Foundation.IAsyncOperation`1"
                    && parameters[1].ParameterType == typeof(CancellationToken)) return method.MakeGenericMethod(resultType);
            }
            throw new PlatformNotSupportedException("The Windows Store async bridge is unavailable.");
        }

        internal static async Task<StoreUpdateState> QueryAsync(IntPtr owner, CancellationToken cancellation)
        {
            cancellation.ThrowIfCancellationRequested();
            Type type = Type.GetType("Windows.Services.Store.StoreContext, Windows, ContentType=WindowsRuntime", true);
            MethodInfo query = type.GetMethod("GetAppAndOptionalStorePackageUpdatesAsync");
            MethodInfo adapter = TaskAdapter(query.ReturnType.GetGenericArguments()[0]);
            object context = type.GetMethod("GetDefault").Invoke(null, null);
            ((IInitializeWithWindow)context).Initialize(owner);
            object operation = query.Invoke(context, null);
            var task = (Task)adapter.Invoke(null, new object[] { operation, cancellation });
            await task;
            var updates = (System.Collections.IEnumerable)task.GetType().GetProperty("Result").GetValue(task, null);
            var iterator = updates.GetEnumerator();
            try { return iterator.MoveNext() ? StoreUpdateState.Available : StoreUpdateState.NoUpdate; }
            finally { var disposable = iterator as IDisposable; if (disposable != null) disposable.Dispose(); GC.KeepAlive(context); }
        }
    }

    internal static class RestoreGeometry
    {
        // Coordinates may be negative on monitors left of/above the primary.
        internal static Rectangle Fit(Rectangle desired, Rectangle workArea)
        {
            int width = Math.Max(1, Math.Min(desired.Width, workArea.Width));
            int height = Math.Max(1, Math.Min(desired.Height, workArea.Height));
            return new Rectangle(
                Math.Max(workArea.Left, Math.Min(desired.Left, workArea.Right - width)),
                Math.Max(workArea.Top, Math.Min(desired.Top, workArea.Bottom - height)), width, height);
        }
    }

    // Read-only Windows display state. This describes desktop outputs, not WoW's
    // swap chain or whether Auto HDR / a driver filter is active for the game.
    internal static class DisplayIdentity
    {
        internal sealed class ActivePath { internal string Device, Identity; }
        internal sealed class Child { internal string Identity, LegacyIdentity; }
        internal sealed class State { internal string Identity, LegacyIdentity, Detail; }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        internal struct TargetName
        {
            internal DisplayColor.Header Header;
            internal uint Flags, Technology;
            internal ushort EdidManufacturer, EdidProduct;
            internal uint ConnectorInstance;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] internal string Name;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] internal string Path;
        }
        [DllImport("user32.dll", EntryPoint = "DisplayConfigGetDeviceInfo", ExactSpelling = true)]
        private static extern int GetTargetName(ref TargetName name);

        // Null paths mean the API is unsupported. An empty successful snapshot,
        // missing target or cloned source must never fall back to child zero.
        internal static State Resolve(string device, IList<ActivePath> paths, IList<Child> children, string failure)
        {
            var state = new State();
            if (paths == null)
            {
                if (failure != null) { state.Detail = failure; return state; }
                if (children.Count != 1 || string.IsNullOrWhiteSpace(children[0].Identity))
                { state.Detail = "Active display paths unavailable; monitor entries are missing or ambiguous"; return state; }
                state.Identity = children[0].Identity.Trim();
                state.LegacyIdentity = children[0].LegacyIdentity;
                state.Detail = "Single monitor interface fallback (active display paths unsupported)";
                return state;
            }
            ActivePath match = null;
            foreach (var path in paths)
            {
                if (!string.Equals(path.Device, device, StringComparison.OrdinalIgnoreCase)) continue;
                if (match != null) { state.Detail = "Multiple active targets share this display source"; return state; }
                match = path;
            }
            if (match == null || string.IsNullOrWhiteSpace(match.Identity))
            { state.Detail = "Windows did not identify an active monitor target for this display"; return state; }
            state.Identity = match.Identity.Trim();
            int aliases = 0;
            foreach (var child in children)
                if (string.Equals(child.Identity, state.Identity, StringComparison.OrdinalIgnoreCase))
                { aliases++; state.LegacyIdentity = child.LegacyIdentity; }
            if (aliases != 1) state.LegacyIdentity = null;
            state.Detail = "Windows active display path";
            return state;
        }

        private static List<ActivePath> ReadPaths(out string failure)
        {
            failure = null;
            try
            {
                for (int attempt = 0; attempt < 3; attempt++)
                {
                    uint count, modes;
                    int result = DisplayColor.GetDisplayConfigBufferSizes(2, out count, out modes);
                    if (result == 50) return null; // ERROR_NOT_SUPPORTED, including older display drivers.
                    if (result != 0) { failure = "Active display enumeration failed: " + result; return null; }
                    if (count > 256 || modes > 1024) { failure = "Active display enumeration exceeded safe limits"; return null; }
                    var paths = new DisplayColor.Path[Math.Max(1u, count)];
                    var modeInfo = new DisplayColor.ModeInfo[Math.Max(1u, modes)];
                    result = DisplayColor.QueryDisplayConfig(2, ref count, paths, ref modes, modeInfo, IntPtr.Zero);
                    if (result == 122) continue;
                    if (result == 50) return null;
                    if (result != 0) { failure = "Active display query failed: " + result; return null; }
                    var values = new List<ActivePath>();
                    for (int i = 0; i < count; i++)
                    {
                        var source = new DisplayColor.SourceName { Header = new DisplayColor.Header { Type = 1,
                            Size = (uint)Marshal.SizeOf(typeof(DisplayColor.SourceName)), Adapter = paths[i].Source.Adapter, Id = paths[i].Source.Id } };
                        if (DisplayColor.GetSourceName(ref source) != 0 || string.IsNullOrWhiteSpace(source.Name))
                        { failure = "Windows could not identify an active display source"; return null; }
                        var target = new TargetName { Header = new DisplayColor.Header { Type = 2,
                            Size = (uint)Marshal.SizeOf(typeof(TargetName)), Adapter = paths[i].Target.Adapter, Id = paths[i].Target.Id } };
                        int named = GetTargetName(ref target);
                        values.Add(new ActivePath { Device = source.Name,
                            Identity = named == 0 && paths[i].Target.Available != 0 ? target.Path : null });
                    }
                    return values;
                }
                failure = "Display configuration kept changing; try again after reconnecting displays";
            }
            catch (DllNotFoundException) { }
            catch (EntryPointNotFoundException) { }
            return null;
        }

        private static List<Child> ReadChildren(string device)
        {
            var children = new List<Child>();
            for (uint index = 0; index < 256; index++)
            {
                var current = new NativeMethods.DISPLAY_DEVICE();
                current.cb = Marshal.SizeOf(typeof(NativeMethods.DISPLAY_DEVICE));
                if (!NativeMethods.EnumDisplayDevices(device, index, ref current, 1)) return children;
                var legacy = new NativeMethods.DISPLAY_DEVICE();
                legacy.cb = current.cb;
                bool found = NativeMethods.EnumDisplayDevices(device, index, ref legacy, 0);
                children.Add(new Child { Identity = (current.DeviceID ?? "").Trim(),
                    LegacyIdentity = found && !string.IsNullOrWhiteSpace(legacy.DeviceID) ? legacy.DeviceID.Trim() : null });
            }
            // Do not accept a truncated enumeration as a unique legacy alias.
            return new List<Child>();
        }

        internal static Dictionary<string, State> Read(IEnumerable<string> devices)
        {
            string failure;
            var paths = ReadPaths(out failure);
            var result = new Dictionary<string, State>(StringComparer.OrdinalIgnoreCase);
            foreach (string device in devices)
                result[device] = Resolve(device, paths, ReadChildren(device), failure);
            return result;
        }
    }

    internal static class DisplayColor
    {
        internal enum Mode { Unknown, Sdr, Wcg, Hdr }
        internal sealed class State
        {
            internal Mode Active;
            internal bool? HdrSupported;
            internal string Detail;
            internal string Label
            {
                get
                {
                    if (Active == Mode.Hdr) return "HDR on";
                    if (Active == Mode.Wcg) return "SDR (wide color)";
                    if (Active == Mode.Sdr) return HdrSupported == true ? "SDR, HDR available" : "SDR";
                    return "Color mode unavailable";
                }
            }
        }

        internal const string Guidance =
            "Offhand spans one WoW window across the selected displays. Mixed HDR/SDR output may cause excessive brightness or washed-out colors. " +
            "This message identifies a possible compatibility issue, not a confirmed rendering problem. Spanning remains available.\r\n\r\n" +
            "1. If you use Windows Auto HDR or NVIDIA RTX HDR for WoW, disable that game HDR feature and restart WoW. Leave Windows HDR on for this first comparison.\r\n\r\n" +
            "2. If brightness remains incorrect, compare with Windows HDR disabled on the HDR display. Restore your preferred settings after testing.\r\n\r\n" +
            "3. Include the copied display diagnostics, WoW version, Windows version, GPU/driver and monitor models when reporting the result.\r\n\r\n" +
            "Detection reads Windows display modes. It cannot tell whether WoW, Auto HDR or a driver filter is producing HDR, measure image brightness, or correct colors. " +
            "No HDR, driver or game settings are changed by the Companion. Older Windows versions, drivers and Wine may not provide an unambiguous HDR mode.";

        [StructLayout(LayoutKind.Sequential)]
        internal struct Luid { internal uint Low; internal int High; }
        [StructLayout(LayoutKind.Sequential)]
        internal struct Header { internal uint Type, Size; internal Luid Adapter; internal uint Id; }
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        internal struct SourceName
        {
            internal Header Header;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] internal string Name;
        }
        [StructLayout(LayoutKind.Sequential)]
        internal struct ColorInfo
        {
            internal Header Header;
            internal uint Flags, Encoding, Bits, ActiveMode;
        }
        [StructLayout(LayoutKind.Sequential)]
        internal struct Source { internal Luid Adapter; internal uint Id, ModeIndex, Status; }
        [StructLayout(LayoutKind.Sequential)]
        internal struct Target
        {
            internal Luid Adapter;
            internal uint Id, ModeIndex, Technology, Rotation, Scaling, RefreshNumerator, RefreshDenominator, Scanline;
            internal int Available;
            internal uint Status;
        }
        [StructLayout(LayoutKind.Sequential)]
        internal struct Path { internal Source Source; internal Target Target; internal uint Flags; }
        [StructLayout(LayoutKind.Explicit, Size = 64)]
        internal struct ModeInfo { [FieldOffset(0)] internal uint Type; }

        [DllImport("user32.dll")]
        internal static extern int GetDisplayConfigBufferSizes(uint flags, out uint paths, out uint modes);
        [DllImport("user32.dll")]
        internal static extern int QueryDisplayConfig(uint flags, ref uint pathCount, [Out] Path[] paths,
            ref uint modeCount, [Out] ModeInfo[] modes, IntPtr topology);
        [DllImport("user32.dll", EntryPoint = "DisplayConfigGetDeviceInfo", CharSet = CharSet.Unicode)]
        internal static extern int GetSourceName(ref SourceName name);
        [DllImport("user32.dll", EntryPoint = "DisplayConfigGetDeviceInfo")]
        private static extern int GetColorInfo(ref ColorInfo info);

        internal static State DecodeModern(uint flags, uint mode)
        {
            return new State { Active = mode == 2 ? Mode.Hdr : mode == 1 ? Mode.Wcg : mode == 0 ? Mode.Sdr : Mode.Unknown,
                HdrSupported = (flags & 16) != 0, Detail = "Windows active color mode=" + mode + "; flags=" + flags };
        }

        internal static State DecodeLegacy(uint flags)
        {
            // Legacy AdvancedColorEnabled can also mean WCG on newer Windows.
            // Never advertise it as confirmed HDR, or infer HDR capability from
            // AdvancedColorSupported. A successful modern query resolves both.
            return new State { Active = (flags & 2) == 0 ? Mode.Sdr : Mode.Unknown,
                Detail = "Legacy advanced color flags=" + flags + "; HDR-specific state unavailable" };
        }

        private static State ReadTarget(Target target)
        {
            ColorInfo info = new ColorInfo();
            info.Header = new Header { Type = 15, Size = (uint)Marshal.SizeOf(typeof(ColorInfo)), Adapter = target.Adapter, Id = target.Id };
            int modern = GetColorInfo(ref info);
            if (modern == 0) return DecodeModern(info.Flags, info.ActiveMode);
            // The legacy structure ends before ActiveMode (32 bytes).
            info = new ColorInfo();
            info.Header = new Header { Type = 9, Size = 32, Adapter = target.Adapter, Id = target.Id };
            int legacy = GetColorInfo(ref info);
            if (legacy == 0) return DecodeLegacy(info.Flags);
            return new State { Detail = "Windows color query failed: modern=" + modern + ", legacy=" + legacy };
        }

        internal static void Merge(Dictionary<string, State> states, string device, State value)
        {
            // A cloned source can drive multiple physical targets. Conflicting
            // target modes must not silently become whichever target came last.
            State previous;
            if (states.TryGetValue(device, out previous))
                states[device] = new State { Detail = "Multiple active targets share this display source; color mode is ambiguous" };
            else states[device] = value;
        }

        internal static Dictionary<string, State> Read(out string failure)
        {
            failure = null;
            var states = new Dictionary<string, State>(StringComparer.OrdinalIgnoreCase);
            try
            {
                // Retry only a bounded number of times if hotplug changes the
                // required buffer sizes between enumeration calls.
                for (int attempt = 0; attempt < 3; attempt++)
                {
                    uint pathCount, modeCount;
                    int result = GetDisplayConfigBufferSizes(2, out pathCount, out modeCount);
                    if (result != 0) { failure = "Windows display enumeration failed: " + result; return states; }
                    if (pathCount > 256 || modeCount > 1024) { failure = "Windows display enumeration exceeded safe limits"; return states; }
                    var paths = new Path[pathCount];
                    var modes = new ModeInfo[modeCount];
                    result = QueryDisplayConfig(2, ref pathCount, paths, ref modeCount, modes, IntPtr.Zero);
                    if (result == 122) continue;
                    if (result != 0) { failure = "Windows display query failed: " + result; return states; }
                    for (int i = 0; i < pathCount; i++)
                    {
                        SourceName name = new SourceName();
                        name.Header = new Header { Type = 1, Size = (uint)Marshal.SizeOf(typeof(SourceName)),
                            Adapter = paths[i].Source.Adapter, Id = paths[i].Source.Id };
                        if (GetSourceName(ref name) != 0 || string.IsNullOrEmpty(name.Name)) continue;
                        Merge(states, name.Name, ReadTarget(paths[i].Target));
                    }
                    return states;
                }
                failure = "Display configuration kept changing; color mode unavailable";
            }
            catch (DllNotFoundException) { failure = "Windows color detection is unavailable on this system"; }
            catch (EntryPointNotFoundException) { failure = "Windows color detection is unavailable on this system"; }
            catch (NotSupportedException) { failure = "Windows color detection is unsupported on this system"; }
            return states;
        }

        internal static State Lookup(Dictionary<string, State> states, string device, string failure)
        {
            State state;
            return device != null && states.TryGetValue(device, out state) ? state :
                new State { Detail = failure ?? "No unambiguous active Windows output matched this display" };
        }

        internal static bool IsMixed(State mainhand, State workspace, bool singleSplit)
        {
            return !singleSplit && ((mainhand.Active == Mode.Hdr && (workspace.Active == Mode.Sdr || workspace.Active == Mode.Wcg))
                || (workspace.Active == Mode.Hdr && (mainhand.Active == Mode.Sdr || mainhand.Active == Mode.Wcg)));
        }
    }

    internal static class DisplayScaling
    {
        internal sealed class State
        {
            internal int? Percent;
            internal string Detail;
            internal string Label { get { return Percent.HasValue ? Percent.Value + "% scale" : "Scale unavailable"; } }
        }

        internal const string Guidance =
            "The display percentages describe Windows scaling, not the monitor's physical pixel density, WoW's UI scale or its render resolution. " +
            "Different scales, or scales above 100%, are supported configurations and do not by themselves indicate a problem.\r\n\r\n" +
            "If WoW looks blurry or its size changes unexpectedly while spanned:\r\n\r\n" +
            "1. Confirm each monitor uses its recommended native resolution in Windows Display Settings. Record each display's Scale setting.\r\n\r\n" +
            "2. Compare Restore Window with the same scene after Span WoW Now. Include the copied display diagnostics and /offhand diag in your report.\r\n\r\n" +
            "3. If needed, temporarily compare both monitors at the same Windows scale, then restart WoW and span again. " +
            "Restore your preferred scales after testing. Follow any Windows sign-out prompt before comparing results.\r\n\r\n" +
            "The Companion does not change Windows scaling, compatibility overrides, WoW UI scale or render scale. " +
            "Detected percentages do not prove that Windows is stretching WoW or identify the cause of blur.";

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        internal struct MonitorInfo
        {
            internal uint Size;
            internal NativeMethods.RECT Bounds, WorkArea;
            internal uint Flags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] internal string Device;
        }
        [DllImport("user32.dll")]
        private static extern IntPtr MonitorFromRect(ref NativeMethods.RECT rect, uint flags);
        [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "GetMonitorInfoW")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);
        [DllImport("shcore.dll")]
        private static extern int GetScaleFactorForMonitor(IntPtr monitor, out int scale);

        internal static State FromResult(int result, int percent)
        {
            // Windows can return a default factor even on failure. Never turn
            // that fallback into an observed 100% scale.
            return result == 0 && percent > 0 && percent <= 1000
                ? new State { Percent = percent, Detail = "Windows GetScaleFactorForMonitor=" + percent + "%" }
                : new State { Detail = "Windows scale query unavailable: result=" + result + "; value=" + percent };
        }

        internal static State Read(MonitorSelection.Display display)
        {
            if (display == null) return new State { Detail = "No selected display to query" };
            try
            {
                var rect = new NativeMethods.RECT { Left = display.Bounds.Left, Top = display.Bounds.Top,
                    Right = display.Bounds.Right, Bottom = display.Bounds.Bottom };
                IntPtr monitor = MonitorFromRect(ref rect, 0); // No primary/nearest fallback.
                var info = new MonitorInfo { Size = (uint)Marshal.SizeOf(typeof(MonitorInfo)) };
                if (monitor == IntPtr.Zero || !GetMonitorInfo(monitor, ref info)
                    || !string.Equals(info.Device, display.DeviceName, StringComparison.OrdinalIgnoreCase))
                    return new State { Detail = "Selected display no longer matches a Windows monitor" };
                int percent;
                int result = GetScaleFactorForMonitor(monitor, out percent);
                return FromResult(result, percent);
            }
            catch (DllNotFoundException) { return new State { Detail = "Windows scale detection is unavailable on this system" }; }
            catch (EntryPointNotFoundException) { return new State { Detail = "Windows scale detection is unavailable on this system" }; }
            catch (NotSupportedException) { return new State { Detail = "Windows scale detection is unsupported on this system" }; }
        }

        internal static bool IsMixed(State game, State work, bool singleSplit)
        {
            return !singleSplit && game.Percent.HasValue && work.Percent.HasValue && game.Percent != work.Percent;
        }

        internal static string Summary(State game, State work, bool singleSplit)
        {
            if (!game.Percent.HasValue || (!singleSplit && !work.Percent.HasValue))
                return "Windows scale unavailable for one or more selected displays.";
            if (IsMixed(game, work, singleSplit))
                return "Different Windows scales detected. This is supported; see troubleshooting if WoW looks blurry.";
            return singleSplit ? "One physical display uses " + game.Percent + "% Windows scaling."
                : "Both selected displays use " + game.Percent + "% Windows scaling.";
        }

        internal static string Summary(IList<State> selected)
        {
            if(selected==null||selected.Count==0)return "Windows scale unavailable for one or more selected displays.";
            int? first=null;bool mixed=false;
            foreach(var state in selected){if(state==null||!state.Percent.HasValue)return "Windows scale unavailable for one or more selected displays.";
                if(first.HasValue&&first.Value!=state.Percent.Value)mixed=true;first=state.Percent;}
            if(selected.Count==1)return "Selected display uses "+first+"% Windows scaling.";
            return mixed?"Different Windows scales detected. Physical multi-monitor DPI testing remains pending. See Display Troubleshooting."
                : "All "+selected.Count+" selected displays use "+first+"% Windows scaling.";
        }
    }

    internal static class MonitorSelection
    {
        internal sealed class Display
        {
            internal int Index;
            internal string DeviceName;
            internal string StableId;
            internal string LegacyStableId;
            internal string IdentityDetail;
            internal Rectangle Bounds;
            internal Rectangle WorkArea;
            internal bool Primary;
        }

        internal sealed class Plan
        {
            internal int[] Indices;
            internal int MainhandIndex;
            internal int WorkspaceIndex;
            internal bool SplitSingle;
            internal bool GameOnLeft;
            internal bool PartialSingle;
            internal bool PartialSecondary;
            internal bool FlexibleLayout;
            internal int TopologySchema { get { return FlexibleLayout ? 3 : MultiRegion ? 2 : 1; } }
            internal WorkspaceRegion[] Workspaces;
            internal string PrimaryWorkspaceId;
            internal string WorkspaceProfileID;
            internal string WorkspaceProfileName;
            internal bool MultiRegion { get { return Workspaces != null; } }
            internal bool IsCustom { get { return PartialSingle || PartialSecondary || MultiRegion; } }
            internal Rectangle Bounds;
            internal Rectangle MainhandBounds;
            internal Rectangle WorkspaceBounds;
        }

        internal sealed class WorkspaceRegion
        {
            internal string Id;
            internal int DisplayIndex;
            internal Rectangle Bounds;
        }

        internal static bool MultiEnabled(IDictionary<string,string> settings)
        {
            string value;
            return settings.TryGetValue("WorkspaceRegionsEnabled",out value)
                && string.Equals(value,"True",StringComparison.OrdinalIgnoreCase);
        }

        private static Plan CreateMultiPlan(IDictionary<string,string> settings,IList<Display> displays)
        {
            if(displays==null||displays.Count==0)throw new InvalidOperationException("Windows reports no connected displays.");
            Func<string,string> read=key=>settings.ContainsKey(key)?settings[key]:null;
            Func<string,int> number=key=> {int value;if(!int.TryParse(read(key),out value))
                throw new InvalidOperationException("Workspace dimensions are incomplete. Review Workspaces.");return value;};
            if(read("WorkspaceRegionVersion")!="2") throw new InvalidOperationException("Unsupported workspace plan. Review Workspaces.");
            int count=number("WorkspaceRegionCount");
            if(count<1||count>2)throw new InvalidOperationException("Select one or two workspaces.");
            Func<string,int> display=id=> {
                if(string.IsNullOrWhiteSpace(id))throw new InvalidOperationException("A workspace display identity is missing.");
                int found=FindDisplay(displays,id,null);
                if(found == -2)throw new InvalidOperationException("A display identity is ambiguous. Review the connected monitors.");
                if(found<0)throw new InvalidOperationException("A required workspace display is disconnected. Restore WoW or reconnect it.");
                return found;
            };
            int main=display(read("MainhandIdentity"));
            Rectangle game=displays[main].Bounds, bounds=game;
            if(game.Width<960||game.Height<600)throw new InvalidOperationException("The game display must be at least 960 x 600 pixels.");
            var indices=new List<int>{main};var workspaces=new List<WorkspaceRegion>();
            var ids=new HashSet<string>(StringComparer.Ordinal);
            var deviceNames=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if(string.IsNullOrWhiteSpace(displays[main].DeviceName))throw new InvalidOperationException("The game display device is unavailable.");
            deviceNames.Add(displays[main].DeviceName);
            string primary=read("WorkspacePrimary");Rectangle primaryBounds=Rectangle.Empty;int primaryIndex=-1;
            for(int n=1;n<=count;n++) {
                string prefix="WorkspaceRegion"+n, id=read(prefix+"Id");
                if(string.IsNullOrEmpty(id)||id.Length>32||!Regex.IsMatch(id,@"^[A-Za-z0-9_-]+$")||!ids.Add(id))
                    throw new InvalidOperationException("Workspace IDs must be unique. Review Workspaces.");
                int index=display(read(prefix+"Identity"));
                if(indices.Contains(index))throw new InvalidOperationException("Choose a different monitor for each workspace and the game.");
                if(string.IsNullOrWhiteSpace(displays[index].DeviceName)||!deviceNames.Add(displays[index].DeviceName))
                    throw new InvalidOperationException("Selected display devices are ambiguous. Review the connected monitors.");
                Rectangle monitor=displays[index].Bounds;
                if(number(prefix+"MonitorWidth")!=monitor.Width||number(prefix+"MonitorHeight")!=monitor.Height)
                    throw new InvalidOperationException("A workspace display resolution changed. Review and save its area.");
                int x=number(prefix+"X"),y=number(prefix+"Y"),w=number(prefix+"Width"),h=number(prefix+"Height");
                if(x<0||y<0||w<480||h<600||(long)x+w>monitor.Width||(long)y+h>monitor.Height)
                    throw new InvalidOperationException("Each workspace must fit its monitor and be at least 480 x 600 pixels.");
                Rectangle area;
                try {area=new Rectangle(checked(monitor.Left+x),checked(monitor.Top+y),w,h);}
                catch(OverflowException){throw new InvalidOperationException("Workspace coordinates exceed the supported desktop range.");}
                if(area.IntersectsWith(game))throw new InvalidOperationException("A workspace overlaps the game display.");
                foreach(var previous in workspaces)if(area.IntersectsWith(previous.Bounds))
                    throw new InvalidOperationException("Workspace areas must not overlap.");
                indices.Add(index);workspaces.Add(new WorkspaceRegion{Id=id,DisplayIndex=index,Bounds=area});
                bounds=Rectangle.Union(bounds,area);
                if(id==primary){primaryBounds=area;primaryIndex=index;}
            }
            if(primaryIndex<0)throw new InvalidOperationException("Choose a primary workspace.");
            if(bounds.Width<=0||bounds.Height<=0||bounds.Width>16384||bounds.Height>16384
                || (long)bounds.Width*bounds.Height>(long)game.Width*game.Height*4)
                throw new InvalidOperationException("This workspace plan exceeds the prototype surface budget (16384 pixels per axis and four times the game area). Move or reduce the workspace areas.");
            // Preserve all identities in preferences. Older Companions reject a
            // three-selected-display plan rather than silently dropping a region.
            var selected=new HashSet<int>();
            foreach(string identity in Tokens(read("MonitorIdentities"),'|')) {
                int index=display(identity);
                if(!selected.Add(index))throw new InvalidOperationException("Selected monitor identities are duplicated. Review Workspaces.");
            }
            if(selected.Count!=indices.Count)throw new InvalidOperationException("Selected monitors differ from the workspace plan. Review Workspaces.");
            foreach(int index in indices)if(!selected.Contains(index))throw new InvalidOperationException("Selected monitors differ from the workspace plan. Review Workspaces.");
            ValidatePhysicalIdentities(displays,indices);
            string profileID=read("WorkspaceProfileID"),profileName=read("WorkspaceProfileName");
            if(profileID!=null&&(!Regex.IsMatch(profileID,"^[a-f0-9]{32}$")||WorkspacePlanProfiles.Name(profileName)!=profileName))
                throw new InvalidOperationException("The workspace profile identity is invalid. Review Workspace profiles.");
            return new Plan{Indices=indices.ToArray(),MainhandIndex=main,WorkspaceIndex=primaryIndex,
                MainhandBounds=game,WorkspaceBounds=primaryBounds,Bounds=bounds,
                Workspaces=workspaces.ToArray(),PrimaryWorkspaceId=primary,WorkspaceProfileID=profileID,WorkspaceProfileName=profileName};
        }

        internal static string AlignmentWarning(Plan plan)
        {
            if (plan == null || plan.SplitSingle) return null;
            Rectangle game = plan.MainhandBounds;
            Rectangle workspace = plan.WorkspaceBounds;
            bool sideBySide = game.Right <= workspace.Left || workspace.Right <= game.Left;
            int verticalOffset = Math.Abs(game.Top - workspace.Top);
            if (!sideBySide || verticalOffset == 0) return null;
            return string.Format(
                "Windows places the selected displays {0}px apart vertically. Offhand preserves that exact arrangement, so the span contains unused corner space. If this is unintended, align their top edges in Windows Display Settings and span again.",
                verticalOffset);
        }

        private static string[] Tokens(string value, char separator)
        {
            return string.IsNullOrWhiteSpace(value)
                ? new string[0]
                : value.Split(new char[] { separator }, StringSplitOptions.RemoveEmptyEntries);
        }

        internal static bool HasStableIdentitySettings(IDictionary<string, string> settings)
        {
            string version;
            if (settings == null || !settings.TryGetValue("DisplayIdentityVersion",out version) || version!="2") return false;
            return HasSavedIdentitySettings(settings);
        }

        internal static bool HasSavedIdentitySettings(IDictionary<string,string> settings)
        {
            string version,identities,mainhand;
            if(settings==null || !settings.TryGetValue("DisplayIdentityVersion",out version) || (version!="1" && version!="2")
                || !settings.TryGetValue("MonitorIdentities",out identities) || !settings.TryGetValue("MainhandIdentity",out mainhand)
                || string.IsNullOrWhiteSpace(mainhand))return false;
            var unique=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach(string identity in (identities??"").Split('|'))if(string.IsNullOrWhiteSpace(identity)||identity!=identity.Trim()||!unique.Add(identity))return false;
            return unique.Count>0 && unique.Contains(mainhand);
        }

        // Legacy IDs are read only for reviewed migration/profile recovery.
        // Resolve over both namespaces together; never let an alias hide a collision.
        internal static int FindDisplay(IList<Display> displays, string stableId, string deviceName)
        {
            if(displays==null)return -1;
            int found=-1;
            for(int i=0;i<displays.Count;i++) {
                Display display=displays[i];if(display==null)continue;
                bool match=!string.IsNullOrWhiteSpace(stableId)
                    ? string.Equals(display.StableId,stableId,StringComparison.OrdinalIgnoreCase)
                        || string.Equals(display.LegacyStableId,stableId,StringComparison.OrdinalIgnoreCase)
                    : !string.IsNullOrWhiteSpace(deviceName) && string.Equals(display.DeviceName,deviceName,StringComparison.OrdinalIgnoreCase);
                if(!match)continue;if(found>=0)return -2;found=i;
            }
            return found;
        }

        internal static void ValidatePhysicalIdentities(IList<Display> displays,IEnumerable<int> indices)
        {
            var devices=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach(int index in indices) {
                Display display=displays[index];
                if(display==null || string.IsNullOrWhiteSpace(display.StableId))
                    throw new InvalidOperationException("Windows did not provide a per-monitor interface identity. Reconnect the display or review the dock/adapter; no span was applied.");
                if(FindDisplay(displays,display.StableId,null)!=index)
                    throw new InvalidOperationException("Windows returned the same monitor identity for multiple displays. Offhand cannot safely distinguish their roles; no span was applied.");
                if(string.IsNullOrWhiteSpace(display.DeviceName)||!devices.Add(display.DeviceName))
                    throw new InvalidOperationException("Selected display devices are ambiguous. Review the connected monitors; no span was applied.");
            }
        }

        internal static Dictionary<string,string> UpgradeIdentitySettings(IDictionary<string,string> settings,IList<Display> displays)
        {
            Plan plan=CreatePlan(settings,displays);
            var result=new Dictionary<string,string>(settings);
            var identities=new List<string>();var devices=new List<string>();var indices=new List<string>();
            foreach(int index in plan.Indices){identities.Add(displays[index].StableId);devices.Add(displays[index].DeviceName);indices.Add(index.ToString());}
            result["MonitorIdentities"]=string.Join("|",identities);result["MonitorDevices"]=string.Join("|",devices);result["Monitors"]=string.Join(",",indices);
            result["MainhandIdentity"]=displays[plan.MainhandIndex].StableId;result["MainhandDevice"]=displays[plan.MainhandIndex].DeviceName;
            if(plan.PartialSingle)result["PartialDisplayIdentity"]=displays[plan.MainhandIndex].StableId;
            if(plan.PartialSecondary)result["SecondaryAreaIdentity"]=displays[plan.WorkspaceIndex].StableId;
            if(plan.FlexibleLayout)result[WorkspaceLayoutSettings.DocumentKey]=WorkspaceLayoutSettings.Encode(WorkspaceLayoutSettings.Read(settings),displays);
            else if(plan.MultiRegion)for(int n=1;n<=plan.Workspaces.Length;n++)
                result["WorkspaceRegion"+n+"Identity"]=displays[plan.Workspaces[n-1].DisplayIndex].StableId;
            result["DisplayIdentityVersion"]="2";
            CreatePlan(result,displays);
            return result;
        }

        internal static bool HasDisconnectedSavedDisplay(string savedIdentities, string savedDevices,
            IList<Display> displays)
        {
            string requestedValues = savedIdentities ?? savedDevices;
            if (string.IsNullOrWhiteSpace(requestedValues)) return false;
            bool useStableIdentities = savedIdentities != null;
            foreach (string requested in Tokens(requestedValues, '|'))
            {
                if (FindDisplay(displays, useStableIdentities ? requested : null,
                    useStableIdentities ? null : requested) < 0) return true;
            }
            return false;
        }

        internal static Display RecoveryDisplay(string mainhandIdentity, string mainhandDevice,
            IList<Display> displays)
        {
            if (displays == null || displays.Count == 0) return null;
            int match = FindDisplay(displays, mainhandIdentity, mainhandDevice);
            if (match >= 0) return displays[match];
            foreach (Display display in displays) if (display.Primary) return display;
            return displays[0];
        }

        internal static bool SameDisplays(IList<Display> left, IList<Display> right)
        {
            if (ReferenceEquals(left, right)) return true;
            if (left == null || right == null || left.Count != right.Count) return false;
            for (int i = 0; i < left.Count; i++)
            {
                if (!string.Equals(left[i].DeviceName, right[i].DeviceName, StringComparison.OrdinalIgnoreCase)
                    || !string.Equals(left[i].StableId, right[i].StableId, StringComparison.OrdinalIgnoreCase)
                    || !string.Equals(left[i].LegacyStableId, right[i].LegacyStableId, StringComparison.OrdinalIgnoreCase)
                    || left[i].Bounds != right[i].Bounds
                    || left[i].WorkArea != right[i].WorkArea
                    || left[i].Primary != right[i].Primary)
                    return false;
            }
            return true;
        }

        internal static Plan CreatePlan(string savedIdentities, string savedDevices, string legacySaved,
            string mainhandIdentity, string mainhandDevice, bool splitSingle, bool gameOnLeft,
            IList<Display> displays)
        {
            if (displays == null || displays.Count == 0)
                throw new InvalidOperationException("Windows reports no connected displays.");

            var selected = new List<int>();
            string selectedValues = savedIdentities ?? savedDevices;
            string[] devices = Tokens(selectedValues, '|');
            bool useStableIdentities = savedIdentities != null;
            if (selectedValues != null)
            {
                var requestedSet=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (string requested in devices)
                {
                    if(!requestedSet.Add(requested))throw new InvalidOperationException("The saved display selection contains duplicate identities. Review the checked displays and Mainhand.");
                    int match = FindDisplay(displays, useStableIdentities ? requested : null,
                        useStableIdentities ? null : requested);
                    if(match == -2)throw new InvalidOperationException("Windows returned the same monitor identity for multiple displays. Offhand cannot safely distinguish their roles; no span was applied.");
                    if (match < 0)
                        throw new InvalidOperationException("A saved display is disconnected (" + requested + "). Restore the WoW window or reconnect it; Offhand will not collapse the span onto the remaining screen.");
                    if (!selected.Contains(match)) selected.Add(match);
                }
            }
            else if (legacySaved != null)
            {
                foreach (string token in Tokens(legacySaved, ','))
                {
                    int index;
                    if (!int.TryParse(token, out index) || index < 0 || index >= displays.Count)
                        throw new InvalidOperationException("A previously selected display is disconnected. Review the display selection before spanning.");
                    if (!selected.Contains(index)) selected.Add(index);
                }
            }
            else
            {
                for (int i = 0; i < displays.Count; i++) selected.Add(i);
            }

            if (selected.Count == 0)
                throw new InvalidOperationException("Select displays before spanning.");
            if (selected.Count == 1 && !splitSingle)
                throw new InvalidOperationException("Select exactly two displays, or enable Single-display 32:9 split for one super-ultrawide monitor.");
            if (selected.Count > 2)
                throw new InvalidOperationException("Offhand currently supports exactly two displays, or one super-ultrawide in split mode. Select only the Mainhand and Offhand displays.");
            if(useStableIdentities)ValidatePhysicalIdentities(displays,selected);

            int mainhand = -1;
            if (!string.IsNullOrWhiteSpace(mainhandIdentity) || !string.IsNullOrWhiteSpace(mainhandDevice))
            {
                mainhand=FindDisplay(displays,mainhandIdentity,string.IsNullOrWhiteSpace(mainhandIdentity)?mainhandDevice:null);
                if(mainhand == -2)throw new InvalidOperationException("The Mainhand monitor identity is ambiguous. Review the display selection; no span was applied.");
                if (mainhand < 0 || !selected.Contains(mainhand))
                    throw new InvalidOperationException("The saved Mainhand display is unavailable. Select the connected game-view display before spanning.");
            }
            if (mainhand < 0)
            {
                foreach (int index in selected) if (displays[index].Primary) { mainhand = index; break; }
                if (mainhand < 0) mainhand = selected[selected.Count - 1];
            }

            Rectangle union = displays[selected[0]].Bounds;
            foreach (int index in selected) union = Rectangle.Union(union, displays[index].Bounds);
            Rectangle game = displays[mainhand].Bounds;
            int workspaceIndex = selected.Count == 2 ? selected[0] == mainhand ? selected[1] : selected[0] : mainhand;
            Rectangle workspace = displays[workspaceIndex].Bounds;
            if (selected.Count == 1)
            {
                int workspaceWidth = workspace.Width / 2;
                int gameWidth = workspace.Width - workspaceWidth;
                if (gameOnLeft)
                {
                    game = new Rectangle(workspace.Left, workspace.Top, gameWidth, workspace.Height);
                    workspace = new Rectangle(game.Right, workspace.Top, workspaceWidth, workspace.Height);
                }
                else
                {
                    workspace = new Rectangle(workspace.Left, workspace.Top, workspaceWidth, workspace.Height);
                    game = new Rectangle(workspace.Right, workspace.Top, gameWidth, workspace.Height);
                }
            }

            return new Plan { Indices = selected.ToArray(), MainhandIndex = mainhand,
                WorkspaceIndex = workspaceIndex, SplitSingle = selected.Count == 1,
                GameOnLeft = gameOnLeft, Bounds = union, MainhandBounds = game,
                WorkspaceBounds = workspace };
        }

        internal static Plan CreatePlan(IDictionary<string, string> settings, IList<Display> displays)
        {
            string identityVersion;
            if(settings.TryGetValue("DisplayIdentityVersion",out identityVersion) && identityVersion!="1" && identityVersion!="2")
                throw new InvalidOperationException("Unsupported display identity settings. Existing preferences were retained; review them before applying.");
            Func<string, string> read = key => settings.ContainsKey(key) ? settings[key] : null;
            if (WorkspaceLayoutSettings.Enabled(settings)) return WorkspaceLayoutSettings.CreatePlan(settings, displays);
            bool partial = string.Equals(read("PartialSpanEnabled"), "True", StringComparison.OrdinalIgnoreCase);
            bool secondary = string.Equals(read("SecondaryAreaEnabled"), "True", StringComparison.OrdinalIgnoreCase);
            if(MultiEnabled(settings)) {
                if(partial||secondary)throw new InvalidOperationException("Choose one custom workspace mode before spanning.");
                return CreateMultiPlan(settings,displays);
            }
            if (partial && secondary) throw new InvalidOperationException("Choose one custom layout mode before spanning.");
            bool stable = HasSavedIdentitySettings(settings);
            if(settings.ContainsKey("MonitorIdentities") && !stable)
                throw new InvalidOperationException("The saved monitor identities are incomplete or duplicated. Review the checked displays and Mainhand.");
            Plan plan = CreatePlan(stable ? read("MonitorIdentities") : null, read("MonitorDevices"), read("Monitors"),
                stable ? read("MainhandIdentity") : null, read("MainhandDevice"),
                partial || string.Equals(read("SingleDisplaySplit"), "True", StringComparison.OrdinalIgnoreCase),
                string.Equals(read("SingleGameSide"), "LEFT", StringComparison.OrdinalIgnoreCase), displays);
            if (secondary) {
                if (plan.Indices.Length != 2) throw new InvalidOperationException("A partial secondary workspace requires exactly two selected monitors.");
                Display workDisplay = displays[plan.WorkspaceIndex];
                if (FindDisplay(displays,read("SecondaryAreaIdentity"),null)!=plan.WorkspaceIndex)
                    throw new InvalidOperationException("The custom workspace monitor changed. Review Secondary area before spanning.");
                int x, y, w, h, mw, mh;
                if (!int.TryParse(read("SecondaryAreaX"), out x) || !int.TryParse(read("SecondaryAreaY"), out y)
                    || !int.TryParse(read("SecondaryAreaWidth"), out w) || !int.TryParse(read("SecondaryAreaHeight"), out h)
                    || !int.TryParse(read("SecondaryMonitorWidth"), out mw) || !int.TryParse(read("SecondaryMonitorHeight"), out mh))
                    throw new InvalidOperationException("The custom workspace dimensions are incomplete. Review Secondary area.");
                if (mw != workDisplay.Bounds.Width || mh != workDisplay.Bounds.Height)
                    throw new InvalidOperationException("The workspace monitor resolution changed. Review and save Secondary area.");
                if (mw > 32768 || mh > 32768 || x < 0 || y < 0 || w < 480 || h < 600
                    || (long)x + w > mw || (long)y + h > mh)
                    throw new InvalidOperationException("The workspace must fit its monitor and be at least 480 x 600 pixels.");
                Rectangle work = new Rectangle(workDisplay.Bounds.Left + x, workDisplay.Bounds.Top + y, w, h);
                Rectangle occupied = Rectangle.Union(plan.MainhandBounds, work);
                if (work.IntersectsWith(plan.MainhandBounds) || occupied.Width > 32768 || occupied.Height > 32768)
                    throw new InvalidOperationException("The game and workspace must not overlap and their combined surface must fit within 32768 pixels per axis.");
                plan.PartialSecondary = true; plan.WorkspaceBounds = work; plan.Bounds = occupied;
                return plan;
            }
            if (!partial) return plan;
            if (plan.Indices.Length != 1)
                throw new InvalidOperationException("This custom layout needs exactly one display. Open Advanced > Workspace layout to review it.");
            Display display = displays[plan.MainhandIndex];
            if (FindDisplay(displays,read("PartialDisplayIdentity"),null)!=plan.MainhandIndex)
                throw new InvalidOperationException("The custom region belongs to a different display. Open Advanced > Workspace layout and save it for this monitor.");
            int width, workspace, monitorWidth, monitorHeight;
            if (!int.TryParse(read("PartialWidth"), out width) || !int.TryParse(read("PartialWorkspaceWidth"), out workspace)
                || !int.TryParse(read("PartialMonitorWidth"), out monitorWidth) || !int.TryParse(read("PartialMonitorHeight"), out monitorHeight))
                throw new InvalidOperationException("Custom region dimensions are incomplete. Open Advanced > Workspace layout and save a valid layout.");
            if (display.Bounds.Width != monitorWidth || display.Bounds.Height != monitorHeight)
                throw new InvalidOperationException("The custom display resolution changed. Open Advanced > Workspace layout and save the revised layout before spanning.");
            string edge = read("PartialEdge"), side = read("PartialGameSide");
            if ((edge != "LEFT" && edge != "RIGHT") || (side != "LEFT" && side != "RIGHT"))
                throw new InvalidOperationException("Choose a valid occupied edge and game side in Workspace layout.");
            // Physical-pixel guardrails, not a promise that all panels are readable.
            if (display.Bounds.Width > 32768 || display.Bounds.Height > 32768 || display.Bounds.Height < 600
                || width < 1440 || width > display.Bounds.Width || workspace < 480 || workspace >= width || width - workspace < 960)
                throw new InvalidOperationException("Custom region needs at least 480px workspace, 960px game and 600px height, within the selected display (maximum 32768px).");
            plan.PartialSingle = true;
            plan.GameOnLeft = side == "LEFT";
            plan.Bounds = new Rectangle(display.Bounds.Left + (edge == "RIGHT" ? display.Bounds.Width - width : 0), display.Bounds.Top, width, display.Bounds.Height);
            plan.MainhandBounds = new Rectangle(plan.Bounds.Left + (plan.GameOnLeft ? 0 : workspace), plan.Bounds.Top, width - workspace, plan.Bounds.Height);
            plan.WorkspaceBounds = new Rectangle(plan.Bounds.Left + (plan.GameOnLeft ? width - workspace : 0), plan.Bounds.Top, workspace, plan.Bounds.Height);
            return plan;
        }

        internal static Rectangle[] VisibleRectangles(Plan plan)
        {
            if(!plan.MultiRegion)return new Rectangle[] { plan.MainhandBounds, plan.WorkspaceBounds };
            var result=new List<Rectangle>{plan.MainhandBounds};
            foreach(var workspace in plan.Workspaces)result.Add(workspace.Bounds);
            return result.ToArray();
        }
    }

    internal static class SpanClipRegion
    {
        // Caller owns the handle until SetWindowRgn succeeds.
        internal static IntPtr Create(MonitorSelection.Plan plan, Rectangle bounds)
        {
            IntPtr combined = IntPtr.Zero;
            try
            {
                foreach (Rectangle b in MonitorSelection.VisibleRectangles(plan))
                {
                    IntPtr next = NativeMethods.CreateRectRgn(b.Left - bounds.X, b.Top - bounds.Y, b.Right - bounds.X, b.Bottom - bounds.Y);
                    if (next == IntPtr.Zero) throw new IOException("Could not create window clipping region.");
                    if (combined == IntPtr.Zero) combined = next;
                    else {
                        try { if (NativeMethods.CombineRgn(combined, combined, next, 2) == 0) throw new IOException("Could not combine window clipping regions."); }
                        finally { NativeMethods.DeleteObject(next); }
                    }
                }
                IntPtr result = combined; combined = IntPtr.Zero; return result;
            }
            finally { if (combined != IntPtr.Zero) NativeMethods.DeleteObject(combined); }
        }
    }

    // Physical-pixel selection model. Editing never changes a native game window.
    internal sealed class PartialRegionSelection
    {
        internal readonly int MonitorWidth;
        internal int Width, WorkspaceWidth;
        internal bool OccupiedRight, GameLeft;
        internal PartialRegionSelection(int monitorWidth, int width, int workspace, bool right, bool gameLeft)
        {
            if (monitorWidth < 1440 || monitorWidth > 32768) throw new ArgumentOutOfRangeException("monitorWidth");
            MonitorWidth = monitorWidth; Width = Math.Max(1440, Math.Min(monitorWidth, width));
            WorkspaceWidth = Math.Max(480, Math.Min(Width - 960, workspace));
            OccupiedRight = right; GameLeft = gameLeft;
        }
        internal int Left { get { return OccupiedRight ? MonitorWidth - Width : 0; } }
        internal int OuterDivider { get { return OccupiedRight ? Left : Width; } }
        internal int WorkspaceDivider { get { return Left + (GameLeft ? Width - WorkspaceWidth : WorkspaceWidth); } }
        internal void ResizeOccupied(int x)
        {
            Width = Math.Max(WorkspaceWidth + 960, Math.Min(MonitorWidth, OccupiedRight ? MonitorWidth - x : x));
        }
        internal void ResizeWorkspace(int x)
        {
            WorkspaceWidth = Math.Max(480, Math.Min(Width - 960, GameLeft ? Left + Width - x : x - Left));
        }
        internal void Move(int delta, bool startedRight)
        {
            // This first editor supports the two validated monitor-edge anchors.
            long centerTwice = (startedRight ? 2L * MonitorWidth - Width : Width) + 2L * delta;
            OccupiedRight = centerTwice == MonitorWidth ? startedRight : centerTwice > MonitorWidth;
        }
    }

    // Shared presentation for the dashboard's workspace editors. Geometry and
    // preference publication remain owned by the existing planners and callers.
    internal static class CompanionUi
    {
        [DllImport("uxtheme.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
        private static extern int SetWindowTheme(IntPtr window, string application, string classes);

        [DllImport("user32.dll", ExactSpelling = true)]
        private static extern int GetSystemMetricsForDpi(int index, uint dpi);

        internal static int ScrollbarGutter(float scale)
        {
            try
            {
                int width = GetSystemMetricsForDpi(2, (uint)Math.Max(96, Math.Round(96 * scale)));
                if (width > 0) return width;
            }
            catch (DllNotFoundException) { }
            catch (EntryPointNotFoundException) { }
            return Math.Max(SystemInformation.VerticalScrollBarWidth, (int)Math.Ceiling(17 * scale));
        }

        internal static void PrimeScrollbars(Control parent)
        {
            // Hidden log/editor controls otherwise create their native handles
            // during Show, exposing the default non-client paint before theming.
            if (parent is ScrollableControl || parent is TextBoxBase || parent is ListBox)
            {
                IntPtr handle = parent.Handle;
            }
            foreach (Control child in parent.Controls) PrimeScrollbars(child);
        }

        // Theme only managed controls owned by this process. Native scrolling,
        // focus, text selection and accessibility remain with Windows.
        internal static void StyleScrollbars(Control parent)
        {
            var form = parent as Form;
            if (form != null) form.Load += (s, e) => { PrimeScrollbars(form); };
            if (parent is ScrollableControl || parent is TextBoxBase || parent is ListBox)
            {
                EventHandler apply = (s, e) =>
                {
                    if (!parent.IsHandleCreated || parent.IsDisposed) return;
                    try { SetWindowTheme(parent.Handle, SystemInformation.HighContrast ? null : "DarkMode_Explorer", null); }
                    catch (DllNotFoundException) { }
                    catch (EntryPointNotFoundException) { }
                };
                parent.HandleCreated += apply;
                parent.SystemColorsChanged += apply;
                apply(parent, EventArgs.Empty);
            }
            foreach (Control child in parent.Controls) StyleScrollbars(child);
        }
        internal static readonly Color Background=Color.FromArgb(12,12,14), Surface=Color.FromArgb(20,20,24),
            Field=Color.FromArgb(28,28,34), Text=Color.FromArgb(235,230,215), Muted=Color.FromArgb(176,170,158),
            Gold=Color.FromArgb(240,184,54), Border=Color.FromArgb(101,87,58), Warning=Color.FromArgb(255,205,104);
        private static readonly Lazy<Icon> appIcon = new Lazy<Icon>(() =>
        {
            try { return Icon.ExtractAssociatedIcon(Application.ExecutablePath); }
            catch (ArgumentException) { return null; }
            catch (System.ComponentModel.Win32Exception) { return null; }
        });
        internal static Icon AppIcon { get { return appIcon.Value; } }
        internal static string DisplayName(MonitorSelection.Display display,int index)
        {return string.Format("Display {0}: {1} x {2}{3}",index+1,display.Bounds.Width,display.Bounds.Height,display.Primary?" (primary)":"");}
        internal static void StyleButton(Button button,bool primary)
        {
            button.FlatStyle=FlatStyle.Flat;button.UseVisualStyleBackColor=false;
            button.BackColor=primary?Color.FromArgb(44,35,20):Field;button.ForeColor=primary?Gold:Text;
            button.FlatAppearance.BorderColor=primary?Gold:Border;button.FlatAppearance.BorderSize=1;
            button.FlatAppearance.MouseOverBackColor=Color.FromArgb(53,48,37);
            button.FlatAppearance.MouseDownBackColor=Color.FromArgb(69,57,32);
            button.MinimumSize=new Size(button.MinimumSize.Width,32);button.Padding=new Padding(8,3,8,3);
            button.Cursor=Cursors.Hand;StyleDisabledButton(button);
        }
        internal static void StyleDisabledButton(Button button)
        {
            button.Paint+=(s,e)=>{if(button.Enabled)return;e.Graphics.Clear(button.BackColor);
                using(var border=new Pen(Border))e.Graphics.DrawRectangle(border,0,0,button.Width-1,button.Height-1);
                TextRenderer.DrawText(e.Graphics,button.Text,button.Font,Rectangle.Inflate(button.ClientRectangle,-6,-2),Muted,
                    TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter|TextFormatFlags.WordBreak|TextFormatFlags.NoPrefix);};
        }
        internal static void Wrap(Label label)
        {
            int maximum=label.MaximumSize.Width,initialFontHeight=label.Font.Height;
            Action fit=()=>{if(label.Parent==null)return;int width=Math.Max(1,label.Parent.ClientSize.Width-label.Margin.Horizontal);
                if(maximum>0)width=Math.Min(width,(int)Math.Round(maximum*label.Font.Height/(double)initialFontHeight));
                if(label.MaximumSize.Width!=width)label.MaximumSize=new Size(width,0);};
            if(label.Parent!=null)label.Parent.SizeChanged+=(s,e)=>fit();fit();
        }
        internal static void StyleCombo(ComboBox combo)
        {
            combo.BackColor=Field;combo.ForeColor=Text;combo.FlatStyle=FlatStyle.Flat;combo.DrawMode=DrawMode.OwnerDrawFixed;
            Action height=()=>combo.ItemHeight=Math.Max(20,combo.Font.Height+6);height();combo.FontChanged+=(s,e)=>height();
            combo.DrawItem+=(s,e)=>{
                bool selected=(e.State&DrawItemState.Selected)!=0;
                using(var fill=new SolidBrush(selected?Color.FromArgb(59,49,30):Field))e.Graphics.FillRectangle(fill,e.Bounds);
                string text=e.Index>=0&&e.Index<combo.Items.Count?combo.GetItemText(combo.Items[e.Index]):"Choose an option";
                TextRenderer.DrawText(e.Graphics,text,combo.Font,Rectangle.Inflate(e.Bounds,-5,0),combo.Enabled?Text:Muted,
                    TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis|TextFormatFlags.NoPrefix);
                if((e.State&DrawItemState.Focus)!=0)e.DrawFocusRectangle();
            };
        }
        private static void StyleChildren(Control parent,IButtonControl primary)
        {
            foreach(Control child in parent.Controls) {
                child.ForeColor=Text;
                var button=child as Button;
                if(button!=null)StyleButton(button,ReferenceEquals(button,primary));
                else if(child is TextBox || child is NumericUpDown || child is ComboBox || child is ListBox)child.BackColor=Field;
                else child.BackColor=Background;
                var combo=child as ComboBox;if(combo!=null)StyleCombo(combo);
                var text=child as TextBox;if(text!=null)text.BorderStyle=BorderStyle.FixedSingle;
                var number=child as NumericUpDown;if(number!=null){number.BorderStyle=BorderStyle.FixedSingle;number.ThousandsSeparator=true;}
                var label=child as Label;if(label!=null){label.UseMnemonic=false;label.TabStop=false;if(label.AutoSize)Wrap(label);}
                if(!(child is Label)&&string.IsNullOrEmpty(child.AccessibleName)&&!string.IsNullOrEmpty(child.Text))child.AccessibleName=child.Text.Replace("&","");
                if(!(child is NumericUpDown)&&!(child is TextBox)&&!(child is ComboBox))StyleChildren(child,primary);
            }
        }
        internal static void Apply(Form form)
        {
            form.BackColor=Background;form.ForeColor=Text;StyleChildren(form,form.AcceptButton);
            StyleScrollbars(form);
            if (AppIcon != null) form.Icon = AppIcon;
            form.Load += (s, e) => Fit(form, Screen.FromControl(form.Owner ?? form).WorkingArea);
        }
        internal static void Fit(Form form,Rectangle work)
        {
            form.MinimumSize=new Size(Math.Min(form.MinimumSize.Width,work.Width),Math.Min(form.MinimumSize.Height,work.Height));
            form.Size=new Size(Math.Min(form.Width,work.Width),Math.Min(form.Height,work.Height));
            form.Location=new Point(Math.Max(work.Left,Math.Min(form.Left,work.Right-form.Width)),Math.Max(work.Top,Math.Min(form.Top,work.Bottom-form.Height)));
        }
    }

    internal sealed class DashboardViewport : Panel
    {
        internal DashboardViewport() { DoubleBuffered = true; }
    }

    internal sealed class DashboardStack : TableLayoutPanel
    {
        internal DashboardStack() { DoubleBuffered = true; }
    }

    internal sealed class WorkspaceEditorLayout
    {
        internal const string ApplySteps = "Save plan updates your settings. Click Span WoW Now to apply, then reload the WoW UI.";
        internal const string SelectArea = "Select area on monitor...";
        internal const string InvalidPlan = "Check your layout. ";
        internal const string Standard = "Standard display layout";
        internal const string Single = "One monitor";
        internal const string Secondary = "Two monitors";
        internal const string Multiple = "Multiple workspaces";
        internal const string Flexible = "Flexible layout (prototype)";
        internal const string FlexibleAddon = "Use the Offhand addon paired with this Companion build.";

        internal readonly TableLayoutPanel Table;
        private readonly Form form;
        private readonly Panel scroll;

        internal WorkspaceEditorLayout(Form form, string title, Size size, Size minimum, params float[] widths)
        {
            this.form = form;
            form.SuspendLayout();
            form.Text = title;
            form.AutoScaleDimensions = new SizeF(96F, 96F);
            form.AutoScaleMode = AutoScaleMode.Dpi;
            form.Font = new Font("Segoe UI", 10);
            form.ClientSize = size;
            form.MinimumSize = minimum;
            form.StartPosition = FormStartPosition.CenterParent;
            form.MinimizeBox = false;
            form.MaximizeBox = false;
            form.ShowInTaskbar = false;
            scroll = new Panel { Dock = DockStyle.Fill, AutoScroll = true, Padding = new Padding(20, 16, 20, 12) };
            Table = new TableLayoutPanel { Dock = DockStyle.Top, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink,
                ColumnCount = widths.Length, Margin = Padding.Empty, Padding = Padding.Empty };
            scroll.SuspendLayout();
            Table.SuspendLayout();
            foreach (float width in widths) Table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, width));
            scroll.Controls.Add(Table);
        }

        internal static string CurrentMode(IDictionary<string, string> settings)
        {
            if (WorkspaceLayoutSettings.Enabled(settings)) return Flexible;
            if (MonitorSelection.MultiEnabled(settings)) return Multiple;
            string value;
            if (settings.TryGetValue("SecondaryAreaEnabled", out value) && string.Equals(value, "True", StringComparison.OrdinalIgnoreCase)) return Secondary;
            if (settings.TryGetValue("PartialSpanEnabled", out value) && string.Equals(value, "True", StringComparison.OrdinalIgnoreCase)) return Single;
            return Standard;
        }

        internal void AddWide(Control control)
        {
            int row = Table.RowCount++;
            Table.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            Table.Controls.Add(control, 0, row);
            Table.SetColumnSpan(control, Table.ColumnCount);
        }

        internal void Field(string label, Control control)
        {
            int row = Table.RowCount++;
            Table.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            Table.Controls.Add(new Label { Text = label, AutoSize = true, Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleLeft, Margin = new Padding(0, 4, 12, 4) }, 0, row);
            control.AccessibleName = control is CheckBox || control is Button ? control.Text : label;
            control.Margin = new Padding(0, 4, 0, 4);
            Table.Controls.Add(control, 1, row);
        }

        internal Label Heading(string text)
        {
            var heading = new Label { Text = text, Font = new Font(form.Font, FontStyle.Bold), AutoSize = true,
                Dock = DockStyle.Fill, Margin = new Padding(0, Table.RowCount == 0 ? 0 : 14, 0, 5) };
            AddWide(heading);
            return heading;
        }

        internal Label Guide(string text, int bottom = 8)
        {
            var guide = new Label { Text = text, AutoSize = true, Dock = DockStyle.Fill, Margin = new Padding(0, 0, 0, bottom) };
            AddWide(guide);
            return guide;
        }

        internal void ExplainReplacement(IDictionary<string, string> settings, string mode)
        {
            string current = CurrentMode(settings);
            if (current != Standard && current != mode)
                Guide("Saving here replaces the active custom plan (" + current + "). Choose Cancel to keep it.");
        }

        internal void Finish(Button save, Label status = null, Button defaultChoice = null, bool fitHeight = false, Control pinnedPreview = null)
        {
            var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, AutoSize = true, Margin = Padding.Empty };
            var actions = new FlowLayoutPanel { Dock = DockStyle.Bottom, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink,
                Padding = new Padding(20, 8, 20, 12), FlowDirection = FlowDirection.RightToLeft, WrapContents = false };
            actions.Controls.Add(cancel);
            if (save != null)
            {
                save.Margin = new Padding(0, 0, 8, 0);
                actions.Controls.Add(save);
                status.AutoSize = true;
                status.Dock = DockStyle.Bottom;
                status.Padding = new Padding(20, 9, 20, 5);
                status.AccessibleName = "Plan status";
            }
            form.Controls.Add(scroll);
            if (pinnedPreview != null) form.Controls.Add(pinnedPreview);
            if (status != null) form.Controls.Add(status);
            form.Controls.Add(actions);
            form.CancelButton = cancel;
            form.AcceptButton = save ?? defaultChoice;
            CompanionUi.Apply(form);
            foreach (Control control in Table.Controls)
                if (control is Label && control.Font.Bold) control.ForeColor = CompanionUi.Gold;
            actions.BackColor = CompanionUi.Surface;
            form.Load += (s, e) => FitContent(fitHeight);
            form.ResumeLayout(true);
            scroll.ResumeLayout(true);
            Table.ResumeLayout(true);
        }

        internal void FitContent(bool allowShrink)
        {
            Rectangle work = Screen.FromControl(form.Owner ?? form).WorkingArea;
            form.PerformLayout();
            int needed = Table.Height + scroll.Padding.Vertical + 2;
            int height = Math.Min(work.Height, Math.Max(form.MinimumSize.Height, form.Height + needed - scroll.ClientSize.Height));
            if (height == form.Height || (!allowShrink && height < form.Height)) return;
            var bounds = new Rectangle(form.Left, form.Top + (form.Height - height) / 2, form.Width, height);
            form.Bounds = RestoreGeometry.Fit(bounds, work);
            scroll.AutoScrollPosition = Point.Empty;
        }

        internal static void UpdateStatus(Button save, Label status, WorkspacePlanPreview diagram,
            MonitorSelection.Plan plan, string text, bool canSave, bool showEmptyPreview = false)
        {
            save.Enabled = canSave;
            status.Text = canSave ? text + "\r\n" + ApplySteps : text;
            status.ForeColor = canSave ? CompanionUi.Text : CompanionUi.Warning;
            diagram.Plan = plan;
            diagram.Visible = plan != null || showEmptyPreview;
            diagram.Invalidate();
        }
    }

    internal sealed class WorkspacePlanPreview : Control
    {
        internal MonitorSelection.Plan Plan;
        internal IList<MonitorSelection.Display> Displays;
        internal WorkspacePlanPreview(){Height=164;Dock=DockStyle.Fill;DoubleBuffered=true;TabStop=false;AccessibleName="Display layout preview";}
        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);e.Graphics.Clear(CompanionUi.Surface);
            if (Plan == null || Displays == null)
            {
                TextRenderer.DrawText(e.Graphics, "Choose a valid game monitor and Workspace A to preview your layout.", Font, Rectangle.Inflate(ClientRectangle, -12, -8),
                    CompanionUi.Muted, TextFormatFlags.WordBreak | TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
                return;
            }
            Rectangle all=Rectangle.Empty;
            foreach(int index in Plan.Indices)all=all.IsEmpty?Displays[index].Bounds:Rectangle.Union(all,Displays[index].Bounds);
            if(all.Width<=0||all.Height<=0)return;
            int inset=Math.Max(8,Font.Height*3/4),legendHeight=Font.Height+inset;
            float scale=Math.Min(Math.Max(1,Width-2*inset)/(float)all.Width,Math.Max(1,Height-legendHeight-2*inset)/(float)all.Height);
            float x=(Width-all.Width*scale)/2,y=inset;
            Func<Rectangle,RectangleF> map=r=>new RectangleF(x+(r.X-all.X)*scale,y+(r.Y-all.Y)*scale,r.Width*scale,r.Height*scale);
            using(var edge=new Pen(CompanionUi.Border))foreach(int index in Plan.Indices){var r=map(Displays[index].Bounds);e.Graphics.DrawRectangle(edge,r.X,r.Y,r.Width,r.Height);}
            using(var game=new SolidBrush(Color.FromArgb(55,105,74)))e.Graphics.FillRectangle(game,map(Plan.MainhandBounds));
            using(var work=new SolidBrush(Color.FromArgb(175,130,44)))foreach(var r in MonitorSelection.VisibleRectangles(Plan))if(r!=Plan.MainhandBounds)e.Graphics.FillRectangle(work,map(r));
            using(var brush=new SolidBrush(CompanionUi.Text))using(var font=new Font(Font,FontStyle.Regular)) {
                var center=new StringFormat{Alignment=StringAlignment.Center,LineAlignment=StringAlignment.Center};
                e.Graphics.DrawString("Game",font,brush,map(Plan.MainhandBounds),center);
                if(Plan.MultiRegion)using(var edge=new Pen(CompanionUi.Text)) {
                    for(int i=0;i<Plan.Workspaces.Length;i++) {
                        var area=map(Plan.Workspaces[i].Bounds);
                        e.Graphics.DrawRectangle(edge,area.X+.5f,area.Y+.5f,Math.Max(0,area.Width-1),Math.Max(0,area.Height-1));
                        if(area.Width>=font.Height&&area.Height>=font.Height)
                            e.Graphics.DrawString(i==0?"A":"B",font,brush,area,center);
                    }
                }
                center.Dispose();
                e.Graphics.DrawString("Game (green)   Workspace (gold)   Free desktop (unfilled)",font,brush,new RectangleF(inset,Height-legendHeight,Width-2*inset,legendHeight));
            }
        }
    }

    internal sealed class PartialRegionOverlay : Form
    {
        internal readonly PartialRegionSelection Selection;
        private int drag, startX;
        private bool startRight;
        internal PartialRegionOverlay(Rectangle monitor, PartialRegionSelection selection)
        {
            if (monitor.Height < 600 || monitor.Height > 32768 || monitor.Width != selection.MonitorWidth)
                throw new ArgumentException("The selected monitor cannot use this custom layout.");
            Selection = selection; Text = "Select custom workspace area";
            Icon = CompanionUi.AppIcon;
            FormBorderStyle = FormBorderStyle.None; StartPosition = FormStartPosition.Manual;
            AutoScaleMode = AutoScaleMode.None; Bounds = monitor; TopMost = true;
            // Keep the borderless modal reachable through Alt+Tab and accessible
            // as its own desktop window, including when its owner is elsewhere.
            ShowInTaskbar = true; KeyPreview = true; DoubleBuffered = true;
            BackColor = Color.FromArgb(20, 23, 28); Opacity = 0.93;
            var buttons = new FlowLayoutPanel { Dock = DockStyle.Bottom, AutoSize = true,
                FlowDirection = FlowDirection.RightToLeft, Padding = new Padding(16), BackColor = BackColor };
            var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, AutoSize = true };
            var use = new Button { Text = "Use selection", DialogResult = DialogResult.OK, AutoSize = true };
            var flip = new Button { Text = "Swap game and workspace", AutoSize = true };
            foreach (Button button in new Button[] { cancel, use, flip }) {
                button.Font = new Font("Segoe UI", 11); button.Padding = new Padding(12, 6, 12, 6);
                CompanionUi.StyleButton(button,button==use); buttons.Controls.Add(button);
            }
            flip.Click += (s,e) => { Selection.GameLeft = !Selection.GameLeft; Invalidate(); };
            CancelButton = cancel; AcceptButton = use; Controls.Add(buttons);
        }
        protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
        {
            if (keyData == Keys.Enter || keyData == Keys.Escape) {
                DialogResult = keyData == Keys.Enter ? DialogResult.OK : DialogResult.Cancel;
                Close(); return true;
            }
            if (keyData == Keys.Left || keyData == Keys.Right) {
                Selection.OccupiedRight = keyData == Keys.Right; Invalidate(); return true;
            }
            return base.ProcessCmdKey(ref msg, keyData);
        }
        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            var s = Selection; int gameWidth = s.Width - s.WorkspaceWidth;
            Rectangle workspace = new Rectangle(s.Left + (s.GameLeft ? gameWidth : 0), 0, s.WorkspaceWidth, ClientSize.Height);
            Rectangle game = new Rectangle(s.Left + (s.GameLeft ? 0 : s.WorkspaceWidth), 0, gameWidth, ClientSize.Height);
            using (var brush = new SolidBrush(Color.FromArgb(46, 83, 98))) e.Graphics.FillRectangle(brush, workspace);
            using (var brush = new SolidBrush(Color.FromArgb(48, 67, 46))) e.Graphics.FillRectangle(brush, game);
            using (var font = new Font("Segoe UI", 15))
            using (var white = new SolidBrush(Color.White))
            using (var center = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center }) {
                e.Graphics.DrawString("Drag a divider to resize. Drag the combined area to snap it left or right.\nUse Left or Right to choose an edge. Press Enter to use the selection or Esc to cancel.",
                    font, white, new RectangleF(20, 20, ClientSize.Width - 40, 130));
                e.Graphics.DrawString("Workspace\n" + s.WorkspaceWidth + " x " + ClientSize.Height, font, white,
                    new RectangleF(workspace.X, ClientSize.Height / 2 - 100, workspace.Width, 120), center);
                e.Graphics.DrawString("Game\n" + gameWidth + " x " + ClientSize.Height, font, white,
                    new RectangleF(game.X, ClientSize.Height / 2 - 100, game.Width, 120), center);
                int free = s.MonitorWidth - s.Width;
                if (free > 0) e.Graphics.DrawString("Free desktop\n" + free + " px", font, white,
                    new RectangleF(s.OccupiedRight ? 0 : s.Width, ClientSize.Height / 2 - 100, free, 120), center);
            }
            using (var pen = new Pen(Color.White, 3)) {
                e.Graphics.DrawLine(pen, s.OuterDivider, 160, s.OuterDivider, ClientSize.Height - 110);
                e.Graphics.DrawLine(pen, s.WorkspaceDivider, 160, s.WorkspaceDivider, ClientSize.Height - 110);
            }
            using (var brush = new SolidBrush(Color.White)) {
                e.Graphics.FillRectangle(brush, s.OuterDivider - 4, ClientSize.Height / 2 + 50, 8, 70);
                e.Graphics.FillRectangle(brush, s.WorkspaceDivider - 4, ClientSize.Height / 2 + 50, 8, 70);
            }
        }
        private int Hit(int x)
        {
            if (Math.Abs(x - Selection.OuterDivider) <= 14) return 1;
            if (Math.Abs(x - Selection.WorkspaceDivider) <= 14) return 2;
            return x >= Selection.Left && x <= Selection.Left + Selection.Width ? 3 : 0;
        }
        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            if (e.Button != MouseButtons.Left || e.Y < 160 || e.Y > ClientSize.Height - 110) return;
            drag = Hit(e.X); startX = e.X; startRight = Selection.OccupiedRight;
            if (drag != 0) Capture = true;
        }
        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            if (drag == 1) Selection.ResizeOccupied(e.X);
            else if (drag == 2) Selection.ResizeWorkspace(e.X);
            else if (drag == 3) Selection.Move(e.X - startX, startRight);
            Cursor = (drag == 0 ? Hit(e.X) : drag) == 3 ? Cursors.SizeAll : Cursors.SizeWE;
            if (drag != 0) Invalidate();
        }
        protected override void OnMouseUp(MouseEventArgs e)
        { base.OnMouseUp(e); if (e.Button == MouseButtons.Left) { drag = 0; Capture = false; } }
        protected override void OnMouseCaptureChanged(EventArgs e)
        { base.OnMouseCaptureChanged(e); if (!Capture) drag = 0; }
    }

    internal sealed class WorkspaceAreaSelection
    {
        internal readonly Size Monitor;
        internal Rectangle Area;
        internal WorkspaceAreaSelection(Size monitor, Rectangle area)
        {
            if (monitor.Width < 480 || monitor.Height < 600 || monitor.Width > 32768 || monitor.Height > 32768)
                throw new ArgumentException("Workspace monitor must be at least 480 x 600 pixels (maximum 32768 per axis).");
            Monitor = monitor;
            int w = Math.Max(480, Math.Min(monitor.Width, area.Width)), h = Math.Max(600, Math.Min(monitor.Height, area.Height));
            Area = new Rectangle(Math.Max(0, Math.Min(monitor.Width-w, area.X)), Math.Max(0, Math.Min(monitor.Height-h, area.Y)), w, h);
        }
        // Edge bits: left=1, right=2, top=4, bottom=8; zero moves the rectangle.
        internal void Drag(Rectangle original, Point delta, int edges)
        {
            if (edges == 0) {
                Area = new Rectangle(Math.Max(0, Math.Min(Monitor.Width-original.Width, original.X+delta.X)),
                    Math.Max(0, Math.Min(Monitor.Height-original.Height, original.Y+delta.Y)), original.Width, original.Height); return;
            }
            int l=original.Left, r=original.Right, t=original.Top, b=original.Bottom;
            if ((edges & 1) != 0) l=Math.Max(0, Math.Min(r-480, l+delta.X));
            if ((edges & 2) != 0) r=Math.Max(l+480, Math.Min(Monitor.Width, r+delta.X));
            if ((edges & 4) != 0) t=Math.Max(0, Math.Min(b-600, t+delta.Y));
            if ((edges & 8) != 0) b=Math.Max(t+600, Math.Min(Monitor.Height, b+delta.Y));
            Area = Rectangle.FromLTRB(l,t,r,b);
        }
    }

    internal sealed class WorkspaceAreaOverlay : Form
    {
        internal readonly WorkspaceAreaSelection Selection;
        private bool dragging;
        private int edges;
        private Point start;
        private Rectangle original;
        internal WorkspaceAreaOverlay(Rectangle monitor, WorkspaceAreaSelection selection)
        {
            Selection=selection; Text="Select secondary workspace area";
            Icon = CompanionUi.AppIcon;
            FormBorderStyle=FormBorderStyle.None; StartPosition=FormStartPosition.Manual;
            AutoScaleMode=AutoScaleMode.None; Bounds=monitor; TopMost=true; ShowInTaskbar=true;
            DoubleBuffered=true; BackColor=Color.FromArgb(20,23,28); Opacity=0.93;
            var buttons=new FlowLayoutPanel { Dock=DockStyle.Bottom, Height=78, Padding=new Padding(12), FlowDirection=FlowDirection.RightToLeft, BackColor=CompanionUi.Background };
            var cancel=new Button {Text="Cancel",AutoSize=true,DialogResult=DialogResult.Cancel};
            var use=new Button {Text="Use selection",AutoSize=true,DialogResult=DialogResult.OK};
            foreach (Button button in new Button[] {cancel,use}) {
                button.Font=new Font("Segoe UI",11); CompanionUi.StyleButton(button,button==use); buttons.Controls.Add(button);
            }
            Controls.Add(buttons); CancelButton=cancel; AcceptButton=use;
        }
        protected override bool ProcessCmdKey(ref Message msg, Keys key)
        {
            if (key==Keys.Enter || key==Keys.Escape) { DialogResult=key==Keys.Enter?DialogResult.OK:DialogResult.Cancel; Close(); return true; }
            Point delta=Point.Empty;int step=(key&Keys.Control)==Keys.Control?1:10;Keys arrow=key&Keys.KeyCode;
            if (arrow==Keys.Left) delta.X=-step; else if(arrow==Keys.Right) delta.X=step;
            else if(arrow==Keys.Up) delta.Y=-step; else if(arrow==Keys.Down) delta.Y=step;
            else return base.ProcessCmdKey(ref msg,key);
            int resize=(key&Keys.Shift)==Keys.Shift?(delta.X!=0?2:8):0;
            Selection.Drag(Selection.Area,delta,resize); Invalidate(); return true;
        }
        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e); Rectangle a=Selection.Area;
            using(var brush=new SolidBrush(Color.FromArgb(46,83,98))) e.Graphics.FillRectangle(brush,a);
            using(var pen=new Pen(Color.White,3)) e.Graphics.DrawRectangle(pen,a.X,a.Y,a.Width-1,a.Height-1);
            using(var white=new SolidBrush(Color.White))
            using(var font=new Font("Segoe UI",14))
            using(var center=new StringFormat {Alignment=StringAlignment.Center,LineAlignment=StringAlignment.Center}) {
                e.Graphics.DrawString("Drag to move the area or drag its edges to resize.\nUse arrows to move 10 px. Hold Ctrl for 1 px or Shift to resize.\nPress Enter to use the selection or Esc to cancel.",font,white,new RectangleF(16,16,Math.Max(120,ClientSize.Width-32),124));
                e.Graphics.DrawString("Workspace\n"+a.Width+" x "+a.Height+"\nOffset "+a.X+", "+a.Y,font,white,a,center);
                foreach(Point p in new Point[] {a.Location,new Point(a.Right-8,a.Top),new Point(a.Left,a.Bottom-8),new Point(a.Right-8,a.Bottom-8)})
                    e.Graphics.FillRectangle(white,p.X,p.Y,8,8);
            }
        }
        private int Hit(Point p)
        {
            Rectangle a=Selection.Area; var hit=a; hit.Inflate(12,12); if(!hit.Contains(p)) return -1;
            int result=0;
            if(Math.Abs(p.X-a.Left)<=12) result|=1; else if(Math.Abs(p.X-a.Right)<=12) result|=2;
            if(Math.Abs(p.Y-a.Top)<=12) result|=4; else if(Math.Abs(p.Y-a.Bottom)<=12) result|=8;
            return result;
        }
        protected override void OnMouseDown(MouseEventArgs e)
        { base.OnMouseDown(e); if(e.Button!=MouseButtons.Left || Hit(e.Location)<0) return; edges=Hit(e.Location); start=e.Location; original=Selection.Area; dragging=true; Capture=true; }
        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            if(dragging) { Selection.Drag(original,new Point(e.X-start.X,e.Y-start.Y),edges); Invalidate(); }
            int hit=dragging?edges:Hit(e.Location);
            Cursor=hit<0?Cursors.Default:hit==0?Cursors.SizeAll:(hit==1||hit==2)?Cursors.SizeWE:(hit==4||hit==8)?Cursors.SizeNS:(hit==5||hit==10)?Cursors.SizeNWSE:Cursors.SizeNESW;
        }
        protected override void OnMouseUp(MouseEventArgs e) { base.OnMouseUp(e); if(e.Button==MouseButtons.Left) {dragging=false;Capture=false;} }
        protected override void OnMouseCaptureChanged(EventArgs e) {base.OnMouseCaptureChanged(e);if(!Capture)dragging=false;}
    }

    internal sealed class CustomRegionModeDialog : Form
    {
        internal bool Secondary;
        internal bool Multiple;
        internal bool Flexible;
        internal bool UseStandard;
        internal readonly Button SingleButton, SecondaryButton, MultipleButton, FlexibleButton;

        internal CustomRegionModeDialog(IDictionary<string,string> settings)
        {
            string current = WorkspaceEditorLayout.CurrentMode(settings);
            var layout = new WorkspaceEditorLayout(this, "Choose a custom workspace",
                new Size(620, current == WorkspaceEditorLayout.Standard ? 484 : 620), new Size(470, 360), 100);
            layout.Heading("Saved layout");
            layout.Guide(current);
            layout.Heading("Choose a layout to edit");
            layout.Guide("Select an option below. The editor keeps your changes when you click Save plan.");
            SingleButton = AddOption(layout, WorkspaceEditorLayout.Single, "Split one monitor into side-by-side, full-height game and workspace areas.");
            SecondaryButton = AddOption(layout, WorkspaceEditorLayout.Secondary, "Keep one full monitor for the game and choose a workspace area on a second monitor.");
            MultipleButton = AddOption(layout, WorkspaceEditorLayout.Multiple, "Keep one full monitor for the game and place up to two workspaces on separate monitors.");
            FlexibleButton = AddOption(layout, WorkspaceEditorLayout.Flexible, "Place the game and one or two workspaces anywhere on a single monitor. " + WorkspaceEditorLayout.FlexibleAddon);
            if (current != WorkspaceEditorLayout.Standard)
            {
                layout.Heading("Return to a standard layout");
                var standard = AddOption(layout, "Use standard display layout", "Turn off custom workspaces and review the displays to use. Named workspace profiles stay saved.");
                standard.Click += (s, e) => { UseStandard = true; DialogResult = DialogResult.OK; Close(); };
            }

            SingleButton.Click += (s, e) => { DialogResult = DialogResult.OK; Close(); };
            SecondaryButton.Click += (s, e) => { Secondary = true; DialogResult = DialogResult.OK; Close(); };
            MultipleButton.Click += (s, e) => { Multiple = true; DialogResult = DialogResult.OK; Close(); };
            FlexibleButton.Click += (s, e) => { Flexible = true; DialogResult = DialogResult.OK; Close(); };
            Button selected = current == WorkspaceEditorLayout.Flexible ? FlexibleButton
                : current == WorkspaceEditorLayout.Multiple ? MultipleButton
                : current == WorkspaceEditorLayout.Secondary ? SecondaryButton : SingleButton;
            layout.Finish(null, defaultChoice: selected);
            ActiveControl = selected;
        }

        private static Button AddOption(WorkspaceEditorLayout layout, string title, string description)
        {
            var button = new Button { Text = title, TextAlign = ContentAlignment.MiddleLeft, AutoSize = true,
                Dock = DockStyle.Fill, Margin = new Padding(0, 3, 0, 3), AccessibleDescription = description };
            layout.AddWide(button);
            layout.Guide(description);
            return button;
        }
    }

    // Named plans store only display geometry. Launcher, update, graphics and
    // window recovery preferences never travel with a workspace profile.
    internal static class WorkspacePlanProfiles
    {
        internal const string Key="WorkspaceProfilesV1";
        internal const string KeyV2="WorkspaceProfilesV2";
        public sealed class Record { public string ID; public string Name; public int MainWidth; public int MainHeight; public Dictionary<string,string> Settings; public override string ToString(){return Name;} }
        public sealed class Store { public int Version=1; public List<Record> Items=new List<Record>(); }
        internal static bool PlanKey(string key)
        {
            return WorkspaceLayoutSettings.IsSetting(key) || Regex.IsMatch(key,@"^WorkspaceRegion(?:sEnabled|Version|Count|[12](?:Id|Identity|MonitorWidth|MonitorHeight|X|Y|Width|Height))$")
                || Array.IndexOf(new[]{"WorkspacePrimary","MainhandIdentity","MainhandDevice","DisplayIdentityVersion","MonitorIdentities","MonitorDevices","Monitors","SingleDisplaySplit","PartialSpanEnabled","SecondaryAreaEnabled"},key)>=0;
        }
        internal static string Name(string name)
        {
            name=(name??"").Trim();
            if(name.Length<1||name.Length>48||name.IndexOf('|')>=0)throw new InvalidOperationException("Use a profile name with 1 to 48 characters, without vertical bars or control characters.");
            foreach(char c in name)if(char.IsControl(c))throw new InvalidOperationException("Profile names cannot contain control characters.");
            return name;
        }
        private static Store ReadLegacy(IDictionary<string,string> settings)
        {
            string raw;if(!settings.TryGetValue(Key,out raw))return new Store();
            try {
                if(raw.Length>196608)throw new FormatException();
                byte[] bytes=Convert.FromBase64String(raw);if(bytes.Length>131072)throw new FormatException();
                var store=new JavaScriptSerializer{MaxJsonLength=131072,RecursionLimit=8}.Deserialize<Store>(Encoding.UTF8.GetString(bytes));
                if(store==null||store.Version!=1||store.Items==null||store.Items.Count>20)throw new FormatException();
                var ids=new HashSet<string>(StringComparer.Ordinal);var names=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach(var item in store.Items) {
                    if(item==null||item.ID==null||!Regex.IsMatch(item.ID,"^[a-f0-9]{32}$")||!ids.Add(item.ID)
                        ||Name(item.Name)!=item.Name||!names.Add(item.Name)||item.Settings==null||item.Settings.Count>40
                        ||item.MainWidth<960||item.MainHeight<600)throw new FormatException();
                    foreach(var pair in item.Settings)if(!PlanKey(pair.Key)||WorkspaceLayoutSettings.IsSetting(pair.Key)||pair.Value==null||pair.Value.Length>4096)throw new FormatException();
                }
                return store;
            } catch(Exception ex) {
                if(!(ex is FormatException||ex is ArgumentException||ex is InvalidOperationException))throw;
                throw new InvalidOperationException("Saved workspace profiles could not be read. Existing preferences were retained.");
            }
        }
        internal static Store Read(IDictionary<string,string> settings)
        {
            string raw;if(!settings.TryGetValue(KeyV2,out raw))return ReadLegacy(settings);
            try {
                if(raw.Length>699052)throw new FormatException();
                byte[] bytes=Convert.FromBase64String(raw);if(bytes.Length>524288)throw new FormatException();
                var store=new JavaScriptSerializer{MaxJsonLength=524288,RecursionLimit=12}.Deserialize<Store>(new UTF8Encoding(false,true).GetString(bytes));
                if(store==null||store.Version!=2||store.Items==null||store.Items.Count>20)throw new FormatException();
                var ids=new HashSet<string>(StringComparer.Ordinal);var names=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach(var item in store.Items) {
                    if(item==null||item.ID==null||!Regex.IsMatch(item.ID,@"\A[a-f0-9]{32}\z")||!ids.Add(item.ID)
                        ||Name(item.Name)!=item.Name||!names.Add(item.Name)||item.Settings==null||item.Settings.Count>64
                        ||item.MainWidth<960||item.MainHeight<600)throw new FormatException();
                    foreach(var pair in item.Settings)if(!PlanKey(pair.Key)||pair.Value==null||pair.Value.Length>(WorkspaceLayoutSettings.IsSetting(pair.Key)?32768:4096))throw new FormatException();
                    if(WorkspaceLayoutSettings.Enabled(item.Settings))WorkspaceLayoutSettings.Read(item.Settings);
                }
                return store;
            } catch(Exception ex) {
                if(!(ex is FormatException||ex is ArgumentException||ex is InvalidOperationException))throw;
                throw new InvalidOperationException("Saved version 2 workspace profiles could not be read. Existing preferences were retained.");
            }
        }
        private static Dictionary<string,string> Write(IDictionary<string,string> current,Store store)
        {
            var result=new Dictionary<string,string>(current);
            if(store.Version==2||current.ContainsKey(KeyV2)||WorkspaceLayoutSettings.Enabled(current)) {
                store.Version=2;
                string version2=new JavaScriptSerializer{MaxJsonLength=524288,RecursionLimit=12}.Serialize(store);
                result[KeyV2]=Convert.ToBase64String(Encoding.UTF8.GetBytes(version2));
                Read(result);return result;
            }
            string json=new JavaScriptSerializer{MaxJsonLength=131072,RecursionLimit=8}.Serialize(store);
            result[Key]=Convert.ToBase64String(Encoding.UTF8.GetBytes(json));return result;
        }
        private static Record Find(Store store,string id)
        {
            var record=store.Items.Find(item=>item.ID==id);
            if(record==null)throw new InvalidOperationException("Select an existing workspace profile.");return record;
        }
        internal static Dictionary<string,string> Save(IDictionary<string,string> current,string name,string replaceID,IList<MonitorSelection.Display> displays)
        {
            name=Name(name);var store=Read(current);
            if(!MonitorSelection.MultiEnabled(current)&&!WorkspaceLayoutSettings.Enabled(current))throw new InvalidOperationException("Configure custom workspaces before saving a workspace profile.");
            var plan=MonitorSelection.CreatePlan(current,displays);
            var item=replaceID==null?null:Find(store,replaceID);
            if(store.Items.Exists(other=>other!=item&&string.Equals(other.Name,name,StringComparison.OrdinalIgnoreCase)))throw new InvalidOperationException("A workspace profile already has that name.");
            if(item==null){if(store.Items.Count>=20)throw new InvalidOperationException("Keep at most 20 workspace profiles.");item=new Record{ID=Guid.NewGuid().ToString("N")};store.Items.Add(item);}
            item.Name=name;item.MainWidth=plan.MainhandBounds.Width;item.MainHeight=plan.MainhandBounds.Height;item.Settings=new Dictionary<string,string>();
            foreach(var pair in current)if(PlanKey(pair.Key))item.Settings[pair.Key]=pair.Value;
            var result=Write(current,store);result["WorkspaceProfileID"]=item.ID;result["WorkspaceProfileName"]=item.Name;return result;
        }
        internal static Dictionary<string,string> Load(IDictionary<string,string> current,string id,IList<MonitorSelection.Display> displays)
        {
            var item=Find(Read(current),id);var result=new Dictionary<string,string>(current);
            foreach(string key in new List<string>(result.Keys))if(PlanKey(key))result.Remove(key);
            foreach(var pair in item.Settings)result[pair.Key]=pair.Value;
            result["AutoSpan"]="False";
            var plan=MonitorSelection.CreatePlan(result,displays);
            if(!plan.MultiRegion||plan.MainhandBounds.Width!=item.MainWidth||plan.MainhandBounds.Height!=item.MainHeight)
                throw new InvalidOperationException("A profile display resolution changed. Review the connected monitors and save an updated plan.");
            result["WorkspaceProfileID"]=item.ID;result["WorkspaceProfileName"]=item.Name;return result;
        }
        internal static Dictionary<string,string> Rename(IDictionary<string,string> current,string id,string name)
        {
            name=Name(name);var store=Read(current);var item=Find(store,id);
            if(store.Items.Exists(other=>other!=item&&string.Equals(other.Name,name,StringComparison.OrdinalIgnoreCase)))throw new InvalidOperationException("A workspace profile already has that name.");
            item.Name=name;var result=Write(current,store);string active;
            if(result.TryGetValue("WorkspaceProfileID",out active)&&active==id)result["WorkspaceProfileName"]=name;
            return result;
        }
        internal static Dictionary<string,string> Delete(IDictionary<string,string> current,string id)
        {
            var store=Read(current);store.Items.Remove(Find(store,id));var result=Write(current,store);string active;
            if(result.TryGetValue("WorkspaceProfileID",out active)&&active==id){result.Remove("WorkspaceProfileID");result.Remove("WorkspaceProfileName");}
            return result;
        }
    }

    internal sealed class WorkspaceProfilesDialog : Form
    {
        internal Dictionary<string,string> Settings;
        internal bool LoadedPlan;
        private readonly ComboBox selection=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Dock=DockStyle.Fill,DisplayMember="Name"};
        private readonly TextBox name=new TextBox{Dock=DockStyle.Fill,MaxLength=48};
        private readonly Func<List<MonitorSelection.Display>> readDisplays;
        private readonly Dictionary<string,Button> actionsByName=new Dictionary<string,Button>();
        private readonly Label feedback=new Label{AutoSize=true,Dock=DockStyle.Fill,Margin=new Padding(0,12,0,8),AccessibleName="Profile status"};
        internal WorkspaceProfilesDialog(IDictionary<string,string> current,Func<List<MonitorSelection.Display>> displays)
        {
            Settings=new Dictionary<string,string>(current);readDisplays=displays;Text="Workspace profiles";ClientSize=new Size(620,400);MinimumSize=new Size(510,345);
            AutoScaleMode=AutoScaleMode.Dpi;Font=new Font("Segoe UI",10);StartPosition=FormStartPosition.CenterParent;MinimizeBox=false;MaximizeBox=false;
            var layout=new TableLayoutPanel{Dock=DockStyle.Fill,Padding=new Padding(16),ColumnCount=1,AutoScroll=true};
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            layout.Controls.Add(new Label{Text="Save monitor areas as named plans. Loading selects a plan without resizing WoW. Click Span WoW Now to apply, then reload the addon to switch its matching panel layout.",AutoSize=true,MaximumSize=new Size(540,0),Margin=new Padding(0,0,0,12)});
            selection.AccessibleName="Saved workspace profiles";name.AccessibleName="Profile name";
            layout.Controls.Add(new Label{Text="Saved profiles",AutoSize=true});layout.Controls.Add(selection);layout.Controls.Add(new Label{Text="Profile name",AutoSize=true,Margin=new Padding(0,12,0,4)});layout.Controls.Add(name);
            var actions=new FlowLayoutPanel{AutoSize=true,Dock=DockStyle.Fill,WrapContents=true,Margin=new Padding(0,12,0,0)};
            Action<string,Action> button=(text,action)=>{var b=new Button{Text=text,AutoSize=true};actionsByName[text]=b;b.Click+=(s,e)=>{try{action();RefreshProfiles();feedback.ForeColor=CompanionUi.Text;feedback.Text="Changes are pending. Save changes keeps them; Cancel discards them. WoW has not been resized.";}catch(Exception ex){feedback.ForeColor=CompanionUi.Warning;feedback.Text=ex.Message;}};actions.Controls.Add(b);};
            button("Save as new",()=>{Settings=WorkspacePlanProfiles.Save(Settings,name.Text,null,readDisplays());selection.SelectedIndex=-1;});
            button("Update selected",()=>{var item=Selected();Settings=WorkspacePlanProfiles.Save(Settings,item.Name,item.ID,readDisplays());});
            button("Load selected",()=>{Settings=WorkspacePlanProfiles.Load(Settings,Selected().ID,readDisplays());LoadedPlan=true;});
            button("Rename",()=>Settings=WorkspacePlanProfiles.Rename(Settings,Selected().ID,name.Text));
            button("Delete",()=>{var item=Selected();if(MessageBox.Show(this,"Delete the saved profile '"+item.Name+"'? The current display areas and addon layouts are retained.",Text,MessageBoxButtons.OKCancel,MessageBoxIcon.Question)==DialogResult.OK)Settings=WorkspacePlanProfiles.Delete(Settings,item.ID);});
            layout.Controls.Add(actions);layout.Controls.Add(feedback);
            var done=new Button{Text="Save changes",AutoSize=true,DialogResult=DialogResult.OK};var cancel=new Button{Text="Cancel",AutoSize=true,DialogResult=DialogResult.Cancel};
            var footer=new FlowLayoutPanel{Dock=DockStyle.Bottom,AutoSize=true,FlowDirection=FlowDirection.RightToLeft,Padding=new Padding(12)};footer.Controls.Add(cancel);footer.Controls.Add(done);
            Controls.Add(layout);Controls.Add(footer);AcceptButton=done;CancelButton=cancel;
            selection.SelectedIndexChanged+=(s,e)=>{var item=selection.SelectedItem as WorkspacePlanProfiles.Record;if(item!=null)name.Text=item.Name;UpdateActions();};
            name.TextChanged+=(s,e)=>UpdateActions();RefreshProfiles();CompanionUi.Apply(this);
            feedback.Text=selection.Items.Count==0?"No saved profiles yet. Configure Multiple workspaces, enter a name, then Save as new.":"Choose a profile to load or manage. Changes stay pending until Save changes.";
        }
        private void UpdateActions()
        {
            bool selected=selection.SelectedItem is WorkspacePlanProfiles.Record,validName=true;
            try{WorkspacePlanProfiles.Name(name.Text);}catch(InvalidOperationException){validName=false;}
            bool plan=MonitorSelection.MultiEnabled(Settings)||WorkspaceLayoutSettings.Enabled(Settings);
            var store=WorkspacePlanProfiles.Read(Settings);bool fresh=!store.Items.Exists(item=>string.Equals(item.Name,name.Text.Trim(),StringComparison.OrdinalIgnoreCase));
            foreach(var pair in actionsByName)pair.Value.Enabled=pair.Key=="Save as new"?plan&&validName&&fresh&&store.Items.Count<20:
                pair.Key=="Update selected"?selected&&plan:pair.Key=="Rename"?selected&&validName:selected;
        }
        private WorkspacePlanProfiles.Record Selected()
        {
            var item=selection.SelectedItem as WorkspacePlanProfiles.Record;
            if(item==null)throw new InvalidOperationException("Select a saved workspace profile.");return item;
        }
        private void RefreshProfiles()
        {
            var selected=selection.SelectedItem as WorkspacePlanProfiles.Record;string id=selected==null?null:selected.ID;
            var items=WorkspacePlanProfiles.Read(Settings).Items;items.Sort((a,b)=>string.Compare(a.Name,b.Name,StringComparison.CurrentCultureIgnoreCase));
            selection.Items.Clear();foreach(var item in items)selection.Items.Add(item);
            if(id==null)Settings.TryGetValue("WorkspaceProfileID",out id);
            int index=items.FindIndex(item=>item.ID==id);selection.SelectedIndex=index>=0?index:(items.Count>0?0:-1);
            UpdateActions();
        }
    }

    internal sealed class WorkspaceRegionsDialog : Form
    {
        internal Dictionary<string,string> Settings;
        internal readonly ComboBox Game=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Dock=DockStyle.Fill};
        internal readonly ComboBox Primary=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Dock=DockStyle.Fill};
        internal readonly CheckBox UseRegions=new CheckBox{Text="Use this layout",Checked=true,AutoSize=true};
        internal readonly CheckBox Second=new CheckBox{Text="Use Workspace B",Checked=true,AutoSize=true};
        internal readonly ComboBox[] Monitors=new ComboBox[2];
        internal readonly NumericUpDown[,] Areas=new NumericUpDown[2,4];
        internal readonly Button[] SelectAreas=new Button[2];
        private readonly IList<MonitorSelection.Display> displays;
        private readonly IDictionary<string,string> original;
        private readonly string[] ids=new string[2];
        private bool loading;
        private Label preview;
        private Label secondHeading;
        private readonly Panel pinnedPreview;
        internal readonly Button SavePlan=new Button{Text="Save plan",AutoSize=true};
        internal readonly WorkspacePlanPreview Diagram=new WorkspacePlanPreview();
        internal WorkspaceRegionsDialog(IList<MonitorSelection.Display> connected,IDictionary<string,string> settings)
        {
            displays = connected;
            original = settings;
            var layout = new WorkspaceEditorLayout(this, WorkspaceEditorLayout.Multiple, new Size(670, 768), new Size(520, 440), 39, 61);
            var table = layout.Table;
            layout.Heading("1. Choose the game monitor");
            layout.Guide("Use one full monitor for the game and a different monitor for each workspace. The default workspace receives panels without a workspace assignment.");
            layout.ExplainReplacement(settings, WorkspaceEditorLayout.Multiple);
            for(int i=0;i<displays.Count;i++)Game.Items.Add(CompanionUi.DisplayName(displays[i],i));
            string main;settings.TryGetValue("MainhandIdentity",out main);
            Game.SelectedIndex=Find(main,displays.Count > 0 ? 0 : -1);Primary.Items.AddRange(new object[]{"Workspace A","Workspace B"});Primary.SelectedIndex=0;
            string count;Second.Checked=settings.TryGetValue("WorkspaceRegionCount",out count)?count!="1":displays.Count>=3;
            layout.Field("Layout", UseRegions);
            layout.Field("Game monitor", Game);
            layout.Field("Second workspace", Second);
            layout.Field("Default workspace", Primary);
            Primary.AccessibleDescription = "Where supported panels go when they have no assigned workspace.";
            loading = true;
            for (int i = 0; i < 2; i++)
            {
                int slot = i;
                string p = "WorkspaceRegion" + (i + 1), id, identity;
                var areaHeading = layout.Heading(i == 0 ? "2. Set Workspace A" : "3. Set Workspace B");
                if (i == 1) secondHeading = areaHeading;
                ids[i]=settings.TryGetValue(p+"Id",out id)?id:(i==0?"workspace-a":"workspace-b");
                settings.TryGetValue(p+"Identity",out identity);
                Monitors[i]=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Dock=DockStyle.Fill};
                for(int j=0;j<displays.Count;j++)Monitors[i].Items.Add(CompanionUi.DisplayName(displays[j],j));
                int fallback = -1;
                for (int j = 0; j < displays.Count; j++)
                    if (j != Game.SelectedIndex && (i == 0 || j != Monitors[0].SelectedIndex))
                    {
                        fallback = j;
                        break;
                    }
                Monitors[i].SelectedIndex=Find(identity,fallback);
                layout.Field(i == 0 ? "Workspace A monitor" : "Workspace B monitor", Monitors[i]);
                var visual = new Button { Text = WorkspaceEditorLayout.SelectArea, AutoSize = true, Dock = DockStyle.Fill, MaximumSize = new Size(0, 38) };
                SelectAreas[i] = visual;
                layout.Field("Pick an area", visual);
                string[] labels = { "Left offset (px)", "Top offset (px)", "Width (px)", "Height (px)" };
                for (int n = 0; n < 4; n++)
                {
                    Areas[i,n] = new NumericUpDown { Minimum = 0, Maximum = 32768, Dock = DockStyle.Fill };
                    layout.Field(labels[n], Areas[i,n]);
                    Areas[i,n].AccessibleName = "Workspace " + (i == 0 ? "A " : "B ") + labels[n];
                }
                visual.AccessibleName="Select Workspace "+(i==0?"A":"B")+" area on monitor";
                visual.Click+=(s,e)=>EditArea(slot);
                Monitors[i].SelectedIndexChanged+=(s,e)=> {if(!loading){LoadArea(slot);UpdatePreview();}};
                for(int n=0;n<4;n++)Areas[i,n].ValueChanged+=(s,e)=>{if(!loading)UpdatePreview();};
                LoadArea(i);
            }
            string primary;if(settings.TryGetValue("WorkspacePrimary",out primary)&&primary==ids[1])Primary.SelectedIndex=1;
            loading=false;
            Diagram.Displays = displays;
            pinnedPreview = new Panel { Dock = DockStyle.Bottom, Height = 164, Padding = new Padding(20, 6, 20, 0) };
            pinnedPreview.Controls.Add(Diagram);
            preview = new Label();
            Game.SelectedIndexChanged+=(s,e)=>UpdatePreview();Primary.SelectedIndexChanged+=(s,e)=>UpdatePreview();UseRegions.CheckedChanged+=(s,e)=>UpdatePreview();
            Second.CheckedChanged+=(s,e)=> {
                string savedCount;
                if(!Second.Checked&&MonitorSelection.MultiEnabled(original)&&original.TryGetValue("WorkspaceRegionCount",out savedCount)&&savedCount=="2") {
                    if(MessageBox.Show(this,"Remove Workspace B from the next plan? Its saved frames will fall back to Workspace A when applied. Existing positions are retained for recovery.",Text,MessageBoxButtons.OKCancel,MessageBoxIcon.Question)!=DialogResult.OK){Second.Checked=true;return;}
                }
                if(!Second.Checked)Primary.SelectedIndex=0;UpdatePreview();
            };
            SavePlan.Click += (s, e) =>
            {
                try
                {
                    var proposed = Proposed();
                    if (UseRegions.Checked) MonitorSelection.CreatePlan(proposed, displays);
                    Settings = proposed;
                    DialogResult = DialogResult.OK;
                    Close();
                }
                catch (Exception ex)
                {
                    MessageBox.Show(this, ex.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Information);
                }
            };
            layout.Finish(SavePlan, preview, pinnedPreview: pinnedPreview);
            UpdatePreview();
        }
        internal void FitToWorkingArea(Rectangle workArea)
        {
            CompanionUi.Fit(this,workArea);
        }
        private int Find(string identity, int fallback)
        {
            return string.IsNullOrEmpty(identity) ? fallback : Math.Max(-1, MonitorSelection.FindDisplay(displays, identity, null));
        }
        private void LoadArea(int slot)
        {
            if(Monitors[slot].SelectedIndex<0)return;
            bool prior=loading;loading=true;
            var monitor=displays[Monitors[slot].SelectedIndex];string p="WorkspaceRegion"+(slot+1),identity;
            bool saved=original.TryGetValue(p+"Identity",out identity)&&MonitorSelection.FindDisplay(displays,identity,null)==Monitors[slot].SelectedIndex;
            string[] keys={"X","Y","Width","Height"};int[] defaults={0,0,Math.Min(800,monitor.Bounds.Width),Math.Min(1080,monitor.Bounds.Height)};
            for(int n=0;n<4;n++){string value;int parsed;Areas[slot,n].Value=saved&&original.TryGetValue(p+keys[n],out value)&&int.TryParse(value,out parsed)?Math.Max(0,Math.Min(32768,parsed)):defaults[n];}
            loading=prior;
        }
        private void EditArea(int slot)
        {
            if(Monitors[slot].SelectedIndex<0)return;
            try{var monitor=displays[Monitors[slot].SelectedIndex].Bounds;
                var selection=new WorkspaceAreaSelection(monitor.Size,new Rectangle((int)Areas[slot,0].Value,(int)Areas[slot,1].Value,(int)Areas[slot,2].Value,(int)Areas[slot,3].Value));
                using(var overlay=new WorkspaceAreaOverlay(monitor,selection)){if(overlay.ShowDialog(this)!=DialogResult.OK)return;
                    loading=true;int[] values={selection.Area.X,selection.Area.Y,selection.Area.Width,selection.Area.Height};for(int n=0;n<4;n++)Areas[slot,n].Value=values[n];loading=false;UpdatePreview();}}
            catch(ArgumentException ex){loading=false;MessageBox.Show(this,ex.Message,Text);}
        }
        internal Dictionary<string,string> Proposed()
        {
            return Proposed(Second.Checked);
        }

        private Dictionary<string,string> Proposed(bool includeSecond)
        {
            if(!UseRegions.Checked) {
                // Turning the feature off must remain possible after a required
                // display disappears. Retain all saved region definitions.
                var disabled=new Dictionary<string,string>(original);
                disabled[WorkspaceLayoutSettings.EnabledKey]="False";disabled["WorkspaceRegionsEnabled"]="False";disabled["PartialSpanEnabled"]="False";
                disabled["SecondaryAreaEnabled"]="False";disabled["SingleDisplaySplit"]="False";disabled["AutoSpan"]="False";
                int game=Game.SelectedIndex,workspace=Monitors[0].SelectedIndex;
                if(game>=0&&workspace>=0&&game!=workspace) {
                    var g=displays[game];var w=displays[workspace];
                    disabled["DisplayIdentityVersion"]="2";disabled["MainhandIdentity"]=g.StableId;disabled["MainhandDevice"]=g.DeviceName;
                    disabled["MonitorIdentities"]=g.StableId+"|"+w.StableId;disabled["MonitorDevices"]=g.DeviceName+"|"+w.DeviceName;
                    disabled["Monitors"]=game+","+workspace;
                }
                return disabled;
            }
            if (Game.SelectedIndex < 0 || Monitors[0].SelectedIndex < 0)
                throw new InvalidOperationException("Choose connected monitors for the game and Workspace A.");
            if (includeSecond)
            {
                if (displays.Count < 3)
                    throw new InvalidOperationException("Workspace B needs a third connected monitor. Connect one or turn off Workspace B.");
                int second = Monitors[1].SelectedIndex;
                if (second < 0 || second == Game.SelectedIndex || second == Monitors[0].SelectedIndex)
                    throw new InvalidOperationException("Choose a separate monitor for Workspace B.");
            }
            var result=new Dictionary<string,string>(original);int count=includeSecond?2:1;
            result[WorkspaceLayoutSettings.EnabledKey]="False";result["WorkspaceRegionsEnabled"]=UseRegions.Checked.ToString();result["WorkspaceRegionVersion"]="2";result["WorkspaceRegionCount"]=count.ToString();
            result["PartialSpanEnabled"]="False";result["SecondaryAreaEnabled"]="False";result["SingleDisplaySplit"]="False";result["AutoSpan"]="False";
            result["DisplayIdentityVersion"]="2";result["MainhandIdentity"]=displays[Game.SelectedIndex].StableId;result["MainhandDevice"]=displays[Game.SelectedIndex].DeviceName;
            result["WorkspacePrimary"]=ids[Primary.SelectedIndex==1&&count==2?1:0];
            var identities=new List<string>{displays[Game.SelectedIndex].StableId};var devices=new List<string>{displays[Game.SelectedIndex].DeviceName};var legacy=new List<string>{Game.SelectedIndex.ToString()};
            for(int i=0;i<count;i++) {
                var monitor=displays[Monitors[i].SelectedIndex];string p="WorkspaceRegion"+(i+1);result[p+"Id"]=ids[i];result[p+"Identity"]=monitor.StableId;
                result[p+"MonitorWidth"]=monitor.Bounds.Width.ToString();result[p+"MonitorHeight"]=monitor.Bounds.Height.ToString();
                string[] keys={"X","Y","Width","Height"};for(int n=0;n<4;n++)result[p+keys[n]]=Areas[i,n].Value.ToString();
                identities.Add(monitor.StableId);devices.Add(monitor.DeviceName);legacy.Add(Monitors[i].SelectedIndex.ToString());
            }
            result["MonitorIdentities"]=string.Join("|",identities.ToArray());result["MonitorDevices"]=string.Join("|",devices.ToArray());result["Monitors"]=string.Join(",",legacy.ToArray());return result;
        }
        private void UpdatePreview()
        {
            if(loading||preview==null)return;
            bool enabled=UseRegions.Checked;
            Second.Enabled=enabled;Primary.Enabled=enabled&&Second.Checked;
            secondHeading.Visible=Second.Checked;
            pinnedPreview.Visible = enabled;
            var table = (TableLayoutPanel)Monitors[1].Parent;
            table.SuspendLayout();
            try
            {
                foreach (Control field in new Control[] { Monitors[1], Areas[1,0], Areas[1,1], Areas[1,2], Areas[1,3], SelectAreas[1] })
                {
                    field.Visible = Second.Checked;
                    var label = table.GetControlFromPosition(0, table.GetRow(field));
                    label.Visible = Second.Checked;
                }
            }
            finally { table.ResumeLayout(true); }
            if(!Second.Checked&&Primary.SelectedIndex!=0)Primary.SelectedIndex=0;
            for(int i=0;i<2;i++) {
                bool active=enabled&&(i==0||Second.Checked);
                if(i==1)Monitors[i].Enabled=active;
                for(int n=0;n<4;n++)Areas[i,n].Enabled=active;
                SelectAreas[i].Enabled=active&&Monitors[i].SelectedIndex>=0;
            }
            try
            {
                var settings = Proposed();
                if (!enabled)
                {
                    WorkspaceEditorLayout.UpdateStatus(SavePlan, preview, Diagram, null,
                        "Custom workspaces are off. Save the plan, then review Span displays and Mainhand (game).", true);
                    return;
                }
                var plan = MonitorSelection.CreatePlan(settings, displays);
                double ratio = (double)plan.Bounds.Width * plan.Bounds.Height / ((long)plan.MainhandBounds.Width * plan.MainhandBounds.Height);
                string summary = plan.Workspaces.Length == 1 ? "One workspace is ready." : "Two workspaces are ready.";
                if (ratio >= 2)
                    summary += string.Format(" WoW renders {0:0.0}× the game area. This can affect performance.", ratio);
                WorkspaceEditorLayout.UpdateStatus(SavePlan, preview, Diagram, plan, summary, true);
                Diagram.AccessibleDescription = string.Format("{0} × {1} pixels across the game and workspace areas.", plan.Bounds.Width, plan.Bounds.Height);
            }
            catch (Exception ex)
            {
                // Keep the valid part of the current draft in view while the
                // user fixes Workspace B. Never save that partial preview.
                MonitorSelection.Plan gameAndA = null;
                if (Second.Checked)
                {
                    try { gameAndA = MonitorSelection.CreatePlan(Proposed(false), displays); }
                    catch (InvalidOperationException) { }
                }
                string message = WorkspaceEditorLayout.InvalidPlan + ex.Message;
                if (gameAndA != null) message += "\r\nPreview shows the game and Workspace A.";
                WorkspaceEditorLayout.UpdateStatus(SavePlan, preview, Diagram, gameAndA, message, false, showEmptyPreview: true);
                Diagram.AccessibleDescription = gameAndA == null ? message : "Preview shows the game and Workspace A.";
            }
        }
    }

    internal sealed class SecondaryAreaDialog : Form
    {
        internal Dictionary<string,string> Settings;
        private readonly ComboBox game=new ComboBox {DropDownStyle=ComboBoxStyle.DropDownList,Dock=DockStyle.Fill};
        private readonly ComboBox work=new ComboBox {DropDownStyle=ComboBoxStyle.DropDownList,Dock=DockStyle.Fill};
        private readonly NumericUpDown x=new NumericUpDown(), y=new NumericUpDown(), width=new NumericUpDown(), height=new NumericUpDown();
        private readonly CheckBox enabled=new CheckBox {Text="Use this layout",Checked=true,AutoSize=true};
        internal readonly Button SavePlan=new Button{Text="Save plan",AutoSize=true};
        internal SecondaryAreaDialog(IList<MonitorSelection.Display> displays, IDictionary<string,string> settings)
        {
            var layout = new WorkspaceEditorLayout(this, "Two-monitor workspace", new Size(640, 695), new Size(500, 430), 40, 60);
            layout.Heading("1. Choose two monitors");
            layout.Guide("The game uses a full monitor. Choose a rectangle on the second monitor for your Offhand panels.");
            layout.ExplainReplacement(settings, WorkspaceEditorLayout.Secondary);
            for (int i = 0; i < displays.Count; i++)
            {
                string name = CompanionUi.DisplayName(displays[i], i);
                game.Items.Add(name);
                work.Items.Add(name);
            }
            for(int i=0;i<displays.Count;i++) {
                string id; if(settings.TryGetValue("MainhandIdentity",out id)&&MonitorSelection.FindDisplay(displays,id,null)==i)game.SelectedIndex=i;
                if(settings.TryGetValue("SecondaryAreaIdentity",out id)&&MonitorSelection.FindDisplay(displays,id,null)==i)work.SelectedIndex=i;
            }
            if(game.SelectedIndex<0&&displays.Count>0&&!settings.ContainsKey("MainhandIdentity"))game.SelectedIndex=0;
            if(work.SelectedIndex<0&&displays.Count>1&&!settings.ContainsKey("SecondaryAreaIdentity"))work.SelectedIndex=game.SelectedIndex==0?1:0;
            foreach(var n in new NumericUpDown[] {x,y,width,height}) {n.Minimum=0;n.Maximum=32768;n.Dock=DockStyle.Fill;}
            layout.Field("Layout", enabled);
            layout.Field("Game monitor", game);
            layout.Field("Workspace monitor", work);
            layout.Heading("2. Set the workspace area");
            layout.Guide("New plans use the full workspace monitor. Select a smaller area only if you want to leave desktop space free.");
            var visual = new Button { Text = WorkspaceEditorLayout.SelectArea, AutoSize = true, Dock = DockStyle.Fill, MaximumSize = new Size(0, 38) };
            layout.Field("Pick an area", visual);
            layout.Field("Left offset (px)", x);
            layout.Field("Top offset (px)", y);
            layout.Field("Workspace width (px)", width);
            layout.Field("Workspace height (px)", height);
            var review = layout.Heading("3. Review the layout");
            var diagram = new WorkspacePlanPreview { Displays = displays };
            layout.AddWide(diagram);
            var preview = new Label();
            Func<Dictionary<string,string>> proposed=()=> {
                var result=new Dictionary<string,string>(settings);result[WorkspaceLayoutSettings.EnabledKey]="False";result["SecondaryAreaEnabled"]=enabled.Checked.ToString();result["PartialSpanEnabled"]="False";result["WorkspaceRegionsEnabled"]="False";
                if(!enabled.Checked)return result;
                if(game.SelectedIndex<0||work.SelectedIndex<0||game.SelectedIndex==work.SelectedIndex)throw new InvalidOperationException("Choose two different connected monitors.");
                var g=displays[game.SelectedIndex];var w=displays[work.SelectedIndex];
                result["DisplayIdentityVersion"]="2";result["MonitorIdentities"]=g.StableId+"|"+w.StableId;result["MonitorDevices"]=g.DeviceName+"|"+w.DeviceName;result["Monitors"]=g.Index+","+w.Index;
                result["MainhandIdentity"]=g.StableId;result["MainhandDevice"]=g.DeviceName;result["SecondaryAreaIdentity"]=w.StableId;
                result["SecondaryMonitorWidth"]=w.Bounds.Width.ToString();result["SecondaryMonitorHeight"]=w.Bounds.Height.ToString();
                result["SecondaryAreaX"]=x.Value.ToString();result["SecondaryAreaY"]=y.Value.ToString();result["SecondaryAreaWidth"]=width.Value.ToString();result["SecondaryAreaHeight"]=height.Value.ToString();result["AutoSpan"]="False";result["SingleDisplaySplit"]="False";
                return result;
            };
            Action update = () =>
            {
                visual.Enabled = enabled.Checked && work.SelectedIndex >= 0;
                foreach (var field in new[] { x, y, width, height }) field.Enabled = enabled.Checked;
                try
                {
                    if (!enabled.Checked)
                    {
                        WorkspaceEditorLayout.UpdateStatus(SavePlan, preview, diagram, null,
                            "The custom area is off. Save the plan, then review Span displays and Mainhand (game).", true);
                        return;
                    }
                    var plan = MonitorSelection.CreatePlan(proposed(), displays);
                    string summary = string.Format("Workspace ready on Display {0} ({1:N0} × {2:N0} px).",
                        work.SelectedIndex + 1, plan.WorkspaceBounds.Width, plan.WorkspaceBounds.Height);
                    WorkspaceEditorLayout.UpdateStatus(SavePlan, preview, diagram, plan, summary, true);
                }
                catch (Exception ex)
                {
                    WorkspaceEditorLayout.UpdateStatus(SavePlan, preview, diagram, null, WorkspaceEditorLayout.InvalidPlan + ex.Message, false);
                }
                finally { review.Visible = diagram.Plan != null; }
            };
            Action load=()=> {
                if(work.SelectedIndex<0||game.SelectedIndex<0)return;var w=displays[work.SelectedIndex];
                int dx=0,dy=0,dw=w.Bounds.Width,dh=w.Bounds.Height;
                string id;bool saved=settings.TryGetValue("SecondaryAreaIdentity",out id)&&MonitorSelection.FindDisplay(displays,id,null)==work.SelectedIndex;
                NumericUpDown[] controls={x,y,width,height};string[] keys={"SecondaryAreaX","SecondaryAreaY","SecondaryAreaWidth","SecondaryAreaHeight"};int[] values={dx,dy,dw,dh};
                for(int i=0;i<4;i++){int v;string value;controls[i].Value=saved&&settings.TryGetValue(keys[i],out value)&&int.TryParse(value,out v)?Math.Max(0,Math.Min(32768,v)):values[i];}update();
            };
            game.SelectedIndexChanged+=(s,e)=>load();work.SelectedIndexChanged+=(s,e)=>load();foreach(var n in new NumericUpDown[] {x,y,width,height})n.ValueChanged+=(s,e)=>update();enabled.CheckedChanged+=(s,e)=>update();
            visual.Click+=(s,e)=> {if(work.SelectedIndex<0)return;try {var m=displays[work.SelectedIndex].Bounds;var selection=new WorkspaceAreaSelection(m.Size,new Rectangle((int)x.Value,(int)y.Value,(int)width.Value,(int)height.Value));using(var overlay=new WorkspaceAreaOverlay(m,selection)){if(overlay.ShowDialog(this)!=DialogResult.OK)return;x.Value=selection.Area.X;y.Value=selection.Area.Y;width.Value=selection.Area.Width;height.Value=selection.Area.Height;}}catch(ArgumentException ex){MessageBox.Show(this,ex.Message,Text);}};
            SavePlan.Click += (s, e) =>
            {
                try
                {
                    var pending = proposed();
                    if (enabled.Checked) MonitorSelection.CreatePlan(pending, displays);
                    Settings = pending;
                    DialogResult = DialogResult.OK;
                    Close();
                }
                catch (Exception ex)
                {
                    MessageBox.Show(this, ex.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Information);
                }
            };
            layout.Finish(SavePlan, preview);
            load();
            update();
        }
    }

    // Editing this dialog changes only a pending settings copy. The owner saves
    // atomically on OK; native window changes remain an explicit Span action.
    internal sealed class PartialSpanDialog : Form
    {
        internal Dictionary<string, string> Settings;
        internal readonly ComboBox DisplaySelector = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Dock = DockStyle.Fill };
        internal readonly NumericUpDown OccupiedWidth = new NumericUpDown { Minimum = 1, Maximum = 32768, Dock = DockStyle.Fill };
        internal readonly NumericUpDown WorkspaceWidth = new NumericUpDown { Minimum = 1, Maximum = 32768, Dock = DockStyle.Fill };
        internal readonly Button SavePlan=new Button{Text="Save plan",AutoSize=true};
        private readonly CheckBox enabled = new CheckBox { Text = "Use this layout", AutoSize = true };
        private readonly ComboBox edge = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Dock = DockStyle.Fill };
        private readonly ComboBox side = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Dock = DockStyle.Fill };
        private readonly Label preview = new Label();
        internal PartialSpanDialog(IList<MonitorSelection.Display> displays, IDictionary<string, string> settings)
        {
            var layout = new WorkspaceEditorLayout(this, "One-monitor workspace", new Size(640, 695), new Size(500, 430), 43, 57);
            layout.Heading("1. Choose a monitor");
            layout.Guide("The game and workspace sit side by side at the full height of one monitor.");
            layout.ExplainReplacement(settings, WorkspaceEditorLayout.Single);
            layout.Field("Layout", enabled);
            layout.Field("Monitor", DisplaySelector);
            layout.Heading("2. Set the game and workspace widths");
            layout.Guide("Use the monitor overlay or enter widths below. The combined width includes the game and workspace.");
            var visual = new Button { Text = WorkspaceEditorLayout.SelectArea, AutoSize = true, Dock = DockStyle.Fill, MaximumSize = new Size(0, 38) };
            layout.Field("Pick an area", visual);
            layout.Field("Combined width (px)", OccupiedWidth);
            layout.Field("Workspace width (px)", WorkspaceWidth);
            layout.Field("Anchor combined area to", edge);
            layout.Field("Game side within area", side);
            var review = layout.Heading("3. Review the layout");
            var diagram = new WorkspacePlanPreview { Displays = displays };
            layout.AddWide(diagram);
            visual.Click += (s,e) => {
                if (DisplaySelector.SelectedIndex < 0) return;
                var monitor = displays[DisplaySelector.SelectedIndex].Bounds;
                try {
                    var selection = new PartialRegionSelection(monitor.Width, (int)OccupiedWidth.Value,
                        (int)WorkspaceWidth.Value, edge.SelectedIndex == 1, side.SelectedIndex == 1);
                    using (var overlay = new PartialRegionOverlay(monitor, selection)) {
                        if (overlay.ShowDialog(this) != DialogResult.OK) return;
                        OccupiedWidth.Value = selection.Width; WorkspaceWidth.Value = selection.WorkspaceWidth;
                        edge.SelectedIndex = selection.OccupiedRight ? 1 : 0;
                        side.SelectedIndex = selection.GameLeft ? 1 : 0;
                        enabled.Checked = true;
                    }
                } catch (ArgumentException ex) { MessageBox.Show(this, ex.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Information); }
            };
            edge.Items.AddRange(new object[] { "Left", "Right" }); side.Items.AddRange(new object[] { "Right", "Left" });
            edge.SelectedIndex = settings.ContainsKey("PartialEdge") && settings["PartialEdge"] == "RIGHT" ? 1 : 0;
            side.SelectedIndex = settings.ContainsKey("PartialGameSide") && settings["PartialGameSide"] == "LEFT" ? 1 : 0;
            enabled.Checked = true;
            for (int i = 0; i < displays.Count; i++) {
                DisplaySelector.Items.Add(CompanionUi.DisplayName(displays[i], i));
                if (settings.ContainsKey("PartialDisplayIdentity") && MonitorSelection.FindDisplay(displays,settings["PartialDisplayIdentity"],null)==i) DisplaySelector.SelectedIndex = i;
            }
            if (DisplaySelector.SelectedIndex < 0 && displays.Count > 0 && !settings.ContainsKey("PartialDisplayIdentity")) DisplaySelector.SelectedIndex = 0;
            int value;
            int defaultWidth = DisplaySelector.SelectedIndex < 0 ? 1440
                : Math.Max(1440, Math.Min(4080, displays[DisplaySelector.SelectedIndex].Bounds.Width - 320));
            OccupiedWidth.Value = settings.ContainsKey("PartialWidth") && int.TryParse(settings["PartialWidth"], out value)
                ? Math.Max(1, Math.Min(32768, value)) : defaultWidth;
            WorkspaceWidth.Value = settings.ContainsKey("PartialWorkspaceWidth") && int.TryParse(settings["PartialWorkspaceWidth"], out value)
                ? Math.Max(1, Math.Min(32768, value)) : 640;
            Func<Dictionary<string,string>> proposed=()=>{
                var result=new Dictionary<string,string>(settings);
                result[WorkspaceLayoutSettings.EnabledKey]="False";result["PartialSpanEnabled"]=enabled.Checked.ToString();result["SecondaryAreaEnabled"]="False";result["WorkspaceRegionsEnabled"]="False";
                if(!enabled.Checked)return result;
                if(DisplaySelector.SelectedIndex<0)throw new InvalidOperationException("Choose a connected display.");
                var display=displays[DisplaySelector.SelectedIndex];
                result["PartialDisplayIdentity"]=display.StableId;result["PartialMonitorWidth"]=display.Bounds.Width.ToString();result["PartialMonitorHeight"]=display.Bounds.Height.ToString();
                result["PartialWidth"]=OccupiedWidth.Value.ToString();result["PartialWorkspaceWidth"]=WorkspaceWidth.Value.ToString();
                result["PartialEdge"]=edge.SelectedIndex==0?"LEFT":"RIGHT";result["PartialGameSide"]=side.SelectedIndex==0?"RIGHT":"LEFT";
                result["MonitorIdentities"]=display.StableId;result["MonitorDevices"]=display.DeviceName;result["Monitors"]=display.Index.ToString();
                result["MainhandIdentity"]=display.StableId;result["MainhandDevice"]=display.DeviceName;result["DisplayIdentityVersion"]="2";result["AutoSpan"]="False";
                return result;
            };
            Action update = () =>
            {
                foreach (Control field in new Control[] { OccupiedWidth, WorkspaceWidth, edge, side })
                    field.Enabled = enabled.Checked;
                visual.Enabled = enabled.Checked && DisplaySelector.SelectedIndex >= 0;
                try
                {
                    if (!enabled.Checked)
                    {
                        WorkspaceEditorLayout.UpdateStatus(SavePlan, preview, diagram, null,
                            "This layout is off. Save the plan, then review Span displays and Mainhand (game).", true);
                        return;
                    }
                    var plan = MonitorSelection.CreatePlan(proposed(), displays);
                    string summary = string.Format("Game {0:N0} px wide. Workspace {1:N0} px wide.",
                        plan.MainhandBounds.Width, plan.WorkspaceBounds.Width);
                    WorkspaceEditorLayout.UpdateStatus(SavePlan, preview, diagram, plan, summary, true);
                }
                catch (Exception ex)
                {
                    WorkspaceEditorLayout.UpdateStatus(SavePlan, preview, diagram, null, WorkspaceEditorLayout.InvalidPlan + ex.Message, false);
                }
                finally { review.Visible = diagram.Plan != null; }
            };
            DisplaySelector.SelectedIndexChanged += (s,e) => update();
            OccupiedWidth.ValueChanged += (s,e) => update();
            WorkspaceWidth.ValueChanged += (s,e) => update();
            enabled.CheckedChanged += (s,e) => update();
            edge.SelectedIndexChanged += (s,e) => update();
            side.SelectedIndexChanged += (s,e) => update();
            SavePlan.Click += (s,e) =>
            {
                try
                {
                    var pending = proposed();
                    if (enabled.Checked) MonitorSelection.CreatePlan(pending, displays);
                    Settings = pending;
                    DialogResult = DialogResult.OK;
                    Close();
                }
                catch (Exception ex)
                {
                    WorkspaceEditorLayout.UpdateStatus(SavePlan, preview, diagram, null, WorkspaceEditorLayout.InvalidPlan + ex.Message, false);
                }
            };
            layout.Finish(SavePlan, preview);
            update();
        }
    }

    internal static class WindowInteropDiagnostics
    {
        internal static string StyleFailure(string action, int error)
        {
            string detail = string.Format("{0} (Windows error {1}).", action, error);
            if (error == 5)
                return detail + " Windows blocked cross-process window control. Close both programs and launch WoW and Offhand Companion at the same privilege level; avoid Run as administrator unless both must use it.";
            return detail + " Confirm WoW is using standard Windowed mode, then restart WoW and the Companion and retry.";
        }
    }

    // Pure decision logic for the captured graphics-reset signature.
    // A Companion-applied span establishes ownership; ordinary resizes do not.
    internal sealed class ClassicGraphicsRecovery
    {
        internal sealed class Observation
        {
            internal IntPtr Handle;
            internal Rectangle Bounds, Region;
            internal Size Client;
            internal int Style;
            internal bool Usable;
        }
        private readonly IntPtr handle;
        private readonly Rectangle span;
        private readonly Size originalClient;
        internal readonly string PlanKey;
        private string pending;
        private DateTime since;
        internal bool Spent;
        internal bool Confirmed;
        internal bool Rearming, InFlight;
        internal string StopReason;
        private DateTime cooldownUntil, verificationDeadline;
        private readonly Queue<DateTime> attempts = new Queue<DateTime>();
        internal const int CooldownSeconds = 10, StableSeconds = 4, AttemptLimit = 3, WindowSeconds = 300;
        internal bool Armed { get { return Confirmed && !Spent && !Rearming && !InFlight; } }
        internal ClassicGraphicsRecovery(IntPtr handle, Rectangle span, Size originalClient, string planKey)
        { this.handle = handle; this.span = span; this.originalClient = originalClient; PlanKey = planKey; }
        internal static bool IsClassicClient(string wowDir)
        {
            if (string.IsNullOrEmpty(wowDir)) return false;
            string leaf = Path.GetFileName(wowDir.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
            return string.Equals(leaf, "_anniversary_", StringComparison.OrdinalIgnoreCase)
                || string.Equals(leaf, "_classic_era_", StringComparison.OrdinalIgnoreCase);
        }
        internal static bool IsProductionClient(string wowDir)
        {
            // Prior live acceptance covers Anniversary and Retail only. Normal
            // spanning remains available for clients without recovery acceptance.
            if (string.IsNullOrEmpty(wowDir)) return false;
            string leaf = Path.GetFileName(wowDir.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
            return string.Equals(leaf, "_anniversary_", StringComparison.OrdinalIgnoreCase)
                || string.Equals(leaf, "_retail_", StringComparison.OrdinalIgnoreCase);
        }
        internal enum ClientScope { Classic, Retail, Forever }
        internal static bool IsSupportedClient(string wowDir, bool retailTest)
        { return IsSupportedClient(wowDir, retailTest ? ClientScope.Retail : ClientScope.Classic); }
        internal static bool IsSupportedClient(string wowDir, ClientScope scope)
        {
            if (scope == ClientScope.Classic) return IsClassicClient(wowDir);
            if (string.IsNullOrEmpty(wowDir)) return false;
            string leaf = Path.GetFileName(wowDir.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
            if (scope == ClientScope.Retail) return string.Equals(leaf, "_retail_", StringComparison.OrdinalIgnoreCase);
            if (scope == ClientScope.Forever) return string.Equals(leaf, "_forever_", StringComparison.OrdinalIgnoreCase);
            return false;
        }
        internal bool Owns(IntPtr currentHandle, string planKey)
        { return handle == currentHandle && string.Equals(PlanKey, planKey, StringComparison.Ordinal); }
        internal void CompleteAttempt(bool succeeded, DateTime now)
        {
            if (Spent || !InFlight) return;
            InFlight = false;
            pending = null;
            if (!succeeded) { Spent = true; StopReason = "recovery failed"; return; }
            Rearming = true;
            cooldownUntil = now.AddSeconds(CooldownSeconds);
            verificationDeadline = now.AddSeconds(20);
        }
        internal bool Observe(Observation current, string planKey, DateTime now, bool monitoring)
        {
            if (Spent) return false;
            if (!monitoring || current == null || !Owns(current.Handle, planKey))
            { Spent = true; StopReason = "ownership changed"; return false; }
            if (InFlight) return false;
            if (!current.Usable)
            {
                pending = null;
                if (Rearming && now >= verificationDeadline) { Spent = true; StopReason = "stability check failed"; }
                return false;
            }
            bool healthy = current.Bounds == span && current.Client == span.Size
                && current.Region == new Rectangle(Point.Empty, span.Size)
                && (current.Style & (NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME)) == 0;
            if (Rearming)
            {
                if (now > verificationDeadline)
                { Spent = true; StopReason = "stability check failed"; return false; }
                // Recovery success must survive native asynchronous updates.
                // Never issue another resize during this verification/cooldown.
                if (!healthy) pending = null;
                else
                {
                    if (pending != "healthy") { pending = "healthy"; since = now; }
                    if ((now - since).TotalSeconds >= StableSeconds && now >= cooldownUntil)
                    { Rearming = false; pending = null; return false; }
                }
                if (now >= verificationDeadline) { Spent = true; StopReason = "stability check failed"; }
                return false;
            }
            if (healthy && Confirmed) { pending = null; return false; }
            string signature = current.Bounds.ToString() + current.Client.ToString() + current.Style
                + current.Region.ToString();
            if (pending != signature) { pending = signature; since = now; return false; }
            if ((now - since).TotalSeconds < 2) return false;
            if (!Confirmed)
            {
                if (healthy) { Confirmed = true; pending = null; }
                else { Spent = true; StopReason = "initial span unstable"; }
                return false;
            }
            bool reset = originalClient.Width > 0 && originalClient.Height > 0
                && originalClient != span.Size
                && (current.Client == originalClient || current.Bounds.Size == originalClient)
                && (current.Style & NativeMethods.WS_THICKFRAME) != 0
                && current.Region == new Rectangle(Point.Empty, span.Size);
            if (!reset) { Spent = true; StopReason = "unrecognized window change"; return false; }
            while (attempts.Count > 0 && (now - attempts.Peek()).TotalSeconds >= WindowSeconds) attempts.Dequeue();
            if (attempts.Count >= AttemptLimit) { Spent = true; StopReason = "attempt limit"; return false; }
            attempts.Enqueue(now);
            InFlight = true;
            pending = null;
            return true;
        }
    }

    internal static class RenderResizeHandshake
    {
        internal static bool Allowed(bool classicGraphicsCandidate)
        {
#if GRAININESS_TEST
            return !classicGraphicsCandidate;
#else
            // The resize comparison has conflicting live evidence. Keep it
            // exclusive to the explicit graininess experiment until accepted.
            return false;
#endif
        }
        internal static Rectangle IntermediateBounds(Rectangle target)
        {
            // Keep the origin and width stable so mixed-width/negative-origin
            // monitor regions do not shift. A one-pixel height change is enough
            // to produce a second ordinary WM_SIZE through SetWindowPos after
            // the borderless style has settled. The exact target is restored
            // immediately afterward.
            if (target.Height > 1)
                return new Rectangle(target.X, target.Y, target.Width, target.Height - 1);
            if (target.Width > 1)
                return new Rectangle(target.X, target.Y, target.Width - 1, target.Height);
            return target;
        }
    }

    internal sealed class AddonInstallCheck
    {
        internal bool Installed;
        internal string AddonDir;
        internal string ExpectedAddonDir;
        internal string ReleaseTag;
        internal string Version;
        internal int? CompanionProtocol;
        internal string MinimumCompanionVersion;
        internal string Reason;
        internal string SetupHint;
    }

    internal static class AddonInstallation
    {
        internal const int SupportedCompanionProtocol = 1;
        internal const string LegacyCompanionVersion = "2.1.2";
        private static readonly string[] ManifestNames = new string[] {
            "Offhand.toc", "Offhand_Mainline.toc", "Offhand_Vanilla.toc",
            "Offhand_Classic.toc", "Offhand_Forever.toc"
        };

        private static string ChildDirectory(string parent, string wanted)
        {
            if (string.IsNullOrEmpty(parent) || !Directory.Exists(parent)) return null;
            string exact = Path.Combine(parent, wanted);
            if (Directory.Exists(exact)) return exact;
            try
            {
                foreach (string child in Directory.GetDirectories(parent))
                    if (string.Equals(Path.GetFileName(child), wanted, StringComparison.OrdinalIgnoreCase))
                        return child;
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
            return null;
        }

        private static bool HasManifest(string addonDir)
        {
            if (string.IsNullOrEmpty(addonDir) || !Directory.Exists(addonDir)) return false;
            try
            {
                var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (string file in Directory.GetFiles(addonDir, "*.toc", SearchOption.TopDirectoryOnly))
                    names.Add(Path.GetFileName(file));
                foreach (string manifest in ManifestNames)
                    if (names.Contains(manifest)) return true;
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
            return false;
        }

        private static string ReadMetadata(string addonDir, string key)
        {
            if (string.IsNullOrEmpty(addonDir)) return null;
            string prefix = "## " + key + ":";
            foreach (string manifest in ManifestNames)
            {
                string path = Path.Combine(addonDir, manifest);
                if (!File.Exists(path)) continue;
                try
                {
                    foreach (string line in File.ReadAllLines(path))
                    {
                        if (line.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                            return line.Substring(prefix.Length).Trim();
                    }
                }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
            return null;
        }

        private static CompanionReleaseVersion CurrentCompanionVersion()
        {
            var informational = (AssemblyInformationalVersionAttribute)Attribute.GetCustomAttribute(
                Assembly.GetExecutingAssembly(), typeof(AssemblyInformationalVersionAttribute));
            CompanionReleaseVersion version;
            return informational != null
                && CompanionReleaseVersion.TryParse(informational.InformationalVersion, out version)
                ? version : null;
        }

        internal static bool SupportsTopologySchema(string wowDir,int schema)
        {
            var install=Inspect(wowDir);
            if(!install.Installed)return false;
            if(schema==1)return true;
            string value=ReadMetadata(install.AddonDir,"X-Offhand-Topology-Schemas");
            foreach(string token in (value??"").Split(',')) {
                int supported;if(int.TryParse(token.Trim(),out supported)&&supported==schema)return true;
            }
            return false;
        }

        private static string FindVersionedOffhandFolder(string addOnsDir)
        {
            if (string.IsNullOrEmpty(addOnsDir) || !Directory.Exists(addOnsDir)) return null;
            try
            {
                foreach (string child in Directory.GetDirectories(addOnsDir))
                {
                    string name = Path.GetFileName(child);
                    if (name.StartsWith("Offhand", StringComparison.OrdinalIgnoreCase)
                        && !name.Equals("Offhand", StringComparison.OrdinalIgnoreCase)
                        && HasManifest(child)) return child;
                }
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
            return null;
        }

        private static string FindSiblingClientInstall(string wowDir)
        {
            DirectoryInfo current;
            try { current = new DirectoryInfo(wowDir); }
            catch { return null; }
            DirectoryInfo productRoot = current.Parent;
            if (productRoot == null || !productRoot.Exists) return null;
            try
            {
                foreach (DirectoryInfo sibling in productRoot.GetDirectories())
                {
                    if (sibling.FullName.Equals(current.FullName, StringComparison.OrdinalIgnoreCase)) continue;
                    string candidate = Path.Combine(sibling.FullName, "Interface", "AddOns", "Offhand");
                    if (HasManifest(candidate)) return candidate;
                }
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
            return null;
        }

        internal static AddonInstallCheck Inspect(string wowDir)
        {
            var result = new AddonInstallCheck {
                Installed = false,
                Reason = "The running WoW client's addon directory could not be determined.",
                SetupHint = "Install Offhand for the running WoW client."
            };
            string interfaceDir = ChildDirectory(wowDir, "Interface");
            string addOnsDir = ChildDirectory(interfaceDir, "AddOns");
            string addonDir = ChildDirectory(addOnsDir, "Offhand");
            result.AddonDir = addonDir;
            result.ExpectedAddonDir = string.IsNullOrEmpty(wowDir) ? null
                : Path.Combine(wowDir, "Interface", "AddOns", "Offhand");
            if (HasManifest(addonDir))
            {
                result.ReleaseTag = ReadMetadata(addonDir, "X-Offhand-Release");
                result.Version = ReadMetadata(addonDir, "Version");
                string protocolText = ReadMetadata(addonDir, "X-Offhand-Companion-Protocol");
                string legacyVersion = ReadMetadata(addonDir, "X-Offhand-Companion-Version");
                result.MinimumCompanionVersion = ReadMetadata(addonDir, "X-Offhand-Companion-Min-Version");
                int protocol;
                if (int.TryParse(protocolText, out protocol)) result.CompanionProtocol = protocol;
                else if (string.IsNullOrWhiteSpace(protocolText)
                    && string.Equals(legacyVersion, LegacyCompanionVersion, StringComparison.OrdinalIgnoreCase))
                    result.CompanionProtocol = SupportedCompanionProtocol;

                if (!result.CompanionProtocol.HasValue)
                {
                    result.SetupHint = "Update the Offhand addon for this client.";
                    result.Reason = "Offhand is installed at " + addonDir
                        + ", but it does not declare a supported Companion protocol.";
                    return result;
                }
                if (result.CompanionProtocol.Value != SupportedCompanionProtocol)
                {
                    result.SetupHint = "Use a Companion version compatible with this Offhand addon.";
                    result.Reason = "Offhand is installed at " + addonDir + " and uses Companion protocol "
                        + result.CompanionProtocol.Value + ", but this Companion supports protocol "
                        + SupportedCompanionProtocol + ".";
                    return result;
                }
                if (!string.IsNullOrWhiteSpace(result.MinimumCompanionVersion))
                {
                    CompanionReleaseVersion required;
                    CompanionReleaseVersion current = CurrentCompanionVersion();
                    if (!CompanionReleaseVersion.TryParse(result.MinimumCompanionVersion, out required))
                    {
                        result.SetupHint = "Reinstall Offhand for this client and check again.";
                        result.Reason = "Offhand is installed at " + addonDir
                            + ", but its minimum Companion version is malformed: "
                            + result.MinimumCompanionVersion + ".";
                        return result;
                    }
                    if (current == null || current.CompareTo(required) < 0)
                    {
                        result.SetupHint = "Update Companion to " + required.Display + " or newer.";
                        result.Reason = "Offhand " + (result.ReleaseTag ?? "addon")
                            + " requires Companion " + required.Display + " or newer.";
                        return result;
                    }
                }
                else if (!string.Equals(legacyVersion, LegacyCompanionVersion, StringComparison.OrdinalIgnoreCase))
                {
                    result.SetupHint = "Update the Offhand addon for this client.";
                    result.Reason = "Offhand is installed at " + addonDir
                        + ", but it does not declare a minimum or legacy-compatible Companion version.";
                    return result;
                }
                result.Installed = true;
                result.Reason = "Verified " + (result.ReleaseTag ?? "Offhand") + " at " + addonDir
                    + " (Companion protocol " + result.CompanionProtocol.Value + "). Confirm it is enabled in WoW.";
                return result;
            }

            string nested = ChildDirectory(addonDir, "Offhand");
            if (HasManifest(nested))
            {
                result.SetupHint = "Move the inner Offhand folder directly into Interface\\AddOns.";
                result.Reason = "Nested install found: move the inner Offhand folder directly into Interface\\AddOns.";
                return result;
            }
            if (!string.IsNullOrEmpty(addonDir))
            {
                result.SetupHint = "Reinstall Offhand. Its addon files belong directly inside the Offhand folder.";
                result.Reason = "Offhand folder found, but no supported Offhand TOC is at its top level: "
                    + addonDir;
                return result;
            }

            string versioned = FindVersionedOffhandFolder(addOnsDir);
            if (!string.IsNullOrEmpty(versioned))
            {
                result.SetupHint = "Install the addon in Interface\\AddOns\\Offhand.";
                result.Reason = "Offhand files were found in a differently named folder: " + versioned
                    + ". Install the addon as " + result.ExpectedAddonDir + ".";
                return result;
            }

            string sibling = FindSiblingClientInstall(wowDir);
            if (!string.IsNullOrEmpty(sibling))
            {
                result.Reason = "Offhand is installed for a different WoW client at " + sibling
                    + ". The running client expects: " + result.ExpectedAddonDir;
                return result;
            }

            result.Reason = "Offhand was not found for the running WoW client. Expected: "
                + result.ExpectedAddonDir;
            return result;
        }
    }

    internal static class CompanionTopologyBridge
    {
        private static string LuaString(string value)
        {
            return "\"" + (value ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
        }

        private static string RectLua(Rectangle rect, Rectangle union)
        {
            int left = rect.Left - union.Left;
            int bottom = union.Bottom - rect.Bottom;
            return string.Format("{{ x = {0}, y = {1}, width = {2}, height = {3} }}", left, bottom, rect.Width, rect.Height);
        }

        private static string CurrentVersion()
        {
            return (Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyInformationalVersionAttribute>()
                ?? new AssemblyInformationalVersionAttribute(CompanionForm.BaseVersion))
                .InformationalVersion;
        }

        private static string ProfileFields(MonitorSelection.Plan plan)
        {
            return "workspaceProfileID = "+(plan.MultiRegion&&plan.WorkspaceProfileID!=null?LuaString(plan.WorkspaceProfileID):"nil")
                +", workspaceProfileName = "+(plan.MultiRegion&&plan.WorkspaceProfileID!=null?LuaString(plan.WorkspaceProfileName):"nil");
        }

        private static string WorkspaceFields(MonitorSelection.Plan plan,IList<MonitorSelection.Display> displays)
        {
            string primary="workspace = "+RectLua(plan.WorkspaceBounds,plan.Bounds);
            if(!plan.MultiRegion)return primary;
            var result=new StringBuilder(primary+",\r\n  primaryWorkspace = "+LuaString(plan.PrimaryWorkspaceId)+",\r\n  workspaces = {\r\n");
            foreach(var r in plan.Workspaces) {
                string rectangle=RectLua(r.Bounds,plan.Bounds);
                result.Append("    { id = "+LuaString(r.Id)+", device = "+LuaString(displays[r.DisplayIndex].DeviceName)+", "+rectangle.Substring(2)+",\r\n");
            }
            result.Append("  }");return result.ToString();
        }

        private static string DisplayFields(MonitorSelection.Plan plan,IList<MonitorSelection.Display> displays)
        {
            if(!plan.FlexibleLayout)return "";
            var result=new StringBuilder("coordinateSpace = \"BOTTOM_LEFT_PHYSICAL\",\r\n  displays = {\r\n");
            foreach(int index in plan.Indices) {
                string rectangle=RectLua(displays[index].Bounds,plan.Bounds);
                result.Append("    { device = "+LuaString(displays[index].DeviceName)+", "+rectangle.Substring(2)+",\r\n");
            }
            result.Append("  },\r\n  ");return result.ToString();
        }

        internal static bool IsCurrent(string wowDir, MonitorSelection.Plan plan,
            IList<MonitorSelection.Display> displays)
        {
            if (string.IsNullOrEmpty(wowDir) || plan == null || displays == null) return false;
            string target = Path.Combine(wowDir, "Interface", "AddOns", "Offhand", "Core", "CompanionTopology.lua");
            string text;
            try { text = File.ReadAllText(target); }
            catch (IOException) { return false; }
            catch (UnauthorizedAccessException) { return false; }

            var selected = new StringBuilder();
            for (int i = 0; i < plan.Indices.Length; i++)
            {
                if (i > 0) selected.Append(", ");
                selected.Append(LuaString(displays[plan.Indices[i]].DeviceName));
            }
            string[] expected = {
                "companionVersion = " + LuaString(CurrentVersion()),
                "schema = "+plan.TopologySchema,
                "mode = " + LuaString(plan.MultiRegion ? "CUSTOM_REGIONS" : plan.SplitSingle ? "SPLIT_ULTRAWIDE" : "DUAL_DISPLAY"),
                "physicalWidth = " + plan.Bounds.Width + ", physicalHeight = " + plan.Bounds.Height,
                "mainhandDevice = " + LuaString(displays[plan.MainhandIndex].DeviceName),
                "selectedDevices = { " + selected + " }",
                "game = " + RectLua(plan.MainhandBounds, plan.Bounds),
                WorkspaceFields(plan,displays),
                DisplayFields(plan,displays),
                ProfileFields(plan),
            };
            foreach (string fragment in expected)
                if (text.IndexOf(fragment, StringComparison.Ordinal) < 0) return false;
            return true;
        }

        internal static bool TryWrite(string wowDir, MonitorSelection.Plan plan,
            IList<MonitorSelection.Display> displays, out string message)
        {
            byte[] written;
            return TryWrite(wowDir, plan, displays, out message, out written);
        }

        internal static bool TryWrite(string wowDir, MonitorSelection.Plan plan,
            IList<MonitorSelection.Display> displays, out string message, out byte[] written)
        {
            written = null;
            message = "Display topology was not written.";
            if (string.IsNullOrEmpty(wowDir) || plan == null) return false;
            if(plan.MultiRegion && !AddonInstallation.SupportsTopologySchema(wowDir,plan.TopologySchema)) {
                message=plan.FlexibleLayout
                    ? "The Offhand addon installed for this WoW client does not support Flexible Layout. " + WorkspaceEditorLayout.FlexibleAddon
                    : "The installed addon does not support this workspace topology schema. Update it before applying this plan.";
                return false;
            }
            string core = Path.Combine(wowDir, "Interface", "AddOns", "Offhand", "Core");
            if (!Directory.Exists(core)) return false;
            string target = Path.Combine(core, "CompanionTopology.lua");
            string temporary = target + ".tmp";
            var selected = new StringBuilder();
            for (int i = 0; i < plan.Indices.Length; i++)
            {
                if (i > 0) selected.Append(", ");
                selected.Append(LuaString(displays[plan.Indices[i]].DeviceName));
            }
            string text =
                "-- Generated by Offhand Companion. Do not edit while the Companion is running.\r\n" +
                "OffhandCompanionTopology = {\r\n" +
                "  schema = "+plan.TopologySchema+", generatedAt = " + LuaString(DateTime.UtcNow.ToString("o")) + ",\r\n" +
                "  companionVersion = " + LuaString(CurrentVersion()) + ",\r\n" +
                "  mode = " + LuaString(plan.MultiRegion ? "CUSTOM_REGIONS" : plan.SplitSingle ? "SPLIT_ULTRAWIDE" : "DUAL_DISPLAY") + ",\r\n" +
                "  physicalWidth = " + plan.Bounds.Width + ", physicalHeight = " + plan.Bounds.Height + ",\r\n" +
                "  mainhandDevice = " + LuaString(displays[plan.MainhandIndex].DeviceName) + ",\r\n" +
                "  selectedDevices = { " + selected + " },\r\n" +
                "  game = " + RectLua(plan.MainhandBounds, plan.Bounds) + ",\r\n" +
                "  " + WorkspaceFields(plan,displays) + ",\r\n" +
                "  " + DisplayFields(plan,displays) + ProfileFields(plan) + ",\r\n" +
                "}\r\n";
            try
            {
                byte[] bytes = new UTF8Encoding(false).GetBytes(text);
                File.WriteAllBytes(temporary, bytes);
                if (File.Exists(target)) File.Replace(temporary, target, null);
                else File.Move(temporary, target);
                written = bytes;
                message = string.Format("Display topology updated: game {0}x{1}, workspace {2}x{3}.",
                    plan.MainhandBounds.Width, plan.MainhandBounds.Height,
                    plan.WorkspaceBounds.Width, plan.WorkspaceBounds.Height);
                return true;
            }
            catch (Exception ex)
            {
                try { if (File.Exists(temporary)) File.Delete(temporary); } catch { }
                message = "Display topology update failed: " + ex.Message;
                return false;
            }
        }
    }

    internal sealed class TopologySnapshot
    {
        private readonly string path;
        private readonly byte[] original;
        private byte[] written;

        internal TopologySnapshot(string path)
        {
            this.path = path;
            try { original = File.ReadAllBytes(path); }
            catch (FileNotFoundException) { }
        }

        internal void RecordWrite(byte[] bytes) { written = bytes; }

        internal void Restore()
        {
            if (written == null) return;
            // An addon manager or another writer can supersede this snapshot.
            if (!File.Exists(path) || !SpanRollback.SameBytes(File.ReadAllBytes(path), written))
                throw new IOException("Topology changed externally. Previous bytes were not restored.");
            if (original == null) { File.Delete(path); return; }
            string temporary = path + ".rollback-" + Guid.NewGuid().ToString("N");
            try
            {
                File.WriteAllBytes(temporary, original);
                File.Replace(temporary, path, null);
            }
            finally { try { if (File.Exists(temporary)) File.Delete(temporary); } catch (IOException) { } }
        }
    }

    // One synchronous span operation owns this snapshot. Rollback failures are
    // reported separately so the original operation failure remains visible.
    internal sealed class SpanRollback : IDisposable
    {
        internal readonly TopologySnapshot Topology;
        private readonly IntPtr handle;
        private readonly uint processId;
        private readonly int style;
        private readonly NativeMethods.RECT bounds;
        private NativeMethods.WINDOWPLACEMENT placement;
        private IntPtr region;
        internal bool WindowChanged;
        private bool completed;

        internal SpanRollback(string path, IntPtr handle)
        {
            this.handle = handle;
            if (path != null) Topology = new TopologySnapshot(path);
            NativeMethods.GetWindowThreadProcessId(handle, out processId);
            placement.length = Marshal.SizeOf(typeof(NativeMethods.WINDOWPLACEMENT));
            if (processId == 0 || !NativeMethods.GetWindowRect(handle, out bounds)
                || !NativeMethods.GetWindowPlacement(handle, ref placement))
                throw new IOException("Could not capture the previous window for rollback.");
            if (!NativeMethods.IsWindowVisible(handle)) placement.showCmd = 0;
            style = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE);
            region = NativeMethods.CreateRectRgn(0, 0, 0, 0);
            if (region == IntPtr.Zero) throw new IOException("Could not capture the pre-span clipping region.");
            NativeMethods.SetLastError(0);
            if (NativeMethods.GetWindowRgn(handle, region) == 0)
            {
                // ERROR also denotes an ordinary window with no explicit region.
                int error = Marshal.GetLastWin32Error();
                NativeMethods.DeleteObject(region); region = IntPtr.Zero;
                if (error != 0) throw new IOException("Could not read the pre-span clipping region (Windows error " + error + ").");
            }
        }

        internal void TopologyWritten(byte[] bytes)
        {
            if (Topology == null) throw new InvalidOperationException("This snapshot owns only native window state.");
            Topology.RecordWrite(bytes);
        }
        internal void Commit() { completed = true; }

        internal static bool SameBytes(byte[] left, byte[] right)
        {
            if (left == null || right == null || left.Length != right.Length) return false;
            for (int i = 0; i < left.Length; i++) if (left[i] != right[i]) return false;
            return true;
        }

        internal string Rollback()
        {
            if (completed) return null;
            completed = true;
            var failures = new List<string>();
            if (WindowChanged)
            {
                try
                {
                    uint currentPid;
                    NativeMethods.GetWindowThreadProcessId(handle, out currentPid);
                    if (currentPid != processId) throw new IOException("Window ownership changed; native rollback skipped.");
                    NativeMethods.SetLastError(0);
                    int previous = NativeMethods.SetWindowLong(handle, NativeMethods.GWL_STYLE, style);
                    if (previous == 0 && Marshal.GetLastWin32Error() != 0) failures.Add("window style");
                    if (!NativeMethods.SetWindowPos(handle, IntPtr.Zero, bounds.Left, bounds.Top, bounds.Width, bounds.Height,
                        NativeMethods.SWP_NOZORDER | NativeMethods.SWP_NOACTIVATE | NativeMethods.SWP_FRAMECHANGED)) failures.Add("window bounds");
                    if (!NativeMethods.SetWindowPlacement(handle, ref placement)) failures.Add("window placement");
                    if (NativeMethods.SetWindowRgn(handle, region, true) == 0) failures.Add("window clipping");
                    else region = IntPtr.Zero; // Ownership transferred to Windows.
                }
                catch (Exception ex) { failures.Add(ex.Message); }
            }
            if (Topology != null)
            {
                try { Topology.Restore(); }
                catch (Exception ex) { failures.Add("topology: " + ex.Message); }
            }
            return failures.Count == 0 ? null : "Span rollback incomplete: " + string.Join("; ", failures.ToArray());
        }

        public void Dispose()
        {
            if (region != IntPtr.Zero) { NativeMethods.DeleteObject(region); region = IntPtr.Zero; }
        }
    }

    internal static class WindowRestore
    {
        internal static void Apply(IntPtr handle, Rectangle target, int style)
        { Apply(handle, target, style, null); }

        // The callback is used only by failure-injection tests of this exact path.
        internal static void Apply(IntPtr handle, Rectangle target, int style, Action<string> afterStage)
        {
            // Restore always requests normal placement, including when no
            // remembered pre-span style exists for an adopted/minimized window.
            style &= ~(NativeMethods.WS_MINIMIZE | NativeMethods.WS_MAXIMIZE);
            using (var rollback = new SpanRollback(null, handle))
            {
                try
                {
                    bool visible = NativeMethods.IsWindowVisible(handle);
                    rollback.WindowChanged = true;
                    if (NativeMethods.IsZoomed(handle) || NativeMethods.IsIconic(handle))
                        NativeMethods.ShowWindow(handle, NativeMethods.SW_RESTORE);
                    NativeMethods.SetLastError(0);
                    int previous = NativeMethods.SetWindowLong(handle, NativeMethods.GWL_STYLE, style);
                    int error = Marshal.GetLastWin32Error();
                    if (previous == 0 && error != 0)
                        throw new IOException(WindowInteropDiagnostics.StyleFailure(
                            "Windows rejected restoring the WoW window borders", error));
                    if (afterStage != null) afterStage("style");
                    if (NativeMethods.SetWindowRgn(handle, IntPtr.Zero, true) == 0)
                        throw new IOException("Windows rejected clearing the window clipping region.");
                    if (afterStage != null) afterStage("clipping");
                    uint flags = NativeMethods.SWP_NOZORDER | NativeMethods.SWP_NOACTIVATE | NativeMethods.SWP_FRAMECHANGED;
                    if (visible) flags |= NativeMethods.SWP_SHOWWINDOW;
                    if (!NativeMethods.SetWindowPos(handle, IntPtr.Zero, target.X, target.Y, target.Width, target.Height, flags))
                        throw new IOException("Windows rejected restoring the window bounds.");
                    if (afterStage != null) afterStage("bounds");
                    NativeMethods.RECT actual;
                    int borderMask = NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME;
                    if (!NativeMethods.GetWindowRect(handle, out actual)
                        || actual.Left != target.X || actual.Top != target.Y
                        || actual.Width != target.Width || actual.Height != target.Height
                        || (NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE) & borderMask) != (style & borderMask))
                        throw new IOException("WoW did not accept the restore. Select Windowed mode and retry.");
                    if (afterStage != null) afterStage("verification");
                    rollback.Commit();
                }
                catch (Exception ex)
                {
                    string failure = rollback.Rollback();
                    if (failure != null) throw new IOException(ex.Message + Environment.NewLine + failure, ex);
                    throw;
                }
            }
        }
    }

    internal static class CustomRegionPreferences
    {
        internal static Dictionary<string,string> StandardLayout(IDictionary<string,string> current,
            IList<MonitorSelection.Display> displays, out int[] selected)
        {
            if (displays.Count == 0) throw new InvalidOperationException("Connect a display before choosing a standard layout.");
            string identity, device, saved;
            current.TryGetValue("MainhandIdentity", out identity);
            current.TryGetValue("MainhandDevice", out device);
            MonitorSelection.Plan activePlan = null;
            try { activePlan = MonitorSelection.CreatePlan(current, displays); }
            catch (InvalidOperationException) { }
            int game = activePlan == null ? MonitorSelection.FindDisplay(displays, identity, device) : activePlan.MainhandIndex;
            if (game < 0)
            {
                game = 0;
                for (int i = 0; i < displays.Count; i++)
                    if (displays[i].Primary) { game = i; break; }
            }

            int workspace = activePlan == null ? -1 : activePlan.WorkspaceIndex;
            if (workspace == game) workspace = -1;
            if (workspace < 0 && current.TryGetValue("MonitorIdentities", out saved))
            {
                foreach (string monitor in (saved ?? "").Split('|'))
                {
                    int index = MonitorSelection.FindDisplay(displays, monitor, null);
                    if (index >= 0 && index != game) { workspace = index; break; }
                }
            }
            if (workspace < 0 && displays.Count > 1)
                workspace = game == 0 ? 1 : 0;
            selected = workspace < 0 ? new[] { game } : new[] { game, workspace };

            var next = new Dictionary<string,string>(current);
            foreach (string key in new[] { WorkspaceLayoutSettings.EnabledKey, "WorkspaceRegionsEnabled",
                "SecondaryAreaEnabled", "PartialSpanEnabled", "SingleDisplaySplit", "AutoSpan" })
                next[key] = "False";
            foreach (string key in new[] { "WorkspaceProfileID", "WorkspaceProfileName",
                "DisplayIdentityVersion", "MonitorIdentities", "MainhandIdentity" })
                next.Remove(key);

            var devices = new List<string>();
            var indices = new List<string>();
            var identities = new List<string>();
            foreach (int index in selected)
            {
                devices.Add(displays[index].DeviceName);
                indices.Add(index.ToString());
                identities.Add(displays[index].StableId);
            }
            next["MonitorDevices"] = string.Join("|", devices);
            next["Monitors"] = string.Join(",", indices);
            next["MainhandDevice"] = displays[game].DeviceName;
            try
            {
                MonitorSelection.ValidatePhysicalIdentities(displays, selected);
                next["MonitorIdentities"] = string.Join("|", identities);
                next["MainhandIdentity"] = displays[game].StableId;
                next["DisplayIdentityVersion"] = "2";
            }
            catch (InvalidOperationException) { /* The standard selectors can still be reviewed. */ }
            return next;
        }

        // Editors hold a snapshot while open. Re-enumerate at publication so a
        // stale custom plan cannot replace the last saved preferences.
        internal static List<MonitorSelection.Display> Write(string path,
            IDictionary<string,string> settings, Func<List<MonitorSelection.Display>> readDisplays,
            IList<MonitorSelection.Display> confirmedDisplays = null)
        {
            List<MonitorSelection.Display> current = null;
            PreferenceFile.Write(path, settings, temporary => {
                current = readDisplays();
                if (confirmedDisplays != null && !MonitorSelection.SameDisplays(confirmedDisplays, current))
                    throw new InvalidOperationException("The connected displays changed. Open Advanced > Workspace layout and review the standard layout again.");
                string value;
                bool custom = (settings.TryGetValue("PartialSpanEnabled", out value)
                        && string.Equals(value, "True", StringComparison.OrdinalIgnoreCase))
                    || (settings.TryGetValue("SecondaryAreaEnabled", out value)
                        && string.Equals(value, "True", StringComparison.OrdinalIgnoreCase))
                    || MonitorSelection.MultiEnabled(settings) || WorkspaceLayoutSettings.Enabled(settings);
                // Disabling custom mode remains available with a display missing.
                if (custom) MonitorSelection.CreatePlan(settings, current);
            });
            return current;
        }
    }

    internal static class CompanionSettingsPath
    {
        internal static string Resolve(string localData, string packageFamily)
        {
            if (string.IsNullOrEmpty(packageFamily)) return Path.Combine(localData, "Offhand", "OffhandConfig.ini");
            if (packageFamily.IndexOfAny(new[] { '\\', '/', ':', '\r', '\n' }) >= 0 || packageFamily == "." || packageFamily == "..")
                throw new InvalidDataException("Invalid Microsoft Store package family.");
            // Use one physical package-data directory, not merged/redirected
            // AppData paths whose source and destination may resolve differently.
            return Path.Combine(localData, "Packages", packageFamily, "LocalState", "OffhandConfig.ini");
        }

        internal static string ReadSource(string current, string legacy, string portable)
        {
            if (File.Exists(current)) return current;
            // Read legacy through the package context so Windows can find its
            // existing redirected copy. Import only on the next explicit save.
            return File.Exists(legacy) ? legacy : portable;
        }
    }

    internal static class PreferenceFile
    {
        [DllImport("kernel32.dll", EntryPoint = "MoveFileExW", CharSet = CharSet.Unicode,
            ExactSpelling = true, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool MoveFileEx(string source, string destination, uint flags);

        internal static void ReplaceExisting(string temporary, string target, Action<string,string> replace = null)
        {
            try
            {
                if (replace != null) replace(temporary, target);
                else File.Replace(temporary, target, null);
            }
            catch (IOException ex)
            {
                // Only ERROR_INVALID_PARAMETER has this compatibility path.
                // Sharing/permission errors still fail without touching target.
                if (ex.HResult != unchecked((int)0x80070057)) throw;
                if (!string.Equals(Path.GetDirectoryName(Path.GetFullPath(temporary)),
                    Path.GetDirectoryName(Path.GetFullPath(target)), StringComparison.OrdinalIgnoreCase)) throw;
                // Immediate same-directory rename, no copy/delete or live-file
                // truncation fallback, and no cross-volume/reboot options.
                if (!MoveFileEx(temporary, target, 0x1 | 0x8))
                {
                    int error = Marshal.GetLastWin32Error();
                    throw new IOException("Cannot replace saved settings: " +
                        new System.ComponentModel.Win32Exception(error).Message,
                        unchecked((int)(0x80070000U | (uint)error)));
                }
            }
        }

        internal static void Write(string path, IDictionary<string, string> settings)
        { Write(path, settings, null); }

        internal static void Write(string path, IDictionary<string, string> settings, Action<string> beforePublish)
        {
            var keys = new List<string>(settings.Keys);
            keys.Sort(StringComparer.Ordinal);
            var lines = new List<string>();
            foreach (string key in keys)
            {
                string value = settings[key] ?? string.Empty;
                if (string.IsNullOrWhiteSpace(key) || key != key.Trim()
                    || key.IndexOfAny(new char[] { '=', '\r', '\n' }) >= 0
                    || value.IndexOfAny(new char[] { '\r', '\n' }) >= 0)
                    throw new InvalidDataException("Settings contain an invalid key or multiline value.");
                lines.Add(key + "=" + value);
            }
            string target = Path.GetFullPath(path);
            string temporary = target + ".pending-" + Guid.NewGuid().ToString("N");
            string operation = "creating the settings directory";
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                operation = "writing the new settings file";
                byte[] bytes = new UTF8Encoding(false).GetBytes(string.Join(Environment.NewLine, lines.ToArray()) + Environment.NewLine);
                using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                {
                    stream.Write(bytes, 0, bytes.Length);
                    operation = "flushing the new settings file";
                    stream.Flush(true);
                }
                operation = "validating the new settings";
                if (beforePublish != null) beforePublish(temporary);
                // Never fall back to truncating a live settings file if atomic
                // replacement is unavailable or rejected by the filesystem.
                operation = "replacing saved settings";
                if (File.Exists(target)) ReplaceExisting(temporary, target);
                else File.Move(temporary, target);
            }
            catch (IOException ex)
            {
                throw new IOException("Settings were not saved while " + operation + " (0x" +
                    ex.HResult.ToString("X8") + "): " + ex.Message, ex);
            }
            finally
            {
                // Cleanup must not hide the operation that actually failed.
                try { if (File.Exists(temporary)) File.Delete(temporary); }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
        }

        internal static Dictionary<string, string> Read(string path)
        {
            var settings = new Dictionary<string, string>();
            if (!File.Exists(path)) return settings;
            foreach (var line in File.ReadAllLines(path))
            {
                var parts = line.Split(new char[] { '=' }, 2);
                if (parts.Length == 2 && parts[0].Trim().Length > 0)
                    settings[parts[0].Trim()] = parts[1].Trim();
            }
            return settings;
        }

        internal static decimal Delay(string value)
        {
            decimal delay;
            return decimal.TryParse(value, out delay) ? Math.Max(0, Math.Min(60, delay)) : 15;
        }
    }

    internal static class CompanionTiming
    {
        internal static double AutoSpanDelay(string processName, string wowDir, decimal configuredDelay)
        {
            // Respect the user's configured delay on every supported client.
            // Forever users who need pre-login geometry can explicitly select 0.
            return (double)configuredDelay;
        }
    }

    internal static class CompanionDefaults
    {
        // Automatic window movement is opt-in so a first launch cannot unexpectedly
        // rearrange a player's WoW window before the selected displays are reviewed.
        internal const bool AutoSpanOnLaunch = false;
    }

    internal static class AutoSpanAttemptPolicy
    {
        internal static bool ShouldAttempt(bool monitoring, bool enabled, bool addonInstalled,
            bool displayPlanReady, bool alreadySpanned, bool explicitlyRestored, bool previousFailure)
        {
            return monitoring && enabled && addonInstalled && displayPlanReady
                && !alreadySpanned && !explicitlyRestored && !previousFailure;
        }
    }

    internal static class ProcessPathResolver
    {
        internal static string Get(Process process)
        {
            string diagnostic;
            return Get(process, out diagnostic);
        }

        internal static string Get(Process process, out string diagnostic)
        {
            diagnostic = null;
            if (process == null) return null;
            Exception preferredFailure = null;
            try { return process.MainModule.FileName; }
            catch (Exception ex)
            {
                // Wine Mono can expose another process with an empty module
                // collection, causing Process.MainModule to throw an
                // ArgumentOutOfRangeException. MainModule is only the preferred
                // probe; every failure must reach the limited-access fallback.
                preferredFailure = ex;
            }

            string preferredDiagnostic = "Process.MainModule failed ("
                + preferredFailure.GetType().Name + ": " + preferredFailure.Message + "). ";
            IntPtr handle = IntPtr.Zero;
            try
            {
                handle = NativeMethods.OpenProcess(
                    NativeMethods.PROCESS_QUERY_LIMITED_INFORMATION, false, process.Id);
                if (handle == IntPtr.Zero)
                {
                    diagnostic = preferredDiagnostic + "OpenProcess failed with Windows error "
                        + Marshal.GetLastWin32Error() + ".";
                    return null;
                }
                int size = 32768;
                var path = new StringBuilder(size);
                if (NativeMethods.QueryFullProcessImageName(handle, 0, path, ref size))
                    return path.ToString();
                diagnostic = preferredDiagnostic + "QueryFullProcessImageName failed with Windows error "
                    + Marshal.GetLastWin32Error() + ".";
                return null;
            }
            catch (Exception ex)
            {
                diagnostic = preferredDiagnostic + ex.GetType().Name + ": " + ex.Message;
                return null;
            }
            finally
            {
                if (handle != IntPtr.Zero)
                {
                    try { NativeMethods.CloseHandle(handle); }
                    catch { }
                }
            }
        }
    }

    internal static class ForeverStateBridge
    {
        private const int MaxSavedVariablesBytes = 16 * 1024 * 1024;

        private static string ReadValidated(string path, string variable)
        {
            if (!File.Exists(path)) return null;
            var info = new FileInfo(path);
            if (info.Length <= 0 || info.Length > MaxSavedVariablesBytes) return null;
            string text = File.ReadAllText(path);
            if (text.IndexOf('\0') >= 0) return null;
            text = text.TrimStart('\uFEFF', '\r', '\n', ' ', '\t');
            if (!text.StartsWith(variable + " =", StringComparison.Ordinal)) return null;
            return text.TrimEnd() + Environment.NewLine;
        }

        private static string NewestValid(IEnumerable<string> paths, string variable)
        {
            string newest = null;
            DateTime newestWrite = DateTime.MinValue;
            foreach (string path in paths)
            {
                string valid;
                try { valid = ReadValidated(path, variable); }
                catch (IOException) { continue; }
                catch (UnauthorizedAccessException) { continue; }
                if (valid == null) continue;
                DateTime write = File.GetLastWriteTimeUtc(path);
                if (newest == null || write > newestWrite)
                {
                    newest = path;
                    newestWrite = write;
                }
            }
            return newest;
        }

        private static string Hash(string value)
        {
            using (var sha = SHA256.Create())
            {
                byte[] digest = sha.ComputeHash(Encoding.UTF8.GetBytes(value));
                var result = new StringBuilder(digest.Length * 2);
                foreach (byte b in digest) result.Append(b.ToString("x2"));
                return result.ToString();
            }
        }

        internal static bool TryRefresh(string wowDir, out string message)
        {
            message = "Forever recovery bridge was not updated.";
            if (string.IsNullOrEmpty(wowDir) || !Directory.Exists(wowDir))
            {
                message = "Forever recovery skipped: WoW directory unavailable.";
                return false;
            }

            string accountRoot = Path.Combine(wowDir, "WTF", "Account");
            string addonCore = Path.Combine(wowDir, "Interface", "AddOns", "Offhand", "Core");
            if (!Directory.Exists(accountRoot) || !Directory.Exists(addonCore))
            {
                message = "Forever recovery skipped: Offhand or WTF directory unavailable.";
                return false;
            }

            string[] all;
            try { all = Directory.GetFiles(accountRoot, "Offhand.lua", SearchOption.AllDirectories); }
            catch (IOException ex) { message = "Forever recovery cannot scan SavedVariables: " + ex.Message; return false; }
            catch (UnauthorizedAccessException ex) { message = "Forever recovery cannot scan SavedVariables: " + ex.Message; return false; }

            var accountFiles = new List<string>();
            foreach (string path in all)
            {
                var savedVariables = Directory.GetParent(path);
                var account = savedVariables == null ? null : savedVariables.Parent;
                if (savedVariables != null && account != null &&
                    savedVariables.Name.Equals("SavedVariables", StringComparison.OrdinalIgnoreCase) &&
                    account.Parent != null && account.Parent.FullName.Equals(accountRoot, StringComparison.OrdinalIgnoreCase))
                    accountFiles.Add(path);
            }

            string accountPath = NewestValid(accountFiles, "OffhandDB");
            if (accountPath == null)
            {
                message = "Forever recovery skipped: no valid account Offhand.lua found.";
                return false;
            }

            DirectoryInfo accountDirectory = Directory.GetParent(accountPath).Parent;
            var characterFiles = new List<string>();
            foreach (string path in all)
            {
                if (!path.StartsWith(accountDirectory.FullName + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)) continue;
                if (path.Equals(accountPath, StringComparison.OrdinalIgnoreCase)) continue;
                characterFiles.Add(path);
            }
            string characterPath = NewestValid(characterFiles, "OffhandCharDB");
            if (characterPath == null)
            {
                message = "Forever recovery skipped: no valid character Offhand.lua found for the newest account.";
                return false;
            }

            string accountText = ReadValidated(accountPath, "OffhandDB");
            string characterText = ReadValidated(characterPath, "OffhandCharDB");
            if (accountText == null || characterText == null)
            {
                message = "Forever recovery skipped: SavedVariables changed while being read.";
                return false;
            }

            string version = Hash(accountText + "\n" + characterText);
            string generated =
                "-- Generated by Offhand Companion from Forever SavedVariables while WoW was closed.\r\n" +
                "local interfaceVersion = select(4, GetBuildInfo())\r\n" +
                "if interfaceVersion >= 16000 and interfaceVersion < 17000 then\r\n" +
                "OffhandForeverStateBridgeVersion = \"" + version + "\"\r\n" +
                "local recoveryCVar = \"offhandForeverRecoveryVersion\"\r\n" +
                "local register = RegisterCVar or (C_CVar and C_CVar.RegisterCVar)\r\n" +
                "local getter = GetCVar or (C_CVar and C_CVar.GetCVar)\r\n" +
                "if register then pcall(register, recoveryCVar, \"\") end\r\n" +
                "local consumed = getter and tostring(getter(recoveryCVar) or \"\") == OffhandForeverStateBridgeVersion\r\n" +
                "if not consumed then\r\n" +
                accountText + characterText + "end\r\nend\r\n";
            string target = Path.Combine(addonCore, "ForeverState.lua");
            try
            {
                if (File.Exists(target) && File.ReadAllText(target) == generated)
                {
                    message = "Forever recovery snapshot is current.";
                    return true;
                }
                string temporary = target + ".tmp." + Process.GetCurrentProcess().Id;
                File.WriteAllText(temporary, generated, new UTF8Encoding(false));
                try
                {
                    if (File.Exists(target))
                        File.Replace(temporary, target, target + ".bak", true);
                    else
                        File.Move(temporary, target);
                }
                finally
                {
                    if (File.Exists(temporary)) File.Delete(temporary);
                }
                message = "Forever recovery snapshot updated from " +
                    accountDirectory.Name + " / " + Directory.GetParent(Directory.GetParent(characterPath).FullName).Name + ".";
                return true;
            }
            catch (IOException ex) { message = "Forever recovery cannot update addon state: " + ex.Message; return false; }
            catch (UnauthorizedAccessException ex) { message = "Forever recovery cannot update addon state: " + ex.Message; return false; }
        }
    }

    // Tell the Shell about the real WoW HWND rather than changing global
    // taskbar preferences, hiding Explorer windows, or making WoW topmost.
    // The Shell owns focus-dependent taskbar ordering and removes the marking
    // when the HWND is destroyed. It can outlive the Companion, like the span.
    internal static class TaskbarPresentation
    {
        [ComImport, Guid("602D4995-B13A-429B-A66E-1935E44F4317"),
            InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface ITaskbarList2
        {
            [PreserveSig] int HrInit();
            [PreserveSig] int AddTab(IntPtr window);
            [PreserveSig] int DeleteTab(IntPtr window);
            [PreserveSig] int ActivateTab(IntPtr window);
            [PreserveSig] int SetActiveAlt(IntPtr window);
            [PreserveSig] int MarkFullscreenWindow(IntPtr window, [MarshalAs(UnmanagedType.Bool)] bool fullscreen);
        }

        internal static bool TrySetFullscreen(IntPtr window, bool fullscreen, out string failure)
        {
            failure = null;
            uint owner;
            if (window == IntPtr.Zero || NativeMethods.GetWindowThreadProcessId(window, out owner) == 0)
            {
                failure = "The target window is no longer available.";
                return false;
            }
            object instance = null;
            try
            {
                instance = Activator.CreateInstance(Type.GetTypeFromCLSID(
                    new Guid("56FDF344-FD6D-11D0-958A-006097C9A090"), true));
                var taskbar = (ITaskbarList2)instance;
                Marshal.ThrowExceptionForHR(taskbar.HrInit());
                Marshal.ThrowExceptionForHR(taskbar.MarkFullscreenWindow(window, fullscreen));
                return true;
            }
            catch (Exception ex)
            {
                // Unsupported shells (including some Wine environments) must
                // retain the existing span/Restore behavior without a modal.
                failure = ex.Message;
                return false;
            }
            finally
            {
                if (instance != null && Marshal.IsComObject(instance))
                    try { Marshal.FinalReleaseComObject(instance); } catch { }
            }
        }
    }

    public static class NativeMethods
    {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
            public int Width { get { return Right - Left; } }
            public int Height { get { return Bottom - Top; } }
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct WINDOWPLACEMENT
        {
            public int length, flags, showCmd;
            public Point ptMinPosition, ptMaxPosition;
            public RECT rcNormalPosition;
        }

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool GetWindowPlacement(IntPtr hWnd, ref WINDOWPLACEMENT placement);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetWindowPlacement(IntPtr hWnd, ref WINDOWPLACEMENT placement);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct DISPLAY_DEVICE
        {
            public int cb;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
            public int StateFlags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
        }

        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool IsZoomed(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool IsIconic(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

        [DllImport("kernel32.dll")]
        public static extern void SetLastError(uint dwErrCode);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool QueryFullProcessImageName(IntPtr hProcess, int dwFlags,
            StringBuilder lpExeName, ref int lpdwSize);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CloseHandle(IntPtr hObject);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

        [DllImport("user32.dll")]
        public static extern int SetWindowRgn(IntPtr hWnd, IntPtr hRgn, bool bRedraw);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern int GetWindowRgn(IntPtr hWnd, IntPtr hRgn);

        [DllImport("user32.dll")]
        public static extern bool GetClientRect(IntPtr hWnd, out RECT rect);

        [DllImport("user32.dll")]
        public static extern bool IsHungAppWindow(IntPtr hWnd);

        [DllImport("gdi32.dll")]
        public static extern int GetRgnBox(IntPtr region, out RECT rect);

        [DllImport("gdi32.dll")]
        public static extern IntPtr CreateRectRgn(int nLeftRect, int nTopRect, int nRightRect, int nBottomRect);

        [DllImport("gdi32.dll")]
        public static extern int CombineRgn(IntPtr hrgnDest, IntPtr hrgnSrc1, IntPtr hrgnSrc2, int fnCombineMode);

        [DllImport("gdi32.dll")]
        public static extern bool DeleteObject(IntPtr hObject);

        [DllImport("user32.dll")]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        [DllImport("user32.dll")]
        public static extern int GetSystemMetrics(int nIndex);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum,
            ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr dpiContext);

        public const int GWL_STYLE = -16;
        public const int WS_CAPTION = 0x00C00000;
        public const int WS_THICKFRAME = 0x00040000;
        public const int WS_MINIMIZE = 0x20000000;
        public const int WS_MAXIMIZE = 0x01000000;
        public const uint SWP_NOZORDER = 0x0004;
        public const uint SWP_NOACTIVATE = 0x0010;
        public const uint SWP_FRAMECHANGED = 0x0020;
        public const uint SWP_SHOWWINDOW = 0x0040;
        public const int SW_RESTORE = 9;
        public const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;

        public static IntPtr FindProcessWindow(int processId)
        {
            IntPtr found = IntPtr.Zero;
            EnumWindows(delegate (IntPtr h, IntPtr p)
            {
                uint id;
                GetWindowThreadProcessId(h, out id);
                if (id == processId && IsWindowVisible(h))
                {
                    found = h;
                    return false;
                }
                return true;
            }, IntPtr.Zero);
            return found;
        }
    }

    public class AddonStatus
    {
        public bool Installed;
        public string WowDir;
        public string Reason;
        internal string ReleaseTag;
        internal string Version;
        internal string SetupHint;
    }

    internal static class RemoteDesktop
    {
        internal enum State { Local, Unavailable, Active }

        internal const int SessionChange = 0x02B1;
        private const int CurrentSession = -1;
        private const int ConnectionState = 8;
        private const int ClientProtocolType = 16;
        private const short RdpProtocol = 2;
        private const int ActiveConnection = 0;

        [DllImport("wtsapi32.dll", ExactSpelling = true)]
        private static extern bool WTSQuerySessionInformationW(IntPtr server, int session, int infoClass,
            out IntPtr buffer, out uint bytes);

        [DllImport("wtsapi32.dll", ExactSpelling = true)]
        private static extern void WTSFreeMemory(IntPtr buffer);

        [DllImport("wtsapi32.dll", ExactSpelling = true)]
        private static extern bool WTSRegisterSessionNotification(IntPtr window, uint flags);

        [DllImport("wtsapi32.dll", ExactSpelling = true)]
        private static extern bool WTSUnRegisterSessionNotification(IntPtr window);

        private static int? ReadSessionValue(int infoClass, bool wide)
        {
            IntPtr buffer = IntPtr.Zero;
            try
            {
                uint bytes;
                if (!WTSQuerySessionInformationW(IntPtr.Zero, CurrentSession, infoClass, out buffer, out bytes)
                    || buffer == IntPtr.Zero || bytes < (wide ? 4 : 2)) return null;
                return wide ? Marshal.ReadInt32(buffer) : Marshal.ReadInt16(buffer);
            }
            catch (DllNotFoundException) { return null; }
            catch (EntryPointNotFoundException) { return null; }
            finally { if (buffer != IntPtr.Zero) WTSFreeMemory(buffer); }
        }

        internal static State Read()
        {
            int? protocol = ReadSessionValue(ClientProtocolType, false);
            if (protocol == RdpProtocol)
                return ReadSessionValue(ConnectionState, true) == ActiveConnection ? State.Active : State.Unavailable;
            return (protocol.HasValue && protocol != 0) || SystemInformation.TerminalServerSession
                ? State.Unavailable : State.Local;
        }

        internal static bool Register(IntPtr window)
        {
            try { return WTSRegisterSessionNotification(window, 0); } // NOTIFY_FOR_THIS_SESSION
            catch (DllNotFoundException) { return false; }
            catch (EntryPointNotFoundException) { return false; }
        }

        internal static void Unregister(IntPtr window) { WTSUnRegisterSessionNotification(window); }

        internal static bool ConnectionChanged(int reason)
        {
            // Console/remote connect and disconnect, or session logoff.
            return (reason >= 1 && reason <= 4) || reason == 6;
        }

        internal static bool SameConnection(State state, bool registered, int confirmedGeneration, int currentGeneration,
            IList<MonitorSelection.Display> confirmed, IList<MonitorSelection.Display> current)
        {
            return state == State.Active && registered && confirmedGeneration == currentGeneration
                && MonitorSelection.SameDisplays(confirmed, current);
        }

        internal static MonitorSelection.Plan CreatePlan(IList<MonitorSelection.Display> displays, int mainhand, int workspace)
        {
            if (mainhand < 0 || workspace < 0 || mainhand == workspace
                || mainhand >= displays.Count || workspace >= displays.Count)
                throw new InvalidOperationException("Choose two different Remote Desktop displays.");
            string game = displays[mainhand].DeviceName;
            string other = displays[workspace].DeviceName;
            if (string.IsNullOrWhiteSpace(game) || string.IsNullOrWhiteSpace(other)
                || MonitorSelection.FindDisplay(displays, null, game) != mainhand
                || MonitorSelection.FindDisplay(displays, null, other) != workspace)
                throw new InvalidOperationException("Windows could not distinguish the selected Remote Desktop displays.");
            Rectangle gameBounds = displays[mainhand].Bounds;
            Rectangle workspaceBounds = displays[workspace].Bounds;
            if (gameBounds.Width <= 0 || gameBounds.Height <= 0 || workspaceBounds.Width <= 0
                || workspaceBounds.Height <= 0 || gameBounds.IntersectsWith(workspaceBounds))
                throw new InvalidOperationException("Choose two extended Remote Desktop displays with separate screen areas.");
            return MonitorSelection.CreatePlan(null, game + "|" + other, null, null, game, false, false, displays);
        }
    }

    // The dashboard handle can be recreated when it moves into or out of the
    // tray. Keep listening on a separate hidden window across those changes.
    internal sealed class RemoteDesktopWatcher : NativeWindow, IDisposable
    {
        private const int DisplayChange = 0x007E;
        private readonly Action changed;
        internal readonly bool Registered;

        internal RemoteDesktopWatcher(Action changed)
        {
            this.changed = changed;
            CreateHandle(new CreateParams());
            Registered = RemoteDesktop.Register(Handle);
        }

        protected override void WndProc(ref Message message)
        {
            if (message.Msg == DisplayChange || (message.Msg == RemoteDesktop.SessionChange
                && RemoteDesktop.ConnectionChanged(message.WParam.ToInt32())))
                changed();
            base.WndProc(ref message);
        }

        public void Dispose()
        {
            if (Handle == IntPtr.Zero) return;
            if (Registered) RemoteDesktop.Unregister(Handle);
            DestroyHandle();
        }
    }

    internal sealed class RemoteDisplayDialog : Form
    {
        private readonly ComboBox mainhand = new ComboBox();
        private readonly ComboBox workspace = new ComboBox();

        internal int Mainhand { get { return mainhand.SelectedIndex; } }
        internal int Workspace { get { return workspace.SelectedIndex; } }

        internal RemoteDisplayDialog(IList<MonitorSelection.Display> displays)
        {
            Text = "Confirm Remote Desktop displays";
            Icon = CompanionUi.AppIcon;
            StartPosition = FormStartPosition.CenterParent;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            AutoScaleMode = AutoScaleMode.Dpi;
            AutoSize = true;
            AutoSizeMode = AutoSizeMode.GrowAndShrink;
            ShowInTaskbar = false;
            MaximizeBox = false;
            MinimizeBox = false;

            var layout = new TableLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, ColumnCount = 1, Padding = new Padding(12) };
            layout.Controls.Add(new Label { Text = "Choose two screens for this Remote Desktop connection.",
                AutoSize = true });
            AddChoice(layout, mainhand, "Mainhand (game)", displays);
            AddChoice(layout, workspace, "Offhand (workspace)", displays);

            var actions = new FlowLayoutPanel { AutoSize = true, FlowDirection = FlowDirection.RightToLeft, Dock = DockStyle.Fill };
            var cancel = new Button { Text = "Cancel", AutoSize = true, DialogResult = DialogResult.Cancel };
            var span = new Button { Text = "Span WoW", AutoSize = true, Enabled = false, DialogResult = DialogResult.OK };
            actions.Controls.Add(cancel);
            actions.Controls.Add(span);
            layout.Controls.Add(actions);
            Controls.Add(layout);
            AcceptButton = span;
            CancelButton = cancel;
            mainhand.SelectedIndexChanged += (s, e) =>
            {
                if (displays.Count == 2 && Mainhand >= 0) workspace.SelectedIndex = 1 - Mainhand;
                span.Enabled = Mainhand >= 0 && Workspace >= 0 && Mainhand != Workspace;
            };
            workspace.SelectedIndexChanged += (s, e) => { span.Enabled = Mainhand >= 0 && Workspace >= 0 && Mainhand != Workspace; };
        }

        private static void AddChoice(TableLayoutPanel layout, ComboBox combo, string label,
            IList<MonitorSelection.Display> displays)
        {
            layout.Controls.Add(new Label { Text = label, AutoSize = true, Margin = new Padding(3, 8, 3, 0) });
            combo.AccessibleName = label;
            combo.DropDownStyle = ComboBoxStyle.DropDownList;
            combo.Width = 300;
            for (int i = 0; i < displays.Count; i++)
                combo.Items.Add(string.Format("Display {0}: {1}x{2}{3}", i + 1,
                    displays[i].Bounds.Width, displays[i].Bounds.Height, displays[i].Primary ? " (Primary)" : ""));
            layout.Controls.Add(combo);
        }
    }

    public class CompanionForm : Form
    {
#if HDR_DPI_DIAGNOSTICS_TEST || GRAININESS_TEST || FOREVER_GRAPHICS_RECOVERY_TEST || RETAIL_GRAPHICS_RECOVERY_TEST || CLASSIC_GRAPHICS_RECOVERY_TEST
        internal const string BaseVersion = "2.1.2";
#elif RDP_TEST
        internal const string BaseVersion = "2.1.3";
#else
        internal const string BaseVersion = "2.1.5";
#endif
#if UI_PREVIEW
        internal const string ReleaseLabel = "UI Preview 4";
        internal static readonly bool GraphicsRecoveryEnabled = false;
        internal static readonly bool RetailGraphicsRecoveryEnabled = false;
        internal static readonly bool ForeverGraphicsRecoveryEnabled = false;
#elif RDP_TEST
        internal const string ReleaseLabel = "Beta 6 RDP Test 1";
        internal static readonly bool GraphicsRecoveryEnabled = true;
        internal static readonly bool RetailGraphicsRecoveryEnabled = false;
        internal static readonly bool ForeverGraphicsRecoveryEnabled = false;
#elif HDR_DPI_DIAGNOSTICS_TEST
        internal const string ReleaseLabel = "Beta 20 HDR / DPI DIAGNOSTICS TEST 3";
        internal static readonly bool GraphicsRecoveryEnabled = false;
        internal static readonly bool RetailGraphicsRecoveryEnabled = false;
        internal static readonly bool ForeverGraphicsRecoveryEnabled = false;
#elif FOREVER_GRAPHICS_RECOVERY_TEST
        internal const string ReleaseLabel = "Beta 20 FOREVER GRAPHICS TEST 5";
        internal static readonly bool GraphicsRecoveryEnabled = true;
        internal static readonly bool RetailGraphicsRecoveryEnabled = false;
        internal static readonly bool ForeverGraphicsRecoveryEnabled = true;
#elif RETAIL_GRAPHICS_RECOVERY_TEST
        internal const string ReleaseLabel = "Beta 20 RETAIL GRAPHICS TEST 4";
        internal static readonly bool GraphicsRecoveryEnabled = true;
        internal static readonly bool RetailGraphicsRecoveryEnabled = true;
        internal static readonly bool ForeverGraphicsRecoveryEnabled = false;
#elif CLASSIC_GRAPHICS_RECOVERY_TEST
        internal const string ReleaseLabel = "Beta 20 CLASSIC GRAPHICS TEST 3";
        internal static readonly bool GraphicsRecoveryEnabled = true;
        internal static readonly bool RetailGraphicsRecoveryEnabled = false;
        internal static readonly bool ForeverGraphicsRecoveryEnabled = false;
#elif GRAININESS_TEST
        internal const string ReleaseLabel = "Beta 20";
        internal static readonly bool GraphicsRecoveryEnabled = false;
        internal static readonly bool RetailGraphicsRecoveryEnabled = false;
        internal static readonly bool ForeverGraphicsRecoveryEnabled = false;
#else
        internal const string ReleaseLabel = "";
        internal static readonly bool GraphicsRecoveryEnabled = true;
        internal static readonly bool RetailGraphicsRecoveryEnabled = false;
        internal static readonly bool ForeverGraphicsRecoveryEnabled = false;
#endif
        internal static readonly bool GraphicsRecoveryTestBuild =
#if FOREVER_GRAPHICS_RECOVERY_TEST || RETAIL_GRAPHICS_RECOVERY_TEST || CLASSIC_GRAPHICS_RECOVERY_TEST
            true;
#else
            false;
#endif
        internal static bool IsRecoveryClient(string wowDir)
        {
            return GraphicsRecoveryEnabled && (GraphicsRecoveryTestBuild
                ? ClassicGraphicsRecovery.IsSupportedClient(wowDir, RecoveryClientScope)
                : ClassicGraphicsRecovery.IsProductionClient(wowDir));
        }
        internal static bool CanArmRecovery(string wowDir, bool monitoring, bool recoveryOperation,
            IntPtr handle, Size originalClient, Size target)
        {
            return IsRecoveryClient(wowDir) && monitoring && !recoveryOperation
                && handle != IntPtr.Zero && originalClient.Width > 0 && originalClient.Height > 0
                && target.Width > 0 && target.Height > 0 && originalClient != target;
        }
        private static string RecoveryScope { get { return !GraphicsRecoveryTestBuild ? "Graphics" : ForeverGraphicsRecoveryEnabled ? "Forever" : RetailGraphicsRecoveryEnabled ? "Retail" : "Classic"; } }
        private static ClassicGraphicsRecovery.ClientScope RecoveryClientScope { get {
            return ForeverGraphicsRecoveryEnabled ? ClassicGraphicsRecovery.ClientScope.Forever :
                RetailGraphicsRecoveryEnabled ? ClassicGraphicsRecovery.ClientScope.Retail : ClassicGraphicsRecovery.ClientScope.Classic;
        } }
        internal const string FullVersion = ReleaseLabel == "" ? BaseVersion : BaseVersion + " " + ReleaseLabel;
        internal const string LayoutApplyInstruction =
            "After changing Mainhand or layout, click Span WoW Now, then type /reload in WoW.";
        internal const string ReloadLayoutInstruction =
            "Return to WoW and type /reload once to load the selected Mainhand and workspace layout.";

        // Warcraft Dark Interface Palette (Black / Dark Grey / Burnished Gold)
        private readonly Color cBg = Color.FromArgb(12, 12, 14);                // Obsidian black canvas (#0c0c0e)
        private readonly Color cCard = Color.FromArgb(20, 20, 24);              // Dark forged iron card (#141418)
        private readonly Color cBorder = Color.FromArgb(145, 115, 55);          // Burnished gold outer border (#917337)
        private readonly Color cBorderDim = Color.FromArgb(65, 52, 28);         // Antique bronze divider (#41341c)
        private readonly Color cText = Color.FromArgb(235, 230, 215);           // Warm parchment white (#ebe6d7)
        private readonly Color cMuted = Color.FromArgb(155, 145, 130);          // Weathered silver-grey (#9b9182)
        private readonly Color cGold = Color.FromArgb(240, 184, 54);            // Iconic Warcraft Gold (#f0b836)
        private readonly Color cGoldBright = Color.FromArgb(255, 215, 80);      // Luminous gold highlight (#ffd750)
        private readonly Color cBrass = Color.FromArgb(185, 145, 60);           // Warm brass trim (#b9913c)
        private readonly Color cGreen = Color.FromArgb(72, 204, 120);           // Active emerald green (#48cc78)
        private readonly Color cYellow = Color.FromArgb(240, 185, 55);          // Warning amber (#f0b937)
        private readonly Color cBtnBg = Color.FromArgb(28, 28, 34);             // Dark iron button (#1c1c22)
        private readonly Color cBtnPrimaryBg = Color.FromArgb(36, 30, 20);      // Dark bronze primary button (#241e14)
        private readonly Color cBtnDanger = Color.FromArgb(44, 16, 16);          // Dark ruby danger button (#2c1010)
        private readonly Color cLogBg = Color.FromArgb(8, 8, 10);               // Deepest obsidian log (#08080a)
        private readonly Color cLogText = Color.FromArgb(195, 190, 175);        // Parchment log text (#c3beaf)

        // UI Controls
        private Label lblWowStatus;
        private Label lblAddonStatus;
        private Label lblDisplayInfo;
        private Label lblColorModes;
        private Label lblColorWarning;
        private Label lblScaleInfo;
        private Label lblStatusSummary;
        private Label lblHeaderVersion;
        private Label lblHeaderTitle, lblHeaderTagline, lblHeaderSubtitle;
        private Panel advancedPanel;
        private Button btnUseStandardLayout;
        private Panel configurationPanel, diagnosticsPanel, activityPanel, setupGuide;
        private TableLayoutPanel dashboardNavigation;
        private Button setupTab, advancedTab;
        private Label[] setupGuideSteps;
        private bool advancedPage;
        private const int DashboardActionHeight = 44;
        private sealed class DashboardSection
        {
            internal Panel Panel;
            internal Label Heading;
            internal Button Toggle;
            internal string Key;
            internal bool Expanded = true;
            internal bool CanCollapse = true;
        }
        private readonly Dictionary<Panel, DashboardSection> dashboardSections = new Dictionary<Panel, DashboardSection>();
        private TableLayoutPanel dashboardStack;
        private Panel dashboardScroll;
        private TableLayoutPanel dashboardFooter;
        private Panel dashboardHeader;
        private bool layingOutDashboard;
        private string colorDiagnostics = "Select a valid display plan to inspect color modes.";
        private string lastColorDiagnostic;
        private Label lblAddonReason;
        private string lastAddonDiagnostic;
        private CheckBox chkAutoSpan;
        private NumericUpDown numDelaySpan;
        private Label lblDelay;
        private CheckedListBox clbMonitors;
        private ComboBox cmbMainhand;
        private CheckBox chkSingleSplit;
        private ComboBox cmbSingleSide;
        private Button btnPartialSpan;
        private Button btnWorkspaceProfiles;
        private List<MonitorSelection.Display> uiDisplays;
        private bool refreshingDisplayControls;
        private int displaySelectionGeneration;

        private sealed class DisplayChoice
        {
            internal int Index;
            internal string DeviceName;
            internal string StableId;
            internal string Label;
            public override string ToString() { return Label; }
        }

        private sealed class DisplayIdentifierForm : Form
        {
            internal DisplayIdentifierForm(MonitorSelection.Display display, string role,
                Color background, Color border, Color heading, Color text)
            {
                Text = "Offhand Display Identifier";
                StartPosition = FormStartPosition.Manual;
                Bounds = display.Bounds;
                FormBorderStyle = FormBorderStyle.None;
                ShowInTaskbar = false;
                TopMost = true;
                BackColor = background;
                Opacity = 0.92;
                KeyPreview = true;
                Cursor = Cursors.Hand;

                var content = new TableLayoutPanel
                {
                    Dock = DockStyle.Fill,
                    BackColor = background,
                    ColumnCount = 1,
                    RowCount = 4,
                    Padding = new Padding(24)
                };
                content.RowStyles.Add(new RowStyle(SizeType.Percent, 28));
                content.RowStyles.Add(new RowStyle(SizeType.Percent, 30));
                content.RowStyles.Add(new RowStyle(SizeType.Percent, 24));
                content.RowStyles.Add(new RowStyle(SizeType.Percent, 18));

                var title = new Label
                {
                    Text = "DISPLAY " + (display.Index + 1),
                    Dock = DockStyle.Fill,
                    TextAlign = ContentAlignment.BottomCenter,
                    Font = new Font("Georgia", 48, FontStyle.Bold),
                    ForeColor = heading,
                    BackColor = background
                };
                var roleLabel = new Label
                {
                    Text = role,
                    Dock = DockStyle.Fill,
                    TextAlign = ContentAlignment.MiddleCenter,
                    Font = new Font("Segoe UI", 22, FontStyle.Bold),
                    ForeColor = text,
                    BackColor = background
                };
                var details = new Label
                {
                    Text = string.Format("{0} x {1}{2}", display.Bounds.Width, display.Bounds.Height,
                        display.Primary ? "  •  Windows primary display" : ""),
                    Dock = DockStyle.Fill,
                    TextAlign = ContentAlignment.TopCenter,
                    Font = new Font("Segoe UI", 14),
                    ForeColor = text,
                    BackColor = background
                };
                var hint = new Label
                {
                    Text = "Closes automatically • Click to close now",
                    Dock = DockStyle.Fill,
                    TextAlign = ContentAlignment.MiddleCenter,
                    Font = new Font("Segoe UI", 10),
                    ForeColor = border,
                    BackColor = background
                };

                content.Controls.Add(title, 0, 0);
                content.Controls.Add(roleLabel, 0, 1);
                content.Controls.Add(details, 0, 2);
                content.Controls.Add(hint, 0, 3);
                content.Paint += (s, e) =>
                {
                    using (var pen = new Pen(border, 8))
                        e.Graphics.DrawRectangle(pen, 4, 4,
                            content.ClientSize.Width - 9, content.ClientSize.Height - 9);
                };
                Controls.Add(content);

                Action close = () => { if (!IsDisposed) Close(); };
                Click += (s, e) => close();
                content.Click += (s, e) => close();
                foreach (Control child in content.Controls) child.Click += (s, e) => close();
                KeyDown += (s, e) => { if (e.KeyCode == Keys.Escape) close(); };

            }

            protected override bool ShowWithoutActivation
            {
                get { return true; }
            }

            protected override CreateParams CreateParams
            {
                get
                {
                    const int WS_EX_NOACTIVATE = 0x08000000;
                    CreateParams parameters = base.CreateParams;
                    parameters.ExStyle |= WS_EX_NOACTIVATE;
                    return parameters;
                }
            }
        }

        private static List<MonitorSelection.Display> ReadDisplays()
        {
            var result = new List<MonitorSelection.Display>();
            var screens = Screen.AllScreens;
            var devices = new List<string>();
            foreach (var screen in screens) devices.Add(screen.DeviceName);
            var identities = DisplayIdentity.Read(devices);
            for (int i = 0; i < screens.Length; i++)
                result.Add(new MonitorSelection.Display { Index = i, DeviceName = screens[i].DeviceName,
                    StableId = identities[screens[i].DeviceName].Identity,
                    LegacyStableId = identities[screens[i].DeviceName].LegacyIdentity,
                    IdentityDetail = identities[screens[i].DeviceName].Detail,
                    Bounds = screens[i].Bounds, WorkArea = screens[i].WorkingArea, Primary = screens[i].Primary });
            return result;
        }

        private static bool HasStableIdentitySettings()
        {
            return MonitorSelection.HasStableIdentitySettings(appSettings);
        }

        private bool IsCustomSelection()
        {
            return WorkspaceLayoutSettings.Enabled(appSettings)||MonitorSelection.MultiEnabled(appSettings)
                || (appSettings.ContainsKey("PartialSpanEnabled")&&appSettings["PartialSpanEnabled"]=="True")
                || (appSettings.ContainsKey("SecondaryAreaEnabled")&&appSettings["SecondaryAreaEnabled"]=="True");
        }

        private static bool HasSelectedIdentity(HashSet<string> identities,IList<MonitorSelection.Display> displays,int index)
        {
            foreach(string identity in identities)if(MonitorSelection.FindDisplay(displays,identity,null)==index)return true;
            return false;
        }

        private void RefreshDisplayControls(List<MonitorSelection.Display> displays, bool force = false)
        {
            if (clbMonitors == null || cmbMainhand == null || displays == null
                || (!force && MonitorSelection.SameDisplays(uiDisplays, displays))) return;

            string savedDevices, savedIdentities;
            appSettings.TryGetValue("MonitorDevices", out savedDevices);
            appSettings.TryGetValue("MonitorIdentities", out savedIdentities);
            bool useStableIdentities = MonitorSelection.HasSavedIdentitySettings(appSettings);
            string wantedValues = useStableIdentities ? savedIdentities : savedDevices;
            bool hasSavedSelection = useStableIdentities
                ? appSettings.ContainsKey("MonitorIdentities")
                : appSettings.ContainsKey("MonitorDevices");
            var wanted = new HashSet<string>((wantedValues ?? "").Split(
                new char[] { '|' }, StringSplitOptions.RemoveEmptyEntries), StringComparer.OrdinalIgnoreCase);
            string savedMainhandIdentity;
            appSettings.TryGetValue("MainhandIdentity", out savedMainhandIdentity);
            string savedMainhand;
            appSettings.TryGetValue("MainhandDevice", out savedMainhand);

            refreshingDisplayControls = true;
            displaySelectionEdited=false;
            clbMonitors.BeginUpdate();
            cmbMainhand.BeginUpdate();
            try
            {
                uiDisplays = displays;
                clbMonitors.Items.Clear();
                cmbMainhand.Items.Clear();
                for (int i = 0; i < uiDisplays.Count; i++)
                {
                    Rectangle b = uiDisplays[i].Bounds;
                    string selectionKey = useStableIdentities ? uiDisplays[i].StableId : uiDisplays[i].DeviceName;
                    bool selected = !hasSavedSelection || (useStableIdentities
                        ? wanted.Count>0 && HasSelectedIdentity(wanted,uiDisplays,i) : wanted.Contains(selectionKey ?? ""));
                    clbMonitors.Items.Add(string.Format("Display {0}: {1}x{2}{3}", i + 1, b.Width, b.Height,
                        uiDisplays[i].Primary ? " (Primary)" : ""), selected);
                    cmbMainhand.Items.Add(new DisplayChoice { Index = i, DeviceName = uiDisplays[i].DeviceName,
                        StableId = uiDisplays[i].StableId,
                        Label = string.Format("Display {0} — {1}x{2}", i + 1, b.Width, b.Height) });
                }
                for (int i = 0; i < cmbMainhand.Items.Count; i++)
                {
                    var choice = (DisplayChoice)cmbMainhand.Items[i];
                    if ((useStableIdentities && MonitorSelection.FindDisplay(uiDisplays,savedMainhandIdentity,null)==i)
                        || (!useStableIdentities && string.Equals(choice.DeviceName,savedMainhand,StringComparison.OrdinalIgnoreCase)))
                    {
                        cmbMainhand.SelectedIndex = i;
                        break;
                    }
                }
                if (cmbMainhand.SelectedIndex < 0 && cmbMainhand.Items.Count > 0
                    && string.IsNullOrWhiteSpace(savedMainhand) && string.IsNullOrWhiteSpace(savedMainhandIdentity))
                {
                    for (int i = 0; i < uiDisplays.Count; i++)
                        if (uiDisplays[i].Primary) { cmbMainhand.SelectedIndex = i; break; }
                    if (cmbMainhand.SelectedIndex < 0) cmbMainhand.SelectedIndex = 0;
                }
                string side;
                chkSingleSplit.Checked = appSettings.TryGetValue("SingleDisplaySplit", out side) && side == "True";
                cmbSingleSide.SelectedIndex = appSettings.TryGetValue("SingleGameSide", out side)
                    && string.Equals(side, "LEFT", StringComparison.OrdinalIgnoreCase) ? 1 : 0;
            }
            finally
            {
                cmbMainhand.EndUpdate();
                clbMonitors.EndUpdate();
                refreshingDisplayControls = false;
                displaySelectionGeneration++;
            }
            AddLog("Windows display topology changed; refreshed the display controls.");
        }

        private MonitorSelection.Plan GetMonitorPlan(List<MonitorSelection.Display> displays)
        {
            if (!HasStableIdentitySettings())
                throw new InvalidOperationException(DisplaySelectionPrompt(appSettings, IsCustomSelection(), requiresDisplayIdentityConfirmation));
            return MonitorSelection.CreatePlan(appSettings, displays);
        }

        internal static string DisplaySelectionPrompt(IDictionary<string, string> settings, bool custom, bool confirmSaved)
        {
            string version;
            if (settings.TryGetValue("DisplayIdentityVersion", out version) && version != "1" && version != "2")
                return "Open this display layout with the Companion version that saved it.";
            if (confirmSaved || version == "1")
                return "Confirm your saved displays\r\nWith WoW open, click Span WoW Now. Check the game and workspace screens in the dialog. Companion remembers your choice when you click OK."
                    + (custom ? "\r\nTo change the layout, open Advanced > Workspace layout." : "");
            return custom
                ? "Open Advanced > Workspace layout to review and save the layout before spanning."
                : "Select the displays to span and choose the Mainhand game display.";
        }

        private void UpdatePartialControls()
        {
            bool partial = IsCustomSelection();
            bool local = remoteState == RemoteDesktop.State.Local;
            if (btnPartialSpan != null)
            {
                string caption = partial ? "Workspace layout (custom)…" : "Workspace layout (standard)…";
                btnPartialSpan.Text = caption;
                btnPartialSpan.AccessibleName = caption;
                btnPartialSpan.Enabled = local;
            }
            if (btnWorkspaceProfiles != null) btnWorkspaceProfiles.Enabled = local;
            if (btnUseStandardLayout != null) btnUseStandardLayout.Enabled = local && partial;
            DashboardSection advanced;
            if (advancedPanel != null && dashboardSections.TryGetValue(advancedPanel, out advanced)) {
                advanced.Heading.Text = "WORKSPACE AND STARTUP";
                advanced.Toggle.AccessibleName = (advanced.Expanded ? "Collapse " : "Expand ") + advanced.Heading.Text;
            }
            UpdateDashboardNavigation();
            clbMonitors.Enabled = local && !partial;
            cmbMainhand.Enabled = local && !partial;
            chkSingleSplit.Enabled = local && !partial;
            cmbSingleSide.Enabled = local && !partial && chkSingleSplit.Checked;
            numDelaySpan.Enabled = local;
            chkAutoSpan.Enabled = local && !partial && !GraphicsRecoveryTestBuild;
            if (itemAuto != null) itemAuto.Enabled = chkAutoSpan.Enabled;
        }

        private void EditWorkspaceProfiles()
        {
            if (RemoteDesktop.Read() != RemoteDesktop.State.Local) return;
            SuspendUiPolling();
            try {
                using(var dialog=new WorkspaceProfilesDialog(appSettings,ReadDisplays)) {
                    if(dialog.ShowDialog(this)!=DialogResult.OK || RemoteDesktop.Read()!=RemoteDesktop.State.Local)return;
                    if(dialog.LoadedPlan)CustomRegionPreferences.Write(configPath,dialog.Settings,ReadDisplays);
                    else PreferenceFile.Write(configPath,dialog.Settings);
                    appSettings=dialog.Settings;
                    requiresDisplayIdentityConfirmation=!HasStableIdentitySettings();
                }
                classicRecovery.Clear();displaySelectionGeneration++;
                RefreshDisplayControls(ReadDisplays(),true);
                chkAutoSpan.Checked=appSettings.ContainsKey("AutoSpan")&&appSettings["AutoSpan"]=="True";
                UpdatePartialControls();RefreshSelectedColorStatus();
                AddLog("Workspace profiles saved. Click Span WoW Now to apply the selected display plan, then type /reload in WoW.");
            } catch(Exception ex) {AddLog("Workspace profiles were not saved: "+ex.Message);MessageBox.Show(this,ex.Message,"Workspace profiles",MessageBoxButtons.OK,MessageBoxIcon.Information);}
            finally {ResumeUiPolling();}
        }

        private void EditPartialSpan() { EditWorkspaceLayout(false); }

        private void EditWorkspaceLayout(bool useStandard)
        {
            if (RemoteDesktop.Read() != RemoteDesktop.State.Local) return;
            SuspendUiPolling();
            try
            {
                Dictionary<string,string> proposed;
                List<MonitorSelection.Display> confirmedDisplays = null;
                using (var choice = new CustomRegionModeDialog(appSettings))
                {
                    if (!useStandard && choice.ShowDialog(this) != DialogResult.OK) return;
                    if (useStandard || choice.UseStandard)
                    {
                        confirmedDisplays = ReadDisplays();
                        int[] selection;
                        proposed = CustomRegionPreferences.StandardLayout(appSettings, confirmedDisplays, out selection);
                        if (!ConfirmStandardLayout(confirmedDisplays, selection)) return;
                    }
                    else if (choice.Flexible) {
                        using(var dialog=new FlexibleWorkspaceEditor(ReadDisplays(),appSettings)) {
                            if(dialog.ShowDialog(this)!=DialogResult.OK)return;
                            proposed=dialog.Settings;
                        }
                    } else if (choice.Multiple) {
                        using(var dialog=new WorkspaceRegionsDialog(ReadDisplays(),appSettings)) {
                            if(dialog.ShowDialog(this)!=DialogResult.OK)return;
                            proposed=dialog.Settings;
                        }
                    } else if (choice.Secondary) {
                        using (var dialog = new SecondaryAreaDialog(ReadDisplays(), appSettings)) {
                            if (dialog.ShowDialog(this) != DialogResult.OK) return;
                            proposed = dialog.Settings;
                        }
                    } else {
                        using (var dialog = new PartialSpanDialog(ReadDisplays(), appSettings)) {
                            if (dialog.ShowDialog(this) != DialogResult.OK) return;
                            proposed = dialog.Settings;
                        }
                    }
                }
                if (RemoteDesktop.Read() != RemoteDesktop.State.Local) return;
                // Publish the complete validated copy before adopting it.
                var currentDisplays = CustomRegionPreferences.Write(configPath, proposed, ReadDisplays, confirmedDisplays);
                appSettings = proposed;
                requiresDisplayIdentityConfirmation=!HasStableIdentitySettings();
                classicRecovery.Clear(); displaySelectionGeneration++;
                RefreshDisplayControls(currentDisplays, true);
                chkAutoSpan.Checked = appSettings.ContainsKey("AutoSpan") && appSettings["AutoSpan"] == "True";
                UpdatePartialControls(); RefreshSelectedColorStatus();
                AddLog(confirmedDisplays == null
                    ? "Custom region plan saved. Click Span WoW Now to apply, or Restore Window to return to the ordinary window."
                    : "Standard display layout saved. Review the dashboard displays before spanning or restoring WoW.");
            }
            catch (Exception ex) { AddLog("Workspace layout was not saved: " + ex.Message); MessageBox.Show(this, ex.Message, "Workspace layout", MessageBoxButtons.OK, MessageBoxIcon.Information); }
            finally { ResumeUiPolling(); }
        }

        private bool ConfirmStandardLayout(IList<MonitorSelection.Display> displays, int[] selected)
        {
            string review = DescribeDisplayRole("Mainhand (game)", selected[0], displays);
            string next = "Use Restore Window if WoW is currently spanned.";
            if (selected.Length == 2)
            {
                review += "\r\n" + DescribeDisplayRole("Offhand workspace", selected[1], displays);
                next = "Click Span WoW Now to apply, then reload the WoW UI.";
            }
            return MessageBox.Show(this, review + "\r\n\r\nClick OK to turn off custom workspaces and save this display selection. Named profiles stay saved.\r\n\r\n" + next,
                "Use standard display layout", MessageBoxButtons.OKCancel, MessageBoxIcon.Question, MessageBoxDefaultButton.Button2) == DialogResult.OK;
        }

        private void SaveDisplaySettingsFromControls(bool persist = true)
        {
            if (refreshingDisplayControls || clbMonitors == null || uiDisplays == null
                || remoteState != RemoteDesktop.State.Local || RemoteDesktop.Read() != RemoteDesktop.State.Local) return;
            if(IsCustomSelection())return;
            string identityVersion;
            if(appSettings.TryGetValue("DisplayIdentityVersion",out identityVersion)&&identityVersion!="1"&&identityVersion!="2") {
                AddLog("Unsupported display identity settings were retained. Review or restore compatible preferences before changing displays.");return;
            }
            // A user's display edit cancels ownership immediately, even if the
            // selection is changed back before the next monitoring poll.
            classicRecovery.Clear();
            var devices = new List<string>();
            var identities = new List<string>();
            var legacy = new List<string>();
            for (int i = 0; i < clbMonitors.Items.Count; i++)
            {
                if (!clbMonitors.GetItemChecked(i)) continue;
                devices.Add(uiDisplays[i].DeviceName);
                if (!string.IsNullOrWhiteSpace(uiDisplays[i].StableId)) identities.Add(uiDisplays[i].StableId);
                legacy.Add(i.ToString());
            }
            // No valid span uses zero displays. Preserve the last known-good
            // selection while controls are rebuilt or identities temporarily
            // disappear instead of turning an empty transient state into the
            // next launch's implicit "select every display" default.
            if (devices.Count == 0) {appSettings.Remove("DisplayIdentityVersion");if(persist)SaveConfig();return;}
            appSettings["MonitorDevices"] = string.Join("|", devices.ToArray());
            if (identities.Count == devices.Count)
                appSettings["MonitorIdentities"] = string.Join("|", identities.ToArray());
            else appSettings.Remove("MonitorIdentities");
            appSettings["Monitors"] = string.Join(",", legacy.ToArray());
            var choice = cmbMainhand == null ? null : cmbMainhand.SelectedItem as DisplayChoice;
            if (choice != null)
            {
                appSettings["MainhandDevice"] = choice.DeviceName;
                if (!string.IsNullOrWhiteSpace(choice.StableId)) appSettings["MainhandIdentity"] = choice.StableId;
                else appSettings.Remove("MainhandIdentity");
            }
            else appSettings.Remove("MainhandIdentity");
            appSettings.Remove("DisplayIdentityVersion");
            if (chkSingleSplit != null) appSettings["SingleDisplaySplit"] = chkSingleSplit.Checked.ToString();
            if (cmbSingleSide != null && cmbSingleSide.SelectedItem != null)
                appSettings["SingleGameSide"] = cmbSingleSide.SelectedItem.ToString().ToUpperInvariant();
            if(identities.Count==devices.Count && identities.Count>0 && choice!=null && !string.IsNullOrWhiteSpace(choice.StableId)) {
                try {
                    MonitorSelection.CreatePlan(appSettings["MonitorIdentities"],null,null,choice.StableId,null,
                        chkSingleSplit!=null&&chkSingleSplit.Checked,false,uiDisplays);
                    if(!requiresDisplayIdentityConfirmation)appSettings["DisplayIdentityVersion"]="2";
                }catch(InvalidOperationException){}
            }
            if(persist)SaveConfig();
            if (persist && lblColorModes != null) RefreshSelectedColorStatus();
        }

        private bool ConfirmStableDisplayIdentity(bool manual)
        {
            if (HasStableIdentitySettings()) return false;
            string identityVersion;
            if(appSettings.TryGetValue("DisplayIdentityVersion",out identityVersion)&&identityVersion!="1"&&identityVersion!="2")
                throw new InvalidOperationException("Unsupported display identity settings were retained. Use a compatible Companion before changing this plan.");
            if (!manual)
                throw new InvalidOperationException("Display selection must be confirmed once before automatic spanning can resume.");
            // Work on a copy. Cancellation and incomplete/missing bindings leave
            // the active plan, profile store and fallback snapshots intact.
            var proposed=new Dictionary<string,string>(appSettings);
            if(!IsCustomSelection()) {
                if(!proposed.ContainsKey("MonitorIdentities")||!proposed.ContainsKey("MainhandIdentity"))
                    throw new InvalidOperationException("Windows did not provide an identity for every selected display. Review the checked displays and Mainhand.");
                proposed["DisplayIdentityVersion"]="1";
            }
            proposed=MonitorSelection.UpgradeIdentitySettings(proposed,uiDisplays);
            var reviewed=MonitorSelection.CreatePlan(proposed,uiDisplays);
            var screens = new List<string> { DescribeDisplayRole("Mainhand (game)", reviewed.MainhandIndex, uiDisplays) };
            if (reviewed.MultiRegion)
            {
                for (int i = 0; i < reviewed.Workspaces.Length; i++)
                    screens.Add(DescribeDisplayRole(i == 0 ? "Workspace A" : "Workspace B", reviewed.Workspaces[i].DisplayIndex, uiDisplays));
            }
            else
            {
                screens.Add(DescribeDisplayRole("Offhand workspace", reviewed.WorkspaceIndex, uiDisplays));
            }
            DialogResult answer = MessageBox.Show(this,
                string.Join("\r\n", screens) + "\r\n\r\nClick OK to save these screens and span WoW. Click Cancel to review the layout.",
                "Confirm your saved displays", MessageBoxButtons.OKCancel, MessageBoxIcon.Question, MessageBoxDefaultButton.Button2);
            if (answer != DialogResult.OK)
                throw new OperationCanceledException("Span cancelled at display confirmation.");
            if (RemoteDesktop.Read() != RemoteDesktop.State.Local)
                throw new InvalidOperationException("The Windows session changed. Review the displays and click Span WoW Now again.");
            // A failed preference write must block Apply, not merely log and
            // continue with a migration that would be lost on restart.
            PreferenceFile.Write(configPath,proposed);
            appSettings=proposed;requiresDisplayIdentityConfirmation=false;
            if (!HasStableIdentitySettings())
                throw new InvalidOperationException("The physical display selection could not be saved.");
            AddLog("Confirmed physical display identities; future Windows DISPLAY renumbering will not swap Mainhand and workspace.");
            return true;
        }

        private static string DescribeDisplayRole(string role, int displayIndex, IList<MonitorSelection.Display> displays)
        {
            Rectangle bounds = displays[displayIndex].Bounds;
            return string.Format("{0} on Display {1} ({2} × {3})", role, displayIndex + 1, bounds.Width, bounds.Height);
        }

        private static Dictionary<string, string> appSettings = new Dictionary<string, string>();
        private static readonly string publicConfigPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Offhand", "OffhandConfig.ini");
#if UI_PREVIEW
        private static readonly string configPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "DashboardPreviewConfig.ini");
#elif RDP_TEST
        private static readonly string configPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "RdpTestConfig.ini");
#elif HDR_DPI_DIAGNOSTICS_TEST
        private static readonly string configPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "DiagnosticsTestConfig.ini");
#elif GRAININESS_TEST
        private static readonly string configPath = SpanPresentationTest.ConfigPath;
#else
        private static readonly string configPath = GraphicsRecoveryTestBuild
            ? Path.Combine(AppDomain.CurrentDomain.BaseDirectory, RecoveryScope + "TestConfig.ini")
            : CompanionSettingsPath.Resolve(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                CompanionDistribution.PackageFamilyName());
#endif
        private string configWarning;
        private bool requiresDisplayIdentityConfirmation;
        private bool displaySelectionEdited;

        private void LoadConfig()
        {
            try
            {
                // Import portable settings once; future launches are independent of CWD.
#if UI_PREVIEW
                string source = configPath;
#elif RDP_TEST || HDR_DPI_DIAGNOSTICS_TEST
                string source = File.Exists(configPath) ? configPath : publicConfigPath;
#else
                string source = CompanionSettingsPath.ReadSource(configPath, publicConfigPath,
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "OffhandConfig.ini"));
#endif
                appSettings = PreferenceFile.Read(source);
                requiresDisplayIdentityConfirmation=!HasStableIdentitySettings()
                    &&(appSettings.ContainsKey("MonitorIdentities")||appSettings.ContainsKey("MonitorDevices")||appSettings.ContainsKey("Monitors"));
            }
            catch (IOException ex) { configWarning = "Cannot read settings: " + ex.Message; }
            catch (UnauthorizedAccessException ex) { configWarning = "Cannot read settings: " + ex.Message; }
        }

        private void SaveConfig()
        {
            try
            {
                PreferenceFile.Write(configPath, appSettings);
            }
            catch (IOException ex) { AddLog("Cannot save settings: " + ex.Message); }
            catch (UnauthorizedAccessException ex) { AddLog("Cannot save settings: " + ex.Message); }
        }

        private Button btnSpanNow;
        private ToolStripMenuItem itemMonitor;
        private Button btnCheckUpdates;
        private RichTextBox logBox;
        private readonly List<string> activityLogEntries = new List<string>();
        private NotifyIcon trayIcon;
        private ToolStripMenuItem itemAuto;
        private Timer monitorTimer;
        private ToolTip uiToolTips;

        // State
        private bool isMonitoring = true;
        private bool isExplicitExit = false;
        private bool updateCheckInProgress = false;
        private Timer storeUpdateTimer;
        private readonly CancellationTokenSource storeUpdateLifetime = new CancellationTokenSource();
        private bool storeUpdateStopped;
        private StoreUpdateCache storeUpdateCache;
        private ToolStripMenuItem itemCheckUpdates;
        private Func<IntPtr, CancellationToken, Task<StoreUpdateState>> storeUpdateQuery = StoreUpdateRuntime.QueryAsync;
        private readonly bool isStorePackage = CompanionDistribution.IsStorePackage();
        private readonly HashSet<int> spannedPids = new HashSet<int>();
#if GRAININESS_TEST
        private int spanTestGeneration;
#endif
        private readonly HashSet<int> restoredPids = new HashSet<int>();
        private readonly HashSet<int> failedAutoSpanPids = new HashSet<int>();
        private sealed class WindowSnapshot
        {
            internal IntPtr Handle;
            internal Rectangle Bounds;
            internal int Style;
            internal Size ClientSize;
        }
        private readonly Dictionary<int, WindowSnapshot> originalWindows = new Dictionary<int, WindowSnapshot>();
        private readonly Dictionary<int, ClassicGraphicsRecovery> classicRecovery = new Dictionary<int, ClassicGraphicsRecovery>();
        private readonly Dictionary<int, DateTime> retryAfter = new Dictionary<int, DateTime>();
        private readonly Dictionary<int, DateTime> launchTimes = new Dictionary<int, DateTime>();
        private readonly int currentSessionId;
        private RemoteDesktop.State remoteState = RemoteDesktop.Read();
        private readonly RemoteDesktopWatcher remoteWatcher;
        private int remoteGeneration;
        private RemoteSpan remoteSpan;
        private sealed class RemoteSpan
        {
            internal int ProcessId;
            internal IntPtr Handle;
            internal List<MonitorSelection.Display> Displays;
            internal TopologySnapshot Topology;
        }
        private string lastObservedWowDir;
        private string lastTopologyRepairFailure;
        private bool bridgeAttemptedWhileStopped;
        private static readonly string[] wowProcessNames = new string[] {
            "WowClassic", "Wow", "WowClassicEra", "WowForever", "WowT", "WowB", "WowClassicT", "WowClassicB"
        };
        private bool uiInteractionPaused;

        private void InvalidateRemoteSpan()
        {
            remoteGeneration++;
            displaySelectionGeneration++;
            var previous = remoteSpan;
            remoteSpan = null;
            if (previous == null) return;
            // A local plan or a replacement connection must not re-use this
            // window as an automatic span target until the player reviews it.
            spannedPids.Remove(previous.ProcessId);
            restoredPids.Add(previous.ProcessId);
            classicRecovery.Remove(previous.ProcessId);
            try { previous.Topology.Restore(); }
            catch (IOException ex) { if (!IsDisposed && !Disposing) AddLog("Remote Desktop topology cleanup: " + ex.Message); }
            catch (UnauthorizedAccessException ex) { if (!IsDisposed && !Disposing) AddLog("Remote Desktop topology cleanup: " + ex.Message); }
            if (!IsDisposed && !Disposing) AddLog("Remote Desktop span ended. Confirm the screens before spanning again.");
        }

        private MonitorSelection.Plan ConfirmRemotePlan(List<MonitorSelection.Display> displays)
        {
            if (!remoteWatcher.Registered)
                throw new InvalidOperationException("Offhand could not monitor Remote Desktop connection changes. Restart the Companion and try again.");
            if (remoteSpan != null)
                throw new InvalidOperationException("Click Restore Window before changing the screens for this Remote Desktop span.");
            if (displays.Count < 2)
                throw new InvalidOperationException("Connect to Remote Desktop with at least two displays before spanning.");
            if (!Visible) RestoreForm();
            SuspendUiPolling();
            try
            {
                using (var dialog = new RemoteDisplayDialog(displays))
                {
                    if (dialog.ShowDialog(this) != DialogResult.OK) return null;
                    return RemoteDesktop.CreatePlan(displays, dialog.Mainhand, dialog.Workspace);
                }
            }
            finally { ResumeUiPolling(); }
        }

        private void ValidateRemoteConfirmation(int generation, List<MonitorSelection.Display> displays)
        {
            if (!RemoteDesktop.SameConnection(RemoteDesktop.Read(), remoteWatcher.Registered,
                generation, remoteGeneration, displays, ReadDisplays()))
                throw new InvalidOperationException("The Remote Desktop connection or display layout changed. Click Span WoW Now to confirm the screens again.");
        }

        protected override void WndProc(ref Message m)
        {
            const int WM_ENTERSIZEMOVE = 0x0231;
            const int WM_EXITSIZEMOVE = 0x0232;
            if (m.Msg == WM_ENTERSIZEMOVE) SuspendUiPolling();
            base.WndProc(ref m);
            if (m.Msg == WM_EXITSIZEMOVE) ResumeUiPolling();
        }

        private void ShowDisplayIdentifiers()
        {
            List<MonitorSelection.Display> displays = ReadDisplays();
            RefreshDisplayControls(displays);
            bool remote = RemoteDesktop.Read() != RemoteDesktop.State.Local;
            if (displays.Count == 0)
            {
                MessageBox.Show("Windows did not report any connected displays.", "Identify Displays",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            SuspendUiPolling();
            int mainhandIndex = -1;
            var choice = cmbMainhand == null ? null : cmbMainhand.SelectedItem as DisplayChoice;
            if (choice != null) mainhandIndex = choice.Index;
            var overlays = new List<DisplayIdentifierForm>();
            var closeTimer = new Timer { Interval = 4000 };
            int remaining = displays.Count;
            bool resumed = false;
            Action finish = () =>
            {
                if (resumed) return;
                resumed = true;
                closeTimer.Stop();
                closeTimer.Dispose();
                ResumeUiPolling();
                if (!IsDisposed) Activate();
            };

            for (int i = 0; i < displays.Count; i++)
            {
                bool selected = clbMonitors != null && i < clbMonitors.Items.Count
                    && clbMonitors.GetItemChecked(i);
                string role;
                if (remote) role = "Remote Desktop";
                else if (selected && chkSingleSplit != null && chkSingleSplit.Checked)
                    role = "Selected super-ultrawide • game " +
                        (cmbSingleSide != null && cmbSingleSide.SelectedIndex == 1 ? "left" : "right");
                else if (selected && i == mainhandIndex) role = "Mainhand (game)";
                else if (selected) role = "Offhand workspace";
                else role = "Not selected";

                var overlay = new DisplayIdentifierForm(displays[i], role,
                    Color.FromArgb(12, 12, 14), cGold, cGoldBright, cText);
                overlay.FormClosed += (s, e) =>
                {
                    remaining--;
                    if (remaining <= 0) finish();
                };
                overlays.Add(overlay);
            }

            closeTimer.Tick += (s, e) =>
            {
                closeTimer.Stop();
                foreach (DisplayIdentifierForm overlay in overlays.ToArray())
                    if (!overlay.IsDisposed) overlay.Close();
                if (remaining <= 0) finish();
            };
            foreach (DisplayIdentifierForm overlay in overlays) overlay.Show();
            closeTimer.Start();
            AddLog("Display identifiers shown for four seconds.");
        }

        public CompanionForm()
        {
            using (Process current = Process.GetCurrentProcess()) currentSessionId = current.SessionId;
            LoadConfig();
#if UI_PREVIEW
            appSettings["AutoSpan"] = "False";
#endif
#if RDP_TEST
            appSettings["AutoSpan"] = "False";
#endif
#if HDR_DPI_DIAGNOSTICS_TEST
            // Import display choices in memory, but never arm automatic spanning
            // from the public user's settings in a diagnostics candidate.
            appSettings["AutoSpan"] = "False";
#endif
#if GRAININESS_TEST
            // Candidate preferences are isolated; never auto-span during this experiment.
            appSettings["AutoSpan"] = "False";
#endif
            InitializeUI();
            remoteWatcher = new RemoteDesktopWatcher(InvalidateRemoteSpan);
            Disposed += (s, e) =>
            {
                if (!storeUpdateStopped)
                {
                    storeUpdateStopped = true;
                    if (storeUpdateTimer != null) storeUpdateTimer.Dispose();
                    storeUpdateLifetime.Cancel();
                    storeUpdateLifetime.Dispose();
                }
                remoteWatcher.Dispose();
                InvalidateRemoteSpan();
            };
            InitializeTray();
            InitializeTimer();
#if UI_PREVIEW
            chkAutoSpan.Enabled = false;
            itemAuto.Enabled = false;
            AddLog("UI PREVIEW: separate local settings; automatic spanning and graphics recovery disabled.");
#endif
#if RDP_TEST
            this.Text = "Offhand Companion - RDP Test 1";
            AddLog("RDP TEST 1: preferences are saved beside this test executable.");
#endif
#if GRAININESS_TEST
            chkAutoSpan.Enabled = false;
            itemAuto.Enabled = false;
            this.Text = "Offhand Graininess Test2: " + SpanPresentationTest.Mode;
            AddLog("TEST MODE: " + SpanPresentationTest.Mode + "; manual Span only. Logs: " + SpanPresentationTest.LogPath);
#endif
            if (configWarning != null) AddLog(configWarning);
            AddLog("Offhand Companion v" + FullVersion + " (build " +
                ((AssemblyFileVersionAttribute)Attribute.GetCustomAttribute(typeof(CompanionForm).Assembly,
                    typeof(AssemblyFileVersionAttribute))).Version + ") initialized.");
            AddLog("Settings storage: " + (isStorePackage ? "Microsoft Store package data." : "local user profile."));
#if HDR_DPI_DIAGNOSTICS_TEST
            this.Text = "Offhand Companion - HDR / DPI DIAGNOSTICS TEST 3";
            chkAutoSpan.Enabled = false;
            itemAuto.Enabled = false;
            AddLog("DIAGNOSTICS TEST 3: manual Span only; settings saved beside this test executable. Public settings are read once as defaults and never overwritten.");
#endif
            if (GraphicsRecoveryTestBuild)
                AddLog(RecoveryScope + " TEST ONLY: launch auto-span disabled; test settings isolated. Click Span WoW Now, then wait for stable-span confirmation.");
            if (isStorePackage) AddLog("Updates are managed by Microsoft Store.");
            AddLog("Monitoring active. Enable Offhand in WoW; calibrate with /offhand wizard.");
        }

        private void CheckForUpdates()
        {
            if (isStorePackage)
            {
                AddLog("Opening the official Microsoft Store page for updates...");
                try
                {
                    Process.Start(CompanionDistribution.StoreProductUri);
                }
                catch (Exception ex)
                {
                    AddLog("Could not open Microsoft Store: " + ex.Message);
                    MessageBox.Show("The Companion could not open its Microsoft Store page.\n\n" + ex.Message +
                        "\n\nOpen Microsoft Store manually and search for Offhand Companion.",
                        "Microsoft Store Unavailable", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                }
                return;
            }

            if (updateCheckInProgress) return;
            updateCheckInProgress = true;
            if (btnCheckUpdates != null) btnCheckUpdates.Enabled = false;
            AddLog("Checking GitHub for Companion updates (requested by user)...");

            System.Threading.ThreadPool.QueueUserWorkItem(_ =>
            {
                try
                {
                    System.Net.ServicePointManager.SecurityProtocol = System.Net.SecurityProtocolType.Tls12;
                    using (System.Net.WebClient wc = new System.Net.WebClient())
                    {
                        wc.Headers.Add("User-Agent", "Offhand-Companion");
                        wc.Headers.Add("Accept", "application/vnd.github+json");
                        string json = wc.DownloadString("https://api.github.com/repos/N4UX-GIT/Offhand-DualMonitor/releases?per_page=30");
                        var informational = Assembly.GetExecutingAssembly()
                            .GetCustomAttribute<AssemblyInformationalVersionAttribute>();
                        CompanionReleaseVersion current;
                        if (informational == null || !CompanionReleaseVersion.TryParse(informational.InformationalVersion, out current))
                            throw new FormatException("The installed Companion version was not recognized.");
                        CompanionUpdateRelease latest = CompanionUpdatePolicy.SelectLatest(json, current);

                        CompleteUpdateCheck(new Action(() =>
                        {
                            if (latest.Version.CompareTo(current) > 0)
                            {
                                AddLog("UPDATE AVAILABLE: " + latest.Version.Display);
                                if (MessageBox.Show("Offhand Companion " + latest.Version.Display + " is available.\n\nOpen the official GitHub release page?", "Update Available", MessageBoxButtons.YesNo, MessageBoxIcon.Information) == DialogResult.Yes)
                                    System.Diagnostics.Process.Start(latest.Url ?? "https://github.com/N4UX-GIT/Offhand-DualMonitor/releases");
                            }
                            else
                            {
                                AddLog("Companion is up to date (" + current.Display + ").");
                                MessageBox.Show("You are running the latest published Companion version.", "No Update Available", MessageBoxButtons.OK, MessageBoxIcon.Information);
                            }
                        }));
                    }
                }
                catch (Exception ex)
                {
                    CompleteUpdateCheck(new Action(() =>
                    {
                        AddLog("Update check failed: " + ex.Message);
                        MessageBox.Show("The Companion could not check the official GitHub releases.\n\n" + ex.Message + "\n\nNo automatic retry will be made.", "Update Check Failed", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    }));
                }
            });
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            if (!StoreUpdateCheck.Eligible(isStorePackage) || storeUpdateTimer != null) return;
            string build = ((AssemblyFileVersionAttribute)Attribute.GetCustomAttribute(
                typeof(CompanionForm).Assembly, typeof(AssemblyFileVersionAttribute))).Version;
            storeUpdateCache = new StoreUpdateCache(Path.Combine(Path.GetDirectoryName(configPath), "StoreUpdateCheck.ini"), build);
            try { ApplyStoreUpdateState(storeUpdateCache.Cached(DateTime.UtcNow)); }
            catch (Exception) { ApplyStoreUpdateState(StoreUpdateState.Unavailable); }
            storeUpdateTimer = new Timer { Interval = 30000 };
            storeUpdateTimer.Tick += async (s, args) =>
            {
                storeUpdateTimer.Stop();
                DateTime attempted = DateTime.UtcNow;
                try
                {
                    if (storeUpdateCache.TryClaim(attempted))
                    {
                        var result = await StoreUpdateCheck.RunAsync(
                            token => storeUpdateQuery(Handle, token), 15000, storeUpdateLifetime.Token);
                        if (IsDisposed || Disposing || isExplicitExit) return;
                        storeUpdateCache.Complete(attempted, result);
                        ApplyStoreUpdateState(result);
                    }
                    else ApplyStoreUpdateState(storeUpdateCache.Cached(attempted));
                }
                catch (Exception)
                {
                    if (!IsDisposed && !Disposing && !isExplicitExit) ApplyStoreUpdateState(StoreUpdateState.Unavailable);
                }
                if (IsDisposed || Disposing || isExplicitExit) return;
                TimeSpan delay = StoreUpdateCache.Interval;
                try { var remaining = storeUpdateCache.UntilDue(DateTime.UtcNow); if (remaining > TimeSpan.Zero) delay = remaining; }
                catch (Exception) { }
                storeUpdateTimer.Interval = (int)Math.Max(1000, Math.Min(StoreUpdateCache.Interval.TotalMilliseconds, delay.TotalMilliseconds));
                storeUpdateTimer.Start();
            };
            storeUpdateTimer.Start();
        }

        private void ApplyStoreUpdateState(StoreUpdateState state)
        {
            if (!isStorePackage || IsDisposed || Disposing) return;
            btnCheckUpdates.Text = CompanionDistribution.UpdateButtonText(true, state);
            btnCheckUpdates.AccessibleName = btnCheckUpdates.Text;
            btnCheckUpdates.AccessibleDescription = CompanionDistribution.StoreUpdateTip(state);
            btnCheckUpdates.ForeColor = state == StoreUpdateState.Available ? cGoldBright : cText;
            uiToolTips.SetToolTip(btnCheckUpdates, CompanionDistribution.StoreUpdateTip(state));
            if (itemCheckUpdates != null) itemCheckUpdates.Text = state == StoreUpdateState.Available
                ? "Update available in Microsoft Store…" : CompanionDistribution.UpdateMenuText(true);
        }

        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);
            FitDashboardToWorkingArea(Screen.FromControl(this).WorkingArea);
        }

        private int DashboardRequiredClientHeight()
        {
            return dashboardStack.GetPreferredSize(new Size(dashboardStack.Width, 0)).Height
                + dashboardScroll.Padding.Vertical + dashboardFooter.Height;
        }

        internal void FitDashboardToWorkingArea(Rectangle workArea)
        {
            if (dashboardStack == null) return;
            LayoutDashboardCards();
            float scale = btnSpanNow.Height / (float)DashboardActionHeight;
            Size desired = SizeFromClientSize(new Size((int)Math.Ceiling(548 * scale),
                DashboardRequiredClientHeight()));
            Size fitted = new Size(Math.Min(desired.Width, workArea.Width), Math.Min(desired.Height, workArea.Height));
            Bounds = new Rectangle(workArea.Left + (workArea.Width - fitted.Width) / 2,
                workArea.Top + (workArea.Height - fitted.Height) / 2, fitted.Width, fitted.Height);
            dashboardScroll.AutoScrollPosition = Point.Empty;
            PerformLayout();
            LayoutDashboardCards();
        }

        private void CompleteUpdateCheck(Action completion)
        {
            if (IsDisposed || Disposing || !IsHandleCreated) return;
            try
            {
                BeginInvoke(new Action(() =>
                {
                    updateCheckInProgress = false;
                    if (btnCheckUpdates != null) btnCheckUpdates.Enabled = true;
                    if (completion != null) completion();
                }));
            }
            catch (InvalidOperationException) { }
        }

        private void InitializeUI()
        {
            this.SuspendLayout();
            // Every coordinate below is authored against a 96-DPI baseline.
            // Explicit DPI scaling keeps the fixed dashboard geometry and its
            // fonts proportional on high-resolution and mixed-DPI displays.
            this.AutoScaleDimensions = new SizeF(96F, 96F);
            this.AutoScaleMode = AutoScaleMode.Dpi;
            this.DoubleBuffered = true;
            this.Font = new Font("Segoe UI", 9F);
            this.Text = GraphicsRecoveryTestBuild ? "Offhand Companion - " + (ForeverGraphicsRecoveryEnabled ? "FOREVER TEST 5" : RetailGraphicsRecoveryEnabled ? "RETAIL TEST 4" : "CLASSIC TEST 3") : "Offhand Companion " + FullVersion;
            this.ClientSize = new Size(548, 824);
            this.MinimumSize = new Size(500, 400);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.Sizable;
            this.MaximizeBox = true;
            this.AutoScroll = false;
            this.BackColor = cBg;
            this.ForeColor = cText;
            uiToolTips = new ToolTip
            {
                AutoPopDelay = 12000,
                InitialDelay = 450,
                ReshowDelay = 100,
                ShowAlways = true
            };
            this.Disposed += (s, e) => { if (uiToolTips != null) uiToolTips.Dispose(); };

            // Load Application Icon if available
            // Use the same executable icon in the dashboard and its dialogs.
            Icon = CompanionUi.AppIcon;

            // Header Panel
            Panel headerPanel = new Panel();
            headerPanel.Location = new Point(0, 0);
            headerPanel.Size = new Size(548, 144);
            headerPanel.BackColor = Color.FromArgb(15, 15, 18);
            headerPanel.Paint += (s, e) =>
            {
                using (Pen pen = new Pen(cBorder, 2))
                {
                    e.Graphics.DrawLine(pen, 0, headerPanel.Height - 1, headerPanel.Width, headerPanel.Height - 1);
                }
            };
            this.Controls.Add(headerPanel);

            // Header Logo
            PictureBox logoBox = new PictureBox();
            logoBox.Location = new Point(14, 9);
            logoBox.Size = new Size(74, 74);
            logoBox.SizeMode = PictureBoxSizeMode.Zoom;
            logoBox.BackColor = Color.Transparent;

            try
            {
                using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("Offhand.Companion.Resources.offhand-logo.png"))
                {
                    if (stream != null)
                    {
                        logoBox.Image = Image.FromStream(stream);
                    }
                }
            }
            catch { }

            if (logoBox.Image == null)
            {
                // Fallback to disk asset if running unpackaged
                string[] diskFallbacks = new string[] {
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, @"..\Media\offhand-icon.png"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, @"..\Media\offhand-logo.png"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, @"Media\offhand-icon.png"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, @"Media\offhand-logo.png"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, @"..\Website\assets\offhand-icon.png")
                };
                foreach (string path in diskFallbacks)
                {
                    if (File.Exists(path))
                    {
                        try { logoBox.Image = Image.FromFile(path); break; } catch { }
                    }
                }
            }
            headerPanel.Controls.Add(logoBox);

            // Title
            Label titleLabel = lblHeaderTitle = new Label();
            titleLabel.Text = "OFFHAND";
            titleLabel.Location = new Point(102, 9);
            titleLabel.Size = new Size(365, 38);
            titleLabel.Font = new Font("Georgia", 22, FontStyle.Bold);
            titleLabel.ForeColor = cGold;
            titleLabel.BackColor = Color.Transparent;
            headerPanel.Controls.Add(titleLabel);

            Label tagline = lblHeaderTagline = new Label { Text = "Dual-wield your monitors", Location = new Point(104, 47),
                Size = new Size(365, 18), Font = new Font("Segoe UI", 9, FontStyle.Bold),
                ForeColor = cText, BackColor = Color.Transparent, AccessibleName = "Brand tagline" };
            headerPanel.Controls.Add(tagline);

            // Descriptive subtitle follows the brand tagline.
            Label subLabel = lblHeaderSubtitle = new Label();
            subLabel.Text = "Multi-Monitor Companion for World of Warcraft";
            subLabel.Location = new Point(104, 67);
            subLabel.Size = new Size(365, 18);
            subLabel.Font = new Font("Segoe UI", 8.5f);
            subLabel.ForeColor = cBrass;
            subLabel.BackColor = Color.Transparent;
            headerPanel.Controls.Add(subLabel);

            // Version
            Label verLabel = lblHeaderVersion = new Label();
            verLabel.Text = HeaderVersionText(null, false);
            verLabel.AccessibleName = "Companion and detected addon versions";
            verLabel.UseMnemonic = false;
            verLabel.Location = new Point(104, 87);
            verLabel.Size = new Size(365, 14);
            verLabel.Font = new Font("Segoe UI", 7.5f, FontStyle.Italic);
            verLabel.ForeColor = cMuted;
            verLabel.BackColor = Color.Transparent;
            headerPanel.Controls.Add(verLabel);
            uiToolTips.SetToolTip(verLabel, "Addon version comes from the running WoW client's installed files. Confirm Offhand is enabled in WoW; file detection does not confirm it is loaded.");

            Button website = CreateButton("Website", 104, 86, 78, 25, cBtnBg, cText, cBorderDim);
            website.Click += (s, e) => OpenCommunityLink(CompanionDistribution.WebsiteUrl, "the Offhand website");
            headerPanel.Controls.Add(website);
            uiToolTips.SetToolTip(website, "Open the Offhand website in your default browser.");

            Button discord = CreateButton("Discord", 190, 86, 78, 25, cBtnBg, cText, cBorderDim);
            discord.Click += (s, e) => OpenCommunityLink(CompanionDistribution.DiscordUrl, "the Offhand Discord invite");
            headerPanel.Controls.Add(discord);
            uiToolTips.SetToolTip(discord, "Open the Offhand Discord invite in your default browser.");

            Button curseForge = CreateButton("CurseForge", 276, 86, 96, 25, cBtnBg, cText, cBorderDim);
            curseForge.Click += (s, e) => OpenCommunityLink(CompanionDistribution.CurseForgeUrl, "Offhand on CurseForge");
            headerPanel.Controls.Add(curseForge);
            uiToolTips.SetToolTip(curseForge, "Open the Offhand addon page on CurseForge in your default browser.");

            Button btnHelp = CreateButton("?", 470, 12, 34, 34, cBtnPrimaryBg, cGoldBright, cGold);
            btnHelp.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            btnHelp.Font = new Font("Georgia", 14, FontStyle.Bold);
            btnHelp.AccessibleName = "Companion Help and Setup Guide";
            btnHelp.Click += (s, e) => { ShowHelpDialog(); };
            headerPanel.Controls.Add(btnHelp);
            uiToolTips.SetToolTip(btnHelp, "Open the complete Companion setup, daily-use, recovery, and troubleshooting guide.");

            // Status Card
            Panel statusPanel = CreateCardPanel(16, 102, 490, 184, "System Status");
            this.Controls.Add(statusPanel);
            lblStatusSummary = new Label { Text = "Checking WoW...", AutoEllipsis = true,
                Font = new Font("Segoe UI", 8.5f), ForeColor = cMuted,
                TextAlign = ContentAlignment.MiddleLeft, UseMnemonic = false,
                AccessibleName = "System status summary" };
            statusPanel.Controls.Add(lblStatusSummary);
            lblStatusSummary.Click += (s, e) => { SetDashboardSectionExpanded(statusPanel, true, true); };

            lblWowStatus = new Label
            {
                Text = "WoW: Checking...",
                Location = new Point(0, 30),
                Size = new Size(490, 20),
                Font = new Font("Segoe UI", 9, FontStyle.Bold),
                ForeColor = cMuted
            };
            statusPanel.Controls.Add(lblWowStatus);

            lblAddonStatus = new Label
            {
                Text = "Offhand addon: Checking...",
                Location = new Point(0, 54),
                Size = new Size(490, 20),
                Font = new Font("Segoe UI", 9, FontStyle.Bold),
                ForeColor = cMuted
            };
            statusPanel.Controls.Add(lblAddonStatus);

            lblDisplayInfo = new Label
            {
                Text = "Display layout: Checking...",
                Location = new Point(10, 76),
                Size = new Size(470, 54),
                AutoSize = false,
                UseMnemonic = false,
                Font = new Font("Segoe UI", 8.5f),
                ForeColor = cMuted
            };
            statusPanel.Controls.Add(lblDisplayInfo);

            lblAddonReason = new Label
            {
                Text = "",
                Location = new Point(10, 134),
                Size = new Size(470, 42),
                AutoSize = false,
                UseMnemonic = false,
                Font = new Font("Segoe UI", 8.5f),
                ForeColor = cMuted
            };
            statusPanel.Controls.Add(lblAddonReason);

            // Ordinary display selection is kept separate from opt-in layout and launch tools.
            Panel configPanel = CreateCardPanel(16, 296, 490, 212, "Configuration");
            this.Controls.Add(configPanel);
            var configLayout = CreateDashboardGrid(configPanel, 1);
            var configLeft = CreateDashboardColumn(new Padding(0, 0, 6, 0));
            var configRight = CreateDashboardColumn(new Padding(6, 0, 0, 0));
            configLayout.Controls.Add(configLeft, 0, 0);
            configLayout.Controls.Add(configRight, 1, 0);
            Label lblMonitors = new Label { Text = "Span displays", AutoSize = true, Margin = new Padding(0, 0, 0, 6), ForeColor = cText, BackColor = Color.Transparent };
            configLeft.Controls.Add(lblMonitors);
            // Keep the checklist at a fixed logical height. CheckedListBox uses
            // IntegralHeight by default and can silently grow to the next whole
            // row; with three or more connected displays that growth overlaps
            // Mainhand controls. Four rows fit at 96 DPI and additional
            // displays scroll; the flow column positions Identify Displays
            // below the checklist using its actual scaled height.
            clbMonitors = new CheckedListBox { Size = new Size(220, 74), Margin = new Padding(0, 0, 0, 10), IntegralHeight = false, BackColor = cBtnBg, ForeColor = cText, BorderStyle = BorderStyle.FixedSingle };
            clbMonitors.CheckOnClick = true;
            uiDisplays = ReadDisplays();
            for (int i = 0; i < uiDisplays.Count; i++)
            {
                Rectangle b = uiDisplays[i].Bounds;
                clbMonitors.Items.Add(string.Format("Display {0}: {1}x{2}{3}", i + 1, b.Width, b.Height,
                    uiDisplays[i].Primary ? " (Primary)" : ""), true);
            }
            configLeft.Controls.Add(clbMonitors);

            Label lblMainhand = new Label { Text = "Mainhand (game)", Height = 22, Margin = new Padding(0, 0, 0, 4),
                TextAlign = ContentAlignment.MiddleLeft, ForeColor = cText, BackColor = Color.Transparent };
            configRight.Controls.Add(lblMainhand);
            cmbMainhand = new ComboBox { Width = 220, Margin = Padding.Empty, DropDownStyle = ComboBoxStyle.DropDownList, BackColor = cCard, ForeColor = cText };
            CompanionUi.StyleCombo(cmbMainhand);cmbMainhand.AccessibleName="Mainhand game display";
            for (int i = 0; i < uiDisplays.Count; i++)
            {
                Rectangle b = uiDisplays[i].Bounds;
                cmbMainhand.Items.Add(new DisplayChoice { Index = i, DeviceName = uiDisplays[i].DeviceName,
                    StableId = uiDisplays[i].StableId,
                    Label = string.Format("Display {0} — {1}x{2}", i + 1, b.Width, b.Height) });
            }
            configRight.Controls.Add(cmbMainhand);

            chkSingleSplit = new CheckBox { Text = "Single-display 32:9 split", Size = new Size(220, 22), Margin = new Padding(0, 12, 0, 4), Font = new Font("Segoe UI", 9), ForeColor = cText, BackColor = Color.Transparent };
            configRight.Controls.Add(chkSingleSplit);
            FlowLayoutPanel sideRow = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.LeftToRight,
                WrapContents = false,
                Size = new Size(220, 24),
                Margin = Padding.Empty,
                Padding = Padding.Empty,
                BackColor = Color.Transparent
            };
            Label lblSingleSide = new Label { Text = "Game side", Size = new Size(90, 22), Margin = Padding.Empty,
                TextAlign = ContentAlignment.MiddleLeft, AutoEllipsis = true, ForeColor = cText, BackColor = Color.Transparent };
            sideRow.Controls.Add(lblSingleSide);
            cmbSingleSide = new ComboBox { Width = 100, Margin = Padding.Empty, DropDownStyle = ComboBoxStyle.DropDownList, BackColor = cCard, ForeColor = cText };
            CompanionUi.StyleCombo(cmbSingleSide);cmbSingleSide.AccessibleName="Game side on single display";
            cmbSingleSide.Items.AddRange(new object[] { "Right", "Left" });
            cmbSingleSide.SelectedIndex = 0;
            sideRow.Controls.Add(cmbSingleSide);
            configRight.Controls.Add(sideRow);


            Button btnIdentifyDisplays = CreateButton("Identify Displays", 0, 0, 220, 30, cBtnBg, cText, cBorder);
            btnIdentifyDisplays.Margin = Padding.Empty;
            btnIdentifyDisplays.Font = new Font("Segoe UI", 8.5f, FontStyle.Bold);
            btnIdentifyDisplays.Click += (sender, args) => ShowDisplayIdentifiers();
            configLeft.Controls.Add(btnIdentifyDisplays);

            advancedPanel = CreateCardPanel(16, 510, 490, 170, "Advanced Options");
            this.Controls.Add(advancedPanel);
            var advancedLayout = CreateDashboardGrid(advancedPanel, 2);
            var layoutOptions = CreateDashboardColumn(new Padding(0, 0, 6, 8));
            var profileOptions = CreateDashboardColumn(new Padding(6, 0, 0, 8));
            var autoOptions = CreateDashboardColumn(new Padding(0, 0, 6, 0));
            var standardOptions = CreateDashboardColumn(new Padding(6, 0, 0, 0));
            advancedLayout.Controls.Add(layoutOptions, 0, 0);
            advancedLayout.Controls.Add(profileOptions, 1, 0);
            advancedLayout.Controls.Add(autoOptions, 0, 1);
            advancedLayout.Controls.Add(standardOptions, 1, 1);

            btnPartialSpan = CreateButton("Workspace layout (standard)…", 0, 0, 220, 30, cBtnBg, cText, cBorder);
            btnPartialSpan.Margin = Padding.Empty;
            btnPartialSpan.Click += (sender, args) => EditPartialSpan();
            layoutOptions.Controls.Add(btnPartialSpan);
            btnWorkspaceProfiles = CreateButton("Workspace profiles...", 0, 0, 220, 30, cBtnBg, cText, cBorder);
            btnWorkspaceProfiles.Margin = Padding.Empty;
            btnWorkspaceProfiles.Click += (sender, args) => EditWorkspaceProfiles();
            profileOptions.Controls.Add(btnWorkspaceProfiles);
            btnUseStandardLayout = CreateButton("Use standard display layout", 0, 0, 220, 30, cBtnBg, cText, cBorder);
            btnUseStandardLayout.Margin = Padding.Empty;
            btnUseStandardLayout.Click += (sender, args) => EditWorkspaceLayout(true);
            standardOptions.Controls.Add(btnUseStandardLayout);
            uiToolTips.SetToolTip(btnUseStandardLayout, "Turn off custom workspaces and review the standard display selection. Saved workspace profiles remain available. Click Span WoW Now afterward to apply.");
            chkAutoSpan = new CheckBox
            {
                Text = "Auto-span WoW on launch",
                Size = new Size(220, 22),
                Margin = new Padding(0, 0, 0, 4),
                Font = new Font("Segoe UI", 9),
                ForeColor = cText,
                BackColor = Color.Transparent,
                Checked = CompanionDefaults.AutoSpanOnLaunch
            };
            chkAutoSpan.CheckedChanged += (s, e) =>
            {
                if (itemAuto != null) itemAuto.Checked = chkAutoSpan.Checked;
                AddLog("Auto-Span on launch: " + chkAutoSpan.Checked);
            };
            autoOptions.Controls.Add(chkAutoSpan);

            FlowLayoutPanel delayRow = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.LeftToRight,
                WrapContents = false,
                Size = new Size(220, 24),
                Margin = new Padding(0, 0, 0, 4),
                Padding = Padding.Empty,
                BackColor = Color.Transparent
            };
            lblDelay = new Label { Text = "Auto-span delay (sec)", Size = new Size(130, 22), Margin = Padding.Empty,
                TextAlign = ContentAlignment.MiddleLeft, AutoEllipsis = true, ForeColor = cText, BackColor = Color.Transparent };
            delayRow.Controls.Add(lblDelay);
            numDelaySpan = new NumericUpDown { Width = 60, Minimum = 0, Maximum = 60, Value = 15, Margin = Padding.Empty, BackColor = cCard, ForeColor = cText };
            numDelaySpan.AccessibleName = "Auto-span delay in seconds";
            delayRow.Controls.Add(numDelaySpan);
            autoOptions.Controls.Add(delayRow);

            uiToolTips.SetToolTip(btnWorkspaceProfiles,"Save and manage named Multiple workspaces plans. Loading selects settings; Span WoW Now applies them.");
            uiToolTips.SetToolTip(btnPartialSpan, "Edit a custom workspace or return to a standard display layout.");

            uiToolTips.SetToolTip(chkAutoSpan,
                "Disabled by default. When enabled, Offhand spans each newly detected WoW window across the selected displays. Manual Span WoW Now remains available when disabled.");
            uiToolTips.SetToolTip(lblDelay,
                "Wait time before automatically spanning a newly detected WoW window. Use 0 for immediate pre-login spanning.");
            uiToolTips.SetToolTip(numDelaySpan,
                "Automatic-span delay for every supported WoW client (0-60 seconds). Forever no longer overrides this value.");
            uiToolTips.SetToolTip(btnIdentifyDisplays,
                "Temporarily label every connected screen with the same Display number and role used by Offhand.");
            uiToolTips.SetToolTip(lblMonitors,
                "Select every display that should form WoW's borderless virtual desktop.");
            uiToolTips.SetToolTip(clbMonitors,
                "Select exactly two displays for normal use. If a saved display is disconnected, Offhand refuses to span rather than shrinking the UI onto the remaining screen.");
            uiToolTips.SetToolTip(cmbMainhand,
                "The display that contains the 3D game view and Blizzard combat UI. The other selected display becomes the Offhand workspace.\r\n\r\n"
                + LayoutApplyInstruction);
            uiToolTips.SetToolTip(chkSingleSplit,
                "For one 32:9 or 32:10 super-ultrawide only: divide that display into a game half and workspace half. Leave disabled for ordinary single-monitor use.");
            uiToolTips.SetToolTip(cmbSingleSide,
                "Choose which half of a single super-ultrawide contains the game view.");

            string savedDevices, savedIdentities;
            bool useStableIdentities = MonitorSelection.HasSavedIdentitySettings(appSettings);
            appSettings.TryGetValue("MonitorIdentities", out savedIdentities);
            if (appSettings.TryGetValue("MonitorDevices", out savedDevices) || useStableIdentities)
            {
                string wantedValues = useStableIdentities ? savedIdentities : savedDevices;
                var wanted = new HashSet<string>((wantedValues ?? "").Split(new char[] { '|' }, StringSplitOptions.RemoveEmptyEntries), StringComparer.OrdinalIgnoreCase);
                for (int i = 0; i < clbMonitors.Items.Count; i++)
                    clbMonitors.SetItemChecked(i, useStableIdentities ? HasSelectedIdentity(wanted,uiDisplays,i) : wanted.Contains(uiDisplays[i].DeviceName ?? ""));
            }
            else if (appSettings.ContainsKey("Monitors"))
            {
                string[] saved = appSettings["Monitors"].Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
                for (int i = 0; i < clbMonitors.Items.Count; i++) clbMonitors.SetItemChecked(i, false);
                foreach (string m in saved) { int idx; if (int.TryParse(m, out idx) && idx >= 0 && idx < clbMonitors.Items.Count) clbMonitors.SetItemChecked(idx, true); }
            }

            string savedMainhand, savedMainhandIdentity;
            appSettings.TryGetValue("MainhandDevice", out savedMainhand);
            appSettings.TryGetValue("MainhandIdentity", out savedMainhandIdentity);
            for (int i = 0; i < cmbMainhand.Items.Count; i++)
            {
                var choice = (DisplayChoice)cmbMainhand.Items[i];
                if ((useStableIdentities && MonitorSelection.FindDisplay(uiDisplays,savedMainhandIdentity,null)==i)
                    || (!useStableIdentities && string.Equals(choice.DeviceName,savedMainhand,StringComparison.OrdinalIgnoreCase))) { cmbMainhand.SelectedIndex = i; break; }
            }
            if (cmbMainhand.SelectedIndex < 0 && cmbMainhand.Items.Count > 0
                && string.IsNullOrWhiteSpace(savedMainhand)&&string.IsNullOrWhiteSpace(savedMainhandIdentity))
            {
                for (int i = 0; i < uiDisplays.Count; i++)
                    if (uiDisplays[i].Primary) { cmbMainhand.SelectedIndex = i; break; }
                if (cmbMainhand.SelectedIndex < 0) cmbMainhand.SelectedIndex = 0;
            }
            chkSingleSplit.Checked = appSettings.ContainsKey("SingleDisplaySplit") && appSettings["SingleDisplaySplit"] == "True";
            if (appSettings.ContainsKey("SingleGameSide") && appSettings["SingleGameSide"].Equals("LEFT", StringComparison.OrdinalIgnoreCase)) cmbSingleSide.SelectedIndex = 1;

            cmbMainhand.SelectedIndexChanged += (s, e) => { if(!refreshingDisplayControls)displaySelectionEdited=true;SaveDisplaySettingsFromControls(); };
            chkSingleSplit.CheckedChanged += (s, e) => { if(!refreshingDisplayControls)displaySelectionEdited=true;cmbSingleSide.Enabled = chkSingleSplit.Checked; SaveDisplaySettingsFromControls(); UpdateDashboardNavigation(); };
            cmbSingleSide.SelectedIndexChanged += (s, e) => { if(!refreshingDisplayControls)displaySelectionEdited=true;SaveDisplaySettingsFromControls(); };
            clbMonitors.ItemCheck += (s, e) => {
                if (!this.IsHandleCreated||refreshingDisplayControls) return;
                displaySelectionEdited=true;
                int generation = displaySelectionGeneration;
                this.BeginInvoke(new Action(() => {
                    // ItemCheck is raised for programmatic rebuilds as well as
                    // player clicks. A rebuild advances the generation before
                    // this deferred callback runs, so only real input is saved.
                    if (!IsDisposed && generation == displaySelectionGeneration)
                        SaveDisplaySettingsFromControls();
                }));
            };
            cmbSingleSide.Enabled = chkSingleSplit.Checked;
            UpdatePartialControls();

            if (appSettings.ContainsKey("AutoSpan")) chkAutoSpan.Checked = appSettings["AutoSpan"] == "True";
            if (GraphicsRecoveryTestBuild)
            {
                // Candidate must not auto-span a launch before its scope is reviewed.
                // Do not overwrite the user's saved public Companion preference.
                chkAutoSpan.Checked = false;
                chkAutoSpan.Enabled = false;
            }
            if (appSettings.ContainsKey("DelaySpan")) numDelaySpan.Value = PreferenceFile.Delay(appSettings["DelaySpan"]);

            chkAutoSpan.CheckedChanged += (s, e) =>
            {
                if (RemoteDesktop.Read() != RemoteDesktop.State.Local) return;
                appSettings["AutoSpan"] = chkAutoSpan.Checked.ToString();
                SaveConfig();
            };
            numDelaySpan.ValueChanged += (s, e) => SaveSpanDelay();
            numDelaySpan.KeyUp += (s, e) =>
            {
                SaveSpanDelay();
                if (e.KeyCode == Keys.Enter) { e.Handled = true; this.ActiveControl = null; }
            };
            // Migrate legacy numeric monitor indices only when every saved
            // display is currently connected. Never erase evidence of a
            // disconnected display merely because Windows renumbered screens.
            if (!appSettings.ContainsKey("MonitorDevices"))
            {
                bool completeLegacySelection = true;
                string legacySelection;
                if (appSettings.TryGetValue("Monitors", out legacySelection))
                {
                    foreach (string token in legacySelection.Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries))
                    {
                        int index;
                        if (!int.TryParse(token, out index) || index < 0 || index >= uiDisplays.Count)
                        {
                            completeLegacySelection = false;
                            break;
                        }
                    }
                }
                if (completeLegacySelection) SaveDisplaySettingsFromControls();
            }


            // Action Buttons
            btnSpanNow = CreateButton("Span WoW Now", 16, 522, 158, DashboardActionHeight, cBtnPrimaryBg, cGoldBright, cGold);
            btnSpanNow.Click += (s, e) => { InvokeSpanWindow(true); };
            this.Controls.Add(btnSpanNow);
            uiToolTips.SetToolTip(btnSpanNow, "Immediately make the detected WoW window borderless and span it across the selected displays. This also resumes spanning after Restore Window.");

            Button btnRestoreNow = CreateButton("Restore Window", 182, 522, 158, DashboardActionHeight, cBtnBg, cText, cBorder);
            btnRestoreNow.FlatAppearance.BorderColor = cBorderDim;
            btnRestoreNow.Font = new Font("Segoe UI", 9);
            btnRestoreNow.Click += (s, e) => { InvokeRestoreWindow(true); };
            this.Controls.Add(btnRestoreNow);
            uiToolTips.SetToolTip(btnRestoreNow, "Return WoW to the bordered bounds remembered before spanning. Missing-display recovery still fills the surviving Mainhand. Automatic spanning pauses for that WoW process until Span WoW Now is used.");

            // Color status is advisory and never gates Span or auto-spanning.
            Panel colorPanel = CreateCardPanel(16, 570, 490, 206, "Display Diagnostics");
            this.Controls.Add(colorPanel);
            lblColorModes = new Label { Text = "Color mode: Checking...", Location = new Point(10, 28),
                Size = new Size(470, 38), Font = new Font("Segoe UI", 8.5f), ForeColor = cText, UseMnemonic = false };
            colorPanel.Controls.Add(lblColorModes);
            lblColorWarning = new Label { Text = "", Location = new Point(10, 68), Size = new Size(470, 44),
                Font = new Font("Segoe UI", 8.5f), ForeColor = cMuted, UseMnemonic = false };
            colorPanel.Controls.Add(lblColorWarning);
            lblScaleInfo = new Label { Text = "", Location = new Point(10, 116), Size = new Size(470, 34),
                Font = new Font("Segoe UI", 8.5f), ForeColor = cMuted, UseMnemonic = false };
            colorPanel.Controls.Add(lblScaleInfo);
            Button colorHelp = CreateButton("Display Troubleshooting", 10, 160, 224, 30, cBtnBg, cText, cBorderDim);
            colorHelp.Click += (s, e) => { ShowHelpDialog(true); };
            colorPanel.Controls.Add(colorHelp);
            Button colorCopy = CreateButton("Copy Display Diagnostics", 244, 160, 236, 30, cBtnBg, cText, cBorderDim);
            colorCopy.Click += (s, e) => { CopyColorDiagnostics(); };
            colorPanel.Controls.Add(colorCopy);

            // Activity Log Card
            Panel logPanel = CreateCardPanel(16, 788, 490, 200, "Activity Log");
            this.Controls.Add(logPanel);

            logBox = new RichTextBox
            {
                Location = new Point(4, 28),
                Size = new Size(482, 166),
                BackColor = cLogBg,
                ForeColor = cLogText,
                BorderStyle = BorderStyle.None,
                Font = new Font("Consolas", 8.5f),
                ReadOnly = true,
                DetectUrls = false,
                ScrollBars = RichTextBoxScrollBars.Vertical,
                WordWrap = true,
                TabStop = false
            };
            logPanel.Controls.Add(logBox);

            // Footer Buttons
            Button btnMinimize = CreateButton("Minimize to Tray", 16, 1000, 152, 30, cBtnBg, cMuted, cBorderDim);
            btnMinimize.Click += (s, e) =>
            {
                this.ShowInTaskbar = false;
                this.Hide();
                trayIcon.ShowBalloonTip(2000, "Offhand Running in Tray", "Monitoring in background. Double-click tray icon to restore.", ToolTipIcon.Info);
            };
            this.Controls.Add(btnMinimize);
            uiToolTips.SetToolTip(btnMinimize, "Hide the dashboard while keeping the Companion and launch monitor running in the Windows notification tray.");

            btnCheckUpdates = CreateButton(CompanionDistribution.UpdateButtonText(isStorePackage), 182, 1000, 158, 30, cBtnBg, cText, cBorder);
            btnCheckUpdates.Click += (s, e) => { CheckForUpdates(); };
            this.Controls.Add(btnCheckUpdates);
            uiToolTips.SetToolTip(btnCheckUpdates, isStorePackage
                ? CompanionDistribution.StoreUpdateTip(StoreUpdateState.NotChecked)
                : "Contact the official GitHub Releases API once to compare versions. The Companion never checks for updates automatically.");

            Button btnExit = CreateButton("Exit Companion", 356, 1000, 152, 30, cBtnDanger, Color.FromArgb(235, 130, 130), Color.FromArgb(140, 45, 45));
            btnExit.Click += (s, e) => { ExitApplication(); };
            this.Controls.Add(btnExit);
            uiToolTips.SetToolTip(btnExit, "Stop monitoring and fully exit the Companion. Closing the title-bar X only minimizes it to the tray.");

            ArrangeDashboard(headerPanel, statusPanel, configPanel, advancedPanel, colorPanel, logPanel,
                new Control[] { btnSpanNow, btnRestoreNow },
                new Control[] { btnMinimize, btnCheckUpdates, btnExit });
            CompanionUi.StyleScrollbars(this);

            this.FormClosing += (s, e) =>
            {
                if (!isExplicitExit && e.CloseReason == CloseReason.UserClosing)
                {
                    e.Cancel = true;
                    this.ShowInTaskbar = false;
                    this.Hide();
                    trayIcon.ShowBalloonTip(1500, "Offhand Minimized", "Running in System Tray. Right-click or double-click to control.", ToolTipIcon.Info);
                }
            };
            this.ResumeLayout(false);
        }

        private TableLayoutPanel DashboardButtonRow(Control[] buttons, int height)
        {
            var row = new TableLayoutPanel { Height = height, ColumnCount = buttons.Length, RowCount = 1,
                Dock = DockStyle.Top, Margin = Padding.Empty, Padding = Padding.Empty, BackColor = cBg };
            row.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            for (int i = 0; i < buttons.Length; i++)
            {
                row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f / buttons.Length));
                buttons[i].Dock = DockStyle.Fill;
                buttons[i].Margin = new Padding(0, 0, i + 1 == buttons.Length ? 0 : 10, 0);
                row.Controls.Add(buttons[i], i, 0);
            }
            return row;
        }

        private void ArrangeDashboard(Panel header, Panel status, Panel config, Panel advanced, Panel diagnostics, Panel log,
            Control[] actions, Control[] footer)
        {
            SuspendLayout();
            dashboardHeader = header;
            configurationPanel = config;
            diagnosticsPanel = diagnostics;
            activityPanel = log;
            dashboardNavigation = new TableLayoutPanel { Height = 38, ColumnCount = 2, RowCount = 1,
                Margin = Padding.Empty, Padding = Padding.Empty, BackColor = cBg, AccessibleName = "Companion navigation",
                AccessibleRole = AccessibleRole.PageTabList };
            dashboardNavigation.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 40));
            dashboardNavigation.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 60));
            dashboardNavigation.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            setupTab = CreateButton("Setup", 0, 0, 190, 38, cBtnBg, cText, cBorder);
            advancedTab = CreateButton("Advanced", 0, 0, 280, 38, cBtnBg, cText, cBorder);
            setupTab.Dock = advancedTab.Dock = DockStyle.Fill;
            setupTab.Margin = new Padding(0, 0, 6, 0);
            advancedTab.Margin = new Padding(6, 0, 0, 0);
            setupTab.AccessibleRole = advancedTab.AccessibleRole = AccessibleRole.PageTab;
            setupTab.Click += (sender, args) => SelectDashboardPage(false);
            advancedTab.Click += (sender, args) => SelectDashboardPage(true);
            foreach (Button tab in new[] { setupTab, advancedTab }) {
                tab.FlatAppearance.BorderSize = 0;
                tab.FlatAppearance.MouseOverBackColor = Color.FromArgb(24, 24, 28);
                tab.FlatAppearance.MouseDownBackColor = Color.FromArgb(29, 29, 33);
                tab.Paint += (sender, args) => {
                    if ((tab == advancedTab) != advancedPage) return;
                    float scale = btnSpanNow.Height / (float)DashboardActionHeight;
                    using (var pen = new Pen(cGold, Math.Max(2, 2 * scale)))
                        args.Graphics.DrawLine(pen, 0, tab.Height - pen.Width / 2, tab.Width, tab.Height - pen.Width / 2);
                };
                tab.PreviewKeyDown += (sender, args) => {
                    if (args.KeyCode == Keys.Left || args.KeyCode == Keys.Right || args.KeyCode == Keys.Home || args.KeyCode == Keys.End)
                        args.IsInputKey = true;
                };
                tab.KeyDown += (sender, args) => {
                    if (args.KeyCode != Keys.Left && args.KeyCode != Keys.Right && args.KeyCode != Keys.Home && args.KeyCode != Keys.End) return;
                    bool selectAdvanced = args.KeyCode == Keys.Right || args.KeyCode == Keys.End;
                    SelectDashboardPage(selectAdvanced);
                    (selectAdvanced ? advancedTab : setupTab).Focus();
                    args.Handled = args.SuppressKeyPress = true;
                };
            }
            dashboardNavigation.Controls.Add(setupTab, 0, 0);
            dashboardNavigation.Controls.Add(advancedTab, 1, 0);
            setupGuide = new Panel { BackColor = cCard, Height = 230, AccessibleName = "Apply your layout guide" };
            setupGuide.Controls.Add(new Label { Text = "APPLY YOUR LAYOUT", ForeColor = cGold,
                Font = new Font("Segoe UI", 9, FontStyle.Bold), Location = new Point(14, 12), Size = new Size(450, 22) });
            setupGuideSteps = new Label[6];
            for (int i = 0; i < setupGuideSteps.Length; i++) {
                var step = new Label { AutoSize = false, ForeColor = i < 4 ? cText : cMuted,
                    Font = new Font("Segoe UI", 9), UseMnemonic = false, AccessibleName = "Setup guidance " + (i + 1) };
                setupGuideSteps[i] = step;
                setupGuide.Controls.Add(step);
            }
            dashboardScroll = new DashboardViewport { Dock = DockStyle.Fill, AutoScroll = true, Padding = new Padding(16, 10, 16, 6), BackColor = cBg };
            dashboardStack = new DashboardStack { Location = new Point(16, 10), AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink, ColumnCount = 1, RowCount = 0,
                Margin = Padding.Empty, Padding = Padding.Empty, BackColor = cBg };
            dashboardStack.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            var actionRow = DashboardButtonRow(actions, DashboardActionHeight);
            actionRow.ColumnStyles[0].Width = 64;
            actionRow.ColumnStyles[1].Width = 36;
            var actionPanel = new TableLayoutPanel { AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink,
                ColumnCount = 2, RowCount = 2, Margin = Padding.Empty, Padding = Padding.Empty, BackColor = cBg };
            actionPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 64));
            actionPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 36));
            actionPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            actionPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            actionPanel.Controls.Add(actionRow, 0, 0);
            actionPanel.SetColumnSpan(actionRow, 2);
            actionPanel.Controls.Add(new Label { AutoSize = true, Dock = DockStyle.Fill,
                Margin = new Padding(0, 6, 10, 0), ForeColor = cMuted, Font = new Font("Segoe UI", 8.5f),
                Text = "Apply layout, then type /reload in WoW.", AccessibleName = "Span guidance",
                UseMnemonic = false }, 0, 1);
            actionPanel.Controls.Add(new Label { AutoSize = true, Dock = DockStyle.Fill,
                Margin = new Padding(0, 6, 0, 0), ForeColor = cMuted, Font = new Font("Segoe UI", 8.5f),
                Text = "Return to the previous window.", AccessibleName = "Restore guidance",
                UseMnemonic = false }, 1, 1);
            foreach (Control item in new Control[] { header, dashboardNavigation, actionPanel, status, config, setupGuide, advanced, diagnostics, log })
            {
                item.Dock = DockStyle.Top;
                item.Margin = new Padding(0, 0, 0, 10);
                dashboardStack.RowCount++;
                dashboardStack.RowStyles.Add(new RowStyle(SizeType.AutoSize));
                dashboardStack.Controls.Add(item, 0, dashboardStack.RowCount - 1);
            }
            dashboardNavigation.Margin = new Padding(0, 0, 0, 18);
            foreach (Control child in header.Controls)
            {
                if (child is Label) child.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
            }
            dashboardFooter = DashboardButtonRow(footer, 56);
            dashboardFooter.Dock = DockStyle.Bottom;
            dashboardFooter.Padding = new Padding(16, 8, 16, 12);
            dashboardScroll.Controls.Add(dashboardStack);
            Controls.Add(dashboardScroll);
            Controls.Add(dashboardFooter);
            dashboardFooter.BringToFront();
            dashboardScroll.BringToFront();
            foreach (var section in dashboardSections.Values)
            {
                if (section.Panel == config || section.Panel == advanced) {
                    section.CanCollapse = false;
                    section.Expanded = true;
                    section.Toggle.Visible = false;
                }
                bool collapsed = section.Panel != config;
                string saved;
                bool parsed;
                if (appSettings.TryGetValue(section.Key, out saved) && bool.TryParse(saved, out parsed)) collapsed = parsed;
                SetDashboardSectionExpanded(section.Panel, !collapsed, false);
                section.Panel.SizeChanged += (s, e) => { LayoutDashboardCards(); };
            }
            foreach (Label label in new[] { lblWowStatus, lblAddonStatus, lblDisplayInfo, lblAddonReason,
                lblColorModes, lblColorWarning, lblScaleInfo })
                label.TextChanged += (s, e) =>
                {
                    UpdateDashboardStatusSummary();
                    LayoutDashboardCards();
                };
            lblDisplayInfo.ForeColorChanged += (s, e) => { UpdateDashboardStatusSummary(); };
            dashboardStack.Layout += (s, e) => { LayoutDashboardCards(); };
            dashboardScroll.SizeChanged += (s, e) => { LayoutDashboardCards(); };
            SelectDashboardPage(false);
            ResumeLayout(true);
            LayoutDashboardCards();
        }

        internal void SelectDashboardPage(bool showAdvanced)
        {
            if (dashboardScroll == null) return;
            dashboardScroll.SuspendLayout();
            dashboardStack.SuspendLayout();
            try {
                advancedPage = showAdvanced;
                configurationPanel.Visible = setupGuide.Visible = !showAdvanced;
                advancedPanel.Visible = diagnosticsPanel.Visible = activityPanel.Visible = showAdvanced;
                UpdateDashboardNavigation();
                dashboardScroll.AutoScrollPosition = Point.Empty;
            }
            finally {
                dashboardStack.ResumeLayout(true);
                dashboardScroll.ResumeLayout(true);
            }
            LayoutDashboardCards();
        }

        private void UpdateDashboardNavigation()
        {
            if (setupTab == null) return;
            bool custom = IsCustomSelection();
            advancedTab.Text = custom ? "Advanced · Custom layout active" : "Advanced";
            foreach (Button tab in new[] { setupTab, advancedTab }) {
                bool selected = (tab == advancedTab) == advancedPage;
                tab.BackColor = cBg;
                tab.ForeColor = selected ? cText : cMuted;
                tab.Invalidate();
                tab.AccessibleName = tab == setupTab ? "Setup tab" : "Advanced tab";
                tab.AccessibleDescription = (selected ? "Selected. " : "") + (tab == advancedTab
                    ? "Workspace layouts, profiles, automatic spanning, diagnostics and activity log. " + (custom ? "Custom layout active." : "")
                    : "Display selection and setup guidance. Switching tabs does not change your saved layout.");
            }
            setupGuideSteps[0].Text = custom
                ? "1. Review your custom layout in Advanced > Workspace layout."
                : chkSingleSplit.Checked ? "1. Select your ultrawide under Span displays and enable Single-display 32:9 split."
                : "1. Choose your displays. Select both screens under Span displays.";
            setupGuideSteps[1].Text = custom
                ? "2. Check the game and workspace areas in the preview, then save your plan."
                : chkSingleSplit.Checked ? "2. Choose Game side. The other half becomes your Offhand workspace."
                : "2. Choose Mainhand (game). The other screen becomes your Offhand workspace.";
            setupGuideSteps[2].Text = "3. Enable Offhand and log into a character. Choose Windowed mode, not Windowed (Fullscreen), then click Span WoW Now.";
            setupGuideSteps[3].Text = "4. In WoW, type /reload after spanning or changing the layout.";
            setupGuideSteps[4].Text = "First time? Type /offhand guide and choose Companion. Follow Reload UI, Confirm placement and Start Calibration. Complete calibration, then follow Create Mainhand HUD Layout and reload prompts when offered.";
            setupGuideSteps[5].Text = "For custom workspace areas, saved profiles and automatic spanning, open Advanced.";
            if (custom) setupGuideSteps[5].Text = "To turn off custom workspaces, open Advanced > Use standard display layout.";
            LayoutDashboardCards();
        }

        internal void SetDashboardSectionExpanded(Panel panel, bool expanded, bool persist)
        {
            DashboardSection section;
            if (!dashboardSections.TryGetValue(panel, out section)) return;
            if (!section.CanCollapse) expanded = true;
            dashboardScroll.SuspendLayout();
            panel.SuspendLayout();
            try
            {
                section.Expanded = expanded;
                section.Toggle.Text = expanded ? "Hide" : "Show";
                section.Toggle.AccessibleName = (expanded ? "Collapse " : "Expand ") + section.Heading.Text.Trim();
                foreach (Control child in panel.Controls)
                    if (child == lblStatusSummary) child.Visible = !expanded;
                    else if (child != section.Heading && child != section.Toggle) child.Visible = expanded;
                LayoutDashboardCards();
            }
            finally
            {
                panel.ResumeLayout(false);
                dashboardScroll.ResumeLayout(true);
            }
            if (persist && section.CanCollapse)
            {
                appSettings[section.Key] = (!expanded).ToString();
                SaveConfig();
            }
        }

        private int LayoutDashboardLabels(Panel panel, Label[] labels, float scale)
        {
            int y = (int)Math.Ceiling(40 * scale);
            int inset = (int)Math.Ceiling(14 * scale);
            int gap = (int)Math.Ceiling(5 * scale);
            foreach (var label in labels)
            {
                label.Visible = !string.IsNullOrEmpty(label.Text);
                int height = string.IsNullOrEmpty(label.Text) ? 0 : TextRenderer.MeasureText(label.Text, label.Font,
                    new Size(Math.Max(1, panel.Width - 2 * inset), int.MaxValue), TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix).Height;
                label.SetBounds(inset, y, Math.Max(1, panel.Width - 2 * inset), height);
                if (height > 0) y += height + gap;
            }
            return Math.Max((int)Math.Ceiling(40 * scale), y - gap);
        }

        private static FlowLayoutPanel CreateDashboardColumn(Padding margin)
        {
            return new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown,
                WrapContents = false, Margin = margin, Padding = Padding.Empty, BackColor = Color.Transparent };
        }

        private static int MeasureDashboardColumn(FlowLayoutPanel column, float scale)
        {
            int contentHeight = 0;
            column.SuspendLayout();
            int width = Math.Max(1, column.ClientSize.Width);
            foreach (Control item in column.Controls)
            {
                if (!item.AutoSize) item.Width = width;
                var fieldRow = item as FlowLayoutPanel;
                if (fieldRow == null) continue;
                var caption = (Label)fieldRow.Controls[0];
                var field = fieldRow.Controls[1];
                int gap = (int)Math.Ceiling(8 * scale);
                fieldRow.SuspendLayout();
                field.Width = (int)Math.Ceiling((field is NumericUpDown ? 64 : 104) * scale);
                field.Margin = new Padding(gap, 0, 0, 0);
                caption.Width = Math.Max(1, width - field.Width - gap);
                caption.Height = Math.Max(caption.PreferredHeight, field.Height);
                fieldRow.Height = caption.Height;
                fieldRow.ResumeLayout(true);
            }
            column.ResumeLayout(true);
            foreach (Control item in column.Controls)
                contentHeight = Math.Max(contentHeight, item.Bottom + item.Margin.Bottom);
            return contentHeight + column.Margin.Vertical;
        }

        private TableLayoutPanel CreateDashboardGrid(Panel panel, int rows)
        {
            var table = new TableLayoutPanel { Location = new Point(14, 40), Size = new Size(462, 150),
                ColumnCount = 2, RowCount = rows, Margin = Padding.Empty, Padding = Padding.Empty, BackColor = Color.Transparent };
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            for (int row=0; row<rows; row++) table.RowStyles.Add(new RowStyle(SizeType.Absolute, 50));
            panel.Controls.Add(table);
            return table;
        }

        private void LayoutDashboardConfiguration(Panel panel, TableLayoutPanel table, int inset, float scale)
        {
            table.SetBounds(inset, (int)Math.Ceiling(40 * scale), Math.Max(1, panel.Width - 2 * inset), table.Height);
            table.PerformLayout();
            if (table.Contains(clbMonitors)) {
                var displayCaption=(Label)clbMonitors.Parent.Controls[0];
                var gameCaption=(Label)cmbMainhand.Parent.Controls[0];
                displayCaption.AutoSize=false;
                displayCaption.Height=gameCaption.Height=(int)Math.Ceiling(22*scale);
                gameCaption.Margin=new Padding(0,0,0,(int)Math.Ceiling(6*scale));
            }
            int height=0;
            for (int row=0; row<table.RowCount; row++)
            {
                int rowHeight = Math.Max(
                    MeasureDashboardColumn((FlowLayoutPanel)table.GetControlFromPosition(0, row), scale),
                    MeasureDashboardColumn((FlowLayoutPanel)table.GetControlFromPosition(1, row), scale));
                table.RowStyles[row].Height=rowHeight;
                height+=rowHeight;
            }
            table.Height=height;
            panel.Height=table.Bottom+inset;
        }

        private void LayoutDashboardCards()
        {
            if (dashboardStack == null || layingOutDashboard) return;
            layingOutDashboard = true;
            try
            {
                float scale = btnSpanNow.Height / (float)DashboardActionHeight;
                // Reserve the native scrollbar gutter even while it is hidden.
                // Dock=Top would otherwise resize every card when WS_VSCROLL
                // changes the viewport's client width during Show/Hide.
                int width = Math.Max(1, dashboardScroll.Width - dashboardScroll.Padding.Horizontal
                    - CompanionUi.ScrollbarGutter(scale));
                dashboardStack.MinimumSize = new Size(width, 0);
                dashboardStack.MaximumSize = new Size(width, 0);
                dashboardStack.Width = width;
                dashboardStack.PerformLayout();
                dashboardStack.SuspendLayout();
                int inset = (int)Math.Ceiling(14 * scale);
                foreach (Control child in dashboardHeader.Controls)
                {
                    if (child is Button && (child.Anchor & AnchorStyles.Right) != 0)
                        child.Left = dashboardHeader.Width - child.Width - inset;
                    else if (child is Label) child.Width = Math.Max(1, dashboardHeader.Width - child.Left - inset
                        - (child.Top < (int)Math.Ceiling(40 * scale) ? (int)Math.Ceiling(44 * scale) : 0));
                }
                if (lblHeaderVersion != null) {
                    int headerGap = (int)Math.Ceiling(2 * scale);
                    lblHeaderTagline.Top = lblHeaderTitle.Bottom + headerGap;
                    lblHeaderSubtitle.Top = lblHeaderTagline.Bottom + headerGap;
                    lblHeaderVersion.Top = lblHeaderSubtitle.Bottom + headerGap;
                    lblHeaderVersion.Height = TextRenderer.MeasureText(lblHeaderVersion.Text, lblHeaderVersion.Font,
                        new Size(lblHeaderVersion.Width, int.MaxValue), TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix).Height;
                    int bottom = lblHeaderVersion.Bottom;
                    foreach (Control link in dashboardHeader.Controls) {
                        if (!(link is Button)) continue;
                        if (link.Text != "Website" && link.Text != "Discord" && link.Text != "CurseForge") continue;
                        link.Top = lblHeaderVersion.Bottom + (int)Math.Ceiling(6 * scale);
                        bottom = Math.Max(bottom, link.Bottom);
                    }
                    dashboardHeader.Height = bottom + inset;
                }
                foreach (var section in dashboardSections.Values)
                {
                    Panel panel = section.Panel;
                    section.Toggle.Left = panel.Width - section.Toggle.Width - inset;
                    section.Heading.SetBounds(inset, (int)Math.Ceiling(6 * scale),
                        Math.Max(1, (section.CanCollapse ? section.Toggle.Left : panel.Width) - 2 * inset), (int)Math.Ceiling(22 * scale));
                    if (panel.Controls.Contains(lblStatusSummary) && !section.Expanded)
                    {
                        section.Heading.Width = (int)Math.Ceiling(128 * scale);
                        int left = section.Heading.Right + (int)Math.Ceiling(8 * scale);
                        lblStatusSummary.SetBounds(left, section.Heading.Top,
                            Math.Max(1, section.Toggle.Left - inset - left), section.Heading.Height);
                    }
                    if (!section.Expanded) { panel.Height = (int)Math.Ceiling(34 * scale); continue; }
                    if (panel.Controls.Contains(lblWowStatus))
                    {
                        int bottom = LayoutDashboardLabels(panel, new[] { lblWowStatus, lblAddonStatus, lblDisplayInfo, lblAddonReason }, scale);
                        panel.Height = bottom + inset;
                    }
                    else if (panel.Controls.Contains(lblColorModes))
                    {
                        int bottom = LayoutDashboardLabels(panel, new[] { lblColorModes, lblColorWarning, lblScaleInfo }, scale);
                        var buttons = new List<Button>();
                        foreach (Control child in panel.Controls) if (child is Button && child != section.Toggle) buttons.Add((Button)child);
                        buttons.Sort((a, b) => a.Left.CompareTo(b.Left));
                        int gap = (int)Math.Ceiling(12 * scale);
                        int available = Math.Max(2, panel.Width - 2 * inset - gap);
                        int y = bottom + gap;
                        int height = (int)Math.Ceiling(32 * scale);
                        buttons[0].SetBounds(inset, y, available / 2, height);
                        buttons[1].SetBounds(inset + available / 2 + gap, y, available - available / 2, height);
                        panel.Height = y + height + inset;
                    }
                    else if (panel.Controls.Contains(logBox))
                    {
                        panel.Height = (int)Math.Ceiling(168 * scale);
                        int top = (int)Math.Ceiling(40 * scale);
                        logBox.SetBounds(inset, top, Math.Max(1, panel.Width - 2 * inset),
                            panel.Height - top - inset);
                    }
                    else
                    {
                        foreach (Control child in panel.Controls)
                            if (child is TableLayoutPanel)
                                LayoutDashboardConfiguration(panel, (TableLayoutPanel)child, inset, scale);
                    }
                }
                if (setupGuide != null) {
                    var title = (Label)setupGuide.Controls[0];
                    title.SetBounds(inset, (int)Math.Ceiling(12 * scale), Math.Max(1, setupGuide.Width - 2 * inset), (int)Math.Ceiling(22 * scale));
                    int y = (int)Math.Ceiling(42 * scale);
                    foreach (Label step in setupGuideSteps) {
                        int available = Math.Max(1, setupGuide.Width - 2 * inset);
                        int height = TextRenderer.MeasureText(step.Text, step.Font, new Size(available, int.MaxValue),
                            TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix).Height;
                        step.SetBounds(inset, y, available, height);
                        y += height + (int)Math.Ceiling(9 * scale);
                    }
                    setupGuide.Height = y - (int)Math.Ceiling(9 * scale) + inset;
                }
            }
            finally
            {
                dashboardStack.ResumeLayout(true);
                dashboardScroll.AutoScrollMinSize = new Size(0, dashboardStack.Height + dashboardScroll.Padding.Vertical);
                layingOutDashboard = false;
            }
        }

        private Panel CreateCardPanel(int x, int y, int w, int h, string title)
        {
            Panel panel = new Panel
            {
                Location = new Point(x, y),
                Size = new Size(w, h),
                BackColor = cCard
            };

            Label lblTitle = new Label
            {
                Text = title.ToUpperInvariant(),
                Location = new Point(14, 6),
                Size = new Size(w, 20),
                Font = new Font("Segoe UI", 8.5f, FontStyle.Bold),
                TextAlign = ContentAlignment.MiddleLeft,
                ForeColor = cGold
            };
            panel.Controls.Add(lblTitle);
            var toggle = CreateButton("Hide", w - 78, 6, 64, 22, cCard, cGold, cBorderDim);
            toggle.Font = new Font("Segoe UI", 8, FontStyle.Bold);
            toggle.AccessibleName = "Collapse " + title;
            toggle.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            panel.Controls.Add(toggle);
            var section = new DashboardSection { Panel = panel, Heading = lblTitle, Toggle = toggle,
                Key = "DashboardCollapsed." + title.Replace(" ", "") };
            dashboardSections.Add(panel, section);
            toggle.Click += (s, e) => { SetDashboardSectionExpanded(panel, !section.Expanded, true); };
            lblTitle.Click += (s, e) => { if (section.CanCollapse) SetDashboardSectionExpanded(panel, !section.Expanded, true); };

            panel.Paint += (s, e) =>
            {
                using (Pen pen = new Pen(cBorderDim, 1))
                {
                    e.Graphics.DrawRectangle(pen, 0, 0, panel.ClientSize.Width - 1, panel.ClientSize.Height - 1);
                }
                if (section.Expanded)
                {
                    int divider = Math.Max(lblTitle.Bottom, toggle.Bottom) + lblTitle.Top / 2;
                    using (Pen penDim = new Pen(cBorderDim, 1))
                        e.Graphics.DrawLine(penDim, lblTitle.Left, divider, toggle.Right, divider);
                }
            };

            return panel;
        }

        private Button CreateButton(string text, int x, int y, int w, int h, Color bg, Color fg, Color border)
        {
            Button btn = new Button
            {
                Text = text,
                Location = new Point(x, y),
                Size = new Size(w, h),
                FlatStyle = FlatStyle.Flat,
                BackColor = bg,
                ForeColor = fg,
                Font = new Font("Segoe UI", 9, FontStyle.Bold),
                Cursor = Cursors.Hand
            };
            btn.FlatAppearance.BorderSize = 1;
            btn.FlatAppearance.BorderColor = border;
            btn.UseVisualStyleBackColor=false;
            btn.FlatAppearance.MouseOverBackColor=Color.FromArgb(53,48,37);
            btn.FlatAppearance.MouseDownBackColor=Color.FromArgb(69,57,32);
            btn.AccessibleName=text.Replace("&","");
            CompanionUi.StyleDisabledButton(btn);
            return btn;
        }

        private void OpenCommunityLink(string url, string destination)
        {
            try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); }
            catch (System.ComponentModel.Win32Exception)
            {
                MessageBox.Show(this, "Windows could not open " + destination + ". Open this address in your browser:\r\n\r\n" + url,
                    "Offhand Companion", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }

        private void AppendHelpSection(RichTextBox guide, Font sectionFont, string title, params string[] paragraphs)
        {
            if (guide.TextLength > 0) guide.AppendText("\n");
            guide.SelectionFont = sectionFont;
            guide.SelectionColor = cGoldBright;
            guide.AppendText(title + "\n");
            guide.SelectionFont = guide.Font;
            guide.SelectionColor = cText;
            guide.AppendText(string.Join("\n\n", paragraphs) + "\n");
        }

        private void FillSetupHelp(RichTextBox guide, Font sectionFont)
        {
            AppendHelpSection(guide, sectionFont, "First-time setup",
                "1. Start WoW with the Offhand addon enabled. In WoW's Graphics options, select Windowed and click Apply. WoW should have a movable title bar.",
                "2. Enter the game world and type /offhand guide in chat. Choose Use Companion when the guide asks for a setup method. Continue to the window placement step.",
                "3. In Companion, leave Auto-span WoW on launch off for setup. Choose the layout you want, then click Span WoW Now. See Choose a display layout below for the available options.",
                "4. Return to the in-game guide. Click Reload UI, then Confirm placement. Follow the Auto-Setup Wizard to finish calibration.",
                "5. On Retail and Forever, finish with Create Mainhand HUD Layout. Leave combat, close Edit Mode, and click the button. Reload when prompted. Wait for layout creation to succeed before moving your panels.");

            AppendHelpSection(guide, sectionFont, "Confirm saved displays",
                "If System Status asks you to confirm your saved displays, open WoW and click Span WoW Now. Check the game and workspace screens in the dialog.",
                "Click OK to save the screen selection and proceed with spanning. If a screen is wrong, click Cancel. Use Identify Displays to match the screen numbers to your monitors, then correct Span displays and Mainhand (game) or open Advanced > Workspace layout to edit a saved custom layout. Click Span WoW Now again when ready.");

            AppendHelpSection(guide, sectionFont, "Choose a display layout",
                "Two full displays. Check both screens under Span displays and pick Mainhand (game). The other screen becomes your Offhand workspace.",
                "One super-ultrawide. For an equal split on a 32:9 or 32:10 display, check only that screen, enable Single-display 32:9 split, and choose Game side.",
                "Advanced > Workspace layout. Choose One monitor for a full-height game and workspace split, Two monitors for a full game screen and a rectangular workspace, or Multiple workspaces for a full game screen plus one or two workspaces on separate displays.",
                "Flexible layout (prototype). Use presets or enter the game and workspace rectangles to place one or two workspaces on the same physical display. " + WorkspaceEditorLayout.FlexibleAddon);

            AppendHelpSection(guide, sectionFont, "Edit and reuse custom workspaces",
                "In custom editors with a visual picker, click Select area on monitor. Drag to move the area or drag its edges to resize. Use the arrow keys to move, Ctrl + arrow keys to move one pixel, or Shift + arrow keys to resize. Press Enter to accept the area or Esc to return to the editor.",
                "Check the preview and click Save plan to keep your settings. Click Span WoW Now to resize the game window, then reload the WoW UI once.",
                "To turn off custom workspaces, open Advanced and click Use standard display layout. The Advanced tab indicates when a custom layout is active, including while viewing Setup. Review the suggested displays before saving. Named profiles stay saved.",
                "Open Advanced > Workspace profiles to manage named Multiple workspaces plans. To switch plans, pick a profile, click Load selected, then click Save changes. Click Span WoW Now and reload in WoW. Use the in-game Profiles tab for addon panel layouts and theme choices.");

            AppendHelpSection(guide, sectionFont, "Daily use",
                "Click Span WoW Now after the game window opens. For standard display layouts, open Advanced to enable Auto-span WoW on launch and set a delay. It is off by default. For custom layouts, use Span WoW Now each time.",
                "Restore Window returns WoW to its pre-span window and suspends auto-span for that WoW session. Click Span WoW Now to apply the layout again. To stop background launch detection, right-click the Companion tray icon and select Pause background monitoring. Manual Span and Restore remain available.",
                "The title-bar X minimizes Companion to the tray. Exit Companion closes it and leaves the current WoW window spanned. Keep Companion open for auto-span, automatic display-disconnect recovery, or to restore the remembered window bounds.",
                "In Remote Desktop, click Span WoW Now and choose the game and workspace screens for that connection. Keep Companion running for Restore Window and confirm the screens again after reconnecting.");

            AppendHelpSection(guide, sectionFont, "Recover your window or panels",
                "If a display is missing, reconnect it before spanning again. Use Restore Window to bring the game back to a usable window.",
                "If addon panels are out of reach, open Offhand's Recovery & Preview and use Gather Off-Screen UI or Gather Safe UI to Mainhand. To rebuild the game HUD, leave combat, close Edit Mode, and choose Create Mainhand HUD Layout. Reload when prompted.",
                "On Forever, if Offhand offers Use Modern after a display disconnect, use it until you can reconnect and reapply the saved span. Then choose Restore Offhand. After making personal Edit Mode changes, choose Use Current Edit Mode Layout in Recovery & Preview. Keep Companion running through shutdown when Forever needs the compatibility bridge to restore its layout on the next launch.");

            AppendHelpSection(guide, sectionFont, "Troubleshooting",
                "If the game view still fills the entire window after a reload, check that the Offhand addon is enabled for that WoW client and matches your Companion package. Open Activity Log for the installation path and any span or file-permission errors.",
                "If the screen arrangement looks wrong, match the monitor positions in Windows Display Settings to your desk. For color or scale issues, use Display Troubleshooting and Copy Display Diagnostics on the dashboard.",
                "If Windows reports error 5 when spanning, close both apps and launch Battle.net, WoW, and Companion at the same privilege level.");

            AppendHelpSection(guide, sectionFont, "Updates and privacy",
                CompanionDistribution.UpdateHelpText(isStorePackage),
                CompanionDistribution.PrivacyNetworkText(isStorePackage),
                "Website, Discord, and CurseForge open in your default browser when you click their buttons.");
        }

        internal Form CreateHelpDialog(bool displayTroubleshooting)
        {
            string title = displayTroubleshooting ? "Display Troubleshooting" : "Setup and Help";
            var help = new Form
            {
                Text = displayTroubleshooting ? title : "Offhand Companion Help",
                StartPosition = FormStartPosition.CenterParent,
                AutoScaleDimensions = new SizeF(96F, 96F),
                AutoScaleMode = AutoScaleMode.Dpi,
                Size = new Size(740, 710),
                MinimumSize = new Size(540, 430),
                BackColor = cBg,
                ForeColor = cText,
                MinimizeBox = false,
                ShowInTaskbar = false
            };
            if (Icon != null) help.Icon = Icon;
            help.Load += (s, e) => CompanionUi.Fit(help, Screen.FromControl(this).WorkingArea);

            var heading = new Label
            {
                Text = title,
                Dock = DockStyle.Top,
                Height = 56,
                Padding = new Padding(22, 0, 12, 0),
                TextAlign = ContentAlignment.MiddleLeft,
                Font = new Font("Georgia", 15, FontStyle.Bold),
                ForeColor = cGoldBright,
                BackColor = cCard
            };
            var footer = new Panel { Dock = DockStyle.Bottom, Height = 56, Padding = new Padding(22, 10, 22, 12), BackColor = cCard };
            Button close = CreateButton("Close", 0, 0, 120, 32, cBtnPrimaryBg, cGoldBright, cGold);
            close.Click += (s, e) => help.Close();
            if (displayTroubleshooting)
            {
                Button settings = CreateButton("Windows Display Settings", 0, 0, 0, 32, cBtnBg, cText, cBorderDim);
                settings.Click += (s, e) =>
                {
                    try { Process.Start(new ProcessStartInfo("ms-settings:display") { UseShellExecute = true }); }
                    catch (Exception ex) { MessageBox.Show(help, "Could not open Windows Display Settings. Open Settings > System > Display manually.\r\n" + ex.Message,
                        "Display Settings", MessageBoxButtons.OK, MessageBoxIcon.Information); }
                };
                Button copy = CreateButton("Copy Diagnostics", 0, 0, 0, 32, cBtnBg, cText, cBorderDim);
                copy.Click += (s, e) => CopyColorDiagnostics();
                var buttons = DashboardButtonRow(new Control[] { settings, copy, close }, 32);
                buttons.Dock = DockStyle.Fill;
                buttons.BackColor = cCard;
                footer.Controls.Add(buttons);
            }
            else
            {
                close.Dock = DockStyle.Right;
                footer.Controls.Add(close);
            }

            var guide = new RichTextBox
            {
                Dock = DockStyle.Fill,
                ReadOnly = true,
                DetectUrls = false,
                BorderStyle = BorderStyle.None,
                BackColor = cBg,
                ForeColor = cText,
                Font = new Font("Segoe UI", 10),
                ScrollBars = RichTextBoxScrollBars.Vertical,
                AccessibleName = title + " guide"
            };
            CompanionUi.StyleScrollbars(guide);
            using (var sectionFont = new Font(guide.Font.FontFamily, 11, FontStyle.Bold))
            {
                if (displayTroubleshooting)
                {
                    AppendHelpSection(guide, sectionFont, "Color and HDR", DisplayColor.Guidance);
                    AppendHelpSection(guide, sectionFont, "Windows display scaling", DisplayScaling.Guidance);
                }
                else FillSetupHelp(guide, sectionFont);
            }
            guide.Select(0, 0);
            guide.ScrollToCaret();
            var guidePanel = new Panel { Dock = DockStyle.Fill, Padding = new Padding(22, 18, 22, 16), BackColor = cBg };
            guidePanel.Controls.Add(guide);
            help.Controls.Add(guidePanel);
            help.Controls.Add(footer);
            help.Controls.Add(heading);
            help.AcceptButton = close;
            help.CancelButton = close;
            help.ActiveControl = close;
            return help;
        }

        private void ShowHelpDialog(bool displayTroubleshooting = false)
        {
            SuspendUiPolling();
            try
            {
                using (Form help = CreateHelpDialog(displayTroubleshooting))
                    help.ShowDialog(this);
            }
            finally { ResumeUiPolling(); }
        }

        private void InitializeTray()
        {
            trayIcon = new NotifyIcon
            {
                Text = "Offhand Companion",
                Visible = true
            };

            // Programmatic icon or loaded icon
            if (this.Icon != null)
            {
                trayIcon.Icon = this.Icon;
            }
            else
            {
                using (Bitmap bmp = new Bitmap(16, 16))
                using (Graphics g = Graphics.FromImage(bmp))
                using (SolidBrush brush = new SolidBrush(Color.FromArgb(90, 184, 255)))
                using (Font font = new Font("Georgia", 9, FontStyle.Bold))
                {
                    g.Clear(Color.FromArgb(8, 10, 18));
                    g.DrawString("A", font, brush, 1, 0);
                    trayIcon.Icon = Icon.FromHandle(bmp.GetHicon());
                }
            }

            ContextMenuStrip trayMenu = new ContextMenuStrip
            {
                BackColor = cCard,
                ForeColor = cText
            };

            ToolStripMenuItem itemOpen = new ToolStripMenuItem("Open Dashboard");
            itemOpen.Click += (s, e) => { RestoreForm(); };
            trayMenu.Items.Add(itemOpen);

            ToolStripMenuItem itemHelp = new ToolStripMenuItem("Help / Setup Guide");
            itemHelp.Click += (s, e) => { RestoreForm(); ShowHelpDialog(); };
            trayMenu.Items.Add(itemHelp);

            itemCheckUpdates = new ToolStripMenuItem(CompanionDistribution.UpdateMenuText(isStorePackage));
            itemCheckUpdates.Click += (s, e) => { RestoreForm(); CheckForUpdates(); };
            trayMenu.Items.Add(itemCheckUpdates);

            trayMenu.Items.Add(new ToolStripSeparator());

            ToolStripMenuItem itemSpan = new ToolStripMenuItem("Span WoW Now");
            itemSpan.Click += (s, e) => { InvokeSpanWindow(true); };
            trayMenu.Items.Add(itemSpan);

            itemAuto = new ToolStripMenuItem("Automatically Span on Launch")
            {
                Checked = chkAutoSpan.Checked,
                Enabled = chkAutoSpan.Enabled
            };
            itemAuto.Click += (s, e) =>
            {
                if (RemoteDesktop.Read() != RemoteDesktop.State.Local) return;
                chkAutoSpan.Checked = !chkAutoSpan.Checked;
                itemAuto.Checked = chkAutoSpan.Checked;
            };
            trayMenu.Items.Add(itemAuto);

            itemMonitor = new ToolStripMenuItem("Pause background monitoring");
            itemMonitor.Click += (s, e) => { ToggleBackgroundMonitoring(); };
            trayMenu.Items.Add(itemMonitor);

            trayMenu.Items.Add(new ToolStripSeparator());

            ToolStripMenuItem itemExit = new ToolStripMenuItem("Exit");
            itemExit.Click += (s, e) => { ExitApplication(); };
            trayMenu.Items.Add(itemExit);

            trayIcon.ContextMenuStrip = trayMenu;
            trayIcon.DoubleClick += (s, e) => { RestoreForm(); };
        }

        private void RestoreForm()
        {
            this.ShowInTaskbar = true;
            this.Show();
            this.WindowState = FormWindowState.Normal;
            this.Activate();
        }

        internal void ToggleBackgroundMonitoring()
        {
            isMonitoring = !isMonitoring;
            if (!isMonitoring) classicRecovery.Clear();
            if (itemMonitor != null)
                itemMonitor.Text = isMonitoring ? "Pause background monitoring" : "Resume background monitoring";
            AddLog(isMonitoring ? "Background auto-watcher resumed." : "Background auto-watcher PAUSED by user.");
            UpdateDashboardStatusSummary();
        }

        private void ExitApplication()
        {
            isExplicitExit = true;
            if (monitorTimer != null) monitorTimer.Stop();
            if (remoteSpan != null) InvokeRestoreWindow(false);
            if (trayIcon != null) trayIcon.Visible = false;
            this.Close();
            Application.Exit();
        }

        private void AddLog(string message)
        {
#if GRAININESS_TEST
            SpanPresentationTest.Log(message);
#endif
            if (GraphicsRecoveryTestBuild)
            {
                try { File.AppendAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, RecoveryScope.ToLowerInvariant() + "-recovery.log"),
                    DateTime.UtcNow.ToString("o") + " " + message + Environment.NewLine); }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
            if (logBox == null) { configWarning = message; return; }
            string time = DateTime.Now.ToString("HH:mm:ss");
            activityLogEntries.Insert(0, string.Format("[{0}] {1}", time, message));
            while (activityLogEntries.Count > 100) activityLogEntries.RemoveAt(activityLogEntries.Count - 1);
            logBox.Lines = activityLogEntries.ToArray();
            logBox.SelectionStart = 0;
            logBox.SelectionLength = 0;
            logBox.ScrollToCaret();
        }

        private void InitializeTimer()
        {
            monitorTimer = new Timer
            {
                Interval = 2000
            };
            monitorTimer.Tick += (s, e) => { OnTimerTick(); };
            monitorTimer.Start();
        }

        private void SuspendUiPolling()
        {
            uiInteractionPaused = true;
            if (monitorTimer != null) monitorTimer.Stop();
        }

        private void ResumeUiPolling()
        {
            uiInteractionPaused = false;
            if (monitorTimer == null || isExplicitExit) return;
            monitorTimer.Start();
        }

        private void SaveSpanDelay()
        {
            if (RemoteDesktop.Read() != RemoteDesktop.State.Local) return;
            appSettings["DelaySpan"] = numDelaySpan.Value.ToString();
            SaveConfig();
        }

        private void RememberWowDirectory(string wowDir)
        {
            if (string.IsNullOrEmpty(wowDir)) return;
            lastObservedWowDir = wowDir;
            string saved;
            if (!appSettings.TryGetValue("LastWowDir", out saved) ||
                !string.Equals(saved, wowDir, StringComparison.OrdinalIgnoreCase))
            {
                appSettings["LastWowDir"] = wowDir;
                SaveConfig();
            }
        }

        private string ResolveStoppedWowDirectory()
        {
            if (!string.IsNullOrEmpty(lastObservedWowDir) && Directory.Exists(lastObservedWowDir))
                return lastObservedWowDir;
            string saved;
            if (appSettings.TryGetValue("LastWowDir", out saved) && Directory.Exists(saved))
                return saved;

            var companion = new DirectoryInfo(AppDomain.CurrentDomain.BaseDirectory.TrimEnd(
                Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
            var addon = companion.Name.Equals("Companion", StringComparison.OrdinalIgnoreCase) ? companion.Parent : null;
            var addOns = addon == null ? null : addon.Parent;
            var interfaceDirectory = addOns == null ? null : addOns.Parent;
            var wow = interfaceDirectory == null ? null : interfaceDirectory.Parent;
            if (addon != null && addOns != null && interfaceDirectory != null && wow != null &&
                addon.Name.Equals("Offhand", StringComparison.OrdinalIgnoreCase) &&
                addOns.Name.Equals("AddOns", StringComparison.OrdinalIgnoreCase) &&
                interfaceDirectory.Name.Equals("Interface", StringComparison.OrdinalIgnoreCase))
                return wow.FullName;
            return null;
        }

        private void RefreshForeverStateWhileStopped()
        {
            if (bridgeAttemptedWhileStopped) return;
            bridgeAttemptedWhileStopped = true;
            string wowDir = ResolveStoppedWowDirectory();
            if (string.IsNullOrEmpty(wowDir)) return;
            string message;
            ForeverStateBridge.TryRefresh(wowDir, out message);
            AddLog(message);
        }

        private void RefreshSelectedColorStatus()
        {
            var displays = ReadDisplays();
            MonitorSelection.Plan plan = null;
            try { plan = GetMonitorPlan(displays); }
            catch (Exception) { /* Invalid or incomplete selection is shown above. */ }
            RefreshColorStatus(displays, plan);
        }

        private void CopyColorDiagnostics()
        {
            RefreshSelectedColorStatus();
            try
            {
                Clipboard.SetText("Offhand Companion " + FullVersion
                    + "\r\nBuild: " + ((AssemblyFileVersionAttribute)Attribute.GetCustomAttribute(typeof(CompanionForm).Assembly,
                        typeof(AssemblyFileVersionAttribute))).Version
                    + "\r\nWindows: " + Environment.OSVersion.Version
                    + "\r\nSettings storage: " + (isStorePackage ? "Microsoft Store package data" : "local user profile")
                    + "\r\nCaptured UTC: " + DateTime.UtcNow.ToString("u")
                    + "\r\n" + colorDiagnostics + "\r\nWindows display state only; game HDR conversion, WoW UI/render scale and image brightness are not measured.");
                AddLog("Display diagnostics copied to clipboard.");
            }
            catch (ExternalException) { MessageBox.Show(this, "The clipboard is busy. Try copying the diagnostics again.", "Display Diagnostics"); }
            catch (System.Threading.ThreadStateException) { MessageBox.Show(this, "Clipboard access is unavailable in this session.", "Display Diagnostics"); }
        }

        private void RefreshColorStatus(List<MonitorSelection.Display> displays, MonitorSelection.Plan plan)
        {
            if (lblColorModes == null) return;
            if (plan == null)
            {
                lblColorModes.Text = "Color and scaling details appear after a display layout is confirmed.";
                lblColorWarning.Text = "";
                lblColorWarning.ForeColor = cMuted;
                lblScaleInfo.Text = "";
                colorDiagnostics = lblColorModes.Text;
                foreach (var display in displays)
                    colorDiagnostics += string.Format("\r\nDisplay {0}: {1}; identity={2}; {3}",
                        display.Index + 1, display.DeviceName, display.StableId, display.IdentityDetail);
                lastColorDiagnostic = null;
                return;
            }
            string failure;
            var states = DisplayColor.Read(out failure);
            var mainhand = displays.Find(display => display.Index == plan.MainhandIndex);
            var workspace = displays.Find(display => display.Index == plan.WorkspaceIndex);
            var game = DisplayColor.Lookup(states, mainhand == null ? null : mainhand.DeviceName, failure);
            var work = DisplayColor.Lookup(states, workspace == null ? null : workspace.DeviceName, failure);
            var gameScale = DisplayScaling.Read(mainhand);
            var workScale = plan.SplitSingle ? gameScale : DisplayScaling.Read(workspace);
            bool mixed = DisplayColor.IsMixed(game, work, plan.SplitSingle);
            lblColorModes.Text = string.Format("Mainhand (Display {0}): {1}, {2}\r\nOffhand (Display {3}): {4}, {5}{6}",
                plan.MainhandIndex + 1, game.Label, gameScale.Label, plan.WorkspaceIndex + 1, work.Label,
                workScale.Label, plan.SplitSingle ? " (same display)" : "");
            lblColorWarning.Text = mixed ? "Mixed HDR/SDR displays: WoW may appear too bright or washed out. See Display Troubleshooting."
                : game.Active == DisplayColor.Mode.Unknown || work.Active == DisplayColor.Mode.Unknown
                    ? "Windows could not confirm every color mode. See Display Troubleshooting for guidance."
                    : "Windows display modes detected. Game HDR conversion is not measured.";
            lblColorWarning.ForeColor = mixed ? cYellow : cMuted;
            lblScaleInfo.Text = DisplayScaling.Summary(gameScale, workScale, plan.SplitSingle);
            var scaleByIndex=new Dictionary<int,DisplayScaling.State>{{plan.MainhandIndex,gameScale}};
            scaleByIndex[plan.WorkspaceIndex]=workScale;
            if(plan.MultiRegion) {
                var lines=new List<string>{string.Format("Mainhand (Display {0}): {1}, {2}",plan.MainhandIndex+1,game.Label,gameScale.Label)};
                var scales=new List<DisplayScaling.State>{gameScale};
                bool unknown=game.Active==DisplayColor.Mode.Unknown;var colors=new List<DisplayColor.State>{game};
                for(int i=0;i<plan.Workspaces.Length;i++) {
                    var region=plan.Workspaces[i];var display=displays[region.DisplayIndex];
                    var color=DisplayColor.Lookup(states,display.DeviceName,failure);var scale=DisplayScaling.Read(display);
                    if(!scaleByIndex.ContainsKey(region.DisplayIndex))scales.Add(scale);
                    scaleByIndex[region.DisplayIndex]=scale;colors.Add(color);unknown|=color.Active==DisplayColor.Mode.Unknown;
                    lines.Add(string.Format("Workspace {0} (Display {1}): {2}, {3}",i+1,region.DisplayIndex+1,color.Label,scale.Label));
                }
                mixed=false;foreach(var a in colors)foreach(var b in colors)mixed|=DisplayColor.IsMixed(a,b,false);
                lblColorModes.Text=string.Join("\r\n",lines.ToArray());
                lblColorWarning.Text=mixed?"Mixed HDR/SDR displays: WoW may appear too bright or washed out. See Display Troubleshooting."
                    :unknown?"Windows could not confirm every color mode. See Display Troubleshooting for guidance."
                    :"Windows display modes detected. Game HDR conversion is not measured.";
                lblColorWarning.ForeColor=mixed?cYellow:cMuted;lblScaleInfo.Text=DisplayScaling.Summary(scales);
            }
            var detail = new StringBuilder();
            detail.AppendLine(lblColorModes.Text);
            detail.AppendLine(lblColorWarning.Text);
            detail.AppendLine(lblScaleInfo.Text);
            foreach (int index in plan.Indices)
            {
                var display = displays.Find(item => item.Index == index);
                if (display == null) continue;
                var state = DisplayColor.Lookup(states, display.DeviceName, failure);
                DisplayScaling.State scale;if(!scaleByIndex.TryGetValue(index,out scale))scale=DisplayScaling.Read(display);
                detail.AppendFormat("Display {0}: {1}; identity={2}; bounds={3}; {4}; {5}; {6}; {7}\r\n",
                    index + 1, display.DeviceName, display.StableId, display.Bounds, state.Label, state.Detail, scale.Label, scale.Detail);
                detail.AppendLine("Identity lookup: " + display.IdentityDetail);
            }
            colorDiagnostics = detail.ToString();
            if (!string.Equals(lastColorDiagnostic, colorDiagnostics, StringComparison.Ordinal))
            {
                lastColorDiagnostic = colorDiagnostics;
                AddLog("Display diagnostics: " + colorDiagnostics.Trim());
            }
        }

        private static string DescribeDashboardLayout(MonitorSelection.Plan plan, bool windowMatches)
        {
            string state = windowMatches ? "WoW window matches the selected layout" : "Selected display layout";
            string game = string.Format("Game {0} × {1}", plan.MainhandBounds.Width, plan.MainhandBounds.Height);
            string workspace = plan.MultiRegion
                ? string.Format("{0} workspace{1} on {2} display{3}", plan.Workspaces.Length,
                    plan.Workspaces.Length == 1 ? "" : "s", plan.Indices.Length, plan.Indices.Length == 1 ? "" : "s")
                : string.Format("Workspace {0} × {1}{2}", plan.WorkspaceBounds.Width, plan.WorkspaceBounds.Height,
                    plan.SplitSingle ? " (single display)" : "");
            return state + "\r\n" + game + "  •  " + workspace;
        }

        private void UpdateDashboardStatusSummary()
        {
            if (lblStatusSummary == null) return;
            string text;
            Color color;
            if (!isMonitoring) { text = "Monitoring paused"; color = cYellow; }
            else if (lblDisplayInfo.ForeColor == cYellow) { text = "Check display layout"; color = cYellow; }
            else if (lblAddonStatus.ForeColor == cYellow) { text = "Check add-on"; color = cYellow; }
            else if (lblWowStatus.ForeColor == cGreen) { text = "WoW running"; color = cGreen; }
            else
            {
                string state = lblWowStatus.Text.Replace("WoW: ", "");
                text = "WoW " + (state.Length == 0 ? "checking..." : char.ToLowerInvariant(state[0]) + state.Substring(1));
                color = cMuted;
            }
            lblStatusSummary.Text = "\u25CF " + text;
            lblStatusSummary.ForeColor = color;
            uiToolTips.SetToolTip(lblStatusSummary, text + ". Select Show for details.");
        }

        internal static string HeaderVersionText(AddonStatus status, bool anyWoWProcess)
        {
            string addon = anyWoWProcess ? "checking WoW" : "waiting for WoW";
            if (status != null) {
                string version = (status.Version ?? "").Trim();
                string release = (status.ReleaseTag ?? "").Trim();
                string releaseName = Regex.Replace(release, @"^beta\.(\d+)$", "Beta $1", RegexOptions.IgnoreCase);
                addon = version;
                if (release.Length > 0 && version.IndexOf(release, StringComparison.OrdinalIgnoreCase) < 0)
                    addon += (addon.Length > 0 ? " " : "") + releaseName;
                if (addon.Length == 0) addon = status.Installed ? "version unavailable" : "not found";
            }
            return "v" + FullVersion + " | Addon: " + addon + " | Crafted by: N4UX";
        }

        internal void UpdateClientStatus(AddonStatus status, bool anyWoWProcess)
        {
            string headerText = HeaderVersionText(status, anyWoWProcess);
            if (lblHeaderVersion != null && lblHeaderVersion.Text != headerText) {
                lblHeaderVersion.Text = headerText;
                LayoutDashboardCards();
            }
            if (status == null)
            {
                lblWowStatus.Text = anyWoWProcess ? "WoW: Waiting for one game window" : "WoW: Not running";
                lblWowStatus.ForeColor = cMuted;
                lblAddonStatus.Text = "Offhand addon: Waiting for WoW";
                lblAddonStatus.ForeColor = cMuted;
                lblAddonReason.Text = anyWoWProcess
                    ? "Wait for WoW to open. Keep one WoW window open when using Remote Desktop."
                    : "Start WoW to check the addon for that client.";
                UpdateDashboardStatusSummary();
                return;
            }

            string client = "";
            if (!string.IsNullOrEmpty(status.WowDir))
            {
                switch (Path.GetFileName(status.WowDir).ToLowerInvariant())
                {
                    case "_retail_": client = "Retail"; break;
                    case "_forever_": client = "Forever"; break;
                    case "_classic_": client = "Classic"; break;
                    case "_classic_era_": client = "Classic Era"; break;
                    case "_anniversary_": client = "Anniversary"; break;
                    case "_ptr_": case "_classic_ptr_": client = "PTR"; break;
                    case "_beta_": case "_classic_beta_": client = "Beta"; break;
                }
            }
            lblWowStatus.Text = string.IsNullOrEmpty(client) ? "WoW: Running" : "WoW: " + client + " running";
            lblWowStatus.ForeColor = cGreen;
            string release = string.IsNullOrWhiteSpace(status.ReleaseTag) ? "" : " (" + status.ReleaseTag + ")";
            lblAddonStatus.Text = status.Installed
                ? "Offhand addon: Installed" + release : "Offhand addon: Needs attention";
            lblAddonStatus.ForeColor = status.Installed ? cGreen : cYellow;
            lblAddonReason.Text = status.Installed
                ? "Confirm Offhand is enabled in WoW. " + LayoutApplyInstruction
                : status.SetupHint;
            UpdateDashboardStatusSummary();
        }

        private void OnTimerTick()
        {
            if (uiInteractionPaused) return;
            bool savedDisplayDisconnected = false;
            MonitorSelection.Plan currentDisplayPlan = null;
            List<MonitorSelection.Display> currentDisplays = ReadDisplays();
            RemoteDesktop.State session = RemoteDesktop.Read();
            bool changedSession = session != remoteState;
            if (changedSession)
            {
                InvalidateRemoteSpan();
                remoteState = session;
                UpdatePartialControls();
            }
            if (remoteSpan != null && !MonitorSelection.SameDisplays(remoteSpan.Displays, currentDisplays))
                InvalidateRemoteSpan();
            RefreshDisplayControls(currentDisplays, changedSession);
            bool local = session == RemoteDesktop.State.Local;
            lblDisplayInfo.ForeColor = cText;
            if (!local)
            {
                lblDisplayInfo.Text = remoteSpan != null
                    ? "Remote Desktop span active. Use Restore Window when done."
                    : session == RemoteDesktop.State.Active
                        ? "Remote Desktop: choose two displays with Span WoW Now."
                        : "Waiting for an active Remote Desktop connection.";
            }
            else try
            {
                currentDisplayPlan = GetMonitorPlan(currentDisplays);
            }
            catch (Exception ex)
            {
                lblDisplayInfo.Text = ex.Message;
                lblDisplayInfo.ForeColor = cYellow;
                string savedIdentities, savedDevices;
                appSettings.TryGetValue("MonitorIdentities", out savedIdentities);
                appSettings.TryGetValue("MonitorDevices", out savedDevices);
                savedDisplayDisconnected = MonitorSelection.HasDisconnectedSavedDisplay(
                    HasStableIdentitySettings() ? savedIdentities : null, savedDevices, currentDisplays);
            }

            RefreshColorStatus(currentDisplays, currentDisplayPlan);

            bool anyWoWProcess;
            Process proc = GetWoWProcess(out anyWoWProcess);
            if (monitorTimer != null) monitorTimer.Interval = proc == null ? 5000 : 2000;

            if (proc != null)
            {
                if (remoteSpan != null && remoteSpan.ProcessId == proc.Id && GetWoWWindowHandle(proc) != remoteSpan.Handle)
                    InvalidateRemoteSpan();
                AddonStatus status = TestOffhandAddonStatus(proc);
                UpdateClientStatus(status, true);
                RememberWowDirectory(status.WowDir);
                bridgeAttemptedWhileStopped = false;
                string addonDiagnostic = proc.Id + "|" + status.Installed + "|" + status.Reason;
                if (!string.Equals(lastAddonDiagnostic, addonDiagnostic, StringComparison.Ordinal))
                {
                    lastAddonDiagnostic = addonDiagnostic;
                    AddLog("Addon verification: " + status.Reason);
                }
                bool windowMatchesCurrentPlan = false;
                if (currentDisplayPlan != null)
                {
                    IntPtr observedHandle = GetWoWWindowHandle(proc);
                    NativeMethods.RECT observedRect;
                    if (observedHandle != IntPtr.Zero && NativeMethods.GetWindowRect(observedHandle, out observedRect)
                        && observedRect.Left == currentDisplayPlan.Bounds.Left
                        && observedRect.Top == currentDisplayPlan.Bounds.Top
                        && observedRect.Width == currentDisplayPlan.Bounds.Width
                        && observedRect.Height == currentDisplayPlan.Bounds.Height)
                    {
                        windowMatchesCurrentPlan = true;
                        if (!spannedPids.Contains(proc.Id) && !restoredPids.Contains(proc.Id))
                        {
                            spannedPids.Add(proc.Id);
                            AddLog("Detected an existing WoW span and resumed display-loss protection for this client.");
                        }
                    }
                }
                if (currentDisplayPlan != null)
                    lblDisplayInfo.Text = DescribeDashboardLayout(currentDisplayPlan, windowMatchesCurrentPlan);

                // Addon managers and local deployments replace the generated
                // bridge with the packaged placeholder. If the live WoW window
                // still exactly matches the selected span, repair that file
                // without moving the window. The next /reload can then consume
                // the same trusted display plan again.
                if (status.Installed && windowMatchesCurrentPlan
                    && spannedPids.Contains(proc.Id) && !restoredPids.Contains(proc.Id)
                    && !CompanionTopologyBridge.IsCurrent(status.WowDir, currentDisplayPlan, currentDisplays))
                {
                    string topologyMessage;
                    if (CompanionTopologyBridge.TryWrite(status.WowDir, currentDisplayPlan,
                        currentDisplays, out topologyMessage))
                    {
                        lastTopologyRepairFailure = null;
                        AddLog("Repaired the addon-updated display topology. Use /reload once in WoW.");
                    }
                    else if (!string.Equals(lastTopologyRepairFailure, topologyMessage,
                        StringComparison.Ordinal))
                    {
                        lastTopologyRepairFailure = topologyMessage;
                        AddLog(topologyMessage);
                    }
                }

                if (local) TryRecoverClassicSpan(proc, status, currentDisplayPlan, currentDisplays);

                if (isMonitoring && savedDisplayDisconnected && spannedPids.Contains(proc.Id)
                    && !restoredPids.Contains(proc.Id)
                    && (!retryAfter.ContainsKey(proc.Id) || DateTime.Now >= retryAfter[proc.Id]))
                {
                    retryAfter[proc.Id] = DateTime.Now.AddSeconds(10);
                    AddLog("A saved display disconnected while WoW was spanned. Restoring WoW to the surviving Mainhand display...");
                    if (InvokeRestoreWindow(false, true))
                        AddLog("Missing-monitor recovery filled the surviving Mainhand display. Reconnect the workspace display before spanning again.");
                }

                if (local && !GraphicsRecoveryTestBuild && AutoSpanAttemptPolicy.ShouldAttempt(isMonitoring, chkAutoSpan.Checked,
                    status.Installed, currentDisplayPlan != null,
                    spannedPids.Contains(proc.Id), restoredPids.Contains(proc.Id),
                    failedAutoSpanPids.Contains(proc.Id)))
                {
                    if (!retryAfter.ContainsKey(proc.Id) || DateTime.Now >= retryAfter[proc.Id])
                    {
                        if (!launchTimes.ContainsKey(proc.Id)) launchTimes[proc.Id] = DateTime.Now;
                        double spanDelay = CompanionTiming.AutoSpanDelay(proc.ProcessName, status.WowDir, numDelaySpan.Value);
                        if ((DateTime.Now - launchTimes[proc.Id]).TotalSeconds < spanDelay)
                        {
                            retryAfter[proc.Id] = DateTime.Now.AddSeconds(1);
                            proc.Dispose();
                            return;
                        }
                        AddLog(string.Format("New WoW launch detected (PID: {0}). Preparing auto-span...", proc.Id));
                        retryAfter[proc.Id] = DateTime.Now.AddSeconds(10);
                        if (InvokeSpanWindow(false))
                        {
                            spannedPids.Add(proc.Id);
                        }
                        else
                        {
                            failedAutoSpanPids.Add(proc.Id);
                            AddLog("Automatic spanning is paused for this WoW process after a failed window operation. Review the diagnostic above, then use Span WoW Now to retry explicitly.");
                        }
                    }
                }
            }
            else
            {
                UpdateClientStatus(null, anyWoWProcess);
                if (currentDisplayPlan != null)
                    lblDisplayInfo.Text = DescribeDashboardLayout(currentDisplayPlan, false);
                lastAddonDiagnostic = null;
                // The game window can disappear before the process finishes
                // flushing SavedVariables. Never read or replace the recovery
                // snapshot until every recognized WoW process has exited.
                if (!anyWoWProcess) RefreshForeverStateWhileStopped();
            }

            if (proc != null) proc.Dispose();

            // Clean dead PIDs
            var pidsToCheck = new HashSet<int>(spannedPids);
            pidsToCheck.UnionWith(restoredPids);
            pidsToCheck.UnionWith(failedAutoSpanPids);
            pidsToCheck.UnionWith(launchTimes.Keys);
            foreach (int pid in pidsToCheck)
            {
                try
                {
                    Process.GetProcessById(pid);
                }
                catch
                {
                    if (remoteSpan != null && remoteSpan.ProcessId == pid) InvalidateRemoteSpan();
                    spannedPids.Remove(pid);
                    restoredPids.Remove(pid);
                    failedAutoSpanPids.Remove(pid);
                    originalWindows.Remove(pid);
                    classicRecovery.Remove(pid);
                    launchTimes.Remove(pid);
                    retryAfter.Remove(pid);
                    AddLog(string.Format("WoW process (PID: {0}) closed.", pid));
                }
            }
        }

        private Process GetWoWProcess(out bool anyRecognizedProcess, bool requireSingleWindow = false)
        {
            anyRecognizedProcess = false;
            Process selected = null;
            bool multipleWindows = false;
            foreach (string processName in wowProcessNames)
            {
                Process[] candidates;
                try
                {
                    candidates = Process.GetProcessesByName(processName);
                }
                catch
                {
                    // Process discovery can race with process startup or shutdown.
                    continue;
                }

                foreach (Process candidate in candidates)
                {
                    bool keep = false;
                    try
                    {
                        if (candidate.SessionId != currentSessionId) continue;
                        anyRecognizedProcess = true;
                        if ((selected == null || requireSingleWindow) && candidate.MainWindowHandle != IntPtr.Zero)
                        {
                            if (selected == null)
                            {
                                selected = candidate;
                                keep = true;
                            }
                            else multipleWindows = true;
                        }
                    }
                    catch
                    {
                        // A process can exit while Windows is returning its window.
                    }
                    finally
                    {
                        if (!keep) candidate.Dispose();
                    }
                }
            }
            if (multipleWindows)
            {
                selected.Dispose();
                return null;
            }
            return selected;
        }

        private Process GetWoWProcess()
        {
            bool anyRecognizedProcess;
            return GetWoWProcess(out anyRecognizedProcess);
        }

        private bool IsAnyWoWProcessRunning()
        {
            bool anyRecognizedProcess;
            Process process = GetWoWProcess(out anyRecognizedProcess);
            if (process != null) process.Dispose();
            return anyRecognizedProcess;
        }

        private AddonStatus TestOffhandAddonStatus(Process proc)
        {
            AddonStatus result = new AddonStatus { Installed = false, Reason = "Launch exactly one WoW client.",
                SetupHint = "See the Activity Log for the addon check details." };
            if (proc == null) return result;

            try
            {
                string processPathDiagnostic;
                string mainModule = ProcessPathResolver.Get(proc, out processPathDiagnostic);
                if (string.IsNullOrEmpty(mainModule))
                {
                    result.SetupHint = "Restart WoW and Companion. On Wine, use the same prefix for both.";
                    result.Reason = "Client path unavailable. Under Wine, start the Companion in WoW's WINEPREFIX."
                        + (string.IsNullOrWhiteSpace(processPathDiagnostic)
                            ? "" : " " + processPathDiagnostic);
                    return result;
                }
                result.WowDir = Path.GetDirectoryName(mainModule);
                if (string.IsNullOrEmpty(result.WowDir))
                {
                    result.Reason = "Client path unavailable.";
                    return result;
                }

                AddonInstallCheck install = AddonInstallation.Inspect(result.WowDir);
                result.Installed = install.Installed;
                result.Reason = install.Reason;
                result.ReleaseTag = install.ReleaseTag;
                result.Version = install.Version;
                result.SetupHint = install.SetupHint;
            }
            catch (Exception ex)
            {
                result.Reason = "Cannot verify the addon installation for this client. "
                    + ex.GetType().Name + ": " + ex.Message;
            }

            return result;
        }

        private IntPtr GetWoWWindowHandle(Process proc)
        {
            if (proc == null) return IntPtr.Zero;
            proc.Refresh();
            IntPtr handle = proc.MainWindowHandle;
            if (handle == IntPtr.Zero)
            {
                handle = NativeMethods.FindProcessWindow(proc.Id);
            }
            uint ownerPid;
            NativeMethods.GetWindowThreadProcessId(handle, out ownerPid);
            if (ownerPid != proc.Id) return IntPtr.Zero;
            return handle;
        }

        private static string RecoveryPlanKey(MonitorSelection.Plan plan, IList<MonitorSelection.Display> displays)
        {
            if (plan == null || displays == null) return null;
            var keys = new List<string>();
            foreach (var display in displays)
                keys.Add(display.DeviceName + "|" + display.StableId + "|" + display.Bounds.ToString());
            keys.Sort(StringComparer.Ordinal);
            return plan.MainhandBounds.ToString() + "|" + plan.WorkspaceBounds.ToString() + "|"
                + plan.SplitSingle + "|" + string.Join(";", keys.ToArray());
        }

        private static ClassicGraphicsRecovery.Observation ReadRecoveryObservation(IntPtr handle)
        {
            NativeMethods.RECT bounds, client, box;
            if (!NativeMethods.GetWindowRect(handle, out bounds) || !NativeMethods.GetClientRect(handle, out client)) return null;
            var result = new ClassicGraphicsRecovery.Observation {
                Handle = handle, Bounds = new Rectangle(bounds.Left, bounds.Top, bounds.Width, bounds.Height),
                Client = new Size(client.Width, client.Height), Style = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE),
                Usable = !NativeMethods.IsHungAppWindow(handle) && !NativeMethods.IsIconic(handle) && !NativeMethods.IsZoomed(handle)
            };
            IntPtr region = NativeMethods.CreateRectRgn(0, 0, 0, 0);
            if (region == IntPtr.Zero) return null;
            try {
                if (NativeMethods.GetWindowRgn(handle, region) > 0 && NativeMethods.GetRgnBox(region, out box) > 0)
                    result.Region = new Rectangle(box.Left, box.Top, box.Width, box.Height);
            } finally { NativeMethods.DeleteObject(region); }
            return result;
        }

        private void TryRecoverClassicSpan(Process process, AddonStatus status, MonitorSelection.Plan plan,
            IList<MonitorSelection.Display> displays)
        {
            if (!GraphicsRecoveryEnabled) return;
            ClassicGraphicsRecovery recovery;
            if (!classicRecovery.TryGetValue(process.Id, out recovery) || recovery.Spent) return;
            if (!isMonitoring || !status.Installed || !IsRecoveryClient(status.WowDir)
                || restoredPids.Contains(process.Id) || !spannedPids.Contains(process.Id) || plan == null)
            { classicRecovery.Remove(process.Id); return; }
            try {
                var observed = ReadRecoveryObservation(GetWoWWindowHandle(process));
                bool wasConfirmed = recovery.Confirmed;
                bool wasRearming = recovery.Rearming;
                bool shouldRecover = recovery.Observe(observed, RecoveryPlanKey(plan, displays), DateTime.UtcNow, isMonitoring);
                if (!wasConfirmed && recovery.Confirmed)
                    AddLog(RecoveryScope + " span verified stable. Graphics-reset recovery is armed. Restore Window or Pause background monitoring in the tray menu cancels it.");
                if (wasRearming && !recovery.Rearming && !recovery.Spent)
                    AddLog(RecoveryScope + " recovery re-armed after verified stability and cooldown. Limit: 3 automatic recoveries per 5 minutes.");
                if (!shouldRecover)
                {
                    if (!wasConfirmed && recovery.Spent)
                        AddLog(RecoveryScope + " initial span did not remain valid. Recovery was not armed. Use Restore Window and retain the diagnostic capture.");
                    else if (recovery.Spent && (recovery.StopReason == "attempt limit" || recovery.StopReason == "stability check failed"))
                    {
                        AddLog(RecoveryScope + " automatic recovery paused: " + recovery.StopReason + ". Use Span WoW Now or Restore Window; no automatic retry will run.");
                        trayIcon.ShowBalloonTip(5000, "Offhand recovery paused",
                            "Repeated resets or unstable graphics stopped automatic recovery. Use Span WoW Now or Restore Window.", ToolTipIcon.Info);
                    }
                    return;
                }
                AddLog(RecoveryScope + " graphics reset detected: pre-span client size with stale span clipping. Attempting one recovery.");
                bool succeeded = InvokeSpanWindow(false, true);
                recovery.CompleteAttempt(succeeded, DateTime.UtcNow);
                if (succeeded)
                    AddLog(RecoveryScope + " graphics recovery restored confirmed bounds, borderless style and clipping. Verifying stability and waiting 10 seconds before re-arming.");
                else AddLog(RecoveryScope + " graphics recovery stopped. Use Span WoW Now or Restore Window; no automatic retry will run.");
            } catch (Exception ex) {
                recovery.Spent = true;
                AddLog(RecoveryScope + " graphics observation stopped: " + ex.Message);
            }
        }

        private bool InvokeRestoreWindow(bool manual)
        {
            // A user-requested restore should return to the exact bordered bounds
            // captured before the first span. Forcing the complete Mainhand work
            // area creates an avoidable second renderer resize when WoW reapplies
            // its saved windowed client size, and can trigger D3D12 device recovery.
            return InvokeRestoreWindow(manual, false);
        }

        private bool InvokeRestoreWindow(bool manual, bool fillConnectedMainhand)
        {
            Process proc = null;
            try
            {
                RemoteSpan activeRemoteSpan = remoteSpan;
                proc = activeRemoteSpan == null ? GetWoWProcess() : Process.GetProcessById(activeRemoteSpan.ProcessId);
                if (proc == null) throw new Exception("Launch exactly one WoW client first.");
                classicRecovery.Remove(proc.Id);
                IntPtr handle = GetWoWWindowHandle(proc);
                if (handle == IntPtr.Zero) throw new Exception("WoW window is not ready.");
                if (activeRemoteSpan != null && (handle != activeRemoteSpan.Handle || proc.SessionId != currentSessionId))
                {
                    InvalidateRemoteSpan();
                    throw new InvalidOperationException("The original Remote Desktop WoW window changed. Retry Restore Window for the current window.");
                }

                int oldStyle = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE);
                WindowSnapshot snapshot;
                bool known = originalWindows.TryGetValue(proc.Id, out snapshot) && snapshot.Handle == handle;
                int newStyle = (known ? snapshot.Style : oldStyle) | NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME;
                Rectangle desired;
                Rectangle workArea;
                if (fillConnectedMainhand)
                {
                    string mainhandIdentity, mainhandDevice;
                    appSettings.TryGetValue("MainhandIdentity", out mainhandIdentity);
                    appSettings.TryGetValue("MainhandDevice", out mainhandDevice);
                    MonitorSelection.Display recoveryDisplay = MonitorSelection.RecoveryDisplay(
                        HasStableIdentitySettings() ? mainhandIdentity : null,
                        HasStableIdentitySettings() ? mainhandDevice : null, ReadDisplays());
                    if (recoveryDisplay == null) throw new Exception("Windows reports no surviving display for recovery.");
                    workArea = recoveryDisplay.WorkArea.Width > 0 && recoveryDisplay.WorkArea.Height > 0
                        ? recoveryDisplay.WorkArea : recoveryDisplay.Bounds;
                    desired = workArea;
                }
                else
                {
                    desired = known ? snapshot.Bounds : new Rectangle(Screen.PrimaryScreen.WorkingArea.Location, new Size(1920, 1080));
                    workArea = Screen.FromRectangle(desired).WorkingArea;
                }
                Rectangle target = RestoreGeometry.Fit(desired, workArea);
                
                WindowRestore.Apply(handle, target, newStyle);
                SetTaskbarFullscreen(handle, false);
                if (remoteSpan != null && remoteSpan.ProcessId == proc.Id) InvalidateRemoteSpan();
                
                spannedPids.Remove(proc.Id);
                restoredPids.Add(proc.Id);
                if (manual && !NativeMethods.SetForegroundWindow(handle))
                    AddLog("WoW was restored, but Windows did not return keyboard focus automatically. Click the WoW window once to activate it.");
                AddLog(fillConnectedMainhand
                    ? "Restored WoW across the selected or surviving Mainhand display. Auto-span paused until Span Now. On Forever, click Use Modern if Offhand prompts."
                    : "Restored WoW window. Auto-span paused for this client until Span Now or a new WoW launch.");
                return true;
            }
            catch (Exception ex)
            {
                AddLog(ex.Message);
                if (manual) MessageBox.Show(ex.Message, "Offhand", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return false;
            }
            finally
            {
                if (proc != null) proc.Dispose();
            }
        }

        private bool InvokeSpanWindow(bool manual)
        {
            return InvokeSpanWindow(manual, false);
        }

        private void PreparePhysicalSpanSelection(bool manual, List<MonitorSelection.Display> displays)
        {
            Dictionary<string, string> originalSelection = null;
            if (manual)
            {
                if (!MonitorSelection.SameDisplays(uiDisplays, displays))
                {
                    RefreshDisplayControls(displays);
                    throw new InvalidOperationException("Windows display arrangement changed. Review the selected displays and Mainhand, then click Span WoW Now again.");
                }
                if (!IsCustomSelection())
                {
                    string savedIdentities, savedDevices;
                    appSettings.TryGetValue("MonitorIdentities", out savedIdentities);
                    appSettings.TryGetValue("MonitorDevices", out savedDevices);
                    if (!displaySelectionEdited && MonitorSelection.HasDisconnectedSavedDisplay(
                        MonitorSelection.HasSavedIdentitySettings(appSettings) ? savedIdentities : null, savedDevices, displays))
                        throw new InvalidOperationException("A saved display is disconnected or ambiguous. Reconnect it, or explicitly review and change the selected displays before spanning.");
                    originalSelection = appSettings;
                    appSettings = new Dictionary<string, string>(appSettings);
                }
            }

            try
            {
                if (RemoteDesktop.Read() != RemoteDesktop.State.Local)
                    throw new InvalidOperationException("The Windows session changed. Review the displays and click Span WoW Now again.");
                if (originalSelection != null) SaveDisplaySettingsFromControls(false);
                bool committed = ConfirmStableDisplayIdentity(manual);
                if (originalSelection != null && !committed) PreferenceFile.Write(configPath, appSettings);
            }
            catch
            {
                if (originalSelection != null) appSettings = originalSelection;
                throw;
            }
        }

        private bool InvokeSpanWindow(bool manual, bool graphicsRecovery)
        {
            Process proc = null;
            SpanRollback rollback = null;
            try
            {
                RemoteDesktop.State session = RemoteDesktop.Read();
                bool remote = session == RemoteDesktop.State.Active;
                if (session != RemoteDesktop.State.Local && (!remote || !manual))
                    throw new InvalidOperationException("Remote Desktop spanning requires an active connection and a manual click on Span WoW Now.");
                bool anyWoWProcess;
                proc = GetWoWProcess(out anyWoWProcess, remote);
                if (proc == null) throw new Exception("Launch exactly one WoW client first.");
                int confirmedGeneration = remoteGeneration;
                List<MonitorSelection.Display> displays = ReadDisplays();
                MonitorSelection.Plan plan;
                if (remote)
                {
                    plan = ConfirmRemotePlan(displays);
                    if (plan == null) return false;
                }
                else
                {
                    try { PreparePhysicalSpanSelection(manual, displays); }
                    catch (OperationCanceledException ex) { AddLog(ex.Message); return false; }
                    if (manual) classicRecovery.Remove(proc.Id);
                    plan = null;
                }

                AddonStatus status = TestOffhandAddonStatus(proc);
                if (!status.Installed) throw new Exception(status.Reason);
                if (GraphicsRecoveryTestBuild && !IsRecoveryClient(status.WowDir))
                    throw new Exception("This test candidate spans only " + (RecoveryClientScope == ClassicGraphicsRecovery.ClientScope.Classic ? "Classic Era and Anniversary" : RecoveryScope) + ". Use the matching candidate for this client.");
                if (graphicsRecovery && !IsRecoveryClient(status.WowDir))
                    throw new Exception("Automatic recovery is not enabled for this client.");

                IntPtr handle = GetWoWWindowHandle(proc);
                if (handle == IntPtr.Zero) throw new Exception("WoW window is not ready. Retry after it opens.");

                if (!remote) plan = MonitorSelection.CreatePlan(appSettings, displays);
                if (plan.IsCustom && !manual)
                    throw new InvalidOperationException("Custom regions are manual-only in this prototype. Click Span WoW Now.");
                if (graphicsRecovery)
                {
                    ClassicGraphicsRecovery expected;
                    if (!classicRecovery.TryGetValue(proc.Id, out expected)
                        || !expected.Owns(handle, RecoveryPlanKey(plan, displays))
                        || NativeMethods.IsHungAppWindow(handle) || NativeMethods.IsIconic(handle) || NativeMethods.IsZoomed(handle))
                        throw new Exception(RecoveryScope + " recovery cancelled because the window or confirmed displays changed.");
                }
                string alignmentWarning = MonitorSelection.AlignmentWarning(plan);
                RefreshColorStatus(displays, plan);
                if (alignmentWarning != null) AddLog("Display alignment warning: " + alignmentWarning);
                Rectangle plannedBounds = plan.Bounds;
                Rectangle bounds = plannedBounds;
                if (bounds.Width <= 0 || bounds.Height <= 0) throw new Exception("Invalid virtual desktop dimensions.");

                if (remote) ValidateRemoteConfirmation(confirmedGeneration, displays);
                else if (RemoteDesktop.Read() != RemoteDesktop.State.Local)
                    throw new InvalidOperationException("The Windows session changed. Review the displays and click Span WoW Now again.");
                string topologyMessage;
                rollback = new SpanRollback(Path.Combine(status.WowDir, "Interface", "AddOns", "Offhand", "Core", "CompanionTopology.lua"), handle);
                byte[] writtenTopology;
                if (!CompanionTopologyBridge.TryWrite(status.WowDir, plan, displays, out topologyMessage, out writtenTopology))
                    throw new IOException(topologyMessage + " WoW was not spanned because Offhand cannot safely receive the selected display geometry.");
                rollback.TopologyWritten(writtenTopology);
                AddLog(topologyMessage);

                rollback.WindowChanged = true;
                if (NativeMethods.IsZoomed(handle) || NativeMethods.IsIconic(handle))
                {
                    NativeMethods.ShowWindow(handle, NativeMethods.SW_RESTORE);
                }

                NativeMethods.RECT oldRect;
                if (!NativeMethods.GetWindowRect(handle, out oldRect)) throw new Exception("Could not read WoW window bounds.");

                NativeMethods.RECT oldClient;
                Size oldClientSize = NativeMethods.GetClientRect(handle, out oldClient)
                    ? new Size(oldClient.Width, oldClient.Height) : Size.Empty;

                int oldStyle = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE);
                int newStyle = oldStyle & ~(NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME);
#if GRAININESS_TEST
                AddLog(SpanPresentationTest.Describe(handle, "Before span"));
                if (SpanPresentationTest.KeepBorders)
                    newStyle = oldStyle | NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME;
                bounds = SpanPresentationTest.OuterBounds(handle, plannedBounds, newStyle);
                AddLog("Target client=" + plannedBounds + "; target outer=" + bounds);
#endif
                if (newStyle != oldStyle)
                {
                    NativeMethods.SetLastError(0);
                    int res = NativeMethods.SetWindowLong(handle, NativeMethods.GWL_STYLE, newStyle);
                    int styleError = Marshal.GetLastWin32Error();
                    if (res == 0 && styleError != 0)
                    {
                        throw new Exception(WindowInteropDiagnostics.StyleFailure(
                            "Could not remove WoW window borders", styleError));
                    }
                }

                try
                {
#if GRAININESS_TEST
                    if (!SpanPresentationTest.Clip)
                    {
                        if (NativeMethods.SetWindowRgn(handle, IntPtr.Zero, true) == 0)
                            throw new Exception("Could not clear WoW clipping region.");
                    }
                    else
                    {
#endif
                    IntPtr combinedRgn = IntPtr.Zero;
                    IntPtr previousDpi = NativeMethods.SetThreadDpiAwarenessContext((IntPtr)(-4));
                    try
                    {
                        combinedRgn = SpanClipRegion.Create(plan, bounds);
                        if (NativeMethods.SetWindowRgn(handle, combinedRgn, true) == 0) throw new Exception("Could not apply monitor clipping region.");
                        combinedRgn = IntPtr.Zero; // Windows owns the region after success.
                    }
                    finally
                    {
                        if (combinedRgn != IntPtr.Zero) NativeMethods.DeleteObject(combinedRgn);
                        if (previousDpi != IntPtr.Zero) NativeMethods.SetThreadDpiAwarenessContext(previousDpi);
                    }
#if GRAININESS_TEST
                    }
#endif

                    uint flags = NativeMethods.SWP_NOZORDER | NativeMethods.SWP_NOACTIVATE | NativeMethods.SWP_FRAMECHANGED | NativeMethods.SWP_SHOWWINDOW;
                    if (!NativeMethods.SetWindowPos(handle, IntPtr.Zero, bounds.X, bounds.Y, bounds.Width, bounds.Height, flags))
                    {
                        throw new Exception("Windows rejected the requested span.");
                    }

                    // Experimental graininess comparison only. Ordinary and
                    // recovery builds omit this sequence because its presentation
                    // benefit and initial-span stability remain unverified together.
                    Rectangle intermediate = RenderResizeHandshake.IntermediateBounds(bounds);
                    bool renderResizeHandshake = RenderResizeHandshake.Allowed(GraphicsRecoveryEnabled) && intermediate != bounds
#if GRAININESS_TEST
                        && SpanPresentationTest.Resize
#endif
                        && NativeMethods.SetWindowPos(handle, IntPtr.Zero,
                            intermediate.X, intermediate.Y,
                            intermediate.Width, intermediate.Height, flags);
                    if (renderResizeHandshake)
                    {
                        System.Threading.Thread.Sleep(50);
                        if (!NativeMethods.SetWindowPos(handle, IntPtr.Zero,
                            bounds.X, bounds.Y, bounds.Width, bounds.Height, flags))
                        {
                            throw new Exception("WoW did not return to the exact span after the render resize handshake.");
                        }
                        AddLog("Render resize handshake applied; exact display bounds restored.");
                    }

                    NativeMethods.RECT actual;
                    if (GraphicsRecoveryEnabled)
                    {
                        var observedSpan = ReadRecoveryObservation(handle);
                        if (observedSpan != null)
                            AddLog(RecoveryScope + " span readback: outer=" + observedSpan.Bounds + "; client="
                                + observedSpan.Client + "; region=" + observedSpan.Region + "; style="
                                + observedSpan.Style.ToString("X8") + "; expected=" + bounds + ".");
                    }
                    if (!NativeMethods.GetWindowRect(handle, out actual) ||
                        actual.Left != bounds.X || actual.Top != bounds.Y ||
                        actual.Width != bounds.Width || actual.Height != bounds.Height)
                    {
                        throw new Exception(GraphicsRecoveryEnabled
                            ? "WoW changed its window bounds during spanning. Use Restore Window and retain the diagnostic capture; recovery was not armed."
                            : "WoW did not accept the requested bounds. Select Windowed mode and retry.");
                    }
                    if (graphicsRecovery)
                    {
                        var verified = ReadRecoveryObservation(handle);
                        if (verified == null || !verified.Usable || verified.Client != bounds.Size
                            || verified.Region != new Rectangle(Point.Empty, bounds.Size)
                            || (verified.Style & (NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME)) != 0)
                            throw new Exception(RecoveryScope + " graphics recovery could not verify borderless client bounds and clipping. Automatic retries are stopped.");
                    }
#if GRAININESS_TEST
                    // Bordered and borderless modes compare the same drawable area.
                    // No backbuffer or process memory is inspected or changed.
                    Rectangle measuredClient = SpanPresentationTest.ClientBounds(handle);
                    AddLog(SpanPresentationTest.Describe(handle, "After span"));
                    if (measuredClient != plannedBounds)
                        throw new Exception("Drawable client bounds differ from the plan. Test is invalid; window restored. See log.");
#endif
                }
                catch
                {
                    // The operation-level snapshot restores the exact prior
                    // file, clipping region, style, bounds and show state.
                    throw;
                }

                if (remote) ValidateRemoteConfirmation(confirmedGeneration, displays);
                WindowSnapshot original;
                if (!originalWindows.TryGetValue(proc.Id, out original) || original.Handle != handle)
                    originalWindows[proc.Id] = new WindowSnapshot { Handle = handle, Style = oldStyle, ClientSize = oldClientSize,
                        Bounds = new Rectangle(oldRect.Left, oldRect.Top, oldRect.Width, oldRect.Height) };
                if (!remote && !plan.IsCustom && !graphicsRecovery && IsRecoveryClient(status.WowDir))
                {
                    WindowSnapshot first = originalWindows[proc.Id];
                    if (CanArmRecovery(status.WowDir, isMonitoring, graphicsRecovery, handle, first.ClientSize, bounds.Size))
                    {
                        classicRecovery[proc.Id] = new ClassicGraphicsRecovery(handle, bounds, first.ClientSize,
                            RecoveryPlanKey(plan, displays));
                        AddLog(RecoveryScope + " span requested. Waiting for stable bounds, client size, borderless style and clipping before arming recovery.");
                    }
                    else AddLog(RecoveryScope + " recovery not armed: monitoring is paused or no distinct pre-span client size was recorded. Resume monitoring, Restore Window, then span again.");
                }
                restoredPids.Remove(proc.Id);
                failedAutoSpanPids.Remove(proc.Id);
                spannedPids.Add(proc.Id);
#if GRAININESS_TEST
                // Bound read-only sampling to one minute and cancel superseded runs.
                int generation = ++spanTestGeneration;
                int samplePid = proc.Id;
                int remaining = 30;
                Timer evidenceTimer = new Timer { Interval = 2000 };
                evidenceTimer.Tick += (sender, args) =>
                {
                    if (IsDisposed || generation != spanTestGeneration || !spannedPids.Contains(samplePid)
                        || remaining-- <= 0)
                    {
                        evidenceTimer.Stop(); evidenceTimer.Dispose(); return;
                    }
                    AddLog(SpanPresentationTest.Describe(handle, "Settled sample"));
                };
                evidenceTimer.Start();
#endif
                if (remote) AddLog(string.Format("Remote Desktop span applied at {0}x{1}. {2} Keep Companion open for Restore Window.", bounds.Width, bounds.Height, ReloadLayoutInstruction));
                else AddLog(GraphicsRecoveryTestBuild
                    ? string.Format(RecoveryScope + " span request applied at {0}x{1}; stable-window verification remains separate.", bounds.Width, bounds.Height)
                    : string.Format("Spanned {0}x{1}. {2} For first-time setup, run /offhand guide after reloading.", bounds.Width, bounds.Height, ReloadLayoutInstruction));
                if (plan.IsCustom)
                    AddLog("Custom region applied. In Offhand Window Setup choose Use Companion, then type /reload in WoW. Automatic graphics-reset recovery is disabled for this prototype; use Span WoW Now after a graphics reset.");
                trayIcon.ShowBalloonTip(6000, GraphicsRecoveryTestBuild ? RecoveryScope + " span requested" : "Span applied: type /reload in WoW",
                    GraphicsRecoveryTestBuild ? "Wait for stable-span confirmation in the activity log before the VSync test."
                    : ReloadLayoutInstruction + (remote ? " Keep Companion open for Restore Window." : ""), ToolTipIcon.Info);
                rollback.Commit();
                if (remote)
                    remoteSpan = new RemoteSpan { ProcessId = proc.Id, Handle = handle, Displays = displays, Topology = rollback.Topology };
                SetTaskbarFullscreen(handle, true);
                return true;
            }
            catch (Exception ex)
            {
                if (rollback != null)
                {
                    string rollbackFailure = rollback.Rollback();
                    if (rollbackFailure != null) AddLog(rollbackFailure);
                }
                AddLog(ex.Message);
                if (manual)
                {
                    MessageBox.Show(ex.Message, "Offhand", MessageBoxButtons.OK, MessageBoxIcon.Information);
                }
                return false;
            }
            finally
            {
                if (rollback != null) rollback.Dispose();
                if (proc != null) proc.Dispose();
            }
        }

        private void SetTaskbarFullscreen(IntPtr handle, bool fullscreen)
        {
            string failure;
            if (!TaskbarPresentation.TrySetFullscreen(handle, fullscreen, out failure))
                AddLog("Windows taskbar fullscreen notification was unavailable: " + failure);
        }

        [STAThread]
        public static void Main()
        {
#if GRAININESS_TEST
            try
            {
                SpanPresentationTest.Initialize(Environment.GetCommandLineArgs().Length > 1
                    ? new System.Collections.Generic.List<string>(Environment.GetCommandLineArgs()).GetRange(1,
                        Environment.GetCommandLineArgs().Length - 1).ToArray() : new string[0]);
                SpanPresentationTest.ImportConfig();
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "Offhand Graininess Test2"); return;
            }
#endif
            bool ownsInstance = false;
            System.Threading.Mutex instanceMutex = null;
            try
            {
                try
                {
#if UI_PREVIEW
                    instanceMutex = new System.Threading.Mutex(true, @"Local\OffhandCompanionDashboardPreview", out ownsInstance);
#else
                    instanceMutex = new System.Threading.Mutex(true, @"Local\OffhandCompanion", out ownsInstance);
#endif
                }
                catch (System.Threading.AbandonedMutexException)
                {
                    ownsInstance = true;
                }
                if (!ownsInstance)
                {
                    MessageBox.Show("Offhand Companion is already running. Open it from the Windows notification area.",
                        "Offhand Companion", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new CompanionForm());
            }
            finally
            {
                if (instanceMutex != null)
                {
                    if (ownsInstance)
                    {
                        try { instanceMutex.ReleaseMutex(); }
                        catch { }
                    }
                    instanceMutex.Dispose();
                }
            }
        }
    }
}











