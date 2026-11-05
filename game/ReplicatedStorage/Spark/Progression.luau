-- Long-term progression: rank XP, achievements, daily/weekly goals and earned
-- cosmetics. Pure and server-authoritative; the client renders snapshots only.
-- No streaks, no loss for missed days, no paid skips, no random paid rewards.
local Config = if script then require(script.Parent.Config) else require("./Config")
local Loadout = if script then require(script.Parent.Loadout) else require("./Loadout")
local Progression = {}
local MAX_COUNT, MAX_COINS, MAX_XP = 1000000, 2000000000, 100000000
Progression.MaxRank = 50
Progression.DailyGlow, Progression.DailyXp, Progression.DailyBonus = 30, 60, 50
Progression.WeeklyGlow, Progression.WeeklyXp = 150, 300

local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function int(n, limit)
	if not finite(n) then return 0 end
	return math.clamp(math.floor(n), 0, limit or MAX_COUNT)
end

-- Rank r needs 100*(r-1)^2 cumulative XP. Round XP grows with the square root
-- of score, so experts progress ~2x (not 10x) faster than newcomers. Rank 2
-- (first perks) follows any first round scoring 100+; rank 50 is a long goal.
function Progression.xpFor(rank)
	rank = math.clamp(math.floor(if finite(rank) then rank else 1), 1, Progression.MaxRank)
	return 100 * (rank - 1) * (rank - 1)
end
function Progression.rank(xp)
	xp = int(xp, MAX_XP)
	local rank = 1
	while rank < Progression.MaxRank and xp >= Progression.xpFor(rank + 1) do rank += 1 end
	return rank
end
function Progression.rankProgress(xp)
	local rank = Progression.rank(xp)
	local floor = Progression.xpFor(rank)
	local nextXp = if rank < Progression.MaxRank then Progression.xpFor(rank + 1) else floor
	return {rank=rank, xp=int(xp,MAX_XP), floor=floor, nextXp=nextXp,
		fraction=if nextXp > floor then (int(xp,MAX_XP) - floor) / (nextXp - floor) else 1}
end
-- completed=false (fewer than Cycle.CompletionCatches catches) earns no
-- completion bonus, so idling through rounds never levels a player (D17).
function Progression.roundXp(score, completed)
	return math.floor(math.sqrt(int(score)) * 4) + (if completed == false then 0 else 60)
end

-- Earned cosmetics. Prices are guaranteed and shown; nothing is random or paid.
Progression.Trails = {
	{id="none", name="No trail", colors={{255,255,255},{255,255,255}}},
	{id="sunbeam", name="Sunbeam", price=300, colors={{255,226,92},{255,170,64}}},
	{id="mintwave", name="Mint Wave", price=500, colors={{110,240,190},{80,200,255}}},
	{id="lagoon", name="Lagoon", rank=5, colors={{70,205,255},{120,255,220}}},
	{id="bubblegum", name="Bubblegum", price=800, colors={{255,140,200},{255,214,240}}},
	{id="ember", name="Ember Fizz", price=1200, colors={{255,120,80},{255,200,90}}},
	{id="aurora", name="Aurora Ribbon", rank=9, colors={{140,120,255},{255,150,230}}},
	{id="candyfloss", name="Candyfloss", price=1500, colors={{255,190,230},{190,220,255}}},
	{id="comet", name="Comet Tail", price=2000, colors={{200,240,255},{120,160,255}}},
	{id="prism", name="Prism Split", rank=13, colors={{255,120,120},{120,200,255}}},
	{id="tidepool", name="Tidepool", price=2500, colors={{60,190,200},{230,255,250}}},
	{id="neonmint", name="Neon Mint", price=3500, rank=10, colors={{120,255,170},{255,255,140}}},
	{id="starlight", name="Starlight", rank=20, colors={{255,255,220},{170,220,255}}},
	{id="sunset", name="Sunset Parade", price=5000, rank=15, colors={{255,150,90},{200,110,220}}},
	{id="royal", name="Royal Parade", price=6000, rank=30, colors={{180,120,255},{255,214,90}}},
	{id="galaxy", name="Galaxy Swirl", price=8000, rank=25, colors={{80,70,200},{255,170,250}}},
	{id="rainbowroad", name="Rainbow Road", price=12000, rank=35, colors={{255,110,110},{110,200,255}}},
	{id="gilded", name="Gilded Dash", achievement="golden_10", colors={{255,214,80},{255,245,180}}},
	{id="gildedalbum", name="Golden Herd", achievement="gilded_album", colors={{255,236,140},{255,190,60}}},
	{id="radiant", name="Radiant Bloom", achievement="radiant_medal", colors={{255,255,255},{255,190,250}}},
	{id="heartbeat", name="Heartbeat", achievement="heat_5", colors={{255,90,120},{255,180,120}}},
	{id="legend", name="Legend Stream", rank=50, colors={{255,255,255},{255,214,90}}},
}
local trailById = {}
for _, trail in ipairs(Progression.Trails) do trailById[trail.id] = trail end
Progression.TrailById = trailById

