using System;
using System.Collections.Generic;
using System.Drawing;
using System.Text.RegularExpressions;
using System.Windows.Forms;

namespace Offhand.Companion
{
    internal static class WorkspaceLayoutPresets
    {
        internal static WorkspaceLayoutDocument SingleDisplay(MonitorSelection.Display display,string preset,string id,string name)
        {
            int width=display.Bounds.Width,height=display.Bounds.Height;
            var document=new WorkspaceLayoutDocument{Id=id,Name=name,PrimaryWorkspaceId="workspace-a"};
            document.Displays.Add(new WorkspaceLayoutBinding{Role="screen",StableId=display.StableId,Resolution=display.Bounds.Size});
            Func<string,Rectangle,WorkspaceLayoutRegion> region=(key,rect)=>new WorkspaceLayoutRegion{Id=key,DisplayRole="screen",Bounds=rect};
            int work=Math.Max(480,width/4);
            if(preset=="stacked") {
                document.Game=region("game",new Rectangle(work,0,width-work,height));
                document.Workspaces.Add(region("workspace-a",new Rectangle(0,0,work,height/2)));
                document.Workspaces.Add(region("workspace-b",new Rectangle(0,height/2,work,height-height/2)));
            } else if(preset=="single") {
                document.Game=region("game",new Rectangle(work,0,width-work,height));
                document.Workspaces.Add(region("workspace-a",new Rectangle(0,0,work,height)));
            } else if(preset=="centered") {
                document.Game=region("game",new Rectangle(work,0,width-2*work,height));
                document.Workspaces.Add(region("workspace-a",new Rectangle(0,0,work,height)));
                document.Workspaces.Add(region("workspace-b",new Rectangle(width-work,0,work,height)));
            } else throw new InvalidOperationException("Unknown flexible layout preset.");
            return document;
        }
    }

    // An explicit opt-in private prototype. Draft edits never resize WoW.
    // The existing native Apply and Restore transaction remains the only path.
    internal sealed class FlexibleWorkspaceEditor : Form
    {
        internal Dictionary<string,string> Settings;
        internal readonly ComboBox DisplaySelector=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Dock=DockStyle.Fill};
        internal readonly CheckBox UseLayout=new CheckBox{Text="Enable flexible layout prototype",AutoSize=true};
        internal readonly CheckBox Second=new CheckBox{Text="Use Workspace B",AutoSize=true};
        internal readonly NumericUpDown[,] Areas=new NumericUpDown[3,4];
        internal readonly Button SavePlan=new Button{Text="Save plan",AutoSize=true};
        internal readonly WorkspacePlanPreview Diagram=new WorkspacePlanPreview{Dock=DockStyle.Top,Height=160};
        private readonly Label status = new Label();
        private readonly Label review;
        private readonly List<Control> areaControls = new List<Control>();
        private readonly List<MonitorSelection.Display> displays;
        private readonly Dictionary<string,string> original;
        private readonly Control[] secondControls=new Control[5];
        private string layoutId,layoutName;
        private string primaryWorkspaceId="workspace-a";
        private readonly string[] regionIds={"game","workspace-a","workspace-b"};
        private bool updating;

        internal FlexibleWorkspaceEditor(List<MonitorSelection.Display> connected,IDictionary<string,string> current)
        {
            if(connected==null||connected.Count==0)throw new InvalidOperationException("No connected display is available.");
            displays=connected;original=new Dictionary<string,string>(current);
            var layout = new WorkspaceEditorLayout(this, WorkspaceEditorLayout.Flexible, new Size(740, 710), new Size(550, 310), 32, 17, 17, 17, 17);
            var table = layout.Table;
            layout.Heading("1. Choose a monitor");
            layout.Guide("Place the game and one or two workspaces on one monitor. " + WorkspaceEditorLayout.FlexibleAddon);
            layout.ExplainReplacement(current, WorkspaceEditorLayout.Flexible);
            layout.AddWide(UseLayout);
            DisplaySelector.AccessibleName = "Monitor";
            DisplaySelector.Margin = new Padding(0, 4, 0, 4);
            layout.AddWide(DisplaySelector);

            int firstAreaRow = table.RowCount;
            layout.Heading("2. Set the areas");
            layout.Guide("Start with a preset or edit the rectangles below. X and Y are pixel offsets from the monitor's top-left corner.");
            var presets = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Fill, WrapContents = true, Margin = new Padding(0, 0, 0, 8) };
            foreach (string preset in new[] { "centered", "stacked", "single" })
            {
                string value = preset;
                var button = new Button { Text = preset == "centered" ? "Game between two workspaces"
                    : preset == "stacked" ? "Two stacked workspaces" : "One side workspace", AutoSize = true };
                button.Click += (s,e) => LoadPreset(value);
                presets.Controls.Add(button);
            }
            layout.AddWide(presets);
            layout.AddWide(Second);

