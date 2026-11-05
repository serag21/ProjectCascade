"""Exercise exact Main capture/bank/replay functions in offline Luau.

Engine objects, scheduling and transport are doubles. Real production Rules,
Challenge and Profile run with the extracted orchestrator, not a rewritten
transaction. This is not multiplayer engine, physics or persistence proof.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PRELUDE = r'''
local Config=require("./Config")
local Profile=require("./Profile")
local Challenge=require("./Challenge")
local Rules=require("./Rules")
local ArenaRally=require("./ArenaRally")
local ArenaEvents=require("./ArenaEvents")
local Loadout=require("./Loadout")
local Encounters=require("./Encounters")
local Progression=require("./Progression")
local Cycle=require("./Cycle")
local arenaEpoch=0
local Targeting=require("./Targeting")
local now=1
local os={clock=function() return now end,time=function() return 1000 end}
local vector={}
vector.__index=function(v,key)
    if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    if key=="Unit" then return setmetatable({X=v.X/v.Magnitude,Y=v.Y/v.Magnitude,Z=v.Z/v.Magnitude},vector) end
    if key=="Dot" then return function(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
vector.__sub=function(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z},vector) end
vector.__add=function(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},vector) end
vector.__mul=function(a,b) if type(a)=="number" then a,b=b,a end return setmetatable({X=a.X*b,Y=a.Y*b,Z=a.Z*b},vector) end
local Vector3={new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vector) end}
local CFrame={new=function(...) return {...} end}
local world={arenas={{bank=Vector3.new(0,0,0),origin=Vector3.new(0,0,0)}}}
local species={}
for _,def in ipairs(Config.Creatures) do species[def.id]=def end
local random={NextNumber=function(_,a,b) return (a+b)/2 end}
local staticModels={}
local World={static=function(_,owner)
    local m={owner=owner,destroyed=false,PivotTo=function() end,Destroy=function(self) assert(not self.destroyed);self.destroyed=true end}
    table.insert(staticModels,m); return m end}
local staticsFolder={}
local clearPersonal,onRoundRecorded
local recorded={}
onRoundRecorded=function(_,_,summary,result) table.insert(recorded,{summary=summary,result=result}) end
local function economy() end
local function arenaClock() return now-arenaEpoch end
local function statsFor(s) return Loadout.stats(s.profile.upgrades,s.profile.loadout,s.profile.heat) end
local function stats(s) if not s.stats then s.stats=statsFor(s) end return s.stats end
local herd={}
local lifecycle={closing=false}
local rallies={ArenaRally.new(0)}
local sessions={}
local persistence={leaseDeadline=function() return 2000 end}
local delayed={}
local task={delay=function(_,callback) table.insert(delayed,callback) end}
local messages={}
local function xyz(v) return {x=v.X,y=v.Y,z=v.Z} end
local function rootOf(player) return player.root,{Health=100} end
local function validApproach(_,s) return s.approach~=false end
local function capacity(s) return stats(s).capacity end
local function parade(_,s) s.parade=table.concat(s.carry,",") end
local function metric(_,s,name) s.metrics[name]=s.metrics[name] or now end
local function feedback(_,kind,message) table.insert(messages,{kind=kind,message=message}) end
local function send(_,s) s.sent=(s.sent or 0)+1 end
local function clearStarters(userId)
    for id,c in pairs(herd) do if c.starterOwner==userId then c.model:Destroy(); herd[id]=nil end end
end
local function teleport(_,s) s.motion={dashStarted=nil}; s.teleported=true end
local function issueStarters(_,s) s.starterRemaining=Rules.issueStarters(s,s.profile.totalBanked) end
local spawned={}
local function spawnCreature(biome,index,starter,options) table.insert(spawned,{biome=biome,index=index,options=options}) end
local function player(id)
    return {UserId=id,DisplayName="P"..id,root={Position=Vector3.new(0,0,0),CFrame={LookVector=Vector3.new(1,0,0)}}}
end
local function session()
    return {ready=true,phase="Playing",started=0,endsAt=110,fullRound=true,cycleIndex=0,roundsAtStart=5,
        biome=1,score=0,carry={},buckets={},metrics={},roundCatches=0,
        profile=Profile.new(),challenge=Challenge.new(1),motion={},suspiciousUntil=0,revision=0}
end
local function target(id,x,owner,z)
    local model={destroyed=false,Destroy=function(self) assert(not self.destroyed);self.destroyed=true end}
    local c={id=id,position=Vector3.new(x,0,z or 0),biome=1,def=Config.Creatures[1],model=model,
        starterOwner=owner,index=1}
    herd[id]=c
    return c
end
local count=0
local function test(name,callback)
    herd={};delayed={};messages={};sessions={};rallies={ArenaRally.new(0)};now=1;spawned={};staticModels={};recorded={}
    callback(); count+=1; print("PASS "..name)
end
'''
CASES = r'''
test("two contenders cannot duplicate a single creature or its score",function()
    local a,b=player(1),player(2);local sa,sb=session(),session()
    local c=target(1,2)
    capture(a,sa);capture(b,sb)
    assert(c.claimed and c.model.destroyed and herd[1]==nil)
    assert(#sa.carry==1 and #sb.carry==0 and sa.challenge.captures==1 and sb.challenge.captures==0)
    assert(#delayed==1 and sb.challenge.misses==1)
    bank(a,sa,true);bank(b,sb,true)
    assert(sa.profile.totalBanked==1 and sa.profile.coins==3 and sa.challenge.score==31)
    assert(sb.profile.totalBanked==0 and sb.profile.coins==0 and sb.challenge.score==0)
end)
test("repeat bank cannot duplicate collection, glow, skill or save revisions",function()
    local p,s=player(1),session();target(1,2);capture(p,s)
    bank(p,s,false);local revision=s.revision
    bank(p,s,true);bank(p,s,false)
    assert(s.profile.coins==3 and s.profile.album.pip==1 and s.challenge.score==31)
    assert(s.revision==revision and s.parade=="")
end)
test("full pack prompts banking without destroying a target or a chain",function()
    local p,s=player(1),session()
    for i=1,8 do now=i;target(i,2);capture(p,s) end
    assert(#s.carry==8 and s.challenge.bestChain==8)
    local bonus=s.challenge.pendingBonus;local c=target(99,2)
    now=10;capture(p,s)
    assert(not c.claimed and not c.model.destroyed and s.challenge.misses==0)
    assert(s.challenge.pendingBonus==bonus and #delayed==8)
end)
test("miss breaks style but recovery banking retains collection and base",function()
    local p,s=player(1),session();target(1,2);capture(p,s)
    now=2;capture(p,s)
    assert(s.challenge.pendingBonus==0 and #s.carry==1)
    now=3;target(2,2);capture(p,s);bank(p,s,true)
    assert(s.challenge.score==47 and s.profile.coins==6 and s.profile.totalBanked==2)
end)
test("private onboarding remains owner-only and cannot award mastery",function()
    local p,s=player(1),session();s.starterRemaining=2
    local foreign=target(1,1,2);local own=target(2,2,1)
    capture(p,s);bank(p,s,true)
    assert(not foreign.claimed and own.claimed and #delayed==0)
    assert(s.profile.totalBanked==1 and s.challenge.captures==0 and s.challenge.score==0)
    assert(s.starterRemaining==1)
end)
test("cooldown denies a second capture without false miss or deletion",function()
    local p,s=player(1),session();target(1,2);capture(p,s)
    local c=target(2,2);now=1.64;capture(p,s)
    assert(#s.carry==1 and not c.claimed and s.challenge.misses==0)
    now=1.66;capture(p,s)
    assert(#s.carry==2 and s.challenge.captures==2)
end)
test("invalid movement cannot claim or bank from remote position",function()
    local p,s=player(1),session();local c=target(1,2);s.approach=false
    capture(p,s);assert(not c.claimed and #s.carry==0)
    s.approach=true;now=2;capture(p,s);s.approach=false
    bank(p,s,false);assert(#s.carry==1 and s.profile.coins==0)
    bank(p,s,true);assert(#s.carry==0 and s.profile.coins==3)
end)
test("results and hazard interruption reject catches",function()
    local p,s=player(1),session();local c=target(1,2)
    s.phase="Results";capture(p,s);assert(not c.claimed)
    s.phase="Playing";s.hazardUntil=2;capture(p,s);assert(not c.claimed)
    now=2;capture(p,s);assert(c.claimed and s.challenge.captures==1)
end)
test("replay resets only ephemeral round state and never refills starters",function()
    local p,s=player(1),session();s.starterIssued=true;s.profile.coins=72;s.profile.rounds=2
    s.profile.mastery.bestScore=100;s.profile.album.pip=8;s.challenge=Challenge.new(2)
    s.challenge.score=100;s.phase="Results";s.newPersonalBest=true
    beginRound(p,s,Cycle.fullRound(now))
    assert(s.phase=="Playing" and s.challenge.score==0 and s.challenge.roundIndex==3)
    assert(s.profile.coins==72 and s.profile.mastery.bestScore==100 and s.profile.album.pip==8)
    assert(s.starterRemaining==0 and not s.newPersonalBest and s.teleported)
end)
test("exact deadline denies captures and manual bank before heartbeat settles phase",function()
    local p,s=player(1),session();target(1,2);capture(p,s)
    local c=target(2,2);now=110;capture(p,s);bank(p,s,false)
    assert(s.phase=="Playing" and not roundPlaying(s,now))
    assert(not c.claimed and #s.carry==1 and s.profile.coins==0 and s.challenge.misses==0)
    bank(p,s,true)
    assert(#s.carry==0 and s.profile.coins==3 and s.challenge.score==31)
end)
test("late onboarding unlock starts a fresh warning timeline",function()
    local p,s=player(1),session();s.profile.totalBanked=2
    now=28;target(1,2);capture(p,s);bank(p,s,false)
    assert(s.profile.totalBanked==3 and s.hazardStarted==28)
    assert(not hazardFor(s,28).visible and not hazardFor(s,52.99).visible)
    assert(hazardFor(s,53).warning and not hazardFor(s,54.99).active)
    assert(hazardFor(s,55).active and not hazardFor(s,110).visible)
end)
test("two ordinary bank contributors receive rally once without skill inflation",function()
    local a,b=player(1),player(2);local sa,sb=session(),session();sessions[a]=sa;sessions[b]=sb
    for i=1,3 do now=i;target(i,2);capture(a,sa) end
    now=4;bank(a,sa,false);local skillA=sa.challenge.score
    assert(sa.profile.coins==12 and rallies[1].total==3)
    for i=4,6 do now=i+1;target(i,2);capture(b,sb) end
    now=8;bank(b,sb,false)
    assert(rallies[1].complete and sa.profile.coins==20 and sb.profile.coins==20)
    assert(sa.challenge.score==skillA and sa.challenge.score==sb.challenge.score)
    bank(a,sa,false);bank(b,sb,false)
    assert(sa.profile.coins==20 and sb.profile.coins==20)
end)
test("automatic banking never contributes to shared rally",function()
    local p,s=player(1),session();sessions[p]=s
    for i=1,6 do now=i;target(i,2);capture(p,s) end
    now=7;bank(p,s,true)
    assert(s.profile.totalBanked==6 and s.profile.coins==24 and rallies[1].total==0)
end)
test("onboarding glow cannot complete a shared rally",function()
    local p,s=player(1),session();sessions[p]=s;s.starterRemaining=3
    for i=1,3 do now=i;target(i,2,1);capture(p,s) end
    now=4;bank(p,s,false)
    assert(s.profile.coins==12 and s.challenge.score==0 and rallies[1].total==0)
end)
test("round settlement banks and records once before any post-deadline hazard",function()
    local p,s=player(1),session();s.challengeBiome=1
    for i=1,3 do now=i;target(i,2);capture(p,s) end
    now=109.999;assert(not settleRound(p,s,now) and s.phase=="Playing")
    now=110;assert(settleRound(p,s,now))
    assert(s.phase=="Results" and s.profile.rounds==1 and s.challenge.finished)
    assert(s.profile.totalBanked==3 and s.profile.mastery.precision==3 and s.profile.mastery.completed==1)
    assert(s.profile.mastery.lastRecordedRound==1 and not hazardFor(s,now).active)
    local score,coins,revision=s.challenge.score,s.profile.coins,s.revision
    now=111;assert(not settleRound(p,s,now))
    assert(s.challenge.score==score and s.profile.coins==coins and s.revision==revision)
    assert(s.profile.mastery.precision==3 and s.profile.rounds==1)
end)
test("expired lease or inactive teammate cannot collect shared completion reward",function()
    local a,b=player(1),player(2);local sa,sb=session(),session();sessions[a]=sa;sessions[b]=sb
    for i=1,3 do now=i;target(i,2);capture(a,sa) end
    bank(a,sa,false);sa.phase="Results"
    for i=4,6 do now=i;target(i,2);capture(b,sb) end
    local previous=persistence.leaseDeadline
    persistence.leaseDeadline=function() return 999 end
    now=7;bank(b,sb,false);persistence.leaseDeadline=previous
    assert(rallies[1].complete and sa.profile.coins==12 and sb.profile.coins==12)
end)

test("dash-through claims path-ordered sparks up to the limit and capacity",function()
    local p,s=player(1),session();sessions[p]=s
    s.challenge=Challenge.new(1,nil,stats(s))
    local far=target(3,6);local mid=target(2,4);local near=target(1,2);local off=target(4,4,nil,9)
    s.dashSweep={last={x=0,y=0,z=0},untilT=5,caught=0}
    p.root.Position=Vector3.new(8,0,0)
    assert(dashSweep(p,s,p.root,now)==2)
    assert(near.claimed and mid.claimed and not far.claimed and not off.claimed)
    assert(#s.carry==2 and s.challenge.multiCatches==1 and s.challenge.dashCatches==2 and #delayed==2)
    assert(dashSweep(p,s,p.root,now)==0 and not far.claimed,"Limit holds for the rest of the dash")
    now=6;assert(dashSweep(p,s,p.root,now)==0 and s.dashSweep==nil,"Window ends")
end)
test("dash-through respects capacity, hazard lock and invalid rounds",function()
    local p,s=player(1),session()
    s.challenge=Challenge.new(1,nil,stats(s))
    for i=1,8 do table.insert(s.carry,"pip") end
    local c=target(1,2)
    s.dashSweep={last={x=0,y=0,z=0},untilT=5,caught=0};p.root.Position=Vector3.new(4,0,0)
    assert(dashSweep(p,s,p.root,now)==0 and not c.claimed,"Full parade")
    s.carry={};s.hazardUntil=now+1
    assert(dashSweep(p,s,p.root,now)==0 and not c.claimed,"Zap lock")
    s.hazardUntil=0;s.phase="Results"
    assert(dashSweep(p,s,p.root,now)==0 and not c.claimed and s.dashSweep==nil,"Not playing")
end)
test("a zap scatters carried sparks back into the arena without touching saved progress",function()
    local p,s=player(1),session();s.profile.totalBanked=5;s.profile.coins=40
    for i=1,3 do now=i;target(i,2);capture(p,s) end
    local revision=s.revision
    now=4;hit(p,s,now,Vector3.new(2,0,0),"ZAP")
    assert(#s.carry==1 and #spawned==2 and s.parade=="pip")
    for _,entry in ipairs(spawned) do assert(entry.options.extra and entry.options.def.id=="pip" and entry.index==nil) end
    assert(s.challenge.pendingCount==1 and s.challenge.pendingBonus==0 and s.challenge.zaps==1 and s.challenge.scattered==2)
    assert(s.profile.coins==40 and s.profile.totalBanked==5 and s.revision==revision)
    assert(s.hazardUntil==now+.8 and s.zapImmuneUntil==now+1.5)
    now=5;bank(p,s,true);assert(s.profile.totalBanked==6 and s.profile.coins==43)
end)
test("buzzer forfeits carried style at settlement but banks base points and glow",function()
    local p,s=player(1),session();s.challengeBiome=1
    target(1,2);capture(p,s)
    assert(s.challenge.pendingBonus>0)
    now=110;assert(settleRound(p,s,now))
    assert(s.challenge.buzzerLost>0 and s.challenge.score==16 and s.profile.coins==3)
end)
test("finale bank bonus applies only to manual banks in the last 25 seconds",function()
    local p,s=player(1),session()
    now=90;target(1,2);capture(p,s);bank(p,s,false)
    assert(s.challenge.finaleBanks==1 and s.challenge.score==math.floor(31*1.25))
    local q,t=player(2),session()
    now=50;target(2,2);capture(q,t);bank(q,t,false)
    assert(t.challenge.finaleBanks==0 and t.challenge.score==31)
end)
test("golden catches bank triple glow and a gilded album mark",function()
    local p,s=player(1),session();sessions[p]=s
    local c=target(1,2);c.golden=true;c.extra=true
    capture(p,s)
    assert(s.carry[1]=="*pip" and s.challenge.golden==1 and #delayed==0,"Golden is an extra: no respawn")
    bank(p,s,true)
    assert(s.profile.coins==9 and s.profile.gilded.pip and s.profile.album.pip==1)
end)
test("herded sparks join the herder's parade and credit only a recent flanker",function()
    local a,b,c=player(1),player(2),player(3);local sa,sb,sc=session(),session(),session()
    sessions[a]=sa;sessions[b]=sb;sessions[c]=sc
    local spark=target(1,20);spark.spookedBy=1;spark.spookedAt=now;spark.assistBy=2;spark.assistAt=now-1
    claim(a,sa,spark,"herd",{distance=0,facing=1},nil)
    assert(sa.challenge.herded==1 and #sa.carry==1 and sb.challenge.assists==1 and sc.challenge.assists==0)
    local stale=target(2,20);stale.spookedBy=1;stale.spookedAt=now;stale.assistBy=3;stale.assistAt=now-5
    claim(a,sa,stale,"herd",{distance=0,facing=1},nil)
    assert(sc.challenge.assists==0,"Stale flank earns nothing")
    sb.phase="Results";local third=target(3,20);third.spookedBy=2;third.spookedAt=now
    claim(a,sa,third,"herd",{distance=0,facing=1},nil)
    assert(sb.challenge.assists==1,"Finished teammate cannot earn assists")
end)
test("personal statics spawn only after eligibility, pop on dash, zap otherwise",function()
    local p,s=player(1),session();sessions[p]=s
    s.challenge=Challenge.new(1,nil,stats(s))
    s.hazardStarted=0;s.profile.totalBanked=2;now=30
    updateStatics(p,s,p.root,now,0.1);assert(#staticModels==0,"Onboarding players have no statics")
    s.profile.totalBanked=3;now=20
    updateStatics(p,s,p.root,now,0.1);assert(#staticModels==0,"Grace period")
    now=30;updateStatics(p,s,p.root,now,0.1)
    assert(#staticModels==1 and s.staticCount==1 and staticModels[1].owner==1)
    updateStatics(p,s,p.root,now+.1,0.1);assert(#staticModels==1,"Cap 1 at heat 0")
    local _,static=next(s.statics);static.pos={x=1,z=0}
    s.motion={dashUntil=now+0.3};target(9,2);capture(p,s)
    updateStatics(p,s,p.root,now+.2,0.1)
    assert(s.challenge.pops==1 and s.staticCount==0 and staticModels[1].destroyed)
    now=40;s.motion={};updateStatics(p,s,p.root,now,0.1)
    local _,second=next(s.statics);second.pos={x=0.5,z=0}
    updateStatics(p,s,p.root,now+.1,0.1)
    assert(s.challenge.zaps==1 and s.staticCount==0)
    now=55;updateStatics(p,s,p.root,now,0.1);local _,old=next(s.statics);assert(old)
    updateStatics(p,s,p.root,now+12.5,0.1);assert(s.staticCount<=1 and old.model.destroyed,"Statics fizzle after 12s")
end)
test("round start locks heat to unlocked tiers and sanitizes the loadout",function()
    local p,s=player(1),session();s.phase="Results";s.profile.heat=5;s.profile.loadout={"goldnose","reach"};s.starterIssued=true
    beginRound(p,s,Cycle.fullRound(now))
    assert(s.profile.heat==0 and s.roundHeat==0 and #s.profile.loadout==0 and s.challenge.rules.maxMultiplier==4)
    s.phase="Results";s.profile.xp=Progression.xpFor(14);s.profile.loadout={"goldnose","reach"}
    s.profile.records.meadow[1]=Config.Medals.Silver;s.profile.heat=1
    beginRound(p,s,Cycle.fullRound(now))
    assert(s.profile.heat==1 and s.roundHeat==1 and #s.profile.loadout==2 and s.challenge.rules.scoreMultiplier==1.2)
end)
test("settlement applies long-term progression exactly once",function()
    local p,s=player(1),session();s.challengeBiome=1;s.roundHeat=0
    for i=1,3 do now=i;target(i,2);capture(p,s) end
    now=110;assert(settleRound(p,s,now))
    local xp=s.profile.xp
    assert(xp>0 and s.lastResult and s.lastResult.xp==Progression.roundXp(s.challenge.score) and #recorded==1)
    assert(s.profile.records.meadow[1]==s.challenge.score and s.profile.progressReceipt==1)
    now=111;settleRound(p,s,now)
    assert(s.profile.xp==xp and #recorded==1)
end)

test("warm-up catches bank glow only and roll straight into the next full round",function()
    local p,s=player(1),session();s.phase="Warmup";s.endsAt=120;s.fullRound=false;s.starterIssued=true
    now=112;target(1,2);capture(p,s)
    assert(#s.carry==1,"Warm-up allows catching")
    now=113;bank(p,s,false)
    assert(s.profile.coins==3 and s.challenge.score==0 and rallies[1].total==0,"Warm-up glow, no skill or rally")
    now=120;assert(settleRound(p,s,now))
    assert(s.phase=="Playing" and s.fullRound and s.endsAt==120+Cycle.Play and s.profile.rounds==0,"Full round starts; no round credit for warm-up")
    assert(not hazardFor(s,121).visible,"No hazard at round start")
end)
test("a round with fewer than three catches gives no round credit or XP",function()
    local p,s=player(1),session();s.challengeBiome=1;s.roundHeat=0
    for i=1,2 do now=i;target(i,2);capture(p,s) end
    now=110;assert(settleRound(p,s,now))
    assert(s.phase=="Results" and s.profile.rounds==0 and s.profile.xp==0 and s.lastResult.incomplete,"Incomplete round")
    assert(s.profile.coins==6 and s.profile.totalBanked==2,"Glow and album still banked")
    assert(s.resultsUntil==Cycle.Length,"Results last until the next cycle start")
end)
test("two idle rounds switch a player to sit out; activity resets the count",function()
    local p,s=player(1),session();s.challengeBiome=1
    now=110;settleRound(p,s,now);assert(s.idleRounds==1 and not s.sitOut)
    s.phase="Playing";s.endsAt=230;s.started=120;s.active=false;s.cycleIndex=1
    now=230;settleRound(p,s,now);assert(s.idleRounds==2 and s.sitOut,"Second idle round sits the player out")
    s.phase="Playing";s.endsAt=350;s.started=240;s.active=false;s.cycleIndex=2;s.sitOut=false;s.idleRounds=1
    now=241;target(9,2);capture(p,s)
    now=350;settleRound(p,s,now);assert(s.idleRounds==0 and not s.sitOut,"Catching counts as activity")
end)
test("partial rounds earn XP and goals but never write score records",function()
    local p,s=player(1),session();s.challengeBiome=1;s.roundHeat=0;s.fullRound=false
    for i=1,4 do now=40+i;target(i,2);capture(p,s) end
    now=110;assert(settleRound(p,s,now))
    assert(s.profile.rounds==1 and s.profile.xp>0,"Partial round credit")
    assert(s.profile.records.meadow[1]==0 and s.profile.mastery.bestScore==0 and not s.lastResult.newRecord and not s.lastResult.full,"No records from partial rounds")
end)
test("catching a Spark another player was chasing gives that player a teamwork assist",function()
    local a,b=player(1),player(2);local sa,sb=session(),session();sessions[a]=sa;sessions[b]=sb
    local spark=target(1,2);spark.spookedBy=1;spark.spookedAt=now
    a.root.Position=Vector3.new(6,0,0)
    capture(b,sb)
    assert(spark.claimed and #sb.carry==1 and sa.challenge.assists==1 and sa.challenge.pendingBonus==15,"Chaser credited")
    local far=target(2,2);far.spookedBy=1;far.spookedAt=now;a.root.Position=Vector3.new(30,0,0)
    now=2;capture(b,sb);assert(sa.challenge.assists==1,"Too far away: no assist")
    local stale=target(3,2);stale.spookedBy=1;stale.spookedAt=now-3;a.root.Position=Vector3.new(4,0,0)
    now=3;capture(b,sb);assert(sa.challenge.assists==1,"Stale chase: no assist")
end)
test("new players meet sweeps in round two and statics in round three",function()
    local p,s=player(1),session();s.profile.totalBanked=5;s.hazardStarted=0;s.roundsAtStart=0
    s.challenge=Challenge.new(1,nil,stats(s))
    assert(not hazardFor(s,27).visible,"Round 1: no sweep")
    now=30;updateStatics(p,s,p.root,now,0.1);assert(#staticModels==0,"Round 1: no statics")
    s.roundsAtStart=1;assert(hazardFor(s,27).active,"Round 2: sweeps")
    updateStatics(p,s,p.root,now,0.1);assert(#staticModels==0,"Round 2: still no statics")
    s.roundsAtStart=2;updateStatics(p,s,p.root,now+0.1,0.1);assert(#staticModels==1,"Round 3: statics")
end)
print("SparkGameplayIntegration: "..count.." exact production-function cases passed (engine dependencies mocked)")
'''


def extract(source: str, start: str, end: str) -> str:
    assert source.count(start) == source.count(end) == 1, "Missing/ambiguous production boundaries"
    return start + source.split(start, 1)[1].split(end, 1)[0]


def main() -> None:
    source = (ROOT / "game/ServerScriptService/Spark/Main.server.luau").read_text(encoding="utf-8")
    blocks = extract(source, "-- BEGIN PURE LIFECYCLE", "-- END PURE LIFECYCLE")
    blocks += extract(source, "local function creatureBase(entry)", "local function rootOf(player)")
    blocks += extract(source, "local function roundPlaying(s,now)", "local function objective(")
    blocks += extract(source, "local function bank(player,s,automatic)", "local function spawnCreature(")
    blocks += extract(source, "-- BEGIN CATCH TRANSACTIONS", "-- END CATCH TRANSACTIONS")
    with tempfile.TemporaryDirectory(prefix="spark-gameplay-") as directory:
        folder = Path(directory)
        for name in ("Config", "Profile", "Challenge", "Rules", "Targeting", "ArenaRally", "ArenaEvents", "Loadout", "Encounters", "Progression", "Cycle"):
            shutil.copyfile(ROOT / f"game/ReplicatedStorage/Spark/{name}.luau", folder / f"{name}.luau")
        script = folder / "gameplay.spec.luau"
        script.write_text(PRELUDE + blocks + CASES, encoding="utf-8")
        result = subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], cwd=ROOT, timeout=15)
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
