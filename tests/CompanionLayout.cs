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
                var toggle = parent.Controls.OfType<Button>().FirstOrDefault(button => button.Text == "Show" || button.Text == "Hide");
                if (toggle != null && ((toggle.Text == "Show" && child != toggle && child != parent.Controls[0]
                        && child.AccessibleName != "System status summary") ||
                    (toggle.Text == "Hide" && child.AccessibleName == "System status summary"))) continue;
                Point location = new Point(origin.X + child.Left, origin.Y + child.Top);
                using (var bitmap = new Bitmap(child.Width, child.Height))
                {
                    child.DrawToBitmap(bitmap, new Rectangle(Point.Empty, bitmap.Size));
                    RenderChildren(child, bitmap, Point.Empty);
                    using (var graphics = Graphics.FromImage(target)) graphics.DrawImageUnscaled(bitmap, location);
                }
            }
        }

        private static void CheckScale(float factor, bool enlargedChildren = false)
        {
            // Synthetic work areas still obey WinForms' host MaxWindowTrackSize.
            // Verify scrolling at that native limit and full fit when space exists.
            using (var form = new CompanionForm())
            {
                form.CreateControl();
                form.Scale(new SizeF(factor, factor));
                LayoutAll(form);
                CheckHelpLayout(form, factor);

                Panel config = Descendants(form).OfType<Panel>().Single(panel =>
                    panel.Controls.OfType<Label>().Any(label => label.Text == "CONFIGURATION"));
                var delay = One<NumericUpDown>(config, control => true);
                var displays = One<CheckedListBox>(config, control => true);
                var combos = Descendants(config).OfType<ComboBox>().ToArray();
                if (combos.Length != 2) throw new Exception("Expected Mainhand and game-side selectors.");
                ComboBox mainhand = combos.Single(control => control.AccessibleName == "Mainhand game display");
                ComboBox gameSide = combos.Single(control => control.AccessibleName == "Game side on single display");
                Button identify = One<Button>(config, control => control.Text == "Identify Displays");
                if (enlargedChildren)
                {
                    form.Font = new Font("Segoe UI", 9f * factor);
                    displays.Scale(new SizeF(factor, factor));
                    delay.Parent.Controls[0].Scale(new SizeF(factor, factor));
                    LayoutAll(form);
                }

                Button custom = One<Button>(config, control => control.Text.StartsWith("Workspace layout ("));
                Button profiles = One<Button>(config, control => control.Text == "Workspace profiles...");
                foreach (Control control in new Control[] { delay, displays, mainhand, gameSide, identify, custom, profiles })
                {
                    Rectangle bounds = BoundsInside(control, config);
                    if (bounds.Left < 0 || bounds.Top < 24 || bounds.Right > config.ClientSize.Width
                        || bounds.Bottom > config.ClientSize.Height)
                        throw new Exception(control.GetType().Name + " escaped the configuration card at " + factor + "x: " + bounds);
                    if (bounds.Width <= 0 || bounds.Height <= 0)
                        throw new Exception(control.GetType().Name + " collapsed at " + factor + "x.");
                    for (Control parent = control.Parent; parent != config; parent = parent.Parent)
                    {
                        Rectangle inside = BoundsInside(control, parent);
                        if (!parent.ClientRectangle.Contains(inside))
                            throw new Exception(control.GetType().Name + " clipped by " + parent.GetType().Name
                                + " at " + factor + "x: " + inside);
                    }
                }

                Rectangle displayBounds = BoundsInside(displays, config);
                Rectangle mainhandBounds = BoundsInside(mainhand, config);
                Rectangle identifyBounds = BoundsInside(identify, config);
                if (displayBounds.Bottom >= mainhandBounds.Top)
                    throw new Exception("Display checklist overlaps Mainhand at " + factor + "x.");
                if (identifyBounds.Right >= displayBounds.Left)
                    throw new Exception("Identify Displays overlaps the display selectors at " + factor + "x.");

                if (profiles.Top != custom.Top || profiles.Height != custom.Height ||
                    BoundsInside(profiles, config).Right != identifyBounds.Right ||
                    BoundsInside(custom, config).Left != displayBounds.Left)
                    throw new Exception("Workspace actions are misaligned at " + factor + "x.");
                if (BoundsInside(gameSide, config).Top != mainhandBounds.Top)
                    throw new Exception("Game Side and Mainhand selectors are misaligned at " + factor + "x.");
                foreach (Control field in new Control[] { delay, gameSide, mainhand })
                    if (!field.Parent.ClientRectangle.Contains(field.Bounds))
                        throw new Exception(field.AccessibleName + " is clipped by its own row at " + factor + "x.");

                Panel status = Descendants(form).OfType<Panel>().Single(panel =>
                    panel.Controls.OfType<Label>().Any(label => label.Text == "SYSTEM STATUS"));
                var summary = One<Label>(status, label => label.AccessibleName == "System status summary");
                if (!status.Controls.OfType<Button>().Any(button => button.Text == "Show") ||
                    !config.Controls.OfType<Button>().Any(button => button.Text == "Hide"))
                    throw new Exception("Fresh dashboard must collapse System Status and expand Configuration.");
                foreach (string heading in new[] { "DISPLAY DIAGNOSTICS", "ACTIVITY LOG" })
                {
                    Panel card = Descendants(form).OfType<Panel>().Single(panel =>
                        panel.Controls.OfType<Label>().Any(label => label.Text == heading));
                    if (!card.Controls.OfType<Button>().Any(button => button.Text == "Show"))
                        throw new Exception("Supporting panels must start collapsed.");
                }
                var span = One<Button>(form, button => button.Text == "Span WoW Now");
                var restore = One<Button>(form, button => button.Text == "Restore Window");
                if (span.Parent != restore.Parent || span.Width <= restore.Width ||
                    BoundsInside(span, form).Top >= BoundsInside(status, form).Top ||
                    span.Height < 44 * factor - 1 || Descendants(form).OfType<Button>().Any(button => button.Text == "Pause Monitor"))
                    throw new Exception("Primary actions must be prominent and precede System Status.");
                CheckActionGuidance(form);
                form.UpdateClientStatus(null, false);
                if (!summary.Text.Contains("WoW not running")) throw new Exception("Collapsed status lost stopped-client text.");
                form.FitDashboardToWorkingArea(Screen.PrimaryScreen.WorkingArea);
                LayoutAll(form);
                var headingLabel = status.Controls.OfType<Label>().Single(label => label.Text == "SYSTEM STATUS");
                var showButton = status.Controls.OfType<Button>().Single(button => button.Text == "Show");
                if (!status.ClientRectangle.Contains(summary.Bounds) || summary.Left <= headingLabel.Right || summary.Right >= showButton.Left ||
                    TextRenderer.MeasureText(summary.Text, summary.Font).Width > summary.Width)
                    throw new Exception("Collapsed status summary must fit between its title and Show button at " + factor + "x.");
                string defaultPreview = Environment.GetEnvironmentVariable("OFFHAND_LAYOUT_PREVIEW");
                if (factor == 1f && !string.IsNullOrEmpty(defaultPreview))
                    using (var bitmap = new Bitmap(form.ClientSize.Width, form.ClientSize.Height))
                    {
                        using (var graphics = Graphics.FromImage(bitmap)) graphics.Clear(form.BackColor);
                        RenderChildren(form, bitmap, Point.Empty);
                        bitmap.Save(defaultPreview + ".default.png", System.Drawing.Imaging.ImageFormat.Png);
                    }
                form.UpdateClientStatus(new AddonStatus { Installed = false, SetupHint = "Install Offhand." }, true);
                if (!summary.Text.Contains("Check add-on")) throw new Exception("Collapsed status hid an addon problem.");
                Color attentionColor = summary.ForeColor;
                form.UpdateClientStatus(new AddonStatus { Installed = true }, true);
                if (!summary.Text.Contains("WoW running")) throw new Exception("Collapsed status lost running-client text.");
                var layoutLine = status.Controls.OfType<Label>().Single(label => label.Text.StartsWith("Display layout"));
                Color layoutColor = layoutLine.ForeColor;
                layoutLine.ForeColor = attentionColor;
                if (!summary.Text.Contains("Check display layout")) throw new Exception("Collapsed status hid a layout problem.");
                layoutLine.ForeColor = layoutColor;
                var tray = (NotifyIcon)typeof(CompanionForm).GetField("trayIcon",
                    System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic).GetValue(form);
                var monitorItem = tray.ContextMenuStrip.Items.OfType<ToolStripMenuItem>().Single(item => item.Text == "Pause background monitoring");
                monitorItem.PerformClick();
                if (!summary.Text.Contains("Monitoring paused")) throw new Exception("Tray pause must remain visible on dashboard.");
                if (monitorItem.Text != "Resume background monitoring") throw new Exception("Tray menu must allow resuming.");
                monitorItem.PerformClick();
                if (monitorItem.Text != "Pause background monitoring" || !summary.Text.Contains("WoW running"))
                    throw new Exception("Tray resume must restore launch monitoring and the client summary.");
                CompanionUi.PrimeScrollbars(form);
                var viewportBeforeToggles = form.Controls.OfType<Panel>().Single(panel => panel.AutoScroll);
                var stackBeforeToggles = viewportBeforeToggles.Controls.OfType<TableLayoutPanel>().Single();
                int stableContentWidth = stackBeforeToggles.Width;
                int transientResizes = 0, contentWidthChanges = 0, logHandleCreations = 0;
                var logControl = One<RichTextBox>(form, item => true);
                if (!logControl.IsHandleCreated) throw new Exception("Hidden Activity Log must be themed before its first Show.");
                EventHandler onOuterChange = (sender, args) => { transientResizes++; };
                EventHandler onContentChange = (sender, args) => { if (stackBeforeToggles.Width != stableContentWidth) contentWidthChanges++; };
                EventHandler onLogHandle = (sender, args) => { logHandleCreations++; };
                form.SizeChanged += onOuterChange;
                form.LocationChanged += onOuterChange;
                stackBeforeToggles.SizeChanged += onContentChange;
                logControl.HandleCreated += onLogHandle;
                foreach (Panel section in new[] { status, config,
                    Descendants(form).OfType<Panel>().Single(panel => panel.Controls.OfType<Label>().Any(label => label.Text == "DISPLAY DIAGNOSTICS")),
                    Descendants(form).OfType<Panel>().Single(panel => panel.Controls.OfType<Label>().Any(label => label.Text == "ACTIVITY LOG")) })
                {
                    bool expanded = section.Controls.OfType<Button>().Any(button => button.Text == "Hide");
                    Rectangle stableBounds = form.Bounds;
                    form.SetDashboardSectionExpanded(section, !expanded, true);
                    LayoutAll(form);
                    if (form.Bounds != stableBounds) throw new Exception("Toggling a panel resized or moved the dashboard.");
                    form.SetDashboardSectionExpanded(section, expanded, true);
                    LayoutAll(form);
                    if (form.Bounds != stableBounds) throw new Exception("Restoring a panel resized or moved the dashboard.");
                }
                form.SizeChanged -= onOuterChange;
                form.LocationChanged -= onOuterChange;
                stackBeforeToggles.SizeChanged -= onContentChange;
                logControl.HandleCreated -= onLogHandle;
                if (transientResizes != 0 || contentWidthChanges != 0 || logHandleCreations != 0)
                    throw new Exception("Show/Hide caused transient outer/content resizing or late log creation: "
                        + transientResizes + "/" + contentWidthChanges + "/" + logHandleCreations);
                form.SetDashboardSectionExpanded(status, true, false);
                var layoutStatus = status.Controls.OfType<Label>().Single(label => label.Text.StartsWith("Display layout"));
                var roomyDesktop = new Rectangle(0, 0, 2560, 2300);
                form.FitDashboardToWorkingArea(roomyDesktop);
                Rectangle startupBounds = form.Bounds;
                var legacy = new Dictionary<string, string> { { "DisplayIdentityVersion", "1" } };
                string review = CompanionForm.DisplaySelectionPrompt(legacy, true, true);
                if (!review.StartsWith("Confirm your saved displays\r\n") || !review.Contains("With WoW open") ||
                    !review.Contains("click Span WoW Now") || !review.Contains("when you click OK") ||
                    !review.Contains("\r\nTo change the layout, open Workspace layout.") ||
                    CompanionForm.DisplaySelectionPrompt(legacy, false, true).Contains("Workspace layout"))
                    throw new Exception("Saved display review must explain when to open the confirmation and how to accept it.");
                layoutStatus.Text = review;
                form.UpdateClientStatus(null, false);
                Panel scrollPanel = form.Controls.OfType<Panel>().Single(panel => panel.AutoScroll);
                var cards = scrollPanel.Controls.OfType<TableLayoutPanel>().Single();
                if (cards.Height + scrollPanel.Padding.Vertical <= scrollPanel.ClientSize.Height)
                    throw new Exception("Fixture did not reproduce the initial status refresh outgrowing the startup window.");
                // Status updates and panel toggles must scroll within the
                // existing window rather than grow or move the dashboard.
                LayoutAll(form);
                bool contentOverflows = cards.Bottom > scrollPanel.ClientSize.Height - scrollPanel.Padding.Bottom;
                if (form.Bounds != startupBounds || (contentOverflows != scrollPanel.VerticalScroll.Visible))
                    throw new Exception("Status refresh must preserve bounds and scroll overflowing content at " + factor
                        + "x. Startup=" + startupBounds + ", current=" + form.Bounds
                        + ", viewport=" + scrollPanel.ClientSize + ", cardsBottom=" + cards.Bottom
                        + ", padding=" + scrollPanel.Padding + ", scrollbar=" + scrollPanel.VerticalScroll.Visible
                        + ", maximum=" + form.MaximumSize + ", host=" + SystemInformation.VirtualScreen);

                layoutStatus.Text = "Standard layout: full monitors\r\nSelected display layout\r\nGame 2560 × 1440  •  Workspace 1418 × 1440";
                form.UpdateClientStatus(null, false);
                if (!status.Controls.OfType<Label>().Any(label => label.Text == "WoW: Not running"))
                    throw new Exception("System Status omitted the stopped client state.");
                form.UpdateClientStatus(new AddonStatus {
                    WowDir = @"C:\Game\_forever_", Reason = @"Detailed diagnostic at C:\Game\_forever_\Interface\AddOns\Offhand",
                    SetupHint = "Install Offhand for the running WoW client."
                }, true);
                if (!status.Controls.OfType<Label>().Any(label => label.Text == "Install Offhand for the running WoW client.") ||
                    status.Controls.OfType<Label>().Any(label => label.Text.Contains(@"C:\Game")))
                    throw new Exception("System Status needs a next step without an installation path.");
                form.UpdateClientStatus(new AddonStatus {
                    Installed = true, WowDir = @"C:\Game\_forever_", ReleaseTag = "beta.26"
                }, true);
                if (!status.Controls.OfType<Label>().Any(label => label.Text == "WoW: Forever running") ||
                    !status.Controls.OfType<Label>().Any(label => label.Text == "Offhand addon: Installed (beta.26)"))
                    throw new Exception("System Status omitted the client or addon release.");

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
                    var website = One<Button>(help.Parent, button => button.Text == "Website");
                    var discord = One<Button>(help.Parent, button => button.Text == "Discord");
                    var curseForge = One<Button>(help.Parent, button => button.Text == "CurseForge");
                    var version = One<Label>(help.Parent, label => label.Text.StartsWith("v2."));
                    if (website.Top < version.Bottom || discord.Top != website.Top || curseForge.Top != website.Top ||
                        website.Left != version.Left || website.Right >= discord.Left || discord.Right >= curseForge.Left ||
                        !help.Parent.ClientRectangle.Contains(website.Bounds) ||
                        !help.Parent.ClientRectangle.Contains(discord.Bounds) ||
                        !help.Parent.ClientRectangle.Contains(curseForge.Bounds) ||
                        help.Bounds.IntersectsWith(website.Bounds) || help.Bounds.IntersectsWith(discord.Bounds) ||
                        help.Bounds.IntersectsWith(curseForge.Bounds))
                        throw new Exception("Header links must fit in one aligned row below the version at " + factor + "x.");
                    if (stack.Right > viewport.ClientSize.Width - viewport.Padding.Right || viewport.HorizontalScroll.Visible || form.HorizontalScroll.Visible)
                        throw new Exception("Dashboard needs horizontal scrolling at " + factor + "x: stack=" + stack.Bounds + ", viewport=" + viewport.ClientSize);
                    var statusRows = status.Controls.OfType<Label>().Where(label => label != summary).OrderBy(label => label.Top).ToArray();
                    for (int i = 1; i < statusRows.Length; i++)
                        if (statusRows[i].Left != statusRows[0].Left ||
                            statusRows[i].Top < statusRows[i - 1].Bottom ||
                            !status.ClientRectangle.Contains(statusRows[i].Bounds))
                            throw new Exception("System Status rows overlap or escape the card at " + factor + "x.");
                    if (factor == 1f && workArea.Height >= 1400)
                    {
                        bool overflow = stack.Bottom > viewport.ClientSize.Height - viewport.Padding.Bottom;
                        bool atNativeLimit = form.Height >= SystemInformation.MaxWindowTrackSize.Height;
                        if (overflow ? !atNativeLimit || !viewport.VerticalScroll.Visible : viewport.VerticalScroll.Visible)
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
                    panel.Controls.OfType<Label>().Any(label => label.Text == "DISPLAY DIAGNOSTICS")) })
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
                    CheckActionGuidance(form);
                    Panel viewport = form.Controls.OfType<Panel>().Single(panel => panel.AutoScroll);
                    var stack = viewport.Controls.OfType<TableLayoutPanel>().Single();
                    foreach (Control section in stack.Controls)
                        if (Math.Abs(section.Width - stack.ClientSize.Width) > 2)
                            throw new Exception("Section does not use the available dashboard width");
                    if (viewport.HorizontalScroll.Visible || form.HorizontalScroll.Visible)
                        throw new Exception("Resizing introduced a horizontal scrollbar");
                }
                CheckWorkspaceLayoutCaption(form, config, custom, factor);
            }
        }

        private static void CheckActionGuidance(CompanionForm form)
        {
            foreach (var pair in new[] { new[] { "Span WoW Now", "Span guidance" }, new[] { "Restore Window", "Restore guidance" } })
            {
                var button = One<Button>(form, item => item.Text == pair[0]);
                var hint = One<Label>(form, item => item.AccessibleName == pair[1]);
                Rectangle buttonBounds = BoundsInside(button, hint.Parent);
                if (Math.Abs(buttonBounds.Left - hint.Left) > 1 || Math.Abs(buttonBounds.Width - hint.Width) > 1 || hint.Top <= buttonBounds.Bottom)
                    throw new Exception("Action guidance must align below its own button: " + pair[0]);
                Size measured = TextRenderer.MeasureText(hint.Text, hint.Font, new Size(hint.Width, int.MaxValue),
                    TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix);
                if (measured.Height > hint.Height || hint.Right > hint.Parent.ClientSize.Width)
                    throw new Exception("Action guidance is clipped: " + pair[0]);
            }
        }

        private static void CheckWorkspaceLayoutCaption(CompanionForm form, Panel config, Button workspaceLayout, float factor)
        {
            const System.Reflection.BindingFlags privateMembers = System.Reflection.BindingFlags.NonPublic;
            var settingsField = typeof(CompanionForm).GetField("appSettings", privateMembers | System.Reflection.BindingFlags.Static);
            var refresh = typeof(CompanionForm).GetMethod("UpdatePartialControls", privateMembers | System.Reflection.BindingFlags.Instance);
            var original = settingsField.GetValue(null);
            var settings = new Dictionary<string, string>();
            try
            {
                settingsField.SetValue(null, settings);
                form.ClientSize = new Size((int)(500 * factor), form.ClientSize.Height);
                LayoutAll(form);
                var table = (TableLayoutPanel)workspaceLayout.Parent;
                int standardHeight = config.Height;
                foreach (bool custom in new[] { false, true, false })
                {
                    settings["WorkspaceRegionsEnabled"] = custom.ToString();
                    refresh.Invoke(form, null);
                    LayoutAll(form);
                    string caption = custom ? "Workspace layout (custom)…" : "Workspace layout (standard)…";
                    var textSize = TextRenderer.MeasureText(caption, workspaceLayout.Font);
                    if (workspaceLayout.Text != caption || workspaceLayout.AccessibleName != caption ||
                        textSize.Width + workspaceLayout.Padding.Horizontal + 8 > workspaceLayout.Width ||
                        textSize.Height + workspaceLayout.Padding.Vertical > workspaceLayout.Height ||
                        table.RowCount != 3 || config.Height != standardHeight)
                        throw new Exception("The workspace layout caption is wrong or does not fit the compact card at " + factor + "x.");
                }
            }
            finally { settingsField.SetValue(null, original); }
        }

        private static void CheckHelpLayout(CompanionForm form, float factor)
        {
            foreach (bool troubleshooting in new[] { false, true })
            {
                using (var dialog = form.CreateHelpDialog(troubleshooting))
                {
                    dialog.CreateControl();
                    dialog.Scale(new SizeF(factor, factor));
                    dialog.Size = dialog.MinimumSize;
                    LayoutAll(dialog);
                    var guide = One<RichTextBox>(dialog, control => true);
                    var close = One<Button>(dialog, button => button.Text == "Close");
                    var heading = One<Label>(dialog, label => true);
                    Rectangle bounds = BoundsInside(guide, dialog);
                    if (!guide.ReadOnly || bounds.Top <= heading.Bottom || bounds.Bottom >= BoundsInside(close, dialog).Top ||
                        dialog.AcceptButton != close || dialog.CancelButton != close)
                        throw new Exception("Help text must scroll between its title and the pinned Close button.");
                    string section = troubleshooting ? "Color and HDR" : "First-time setup: use Companion only";
                    if (!guide.Text.StartsWith(section))
                        throw new Exception("Help must start with the relevant section.");
                    guide.Select(0, section.Length);
                    if (!guide.SelectionFont.Bold || guide.SelectionColor.ToArgb() == guide.ForeColor.ToArgb())
                        throw new Exception("Help section headings must stand out from the steps.");
                    guide.Select(section.Length + 1, 1);
                    if (guide.SelectionFont.Bold || guide.SelectionColor.ToArgb() != guide.ForeColor.ToArgb())
                        throw new Exception("Help body text must use the regular guide style.");
                    if (!troubleshooting)
                    {
                        string[] orderedSections = { "First-time setup:", "Calibration: finish", "After calibration:", "Optional: custom", "Recovery: choose", "Updates and support" };
                        int previous = -1;
                        foreach (string expected in orderedSections)
                        {
                            int position = guide.Text.IndexOf(expected, StringComparison.Ordinal);
                            if (position <= previous) throw new Exception("Help section missing or out of sequence: " + expected);
                            previous = position;
                        }
                        if (!guide.Text.Contains("Span WoW Now at the top") || !guide.Text.Contains("Reload UI, Confirm placement, then Start Calibration") ||
                            !guide.Text.Contains("Load selected, then Save changes") || !guide.Text.Contains("Installed files do not confirm"))
                            throw new Exception("Help must match dashboard controls, calibration handoff and staged profile saving.");
                    }
                    foreach (Control button in Descendants(dialog).OfType<Button>())
                        if (!button.Parent.ClientRectangle.Contains(button.Bounds))
                            throw new Exception("Help footer button is clipped at " + factor + "x.");
                }
            }
        }

        private static void CheckHostWorkingArea()
        {
            using (var form = new CompanionForm())
            {
                form.CreateControl();
                Rectangle host = Screen.PrimaryScreen.WorkingArea;
                form.FitDashboardToWorkingArea(host);
                LayoutAll(form);
                if (!host.Contains(form.Bounds))
                    throw new Exception("Native dashboard escaped the actual host work area: " + form.Bounds + ", host=" + host);
                var viewport = form.Controls.OfType<Panel>().Single(panel => panel.AutoScroll);
                var stack = viewport.Controls.OfType<TableLayoutPanel>().Single();
                var footer = form.Controls.OfType<TableLayoutPanel>().Single();
                if (viewport.Bottom > footer.Top || footer.Bottom > form.ClientSize.Height)
                    throw new Exception("Actual-host scrolling overlaps the native footer.");
                foreach (Control button in footer.Controls)
                    if (!footer.ClientRectangle.Contains(button.Bounds))
                        throw new Exception("Actual-host footer action is clipped: " + button.Text);
                if (stack.Bottom > viewport.ClientSize.Height - viewport.Padding.Bottom && !viewport.VerticalScroll.Visible)
                    throw new Exception("Actual-host overflow has no scrollbar.");
            }
        }

        [STAThread]
        internal static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            // Never inherit or write the owner's real dashboard preferences.
            string isolated = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "Offhand-layout-" + Guid.NewGuid().ToString("N") + ".ini");
            foreach (string field in new[] { "configPath", "publicConfigPath" })
                typeof(CompanionForm).GetField(field, System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static)
                    .SetValue(null, isolated);
            AppDomain.CurrentDomain.ProcessExit += (sender, args) => { if (System.IO.File.Exists(isolated)) System.IO.File.Delete(isolated); };
            CheckHostWorkingArea();
            CheckScale(1f);
            CheckScale(1.25f);
            CheckScale(1.5f);
            CheckScale(1.75f);
            CheckScale(2.0f);
            CheckScale(1.75f, true);
            foreach (float factor in new float[] { 1f, 1.25f, 1.5f, 2f })
            foreach (string mode in new string[] { "standard", "single", "secondary" })
            foreach (bool smallHost in new[] { false, true })
            using (var choice = new CustomRegionModeDialog(new Dictionary<string,string> {
                {"PartialSpanEnabled", mode == "single" ? "True" : "False"},
                {"SecondaryAreaEnabled", mode == "secondary" ? "true" : "False"}
            })) {
                choice.CreateControl(); choice.Scale(new SizeF(factor, factor));
                // Reproduce the hosted Windows runner's window-track limit on
                // larger developer desktops too, including scroll-to-last-row.
                if (smallHost) choice.Size = new Size(Math.Min(1044, choice.Width), Math.Min(788, choice.Height));
                LayoutAll(choice);
                if (choice.AcceptButton != (mode == "standard" ? choice.StandardButton : mode == "secondary" ? choice.SecondaryButton : choice.SingleButton))
                    throw new Exception("Layout chooser does not default to the saved custom mode.");
                if (choice.ActiveControl != choice.AcceptButton)
                    throw new Exception("Layout chooser focuses a different mode than its default Enter action.");
                if (!choice.StandardButton.Enabled || choice.EnableCustom.Checked != (mode != "standard") ||
                    choice.SecondaryButton.Enabled != (mode != "standard"))
                    throw new Exception("Standard must always be available; fresh custom choices must require opt-in.");
                if (BoundsInside(choice.StandardButton, choice).Top >= BoundsInside(choice.SingleButton, choice).Top)
                    throw new Exception("Standard layout must precede custom editor choices.");
                foreach (Control c in Descendants(choice).Where(c => c is Button || c is Label)) {
                    Rectangle bounds = BoundsInside(c, choice);
                    bool reachableByScroll = false;
                    for (Control ancestor = c.Parent; ancestor != choice; ancestor = ancestor.Parent)
                    {
                        var scroll = ancestor as ScrollableControl;
                        if (scroll != null && scroll.AutoScroll && scroll.VerticalScroll.Visible)
                        {
                            scroll.ScrollControlIntoView(c);
                            LayoutAll(scroll);
                            reachableByScroll = scroll.ClientRectangle.Contains(BoundsInside(c, scroll));
                            scroll.AutoScrollPosition = Point.Empty;
                            LayoutAll(scroll);
                        }
                    }
                    if (bounds.Left < 0 || bounds.Top < 0 || bounds.Right > choice.ClientSize.Width ||
                        (bounds.Bottom > choice.ClientSize.Height && !reachableByScroll))
                        throw new Exception("Layout chooser clipped at " + factor + "x: " + c.Text
                            + ", bounds=" + bounds + ", client=" + choice.ClientSize
                            + ", scroll=" + reachableByScroll + ", parent=" + c.Parent.Bounds);
                }
                string preview = Environment.GetEnvironmentVariable("OFFHAND_LAYOUT_PREVIEW");
                if (factor == 1f && mode == "secondary" && !string.IsNullOrEmpty(preview))
                    using (var bitmap = new Bitmap(choice.ClientSize.Width, choice.ClientSize.Height)) {
                        using (var graphics = Graphics.FromImage(bitmap)) graphics.Clear(choice.BackColor);
                        RenderChildren(choice, bitmap, Point.Empty);
                        bitmap.Save(preview + ".mode.png", System.Drawing.Imaging.ImageFormat.Png);
                    }
                // Exercise both explicit choices, including a change from the saved mode.
                bool secondary = mode != "secondary";
                choice.EnableCustom.Checked = true;
                typeof(Button).GetMethod("OnClick", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)
                    .Invoke(secondary ? choice.SecondaryButton : choice.SingleButton, new object[] { EventArgs.Empty });
                if (choice.DialogResult != DialogResult.OK || choice.Secondary != secondary)
                    throw new Exception("Layout chooser returned the wrong editor selection.");
            }
            foreach (float factor in new float[] { 1f, 1.25f, 1.5f, 2f })
            using (var dialog = new PartialSpanDialog(new List<MonitorSelection.Display> {
                new MonitorSelection.Display {Index=0, DeviceName="fixture", StableId="fixture", Bounds=new Rectangle(0,0,5120,1440)}
            }, new Dictionary<string,string>()))
            {
                dialog.CreateControl(); dialog.Scale(new SizeF(factor, factor)); LayoutAll(dialog);
                var scroll = dialog.Controls.OfType<Panel>().Single(p => p.AutoScroll);
                foreach (Control c in new Control[] {dialog.DisplaySelector, dialog.OccupiedWidth, dialog.WorkspaceWidth,
                    Descendants(dialog).OfType<Button>().Single(b => b.Text == "Select area on monitor...")}) {
                    Rectangle b = BoundsInside(c, scroll);
                    if (b.Left < 0 || b.Right > scroll.ClientSize.Width)
                        throw new Exception("Custom region control clipped at " + factor + "x: " + b);
                }
                if (dialog.Settings != null) throw new Exception("Opening editor must not commit settings.");
                string preview = Environment.GetEnvironmentVariable("OFFHAND_LAYOUT_PREVIEW");
                if (factor == 1f && !string.IsNullOrEmpty(preview))
                    using (var bitmap = new Bitmap(dialog.ClientSize.Width, dialog.ClientSize.Height)) {
                        using (var graphics = Graphics.FromImage(bitmap)) graphics.Clear(dialog.BackColor);
                        RenderChildren(dialog, bitmap, Point.Empty);
                        bitmap.Save(preview + ".custom.png", System.Drawing.Imaging.ImageFormat.Png);
                    }
            }
            foreach (Keys finish in new Keys[] { Keys.Enter, Keys.Escape })
            using (var overlay = new PartialRegionOverlay(new Rectangle(-2560,0,2560,1440),
                new PartialRegionSelection(2560,1920,640,false,false))) {
                var keyHandler = typeof(PartialRegionOverlay).GetMethod("ProcessCmdKey",
                    System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic);
                var message = new Message();
                keyHandler.Invoke(overlay, new object[] {message, Keys.Right});
                if (!overlay.Selection.OccupiedRight) throw new Exception("Overlay Right key did not select right monitor edge.");
                keyHandler.Invoke(overlay, new object[] {message, Keys.Left});
                if (overlay.Selection.OccupiedRight) throw new Exception("Overlay Left key did not select left monitor edge.");
                keyHandler.Invoke(overlay, new object[] {message, finish});
                if (overlay.DialogResult != (finish == Keys.Enter ? DialogResult.OK : DialogResult.Cancel))
                    throw new Exception("Overlay keyboard completion depends on focused button.");
            }
            foreach(float factor in new float[] {1f,1.25f,1.5f,2f})
            using(var dialog=new SecondaryAreaDialog(new List<MonitorSelection.Display> {
                new MonitorSelection.Display {Index=0,StableId="game",DeviceName="game",Bounds=new Rectangle(0,0,2560,1440)},
                new MonitorSelection.Display {Index=1,StableId="work",DeviceName="work",Bounds=new Rectangle(-1440,-1114,1440,2560)}
            },new Dictionary<string,string>())) {
                dialog.CreateControl();dialog.Scale(new SizeF(factor,factor));LayoutAll(dialog);
                var scroll=dialog.Controls.OfType<Panel>().Single(p=>p.AutoScroll);
                foreach(Control c in Descendants(dialog).Where(c=>c is NumericUpDown || c is ComboBox || c is CheckBox || (c is Button && c.Text.StartsWith("Select workspace")))) {
                    Rectangle b=BoundsInside(c,scroll);
                    if(b.Left<0||b.Right>scroll.ClientSize.Width)throw new Exception("Secondary area editor clipped at "+factor+"x: "+c.Text);
                }
                if(dialog.Settings!=null)throw new Exception("Opening secondary editor committed settings.");
                string preview=Environment.GetEnvironmentVariable("OFFHAND_LAYOUT_PREVIEW");
                if(factor==1f&&!string.IsNullOrEmpty(preview))using(var bitmap=new Bitmap(dialog.ClientSize.Width,dialog.ClientSize.Height)) {
                    using(var graphics=Graphics.FromImage(bitmap))graphics.Clear(dialog.BackColor);
                    RenderChildren(dialog,bitmap,Point.Empty);bitmap.Save(preview+".secondary.png",System.Drawing.Imaging.ImageFormat.Png);
                }
            }
            foreach(Keys finish in new Keys[] {Keys.Enter,Keys.Escape})
            using(var overlay=new WorkspaceAreaOverlay(new Rectangle(-1440,-1114,1440,2560),
                new WorkspaceAreaSelection(new Size(1440,2560),new Rectangle(100,200,640,1440)))) {
                var handler=typeof(WorkspaceAreaOverlay).GetMethod("ProcessCmdKey",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic);
                handler.Invoke(overlay,new object[] {new Message(),Keys.Right});handler.Invoke(overlay,new object[] {new Message(),Keys.Down});
                if(overlay.Selection.Area.Location!=new Point(110,210))throw new Exception("Secondary overlay arrow movement failed.");
                handler.Invoke(overlay,new object[] {new Message(),finish});
                if(overlay.DialogResult!=(finish==Keys.Enter?DialogResult.OK:DialogResult.Cancel))throw new Exception("Secondary overlay keyboard completion failed.");
            }
            Console.WriteLine("PASS: dashboard alignment, status and working-area fit at 100%, 125%, 150%, 175%, and 200% scaling");
        }
    }
}
