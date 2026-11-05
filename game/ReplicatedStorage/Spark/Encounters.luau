-- Pure arena encounter choreography on the shared 110s arena clock. Because a
-- personal round is also 110s, every round contains each encounter exactly once
-- no matter when a player joined. Coordinates are relative to the arena origin.
-- Main owns spawning, hits and rewards; clients only draw what the server sends.
local Encounters = {}
Encounters.Cycle = 120 -- Cycle.Length: 110 s play + 10 s intermission
Encounters.Play = 110
Encounters.Bank = {x=0, z=44}
Encounters.Spawn = {x=0, z=38}

-- Per-arena obstacle layouts (D22, plan §6.8.2): arena-relative {x, z, r} collision
-- circles. World builds them; Main's herd avoidance, Trial placement and every
-- encounter clearance read the same data. Literal 0.1-stud coordinates (no trig)
-- keep shared placement bit-identical on every platform.
-- Meadow: four low steering islands (the readable tutorial layout; also the Daily
-- Stampede Trial Grounds layout on every day). Canyon: six rock pillars in two
-- columns whose gaps frame both Stampede Run lanes. Aurora: five crystal pillars in
-- a pentagon (radius 30) with one point away from the bank approach.
Encounters.Obstacles = {
	{kind="island", list={{x=-26.163,z=-26.163,r=4.5},{x=26.163,z=-26.163,r=4.5},{x=-26.163,z=26.163,r=4.5},{x=26.163,z=26.163,r=4.5}}},
	{kind="pillar", list={{x=-30,z=-26,r=3.5},{x=-30,z=-2,r=3.5},{x=-30,z=22,r=3.5},{x=30,z=-26,r=3.5},{x=30,z=-2,r=3.5},{x=30,z=22,r=3.5}}},
	{kind="crystal", list={{x=0,z=-30,r=3},{x=28.5,z=-9.3,r=3},{x=17.6,z=24.3,r=3},{x=-17.6,z=24.3,r=3},{x=-28.5,z=-9.3,r=3}}},
}
Encounters.Island = 26.163 -- legacy: meadow island offset

local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function biomeIndex(biome)
	if biome=="meadow" then return 1 elseif biome=="canyon" then return 2 elseif biome=="aurora" then return 3 end
	if finite(biome) and biome%1==0 and biome>=1 and biome<=3 then return biome end
	return nil
end
local function clock(elapsed)
	if not finite(elapsed) or elapsed<0 then return nil end
	return elapsed%Encounters.Cycle, math.floor(elapsed/Encounters.Cycle)
end

-- Obstacles for an arena (1..3); the kind names the World art. Unknown arenas: none.
function Encounters.obstacles(biome)
	local layout = Encounters.Obstacles[biomeIndex(biome) or 0]
	return if layout then layout.list else {}, if layout then layout.kind else nil
end
-- True when (x, z) keeps `margin` studs of body clearance from every obstacle.
function Encounters.clearOfObstacles(biome, x, z, margin)
	if not finite(x) or not finite(z) then return false end
	for _, o in ipairs((Encounters.obstacles(biome))) do
		local dx, dz = x - o.x, z - o.z
		local need = o.r + (if finite(margin) then margin else 0)
		if dx * dx + dz * dz < need * need then return false end
	end
	return true
end

-- SPARK GATE (Pop Meadow): drift through the infield, never over the bank
-- approach. Sparks herded through it join the herder's parade. Aurora has Starfall.
Encounters.GateRadius = 6
function Encounters.gate(elapsed, biome)
	local index=biomeIndex(biome)
	local t,cycle=clock(elapsed)
	if not t or index~=1 or t<52 or t>=85 then return {visible=false,active=false} end
	local age=math.max(0,t-55)
	local x=math.sin(age*0.24)*18
	local z=-4+math.sin(age*0.17+0.6)*10
	return {visible=true,active=t>=55,warning=t<55,x=x,z=z,radius=Encounters.GateRadius,
		seconds=if t<55 then 55-t else 85-t,cycle=cycle,name="SPARK GATE",cue="HERD SPARKS THROUGH THE GATE"}
end

