local Config = if script then require(script.Parent.Config) else require("./Config")
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

function Profile.new()
	return {version=1, coins=0, totalBanked=0, rounds=0, album={}, mutations={},
		upgrades={boots=0,magnet=0,basket=0}, quests={},
		mastery={bestScore=0,bestChain=0,completed=0,bestByBiome={}},
		settings={reducedMotion=false,music=true,sfx=true,competition=false}, lastSeen=0}
end

-- Whitelist every persisted key. Never retain unknown nested values, Instances or cycles.
-- Unsupported versions are rejected, not silently downgraded and overwritten.
function Profile.sanitize(raw)
	if raw == nil then return Profile.new(), "new" end
	if type(raw) ~= "table" then return nil, "corrupt" end
	if raw.version ~= nil and raw.version ~= 1 then return nil, "future-version" end
	local result = Profile.new()
	result.coins = integer(raw.coins, MAX_COINS)
	result.totalBanked = integer(raw.totalBanked, MAX_COUNT)
	result.rounds = integer(raw.rounds, MAX_COUNT)
	result.lastSeen = integer(raw.lastSeen, 4102444800)
	if type(raw.mastery)=="table" then
		for _,key in ipairs({"bestScore","bestChain","completed"}) do
			result.mastery[key]=integer(raw.mastery[key],MAX_COUNT)
		end
		if type(raw.mastery.bestByBiome)=="table" then
			for _,biome in ipairs(Config.Biomes) do
				result.mastery.bestByBiome[biome.id]=integer(raw.mastery.bestByBiome[biome.id],MAX_COUNT)
			end
		end
	end
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
		for key in pairs(result.settings) do
			if type(raw.settings[key]) == "boolean" then result.settings[key] = raw.settings[key] end
		end
	end
	deriveMutations(result)
	return result, "ready"
end

function Profile.speciesCount(profile)
	local count = 0
	for id in pairs(species) do if (profile.album[id] or 0) > 0 then count += 1 end end
	return count
end

-- A completed server-owned round summary only; never accepts a client score.
function Profile.recordMastery(profile,biomeId,summary)
	if type(summary)~="table" or summary.finished~=true then return false end
	local known=false
	for _,biome in ipairs(Config.Biomes) do if biome.id==biomeId then known=true; break end end
	if not known then return false end
	local score=integer(summary.score,MAX_COUNT)
	local mastery=profile.mastery
	local improved=score>mastery.bestScore
	mastery.bestScore=math.max(mastery.bestScore,score)
	mastery.bestChain=math.max(mastery.bestChain,integer(summary.bestChain,MAX_COUNT))
	mastery.bestByBiome[biomeId]=math.max(mastery.bestByBiome[biomeId] or 0,score)
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
		local id = catches[index]
		local creature = if type(id) == "string" then species[id] else nil
		if creature then
			local previous = profile.album[id] or 0
			if previous == 0 then discovered += 1 end
			profile.album[id] = math.min(previous + 1, MAX_COUNT)
			reward += creature.value
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

function Profile.questProgress(profile, quest)
	if quest.metric == "species" then return Profile.speciesCount(profile) end
	if quest.metric == "totalBanked" then return profile.totalBanked end
	if quest.metric == "rounds" then return profile.rounds end
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
