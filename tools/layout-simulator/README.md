# Offhand Virtual Monitor & Layout Simulator (`tools/layout-simulator`)

Local Windows testing application for simulating multi-monitor layouts, mixed resolutions, GDI void clipping, and `Core/CompanionTopology.lua` schemas (1, 2, and 3) against a live Windowed World of Warcraft client or the headless Lua 5.1 verification harness—even when developing on a single physical monitor.

## Quick Start

### Launch the GUI Simulator

Double-click [`Start-LayoutSimulator.cmd`](file:///d:/Tools/Code/Offhand/tools/layout-simulator/Start-LayoutSimulator.cmd) or run from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/layout-simulator/Start-LayoutSimulator.ps1
```

### Run the Automated CLI & Lua Verification Suite

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/layout-simulator/Start-LayoutSimulator.ps1 -SelfTest
```

### List All Built-in Monitor Topology Presets

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/layout-simulator/Start-LayoutSimulator.ps1 -ListPresets
```

---

## Live World of Warcraft Testing Workflow

1. **Launch World of Warcraft** in **Windowed** mode (with the `Offhand` add-on enabled).
2. **Open the Simulator** (`Start-LayoutSimulator.cmd`).
3. **Pick a Preset or Build Any Custom Resolution & Monitor Combination**:
   - **Starting Preset**: Choose any of the 12 built-in topologies (Dual 16:9, 21:9 + Portrait, 4K + 1440p, Vertical Stacked, 32:9 Split, 3-Monitor Dual Workspace, Flexible Centered Wings).
   - **Custom Monitor & Resolution Builder**:
     - Select **Mainhand Game** or any **Workspace** region from `Custom Edit Region`.
     - Choose a **Quick Resolution** (`1920x1080`, `2560x1440`, `3840x2160 4K`, `3440x1440 21:9`, `5120x1440 32:9`, `1080x1920 Portrait`, `1440x2560 Portrait`, `2560x1600`, etc.) **or** dial in any arbitrary `Width`, `Height`, `X Offset`, and `Y Offset`.
     - Click **`+ Add Monitor/WS`** or **`- Remove WS`** to add or remove additional workspace screens on the fly (automatically upgrading/downgrading between Schema 1 and Schema 2/3).
     - Use **Quick Arrangement** buttons (`Snap Left of Game`, `Snap Right of Game`, `Snap Above Game`, `Snap Below Game`, `Align Bottoms`, `Center Vertically`, `Align Tops`) **or click and drag any screen directly on the preview canvas** to test arbitrary offsets and gaps.
   - **In-Game Layout & Span Overlay (`Show In-Game HUD & Panel Overlay`)**:
     - Displays where the **3D `WorldFrame` camera reticle**, **Minimap**, **Quest Tracker**, **Player/Target UnitFrames**, and **Action Bars** sit inside Mainhand (scaled by `DesiredHUDScale`).
     - Displays where the **Offhand Deck Header**, **ChatFrame**, **Bags**, and **Talents / World Map / Character** panels sit inside each Workspace, along with live **Panel Fit vs. Mainhand Recovery** telemetry (`FITS WORKSPACE (100% Native)`, `AUTO-SCALED IN WORKSPACE`, or `MAINHAND RECOVERY`).
     - Highlights **Dead Void Space** (hatched crimson/charcoal) that GDI `SetWindowRgn` clips out on mixed-height or stacked monitor combinations.
   - **Simulation Scale Mode**:
     - **Fit to Host Monitor (Proportional)**: Proportionally scales large multi-monitor canvases (such as Dual 4K `7680x2160`, 32:9 `5120x1440`, or Triple-Monitor `6400x1440`) so the entire spanned WoW window fits inside your single physical monitor while preserving exact aspect ratios, region offsets, GDI void clipping, and Schema 2/3 region size minimums (`game >= 960x600`, `workspace >= 480x600`).
     - **1:1 Exact Pixel Resolution**: Resizes the borderless WoW window to the exact pixel dimensions of the preset (`physicalWidth x physicalHeight`).
     - **75% / 50% Proportional Scale**: Fixed proportional scaling factors.
4. **Click `1. Simulate on Live WoW`**:
   - Auto-detects the running WoW process and resolves `<WoW>/Interface/AddOns/Offhand`.
   - Backs up your original WoW window style, outer bounds, and `Core/CompanionTopology.lua`.
   - Stages the matching `Core/CompanionTopology.lua` payload (Schema 1, 2, or 3).
   - Applies borderless window styling (`SetWindowLong`), GDI non-rectangular clipping (`CreateRectRgn` + `CombineRgn` + `SetWindowRgn`) so dead-space voids are clipped out just like real mixed-height monitors, and resizes/moves the WoW window (`SetWindowPos`).
5. **In World of Warcraft, type `/reload`**:
   - Offhand's [`Viewport:GetMetrics()`](file:///d:/Tools/Code/Offhand/Core/Viewport.lua) and [`TopologyDetection.Detect()`](file:///d:/Tools/Code/Offhand/Core/TopologyDetection.lua) will read the live `GetPhysicalScreenSize()` and `UIParent` dimensions, validate `OffhandCompanionTopology`, restrict the 3D `WorldFrame` to the Mainhand region, and open the Offhand workspace across the simulated Secondary / Wing / Stacked regions.
   - Type `/offhand diag` or `/offhand status` in-game to inspect live add-on telemetry.
6. **Click `2. Verify State & Run Lua QA`**:
   - Verifies that the live WoW window's drawable client rect (`GetClientRect`) matches the simulated `physicalWidth x physicalHeight` within tolerance and runs headless Lua 5.1 assertions against [`Core/WorkspaceRegions.lua`](file:///d:/Tools/Code/Offhand/Core/WorkspaceRegions.lua), [`Core/Viewport.lua`](file:///d:/Tools/Code/Offhand/Core/Viewport.lua), [`Core/TopologyDetection.lua`](file:///d:/Tools/Code/Offhand/Core/TopologyDetection.lua), and [`Core/CanvasPersistence.lua`](file:///d:/Tools/Code/Offhand/Core/CanvasPersistence.lua).
7. **Click `3. Restore Window & Reset`** (or close the simulator and confirm restore):
   - Clears the GDI clipping region, restores the original WoW window frame and bounds, and restores `Core/CompanionTopology.lua` to its inert `OffhandCompanionTopology = nil` state.

---

## Built-in Monitor Topology Presets (12 Topologies)

| Preset ID | Schema | Mode | Native Canvas | Description |
| :--- | :---: | :--- | :---: | :--- |
| `dual-1080p-left` | 1 | `DUAL_DISPLAY` | `3840x1080` | Dual 1080p Side-by-Side (`1920x1080` + `1920x1080`, Game Left) |
| `dual-1440p-right` | 1 | `DUAL_DISPLAY` | `5120x1440` | Dual 1440p Side-by-Side (`2560x1440` + `2560x1440`, Game Right / Negative Origin) |
| `dual-4k-left` | 1 | `DUAL_DISPLAY` | `7680x2160` | Dual 4K UHD Side-by-Side (`3840x2160` + `3840x2160`) |
| `portrait-1080p-landscape-1440p` | 1 | `DUAL_DISPLAY` | `3640x1920` | Portrait 1080p Left + 1440p Landscape Right (`1080x1920` + `2560x1440`, 480px void clipped) |
| `ultrawide-21-9-portrait-1440p` | 1 | `DUAL_DISPLAY` | `4880x2560` | Ultrawide 21:9 (`3440x1440`) + Portrait 1440p (`1440x2560`) |
| `mixed-4k-1440p` | 1 | `DUAL_DISPLAY` | `6400x2160` | 4K Mainhand (`3840x2160`) + 1440p Workspace (`2560x1440`, Bottom-Aligned, top-right void clipped) |
| `stacked-vertical-1440p-1080p` | 1 | `DUAL_DISPLAY` | `2560x2520` | Stacked Vertical (`2560x1440` Bottom Game + `1920x1080` Top Centered Workspace) |
| `super-ultrawide-32-9-split` | 1 | `SPLIT_ULTRAWIDE` | `5120x1440` | Super-Ultrawide 32:9 Single-Display 50/50 Split (`5120x1440`) |
| `partial-single-4080x1440` | 1 | `SPLIT_ULTRAWIDE` | `4080x1440` | Partial Single-Monitor Split (`3440x1440` Game + `640x1440` Workspace = `4080x1440`) |
| `schema2-three-monitors` | 2 | `CUSTOM_REGIONS` | `6400x1440` | Three-Monitor Dual Workspace (1080p Left WS-A + 1440p Center Game + 1080p Right WS-B) |
| `schema3-centered-wings` | 3 | `CUSTOM_REGIONS` | `5120x1440` | Flexible 32:9 Centered Game (`1280px` Left WS-A + `2560px` Center Game + `1280px` Right WS-B) |
| `schema3-stacked-sidebar` | 3 | `CUSTOM_REGIONS` | `5120x1440` | Flexible Stacked Sidebar (Two `1280x720` Stacked Workspaces + `3840x1440` Game) |

---

## Security & Evidence Boundary

- **Strict Win32 Boundary**: Uses only standard window-geometry and process-path inspection APIs (`GetWindowLong`, `SetWindowLong`, `GetWindowRect`, `GetClientRect`, `AdjustWindowRectEx`, `SetWindowPos`, `CreateRectRgn`, `CombineRgn`, `SetWindowRgn`, `QueryFullProcessImageName` with `PROCESS_QUERY_LIMITED_INFORMATION`). No input injection, window message posting, hooks, or process memory APIs are present.
- **Simulation vs. Physical Hardware Evidence**:
  - **Verified by this Simulator**: Live WoW borderless window sizing, GDI non-rectangular dead-space clipping (`SetWindowRgn`), `GetPhysicalScreenSize()` + `UIParent` coordinate alignment, `CompanionTopology.lua` Schema 1/2/3 parsing, `Viewport` camera/WorldFrame split calculations, `WorkspaceRegions` multi-workspace normalization, `TopologyDetection`, and `CanvasPersistence`.
  - **Requires Physical Multi-Monitor Hardware**: OS per-monitor mixed-DPI scaling transitions across physical display boundaries, physical DisplayPort/HDMI hotplug/disconnect EDID events, and live combat/taint lockdown transitions during active gameplay.
