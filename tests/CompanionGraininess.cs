using System;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

namespace Offhand.Companion
{
    internal static class GraininessTest
    {
        private static void Check(bool condition, string message)
        {
            if (!condition) throw new Exception(message);
        }

        [STAThread]
        public static void Main()
        {
            Check(!CompanionForm.GraphicsRecoveryEnabled,
                "graininess mode must not arm graphics recovery or suppress its resize comparison");
            string config = (string)typeof(CompanionForm).GetField("configPath",
                BindingFlags.NonPublic | BindingFlags.Static).GetValue(null);
            Check(config == SpanPresentationTest.ConfigPath,
                "graininess candidate must retain its own preference path after source integration");
            // Exercise the actual candidate assembly's version gate, not only
            // the parser in isolation. This caught the test1 launch blocker.
            string fixture = Path.Combine(Path.GetTempPath(), "Offhand-graininess-gate-" + Guid.NewGuid().ToString("N"));
            string addon = Path.Combine(fixture, "Interface", "AddOns", "Offhand");
            Directory.CreateDirectory(addon);
            try
            {
                string manifest = Path.Combine(addon, "Offhand_Forever.toc");
                string metadata = "## Interface: 16001\n## X-Offhand-Release: beta.21-discord.topology-test1\n"
                    + "## X-Offhand-Companion-Protocol: 1\n## X-Offhand-Companion-Min-Version: ";
                File.WriteAllText(manifest, metadata + "2.1.2-beta.19\n");
                AddonInstallCheck actual = AddonInstallation.Inspect(fixture);
                Check(actual.Installed, "Reported topology-test1 pairing rejected: " + actual.Reason);
                var identity = (AssemblyInformationalVersionAttribute)Attribute.GetCustomAttribute(
                    Assembly.GetExecutingAssembly(), typeof(AssemblyInformationalVersionAttribute));
                CompanionReleaseVersion compatibility;
                Check(CompanionReleaseVersion.TryParse(identity.InformationalVersion, out compatibility),
                    "Candidate/writer compatibility identity must be parseable");
                File.WriteAllText(manifest, metadata + "2.1.2-beta.21\n");
                Check(!AddonInstallation.Inspect(fixture).Installed, "A future minimum must still be rejected");
                File.WriteAllText(manifest, (metadata + "2.1.2-beta.19\n").Replace("Protocol: 1", "Protocol: 2"));
                Check(!AddonInstallation.Inspect(fixture).Installed, "Unsupported protocol must still be rejected");
            }
            finally
            {
                if (!Path.GetFullPath(fixture).StartsWith(Path.GetFullPath(Path.GetTempPath()), StringComparison.OrdinalIgnoreCase)
                    || !Path.GetFileName(fixture).StartsWith("Offhand-graininess-gate-"))
                    throw new Exception("Unexpected fixture cleanup path");
                Directory.Delete(fixture, true);
            }
            Check(SpanPresentationTest.Parse(new string[0]) == SpanTestMode.Baseline, "Default baseline");
            bool rejected = false;
            try { SpanPresentationTest.Parse(new string[] { "--span-test=unknown" }); }
            catch (ArgumentException) { rejected = true; }
            Check(rejected, "Unknown mode must not run a different experiment silently");
            Check(SpanPresentationTest.AddInsets(new Rectangle(-1080, -8, 3640, 1824), -8, -31, 8, 8)
                == new Rectangle(-1088, -39, 3656, 1863), "Negative-origin bordered outer/client conversion");
            foreach (SpanTestMode mode in Enum.GetValues(typeof(SpanTestMode)))
            {
                SpanPresentationTest.Mode = mode;
                Check(SpanPresentationTest.KeepBorders == (mode == SpanTestMode.Bordered), "Border isolation");
                Check(SpanPresentationTest.Resize == (mode == SpanTestMode.Resize), "Resize isolation");
                Check(SpanPresentationTest.Clip == (mode == SpanTestMode.Baseline || mode == SpanTestMode.Resize),
                    "Clipping isolation");
                // A synthetic hidden window only. Never locate or operate on WoW.
                using (Form window = new Form())
                {
                    IntPtr handle = window.Handle;
                    int style = NativeMethods.GetWindowLong(handle, NativeMethods.GWL_STYLE);
                    if (!SpanPresentationTest.KeepBorders)
                        style &= ~(NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME);
                    NativeMethods.SetLastError(0);
                    int previous = NativeMethods.SetWindowLong(handle, NativeMethods.GWL_STYLE, style);
                    Check(previous != 0 || System.Runtime.InteropServices.Marshal.GetLastWin32Error() == 0,
                        "Synthetic style change");
                    Rectangle client = new Rectangle(100, 100, 640, 480);
                    Rectangle outer = SpanPresentationTest.OuterBounds(handle, client, style);
                    Check(NativeMethods.SetWindowPos(handle, IntPtr.Zero, outer.X, outer.Y,
                        outer.Width, outer.Height, 0x0034), "Synthetic resize");
                    Check(SpanPresentationTest.ClientBounds(handle) == client,
                        "Equal drawable dimensions/origin for " + mode);
                    Check(SpanPresentationTest.Describe(handle, "test").Contains("client="), "Client evidence");
                    if (SpanPresentationTest.Resize)
                    {
                        Rectangle intermediate = RenderResizeHandshake.IntermediateBounds(outer);
                        Check(NativeMethods.SetWindowPos(handle, IntPtr.Zero, intermediate.X, intermediate.Y,
                            intermediate.Width, intermediate.Height, 0x0034), "Synthetic intermediate resize");
                        Check(NativeMethods.SetWindowPos(handle, IntPtr.Zero, outer.X, outer.Y,
                            outer.Width, outer.Height, 0x0034), "Synthetic final resize");
                        Check(SpanPresentationTest.ClientBounds(handle) == client, "Exact client bounds after handshake");
                    }
                }
            }
            Console.WriteLine("PASS: candidate mode isolation, unknown-mode refusal, negative origins, native hidden-window client bounds and resize return");
        }
    }
}
