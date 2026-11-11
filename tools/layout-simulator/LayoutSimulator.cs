using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

namespace Offhand.LayoutSimulator
{
    public sealed class VirtualMonitor
    {
        public string Role;
        public string DeviceName;
        public string StableId;
        public Rectangle Bounds;
        public bool Primary;
    }

    public sealed class VirtualRegion
    {
        public string Id;
        public string DeviceName;
        public Rectangle Bounds;
    }

    public sealed class TopologyPreset
    {
        public string Id;
        public string Name;
        public string Category;
        public string Description;
        public int Schema;
        public string Mode;
        public string PrimaryWorkspaceId;
        public string WorkspaceProfileId;
        public string WorkspaceProfileName;
        public List<VirtualMonitor> Monitors = new List<VirtualMonitor>();
        public VirtualRegion Game;
        public List<VirtualRegion> Workspaces = new List<VirtualRegion>();

        public Rectangle ComputeUnionBounds()
        {
            Rectangle union = Game.Bounds;
            foreach (VirtualRegion ws in Workspaces)
            {
                union = Rectangle.Union(union, ws.Bounds);
            }
            if (Schema == 1 && Mode == "DUAL_DISPLAY")
            {
                foreach (VirtualMonitor m in Monitors)
                {
                    union = Rectangle.Union(union, m.Bounds);
                }
            }
            return union;
        }

        public TopologyPreset Clone()
        {
            var copy = new TopologyPreset
            {
                Id = Id,
                Name = Name,
                Category = Category,
                Description = Description,
                Schema = Schema,
                Mode = Mode,
                PrimaryWorkspaceId = PrimaryWorkspaceId,
                WorkspaceProfileId = WorkspaceProfileId,
                WorkspaceProfileName = WorkspaceProfileName,
                Game = new VirtualRegion { Id = Game.Id, DeviceName = Game.DeviceName, Bounds = Game.Bounds }
            };
            foreach (VirtualMonitor m in Monitors)
            {
                copy.Monitors.Add(new VirtualMonitor
                {
                    Role = m.Role,
                    DeviceName = m.DeviceName,
                    StableId = m.StableId,
                    Bounds = m.Bounds,
                    Primary = m.Primary
                });
            }
            foreach (VirtualRegion ws in Workspaces)
            {
                copy.Workspaces.Add(new VirtualRegion
                {
                    Id = ws.Id,
                    DeviceName = ws.DeviceName,
                    Bounds = ws.Bounds
                });
            }
            return copy;
        }

        public void SyncMonitorsFromRegions()
        {
            Monitors.Clear();
            Monitors.Add(new VirtualMonitor
            {
                Role = "mainhand",
                DeviceName = Game.DeviceName ?? @"\\.\DISPLAY_SIM1",
                StableId = "SIM-CUSTOM-GAME",
                Bounds = Game.Bounds,
                Primary = true
            });
            for (int i = 0; i < Workspaces.Count; i++)
            {
                VirtualRegion ws = Workspaces[i];
                string dev = string.Format(@"\\.\DISPLAY_SIM{0}", i + 2);
                ws.DeviceName = dev;
                Monitors.Add(new VirtualMonitor
                {
                    Role = ws.Id,
                    DeviceName = dev,
                    StableId = "SIM-CUSTOM-WS-" + (i + 1),
                    Bounds = ws.Bounds,
                    Primary = false
                });
            }
            if (Workspaces.Count > 1)
            {
                if (Schema < 2) Schema = 2;
                Mode = "CUSTOM_REGIONS";
                if (string.IsNullOrEmpty(WorkspaceProfileId))
                    WorkspaceProfileId = "99999999999999999999999999999999";
                if (string.IsNullOrEmpty(WorkspaceProfileName))
                    WorkspaceProfileName = "Custom Simulated Layout";
            }
            else if (Workspaces.Count == 1)
            {
                PrimaryWorkspaceId = Workspaces[0].Id;
            }
        }

        public override string ToString()
        {
            return Name;
        }
    }

    public sealed class InGameLayoutTelemetry
    {
        public double UiParentWidth;
        public double UiParentHeight;
        public double UiEffectiveScale;
        public double GameUiWidth;
        public double GameUiHeight;
        public double WorkspaceUiWidth;
        public double WorkspaceUiHeight;
        public double DesiredHudScale;
        public double WorldTextRatio;
        public double CoveragePercent;
        public long VoidPixelArea;
        public string GameAspectText;
        public string TalentsFitStatus;
        public bool TalentsFitsWorkspace;
        public double TalentsScaleFactor;
        public string WorldMapFitStatus;
        public bool WorldMapFitsWorkspace;

        public static InGameLayoutTelemetry Compute(ScaledSimulationPlan plan)
        {
            if (plan == null) return null;
            double pw = Math.Max(1, plan.TopologyWidth);
            double ph = Math.Max(1, plan.TopologyHeight);
            double sh = 768.0;
            double sw = pw * (sh / ph);
            double ux = sw / pw;
            double uy = sh / ph;

            double gw = plan.ScaledGame.Bounds.Width;
            double gh = plan.ScaledGame.Bounds.Height;
            double wsw = plan.PrimaryWorkspace.Bounds.Width;
            double wsh = plan.PrimaryWorkspace.Bounds.Height;

            double geomScale = Math.Min(gh / ph, (gw * 768.0) / (1100.0 * ph));
            double hudScale = Math.Max(0.05, geomScale * 0.70);
            double heightRatio = gh / ph;
            double worldText = Math.Abs(heightRatio - 1.0) <= 0.01 ? 1.0 : hudScale;

            double gameUiW = gw * ux;
            double gameUiH = gh * uy;
            double wsUiW = wsw * ux;
            double wsUiH = wsh * uy;

            // Blizzard standard panel dimensions in UIParent units:
            // PlayerSpellsFrame ~ 1150x680, WorldMapFrame ~ 1002x668
            double availW = Math.Max(0, wsUiW - 24.0);
            double availH = Math.Max(0, wsUiH - 24.0);

            double talentsScale = Math.Min(1.0, Math.Min(availW / 1150.0, availH / 680.0));
            bool talentsFits;
            string talentsText;
            if (plan.Preset.Schema >= 2)
            {
                talentsFits = availW >= 1150.0 && availH >= 680.0;
                talentsText = talentsFits
                    ? "FITS WORKSPACE (100% Native)"
                    : "MAINHAND RECOVERY (Too narrow for native Talents in Schema " + plan.Preset.Schema + ")";
            }
            else
            {
                talentsFits = talentsScale >= 0.45;
                talentsText = talentsScale >= 0.999
                    ? "FITS WORKSPACE (100% Native)"
                    : string.Format(CultureInfo.InvariantCulture, "AUTO-SCALED IN WORKSPACE ({0:0}% Scale)", talentsScale * 100.0);
            }

            bool mapFits = availW >= 700.0 && availH >= 460.0;
            string mapText = (availW >= 1002.0 && availH >= 668.0)
                ? "FITS WORKSPACE (100% Large Map)"
                : (mapFits ? "FITS WORKSPACE (Compact/Scaled)" : "MAINHAND RECOVERY");

            long activeArea = (long)plan.ScaledGame.Bounds.Width * plan.ScaledGame.Bounds.Height;
            foreach (VirtualRegion ws in plan.ScaledWorkspaces)
            {
                activeArea += (long)ws.Bounds.Width * ws.Bounds.Height;
            }
            long totalArea = (long)plan.TopologyWidth * plan.TopologyHeight;
            long voidArea = Math.Max(0L, totalArea - activeArea);
            double coverage = totalArea > 0 ? Math.Min(100.0, (activeArea * 100.0) / totalArea) : 100.0;

            return new InGameLayoutTelemetry
            {
                UiParentWidth = sw,
                UiParentHeight = sh,
                UiEffectiveScale = uy,
                GameUiWidth = gameUiW,
                GameUiHeight = gameUiH,
                WorkspaceUiWidth = wsUiW,
                WorkspaceUiHeight = wsUiH,
                DesiredHudScale = hudScale,
                WorldTextRatio = worldText,
                CoveragePercent = coverage,
                VoidPixelArea = voidArea,
                GameAspectText = FormatAspectRatio(plan.ScaledGame.Bounds.Width, plan.ScaledGame.Bounds.Height),
                TalentsFitStatus = talentsText,
                TalentsFitsWorkspace = talentsFits,
                TalentsScaleFactor = talentsScale,
                WorldMapFitStatus = mapText,
                WorldMapFitsWorkspace = mapFits
            };
        }

        public static string FormatAspectRatio(int w, int h)
        {
            if (w <= 0 || h <= 0) return "?";
            double r = (double)w / h;
            if (Math.Abs(r - 16.0 / 9.0) < 0.03) return "16:9";
            if (Math.Abs(r - 16.0 / 10.0) < 0.03) return "16:10";
            if (Math.Abs(r - 21.0 / 9.0) < 0.08) return "21:9";
            if (Math.Abs(r - 32.0 / 9.0) < 0.08) return "32:9";
            if (Math.Abs(r - 9.0 / 16.0) < 0.03) return "9:16 Portrait";
            return string.Format(CultureInfo.InvariantCulture, "{0:0.00}:1", r);
        }
    }

    public sealed class ScaledSimulationPlan
    {
        public TopologyPreset Preset;
        public double ScaleFactor;
        public string ScaleLabel;
        public Rectangle WindowBounds;
        public int TopologyWidth;
        public int TopologyHeight;
        public VirtualRegion ScaledGame;
        public List<VirtualRegion> ScaledWorkspaces = new List<VirtualRegion>();
        public List<VirtualMonitor> ScaledMonitors = new List<VirtualMonitor>();
        public VirtualRegion PrimaryWorkspace;
    }

