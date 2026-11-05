local Rules = require("../game/ReplicatedStorage/Spark/Rules")
local total = 0
local function check(value, message) total += 1; assert(value, message) end
local player = {phase="Playing",ready=true,carry=0,biome=1,position={x=0,y=0,z=0}}
local creature = {claimed=false,biome=1,position={x=6,y=0,z=8}}
check(Rules.canCapture(player,creature,1,10,8), "radius edge")
creature.position.x=6.01
check(not Rules.canCapture(player,creature,1,10,8), "outside radius")
creature.position.x=6; creature.claimed=true
check(not Rules.canCapture(player,creature,1,10,8), "double capture rejected")
creature.claimed=false; player.carry=8
check(not Rules.canCapture(player,creature,1,10,8), "capacity enforced")
player.carry=0; player.biome=2
check(not Rules.canCapture(player,creature,1,10,8), "cross arena capture rejected")
player.biome=1; player.position.x=0/0
check(not Rules.canCapture(player,creature,1,10,8), "NaN rejected")
player.position.x=0
-- Daily Stampede ownership: trial Sparks are private both ways.
player.userId=7
local trialSpark={claimed=false,biome=1,position={x=1,y=0,z=1},trialOwner=7}
check(Rules.canCapture(player,trialSpark,1,10,8), "owner may catch own trial Spark")
trialSpark.trialOwner=8
check(not Rules.canCapture(player,trialSpark,1,10,8), "another runner's trial Spark rejected")
player.mode="trial"
check(not Rules.canCapture(player,{claimed=false,biome=1,position={x=1,y=0,z=1}},1,10,8), "trial runner cannot catch shared Sparks")
trialSpark.trialOwner=7
check(Rules.canCapture(player,trialSpark,1,10,8), "trial runner catches own course")
player.mode=nil; player.userId=nil
player.position.x=0; player.suspiciousUntil=3
check(not Rules.canCapture(player,creature,1,10,8), "teleport quarantine")
player.suspiciousUntil=0; player.ready=false
check(not Rules.canCapture(player,creature,1,10,8), "load failure blocks reward")
local bucket={}
check(Rules.allow(bucket,"capture",1,.65), "first capture")
check(not Rules.allow(bucket,"capture",1.1,.65), "rate limited")
check(Rules.allow(bucket,"capture",1.66,.65), "cooldown elapsed")
check(not Rules.allow(bucket,"capture",0/0,.65), "invalid clock")
local phase,remaining=Rules.roundPhase(10,119,110)
check(phase=="Playing" and remaining==1,"last second")
phase,remaining=Rules.roundPhase(10,120,110)
check(phase=="Results" and remaining==0,"round boundary")
for clients=1,4 do
	local claimed=false; local winners=0
	for _=1,clients do
		creature.claimed=claimed; player.ready=true
		if Rules.canCapture(player,creature,5,10,8) then claimed=true; winners+=1 end
	end
	check(winners==1,"serialized claim is unique across contenders")
end
local limits={origin={x=0,y=0,z=0},radius=78,minY=-4,maxY=24,speed=24,burst=10}
local function motion()
	return {position={x=0,y=3,z=0},at=0,credit=10,blockedUntil=0}
end
local m=motion()
check(Rules.movement(m,{x=2.2,y=3,z=0},.1,limits),"normal movement accepted")
check(not Rules.movement(m,{x=40,y=3,z=0},.1,limits),"same-frame teleport rejected before capture")
check(m.position.x==2.2 and m.blockedUntil==1.6,"last valid position retained and quarantine set")
player.ready=true;player.position={x=40,y=3,z=0};player.suspiciousUntil=m.blockedUntil
creature.claimed=false;creature.position={x=40,y=3,z=0}
check(not Rules.canCapture(player,creature,.1,10,8),"teleport-then-capture same frame blocked")
for _,bad in ipairs({{x=0/0,y=3,z=0},{x=math.huge,y=3,z=0},{x=0,y=math.huge,z=0},{x=0,y=25,z=0},{x=0,y=-5,z=0},{x=79,y=3,z=0},{x="bad",y=3,z=0}}) do
	check(not Rules.movement(motion(),bad,.1,limits),"invalid positions and bounds rejected")
