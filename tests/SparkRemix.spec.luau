-- Weekly Remix (plan §6.9.3): week -> remix determinism, bounded effects, and the A2
-- "each encounter once per round" property for every remix. Pure modules only.
local Remix=require("../game/ReplicatedStorage/Spark/Remix")
local Encounters=require("../game/ReplicatedStorage/Spark/Encounters")
local Loadout=require("../game/ReplicatedStorage/Spark/Loadout")
local Progression=require("../game/ReplicatedStorage/Spark/Progression")
local Profile=require("../game/ReplicatedStorage/Spark/Profile")
local n=0
local function check(ok,message) n+=1; if not ok then error(message,2) end end

-- Determinism and rotation ------------------------------------------------------------
check(#Remix.List==6,"Six remixes")
local seen={}
for week=2900,2905 do
	local r=Remix.forWeek(week)
	check(r==Remix.forWeek(week) and Remix.ById[r.id]==r,"Same week, same remix")
	check(Remix.forWeek(week+1)~=r,"Never the same remix twice in a row")
	seen[r.id]=true
end
local count=0; for _ in pairs(seen) do count+=1 end
check(count==6,"Every remix comes round once in six weeks")
-- 1970-01-05 (day 4) was a Monday: weeks start Monday 00:00 UTC, matching Progression.week.
check(Remix.week(4*86400)==1 and Remix.week(4*86400-1)==0,"Weeks start Monday 00:00 UTC")
for _,t in ipairs({0,4*86400,1793750400,1793750400+3*86400+5,4102444800}) do
	check(Remix.week(t)==Progression.week(t),"Same week index as weekly goals ("..t..")")
end
check(Remix.endsIn(4*86400)==7*86400 and Remix.endsIn(4*86400+60)==7*86400-60,"Countdown to the next Monday")
check(Remix.current(1793750400)==Remix.forWeek(Remix.week(1793750400)) and Remix.next(1793750400)==Remix.forWeek(Remix.week(1793750400)+1),"current/next")
for _,bad in ipairs({0/0,math.huge,-5,"x"}) do check(Remix.forWeek(bad)~=nil and Remix.current(bad)~=nil,"Bad input still yields a remix") end
local d=Remix.describe(Remix.List[1],4*86400)
check(d.id=="golden_rush" and d.name=="Golden Rush" and d.endsIn==7*86400 and Remix.describe(nil,0)==nil,"Public description")

-- Bounded effects ----------------------------------------------------------------------
local base=Loadout.stats({},{},0)
for _,remix in ipairs(Remix.List) do
	local s=Remix.apply(base,remix)
	check(s~=base and s.chainSeconds<=Remix.MaxChainSeconds and s.popPoints<=120,"Stats bounded ("..remix.id..")")
	check(s.capacity==base.capacity and s.captureRadius==base.captureRadius and s.dashCooldown==base.dashCooldown,"No power creep ("..remix.id..")")
end
check(Remix.apply(base,Remix.ById.rhythm_week).chainSeconds==base.chainSeconds+1,"Rhythm Week: chain +1 s")
check(Remix.apply(base,Remix.ById.fizz_festival).popPoints==base.popPoints*2 and Remix.ById.fizz_festival.staticsMinHeat==1,"Fizz Festival: pops x2, statics from Heat 1")
local maxed=Loadout.stats({magnet=3,pockets=3},{"rhythm","breaker"},5)
check(Remix.apply(maxed,Remix.ById.rhythm_week).chainSeconds<=12 and Remix.apply(maxed,Remix.ById.fizz_festival).popPoints<=120,"Caps hold on maxed builds")
check(base.chainSeconds==Loadout.stats({},{},0).chainSeconds,"Input stats never mutated")
check(Remix.apply(base,nil)==base and Remix.apply(nil,Remix.List[1])==nil,"Pass-through guards")
for players=1,4 do
	for biome=1,3 do
		local plain=Encounters.golden(90,biome,players)
		local rush=Encounters.golden(90,biome,players,Remix.ById.golden_rush)
		check(rush.count==plain.count+2 and rush.count<=Remix.MaxGoldens,"Golden Rush +2, bounded")
		check(Encounters.golden(90,biome,players,Remix.ById.big_herd).count==plain.count,"Other remixes leave goldens alone")
	end
end
check(Remix.ById.big_herd.extraSparks==6,"Big Herd: +6 Sparks")

-- A2: every remix keeps "each encounter once per round" ---------------------------------
local function dist(x1,z1,x2,z2) return math.sqrt((x1-x2)^2+(z1-z2)^2) end
for _,remix in ipairs(Remix.List) do
	for offset=0,960,120 do
		for biome=1,3 do
			local gate,runs,impacts=false,{},{}
			for step=0,1100 do
				local e=offset+step/10
				if Encounters.gate(e,biome).active then gate=true end
				local r=Encounters.stampede(e,biome,remix)
				if r.active then
					runs[r.cycle..":"..r.run]=true
					for x=-44,44,4 do check(Encounters.clearOfObstacles(biome,x,r.from.z,4.4),"Run lane clear of obstacles ("..remix.id..","..biome..")") end
				end
				local f=Encounters.starfall(e,biome,nil,remix)
				if f.warning then impacts[f.cycle..":"..f.impact]=true end
			end
			local nRuns,nImpacts=0,0
			for _ in pairs(runs) do nRuns+=1 end
			for _ in pairs(impacts) do nImpacts+=1 end
			local expectRuns=if biome==2 then 2 elseif remix.stampedeEverywhere then 1 else 0
			local expectImpacts=if biome==3 or remix.starfallEverywhere then Encounters.StarfallCount else 0
			check(nRuns==expectRuns,"Runs per round ("..remix.id..", arena "..biome..": "..nRuns..")")
			check(nImpacts==expectImpacts,"Starfall impacts per round ("..remix.id..", arena "..biome..": "..nImpacts..")")
			check(gate==(biome==1),"Gate stays meadow-only ("..remix.id..")")
		end
	end
end
-- Starfall spots stay fair in every arena (Starfall Everywhere).
for biome=1,3 do
	for i=1,200 do
		local cands={}
		for k=1,16 do cands[k]={x=math.sin(i*k+biome)*46,z=math.cos(i*k*0.7)*46} end
		local spot=Encounters.starfallSpot(cands,(i%5)/5,(i%9)/9,biome)
		check(dist(spot.x,spot.z,0,44)>=24-1e-6 and Encounters.clearOfObstacles(biome,spot.x,spot.z,1),"Starfall spot fair in arena "..biome)
	end
end

-- Weekly goals carry the Remix slot ------------------------------------------------------
local p=Profile.new()
Progression.ensureGoals(p,1793750400)
check(#p.weekly.goals==3 and p.weekly.goals[3]=="w_remix" and Progression.GoalById.w_remix.fixed,"Weekly goals: two picks + the Remix goal")
check(not table.find({p.weekly.goals[1],p.weekly.goals[2]},"w_remix"),"Remix goal never drawn twice")

print("PASS SparkRemix: "..n.." assertions (week rotation, bounded effects, A2 per remix; pure modules)")