    public static class PresetCatalog
    {
        public static List<TopologyPreset> CreateAll()
        {
            var list = new List<TopologyPreset>();

            // 1. Dual 1080p Landscape (Mainhand Left)
            list.Add(new TopologyPreset
            {
                Id = "dual-1080p-left",
                Name = "Dual 1080p Side-by-Side (1920x1080 + 1920x1080, Game Left)",
                Category = "Schema 1: Standard Dual",
                Description = "Two 1920x1080 16:9 monitors side-by-side (3840x1080 total). Mainhand on Display 1 (Left), Offhand Workspace on Display 2 (Right).",
                Schema = 1,
                Mode = "DUAL_DISPLAY",
                Monitors = new List<VirtualMonitor>
                {
                    new VirtualMonitor { Role = "mainhand", DeviceName = @"\\.\DISPLAY_SIM1", StableId = "SIM-1080P-A", Bounds = new Rectangle(0, 0, 1920, 1080), Primary = true },
                    new VirtualMonitor { Role = "workspace", DeviceName = @"\\.\DISPLAY_SIM2", StableId = "SIM-1080P-B", Bounds = new Rectangle(1920, 0, 1920, 1080), Primary = false }
                },
                Game = new VirtualRegion { Id = "game", DeviceName = @"\\.\DISPLAY_SIM1", Bounds = new Rectangle(0, 0, 1920, 1080) },
                Workspaces = new List<VirtualRegion>
                {
                    new VirtualRegion { Id = "workspace", DeviceName = @"\\.\DISPLAY_SIM2", Bounds = new Rectangle(1920, 0, 1920, 1080) }
                },
                PrimaryWorkspaceId = "workspace"
            });

            // 2. Dual 1440p Landscape (Mainhand Right, Negative Left Workspace)
            list.Add(new TopologyPreset
            {
                Id = "dual-1440p-right",
                Name = "Dual 1440p Side-by-Side (2560x1440 + 2560x1440, Game Right / Negative Origin)",
                Category = "Schema 1: Standard Dual",
                Description = "Two 2560x1440 16:9 monitors (5120x1440 total) with negative Windows desktop coordinates (-2560,0) for the left workspace monitor.",
                Schema = 1,
                Mode = "DUAL_DISPLAY",
                Monitors = new List<VirtualMonitor>
                {
                    new VirtualMonitor { Role = "workspace", DeviceName = @"\\.\DISPLAY_SIM2", StableId = "SIM-1440P-LEFT", Bounds = new Rectangle(-2560, 0, 2560, 1440), Primary = false },
                    new VirtualMonitor { Role = "mainhand", DeviceName = @"\\.\DISPLAY_SIM1", StableId = "SIM-1440P-MAIN", Bounds = new Rectangle(0, 0, 2560, 1440), Primary = true }
                },
                Game = new VirtualRegion { Id = "game", DeviceName = @"\\.\DISPLAY_SIM1", Bounds = new Rectangle(0, 0, 2560, 1440) },
                Workspaces = new List<VirtualRegion>
                {
                    new VirtualRegion { Id = "workspace", DeviceName = @"\\.\DISPLAY_SIM2", Bounds = new Rectangle(-2560, 0, 2560, 1440) }
                },
                PrimaryWorkspaceId = "workspace"
            });

            // 3. Dual 4K Landscape (7680x2160)
            list.Add(new TopologyPreset
            {
                Id = "dual-4k-left",
                Name = "Dual 4K UHD Side-by-Side (3840x2160 + 3840x2160)",
                Category = "Schema 1: Standard Dual",
                Description = "Two 3840x2160 4K monitors side-by-side (7680x2160 total). Ideal for testing high-resolution scaling with Fit-to-Host proportional scaling.",
                Schema = 1,
                Mode = "DUAL_DISPLAY",
                Monitors = new List<VirtualMonitor>
                {
                    new VirtualMonitor { Role = "mainhand", DeviceName = @"\\.\DISPLAY_SIM1", StableId = "SIM-4K-A", Bounds = new Rectangle(0, 0, 3840, 2160), Primary = true },
                    new VirtualMonitor { Role = "workspace", DeviceName = @"\\.\DISPLAY_SIM2", StableId = "SIM-4K-B", Bounds = new Rectangle(3840, 0, 3840, 2160), Primary = false }
                },
                Game = new VirtualRegion { Id = "game", DeviceName = @"\\.\DISPLAY_SIM1", Bounds = new Rectangle(0, 0, 3840, 2160) },
                Workspaces = new List<VirtualRegion>
                {
                    new VirtualRegion { Id = "workspace", DeviceName = @"\\.\DISPLAY_SIM2", Bounds = new Rectangle(3840, 0, 3840, 2160) }
                },
                PrimaryWorkspaceId = "workspace"
            });

            // 4. Portrait 1080p Left + 1440p Landscape Right (Mixed Height + Vertical Offset)
            list.Add(new TopologyPreset
            {
                Id = "portrait-1080p-landscape-1440p",
                Name = "Portrait 1080p Left + 1440p Landscape Right (1080x1920 + 2560x1440, Offset)",
                Category = "Schema 1: Asymmetric & Mixed",
                Description = "Asymmetric mixed-height setup (3640x1920 total bounding box). Left screen is 1080x1920 Portrait workspace; Right screen is 2560x1440 Mainhand offset vertically by 240px.",
                Schema = 1,
                Mode = "DUAL_DISPLAY",
                Monitors = new List<VirtualMonitor>
                {
                    new VirtualMonitor { Role = "workspace", DeviceName = @"\\.\DISPLAY_SIM_PORTRAIT", StableId = "SIM-PORTRAIT-1080", Bounds = new Rectangle(-1080, -240, 1080, 1920), Primary = false },
                    new VirtualMonitor { Role = "mainhand", DeviceName = @"\\.\DISPLAY_SIM_MAIN", StableId = "SIM-LANDSCAPE-1440", Bounds = new Rectangle(0, 0, 2560, 1440), Primary = true }
                },
                Game = new VirtualRegion { Id = "game", DeviceName = @"\\.\DISPLAY_SIM_MAIN", Bounds = new Rectangle(0, 0, 2560, 1440) },
                Workspaces = new List<VirtualRegion>
                {
                    new VirtualRegion { Id = "workspace", DeviceName = @"\\.\DISPLAY_SIM_PORTRAIT", Bounds = new Rectangle(-1080, -240, 1080, 1920) }
                },
                PrimaryWorkspaceId = "workspace"
            });

            // 5. Ultrawide 21:9 (3440x1440) + Portrait 1440p (1440x2560)
            list.Add(new TopologyPreset
            {
                Id = "ultrawide-21-9-portrait-1440p",
                Name = "Ultrawide 21:9 (3440x1440) + Portrait 1440p (1440x2560)",
                Category = "Schema 1: Asymmetric & Mixed",
                Description = "3440x1440 21:9 Ultrawide Mainhand on the right with a tall 1440x2560 Portrait workspace on the left (4880x2560 total bounding box).",
                Schema = 1,
                Mode = "DUAL_DISPLAY",
                Monitors = new List<VirtualMonitor>
                {
                    new VirtualMonitor { Role = "workspace", DeviceName = @"\\.\DISPLAY_SIM_TALL", StableId = "SIM-PORTRAIT-1440", Bounds = new Rectangle(-1440, -560, 1440, 2560), Primary = false },
                    new VirtualMonitor { Role = "mainhand", DeviceName = @"\\.\DISPLAY_SIM_UW", StableId = "SIM-UW-3440", Bounds = new Rectangle(0, 0, 3440, 1440), Primary = true }
                },
                Game = new VirtualRegion { Id = "game", DeviceName = @"\\.\DISPLAY_SIM_UW", Bounds = new Rectangle(0, 0, 3440, 1440) },
                Workspaces = new List<VirtualRegion>
                {
                    new VirtualRegion { Id = "workspace", DeviceName = @"\\.\DISPLAY_SIM_TALL", Bounds = new Rectangle(-1440, -560, 1440, 2560) }
                },
                PrimaryWorkspaceId = "workspace"
            });

            // 6. 4K Mainhand + 1440p Workspace (Mixed Resolution Landscape)
            list.Add(new TopologyPreset
            {
                Id = "mixed-4k-1440p",
                Name = "4K Mainhand (3840x2160) + 1440p Workspace (2560x1440, Bottom-Aligned)",
                Category = "Schema 1: Asymmetric & Mixed",
                Description = "3840x2160 4K Mainhand on Left + 2560x1440 Workspace on Right, aligned along the bottom edge (6400x2160 total bounding box).",
                Schema = 1,
                Mode = "DUAL_DISPLAY",
                Monitors = new List<VirtualMonitor>
                {
                    new VirtualMonitor { Role = "mainhand", DeviceName = @"\\.\DISPLAY_SIM_4K", StableId = "SIM-4K-MAIN", Bounds = new Rectangle(0, 0, 3840, 2160), Primary = true },
                    new VirtualMonitor { Role = "workspace", DeviceName = @"\\.\DISPLAY_SIM_QHD", StableId = "SIM-QHD-WORK", Bounds = new Rectangle(3840, 720, 2560, 1440), Primary = false }
                },
                Game = new VirtualRegion { Id = "game", DeviceName = @"\\.\DISPLAY_SIM_4K", Bounds = new Rectangle(0, 0, 3840, 2160) },
                Workspaces = new List<VirtualRegion>
                {
                    new VirtualRegion { Id = "workspace", DeviceName = @"\\.\DISPLAY_SIM_QHD", Bounds = new Rectangle(3840, 720, 2560, 1440) }
                },
                PrimaryWorkspaceId = "workspace"
            });

            // 7. Stacked Vertical (2560x1440 Bottom Game + 1920x1080 Top Workspace)
            list.Add(new TopologyPreset
            {
                Id = "stacked-vertical-1440p-1080p",
                Name = "Stacked Vertical (2560x1440 Bottom Game + 1920x1080 Top Centered Workspace)",
                Category = "Schema 1: Stacked & Split",
                Description = "Vertical over/under monitor mount (2560x2520 total). 2560x1440 Mainhand on bottom, 1920x1080 Workspace centered above it.",
                Schema = 1,
                Mode = "DUAL_DISPLAY",
                Monitors = new List<VirtualMonitor>
                {
                    new VirtualMonitor { Role = "mainhand", DeviceName = @"\\.\DISPLAY_SIM_BOTTOM", StableId = "SIM-STACK-BOT", Bounds = new Rectangle(0, 0, 2560, 1440), Primary = true },
                    new VirtualMonitor { Role = "workspace", DeviceName = @"\\.\DISPLAY_SIM_TOP", StableId = "SIM-STACK-TOP", Bounds = new Rectangle(320, -1080, 1920, 1080), Primary = false }
                },
                Game = new VirtualRegion { Id = "game", DeviceName = @"\\.\DISPLAY_SIM_BOTTOM", Bounds = new Rectangle(0, 0, 2560, 1440) },
                Workspaces = new List<VirtualRegion>
                {
                    new VirtualRegion { Id = "workspace", DeviceName = @"\\.\DISPLAY_SIM_TOP", Bounds = new Rectangle(320, -1080, 1920, 1080) }
                },
                PrimaryWorkspaceId = "workspace"
            });

            // 8. Super-Ultrawide 32:9 Equal Split (5120x1440)
            list.Add(new TopologyPreset
            {
                Id = "super-ultrawide-32-9-split",
                Name = "Super-Ultrawide 32:9 Single-Display 50/50 Split (5120x1440)",
                Category = "Schema 1: Stacked & Split",
                Description = "Single 49-inch 5120x1440 32:9 display divided equally into 2560x1440 Game (Right) and 2560x1440 Workspace (Left).",
                Schema = 1,
                Mode = "SPLIT_ULTRAWIDE",
                Monitors = new List<VirtualMonitor>
                {
                    new VirtualMonitor { Role = "mainhand", DeviceName = @"\\.\DISPLAY_SIM_329", StableId = "SIM-329-SINGLE", Bounds = new Rectangle(0, 0, 5120, 1440), Primary = true }
                },
                Game = new VirtualRegion { Id = "game", DeviceName = @"\\.\DISPLAY_SIM_329", Bounds = new Rectangle(2560, 0, 2560, 1440) },
                Workspaces = new List<VirtualRegion>
                {
                    new VirtualRegion { Id = "workspace", DeviceName = @"\\.\DISPLAY_SIM_329", Bounds = new Rectangle(0, 0, 2560, 1440) }
                },
                PrimaryWorkspaceId = "workspace"
            });

            // 9. Single-Monitor Partial Occupied Split (3440x1440 Game + 640x1440 Workspace on 5120x1440)
            list.Add(new TopologyPreset
            {
                Id = "partial-single-4080x1440",
                Name = "Partial Single-Monitor Split (3440x1440 Game + 640x1440 Workspace = 4080x1440)",
                Category = "Schema 1: Stacked & Split",
                Description = "Occupies 4080x1440 on a 5120x1440 monitor (leaving 1040px free desktop), with 640x1440 Workspace on Left and 3440x1440 21:9 Game on Right.",
                Schema = 1,
                Mode = "SPLIT_ULTRAWIDE",
                Monitors = new List<VirtualMonitor>
                {
                    new VirtualMonitor { Role = "mainhand", DeviceName = @"\\.\DISPLAY_SIM_329", StableId = "SIM-329-PARTIAL", Bounds = new Rectangle(0, 0, 4080, 1440), Primary = true }
                },
                Game = new VirtualRegion { Id = "game", DeviceName = @"\\.\DISPLAY_SIM_329", Bounds = new Rectangle(640, 0, 3440, 1440) },
                Workspaces = new List<VirtualRegion>
                {
                    new VirtualRegion { Id = "workspace", DeviceName = @"\\.\DISPLAY_SIM_329", Bounds = new Rectangle(0, 0, 640, 1440) }
                },
                PrimaryWorkspaceId = "workspace"
            });

            // 10. Schema 2: Three-Monitor Multi-Workspace (2560x1440 Center Game + Left & Right Workspaces)
            list.Add(new TopologyPreset
            {
                Id = "schema2-three-monitors",
                Name = "Three-Monitor Dual Workspace (1080p Left WS-A + 1440p Center Game + 1080p Right WS-B)",
                Category = "Schema 2: Multi-Monitor Workspaces",
                Description = "Three separate monitors: 2560x1440 Center Mainhand flanked by Workspace A (Left, 1920x1080) and Workspace B (Right, 1920x1080).",
                Schema = 2,
                Mode = "CUSTOM_REGIONS",
                PrimaryWorkspaceId = "workspace-a",
                WorkspaceProfileId = "11111111111111111111111111111111",
                WorkspaceProfileName = "Sim Tri-Screen Battlestation",
                Monitors = new List<VirtualMonitor>
                {
                    new VirtualMonitor { Role = "mainhand", DeviceName = @"\\.\DISPLAY_SIM_CENTER", StableId = "SIM-3M-CENTER", Bounds = new Rectangle(0, 0, 2560, 1440), Primary = true },
                    new VirtualMonitor { Role = "workspace-a", DeviceName = @"\\.\DISPLAY_SIM_LEFT", StableId = "SIM-3M-LEFT", Bounds = new Rectangle(-1920, 180, 1920, 1080), Primary = false },
                    new VirtualMonitor { Role = "workspace-b", DeviceName = @"\\.\DISPLAY_SIM_RIGHT", StableId = "SIM-3M-RIGHT", Bounds = new Rectangle(2560, 180, 1920, 1080), Primary = false }
                },
                Game = new VirtualRegion { Id = "game", DeviceName = @"\\.\DISPLAY_SIM_CENTER", Bounds = new Rectangle(0, 0, 2560, 1440) },
                Workspaces = new List<VirtualRegion>
                {
                    new VirtualRegion { Id = "workspace-a", DeviceName = @"\\.\DISPLAY_SIM_LEFT", Bounds = new Rectangle(-1920, 180, 1920, 1080) },
                    new VirtualRegion { Id = "workspace-b", DeviceName = @"\\.\DISPLAY_SIM_RIGHT", Bounds = new Rectangle(2560, 180, 1920, 1080) }
                }
            });

            // 11. Schema 3: Flexible Layout — Centered Game between Two Workspaces on One 32:9 Display
            list.Add(new TopologyPreset
            {
                Id = "schema3-centered-wings",
                Name = "Flexible 32:9 Centered Game (1280px Left WS-A + 2560px Center Game + 1280px Right WS-B)",
                Category = "Schema 3: Flexible Layouts",
                Description = "Single 5120x1440 display split into 3 regions: 1280x1440 Left Workspace A, 2560x1440 Center Mainhand Game, and 1280x1440 Right Workspace B.",
                Schema = 3,
                Mode = "CUSTOM_REGIONS",
                PrimaryWorkspaceId = "workspace-a",
                WorkspaceProfileId = "22222222222222222222222222222222",
                WorkspaceProfileName = "Sim Centered Wings",
                Monitors = new List<VirtualMonitor>
                {
                    new VirtualMonitor { Role = "screen", DeviceName = @"\\.\DISPLAY_SIM_ULTRA", StableId = "SIM-FLEX-ULTRA", Bounds = new Rectangle(0, 0, 5120, 1440), Primary = true }
                },
                Game = new VirtualRegion { Id = "game", DeviceName = @"\\.\DISPLAY_SIM_ULTRA", Bounds = new Rectangle(1280, 0, 2560, 1440) },
                Workspaces = new List<VirtualRegion>
                {
                    new VirtualRegion { Id = "workspace-a", DeviceName = @"\\.\DISPLAY_SIM_ULTRA", Bounds = new Rectangle(0, 0, 1280, 1440) },
                    new VirtualRegion { Id = "workspace-b", DeviceName = @"\\.\DISPLAY_SIM_ULTRA", Bounds = new Rectangle(3840, 0, 1280, 1440) }
                }
            });

            // 12. Schema 3: Flexible Layout — Two Stacked Workspaces on Left + Game on Right
            list.Add(new TopologyPreset
            {
                Id = "schema3-stacked-sidebar",
                Name = "Flexible Stacked Sidebar (Two 1280x720 Stacked Workspaces + 3840x1440 Game)",
                Category = "Schema 3: Flexible Layouts",
                Description = "Single 5120x1440 display with two stacked 1280x720 workspaces on the left (WS-A top, WS-B bottom) and a 3840x1440 Game area on the right.",
                Schema = 3,
                Mode = "CUSTOM_REGIONS",
                PrimaryWorkspaceId = "workspace-a",
                WorkspaceProfileId = "33333333333333333333333333333333",
                WorkspaceProfileName = "Sim Stacked Sidebar",
                Monitors = new List<VirtualMonitor>
                {
                    new VirtualMonitor { Role = "screen", DeviceName = @"\\.\DISPLAY_SIM_ULTRA", StableId = "SIM-FLEX-STACK", Bounds = new Rectangle(0, 0, 5120, 1440), Primary = true }
                },
                Game = new VirtualRegion { Id = "game", DeviceName = @"\\.\DISPLAY_SIM_ULTRA", Bounds = new Rectangle(1280, 0, 3840, 1440) },
                Workspaces = new List<VirtualRegion>
                {
                    new VirtualRegion { Id = "workspace-a", DeviceName = @"\\.\DISPLAY_SIM_ULTRA", Bounds = new Rectangle(0, 0, 1280, 720) },
                    new VirtualRegion { Id = "workspace-b", DeviceName = @"\\.\DISPLAY_SIM_ULTRA", Bounds = new Rectangle(0, 720, 1280, 720) }
                }
            });

            return list;
        }
    }

