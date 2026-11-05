-- DAILY STAMPEDE: one seeded 75-second solo run, identical for every player on a UTC
-- day, scored with NORMALIZED rules (upgrades, perks and heat ignored) so the public
-- daily leaderboard compares skill, not progression. Pure and engine-independent.
--
-- Determinism: the plan uses only integer hashing (bit32), a Park-Miller LCG and
-- IEEE + - * / comparisons on a 0.1-stud grid (no sin/cos/math.random), so every
-- server and client derives bit-identical plans. Changing Config.Creatures (order,
-- biome or rarity), Encounters geometry or the constants below changes the plans:
-- ship such changes at a UTC day boundary so one day's board never mixes layouts.
local Config = if script then require(script.Parent.Config) else require("./Config")
local Encounters = if script then require(script.Parent.Encounters) else require("./Encounters")
local Trial = {}

Trial.RunSeconds = 75
Trial.SparkCount = 20
Trial.FirstRunGlow = 40
Trial.FirstRunXp = 80
Trial.XpRunsPerDay = 5
-- Calibrated 2026-11-05 by tools/economy_model.luau (synthetic archetypes): novice
-- median Bronze, regular median Silver / p90 Gold, expert median Gold / p90 Radiant.
Trial.Medals = {Bronze=300, Silver=800, Gold=2000, Radiant=5000}

-- Run choreography (seconds into the run).
Trial.GoldenAt = 50
Trial.StaticsFrom = 15
Trial.RunAt = 30
Trial.RunLength = Encounters.RunLength
Trial.RunWarning = 3
Trial.Encounters = {"gate", "stampede", "starfall"}

-- Spawn fairness clearances (arena-relative studs).
Trial.MinRadius = 12
Trial.MaxRadius = 42
Trial.BankClearance = 26
Trial.SpawnClearance = 10
Trial.IslandClearance = 7
Trial.Separation = 4
-- Random candidates tried before the deterministic grid scan. Part of the plan
-- contract: never change at runtime (tests lower it to exercise the fallback).
Trial.PlacementAttempts = 48
Trial.RarityWeights = {Common=5, Uncommon=3, Rare=2}

-- Theoretical score ceiling inputs (see Trial.maxScore).
Trial.CaptureInterval = 0.6
Trial.StyleBonus = {precision=15, dash=20, multi=25, herd=40, starstruck=30, signature=15}
Trial.GoldenBonus = 250
Trial.FinaleFactor = 1.25
Trial.GoalBonus = 100

local DAY = 86400
local TWO32 = 4294967296
local MAX_DAY = 2147483647
local MINSTD_M, MINSTD_A = 2147483647, 48271
local BANK, SPAWN, ISLAND = Encounters.Bank, Encounters.Spawn, Encounters.Island
local ISLANDS = {{-ISLAND, -ISLAND}, {-ISLAND, ISLAND}, {ISLAND, -ISLAND}, {ISLAND, ISLAND}}

local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function dayIndex(day)
	if not finite(day) then return 0 end
	return math.clamp(math.floor(day), 0, MAX_DAY)
end

-- (a*b) mod 2^32 for 0 <= a,b < 2^32 using only exact double arithmetic (< 2^53).
local function mul32(a, b)
	local low = a * (b % 65536)
	local high = (a * math.floor(b / 65536)) % 65536 * 65536
	return (low + high) % TWO32
end
-- lowbias32 integer finalizer (a bijection on 32-bit values).
local function hash32(x)
	x = x % TWO32
	x = bit32.bxor(x, bit32.rshift(x, 16))
	x = mul32(x, 0x7feb352d)
	x = bit32.bxor(x, bit32.rshift(x, 15))
	x = mul32(x, 0x846ca68b)
	x = bit32.bxor(x, bit32.rshift(x, 16))
	return x
end

-- Park-Miller minimal standard LCG; returns randint(n) -> integer 0..n-1.
local function generator(seed)
	local state = seed % (MINSTD_M - 1) + 1
	local function nextState()
		state = (state * MINSTD_A) % MINSTD_M
		return state
	end
	nextState(); nextState()
	return function(n)
		return math.floor(nextState() / MINSTD_M * n)
	end
end

-- Species pools per biome, in Config order, weighted by rarity.
local pools = {}
for _, creature in ipairs(Config.Creatures) do
	local biome = creature.biome
	pools[biome] = pools[biome] or {total=0}
	local weight = Trial.RarityWeights[creature.rarity] or 1
	table.insert(pools[biome], {id=creature.id, weight=weight})
	pools[biome].total += weight
