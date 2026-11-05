-- Mastery depth v2: perks/heat stats, Challenge v2 scoring, dash-through geometry
-- and encounter schedules. Pure production modules; no engine, physics or rendering.
local Config=require("../game/ReplicatedStorage/Spark/Config")
local Loadout=require("../game/ReplicatedStorage/Spark/Loadout")
local Challenge=require("../game/ReplicatedStorage/Spark/Challenge")
local Targeting=require("../game/ReplicatedStorage/Spark/Targeting")
local Encounters=require("../game/ReplicatedStorage/Spark/Encounters")
local n=0
local function check(ok,message) n+=1; if not ok then error(message,2) end end
local function near(a,b,message) check(math.abs(a-b)<1e-6,message.." ("..tostring(a).." vs "..tostring(b)..")") end

-- Loadout: slots, sanitization, unlocks -------------------------------------
check(Loadout.slots(1)==0 and Loadout.slots(2)==2 and Loadout.slots(14)==2 and Loadout.slots(15)==3 and Loadout.slots(0/0)==0,"Slot ladder")
check(#Loadout.sanitize({"reach","rhythm"},1)==0,"No perks before rank 2")
local l=Loadout.sanitize({"reach","reach","bogus",5,"rhythm","slipstream"},4)
check(#l==2 and l[1]=="reach" and l[2]=="rhythm","Dedupe, unknown removal, slot cap")
check(#Loadout.sanitize({"goldnose"},13)==0 and #Loadout.sanitize({"goldnose"},14)==1,"Rank gates")
check(#Loadout.sanitize({"reach","rhythm","slipstream"},15)==3,"Third slot")
check(#Loadout.sanitize("reach",50)==0 and #Loadout.sanitize(nil,50)==0,"Malformed loadout")
local seen={}
for _,perk in ipairs(Loadout.Perks) do
	check(not seen[perk.id] and type(perk.up)=="string" and type(perk.down)=="string" and perk.rank>=2,"Perk metadata "..perk.id)
	seen[perk.id]=true
end

-- Every perk changes at least one stat favourably and one unfavourably.
local base=Loadout.stats({boots=0,magnet=0,basket=0},{},0)
check(base.captureRadius==10 and base.capacity==8 and base.dashCooldown==3 and base.chainSeconds==6
	and base.maxMultiplier==4 and base.scoreMultiplier==1 and base.staticCap==1 and base.zapScatter==2,"Baseline stats")
local better={captureRadius=1,capacity=1,chainSeconds=1,dashCatchLimit=1,dashCatchRadius=1,popPoints=1,herdMultiplier=1,goldenMultiplier=1}
local worse={precisionFacing=1,maxMultiplier=-1,dashCooldown=1,haulCap=-1,zapScatter=1,captureRadius=-1,missLock=1,dashBonus=-1}
for _,perk in ipairs(Loadout.Perks) do
	local s=Loadout.stats({},{perk.id},0)
	local up,down=false,false
	for key,sign in pairs(better) do if (s[key]-base[key])*sign>0 then up=true end end
	if perk.id=="quickpaws" and s.captureCooldown<base.captureCooldown then up=true end
	if perk.id=="goldnose" and s.goldenCompass then up=true end
	for key,sign in pairs(worse) do if (s[key]-base[key])*sign>0 then down=true end end
	check(up and down,"Perk "..perk.id.." is a side-grade")
end
-- Upgrades still matter and stack with perks.
local maxed=Loadout.stats({boots=3,magnet=3,basket=3},{"reach","pockets"},0)
near(maxed.captureRadius,10+4.5+2.5,"Radius stack"); check(maxed.capacity==8+6+4,"Capacity stack")
near(maxed.dashCooldown,3-1.05,"Boots")
-- Heat is monotonic in difficulty and bounded in reward.
local previous=nil
for heat=0,5 do
	local s=Loadout.stats({},{},heat)
	check(s.heat==heat,"Heat stored")
	if previous then
		check(s.captureRadius<=previous.captureRadius and s.chainSeconds<=previous.chainSeconds and s.staticCap>=previous.staticCap
			and s.zapScatter>=previous.zapScatter and s.staticSpeed>=previous.staticSpeed and s.sweepWarning<=previous.sweepWarning
			and s.scoreMultiplier>previous.scoreMultiplier,"Heat "..heat.." harder and better rewarded")
	end
	check(s.staticSpeed<Config.WalkSpeed,"Statics always slower than walking")
	check(s.chainSeconds>=2 and s.captureRadius>=5,"Playable floors")
	previous=s
end
near(Loadout.stats({},{},5).scoreMultiplier,2,"Heat 5 multiplier"); check(Loadout.stats({},{},99).heat==5 and Loadout.stats({},{},-3).heat==0,"Heat clamp")
check(Loadout.stats({},{"rhythm"},5).chainSeconds==6,"Rhythm offsets two heat steps")
-- Heat unlock ladder.
local records={meadow={0,0,0,0,0,0},canyon={0,0,0,0,0,0},aurora={0,0,0,0,0,0}}
check(Loadout.heatUnlocked(records)==0,"Locked initially")
local SILVER=Config.Medals.Silver
records.canyon[1]=SILVER-1; check(Loadout.heatUnlocked(records)==0,"Silver threshold")
records.canyon[1]=SILVER; check(Loadout.heatUnlocked(records)==1,"Silver opens heat 1")
records.aurora[2]=SILVER+50; records.meadow[3]=SILVER*2; check(Loadout.heatUnlocked(records)==3,"Ladder across arenas")
records.meadow[5]=SILVER+100; check(Loadout.heatUnlocked(records)==3,"No skipping heat 3")
records.meadow[4]=SILVER; records.meadow[6]=99999; check(Loadout.heatUnlocked(records)==5,"Cap 5")
check(Loadout.heatUnlocked(nil)==0 and Loadout.heatUnlocked({meadow={0/0}})==0,"Malformed records")

-- Targeting.sweep ---------------------------------------------------------------
local a,b={x=0,y=3,z=0},{x=20,y=3,z=0}
check(Targeting.sweep(a,b,{x=10,y=3,z=4},4.5).distance==4,"Lateral distance")
check(Targeting.sweep(a,b,{x=10,y=3,z=4.6},4.5)==nil,"Outside path")
check(Targeting.sweep(a,b,{x=-4,y=3,z=0},4.5).distance==4,"Behind start uses endpoint")
check(Targeting.sweep(a,b,{x=24.6,y=3,z=0},4.5)==nil,"Beyond end")
check(Targeting.sweep(a,a,{x=3,y=3,z=0},4.5).distance==3,"Stationary dash is a circle")
check(Targeting.sweep(a,b,{x=10,y=12,z=0},4.5)==nil,"Vertical tolerance")
for _,bad in ipairs({0/0,math.huge,-1,0}) do check(Targeting.sweep(a,b,{x=1,y=3,z=0},bad)==nil,"Bad radius") end
check(Targeting.sweep({x=0/0,y=0,z=0},b,{x=1,y=3,z=0},4)==nil and Targeting.sweep(a,b,nil,4)==nil,"Bad vectors")

-- Challenge v2 ------------------------------------------------------------------
local rules=Loadout.stats({},{},0)
local s=Challenge.new(1,nil,rules)
local t=1
local idCounter=0
local function catch(kind,extra)
	idCounter+=1
	local c={distance=6,facing=0,value=5,starter=false,captureId=idCounter,kind=kind}
	for k,v in pairs(extra or {}) do c[k]=v end
	local ok,r=Challenge.capture(s,t,c); return ok,r
end
-- x4 tier with live rules
for i=1,16 do local ok,r=catch("normal"); check(ok,"Catch "..i); check(r.multiplier==math.min(4,1+math.floor((i-1)/5)),"Tier every 5 catches "..i); t+=0.7 end
check(Challenge.snapshot(s,t).multiplier==4 and Challenge.snapshot(s,t).maxMultiplier==4,"STAMPEDE x4")
-- dash-through bypasses button interval but not duplicate IDs
local ok1=Challenge.capture(s,t,{distance=2,facing=1,value=5,starter=false,captureId="d1",kind="dash",multiIndex=1})
local ok2,r2=Challenge.capture(s,t,{distance=2,facing=1,value=5,starter=false,captureId="d2",kind="dash",multiIndex=2})
check(ok1 and ok2 and r2.multi and r2.dash and not r2.precision,"Same-tick multi-catch")
check(not Challenge.capture(s,t,{distance=2,facing=1,value=5,starter=false,captureId="d2",kind="dash",multiIndex=3}),"Duplicate rejected")
check(not Challenge.capture(s,t,{distance=2,facing=1,value=5,starter=false,captureId="x",kind="teleport"}),"Unknown kind rejected")
check(not Challenge.capture(s,t,{distance=2,facing=1,value=5,starter=false,captureId="y",kind="dash",multiIndex=0.5}),"Bad multi index")
check(Challenge.snapshot(s,t).multiCatches==1 and Challenge.snapshot(s,t).bestMulti==2,"Multi stats")
-- herd/golden scoring includes multiplier
local before=Challenge.snapshot(s,t).pending
local okh,rh=Challenge.capture(s,t+0.1,{distance=8,facing=0,value=5,starter=false,captureId="h",kind="herd"})
check(okh and rh.kind=="herd" and rh.points==(20+40)*4,"Herded points at x4 ("..tostring(rh.points)..")")
check(Challenge.snapshot(s,t+0.1).pending==before+rh.points,"Pending grows")
local okg,rg=Challenge.capture(s,t+0.2,{distance=8,facing=0,value=7,starter=false,captureId="g",kind="golden"})
check(okg and rg.points==(24+250)*4,"Golden points")
-- pop refreshes chain timer and adds style; assist adds style
t+=5.5
local chainBefore=Challenge.snapshot(s,t).chainSeconds
check(chainBefore<1,"Chain almost expired")
local okp,pts=Challenge.award(s,t,"pop"); check(okp and pts==40,"Pop points")
near(Challenge.snapshot(s,t).chainSeconds,6,"Pop refreshes chain")
check(Challenge.award(s,t,"assist") and Challenge.snapshot(s,t).assists==1,"Assist")
check(not Challenge.award(s,t,"cheat"),"Unknown award")
-- haul bonus on bank
local snap=Challenge.snapshot(s,t)
local expected=math.floor((snap.pending-snap.pendingBonus)+math.floor(snap.pendingBonus*math.min(1.5,1+0.05*(snap.pendingCount-1))))
local banked=Challenge.bank(s,t)
check(banked==expected+(if Challenge.snapshot(s,t).challenge.complete then 100 else 0),"Haul bonus applied ("..banked.." vs "..expected..")")
check(Challenge.snapshot(s,t).bestBank==banked,"Best bank tracked")
-- finale and heat multipliers
local h=Challenge.new(4,nil,Loadout.stats({},{},5))
Challenge.capture(h,1,{distance=6,facing=0,value=5,starter=false,captureId=1})
check(Challenge.bank(h,2,{finale=true})==math.floor(math.floor(20*1.25)*2),"Finale x1.25 then heat x2")
-- buzzer forfeits style but keeps base
local z=Challenge.new(1,nil,rules)
Challenge.capture(z,1,{distance=2,facing=1,value=5,starter=false,captureId=1,dashAge=.1})
local pend=Challenge.snapshot(z,1)
local lost=Challenge.buzzer(z,2)
check(lost==pend.pendingBonus and lost>0,"Buzzer forfeits bonus")
local final=Challenge.finish(z,3)
check(final.score==20 and final.buzzerLost==lost,"Base points kept after buzzer")
-- scatter removes carried base points and counts; zap reason counted
local q=Challenge.new(1,nil,rules)
for i=1,4 do Challenge.capture(q,i,{distance=6,facing=0,value=5,starter=false,captureId=i}) end
Challenge.miss(q,5,"zap")
check(Challenge.scatter(q,5,{20,20,20,20,20,20})==4,"Cannot scatter more than carried")
local qs=Challenge.snapshot(q,5)
check(qs.pendingCount==0 and qs.pending==0 and qs.zaps==1 and qs.scattered==4,"Scatter accounting")
check(Challenge.scatter(q,5,"bad")==0 and Challenge.scatter(q,5,{0/0})==0,"Malformed scatter")
-- perk effects inside Challenge
local nose=Challenge.new(1,nil,Loadout.stats({},{"goldnose"},0))
local _,rn=Challenge.capture(nose,1,{distance=6,facing=0,value=5,starter=false,captureId=1,dashAge=.1})
check(rn.points==20+10,"Golden Nose halves dash bonus")
local reach=Challenge.new(1,nil,Loadout.stats({},{"reach"},0))
local _,rr=Challenge.capture(reach,1,{distance=3,facing=.8,value=5,starter=false,captureId=1})
check(not rr.precision,"Long Reach stricter precision")
local rhythm=Challenge.new(1,nil,Loadout.stats({},{"rhythm"},0))
for i=1,12 do Challenge.capture(rhythm,i*7.5,{distance=6,facing=0,value=5,starter=false,captureId=i}) end
check(Challenge.snapshot(rhythm,90).chain==12 and Challenge.snapshot(rhythm,90).multiplier==3,"Rhythm Keeper: 8s window, x3 cap")
-- legacy default keeps x3 cap (old callers / tests)
local legacy=Challenge.new(1)
for i=1,12 do Challenge.capture(legacy,i,{distance=6,facing=0,value=5,starter=false,captureId=i}) end
check(Challenge.snapshot(legacy,12).multiplier==3,"Legacy cap")
check(Challenge.snapshot(Challenge.new(1),0).medal=="Unranked","Medal default")
-- Radiant medal
local rad=Challenge.new(1,nil,Loadout.stats({},{},5))
for i=1,20 do Challenge.capture(rad,i*.7,{distance=2,facing=1,value=16,starter=false,captureId=i,dashAge=.1}) end
Challenge.bank(rad,15,{finale=true})
check(Challenge.snapshot(rad,15).medal=="Radiant","Radiant reachable at heat")
-- Fuzz: invariants under random event sequences with live rules.
local rng=Random and Random.new and Random.new(7) or nil
local seed=12345
local function rand(m) seed=(seed*1103515245+12345)%2147483648; return seed%m end
for trial=1,300 do
	local st=Challenge.new(trial,nil,Loadout.stats({boots=rand(4)},{Loadout.Perks[rand(8)+1].id},rand(6)))
	local now=0
	for step=1,120 do
		now+=rand(100)/100
		local choice=rand(8)
		if choice<=2 then Challenge.capture(st,now,{distance=rand(10),facing=(rand(200)-100)/100,value=rand(17),starter=false,captureId=step,dashAge=if rand(2)==0 then rand(100)/100 else nil})
		elseif choice==3 then Challenge.capture(st,now,{distance=1,facing=1,value=rand(17),starter=false,captureId="m"..step,kind="dash",multiIndex=rand(4)+1})
		elseif choice==4 then Challenge.award(st,now,if rand(2)==0 then "pop" else "assist")
		elseif choice==5 then Challenge.miss(st,now,"zap"); Challenge.scatter(st,now,{20,20})
		elseif choice==6 then Challenge.bank(st,now,{finale=rand(2)==0})
		else Challenge.capture(st,now,{distance=5,facing=0,value=rand(17),starter=false,captureId="h"..step,kind=if rand(2)==0 then "herd" else "golden"}) end
		local v=Challenge.snapshot(st,now)
		check(v.pending>=0 and v.pendingCount>=0 and v.score>=0 and v.multiplier>=1 and v.multiplier<=4,"Fuzz bounds")
	end
	Challenge.buzzer(st,now+1)
	local f=Challenge.finish(st,now+1)
	check(f.finished and f.pending==0 and f.score>=0 and f.score<=1000000,"Fuzz finish")
end

-- Encounters --------------------------------------------------------------------
local function dist(x1,z1,x2,z2) return math.sqrt((x1-x2)^2+(z1-z2)^2) end
-- A2: every synchronized 110 s play window (cycle starts) contains each encounter.
for offset=0,1200,120 do
	for biome=1,3 do
		local gateSeen,runStarts,goldenSpawns=false,{},0
		local lastGoldenCycle=nil
		for step=0,1100 do
			local e=offset+step/10
			local g=Encounters.gate(e,biome)
			if g.active then gateSeen=true end
			local r=Encounters.stampede(e,biome)
			if r.active then runStarts[r.cycle..":"..r.run]=true end
			local gold=Encounters.golden(e,biome,1)
			if gold.spawn and gold.cycle~=lastGoldenCycle then goldenSpawns+=1; lastGoldenCycle=gold.cycle end
		end
		local runs=0; for _ in pairs(runStarts) do runs+=1 end
		if biome==2 then check(not gateSeen and runs>=2,"Canyon runs in every round (offset "..offset..")")
		else check(gateSeen and runs==0,"Gate in every meadow/aurora round (offset "..offset..")") end
		check(goldenSpawns>=1 and goldenSpawns<=2,"Golden finale reachable each round")
	end
end
for step=0,1100 do
	local e=step/10
	for biome=1,3 do
		local g=Encounters.gate(e,biome)
		if g.visible then
			check(dist(g.x,g.z,0,44)-g.radius>24,"Gate clear of bank")
			for _,x in ipairs({-26.163,26.163}) do for _,zz in ipairs({-26.163,26.163}) do
				check(dist(g.x,g.z,x,zz)>g.radius+4.5,"Gate clear of islands") end end
			check(dist(g.x,g.z,0,0)+g.radius<=48,"Gate inside herd area")
		end
		local r=Encounters.stampede(e,biome)
		if r.visible then
			for _,p in ipairs({r.from,r.to}) do check(dist(p.x,p.z,0,0)<=48 and dist(p.x,p.z,0,44)>28,"Lane endpoints fair") end
			check(math.abs(r.from.z)<=21.6-2 or math.abs(r.from.z)>=30.8,"Lane clear of islands")
			check(r.progress>=0 and r.progress<=1 and r.seconds>0,"Run timing")
		end
	end
end
check(Encounters.runSpeed()<Config.WalkSpeed,"Runners slower than walking (catchable)")
check(Encounters.golden(90,3,1).count==2 and Encounters.golden(90,1,4).count==2 and Encounters.golden(90,1,1).count==1,"Golden counts")
check(Encounters.golden(10,1,1).spawn==false and Encounters.golden(0/0,1,1).spawn==false,"Golden timing guards")
check(Encounters.staticStart(3)==20 and Encounters.staticStart(1)==25,"Static starts")
for _,bad in ipairs({0/0,-1,math.huge,"x"}) do
	check(not Encounters.gate(bad,1).visible and not Encounters.stampede(bad,2).visible,"Bad clock hides encounters")
end
check(not Encounters.gate(60,7).visible and not Encounters.stampede(60,0).visible,"Bad biome")
-- static spawning and drift fairness
local accepted=0
for i=1,2000 do
	local angle=i*0.7; local radius=10+(i%40)
	local p=Encounters.staticSpawn(angle,radius,{x=0,z=38})
	if p then
		accepted+=1
		check(dist(p.x,p.z,0,38)>=16 and dist(p.x,p.z,0,44)>=30,"Spawn clearances")
	end
end
check(accepted>200,"Enough valid static spawns")
check(Encounters.staticSpawn(0/0,20,{x=0,z=0})==nil and Encounters.staticSpawn(1,20,nil)==nil,"Spawn guards")
local pos={x=0,z=-30}
for i=1,200 do
	local nextPos=Encounters.staticStep(pos,{x=0,z=60},8,0.1)
	check(dist(nextPos.x,nextPos.z,pos.x,pos.z)<=0.8+1e-6 or dist(nextPos.x,nextPos.z,0,44)>=22-1e-6,"Speed bounded")
	pos=nextPos
	check(dist(pos.x,pos.z,0,44)>=22-1e-6 and dist(pos.x,pos.z,0,0)<=46+1e-6,"Statics never camp the bank")
end
check(Encounters.staticStep(nil,{x=0,z=0},8,.1)==nil,"Step guard")
check(Encounters.describe(10,1).next=="SPARK GATE" and Encounters.describe(60,2).phase=="STAMPEDE RUN" and Encounters.describe(95,3).phase=="GOLDEN FINALE","Describe")
print("PASS SparkDepth: "..n.." assertions (perks/heat, Challenge v2, dash path, encounters; pure modules)")
