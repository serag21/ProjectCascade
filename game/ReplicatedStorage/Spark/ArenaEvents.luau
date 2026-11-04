-- Pure biome event choreography. Main owns hits/motion; clients only draw warnings.
-- Paths stay in the infield, clear of the bank/spawn and four steering islands.
local ArenaEvents={}
local ids={meadow=1,canyon=2,aurora=3}
local hazards={
	{name="MEADOW SWEEP",cue="STEP OUT"},
	{name="CANYON CROSSING",cue="SIDESTEP"},
	{name="AURORA WEAVE",cue="READ THE LOOP"},
}
local phases={0,25,55,85,110}
local events={
	{
		{name="MEADOW WARM UP",speedScale=.65,turnScale=1},
		{name="MEADOW PARADE",speedScale=.8,turnScale=.8},
		{name="MEADOW BOUND",speedScale=1.25,turnScale=1.1},
		{name="GOLDEN MEADOW",speedScale=1.1,turnScale=.9},
	},
	{
		{name="CANYON WARM UP",speedScale=.65,turnScale=1},
		{name="CANYON CRUISE",speedScale=.9,turnScale=.7},
		{name="CANYON TAILWIND",speedScale=1.4,turnScale=.65},
		{name="CANYON SWITCHBACK",speedScale=1.15,turnScale=1.35},
	},
	{
		{name="AURORA WARM UP",speedScale=.65,turnScale=1},
		{name="AURORA DRIFT",speedScale=.75,turnScale=.7},
		{name="AURORA TWIRL",speedScale=1.15,turnScale=1.4},
		{name="STAR PARADE",speedScale=1.3,turnScale=.9},
	},
}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function biomeIndex(biome)
	if type(biome)=="string" then return ids[biome] end
	if finite(biome) and biome%1==0 and biome>=1 and biome<=3 then return biome end
	return nil
end
local function hidden() return {visible=false,active=false,warning=false} end

function ArenaEvents.hazard(elapsed,difficulty,biome)
	local index=biomeIndex(biome)
	if not index or not finite(elapsed) or elapsed<25 then return hidden() end
	local tier=if finite(difficulty) then math.clamp(difficulty,1,3) else 1
	local age=elapsed-25
	local cycle=age%14
	if cycle>=6 then return hidden() end
	local rate=.14+tier*.03
	-- Reduce before multiplying so every finite input yields finite geometry.
	local angle=(age%(2*math.pi/rate))*rate
	local x,z
	if index==1 then x=math.cos(angle)*18; z=math.sin(angle)*18
	elseif index==2 then x=math.sin(angle)*18; z=-5
	else x=math.sin(angle)*16; z=math.sin(angle*2)*12-3 end
	local def=hazards[index]
	return {visible=true,active=cycle>=2,warning=cycle<2,x=x,z=z,radius=3.5,
		seconds=if cycle<2 then 2-cycle else 6-cycle,name=def.name,cue=def.cue}
end

-- Shared arena clock, independent of personal joins/replays. Return fresh tables:
-- callers cannot mutate future samples or another player's event state.
function ArenaEvents.herd(elapsed,biome)
	local index=biomeIndex(biome)
	if not index or not finite(elapsed) or elapsed<0 then
		return {name="WARM UP",speedScale=1,turnScale=1,remaining=0,phase=0}
	end
	local cycle=elapsed%110
	local phase=1
	for i=2,4 do if cycle>=phases[i] then phase=i end end
	local def=events[index][phase]
	return {name=def.name,speedScale=def.speedScale,turnScale=def.turnScale,
		remaining=phases[phase+1]-cycle,phase=phase}
end
return ArenaEvents