-- STAMPEDE RUN (Fizz Canyon): two telegraphed straight lanes of fast Sparks.
Encounters.RunLength = 5
Encounters.RunCount = 6
local runs = {
	{start=58, from={x=-44,z=-14}, to={x=44,z=-14}},
	{start=72, from={x=44,z=10}, to={x=-44,z=10}},
}
Encounters.Runs = runs
-- Weekly Remix "Stampede Season": one run in the other arenas too, on the lane that
-- is clear of that arena's obstacles (meadow: north lane; aurora: south lane).
Encounters.SeasonLane = {[1]=1, [3]=2}
function Encounters.stampede(elapsed, biome, remix)
	local index=biomeIndex(biome)
	local t,cycle=clock(elapsed)
	local season=type(remix)=="table" and remix.stampedeEverywhere==true and index~=nil and Encounters.SeasonLane[index]~=nil
	if not t or (index~=2 and not season) then return {visible=false,active=false} end
	for number,run in ipairs(runs) do
		if season and number~=Encounters.SeasonLane[index] then continue end
		if t>=run.start-3 and t<run.start+Encounters.RunLength then
			local active=t>=run.start
			return {visible=true,active=active,warning=not active,run=number,cycle=cycle,
				from={x=run.from.x,z=run.from.z},to={x=run.to.x,z=run.to.z},
				progress=if active then (t-run.start)/Encounters.RunLength else 0,
				seconds=if active then run.start+Encounters.RunLength-t else run.start-t,
				name="STAMPEDE RUN",cue="DASH THROUGH THE LANE"}
		end
	end
	return {visible=false,active=false}
end
function Encounters.runSpeed()
	local run=runs[1]
	return math.abs(run.to.x-run.from.x)/Encounters.RunLength
end

-- GOLDEN FINALE: spawn once per arena cycle at 86s; uncaught goldens leave at 110s.
Encounters.GoldenAt = 86
function Encounters.golden(elapsed, biome, players, remix)
	local index=biomeIndex(biome)
	local t,cycle=clock(elapsed)
	if not t or not index then return {spawn=false,count=0} end
	local count=1+math.floor((math.clamp(if finite(players) then math.floor(players) else 1,1,4)-1)/2)
		+(if index==3 then 1 else 0)
	-- Weekly Remix "Golden Rush": +2 at every finale (bounded to 6).
	local extra=if type(remix)=="table" and finite(remix.extraGoldens) then math.clamp(math.floor(remix.extraGoldens),0,2) else 0
	return {spawn=t>=Encounters.GoldenAt and t<Encounters.Play,count=math.min(4,count)+extra,cycle=cycle,
		remaining=math.max(0,Encounters.Play-t),expiresIn=math.max(0,Encounters.Play-t)}
end

function Encounters.staticStart(biome)
	return if biomeIndex(biome)==3 then 20 else 25
end

-- Personal static spawn candidate. Inputs are random draws from the server RNG.
-- Returns nil when the candidate violates fairness clearances (caller retries).
function Encounters.staticSpawn(angle, radius, player)
	if not finite(angle) or not finite(radius) or type(player)~="table" or not finite(player.x) or not finite(player.z) then return nil end
	if radius<16 or radius>44 then return nil end
	local x,z=math.cos(angle)*radius,math.sin(angle)*radius
	local function far(px,pz,minimum) return (x-px)^2+(z-pz)^2>=minimum*minimum end
	if not far(player.x,player.z,16) or not far(Encounters.Bank.x,Encounters.Bank.z,30) or not far(Encounters.Spawn.x,Encounters.Spawn.z,20) then return nil end
	return {x=x,z=z}
end

-- Drift toward the target at a bounded speed, staying inside the infield.
function Encounters.staticStep(position, target, speed, dt)
	if type(position)~="table" or not finite(position.x) or not finite(position.z) then return nil end
	if not finite(speed) or speed<0 or not finite(dt) or dt<0 then return {x=position.x,z=position.z} end
	local x,z=position.x,position.z
	if type(target)=="table" and finite(target.x) and finite(target.z) then
		local dx,dz=target.x-x,target.z-z
		local length=math.sqrt(dx*dx+dz*dz)
		if length>0.01 then
			local step=math.min(length,speed*math.min(dt,0.5))
			x+=dx/length*step; z+=dz/length*step
		end
	end
	local length=math.sqrt(x*x+z*z)
	if length>46 then x=x/length*46; z=z/length*46 end
	-- Never drift onto the bank gate: statics cannot camp the only scoring point.
	local bx,bz=x-Encounters.Bank.x,z-Encounters.Bank.z
	local bank=math.sqrt(bx*bx+bz*bz)
	if bank<22 then
		if bank>0.01 then x=Encounters.Bank.x+bx/bank*22; z=Encounters.Bank.z+bz/bank*22 else z=Encounters.Bank.z-22 end
	end
	return {x=x,z=z}
end

