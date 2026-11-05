-- Daily Stampede: deterministic seeded plans, spawn/respawn fairness clearances,
-- normalized rules, score ceiling, XP cap, medals and run schedule. Pure modules;
-- the leaderboard/DataStore and live arena are not exercised here.
local Config=require("../game/ReplicatedStorage/Spark/Config")
local Loadout=require("../game/ReplicatedStorage/Spark/Loadout")
local Challenge=require("../game/ReplicatedStorage/Spark/Challenge")
local Trial=require("../game/ReplicatedStorage/Spark/Trial")
local n=0
local function check(ok,message) n+=1; if not ok then error(message,2) end end
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function deepEqual(a,b)
	if type(a)~=type(b) then return false end
	if type(a)~="table" then return a==b end
	for key,value in pairs(a) do if not deepEqual(value,b[key]) then return false end end
	for key in pairs(b) do if a[key]==nil then return false end end
	return true
end
local pools={}
for _,creature in ipairs(Config.Creatures) do
	pools[creature.biome]=pools[creature.biome] or {}
	pools[creature.biome][creature.id]=true
end
local ISLAND=26.163
local function staticClear(x,z,label)
	check(finite(x) and finite(z),label.." finite")
	local r=math.sqrt(x*x+z*z)
	check(r>=12-1e-9 and r<=42+1e-9,label.." radius 12..42 ("..r..")")
	check(math.sqrt(x*x+(z-44)^2)>=26-1e-9,label.." >=26 from bank")
	check(math.sqrt(x*x+(z-38)^2)>=10-1e-9,label.." >=10 from spawn")
	for _,sx in ipairs({-ISLAND,ISLAND}) do for _,sz in ipairs({-ISLAND,ISLAND}) do
		check(math.sqrt((x-sx)^2+(z-sz)^2)>=7-1e-9,label.." >=7 from steering island")
	end end
	check(math.abs(x*10-math.floor(x*10+0.5))<1e-6 and math.abs(z*10-math.floor(z*10+0.5))<1e-6,label.." on 0.1-stud grid")
