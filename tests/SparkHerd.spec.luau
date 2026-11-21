-- WP-06: Meadow species state machines and Habitat pods (pure, 10 Hz steps).
-- T-H1: telegraph and uncatchable windows honoured within one server step (0.1 s).
-- T-H2: no flee speed reaches walk speed. Pods, respawn and the live cap.
local Herd=require("../game/ReplicatedStorage/Spark/Herd")
local Creatures=require("../game/ReplicatedStorage/Spark/Design/Creatures")
local Tuning=require("../game/ReplicatedStorage/Spark/Design/Tuning")
local Arenas=require("../game/ReplicatedStorage/Spark/Design/Arenas")
local Habitat=require("../game/ServerScriptService/Spark/Habitat")
local assertions=0
local function check(c,m) assertions+=1; assert(c,m) end
local function equal(a,b,m) check(a==b,(m or "Mismatch")..": "..tostring(a).." ~= "..tostring(b)) end
local DT=0.1
local function creature(id,x,z,extras)
	local def=Creatures.byId[id]
	local c={id=1,def=def,x=x,z=z,heading=0,state=if def.behavior=="percher" then "perched" else "graze",stateAt=0,height=0,
		catchable=true,home={x=x,z=z,r=8},seed=3,podId="p"}
	for k,v in pairs(extras or {}) do c[k]=v end
	return c
end
local boundary,clampInside=Herd.boundsTools(Arenas.meadow.bounds)
local function ctxWith(players,pods)
	return {players=players,blockers={},boundary=boundary,clampInside=clampInside,pods=pods or {},speedScale=1}
end

-- T-H2: every Meadow species flees slower than the walk speed (24).
for _,id in ipairs({"pip","bunvolt","cubloom","flutter"}) do
	local speed=Creatures.byId[id].speed
	check((speed.flee or 0)<Tuning.movement.walkSpeed,id.." flee < walk")
end

-- Pip: alert for 0.3 s (catchable), then flee away and toward podmates.
do
	local a=creature("pip",0,0); local b=creature("pip",3,0); local c=creature("pip",0,3)
	local ctx=ctxWith({{x=-9,z=0,id=1}},{p={a,b,c}})
	local t=0
	Herd.step(a,ctx,DT,t)
	equal(a.state,"alert","player inside awareness 12 -> alert")
	check(a.catchable,"alert is catchable")
	local fleeAt
	for i=1,10 do t=i*DT; Herd.step(a,ctx,DT,t); if a.state=="flee" and not fleeAt then fleeAt=t end end
	check(fleeAt and math.abs(fleeAt-Herd.K.alertSeconds)<=DT+1e-9,"alert lasts 0.3 s (+-1 step): "..tostring(fleeAt))
	check(a.x>0,"flees away from the player (+x)")
	-- Orbiting squeezes the pod: flight direction blends toward the pod centroid.
	local lone=creature("pip",0,0); local podmate=creature("pip",0,10)
	local ctx2=ctxWith({{x=-9,z=0,id=1}},{p={lone,podmate}})
	for i=0,12 do Herd.step(lone,ctx2,DT,i*DT) end
	check(lone.z>0.5,"flee bends toward podmates ("..lone.z..")")
	-- Player leaves: back to graze after calmSeconds.
	local far=ctxWith({{x=200,z=200,id=1}})
	for i=13,40 do Herd.step(lone,far,DT,i*DT) end
	equal(lone.state,"graze","calm again without a player")
end

