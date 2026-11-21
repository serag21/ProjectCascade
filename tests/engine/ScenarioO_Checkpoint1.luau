--!nocheck
-- (o) WP-08: the Checkpoint 1 slice end to end through the real Main + remotes.
--   T-E1  Bloom Burst telegraph 25 s / opens 30 s; Stampede telegraph 49 s, horn
--         53 s, herd 55 s; all on the shared clock (+-1 server step).
--   T-H3  live creatures <= eventLiveCap (30) through both events.
--   FULL BLOOM: one ring around the feeding cluster catches all eight (+40).
--   Phase names GRAZE -> GATHER -> STAMPEDE -> GOLDEN FINALE; results sheet data
--   (score, provisional medal, best loop size, next-round countdown).
--   T-S0  everything 'off' in slice.json is unreachable (Daily Stampede,
--         upgrades, perks/Heat, arena travel, Static Puff, Golden Runaway, sweeps).
-- Scripted bots, virtual time: proves rules and timing, not feel.
local Harness = require("./Harness")
local check = Harness.check
local Vector3 = Harness.Vector3
local h = Harness.boot()
local e = h.engine
local Events = e.requireSource("ReplicatedStorage/Spark/Design/Events.luau")
local Tuning = e.requireSource("ReplicatedStorage/Spark/Design/Tuning.luau")
local Arenas = e.requireSource("ReplicatedStorage/Spark/Design/Arenas.luau")
local p = h:join(7701)
check(h:awaitPlaying({p}, 130) and h:state(p).fullRound, "a full round starts")
local function cycleT() return (h:viewClock(1) + 0.1) % 120 end

-- Slice-off features are refused (T-S0).
local before = h:state(p)
h:send(p, "Trial", "start"); e.step(0.3)
check(h:state(p).mode ~= "trial", "Daily Stampede refused")
h:send(p, "Biome", 2); e.step(0.3)
check(h:state(p).biome == 1, "arena travel refused")
h:send(p, "Upgrade", "boots"); e.step(0.3)
check((h:state(p).profile.upgrades.boots or 0) == (before.profile.upgrades.boots or 0), "upgrades refused")
h:send(p, "Heat", 1); e.step(0.3)
check((h:state(p).profile.heat or 0) == 0, "Heat refused")

local seen = {phase = {}, events = {}}
local maxLive, goldenSeen, staticsSeen, hazardSeen = 0, false, false, false
local fullBloom, bloomRing = nil, false
local stampedeRunnersMoved = false
local feedbackIndex = 0
local function watch()
	local s = h:state(p)
	if s.phaseName and not seen.phase[s.phaseName] then seen.phase[s.phaseName] = cycleT() end
	if s.hazard and s.hazard.visible then hazardSeen = true end
	if (s.statics or 0) > 0 then staticsSeen = true end
	local live = 0
	for _, m in ipairs(h:creatures()) do
		if m:GetAttribute("StarterOwnerId") == nil then live += 1 end
		if m:GetAttribute("Golden") then goldenSeen = true end
		if m:GetAttribute("State") == 9 then stampedeRunnersMoved = true end
	end
	maxLive = math.max(maxLive, live)
	local list = h:feedbackOf(p, "Event")
	for i = feedbackIndex + 1, #list do
		local f = list[i]
		local x = f.extra or {}
		local key = tostring(x.event) .. (if x.open then ":open" elseif x.telegraph then ":telegraph" elseif x.horn then ":horn"
			elseif x.run then ":run" else ":telegraph")
		if not seen.events[key] then seen.events[key] = {t = x.at or cycleT(), extra = x} end
	end
	feedbackIndex = #list
end
-- Play the round with the loop bot, but at the Bloom Burst walk to the bud and
-- ring the feeding cluster from outside the 5-stud ignore radius.
local deadline = e.now + 125
while e.now < deadline and h:state(p).phase == "Playing" do
	watch()
	local open = seen.events["bloom_burst:open"]
	if open and not bloomRing and cycleT() < 36 then
		bloomRing = true
		local bud = open.extra.position
		local centre = Vector3.new(bud.X, 0, bud.Z + 6)
		local results = #h:loopResults(p)
		h:ringAround(p, centre, 6.5, {turns = 1.4})
		e.advance(0.4); watch()
		for _, r in ipairs(h:loopResults(p, results)) do
			if #(r.extra.caught or {}) == 8 then fullBloom = r.extra end
		end
	else
		h:playRounds({p}, {timeout = 1, bankAt = 6})
	end
