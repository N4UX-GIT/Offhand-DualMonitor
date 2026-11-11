using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Windows.Forms;

namespace Offhand.Companion
{
    internal static class WorkspaceUxTest
    {
        private static int checks;
        private static void Check(bool value,string message){checks++;if(!value)throw new Exception(message);}
        private static IEnumerable<Control> All(Control parent){foreach(Control c in parent.Controls){yield return c;foreach(var nested in All(c))yield return nested;}}
        private static void Key(WorkspaceAreaOverlay overlay,Keys key){typeof(WorkspaceAreaOverlay).GetMethod("ProcessCmdKey",BindingFlags.Instance|BindingFlags.NonPublic).Invoke(overlay,new object[]{new Message(),key});}
        private static void Render(Form form, string path)
        {
            Size? loaded = null;
            EventHandler capture = (sender, args) => loaded = form.Size;
            form.Load += capture;
            form.Show();
            Application.DoEvents();
            form.Load -= capture;
            if (loaded.HasValue)
                Check(loaded.Value == form.Size, form.Text + " resized after loading.");
            Check(ReferenceEquals(form.Icon, CompanionUi.AppIcon), form.Text + " does not use the Offhand icon.");
            using (var image = new Bitmap(form.Width, form.Height))
            {
                form.DrawToBitmap(image, new Rectangle(Point.Empty, image.Size));
                image.Save(path);
            }
            form.Hide();
        }
        [STAThread]
        public static int Main(string[] args)
        {
            try{Run(args);return 0;}catch(Exception ex){Console.Error.WriteLine(ex.Message);return 1;}
        }
        private static void Run(string[] args)
        {
            Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
            var displays=new List<MonitorSelection.Display>{
                new MonitorSelection.Display{Index=0,StableId="game",DeviceName="game",Primary=true,Bounds=new Rectangle(0,0,2560,1440)},
                new MonitorSelection.Display{Index=1,StableId="left",DeviceName="left",Bounds=new Rectangle(-1440,-1114,1440,2560)},
                new MonitorSelection.Display{Index=2,StableId="right",DeviceName="right",Bounds=new Rectangle(2560,0,1920,1080)}};
            var settings=new Dictionary<string,string>{{"WorkspaceRegionsEnabled","False"},{"WorkspaceRegionVersion","2"},{"WorkspaceRegionCount","2"},
                {"MainhandIdentity","game"},{"WorkspacePrimary","a"},{"MonitorIdentities","game|left|right"}};
            for(int i=1;i<=2;i++){
                string p="WorkspaceRegion"+i;settings[p+"Id"]=i==1?"a":"b";settings[p+"Identity"]=i==1?"left":"right";
                settings[p+"MonitorWidth"]=i==1?"1440":"1920";settings[p+"MonitorHeight"]=i==1?"2560":"1080";
                settings[p+"X"]="0";settings[p+"Y"]="0";settings[p+"Width"]="640";settings[p+"Height"]="900";
            }
            foreach(float factor in new[]{1f,1.25f,1.5f,2f})using(var editor=new WorkspaceRegionsDialog(displays,settings)){
                editor.CreateControl();editor.Scale(new SizeF(factor,factor));editor.PerformLayout();
                Check(editor.BackColor==CompanionUi.Background,"Editor lost dashboard theme");
                Check(editor.Game.DrawMode==DrawMode.OwnerDrawFixed,"Display selector lost dark rendering");
                Check(editor.Game.Items[0].ToString().StartsWith("Display 1:"),"Editor labels differ from dashboard display numbers");
                Check(editor.Areas[0,2].AccessibleName=="Workspace A Width (px)","Area lacks a distinct accessible name");
                Check(editor.SavePlan.Enabled&&editor.Diagram.Plan!=null,"Valid plan has no actionable preview");
                editor.Monitors[0].SelectedIndex=editor.Game.SelectedIndex;
                Check(!editor.SavePlan.Enabled&&editor.Diagram.Plan==null,"Invalid display overlap is actionable or previewed as valid");
                editor.Monitors[0].SelectedIndex=1;editor.Areas[0,2].Value=0;
                Check(!editor.SavePlan.Enabled,"Zero-width area can be saved");
                editor.Areas[0,2].Value=640;Check(editor.SavePlan.Enabled,"Corrected plan did not become actionable");
                Check(editor.Settings==null&&settings["WorkspaceRegionsEnabled"]=="False","Editor changed original settings before Save");
                Render(editor,Path.Combine(args[0],"workspace-editor-"+(int)(factor*100)+".png"));
                var status=editor.Controls.OfType<Label>().Single(l=>l.AccessibleName=="Plan status");
                Check(status.Bottom<=editor.SavePlan.Parent.Top&&status.Top>=0,"Plan status is hidden behind footer");
                var viewport = editor.Controls.OfType<Panel>().Single(panel => panel.AutoScroll);
                Check(viewport.Bottom <= editor.Diagram.Parent.Top && editor.Diagram.Parent.Bottom <= status.Top,
                    "The preview does not fit between the scroll area and the footer.");
                editor.Monitors[0].SelectedIndex=0;Render(editor,Path.Combine(args[0],"workspace-invalid-"+(int)(factor*100)+".png"));
                Check(status.Text.StartsWith(WorkspaceEditorLayout.InvalidPlan),"Invalid plan gives no visible correction guidance");
                editor.Monitors[0].SelectedIndex=1;
                editor.UseRegions.Checked=false;Check(editor.SavePlan.Enabled,"Disable/recovery path was blocked");
            }
            using(var missing=new WorkspaceRegionsDialog(new List<MonitorSelection.Display>{displays[0]},settings)){
                Check(!missing.SavePlan.Enabled,"Missing workspace monitor remains saveable");
                missing.UseRegions.Checked=false;Check(missing.SavePlan.Enabled,"Cannot disable after monitor loss");
            }
            var oneWorkspace = new Dictionary<string,string>(settings);
            oneWorkspace["WorkspaceRegionCount"] = "1";
            using (var editor = new WorkspaceRegionsDialog(displays.GetRange(0, 2), oneWorkspace))
            {
                Check(editor.SavePlan.Enabled && editor.Diagram.Plan.Workspaces.Length == 1, "The initial two-monitor draft is invalid.");
                editor.Second.Checked = true;
                Check(!editor.SavePlan.Enabled && editor.Diagram.Plan.Workspaces.Length == 1, "Missing third monitor removed the valid preview or enabled Save.");
                var status = editor.Controls.OfType<Label>().Single(label => label.AccessibleName == "Plan status");
                Check(status.Text.Contains("third connected monitor") && status.Text.Contains("Preview shows the game and Workspace A"),
                    "The two-monitor fallback does not explain the missing monitor and partial preview.");
                Render(editor, Path.Combine(args[0], "workspace-b-needs-monitor.png"));
                editor.Second.Checked = false;
                Check(editor.SavePlan.Enabled && editor.Diagram.Plan.Workspaces.Length == 1, "Disabling Workspace B did not restore the valid draft.");
            }
            using (var editor = new WorkspaceRegionsDialog(displays, oneWorkspace))
            {
                editor.Show();
                Application.DoEvents();
                editor.Second.Checked = true;
                Check(editor.SavePlan.Enabled && editor.Diagram.Visible && editor.Diagram.Plan.Workspaces.Length == 2,
                    "Enabling Workspace B on a third monitor did not keep the preview visible.");
                editor.Areas[1, 2].Value = 0;
                Check(!editor.SavePlan.Enabled && editor.Diagram.Visible && editor.Diagram.Plan.Workspaces.Length == 1,
                    "Editing an invalid Workspace B removed the valid preview or enabled Save.");
            }
            using(var profiles=new WorkspaceProfilesDialog(new Dictionary<string,string>(),()=>displays)){
                var buttons=All(profiles).OfType<Button>().ToArray();
                Check(!buttons.Single(b=>b.Text=="Load selected").Enabled,"Empty picker offers Load");
                Check(!buttons.Single(b=>b.Text=="Rename").Enabled,"Empty picker offers Rename");
                Check(!buttons.Single(b=>b.Text=="Delete").Enabled,"Empty picker offers Delete");
                Check(All(profiles).OfType<Label>().Any(l=>l.AccessibleName=="Profile status"
                    && l.Text.Contains("Save as new")),"Empty picker gives no guidance");
            }
            settings["WorkspaceRegionsEnabled"]="True";
            var saved=WorkspacePlanProfiles.Save(settings,"Desk",null,displays);
            using(var profiles=new WorkspaceProfilesDialog(saved,()=>displays)){
                profiles.Show();Application.DoEvents();
                var name=All(profiles).OfType<TextBox>().Single();var add=All(profiles).OfType<Button>().Single(b=>b.Text=="Save as new");
                Check(!add.Enabled,"Duplicate Save as new remains actionable");name.Text="Media desk";Check(add.Enabled,"Valid new name remains disabled");
                add.PerformClick();Check(WorkspacePlanProfiles.Read(profiles.Settings).Items.Count==2,"Profile action did not stage new data");
                Check(WorkspacePlanProfiles.Read(saved).Items.Count==1,"Profile action changed caller data before Save changes");
                Check(All(profiles).OfType<Label>().Any(l=>l.Text.StartsWith("Changes are pending")),"Staged profile change has no feedback");
                Render(profiles,Path.Combine(args[0],"workspace-profiles.png"));
                profiles.Show();Application.DoEvents();((Button)profiles.CancelButton).PerformClick();Check(profiles.DialogResult==DialogResult.Cancel,"Cancel did not discard the editor transaction");
            }
            using(var overlay=new WorkspaceAreaOverlay(new Rectangle(-1440,-1114,1440,2560),new WorkspaceAreaSelection(new Size(1440,2560),new Rectangle(100,200,640,900)))){
                Key(overlay,Keys.Control|Keys.Right);Check(overlay.Selection.Area.X==101,"Fine keyboard movement is not one pixel");
                Key(overlay,Keys.Shift|Keys.Right);Check(overlay.Selection.Area.Width==650&&overlay.Selection.Area.X==101,"Keyboard resize moved the origin");
                Key(overlay,Keys.Control|Keys.Shift|Keys.Down);Check(overlay.Selection.Area.Height==901,"Fine keyboard resize failed");
                Key(overlay,Keys.Escape);Check(overlay.DialogResult==DialogResult.Cancel,"Overlay Escape failed");
            }
            using(var partial=new PartialSpanDialog(new List<MonitorSelection.Display>{new MonitorSelection.Display{Index=0,StableId="wide",DeviceName="wide",Bounds=new Rectangle(0,0,5120,1440)}},new Dictionary<string,string>{{"PartialSpanEnabled","True"}})){
                partial.OccupiedWidth.Value=100;Check(!partial.SavePlan.Enabled,"Invalid single-display dimensions can be saved");
                partial.OccupiedWidth.Value=3000;partial.WorkspaceWidth.Value=800;Check(partial.SavePlan.Enabled,"Valid single-display selection remains disabled");
                Check(All(partial).OfType<WorkspacePlanPreview>().Single().Plan != null, "Single-display editor is missing its preview");
                Render(partial,Path.Combine(args[0],"single-display-editor.png"));
            }
            using (var missing = new PartialSpanDialog(displays, new Dictionary<string,string> {
                { "PartialSpanEnabled", "True" }, { "PartialDisplayIdentity", "unplugged" }
            }))
            {
                Check(!missing.SavePlan.Enabled, "A disconnected single-monitor plan can be saved");
                All(missing).OfType<CheckBox>().Single().Checked = false;
                Check(missing.SavePlan.Enabled, "A disconnected single-monitor plan cannot be turned off");
            }
            using(var secondary=new SecondaryAreaDialog(displays,new Dictionary<string,string>())){
                Check(secondary.SavePlan.Enabled,"Valid secondary editor is disabled");
                var plan=All(secondary).OfType<WorkspacePlanPreview>().Single().Plan;
                Check(plan.WorkspaceBounds==displays[1].Bounds,"New two-monitor custom layout must start with the full Offhand monitor");
                Check(secondary.Settings==null,"Opening the full-monitor default committed a plan");
                Check(All(secondary).OfType<WorkspacePlanPreview>().Single().Plan != null, "Two-monitor editor is missing its preview");
                Render(secondary,Path.Combine(args[0],"two-display-editor.png"));
            }
            using(var secondary=new SecondaryAreaDialog(displays,new Dictionary<string,string> {
                {"SecondaryAreaIdentity",displays[1].StableId},{"SecondaryAreaX","25"},{"SecondaryAreaY","50"},
                {"SecondaryAreaWidth","800"},{"SecondaryAreaHeight","900"}})) {
                var plan=All(secondary).OfType<WorkspacePlanPreview>().Single().Plan;
                Check(plan.WorkspaceBounds==new Rectangle(displays[1].Bounds.Left+25,displays[1].Bounds.Top+50,800,900),
                    "Saved partial Offhand layout was replaced by the safer first-use default");
            }
            using (var flexible = new FlexibleWorkspaceEditor(displays, new Dictionary<string,string>()))
            {
                Check(!flexible.SavePlan.Enabled && flexible.Diagram.Plan == null, "An unused flexible layout can be saved while off");
                Render(flexible, Path.Combine(args[0], "flexible-off.png"));
                int compactHeight = flexible.Height;
                flexible.Show();
                Application.DoEvents();
                Check(!flexible.DisplaySelector.Visible && !flexible.Diagram.Visible, "The off state shows an inactive editor");
                flexible.UseLayout.Checked = true;
                Check(flexible.SavePlan.Enabled && flexible.Diagram.Visible && flexible.Height > compactHeight,
                    "Enabling a valid flexible draft did not expand the editor and show its preview");
                Render(flexible, Path.Combine(args[0], "flexible-editor.png"));
            }
            using(var chooser=new CustomRegionModeDialog(saved)){Render(chooser,Path.Combine(args[0],"layout-chooser.png"));}
            Console.WriteLine("PASS: "+checks+" workspace UX checks: dark fields, DPI, actionable validation, preview, accessible names, staged profiles and keyboard selection");
        }
    }
}
