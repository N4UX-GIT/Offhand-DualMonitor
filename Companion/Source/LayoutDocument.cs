using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Drawing;
using System.Text.RegularExpressions;

namespace Offhand.Companion
{
    // Authoring and validation only. This model has no native calls, files,
    // process inspection, gameplay input, timers, or automatic application.
    internal sealed class WorkspaceLayoutDocument
    {
        internal const int CurrentVersion = 1;
        internal int Version = CurrentVersion;
        internal string Id;
        internal string Name;
        internal string PrimaryWorkspaceId;
        internal WorkspaceLayoutRegion Game;
        internal List<WorkspaceLayoutRegion> Workspaces = new List<WorkspaceLayoutRegion>();
        internal List<WorkspaceLayoutBinding> Displays = new List<WorkspaceLayoutBinding>();

        internal WorkspaceLayoutDocument Copy()
        {
            if (Version != CurrentVersion || Workspaces == null || Displays == null)
                throw new InvalidOperationException("Unsupported or incomplete layout document.");
            var copy = new WorkspaceLayoutDocument { Version = Version, Id = Id, Name = Name,
                PrimaryWorkspaceId = PrimaryWorkspaceId, Game = Game == null ? null : Game.Copy() };
            foreach (var region in Workspaces) copy.Workspaces.Add(region == null ? null : region.Copy());
            foreach (var display in Displays) copy.Displays.Add(display == null ? null : display.Copy());
            return copy;
        }
    }

    internal sealed class WorkspaceLayoutBinding
    {
        internal string Role;
        internal string StableId;
        internal Size Resolution;
        internal WorkspaceLayoutBinding Copy()
        { return new WorkspaceLayoutBinding { Role = Role, StableId = StableId, Resolution = Resolution }; }
    }

    internal sealed class WorkspaceLayoutRegion
    {
        internal string Id;
        internal string DisplayRole;
        // Monitor-local physical pixels, origin at the top left.
        internal Rectangle Bounds;
        internal WorkspaceLayoutRegion Copy()
        { return new WorkspaceLayoutRegion { Id = Id, DisplayRole = DisplayRole, Bounds = Bounds }; }
    }

    internal sealed class ResolvedWorkspaceRegion
    {
        internal readonly string Id;
        internal readonly int DisplayIndex;
        internal readonly Rectangle Bounds;
        internal ResolvedWorkspaceRegion(string id, int displayIndex, Rectangle bounds)
        { Id = id; DisplayIndex = displayIndex; Bounds = bounds; }
    }

    internal sealed class ResolvedWorkspaceLayout
    {
        internal readonly Rectangle Bounds;
        internal readonly ResolvedWorkspaceRegion Game;
        internal readonly ReadOnlyCollection<ResolvedWorkspaceRegion> Workspaces;
        internal readonly ReadOnlyCollection<int> DisplayIndices;
        internal readonly string PrimaryWorkspaceId;
        internal ResolvedWorkspaceLayout(Rectangle bounds, ResolvedWorkspaceRegion game,
            List<ResolvedWorkspaceRegion> workspaces, List<int> indices, string primary)
        {
            Bounds = bounds; Game = game; Workspaces = workspaces.AsReadOnly();
            DisplayIndices = indices.AsReadOnly(); PrimaryWorkspaceId = primary;
        }
    }

    internal static class WorkspaceLayoutPlanner
    {
        internal const int MaximumWorkspaces = 2;
        internal const int MaximumAxis = 16384;
        private static readonly Regex Identifier = new Regex(@"\A[A-Za-z0-9_-]{1,32}\z");