local function bestRecord(profile, biomeId, minimumHeat)
	local best = 0
	local row = profile.records and profile.records[biomeId]
	if type(row) ~= "table" then return 0 end
	for heat = minimumHeat or 0, Loadout.MaxHeat do best = math.max(best, int(row[heat + 1])) end
	return best
end
local function anyRecord(profile, threshold, minimumHeat)
	for _, biome in ipairs(Config.Biomes) do
		if bestRecord(profile, biome.id, minimumHeat) >= threshold then return true end
	end
	return false
end
local function mutationAtLeast(profile, level)
	for _, value in pairs(profile.mutations or {}) do if value >= level then return true end end
	return false
end
local function speciesCount(profile)
	local count = 0
	for _, creature in ipairs(Config.Creatures) do if (profile.album[creature.id] or 0) > 0 then count += 1 end end
	return count
end
local function stat(profile, key) return int(profile.stats and profile.stats[key]) end

Progression.Achievements = {
	{id="first_spark", name="First Spark", description="Bank your first Spark.", xp=50, test=function(p) return p.totalBanked>=1 end},
	{id="stampede", name="Stampede!", description="Reach a 10-catch chain (x4).", xp=300, title="Stampeder", test=function(p) return p.mastery.bestChain>=10 end},
	{id="triple_dash", name="Triple Dash", description="Catch 3 Sparks in one dash.", xp=250, test=function(p) return stat(p,"bestMulti")>=3 end},
	{id="quad_dash", name="Quad Dash", description="Catch 4 Sparks in one dash.", xp=500, title="Slipstreamer", test=function(p) return stat(p,"bestMulti")>=4 end},
	{id="gate_herder", name="Gate Herder", description="Herd 10 Sparks through Spark Gates.", xp=250, title="Herder", test=function(p) return stat(p,"herded")>=10 end},
	{id="wingmate", name="Wingmate", description="Earn 10 herding assists with friends.", xp=300, title="Wingmate", test=function(p) return stat(p,"assists")>=10 end},
	{id="static_popper", name="Static Popper", description="Pop 50 statics with a dash.", xp=300, test=function(p) return stat(p,"pops")>=50 end},
	{id="golden_1", name="Golden Touch", description="Catch a Golden Spark.", xp=150, test=function(p) return stat(p,"golden")>=1 end},
	{id="golden_10", name="Gold Rush", description="Catch 10 Golden Sparks.", xp=500, title="Prospector", test=function(p) return stat(p,"golden")>=10 end},
	{id="gold_medal", name="Gold Parade", description="Earn a Gold round (2,500 skill).", xp=300, test=function(p) return anyRecord(p,Config.Medals.Gold) end},
	{id="radiant_medal", name="Radiant Parade", description="Earn a Radiant round (5,000 skill).", xp=600, title="Radiant", test=function(p) return anyRecord(p,Config.Medals.Radiant) end},
	{id="triple_gold", name="Triple Gold", description="Gold in all three arenas.", xp=600, test=function(p)
		for _, biome in ipairs(Config.Biomes) do if bestRecord(p,biome.id)<Config.Medals.Gold then return false end end
		return true end},
	{id="heat_1", name="Feeling the Heat", description="Bronze at Heat 1 or higher.", xp=200, test=function(p) return anyRecord(p,Config.Medals.Bronze,1) end},
	{id="heat_3", name="Static Storm Survivor", description="Bronze at Heat 3 or higher.", xp=400, test=function(p) return anyRecord(p,Config.Medals.Bronze,3) end},
	{id="heat_5", name="Heartbeat Hero", description="Bronze at Heat 5.", xp=800, title="Heartbeat", test=function(p) return anyRecord(p,Config.Medals.Bronze,5) end},
	{id="heat_5_gold", name="Unstoppable", description="Gold at Heat 5.", xp=1500, title="Legend of the Stampede", test=function(p) return anyRecord(p,Config.Medals.Gold,5) end},
	{id="whole_bunch", name="Whole Bright Bunch", description="Discover all 12 Sparks.", xp=500, title="Collector", test=function(p) return speciesCount(p)>=12 end},
	{id="prism_keeper", name="Prism Keeper", description="Unlock a Prism Spark (15 banked).", xp=200, test=function(p) return mutationAtLeast(p,2) end},
	{id="radiant_keeper", name="Radiant Keeper", description="Unlock a Radiant Spark (50 banked).", xp=500, title="Keeper", test=function(p) return mutationAtLeast(p,3) end},
	{id="marshal", name="Parade Marshal", description="Bank 500 Sparks.", xp=500, title="Marshal", test=function(p) return p.totalBanked>=500 end},
	{id="encore", name="Encore Regular", description="Finish 50 rounds.", xp=400, test=function(p) return p.rounds>=50 end},
	{id="clean_sweep", name="Clean Sweep", description="Finish a round with 15+ catches and no miss or zap.", xp=400, title="Clean", test=function(p) return stat(p,"flawless")>=1 end},
	{id="heavy_haul", name="Heavy Haul", description="Bank 12 Sparks at once.", xp=300, test=function(p) return stat(p,"bestBankCount")>=12 end},
	{id="gilded_album", name="Golden Herd", description="Catch a Golden Spark of all 12 species.", xp=1200, title="Golden Herder", test=function(p)
		for _, c in ipairs(Config.Creatures) do if not (p.gilded and p.gilded[c.id]) then return false end end
		return true end},
	{id="rally_captain", name="Rally Captain", description="Complete 10 Arena Rallies.", xp=300, test=function(p) return stat(p,"rallies")>=10 end},
}
local achievementById = {}
for _, a in ipairs(Progression.Achievements) do achievementById[a.id] = a end
Progression.AchievementById = achievementById

