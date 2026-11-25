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

            // other arrangements: whatever the layout, every display keeps its place relative to the others, nothing
            // overlaps that doesn't overlap on the desktop, the game and workspace sit on their own displays, and it all fits
            var layouts = new List<KeyValuePair<string, List<MonitorSelection.Display>>>
            {
                // the Offhand monitor stacked above the game monitor
                new KeyValuePair<string, List<MonitorSelection.Display>>("stacked",
                    new List<MonitorSelection.Display> { D(0, 0, 0, 2560, 1440), D(1, 320, -1080, 1920, 1080) }),
                // four in a 2x2 grid
                new KeyValuePair<string, List<MonitorSelection.Display>>("grid",
                    new List<MonitorSelection.Display> { D(0, 0, 0, 1920, 1080), D(1, 1920, 0, 1920, 1080), D(2, 0, 1080, 1920, 1080), D(3, 1920, 1080, 1920, 1080) }),
                // a gap between two monitors (Windows allows it), the second lower down
                new KeyValuePair<string, List<MonitorSelection.Display>>("gap",
                    new List<MonitorSelection.Display> { D(0, 0, 0, 2560, 1440), D(1, 3000, 400, 1920, 1080) }),
                // the game on a monitor left of the primary (negative coordinates), workspace on the primary
                new KeyValuePair<string, List<MonitorSelection.Display>>("left-of-primary",
                    new List<MonitorSelection.Display> { D(0, -3840, 0, 3840, 2160), D(1, 0, 540, 1920, 1080) }),
                // three ultrawides side by side: a very wide, thin strip
                new KeyValuePair<string, List<MonitorSelection.Display>>("three-ultrawides",
                    new List<MonitorSelection.Display> { D(0, 0, 0, 5120, 1440), D(1, 5120, 0, 5120, 1440), D(2, -5120, 0, 5120, 1440) }),
                // your own three: the portrait Samsung, the LG and the MSI, tops not lined up
                new KeyValuePair<string, List<MonitorSelection.Display>>("yours",
                    new List<MonitorSelection.Display> { D(0, 0, 0, 2560, 1440), D(1, -2160, -1630, 2160, 3840), D(2, 2560, 360, 1920, 1080) }),
            };
            foreach (var layout in layouts)
            {
                var ds = layout.Value;
                var p = new MonitorSelection.Plan { Indices = new[] { 0, 1 }, MainhandIndex = 0, WorkspaceIndex = 1,
                    MainhandBounds = ds[0].Bounds, WorkspaceBounds = ds[1].Bounds,
                    Bounds = Rectangle.Union(ds[0].Bounds, ds[1].Bounds) };
                shapes = DisplayPreview.Shapes(ds, p, box, out span);
                string n = layout.Key + ": ";
                Check(shapes.Count == ds.Count + 2, n + "each display, the game and the workspace");
                for (int i = 0; i < ds.Count; i++)
                {
                    RectangleF a = shapes[i].Area;
                    Check(a.Left >= -0.01f && a.Top >= -0.01f && a.Right <= box.Width + 0.01f && a.Bottom <= box.Height + 0.01f, n + "display " + i + " inside the preview");
                    Check(a.Width >= 1 && a.Height >= 1, n + "display " + i + " visible");
                    Check(Math.Abs(a.Width / a.Height - (float)ds[i].Bounds.Width / ds[i].Bounds.Height) < 0.05f, n + "display " + i + " keeps its shape");
                    for (int j = 0; j < ds.Count; j++)
                    {
                        if (i == j) continue;
                        RectangleF b = shapes[j].Area;
                        Rectangle da = ds[i].Bounds, db = ds[j].Bounds;
                        Check((da.Left < db.Left) == (a.Left < b.Left - 0.01f) || da.Left == db.Left, n + "left-to-right order kept for " + i + "," + j);
                        Check((da.Top < db.Top) == (a.Top < b.Top - 0.01f) || da.Top == db.Top, n + "top-to-bottom order kept for " + i + "," + j);
                        RectangleF overlap = RectangleF.Intersect(a, b);
                        Check(overlap.Width < 0.5f || overlap.Height < 0.5f, n + "displays " + i + " and " + j + " don't overlap");
                    }
                }
                Check(Near(shapes[ds.Count].Area.X, shapes[0].Area.X) && Near(shapes[ds.Count].Area.Width, shapes[0].Area.Width), n + "the game on the game display");
                Check(Near(shapes[ds.Count + 1].Area.Y, shapes[1].Area.Y) && Near(shapes[ds.Count + 1].Area.Height, shapes[1].Area.Height), n + "the workspace on the workspace display");
                Save(folder, "arrangement-" + layout.Key, ds, p);
            }
            // the grid's bottom monitors only touch the game and workspace along an edge: still spare, still named
            shapes = DisplayPreview.Shapes(layouts[1].Value, new MonitorSelection.Plan { MainhandBounds = layouts[1].Value[0].Bounds,
                WorkspaceBounds = layouts[1].Value[1].Bounds, Bounds = new Rectangle(0, 0, 3840, 1080) }, box, out span);
            Check(shapes[2].Title == "Display 3" && shapes[3].Title == "Display 4", "monitors touching an area along an edge stay named");
            // gaps stay gaps: the gap layout's second display starts to the right of the first, with space between
            shapes = DisplayPreview.Shapes(layouts[2].Value, null, box, out span);
            Check(shapes[1].Area.Left > shapes[0].Area.Right + 2, "a gap between monitors shows as a gap");

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
