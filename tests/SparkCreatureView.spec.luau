-- Offline checks for the client creature renderer. Pure helpers run directly;
-- the stateful ingest/render path runs against plain-table doubles passed via
-- ctx.env (no Roblox engine, nothing is rendered).
local CreatureView = require("../game/StarterPlayer/StarterPlayerScripts/Spark/CreatureView")
local n = 0
local function check(ok, message) n += 1; assert(ok, message) end
local TAU = math.pi * 2
local function finite(v) return type(v) == "number" and v == v and math.abs(v) < math.huge end
local function angleDiff(a, b) return math.abs((a - b + math.pi) % TAU - math.pi) end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end

-- Families -------------------------------------------------------------------
local expected = {
	orb = "hopper", ears = "hopper", cube = "hopper", moth = "glider", fin = "glider", ribbon = "glider",
	shell = "roller", comet = "roller", star = "roller", prism = "walker", crown = "walker", antler = "walker",
}
local perFamily, shapes = {}, 0
for shape, family in pairs(expected) do
	shapes += 1
	check(CreatureView.family(shape) == family, "family of " .. shape)
	perFamily[family] = (perFamily[family] or 0) + 1
end
check(shapes == 12, "all twelve silhouettes covered")
for _, family in ipairs({"hopper", "glider", "roller", "walker"}) do check(perFamily[family] == 3, "three shapes per family") end
check(CreatureView.family("mystery") == "walker" and CreatureView.family(nil) == "walker", "unknown shapes fall back to walker")

-- Pose bounds ------------------------------------------------------------------
local families = {"hopper", "glider", "roller", "walker"}
local states = {"idle", "move", "flee", "dazed", "startled"}
local times = {-7.3, -0.01, 0, 0.004, 0.137, 0.25, 0.5, 0.9999, 1, 3.3, 17.77, 59.9, 333.3, 4096.5, 1e5 + 0.37}
for i = 1, 120 do table.insert(times, i * 0.0731) end
local speeds = {0, 0.4, 3, 8, 12, 16, 22, 30, 1e6, -5, 0 / 0, math.huge}
local seeds = {0, 1, 7, 17.3, 999, 54321, 0 / 0}
local samples = 0
for _, family in ipairs(families) do
	for _, state in ipairs(states) do
		for _, reduced in ipairs({false, true}) do
			for _, seed in ipairs(seeds) do
				for _, speed in ipairs(speeds) do
					for _, t in ipairs(times) do
						local p = CreatureView.pose(family, t, speed, state, reduced, seed)
						samples += 1
						if not (finite(p.bob) and finite(p.squash) and finite(p.lean) and finite(p.spin) and finite(p.pitch)) then
							error(string.format("non-finite pose %s/%s t=%s", family, state, tostring(t)))
						end
						if p.bob < 0 or p.bob > 1.4 or p.squash < 0.8 or p.squash > 1.2 or math.abs(p.lean) > 0.35
							or math.abs(p.pitch) > 0.35 or p.spin < -0.5 or p.spin > TAU then
							error(string.format("pose out of bounds %s/%s t=%s", family, state, tostring(t)))
						end
						if state ~= "dazed" and math.abs(p.spin) > 0.5 then error("non-dazed spin must stay a small wiggle") end
					end
				end
			end
		end
	end
end
check(samples > 100000, "pose bounds swept over " .. samples .. " samples")

-- Reduced motion: static except a slow dazed spin; no startle jump --------------
for _, family in ipairs(families) do
	for _, state in ipairs(states) do
		local first = CreatureView.pose(family, 0, 12, state, true, 3)
		for _, t in ipairs(times) do
			local p = CreatureView.pose(family, t, 12, state, true, 3)
			check(p.bob == 0 and p.squash == 1 and p.lean == 0 and p.pitch == 0, "reduced pose is static")
			if state == "dazed" then
				check(angleDiff(CreatureView.pose(family, t + 0.1, 12, state, true, 3).spin, p.spin) <= 0.08, "reduced dazed spin is slow")
			else
				check(p.spin == 0 and first.spin == 0, "reduced non-dazed spin is zero")
			end
		end
	end
