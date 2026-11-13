using System;
using System.Collections.Generic;
using System.Drawing;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;

namespace Offhand.Companion
{
    // Local persisted data and geometry adapters only. Native Apply continues
    // through the existing capability check and rollback transaction.
    internal static class WorkspaceLayoutSettings
    {
        internal const string EnabledKey = "WorkspaceLayoutEnabled";
        internal const string DocumentKey = "WorkspaceLayoutV1";
        internal const string FallbackKey = "WorkspaceLayoutFallbackV1";
        internal const int MaximumDocumentBytes = 16384;
        private static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = 32768, RecursionLimit = 16 };

        private static void Require(bool condition, string reason)
        { if (!condition) throw new InvalidOperationException(reason); }
        internal static bool Enabled(IDictionary<string,string> settings)
        { string value; return settings.TryGetValue(EnabledKey, out value) && string.Equals(value,"True",StringComparison.OrdinalIgnoreCase); }
        internal static bool IsSetting(string key)
        { return key == EnabledKey || key == DocumentKey || key == FallbackKey; }
        internal static bool IsWorkspaceRegionSetting(string key)
        {
            return Regex.IsMatch(key, @"\AWorkspaceRegion(?:sEnabled|Version|Count|[1-3](?:Id|Identity|MonitorWidth|MonitorHeight|X|Y|Width|Height))\z");
        }
        internal static bool LegacyKey(string key)
        {
            return IsWorkspaceRegionSetting(key) || Regex.IsMatch(key,@"\A(?:WorkspacePrimary|MainhandIdentity|MainhandDevice|DisplayIdentityVersion|MonitorIdentities|MonitorDevices|Monitors|SingleDisplaySplit|SingleGameSide|Partial(?:SpanEnabled|DisplayIdentity|MonitorWidth|MonitorHeight|Edge|GameSide|Width|WorkspaceWidth)|Secondary(?:AreaEnabled|AreaIdentity|AreaX|AreaY|AreaWidth|AreaHeight|MonitorWidth|MonitorHeight)|WorkspaceProfileID|WorkspaceProfileName)\z");
        }
        private static Dictionary<string,object> Object(object value, params string[] keys)
        {
            var result=value as Dictionary<string,object>;
            Require(result!=null && result.Count==keys.Length,"Incomplete or unsupported layout data.");
            foreach(string key in keys) Require(result.ContainsKey(key),"Incomplete or unsupported layout data.");
            return result;
        }
        private static int Integer(Dictionary<string,object> value,string key)
        { Require(value[key] is int,"Layout dimensions must be whole 32-bit pixels."); return (int)value[key]; }
        private static string Text(Dictionary<string,object> value,string key)
        { Require(value[key] is string,"Invalid layout text."); return (string)value[key]; }
        private static object[] Array(object value,int maximum)
        { var result=value as object[]; Require(result!=null && result.Length>0 && result.Length<=maximum,"Invalid layout collection."); return result; }
        private static object RegionData(WorkspaceLayoutRegion region)
        {
            return new Dictionary<string,object>{{"id",region.Id},{"displayRole",region.DisplayRole},
                {"x",region.Bounds.X},{"y",region.Bounds.Y},{"width",region.Bounds.Width},{"height",region.Bounds.Height}};
        }
        private static WorkspaceLayoutRegion ReadRegion(object value)
        {
            var data=Object(value,"id","displayRole","x","y","width","height");
            return new WorkspaceLayoutRegion{Id=Text(data,"id"),DisplayRole=Text(data,"displayRole"),
                Bounds=new Rectangle(Integer(data,"x"),Integer(data,"y"),Integer(data,"width"),Integer(data,"height"))};
        }
        internal static string Encode(WorkspaceLayoutDocument document,IList<MonitorSelection.Display> displays)
        {
            WorkspaceLayoutPlanner.Resolve(document,displays);
            var regions=new List<object>();foreach(var region in document.Workspaces)regions.Add(RegionData(region));
            var monitors=new List<object>();foreach(var monitor in document.Displays)monitors.Add(new Dictionary<string,object>{
                {"role",monitor.Role},{"stableId",displays[MonitorSelection.FindDisplay(displays,monitor.StableId,null)].StableId},{"width",monitor.Resolution.Width},{"height",monitor.Resolution.Height}});
            string text=Json.Serialize(new Dictionary<string,object>{{"version",document.Version},{"id",document.Id},{"name",document.Name},
                {"primaryWorkspaceId",document.PrimaryWorkspaceId},{"game",RegionData(document.Game)},{"workspaces",regions},{"displays",monitors}});
            Require(Encoding.UTF8.GetByteCount(text)<=MaximumDocumentBytes,"The layout document is too large.");return text;
        }
        internal static WorkspaceLayoutDocument Decode(string text)
        {
            Require(text!=null && text.Length<=MaximumDocumentBytes && Encoding.UTF8.GetByteCount(text)<=MaximumDocumentBytes,"The layout document is missing or too large.");
            try {
                var data=Object(Json.DeserializeObject(text),"version","id","name","primaryWorkspaceId","game","workspaces","displays");
                Require(Integer(data,"version")==WorkspaceLayoutDocument.CurrentVersion,"Unsupported layout document version; the existing value was retained.");
                var document=new WorkspaceLayoutDocument{Id=Text(data,"id"),Name=Text(data,"name"),PrimaryWorkspaceId=Text(data,"primaryWorkspaceId"),Game=ReadRegion(data["game"])};
                foreach(var region in Array(data["workspaces"],WorkspaceLayoutPlanner.MaximumWorkspaces))document.Workspaces.Add(ReadRegion(region));
                foreach(var raw in Array(data["displays"],WorkspaceLayoutPlanner.MaximumDisplays)) {
                    var display=Object(raw,"role","stableId","width","height");
                    document.Displays.Add(new WorkspaceLayoutBinding{Role=Text(display,"role"),StableId=Text(display,"stableId"),
                        Resolution=new Size(Integer(display,"width"),Integer(display,"height"))});
                }
                return document;
            } catch(ArgumentException) {throw new InvalidOperationException("Saved flexible layout data could not be read. The existing value was retained.");}
        }
        internal static WorkspaceLayoutDocument Read(IDictionary<string,string> settings)
        { string text;Require(settings.TryGetValue(DocumentKey,out text),"A flexible layout document is missing.");return Decode(text); }
        private static Dictionary<string,string> ReadFallback(string text)
        {
            Require(text!=null && text.Length<=32768,"The saved fallback layout is missing or too large.");
            try {
                var data=Json.DeserializeObject(text) as Dictionary<string,object>;
                Require(data!=null && data.Count<=64,"Invalid fallback layout.");
                var result=new Dictionary<string,string>();
                foreach(var pair in data) {
                    Require(LegacyKey(pair.Key) && pair.Value is string && ((string)pair.Value).Length<=4096,"Unsupported fallback layout data; the existing value was retained.");
                    result[pair.Key]=(string)pair.Value;
                }
                return result;
            } catch(ArgumentException) {throw new InvalidOperationException("The fallback layout could not be read. Existing settings were retained.");}
        }
        internal static Dictionary<string,string> Save(IDictionary<string,string> current,WorkspaceLayoutDocument document,IList<MonitorSelection.Display> displays)
        {
            var resolved=WorkspaceLayoutPlanner.Resolve(document,displays);string encoded=Encode(document,displays);
            string existingDocument;if(current.TryGetValue(DocumentKey,out existingDocument))Decode(existingDocument);
            var result=new Dictionary<string,string>(current);string fallback;
            if(current.TryGetValue(FallbackKey,out fallback))ReadFallback(fallback);
            if(!Enabled(current)) {
                var original=new Dictionary<string,string>();foreach(var pair in current)if(LegacyKey(pair.Key))original[pair.Key]=pair.Value;
                result[FallbackKey]=Json.Serialize(original);
                ReadFallback(result[FallbackKey]);
            } else Require(result.ContainsKey(FallbackKey),"The previous layout snapshot is missing; retain the current preferences and use Restore Window.");
            result[EnabledKey]="True";result[DocumentKey]=encoded;result["AutoSpan"]="False";
            result["WorkspaceRegionsEnabled"]="False";result["PartialSpanEnabled"]="False";result["SecondaryAreaEnabled"]="False";result["SingleDisplaySplit"]="False";
            var identities=new List<string>();var devices=new List<string>();var indices=new List<string>();
            foreach(int index in resolved.DisplayIndices){identities.Add(displays[index].StableId);devices.Add(displays[index].DeviceName);indices.Add(index.ToString());}
            result["DisplayIdentityVersion"]="2";result["MainhandIdentity"]=displays[resolved.Game.DisplayIndex].StableId;result["MainhandDevice"]=displays[resolved.Game.DisplayIndex].DeviceName;
            result["MonitorIdentities"]=string.Join("|",identities);result["MonitorDevices"]=string.Join("|",devices);result["Monitors"]=string.Join(",",indices);
            result["WorkspaceProfileID"]=document.Id;result["WorkspaceProfileName"]=document.Name;
            return result;
        }
        internal static Dictionary<string,string> Disable(IDictionary<string,string> current)
        {
            var result=new Dictionary<string,string>(current);
            if(Enabled(current)) {
                string text;Require(current.TryGetValue(FallbackKey,out text),"The previous layout snapshot is missing. Use Restore Window before changing modes.");
                var fallback=ReadFallback(text);
                foreach(string key in new List<string>(result.Keys))if(LegacyKey(key))result.Remove(key);
                foreach(var pair in fallback)result[pair.Key]=pair.Value;
            }
            result[EnabledKey]="False";result["AutoSpan"]="False";return result;
        }
        internal static MonitorSelection.Plan CreatePlan(IDictionary<string,string> settings,IList<MonitorSelection.Display> displays)
        {
            var document=Read(settings);var resolved=WorkspaceLayoutPlanner.Resolve(document,displays);
            var indices=new List<int>(resolved.DisplayIndices);var regions=new List<MonitorSelection.WorkspaceRegion>();
            MonitorSelection.WorkspaceRegion primary=null;
            foreach(var region in resolved.Workspaces){var value=new MonitorSelection.WorkspaceRegion{Id=region.Id,DisplayIndex=region.DisplayIndex,Bounds=region.Bounds};regions.Add(value);if(value.Id==resolved.PrimaryWorkspaceId)primary=value;}
            string id,name;settings.TryGetValue("WorkspaceProfileID",out id);settings.TryGetValue("WorkspaceProfileName",out name);
            if(id==null||!Regex.IsMatch(id,@"\A[a-f0-9]{32}\z")){id=null;name=null;}else name=WorkspacePlanProfiles.Name(name);
            return new MonitorSelection.Plan{FlexibleLayout=true,Indices=indices.ToArray(),MainhandIndex=resolved.Game.DisplayIndex,
                WorkspaceIndex=primary.DisplayIndex,SplitSingle=indices.Count==1,Bounds=resolved.Bounds,MainhandBounds=resolved.Game.Bounds,
                WorkspaceBounds=primary.Bounds,Workspaces=regions.ToArray(),PrimaryWorkspaceId=resolved.PrimaryWorkspaceId,WorkspaceProfileID=id,WorkspaceProfileName=name};
        }
    }
}
