--!nocheck
-- (l) Plan §6.14 soak: four bot players share one arena for twenty synchronized
-- Stampede Cycles. Asserts the performance budgets the fake engine CAN observe:
-- steady server instances (<= 4,500), herd per arena (<= 80), no non-herd growth,
-- bounded scheduled threads, and per-client network (herd <= 6 KB/s, average
-- state <= 2 KB, total <= 25 KB/s) from the real remote payloads.
-- NOT measured here: frame time, particles, real replication or device memory.
local Harness = require("./Harness")
local check = Harness.check
local h = Harness.boot()
local e = h.engine
local players = {h:join(7101), h:join(7102), h:join(7103), h:join(7104)}

-- Approximate wire size of a remote payload (numbers 9 B, strings len+2, etc.).
local function size(value, depth)
	depth = depth or 0
	local kind = type(value)
	if kind == "number" then return 9 elseif kind == "boolean" then return 1
	elseif kind == "string" then return #value + 2 elseif kind == "buffer" then return buffer.len(value) + 2
	elseif kind == "table" then
		if value.X ~= nil and value.Y ~= nil and value.Z ~= nil and depth > 0 then return 13 end
		local total = 2
		for key, item in pairs(value) do total += size(key, depth + 1) + size(item, depth + 1) end
		return total
	end
	return 1
end

-- The fake engine keeps only the last 4,000 remote entries, so traffic is drained
-- incrementally (by sequence number) while the measured cycle runs.
local per, lastSeq = nil, 0
local function startMeasure()
	per = {}
	for _, player in ipairs(players) do per[player.UserId] = {herd = 0, state = 0, states = 0, statesNoProfile = 0, stateNoProfile = 0, other = 0} end
	local log = e.remoteLog
	lastSeq = if #log > 0 then log[#log].seq else 0
end
local function drain()
	if not per then return end
	local log = e.remoteLog
	local start = #log
	while start >= 1 and log[start].seq > lastSeq do start -= 1 end
	for index = start + 1, #log do
		local entry = log[index]
		local bucket = per[entry.player.UserId]
		if bucket then
			local bytes = 0
			for _, arg in ipairs(entry.args) do bytes += size(arg) end
			if entry.remote == "HerdNet" then bucket.herd += bytes
			elseif entry.remote == "State" then
				bucket.state += bytes; bucket.states += 1
				if type(entry.args[1]) == "table" and entry.args[1].profile == nil then bucket.statesNoProfile += 1; bucket.stateNoProfile += bytes end
			else bucket.other += bytes end
		end
	end
	if #log > 0 then lastSeq = log[#log].seq end
end
local function measure(seconds)
	drain()
	local worst = {herd = 0, total = 0, avgState = 0, avgStateNoProfile = 0, states = 0, statesNoProfile = 0}
	for _, bucket in pairs(per) do
		worst.herd = math.max(worst.herd, bucket.herd / seconds)
		worst.total = math.max(worst.total, (bucket.herd + bucket.state + bucket.other) / seconds)
		worst.avgState = math.max(worst.avgState, bucket.state / math.max(1, bucket.states))
		worst.avgStateNoProfile = math.max(worst.avgStateNoProfile, bucket.stateNoProfile / math.max(1, bucket.statesNoProfile))
		worst.states = math.max(worst.states, bucket.states)
		worst.statesNoProfile = math.max(worst.statesNoProfile, bucket.statesNoProfile)
	end
	per = nil
	return worst
end

local samples, peakHerd, network = {}, 0, nil
for cycle = 1, 20 do
	check(h:awaitPlaying(players, 130), "Cycle " .. cycle .. ": all four in the shared round")
	local t0 = e.now
	if cycle == 10 then startMeasure() end
	h:playRounds(players, {timeout = 125, stopFor = function(_, now)
		drain()
		-- Mid-round herd sample (finale included) without stopping the bots.
		if now - (h.lastHerdSample or 0) > 10 then
			h.lastHerdSample = now
			local counts = {}
			for _, model in ipairs(h:creatures()) do
				local x = model:GetPivot().Position.X
				local arena = math.floor((x + 150) / 300) + 1
				counts[arena] = (counts[arena] or 0) + 1
			end
			for _, count in pairs(counts) do peakHerd = math.max(peakHerd, count) end
		end
		return false
	end})
	if cycle == 10 then network = measure(math.max(1, e.now - t0)) end
	h:assertClean("cycle " .. cycle)
	e.advance(2)
	for _, player in ipairs(players) do
		check(h:state(player).phase == "Results", "Cycle " .. cycle .. ": settled at the shared buzzer")
	end
	local herdInstances = e.countInstances(h.world.Creatures)
	table.insert(samples, {instances = e.countInstances(), other = e.countInstances() - herdInstances, sleepers = e.sleepers()})
end
local first, last = samples[1], samples[#samples]
local maxInstances, maxOther = 0, 0
for _, s in ipairs(samples) do maxInstances = math.max(maxInstances, s.instances); maxOther = math.max(maxOther, s.other) end
print(string.format("INFO soak4x20: instances first/last/max %d/%d/%d nonHerd first/last/max %d/%d/%d sleepers %d->%d peakHerd/arena %d",
	first.instances, last.instances, maxInstances, first.other, last.other, maxOther, first.sleepers, last.sleepers, peakHerd))
print(string.format("INFO network (cycle 10, worst client): herd %.0f B/s, total %.0f B/s, avg state %.0f B (%.0f B without profile)",
	network.herd, network.total, network.avgState, network.avgStateNoProfile))
check(maxInstances <= 4500, "Server instances within budget (<= 4,500; max " .. maxInstances .. ")")
check(peakHerd <= 80, "Herd per arena within budget (<= 80; peak " .. peakHerd .. ")")
check(maxOther - first.other <= 10 and last.other - first.other <= 10, "No non-herd instance growth over 20 cycles")
check(last.sleepers <= first.sleepers + 10, "Scheduled threads bounded")
check(network.herd > 500 and network.states > 100 and network.statesNoProfile > 100, "Network window actually measured traffic (non-vacuous)")
check(network.herd <= 6000, "Herd traffic <= 6 KB/s per client")
check(network.avgStateNoProfile <= 2048, "Average state payload <= 2 KB (without the periodic profile)")
check(network.total <= 25000, "Total traffic <= 25 KB/s per client")
for _, player in ipairs(players) do
	check(h:state(player).profile.rounds >= 18, "Every player credited for (nearly) every cycle")
end
h:report("soak4x20")
print("PASS ScenarioL_Soak4x20: " .. Harness.count() .. " checks; 80 player-rounds")
