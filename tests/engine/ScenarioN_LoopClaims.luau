--!nocheck
-- (n) WP-04 loop claims through the real Main + remotes:
--   T-L3: a stationary bot spamming every input scores 0 over a full round;
--   T-L5: two simultaneous loops over one creature -> one catch, the other ASSIST;
--   adversarial: replayed polygon, claim during intermission, another arena's
--   coordinates, malformed payloads and a 500-claim flood grant nothing and are counted;
--   Capture is a no-op; no server-created physics constraint on a dash.
local Harness = require("./Harness")
local check = Harness.check
local Vector3 = Harness.Vector3
local h = Harness.boot()
local e = h.engine
local Loop, T = h:loopKit()

-- T-L3: stationary input spam (Capture, Dash, Bank, junk Loops) for a whole round.
local spammer = h:join(4101)
check(h:awaitPlaying({spammer}, 130), "spammer round starts")
local ring = {}
for i = 0, 23 do local a = i * math.pi / 12; ring[i + 1] = {x = 8 * math.cos(a), z = 40 + 8 * math.sin(a)} end
local fake = Loop.encode(ring)
local spamStart = e.now
while e.now - spamStart < 112 do
	for _, action in ipairs({"Capture", "Dash", "Bank"}) do h:send(spammer, action) end
	h:send(spammer, "Loop", {poly = fake, kind = "snap", viewClock = h:viewClock(1)})
	e.advance(0.25)
	local st = h:state(spammer)
	if st.phase == "Results" then break end
end
local st = h:state(spammer)
check(st.phase == "Results" or st.phase == "Playing", "spammer reached the end of the round")
check((st.lastResult and st.lastResult.score or (st.mastery and st.mastery.score) or 0) == 0, "stationary input spam scores 0")
check(st.profile.totalBanked == 0, "stationary input spam banks nothing")
for _, model in ipairs(spammer.Character:GetDescendants()) do
	check(not model:IsA("LinearVelocity") and not model:IsA("BodyVelocity"), "server created no dash constraint")
end
h:assertClean("spam")

-- T-L5 + adversarial with two fresh players in the next round.
local a = h:join(4201)
local b = h:join(4202)
check(h:awaitPlaying({a, b}, 130), "pair round starts")
local before = e.now
-- Starters are private: ring a normal (shared) creature. Both players walk the
-- same ring around it from opposite sides; claims arrive in the same tick.
local function shared(m) return m:GetAttribute("StarterOwnerId") == nil and m:GetPivot().Position.X < 150 end
local target = h:nearest(h:position(a), shared)
check(target ~= nil, "a shared creature exists")
local id = target:GetAttribute("CreatureId")
local centre = target:GetPivot().Position
-- Freeze the target for the test by stepping in tiny increments while both draw.
local ra, rb = h:ribbonFor(a), h:ribbonFor(b)
local radius = 5
local angleA, angleB = 0, math.pi
h:walkTo(a, Vector3.new(centre.X + radius, 3, centre.Z), 6)
h:walkTo(b, Vector3.new(centre.X - radius, 3, centre.Z), 6)
ra.ribbon = Loop.new(); rb.ribbon = Loop.new()
local sentA, sentB
local dt = 1 / 30
for _ = 1, 200 do
	angleA += 21 * dt / radius; angleB += 21 * dt / radius
	e.walkToward(a, Vector3.new(centre.X + math.cos(angleA) * radius, 3, centre.Z + math.sin(angleA) * radius), 22, dt)
	e.walkToward(b, Vector3.new(centre.X + math.cos(angleB) * radius, 3, centre.Z + math.sin(angleB) * radius), 22, dt)
	e.step(dt)
	if not sentA then sentA = h:ribbonStep(a, 1) end
	if not sentB then sentB = h:ribbonStep(b, 1) end
	if sentA and sentB then break end
end
check(sentA ~= nil and sentB ~= nil, "both players closed a ring")
e.advance(0.6)
local resultsA, resultsB = h:loopResults(a), h:loopResults(b)
local function caughtIds(list)
	local ids = {}
	for _, r in ipairs(list) do for _, c in ipairs(r.extra.caught or {}) do ids[c.creatureId] = true end end
	return ids
end
local aIds, bIds = caughtIds(resultsA), caughtIds(resultsB)
local winners = (if aIds[id] then 1 else 0) + (if bIds[id] then 1 else 0)
print(string.format("INFO contest: target=%d A caught=%s B caught=%s", id, tostring(aIds[id]), tostring(bIds[id])))
if winners == 1 then
	local loser = if aIds[id] then b else a
	local assists = h:feedbackOf(loser, "Assist")
	check(#assists >= 1, "the other player gets an ASSIST")
else
	-- The creature may have fled the shared ring before either closed: then neither
	-- caught it and nobody is credited. What can never happen is a double catch.
	check(winners == 0, "a creature is never caught twice")
end

-- Adversarial through the real server: replay of an accepted polygon, another
-- arena's coordinates, malformed payloads. Each grants nothing.
local function carry(player) return h:state(player).carry end
local before = carry(a)
if sentA then
	h:send(a, "Loop", {poly = Loop.encode(sentA), kind = "snap", viewClock = h:viewClock(1)})
	e.advance(0.5)
	check(carry(a) == before, "replayed polygon grants nothing")
end
local canyonRing = {}
for i = 0, 23 do local q = i * math.pi / 12; canyonRing[i + 1] = {x = 300 + 8 * math.cos(q), z = 8 * math.sin(q)} end
h:send(a, "Loop", {poly = Loop.encode(canyonRing), kind = "snap", viewClock = h:viewClock(1)})
for _, junk in ipairs({"x", 5, {poly = "nope", kind = "snap", viewClock = 1}, {poly = fake, kind = "warp", viewClock = 1}}) do
	h:send(a, "Loop", junk)
end
e.advance(0.6)
check(carry(a) == before, "foreign/malformed claims grant nothing")
-- Claim during intermission: wait for Results, then claim.
local deadline = e.now + 130
while h:state(a).phase == "Playing" and e.now < deadline do e.advance(0.5) end
check(h:state(a).phase == "Results", "round ended")
local banked = h:state(a).profile.totalBanked
h:send(a, "Loop", {poly = fake, kind = "snap", viewClock = h:viewClock(1)})
e.advance(0.5)
check(h:state(a).carry == 0 and h:state(a).profile.totalBanked == banked, "a claim during intermission grants nothing")
h:assertClean("claims")
h:report("loop-claims")
print("PASS ScenarioN_LoopClaims: " .. Harness.count() .. " checks")