end
m=motion()
local rejected=false
for step=1,20 do
	if not Rules.movement(m,{x=step*4,y=3,z=0},step*.1,limits) then rejected=true;break end
end
check(rejected,"40 studs/s cannot reuse a fresh per-frame allowance")
m=motion()
for step=1,25 do check(Rules.movement(m,{x=step*2.2,y=3,z=0},step*.1,limits),"sustained legal walk") end
local before=m.credit
for _=1,50 do check(Rules.movement(m,m.position,2.5,limits),"same-timestamp no-op") end
check(m.credit==before,"frequent requests generate no additional travel credit")
m=motion();m.dashStarted=0;m.dashUntil=.35
for step=1,3 do check(Rules.movement(m,{x=step*6.5,y=3,z=0},step*.1,limits),"authorized dash movement") end
check(not Rules.movement(m,{x=40,y=3,z=0},.4,limits),"dash does not authorize arbitrary teleport")
check(Rules.distance(nil,{x=0,y=0,z=0})==math.huge,"malformed distance fails closed")

for banked=0,5 do
	local session={}
	check(Rules.issueStarters(session,banked)==math.max(0,3-banked),"starter allowance is limited by persistent progress")
	for _=1,20 do
		session.phase="Results";session.phase="Playing"
		check(Rules.issueStarters(session,banked)==0,"Replay cannot renew starter allocation")
	end
end
check(Rules.issueStarters({},0/0)==0,"malformed progress cannot allocate starters")
check(Rules.issueStarters({},-1)==0,"negative progress cannot enlarge allowance")
local owners={}
local totalStarters=0
for userId=1,4 do
	owners[userId]={}
	totalStarters+=Rules.issueStarters(owners[userId],0)
end
check(totalStarters==12,"four fresh players add at most twelve finite starters to regular herd")
player={phase="Playing",ready=true,carry=0,biome=1,userId=42,totalBanked=0,position={x=0,y=3,z=38}}
creature={claimed=false,biome=1,starterOwner=42,position={x=0,y=2.2,z=30}}
check(Rules.canCapture(player,creature,10,10,8),"fresh owner can reach immediate starter")
player.userId=43
check(not Rules.canCapture(player,creature,10,10,8),"other players cannot consume onboarding allowance")
player.userId=42;player.totalBanked=3
check(not Rules.canCapture(player,creature,10,10,8),"stale starter rejected after third banked creature")
player.totalBanked=nil
check(not Rules.canCapture(player,creature,10,10,8),"missing authoritative progress fails closed")
player.totalBanked=2;creature.claimed=true
check(not Rules.canCapture(player,creature,10,10,8),"claimed starter cannot duplicate")
local bankPosition={x=0,y=0,z=44}
for angle=0,359,3 do
	for radius=10,43,3 do
		local spawn=Rules.herdSpawn(math.rad(angle),radius)
		check(spawn.z<=12 and Rules.distance(spawn,bankPosition)>31,"ordinary spawns require entering active arena")
	end
end
for x=-35,35,5 do
	for z=10,65,5 do
		local safe=Rules.outsideBank({x=x,y=2.2,z=z},bankPosition)
		check(math.sqrt(safe.x^2+(safe.z-44)^2)>=28-.0001,"normal herd stays outside bank catch envelope")
		-- Explicit banking permits12 studs; max magnet radius is14.5. Clearance28 excludes both.
		check(math.sqrt(safe.x^2+(safe.z-44)^2)>12+14.5,"bank-camping reach cannot overlap normal herd")
	end
end
print("SparkRules: "..total.." assertions passed (pure rules; NOT engine multiplayer)")