-- Human-readable phase for HUD banners (shared arena clock).
-- AURORA STARFALL (D22, plan §6.8.1): during arena time 55–85, six star impacts land
-- every 5 s, each telegraphed for 2 s (radius 6). Sparks inside at impact are dazed
-- for 3 s; catching a dazed Spark scores STARSTRUCK. Positive-only: no player damage.
Encounters.StarfallStart = 55
Encounters.StarfallCount = 6
Encounters.StarfallInterval = 5
Encounters.StarfallWarning = 2
Encounters.StarfallRadius = 6
Encounters.DazeSeconds = 3
Encounters.StarfallBankClearance = 24
-- Schedule only (positions are chosen by the server from live Spark clusters).
-- `offset` lets the Daily Stampede shift the same choreography to its own clock.
function Encounters.starfall(elapsed, biome, offset, remix)
	local index=biomeIndex(biome)
	local t,cycle=clock(elapsed)
	-- Weekly Remix "Starfall Everywhere": the same six impacts in every arena.
	local everywhere=type(remix)=="table" and remix.starfallEverywhere==true and index~=nil
	if not t or (index~=3 and not everywhere) then return {visible=false,active=false} end
	t+=if finite(offset) then offset else 0
	for impact=1,Encounters.StarfallCount do
		local at=Encounters.StarfallStart+(impact-1)*Encounters.StarfallInterval
		if t>=at-Encounters.StarfallWarning and t<at then
			return {visible=true,warning=true,active=false,impact=impact,impactAt=at,seconds=at-t,cycle=cycle,
				radius=Encounters.StarfallRadius,name="AURORA STARFALL",cue="CATCH THE DAZED SPARKS"}
		end
	end
	local last=Encounters.StarfallStart+(Encounters.StarfallCount-1)*Encounters.StarfallInterval
	if t>=Encounters.StarfallStart-Encounters.StarfallWarning and t<last+Encounters.DazeSeconds then
		return {visible=true,warning=false,active=true,impact=nil,cycle=cycle,radius=Encounters.StarfallRadius,
			seconds=math.max(0,last+Encounters.DazeSeconds-t),name="AURORA STARFALL",cue="CATCH THE DAZED SPARKS"}
	end
	return {visible=false,active=false}
end
-- Impact spot near the densest Spark cluster. candidates: arena-relative {x,z} list;
-- jitter: two numbers in [0,1) from the server RNG. Always returns a fair spot:
-- >= 24 studs from the bank, inside the herd area, clear of obstacles.
function Encounters.starfallSpot(candidates, jitterA, jitterB, biome)
	local best,bestCount=nil,-1
	if type(candidates)=="table" then
		for i,a in ipairs(candidates) do
			if i>64 then break end
			if type(a)=="table" and finite(a.x) and finite(a.z) then
				local n=0
				for j,b in ipairs(candidates) do
					if j>64 then break end
					if type(b)=="table" and finite(b.x) and finite(b.z) and (a.x-b.x)^2+(a.z-b.z)^2<=64 then n+=1 end
				end
				if n>bestCount then best,bestCount=a,n end
			end
		end
	end
	local ja=if finite(jitterA) then math.clamp(jitterA,0,1) else 0.5
	local jb=if finite(jitterB) then math.clamp(jitterB,0,1) else 0.5
	local x=(if best then best.x else 0)+(ja-0.5)*4
	local z=(if best then best.z else -10)+(jb-0.5)*4
	local function fair(px,pz)
		return px*px+pz*pz<=40*40 and (px-Encounters.Bank.x)^2+(pz-Encounters.Bank.z)^2>=Encounters.StarfallBankClearance^2
			and Encounters.clearOfObstacles(biome or 3,px,pz,1)
	end
	if fair(x,z) then return {x=x,z=z} end
	-- Pull toward the infield centre until fair; the centre-north fallback always is.
	for step=1,10 do
		local k=1-step/10
		local px,pz=x*k,(z+10)*k-10
		if fair(px,pz) then return {x=px,z=pz} end
	end
	return {x=0,z=-10}
end

function Encounters.describe(elapsed, biome)
	local index=biomeIndex(biome)
	local t=clock(elapsed)
	if not t or not index then return {phase="WARM UP",next=nil,nextIn=0} end
	local upcoming
	if index==2 then upcoming={name="STAMPEDE RUN",at=55}
	elseif index==3 then upcoming={name="AURORA STARFALL",at=53}
	else upcoming={name="SPARK GATE",at=52} end
	if t<upcoming.at then return {phase=if t<25 then "WARM UP" else "RHYTHM SHIFT",next=upcoming.name,nextIn=upcoming.at-t} end
	if t<85 then return {phase=upcoming.name,next="GOLDEN FINALE",nextIn=86-t} end
	if t<Encounters.Play then return {phase="GOLDEN FINALE",next=nil,nextIn=0} end
	return {phase="INTERMISSION",next="STAMPEDE",nextIn=Encounters.Cycle-t}
end

return Encounters
