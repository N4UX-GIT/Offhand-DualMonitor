using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Windows.Forms;
using System.Web.Script.Serialization;

namespace Offhand.Testing
{
    // Test harness only: loads the exact candidate under package identity, stops
    // monitoring, and exercises isolated preference/tutorial state. No WoW input.
    internal static class Companion216PackageProbe
    {
        private const BindingFlags Instance = BindingFlags.Instance | BindingFlags.NonPublic;
        private const BindingFlags Static = BindingFlags.Static | BindingFlags.NonPublic;
        private static Dictionary<string,object> receipt = new Dictionary<string,object>();
        private static int checks;
        private static void Check(bool value,string message)
        { checks++; if(!value) throw new InvalidOperationException(message); }
        private static Dictionary<string,string> Read(string path)
        {
            var result=new Dictionary<string,string>();
            foreach(string line in File.ReadAllLines(path)) {
                int split=line.IndexOf('=');if(split>0)result[line.Substring(0,split)]=line.Substring(split+1);
            }
            return result;
        }
        private static Dictionary<string,string> Seed()
        {
            string profile="{\"Version\":1,\"Items\":[{\"ID\":\"0123456789abcdef0123456789abcdef\",\"Name\":\"QA Desk ø漢字\",\"MainWidth\":2560,\"MainHeight\":1440,\"Settings\":{\"WorkspaceRegionsEnabled\":\"False\",\"MainhandIdentity\":\"qa-main\",\"Monitors\":\"0\",\"PartialSpanEnabled\":\"False\",\"SecondaryAreaEnabled\":\"False\"}}]}";
            return new Dictionary<string,string> {
                {"AutoSpan","True"},{"DelaySpan","31"},{"UnknownFutureKey","preserve=ø漢字"},
                {"PartialSpanEnabled","True"},{"PartialDisplayIdentity","qa-unavailable-monitor"},
                {"PartialWidth","2240"},{"PartialWorkspaceWidth","640"},{"PartialMonitorWidth","2560"},
                {"PartialMonitorHeight","1440"},{"PartialEdge","LEFT"},{"PartialGameSide","RIGHT"},
                {"WorkspaceProfilesV1",Convert.ToBase64String(Encoding.UTF8.GetBytes(profile))},
                {"DashboardCollapsed.SystemStatus","True"},{"DashboardCollapsed.DisplayDiagnostics","True"},
                {"DashboardCollapsed.ActivityLog","True"}
            };
        }
        private static Control Find(Control root,string name)
        {
            foreach(Control child in root.Controls) {
                if(child.AccessibleName==name)return child;
                var result=Find(child,name);if(result!=null)return result;
            }
            return null;
        }
        [STAThread]
        private static int Main(string[] args)
        {
            if(args.Length!=5)return 2;
            string binary=Path.GetFullPath(args[0]),hash=args[1],output=Path.GetFullPath(args[2]),phase=args[3],expectedName=args[4];
            Directory.CreateDirectory(output);
            string resultPath=Path.Combine(output,"result.json");
            if(File.Exists(resultPath))return 3;
            Form form=null;Timer controller=null;
            try {
                Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
                using(var sha=SHA256.Create())using(var input=File.OpenRead(binary))
                    Check(BitConverter.ToString(sha.ComputeHash(input)).Replace("-","")==hash.ToUpperInvariant(),"Exact executable hash changed.");
                var assembly=Assembly.LoadFrom(binary);
                var distribution=assembly.GetType("Offhand.Companion.CompanionDistribution",true);
                string family=(string)distribution.GetMethod("PackageFamilyName",Static).Invoke(null,null);
                Check(family!=null && family.StartsWith(expectedName+"_",StringComparison.Ordinal),"Unexpected package family.");
                bool privatePackage=expectedName=="N4UX.OffhandCompanion.UpgradeValidation216";
                Check(privatePackage || expectedName=="N4UX.OffhandCompanion","Unsupported test identity.");
                string local=Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                string state=Path.Combine(local,"Packages",family,"LocalState");
                string config=Path.Combine(state,"OffhandConfig.ini");
                if(!privatePackage)config=Path.Combine(state,"Companion216Validation",new DirectoryInfo(Path.GetDirectoryName(output)).Name,"OffhandConfig.ini");
                Directory.CreateDirectory(Path.GetDirectoryName(config));
                bool first=phase=="baseline"||phase=="first"||phase=="upgrade-first";
                if(phase=="baseline"||phase=="first") {
                    Check(!File.Exists(config),"Use a fresh isolated fixture directory.");
                    var lines=new List<string>();foreach(var item in Seed())lines.Add(item.Key+"="+item.Value);
                    File.WriteAllLines(config,lines.ToArray(),new UTF8Encoding(false));
                }
                var original=Read(config);
                var type=assembly.GetType("Offhand.Companion.CompanionForm",true);
                var field=type.GetField("configPath",Static);
                string resolved=(string)field.GetValue(null);
                if(privatePackage)Check(resolved==config,"Private package did not resolve package-local production settings.");
                else field.SetValue(null,config);
                type.GetField("publicConfigPath",Static).SetValue(null,config);
                form=(Form)Activator.CreateInstance(type);
                type.GetField("isMonitoring",Instance).SetValue(form,false);
                type.GetField("isExplicitExit",Instance).SetValue(form,true);
                ((Timer)type.GetField("monitorTimer",Instance).GetValue(form)).Stop();
                Check((bool)type.GetField("isStorePackage",Instance).GetValue(form),"Package update routing was not detected.");
                var button=(Button)type.GetField("btnCheckUpdates",Instance).GetValue(form);
                Check(button.Text.Contains("Store"),"Packaged runtime exposed portable update routing.");
                form.Text="Companion 2.1.6 QA: isolated "+phase;
                receipt["phase"]=phase;receipt["packageFamily"]=family;receipt["exactExeSha256"]=hash;
                receipt["version"]=assembly.GetName().Version.ToString();receipt["privatePackage"]=privatePackage;
                receipt["originalKeys"]=original.Count;receipt["monitoringDisabled"]=true;
                var start=type.GetMethod("StartDashboardTutorial",Instance);
                Action finish=()=>{
                    type.GetMethod("SaveConfig",Instance).Invoke(form,null);
                    var saved=Read(config);
                    foreach(var pair in original)Check(saved.ContainsKey(pair.Key)&&saved[pair.Key]==pair.Value,"Existing setting changed: "+pair.Key);
                    foreach(var pair in Seed())Check(saved.ContainsKey(pair.Key)&&saved[pair.Key]==pair.Value,"Upgrade fixture changed: "+pair.Key);
                    if(start!=null)Check(saved.ContainsKey("CompanionTutorialSeen")&&saved["CompanionTutorialSeen"]=="True","Tutorial completion was not persisted.");
                    byte[] before=File.ReadAllBytes(config);
                    using(var locked=new FileStream(config,FileMode.Open,FileAccess.Read,FileShare.None))
                        type.GetMethod("SaveConfig",Instance).Invoke(form,null);
                    Check(Convert.ToBase64String(before)==Convert.ToBase64String(File.ReadAllBytes(config)),"Locked save changed last good preferences.");
                    type.GetMethod("SaveConfig",Instance).Invoke(form,null);
                    Check(Read(config)["UnknownFutureKey"]=="preserve=ø漢字","Retry after unlock lost Unicode/unknown keys.");
                    receipt["result"]="PASS";receipt["checks"]=checks;receipt["settingsPreserved"]=true;
                    receipt["lockedSavePreserved"]=true;receipt["retryPassed"]=true;
                    receipt["tutorialSeen"]=start!=null;
                    if(controller!=null)controller.Stop();form.Close();
                };
                if(start==null) { Check(phase=="baseline","Candidate tutorial API is missing.");finish(); }
                else {
                    DateTime deadline=DateTime.UtcNow.AddSeconds(15);int step=0;
                    form.Shown+=(sender,eventArgs)=>form.BeginInvoke(new Action(()=>{
                        var storeTimer=(Timer)type.GetField("storeUpdateTimer",Instance).GetValue(form);if(storeTimer!=null)storeTimer.Stop();
                    }));
                    controller=new Timer{Interval=125};
                    controller.Tick+=(sender,eventArgs)=>{
                        try {
                            bool active=Find(form,"Companion tutorial")!=null;
                            if(step==0) {
                                if(first&&!active) { Check(DateTime.UtcNow<deadline,"Automatic first-run tutorial did not appear.");return; }
                                if(!first) { Check(!active,"Seen tutorial reappeared after relaunch.");start.Invoke(form,null); }
                                receipt["automaticTutorial"]=first;receipt["replayVerified"]=!first;
                            }
                            type.GetMethod("MoveDashboardTutorial",Instance).Invoke(form,new object[]{1});step++;
                            if(step==16) { Check(Find(form,"Companion tutorial")==null,"Finish did not dismiss the tutorial.");finish(); }
                        }catch(Exception error){receipt["result"]="FAIL";receipt["error"]=error.ToString();controller.Stop();form.Close();}
                    };
                    controller.Start();Application.Run(form);
                }
            }catch(Exception error){receipt["result"]="FAIL";receipt["error"]=error.ToString();}
            finally {
                if(controller!=null)controller.Dispose();
                if(form!=null){var tray=form.GetType().GetField("trayIcon",Instance);if(tray!=null){var icon=tray.GetValue(form)as NotifyIcon;if(icon!=null)icon.Dispose();}form.Dispose();}
                receipt["finishedUtc"]=DateTime.UtcNow.ToString("o");
                File.WriteAllText(resultPath,new JavaScriptSerializer().Serialize(receipt));
            }
            return receipt.ContainsKey("result")&&(string)receipt["result"]=="PASS"?0:1;
        }
    }
}