end

-- Lively and continuous when motion is allowed ---------------------------------
local function range(family, state, speed, field, seconds)
	local lo, hi = math.huge, -math.huge
	for i = 0, seconds * 240 do
		local v = CreatureView.pose(family, i / 240, speed, state, false, 5)[field]
		lo = math.min(lo, v); hi = math.max(hi, v)
	end
	return hi - lo, hi
end
check(range("hopper", "move", 12, "bob", 2) > 0.3, "moving hoppers visibly hop")
check(select(2, range("hopper", "idle", 0, "bob", 2)) <= 0.12, "idle hoppers only breathe")
check(select(2, range("hopper", "startled", 0, "bob", 1)) > 0.9, "startle jump is readable")
check(range("glider", "move", 12, "lean", 4) > 0.2, "gliders bank and sway")
check(range("roller", "move", 12, "pitch", 2) > 0.02 and select(2, range("roller", "move", 16, "pitch", 2)) > 0.15, "rollers rock forward with speed")
check(range("walker", "move", 12, "lean", 2) > 0.15, "walkers sway per step")
check(range("hopper", "dazed", 0, "spin", 4) > 5, "dazed creatures twirl")
check(range("walker", "idle", 0, "spin", 30) > 0.2, "idle creatures glance around")
for _, family in ipairs(families) do
	for _, state in ipairs(states) do
		local prev = CreatureView.pose(family, 0, 10, state, false, 11)
		local prevCopy = {bob = prev.bob, squash = prev.squash, lean = prev.lean, pitch = prev.pitch, spin = prev.spin}
		local worst = 0
		for i = 1, 4 * 240 do
			local p = CreatureView.pose(family, i / 240, 10, state, false, 11)
			worst = math.max(worst, math.abs(p.bob - prevCopy.bob), math.abs(p.squash - prevCopy.squash), math.abs(p.lean - prevCopy.lean),
				math.abs(p.pitch - prevCopy.pitch), angleDiff(p.spin, prevCopy.spin))
			prevCopy.bob, prevCopy.squash, prevCopy.lean, prevCopy.pitch, prevCopy.spin = p.bob, p.squash, p.lean, p.pitch, p.spin
		end
		check(worst < 0.1, string.format("%s/%s pose is continuous (max step %.3f at 240 Hz)", family, state, worst))
	end
end

-- Determinism -------------------------------------------------------------------
local reused = {}
for _, family in ipairs(families) do
	for _, state in ipairs(states) do
		for _, t in ipairs({0.3, 12.7, 999.1}) do
			local a = CreatureView.pose(family, t, 9, state, false, 42)
			local b = CreatureView.pose(family, t, 9, state, false, 42, reused)
			check(b == reused, "out table is filled and returned")
			check(a.bob == b.bob and a.squash == b.squash and a.lean == b.lean and a.spin == b.spin and a.pitch == b.pitch, "pose deterministic")
		end
	end
end
local differs = false
for i = 1, 20 do
	if CreatureView.pose("hopper", i * 0.1, 9, "move", false, 1).bob ~= CreatureView.pose("hopper", i * 0.1, 9, "move", false, 2).bob then differs = true end
end
check(differs, "different seeds desynchronize the herd")
check(CreatureView.pose("orb", 1.3, 9, "move", false, 4).bob == CreatureView.pose("hopper", 1.3, 9, "move", false, 4).bob, "pose accepts a shape name")

