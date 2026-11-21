-- First-round coaching (WP-08, slice): a ghost ring around the starter pod in
-- round 1 and three hint lines, each shown at most once per session (the slice
-- keeps coaching flags in memory; Profile stays v3):
--   "Run a circle around the Sparks"   round 1 start, until the first catch
--   "Bigger ring, bigger score"        after the first catch
--   "Dash to snap a ring shut"         after the first Bunvolt escape
-- Never shown after round 3.
local Coach = {}

Coach.LINES = {
	circle = "Run a circle around the Sparks",
	bigger = "Bigger ring, bigger score",
	snap = "Dash to snap a ring shut",
}

-- Pure: may coaching still show for a profile's round count?
function Coach.allowed(rounds) return (rounds or 0) < 3 end

-- Pure state machine: event -> line id to show (or nil). shown = set of ids.
function Coach.next(shown, event, rounds)
	if not Coach.allowed(rounds) then return nil end
	local id
	if event == "roundStart" and (rounds or 0) == 0 then id = "circle"
	elseif event == "firstCatch" then id = "bigger"
	elseif event == "bunvoltEscape" then id = "snap" end
	if id and not shown[id] then shown[id] = true; return id end
	return nil
end

function Coach.new(ctx)
	local self = {shown = {}, ghost = nil, caught = false, phase = nil}
	local function show(id)
		if id then ctx.hud.hint(Coach.LINES[id], os.clock(), 7) end
	end
	local function rounds()
		local d = ctx.data()
		return d and d.profile and d.profile.rounds or 0
	end
	function self.state(data)
		if data.phase ~= self.phase then
			self.phase = data.phase
			if data.phase == "Playing" then show(Coach.next(self.shown, "roundStart", rounds())) end
		end
		-- Ghost ring: round 1 only, around the private starters while any remain.
		self.ghostWanted = rounds() == 0 and data.phase == "Playing" and (data.startersRemaining or 0) > 0 and not self.caught
		self.starterCenter = data.starterCenter
	end
	function self.loopClosed() end
	function self.loopResult(extra)
		local caught = extra.caught or {}
		if #caught > 0 and not self.caught then
			self.caught = true
			ctx.hud.clearHint()
			show(Coach.next(self.shown, "firstCatch", rounds()))
		end
		for _, id in ipairs(extra.escapedSpecies or {}) do
			if id == "bunvolt" then show(Coach.next(self.shown, "bunvoltEscape", rounds())) end
		end
	end
	function self.chain() end
	local ghostAt = 0
	function self.frame(now, _root)
		if self.ghostWanted and self.starterCenter and now - ghostAt > 0.9 then
			ghostAt = now
			local c = self.starterCenter
			local origin = ctx.origin()
			ctx.loopFx.telegraph(origin + Vector3.new(c.x, ctx.groundY(c.x, c.z), c.z), 6, 1.0, Color3.fromRGB(255, 249, 231))
		end
	end
	return self
end

return Coach
