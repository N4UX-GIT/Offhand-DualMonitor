using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using System.Windows.Forms;
namespace Offhand.Companion {
 internal static class WorkspaceProfilesTest {
  private static int checks;
  private static void Check(bool value,string message){checks++;if(!value)throw new Exception(message);}
  private static void Refuses(Action action){bool refused=false;try{action();}catch(InvalidOperationException){refused=true;}Check(refused,"Invalid plan was accepted");}
  private static List<MonitorSelection.Display> Displays(){return new List<MonitorSelection.Display>{
   new MonitorSelection.Display{Index=0,StableId="game",DeviceName="game-device",Bounds=new Rectangle(0,0,2560,1440)},
   new MonitorSelection.Display{Index=1,StableId="left",DeviceName="left-device",Bounds=new Rectangle(-1440,0,1440,2560)},
   new MonitorSelection.Display{Index=2,StableId="right",DeviceName="right-device",Bounds=new Rectangle(2560,0,1920,1080)}};}
  private static Dictionary<string,string> Settings(){return new Dictionary<string,string>{
   {"WorkspaceRegionsEnabled","True"},{"WorkspaceRegionVersion","2"},{"WorkspaceRegionCount","2"},
   {"MainhandIdentity","game"},{"MainhandDevice","game-device"},{"DisplayIdentityVersion","1"},
   {"MonitorIdentities","game|left|right"},{"MonitorDevices","game-device|left-device|right-device"},{"Monitors","0,1,2"},
   {"WorkspacePrimary","a"},{"WorkspaceRegion1Id","a"},{"WorkspaceRegion1Identity","left"},
   {"WorkspaceRegion1MonitorWidth","1440"},{"WorkspaceRegion1MonitorHeight","2560"},
   {"WorkspaceRegion1X","20"},{"WorkspaceRegion1Y","40"},{"WorkspaceRegion1Width","700"},{"WorkspaceRegion1Height","1200"},
   {"WorkspaceRegion2Id","b"},{"WorkspaceRegion2Identity","right"},
   {"WorkspaceRegion2MonitorWidth","1920"},{"WorkspaceRegion2MonitorHeight","1080"},
   {"WorkspaceRegion2X","0"},{"WorkspaceRegion2Y","0"},{"WorkspaceRegion2Width","700"},{"WorkspaceRegion2Height","900"},
   {"AutoSpan","True"},{"DelaySpan","59"},{"UpdateChannel","stable"},{"PrivateUnrelated","retain"}};}
  [STAThread] public static int Main(string[] args){
   var displays=Displays();var original=Settings();
   var first=WorkspacePlanProfiles.Save(original,"Desk",null,displays);
   Check(!original.ContainsKey(WorkspacePlanProfiles.Key),"Save mutated caller before publication");
   var record=WorkspacePlanProfiles.Read(first).Items.Single();string id=record.ID;
   Check(record.Name=="Desk"&&record.Settings.Count>20&&!record.Settings.ContainsKey("PrivateUnrelated")&&!record.Settings.ContainsKey("AutoSpan"),"Snapshot escaped its geometry allowlist");
   Check(first["PrivateUnrelated"]=="retain"&&first["DelaySpan"]=="59","Saving changed unrelated preferences");
   var modified=new Dictionary<string,string>(first);modified["WorkspaceRegion1X"]="100";
   var second=WorkspacePlanProfiles.Save(modified,"Streaming",null,displays);
   var loaded=WorkspacePlanProfiles.Load(second,id,displays);
   Check(loaded["WorkspaceRegion1X"]=="20"&&loaded["AutoSpan"]=="False"&&loaded["WorkspaceProfileID"]==id,"Loading lost geometry, identity or manual apply policy");
   Check(loaded["PrivateUnrelated"]=="retain"&&loaded["UpdateChannel"]=="stable","Loading replaced unrelated state");
   var renamed=WorkspacePlanProfiles.Rename(loaded,id,"Desk renamed");
   Check(renamed["WorkspaceProfileID"]==id&&renamed["WorkspaceProfileName"]=="Desk renamed","Rename changed stable identity");
   var updated=WorkspacePlanProfiles.Save(renamed,"Desk renamed",id,displays);
   Check(WorkspacePlanProfiles.Read(updated).Items.Count==2&&WorkspacePlanProfiles.Read(updated).Items.Find(x=>x.ID==id).ID==id,"Update duplicated a profile");
   Refuses(()=>WorkspacePlanProfiles.Save(first,"desk",null,displays));
   Refuses(()=>WorkspacePlanProfiles.Save(first,"bad|name",null,displays));
   Refuses(()=>WorkspacePlanProfiles.Save(first,new string('a',49),null,displays));
   var missing=Displays();missing.RemoveAt(1);Refuses(()=>WorkspacePlanProfiles.Load(second,id,missing));
   var resized=Displays();resized[0].Bounds=new Rectangle(0,0,1920,1080);Refuses(()=>WorkspacePlanProfiles.Load(second,id,resized));
   var resizedWorkspace=Displays();resizedWorkspace[1].Bounds=new Rectangle(-1440,0,1440,1920);Refuses(()=>WorkspacePlanProfiles.Load(second,id,resizedWorkspace));
   var reordered=Displays();reordered.Reverse();
   Check(WorkspacePlanProfiles.Load(second,id,reordered)["WorkspaceRegion1Identity"]=="left","Display reorder changed identity");
   var malformed=new Dictionary<string,string>(first);malformed[WorkspacePlanProfiles.Key]="not-base64";
   Refuses(()=>WorkspacePlanProfiles.Save(malformed,"New",null,displays));Check(malformed[WorkspacePlanProfiles.Key]=="not-base64","Malformed data was discarded");
   malformed[WorkspacePlanProfiles.Key]=Convert.ToBase64String(Encoding.UTF8.GetBytes("{\"Version\":99,\"Items\":[]}"));
   Refuses(()=>WorkspacePlanProfiles.Read(malformed));
   var deleted=WorkspacePlanProfiles.Delete(renamed,id);
   Check(!deleted.ContainsKey("WorkspaceProfileID")&&deleted["WorkspaceRegion1Width"]==renamed["WorkspaceRegion1Width"],"Delete changed the current display geometry");
   var plan=MonitorSelection.CreatePlan(renamed,displays);
   Check(plan.WorkspaceProfileID==id&&plan.WorkspaceProfileName=="Desk renamed","Plan dropped named identity");
   string root=args[0],wow=Path.Combine(root,"wow");Directory.CreateDirectory(Path.Combine(wow,"Interface","AddOns","Offhand","Core"));
   File.WriteAllText(Path.Combine(wow,"Interface","AddOns","Offhand","Offhand.toc"),"## X-Offhand-Companion-Protocol: 1\n## X-Offhand-Companion-Min-Version: 2.1.2-beta.19\n## X-Offhand-Topology-Schemas: 1,2\n");
   string message;byte[] bytes;
   Check(CompanionTopologyBridge.TryWrite(wow,plan,displays,out message,out bytes),"Named bridge write failed");
   string bridge=Encoding.UTF8.GetString(bytes);Check(bridge.Contains("workspaceProfileID = \""+id+"\"")&&bridge.Contains("workspaceProfileName = \"Desk renamed\""),"Bridge lost profile fields");
   Check(CompanionTopologyBridge.IsCurrent(wow,plan,displays),"Named bridge cannot be revalidated");
   string bridgePath=Path.Combine(wow,"Interface","AddOns","Offhand","Core","CompanionTopology.lua");
   var pendingSettings=new Dictionary<string,string>(renamed);
   pendingSettings["WorkspaceProfileID"]=second["WorkspaceProfileID"];
   pendingSettings["WorkspaceProfileName"]=second["WorkspaceProfileName"];
   pendingSettings["WorkspacePrimary"]="b";
   var pending=MonitorSelection.CreatePlan(pendingSettings,displays);
   string appliedKey=CompanionTopologyBridge.LayoutKey(plan,displays);
   string pendingKey=CompanionTopologyBridge.LayoutKey(pending,displays);
   var pendingBridge=CompanionTopologyBridge.Inspect(wow,pending,displays);
   Check(plan.Bounds==pending.Bounds && appliedKey!=pendingKey,"Same outer window must distinguish saved layouts");
   Check(pendingBridge==CompanionTopologyBridge.BridgeMatch.DifferentLayout,"Applied bridge matched a pending layout");
   Check(!CompanionTopologyBridge.CanConfirmLayout(appliedKey,pendingKey,pendingBridge),"Polling can apply a pending layout");
   Check(!CompanionTopologyBridge.CanConfirmLayout(null,pendingKey,pendingBridge),"Restart can apply a pending layout");
   var alternate=MonitorSelection.CreatePlan(renamed,displays);
   alternate.PrimaryWorkspaceId=pending.PrimaryWorkspaceId;
   alternate.WorkspaceBounds=pending.WorkspaceBounds;
   Check(CompanionTopologyBridge.LayoutKey(alternate,displays)!=appliedKey
    && CompanionTopologyBridge.Inspect(wow,alternate,displays)==CompanionTopologyBridge.BridgeMatch.DifferentLayout,
    "The same saved plan identity must distinguish changed internal geometry");
   alternate=MonitorSelection.CreatePlan(renamed,displays);
   alternate.WorkspaceProfileID=pending.WorkspaceProfileID;
   Check(CompanionTopologyBridge.LayoutKey(alternate,displays)!=appliedKey
    && CompanionTopologyBridge.Inspect(wow,alternate,displays)==CompanionTopologyBridge.BridgeMatch.DifferentLayout,
    "Identical geometry must distinguish different linked presets");
   File.WriteAllText(bridgePath,bridge.Replace("companionVersion = ","previousVersion = "));
   var outdated=CompanionTopologyBridge.Inspect(wow,plan,displays);
   Check(outdated==CompanionTopologyBridge.BridgeMatch.NeedsRefresh
    && CompanionTopologyBridge.CanConfirmLayout(null,appliedKey,outdated),"Restart cannot refresh an attested layout");
   File.WriteAllText(bridgePath,"OffhandCompanionTopology = nil");
   var placeholder=CompanionTopologyBridge.Inspect(wow,plan,displays);
   Check(CompanionTopologyBridge.CanConfirmLayout(appliedKey,appliedKey,placeholder)
    && !CompanionTopologyBridge.CanConfirmLayout(null,appliedKey,placeholder),"A placeholder can only be repaired for a known window and plan");
   File.WriteAllText(bridgePath,bridge.Replace("Desk renamed","stale name"));
   Check(!CompanionTopologyBridge.IsCurrent(wow,plan,displays),"Rename did not invalidate stale bridge metadata");
   Application.EnableVisualStyles();
   using(var dialog=new WorkspaceProfilesDialog(new Dictionary<string,string>{{"PartialSpanEnabled","True"}},Displays)){
    var layout=dialog.Controls.OfType<TableLayoutPanel>().Single();
    layout.Controls.OfType<TextBox>().Single().Text="Test";
    var save=layout.Controls.OfType<FlowLayoutPanel>().Single().Controls.OfType<Button>().Single(button=>button.Text=="Save as new");
    var feedback=layout.Controls.OfType<Label>().Single(label=>label.AccessibleName=="Profile status");
    Check(!save.Enabled && feedback.Text.Contains("One monitor") && feedback.Text.Contains("Multiple workspaces")
     && feedback.Text.Contains("Save plan"),"Unsupported current layout must explain how to enable profile creation");
   }
   using(var dialog=new WorkspaceProfilesDialog(original,Displays)){
    dialog.Show();Application.DoEvents();
    var layout=dialog.Controls.OfType<TableLayoutPanel>().Single();
    layout.Controls.OfType<TextBox>().Single().Text="Test";
    var save=layout.Controls.OfType<FlowLayoutPanel>().Single().Controls.OfType<Button>().Single(button=>button.Text=="Save as new");
    Check(save.Enabled,"A saved Multiple workspaces layout must allow its first profile");
    save.PerformClick();
    Check(WorkspacePlanProfiles.Read(dialog.Settings).Items.Single().Name=="Test","Save as new must stage a named profile without WoW");
    dialog.Hide();
   }
   using(var dialog=new WorkspaceProfilesDialog(renamed,Displays)){
    dialog.Show();Application.DoEvents();dialog.PerformLayout();
    Check(dialog.Text=="Workspace profiles","Profile editor missing");
    var choice=dialog.Controls.OfType<TableLayoutPanel>().Single().Controls.OfType<ComboBox>().Single();
    Check(choice.GetItemText(choice.SelectedItem)=="Desk renamed","Profile picker exposed a type name instead of its label");
    using(var bitmap=new Bitmap(dialog.Width,dialog.Height)){dialog.DrawToBitmap(bitmap,new Rectangle(0,0,dialog.Width,dialog.Height));bitmap.Save(Path.Combine(root,"profiles-editor.png"));}
    dialog.Hide();
   }
   Console.WriteLine("PASS: "+checks+" named-plan persistence, isolation, monitor recovery, bridge identity and editor checks");return 0;
  }
 }
}