-- Goals. "round" scope takes the best single-round value; "total" sums rounds.
-- requires: "canyon"/"aurora" arena unlocked (totalBanked threshold), minRank.
Progression.DailyPool = {
	{id="d_catch", name="Catch 40 Sparks", metric="captures", target=40},
	{id="d_precise", name="Land 12 precision catches", metric="precision", target=12},
	{id="d_dash", name="Make 10 dash catches", metric="dashCatches", target=10},
	{id="d_multi", name="Make 3 multi-catches in a dash", metric="multiCatches", target=3},
	{id="d_herd", name="Herd 4 Sparks through a Spark Gate", metric="herded", target=4},
	{id="d_pop", name="Pop 6 statics with a dash", metric="pops", target=6},
	{id="d_golden", name="Catch a Golden Spark", metric="golden", target=1},
	{id="d_chain", name="Reach a 7-chain in one round", metric="bestChain", target=7, scope="round"},
	{id="d_score", name="Earn Silver (1,000 skill) in a round", metric="score", target=1000, scope="round"},
	{id="d_rounds", name="Finish 3 rounds", metric="rounds", target=3},
	{id="d_canyon", name="Finish a round in Fizz Canyon", metric="canyonRounds", target=1, requires="canyon"},
	{id="d_aurora", name="Finish a round in Aurora Arcade", metric="auroraRounds", target=1, requires="aurora"},
	{id="d_heat", name="Finish a round at Heat 1+", metric="heatRounds", target=1, requires="heat"},
	-- Fixed third slot every day (D23): the fair, seeded Daily Stampede run.
	{id="d_trial", name="Finish today's Daily Stampede", metric="trialRuns", target=1, fixed=true},
}
Progression.WeeklyPool = {
	{id="w_catch", name="Catch 300 Sparks", metric="captures", target=300},
	{id="w_precise", name="Land 80 precision catches", metric="precision", target=80},
	{id="w_dash", name="Make 60 dash catches", metric="dashCatches", target=60},
	{id="w_multi", name="Make 20 multi-catches", metric="multiCatches", target=20},
	{id="w_herd", name="Herd 25 Sparks through gates", metric="herded", target=25},
	{id="w_pop", name="Pop 40 statics", metric="pops", target=40},
	{id="w_golden", name="Catch 5 Golden Sparks", metric="golden", target=5},
	{id="w_score", name="Earn Gold (2,500 skill) in a round", metric="score", target=2500, scope="round"},
	{id="w_rounds", name="Finish 20 rounds", metric="rounds", target=20},
	{id="w_gold", name="Earn 3 gold medals", metric="golds", target=3},
}
local goalById = {}
for _, g in ipairs(Progression.DailyPool) do g.kind="daily"; goalById[g.id] = g end
for _, g in ipairs(Progression.WeeklyPool) do g.kind="weekly"; goalById[g.id] = g end
Progression.GoalById = goalById