    public static class PlanScaler
    {
        public static ScaledSimulationPlan BuildPlan(
            TopologyPreset preset,
            string scaleMode,
            double customScale,
            Rectangle hostDesktopBounds,
            Point windowOrigin)
        {
            if (preset == null) throw new ArgumentNullException("preset");
            Rectangle rawUnion = preset.ComputeUnionBounds();
            if (rawUnion.Width <= 0 || rawUnion.Height <= 0)
                throw new InvalidOperationException("Preset union bounds are invalid.");

            double factor = 1.0;
            string label = "1:1 Exact Pixel Size";

            if (scaleMode == "FIT_HOST")
            {
                double maxW = Math.Max(960, hostDesktopBounds.Width - 40);
                double maxH = Math.Max(600, hostDesktopBounds.Height - 60);
                factor = Math.Min(1.0, Math.Min(maxW / rawUnion.Width, maxH / rawUnion.Height));
                label = string.Format(CultureInfo.InvariantCulture, "Fit Host ({0:0.0}%)", factor * 100.0);
            }
            else if (scaleMode == "SCALE_75")
            {
                factor = 0.75;
                label = "75% Proportional Scale";
            }
            else if (scaleMode == "SCALE_50")
            {
                factor = 0.50;
                label = "50% Proportional Scale";
            }
            else if (scaleMode == "CUSTOM")
            {
                factor = Math.Max(0.25, Math.Min(1.5, customScale));
                label = string.Format(CultureInfo.InvariantCulture, "Custom ({0:0.0}%)", factor * 100.0);
            }

            // Ensure Schema 2 & 3 minimum region guardrails (Game >= 960x600, Workspace >= 480x600)
            // when scaling down a multi-region preset so WorkspaceRegions.lua accepts it cleanly!
            if (preset.Schema >= 2 && factor < 1.0)
            {
                double minFactor = 0.0;
                minFactor = Math.Max(minFactor, 960.0 / preset.Game.Bounds.Width);
                minFactor = Math.Max(minFactor, 600.0 / preset.Game.Bounds.Height);
                foreach (VirtualRegion ws in preset.Workspaces)
                {
                    minFactor = Math.Max(minFactor, 480.0 / ws.Bounds.Width);
                    minFactor = Math.Max(minFactor, 600.0 / ws.Bounds.Height);
                }
                if (factor < minFactor && minFactor <= 1.0)
                {
                    factor = minFactor;
                    label += string.Format(CultureInfo.InvariantCulture, " [Clamped to {0:0.0}% for Schema {1} min bounds]", factor * 100.0, preset.Schema);
                }
            }

            Func<int, int> scaleCoord = v => (int)Math.Round(v * factor);

            int totalW = Math.Max(1, scaleCoord(rawUnion.Width));
            int totalH = Math.Max(1, scaleCoord(rawUnion.Height));

            Func<Rectangle, Rectangle> toScaledRelative = r =>
            {
                int left = scaleCoord(r.Left - rawUnion.Left);
                int right = scaleCoord(r.Right - rawUnion.Left);
                int top = scaleCoord(r.Top - rawUnion.Top);
                int bottom = scaleCoord(r.Bottom - rawUnion.Top);
                int w = Math.Max(1, right - left);
                int h = Math.Max(1, bottom - top);
                // Convert top-left origin to bottom-left physical coordinate space used by CompanionTopology.lua
                int bottomY = totalH - bottom;
                return new Rectangle(left, bottomY, w, h);
            };

            var plan = new ScaledSimulationPlan
            {
                Preset = preset,
                ScaleFactor = factor,
                ScaleLabel = label,
                TopologyWidth = totalW,
                TopologyHeight = totalH,
                WindowBounds = new Rectangle(windowOrigin.X, windowOrigin.Y, totalW, totalH),
                ScaledGame = new VirtualRegion
                {
                    Id = preset.Game.Id,
                    DeviceName = preset.Game.DeviceName,
                    Bounds = toScaledRelative(preset.Game.Bounds)
                }
            };

            foreach (VirtualRegion ws in preset.Workspaces)
            {
                var scaledWs = new VirtualRegion
                {
                    Id = ws.Id,
                    DeviceName = ws.DeviceName,
                    Bounds = toScaledRelative(ws.Bounds)
                };
                plan.ScaledWorkspaces.Add(scaledWs);
                if (ws.Id == preset.PrimaryWorkspaceId)
                {
                    plan.PrimaryWorkspace = scaledWs;
                }
            }
            if (plan.PrimaryWorkspace == null && plan.ScaledWorkspaces.Count > 0)
            {
                plan.PrimaryWorkspace = plan.ScaledWorkspaces[0];
            }

            foreach (VirtualMonitor m in preset.Monitors)
            {
                plan.ScaledMonitors.Add(new VirtualMonitor
                {
                    Role = m.Role,
                    DeviceName = m.DeviceName,
                    StableId = m.StableId,
                    Primary = m.Primary,
                    Bounds = toScaledRelative(m.Bounds)
                });
            }

            return plan;
        }

        public static string FormatTopologyLua(ScaledSimulationPlan plan, string companionVersion)
        {
            if (plan == null) throw new ArgumentNullException("plan");
            TopologyPreset p = plan.Preset;
            var sb = new StringBuilder();
            sb.AppendLine("-- Generated by Offhand Virtual Layout Simulator. Restored automatically when reset.");
            sb.AppendLine("OffhandCompanionTopology = {");
            sb.AppendFormat(CultureInfo.InvariantCulture, "  schema = {0}, generatedAt = {1},\r\n",
                p.Schema, LuaString(DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture)));
            sb.AppendFormat(CultureInfo.InvariantCulture, "  companionVersion = {0},\r\n",
                LuaString(string.IsNullOrWhiteSpace(companionVersion) ? "2.1.5" : companionVersion));
            sb.AppendFormat(CultureInfo.InvariantCulture, "  mode = {0},\r\n", LuaString(p.Mode));
            sb.AppendFormat(CultureInfo.InvariantCulture, "  physicalWidth = {0}, physicalHeight = {1},\r\n",
                plan.TopologyWidth, plan.TopologyHeight);
            sb.AppendFormat(CultureInfo.InvariantCulture, "  mainhandDevice = {0},\r\n",
                LuaString(plan.ScaledGame.DeviceName));

            var selectedDevices = new List<string>();
            foreach (VirtualMonitor m in plan.ScaledMonitors)
            {
                selectedDevices.Add(LuaString(m.DeviceName));
            }
            sb.AppendFormat(CultureInfo.InvariantCulture, "  selectedDevices = {{ {0} }},\r\n",
                string.Join(", ", selectedDevices.ToArray()));

            sb.AppendFormat(CultureInfo.InvariantCulture, "  game = {0},\r\n", RectTable(plan.ScaledGame.Bounds));
            sb.AppendFormat(CultureInfo.InvariantCulture, "  workspace = {0},\r\n", RectTable(plan.PrimaryWorkspace.Bounds));

            if (p.Schema >= 2)
            {
                sb.AppendFormat(CultureInfo.InvariantCulture, "  primaryWorkspace = {0},\r\n",
                    LuaString(plan.PrimaryWorkspace.Id));
                sb.AppendLine("  workspaces = {");
                foreach (VirtualRegion ws in plan.ScaledWorkspaces)
                {
                    sb.AppendFormat(CultureInfo.InvariantCulture,
                        "    {{ id = {0}, device = {1}, x = {2}, y = {3}, width = {4}, height = {5} }},\r\n",
                        LuaString(ws.Id), LuaString(ws.DeviceName),
                        ws.Bounds.X, ws.Bounds.Y, ws.Bounds.Width, ws.Bounds.Height);
                }
                sb.AppendLine("  },");
            }

            if (p.Schema == 3)
            {
                sb.AppendLine("  coordinateSpace = \"BOTTOM_LEFT_PHYSICAL\",");
                sb.AppendLine("  displays = {");
                foreach (VirtualMonitor m in plan.ScaledMonitors)
                {
                    sb.AppendFormat(CultureInfo.InvariantCulture,
                        "    {{ device = {0}, x = {1}, y = {2}, width = {3}, height = {4} }},\r\n",
                        LuaString(m.DeviceName),
                        m.Bounds.X, m.Bounds.Y, m.Bounds.Width, m.Bounds.Height);
                }
                sb.AppendLine("  },");
            }

            string profId = (p.Schema >= 2 && !string.IsNullOrEmpty(p.WorkspaceProfileId)) ? LuaString(p.WorkspaceProfileId) : "nil";
            string profName = (p.Schema >= 2 && !string.IsNullOrEmpty(p.WorkspaceProfileName)) ? LuaString(p.WorkspaceProfileName) : "nil";
            sb.AppendFormat(CultureInfo.InvariantCulture, "  workspaceProfileID = {0}, workspaceProfileName = {1},\r\n", profId, profName);
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static string LuaString(string value)
        {
            return "\"" + (value ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
        }

        private static string RectTable(Rectangle r)
        {
            return string.Format(CultureInfo.InvariantCulture,
                "{{ x = {0}, y = {1}, width = {2}, height = {3} }}",
                r.X, r.Y, r.Width, r.Height);
        }
    }

