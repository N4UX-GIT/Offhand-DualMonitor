using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

namespace Offhand.Companion
{
    internal static class UpdateNoticesTest
    {
        private const BindingFlags PrivateInstance = BindingFlags.Instance | BindingFlags.NonPublic;
        private const BindingFlags PrivateStatic = BindingFlags.Static | BindingFlags.NonPublic;
        private static int checks;
        private static void Check(bool value, string message)
        { checks++; if (!value) throw new Exception(message); }
        private static IEnumerable<Control> Children(Control root)
        {
            foreach (Control child in root.Controls) {
                yield return child;
                foreach (Control nested in Children(child)) yield return nested;
            }
        }
        private static void Run(string config, bool expectNotice, bool expectTutorial)
        {
            typeof(CompanionForm).GetField("configPath",PrivateStatic).SetValue(null,config);
            typeof(CompanionForm).GetField("publicConfigPath",PrivateStatic).SetValue(null,config);
            using (var form=new CompanionForm())
            using (var timer=new Timer { Interval=50 }) {
                var monitor=(Timer)typeof(CompanionForm).GetField("monitorTimer",PrivateInstance).GetValue(form);
                monitor.Stop();
                typeof(CompanionForm).GetField("isMonitoring",PrivateInstance).SetValue(form,false);
                typeof(CompanionForm).GetField("isExplicitExit",PrivateInstance).SetValue(form,true);
                form.ShowInTaskbar=false;
                Exception failure=null; int ticks=0,noticeCount=0; bool tutorialSeen=false;
                DateTime deadline=DateTime.UtcNow.AddSeconds(8);
                timer.Tick+=(sender,args)=> {
                    try {
                        ticks++;
                        Check(DateTime.UtcNow<deadline,"Introduction did not finish");
                        Form notice=null;
                        foreach(Form open in Application.OpenForms)
                            if(open.Text.EndsWith("- What's new"))notice=open;
                        if(notice!=null) {
                            Check(expectNotice,"Unexpected automatic update notice");
                            noticeCount++;
                            Check(noticeCount==1,"Update notice repeated in the same launch");
                            Button dismiss=null;
                            foreach(Control child in Children(notice)) {
                                var text=child as RichTextBox;
                                if(text!=null)Check(text.Text.Contains("If something looks wrong")
                                    &&text.Text.Contains("/offhand guide"),"Conditional calibration guidance missing");
                                if(child is Button && child.Text=="Got it")dismiss=(Button)child;
                            }
                            Check(dismiss!=null,"Notice cannot be dismissed");
                            dismiss.PerformClick();
                            return;
                        }
                        foreach(Control child in Children(form)) {
                            if(child.AccessibleName!="Companion tutorial")continue;
                            Check(expectTutorial,"Unexpected first-run tutorial");
                            tutorialSeen=true;
                            form.EndDashboardTutorial(true);
                            break;
                        }
                        if(ticks<6)return;
                        Check((noticeCount>0)==expectNotice,"Automatic notice routing differs");
                        Check(tutorialSeen==expectTutorial,"First-run tutorial routing differs");
                        Check(PreferenceFile.Read(config)["KeepMe"]=="preserve","Introduction changed unrelated settings");
                        timer.Stop();form.Close();
                    }
                    catch(Exception error) {
                        failure=error;timer.Stop();
                        var openForms=new List<Form>();foreach(Form open in Application.OpenForms)openForms.Add(open);
                        foreach(Form open in openForms)if(open!=form)open.Close();
                        form.Close();
                    }
                };
                timer.Start(); Application.Run(form);
                var tray=(NotifyIcon)typeof(CompanionForm).GetField("trayIcon",PrivateInstance).GetValue(form);
                if(tray!=null)tray.Dispose();monitor.Dispose();
                if(failure!=null)throw failure;
            }
        }
        [STAThread]
        public static void Main()
        {
            Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
            string root=Path.Combine(Path.GetTempPath(),"Offhand-notices-"+Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(root);
            try {
                var settings=new Dictionary<string,string>();
                Check(!CompanionForm.UpdateNoticeNeeded(settings),"Fresh install must use only the tutorial");
                settings["CompanionTutorialSeen"]="True";
                Check(CompanionForm.UpdateNoticeNeeded(settings),"Legacy tutorial users should see one migration notice");
                settings["KeepMe"]="preserve";
                Check(CompanionForm.RememberCompanionVersion(settings),"Acknowledgement must record version");
                Check(!CompanionForm.UpdateNoticeNeeded(settings)&&!CompanionForm.RememberCompanionVersion(settings),"Same version must not repeat/write");
                settings["CompanionLastSeenVersion"]="2.1.6";
                Check(CompanionForm.UpdateNoticeNeeded(settings),"Older acknowledged version must show changes");
                settings["CompanionLastSeenVersion"]="2.1.8";
                Check(!CompanionForm.UpdateNoticeNeeded(settings)&&!CompanionForm.RememberCompanionVersion(settings)
                    &&settings["CompanionLastSeenVersion"]=="2.1.8","Rollback must preserve newer acknowledgement");
                settings["CompanionLastSeenVersion"]="bad";
                Check(CompanionForm.UpdateNoticeNeeded(settings),"Malformed acknowledgement can recover");
                string upgrade=Path.Combine(root,"upgrade.ini");
                PreferenceFile.Write(upgrade,new Dictionary<string,string>{{"KeepMe","preserve"},{"CompanionTutorialSeen","True"},{"CompanionLastSeenVersion","2.1.6"}});
                Run(upgrade,true,false);
                Check(PreferenceFile.Read(upgrade)["CompanionLastSeenVersion"]==CompanionForm.BaseVersion,"Dismissal did not persist version");
                Run(upgrade,false,false);
                string legacy=Path.Combine(root,"legacy.ini");
                PreferenceFile.Write(legacy,new Dictionary<string,string>{{"KeepMe","preserve"},{"CompanionTutorialSeen","True"}});
                Run(legacy,true,false);
                string fresh=Path.Combine(root,"fresh.ini");
                PreferenceFile.Write(fresh,new Dictionary<string,string>{{"KeepMe","preserve"}});
                Run(fresh,false,true);
                Check(PreferenceFile.Read(fresh)["CompanionLastSeenVersion"]==CompanionForm.BaseVersion,"Fresh tutorial baseline not recorded");
                Run(fresh,false,false);
                Console.WriteLine("PASS: "+checks+" update-notice policy, shown upgrade/dismissal/relaunch, legacy migration and first-run routing checks; isolated preferences, no Store query or game input.");
            }
            finally { Directory.Delete(root,true); }
        }
    }
}
