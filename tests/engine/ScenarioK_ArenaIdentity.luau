--!nocheck
-- (k) Arena identity v2 + Species Signatures: distinct obstacle layouts per arena,
-- Aurora Starfall (telegraph -> impact -> dazed Sparks hold still -> STARSTRUCK
-- catch), signature catches and album signature counts. Real Main + remotes.
local Harness = require("./Harness")
local check = Harness.check
local h = Harness.boot()
local e = h.engine

-- Distinct, data-driven obstacle sets (Encounters.Obstacles via World).
local layouts, counts = {}, {}
for _, arena in ipairs(h.world:GetChildren()) do
	if arena:GetAttribute("BiomeIndex") then
		layouts[arena.Name] = arena:GetAttribute("ObstacleLayout")
		counts[arena.Name] = {}
		for _, d in ipairs(arena:GetDescendants()) do
			if d:IsA("BasePart") then counts[arena.Name][d.Name] = (counts[arena.Name][d.Name] or 0) + 1 end
		end
	end
end
check(layouts.meadow == "island" and layouts.canyon == "pillar" and layouts.aurora == "crystal" and layouts.trials == "island",
	"Layouts: meadow islands, canyon pillars, aurora crystals, Trial Grounds islands")
check(counts.meadow.SteeringIsland == 4 and counts.canyon.RockPillar == 6 and counts.aurora.CrystalPillar == 5 and counts.trials.SteeringIsland == 4,
	"Obstacle counts 4 / 6 / 5 / 4")
check((counts.canyon.SteeringIsland or 0) == 0 and (counts.aurora.SteeringIsland or 0) == 0, "Old islands removed from canyon and aurora")

-- Unlock Aurora (90 banked) with bot rounds; signatures accrue from real catches.
local p = h:join(9301)
local tagSeen = {}
for round = 1, 6 do
	check(h:awaitPlaying({p}, 130), "Round " .. round .. " starts")
	h:playRounds({p}, {timeout = 125})
	for _, f in ipairs(h:feedbackOf(p, "Catch")) do
		for _, tag in ipairs((f.extra and f.extra.tags) or {}) do tagSeen[tag] = true end
	end
	if h:state(p).profile.totalBanked >= 90 then break end
end
local s = h:state(p)
check(s.profile.totalBanked >= 90, "Aurora unlocked by banking (" .. s.profile.totalBanked .. ")")
check(tagSeen.SIGNATURE == true, "Signature catches happen in real play")
local signatureTotal = 0
for _, count in pairs(s.profile.signatures) do signatureTotal += count end
check(signatureTotal > 0, "Album signature counts saved (" .. signatureTotal .. ")")

-- Travel to Aurora between rounds and play into the Starfall window.
h:send(p, "Biome", 3); e.step(0.3)
check(h:state(p).biome == 3, "Travelled to Aurora Arcade")
check(h:awaitPlaying({p}, 20), "Aurora round starts")
local telegraph, impacts, dazedSeen, frozen, struck = nil, 0, false, true, false
local before = e.countInstances()
local lastDazed = {}
local feedbackStart = #h:feedbackOf(p)
for _ = 1, 900 do
	local st = h:state(p)
	local t = st and st.cycle and st.cycle.t or 0
	if st.starfall and st.starfall.visible and st.starfall.position ~= nil then
		telegraph = telegraph or st.starfall
		local rel = st.starfall.position - Harness.Vector3.new(600, 0, 0)
		check(math.sqrt(rel.X ^ 2 + (rel.Z - 44) ^ 2) >= 24 - 1e-6, "Telegraph is clear of the bank")
	end
	local packet = h.latestHerd and h.latestHerd[3]
	local decoded = packet and Harness.decodeHerd(packet)
	if decoded then
		local nowDazed = {}
		for _, entry in ipairs(decoded.entries) do
			if bit32.band(entry.flags, 2) ~= 0 then
				dazedSeen = true
				nowDazed[entry.id] = entry
				local prior = lastDazed[entry.id]
				if prior and (math.abs(prior.x - entry.x) > 0.05 or math.abs(prior.z - entry.z) > 0.05) then frozen = false end
			end
		end
		lastDazed = nowDazed
		-- Chase the nearest dazed Spark and catch it for STARSTRUCK.
		local here = h:position(p)
		local target, best = nil, math.huge
		for _, entry in pairs(nowDazed) do
			local d = math.sqrt((here.X - (600 + entry.x)) ^ 2 + (here.Z - entry.z) ^ 2)
			if d < best then target, best = entry, d end
		end
		if target and not struck then
			e.walkToward(p, Harness.Vector3.new(600 + target.x, 3, target.z), 21, 1 / 10)
			if best < 3.5 then h:send(p, "Capture") end
		end
	end
	for _, f in ipairs(h:feedbackOf(p, "Catch")) do
		for _, tag in ipairs((f.extra and f.extra.tags) or {}) do if tag == "STARSTRUCK" then struck = true end end
	end
	if t >= 90 then break end
	if st.carry >= (st.capacity or 10) then e.walkToward(p, Harness.Vector3.new(600, 3, 41), 21, 1 / 10) end
	e.step(1 / 10)
end
for _, f in ipairs(h:feedbackOf(p, "Starfall")) do impacts += 1 end
local final = h:state(p)
print(string.format("INFO starfall: impacts=%d telegraph=%s dazed=%s struck=%s phase=%s biome=%s t=%s",
	impacts, tostring(telegraph and telegraph.seconds), tostring(dazedSeen), tostring(struck), tostring(final.phase), tostring(final.biome), tostring(final.cycle and final.cycle.t)))
check(telegraph ~= nil and telegraph.radius == 6 and telegraph.seconds <= 2, "Starfall telegraph descriptor (2 s, radius 6)")
check(impacts >= 5 and impacts <= 6, "Six star impacts in the window (" .. impacts .. ")")
check(dazedSeen, "Impacts daze Sparks (HerdNet dazed flag)")
check(frozen, "Dazed Sparks hold still")
check(struck, "Catching a dazed Spark scores STARSTRUCK")
e.step(5)
check(math.abs(e.countInstances() - before) < 400, "No runaway instance growth through Starfall (" .. before .. " -> " .. e.countInstances() .. ")")
check(h:state(p).starfall == nil or h:state(p).starfall.visible == false, "Telegraph clears after the window")
h:assertClean("arena identity")
h:report("arena-identity")
print("PASS ScenarioK_ArenaIdentity: " .. Harness.count() .. " checks")
