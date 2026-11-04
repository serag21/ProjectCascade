--!nocheck
-- (h) Malformed and flooding client requests through the real Action remote:
-- no server errors, no progression change, legitimate play still works.
local Harness = require("./Harness")
local check = Harness.check
local h = Harness.boot()
local e = h.engine
local p = h:join(8001)
-- Stand on the far rim, >10 studs from any Spark (herd radius 48), so junk
-- Capture/Dash/Bank requests cannot legitimately earn anything.
check(h:walkTo(p, Harness.Vector3.new(0, 3, -62), 8), "Walked to the rim")
e.advance(0.5)
local before = h:state(p).profile
local snapshot = {coins = before.coins, banked = before.totalBanked, xp = before.xp, rounds = before.rounds}
local nan, inf = 0 / 0, math.huge
local junk = table.pack(nil, true, 1, -1, nan, inf, -inf, "", string.rep("x", 5000), {}, {1, 2, 3}, {bogus = true},
	{"reach", "rhythm", "slipstream", "pockets"}, Harness.Vector3.new(1, 2, 3), p)
local actions = {"Ready", "Capture", "Dash", "Bank", "Replay", "Upgrade", "Quest", "Settings", "Biome", "Goal", "Style",
	"Title", "Loadout", "Heat", "", string.rep("A", 300), "Admin", "GiveGlow"}
local sent = 0
for _, action in ipairs(actions) do
	for index = 1, junk.n do
		h:send(p, action, junk[index])
		sent += 1
		-- Space past the 0.08s transport limiter so every request reaches its handler.
		e.advance(0.09)
	end
end
-- Non-string action types too.
for _, weird in ipairs({1, true, {}, nan, p}) do h:send(p, weird, "x"); e.advance(0.09); sent += 1 end
-- Flood: 500 requests in one frame.
for _ = 1, 500 do h:send(p, "Capture") end
e.advance(1)
h:assertClean("abuse")
local after = h:state(p).profile
check(after.coins == snapshot.coins and after.totalBanked == snapshot.banked and after.xp == snapshot.xp and after.rounds == snapshot.rounds,
	"Progression unchanged by malformed requests")
check(after.heat == 0 and #after.loadout == 0 and after.style.trail == "none", "No unearned heat/perks/style")
check(p.Parent ~= nil, "Player not kicked by junk")
-- Legitimate play afterwards still works.
local mine = function(m) return m:GetAttribute("StarterOwnerId") == p.UserId end
local caught = h:chaseAndCatch(p, mine, 15)
check(caught, "Legitimate catch after abuse")
h:report("remote-abuse")
print("PASS ScenarioH_RemoteAbuse: " .. Harness.count() .. " checks; " .. sent .. " malformed + 500 flood requests")