        private static void Require(bool valid, string message)
        { if (!valid) throw new InvalidOperationException(message); }
        private static bool Id(string value)
        { return value != null && Identifier.IsMatch(value); }
        private static bool Fits(Rectangle inner, Size outer)
        {
            return inner.X >= 0 && inner.Y >= 0 && inner.Width > 0 && inner.Height > 0
                && (long)inner.X + inner.Width <= outer.Width && (long)inner.Y + inner.Height <= outer.Height;
        }
        private static bool Overlaps(Rectangle a, Rectangle b)
        {
            return Math.Max((long)a.Left, b.Left) < Math.Min((long)a.Left + a.Width, (long)b.Left + b.Width)
                && Math.Max((long)a.Top, b.Top) < Math.Min((long)a.Top + a.Height, (long)b.Top + b.Height);
        }
        private static Rectangle Absolute(Rectangle local, Rectangle monitor)
        {
            long x = (long)monitor.X + local.X, y = (long)monitor.Y + local.Y;
            Require(x >= int.MinValue && y >= int.MinValue && x + local.Width <= int.MaxValue
                && y + local.Height <= int.MaxValue, "Layout coordinates exceed the desktop range.");
            return new Rectangle((int)x, (int)y, local.Width, local.Height);
        }
        private static Rectangle Union(Rectangle a, Rectangle b)
        {
            long left = Math.Min(a.X, b.X), top = Math.Min(a.Y, b.Y);
            long right = Math.Max((long)a.X + a.Width, (long)b.X + b.Width);
            long bottom = Math.Max((long)a.Y + a.Height, (long)b.Y + b.Height);
            Require(right - left <= MaximumAxis && bottom - top <= MaximumAxis,
                "The layout backing surface exceeds the supported dimensions.");
            return new Rectangle((int)left, (int)top, (int)(right - left), (int)(bottom - top));
        }

        internal static ResolvedWorkspaceLayout Resolve(WorkspaceLayoutDocument document,
            IList<MonitorSelection.Display> displays)
        {
            Require(document != null && document.Version == WorkspaceLayoutDocument.CurrentVersion,
                "Unsupported layout document version.");
            Require(Id(document.Id) && !string.IsNullOrWhiteSpace(document.Name) && document.Name.Length <= 48,
                "Choose a valid layout ID and name.");
            foreach (char ch in document.Name) Require(!char.IsControl(ch) && ch != '|', "The layout name contains unsupported characters.");
            Require(displays != null && displays.Count > 0 && displays.Count <= 64, "Connected displays are unavailable or ambiguous.");
            Require(document.Displays != null && document.Displays.Count > 0 && document.Displays.Count <= 3,
                "A layout needs one to three display roles.");
            Require(document.Game != null && document.Workspaces != null && document.Workspaces.Count >= 1
                && document.Workspaces.Count <= MaximumWorkspaces, "Choose one game area and one or two workspaces.");
            Require(document.Game.Id == "game", "The game region must retain its reserved ID.");
            var bindings = new Dictionary<string, WorkspaceLayoutBinding>(StringComparer.Ordinal);
            foreach (var binding in document.Displays)
            {
                Require(binding != null && Id(binding.Role) && !string.IsNullOrWhiteSpace(binding.StableId)
                    && binding.StableId.Length <= 512 && !bindings.ContainsKey(binding.Role)
                    && binding.Resolution.Width > 0 && binding.Resolution.Height > 0, "Invalid or duplicate display role.");
                bindings.Add(binding.Role, binding);
            }
            var usedRoles = new HashSet<string>(StringComparer.Ordinal);
            var ids = new HashSet<string>(StringComparer.Ordinal);
            var indices = new List<int>();
            Func<WorkspaceLayoutRegion, bool, ResolvedWorkspaceRegion> resolve = (region, game) => {
                Require(region != null && Id(region.Id) && ids.Add(region.Id), "Region IDs must be valid and unique.");
                WorkspaceLayoutBinding binding;
                Require(region.DisplayRole != null && bindings.TryGetValue(region.DisplayRole, out binding),
                    "A region's display role is missing.");
                binding = bindings[region.DisplayRole]; usedRoles.Add(binding.Role);
                int found = MonitorSelection.FindDisplay(displays,binding.StableId,null);
                Require(found != -2,"A display identity is ambiguous.");
                Require(found >= 0, "A required display is disconnected. Review the layout before applying.");
                var display = displays[found];
                Require(!string.IsNullOrWhiteSpace(display.DeviceName) && display.Bounds.Size == binding.Resolution,
                    "The display resolution or identity changed. Review the layout.");
                Require(display.Bounds.Width<=32768 && display.Bounds.Height<=32768
                    && (long)display.Bounds.X+display.Bounds.Width<=int.MaxValue
                    && (long)display.Bounds.Y+display.Bounds.Height<=int.MaxValue,
                    "The selected physical display exceeds the supported coordinate range.");
                Require(Fits(region.Bounds, display.Bounds.Size), "Each region must fit wholly inside its display.");
                Require(region.Bounds.Width >= (game ? 960 : 480) && region.Bounds.Height >= 600
                    && region.Bounds.Width <= MaximumAxis && region.Bounds.Height <= MaximumAxis,
                    "The game needs at least 960x600 and each workspace at least 480x600 pixels.");
                // The same resolved monitor may contain several non-overlapping regions.
                if (!indices.Contains(found)) indices.Add(found);
                return new ResolvedWorkspaceRegion(region.Id, found, Absolute(region.Bounds, display.Bounds));
            };
            var resolvedGame = resolve(document.Game, true);
            var workspaces = new List<ResolvedWorkspaceRegion>();
            Rectangle bounds = resolvedGame.Bounds;
            bool primaryFound = false;
            foreach (var region in document.Workspaces)
            {
                var workspace = resolve(region, false);
                Require(!Overlaps(workspace.Bounds, resolvedGame.Bounds), "A workspace overlaps the game area.");
                foreach (var existing in workspaces)
                    Require(!Overlaps(workspace.Bounds, existing.Bounds), "Workspace areas overlap.");
                bounds = Union(bounds, workspace.Bounds); workspaces.Add(workspace);
                primaryFound |= workspace.Id == document.PrimaryWorkspaceId;
            }
            Require(primaryFound && usedRoles.Count == bindings.Count, "Choose a primary workspace and remove unused display roles.");
            MonitorSelection.ValidatePhysicalIdentities(displays,indices);
            for (int a = 0; a < indices.Count; a++) for (int b = a + 1; b < indices.Count; b++)
                Require(!string.Equals(displays[indices[a]].DeviceName, displays[indices[b]].DeviceName, StringComparison.OrdinalIgnoreCase)
                    && !Overlaps(displays[indices[a]].Bounds, displays[indices[b]].Bounds),
                    "Selected physical displays overlap or have ambiguous device names.");
            Require((long)bounds.Width * bounds.Height <= (long)resolvedGame.Bounds.Width * resolvedGame.Bounds.Height * 4,
                "The layout backing surface exceeds the supported game-area budget.");
            return new ResolvedWorkspaceLayout(bounds, resolvedGame, workspaces, indices, document.PrimaryWorkspaceId);
        }