end
local function pick(randint, biome)
	local pool = pools[biome]
	local roll = randint(pool.total)
	for _, entry in ipairs(pool) do
		if roll < entry.weight then return entry.id end
		roll -= entry.weight
	end
	return pool[#pool].id
end

local function far(x, z, px, pz, minimum)
	local dx, dz = x - px, z - pz
	return dx * dx + dz * dz >= minimum * minimum
end
-- Static clearances shared by initial spawns and respawns.
local function staticClear(x, z)
	local r2 = x * x + z * z
	if r2 < Trial.MinRadius * Trial.MinRadius or r2 > Trial.MaxRadius * Trial.MaxRadius then return false end
	if not far(x, z, BANK.x, BANK.z, Trial.BankClearance) then return false end
	if not far(x, z, SPAWN.x, SPAWN.z, Trial.SpawnClearance) then return false end
	for _, island in ipairs(ISLANDS) do
		if not far(x, z, island[1], island[2], Trial.IslandClearance) then return false end
	end
	return true
end

-- Random 0.1-stud grid candidates, then a deterministic 1-stud grid scan from a
-- seeded offset. The final constant (0,-27) satisfies every static clearance.
local GRID_SIDE = Trial.MaxRadius * 2 + 1
local function place(randint, accept)
	local span = Trial.MaxRadius * 20 + 1
	for _ = 1, Trial.PlacementAttempts do
		local x = (randint(span) - Trial.MaxRadius * 10) / 10
		local z = (randint(span) - Trial.MaxRadius * 10) / 10
		if accept(x, z) then return x, z end
	end
	local cells = GRID_SIDE * GRID_SIDE
	local start = randint(cells)
	for step = 0, cells - 1 do
		local index = (start + step) % cells
		local x, z = index % GRID_SIDE - Trial.MaxRadius, math.floor(index / GRID_SIDE) - Trial.MaxRadius
		if accept(x, z) then return x, z end
	end
	return 0, -27
end

function Trial.day(now)
	if not finite(now) then return 0 end
	return dayIndex(now / DAY)
end

-- Deterministic 31-bit seed (0..2^31-1) for a UTC day index.
function Trial.seed(day)
	return bit32.band(hash32(dayIndex(day) + 0x5EED1E55), 0x7FFFFFFF)
end

function Trial.plan(day)
	local index = dayIndex(day)
	local seed = Trial.seed(index)
	local biome = index % 3 + 1
	local randint = generator(seed)
	local spawns = {}
	local function accept(x, z)
		if not staticClear(x, z) then return false end
		for _, other in ipairs(spawns) do
			if not far(x, z, other.x, other.z, Trial.Separation) then return false end
		end
		return true
	end
	for i = 1, Trial.SparkCount do
		local species = pick(randint, biome)
		local x, z = place(randint, accept)
		spawns[i] = {species=species, x=x, z=z}
	end
	return {day=index, seed=seed, biome=biome, biomeId=Config.Biomes[biome].id, encounter=Trial.Encounters[biome],
		goldenAt=Trial.GoldenAt, staticsFrom=Trial.StaticsFrom, runAt=Trial.RunAt, spawns=spawns}
end

-- k-th respawn (k = 1, 2, ...) of a plan. Static clearances only: live Sparks move,
-- so separation from the opening layout is meaningless. nil for invalid input.
function Trial.respawn(plan, k)
	if type(plan) ~= "table" or not pools[plan.biome] then return nil end
	local seed = plan.seed
	if not finite(seed) or seed % 1 ~= 0 or seed < 0 or seed > 0x7FFFFFFF then return nil end
	if not finite(k) or k % 1 ~= 0 or k < 1 or k > MAX_DAY then return nil end
	local randint = generator(bit32.band(hash32(bit32.bxor(seed, hash32(k + 0x632BE5AB))), 0x7FFFFFFF))
	local species = pick(randint, plan.biome)
	local x, z = place(randint, staticClear)
	return {species=species, x=x, z=z}
end

-- Normalized rules: same keys as Loadout.stats(...), fixed values, fresh tables.
function Trial.stats()
	return {
		heat = 0,
		perks = {},
		captureRadius = 11.5,
		capacity = 10,
		dashCooldown = 2.3,
		captureCooldown = 0.65,
		missLock = 0,
		precisionFacing = 0.7,
		chainSeconds = 6,
		maxMultiplier = 4,
		chainStep = 5,
		medals = table.clone(Trial.Medals),
		dashCatchLimit = 3,
		dashCatchRadius = 4.5,
		haulCap = 1.5,
		popPoints = 40,
		zapScatter = 2,
		herdMultiplier = 1,
		goldenMultiplier = 1,
		goldenCompass = false,
		dashBonus = 20,
		staticCap = 2,
		staticInterval = 8,
		staticSpeed = 8,
		sweepWarning = 2,
		scoreMultiplier = 1,
	}
end

-- Generous theoretical ceiling: every button catch at the 0.6s server interval plus
-- every dash at full dashCatchLimit, each scoring the richest base with EVERY style
-- bonus at once (mutually exclusive in real play) at the top multiplier; one extra
-- golden catch; every static popped from t=0; haul cap, finale factor and goal on all.
local function computeMaxScore()
	local s = Trial.stats()
	local maxValue = 0
	for _, creature in ipairs(Config.Creatures) do maxValue = math.max(maxValue, creature.value) end
	local styles = 0
	for _, bonus in pairs(Trial.StyleBonus) do styles += bonus end
	local buttonCatches = math.floor(Trial.RunSeconds / Trial.CaptureInterval + 1e-9) + 1
	local dashCatches = (math.floor(Trial.RunSeconds / s.dashCooldown + 1e-9) + 1) * s.dashCatchLimit
	local perCatch = (10 + 2 * maxValue + styles) * s.maxMultiplier
	local golden = perCatch + Trial.GoldenBonus * s.goldenMultiplier * s.maxMultiplier
	local pops = (math.floor(Trial.RunSeconds / s.staticInterval + 1e-9) + 1) * s.staticCap * s.popPoints
	local raw = ((buttonCatches + dashCatches) * perCatch + golden + pops) * s.haulCap * Trial.FinaleFactor
	return math.ceil(raw * s.scoreMultiplier) + Trial.GoalBonus
end
local MAX_SCORE = computeMaxScore()

function Trial.maxScore()
	return MAX_SCORE
end

function Trial.validScore(score)
	return finite(score) and score % 1 == 0 and score >= 0 and score <= MAX_SCORE
end

-- XP for the runIndexToday-th completed run (1-based); only the first XpRunsPerDay pay.
function Trial.xpFor(score, runIndexToday)
	if not Trial.validScore(score) then return 0 end
	if not finite(runIndexToday) or runIndexToday % 1 ~= 0 or runIndexToday < 1 or runIndexToday > Trial.XpRunsPerDay then return 0 end
	return math.floor(2 * math.sqrt(score)) + 20
end

function Trial.medal(score)
	if not finite(score) then return "Unranked" end
	local m = Trial.Medals
	if score >= m.Radiant then return "Radiant" elseif score >= m.Gold then return "Gold"
	elseif score >= m.Silver then return "Silver" elseif score >= m.Bronze then return "Bronze" end
	return "Unranked"
end

-- Settle one finished run into the profile (pure; the server and the economy model
-- share it). Only completed runs (>= Cycle.CompletionCatches catches) count: they
-- advance runsToday, may set today's best (with ghost-split checkpoints), pay the
-- once-per-UTC-day reward (+40 glow, +80 XP) and capped XP for the first five runs,
-- and progress the "Finish today's Daily Stampede" goal. Abandoned runs never get here.
local MAX_COINS = 2000000000
function Trial.settle(profile, day, score, catches, checkpoints, now)
	local Progression = if script then require(script.Parent.Progression) else require("./Progression")
	local Challenge = if script then require(script.Parent.Challenge) else require("./Challenge")
	local Cycle = if script then require(script.Parent.Cycle) else require("./Cycle")
	local t = profile.trial
	day = dayIndex(day)
	if t.runsDay ~= day then t.runsDay = day; t.runsToday = 0 end
	if t.day ~= day then t.day = day; t.best = 0; t.bestRun = nil end
	local completed = Cycle.completed(catches)
	local valid = Trial.validScore(score)
	local result = {completed = completed, valid = valid, improved = false, glow = 0, xp = 0, score = if valid then score else 0}
	if completed then
		t.runsToday = math.min(1000, t.runsToday + 1)
		if valid and score > t.best then
			t.best = score
			t.bestRun = Challenge.sanitizeBestRun({score = score, checkpoints = checkpoints})
			result.improved = true
		end
		if t.rewardedDay ~= day then
			t.rewardedDay = day
			result.glow = Trial.FirstRunGlow; result.xp += Trial.FirstRunXp
			profile.coins = math.min(profile.coins + result.glow, MAX_COINS)
		end
		if valid then result.xp += Trial.xpFor(score, t.runsToday) end
		if result.xp > 0 then Progression.awardXp(profile, result.xp) end
		Progression.recordTrialRun(profile, now)
	end
	result.best = t.best
	result.runsToday = t.runsToday
	result.xpRunsLeft = math.max(0, Trial.XpRunsPerDay - t.runsToday)
	return result
end

-- Run phase at `elapsed` seconds. Plan timings are used when valid, else defaults.
-- runWarning/runActive mark the plan's encounter window [runAt, runAt+RunLength)
-- (the lane run for a "stampede" plan); `encounter` says which one it is.
function Trial.schedule(elapsed, plan)
	local t = if finite(elapsed) then math.max(0, elapsed) else 0
	local function timing(key, default)
		local value = if type(plan) == "table" then plan[key] else nil
		return if finite(value) and value >= 0 and value <= Trial.RunSeconds then value else default
	end
	local goldenAt, staticsFrom, runAt = timing("goldenAt", Trial.GoldenAt), timing("staticsFrom", Trial.StaticsFrom), timing("runAt", Trial.RunAt)
	local finished = t >= Trial.RunSeconds
	local runActive = not finished and t >= runAt and t < runAt + Trial.RunLength
	return {
		elapsed = t,
		remaining = math.max(0, Trial.RunSeconds - t),
		finished = finished,
		golden = t >= goldenAt,
		staticsActive = not finished and t >= staticsFrom,
		runWarning = not finished and t >= runAt - Trial.RunWarning and t < runAt,
		runActive = runActive,
		runProgress = if runActive then (t - runAt) / Trial.RunLength else 0,
		encounter = if type(plan) == "table" and type(plan.encounter) == "string" then plan.encounter else nil,
	}
end

return Trial
