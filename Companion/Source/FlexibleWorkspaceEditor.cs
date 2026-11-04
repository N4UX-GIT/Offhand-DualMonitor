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
        private readonly Label status=new Label{Dock=DockStyle.Fill,AutoSize=true,MaximumSize=new Size(660,0),AccessibleName="Flexible layout status"};
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
            Text="Flexible workspace layout (prototype)";ClientSize=new Size(740,650);
            MinimumSize=new Size(540,420);StartPosition=FormStartPosition.CenterParent;AutoScaleMode=AutoScaleMode.Dpi;
            var scroll=new Panel{Dock=DockStyle.Fill,AutoScroll=true,Padding=new Padding(16)};
            var table=new TableLayoutPanel{Dock=DockStyle.Top,AutoSize=true,ColumnCount=5};
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,32));for(int i=0;i<4;i++)table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,17));
            Action<Control> wide=control=>{table.Controls.Add(control,0,table.RowCount++);table.SetColumnSpan(control,5);};
            wide(new Label{Text="One display can contain the game and one or two separate workspace areas. The prototype uses numeric rectangles and presets. Save changes settings only; Span WoW Now and one manual UI reload apply them.",AutoSize=true,Dock=DockStyle.Fill,Margin=new Padding(0,0,0,12)});
            wide(UseLayout);wide(DisplaySelector);
            var presets=new FlowLayoutPanel{AutoSize=true,Dock=DockStyle.Fill,WrapContents=true};
            foreach(string preset in new[]{"centered","stacked","single"}) {
                string value=preset;var button=new Button{Text=preset=="centered"?"Game between two workspaces":preset=="stacked"?"Two stacked workspaces":"One side workspace",AutoSize=true};
                button.Click+=(s,e)=>LoadPreset(value);presets.Controls.Add(button);
            }
            wide(presets);wide(Second);
            int header=table.RowCount++;
            string[] headings={"Area","X","Y","Width","Height"};
            for(int c=0;c<5;c++)table.Controls.Add(new Label{Text=headings[c],AutoSize=true,Dock=DockStyle.Fill},c,header);
            for(int row=0;row<3;row++) {
                int tableRow=table.RowCount++;string label=row==0?"Game":row==1?"Workspace A":"Workspace B";
                var text=new Label{Text=label,AutoSize=true,Dock=DockStyle.Fill,Padding=new Padding(0,5,0,0)};table.Controls.Add(text,0,tableRow);
                if(row==2)secondControls[0]=text;
                for(int c=0;c<4;c++) {
                    var field=new NumericUpDown{Minimum=0,Maximum=32768,Dock=DockStyle.Fill,AccessibleName=label+" "+headings[c+1],ThousandsSeparator=true};
                    Areas[row,c]=field;table.Controls.Add(field,c+1,tableRow);field.ValueChanged+=(s,e)=>UpdatePreview();
                    if(row==2)secondControls[c+1]=field;
                }
            }
            wide(Diagram);wide(status);scroll.Controls.Add(table);
            var footer=new FlowLayoutPanel{Dock=DockStyle.Bottom,Height=56,FlowDirection=FlowDirection.RightToLeft,Padding=new Padding(8)};
            var cancel=new Button{Text="Cancel",DialogResult=DialogResult.Cancel,AutoSize=true};
            footer.Controls.Add(cancel);footer.Controls.Add(SavePlan);Controls.Add(scroll);Controls.Add(footer);
            CancelButton=cancel;AcceptButton=SavePlan;
            for(int i=0;i<displays.Count;i++)DisplaySelector.Items.Add(string.Format("Display {0}: {1} x {2}{3}",i+1,displays[i].Bounds.Width,displays[i].Bounds.Height,displays[i].Primary?" (Primary)":""));
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
            UseLayout.CheckedChanged+=(s,e)=>UpdatePreview();Second.CheckedChanged+=(s,e)=>UpdatePreview();
            SavePlan.Click+=(s,e)=>{
                try {Settings=Proposed();DialogResult=DialogResult.OK;Close();}
                catch(InvalidOperationException ex){status.Text=ex.Message;status.ForeColor=CompanionUi.Warning;}
            };
            CompanionUi.Apply(this);UpdatePreview();
        }
        protected override void OnShown(EventArgs e)
        {
            var work=Screen.FromControl(this).WorkingArea;Size=new Size(Math.Min(Width,work.Width),Math.Min(Height,work.Height));
            Location=new Point(Math.Max(work.Left,Math.Min(Left,work.Right-Width)),Math.Max(work.Top,Math.Min(Top,work.Bottom-Height)));base.OnShown(e);
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
            if(updating)return;
            SavePlan.Enabled=false;Diagram.Plan=null;Diagram.Displays=displays;
            foreach(var control in secondControls)if(control!=null)control.Visible=Second.Checked;
            try {
                var proposed=Proposed();
                if(!UseLayout.Checked){status.Text="Flexible mode is disabled. Save restores the previous layout settings. Span WoW Now applies them; Restore Window remains available.";SavePlan.Enabled=true;status.ForeColor=CompanionUi.Text;Diagram.Invalidate();return;}
                var plan=MonitorSelection.CreatePlan(proposed,displays);Diagram.Plan=plan;
                status.Text=string.Format("Ready: game {0} x {1}, {2} workspaces. Backing surface {3} x {4}. Save plan does not resize WoW. Apply manually and reload once. This requires the matching schema 3 addon.",plan.MainhandBounds.Width,plan.MainhandBounds.Height,plan.Workspaces.Length,plan.Bounds.Width,plan.Bounds.Height);
                status.ForeColor=CompanionUi.Text;SavePlan.Enabled=true;
            } catch(InvalidOperationException ex){status.Text="Check your layout: "+ex.Message;status.ForeColor=CompanionUi.Warning;}
            Diagram.Invalidate();
        }
    }
}
