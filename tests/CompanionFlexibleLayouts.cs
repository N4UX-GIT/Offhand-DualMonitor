using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace Offhand.Companion
{
    internal static class FlexibleLayoutsTest
    {
        private static int checks;
        private static void Check(bool value,string reason){checks++;if(!value)throw new Exception(reason);}
        private static bool Equal(IDictionary<string,string> a,IDictionary<string,string> b)
        {return a.Count==b.Count&&a.All(pair=>b.ContainsKey(pair.Key)&&b[pair.Key]==pair.Value);}
        private static List<MonitorSelection.Display> Displays()
        {return new List<MonitorSelection.Display>{new MonitorSelection.Display{StableId="ultra",DeviceName="ultra-device",Bounds=new Rectangle(0,0,5120,1440),Primary=true},
            new MonitorSelection.Display{StableId="left",DeviceName="left-device",Bounds=new Rectangle(-1440,0,1440,2560)}};}
        private static Dictionary<string,string> Legacy()
        {return new Dictionary<string,string>{{"DisplayIdentityVersion","1"},{"MainhandIdentity","ultra"},{"MonitorIdentities","ultra|left"},
            {"WorkspaceRegionsEnabled","True"},{"WorkspaceRegionVersion","2"},{"WorkspaceRegionCount","1"},{"WorkspacePrimary","workspace-a"},
            {"WorkspaceRegion1Id","workspace-a"},{"WorkspaceRegion1Identity","left"},{"WorkspaceRegion1X","0"},{"WorkspaceRegion1Y","0"},
            {"WorkspaceRegion1Width","1440"},{"WorkspaceRegion1Height","1440"},{"WorkspaceRegion1MonitorWidth","1440"},{"WorkspaceRegion1MonitorHeight","2560"},
            {"AutoSpan","True"},{"launcher-note","preserve"}};}
        private static void Reject(Action action,string reason)
        {bool rejected=false;try{action();}catch(InvalidOperationException){rejected=true;}Check(rejected,reason);}
        private static void WriteBridge(string root,string name,Dictionary<string,string> settings,List<MonitorSelection.Display> displays)
        {
            var plan=MonitorSelection.CreatePlan(settings,displays);string message;byte[] written;
            Check(CompanionTopologyBridge.TryWrite(root,plan,displays,out message,out written),message);
            Check(CompanionTopologyBridge.IsCurrent(root,plan,displays),"Generated flexible bridge is not current");
            File.WriteAllBytes(Path.Combine(root,name+".lua"),written);
        }
        [STAThread]
        public static void Main(string[] args)
        {
            string root=args[0];var displays=Displays();var legacy=Legacy();var original=new Dictionary<string,string>(legacy);
            var document=WorkspaceLayoutPresets.SingleDisplay(displays[0],"centered",Guid.NewGuid().ToString("N"),"Centered desk");
            string encoded=WorkspaceLayoutSettings.Encode(document,displays);
            var decoded=WorkspaceLayoutSettings.Decode(encoded);
            Check(decoded.Game.Bounds==document.Game.Bounds&&decoded.Workspaces[1].Id=="workspace-b","Document roundtrip lost geometry or IDs");
            Reject(()=>WorkspaceLayoutSettings.Decode(encoded.Replace("\"version\":1","\"version\":99")),"Future document was accepted");
            Reject(()=>WorkspaceLayoutSettings.Decode(encoded.Replace("\"x\":1280","\"x\":1280.5")),"Fractional persisted pixels accepted");
            Reject(()=>WorkspaceLayoutSettings.Decode(encoded.Replace("\"version\":1","\"version\":1,\"future\":true")),"Unknown document data discarded");
            Reject(()=>WorkspaceLayoutSettings.Decode(new string('x',16385)),"Oversized document accepted");
            var settings=WorkspaceLayoutSettings.Save(legacy,document,displays);
            Check(Equal(legacy,original),"Draft save mutated original preferences");
            Check(settings["AutoSpan"]=="False"&&settings["launcher-note"]=="preserve","Flexible mode changed unrelated settings or enabled auto span");
            var plan=MonitorSelection.CreatePlan(settings,displays);
            Check(plan.TopologySchema==3&&plan.IsCustom&&plan.MultiRegion&&plan.Indices.Length==1,"Flexible plan did not retain a single physical display");
            Check(plan.MainhandBounds==new Rectangle(1280,0,2560,1440)&&plan.Workspaces[1].Bounds.X==3840,"Centered geometry changed during plan adaptation");
            var disabled=WorkspaceLayoutSettings.Disable(settings);
            Check(!WorkspaceLayoutSettings.Enabled(disabled)&&disabled["WorkspaceRegionsEnabled"]=="True","Disable did not restore the prior mode");
            Check(MonitorSelection.CreatePlan(disabled,displays).MainhandBounds==MonitorSelection.CreatePlan(legacy,displays).MainhandBounds,"Fallback changed the original game geometry");
            Check(disabled["AutoSpan"]=="False"&&disabled[WorkspaceLayoutSettings.DocumentKey]==encoded,"Disable lost recoverable document or armed automatic apply");
            var badFallback=new Dictionary<string,string>(settings);badFallback[WorkspaceLayoutSettings.FallbackKey]="{\"unrelated-private-setting\":\"bad\"}";
            Reject(()=>WorkspaceLayoutSettings.Disable(badFallback),"Unknown fallback setting was silently restored");

            // First flexible profile write copies V1 into V2 and leaves V1 bytes intact.
            var savedLegacy=WorkspacePlanProfiles.Save(legacy,"Legacy desk",null,displays);
            string legacyId=savedLegacy["WorkspaceProfileID"],legacyStore=savedLegacy[WorkspacePlanProfiles.Key];
            var flexible=WorkspaceLayoutSettings.Save(savedLegacy,document,displays);
            var saved=WorkspacePlanProfiles.Save(flexible,"Flexible desk",null,displays);string flexibleId=saved["WorkspaceProfileID"];
            Check(saved[WorkspacePlanProfiles.Key]==legacyStore&&saved.ContainsKey(WorkspacePlanProfiles.KeyV2),"V2 migration changed the V1 downgrade copy");
            Check(WorkspacePlanProfiles.Read(saved).Version==2&&WorkspacePlanProfiles.Read(saved).Items.Count==2,"V2 migration lost a saved plan");
            var oldLoaded=WorkspacePlanProfiles.Load(saved,legacyId,displays);
            Check(!WorkspaceLayoutSettings.Enabled(oldLoaded)&&MonitorSelection.CreatePlan(oldLoaded,displays).TopologySchema==2,"Loading migrated legacy profile changed its topology");
            var newLoaded=WorkspacePlanProfiles.Load(oldLoaded,flexibleId,displays);
            Check(WorkspaceLayoutSettings.Enabled(newLoaded)&&newLoaded["AutoSpan"]=="False"&&MonitorSelection.CreatePlan(newLoaded,displays).TopologySchema==3,"Loading flexible profile changed mode or automatic apply");
            Check(newLoaded[WorkspacePlanProfiles.Key]==legacyStore,"Profile switching changed V1 backup bytes");
            var renamed=WorkspacePlanProfiles.Rename(newLoaded,flexibleId,"Renamed flexible");
            Check(renamed["WorkspaceProfileID"]==flexibleId&&renamed[WorkspacePlanProfiles.Key]==legacyStore,"Rename changed profile identity or V1 backup");
            var futureStore=new Dictionary<string,string>(saved);futureStore[WorkspacePlanProfiles.KeyV2]=Convert.ToBase64String(Encoding.UTF8.GetBytes("{\"Version\":99,\"Items\":[]}"));
            string before=futureStore[WorkspacePlanProfiles.KeyV2];
            Reject(()=>WorkspacePlanProfiles.Read(futureStore),"Future V2 store fell back to V1");
            Check(futureStore[WorkspacePlanProfiles.KeyV2]==before,"Future V2 store was overwritten");
            var futureDoc=new Dictionary<string,string>(settings);futureDoc[WorkspaceLayoutSettings.DocumentKey]=encoded.Replace("\"version\":1","\"version\":99");
            Reject(()=>MonitorSelection.CreatePlan(futureDoc,displays),"Future layout fell back to legacy geometry");
            futureDoc[WorkspaceLayoutSettings.EnabledKey]="False";
            Reject(()=>WorkspaceLayoutSettings.Save(futureDoc,document,displays),"Inactive future document was overwritten by a new draft");
            Check(futureDoc[WorkspaceLayoutSettings.DocumentKey].Contains("\"version\":99"),"Future document was modified after refusal");

            string prefs=Path.Combine(root,"prefs.ini");File.WriteAllText(prefs,"keep=original\r\n");
            var resized=Displays();resized[0].Bounds=new Rectangle(0,0,3840,1440);
            Reject(()=>CustomRegionPreferences.Write(prefs,settings,()=>resized),"Save after a resolution change was accepted");
            Check(File.ReadAllText(prefs)=="keep=original\r\n","Rejected Save changed preferences");
            CustomRegionPreferences.Write(prefs,settings,Displays);
            Check(MonitorSelection.CreatePlan(PreferenceFile.Read(prefs),displays).TopologySchema==3,"Preference-file roundtrip lost the document");

            string addon=Path.Combine(root,"Interface","AddOns","Offhand");Directory.CreateDirectory(Path.Combine(addon,"Core"));
            string manifest=Path.Combine(addon,"Offhand.toc"),bridge=Path.Combine(addon,"Core","CompanionTopology.lua");
            string metadata="## X-Offhand-Companion-Protocol: 1\n## X-Offhand-Companion-Min-Version: 2.1.2-beta.19\n";
            File.WriteAllText(manifest,metadata+"## X-Offhand-Topology-Schemas: 1,2\n");File.WriteAllText(bridge,"unchanged");string message;byte[] written;
            Check(!CompanionTopologyBridge.TryWrite(root,plan,displays,out message,out written)&&written==null&&File.ReadAllText(bridge)=="unchanged","Schema 3 wrote into a schema 2-only installation");
            File.WriteAllText(manifest,metadata+"## X-Offhand-Topology-Schemas: 1,2,3\n");
            WriteBridge(root,"schema3-centered",settings,displays);
            Check(File.ReadAllText(bridge).Contains("coordinateSpace = \"BOTTOM_LEFT_PHYSICAL\"")&&File.ReadAllText(bridge).Contains("schema = 3"),"Bridge omitted schema/coordinate declaration");
            var changed=WorkspaceLayoutSettings.Read(settings);changed.PrimaryWorkspaceId="workspace-b";
            var changedSettings=WorkspaceLayoutSettings.Save(settings,changed,displays);
            Check(!CompanionTopologyBridge.IsCurrent(root,MonitorSelection.CreatePlan(changedSettings,displays),displays),"Primary change did not invalidate the old bridge");
            var stacked=WorkspaceLayoutPresets.SingleDisplay(displays[0],"stacked",document.Id,"Stacked desk");
            WriteBridge(root,"schema3-stacked",WorkspaceLayoutSettings.Save(legacy,stacked,displays),displays);
            var offsetDisplays=Displays();offsetDisplays[0].Bounds=new Rectangle(100,-200,3840,2160);
            var offset=WorkspaceLayoutPresets.SingleDisplay(offsetDisplays[0],"centered",document.Id,"Offset desk");
            offset.Game.Bounds=new Rectangle(1000,400,1920,1080);offset.Workspaces[0].Bounds=new Rectangle(0,0,800,600);offset.Workspaces[1].Bounds=new Rectangle(0,700,800,600);
            WriteBridge(root,"schema3-offset",WorkspaceLayoutSettings.Save(legacy,offset,offsetDisplays),offsetDisplays);

            Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
            using(var editor=new FlexibleWorkspaceEditor(displays,renamed)) {
                editor.CreateControl();editor.PerformLayout();
                var proposed=editor.Proposed();Check(proposed["WorkspaceProfileID"]==flexibleId&&proposed["WorkspaceProfileName"]=="Renamed flexible","Editing a cloned/renamed plan reverted its associated profile identity");
                Check(editor.SavePlan.Enabled,"Valid editor draft could not be saved");
                decimal width=editor.Areas[2,2].Value;editor.Second.Checked=false;editor.Second.Checked=true;
                Check(editor.Areas[2,2].Value==width,"Hiding Workspace B discarded its draft");
                editor.Areas[0,2].Value=100;Check(!editor.SavePlan.Enabled,"Invalid game width left Save enabled");
                Check(Equal(newLoaded,WorkspacePlanProfiles.Load(oldLoaded,flexibleId,displays)),"Editor draft changed saved preferences");
                if(args.Length>1){editor.Areas[0,2].Value=2560;editor.Show();Application.DoEvents();using(var bitmap=new Bitmap(editor.Width,editor.Height)){editor.DrawToBitmap(bitmap,new Rectangle(0,0,editor.Width,editor.Height));bitmap.Save(args[1]);}editor.Hide();}
            }
            Console.WriteLine("PASS: {0} flexible document, migration, capability, bridge, atomic preference and prototype editor checks",checks);
        }
    }
}
