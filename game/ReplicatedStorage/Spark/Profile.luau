local Config = if script then require(script.Parent.Config) else require("./Config")
local Challenge = if script then require(script.Parent.Challenge) else require("./Challenge")
local Loadout = if script then require(script.Parent.Loadout) else require("./Loadout")
local Progression = if script then require(script.Parent.Progression) else require("./Progression")
local Cosmetics = if script then require(script.Parent.Cosmetics) else require("./Cosmetics")
local Profile = {}
local MAX_COUNT = 1000000
local MAX_COINS = 2000000000
local species = {}
for _, creature in ipairs(Config.Creatures) do species[creature.id] = creature end

local function integer(value, limit)
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return 0 end
	return math.clamp(math.floor(value), 0, limit)
end
local function deriveMutations(profile)
	profile.mutations = {}
	for id, count in pairs(profile.album) do
		local level = 0
		for index, mutation in ipairs(Config.Mutations) do
			if count >= mutation.threshold then level = index end
		end
		if level > 0 then profile.mutations[id] = level end
	end
end

Profile.Version = 3
Profile.StatKeys = {"herded","assists","pops","zaps","golden","multiCatches","bestMulti","flawless","bestBankCount","rallies"}
Profile.UiScales = {0.85, 1, 1.15}
Profile.MaxHints = 64
local function safeId(value)
	return type(value) == "string" and #value > 0 and #value <= 24 and string.match(value, "^[%w_]+$") ~= nil
end
-- Generic v3 cosmetics sanitizer; Cosmetics.sanitize/stripUnearned validate ids
-- against the catalog where the module is available.
local function sanitizeCosmetics(raw)
	local result = {owned={}, formation="line", burst="confetti", tag="default", title=""}
	if type(raw) ~= "table" then return result end
	if type(raw.owned) == "table" then
		local count = 0
		for id, value in pairs(raw.owned) do
			if value == true and safeId(id) and count < 128 then result.owned[id] = true; count += 1 end
		end
	end
	for _, key in ipairs({"formation", "burst", "tag", "title"}) do
		if safeId(raw[key]) or (key == "title" and raw[key] == "") then result[key] = raw[key] end
	end
	return result
end
local function emptyRecords()
	local records = {}
	for _, biome in ipairs(Config.Biomes) do records[biome.id] = {0,0,0,0,0,0} end
	return records
end
function Profile.new()
	local stats = {}
	for _, key in ipairs(Profile.StatKeys) do stats[key] = 0 end
	return {version=Profile.Version, coins=0, totalBanked=0, rounds=0, album={}, mutations={},
		upgrades={boots=0,magnet=0,basket=0}, quests={},
		mastery={bestScore=0,bestChain=0,completed=0,precision=0,dashCatches=0,lastRecordedRound=0,bestByBiome={},bestRuns={}},
		settings={reducedMotion=false,music=true,sfx=true,competition=false,
			-- v3 (FINAL_PRODUCTION_PLAN §6.11/§6.15)
			showOnPodium=true,holdCatch=false,highContrast=false,uiScale=1,musicVolume=0.6,sfxVolume=0.8}, lastSeen=0,
		-- Version 2: long-term progression. All earned in play; nothing purchasable with Robux.
		xp=0, loadout={}, heat=0, records=emptyRecords(), gilded={}, stats=stats, achievements={},
		daily={day=0,goals={},progress={},claimed={},bonus=false,rerolled=false}, weekly={week=0,goals={},progress={},claimed={}},
		style={owned={},trail="none",title=""}, progressReceipt=0,
		-- Version 3: cosmetics categories, species signatures, Daily Stampede, coaching flags.
		cosmetics={owned={},formation="line",burst="confetti",tag="default",title=""},
		signatures={},
		trial={day=0,best=0,runsToday=0,runsDay=0,rewardedDay=0,bestRun=nil},
		flags={seenHints={},firstSessionDone=false}}