            int header = table.RowCount++;
            string[] headings = { "Area", "X (px)", "Y (px)", "Width (px)", "Height (px)" };
            for (int column = 0; column < headings.Length; column++)
                table.Controls.Add(new Label { Text = headings[column], AutoSize = true, Dock = DockStyle.Fill }, column, header);
            for (int row = 0; row < 3; row++)
            {
                int tableRow = table.RowCount++;
                string label = row == 0 ? "Game" : row == 1 ? "Workspace A" : "Workspace B";
                var area = new Label { Text = label, AutoSize = true, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft };
                table.Controls.Add(area, 0, tableRow);
                if (row == 2) secondControls[0] = area;
                for (int column = 0; column < 4; column++)
                {
                    var field = new NumericUpDown { Minimum = 0, Maximum = 32768, Dock = DockStyle.Fill,
                        AccessibleName = label + " " + headings[column + 1], ThousandsSeparator = true, Margin = new Padding(3, 4, 3, 4) };
                    Areas[row,column] = field;
                    table.Controls.Add(field, column + 1, tableRow);
                    field.ValueChanged += (s,e) => UpdatePreview();
                    if (row == 2) secondControls[column + 1] = field;
                }
            }
            foreach (Control control in table.Controls)
                if (table.GetRow(control) >= firstAreaRow) areaControls.Add(control);
            review = layout.Heading("3. Review the layout");
            layout.AddWide(Diagram);
            for (int i = 0; i < displays.Count; i++)
                DisplaySelector.Items.Add(CompanionUi.DisplayName(displays[i], i));
            layoutId=Guid.NewGuid().ToString("N");layoutName="Flexible layout";
            updating=true;DisplaySelector.SelectedIndex=0;for(int i=0;i<displays.Count;i++)if(displays[i].Primary){DisplaySelector.SelectedIndex=i;break;}
            UseLayout.Checked=WorkspaceLayoutSettings.Enabled(current);updating=false;
            if(UseLayout.Checked) {
                var document=WorkspaceLayoutSettings.Read(current);var resolved=WorkspaceLayoutPlanner.Resolve(document,displays);
                if(resolved.DisplayIndices.Count!=1)throw new InvalidOperationException("This prototype editor supports one physical display. Keep this multi-display document or use Restore Window before changing modes.");
                DisplaySelector.SelectedIndex=resolved.Game.DisplayIndex;layoutId=document.Id;layoutName=document.Name;
                string savedId,savedName;
                if(current.TryGetValue("WorkspaceProfileID",out savedId)&&Regex.IsMatch(savedId,@"\A[a-f0-9]{32}\z")) {
                    layoutId=savedId;
                    if(current.TryGetValue("WorkspaceProfileName",out savedName))layoutName=WorkspacePlanProfiles.Name(savedName);
                }
                LoadDocument(document);
            } else LoadPreset("centered");
            DisplaySelector.SelectedIndexChanged+=(s,e)=>{if(!updating)LoadPreset("centered");};
            UseLayout.CheckedChanged += (s,e) =>
            {
                UpdatePreview();
                layout.FitContent(true);
            };
            Second.CheckedChanged += (s,e) => UpdatePreview();
            SavePlan.Click+=(s,e)=>{
                try {Settings=Proposed();DialogResult=DialogResult.OK;Close();}
                catch (InvalidOperationException ex)
                {
                    WorkspaceEditorLayout.UpdateStatus(SavePlan, status, Diagram, null, WorkspaceEditorLayout.InvalidPlan + ex.Message, false);
                }
            };
            layout.Finish(SavePlan, status, fitHeight: true);
            UpdatePreview();
        }

        private void LoadPreset(string preset)
        {
            if(updating||DisplaySelector.SelectedIndex<0)return;
            var document=WorkspaceLayoutPresets.SingleDisplay(displays[DisplaySelector.SelectedIndex],preset,layoutId,layoutName);
            document.Game.Id=regionIds[0];
            for(int index=0;index<document.Workspaces.Count;index++)document.Workspaces[index].Id=regionIds[index+1];
            document.PrimaryWorkspaceId=document.Workspaces[0].Id;LoadDocument(document);
        }
        private void LoadDocument(WorkspaceLayoutDocument document)
        {
            updating=true;
            try {
                Second.Checked=document.Workspaces.Count==2;
                primaryWorkspaceId=document.PrimaryWorkspaceId;
                var regions=new List<WorkspaceLayoutRegion>{document.Game};regions.AddRange(document.Workspaces);
                for(int row=0;row<regions.Count;row++) {
                    regionIds[row]=regions[row].Id;var rect=regions[row].Bounds;int[] values={rect.X,rect.Y,rect.Width,rect.Height};
                    for(int c=0;c<4;c++)Areas[row,c].Value=Math.Max(0,Math.Min(32768,values[c]));
                }
            } finally {updating=false;}
            UpdatePreview();
        }
        internal Dictionary<string,string> Proposed()
        {
            if(!UseLayout.Checked)return WorkspaceLayoutSettings.Disable(original);
            if(DisplaySelector.SelectedIndex<0)throw new InvalidOperationException("Select a connected display.");
            var display=displays[DisplaySelector.SelectedIndex];
            var document=new WorkspaceLayoutDocument{Id=layoutId,Name=layoutName,PrimaryWorkspaceId=!Second.Checked&&primaryWorkspaceId==regionIds[2]?regionIds[1]:primaryWorkspaceId};
            document.Displays.Add(new WorkspaceLayoutBinding{Role="screen",StableId=display.StableId,Resolution=display.Bounds.Size});
            for(int row=0;row<(Second.Checked?3:2);row++) {
                var region=new WorkspaceLayoutRegion{Id=regionIds[row],DisplayRole="screen",Bounds=new Rectangle((int)Areas[row,0].Value,(int)Areas[row,1].Value,(int)Areas[row,2].Value,(int)Areas[row,3].Value)};
                if(row==0)document.Game=region;else document.Workspaces.Add(region);
            }
            return WorkspaceLayoutSettings.Save(original,document,displays);
        }
        private void UpdatePreview()
        {
            if (updating) return;
            bool enabled = UseLayout.Checked;
            DisplaySelector.Visible = enabled;
            foreach (var control in areaControls) control.Visible = enabled;
            foreach (var control in secondControls) control.Visible = enabled && Second.Checked;
            Diagram.Displays = displays;
            try
            {
                var proposed = Proposed();
                if (!enabled)
                {
                    string text = WorkspaceLayoutSettings.Enabled(original)
                        ? "Flexible layout is off. Saving restores your previous layout settings."
                        : "Check Enable flexible layout prototype to start editing.";
                    WorkspaceEditorLayout.UpdateStatus(SavePlan, status, Diagram, null, text, WorkspaceLayoutSettings.Enabled(original));
                    return;
                }
                var plan = MonitorSelection.CreatePlan(proposed, displays);
                string summary = plan.Workspaces.Length == 1 ? "One workspace is ready." : "Two workspaces are ready.";
                WorkspaceEditorLayout.UpdateStatus(SavePlan, status, Diagram, plan, summary, true);
            }
            catch (InvalidOperationException ex)
            {
                WorkspaceEditorLayout.UpdateStatus(SavePlan, status, Diagram, null, WorkspaceEditorLayout.InvalidPlan + ex.Message, false);
            }
            finally { review.Visible = Diagram.Plan != null; }
        }
    }
}
