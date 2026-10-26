-- Deterministic pure-module integration. NO Roblox engine, players, remotes or rendering.
local Config = require("../game/ReplicatedStorage/Spark/Config")
local Profile = require("../game/ReplicatedStorage/Spark/Profile")
local Rules = require("../game/ReplicatedStorage/Spark/Rules")
local Persistence = require("../game/ServerScriptService/Spark/Persistence")

local assertions = 0
local function check(condition, message)
	assertions += 1
	assert(condition, message)
end
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = copy(item) end
	return result
end
local function same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for key, value in pairs(a) do if not same(value, b[key]) then return false end end
	for key in pairs(b) do if a[key] == nil then return false end end
	return true
end
local function profileEqualExceptSeen(a, b)
	local left, right = copy(a), copy(b)
	left.lastSeen, right.lastSeen = nil, nil
	return same(left, right)
end

-- An independently specified fixture catches reward/schema regressions before the soak.
do
	local p = Profile.new()
	local reward, discovered = Profile.bank(p, {"pip", "bunvolt", "cubloom"})
	check(reward == 15 and discovered == 3 and p.totalBanked == 3, "three known species must bank 15 glow")
	check(not Profile.buy(Profile.new(), "boots"), "fresh account cannot spend unearned currency")
	check(not Profile.claim(Profile.new(), "first_round"), "fresh account cannot claim an incomplete round")
end

