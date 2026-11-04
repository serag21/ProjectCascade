-- Pure arena encounter choreography on the shared 110s arena clock. Because a
-- personal round is also 110s, every round contains each encounter exactly once
-- no matter when a player joined. Coordinates are relative to the arena origin.
-- Main owns spawning, hits and rewards; clients only draw what the server sends.
local Encounters = {}
Encounters.Cycle = 110
Encounters.Island = 26.163
Encounters.Bank = {x=0, z=44}
Encounters.Spawn = {x=0, z=38}

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

-- SPARK GATE (Pop Meadow, Aurora Arcade): drift through the infield, never over the
-- bank approach. Sparks herded through it join the herder's parade.
Encounters.GateRadius = 6
function Encounters.gate(elapsed, biome)
	local index=biomeIndex(biome)
	local t,cycle=clock(elapsed)
	if not t or (index~=1 and index~=3) or t<52 or t>=85 then return {visible=false,active=false} end
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
function Encounters.stampede(elapsed, biome)
	local index=biomeIndex(biome)
	local t,cycle=clock(elapsed)
	if not t or index~=2 then return {visible=false,active=false} end
	for number,run in ipairs(runs) do
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
function Encounters.golden(elapsed, biome, players)
	local index=biomeIndex(biome)
	local t,cycle=clock(elapsed)
	if not t or not index then return {spawn=false,count=0} end
	local count=1+math.floor((math.clamp(if finite(players) then math.floor(players) else 1,1,4)-1)/2)
		+(if index==3 then 1 else 0)
	return {spawn=t>=Encounters.GoldenAt,count=math.min(4,count),cycle=cycle,
		remaining=Encounters.Cycle-t,expiresIn=math.max(0,Encounters.Cycle-t)}
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
function Encounters.describe(elapsed, biome)
	local index=biomeIndex(biome)
	local t=clock(elapsed)
	if not t or not index then return {phase="WARM UP",next=nil,nextIn=0} end
	local upcoming
	if index==2 then upcoming={name="STAMPEDE RUN",at=55} else upcoming={name="SPARK GATE",at=52} end
	if t<upcoming.at then return {phase=if t<25 then "WARM UP" else "RHYTHM SHIFT",next=upcoming.name,nextIn=upcoming.at-t} end
	if t<85 then return {phase=upcoming.name,next="GOLDEN FINALE",nextIn=86-t} end
	return {phase="GOLDEN FINALE",next=nil,nextIn=0}
end

return Encounters