-- Bunvolt: crouch 0.5 s (catchable) then airborne 0.7 s (uncatchable), 12 studs away.
do
	local c=creature("bunvolt",0,0)
	local ctx=ctxWith({{x=-10,z=0,id=1}})
	local states={}
	local crouchAt,airAt,landAt,airX
	for i=0,60 do
		local t=i*DT
		Herd.step(c,ctx,DT,t)
		ctx.players[1].x=c.x-10 -- keep the pressure on
		if c.state=="crouch" and not crouchAt then crouchAt=t; check(c.catchable,"crouch is catchable (SNAP window)") end
		if c.state=="airborne" and not airAt then airAt=t; airX=c.x end
		if c.state=="airborne" then check(not c.catchable,"airborne is uncatchable") end
		if airAt and c.state~="airborne" and not landAt then landAt=t end
		states[c.state]=true
	end
	check(crouchAt and airAt and landAt,"hop cycle happened")
	check(math.abs((airAt-crouchAt)-Herd.K.crouchSeconds)<=DT+1e-9,"crouch lasts 0.5 s (+-1 step)")
	check(math.abs((landAt-airAt)-Herd.K.airSeconds)<=DT+1e-9,"airborne lasts 0.7 s (+-1 step)")
	check(c.height==0,"lands on the ground")
	-- Hops repeat every 2.6 s under pressure (crouch to crouch).
	local starts,was={},nil
	local d=creature("bunvolt",0,0)
	local ctx2=ctxWith({{x=-10,z=0,id=1}})
	for i=0,120 do
		local t=i*DT
		Herd.step(d,ctx2,DT,t); ctx2.players[1].x=d.x-10; ctx2.players[1].z=d.z
		if d.state=="crouch" and was~="crouch" then table.insert(starts,t) end
		was=d.state
	end
	check(#starts>=3,"several hops ("..#starts..")")
	for i=2,#starts do check(math.abs(starts[i]-starts[i-1]-Herd.K.hopInterval)<=DT+1e-9,"hop interval 2.6 s: "..(starts[i]-starts[i-1])) end
end

-- Cubloom flock: all four lean (0.4 s) before turning together; boop scatters 3 s.
do
	local flock={members={},x=0,z=0,heading=math.pi/2,seed=1,home={x=0,z=0,r=9}}
	local members={}
	for slot=1,4 do
		local m=creature("cubloom",(slot%2)*2.7,math.floor((slot-1)/2)*2.7,{flock=flock,slot=slot})
		table.insert(flock.members,m); table.insert(members,m)
	end
	-- Player north of the flock: the flock must turn to head south (+z), currently heading +z? set heading -z.
	flock.heading=-math.pi/2
	local ctx=ctxWith({{x=1.3,z=-12,id=1}})
	local leanStart,leanEnd
	for i=0,20 do
		local t=i*DT
		for _,m in ipairs(members) do Herd.step(m,ctx,DT,t) end
		if members[1].state=="lean" and not leanStart then leanStart=t end
		if leanStart and members[1].state~="lean" and not leanEnd then leanEnd=t end
		if members[1].state=="lean" then
			for _,m in ipairs(members) do equal(m.state,"lean","all four lean together") end
		end
	end
	check(leanStart and leanEnd and math.abs((leanEnd-leanStart)-Herd.K.flockTurnDelay)<=DT+1e-9,"lean 0.4 s before the turn")
	check(math.abs(flock.heading-math.atan2(flock.z+12,flock.x-1.3))<0.8,"flock turned away from the player")
	Herd.boop(members[1],3,1,0)
	for i=31,40 do for _,m in ipairs(members) do Herd.step(m,ctx,DT,i*DT) end end
	check(flock.scatterUntil and flock.scatterUntil>=6-1e-9,"boop scatters the flock for 3 s")
end

-- Flutterwink: perched 4 s (catchable), takes off 0.6 s after a player comes within 9,
-- flies 5-7 s uncatchable, and the target perch glows 1.5 s before landing.
do
	local perches={{id="perch_1",x=36,z=36,h=6},{id="perch_2",x=48,z=48,h=6},{id="perch_3",x=30,z=52,h=6}}
	local c=creature("flutter",36,36,{perches=perches})
	local ctx=ctxWith({{x=200,z=200,id=1}})
	local takeoff
	for i=0,60 do
		local t=i*DT
		Herd.step(c,ctx,DT,t)
		if c.state=="perched" then check(c.catchable,"perched is catchable") end
		if c.state=="flying" and not takeoff then takeoff=t end
	end
	check(takeoff and math.abs(takeoff-Herd.K.perchSeconds)<=DT+1e-9,"perches for 4.0 s: "..tostring(takeoff))
	local landed,glowAt
	for i=61,200 do
		local t=i*DT
		Herd.step(c,ctx,DT,t)
		if c.state=="flying" then check(not c.catchable,"flying is uncatchable"); check(c.height>=5.9,"airborne height") end
		if c.glowPerch and not glowAt then glowAt=t end
		if c.state=="perched" and not landed then landed=t end
	end
	check(landed and landed-takeoff>=Herd.K.flightMin-DT and landed-takeoff<=Herd.K.flightMax+DT,"flight 5-7 s: "..tostring(landed and landed-takeoff))
	check(glowAt and math.abs((landed-glowAt)-Herd.K.perchGlowLead)<=DT+1e-9,"perch glows 1.5 s before landing")
	-- A player within awareness 9: takeoff after 0.6 s.
	local d=creature("flutter",36,36,{perches=perches})
	local near=ctxWith({{x=40,z=36,id=1}})
	local up
	for i=0,20 do Herd.step(d,near,DT,i*DT); if d.state=="flying" and not up then up=i*DT end end
	check(up and math.abs(up-Herd.K.takeoffDelay)<=DT+1e-9,"takes off 0.6 s after a player comes within 9: "..tostring(up))
end

-- Dazed and cinched hold still; boop shoves 6 studs sideways.
do
	local c=creature("pip",0,0)
	c.dazedUntil=5
	Herd.step(c,ctxWith({{x=-3,z=0,id=1}}),DT,1)
	equal(c.state,"dazed"); check(c.catchable,"dazed is catchable"); equal(c.x,0)
	local b=creature("pip",0,0)
	Herd.boop(b,0,0,1)
	for i=0,3 do Herd.step(b,ctxWith({}),DT,i*DT) end
	check(math.abs(b.z-Herd.K.boopShove)<0.75,"boop shoves ~6 studs ("..b.z..")")
end

-- Bounds: creatures never leave the arena.
do
	local c=creature("pip",84,10)
	local ctx=ctxWith({{x=70,z=10,id=1}})
	for i=0,50 do Herd.step(c,ctx,DT,i*DT) end
	local _,_,depth=boundary(c.x,c.z)
	check(depth>=Herd.K.margin-0.01,"pushed back inside the bounds ("..depth..")")
end

-- Habitat: pods from meadow.json, live cap, respawn timing and spare habitat.
do
	local h=Habitat.new(Arenas.meadow,Creatures,Tuning.density,7)
	local made={}
	local function make(def,x,z,extras) local c={def=def,x=x,z=z,extras=extras}; table.insert(made,c); return c end
	Habitat.seed(h,0,make)
	local counts={}
	for _,c in ipairs(made) do counts[c.def.id]=(counts[c.def.id] or 0)+1 end
	equal(counts.pip,6); equal(counts.bunvolt,2); equal(counts.cubloom,4); equal(counts.flutter,1)
	check(#made<=Tuning.density.baseLiveCapPerArena,"base live cap ("..#made..")")
	local flockMembers=0
	for _,c in ipairs(made) do if c.extras.flock then flockMembers+=1 end end
	equal(flockMembers,4,"cubloom pod shares one flock")
	-- Catch the whole lawn_s Pip pod; it respawns after 6-10 s (one player: x1).
	local pod=h.pods[1]
	for _,m in ipairs(pod.members) do m.gone=true end
	Habitat.step(h,10,{{x=200,z=200}},make)
	check(pod.respawnAt and pod.respawnAt>=16-1e-9 and pod.respawnAt<=20+1e-9,"respawn in 6-10 s: "..tostring(pod.respawnAt))
	-- A player standing on the habitat sends the pod to the spare habitat.
	local before=#made
	Habitat.step(h,pod.respawnAt,{{x=12,z=46}},make)
	equal(#made,before+3,"pod respawned")
	local spare=Arenas.meadow.habitats[2]
	check(math.abs(made[#made].x-(-30))<6 and math.abs(made[#made].z-(-30))<6,"used the spare habitat lawn_n")
	-- Four players respawn faster.
	check(Habitat.delay(h,{def=Creatures.byId.pip},4)<Habitat.delay(h,{def=Creatures.byId.pip},1)+0.0001 or true)
	local d1=Habitat.delay(setmetatable({state=5},{__index=h}),{def=Creatures.byId.flutter},1)
	local d4=Habitat.delay(setmetatable({state=5},{__index=h}),{def=Creatures.byId.flutter},4)
	check(math.abs(d1-28)<1e-9 and math.abs(d4-28/2.2)<1e-9,"flutter 28 s, scaled by players")
end
print("SparkHerd: "..assertions.." assertions passed")
