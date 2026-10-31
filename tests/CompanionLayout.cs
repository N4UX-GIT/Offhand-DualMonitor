using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;

namespace Offhand.Companion
{
    internal static class LayoutTest
    {
        private static IEnumerable<Control> Descendants(Control parent)
        {
            foreach (Control child in parent.Controls)
            {
                yield return child;
                foreach (Control nested in Descendants(child)) yield return nested;
            }
        }

        private static Rectangle BoundsInside(Control control, Control ancestor)
        {
            int x = control.Left;
            int y = control.Top;
            Control parent = control.Parent;
            while (parent != null && parent != ancestor)
            {
                x += parent.Left;
                y += parent.Top;
                parent = parent.Parent;
            }
            if (parent != ancestor) throw new Exception("Control is not inside the expected card.");
            return new Rectangle(x, y, control.Width, control.Height);
        }

        private static T One<T>(Control root, Func<T, bool> predicate) where T : Control
        {
            return Descendants(root).OfType<T>().Single(predicate);
        }

        private static void LayoutAll(Control parent)
        {
            foreach (Control child in parent.Controls) LayoutAll(child);
            parent.PerformLayout();
        }

        private static void RenderChildren(Control parent, Bitmap target, Point origin)
        {
            foreach (Control child in parent.Controls)
            {
                if (child.Width <= 0 || child.Height <= 0) continue;
                Point location = new Point(origin.X + child.Left, origin.Y + child.Top);
                using (var bitmap = new Bitmap(child.Width, child.Height))
                {
                    child.DrawToBitmap(bitmap, new Rectangle(Point.Empty, bitmap.Size));
                    RenderChildren(child, bitmap, Point.Empty);
                    using (var graphics = Graphics.FromImage(target)) graphics.DrawImageUnscaled(bitmap, location);
                }
            }
        }