-- Interpolation -----------------------------------------------------------------
local a = {id = 7, x = 0, z = 10, heading = 0, flags = 1}
local b = {id = 7, x = 10, z = -10, heading = 1, flags = 18}
local mid = CreatureView.interpolate(a, b, 0.5)
check(near(mid.x, 5) and near(mid.z, 0) and near(mid.heading, 0.5) and mid.flags == 18 and mid.id == 7, "midpoint lerp, flags from b")
local at0, at1 = CreatureView.interpolate(a, b, 0), CreatureView.interpolate(a, b, 1)
check(near(at0.x, 0) and near(at0.z, 10) and near(at0.heading, 0) and at0.flags == 18, "alpha 0 is a (flags still from b)")
check(near(at1.x, 10) and near(at1.z, -10) and near(at1.heading, 1), "alpha 1 is b")
check(near(CreatureView.interpolate(a, b, -3).x, 0) and near(CreatureView.interpolate(a, b, 0 / 0).x, 10), "alpha clamped and NaN-safe")
check(near(CreatureView.interpolate(a, b, 99).x, 40), "extrapolation capped at alpha 4")
local wrapA, wrapB = {x = 0, z = 0, heading = 3.0, flags = 0}, {x = 0, z = 0, heading = -3.0, flags = 0}
local wrapMid = CreatureView.interpolate(wrapA, wrapB, 0.5)
check(angleDiff(wrapMid.heading, math.pi) < 1e-9, "heading crosses +/-pi on the short arc")
check(angleDiff(CreatureView.interpolate(wrapB, wrapA, 0.25).heading, -3.0 - (2 * math.pi - 6) * 0.25) < 1e-9, "short arc both directions")
check(angleDiff(CreatureView.interpolate({x = 0, z = 0, heading = 0.1}, {x = 0, z = 0, heading = -0.1}, 0.5).heading, 0) < 1e-9, "small arc through zero")
check(angleDiff(CreatureView.interpolate({x = 0, z = 0, heading = 0}, {x = 0, z = 0, heading = TAU * 3 + 0.4}, 0.5).heading, 0.2) < 1e-9, "unwrapped inputs normalized")
local spun = CreatureView.interpolate({x = 0, z = 0, heading = 0}, {x = 0, z = 0, heading = 3}, 4)
check(angleDiff(spun.heading, 3.5) < 1e-9, "extrapolated heading turns at most 0.5 rad past b")
for i = 0, 40 do
	local h = CreatureView.interpolate(wrapA, wrapB, i / 40).heading
	check(h >= -math.pi and h < math.pi and angleDiff(h, 3.0) <= (2 * math.pi - 6) + 1e-9, "never takes the long way round")
end
local out = {}
check(CreatureView.interpolate(a, b, 0.2, out) == out, "interpolate fills out table")

-- Blinks ------------------------------------------------------------------------
for seed = 1, 12 do
	local on, total, runs, longest, run, lastStart, maxGap = 0, 0, 0, 0, 0, nil, 0
	local step = 0.01
	local prev = false
	for i = 0, 30000 do
		local t = 1000 + i * step
		local blink = CreatureView.blinkAt(seed * 13.7, t)
		total += 1
		if blink then
			on += 1; run += 1
			if not prev then
				runs += 1
				if lastStart and t - lastStart > 0.5 then maxGap = math.max(maxGap, t - lastStart) end
				if not lastStart or t - lastStart > 0.5 then lastStart = t end
			end
		else
			longest = math.max(longest, run); run = 0
		end
		prev = blink
	end
	local duty = on / total
	check(duty >= 0.01 and duty <= 0.06, string.format("blink duty %.3f within 1-6%%", duty))
	check(longest * step <= 0.13 + 1e-9 and longest >= 8, "blink windows are ~0.1 s")
	check(runs >= 50 and maxGap <= 6.6, string.format("blinks recur every few seconds (max gap %.2f)", maxGap))
	check(CreatureView.blinkAt(seed, 1234.567) == CreatureView.blinkAt(seed, 1234.567), "blink deterministic")
end
local disagree = 0
for i = 0, 3000 do if CreatureView.blinkAt(1, i * 0.01) ~= CreatureView.blinkAt(2, i * 0.01) then disagree += 1 end end
check(disagree > 0, "seeds blink at different moments")
check(CreatureView.blinkAt(1, 0 / 0) == false, "NaN time never blinks")