end
local function verifyPlan(plan,label)
	check(#plan.spawns==Trial.SparkCount,label.." has 20 spawns")
	for i,spawn in ipairs(plan.spawns) do
		check(pools[plan.biome][spawn.species]==true,label.." species from plan biome")
		staticClear(spawn.x,spawn.z,label.." spawn "..i)
		for j=1,i-1 do
			local other=plan.spawns[j]
			check(math.sqrt((spawn.x-other.x)^2+(spawn.z-other.z)^2)>=4-1e-9,label.." spawns >=4 apart")
		end
	end
end
local TODAY=20762 -- 2026-11-05 UTC

-- Constants and day/seed ---------------------------------------------------------------
check(Trial.RunSeconds==75 and Trial.SparkCount==20 and Trial.FirstRunGlow==40 and Trial.FirstRunXp==80 and Trial.XpRunsPerDay==5,"Trial constants")
check(deepEqual(Trial.Medals,{Bronze=300,Silver=800,Gold=1600,Radiant=2800}),"Trial medals")
check(Trial.day(0)==0 and Trial.day(86399.999)==0 and Trial.day(86400)==1 and Trial.day(TODAY*86400+43200)==TODAY,"UTC day index")
check(Trial.day(1793836800)==TODAY and Trial.day(1793836799)==TODAY-1,"2026-11-05T00:00:00Z boundary")
for _,bad in ipairs({0/0,math.huge,-math.huge,"86400",nil,{},-5,-86400*3}) do
	check(Trial.day(bad)==0,"Bad/negative time -> day 0: "..tostring(bad))
end
local seeds={}
for day=0,999 do
	local seed=Trial.seed(day)
	check(finite(seed) and seed%1==0 and seed>=0 and seed<=0x7FFFFFFF,"31-bit seed")
	check(Trial.seed(day)==seed,"Seed deterministic")
	check(not seeds[seed],"Seeds distinct across 1000 days")
	seeds[seed]=true
end
check(Trial.seed(0/0)==Trial.seed(0) and Trial.seed("x")==Trial.seed(0) and Trial.seed(5.9)==Trial.seed(5),"Seed input sanitized")

-- Plan determinism -------------------------------------------------------------------------
for _,day in ipairs({0,1,2,TODAY,TODAY+1,99999}) do
	local a,b=Trial.plan(day),Trial.plan(day)
	check(a~=b and a.spawns~=b.spawns and a.spawns[1]~=b.spawns[1],"Plans are fresh tables")
	check(deepEqual(a,b),"Same day -> identical plan "..day)
	check(a.day==day and a.seed==Trial.seed(day) and a.biome==day%3+1,"Plan header "..day)
	check(a.biomeId==Config.Biomes[a.biome].id,"Plan biome id")
	check(a.goldenAt==50 and a.staticsFrom==15 and a.runAt==30,"Plan timings")
	a.spawns[1].x=999; a.spawns[2]=nil
	check(deepEqual(Trial.plan(day),b),"Mutating a plan never leaks into the next")
end
check(deepEqual(Trial.plan(0/0),Trial.plan(0)) and deepEqual(Trial.plan(TODAY+0.75),Trial.plan(TODAY)),"Plan day sanitized")
local today=Trial.plan(Trial.day(TODAY*86400+1)); local tonight=Trial.plan(Trial.day(TODAY*86400+86399))
check(deepEqual(today,tonight),"Every moment of a UTC day shares one plan")

-- 60 consecutive days: variety and biome cycle ---------------------------------------------
local encounters={"gate","stampede","starfall"}
local signatures,speciesSeen,previousBiome={}, {}, nil
for day=TODAY,TODAY+59 do
	local plan=Trial.plan(day)
	check(plan.biome==day%3+1 and plan.encounter==encounters[plan.biome],"Biome/encounter mapping")
	if previousBiome then check(plan.biome==previousBiome%3+1,"Biomes cycle 1,2,3") end
	previousBiome=plan.biome
	local parts,distinct={}, {}
	for _,spawn in ipairs(plan.spawns) do
		table.insert(parts,spawn.species..":"..spawn.x..","..spawn.z)
		distinct[spawn.species]=true
		speciesSeen[plan.biome]=speciesSeen[plan.biome] or {}
		speciesSeen[plan.biome][spawn.species]=true
	end
	local count=0; for _ in pairs(distinct) do count+=1 end
	check(count>=2,"A plan mixes species")
	local signature=table.concat(parts,"|")
	check(not signatures[signature],"Plans vary day to day")
	signatures[signature]=true
end
for biome=1,3 do
	local count=0; for _ in pairs(speciesSeen[biome]) do count+=1 end
	check(count==4,"Every species of biome "..biome.." appears within 60 days")
end

-- Clearances: 365 days x 20 spawns and 200 respawns ------------------------------------------
local respawnChecks=0
for day=TODAY,TODAY+364 do
	local plan=Trial.plan(day)
	verifyPlan(plan,"Day "..day)
	local positions={}
	for k=1,200 do
		local spawn=Trial.respawn(plan,k)
		assert(spawn,"Respawn exists")
		check(pools[plan.biome][spawn.species]==true,"Respawn species from biome")
		staticClear(spawn.x,spawn.z,"Respawn "..k)
		positions[spawn.x..","..spawn.z]=true
		respawnChecks+=1
	end
	local distinct=0; for _ in pairs(positions) do distinct+=1 end
	check(distinct>=150,"Respawns vary ("..distinct.."/200)")
end
local plan=Trial.plan(TODAY)
for k=1,50 do
	check(deepEqual(Trial.respawn(plan,k),Trial.respawn(Trial.plan(TODAY),k)),"Respawn deterministic per plan and k")
end
check(not deepEqual(Trial.respawn(plan,1),Trial.respawn(Trial.plan(TODAY+3),1)),"Respawns differ between days")
for _,bad in ipairs({0,-1,1.5,0/0,math.huge,"1",nil,2^31}) do
	check(Trial.respawn(plan,bad)==nil,"Invalid respawn index: "..tostring(bad))
end
for _,bad in ipairs({nil,"plan",{},{seed=1,biome=4},{seed=-1,biome=1},{seed=1.5,biome=1},{seed=2^31,biome=1},{seed=0/0,biome=2}}) do
	check(Trial.respawn(bad,1)==nil,"Invalid plan rejected")
end

-- Deterministic grid fallback (forced by disabling random candidates) ------------------------
local before=Trial.plan(TODAY)
Trial.PlacementAttempts=0
for day=TODAY,TODAY+29 do
	local forced=Trial.plan(day)
	verifyPlan(forced,"Fallback day "..day)
	check(deepEqual(forced,Trial.plan(day)),"Fallback deterministic")
	for k=1,20 do
		local spawn=Trial.respawn(forced,k); assert(spawn)
		staticClear(spawn.x,spawn.z,"Fallback respawn "..k)
	end
end
Trial.PlacementAttempts=48
check(deepEqual(Trial.plan(TODAY),before),"Default placement restored")

-- Normalized stats ---------------------------------------------------------------------------
local expected={heat=0,perks={},captureRadius=11.5,capacity=10,dashCooldown=2.3,captureCooldown=0.65,missLock=0,
	precisionFacing=0.7,chainSeconds=6,maxMultiplier=4,chainStep=5,dashCatchLimit=3,dashCatchRadius=4.5,haulCap=1.5,
	popPoints=40,zapScatter=2,herdMultiplier=1,goldenMultiplier=1,goldenCompass=false,dashBonus=20,staticCap=2,
	staticInterval=8,staticSpeed=8,sweepWarning=2,scoreMultiplier=1,medals={Bronze=300,Silver=800,Gold=1600,Radiant=2800}}
local stats=Trial.stats()
check(deepEqual(stats,expected),"Normalized stat values")
local loadoutCases={Loadout.stats({},{},0),Loadout.stats({boots=3,magnet=3,basket=3},{"reach","rhythm","slipstream"},5),
	Loadout.stats({boots=1},{"pockets","breaker","goldnose"},2),Loadout.stats({},{"gatekeeper","quickpaws"},4)}
for index,loadout in ipairs(loadoutCases) do
	for key in pairs(loadout) do check(stats[key]~=nil,"Trial.stats has Loadout key "..key.." (case "..index..")") end
	for key in pairs(stats) do check(loadout[key]~=nil,"Trial.stats adds no unknown key "..key) end
end
check(not deepEqual(Loadout.stats({boots=3,magnet=3,basket=3},{"reach"},5),stats),"Progression would change live stats")
check(deepEqual(Trial.stats({boots=3,magnet=3,basket=3},{"reach","rhythm"},5),stats),"Arguments (upgrades/perks/heat) are ignored")
local mutated=Trial.stats()
mutated.captureRadius=99; table.insert(mutated.perks,"reach"); mutated.medals.Gold=1
check(deepEqual(Trial.stats(),expected),"Each stats() is a fresh table")
check(Trial.Medals.Gold==1600,"Mutating stats().medals never touches Trial.Medals")
local challenge=Challenge.new(1,nil,Trial.stats())
check(challenge.rules.maxMultiplier==4 and challenge.rules.chainStep==5 and challenge.rules.haulCap==1.5
	and deepEqual(challenge.rules.medals,Trial.Medals),"Challenge accepts normalized rules and trial medals")

-- Score ceiling ---------------------------------------------------------------------------------
local cap=Trial.maxScore()
check(finite(cap) and cap%1==0 and cap==Trial.maxScore(),"Finite integer ceiling")
check(cap>4000 and cap<1000000,"Ceiling above any plausible expert score and below Challenge's hard cap")
-- Superhuman bot through the real Challenge rules: every 0.6s precise dash-timed
-- catch of the richest species, 3 dash catches per cooldown, 2 pops per 8s, golden
-- at 50s, banks at capacity (finale after 50s). Must still fit under the ceiling.
local bot=Challenge.new(1,nil,Trial.stats())
local id=0
local function catch(t,data) id+=1; data.captureId=id; local ok=Challenge.capture(bot,t,data); check(ok,"Bot catch accepted") end
for step=0,7500 do
	local t=step/100
	if step%60==0 then catch(t,{distance=1,facing=1,value=16,dashAge=0.1,starter=false}) end
	if step%230==0 then for m=1,3 do catch(t,{distance=2,facing=1,value=16,starter=false,kind="dash",multiIndex=m}) end end
	if step%400==0 then check(Challenge.award(bot,t,"pop"),"Bot pop") end
	if step==5000 then catch(t,{distance=1,facing=1,value=16,starter=false,kind="golden"}) end
	if bot.pendingCount>=10 then Challenge.bank(bot,t,{finale=t>=50}) end
end
Challenge.bank(bot,75,{finale=true})
local final=Challenge.finish(bot,75)
check(final.score>4000 and final.score<=cap,"Superhuman bot "..final.score.." under ceiling "..cap)
check(Trial.validScore(final.score),"Bot score valid")
check(Trial.validScore(0) and Trial.validScore(2800) and Trial.validScore(cap),"Valid scores")
for _,bad in ipairs({0/0,math.huge,-math.huge,-1,1.5,cap+1,"100",nil,true,{}}) do
	check(not Trial.validScore(bad),"Invalid score rejected: "..tostring(bad))
end

-- XP ---------------------------------------------------------------------------------------------
check(Trial.xpFor(0,1)==20 and Trial.xpFor(100,1)==40 and Trial.xpFor(400,5)==60 and Trial.xpFor(2,3)==22,"XP curve floor(2*sqrt)+20")
local total=0
for run=1,12 do total+=Trial.xpFor(900,run) end
check(total==5*80,"Only the first 5 runs per day pay XP")
for _,bad in ipairs({0,6,-1,1.5,0/0,math.huge,"1",nil}) do check(Trial.xpFor(400,bad)==0,"Bad run index: "..tostring(bad)) end
for _,bad in ipairs({-1,0/0,math.huge,1.5,cap+1,"400",nil}) do check(Trial.xpFor(bad,1)==0,"Bad score: "..tostring(bad)) end
check(Trial.xpFor(cap,1)==math.floor(2*math.sqrt(cap))+20,"XP bounded at ceiling")

-- Medals ------------------------------------------------------------------------------------------
local ladder={{0,"Unranked"},{299,"Unranked"},{300,"Bronze"},{799,"Bronze"},{800,"Silver"},{1599,"Silver"},
	{1600,"Gold"},{2799,"Gold"},{2800,"Radiant"},{cap,"Radiant"}}
for _,row in ipairs(ladder) do check(Trial.medal(row[1])==row[2],"Medal at "..row[1]) end
for _,bad in ipairs({0/0,math.huge,nil,"3000",-5}) do check(Trial.medal(bad)=="Unranked","Bad medal input: "..tostring(bad)) end
check(Trial.medal(-math.huge)=="Unranked","Negative infinity unranked")

-- Schedule -----------------------------------------------------------------------------------------
local s=Trial.schedule(0,plan)
check(not s.golden and not s.runActive and not s.runWarning and not s.staticsActive and not s.finished and s.remaining==75,"Start state")
check(s.encounter==plan.encounter,"Schedule echoes encounter")
check(not Trial.schedule(14.999,plan).staticsActive and Trial.schedule(15,plan).staticsActive,"Statics boundary")
check(not Trial.schedule(26.999,plan).runWarning and Trial.schedule(27,plan).runWarning and not Trial.schedule(27,plan).runActive,"Run telegraph")
check(not Trial.schedule(29.999,plan).runActive and Trial.schedule(30,plan).runActive and not Trial.schedule(30,plan).runWarning,"Run start boundary")
check(Trial.schedule(34.999,plan).runActive and not Trial.schedule(35,plan).runActive,"Five-second run window")
check(Trial.schedule(30,plan).runProgress==0 and math.abs(Trial.schedule(32.5,plan).runProgress-0.5)<1e-9 and Trial.schedule(40,plan).runProgress==0,"Run progress")
check(not Trial.schedule(49.999,plan).golden and Trial.schedule(50,plan).golden,"Golden boundary")
local late=Trial.schedule(74.999,plan)
check(not late.finished and math.abs(late.remaining-0.001)<1e-9 and late.staticsActive and late.golden,"Final moment")
local done=Trial.schedule(75,plan)
check(done.finished and done.remaining==0 and not done.staticsActive and not done.runActive and done.golden,"Finish boundary")
check(Trial.schedule(500,plan).remaining==0 and Trial.schedule(500,plan).finished,"Overtime clamps")
for _,bad in ipairs({0/0,math.huge,-math.huge,-3,"10",nil}) do
	local safe=Trial.schedule(bad,plan)
	check(not safe.finished and safe.remaining==75 and not safe.golden and safe.elapsed==0,"Bad elapsed is a fresh run: "..tostring(bad))
end
check(Trial.schedule(50,nil).golden and Trial.schedule(30,"x").runActive and Trial.schedule(31,nil).encounter==nil,"Missing plan uses defaults")
local custom={goldenAt=10,staticsFrom=5,runAt=60,encounter="stampede"}
check(Trial.schedule(10,custom).golden and Trial.schedule(5,custom).staticsActive and Trial.schedule(61,custom).runActive
	and not Trial.schedule(30,custom).runActive,"Plan timings honored")
check(Trial.schedule(50,{goldenAt=0/0}).golden and not Trial.schedule(49,{goldenAt=-1}).golden
	and not Trial.schedule(49,{goldenAt=1e9}).golden,"Invalid plan timings fall back")

print(string.format("PASS SparkTrial: %d assertions (pure seeded plans over 365 days, %d respawns, normalized rules; ceiling %d, bot %d; no DataStore/arena)",
	n,respawnChecks,cap,final.score))
