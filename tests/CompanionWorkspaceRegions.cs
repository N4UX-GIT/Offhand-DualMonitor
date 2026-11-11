using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows.Forms;
namespace Offhand.Companion
{
    internal static class WorkspaceRegionsTest
    {
        private static int checks;
        [DllImport("gdi32.dll")] private static extern bool PtInRegion(IntPtr r,int x,int y);
        private static void Check(bool value,string message){checks++;if(!value)throw new Exception(message);}
        private static void Reject(IDictionary<string,string> settings,List<MonitorSelection.Display> displays)
        {bool rejected=false;try{MonitorSelection.CreatePlan(settings,displays);}catch(InvalidOperationException){rejected=true;}Check(rejected,"Invalid multi-region plan accepted");}
        private static Dictionary<string,string> Settings()
        {
            var s=new Dictionary<string,string>{{"WorkspaceRegionsEnabled","True"},{"WorkspaceRegionVersion","2"},
                {"WorkspaceRegionCount","2"},{"WorkspacePrimary","left"},{"MainhandIdentity","game"},
                {"MonitorIdentities","game|left|right"}};
            foreach(var name in new[]{"left","right"}) {
                string p="WorkspaceRegion"+(name=="left"?"1":"2");
                s[p+"Id"]=name;s[p+"Identity"]=name;s[p+"X"]="0";s[p+"Y"]="0";
                s[p+"Width"]=name=="left"?"1440":"1920";s[p+"Height"]=name=="left"?"1440":"1080";
                s[p+"MonitorWidth"]=s[p+"Width"];s[p+"MonitorHeight"]=s[p+"Height"];
            }
            return s;
        }
        private static void CheckLayout(WorkspaceRegionsDialog editor,float scale)
        {
            editor.ClientSize=new Size((int)(500*scale),(int)(420*scale));editor.PerformLayout();
            var scroll=editor.Controls.OfType<Panel>().Single(control=>control.AutoScroll);
            var table=scroll.Controls.OfType<TableLayoutPanel>().Single();table.PerformLayout();
            Check(!scroll.HorizontalScroll.Visible,"Editor requires horizontal scrolling at "+scale);
            foreach(Control control in table.Controls) {
                Check(control.Left>=0&&control.Right<=table.ClientSize.Width,"Editor field escapes content width at "+scale+": "+control.Text);
                var label=control as Label;
                if(label!=null){var measured=TextRenderer.MeasureText(label.Text,label.Font,new Size(label.ClientSize.Width,int.MaxValue),TextFormatFlags.WordBreak|TextFormatFlags.NoPrefix);
                    Check(measured.Height<=label.Height,"Editor label clips at "+scale+": "+label.Text);}
            }
            var buttons=editor.Controls.OfType<FlowLayoutPanel>().Single();
            Check(buttons.Top>=0&&buttons.Bottom<=editor.ClientSize.Height,"Editor actions leave short window at "+scale);
            foreach(Control button in buttons.Controls)Check(button.Bounds.Left>=0&&button.Right<=buttons.ClientSize.Width&&button.Top>=0&&button.Bottom<=buttons.ClientSize.Height,"Editor action clips at "+scale);
            var work=new Rectangle(-100,20,(int)(700*scale),(int)(480*scale));
            editor.Location=new Point(-200,0);editor.FitToWorkingArea(work);
            Check(work.Contains(editor.Bounds),"Editor extends beyond available desktop at "+scale);
        }
        [STAThread]
        public static void Main(string[] args)
        {
            Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
            var displays=new List<MonitorSelection.Display>{
                new MonitorSelection.Display{StableId="game",DeviceName="game",Bounds=new Rectangle(0,0,2560,1440),Primary=true},
                new MonitorSelection.Display{StableId="left",DeviceName="left",Bounds=new Rectangle(-1440,0,1440,1440)},
                new MonitorSelection.Display{StableId="right",DeviceName="right",Bounds=new Rectangle(2560,0,1920,1080)}};
            var settings=Settings();var plan=MonitorSelection.CreatePlan(settings,displays);
            Check(DisplayScaling.Summary(new List<DisplayScaling.State>{DisplayScaling.FromResult(0,100),DisplayScaling.FromResult(0,100),DisplayScaling.FromResult(0,125)}).StartsWith("Different"),"Third monitor scale difference omitted");
            Check(DisplayScaling.Summary(new List<DisplayScaling.State>{DisplayScaling.FromResult(0,100),DisplayScaling.FromResult(0,100),DisplayScaling.FromResult(1,100)}).Contains("unavailable"),"Unavailable third monitor scale treated as observed");
            Check(plan.MultiRegion&&plan.IsCustom&&plan.Indices.Length==3,"Three-display plan lost regions");
            Check(plan.Bounds==new Rectangle(-1440,0,5920,1440),"Wrong backing bounds");
            Check(plan.Workspaces.Length==2&&plan.WorkspaceBounds==displays[1].Bounds,"Primary alias differs");
            IntPtr clip=SpanClipRegion.Create(plan,plan.Bounds);
            try {
                Check(PtInRegion(clip,100,100)&&PtInRegion(clip,2000,100)&&PtInRegion(clip,5000,100),"Visible region clipped");
                Check(!PtInRegion(clip,5000,1300),"Desktop hole covered");
            }finally{NativeMethods.DeleteObject(clip);}
            var reordered=new List<MonitorSelection.Display>{displays[2],displays[0],displays[1]};
            var again=MonitorSelection.CreatePlan(settings,reordered);
            Check(again.MainhandBounds==plan.MainhandBounds&&again.Bounds==plan.Bounds&&again.WorkspaceBounds==plan.WorkspaceBounds,"Identity reorder changed geometry");
            foreach(var change in new Action<Dictionary<string,string>>[]{
                s=>s["WorkspaceRegion2Id"]="left",s=>s["WorkspaceRegion2Id"]="bad id",s=>s["WorkspacePrimary"]="missing",
                s=>s["WorkspaceRegionCount"]="3",s=>s["WorkspaceRegionVersion"]="3",s=>s["SecondaryAreaEnabled"]="True",
                s=>s["WorkspaceRegion2Identity"]="game",s=>s["WorkspaceRegion2Identity"]="missing",
                s=>s["WorkspaceRegion2MonitorWidth"]="2000",s=>s["WorkspaceRegion2X"]="2147483647",
                s=>s["WorkspaceRegion2Width"]="479",s=>s["WorkspaceRegion2Height"]="599",
                s=>s["WorkspaceRegion2Y"]="-1",s=>s["MonitorIdentities"]="game|left"}) {
                var invalid=Settings();change(invalid);Reject(invalid,displays);
            }
            Reject(settings,new List<MonitorSelection.Display>{displays[0],displays[1]});
            Reject(settings,new List<MonitorSelection.Display>{displays[0],displays[1],displays[2],displays[2]});
            var far=new List<MonitorSelection.Display>{displays[0],displays[1],new MonitorSelection.Display{
                StableId="right",DeviceName="right",Bounds=new Rectangle(20000,0,1920,1080)}};
            Reject(settings,far);
            var overlap=new List<MonitorSelection.Display>{displays[0],displays[1],new MonitorSelection.Display{
                StableId="right",DeviceName="right",Bounds=new Rectangle(-1200,0,1920,1080)}};
            Reject(settings,overlap);
            string addon=Path.Combine(args[0],"Interface","AddOns","Offhand"),core=Path.Combine(addon,"Core");
            Directory.CreateDirectory(core);string target=Path.Combine(core,"CompanionTopology.lua");
            File.WriteAllText(target,"unchanged");string message;byte[] written;
            Check(!CompanionTopologyBridge.TryWrite(args[0],plan,displays,out message,out written)&&written==null&&File.ReadAllText(target)=="unchanged","Missing capability modified topology");
            string manifest=Path.Combine(addon,"Offhand.toc");
            string metadata="## X-Offhand-Companion-Protocol: 1\n## X-Offhand-Companion-Min-Version: 2.1.2-beta.19\n";
            File.WriteAllText(manifest,metadata);
            Check(!CompanionTopologyBridge.TryWrite(args[0],plan,displays,out message),"Old addon accepted schema 2");
            File.WriteAllText(manifest,metadata+"## X-Offhand-Topology-Schemas: 1,2\n");
            Check(CompanionTopologyBridge.TryWrite(args[0],plan,displays,out message),"Capable addon rejected schema 2");
            Check(CompanionTopologyBridge.IsCurrent(args[0],plan,displays),"Fresh schema 2 bridge not current");
            File.Copy(target,Path.Combine(args[0],"schema2.lua"));
            settings["WorkspacePrimary"]="right";var changed=MonitorSelection.CreatePlan(settings,displays);
            Check(!CompanionTopologyBridge.IsCurrent(args[0],changed,displays),"Primary change not detected");
            var saved=new Dictionary<string,string>(settings);settings["WorkspaceRegion2Width"]="2000";
            string prefs=Path.Combine(args[0],"prefs.ini");File.WriteAllText(prefs,"keep=original\r\n");bool failed=false;
            try{CustomRegionPreferences.Write(prefs,settings,()=>displays);}catch(InvalidOperationException){failed=true;}
            Check(failed&&File.ReadAllText(prefs)=="keep=original\r\n","Rejected multi-region Save changed preferences");
            CustomRegionPreferences.Write(prefs,saved,()=>displays);
            Check(MonitorSelection.CreatePlan(PreferenceFile.Read(prefs),displays).PrimaryWorkspaceId=="right","Settings round trip lost primary");
            var editorSettings=Settings();editorSettings["WorkspaceRegionsEnabled"]="False";
            foreach(float scale in new[]{1f,1.25f,1.5f,2f})using(var editor=new WorkspaceRegionsDialog(displays,editorSettings)) {
                editor.CreateControl();editor.Scale(new SizeF(scale,scale));editor.PerformLayout();
                var pending=editor.Proposed();var edited=MonitorSelection.CreatePlan(pending,displays);
                Check(edited.Workspaces.Length==2&&edited.Bounds==plan.Bounds,"Editor changed the saved pending geometry");
                CheckLayout(editor,scale);
                if(scale==1&&args.Length>1) {
                    var table=editor.Controls.OfType<Panel>().Single(control=>control.AutoScroll).Controls.OfType<TableLayoutPanel>().Single();
                    using(var bitmap=new Bitmap(table.Width,table.Height)) {
                        table.DrawToBitmap(bitmap,new Rectangle(Point.Empty,bitmap.Size));
                        foreach(Control control in table.Controls)control.DrawToBitmap(bitmap,control.Bounds);
                        bitmap.Save(args[1],System.Drawing.Imaging.ImageFormat.Png);
                    }
                }
                editor.Primary.SelectedIndex=1;
                Check(MonitorSelection.CreatePlan(editor.Proposed(),displays).PrimaryWorkspaceId=="right","Editor lost primary selection");
                editor.Second.Checked=false;
                Check(MonitorSelection.CreatePlan(editor.Proposed(),displays).Workspaces.Length==1,"Editor failed to remove the pending second workspace");
                Check(!editor.Monitors[1].Enabled&&!editor.Areas[1,0].Enabled&&!editor.SelectAreas[1].Enabled&&!editor.Primary.Enabled,"Inactive workspace B controls still offered actions");
                Check(editorSettings["WorkspaceRegionCount"]=="2"&&editorSettings["WorkspaceRegionsEnabled"]=="False","Editor mutated original settings before Save");
                editor.UseRegions.Checked=false;
                Check(!MonitorSelection.MultiEnabled(editor.Proposed())&&MonitorSelection.CreatePlan(editor.Proposed(),displays).Indices.Length==2,"Disabling multi-region mode did not restore a two-display plan");
                Check(!editor.Areas[0,0].Enabled&&!editor.SelectAreas[0].Enabled&&!editor.Second.Enabled,"Disabled region mode still offered area-edit actions");
            }
            using(var missing=new WorkspaceRegionsDialog(new List<MonitorSelection.Display>{displays[0],displays[1]},Settings())) {
                Check(missing.Monitors[1].SelectedIndex==-1,"Missing saved monitor silently substituted another display");
                bool missingRejected=false;try{missing.Proposed();}catch(InvalidOperationException){missingRejected=true;}
                Check(missingRejected&&missing.Second.Checked,"Missing second workspace silently collapsed the plan");
                missing.UseRegions.Checked=false;
                var disabled=missing.Proposed();
                Check(!MonitorSelection.MultiEnabled(disabled),"Missing monitor prevented disabling custom mode");
                Check(disabled["WorkspaceRegionCount"]=="2"&&disabled["WorkspaceRegion2Identity"]=="right","Disabling custom mode discarded saved workspace B");
                Check(disabled["WorkspaceRegion2Width"]=="1920"&&Settings()["WorkspaceRegionsEnabled"]=="True","Disable discarded the saved area or mutated the input");
                Check(MonitorSelection.CreatePlan(disabled,new List<MonitorSelection.Display>{displays[0],displays[1]}).Indices.Length==2,"Disabling custom mode failed to select the connected ordinary pair");
                CustomRegionPreferences.Write(prefs,disabled,()=>new List<MonitorSelection.Display>{displays[0]});
                Check(!MonitorSelection.MultiEnabled(PreferenceFile.Read(prefs)),"Display loss during disable prevented publishing the disabled state");
                missing.UseRegions.Checked=true;
                bool reenableRejected=false;try{missing.Proposed();}catch(InvalidOperationException){reenableRejected=true;}
                Check(reenableRejected&&missing.Second.Checked&&missing.Monitors[1].SelectedIndex==-1,"Re-enabling a missing region substituted or discarded its monitor");
            }
            using(var missingAll=new WorkspaceRegionsDialog(new List<MonitorSelection.Display>(),Settings())) {
                missingAll.UseRegions.Checked=false;
                var disabled=missingAll.Proposed();
                Check(!MonitorSelection.MultiEnabled(disabled)&&disabled["MonitorIdentities"]=="game|left|right","Disabling without connected displays changed saved identities");
            }
            using(var chooser=new CustomRegionModeDialog(Settings()))Check(chooser.AcceptButton==chooser.MultipleButton,"Layout chooser did not retain multi-region mode");
            var small=new List<MonitorSelection.Display>{
                new MonitorSelection.Display{StableId="game",DeviceName="game",Bounds=new Rectangle(0,0,960,600)},
                new MonitorSelection.Display{StableId="left",DeviceName="left",Bounds=new Rectangle(-480,0,480,600)},
                new MonitorSelection.Display{StableId="right",DeviceName="right",Bounds=new Rectangle(960,-100,480,600)}};
            var smallSettings=Settings();
            for(int n=1;n<=2;n++){string p="WorkspaceRegion"+n;smallSettings[p+"Width"]="480";smallSettings[p+"Height"]="600";smallSettings[p+"MonitorWidth"]="480";smallSettings[p+"MonitorHeight"]="600";}
            var smallPlan=MonitorSelection.CreatePlan(smallSettings,small);
            for(int stage=0;stage<4;stage++)using(var window=new Form()) {
                window.ShowInTaskbar=false;window.StartPosition=FormStartPosition.Manual;window.Bounds=new Rectangle(40,50,420,350);
                IntPtr handle=window.Handle;NativeMethods.RECT prior;Check(NativeMethods.GetWindowRect(handle,out prior),"Capture native baseline");
                int style=NativeMethods.GetWindowLong(handle,NativeMethods.GWL_STYLE);byte[] before=new byte[]{1,9,2,8};File.WriteAllBytes(target,before);
                using(var rollback=new SpanRollback(target,handle)) {
                    Check(CompanionTopologyBridge.TryWrite(args[0],smallPlan,small,out message,out written),"Native multi-region bridge write");rollback.TopologyWritten(written);
                    if(stage>0){rollback.WindowChanged=true;NativeMethods.SetWindowLong(handle,NativeMethods.GWL_STYLE,style&~(NativeMethods.WS_CAPTION|NativeMethods.WS_THICKFRAME));}
                    if(stage>1){IntPtr region=SpanClipRegion.Create(smallPlan,smallPlan.Bounds);if(NativeMethods.SetWindowRgn(handle,region,false)==0){NativeMethods.DeleteObject(region);throw new Exception("Install multi-region clip failed");}}
                    if(stage>2)Check(NativeMethods.SetWindowPos(handle,IntPtr.Zero,smallPlan.Bounds.X,smallPlan.Bounds.Y,smallPlan.Bounds.Width,smallPlan.Bounds.Height,NativeMethods.SWP_NOZORDER|NativeMethods.SWP_NOACTIVATE|NativeMethods.SWP_FRAMECHANGED),"Resize native multi-region fixture");
                    Check(rollback.Rollback()==null,"Multi-region native rollback failed");
                    Check(rollback.Rollback()==null,"Repeated multi-region rollback failed");
                }
                NativeMethods.RECT after;Check(NativeMethods.GetWindowRect(handle,out after)&&after.Left==prior.Left&&after.Top==prior.Top&&after.Width==prior.Width&&after.Height==prior.Height,"Multi-region rollback bounds differ");
                Check(NativeMethods.GetWindowLong(handle,NativeMethods.GWL_STYLE)==style,"Multi-region rollback style differs");
                IntPtr read=NativeMethods.CreateRectRgn(0,0,0,0);try{Check(NativeMethods.GetWindowRgn(handle,read)==0,"Multi-region rollback left clipping");}finally{NativeMethods.DeleteObject(read);}
                Check(SpanRollback.SameBytes(before,File.ReadAllBytes(target)),"Multi-region rollback topology differs");
            }
            Console.WriteLine("PASS: "+checks+" multi-region planner, native clip, version-skew, bridge and persistence checks");
        }
    }
}
