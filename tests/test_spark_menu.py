"""Run Menu.luau's marked pure block (tab reveal schedule, badges, fingerprint, style
status text) in the official Luau CLI against the REAL shared ReplicatedStorage modules.

The block between "-- BEGIN PURE MENU" and "-- END PURE MENU" must not touch Roblox
globals: it is checked statically for engine names and then executed in the bare CLI
(where game/Instance/Enum/UDim2/... do not exist), so any engine access fails the run.
NOT TESTED: rendering, layout, touch/gamepad input, replication or live Studio state.

Usage: python tests/test_spark_menu.py [--luau PATH]
"""
from pathlib import Path
import argparse
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MENU = ROOT / "game/StarterPlayer/StarterPlayerScripts/Spark/Menu.luau"
SHARED = ["Config", "Profile", "Loadout", "Progression", "Cosmetics", "Trial"]
# Engine / client-only names the pure block must never reference.
FORBIDDEN = ["game", "workspace", "script", "Instance", "Enum", "UDim2", "UDim", "Color3", "Vector2", "Vector3",
             "CFrame", "TweenInfo", "GuiService", "TweenService", "Players", "task", "palette", "Ui", "make",
             "button", "label", "ctx", "self"]

CHECKS = r'''
local n=0
local function check(ok,message) n+=1; if not ok then error(message,2) end end
local function list(t) return table.concat(t,",") end
local function stateFor(p,extra)
    local d={profile=p,rank=Progression.rankProgress(p.xp),phase="Lobby"}
    for k,v in pairs(extra or {}) do d[k]=v end
    return d
end
local function tabs(p,extra) return list(Menu.visibleTabs(stateFor(p,extra))) end
-- Seen state that acknowledges everything currently on show (an opened tab).
local function ackAll(d)
    local seen={}
    for tab,set in pairs(Menu.attention(d)) do seen[tab]=set end
    return seen
end
check(game==nil and Instance==nil and Enum==nil and UDim2==nil,"Bare Luau CLI: no Roblox globals exist")

-- Reveal schedule ---------------------------------------------------------------
local fresh=Profile.new()
check(tabs(fresh)=="Album,Settings","Fresh profile -> Album+Settings, got "..tabs(fresh))
check(list(Menu.visibleTabs(nil))=="Album,Settings","nil state -> Album+Settings")
check(list(Menu.visibleTabs({}))=="Album,Settings","No profile -> Album+Settings")

local r1=Profile.new(); r1.rounds=1
check(tabs(r1)=="Play,Album,Settings","Round 1 without a record -> +Play only, got "..tabs(r1))
r1.records.meadow[1]=150
check(tabs(r1)=="Play,Album,Records,Settings","Round 1 with a record -> +Records, got "..tabs(r1))
local r1h=Profile.new(); r1h.rounds=1; r1h.records.aurora[4]=20
check(string.find(tabs(r1h),"Records",1,true)~=nil,"A record at any Heat reveals Records")
local r1t=Profile.new(); r1t.rounds=1
check(string.find(tabs(r1t,{trial={best=420}}),"Records",1,true)~=nil,"A Daily Stampede best reveals Records")
local r0=Profile.new(); r0.records.meadow[1]=150
check(string.find(tabs(r0),"Records",1,true)==nil,"Records needs at least one finished round")

local r2=Profile.new(); r2.rounds=2
check(string.find(tabs(r2),"Goals",1,true)==nil,"Goals hidden before round 3")
local r3=Profile.new(); r3.rounds=3
check(tabs(r3)=="Play,Goals,Album,Settings","Round 3 -> +Goals, got "..tabs(r3))

local cheapest=math.huge
for _,u in pairs(Config.Upgrades) do cheapest=math.min(cheapest,u.costs[1]) end
check(Menu.cheapestUpgrade()==cheapest,"Cheapest upgrade read from Config.Upgrades")
local c=Profile.new(); c.coins=cheapest-1
check(string.find(tabs(c),"Upgrades",1,true)==nil,"Upgrades hidden below the cheapest cost")
c.coins=cheapest
check(tabs(c)=="Album,Upgrades,Settings","Coins >= cheapest upgrade -> +Upgrades, got "..tabs(c))
local lv=Profile.new(); lv.upgrades.boots=1
check(string.find(tabs(lv),"Upgrades",1,true)~=nil,"Any upgrade level keeps Upgrades visible at 0 glow")

local s3=Profile.new(); s3.xp=Progression.xpFor(Menu.Reveal.styleRank)
check(tabs(s3)=="Album,Style,Settings","Rank "..Menu.Reveal.styleRank.." -> +Style, got "..tabs(s3))
local noRank=stateFor(s3); noRank.rank=nil
check(string.find(list(Menu.visibleTabs(noRank)),"Style",1,true)~=nil,"Rank falls back to profile XP")
local cheapestStyle=math.huge
for _,t in ipairs(Progression.Trails) do
    if t.price and not t.achievement and (t.rank or 0)<=2 then cheapestStyle=math.min(cheapestStyle,t.price) end
end
for _,item in ipairs(Cosmetics.Items) do
    if item.price and not item.achievement and (item.rank or 0)<=2 then cheapestStyle=math.min(cheapestStyle,item.price) end
end
local s2=Profile.new(); s2.xp=Progression.xpFor(2); s2.coins=cheapestStyle-1
check(string.find(tabs(s2),"Style",1,true)==nil,"Rank 2 without an affordable style -> no Style")
s2.coins=cheapestStyle
check(string.find(tabs(s2),"Style",1,true)~=nil,"First affordable trail/cosmetic -> +Style")
local owned=Profile.new(); owned.xp=Progression.xpFor(2)
for _,t in ipairs(Progression.Trails) do if t.price and not t.rank then owned.style.owned[t.id]=true; break end end
check(string.find(tabs(owned),"Style",1,true)~=nil,"An owned trail keeps Style visible at 0 glow")

local all=Profile.new(); all.rounds=3; all.coins=10^6; all.xp=Progression.xpFor(10); all.records.canyon[1]=900
check(tabs(all)==list(Menu.Tabs),"Everything revealed keeps Menu.Tabs order, got "..tabs(all))

-- Badges -------------------------------------------------------------------------
local fd=stateFor(fresh)
local freshNew=Menu.badges(fd,{})
check(freshNew.Album and freshNew.Settings and not freshNew.Play,"Never-opened visible tabs are NEW; hidden tabs never badge")
check(next(Menu.badges(fd,ackAll(fd)))==nil,"Fresh profile with everything acknowledged -> no badge")

local q=Profile.new(); q.rounds=3; q.totalBanked=3
local dq=stateFor(q)
check(Menu.badges(dq,ackAll(dq)).Goals==true,"Claimable milestone quest -> Goals badge (even when acknowledged)")
for _,quest in ipairs(Config.Quests) do q.quests[quest.id]=true end
check(Menu.badges(dq,ackAll(dq)).Goals==nil,"No claimables and acknowledged -> no Goals badge")
local hidden=Profile.new(); hidden.totalBanked=3
check(Menu.badges(stateFor(hidden),{}).Goals==nil,"Hidden Goals tab never badges, even with a claimable quest")

local g=Profile.new(); g.rounds=3
for _,quest in ipairs(Config.Quests) do g.quests[quest.id]=true end
local dailyId=Progression.DailyPool[1].id
local dailyTarget=Progression.DailyPool[1].target
g.daily={day=1,goals={dailyId},progress={[dailyId]=dailyTarget},claimed={},bonus=false}
local dg=stateFor(g)
check(Menu.badges(dg,ackAll(dg)).Goals==true,"Completed unclaimed daily goal -> Goals badge")
g.daily.claimed[dailyId]=true
check(Menu.badges(dg,ackAll(dg)).Goals==nil,"Claimed daily goal -> no Goals badge")
local weeklyId=Progression.WeeklyPool[1].id
g.weekly={week=1,goals={weeklyId},progress={[weeklyId]=Progression.WeeklyPool[1].target},claimed={}}
check(Menu.badges(dg,ackAll(dg)).Goals==true,"Completed unclaimed weekly goal -> Goals badge")
g.weekly.claimed[weeklyId]=true
g.daily={day=1,goals={Menu.TrialGoal},progress={},claimed={},bonus=false}
check(Menu.badges(dg,ackAll(dg)).Goals==nil,"Unfinished Daily Stampede goal -> no badge")
g.daily.progress[Menu.TrialGoal]=Menu.goalFor(Menu.TrialGoal).target
check(Menu.badges(dg,ackAll(dg)).Goals==true,"Finished Daily Stampede goal -> Goals badge")
check(Menu.goalFor(Menu.TrialGoal).name=="Finish today's Daily Stampede","d_trial display name")
check(Menu.goalFor(dailyId)==Progression.GoalById[dailyId],"Play goals come from Progression.GoalById")

local s=Profile.new(); s.rounds=3; s.xp=Progression.xpFor(Menu.Reveal.styleRank)
for _,t in ipairs(Progression.Trails) do if t.price then s.style.owned[t.id]=true end end
local cosmetic,second=nil,nil
for _,item in ipairs(Cosmetics.Items) do
    if item.price and not item.achievement and not item.rank then
        if not cosmetic or item.price<cosmetic.price then second=cosmetic; cosmetic=item
        elseif not second or item.price<second.price then second=item end
    end
end
check(cosmetic~=nil and second~=nil and second.price>cosmetic.price,"Catalog has two unranked priced cosmetics")
s.coins=cosmetic.price
local ds=stateFor(s)
local affordable=Menu.affordableStyles(s,Menu.rankOf(ds))
check(#affordable==1 and affordable[1]==cosmetic.id,"Only the cheapest cosmetic is affordable: "..list(affordable))
local seenS=ackAll(ds); seenS.Style={}
check(Menu.badges(ds,seenS).Style==true,"Affordable unowned cosmetic (not yet seen) -> Style badge")
local acknowledged=ackAll(ds)
check(Menu.badges(ds,acknowledged).Style==nil,"Affordable cosmetic already seen -> no badge")
s.coins=second.price
check(Menu.badges(ds,acknowledged).Style==true,"A newly affordable cosmetic badges Style again")
s.cosmetics.owned[cosmetic.id]=true; s.cosmetics.owned[second.id]=true; s.coins=0
check(#Menu.affordableStyles(s,Menu.rankOf(ds))==0,"Owned cosmetics are not affordable offers")

local nr=Profile.new(); nr.rounds=1
local nrBadges=Menu.badges(stateFor(nr),{Album={},Settings={}})
check(nrBadges.Play==true and nrBadges.Album==nil,"Newly revealed Play (never opened) -> badge")

local u=Profile.new(); u.coins=cheapest
local du=stateFor(u)
local seenU=ackAll(du)
check(Menu.badges(du,seenU).Upgrades==nil,"Acknowledged affordable upgrade -> no badge")
for key,upgrade in pairs(Config.Upgrades) do if upgrade.costs[1]==cheapest then u.upgrades[key]=1; u.coins=upgrade.costs[2]; break end end
check(Menu.badges(du,seenU).Upgrades==true,"Next upgrade level becoming affordable -> Upgrades badge")

local a=Profile.new(); a.rounds=1
local da=stateFor(a)
local seenA=ackAll(da)
a.album[Config.Creatures[1].id]=1
check(Menu.badges(da,seenA).Album==true,"A new species discovery -> Album badge")
local t=Profile.new(); t.rounds=1
local dt=stateFor(t,{trial={available=true,rewardedToday=false,day=20400}})
check(Menu.attention(dt).Play["trial:20400"]==true,"Unclaimed Daily Stampede reward -> Play attention key")
dt.trial.rewardedToday=true
check(Menu.attention(dt).Play["trial:20400"]==nil,"Claimed Daily Stampede reward -> no key")

-- Signatures, medals, volume, titles ------------------------------------------------
local thresholds=Menu.signatureThresholds()
if Config["SignatureStars"]==nil then check(list(thresholds)=="10,25,50","Default signature thresholds")
else check(list(thresholds)==list(Config["SignatureStars"]) and list(thresholds)=="10,25,50","Config signature thresholds (10/25/50) drive the album") end
check(Menu.signatureStars(nil)==0 and Menu.signatureStars(thresholds[1]-1)==0,"No stars below the first threshold")
for index,value in ipairs(thresholds) do check(Menu.signatureStars(value)==index,"Star "..index.." at "..value) end
check(Menu.starText(1,3)=="★☆☆" and Menu.starText(3,3)=="★★★","Star text")
check(Menu.medalWith(Trial.Medals.Silver,Trial.Medals)=="Silver" and Menu.medalWith(0,Trial.Medals)=="Unranked","Trial medal")
check(Menu.medalWith(Trial.Medals.Radiant,Trial.Medals)==Trial.medal(Trial.Medals.Radiant),"Menu medal agrees with Trial.medal")
check(Menu.medalWith(Config.Medals.Gold,nil)=="Gold","nil medal table falls back to Config.Medals")
check(Menu.stepVolume(0.6,1)==0.7 and Menu.stepVolume(0.6,-1)==0.5,"Volume steps by 0.1")
check(Menu.stepVolume(0.95,1)==1 and Menu.stepVolume(1,1)==1,"Volume clamps at 1")
check(Menu.stepVolume(0.05,-1)==0 and Menu.stepVolume(0,-1)==0,"Volume clamps at 0")
check(Menu.stepVolume(0/0,1)==0.1,"NaN volume treated as 0")
check(Menu.activeTitle(fresh)==nil,"No title by default")
local ti=Profile.new(); ti.achievements.stampede=true; ti.style.title="stampede"
local at=Menu.activeTitle(ti)
check(at and at.kind=="achievement" and at.name==Progression.AchievementById.stampede.title,"Achievement title active")
local rankTitle=Cosmetics.RankTitles[1]
ti.style.title=""; ti.xp=Progression.xpFor(rankTitle.rank); ti.cosmetics.title=rankTitle.id
at=Menu.activeTitle(ti)
check(at and at.kind=="rank" and at.name==rankTitle.name,"Rank title active")

-- Style status text ----------------------------------------------------------------
local sp=Profile.new()
local function first(pred) for _,item in ipairs(Cosmetics.Items) do if pred(item) then return item end end end
local ach=first(function(i) return i.achievement~=nil end)
local gated=first(function(i) return i.price and i.rank and i.rank>1 end)
local plain=first(function(i) return i.price and not i.rank end)
local free=first(function(i) return i.rank and not i.price and not i.achievement and not i.default end)
check(Menu.itemStatus(sp,1,plain,false,true).status=="EQUIPPED","Equipped status")
check(Menu.itemStatus(sp,1,plain,true,false).status=="OWNED (tap to equip)","Owned status")
check(Menu.itemStatus(sp,1,ach,false,false).status=="ACHIEVEMENT: "..Progression.AchievementById[ach.achievement].name,"Achievement status")
check(Menu.itemStatus(sp,1,gated,false,false).status=="RANK "..gated.rank.." • "..gated.price.." glow","Rank-gated price status")
check(Menu.itemStatus(sp,1,free,false,false).status=="FREE AT RANK "..free.rank,"Free-at-rank status")
sp.coins=plain.price
local buy=Menu.itemStatus(sp,1,plain,false,false)
check(buy.button=="BUY • "..plain.price.." GLOW" and buy.action=="buy","Affordable price button")
sp.coins=plain.price-1
local need=Menu.itemStatus(sp,1,plain,false,false)
check(need.action=="locked" and need.button=="NEED 1 MORE GLOW","Unaffordable shows the gap")

-- Fingerprint ----------------------------------------------------------------------
local fp=Profile.new(); fp.rounds=3
local fd2=stateFor(fp,{trial={available=true,best=0,runsToday=0,board={}},rally={remaining=30},remaining=80})
local base=Menu.fingerprint(fd2)
check(base~="" and Menu.fingerprint(fd2)==base,"Fingerprint is deterministic")
fd2.remaining=79; fd2.rally.remaining=29
check(Menu.fingerprint(fd2)==base,"Per-tick clocks do not trigger rebuilds")
local function changes(mutate,what)
    local before=Menu.fingerprint(fd2); mutate(); check(Menu.fingerprint(fd2)~=before,"Fingerprint tracks "..what)
end
changes(function() fp.cosmetics.burst="stars" end,"cosmetics")
changes(function() fp.settings.musicVolume=0.3 end,"volume settings")
changes(function() fp.settings.holdCatch=true end,"hold to catch")
changes(function() fd2.trial.best=900 end,"trial best")
changes(function() fd2.trial.runsToday=2 end,"trial runs")
changes(function() fd2.trial.board={{rank=1,name="A",score=900,userId=1}} end,"trial board size")
changes(function() fp.signatures.pip=3 end,"signatures")
changes(function() fp.daily.rerolled=true end,"daily reroll")
changes(function() fd2.mode="trial" end,"trial mode")
check(Menu.fingerprint({})=="" and Menu.fingerprint(nil)=="","No profile -> empty fingerprint")
print("PASS menu pure functions: "..n.." assertions (reveal schedule, badges, signatures, styles, fingerprint)")
'''