-- LOD radius ---------------------------------------------------------------------
check(CreatureView.lodRadius(10) == 90 and CreatureView.lodRadius(4) == 90 and CreatureView.lodRadius(nil) == 90, "full radius 90 at normal quality")
local last = 0
for q = 1, 10 do
	local r = CreatureView.lodRadius(q)
	check(r >= last and r >= 60 and r <= 90, "radius monotonic in quality"); last = r
end
check(CreatureView.seedOf(5) == 5 and CreatureView.seedOf("abc") == CreatureView.seedOf("abc") and CreatureView.seedOf(nil) == 0, "seedOf stable")

-- Stateful render path with doubles ---------------------------------------------
local created = {}
local cfMeta = {}
cfMeta.__mul = function(l, r)
	return setmetatable({x = l.x, y = l.y, z = l.z, lx = l.lx, lz = l.lz, rx = l.rx + r.rx, rz = l.rz + r.rz}, cfMeta)
end
local env = {
	Vector3 = {new = function(x, y, z) return {X = x, Y = y, Z = z} end},
	CFrame = {
		lookAt = function(p, q) return setmetatable({x = p.X, y = p.Y, z = p.Z, lx = q.X - p.X, lz = q.Z - p.Z, rx = 0, rz = 0}, cfMeta) end,
		Angles = function(rx, _, rz) return setmetatable({rx = rx, rz = rz}, cfMeta) end,
	},
	Instance = {new = function(class)
		created[class] = (created[class] or 0) + 1
		local object = {ClassName = class}
		function object:Destroy() self.Parent = nil; self.destroyed = true end
		return object
	end},
	UDim2 = {fromOffset = function(x, y) return {x, y} end, fromScale = function(x, y) return {x, y} end},
	UDim = {new = function(s, o) return {s, o} end},
	Color3 = {fromRGB = function(r, g, bb) return {r, g, bb} end},
	Enum = {Font = {GothamBlack = "GothamBlack"}},
}
local folder = {Name = "Creatures"}
local function isBasePart(_, class) return class == "BasePart" end
local function fakeModel(id, shape, attrs)
	local model = {Name = "Spark_" .. tostring(id), Parent = folder, pivots = 0}
	local attributes = {CreatureId = id, Silhouette = shape}
	for k, v in pairs(attrs or {}) do attributes[k] = v end
	local children = {}
	local function part(name)
		local p = {Name = name, Parent = model, LocalTransparencyModifier = 0, IsA = isBasePart}
		table.insert(children, p)
		return p
	end
	model.PrimaryPart = part("Root")
	model.body = part("Body")
	model.eyes = {}
	for _ = 1, 2 do
		for _, name in ipairs({"EyeWhite", "Pupil", "EyeGlint"}) do table.insert(model.eyes, part(name)) end
	end
	part("Smile"); part("Foot")
	model.attributes = attributes
	function model:GetAttribute(k) return attributes[k] end
	function model:FindFirstChild(name)
		for _, c in ipairs(children) do if c.Name == name then return c end end
		return nil
	end
	function model:GetChildren() return table.clone(children) end
	function model:IsA(class) return class == "Model" end
	function model:PivotTo(cf) self.pivots += 1; self.cf = cf end
	return model
end

local camera = {CFrame = {Position = {X = 0, Y = 20, Z = 0}}}
local reducedFlag, quality = false, 10
local guiParent = {Name = "PlayerGui"}
local view = CreatureView.new({folder = folder, camera = function() return camera end, reducedMotion = function() return reducedFlag end,
	quality = function() return quality end, localUserId = 1, guiParent = guiParent, env = env})
local origin = {X = 0, Y = 0, Z = 0}
local near1 = fakeModel(1, "orb")
local farModel = fakeModel(2, "comet")
local masked = fakeModel(3, "ears", {StarterOwnerId = 999})
for _, p in ipairs(masked:GetChildren()) do p.LocalTransparencyModifier = 1 end -- as Client.watchStarter does
view.track(near1); view.track(farModel); view.track(masked)
check(view.stats().tracked == 3, "models tracked by CreatureId")