        // Legacy conversion is explicitly requested by its caller and writes no
        // preferences. Legacy plans outside the new limits stay on their old path.
        internal static bool TryConvertLegacy(MonitorSelection.Plan plan, IList<MonitorSelection.Display> displays,
            string id, string name, out WorkspaceLayoutDocument document, out string reason)
        {
            document = null; reason = null;
            try
            {
                Require(plan != null && displays != null, "The legacy plan is unavailable.");
                var draft = new WorkspaceLayoutDocument { Id = id, Name = name };
                var roles = new Dictionary<int, string>();
                Func<string, int, Rectangle, WorkspaceLayoutRegion> local = (regionId, index, bounds) => {
                    Require(index >= 0 && index < displays.Count && displays[index] != null, "A legacy display is unavailable.");
                    string role;
                    if (!roles.TryGetValue(index, out role))
                    {
                        role = "display-" + roles.Count; roles.Add(index, role);
                        draft.Displays.Add(new WorkspaceLayoutBinding { Role = role, StableId = displays[index].StableId,
                            Resolution = displays[index].Bounds.Size });
                    }
                    var monitor = displays[index].Bounds;
                    long x = (long)bounds.X - monitor.X, y = (long)bounds.Y - monitor.Y;
                    Require(x >= 0 && y >= 0 && x <= int.MaxValue && y <= int.MaxValue, "Invalid legacy region coordinates.");
                    return new WorkspaceLayoutRegion { Id = regionId, DisplayRole = role,
                        Bounds = new Rectangle((int)x, (int)y, bounds.Width, bounds.Height) };
                };
                draft.Game = local("game", plan.MainhandIndex, plan.MainhandBounds);
                if (plan.MultiRegion)
                {
                    foreach (var workspace in plan.Workspaces)
                    {
                        Require(workspace != null, "A legacy workspace is incomplete.");
                        draft.Workspaces.Add(local(workspace.Id, workspace.DisplayIndex, workspace.Bounds));
                    }
                    draft.PrimaryWorkspaceId = plan.PrimaryWorkspaceId;
                }
                else
                {
                    draft.Workspaces.Add(local("workspace-a", plan.WorkspaceIndex, plan.WorkspaceBounds));
                    draft.PrimaryWorkspaceId = "workspace-a";
                }
                Resolve(draft, displays); document = draft; return true;
            }
            catch (InvalidOperationException ex) { reason = ex.Message; return false; }
        }
    }
}
