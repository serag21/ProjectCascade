-- WEEKLY REMIX (plan §6.9.3, Phase 7): one deterministic, server-wide modifier per
-- UTC week (weeks start Monday 00:00 UTC, the same week index as Progression.week).
-- Every remix only ADDS chaos or generosity, so it never makes the game harder for
-- newcomers, and none of them touches the normalized Daily Stampede. Pure module:
-- Main looks the remix up once per Stampede Cycle; Encounters reads its fields.
local Remix = {}

Remix.List = {
	{id="golden_rush", name="Golden Rush", description="+2 Golden Sparks at every finale", extraGoldens=2},
	{id="big_herd", name="Big Herd", description="+6 Sparks in every arena", extraSparks=6},
	{id="rhythm_week", name="Rhythm Week", description="Chain window +1 s: keep the chain alive", chainBonus=1},
	{id="stampede_season", name="Stampede Season", description="A Stampede Run in every arena", stampedeEverywhere=true},
	{id="starfall_everywhere", name="Starfall Everywhere", description="Aurora Starfall lands in every arena", starfallEverywhere=true},
	{id="fizz_festival", name="Fizz Festival", description="Static pops x2 • statics only at Heat 1+", popMultiplier=2, staticsMinHeat=1},
}
Remix.ById = {}
for _, remix in ipairs(Remix.List) do Remix.ById[remix.id] = remix end
-- Effect bounds (asserted by tests): goldens <= 6 per finale, +6 Sparks, chain <= 12 s,
-- pops <= 120 style (Challenge rules cap), one extra run, the standard six impacts.
Remix.MaxGoldens = 6
Remix.MaxChainSeconds = 12

local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local function day(now) return math.floor(math.clamp(if finite(now) then now else 0, 0, 4102444800) / 86400) end
function Remix.week(now) return math.floor((day(now) + 3) / 7) end
-- Simple rotation: every remix comes round once every six weeks, never twice in a row.
function Remix.forWeek(week)
	local w = if finite(week) then math.max(0, math.floor(week)) else 0
	return Remix.List[w % #Remix.List + 1]
end
function Remix.current(now) return Remix.forWeek(Remix.week(now)) end
function Remix.next(now) return Remix.forWeek(Remix.week(now) + 1) end
-- Seconds until the next Monday 00:00 UTC.
function Remix.endsIn(now)
	local t = math.clamp(if finite(now) then now else 0, 0, 4102444800)
	local start = (Remix.week(t) + 1) * 7 * 86400 - 3 * 86400
	return math.max(0, start - t)
end
-- Normal-round stats with the remix applied (never used for the Daily Stampede).
function Remix.apply(stats, remix)
	if type(stats) ~= "table" or type(remix) ~= "table" then return stats end
	local out = table.clone(stats)
	if finite(remix.chainBonus) then out.chainSeconds = math.min(Remix.MaxChainSeconds, (out.chainSeconds or 6) + remix.chainBonus) end
	if finite(remix.popMultiplier) then out.popPoints = math.min(120, math.floor((out.popPoints or 40) * remix.popMultiplier)) end
	return out
end
-- Public, nonsensitive summary for State.
function Remix.describe(remix, now)
	if type(remix) ~= "table" then return nil end
	return {id=remix.id, name=remix.name, description=remix.description, endsIn=Remix.endsIn(now)}
end

return Remix
