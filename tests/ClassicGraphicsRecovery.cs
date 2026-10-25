using System;
using System.Drawing;
namespace Offhand.Companion {
    internal static class ClassicGraphicsRecoveryTest {
        private static int count;
        private static void Check(bool value, string name) { count++; if (!value) throw new Exception(name); }
        private static readonly Rectangle Span = new Rectangle(-1440,-1114,4000,2560);
        private static readonly IntPtr Handle = new IntPtr(123);
        private static readonly DateTime Start = new DateTime(2026,10,24,18,42,50,DateTimeKind.Utc);
        private static ClassicGraphicsRecovery Policy() {
            var p = new ClassicGraphicsRecovery(Handle,Span,new Size(2114,1353),"same-plan");
            var healthy = Reset(); healthy.Bounds=Span; healthy.Client=Span.Size; healthy.Style=0x140B0000;
            Check(!p.Observe(healthy,"same-plan",Start.AddSeconds(-4),true) && !p.Confirmed,"initial span must wait");
            Check(!p.Observe(healthy,"same-plan",Start.AddSeconds(-2),true) && p.Confirmed,"stable span must confirm before arming");
            return p;
        }
        private static ClassicGraphicsRecovery.Observation Reset() {
            return new ClassicGraphicsRecovery.Observation {Handle=Handle,
                Bounds=new Rectangle(216,12,2128,1367),Client=new Size(2114,1353),
                Region=new Rectangle(0,0,4000,2560),Style=0x140F0000,Usable=true};
        }
        private static bool Poll(ClassicGraphicsRecovery p, ClassicGraphicsRecovery.Observation o, int seconds) {
            return p.Observe(o,"same-plan",Start.AddSeconds(seconds),true);
        }
        public static void Main() {
            Check(CompanionForm.GraphicsRecoveryEnabled,"test build gate must be enabled");
            string config = (string)typeof(CompanionForm).GetField("configPath",
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static).GetValue(null);
            string publicConfig = (string)typeof(CompanionForm).GetField("publicConfigPath",
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static).GetValue(null);
            Check(config != publicConfig && config.EndsWith("TestConfig.ini"),
                "graphics candidate settings must stay isolated from public and graininess preferences");
#if FOREVER_GRAPHICS_RECOVERY_TEST
            Check(CompanionForm.ForeverGraphicsRecoveryEnabled && !CompanionForm.RetailGraphicsRecoveryEnabled
                && CompanionForm.FullVersion.Contains("FOREVER GRAPHICS TEST 5"),"Forever candidate must be distinct");
#elif RETAIL_GRAPHICS_RECOVERY_TEST
            Check(CompanionForm.RetailGraphicsRecoveryEnabled && CompanionForm.FullVersion.Contains("RETAIL GRAPHICS TEST 4"),"Retail candidate must be distinct");
#else
            Check(!CompanionForm.RetailGraphicsRecoveryEnabled && CompanionForm.FullVersion.Contains("CLASSIC GRAPHICS TEST 3"),"Classic candidate must be distinct");
#endif
            Check(ClassicGraphicsRecovery.IsSupportedClient(@"D:\Games\_retail_",true),"Retail test scope");
            Check(!ClassicGraphicsRecovery.IsSupportedClient(@"C:\Games\_anniversary_",true),"Retail candidate excludes Classic");
            Check(!ClassicGraphicsRecovery.IsSupportedClient(@"D:\Games\_retail_",false),"Classic candidate excludes Retail");
            Check(ClassicGraphicsRecovery.IsSupportedClient(@"C:\Games\_FOREVER_\", ClassicGraphicsRecovery.ClientScope.Forever),"Forever path is case insensitive with trailing separator");
            foreach (var path in new string[] {@"C:\Games\_retail_",@"C:\Games\_anniversary_",@"C:\Games\_classic_era_",
                @"C:\Games\_classic_",@"C:\Games\_ptr_",@"C:\Games\_beta_",@"C:\Games\_forever_beta_",@"C:\Games\Wrath",null})
                Check(!ClassicGraphicsRecovery.IsSupportedClient(path, ClassicGraphicsRecovery.ClientScope.Forever),"Forever scope must not infer other clients");
            Check(!ClassicGraphicsRecovery.IsSupportedClient(@"C:\Games\_forever_",ClassicGraphicsRecovery.ClientScope.Retail),"Retail scope excludes Forever");
            Check(!ClassicGraphicsRecovery.IsSupportedClient(@"C:\Games\_forever_",ClassicGraphicsRecovery.ClientScope.Classic),"Classic scope excludes Forever");
            Check(!ClassicGraphicsRecovery.IsSupportedClient(@"C:\Games\_retail_",(ClassicGraphicsRecovery.ClientScope)99),"unknown scope cannot opt in");
            Check(!RenderResizeHandshake.Allowed(true) && RenderResizeHandshake.Allowed(false),
                "Classic candidate must exclude the inherited experimental nudge without changing normal builds");
            Check(ClassicGraphicsRecovery.IsClassicClient(@"C:\Games\_anniversary_"),"Anniversary scope");
            Check(ClassicGraphicsRecovery.IsClassicClient(@"C:\Games\_classic_era_\"),"Era scope");
            foreach (var path in new string[] {@"C:\Games\_retail_",@"C:\Games\_forever_",@"C:\Games\_classic_beta_",null})
                Check(!ClassicGraphicsRecovery.IsClassicClient(path),"exclude untested clients");
            var p=Policy(); var o=Reset();
            Check(!Poll(p,o,0) && !Poll(p,o,1),"wait for stable geometry");
            Check(Poll(p,o,2),"captured signature must recover");
            Check(p.InFlight && !Poll(p,o,10),"no second attempt while recovery is in flight");
            p=Policy(); o=Reset(); o.Bounds=Span; o.Client=Span.Size; o.Style=0x140B0000;
            Check(!Poll(p,o,0) && !Poll(p,o,8) && !p.Spent,"no writes to healthy span");
            p=Policy(); o=Reset(); o.Usable=false;
            Check(!Poll(p,o,0) && !Poll(p,o,10),"hung/minimized window must not recover");
            o.Usable=true; Check(!Poll(p,o,11) && Poll(p,o,13),"require settling again after unusable window");
            p=Policy(); o=Reset(); o.Handle=new IntPtr(456);
            Check(!Poll(p,o,0) && p.Spent,"recreated or different window disarms");
            p=Policy(); Check(!p.Observe(Reset(),"changed-plan",Start,true) && p.Spent,"display/role changes disarm");
            p=Policy(); Check(!p.Observe(Reset(),"same-plan",Start,false) && p.Spent,"paused monitoring disarms");
            p=Policy(); Check(!p.Observe(null,"same-plan",Start,true) && p.Spent,"unreadable window disarms");
            p=Policy(); o=Reset(); o.Region=Rectangle.Empty;
            Check(!Poll(p,o,0) && !Poll(p,o,2) && p.Spent,"ordinary restored window is not stale clipping");
            p=Policy(); o=Reset(); o.Style=0x140B0000;
            Check(!Poll(p,o,0) && !Poll(p,o,2),"borderless move must not recover");
            p=Policy(); o=Reset(); o.Client=new Size(1800,1200);
            Check(!Poll(p,o,0) && !Poll(p,o,2) && p.Spent,"manual resize must not recover");
            p=Policy(); o=Reset(); Check(!Poll(p,o,0),"first observation"); o.Bounds.Offset(1,0);
            Check(!Poll(p,o,2) && !Poll(p,o,3) && Poll(p,o,4),"changing geometry restarts settle delay");
            p=new ClassicGraphicsRecovery(Handle,Span,Span.Size,"same-plan");
            o=Reset(); Check(!Poll(p,o,0) && !Poll(p,o,2),"unknown pre-span client must not be guessed");
            p=new ClassicGraphicsRecovery(Handle,Span,new Size(2114,1353),"same-plan");
            Check(!Poll(p,Reset(),0) && !Poll(p,Reset(),2) && p.Spent && !p.Confirmed,
                "failed initial span cannot arm recovery from a transient successful readback");
            p=Policy(); o=Reset(); o.Bounds=new Rectangle(-1440,-1114,2114,1353); o.Client=new Size(2100,1339);
            Check(!Poll(p,o,0) && Poll(p,o,2),"captured outer-size fallback must tolerate nonclient border accounting");
            // A successful request must remain healthy throughout cooldown.
            p=Policy(); o=Reset(); Poll(p,o,0); Check(Poll(p,o,2),"first repeated-reset attempt");
            p.CompleteAttempt(true,Start.AddSeconds(3));
            var healthy=Reset(); healthy.Bounds=Span; healthy.Client=Span.Size; healthy.Style=0x140B0000;
            Check(!Poll(p,healthy,4) && p.Rearming && !p.Armed,"start post-recovery verification");
            Check(!Poll(p,healthy,8) && p.Rearming,"stable geometry cannot bypass cooldown");
            Check(!Poll(p,healthy,13) && p.Armed,"stable recovered span re-arms after cooldown");
            Check(!Poll(p,o,14) && Poll(p,o,16),"second reset recovers without manual span");
            p.CompleteAttempt(false,Start.AddSeconds(17));
            Check(p.Spent && !Poll(p,o,40),"native recovery failure must never auto-retry");

            p=Policy(); Poll(p,o,0); Poll(p,o,2); p.CompleteAttempt(true,Start.AddSeconds(3));
            Poll(p,healthy,4); Poll(p,o,10); Poll(p,healthy,12);
            Check(!Poll(p,healthy,15) && p.Rearming,"unstable span restarts healthy interval");
            Check(!Poll(p,healthy,16) && p.Armed,"continuous healthy interval required");

            p=Policy(); Poll(p,o,0); Poll(p,o,2); p.CompleteAttempt(true,Start.AddSeconds(3));
            Check(!Poll(p,o,24) && p.Spent && p.StopReason=="stability check failed",
                "an asynchronous reset after apparent success must stop instead of looping");
            p=Policy(); Poll(p,o,0); Poll(p,o,2); p.CompleteAttempt(true,Start.AddSeconds(3));
            Poll(p,healthy,4);
            Check(!Poll(p,healthy,24) && p.Spent,
                "a delayed callback cannot re-arm beyond the verification deadline");
            p=Policy(); Poll(p,o,0); Poll(p,o,2); p.CompleteAttempt(true,Start.AddSeconds(3));
            Check(!p.Observe(healthy,"same-plan",Start.AddSeconds(4),false) && p.Spent,
                "Pause during cooldown permanently cancels the arm");
            p=Policy(); Poll(p,o,0); Poll(p,o,2); p.CompleteAttempt(true,Start.AddSeconds(3));
            Check(!p.Observe(healthy,"different-plan",Start.AddSeconds(4),true) && p.Spent,
                "display changes during cooldown cancel recovery");
            p=Policy();
            for(int t=0;t<60;t+=20) {
                Check(!Poll(p,o,t) && Poll(p,o,t+2),"limited successful attempt");
                p.CompleteAttempt(true,Start.AddSeconds(t+3)); Poll(p,healthy,t+4); Poll(p,healthy,t+14);
                Check(p.Armed,"each accepted attempt must re-arm safely");
            }
            Check(!Poll(p,o,60) && !Poll(p,o,62) && p.Spent && p.StopReason=="attempt limit",
                "fourth automatic attempt within five minutes must latch off");
            Check(!Poll(p,o,600),"attempt-limit pause requires explicit manual action");
            p=Policy(); Poll(p,o,0); Poll(p,o,2); p.CompleteAttempt(true,Start.AddSeconds(3));
            Poll(p,healthy,4); Poll(p,healthy,14);
            Check(!Poll(p,o,302) && Poll(p,o,304),"attempt history expires after five minutes");
            Console.WriteLine("PASS: {0} client-scope recovery gate, exact captured signature, settling, cooldown/re-arm, rate-limit and ownership guards",count);
        }
    }
}