-- One master clock: snapshot k (server clock 100 + 0.1k) is received at local
-- 5.05 + 0.1k and ingested on the first frame at or after that moment.
local includeOne, startleFlags = true, nil
local function snapshot(k)
	local clock = 100 + 0.1 * k
	local entries = {
		{id = 2, x = 200, z = 10 * (clock - 100), heading = math.pi / 2, flags = 0},
		{id = 3, x = 2, z = 2, heading = 0, flags = 0},
	}
	if includeOne then
		-- Creature 1 paces 0..20 studs at 10 studs/s (triangle wave, period 4 s).
		local tt = (clock - 100) % 4
		table.insert(entries, {id = 1, x = if tt <= 2 then 10 * tt else 10 * (4 - tt), z = 0,
			heading = if tt <= 2 then 0 else math.pi, flags = 0})
	end
	if startleFlags then
		for i = 10, 15 do table.insert(entries, {id = i, x = i - 12, z = 6, heading = 0, flags = startleFlags}) end
	end
	view.ingest({arena = 1, origin = origin, clock = clock, receivedAt = 5.05 + 0.1 * k, entries = entries})
end
check(near1.pivots == 0, "no movement before snapshots")
local now, nextK = 5.05, 0
local maskedEyesTouched, nearBlinks, wasBlinking = false, 0, false
local function frame(feed)
	if feed then
		-- Resuming after a deliberate pause skips the missed packets (a real gap).
		if 5.05 + 0.1 * nextK < now - 0.5 then nextK = math.ceil((now - 5.05) / 0.1 - 1e-9) end
		while 5.05 + 0.1 * nextK <= now + 1e-9 do snapshot(nextK); nextK += 1 end
	end
	view.render(now)
	for _, eye in ipairs(masked.eyes) do if eye.LocalTransparencyModifier ~= 1 then maskedEyesTouched = true end end
	local blinking = near1.eyes[1].LocalTransparencyModifier == 1
	if blinking and not wasBlinking then nearBlinks += 1 end
	wasBlinking = blinking
end
local function run(frames, feed)
	for _ = 1, frames do now += 1 / 60; frame(feed) end
end
for i = 0, 59 do
	now = 5.05 + i / 60
	local before = near1.pivots
	frame(true)
	check(near1.pivots == before + 1, "exactly one PivotTo per frame for a near creature")
end
check(near(view.stats().offset, 5.05 - 100, 1e-9), "clock offset from receive times")
-- Interpolated 0.1 s behind: at local 6.10 the render clock is 100.95, so x = 9.5.
now = 5.05 + 1.05
frame(true)
check(near(near1.cf.x, 9.5, 1e-6) and near(near1.cf.z, 0, 1e-6), "position interpolated 0.1 s behind server clock")
check(near1.cf.lx > 0.9 and math.abs(near1.cf.lz) < 0.45, "facing +X for heading 0 (plus small pose spin)")
check(near1.cf.y >= 2.2 - 0.2 and near1.cf.y <= 2.2 + 1.4, "rendered at ground height plus pose")

-- Far creature: position-only, throttled to <= 10 Hz. Snapshots pause here.
local farBefore = farModel.pivots
run(60, false)
local farPivots = farModel.pivots - farBefore
check(farPivots <= 10 and farPivots >= 8, "far creature updates at most 10 times per second (" .. farPivots .. ")")
check(farModel.cf.rx == 0 and farModel.cf.rz == 0 and farModel.cf.y == 2.2, "far creature has no pose")
check(masked.pivots > 0 and masked.cf.rx == 0 and masked.cf.y == 2.2, "masked starter still moves, position only")

-- Extrapolation stops 0.15 s past the newest snapshot (server clock 101.0).
local held = near1.cf.x
run(30, false)
check(near(near1.cf.x, held, 1e-9) and near(near1.cf.x, 10 * (1.0 + 0.15), 1e-6), "extrapolation capped at 0.15 s then held")