    internal static class Win32Interop
    {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT
        {
            public int Left, Top, Right, Bottom;
            public int Width { get { return Right - Left; } }
            public int Height { get { return Bottom - Top; } }
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct POINT
        {
            public int X, Y;
        }

        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool IsIconic(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool IsZoomed(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll")]
        public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

        [DllImport("user32.dll")]
        public static extern int SetWindowRgn(IntPtr hWnd, IntPtr hRgn, bool bRedraw);

        [DllImport("user32.dll")]
        public static extern int GetWindowRgn(IntPtr hWnd, IntPtr hRgn);

        [DllImport("gdi32.dll")]
        public static extern IntPtr CreateRectRgn(int nLeftRect, int nTopRect, int nRightRect, int nBottomRect);

        [DllImport("gdi32.dll")]
        public static extern int CombineRgn(IntPtr hrgnDest, IntPtr hrgnSrc1, IntPtr hrgnSrc2, int fnCombineMode);

        [DllImport("gdi32.dll")]
        public static extern int GetRgnBox(IntPtr hRgn, out RECT lprc);

        [DllImport("gdi32.dll")]
        public static extern bool DeleteObject(IntPtr hObject);

        [DllImport("user32.dll")]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        [DllImport("user32.dll")]
        public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool AdjustWindowRectEx(ref RECT lpRect, uint dwStyle, bool bMenu, uint dwExStyle);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool QueryFullProcessImageName(IntPtr hProcess, int dwFlags, StringBuilder lpExeName, ref int lpdwSize);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(IntPtr hObject);

        [DllImport("user32.dll")]
        public static extern bool SetProcessDPIAware();

        public const int GWL_STYLE = -16;
        public const int GWL_EXSTYLE = -20;
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

        public static IntPtr FindMainWindow(int processId)
        {
            IntPtr found = IntPtr.Zero;
            EnumWindows(delegate(IntPtr h, IntPtr p)
            {
                uint pid;
                GetWindowThreadProcessId(h, out pid);
                if (pid == (uint)processId && IsWindowVisible(h))
                {
                    found = h;
                    return false;
                }
                return true;
            }, IntPtr.Zero);
            return found;
        }

        public static string GetProcessExePath(Process proc)
        {
            if (proc == null) return null;
            try
            {
                if (proc.MainModule != null && !string.IsNullOrEmpty(proc.MainModule.FileName))
                    return proc.MainModule.FileName;
            }
            catch { }

            IntPtr hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, proc.Id);
            if (hProc == IntPtr.Zero) return null;
            try
            {
                var sb = new StringBuilder(1024);
                int cap = sb.Capacity;
                if (QueryFullProcessImageName(hProc, 0, sb, ref cap) && sb.Length > 0)
                    return sb.ToString();
            }
            finally
            {
                CloseHandle(hProc);
            }
            return null;
        }

        public static IntPtr CreatePlanClipRegion(ScaledSimulationPlan plan)
        {
            IntPtr combined = IntPtr.Zero;
            int totalH = plan.TopologyHeight;
            var regions = new List<Rectangle> { plan.ScaledGame.Bounds };
            foreach (VirtualRegion ws in plan.ScaledWorkspaces)
            {
                regions.Add(ws.Bounds);
            }

            try
            {
                foreach (Rectangle b in regions)
                {
                    // Convert from bottom-left physical space back to top-left client window space for GDI region
                    int left = b.X;
                    int top = totalH - (b.Y + b.Height);
                    int right = b.X + b.Width;
                    int bottom = totalH - b.Y;

                    IntPtr next = CreateRectRgn(left, top, right, bottom);
                    if (next == IntPtr.Zero) throw new IOException("Could not create clipping region.");
                    if (combined == IntPtr.Zero)
                    {
                        combined = next;
                    }
                    else
                    {
                        try
                        {
                            if (CombineRgn(combined, combined, next, 2) == 0)
                                throw new IOException("Could not combine clipping regions.");
                        }
                        finally
                        {
                            DeleteObject(next);
                        }
                    }
                }
                IntPtr res = combined;
                combined = IntPtr.Zero;
                return res;
            }
            finally
            {
                if (combined != IntPtr.Zero) DeleteObject(combined);
            }
        }
    }

    public sealed class WindowBackupState
    {
        public int ProcessId;
        public IntPtr WindowHandle;
        public int OriginalStyle;
        public Rectangle OriginalOuterBounds;
        public string AddonCorePath;
        public byte[] OriginalTopologyBytes;
    }

    public sealed class SimulatorCanvasPreview : Control
    {
        public ScaledSimulationPlan Plan;
        public InGameLayoutTelemetry Telemetry;
        public Rectangle HostDesktopBounds;
        public bool ShowInGameOverlay = true;
        public int SelectedRegionIndex = 0; // 0 = Game, 1..N = Workspaces[i-1]
        public event Action<int> RegionSelected;
        public event Action<int, int, int> RegionDraggedDelta;

        private float lastScale = 1f;
        private float lastStartX;
        private float lastStartY;
        private int draggingRegionIndex = -1;
        private Point dragStartMouse;

        public SimulatorCanvasPreview()
        {
            DoubleBuffered = true;
            BackColor = Color.FromArgb(16, 17, 22);
            Cursor = Cursors.Hand;
        }

        private RectangleF MapBottomLeftRect(Rectangle r)
        {
            float rx = lastStartX + r.X * lastScale;
            float ry = lastStartY + (Plan.TopologyHeight - (r.Y + r.Height)) * lastScale;
            return new RectangleF(rx, ry, r.Width * lastScale, r.Height * lastScale);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            if (Plan == null || e.Button != MouseButtons.Left) return;

            for (int i = Plan.ScaledWorkspaces.Count - 1; i >= 0; i--)
            {
                RectangleF wr = MapBottomLeftRect(Plan.ScaledWorkspaces[i].Bounds);
                if (wr.Contains(e.Location))
                {
                    SelectedRegionIndex = i + 1;
                    draggingRegionIndex = i + 1;
                    dragStartMouse = e.Location;
                    if (RegionSelected != null) RegionSelected(SelectedRegionIndex);
                    Invalidate();
                    return;
                }
            }

            RectangleF gr = MapBottomLeftRect(Plan.ScaledGame.Bounds);
            if (gr.Contains(e.Location))
            {
                SelectedRegionIndex = 0;
                draggingRegionIndex = 0;
                dragStartMouse = e.Location;
                if (RegionSelected != null) RegionSelected(0);
                Invalidate();
            }
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            if (draggingRegionIndex < 0 || Plan == null || lastScale <= 0.0001f) return;

            int dxPixels = (int)Math.Round((e.X - dragStartMouse.X) / (lastScale * (float)Plan.ScaleFactor));
            int dyPixels = (int)Math.Round((e.Y - dragStartMouse.Y) / (lastScale * (float)Plan.ScaleFactor));
            if (Math.Abs(dxPixels) >= 10 || Math.Abs(dyPixels) >= 10)
            {
                // Snap to 10px grid while dragging for clean coordinates
                dxPixels = (dxPixels / 10) * 10;
                dyPixels = (dyPixels / 10) * 10;
                dragStartMouse = e.Location;
                if (RegionDraggedDelta != null)
                {
                    RegionDraggedDelta(draggingRegionIndex, dxPixels, dyPixels);
                }
            }
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            base.OnMouseUp(e);
            draggingRegionIndex = -1;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(BackColor);

            using (var borderPen = new Pen(Color.FromArgb(95, 78, 44), 1))
            {
                g.DrawRectangle(borderPen, 0, 0, Width - 1, Height - 1);
            }

            if (Plan == null)
            {
                TextRenderer.DrawText(g, "Select or build a monitor layout to preview its span and in-game appearance.",
                    Font, ClientRectangle, Color.FromArgb(170, 165, 150),
                    TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
                return;
            }

            int pad = 22;
            int legendH = 30;
            int availW = Math.Max(40, Width - pad * 2);
            int availH = Math.Max(40, Height - pad * 2 - legendH);

            lastScale = Math.Min(availW / (float)Plan.TopologyWidth, availH / (float)Plan.TopologyHeight);
            float drawW = Plan.TopologyWidth * lastScale;
            float drawH = Plan.TopologyHeight * lastScale;
            lastStartX = (Width - drawW) / 2f;
            lastStartY = pad + (availH - drawH) / 2f;

            // 1. Draw total spanned bounding box (Dead-Space Void = Hatched Crimson/Charcoal)
            using (var voidBrush = new HatchBrush(HatchStyle.BackwardDiagonal, Color.FromArgb(110, 48, 48), Color.FromArgb(20, 18, 24)))
            using (var backingPen = new Pen(Color.FromArgb(150, 80, 75), 1f) { DashStyle = DashStyle.Dash })
            {
                g.FillRectangle(voidBrush, lastStartX, lastStartY, drawW, drawH);
                g.DrawRectangle(backingPen, lastStartX, lastStartY, drawW, drawH);
            }

            // 2. Draw simulated physical monitor outlines
            using (var monPen = new Pen(Color.FromArgb(120, 110, 85), 1.5f))
            {
                foreach (VirtualMonitor m in Plan.ScaledMonitors)
                {
                    RectangleF mr = MapBottomLeftRect(m.Bounds);
                    g.DrawRectangle(monPen, mr.X, mr.Y, mr.Width, mr.Height);
                }
            }

            // 3. Draw Mainhand (Game) Region + In-Game 3D Camera & HUD Preview
            RectangleF gameRect = MapBottomLeftRect(Plan.ScaledGame.Bounds);
            bool gameSelected = SelectedRegionIndex == 0;
            using (var gameBrush = new SolidBrush(Color.FromArgb(230, 26, 56, 40)))
            using (var gamePen = new Pen(gameSelected ? Color.FromArgb(150, 255, 180) : Color.FromArgb(95, 205, 130), gameSelected ? 2.8f : 1.8f))
            {
                g.FillRectangle(gameBrush, gameRect);
                g.DrawRectangle(gamePen, gameRect.X, gameRect.Y, gameRect.Width, gameRect.Height);
            }

            using (var textBrush = new SolidBrush(Color.FromArgb(245, 240, 225)))
            using (var dimBrush = new SolidBrush(Color.FromArgb(190, 215, 200)))
            using (var titleFont = new Font("Segoe UI", 8.75f, FontStyle.Bold))
            using (var subFont = new Font("Segoe UI", 7.5f, FontStyle.Regular))
            using (var tinyFont = new Font("Segoe UI", 6.75f, FontStyle.Bold))
            using (var sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
            using (var sfTop = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Near })
            {
                if (ShowInGameOverlay && gameRect.Width > 70 && gameRect.Height > 50)
                {
                    DrawInGameMainhandOverlay(g, gameRect, titleFont, tinyFont, textBrush, dimBrush, sfCenter, sfTop);
                }
                else
                {
                    string gameLabel = string.Format("MAINHAND (GAME)\n{0} x {1} px",
                        Plan.ScaledGame.Bounds.Width, Plan.ScaledGame.Bounds.Height);
                    g.DrawString(gameLabel, titleFont, textBrush, gameRect, sfCenter);
                }

                // 4. Draw Workspaces + In-Game Offhand Deck & Blizzard Panel Fit Preview
                for (int i = 0; i < Plan.ScaledWorkspaces.Count; i++)
                {
                    VirtualRegion ws = Plan.ScaledWorkspaces[i];
                    RectangleF wsRect = MapBottomLeftRect(ws.Bounds);
                    bool isPrimary = ws.Id == Plan.PrimaryWorkspace.Id;
                    bool wsSelected = SelectedRegionIndex == (i + 1);
                    Color fill = isPrimary ? Color.FromArgb(230, 74, 54, 20) : Color.FromArgb(230, 28, 52, 76);
                    Color outline = wsSelected
                        ? Color.FromArgb(255, 235, 120)
                        : (isPrimary ? Color.FromArgb(235, 180, 58) : Color.FromArgb(100, 175, 230));

                    using (var wsBrush = new SolidBrush(fill))
                    using (var wsPen = new Pen(outline, wsSelected ? 2.8f : 1.8f))
                    {
                        g.FillRectangle(wsBrush, wsRect);
                        g.DrawRectangle(wsPen, wsRect.X, wsRect.Y, wsRect.Width, wsRect.Height);
                    }

                    if (ShowInGameOverlay && wsRect.Width > 60 && wsRect.Height > 45)
                    {
                        DrawInGameWorkspaceOverlay(g, ws, wsRect, isPrimary, titleFont, tinyFont, textBrush, sfCenter, sfTop);
                    }
                    else
                    {
                        string wsLabel = string.Format("{0}\n{1} x {2} px",
                            ws.Id.ToUpperInvariant(), ws.Bounds.Width, ws.Bounds.Height);
                        g.DrawString(wsLabel, titleFont, textBrush, wsRect, sfCenter);
                    }
                }

                string voidNote = (Telemetry != null && Telemetry.VoidPixelArea > 0)
                    ? string.Format("Void Clipped: {0:0.0}%", 100.0 - Telemetry.CoveragePercent)
                    : "No Dead Void (100% Rect)";
                string footer = string.Format(
                    "Spanned WoW Canvas: {0}x{1} px  |  Schema {2} ({3})  |  {4}  |  Tip: Click & drag any screen to test offsets",
                    Plan.TopologyWidth, Plan.TopologyHeight, Plan.Preset.Schema, Plan.Preset.Mode, voidNote);
                g.DrawString(footer, subFont, textBrush, new RectangleF(6, Height - legendH, Width - 12, legendH - 2), sfCenter);
            }
        }

        private void DrawInGameMainhandOverlay(
            Graphics g,
            RectangleF gameRect,
            Font titleFont,
            Font tinyFont,
            Brush textBrush,
            Brush dimBrush,
            StringFormat sfCenter,
            StringFormat sfTop)
        {
            float hudFactor = Telemetry != null ? (float)Math.Max(0.45, Math.Min(1.15, Telemetry.DesiredHudScale / 0.70)) : 1f;

            // 3D WorldFrame inner reticle
            float cx = gameRect.X + gameRect.Width * 0.5f;
            float cy = gameRect.Y + gameRect.Height * 0.46f;
            using (var reticlePen = new Pen(Color.FromArgb(110, 160, 240, 190), 1f) { DashStyle = DashStyle.Dot })
            {
                g.DrawEllipse(reticlePen, cx - 14, cy - 14, 28, 28);
                g.DrawLine(reticlePen, cx - 22, cy, cx + 22, cy);
                g.DrawLine(reticlePen, cx, cy - 22, cx, cy + 22);
            }

            // Header label
            string ar = Telemetry != null ? Telemetry.GameAspectText : "";
            string topText = string.Format("MAINHAND 3D WORLD ({0}x{1} px, {2})",
                Plan.ScaledGame.Bounds.Width, Plan.ScaledGame.Bounds.Height, ar);
            g.DrawString(topText, titleFont, textBrush,
                new RectangleF(gameRect.X + 4, gameRect.Y + 4, gameRect.Width - 8, 20), sfTop);

            // Minimap (top-right of Mainhand)
            float mapSz = Math.Min(gameRect.Width * 0.14f, gameRect.Height * 0.22f) * hudFactor;
            if (mapSz >= 14f)
            {
                var mmRect = new RectangleF(gameRect.Right - mapSz - 6, gameRect.Y + 6, mapSz, mapSz);
                using (var mmBrush = new SolidBrush(Color.FromArgb(190, 20, 40, 32)))
                using (var mmPen = new Pen(Color.FromArgb(160, 230, 195), 1f))
                {
                    g.FillRectangle(mmBrush, mmRect);
                    g.DrawRectangle(mmPen, mmRect.X, mmRect.Y, mmRect.Width, mmRect.Height);
                    g.DrawString("MAP", tinyFont, dimBrush, mmRect, sfCenter);
                }

                // Objective Tracker below Minimap
                float objH = Math.Min(gameRect.Height * 0.32f, gameRect.Bottom - mmRect.Bottom - 26);
                if (objH > 18f)
                {
                    var objRect = new RectangleF(mmRect.X, mmRect.Bottom + 4, mapSz, objH);
                    using (var objBrush = new SolidBrush(Color.FromArgb(135, 18, 35, 28)))
                    using (var objPen = new Pen(Color.FromArgb(95, 175, 130), 1f))
                    {
                        g.FillRectangle(objBrush, objRect);
                        g.DrawRectangle(objPen, objRect.X, objRect.Y, objRect.Width, objRect.Height);
                        g.DrawString("QUESTS", tinyFont, dimBrush, objRect, sfCenter);
                    }
                }
            }

            // Action Bars at bottom-center of Mainhand
            float abW = Math.Min(gameRect.Width * 0.46f * hudFactor, gameRect.Width - 16);
            float abH = Math.Max(12f, Math.Min(22f, gameRect.Height * 0.11f * hudFactor));
            var abRect = new RectangleF(cx - abW * 0.5f, gameRect.Bottom - abH - 5, abW, abH);
            using (var abBrush = new SolidBrush(Color.FromArgb(210, 16, 32, 24)))
            using (var abPen = new Pen(Color.FromArgb(150, 235, 175), 1.2f))
            {
                g.FillRectangle(abBrush, abRect);
                g.DrawRectangle(abPen, abRect.X, abRect.Y, abRect.Width, abRect.Height);
                g.DrawString(string.Format("ACTION BARS (HUD Scale {0:0.00}x)", Telemetry != null ? Telemetry.DesiredHudScale : 0.70),
                    tinyFont, textBrush, abRect, sfCenter);
            }

            // Player & Target UnitFrames above Action Bars
            float ufW = Math.Min(gameRect.Width * 0.16f * hudFactor, 72f);
            float ufH = Math.Max(10f, Math.Min(16f, gameRect.Height * 0.07f));
            if (abRect.Top - ufH - 6 > gameRect.Y + 26)
            {
                var playerUf = new RectangleF(cx - ufW - 14, abRect.Top - ufH - 5, ufW, ufH);
                var targetUf = new RectangleF(cx + 14, abRect.Top - ufH - 5, ufW, ufH);
                using (var ufBrush = new SolidBrush(Color.FromArgb(195, 32, 75, 50)))
                using (var ufPen = new Pen(Color.FromArgb(140, 230, 170), 1f))
                {
                    g.FillRectangle(ufBrush, playerUf);
                    g.DrawRectangle(ufPen, playerUf.X, playerUf.Y, playerUf.Width, playerUf.Height);
                    g.DrawString("PLAYER", tinyFont, textBrush, playerUf, sfCenter);

                    g.FillRectangle(ufBrush, targetUf);
                    g.DrawRectangle(ufPen, targetUf.X, targetUf.Y, targetUf.Width, targetUf.Height);
                    g.DrawString("TARGET", tinyFont, textBrush, targetUf, sfCenter);
                }
            }
        }

        private void DrawInGameWorkspaceOverlay(
            Graphics g,
            VirtualRegion ws,
            RectangleF wsRect,
            bool isPrimary,
            Font titleFont,
            Font tinyFont,
            Brush textBrush,
            StringFormat sfCenter,
            StringFormat sfTop)
        {
            // Offhand Deck Header Bar
            var deckBar = new RectangleF(wsRect.X + 3, wsRect.Y + 3, wsRect.Width - 6, Math.Min(20f, wsRect.Height * 0.16f));
            using (var deckBrush = new SolidBrush(Color.FromArgb(210, 32, 26, 14)))
            using (var deckPen = new Pen(Color.FromArgb(240, 184, 54), 1f))
            {
                g.FillRectangle(deckBrush, deckBar);
                g.DrawRectangle(deckPen, deckBar.X, deckBar.Y, deckBar.Width, deckBar.Height);
                string header = string.Format("{0} ({1}x{2} px)",
                    ws.Id.ToUpperInvariant(), ws.Bounds.Width, ws.Bounds.Height);
                g.DrawString(header, tinyFont, textBrush, deckBar, sfCenter);
            }

            if (wsRect.Height < 70 || wsRect.Width < 75) return;

            float innerTop = deckBar.Bottom + 4;
            float innerH = wsRect.Bottom - innerTop - 4;
            float innerW = wsRect.Width - 8;
            float leftX = wsRect.X + 4;

            if (isPrimary)
            {
                // Draw simulated Blizzard Workspace Panels:
                // Top area: Character + Spellbook/Talents or WorldMap
                float topPanelH = innerH * 0.60f;
                var talentsRect = new RectangleF(leftX, innerTop, innerW, topPanelH);
                bool fits = Telemetry == null || Telemetry.TalentsFitsWorkspace;
                Color panelFill = fits ? Color.FromArgb(175, 42, 36, 22) : Color.FromArgb(190, 95, 32, 32);
                Color panelBorder = fits ? Color.FromArgb(245, 200, 85) : Color.FromArgb(255, 120, 110);

                using (var pBrush = new SolidBrush(panelFill))
                using (var pPen = new Pen(panelBorder, 1f))
                {
                    g.FillRectangle(pBrush, talentsRect);
                    g.DrawRectangle(pPen, talentsRect.X, talentsRect.Y, talentsRect.Width, talentsRect.Height);
                    string badge = Telemetry != null ? Telemetry.TalentsFitStatus : "PANELS";
                    g.DrawString("TALENTS / WORLD MAP / CHARACTER\n" + badge, tinyFont, textBrush, talentsRect, sfCenter);
                }

                // Bottom-left: ChatFrame1, Bottom-right: Bags
                float botY = talentsRect.Bottom + 3;
                float botH = Math.Max(12f, wsRect.Bottom - botY - 4);
                float chatW = innerW * 0.58f;
                var chatRect = new RectangleF(leftX, botY, chatW - 2, botH);
                var bagsRect = new RectangleF(leftX + chatW + 2, botY, innerW - chatW - 2, botH);

                using (var cBrush = new SolidBrush(Color.FromArgb(175, 22, 28, 38)))
                using (var cPen = new Pen(Color.FromArgb(135, 175, 220), 1f))
                {
                    g.FillRectangle(cBrush, chatRect);
                    g.DrawRectangle(cPen, chatRect.X, chatRect.Y, chatRect.Width, chatRect.Height);
                    g.DrawString("CHAT FRAME", tinyFont, textBrush, chatRect, sfCenter);

                    g.FillRectangle(cBrush, bagsRect);
                    g.DrawRectangle(cPen, bagsRect.X, bagsRect.Y, bagsRect.Width, bagsRect.Height);
                    g.DrawString("BAGS", tinyFont, textBrush, bagsRect, sfCenter);
                }
            }
            else
            {
                var auxRect = new RectangleF(leftX, innerTop, innerW, innerH);
                using (var aBrush = new SolidBrush(Color.FromArgb(165, 20, 38, 56)))
                using (var aPen = new Pen(Color.FromArgb(110, 185, 240), 1f))
                {
                    g.FillRectangle(aBrush, auxRect);
                    g.DrawRectangle(aPen, auxRect.X, auxRect.Y, auxRect.Width, auxRect.Height);
                    g.DrawString("AUX WORKSPACE PANELS\n(Drag any panel here in-game)", tinyFont, textBrush, auxRect, sfCenter);
                }
            }
        }
    }

    public sealed class SimulatorForm : Form
    {
        private readonly List<TopologyPreset> presets;
        private TopologyPreset workingPreset;
        private bool suppressBuilderEvents;

        private readonly ComboBox cmbPreset;
        private readonly ComboBox cmbScale;
        private readonly CheckBox chkApplyClipRegion;
        private readonly CheckBox chkBorderless;
        private readonly CheckBox chkShowInGameOverlay;
        private readonly TextBox txtAddonDir;
        private readonly Label lblPresetDesc;
        private readonly Label lblTelemetrySummary;

        // Custom Monitor & Resolution Builder Controls
        private readonly ComboBox cmbTargetRegion;
        private readonly ComboBox cmbQuickRes;
        private readonly NumericUpDown numRegionX;
        private readonly NumericUpDown numRegionY;
        private readonly NumericUpDown numRegionW;
        private readonly NumericUpDown numRegionH;
        private readonly Button btnAddWorkspace;
        private readonly Button btnRemoveWorkspace;

        private readonly SimulatorCanvasPreview previewCanvas;
        private readonly TextBox txtLuaPreview;
        private readonly TextBox txtLog;
        private readonly Label lblLiveStatus;
        private readonly Button btnDetectWow;
        private readonly Button btnStageTopology;
        private readonly Button btnApplyLive;
        private readonly Button btnRestoreLive;
        private readonly Button btnVerify;

        private readonly Dictionary<int, WindowBackupState> backups = new Dictionary<int, WindowBackupState>();
        private string standaloneStagedPath;
        private byte[] standaloneOriginalBytes;

        public SimulatorForm(string initialAddonRoot)
        {
            Text = "Offhand Virtual Monitor & In-Game Layout Simulator";
            Size = new Size(1220, 860);
            MinimumSize = new Size(1020, 720);
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Color.FromArgb(12, 12, 14);
            ForeColor = Color.FromArgb(235, 230, 215);
            Font = new Font("Segoe UI", 9f, FontStyle.Regular);

            presets = PresetCatalog.CreateAll();

            var mainLayout = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 2,
                RowCount = 1,
                Padding = new Padding(10)
            };
            mainLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 60f));
            mainLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 40f));