end
local function goalBlock(raw, key, pool)
	local block = {[key]=0, goals={}, progress={}, claimed={}}
	if type(raw) ~= "table" then return block end
	block[key] = integer(raw[key], 1000000)
	local allowed = {}
	for _, goal in ipairs(pool) do allowed[goal.id] = goal end
	if type(raw.goals) == "table" then
		for index = 1, math.min(#raw.goals, 8) do
			local id = raw.goals[index]
			if #block.goals < 3 and type(id) == "string" and allowed[id] and not table.find(block.goals, id) then
				table.insert(block.goals, id)
				if type(raw.progress) == "table" then block.progress[id] = math.min(allowed[id].target, integer(raw.progress[id], MAX_COUNT)) end
				if type(raw.claimed) == "table" and raw.claimed[id] == true then block.claimed[id] = true end
			end
		end
	end
	return block
end

-- Whitelist every persisted key. Never retain unknown nested values, Instances or cycles.
-- Unsupported versions are rejected, not silently downgraded and overwritten.
function Profile.sanitize(raw)
	if raw == nil then return Profile.new(), "new" end
	if type(raw) ~= "table" then return nil, "corrupt" end
	-- Version 1 saves migrate forward; anything newer is refused without overwrite.
	if raw.version ~= nil and raw.version ~= 1 and raw.version ~= 2 and raw.version ~= 3 then return nil, "future-version" end
	local result = Profile.new()
	result.coins = integer(raw.coins, MAX_COINS)
	result.totalBanked = integer(raw.totalBanked, MAX_COUNT)
	result.rounds = integer(raw.rounds, MAX_COUNT)
	result.lastSeen = integer(raw.lastSeen, 4102444800)
	if type(raw.mastery)=="table" then
		for _,key in ipairs({"bestScore","bestChain","completed","precision","dashCatches"}) do
			result.mastery[key]=integer(raw.mastery[key],MAX_COUNT)
		end
		-- Records predating round receipts are already accounted for. Start their
		-- receipt at completed rounds; do not let migration replay old summaries.
		result.mastery.lastRecordedRound=if raw.mastery.lastRecordedRound==nil then result.rounds
			else math.min(result.rounds,integer(raw.mastery.lastRecordedRound,MAX_COUNT))
		if type(raw.mastery.bestByBiome)=="table" then
			for _,biome in ipairs(Config.Biomes) do
				result.mastery.bestByBiome[biome.id]=integer(raw.mastery.bestByBiome[biome.id],MAX_COUNT)
			end
		end
		if type(raw.mastery.bestRuns)=="table" then
			for _,biome in ipairs(Config.Biomes) do
				local run=Challenge.sanitizeBestRun(raw.mastery.bestRuns[biome.id])
				if run and run.score==(result.mastery.bestByBiome[biome.id] or 0) then result.mastery.bestRuns[biome.id]=run end
			end
		end
	else result.mastery.lastRecordedRound=result.rounds end
	if type(raw.album) == "table" then
		for id in pairs(species) do
			local count = integer(raw.album[id], MAX_COUNT)
			if count > 0 then result.album[id] = count end
		end
	end
	if type(raw.upgrades) == "table" then
		for key, upgrade in pairs(Config.Upgrades) do result.upgrades[key] = integer(raw.upgrades[key], #upgrade.costs) end
	end
	if type(raw.quests) == "table" then
		for _, quest in ipairs(Config.Quests) do
			if raw.quests[quest.id] == true then result.quests[quest.id] = true end
		end
	end
	if type(raw.settings) == "table" then
		for key, default in pairs(result.settings) do
			local value = raw.settings[key]
			if type(default) == "boolean" and type(value) == "boolean" then result.settings[key] = value
			elseif type(default) == "number" and type(value) == "number" and value == value then
				if key == "uiScale" then
					-- Only the three offered UI scales are accepted.
					for _, allowed in ipairs(Profile.UiScales) do if math.abs(value - allowed) < 1e-6 then result.settings[key] = allowed end end
				else
					result.settings[key] = math.clamp(value, 0, 1)
				end
			end
		end
	end
	-- Version 2 fields (absent on v1 saves -> safe defaults).
	result.xp = integer(raw.xp, 100000000)
	result.progressReceipt = math.min(result.rounds, integer(raw.progressReceipt == nil and result.rounds or raw.progressReceipt, MAX_COUNT))
	if type(raw.records) == "table" then
		for _, biome in ipairs(Config.Biomes) do
			local row = raw.records[biome.id]
			if type(row) == "table" then
				for heat = 0, Loadout.MaxHeat do result.records[biome.id][heat + 1] = integer(row[heat + 1], MAX_COUNT) end
			end
		end
	end
	-- v1 per-arena bests were earned at heat 0.
	for _, biome in ipairs(Config.Biomes) do
		local row = result.records[biome.id]
		row[1] = math.max(row[1], result.mastery.bestByBiome[biome.id] or 0)
	end
	if type(raw.gilded) == "table" then
		for id in pairs(species) do if raw.gilded[id] == true then result.gilded[id] = true end end
	end
	if type(raw.stats) == "table" then
		for _, key in ipairs(Profile.StatKeys) do result.stats[key] = integer(raw.stats[key], MAX_COUNT) end
	end
	if type(raw.achievements) == "table" then
		for _, a in ipairs(Progression.Achievements) do
			if raw.achievements[a.id] == true then result.achievements[a.id] = true end
		end
	end
	result.daily = goalBlock(raw.daily, "day", Progression.DailyPool)
	result.daily.bonus = type(raw.daily) == "table" and raw.daily.bonus == true
	result.daily.rerolled = type(raw.daily) == "table" and raw.daily.rerolled == true
	result.weekly = goalBlock(raw.weekly, "week", Progression.WeeklyPool)
	if type(raw.style) == "table" then
		if type(raw.style.owned) == "table" then
			for _, trail in ipairs(Progression.Trails) do
				if trail.price and raw.style.owned[trail.id] == true then result.style.owned[trail.id] = true end
			end
		end
		if type(raw.style.trail) == "string" and Progression.TrailById[raw.style.trail] then result.style.trail = raw.style.trail end
		if type(raw.style.title) == "string" and Progression.AchievementById[raw.style.title] then result.style.title = raw.style.title end
	end
	-- Version 3 fields (absent on v1/v2 saves -> safe defaults).
	result.cosmetics = Cosmetics.sanitize(sanitizeCosmetics(raw.cosmetics))
	if type(raw.signatures) == "table" then
		for id in pairs(species) do
			local count = integer(raw.signatures[id], MAX_COUNT)
			if count > 0 then result.signatures[id] = count end
		end
	end
	if type(raw.trial) == "table" then
		local t = raw.trial
		result.trial.day = integer(t.day, 10000000)
		result.trial.best = integer(t.best, MAX_COUNT)
		result.trial.runsDay = integer(t.runsDay, 10000000)
		result.trial.runsToday = integer(t.runsToday, 1000)
		result.trial.rewardedDay = integer(t.rewardedDay, 10000000)
		local run = Challenge.sanitizeBestRun(t.bestRun)
		if run.score > 0 and run.score == result.trial.best then result.trial.bestRun = run end
	end
	if type(raw.flags) == "table" then
		if type(raw.flags.seenHints) == "table" then
			local count = 0
			for id, value in pairs(raw.flags.seenHints) do
				if value == true and safeId(id) and count < Profile.MaxHints then result.flags.seenHints[id] = true; count += 1 end
			end
		end
		result.flags.firstSessionDone = raw.flags.firstSessionDone == true
	end
	deriveMutations(result)
	-- Validate equips against what this profile has actually earned.
	if not Progression.styleUnlocked(result, Progression.TrailById[result.style.trail]) then result.style.trail = "none" end
	if Progression.titleText(result) == "" then result.style.title = "" end
	Cosmetics.stripUnearned(result)
	local rank = Progression.rank(result.xp)
	result.loadout = Loadout.sanitize(raw.loadout, rank)
	result.heat = math.min(integer(raw.heat, Loadout.MaxHeat), Loadout.heatUnlocked(result.records))
	return result, "ready"
end

-- "Next up" (competitor comparison 2026-11-05): the closest earned collection
-- milestone, for the results screen. Considers undiscovered species in unlocked
-- arenas, the next Glow/Prism/Radiant tier and the next signature star; returns the
-- one needing the fewest catches (ties: list order). Pure; nil when all complete.
function Profile.nextMilestone(profile)
	if type(profile) ~= "table" or type(profile.album) ~= "table" then return nil end
	local best
	local function offer(remaining, text, kind, speciesId)
		if remaining > 0 and (not best or remaining < best.remaining) then
			best = {remaining = remaining, text = text, kind = kind, species = speciesId}
		end
	end
	local banked = if type(profile.totalBanked) == "number" then profile.totalBanked else 0
	for _, def in ipairs(Config.Creatures) do
		local biome = Config.Biomes[def.biome]
		local unlocked = biome ~= nil and banked >= biome.unlock
		local count = if type(profile.album[def.id]) == "number" then profile.album[def.id] else 0
		if count <= 0 then
			if unlocked then offer(1, "Discover " .. def.name .. " in " .. biome.name, "discover", def.id) end
		else
			for _, tier in ipairs(Config.Mutations) do
				if count < tier.threshold then
					local n = tier.threshold - count
					offer(n, string.format("Bank %d more %s for %s", n, def.name, string.upper(tier.name)), "tier", def.id)
					break
				end
			end
			local signature = def.signature and Config.Signatures and Config.Signatures[def.signature]
			local signed = if type(profile.signatures) == "table" and type(profile.signatures[def.id]) == "number" then profile.signatures[def.id] else 0
			if signature then
				for star, threshold in ipairs(Config.SignatureStars or {}) do
					if signed < threshold then
						local n = threshold - signed
						offer(n, string.format("%d more %s %s catch%s for ★%d", n, def.name, signature.label, if n == 1 then "" else "es", star), "signature", def.id)
						break
					end
				end
			end
		end
	end
	return best
end

function Profile.speciesCount(profile)
	local count = 0
	for id in pairs(species) do if (profile.album[id] or 0) > 0 then count += 1 end end
	return count
end

-- A completed server-owned round summary only; never accepts a client score.
-- Main supplies its incremented profile.rounds as roundSerial. This persisted
-- receipt makes retries idempotent across sanitization/save/load. Three-argument
-- calls are retained for old pure-module callers, which must ensure exactly once.
-- partial=true (joined mid-cycle): counters still accumulate but score records,
-- arena bests and PB splits are written only by full synchronized rounds.
function Profile.recordMastery(profile,biomeId,summary,roundSerial,partial)
	if type(summary)~="table" or summary.finished~=true then return false end
	local known=false
	for _,biome in ipairs(Config.Biomes) do if biome.id==biomeId then known=true; break end end
	if not known then return false end
	for _,key in ipairs({"score","bestChain","captures","precision","dashCatches"}) do
		local value=summary[key]
		if type(value)~="number" or value~=value or value<0 or value==math.huge then return false end
	end
	local score=integer(summary.score,MAX_COUNT)
	local mastery=profile.mastery
	if roundSerial~=nil then
		if type(roundSerial)~="number" or roundSerial~=roundSerial or roundSerial%1~=0
			or roundSerial<=mastery.lastRecordedRound or roundSerial>profile.rounds or roundSerial>MAX_COUNT then return false end
		mastery.lastRecordedRound=roundSerial
	end
	local captures=integer(summary.captures,512)
	local improved=partial~=true and score>mastery.bestScore
	if partial~=true then mastery.bestScore=math.max(mastery.bestScore,score) end
	mastery.bestChain=math.max(mastery.bestChain,math.min(captures,integer(summary.bestChain,512)))
	mastery.precision=math.min(MAX_COUNT,mastery.precision+math.min(captures,integer(summary.precision,512)))
	mastery.dashCatches=math.min(MAX_COUNT,mastery.dashCatches+math.min(captures,integer(summary.dashCatches,512)))
	local arenaBest=mastery.bestByBiome[biomeId] or 0
	if partial~=true and score>arenaBest then
		mastery.bestByBiome[biomeId]=score
		mastery.bestRuns[biomeId]=Challenge.sanitizeBestRun({score=score,checkpoints=summary.checkpoints})
	end
	if type(summary.challenge)=="table" and summary.challenge.complete==true then
		mastery.completed=math.min(MAX_COUNT,mastery.completed+1)
	end
	return improved
end

-- Only call with the server's validated carry list. Never accept client-provided catches.
function Profile.bank(profile, catches)
	if type(catches) ~= "table" then return 0, 0 end
	local reward, discovered, banked = 0, 0, 0
	for index = 1, math.min(#catches, 128) do
		local entry = catches[index]
		-- "*species" marks a server-verified Golden Spark catch (never client input).
		local golden = type(entry) == "string" and string.sub(entry, 1, 1) == "*"
		local id = if golden then string.sub(entry, 2) else entry
		local creature = if type(id) == "string" then species[id] else nil
		if creature then
			local previous = profile.album[id] or 0
			if previous == 0 then discovered += 1 end
			profile.album[id] = math.min(previous + 1, MAX_COUNT)
			reward += creature.value * (if golden then Config.GoldenValueMultiplier else 1)
			if golden and profile.gilded then profile.gilded[id] = true end
			banked += 1
		end
	end
	-- A readable +3 for every trio rewards grouping without exponential inflation.
	reward += math.floor(banked / 3) * 3
	local applied = math.min(reward, MAX_COINS - profile.coins)
	profile.coins += applied
	profile.totalBanked = math.min(profile.totalBanked + banked, MAX_COUNT)
	deriveMutations(profile)
	return applied, discovered
end

function Profile.buy(profile, key)
	local upgrade = if type(key) == "string" then Config.Upgrades[key] else nil
	if not upgrade then return false, "Unknown upgrade" end
	local cost = upgrade.costs[profile.upgrades[key] + 1]
	if not cost then return false, "Fully upgraded" end
	if profile.coins < cost then return false, "Collect more sparks" end
	profile.coins -= cost
	profile.upgrades[key] += 1
	return true, upgrade.name .. " upgraded"
end

-- Called only for the authoritative ArenaRally completion's contributor list.
-- The rally controller owns once-per-cycle authorization; no client amount.
function Profile.rewardRally(profile)
	local applied=math.min(8,MAX_COINS-profile.coins)
	profile.coins+=applied
	if profile.stats then profile.stats.rallies=math.min(MAX_COUNT,(profile.stats.rallies or 0)+1) end
	return applied
end

function Profile.questProgress(profile, quest)
	if quest.metric == "species" then return Profile.speciesCount(profile) end
	if quest.metric == "totalBanked" then return profile.totalBanked end
	if quest.metric == "rounds" then return profile.rounds end
	if quest.metric == "precision" then return profile.mastery.precision end
	if quest.metric == "dashCatches" then return profile.mastery.dashCatches end
	if quest.metric == "bestChain" then return profile.mastery.bestChain end
	if quest.metric == "challenges" then return profile.mastery.completed end
	if quest.metric == "bronzeArenas" then
		local count=0
		for _,biome in ipairs(Config.Biomes) do
			if (profile.mastery.bestByBiome[biome.id] or 0)>=Config.Medals.Bronze then count+=1 end
		end
		return count
	end
	return 0
end

function Profile.claim(profile, questId)
	if type(questId) ~= "string" then return false, "Unknown quest" end
	for _, quest in ipairs(Config.Quests) do
		if quest.id == questId then
			if profile.quests[questId] then return false, "Already claimed" end
			if Profile.questProgress(profile, quest) < quest.target then return false, "Keep exploring" end
			profile.quests[questId] = true
			profile.coins = math.min(profile.coins + quest.reward, MAX_COINS)
			return true, quest.name .. " complete"
		end
	end
	return false, "Unknown quest"
end

return Profile
