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
local Vector3={new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vector) end}
local world={arenas={{bank=Vector3.new(0,0,0)}}}
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
local function capacity(s) return Config.MaxCarry+s.profile.upgrades.basket*2 end
local function parade(_,s) s.parade=table.concat(s.carry,",") end
local function metric(_,s,name) s.metrics[name]=s.metrics[name] or now end
local function feedback(_,kind,message) table.insert(messages,{kind=kind,message=message}) end
local function send(_,s) s.sent=(s.sent or 0)+1 end
local function clearStarters(userId)
    for id,c in pairs(herd) do if c.starterOwner==userId then c.model:Destroy(); herd[id]=nil end end
end
local function teleport(_,s) s.motion={dashStarted=nil}; s.teleported=true end
local function issueStarters(_,s) s.starterRemaining=Rules.issueStarters(s,s.profile.totalBanked) end
local function spawnCreature() end
local function player(id)
    return {UserId=id,root={Position=Vector3.new(0,0,0),CFrame={LookVector=Vector3.new(1,0,0)}}}
end
local function session()
    return {ready=true,phase="Playing",started=0,biome=1,score=0,carry={},buckets={},metrics={},
        profile=Profile.new(),challenge=Challenge.new(1),motion={},suspiciousUntil=0,revision=0}
end
local function target(id,x,owner)
    local model={destroyed=false,Destroy=function(self) assert(not self.destroyed);self.destroyed=true end}
    local c={id=id,position=Vector3.new(x,0,0),biome=1,def=Config.Creatures[1],model=model,
        starterOwner=owner,index=1}
    herd[id]=c
    return c
end
local count=0
local function test(name,callback)
    herd={};delayed={};messages={};sessions={};rallies={ArenaRally.new(0)};now=1
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
    beginRound(p,s)
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
print("SparkGameplayIntegration: "..count.." exact production-function cases passed (engine dependencies mocked)")
'''


def extract(source: str, start: str, end: str) -> str:
    assert source.count(start) == source.count(end) == 1, "Missing/ambiguous production boundaries"
    return start + source.split(start, 1)[1].split(end, 1)[0]


def main() -> None:
    source = (ROOT / "game/ServerScriptService/Spark/Main.server.luau").read_text(encoding="utf-8")
    blocks = extract(source, "-- BEGIN PURE LIFECYCLE", "-- END PURE LIFECYCLE")
    blocks += extract(source, "local function roundPlaying(s,now)", "local function objective(")
    blocks += extract(source, "local function bank(player,s,automatic)", "local function spawnCreature(")
    blocks += extract(source, "local function capture(player,s)", "local function haltForLease(")
    with tempfile.TemporaryDirectory(prefix="spark-gameplay-") as directory:
        folder = Path(directory)
        for name in ("Config", "Profile", "Challenge", "Rules", "Targeting", "ArenaRally"):
            shutil.copyfile(ROOT / f"game/ReplicatedStorage/Spark/{name}.luau", folder / f"{name}.luau")
        script = folder / "gameplay.spec.luau"
        script.write_text(PRELUDE + blocks + CASES, encoding="utf-8")
        result = subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], cwd=ROOT, timeout=15)
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
