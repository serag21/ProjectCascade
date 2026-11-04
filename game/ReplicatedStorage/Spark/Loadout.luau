-- Perk side-grades and opt-in Heat difficulty. Pure and shared: the server derives
-- every gameplay stat from the saved profile; the client only displays the result.
-- Every perk has an explicit upside AND downside so loadouts are choices, not power.
local Config = if script then require(script.Parent.Config) else require("./Config")
local Loadout = {}

Loadout.Perks = {
	{id="reach", name="Long Reach", rank=2, up="+2.5 catch reach", down="Precision needs a straighter facing"},
	{id="rhythm", name="Rhythm Keeper", rank=3, up="Chains last 2s longer", down="Multiplier caps at x3"},
	{id="slipstream", name="Slipstream", rank=4, up="Dash-through catches up to 4, wider path", down="Dash recovers 0.5s slower"},
	{id="pockets", name="Deep Pockets", rank=6, up="Carry 4 more Sparks", down="Haul bonus caps at x1.3"},
	{id="breaker", name="Static Breaker", rank=8, up="Popping statics is worth +60", down="Zaps scatter one extra Spark"},
	{id="gatekeeper", name="Gate Keeper", rank=10, up="Herded and assist points doubled", down="-1 catch reach"},
	{id="quickpaws", name="Quick Paws", rank=12, up="Catch cooldown 0.50s", down="A miss locks catching for 0.6s"},
	{id="goldnose", name="Golden Nose", rank=14, up="Golden compass, golden worth +50%", down="Dash catch bonus halved"},
}
local byId = {}
for index, perk in ipairs(Loadout.Perks) do perk.order = index; byId[perk.id] = perk end
Loadout.ById = byId

Loadout.MaxHeat = 5
Loadout.Heat = {
	[0]={name="Calm", description="The standard stampede."},
	{name="Fizz", description="One more static puff, spawning sooner."},
	{name="Quick Rhythm", description="Chains expire 1s sooner."},
	{name="Static Storm", description="Another static; zaps scatter 3 Sparks."},
	{name="Tight Paws", description="Catch reach -2.5."},
	{name="Heartbeat", description="Chains 1s shorter again, faster statics, shorter sweep warning."},
}
Loadout.SilverScore = Config.Medals.Silver

local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function int(n, low, high)
	if not finite(n) then return low end
	return math.clamp(math.floor(n), low, high)
end

function Loadout.slots(rank)
	rank = int(rank, 1, 1000)
	if rank < 2 then return 0 end
	return if rank >= 15 then 3 else 2
end

-- Unknown, duplicate, locked or excess perks are discarded in order.
function Loadout.sanitize(perks, rank)
	local result, seen = {}, {}
	if type(perks) ~= "table" then return result end
	local slots = Loadout.slots(rank)
	for index = 1, math.min(#perks, 8) do
		local id = perks[index]
		local perk = type(id) == "string" and byId[id] or nil
		if perk and not seen[id] and int(rank,1,1000) >= perk.rank and #result < slots then
			seen[id] = true; table.insert(result, id)
		end
	end
	return result
end

-- records[biomeId][heat+1] = best score at that heat. Heat n+1 opens with a Silver at heat n.
function Loadout.heatUnlocked(records)
	local unlocked = 0
	if type(records) ~= "table" then return 0 end
	for heat = 0, Loadout.MaxHeat - 1 do
		local silver = false
		for _, biome in ipairs(Config.Biomes) do
			local row = records[biome.id]
			local score = type(row) == "table" and row[heat + 1] or nil
			if finite(score) and score >= Loadout.SilverScore then silver = true; break end
		end
		if not silver then break end
		unlocked = heat + 1
	end
	return unlocked
end

local function has(list, id)
	for _, value in ipairs(list) do if value == id then return true end end
	return false
end

-- upgrades: profile.upgrades; perks: sanitized list; heat: 0..5.
function Loadout.stats(upgrades, perks, heat)
	upgrades = if type(upgrades) == "table" then upgrades else {}
	perks = if type(perks) == "table" then perks else {}
	heat = int(heat, 0, Loadout.MaxHeat)
	local boots, magnet, basket = int(upgrades.boots,0,3), int(upgrades.magnet,0,3), int(upgrades.basket,0,3)
	local radius = Config.CaptureRadius + magnet * Config.Upgrades.magnet.radiusPerLevel
	if has(perks, "reach") then radius += 2.5 end
	if has(perks, "gatekeeper") then radius -= 1 end
	if heat >= 4 then radius -= 2.5 end
	local chain = 6
	if has(perks, "rhythm") then chain += 2 end
	if heat >= 2 then chain -= 1 end
	if heat >= 5 then chain -= 1 end
	local staticCap = 1 + (if heat >= 1 then 1 else 0) + (if heat >= 3 then 1 else 0) + (if heat >= 5 then 1 else 0)
	local scatter = 2 + (if heat >= 3 then 1 else 0) + (if has(perks, "breaker") then 1 else 0)
	return {
		heat = heat,
		perks = table.clone(perks),
		captureRadius = math.max(5, radius),
		capacity = Config.MaxCarry + basket * Config.Upgrades.basket.capacityPerLevel + (if has(perks, "pockets") then 4 else 0),
		dashCooldown = math.max(1, Config.DashCooldown - boots * Config.Upgrades.boots.cooldownReduction) + (if has(perks, "slipstream") then 0.5 else 0),
		captureCooldown = if has(perks, "quickpaws") then 0.5 else Config.CaptureCooldown,
		missLock = if has(perks, "quickpaws") then 0.6 else 0,
		precisionFacing = if has(perks, "reach") then 0.85 else 0.7,
		chainSeconds = chain,
		maxMultiplier = if has(perks, "rhythm") then 3 else 4,
		-- Live tiers: x2 from a 6-chain, x3 from 11, x4 STAMPEDE from 16.
		chainStep = 5,
		medals = Config.Medals,
		dashCatchLimit = if has(perks, "slipstream") then 4 else 2,
		dashCatchRadius = if has(perks, "slipstream") then 5.5 else 4.5,
		haulCap = if has(perks, "pockets") then 1.3 else 1.5,
		popPoints = if has(perks, "breaker") then 60 else 40,
		zapScatter = scatter,
		herdMultiplier = if has(perks, "gatekeeper") then 2 else 1,
		goldenMultiplier = if has(perks, "goldnose") then 1.5 else 1,
		goldenCompass = has(perks, "goldnose"),
		dashBonus = if has(perks, "goldnose") then 10 else 20,
		staticCap = staticCap,
		staticInterval = if heat >= 1 then 7 else 9,
		staticSpeed = if heat >= 5 then 12.5 else 8,
		sweepWarning = if heat >= 5 then 1.5 else 2,
		scoreMultiplier = 1 + 0.2 * heat,
	}
end

return Loadout
