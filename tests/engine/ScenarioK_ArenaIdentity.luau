--!nocheck
-- (k) Arena identity: the data-driven Meadow plus the legacy Canyon/Aurora/Trial
-- layouts, and (slice) arena travel refused. Live Starfall returns with WP-12.
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
-- WP-05: the Meadow is built from design data (ScenarioM checks its features);
-- Canyon, Aurora and the Trial Grounds keep the legacy layouts (worldLegacy).
check(h.world.meadow:GetAttribute("DataDriven") == true and (counts.meadow.SteeringIsland or 0) == 0, "Meadow is data-driven")
check(layouts.canyon == "pillar" and layouts.aurora == "crystal" and layouts.trials == "island",
	"Layouts: canyon pillars, aurora crystals, Trial Grounds islands")
check(counts.canyon.RockPillar == 6 and counts.aurora.CrystalPillar == 5 and counts.trials.SteeringIsland == 4,
	"Obstacle counts 6 / 5 / 4")
check((counts.canyon.SteeringIsland or 0) == 0 and (counts.aurora.SteeringIsland or 0) == 0, "Old islands removed from canyon and aurora")

-- Checkpoint 1 slice (Design.Slice "arena_travel" off): Canyon and Aurora keep
-- their legacy layouts (worldLegacy) but are unreachable; the live Starfall
-- check returns with WP-12. Signature stars accrue from loop techniques.
local p = h:join(9301)
check(h:awaitPlaying({p}, 130), "Round starts")
h:playRounds({p}, {timeout = 125})
local s = h:state(p)
check(s.profile.totalBanked >= 1, "Bot banked loop catches (" .. s.profile.totalBanked .. ")")
h:send(p, "Biome", 3); e.step(0.3)
check(h:state(p).biome == 1, "Travel to Aurora is refused in the slice")
h:send(p, "Biome", 2); e.step(0.3)
check(h:state(p).biome == 1, "Travel to Canyon is refused in the slice")
h:assertClean("arena identity")
h:report("arena-identity")
print("PASS ScenarioK_ArenaIdentity: " .. Harness.count() .. " checks")
