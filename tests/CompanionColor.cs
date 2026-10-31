using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace Offhand.Companion
{
    internal static class ColorTest
    {
        private static int assertions;
        private static void Check(bool value, string message)
        {
            assertions++;
            if (!value) throw new Exception(message);
        }

        private static IEnumerable<Control> Descendants(Control parent)
        {
            foreach (Control child in parent.Controls)
            {
                yield return child;
                foreach (Control nested in Descendants(child)) yield return nested;
            }
        }

        private static void CheckCard(float scale, string preview)
        {
            using (var form = new CompanionForm())
            {
#if HDR_DPI_DIAGNOSTICS_TEST
                Check(form.Text.Contains("HDR / DPI DIAGNOSTICS TEST 3"), "Test candidate title is distinct");
                Check(!CompanionForm.GraphicsRecoveryEnabled, "Diagnostics candidate must not enable recovery experiments");
                var auto = (CheckBox)typeof(CompanionForm).GetField("chkAutoSpan",
                    System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic).GetValue(form);
                Check(!auto.Checked && !auto.Enabled, "Diagnostics candidate stays manual-only");
                var path = (string)typeof(CompanionForm).GetField("configPath",
                    System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.NonPublic).GetValue(null);
                Check(path == System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "DiagnosticsTestConfig.ini"),
                    "Diagnostics settings stay beside candidate, not in public config");
#endif
                var card = Descendants(form).OfType<Panel>().Single(panel =>
                    panel.Controls.OfType<Label>().Any(label => label.Text == "  DISPLAY DIAGNOSTICS"));
                form.SetDashboardSectionExpanded(card, true, false);
                var labels = card.Controls.OfType<Label>().Where(label => label.Top > 24).OrderBy(label => label.Top).ToArray();
                Check(labels.Length == 3, "Diagnostics card needs separate modes, HDR and scale labels");
                labels[0].Text = "Mainhand (Display 12): Color mode unavailable, Scale unavailable\r\nOffhand (Display 13): SDR, HDR available, 150% scale (same display)";
                labels[1].Text = "Mixed HDR/SDR displays: WoW may appear too bright or washed out. See Display Troubleshooting.";
                labels[2].Text = "Different Windows scales detected. This is supported; see troubleshooting if WoW looks blurry.";
                labels[1].ForeColor = Color.Goldenrod;
                form.CreateControl();
                form.Scale(new SizeF(scale, scale));
                form.PerformLayout();
                var items = card.Controls.Cast<Control>().OrderBy(control => control.Top).ToArray();
                foreach (Control control in items)
                {
                    Check(control.Left >= 0 && control.Top >= 0 && control.Right <= card.ClientSize.Width
                        && control.Bottom <= card.ClientSize.Height, "Color control escaped card at " + scale);
                    var label = control as Label;
                    if (label != null)
                    {
                        Size measured = TextRenderer.MeasureText(label.Text, label.Font,
                            new Size(label.ClientSize.Width, int.MaxValue), TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix);
                        Check(measured.Height <= label.Height, "Color label clipped at " + scale + ": " + measured + "/" + label.Size);
                    }
                }
                foreach (var button in card.Controls.OfType<Button>())
                    if (button.Text != "Hide" && button.Text != "Show")
                        Check(button.Top >= labels[2].Bottom, "Diagnostics actions overlap scale advisory");
                Check(labels[0].Bottom <= labels[1].Top, "Color mode and advisory overlap");
                Check(labels[1].Bottom <= labels[2].Top, "HDR and scale advisories overlap");
                Check(Descendants(form).OfType<Button>().Single(button => button.Text == "Span WoW Now").Enabled,
                    "Color advisory must not disable spanning");
                if (preview != null)
                {
                    using (var bitmap = new Bitmap(card.Width, card.Height))
                    {
                        card.DrawToBitmap(bitmap, new Rectangle(Point.Empty, bitmap.Size));
                        // The test form stays hidden. Render child controls
                        // explicitly because WinForms skips invisible ancestry.
                        foreach (Control child in card.Controls) child.DrawToBitmap(bitmap, child.Bounds);
                        bitmap.Save(preview, System.Drawing.Imaging.ImageFormat.Png);
                    }
                }
            }
        }

        [STAThread]
        internal static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Check(Marshal.SizeOf(typeof(DisplayColor.Header)) == 20, "DISPLAYCONFIG_DEVICE_INFO_HEADER layout");
            Check(Marshal.SizeOf(typeof(DisplayColor.SourceName)) == 84, "DISPLAYCONFIG_SOURCE_DEVICE_NAME layout");
            Check(Marshal.SizeOf(typeof(DisplayColor.Path)) == 72, "DISPLAYCONFIG_PATH_INFO layout");
            Check(Marshal.SizeOf(typeof(DisplayColor.ModeInfo)) == 64, "DISPLAYCONFIG_MODE_INFO layout");
            Check(Marshal.SizeOf(typeof(DisplayColor.ColorInfo)) == 36, "DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO_2 layout");
            Check(Marshal.OffsetOf(typeof(DisplayColor.ColorInfo), "ActiveMode").ToInt32() == 32, "Legacy color query size");
            Check(Marshal.SizeOf(typeof(DisplayScaling.MonitorInfo)) == 104, "MONITORINFOEXW layout");

            var hdr = DisplayColor.DecodeModern(16 | 32, 2);
            var sdr = DisplayColor.DecodeModern(0, 0);
            var off = DisplayColor.DecodeModern(16 | 32, 0);
            var wcg = DisplayColor.DecodeModern(64 | 128, 1);
            var unknown = DisplayColor.DecodeModern(0, 99);
            Check(hdr.Active == DisplayColor.Mode.Hdr && hdr.Label == "HDR on", "Active HDR detected");
            Check(off.Label == "SDR, HDR available", "User-enabled HDR that is not active stays SDR");
            Check(wcg.Label == "SDR (wide color)", "WCG must not be advertised as HDR");
            Check(unknown.Active == DisplayColor.Mode.Unknown, "Future mode stays unknown");
            foreach (var left in new[] { hdr, sdr, off, wcg, unknown })
                foreach (var right in new[] { hdr, sdr, off, wcg, unknown })
                {
                    bool expected = (left == hdr && (right == sdr || right == off || right == wcg))
                        || (right == hdr && (left == sdr || left == off || left == wcg));
                    Check(DisplayColor.IsMixed(left, right, false) == expected, "Mixed color combination");
                    Check(!DisplayColor.IsMixed(left, right, true), "Single-display split never mixed");
                }
            Check(DisplayColor.DecodeLegacy(0).Active == DisplayColor.Mode.Sdr, "Legacy disabled advanced color is SDR");
            Check(DisplayColor.DecodeLegacy(3).Active == DisplayColor.Mode.Unknown, "Legacy enabled advanced color is ambiguous");
            Check(!DisplayColor.DecodeLegacy(1).HdrSupported.HasValue, "Legacy capability is not HDR-specific");
            var states = new Dictionary<string, DisplayColor.State>(StringComparer.OrdinalIgnoreCase);
            DisplayColor.Merge(states, "DISPLAY1", hdr);
            Check(DisplayColor.Lookup(states, "display1", null) == hdr, "GDI source mapping ignores case");
            DisplayColor.Merge(states, "DISPLAY1", sdr);
            DisplayColor.Merge(states, "DISPLAY1", hdr);
            Check(states["DISPLAY1"].Active == DisplayColor.Mode.Unknown, "Clone ambiguity cannot be overwritten");
            Check(DisplayColor.Lookup(states, "DISPLAY2", null).Active == DisplayColor.Mode.Unknown, "Missing output never assumes SDR");
            Check(DisplayColor.Lookup(states, null, "API unavailable").Detail == "API unavailable", "Detection failure retained");

            var factors = new[] { 100, 125, 150, 175, 200, 225 };
            foreach (int left in factors)
                foreach (int right in factors)
                {
                    var game = DisplayScaling.FromResult(0, left);
                    var work = DisplayScaling.FromResult(0, right);
                    Check(DisplayScaling.IsMixed(game, work, false) == (left != right), "Compare actual Windows scales");
                    Check(!DisplayScaling.IsMixed(game, work, true), "Single physical display is never mixed DPI");
                }
            var unavailable = DisplayScaling.FromResult(unchecked((int)0x80070057), 100);
            Check(!unavailable.Percent.HasValue, "Failed scale query must ignore returned default 100%");
            Check(!DisplayScaling.FromResult(0, 0).Percent.HasValue, "Zero scale is unknown");
            Check(!DisplayScaling.FromResult(0, -1).Percent.HasValue, "Invalid scale is unknown");
            Check(DisplayScaling.FromResult(0, 175).Label == "175% scale", "Non-100 scale is visible");
            Check(!DisplayScaling.IsMixed(unavailable, DisplayScaling.FromResult(0, 150), false), "Unknown is not a mixed-DPI observation");
            Check(DisplayScaling.Summary(DisplayScaling.FromResult(0, 150), DisplayScaling.FromResult(0, 150), false)
                .Contains("Both selected displays use 150%"), "Same scaled DPI remains informational");
            Check(!DisplayScaling.Read(null).Percent.HasValue, "Missing display is unknown");
            Check(!DisplayScaling.Read(new MonitorSelection.Display { DeviceName = "missing-output",
                Bounds = new Rectangle(0, 0, 100, 100) }).Percent.HasValue, "Mismatched monitor cannot borrow another scale");
            foreach (var screen in Screen.AllScreens)
            {
                var scale = DisplayScaling.Read(new MonitorSelection.Display { DeviceName = screen.DeviceName, Bounds = screen.Bounds });
                Console.WriteLine(screen.DeviceName + ": " + scale.Label + "; " + scale.Detail);
            }

            // Actual read-only interop smoke test. No display or game settings change.
            string failure;
            var live = DisplayColor.Read(out failure);
            Console.WriteLine("Native read: " + (failure ?? (live.Count + " source(s)")));
            foreach (var entry in live) Console.WriteLine(entry.Key + ": " + entry.Value.Label + "; " + entry.Value.Detail);
            CheckCard(1f, args.Length > 0 ? args[0] : null);
            CheckCard(1.25f, null);
            CheckCard(1.5f, null);
            CheckCard(2f, null);
            Console.WriteLine("PASS: " + assertions + " color detection, interop layout, mapping and DPI layout assertions (" + (IntPtr.Size * 8) + " bit)");
        }
    }
}