end
e.advance(1); watch()
local s = h:state(p)
check(s.phase == "Results", "round reached Results (" .. tostring(s.phase) .. ")")

-- T-E1: event timing on the shared clock, as fired by the server (+-0.25 s: within
-- one 10 Hz server step, plus the heartbeat accumulator).
local function near(key, t, label)
	local ev = seen.events[key]
	check(ev ~= nil, label .. " happened")
	if ev then check(math.abs(ev.t - t) <= 0.25, string.format("%s at %.2f s (want %.2f)", label, ev.t, t)) end
end
near("bloom_burst:telegraph", Events.byId.bloom_burst.telegraphAt, "Bloom Burst telegraph")
near("bloom_burst:open", Events.byId.bloom_burst.start, "Bloom Burst opens")
near("stampede:telegraph", Events.byId.stampede.telegraphAt, "Stampede telegraph")
near("stampede:horn", Events.byId.stampede.start - 2, "Stampede horn")
near("stampede:run", Events.byId.stampede.start, "Stampede herd")
local route = seen.events["stampede:telegraph"] and seen.events["stampede:telegraph"].extra.route
check(type(route) == "table" and #route >= 4, "Stampede route is sent for the chevron telegraph")
check(stampedeRunnersMoved, "Stampede runners charged (HerdNet state 9)")
-- T-H3
check(maxLive <= Tuning.density.eventLiveCapPerArena, "live creatures <= event cap (" .. maxLive .. ")")
check(maxLive > Tuning.density.baseLiveCapPerArena, "events added creatures above the base cap (" .. maxLive .. ")")
-- FULL BLOOM
check(bloomRing, "bot reached the Bloom Burst")
check(fullBloom ~= nil, "one ring caught all eight Bloom Burst Sparks")
if fullBloom then check(fullBloom.style == 40, "FULL BLOOM style bonus +40 (" .. tostring(fullBloom.style) .. ")") end
-- Phase names in order.
local order = {"GRAZE", "GATHER", "STAMPEDE", "GOLDEN FINALE"}
for i, name in ipairs(order) do
	check(seen.phase[name] ~= nil, "phase " .. name .. " shown")
	if i > 1 and seen.phase[name] and seen.phase[order[i - 1]] then check(seen.phase[name] > seen.phase[order[i - 1]], name .. " after " .. order[i - 1]) end
end
-- Off features never appeared.
check(not goldenSeen, "no Golden Runaway in the slice")
check(not staticsSeen, "no Static Puff in the slice")
check(not hazardSeen, "no sweeps in the slice")
-- Results sheet data.
check(s.lastResult ~= nil and type(s.lastResult.score) == "number", "results score")
check(s.mastery and type(s.mastery.medal) == "string", "provisional medal")
check(s.mastery and (s.mastery.bestLoop or 0) >= 8, "best loop size recorded (" .. tostring(s.mastery and s.mastery.bestLoop) .. ")")
check(type(s.nextRoundIn) == "number" and s.nextRoundIn > 0, "next round countdown")
local medals = Tuning.scoring.medalsProvisional
local expected = if s.mastery.score >= medals.Radiant then "Radiant" elseif s.mastery.score >= medals.Gold then "Gold"
	elseif s.mastery.score >= medals.Silver then "Silver" elseif s.mastery.score >= medals.Bronze then "Bronze" else "Unranked"
check(s.mastery.medal == expected, "medal uses medalsProvisional (" .. s.mastery.medal .. ")")
print(string.format("INFO checkpoint1 bot round: score=%d medal=%s bestLoop=%d maxLive=%d bloom=%.2f/%.2f stampede=%.2f/%.2f/%.2f",
	s.mastery.score, s.mastery.medal, s.mastery.bestLoop or 0, maxLive,
	seen.events["bloom_burst:telegraph"].t, seen.events["bloom_burst:open"].t, seen.events["stampede:telegraph"].t,
	seen.events["stampede:horn"].t, seen.events["stampede:run"].t))
local _ = Arenas
h:assertClean("checkpoint1")
h:report("checkpoint1")
print("PASS ScenarioO_Checkpoint1: " .. Harness.count() .. " checks")
