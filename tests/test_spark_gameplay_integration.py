"""Exercise exact Main loop-claim/bank/settlement functions in offline Luau (WP-04).

Engine objects, scheduling and transport are doubles. Real production Rules,
Challenge, Profile, Loop and LoopService run with the extracted orchestrator
(handleLoop, take, bank, settleRound), not a rewritten transaction. This is not
multiplayer engine, physics or persistence proof.

Ported in WP-04 from the capture/dash-through version: button capture, dash-sweep
catches, gate herding and the dash practice line were removed by the loop redesign;
their cases are replaced by loop equivalents (contention, overflow, starters,
bank tiers, buzzer, finale, signatures, settlement).
"""
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PRELUDE = r"""
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
local Cosmetics=require("./Cosmetics")
local Remix=require("./Remix")
local Loop=require("./Loop")
local GroundMap=require("./GroundMap")
local LoopService=require("./LoopService")
local DesignTuning=require("./Design/Tuning")
local DesignCreatures=require("./Design/Creatures")
local Slice=require("./Design/Slice")
local LOOP_T=Loop.tuning(DesignTuning)
local loops=LoopService.new(Loop,LOOP_T,{rate=3})
local currentRemix={}
local Players={}
local Feedback={FireClient=function() end}
local arenaEpoch=0
local now=1
local os={clock=function() return now end,time=function() return 1000 end}
local vector={}
vector.__index=function(v,key)
    if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    if key=="Unit" then return setmetatable({X=v.X/v.Magnitude,Y=v.Y/v.Magnitude,Z=v.Z/v.Magnitude},vector) end
end
vector.__sub=function(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z},vector) end
vector.__add=function(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},vector) end
vector.__mul=function(a,b) if type(a)=="number" then a,b=b,a end return setmetatable({X=a.X*b,Y=a.Y*b,Z=a.Z*b},vector) end
local Vector3={new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vector) end}
local CFrame={new=function(...) return {...} end}
local world={arenas={{bank=Vector3.new(0,0,58),origin=Vector3.new(0,0,0),ground=GroundMap.flat("meadow"),
    bankRings={{id="south_gate",x=0,z=58,r=5,position=Vector3.new(0,6,58)}}}}}
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
local SLICE_FIXED=true
local function statsFor(s)
    local st=Loadout.stats({},{},0); st.capacity=DesignTuning.parade.capacity; st.medals=DesignTuning.scoring.medalsProvisional
    return st
end
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
local function feedback(_,kind,message,_,_,extra) table.insert(messages,{kind=kind,message=message,extra=extra}) end
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
    local s={ready=true,phase="Playing",started=0,endsAt=110,fullRound=true,cycleIndex=0,roundsAtStart=5,
        biome=1,score=0,carry={},buckets={},metrics={},roundCatches=0,exploit={malformed=0},
        profile=Profile.new(),motion={},suspiciousUntil=0,revision=0,loop=LoopService.session()}
    s.challenge=Challenge.new(1,nil,stats(s))
    return s
end
-- A creature standing still at (x, z) with a 0.5 s history at the current herd clock.
local function target(id,x,owner,z,def)
    local model={destroyed=false,Destroy=function(self) assert(not self.destroyed);self.destroyed=true end}
    local c={id=id,position=Vector3.new(x,0,z or 0),biome=1,def=def or Config.Creatures[1],model=model,
        starterOwner=owner,index=1,history={}}
    LoopService.pushHistory(c.history,now-0.1,x,z or 0,0,true)
    LoopService.pushHistory(c.history,now,x,z or 0,0,true)
    herd[id]=c
    return c
end
-- A validated claim: a ring of radius r around (cx, cz), as the client draws it.
local function ring(r,cx,cz)
    local poly={}
    for i=0,23 do local a=i*math.pi/12; poly[i+1]={x=(cx or 0)+r*math.cos(a),z=(cz or 0)+r*math.sin(a),g=0} end
    return {poly=poly,kind="snap",viewClock=now,arrivedAt=now,herdArrived=now}
end
local count=0
local function test(name,callback)
    herd={};delayed={};messages={};sessions={};rallies={ArenaRally.new(0)};now=1;spawned={};staticModels={};recorded={}
    callback(); count+=1; print("PASS "..name)
end
"""
CASES = r"""
local function loop(p,s,claim,area) handleLoop(p,s,claim or ring(6),now,area or 500) end
test("two contenders cannot duplicate a single creature; the second gets an ASSIST",function()
    local a,b=player(1),player(2);local sa,sb=session(),session();sessions[a]=sa;sessions[b]=sb
    local c=target(1,2)
    loop(a,sa);loop(b,sb)
    assert(c.claimed and c.model.destroyed and herd[1]==nil)
    assert(#sa.carry==1 and #sb.carry==0 and sa.challenge.captures==1 and sb.challenge.captures==0)
    assert(sb.challenge.assists==1,"second claimant credited")
    assert(#delayed==1,"one respawn scheduled")
    bank(a,sa,true);bank(b,sb,true)
    assert(sa.profile.totalBanked==1 and sb.profile.totalBanked==0)
end)
test("one loop catches a pod in pop order and scores once on the server",function()
    local p,s=player(1),session()
    target(1,0,nil,0);target(2,2,nil,1);target(3,-2,nil,-1)
    loop(p,s)
    assert(#s.carry==3 and s.challenge.loops==1 and s.challenge.score==29,"first Pip pod = 29 ("..s.challenge.score..")")
    local result
    for _,m in ipairs(messages) do if m.kind=="Loop" then result=m.extra end end
    assert(result and #result.caught==3 and result.points==29 and result.multiplier==2)
    assert(result.caught[3].creatureId==1,"nearest the centroid pops last")
end)
test("techniques come from server data: SNAP from arrival times, TIGHT from the server area",function()
    local p,s=player(1),session()
    target(1,0);target(2,1,nil,1);target(3,-1,nil,-1)
    s.lastDashAt=now-0.2
    loop(p,s,nil,100)
    assert(s.challenge.score==43,"SNAP + TIGHT pod = 43 ("..s.challenge.score..")")
    local q,t=player(2),session()
    target(4,0);target(5,1,nil,1);target(6,-1,nil,-1)
    t.lastDashAt=now-2
    loop(q,t,nil,500)
    assert(t.challenge.score==29,"no SNAP (stale dash) and no TIGHT (large server area)")
end)
test("an empty loop costs nothing and keeps the chain",function()
    local p,s=player(1),session()
    target(1,0);target(2,1);target(3,-1)
    loop(p,s)
    local links=s.challenge.links
    now=2;loop(p,s,ring(6,40,40))
    assert(s.challenge.links==links and s.challenge.score==29 and #s.carry==3)
end)
test("overflow scores half and is released; the parade keeps capacity",function()
    local p,s=player(1),session()
    for i=1,10 do table.insert(s.carry,"pip") end
    for i=1,5 do target(i,i-3) end
    loop(p,s)
    assert(#s.carry==12,"kept up to capacity ("..#s.carry..")")
    local result
    for _,m in ipairs(messages) do if m.kind=="Loop" then result=m.extra end end
    assert(result.overflow==3 and result.points==48,"overflow_two_of_five style scoring ("..tostring(result.points)..")")
    for id=1,5 do assert(herd[id]==nil,"every ringed creature is consumed") end
end)
test("private onboarding remains owner-only",function()
    local p,s=player(1),session();s.starterRemaining=2
    local foreign=target(1,1,2);local own=target(2,2,1)
    loop(p,s)
    assert(not foreign.claimed and own.claimed and #delayed==0,"starters never respawn")
    assert(s.starterRemaining==1 and #s.carry==1)
end)
test("bank tiers through the ring; repeat bank cannot duplicate",function()
    local p,s=player(1),session()
    for i=1,4 do target(i,i-2) end
    loop(p,s)
    local before=s.challenge.score
    now=3;s.bankRing="south_gate";bank(p,s,false)
    local banked=s.challenge.score-before
    assert(banked==math.floor(4*3*1.25+0.5),"4 carried -> x1.25 ("..banked..")")
    local revision=s.revision
    bank(p,s,false);bank(p,s,true)
    assert(s.revision==revision and s.profile.totalBanked==4 and s.parade=="")
    local last
    for _,m in ipairs(messages) do if m.kind=="Bank" then last=m.extra end end
    assert(last.ring=="south_gate" and last.multiplier==1.25)
end)
test("buzzer auto-banks at x1.0 and settles once",function()
    local p,s=player(1),session();s.challengeBiome=1
    for i=1,4 do target(i,i-2) end
    loop(p,s)
    local loopScore=s.challenge.score
    now=110;assert(settleRound(p,s,now))
    assert(s.phase=="Results" and s.challenge.finished and s.profile.totalBanked==4)
    assert(s.challenge.score==loopScore+12,"auto-bank pays carried values x1.0")
    local score,coins,revision=s.challenge.score,s.profile.coins,s.revision
    now=111;assert(not settleRound(p,s,now))
    assert(s.challenge.score==score and s.profile.coins==coins and s.revision==revision)
end)
test("finale loops score x1.5",function()
    local p,s=player(1),session()
    now=90;target(1,0);target(2,1);target(3,-1)
    loop(p,s)
    assert(s.challenge.score==43,"finale pod: 9 x 1.6 x 2 x 1.5 = 43.2 -> 43 ("..s.challenge.score..")")
end)
test("golden catches carry the gilded mark and never respawn",function()
    local p,s=player(1),session()
    local c=target(1,2);c.golden=true;c.extra=true
    loop(p,s)
    assert(s.carry[1]=="*pip" and s.challenge.golden==1 and #delayed==0)
    bank(p,s,true)
    assert(s.profile.gilded.pip and s.profile.album.pip==1)
end)
test("settlement applies long-term progression exactly once",function()
    local p,s=player(1),session();s.challengeBiome=1;s.roundHeat=0
    for i=1,3 do target(i,i-2) end
    loop(p,s)
    now=110;assert(settleRound(p,s,now))
    local xp=s.profile.xp
    assert(xp>0 and s.lastResult and #recorded==1)
    now=111;settleRound(p,s,now)
    assert(s.profile.xp==xp and #recorded==1)
end)
test("a round with fewer than three catches gives no round credit",function()
    local p,s=player(1),session();s.challengeBiome=1;s.roundHeat=0
    target(1,0);target(2,1)
    loop(p,s)
    now=110;assert(settleRound(p,s,now))
    assert(s.profile.rounds==0 and s.lastResult.incomplete and s.profile.totalBanked==2)
end)
test("two idle rounds switch a player to sit out; a loop counts as activity",function()
    local p,s=player(1),session();s.challengeBiome=1
    now=110;settleRound(p,s,now);assert(s.idleRounds==1 and not s.sitOut)
    s.phase="Playing";s.endsAt=230;s.started=120;s.active=false;s.cycleIndex=1
    now=230;settleRound(p,s,now);assert(s.idleRounds==2 and s.sitOut)
    s.phase="Playing";s.endsAt=350;s.started=240;s.active=false;s.cycleIndex=2;s.sitOut=false;s.idleRounds=1
    s.challenge=Challenge.new(2,nil,stats(s))
    now=241;target(9,2);loop(p,s)
    now=350;settleRound(p,s,now);assert(s.idleRounds==0 and not s.sitOut)
end)
test("warm-up loops bank glow only and roll straight into the next full round",function()
    local p,s=player(1),session();s.phase="Warmup";s.endsAt=120;s.fullRound=false;s.starterIssued=true
    now=112;target(1,2);loop(p,s)
    assert(#s.carry==1)
    now=120;assert(settleRound(p,s,now))
    assert(s.phase=="Playing" and s.fullRound and s.profile.rounds==0 and s.profile.totalBanked==1)
end)
test("species signatures map onto loop techniques and fill album stars",function()
    local p,s=player(1),session()
    -- Bunvolt's signature is DASH -> SNAP.
    local bunvolt=species.bunvolt
    target(1,0,nil,0,bunvolt)
    s.lastDashAt=now
    loop(p,s,nil,500)
    assert(s.challenge.signatures==1 and s.profile.signatures.bunvolt==1,"SNAP fills the DASH signature")
end)
test("slice: sweeps are cut and statics are off",function()
    local p,s=player(1),session();s.profile.totalBanked=5;s.hazardStarted=0;s.roundsAtStart=3
    assert(not hazardFor(s,27).visible and not hazardFor(s,60).active,"no sweeps")
    assert(not Slice.on("static_puff"),"Static Puff is off in the slice")
end)
print("SparkGameplayIntegration: "..count.." exact production-function cases passed (engine dependencies mocked)")
"""