def strip_comments(code):
    return "\n".join(line.split("--", 1)[0] for line in code.splitlines())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", type=Path, default=ROOT / ".tools/luau/luau")
    args = parser.parse_args()
    source = MENU.read_text(encoding="utf-8")
    match = re.search(r"(?s)-- BEGIN PURE MENU[^\n]*\n(.*?)-- END PURE MENU", source)
    if not match:
        print("FAIL: Menu.luau has no BEGIN/END PURE MENU block")
        return 1
    block = match.group(1)
    code = strip_comments(re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', block))
    # A bare name not preceded by "." and not used as a table-constructor key ("button=").
    leaks = sorted({name for name in FORBIDDEN
                    if re.search(r"(?<![\w.])" + re.escape(name) + r"\b(?!\s*=(?!=))", code)})
    if leaks:
        print("FAIL: pure menu block references engine/client names: " + ", ".join(leaks))
        return 1
    # Luau resolves relative requires from the script's folder; build/ is gitignored.
    scratch_root = ROOT / "build"
    scratch_root.mkdir(exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix="spark-menu-", dir=scratch_root))
    try:
        header = "".join(f'local {name}=require("../../game/ReplicatedStorage/Spark/{name}")\n' for name in SHARED)
        path = directory / "menu_pure.luau"
        path.write_text(header + "local Menu={}\n" + block + "\n" + CHECKS, encoding="utf-8")
        result = subprocess.run([str(args.luau), str(path)], capture_output=True, text=True, timeout=60)
        print((result.stdout + result.stderr).strip())
        print("NOT TESTED: Roblox rendering, layout, touch/gamepad input, replication or live Studio behaviour")
        return result.returncode
    finally:
        shutil.rmtree(directory, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