-- Blinks within 40 studs; never on masked models; far models never blink.
run(14 * 60, true)
check(nearBlinks >= 2, "near creature blinks (" .. nearBlinks .. ")")
check(not maskedEyesTouched, "masked starter eyes never unmasked by blinking")
check(farModel.eyes[1].LocalTransparencyModifier == 0, "far creature never blinks")

-- Startle "!": one pooled billboard per rising edge, max 4, hidden after 0.6 s.
local startlers = {}
for i = 10, 15 do
	local model = fakeModel(i, "star")
	view.track(model)
	table.insert(startlers, model)
end
startleFlags = 0
run(12, true)
startleFlags = 16
run(7, true)
local s = view.stats()
check(s.bangs <= 4 and s.bangsActive == 4 and (created.BillboardGui or 0) <= 4, "startle pool bounded at four")
check((created.TextLabel or 0) == (created.BillboardGui or 0) and (created.UICorner or 0) == (created.BillboardGui or 0), "one label + corner per pooled billboard")
run(40, true)
check(view.stats().bangsActive == 0, "startle marks hide after 0.6 s and a held flag does not re-trigger")
startleFlags = 0
run(7, true)
reducedFlag = true
startleFlags = 16
run(7, true)
check(view.stats().bangsActive == 0, "no startle mark in reduced motion")
check((created.BillboardGui or 0) <= 4, "no billboard churn")
for class in pairs(created) do
	check(class == "BillboardGui" or class == "TextLabel" or class == "UICorner", "only the pooled startle instances are ever created")
end

-- Reduced motion settles to a static pose (after the short cross-fade).
run(30, true)
check(near1.cf.rx == 0 and near1.cf.rz == 0 and near(near1.cf.y, 2.2, 1e-9), "reduced motion: no bob, tilt or lean")
reducedFlag = false

-- Destroyed mid-frame (and the server stops sending it): no PivotTo, untracked,
-- last pose kept briefly for catch effects, then released.
local pivotsBefore = near1.pivots
near1.Parent = nil
includeOne = false
run(1, true)
check(near1.pivots == pivotsBefore, "destroyed model is not moved")
check(view.lastPose(1) ~= nil, "last pose survives removal for catch effects")
check(view.stats().tracked == 2 + #startlers, "destroyed model untracked")
run(200, true)
check(view.lastPose(1) == nil, "stale last pose released")
check(view.lastPose(2) == farModel.cf and view.lastPose(farModel) == farModel.cf, "lastPose by id or model")

-- Memory: the stale id was pruned; steady state stays constant.
local before = view.stats().records
check(before == 2 + #startlers, "records match live ids (" .. before .. ")")
run(300, true)
check(view.stats().records == before, "no record growth in steady state")
check(view.stats().ghosts == 0 and view.stats().pending == 0, "no leftover ghosts or pending models")

-- Pending model: tracked once its CreatureId replicates.
local late = fakeModel(nil, "crown")
view.track(late)
check(view.stats().pending == 1, "model without CreatureId waits")
late.attributes.CreatureId = 40
run(20, true)
check(view.stats().pending == 0 and view.stats().tracked == 3 + #startlers, "late CreatureId picked up")

-- Untrack + destroy restore state and release pooled instances.
view.untrack(late)
check(view.stats().tracked == 2 + #startlers, "untrack removes model")
view.destroy()
local s2 = view.stats()
check(s2.records == 0 and s2.bangs == 0, "destroy clears everything")
for _, model in ipairs(startlers) do
	for _, eye in ipairs(model.eyes) do check(eye.LocalTransparencyModifier == 0, "eyes restored on destroy") end
end
view.render(now + 1); view.ingest({origin = origin, clock = 1, entries = {}})
check(view.stats().records == 0, "destroyed view ignores further calls")

print("PASS SparkCreatureView: " .. n .. " assertions (family/pose/interpolate/blink pure helpers + doubled render path)")