function Progression.day(now) return math.floor(int(now, 4102444800) / 86400) end
-- 1970-01-01 was a Thursday; +3 makes weeks begin on Monday (UTC).
function Progression.week(now) return math.floor((Progression.day(now) + 3) / 7) end

local function eligible(profile, goal)
	if goal.requires == "canyon" then return profile.totalBanked >= Config.Biomes[2].unlock end
	if goal.requires == "aurora" then return profile.totalBanked >= Config.Biomes[3].unlock end
	if goal.requires == "heat" then return Loadout.heatUnlocked(profile.records) >= 1 end
	return true
end
-- Deterministic per (period, salt) and frozen into the profile at first sight,
-- so unlocking an arena mid-day never reshuffles goals already in progress.
local function pick(profile, pool, period, salt, count)
	local options = {}
	for _, goal in ipairs(pool) do if eligible(profile, goal) and not goal.fixed then table.insert(options, goal.id) end end
	local seed = (period * 2654435761 + salt) % 4294967296
	local chosen = {}
	while #chosen < count and #options > 0 do
		seed = (seed * 1103515245 + 12345) % 2147483648
		table.insert(chosen, table.remove(options, seed % #options + 1))
	end
	return chosen
end
function Progression.ensureGoals(profile, now)
	local changed = false
	local day, week = Progression.day(now), Progression.week(now)
	if profile.daily.day ~= day then
		local goals = pick(profile, Progression.DailyPool, day, 17, 2)
		table.insert(goals, "d_trial")
		profile.daily = {day=day, goals=goals, progress={}, claimed={}, bonus=false, rerolled=false}
		changed = true
	end
	if profile.weekly.week ~= week then
		profile.weekly = {week=week, goals=pick(profile, Progression.WeeklyPool, week, 91, 3), progress={}, claimed={}}
		changed = true
	end
	return changed
end

local function metricValue(summary, metric, biomeIndex, heat)
	if metric == "rounds" then return 1 end
	if metric == "canyonRounds" then return if biomeIndex == 2 then 1 else 0 end
	if metric == "auroraRounds" then return if biomeIndex == 3 then 1 else 0 end
	if metric == "heatRounds" then return if heat >= 1 then 1 else 0 end
	if metric == "golds" then return if int(summary.score) >= Config.Medals.Gold then 1 else 0 end
	return int(summary[metric], 512 * 1000)
end
local function advanceGoals(block, summary, biomeIndex, heat)
	for _, id in ipairs(block.goals) do
		local goal = goalById[id]
		if goal and not block.claimed[id] then
			local value = metricValue(summary, goal.metric, biomeIndex, heat)
			local current = int(block.progress[id])
			block.progress[id] = math.min(goal.target, if goal.scope == "round" then math.max(current, value) else current + value)
		end
	end
end

-- Every XP grant pays any Glow Gift ranks crossed (Cosmetics.RankRewards), so
-- each gift is paid exactly once whichever source (round, goal, achievement) levels you.
local function grantXp(profile, amount)
	local before = Progression.rank(profile.xp)
	profile.xp = math.min(MAX_XP, int(profile.xp, MAX_XP) + int(amount))
	local after = Progression.rank(profile.xp)
	if after > before then
		-- Lazy require: Cosmetics requires Progression at load time.
		local Cosmetics = if script then require(script.Parent.Cosmetics) else require("./Cosmetics")
		local gift = Cosmetics.glowBetween(before, after)
		if gift > 0 then profile.coins = math.min(MAX_COINS, int(profile.coins, MAX_COINS) + gift) end
	end
end

-- Newly earned achievements grant XP once. Returns their ids (stable order).
function Progression.evaluateAchievements(profile)
	local earned = {}
	for _, a in ipairs(Progression.Achievements) do
		if not profile.achievements[a.id] and a.test(profile) then
			profile.achievements[a.id] = true
			grantXp(profile, a.xp)
			table.insert(earned, a.id)
		end
	end
	return earned
end

-- Rewards unlocked by crossing ranks (perks, slots, trails) for result callouts.
-- Rank reward callouts come from the single rank table (Cosmetics.RankRewards):
-- perks, slot, trails, formations, bursts, tags, titles and glow gifts.
function Progression.unlocksBetween(fromRank, toRank)
	local Cosmetics = if script then require(script.Parent.Cosmetics) else require("./Cosmetics")
	return Cosmetics.unlocksBetween(fromRank, toRank)
end

-- One completed, server-owned round. roundSerial makes it idempotent across retries.
-- partial=true: XP, stats and goals count; records rows are written only by full rounds.
function Progression.applyRound(profile, summary, biomeIndex, heat, roundSerial, now, partial)
	if type(summary) ~= "table" or summary.finished ~= true then return nil end
	if type(roundSerial) ~= "number" or roundSerial % 1 ~= 0 or roundSerial <= profile.progressReceipt or roundSerial > profile.rounds then return nil end
	local biome = Config.Biomes[biomeIndex]
	if not biome then return nil end
	heat = math.clamp(math.floor(if finite(heat) then heat else 0), 0, Loadout.MaxHeat)
	profile.progressReceipt = roundSerial
	Progression.ensureGoals(profile, now)
	local rankBefore = Progression.rank(profile.xp)
	local score = int(summary.score)
	local gained = Progression.roundXp(score)
	grantXp(profile, gained)
	local row = profile.records[biome.id]
	local previousRecord = int(row[heat + 1])
	if partial ~= true then row[heat + 1] = math.max(previousRecord, score) end
	local stats = profile.stats
	local captures = int(summary.captures, 512)
	for _, key in ipairs({"herded","assists","pops","zaps","golden","multiCatches"}) do
		stats[key] = math.min(MAX_COUNT, int(stats[key]) + math.min(512, int(summary[key], 512)))
	end
	stats.bestMulti = math.max(int(stats.bestMulti), math.min(8, int(summary.bestMulti, 8)))
	stats.bestBankCount = math.max(int(stats.bestBankCount), math.min(64, int(summary.bestHaul, 64)))
	if captures >= 15 and int(summary.misses) == 0 and int(summary.zaps) == 0 then stats.flawless = math.min(MAX_COUNT, int(stats.flawless) + 1) end
	advanceGoals(profile.daily, summary, biomeIndex, heat)
	advanceGoals(profile.weekly, summary, biomeIndex, heat)
	local achievements = Progression.evaluateAchievements(profile)
	local rankAfter = Progression.rank(profile.xp)
	return {xp=gained, rankBefore=rankBefore, rankAfter=rankAfter, newRecord=partial ~= true and score > previousRecord, partial=partial == true,
		previousRecord=previousRecord, achievements=achievements, unlocks=Progression.unlocksBetween(rankBefore, rankAfter)}
end

-- A finished Daily Stampede run advances today's fixed trial goal (once).
function Progression.recordTrialRun(profile, now)
	Progression.ensureGoals(profile, now)
	if table.find(profile.daily.goals, "d_trial") and not profile.daily.claimed.d_trial then
		profile.daily.progress.d_trial = 1
		return true
	end
	return false
end

-- One free reroll per day of a daily PLAY goal (never the fixed trial slot,
-- never a claimed goal). Deterministic replacement; progress restarts at 0.
function Progression.rerollGoal(profile, id)
	local goal = type(id) == "string" and goalById[id] or nil
	if not goal or goal.kind ~= "daily" or goal.fixed then return false, "That goal can't be rerolled" end
	local block = profile.daily
	local slot = table.find(block.goals, id)
	if not slot then return false, "Not an active goal" end
	if block.claimed[id] then return false, "Already claimed" end
	if block.rerolled then return false, "Reroll used today" end
	local options = {}
	for _, candidate in ipairs(Progression.DailyPool) do
		if not candidate.fixed and eligible(profile, candidate) and not table.find(block.goals, candidate.id) then table.insert(options, candidate.id) end
	end
	if #options == 0 then return false, "No other goals available" end
	local replacement = options[(block.day * 7 + slot) % #options + 1]
	block.goals[slot] = replacement
	block.progress[id] = nil; block.progress[replacement] = 0
	block.rerolled = true
	return true, "New goal: "..goalById[replacement].name
end

function Progression.claimGoal(profile, id)
	local goal = type(id) == "string" and goalById[id] or nil
	if not goal then return false, "Unknown goal" end
	local block = if goal.kind == "daily" then profile.daily else profile.weekly
	if not table.find(block.goals, id) then return false, "Not an active goal" end
	if block.claimed[id] then return false, "Already claimed" end
	if int(block.progress[id]) < goal.target then return false, "Keep playing" end
	block.claimed[id] = true
	local glow = if goal.kind == "daily" then Progression.DailyGlow else Progression.WeeklyGlow
	grantXp(profile, if goal.kind == "daily" then Progression.DailyXp else Progression.WeeklyXp)
	local message = goal.name.." complete! +"..glow.." glow"
	if goal.kind == "daily" and not block.bonus then
		local all = #block.goals > 0
		for _, other in ipairs(block.goals) do if not block.claimed[other] then all = false end end
		if all then block.bonus = true; glow += Progression.DailyBonus; message ..= " • Daily set bonus +"..Progression.DailyBonus end
	end
	profile.coins = math.min(MAX_COINS, profile.coins + glow)
	return true, message, glow
end

function Progression.styleUnlocked(profile, trail)
	if trail.id == "none" then return true end
	if profile.style.owned[trail.id] then return true end
	if trail.achievement then return profile.achievements[trail.achievement] == true end
	if trail.rank and not trail.price then return Progression.rank(profile.xp) >= trail.rank end
	return false
end
-- Equip if owned/unlocked; otherwise buy at its guaranteed glow price.
function Progression.style(profile, id)
	local trail = type(id) == "string" and trailById[id] or nil
	if not trail then return false, "Unknown style" end
	if Progression.styleUnlocked(profile, trail) then
		profile.style.trail = trail.id
		return true, trail.name.." equipped", 0
	end
	if not trail.price then return false, "Earn this style through play" end
	if trail.rank and Progression.rank(profile.xp) < trail.rank then return false, "Reach rank "..trail.rank.." first" end
	if profile.coins < trail.price then return false, "Collect more glow" end
	profile.coins -= trail.price
	profile.style.owned[trail.id] = true
	profile.style.trail = trail.id
	return true, trail.name.." unlocked and equipped", trail.price
end
function Progression.setTitle(profile, achievementId)
	if achievementId == "" then profile.style.title = ""; return true, "Title cleared" end
	local a = type(achievementId) == "string" and achievementById[achievementId] or nil
	if not a or not a.title then return false, "Unknown title" end
	if not profile.achievements[a.id] then return false, "Earn this title first" end
	profile.style.title = a.id
	return true, "Title: "..a.title
end
function Progression.titleText(profile)
	local a = achievementById[profile.style and profile.style.title or ""]
	return if a and a.title and profile.achievements[a.id] then a.title else ""
end

return Progression
