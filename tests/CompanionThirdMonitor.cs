using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;

namespace Offhand.Companion
{
    // Characterize the current two-selected-display boundary on a three-display
    // desktop. This does not implement a second workspace or move any window.
    internal static class ThirdMonitorTest
    {
        private static int checks;
        [DllImport("gdi32.dll")] private static extern bool PtInRegion(IntPtr region, int x, int y);
        private static void Check(bool value, string message)
        { checks++; if (!value) throw new Exception(message); }
        private static void Reject(Action action)
        {
            bool rejected = false;
            try { action(); } catch (InvalidOperationException) { rejected = true; }
            Check(rejected, "Three selected displays must fail before applying a window plan.");
        }
        private static MonitorSelection.Display Display(int index, string id, Rectangle bounds)
        { return new MonitorSelection.Display { Index=index, StableId=id, DeviceName=id,
            Bounds=bounds, WorkArea=bounds, Primary=id=="game" }; }
        private static Dictionary<string,string> Settings(MonitorSelection.Display workspace)
        {
            return new Dictionary<string,string> {
                {"DisplayIdentityVersion","1"}, {"MonitorIdentities","game|"+workspace.StableId},
                {"MainhandIdentity","game"}, {"SecondaryAreaEnabled","True"},
                {"SecondaryAreaIdentity",workspace.StableId}, {"SecondaryAreaX","20"},
                {"SecondaryAreaY","30"}, {"SecondaryAreaWidth","800"},
                {"SecondaryAreaHeight","700"},
                {"SecondaryMonitorWidth",workspace.Bounds.Width.ToString()},
                {"SecondaryMonitorHeight",workspace.Bounds.Height.ToString()}
            };
        }
        private static Point Centre(Rectangle r)
        { return new Point(r.Left+r.Width/2,r.Top+r.Height/2); }
        private static void Clip(MonitorSelection.Plan plan, Rectangle unselected)
        {
            IntPtr region=SpanClipRegion.Create(plan,plan.Bounds);
            try {
                foreach(Rectangle r in MonitorSelection.VisibleRectangles(plan)) {
                    Point p=Centre(r);
                    Check(PtInRegion(region,p.X-plan.Bounds.X,p.Y-plan.Bounds.Y),"Selected rectangle missing from clip.");
                }
                Point other=Centre(unselected);
                Check(!PtInRegion(region,other.X-plan.Bounds.X,other.Y-plan.Bounds.Y),"Unselected monitor captured by clip.");
                var w=plan.WorkspaceBounds;
                Check(!PtInRegion(region,w.Left-plan.Bounds.X-1,w.Top-plan.Bounds.Y+10),"Reserved strip captured by clip.");
            } finally { NativeMethods.DeleteObject(region); }
        }
        public static void Main(string[] args)
        {
            var game=Display(0,"game",new Rectangle(0,0,2560,1440));
            var left=Display(1,"left",new Rectangle(-1440,-1114,1440,2560));
            var right=Display(2,"right",new Rectangle(2560,0,1920,1080));
            var displays=new List<MonitorSelection.Display>{game,left,right};
            foreach(var work in new[]{left,right}) {
                var settings=Settings(work);
                var plan=MonitorSelection.CreatePlan(settings,displays);
                Check(plan.Indices.Length==2 && plan.PartialSecondary,"Two selected displays on a three-display desktop must work.");
                Check(plan.MainhandBounds==game.Bounds,"Game monitor changed.");
                Check(plan.WorkspaceBounds==new Rectangle(work.Bounds.Left+20,work.Bounds.Top+30,800,700),"Wrong physical workspace.");
                var reordered=new List<MonitorSelection.Display>{right,game,left};
                var again=MonitorSelection.CreatePlan(settings,reordered);
                Check(again.Bounds==plan.Bounds && again.WorkspaceBounds==plan.WorkspaceBounds,"Enumeration order changed geometry.");
                Check(reordered[again.MainhandIndex].StableId=="game","Stable game identity lost.");
                var unused=work==left?right:left;
                Clip(plan,unused.Bounds);
                string wow=Path.Combine(args[0],work.StableId);
                Directory.CreateDirectory(Path.Combine(wow,"Interface","AddOns","Offhand","Core"));
                string message;
                Check(CompanionTopologyBridge.TryWrite(wow,plan,displays,out message),"Schema 1 bridge write failed.");
                string text=File.ReadAllText(Path.Combine(wow,"Interface","AddOns","Offhand","Core","CompanionTopology.lua"));
                Check(text.Contains("schema = 1") && !text.Contains("\""+unused.DeviceName+"\""),"Bridge included unselected monitor.");
                var remaining=new List<MonitorSelection.Display>{game,work};
                Check(MonitorSelection.CreatePlan(settings,remaining).Bounds==plan.Bounds,"Removing unused monitor invalidated selected pair.");
                Check(!MonitorSelection.HasDisconnectedSavedDisplay(settings["MonitorIdentities"],null,remaining),"Unused monitor treated as required.");
                Reject(()=>MonitorSelection.CreatePlan(settings,new List<MonitorSelection.Display>{game,unused}));
                settings["MonitorIdentities"]="game|left|right";
                Reject(()=>MonitorSelection.CreatePlan(settings,displays));
                string preferences=Path.Combine(args[0],work.StableId+".ini");
                File.WriteAllText(preferences,"Keep=original\r\n");
                byte[] before=File.ReadAllBytes(preferences);
                Reject(()=>CustomRegionPreferences.Write(preferences,settings,()=>displays));
                Check(SpanRollback.SameBytes(before,File.ReadAllBytes(preferences)),"Rejected save changed preferences.");
            }
            Reject(()=>MonitorSelection.CreatePlan(null,null,null,null,null,false,false,displays));
            // A third desktop display can sit between the two selected displays.
            // The current clip must preserve that hole, not fill the union box.
            var far=Display(2,"far",new Rectangle(4480,0,1920,1080));
            var gapSettings=Settings(far);
            var separated=MonitorSelection.CreatePlan(gapSettings,new List<MonitorSelection.Display>{game,right,far});
            Clip(separated,right.Bounds);
            Check(separated.Bounds.Width==5300 && separated.Bounds.Height==1440,"Unexpected separated backing surface.");
            Console.WriteLine("PASS: "+checks+" checks for three connected/two selected displays, stable identity, reserved holes, bridge boundaries and three-selection refusal");
        }
    }
}
