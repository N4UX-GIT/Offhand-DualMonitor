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
            }
        }

        [STAThread]
        internal static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            CheckScale(1.25f);
            CheckScale(1.5f);
            CheckScale(2.0f);
            Console.WriteLine("PASS: configuration selectors remain measured and separated at 125%, 150%, and 200% scaling");
        }
    }
}
