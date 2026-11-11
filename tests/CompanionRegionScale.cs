using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;

namespace Offhand.Companion
{
    internal static class RegionScaleTest
    {
        private static void Check(bool value, string message) { if (!value) throw new Exception(message); }
        public static void Main(string[] args)
        {
            var displays = new List<MonitorSelection.Display> {
                new MonitorSelection.Display { DeviceName="main", StableId="main-id", Bounds=new Rectangle(0,0,1000,1200) },
                new MonitorSelection.Display { DeviceName="left", StableId="left-id", Bounds=new Rectangle(-1000,0,1000,1200) },
                new MonitorSelection.Display { DeviceName="right", StableId="right-id", Bounds=new Rectangle(1000,0,1000,1200) }
            };
            var plan = new MonitorSelection.Plan { MainhandIndex=0, WorkspaceIndex=1, Indices=new[]{0,1,2},
                FlexibleLayout=true, Bounds=new Rectangle(-1000,0,3000,1200), MainhandBounds=displays[0].Bounds,
                WorkspaceBounds=displays[1].Bounds, PrimaryWorkspaceId="a", Workspaces=new[]{
                    new MonitorSelection.WorkspaceRegion { Id="a", DisplayIndex=1, Bounds=displays[1].Bounds },
                    new MonitorSelection.WorkspaceRegion { Id="b", DisplayIndex=2, Bounds=displays[2].Bounds }
                }};
            int reads=0;
            Func<MonitorSelection.Display, DisplayScaling.State> read = display => {
                reads++;
                return new DisplayScaling.State { Percent=display.DeviceName=="main"?200:display.DeviceName=="left"?100:150 };
            };
            string fields=CompanionTopologyBridge.PanelScaleFields(plan,displays,read);
            Check(reads==3 && fields.Contains("percent = 200") && fields.Contains("percent = 150")
                && fields.Contains("[\"a\"]") && fields.Contains("[\"b\"]"),"Every selected display needs its own scale");
            string common="mode='CUSTOM_REGIONS',physicalWidth=3000,physicalHeight=1200,mainhandDevice='main',"
                +"selectedDevices={'main','left','right'},game={x=1000,y=0,width=1000,height=1200},"
                +"primaryWorkspace='a',workspaces={{id='a',device='left',x=0,y=0,width=1000,height=1200},"
                +"{id='b',device='right',x=2000,y=0,width=1000,height=1200}},";
            string flexible="coordinateSpace='BOTTOM_LEFT_PHYSICAL',displays={"
                +"{device='main',x=1000,y=0,width=1000,height=1200},{device='left',x=0,y=0,width=1000,height=1200},"
                +"{device='right',x=2000,y=0,width=1000,height=1200}},";
            Directory.CreateDirectory(args[0]);
            File.WriteAllText(Path.Combine(args[0],"schema2.lua"),"OffhandCompanionTopology={schema=2,"+common+fields+"}");
            File.WriteAllText(Path.Combine(args[0],"schema3.lua"),"OffhandCompanionTopology={schema=3,"+common+flexible+fields+"}");
            reads=0;plan.Workspaces[1].DisplayIndex=1;
            fields=CompanionTopologyBridge.PanelScaleFields(plan,displays,read);
            Check(reads==2,"Regions on one monitor should reuse the same observed scale");
            Check(fields.Contains("identity = \"left-id\""),"Stable identity was not preserved");
            fields=CompanionTopologyBridge.PanelScaleFields(plan,displays,d=>new DisplayScaling.State());
            Check(!fields.Contains("percent ="),"Failed query must not invent 100 percent");
            plan.Workspaces=null;plan.SplitSingle=true;reads=0;
            fields=CompanionTopologyBridge.PanelScaleFields(plan,displays,read);
            Check(reads==1 && fields.Contains("[\"workspace\"]"),"Single-display regions must use Mainhand's scale");
            Console.WriteLine("PASS: all-region scale metadata, shared displays, query failure, stable identity and split layout");
        }
    }
}