def extract(source: str, start: str, end: str) -> str:
    assert source.count(start) == source.count(end) == 1, "Missing/ambiguous production boundaries: " + start
    return start + source.split(start, 1)[1].split(end, 1)[0]


def main() -> None:
    source = (ROOT / "game/ServerScriptService/Spark/Main.server.luau").read_text(encoding="utf-8")
    blocks = extract(source, "-- BEGIN PURE LIFECYCLE", "-- END PURE LIFECYCLE")
    blocks += extract(source, "local function creatureBase(entry)", "local function rootOf(player)")
    blocks += extract(source, "local function roundPlaying(s,now)", "local function objective(")
    blocks += extract(source, "local function hintOnce(player,s,id,text)", "local function teleport(player,s)")
    blocks += extract(source, "local function bank(player,s,automatic)", "-- options (all server-owned): def, position, golden, extra")
    blocks += extract(source, "-- BEGIN CATCH TRANSACTIONS", "-- END CATCH TRANSACTIONS")
    with tempfile.TemporaryDirectory(prefix="spark-gameplay-") as directory:
        folder = Path(directory)
        for name in ("Config", "Profile", "Challenge", "Rules", "ArenaRally", "ArenaEvents", "Loadout", "Encounters",
                     "Progression", "Cycle", "Cosmetics", "Remix", "Trial", "Loop", "GroundMap"):
            shutil.copyfile(ROOT / f"game/ReplicatedStorage/Spark/{name}.luau", folder / f"{name}.luau")
        shutil.copyfile(ROOT / "game/ServerScriptService/Spark/LoopService.luau", folder / "LoopService.luau")
        shutil.copytree(ROOT / "game/ReplicatedStorage/Spark/Design", folder / "Design")
        script = folder / "gameplay.spec.luau"
        script.write_text(PRELUDE + blocks + CASES, encoding="utf-8")
        result = subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], cwd=ROOT, timeout=30)
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