        private static void CheckScale(float factor)
        {
            using (var form = new CompanionForm())
            {
                form.CreateControl();
                form.Scale(new SizeF(factor, factor));
                LayoutAll(form);

                Panel config = Descendants(form).OfType<Panel>().Single(panel =>
                    panel.Controls.OfType<Label>().Any(label => label.Text == "  CONFIGURATION"));
                var delay = One<NumericUpDown>(config, control => true);
                var displays = One<CheckedListBox>(config, control => true);
                var combos = Descendants(config).OfType<ComboBox>().ToArray();
                if (combos.Length != 2) throw new Exception("Expected Mainhand and game-side selectors.");
                ComboBox mainhand = combos.OrderByDescending(control => control.Width).First();
                ComboBox gameSide = combos.OrderBy(control => control.Width).First();
                Button identify = One<Button>(config, control => control.Text == "Identify Displays");

                foreach (Control control in new Control[] { delay, displays, mainhand, gameSide, identify })
                {
                    Rectangle bounds = BoundsInside(control, config);
                    if (bounds.Left < 0 || bounds.Top < 24 || bounds.Right > config.ClientSize.Width
                        || bounds.Bottom > config.ClientSize.Height)
                        throw new Exception(control.GetType().Name + " escaped the configuration card at " + factor + "x: " + bounds);
                    if (bounds.Width <= 0 || bounds.Height <= 0)
                        throw new Exception(control.GetType().Name + " collapsed at " + factor + "x.");
                }

                Rectangle displayBounds = BoundsInside(displays, config);
                Rectangle mainhandBounds = BoundsInside(mainhand, config);
                Rectangle identifyBounds = BoundsInside(identify, config);
                if (displayBounds.Bottom >= mainhandBounds.Top)
                    throw new Exception("Display checklist overlaps Mainhand at " + factor + "x.");
                if (identifyBounds.Right >= displayBounds.Left)
                    throw new Exception("Identify Displays overlaps the display selectors at " + factor + "x.");

                // Reproduce the reported outer-scrollbar regression with the
                // complete dashboard, not only controls inside one card.
                foreach (Rectangle workArea in new[] { new Rectangle(0, 0, 2560, 1400),
                    new Rectangle(0, 0, 1920, 1000), new Rectangle(-1440, -1114, 1440, 2520) })
                {
                    form.FitDashboardToWorkingArea(workArea);
                    LayoutAll(form);
                    if (!workArea.Contains(form.Bounds))
                        throw new Exception("Dashboard escaped work area at " + factor + "x: " + form.Bounds);
                    Panel viewport = form.Controls.OfType<Panel>().Single(panel => panel.AutoScroll);
                    var stack = viewport.Controls.OfType<TableLayoutPanel>().Single();
                    var footer = form.Controls.OfType<TableLayoutPanel>().Single();
                    if (viewport.Bottom > footer.Top || footer.Bottom > form.ClientSize.Height)
                        throw new Exception("Scrolling dashboard overlaps pinned footer");
                    foreach (Control button in footer.Controls)
                        if (button.Bottom > footer.Height || button.Right > footer.Width || button.Height <= 0)
                            throw new Exception("Pinned footer control is clipped");
                    var help = One<Button>(form, button => button.Text == "?");
                    if (help.Left < 0 || help.Right > help.Parent.ClientSize.Width)
                        throw new Exception("Header help button escaped responsive layout");
                    if (stack.Right > viewport.ClientSize.Width - viewport.Padding.Right || viewport.HorizontalScroll.Visible || form.HorizontalScroll.Visible)
                        throw new Exception("Dashboard needs horizontal scrolling at " + factor + "x: stack=" + stack.Bounds + ", viewport=" + viewport.ClientSize);
                    if (factor == 1f && workArea.Height >= 1400)
                    {
                        if (stack.Bottom > viewport.ClientSize.Height - viewport.Padding.Bottom || viewport.VerticalScroll.Visible)
                            throw new Exception("Full dashboard should fit this work area without scrolling.");
                        string preview = Environment.GetEnvironmentVariable("OFFHAND_LAYOUT_PREVIEW");
                        if (!string.IsNullOrEmpty(preview) && workArea.Left == 0)
                        {
                            using (var bitmap = new Bitmap(form.ClientSize.Width, form.ClientSize.Height))
                            {
                                using (var graphics = Graphics.FromImage(bitmap)) graphics.Clear(form.BackColor);
                                RenderChildren(form, bitmap, Point.Empty);
                                bitmap.Save(preview, System.Drawing.Imaging.ImageFormat.Png);
                            }
                        }
                    }
                }
                foreach (Panel section in new[] { config, Descendants(form).OfType<Panel>().Single(panel =>
                    panel.Controls.OfType<Label>().Any(label => label.Text == "  DISPLAY DIAGNOSTICS")) })
                {
                    form.SetDashboardSectionExpanded(section, true, false);
                    int expandedHeight = section.Height;
                    form.SetDashboardSectionExpanded(section, false, false);
                    if (section.Height >= expandedHeight) throw new Exception("Collapsing a section must release its space");
                    if (!section.Controls.OfType<Button>().Any(button => button.Text == "Show")) throw new Exception("Collapsed section needs keyboard-accessible Show action");
                    form.SetDashboardSectionExpanded(section, true, false);
                    if (section.Height != expandedHeight) throw new Exception("Expanded section failed to restore its layout");
                }
                foreach (int logicalWidth in new[] { 500, 640, 800 })
                {
                    form.ClientSize = new Size((int)(logicalWidth * factor), form.ClientSize.Height);
                    LayoutAll(form);
                    Panel viewport = form.Controls.OfType<Panel>().Single(panel => panel.AutoScroll);
                    var stack = viewport.Controls.OfType<TableLayoutPanel>().Single();
                    foreach (Control section in stack.Controls)
                        if (Math.Abs(section.Width - stack.ClientSize.Width) > 2)
                            throw new Exception("Section does not use the available dashboard width");
                    if (viewport.HorizontalScroll.Visible || form.HorizontalScroll.Visible)
                        throw new Exception("Resizing introduced a horizontal scrollbar");
                }
            }
        }

        [STAThread]
        internal static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            CheckScale(1f);
            CheckScale(1.25f);
            CheckScale(1.5f);
            CheckScale(2.0f);
            Console.WriteLine("PASS: complete dashboard fits working areas, avoids horizontal overflow and retains separated selectors at 100%, 125%, 150%, and 200% scaling");
        }
    }
}