            // Left Column: Preset/Builder Controls + Visual Canvas Preview + Action Bar
            var leftPanel = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 1,
                RowCount = 4,
                Margin = new Padding(0, 0, 8, 0)
            };
            leftPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            leftPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            leftPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));
            leftPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));

            // 1. Top Config Card (Preset + Scale + Target Dir)
            var configCard = new Panel
            {
                Dock = DockStyle.Fill,
                AutoSize = true,
                BackColor = Color.FromArgb(20, 20, 24),
                Padding = new Padding(10),
                Margin = new Padding(0, 0, 0, 6)
            };

            var configGrid = new TableLayoutPanel
            {
                Dock = DockStyle.Top,
                AutoSize = true,
                ColumnCount = 2
            };
            configGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 140f));
            configGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));

            cmbPreset = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Dock = DockStyle.Fill, BackColor = Color.FromArgb(28, 28, 34), ForeColor = ForeColor };
            foreach (TopologyPreset p in presets) cmbPreset.Items.Add(p);

            cmbScale = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Dock = DockStyle.Fill, BackColor = Color.FromArgb(28, 28, 34), ForeColor = ForeColor };
            cmbScale.Items.Add("Fit to Host Monitor (Proportional)");
            cmbScale.Items.Add("1:1 Exact Pixel Resolution");
            cmbScale.Items.Add("75% Proportional Scale");
            cmbScale.Items.Add("50% Proportional Scale");
            cmbScale.SelectedIndex = 0;

            var addonPathFlow = new TableLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, ColumnCount = 2, Margin = Padding.Empty };
            addonPathFlow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));
            addonPathFlow.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            txtAddonDir = new TextBox
            {
                Dock = DockStyle.Fill,
                BackColor = Color.FromArgb(28, 28, 34),
                ForeColor = ForeColor,
                BorderStyle = BorderStyle.FixedSingle,
                Text = ResolveDefaultAddonRoot(initialAddonRoot)
            };
            btnDetectWow = CreateStyledButton("Detect Live WoW", false);
            btnDetectWow.Click += (s, e) => DetectLiveWowClient();
            addonPathFlow.Controls.Add(txtAddonDir, 0, 0);
            addonPathFlow.Controls.Add(btnDetectWow, 1, 0);

            var optionsFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, WrapContents = true, Margin = Padding.Empty };
            chkBorderless = new CheckBox { Text = "Borderless Window", Checked = true, AutoSize = true, ForeColor = ForeColor };
            chkApplyClipRegion = new CheckBox { Text = "GDI Void Clipping (SetWindowRgn)", Checked = true, AutoSize = true, ForeColor = ForeColor };
            chkShowInGameOverlay = new CheckBox { Text = "Show In-Game HUD & Panel Overlay", Checked = true, AutoSize = true, ForeColor = Color.FromArgb(255, 215, 80) };
            chkShowInGameOverlay.CheckedChanged += (s, e) =>
            {
                previewCanvas.ShowInGameOverlay = chkShowInGameOverlay.Checked;
                previewCanvas.Invalidate();
            };
            optionsFlow.Controls.Add(chkBorderless);
            optionsFlow.Controls.Add(chkApplyClipRegion);
            optionsFlow.Controls.Add(chkShowInGameOverlay);

            lblPresetDesc = new Label
            {
                Dock = DockStyle.Fill,
                AutoSize = true,
                ForeColor = Color.FromArgb(185, 178, 162),
                Padding = new Padding(0, 4, 0, 0)
            };

            AddGridRow(configGrid, "Starting Preset:", cmbPreset);
            AddGridRow(configGrid, "Simulation Scale:", cmbScale);
            AddGridRow(configGrid, "Target Offhand Dir:", addonPathFlow);
            AddGridRow(configGrid, "Display Options:", optionsFlow);
            configGrid.Controls.Add(lblPresetDesc, 0, configGrid.RowCount);
            configGrid.SetColumnSpan(lblPresetDesc, 2);
            configGrid.RowCount++;

            configCard.Controls.Add(configGrid);
            leftPanel.Controls.Add(configCard, 0, 0);

            // 2. Custom Monitor & Resolution Builder Card (Spin up ANY monitor/resolution combination)
            var builderCard = new Panel
            {
                Dock = DockStyle.Fill,
                AutoSize = true,
                BackColor = Color.FromArgb(22, 23, 29),
                Padding = new Padding(10),
                Margin = new Padding(0, 0, 0, 6)
            };

            var builderGrid = new TableLayoutPanel
            {
                Dock = DockStyle.Top,
                AutoSize = true,
                ColumnCount = 2
            };
            builderGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 140f));
            builderGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));

            var regionRowFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, WrapContents = true, Margin = Padding.Empty };
            cmbTargetRegion = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 210, BackColor = Color.FromArgb(28, 28, 34), ForeColor = ForeColor };
            cmbQuickRes = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 210, BackColor = Color.FromArgb(28, 28, 34), ForeColor = ForeColor };
            cmbQuickRes.Items.AddRange(new object[]
            {
                "Quick Resolution...",
                "1920x1080 (16:9 1080p)",
                "2560x1440 (16:9 1440p)",
                "3840x2160 (16:9 4K UHD)",
                "3440x1440 (21:9 Ultrawide)",
                "5120x1440 (32:9 Super-UW)",
                "1080x1920 (9:16 Portrait 1080p)",
                "1440x2560 (9:16 Portrait 1440p)",
                "2560x1600 (16:10 WQXGA)",
                "1920x1200 (16:10 WUXGA)",
                "1280x1440 (Half-1440p Wing)",
                "1280x720 (Stacked Wing)",
                "640x1440 (Narrow Split)"
            });
            cmbQuickRes.SelectedIndex = 0;

            btnAddWorkspace = CreateStyledButton("+ Add Monitor/WS", false);
            btnRemoveWorkspace = CreateStyledButton("- Remove WS", false);
            btnAddWorkspace.Click += (s, e) => AddCustomWorkspaceRegion();
            btnRemoveWorkspace.Click += (s, e) => RemoveSelectedWorkspaceRegion();

            regionRowFlow.Controls.Add(cmbTargetRegion);
            regionRowFlow.Controls.Add(cmbQuickRes);
            regionRowFlow.Controls.Add(btnAddWorkspace);
            regionRowFlow.Controls.Add(btnRemoveWorkspace);

            var coordsFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, WrapContents = true, Margin = Padding.Empty };
            numRegionW = CreateCoordSpinner(320, 15360, 2560);
            numRegionH = CreateCoordSpinner(320, 8640, 1440);
            numRegionX = CreateCoordSpinner(-15360, 15360, 0);
            numRegionY = CreateCoordSpinner(-8640, 8640, 0);

            coordsFlow.Controls.Add(CreateInlineLabel("Width:"));
            coordsFlow.Controls.Add(numRegionW);
            coordsFlow.Controls.Add(CreateInlineLabel("Height:"));
            coordsFlow.Controls.Add(numRegionH);
            coordsFlow.Controls.Add(CreateInlineLabel("X Offset:"));
            coordsFlow.Controls.Add(numRegionX);
            coordsFlow.Controls.Add(CreateInlineLabel("Y Offset:"));
            coordsFlow.Controls.Add(numRegionY);

            var snapFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, WrapContents = true, Margin = Padding.Empty };
            AddSnapButton(snapFlow, "Snap Left of Game", "LEFT");
            AddSnapButton(snapFlow, "Snap Right of Game", "RIGHT");
            AddSnapButton(snapFlow, "Snap Above Game", "TOP");
            AddSnapButton(snapFlow, "Snap Below Game", "BOTTOM");
            AddSnapButton(snapFlow, "Align Bottoms", "ALIGN_BOTTOM");
            AddSnapButton(snapFlow, "Center Vertically", "CENTER_Y");
            AddSnapButton(snapFlow, "Align Tops", "ALIGN_TOP");

            AddGridRow(builderGrid, "Custom Edit Region:", regionRowFlow);
            AddGridRow(builderGrid, "Custom W / H / X / Y:", coordsFlow);
            AddGridRow(builderGrid, "Quick Arrangement:", snapFlow);
            builderCard.Controls.Add(builderGrid);
            leftPanel.Controls.Add(builderCard, 0, 1);

            // 3. Visual Canvas Preview (Interactive Drag + In-Game Layout Overlay)
            previewCanvas = new SimulatorCanvasPreview { Dock = DockStyle.Fill, Margin = new Padding(0, 0, 0, 6) };
            previewCanvas.RegionSelected += idx =>
            {
                if (idx >= 0 && idx < cmbTargetRegion.Items.Count)
                {
                    cmbTargetRegion.SelectedIndex = idx;
                }
            };
            previewCanvas.RegionDraggedDelta += (idx, dx, dy) =>
            {
                if (workingPreset == null) return;
                VirtualRegion target = GetWorkingRegionByIndex(idx);
                if (target == null) return;
                target.Bounds = new Rectangle(target.Bounds.X + dx, target.Bounds.Y + dy, target.Bounds.Width, target.Bounds.Height);
                workingPreset.SyncMonitorsFromRegions();
                SyncBuilderNumericsFromSelectedRegion();
                RefreshCurrentPlan();
            };
            leftPanel.Controls.Add(previewCanvas, 0, 2);

            // 4. Action Buttons Bar
            var actionPanel = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                AutoSize = true,
                WrapContents = true,
                BackColor = Color.FromArgb(20, 20, 24),
                Padding = new Padding(6),
                Margin = Padding.Empty
            };

            btnApplyLive = CreateStyledButton("1. Simulate on Live WoW", true);
            btnStageTopology = CreateStyledButton("Stage Topology Only", false);
            btnVerify = CreateStyledButton("2. Verify State & Run Lua QA", false);
            btnRestoreLive = CreateStyledButton("3. Restore Window & Reset", false);

            btnApplyLive.Click += (s, e) => ApplySimulationToLiveWow();
            btnStageTopology.Click += (s, e) => StageTopologyOnly();
            btnVerify.Click += (s, e) => RunVerificationCheck();
            btnRestoreLive.Click += (s, e) => RestoreAllSimulatedState();

            actionPanel.Controls.Add(btnApplyLive);
            actionPanel.Controls.Add(btnStageTopology);
            actionPanel.Controls.Add(btnVerify);
            actionPanel.Controls.Add(btnRestoreLive);
            leftPanel.Controls.Add(actionPanel, 0, 3);

            // Right Column: Live Status + In-Game Layout Telemetry + Generated Lua + Verification Log
            var rightPanel = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 1,
                RowCount = 4
            };
            rightPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            rightPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            rightPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 45f));
            rightPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 55f));

            var statusCard = new Panel
            {
                Dock = DockStyle.Fill,
                AutoSize = true,
                BackColor = Color.FromArgb(20, 20, 24),
                Padding = new Padding(10),
                Margin = new Padding(0, 0, 0, 6)
            };
            lblLiveStatus = new Label
            {
                Dock = DockStyle.Top,
                AutoSize = true,
                Font = new Font("Segoe UI", 9.25f, FontStyle.Bold),
                ForeColor = Color.FromArgb(240, 184, 54),
                Text = "Ready. Pick a preset or customize any monitor resolution."
            };
            statusCard.Controls.Add(lblLiveStatus);
            rightPanel.Controls.Add(statusCard, 0, 0);

            var telemetryCard = new Panel
            {
                Dock = DockStyle.Fill,
                AutoSize = true,
                BackColor = Color.FromArgb(18, 22, 26),
                Padding = new Padding(10),
                Margin = new Padding(0, 0, 0, 6)
            };
            lblTelemetrySummary = new Label
            {
                Dock = DockStyle.Top,
                AutoSize = true,
                Font = new Font("Consolas", 8.5f, FontStyle.Regular),
                ForeColor = Color.FromArgb(210, 230, 215),
                Text = "In-Game Telemetry..."
            };
            telemetryCard.Controls.Add(lblTelemetrySummary);
            rightPanel.Controls.Add(telemetryCard, 0, 1);

            txtLuaPreview = new TextBox
            {
                Dock = DockStyle.Fill,
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Both,
                WordWrap = false,
                Font = new Font("Consolas", 8.25f),
                BackColor = Color.FromArgb(14, 15, 19),
                ForeColor = Color.FromArgb(210, 215, 225),
                BorderStyle = BorderStyle.FixedSingle,
                Margin = new Padding(0, 0, 0, 6)
            };
            rightPanel.Controls.Add(txtLuaPreview, 0, 2);

            txtLog = new TextBox
            {
                Dock = DockStyle.Fill,
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Vertical,
                Font = new Font("Consolas", 8.75f),
                BackColor = Color.FromArgb(10, 10, 12),
                ForeColor = Color.FromArgb(215, 210, 198),
                BorderStyle = BorderStyle.FixedSingle
            };
            rightPanel.Controls.Add(txtLog, 0, 3);

            mainLayout.Controls.Add(leftPanel, 0, 0);
            mainLayout.Controls.Add(rightPanel, 1, 0);
            Controls.Add(mainLayout);

            cmbPreset.SelectedIndexChanged += (s, e) => LoadSelectedPresetIntoWorkingCopy();
            cmbScale.SelectedIndexChanged += (s, e) => RefreshCurrentPlan();
            cmbTargetRegion.SelectedIndexChanged += (s, e) =>
            {
                previewCanvas.SelectedRegionIndex = Math.Max(0, cmbTargetRegion.SelectedIndex);
                SyncBuilderNumericsFromSelectedRegion();
                previewCanvas.Invalidate();
            };
            cmbQuickRes.SelectedIndexChanged += (s, e) => ApplyQuickResolutionSelection();
            numRegionW.ValueChanged += (s, e) => ApplyBuilderNumericsToRegion();
            numRegionH.ValueChanged += (s, e) => ApplyBuilderNumericsToRegion();
            numRegionX.ValueChanged += (s, e) => ApplyBuilderNumericsToRegion();
            numRegionY.ValueChanged += (s, e) => ApplyBuilderNumericsToRegion();

            Resize += (s, e) => previewCanvas.Invalidate();
            FormClosing += (s, e) =>
            {
                if (backups.Count > 0 || standaloneStagedPath != null)
                {
                    DialogResult dr = MessageBox.Show(this,
                        "Active simulation state or staged CompanionTopology.lua is still present.\r\n\r\nRestore the WoW window and reset CompanionTopology.lua before closing?",
                        "Offhand Layout Simulator",
                        MessageBoxButtons.YesNoCancel,
                        MessageBoxIcon.Question);
                    if (dr == DialogResult.Cancel)
                    {
                        e.Cancel = true;
                        return;
                    }
                    if (dr == DialogResult.Yes)
                    {
                        RestoreAllSimulatedState();
                    }
                }
            };

            if (cmbPreset.Items.Count > 0) cmbPreset.SelectedIndex = 0;
            AppendLog("Offhand Virtual Monitor & In-Game Layout Simulator initialized.");
            AppendLog("Host Primary Screen: " + Screen.PrimaryScreen.Bounds.Width + "x" + Screen.PrimaryScreen.Bounds.Height + " (Working Area: " + Screen.PrimaryScreen.WorkingArea.Width + "x" + Screen.PrimaryScreen.WorkingArea.Height + ").");
            AppendLog("Tip: Pick any preset or use the Custom Monitor Builder (or drag monitors directly on the canvas) to test any resolution combination.");
        }

        private static NumericUpDown CreateCoordSpinner(int min, int max, int val)
        {
            return new NumericUpDown
            {
                Minimum = min,
                Maximum = max,
                Value = val,
                Increment = 10,
                Width = 72,
                BackColor = Color.FromArgb(28, 28, 34),
                ForeColor = Color.FromArgb(235, 230, 215),
                Margin = new Padding(2, 3, 8, 3)
            };
        }

        private static Label CreateInlineLabel(string text)
        {
            return new Label
            {
                Text = text,
                AutoSize = true,
                ForeColor = Color.FromArgb(200, 195, 180),
                Margin = new Padding(2, 6, 2, 2)
            };
        }

        private void AddSnapButton(FlowLayoutPanel panel, string text, string snapAction)
        {
            Button b = CreateStyledButton(text, false);
            b.Font = new Font("Segoe UI", 8f, FontStyle.Regular);
            b.Padding = new Padding(4, 2, 4, 2);
            b.Margin = new Padding(2);
            b.Click += (s, e) => SnapSelectedRegion(snapAction);
            panel.Controls.Add(b);
        }

        private void LoadSelectedPresetIntoWorkingCopy()
        {
            var selected = cmbPreset.SelectedItem as TopologyPreset;
            if (selected == null) return;
            workingPreset = selected.Clone();
            RebuildTargetRegionDropdown(0);
            RefreshCurrentPlan();
        }

        private void RebuildTargetRegionDropdown(int selectIndex)
        {
            if (workingPreset == null) return;
            suppressBuilderEvents = true;
            try
            {
                cmbTargetRegion.Items.Clear();
                cmbTargetRegion.Items.Add(string.Format("Mainhand Game ({0}x{1})", workingPreset.Game.Bounds.Width, workingPreset.Game.Bounds.Height));
                for (int i = 0; i < workingPreset.Workspaces.Count; i++)
                {
                    VirtualRegion ws = workingPreset.Workspaces[i];
                    bool isPrimary = ws.Id == workingPreset.PrimaryWorkspaceId;
                    cmbTargetRegion.Items.Add(string.Format("{0}{1} ({2}x{3})",
                        ws.Id, isPrimary ? " [Primary]" : "", ws.Bounds.Width, ws.Bounds.Height));
                }
                int idx = Math.Max(0, Math.Min(selectIndex, cmbTargetRegion.Items.Count - 1));
                cmbTargetRegion.SelectedIndex = idx;
                previewCanvas.SelectedRegionIndex = idx;
                btnRemoveWorkspace.Enabled = workingPreset.Workspaces.Count > 1 && idx > 0;
            }
            finally
            {
                suppressBuilderEvents = false;
            }
            SyncBuilderNumericsFromSelectedRegion();
        }

        private VirtualRegion GetWorkingRegionByIndex(int idx)
        {
            if (workingPreset == null) return null;
            if (idx <= 0) return workingPreset.Game;
            int wsIdx = idx - 1;
            if (wsIdx >= 0 && wsIdx < workingPreset.Workspaces.Count)
                return workingPreset.Workspaces[wsIdx];
            return null;
        }

        private void SyncBuilderNumericsFromSelectedRegion()
        {
            VirtualRegion r = GetWorkingRegionByIndex(cmbTargetRegion.SelectedIndex);
            if (r == null) return;
            suppressBuilderEvents = true;
            try
            {
                numRegionW.Value = Math.Max(numRegionW.Minimum, Math.Min(numRegionW.Maximum, r.Bounds.Width));
                numRegionH.Value = Math.Max(numRegionH.Minimum, Math.Min(numRegionH.Maximum, r.Bounds.Height));
                numRegionX.Value = Math.Max(numRegionX.Minimum, Math.Min(numRegionX.Maximum, r.Bounds.X));
                numRegionY.Value = Math.Max(numRegionY.Minimum, Math.Min(numRegionY.Maximum, r.Bounds.Y));
                btnRemoveWorkspace.Enabled = workingPreset != null && workingPreset.Workspaces.Count > 1 && cmbTargetRegion.SelectedIndex > 0;
            }
            finally
            {
                suppressBuilderEvents = false;
            }
        }

        private void ApplyQuickResolutionSelection()
        {
            if (suppressBuilderEvents || cmbQuickRes.SelectedIndex <= 0) return;
            string item = cmbQuickRes.SelectedItem as string ?? "";
            int spaceIdx = item.IndexOf(' ');
            string dimPart = spaceIdx > 0 ? item.Substring(0, spaceIdx) : item;
            string[] parts = dimPart.Split('x');
            int w, h;
            if (parts.Length == 2 && int.TryParse(parts[0], out w) && int.TryParse(parts[1], out h))
            {
                suppressBuilderEvents = true;
                try
                {
                    numRegionW.Value = w;
                    numRegionH.Value = h;
                    cmbQuickRes.SelectedIndex = 0;
                }
                finally
                {
                    suppressBuilderEvents = false;
                }
                ApplyBuilderNumericsToRegion();
            }
        }

        private void ApplyBuilderNumericsToRegion()
        {
            if (suppressBuilderEvents || workingPreset == null) return;
            int idx = cmbTargetRegion.SelectedIndex;
            VirtualRegion r = GetWorkingRegionByIndex(idx);
            if (r == null) return;

            r.Bounds = new Rectangle((int)numRegionX.Value, (int)numRegionY.Value, (int)numRegionW.Value, (int)numRegionH.Value);
            workingPreset.Description = "Custom Monitor Layout (Modified from " + workingPreset.Id + ")";
            workingPreset.SyncMonitorsFromRegions();
            RebuildTargetRegionDropdown(idx);
            RefreshCurrentPlan();
        }

        private void SnapSelectedRegion(string snapMode)
        {
            if (workingPreset == null) return;
            int idx = cmbTargetRegion.SelectedIndex;
            if (idx <= 0 && workingPreset.Workspaces.Count > 0)
            {
                idx = 1; // Default to snapping Primary Workspace relative to Mainhand Game
            }
            VirtualRegion ws = GetWorkingRegionByIndex(idx);
            if (ws == null || ws == workingPreset.Game) return;

            Rectangle g = workingPreset.Game.Bounds;
            Rectangle b = ws.Bounds;
            switch (snapMode)
            {
                case "LEFT":
                    b.X = g.Left - b.Width;
                    break;
                case "RIGHT":
                    b.X = g.Right;
                    break;
                case "TOP":
                    b.X = g.Left + (g.Width - b.Width) / 2;
                    b.Y = g.Top - b.Height;
                    break;
                case "BOTTOM":
                    b.X = g.Left + (g.Width - b.Width) / 2;
                    b.Y = g.Bottom;
                    break;
                case "ALIGN_BOTTOM":
                    b.Y = g.Bottom - b.Height;
                    break;
                case "CENTER_Y":
                    b.Y = g.Top + (g.Height - b.Height) / 2;
                    break;
                case "ALIGN_TOP":
                    b.Y = g.Top;
                    break;
            }
            ws.Bounds = b;
            workingPreset.SyncMonitorsFromRegions();
            RebuildTargetRegionDropdown(idx);
            RefreshCurrentPlan();
        }

        private void AddCustomWorkspaceRegion()
        {
            if (workingPreset == null) return;
            int nextNum = workingPreset.Workspaces.Count + 1;
            string newId = "workspace-" + (char)('a' + workingPreset.Workspaces.Count);
            Rectangle union = workingPreset.ComputeUnionBounds();
            var newWs = new VirtualRegion
            {
                Id = newId,
                DeviceName = @"\\.\DISPLAY_SIM" + (nextNum + 1),
                Bounds = new Rectangle(union.Right, workingPreset.Game.Bounds.Top, 1920, 1080)
            };
            workingPreset.Workspaces.Add(newWs);
            if (workingPreset.Workspaces.Count == 2 && workingPreset.Workspaces[0].Id == "workspace")
            {
                workingPreset.Workspaces[0].Id = "workspace-a";
                workingPreset.PrimaryWorkspaceId = "workspace-a";
                newWs.Id = "workspace-b";
            }
            workingPreset.SyncMonitorsFromRegions();
            RebuildTargetRegionDropdown(workingPreset.Workspaces.Count);
            RefreshCurrentPlan();
            AppendLog("Added Workspace Region '" + newWs.Id + "' (1920x1080). Upgraded topology to Schema " + workingPreset.Schema + ".");
        }

        private void RemoveSelectedWorkspaceRegion()
        {
            if (workingPreset == null || workingPreset.Workspaces.Count <= 1) return;
            int idx = cmbTargetRegion.SelectedIndex;
            if (idx <= 0) return;
            int wsIdx = idx - 1;
            string removedId = workingPreset.Workspaces[wsIdx].Id;
            workingPreset.Workspaces.RemoveAt(wsIdx);
            workingPreset.PrimaryWorkspaceId = workingPreset.Workspaces[0].Id;
            if (workingPreset.Workspaces.Count == 1)
            {
                workingPreset.Schema = 1;
                workingPreset.Mode = "DUAL_DISPLAY";
                workingPreset.Workspaces[0].Id = "workspace";
                workingPreset.PrimaryWorkspaceId = "workspace";
            }
            workingPreset.SyncMonitorsFromRegions();
            RebuildTargetRegionDropdown(1);
            RefreshCurrentPlan();
            AppendLog("Removed Workspace Region '" + removedId + "'.");
        }

        private static string ResolveDefaultAddonRoot(string candidate)
        {
            if (!string.IsNullOrWhiteSpace(candidate) && Directory.Exists(Path.Combine(candidate, "Core")))
                return Path.GetFullPath(candidate);
            string current = Environment.CurrentDirectory;
            if (Directory.Exists(Path.Combine(current, "Core")) && File.Exists(Path.Combine(current, "Offhand.toc")))
                return current;
            return current;
        }

        private static void AddGridRow(TableLayoutPanel grid, string labelText, Control control)
        {
            int row = grid.RowCount++;
            grid.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            var lbl = new Label
            {
                Text = labelText,
                AutoSize = true,
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleLeft,
                ForeColor = Color.FromArgb(240, 184, 54),
                Margin = new Padding(0, 4, 8, 4)
            };
            control.Margin = new Padding(0, 4, 0, 4);
            grid.Controls.Add(lbl, 0, row);
            grid.Controls.Add(control, 1, row);
        }

        private static Button CreateStyledButton(string text, bool primary)
        {
            var btn = new Button
            {
                Text = text,
                AutoSize = true,
                FlatStyle = FlatStyle.Flat,
                BackColor = primary ? Color.FromArgb(44, 35, 20) : Color.FromArgb(28, 28, 34),
                ForeColor = primary ? Color.FromArgb(255, 215, 80) : Color.FromArgb(235, 230, 215),
                Font = new Font("Segoe UI", 8.75f, FontStyle.Bold),
                Padding = new Padding(7, 3, 7, 3),
                Margin = new Padding(3),
                Cursor = Cursors.Hand
            };
            btn.FlatAppearance.BorderSize = 1;
            btn.FlatAppearance.BorderColor = primary ? Color.FromArgb(240, 184, 54) : Color.FromArgb(101, 87, 58);
            return btn;
        }

        private string SelectedScaleMode()
        {
            switch (cmbScale.SelectedIndex)
            {
                case 0: return "FIT_HOST";
                case 1: return "EXACT_1_1";
                case 2: return "SCALE_75";
                case 3: return "SCALE_50";
                default: return "FIT_HOST";
            }
        }

        private ScaledSimulationPlan BuildCurrentPlan()
        {
            TopologyPreset preset = workingPreset ?? (cmbPreset.SelectedItem as TopologyPreset);
            if (preset == null) return null;
            Rectangle hostArea = Screen.FromControl(this).WorkingArea;
            return PlanScaler.BuildPlan(preset, SelectedScaleMode(), 1.0, hostArea, hostArea.Location);
        }

        private void RefreshCurrentPlan()
        {
            try
            {
                ScaledSimulationPlan plan = BuildCurrentPlan();
                if (plan == null) return;
                InGameLayoutTelemetry telemetry = InGameLayoutTelemetry.Compute(plan);
                lblPresetDesc.Text = plan.Preset.Description + string.Format(
                    "\r\nSpanned Canvas: {0}x{1} px  |  Mainhand: {2}x{3} at ({4},{5})  |  Primary WS: {6}x{7} at ({8},{9})",
                    plan.TopologyWidth, plan.TopologyHeight,
                    plan.ScaledGame.Bounds.Width, plan.ScaledGame.Bounds.Height, plan.ScaledGame.Bounds.X, plan.ScaledGame.Bounds.Y,
                    plan.PrimaryWorkspace.Bounds.Width, plan.PrimaryWorkspace.Bounds.Height, plan.PrimaryWorkspace.Bounds.X, plan.PrimaryWorkspace.Bounds.Y);

                lblTelemetrySummary.Text = string.Format(
                    "IN-GAME LAYOUT TELEMETRY (What WoW + Offhand computes):\r\n" +
                    " • UIParent Canvas : {0:0.0} x {1:0} UI units (EffectiveScale: {2:0.0000})\r\n" +
                    " • 3D WorldFrame   : {3}x{4} px ({5} aspect, {6:0.0}x{7:0.0} UI units)\r\n" +
                    " • Primary Offhand : {8}x{9} px ({10:0.0}x{11:0.0} UI units, Regions: {12})\r\n" +
                    " • HUD & Nameplates: HUD Scale = {13:0.00}x  |  WorldText Ratio = {14:0.00}x\r\n" +
                    " • Dead Void Space : {15:0.0}% clipped ({16:N0} px² non-monitor area)\r\n" +
                    " • Talents / Spells: {17}\r\n" +
                    " • World Map       : {18}",
                    telemetry.UiParentWidth, telemetry.UiParentHeight, telemetry.UiEffectiveScale,
                    plan.ScaledGame.Bounds.Width, plan.ScaledGame.Bounds.Height, telemetry.GameAspectText, telemetry.GameUiWidth, telemetry.GameUiHeight,
                    plan.PrimaryWorkspace.Bounds.Width, plan.PrimaryWorkspace.Bounds.Height, telemetry.WorkspaceUiWidth, telemetry.WorkspaceUiHeight, plan.ScaledWorkspaces.Count,
                    telemetry.DesiredHudScale, telemetry.WorldTextRatio,
                    100.0 - telemetry.CoveragePercent, telemetry.VoidPixelArea,
                    telemetry.TalentsFitStatus,
                    telemetry.WorldMapFitStatus);

                previewCanvas.Plan = plan;
                previewCanvas.Telemetry = telemetry;
                previewCanvas.HostDesktopBounds = Screen.FromControl(this).WorkingArea;
                previewCanvas.Invalidate();
                txtLuaPreview.Text = PlanScaler.FormatTopologyLua(plan, "2.1.5");
            }
            catch (Exception ex)
            {
                AppendLog("Plan calculation error: " + ex.Message);
            }
        }

        private void AppendLog(string message)
        {
            string line = "[" + DateTime.Now.ToString("HH:mm:ss") + "] " + message + "\r\n";
            txtLog.AppendText(line);
        }

        private Process FindSingleRunningWow(out string error)
        {
            error = null;
            string[] names = { "Wow", "WowClassic", "WowB", "WowT" };
            var matches = new List<Process>();
            int currentSession = Process.GetCurrentProcess().SessionId;

            foreach (string name in names)
            {
                Process[] found;
                try { found = Process.GetProcessesByName(name); }
                catch { continue; }
                foreach (Process p in found)
                {
                    bool keep = false;
                    try
                    {
                        if (p.SessionId == currentSession && p.MainWindowHandle != IntPtr.Zero)
                        {
                            matches.Add(p);
                            keep = true;
                        }
                    }
                    catch { }
                    finally
                    {
                        if (!keep) p.Dispose();
                    }
                }
            }

            if (matches.Count == 0)
            {
                error = "No running World of Warcraft window was found.";
                return null;
            }
            if (matches.Count > 1)
            {
                foreach (Process p in matches) p.Dispose();
                error = "Multiple WoW processes are running. Keep only one client open during simulation.";
                return null;
            }
            return matches[0];
        }

        private void DetectLiveWowClient()
        {
            string error;
            using (Process proc = FindSingleRunningWow(out error))
            {
                if (proc == null)
                {
                    lblLiveStatus.Text = error;
                    AppendLog(error);
                    return;
                }
                string exePath = Win32Interop.GetProcessExePath(proc);
                if (string.IsNullOrEmpty(exePath))
                {
                    lblLiveStatus.Text = "Found WoW PID " + proc.Id + ", but could not read its executable path.";
                    AppendLog(lblLiveStatus.Text);
                    return;
                }
                string wowDir = Path.GetDirectoryName(exePath);
                string addonDir = Path.Combine(wowDir, "Interface", "AddOns", "Offhand");
                if (Directory.Exists(addonDir))
                {
                    txtAddonDir.Text = addonDir;
                    lblLiveStatus.Text = string.Format("Detected WoW PID {0} ({1}) -> {2}", proc.Id, proc.ProcessName, addonDir);
                    AppendLog("Auto-detected live WoW Offhand installation: " + addonDir);
                }
                else
                {
                    lblLiveStatus.Text = string.Format("Found WoW PID {0} at {1}, but Interface\\AddOns\\Offhand is missing.", proc.Id, wowDir);
                    AppendLog(lblLiveStatus.Text);
                }
            }
        }

        private string ValidateAddonCoreDirectory(out string topologyPath)
        {
            topologyPath = null;
            string addonRoot = (txtAddonDir.Text ?? "").Trim();
            if (string.IsNullOrEmpty(addonRoot) || !Directory.Exists(addonRoot))
                return "Target Offhand directory does not exist: " + addonRoot;

            string coreDir = Path.Combine(addonRoot, "Core");
            if (!Directory.Exists(coreDir))
                return "Target directory does not contain a Core folder: " + coreDir;

            topologyPath = Path.Combine(coreDir, "CompanionTopology.lua");
            return null;
        }

        private void WriteTopologyFileSafely(string topologyPath, ScaledSimulationPlan plan)
        {
            if (standaloneStagedPath == null && File.Exists(topologyPath))
            {
                standaloneStagedPath = topologyPath;
                standaloneOriginalBytes = File.ReadAllBytes(topologyPath);
            }
            string lua = PlanScaler.FormatTopologyLua(plan, "2.1.5");
            string tmp = topologyPath + ".sim.tmp";
            File.WriteAllText(tmp, lua, new UTF8Encoding(false));
            if (File.Exists(topologyPath))
                File.Replace(tmp, topologyPath, null);
            else
                File.Move(tmp, topologyPath);
        }

        private void StageTopologyOnly()
        {
            try
            {
                ScaledSimulationPlan plan = BuildCurrentPlan();
                if (plan == null) return;
                string topologyPath;
                string err = ValidateAddonCoreDirectory(out topologyPath);
                if (err != null)
                {
                    MessageBox.Show(this, err, "Offhand Simulator", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return;
                }
                WriteTopologyFileSafely(topologyPath, plan);
                lblLiveStatus.Text = "Staged CompanionTopology.lua (" + plan.Preset.Name + ").";
                AppendLog("Wrote simulated CompanionTopology.lua to: " + topologyPath);
                AppendLog(" Dimensions: " + plan.TopologyWidth + "x" + plan.TopologyHeight + " (" + plan.ScaleLabel + ").");
            }
            catch (Exception ex)
            {
                AppendLog("Failed to stage CompanionTopology.lua: " + ex.Message);
                MessageBox.Show(this, ex.Message, "Offhand Simulator", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void ApplySimulationToLiveWow()
        {
            string error;
            using (Process proc = FindSingleRunningWow(out error))
            {
                if (proc == null)
                {
                    AppendLog("Simulate on Live WoW aborted: " + error);
                    MessageBox.Show(this, error + "\r\n\r\nUse 'Stage Topology Only' if you only want to write CompanionTopology.lua and run offline Lua verification.",
                        "No Live WoW Window", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }

                string exePath = Win32Interop.GetProcessExePath(proc);
                if (!string.IsNullOrEmpty(exePath))
                {
                    string wowAddon = Path.Combine(Path.GetDirectoryName(exePath), "Interface", "AddOns", "Offhand");
                    if (Directory.Exists(Path.Combine(wowAddon, "Core")))
                    {
                        txtAddonDir.Text = wowAddon;
                    }
                }

                string topologyPath;
                string pathErr = ValidateAddonCoreDirectory(out topologyPath);
                if (pathErr != null)
                {
                    AppendLog(pathErr);
                    MessageBox.Show(this, pathErr, "Offhand Simulator", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return;
                }

                ScaledSimulationPlan plan = BuildCurrentPlan();
                if (plan == null) return;

                IntPtr handle = proc.MainWindowHandle;
                if (handle == IntPtr.Zero) handle = Win32Interop.FindMainWindow(proc.Id);
                if (handle == IntPtr.Zero)
                {
                    AppendLog("Could not resolve a visible top-level HWND for WoW PID " + proc.Id);
                    return;
                }

                try
                {
                    if (!backups.ContainsKey(proc.Id))
                    {
                        Win32Interop.RECT oldRect;
                        Win32Interop.GetWindowRect(handle, out oldRect);
                        backups[proc.Id] = new WindowBackupState
                        {
                            ProcessId = proc.Id,
                            WindowHandle = handle,
                            OriginalStyle = Win32Interop.GetWindowLong(handle, Win32Interop.GWL_STYLE),
                            OriginalOuterBounds = new Rectangle(oldRect.Left, oldRect.Top, oldRect.Width, oldRect.Height),
                            AddonCorePath = topologyPath,
                            OriginalTopologyBytes = File.Exists(topologyPath) ? File.ReadAllBytes(topologyPath) : null
                        };
                    }

                    WriteTopologyFileSafely(topologyPath, plan);

                    if (Win32Interop.IsZoomed(handle) || Win32Interop.IsIconic(handle))
                    {
                        Win32Interop.ShowWindow(handle, Win32Interop.SW_RESTORE);
                    }

                    int currentStyle = Win32Interop.GetWindowLong(handle, Win32Interop.GWL_STYLE);
                    int targetStyle = chkBorderless.Checked
                        ? (currentStyle & ~(Win32Interop.WS_CAPTION | Win32Interop.WS_THICKFRAME))
                        : (currentStyle | Win32Interop.WS_CAPTION | Win32Interop.WS_THICKFRAME);

                    if (targetStyle != currentStyle)
                    {
                        Win32Interop.SetWindowLong(handle, Win32Interop.GWL_STYLE, targetStyle);
                    }

                    Rectangle targetOuter = plan.WindowBounds;
                    if (!chkBorderless.Checked)
                    {
                        var r = new Win32Interop.RECT { Left = 0, Top = 0, Right = plan.TopologyWidth, Bottom = plan.TopologyHeight };
                        uint exStyle = unchecked((uint)Win32Interop.GetWindowLong(handle, Win32Interop.GWL_EXSTYLE));
                        if (Win32Interop.AdjustWindowRectEx(ref r, unchecked((uint)targetStyle), false, exStyle))
                        {
                            targetOuter = new Rectangle(plan.WindowBounds.X, plan.WindowBounds.Y, r.Width, r.Height);
                        }
                    }

                    if (chkApplyClipRegion.Checked && chkBorderless.Checked)
                    {
                        IntPtr clip = Win32Interop.CreatePlanClipRegion(plan);
                        if (Win32Interop.SetWindowRgn(handle, clip, true) == 0)
                        {
                            Win32Interop.DeleteObject(clip);
                            AppendLog("Warning: SetWindowRgn returned 0.");
                        }
                    }
                    else
                    {
                        Win32Interop.SetWindowRgn(handle, IntPtr.Zero, true);
                    }

                    uint flags = Win32Interop.SWP_NOZORDER | Win32Interop.SWP_NOACTIVATE | Win32Interop.SWP_FRAMECHANGED | Win32Interop.SWP_SHOWWINDOW;
                    if (!Win32Interop.SetWindowPos(handle, IntPtr.Zero, targetOuter.X, targetOuter.Y, targetOuter.Width, targetOuter.Height, flags))
                    {
                        throw new InvalidOperationException("SetWindowPos failed for the target WoW window.");
                    }

                    lblLiveStatus.Text = string.Format("Simulated {0}x{1} on WoW PID {2}. Type /reload in WoW!",
                        plan.TopologyWidth, plan.TopologyHeight, proc.Id);
                    AppendLog(string.Format("SUCCESS: Applied '{0}' ({1}x{2}) to WoW PID {3}.",
                        plan.Preset.Name, plan.TopologyWidth, plan.TopologyHeight, proc.Id));
                    AppendLog("Next step: In World of Warcraft, type /reload (and /offhand diag) to verify the layout.");
                }
                catch (Exception ex)
                {
                    AppendLog("ERROR applying live simulation: " + ex.Message);
                    MessageBox.Show(this, ex.Message, "Simulation Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }

        private void RestoreAllSimulatedState()
        {
            foreach (var kvp in new List<KeyValuePair<int, WindowBackupState>>(backups))
            {
                WindowBackupState b = kvp.Value;
                try
                {
                    Win32Interop.SetWindowRgn(b.WindowHandle, IntPtr.Zero, true);
                    Win32Interop.SetWindowLong(b.WindowHandle, Win32Interop.GWL_STYLE, b.OriginalStyle);
                    uint flags = Win32Interop.SWP_NOZORDER | Win32Interop.SWP_NOACTIVATE | Win32Interop.SWP_FRAMECHANGED | Win32Interop.SWP_SHOWWINDOW;
                    Win32Interop.SetWindowPos(b.WindowHandle, IntPtr.Zero,
                        b.OriginalOuterBounds.X, b.OriginalOuterBounds.Y,
                        b.OriginalOuterBounds.Width, b.OriginalOuterBounds.Height, flags);
                    AppendLog("Restored WoW window bounds and style for PID " + b.ProcessId + " to " + b.OriginalOuterBounds);
                }
                catch (Exception ex)
                {
                    AppendLog("Window restore warning for PID " + b.ProcessId + ": " + ex.Message);
                }

                if (!string.IsNullOrEmpty(b.AddonCorePath) && b.OriginalTopologyBytes != null)
                {
                    try
                    {
                        File.WriteAllBytes(b.AddonCorePath, b.OriginalTopologyBytes);
                        AppendLog("Restored original CompanionTopology.lua bytes at " + b.AddonCorePath);
                    }
                    catch (Exception ex)
                    {
                        AppendLog("Could not restore CompanionTopology.lua: " + ex.Message);
                    }
                }
                backups.Remove(kvp.Key);
            }

            if (standaloneStagedPath != null)
            {
                try
                {
                    if (standaloneOriginalBytes != null)
                    {
                        File.WriteAllBytes(standaloneStagedPath, standaloneOriginalBytes);
                        AppendLog("Restored original CompanionTopology.lua bytes at " + standaloneStagedPath);
                    }
                }
                catch (Exception ex)
                {
                    AppendLog("Could not restore staged CompanionTopology.lua: " + ex.Message);
                }
                standaloneStagedPath = null;
                standaloneOriginalBytes = null;
            }

            lblLiveStatus.Text = "Restored original window bounds and reset CompanionTopology.lua.";
        }

        private void RunVerificationCheck()
        {
            AppendLog("--- Starting Verification Pass ---");
            ScaledSimulationPlan plan = BuildCurrentPlan();
            if (plan == null) return;

            string topologyPath;
            string err = ValidateAddonCoreDirectory(out topologyPath);
            if (err != null)
            {
                AppendLog("FAIL: " + err);
                return;
            }

            // 1. Ensure topology is staged or verify existing file
            bool wroteTemporary = false;
            byte[] priorBytes = File.Exists(topologyPath) ? File.ReadAllBytes(topologyPath) : null;
            string currentText = File.Exists(topologyPath) ? File.ReadAllText(topologyPath) : "";
            if (!currentText.Contains("OffhandCompanionTopology = {"))
            {
                WriteTopologyFileSafely(topologyPath, plan);
                wroteTemporary = true;
                AppendLog("Staged temporary CompanionTopology.lua for verification.");
            }

            try
            {
                // 2. Run headless Lua 5.1 verification against the actual Offhand addon modules
                string addonRoot = Path.GetFullPath(txtAddonDir.Text.Trim());
                RunLuaModuleVerification(addonRoot, topologyPath, plan);

                // 3. Check live WoW window state if running
                string wowErr;
                using (Process proc = FindSingleRunningWow(out wowErr))
                {
                    if (proc != null)
                    {
                        IntPtr handle = proc.MainWindowHandle != IntPtr.Zero ? proc.MainWindowHandle : Win32Interop.FindMainWindow(proc.Id);
                        if (handle != IntPtr.Zero)
                        {
                            Win32Interop.RECT wRect, cRect;
                            Win32Interop.GetWindowRect(handle, out wRect);
                            Win32Interop.GetClientRect(handle, out cRect);
                            int style = Win32Interop.GetWindowLong(handle, Win32Interop.GWL_STYLE);
                            bool borderless = (style & (Win32Interop.WS_CAPTION | Win32Interop.WS_THICKFRAME)) == 0;
                            bool sizeMatches = Math.Abs(cRect.Width - plan.TopologyWidth) <= 2 && Math.Abs(cRect.Height - plan.TopologyHeight) <= 2;

                            AppendLog(string.Format("Live WoW Window (PID {0}): Client={1}x{2}, Outer=({3},{4} {5}x{6}), Borderless={7}",
                                proc.Id, cRect.Width, cRect.Height, wRect.Left, wRect.Top, wRect.Width, wRect.Height, borderless));
                            if (sizeMatches)
                            {
                                AppendLog("PASS [Live Window]: WoW drawable client area matches simulated topology (" + plan.TopologyWidth + "x" + plan.TopologyHeight + ").");
                            }
                            else
                            {
                                AppendLog(string.Format("NOTE [Live Window]: WoW client area is {0}x{1} (expected {2}x{3}). Click 'Simulate on Live WoW' to resize it.",
                                    cRect.Width, cRect.Height, plan.TopologyWidth, plan.TopologyHeight));
                            }
                        }
                    }
                    else
                    {
                        AppendLog("INFO [Live Window]: No running WoW process detected (" + wowErr + "). Offline Lua module verification completed.");
                    }
                }
            }
            finally
            {
                if (wroteTemporary && priorBytes != null)
                {
                    File.WriteAllBytes(topologyPath, priorBytes);
                    standaloneStagedPath = null;
                    standaloneOriginalBytes = null;
                    AppendLog("Restored inert CompanionTopology.lua after standalone verification.");
                }
            }
            AppendLog("--- Verification Pass Complete ---");
        }

        private void RunLuaModuleVerification(string addonRoot, string topologyPath, ScaledSimulationPlan plan)
        {
            string message;
            bool ok = LuaModuleVerifier.VerifyPlan(addonRoot, topologyPath, plan, out message);
            AppendLog(message);
        }
    }

    public static class LuaModuleVerifier
    {
        public static bool VerifyPlan(string addonRoot, string topologyPath, ScaledSimulationPlan plan, out string resultMessage)
        {
            string tempScript = Path.Combine(Path.GetTempPath(), "offhand-sim-verify-" + Guid.NewGuid().ToString("N") + ".lua");
            try
            {
                string luaCode = @"
local addonRoot, topologyFile, expectedW, expectedH, expectedSchema = arg[1], arg[2], tonumber(arg[3]), tonumber(arg[4]), tonumber(arg[5])
local Offhand = {
    db = { enabled = true, hudScale = 0.70, worldTextCompensation = true, worldTextScale = 1.0 },
    companionMinVersion = '2.1.2-beta.19',
    companionFullVersion = '2.1.5'
}
_G.Offhand = Offhand
_G.InCombatLockdown = function() return false end
_G.GetCVar = function() return nil end
_G.SetCVar = function() end
_G.UIParent = {
    GetWidth = function() return expectedW * (768 / expectedH) end,
    GetHeight = function() return 768 end,
    GetEffectiveScale = function() return 768 / expectedH end,
    SetScale = function() end
}
_G.GetPhysicalScreenSize = function() return expectedW, expectedH end

assert(loadfile(addonRoot .. '/Core/WorkspaceRegions.lua'))('Offhand', Offhand)
assert(loadfile(addonRoot .. '/Core/Viewport.lua'))('Offhand', Offhand)
assert(loadfile(addonRoot .. '/Core/TopologyDetection.lua'))('Offhand', Offhand)
assert(loadfile(addonRoot .. '/Core/CanvasPersistence.lua'))('Offhand', Offhand)
assert(loadfile(topologyFile))()

local metrics = Offhand.Viewport:GetMetrics()
assert(metrics.isSpanned == true, 'Viewport did not accept spanned state')
assert(metrics.companionTopology == true, 'Viewport did not recognize CompanionTopology')
assert(metrics.topologyStatus == 'READY', 'Topology status was ' .. tostring(metrics.topologyStatus))
assert(metrics.physicalWidth == expectedW and metrics.physicalHeight == expectedH, 'Physical dimensions mismatch')

local detect = Offhand.TopologyDetection.Detect()
assert(detect.isSpanned == true and detect.exactTopology == true, 'TopologyDetection did not report exactTopology')

-- Verify panel placement persistence inside primary workspace
local testW = math.min(200, math.max(64, math.floor(metrics.workspaceWidth * 0.5)))
local testH = math.min(180, math.max(64, math.floor(metrics.workspaceHeight * 0.5)))
local savedPos = Offhand.CanvasPersistence.CreateWorkspacePosition(
    metrics,
    metrics.workspaceLeft + 16,
    metrics.workspaceTop - 16,
    testW, testH, false, 768
)
assert(type(savedPos) == 'table', 'CreateWorkspacePosition did not return a table')
local px, py = Offhand.CanvasPersistence.ResolveWorkspacePosition(metrics, savedPos, testW, testH, false, 768)
assert(px and py, 'ResolveWorkspacePosition returned nil')
assert(px >= metrics.workspaceLeft and px <= metrics.workspaceRight, 'Panel X outside workspace bounds')
assert(py >= metrics.workspaceBottom and py <= metrics.workspaceTop, 'Panel Y outside workspace bounds')

-- Verify stale single-monitor rejection (safety fallback)
_G.UIParent.GetWidth = function() return 1365.333 end
_G.UIParent.GetHeight = function() return 768 end
_G.GetPhysicalScreenSize = function() return 1920, 1080 end
local _, staleStatus = Offhand.Viewport:GetCompanionTopology(1920, 1080, 1365.333, 768)
assert(staleStatus == 'MISMATCH', 'Stale single-screen fallback did not trigger MISMATCH')

print(string.format('PASS [Lua Viewport & Detection]: %s | Game=%dx%d | PrimaryWS=%dx%d | Regions=%d | Preset=%s',
    detect.description,
    metrics.gamePixelWidth, metrics.gamePixelHeight,
    metrics.workspacePixelWidth, metrics.workspacePixelHeight,
    metrics.workspaceRegions and #metrics.workspaceRegions or 1,
    tostring(detect.recommendedPreset)))
";
                File.WriteAllText(tempScript, luaCode, new UTF8Encoding(false));

                var psi = new ProcessStartInfo("lua", string.Format("\"{0}\" \"{1}\" \"{2}\" {3} {4} {5}",
                    tempScript, addonRoot.Replace('\\', '/'), topologyPath.Replace('\\', '/'), plan.TopologyWidth, plan.TopologyHeight, plan.Preset.Schema))
                {
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                };

                using (Process p = Process.Start(psi))
                {
                    string stdout = p.StandardOutput.ReadToEnd().Trim();
                    string stderr = p.StandardError.ReadToEnd().Trim();
                    p.WaitForExit(5000);
                    if (p.ExitCode == 0)
                    {
                        resultMessage = stdout;
                        return true;
                    }
                    resultMessage = "FAIL [Lua Verification]: " + (string.IsNullOrEmpty(stderr) ? stdout : stderr);
                    return false;
                }
            }
            catch (Exception ex)
            {
                resultMessage = "Lua verification execution error: " + ex.Message;
                return false;
            }
            finally
            {
                try { if (File.Exists(tempScript)) File.Delete(tempScript); } catch { }
            }
        }
    }

    public static class Program
    {
        public static int RunCliSelfTest(string addonRoot)
        {
            Console.WriteLine("Running Offhand Virtual Monitor & Layout Simulator Self-Test...");
            List<TopologyPreset> presets = PresetCatalog.CreateAll();
            if (presets.Count < 12) throw new Exception("Expected at least 12 topology presets.");

            var hostBounds = new Rectangle(0, 0, 2560, 1440);
            string[] scaleModes = { "EXACT_1_1", "FIT_HOST", "SCALE_75", "SCALE_50" };
            int verifiedCount = 0;
            string tempTopology = Path.Combine(Path.GetTempPath(), "offhand-sim-selftest-topology-" + Guid.NewGuid().ToString("N") + ".lua");

            try
            {
                foreach (TopologyPreset preset in presets)
                {
                    foreach (string mode in scaleModes)
                    {
                        ScaledSimulationPlan plan = PlanScaler.BuildPlan(preset, mode, 1.0, hostBounds, Point.Empty);
                        if (plan.TopologyWidth <= 0 || plan.TopologyHeight <= 0)
                            throw new Exception("Invalid scaled dimensions for " + preset.Id);

                        IntPtr rgn = Win32Interop.CreatePlanClipRegion(plan);
                        if (rgn == IntPtr.Zero)
                            throw new Exception("Failed to build GDI clipping region for " + preset.Id);
                        try
                        {
                            Win32Interop.RECT box;
                            if (Win32Interop.GetRgnBox(rgn, out box) == 0 || box.Width <= 0 || box.Height <= 0)
                                throw new Exception("Empty GDI clipping region box for " + preset.Id);
                        }
                        finally
                        {
                            Win32Interop.DeleteObject(rgn);
                        }

                        string lua = PlanScaler.FormatTopologyLua(plan, "2.1.5");
                        if (!lua.Contains("OffhandCompanionTopology = {"))
                            throw new Exception("Malformed Lua output for " + preset.Id);

                        File.WriteAllText(tempTopology, lua, new UTF8Encoding(false));
                        string luaMsg;
                        if (!LuaModuleVerifier.VerifyPlan(addonRoot, tempTopology, plan, out luaMsg))
                        {
                            throw new Exception(string.Format("Preset '{0}' ({1}) failed Lua module check: {2}", preset.Id, mode, luaMsg));
                        }

                        verifiedCount++;
                    }
                    Console.WriteLine(string.Format("  [OK] {0,-32} (Schema {1}, {2}) -> 4 scale plans verified in C# & Lua", preset.Id, preset.Schema, preset.Mode));
                }
            }
            finally
            {
                try { if (File.Exists(tempTopology)) File.Delete(tempTopology); } catch { }
            }

            Console.WriteLine("PASS: " + verifiedCount + " preset/scale plans, GDI clipping regions, and Offhand Lua modules verified.");
            return 0;
        }

        [STAThread]
        public static int Main(string[] args)
        {
            Win32Interop.SetProcessDPIAware();
            string addonRoot = Environment.CurrentDirectory;
            bool selfTest = false;
            bool listPresets = false;

            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "--self-test") selfTest = true;
                else if (args[i] == "--list-presets") listPresets = true;
                else if (args[i] == "--addon-root" && i + 1 < args.Length) addonRoot = args[++i];
            }

            if (listPresets)
            {
                foreach (TopologyPreset p in PresetCatalog.CreateAll())
                {
                    Rectangle u = p.ComputeUnionBounds();
                    Console.WriteLine(string.Format("{0,-30} | Schema {1} | {2,-18} | {3}x{4} | {5}", p.Id, p.Schema, p.Mode, u.Width, u.Height, p.Name));
                }
                return 0;
            }

            if (selfTest)
            {
                return RunCliSelfTest(addonRoot);
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new SimulatorForm(addonRoot));
            return 0;
        }
    }
}
