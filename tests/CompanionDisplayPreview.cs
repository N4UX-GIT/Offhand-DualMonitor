using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

namespace Offhand.Companion
{
    // The dashboard's display preview: every display to scale, the game area and the workspace(s) over them, and
    // the span outlined. Run with a folder argument to also save pictures of the layouts it draws.
    internal static class DisplayPreviewTest
    {
        private static int assertions;
        private static void Check(bool value, string message)
        { assertions++; if (!value) throw new Exception(message); }
        private static bool Near(float a, float b) { return Math.Abs(a - b) < 0.6f; }

        private static MonitorSelection.Display D(int index, int x, int y, int w, int h)
        {
            return new MonitorSelection.Display { Index = index, DeviceName = "\\\\.\\DISPLAY" + (index + 1),
                Bounds = new Rectangle(x, y, w, h), WorkArea = new Rectangle(x, y, w, h - 40) };
        }

        private static void Save(string folder, string name, List<MonitorSelection.Display> displays, MonitorSelection.Plan plan)
        {
            if (folder == null) return;
            using (var bitmap = new Bitmap(470, 130))
            using (var g = Graphics.FromImage(bitmap))
            using (var font = new Font(FontFamily.GenericSansSerif, 8.5f))
            {
                g.Clear(Color.FromArgb(14, 14, 17));
                DisplayPreview.Draw(g, new Rectangle(0, 0, 470, 130), font, displays, plan);
                bitmap.Save(System.IO.Path.Combine(folder, name + ".png"), System.Drawing.Imaging.ImageFormat.Png);
            }
        }

        private static int Main(string[] args)
        {
            string folder = args.Length > 0 ? args[0] : null;
            var box = new Size(470, 130);
            RectangleF span;

            // one 5120x1440 ultrawide: the Offhand workspace on the left (1280), the game in the middle (2560),
            // the right 1280 left to the desktop
            var ultrawide = new List<MonitorSelection.Display> { D(0, 0, 0, 5120, 1440) };
            var split = new MonitorSelection.Plan { Indices = new[] { 0 }, MainhandIndex = 0, WorkspaceIndex = 0, SplitSingle = true,
                PartialSingle = true, Bounds = new Rectangle(0, 0, 3840, 1440),
                MainhandBounds = new Rectangle(1280, 0, 2560, 1440), WorkspaceBounds = new Rectangle(0, 0, 1280, 1440) };
            var shapes = DisplayPreview.Shapes(ultrawide, split, box, out span);
            Check(shapes.Count == 4, "the display, the game, the workspace and the free desktop part");
            Check(shapes[0].Badge == "1" && shapes[0].Titles == null, "the display: its number in the corner (areas cover its middle)");
            Check(shapes[1].Title == "Mainhand (game)" && shapes[1].Fill == DisplayPreview.GameFill, "the game area, green");
            Check(shapes[1].Titles[1] == "Game", "with a short name for a small preview");
            Check(shapes[2].Title == "Offhand workspace" && shapes[2].Fill == DisplayPreview.WorkspaceFill, "the workspace, amber");
            Check(shapes[3].Title == "Desktop" && shapes[3].Fill.IsEmpty && shapes[3].Detail == "1280\u00d71440", "the free right side: Desktop, 1280 wide");
            Check(Near(shapes[1].Area.Width, shapes[0].Area.Width / 2), "to scale: the game is half the ultrawide");
            Check(Near(shapes[2].Area.Width, shapes[0].Area.Width / 4), "the workspace a quarter");
            Check(Near(shapes[1].Area.X, shapes[0].Area.X + shapes[0].Area.Width / 4), "the game right of the workspace");
            Check(Near(span.Width, shapes[0].Area.Width * 3 / 4), "the span outline covers the workspace and the game, not the free desktop");
            foreach (var s in shapes)
                Check(s.Area.Left >= 0 && s.Area.Top >= 0 && s.Area.Right <= box.Width && s.Area.Bottom <= box.Height, "everything inside the preview");
            Save(folder, "preview-ultrawide", ultrawide, split);

            // three monitors: a 2560x1440 game, a portrait 2160x3840 workspace at 150% to its left, a 1080p desktop to the right
            var three = new List<MonitorSelection.Display> { D(0, 0, 0, 2560, 1440), D(1, -2160, -1200, 2160, 3840), D(2, 2560, 180, 1920, 1080) };
            var twoSpan = new MonitorSelection.Plan { Indices = new[] { 0, 1 }, MainhandIndex = 0, WorkspaceIndex = 1,
                Bounds = new Rectangle(-2160, -1200, 4720, 3840), MainhandBounds = new Rectangle(0, 0, 2560, 1440),
                WorkspaceBounds = new Rectangle(-2160, -1200, 2160, 3840) };
            shapes = DisplayPreview.Shapes(three, twoSpan, box, out span);
            Check(shapes.Count == 5, "three displays, the game and the workspace (no free part: each fills its own display)");
            Check(shapes[2].Title == "Display 3" && shapes[2].Detail == "1920\u00d71080", "the desktop display, nothing on it: its name and size");
            Check(shapes[2].Badge == null, "(and no number badge repeating it)");
            Check(shapes[1].Area.Height > shapes[0].Area.Height * 2.5f, "the portrait display drawn tall");
            Check(shapes[2].Area.Left >= shapes[0].Area.Right - 0.5f, "the desktop display to the game's right");
            Save(folder, "preview-three", three, twoSpan);

            // workspaces A and B (multi-region layouts)
            var multi = new MonitorSelection.Plan { Indices = new[] { 0, 1 }, MainhandIndex = 0, WorkspaceIndex = 1,
                Bounds = new Rectangle(-2160, -1200, 4720, 3840), MainhandBounds = new Rectangle(0, 0, 2560, 1440),
                Workspaces = new[] { new MonitorSelection.WorkspaceRegion { Id = "A", DisplayIndex = 1, Bounds = new Rectangle(-2160, -1200, 2160, 1920) },
                    new MonitorSelection.WorkspaceRegion { Id = "B", DisplayIndex = 1, Bounds = new Rectangle(-2160, 720, 2160, 1920) } } };
            shapes = DisplayPreview.Shapes(three, multi, box, out span);
            Check(shapes.Count == 6 && shapes[4].Title == "Workspace A" && shapes[5].Title == "Workspace B", "each workspace named");
            Check(shapes[4].Titles[1] == "A", "(just its letter when small)");
            Save(folder, "preview-workspaces", three, multi);

            // no plan yet: just the displays; no displays: nothing to draw
            shapes = DisplayPreview.Shapes(three, null, box, out span);
            Check(shapes.Count == 3 && span.Width == 0, "no plan yet: the displays alone, no span");
            shapes = DisplayPreview.Shapes(new List<MonitorSelection.Display>(), null, box, out span);
            Check(shapes.Count == 0, "no displays: nothing drawn");
            Check(DisplayPreview.Shapes(ultrawide, split, new Size(4, 4), out span).Count == 0, "a box too small: nothing drawn");

            Console.WriteLine("DisplayPreview: " + assertions + " assertions passed");
            return 0;
        }
    }
}