local function scenario(contenders)
	local clock = 10000
	local store = {values = {}, calls = 0, failures = 0}
	function store:UpdateAsync(key, transform)
		self.calls += 1
		if self.failures > 0 then self.failures -= 1; error("injected transient storage failure") end
		-- Serialization boundaries avoid a mock accidentally sharing live profile tables.
		local first = transform(copy(self.values[key]))
		local nextValue = transform(copy(self.values[key]))
		check(same(first, nextValue), "retried UpdateAsync transform must be deterministic")
		if nextValue ~= nil then self.values[key] = copy(nextValue) end
		return copy(nextValue)
	end
	local generation = 0
	local function adapter()
		generation += 1
		return Persistence.new(store, function() return clock end, {
			sessionId = "simulation-" .. contenders .. "-" .. generation,
			wait = function(seconds) clock += seconds end,
		})
	end
	local actors, ownership = {}, {}
	local uniqueCaptures, raceAttempts, rejectedReplays, reconnects = 0, 0, 0, 0
	local function addActor(index)
		local service = adapter()
		local profile, status = service:load(index)
		check(profile ~= nil and status == "ready", "new simulated profile loads")
		local impostor, lockStatus = adapter():load(index)
		check(impostor == nil and lockStatus == "locked", "second simulated session cannot own a live profile")
		local actor = {id = index, profile = profile, persistence = service, carry = {},
			phase = "Playing", ready = true, biome = 1, position = {x = 0, y = 2, z = 0},
			buckets = {}, earned = 0, questEarned = 0, spent = 0, caught = 0,
			started = clock, savedAt = clock, completions = {}, visited = {}}
		actors[index] = actor
		return actor
	end
	local function save(actor)
		local ok, status = actor.persistence:save(actor.id, actor.profile)
		check(ok and status == "saved", "periodic mocked save renews lease")
		actor.savedAt = clock
	end
	local function advance(target)
		while clock < target do
			clock = math.min(target, clock + 5)
			for _, actor in ipairs(actors) do
				if clock - actor.savedAt >= 20 then save(actor) end
			end
		end
	end
	local function bank(actor)
		local before, count = actor.profile.totalBanked, #actor.carry
		local batch = actor.carry
		actor.carry = {} -- orchestration modeled here, not imported from Main.server.luau
		local reward = Profile.bank(actor.profile, batch)
		actor.earned += reward
		check(actor.profile.totalBanked - before == count, "bank count equals owned carry count")
		local coins = actor.profile.coins
		check(Profile.bank(actor.profile, actor.carry) == 0 and actor.profile.coins == coins,
			"repeating a bank with consumed carry cannot mint a second reward")
	end
	local function reconnect(actor)
		bank(actor)
		actor.profile.settings.reducedMotion = true
		local before = copy(actor.profile)
		local previous = actor.persistence
		check(previous:release(actor.id, actor.profile), "disconnect releases and saves mocked profile")
		actor.persistence = adapter()
		local restored, status = actor.persistence:load(actor.id)
		check(restored and status == "ready" and profileEqualExceptSeen(before, restored),
			"rejoin restores exact progression, collection, quests, settings and upgrades")
		check(restored.lastSeen > 0, "rejoin receives persisted return timestamp")
		local calls = store.calls
		check(not previous:save(actor.id, before) and store.calls == calls, "released session cannot overwrite its successor")
		actor.profile = restored; actor.savedAt = clock; actor.started = clock; actor.buckets = {}
		reconnects += 1
	end

	for index = 1, contenders do
		if index == contenders and contenders > 1 then advance(clock + 15) end
		addActor(index) -- last actor joins 15 simulated seconds after first, not into a lobby
	end
	local lateStart = actors[contenders].started
	if contenders > 1 then
		check(lateStart - actors[1].started == 15, "late join has independent full-round start")
		check(Rules.roundPhase(lateStart, lateStart, Config.RoundSeconds) == "Playing", "late join starts ready to play")
	end
	for round = 1, 10 do
		for _, actor in ipairs(actors) do
			if round > 1 then actor.started = clock end
			actor.phase = "Playing"; actor.buckets = {}
			for index, biome in ipairs(Config.Biomes) do
				if actor.profile.totalBanked >= biome.unlock then actor.biome = index end
			end
			actor.visited[actor.biome] = true
		end
		-- Twenty-four distinct owned captures per actor per round. Every target is contested
		-- in a deterministic rotating order. This models serial server decisions, not threads.
		for catchIndex = 1, 24 do
			for preferred = 1, contenders do
				advance(clock + 0.75)
				local desired = actors[preferred]
				local def = Config.Creatures[(desired.biome - 1) * 4 + (catchIndex - 1) % 4 + 1]
				local targetId = round .. ":" .. catchIndex .. ":" .. preferred
				local target = {claimed = false, biome = desired.biome, position = {x = 6, y = 2, z = 0}}
				local winners = 0
				for offset = 0, contenders - 1 do
					local actor = actors[(preferred - 1 + offset) % contenders + 1]
					local request = {phase = actor.phase, ready = actor.ready, carry = #actor.carry,
						biome = actor.biome, position = actor.position}
					local capacity = Config.MaxCarry + actor.profile.upgrades.basket * 2
					raceAttempts += 1
					if Rules.canCapture(request, target, clock, Config.CaptureRadius, capacity) then
						check(Rules.roundPhase(actor.started, clock, Config.RoundSeconds) == "Playing", "capture occurs inside actor round")
						check(Rules.allow(actor.buckets, "capture", clock, Config.CaptureCooldown), "winning captures respect real cooldown")
						check(not ownership[targetId], "target ownership cannot be duplicated")
						target.claimed = true; ownership[targetId] = actor.id
						table.insert(actor.carry, def.id); actor.caught += 1
						uniqueCaptures += 1; winners += 1
						check(not Rules.allow(actor.buckets, "capture", clock, Config.CaptureCooldown), "same-frame cooldown replay rejected")
					end
				end
				check(winners == 1 and ownership[targetId] == preferred, "exactly one serialized contender wins each target")
				check(not Rules.canCapture({phase = "Playing", ready = true, carry = 0, biome = target.biome,
					position = desired.position}, target, clock + 1, 10, 8), "claimed target remains unavailable after cooldown")
				rejectedReplays += 1
				if #desired.carry >= 6 then bank(desired) end
				if round == 5 and catchIndex == 13 and preferred == contenders then reconnect(desired) end
			end
		end
		local finishAt = clock
		for _, actor in ipairs(actors) do finishAt = math.max(finishAt, actor.started + Config.RoundSeconds) end
		advance(finishAt)
		for _, actor in ipairs(actors) do
			check(Rules.roundPhase(actor.started, clock, Config.RoundSeconds) == "Results", "round terminates at deadline")
			bank(actor)
			check(not actor.completions[round], "round completion token is unique")
			actor.completions[round] = true; actor.profile.rounds += 1; actor.phase = "Results"
			check(not Rules.canCapture({phase = actor.phase, ready = true, carry = 0,
				biome = actor.biome, position = actor.position}, {claimed = false, biome = actor.biome,
				position = actor.position}, clock, 10, 8), "capture after results rejected")
			for _, quest in ipairs(Config.Quests) do
				if Profile.questProgress(actor.profile, quest) >= quest.target and not actor.profile.quests[quest.id] then
					local coins = actor.profile.coins
					check(Profile.claim(actor.profile, quest.id), "completed quest claims once")
					check(actor.profile.coins - coins == quest.reward, "quest grants exact advertised amount")
					actor.questEarned += quest.reward
					check(not Profile.claim(actor.profile, quest.id), "quest replay cannot grant a second reward")
				end
			end
			for _, key in ipairs({"boots", "magnet", "basket"}) do
				local cost = Config.Upgrades[key].costs[actor.profile.upgrades[key] + 1]
				if cost and actor.profile.coins >= cost then
					local coins = actor.profile.coins
					check(Profile.buy(actor.profile, key), "earned upgrade can be purchased")
					check(coins - actor.profile.coins == cost, "upgrade deducts exact advertised amount")
					actor.spent += cost
				end
			end
			if round == 6 and actor.id == 1 then store.failures = 2 end
			save(actor)
			check(actor.profile.coins + actor.spent == actor.earned + actor.questEarned, "currency ledger conserves rewards and spending")
			check(actor.profile.totalBanked == actor.caught, "banked count equals unique captures owned by this actor")
		end
	end
	for _, actor in ipairs(actors) do
		check(actor.profile.rounds == 10 and actor.caught == 240, "every actor completes ten rounds and banks 240 unique captures")
		check(actor.visited[1] and actor.visited[2] and actor.visited[3], "earned progression visits all three arenas")
		check(Profile.speciesCount(actor.profile) == 12 and actor.profile.quests.complete_album, "all species and collection milestone reachable")
		for _, key in ipairs({"boots", "magnet", "basket"}) do
			check(actor.profile.upgrades[key] == #Config.Upgrades[key].costs, "all upgrade tiers reachable through earned play")
		end
		reconnect(actor)
		check(actor.persistence:release(actor.id, actor.profile), "scenario ends with every lease released")
	end
	check(uniqueCaptures == contenders * 240, "no cross-player duplicate rewards in aggregate ledger")
	print(string.format("PASS contenders=%d rounds=10 player_rounds=%d unique_captures=%d contested_attempts=%d replay_rejections=%d reconnects=%d store_calls=%d",
		contenders, contenders * 10, uniqueCaptures, raceAttempts, rejectedReplays, reconnects, store.calls))
end

for _, contenders in ipairs({1, 2, 4}) do scenario(contenders) end
print(string.format("SparkSessionSimulation: %d assertions passed; 70 simulated player-rounds. PURE MODULES ONLY; NOT STUDIO MULTIPLAYER.", assertions))
