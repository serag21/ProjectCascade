-- Per-species creature state machines (WP-06), pure and shared. The server steps
-- every creature at the 10 Hz heartbeat; nothing here touches Roblox. Numbers
-- come from Design.Creatures (species) and Design.Tuning; a few behaviour
-- constants that the design states in prose live in Herd.K below.
--
-- Creature record (arena-relative studs):
--   {id, species, def, x, z, heading, state, stateAt, until, height, catchable,
--    home = {x, z, r}, podId, flock = flockRecord?, perches?, seed,
--    dazedUntil, boopUntil, boopX, boopZ, starter, extra}
-- States and HerdNet codes (design/fable/03 section 2):
--   graze 0, alert 1, flee 2, crouch 3, airborne 4, perched 5, flying 6, lean 7,
--   feeding 8, charging 9, dazed 10, cinched 11, scatter 12
local Herd = {}

Herd.CODES = {graze = 0, alert = 1, flee = 2, crouch = 3, airborne = 4, perched = 5, flying = 6, lean = 7,
	feeding = 8, charging = 9, dazed = 10, cinched = 11, scatter = 12}
Herd.UNCATCHABLE = {airborne = true, flying = true}

Herd.K = {
	alertSeconds = 0.3,          -- Pip: ears flatten, one squeak, then scoot
	podPull = 0.6,               -- toward-pod weight in flee steering (03 section 2)
	calmSeconds = 1.2,           -- no player inside awareness this long -> graze again
	margin = 2.5,                -- obstacle / water / boundary margin
	hopInterval = 2.6, crouchSeconds = 0.5, airSeconds = 0.7, hopDistance = 12, hopArc = 5,
	flockTurnDelay = 0.4, flockSpacing = 2.7, scatterSeconds = 3,
	perchSeconds = 4.0, takeoffDelay = 0.6, flightMin = 5, flightMax = 7, flightHeight = 9, perchGlowLead = 1.5,
	boopShove = 6, boopAlert = 0.8, boopSeconds = 0.25,
	feedIgnore = 5,              -- Bloom Burst feeders ignore players outside this
	starterTether = 3,           -- starter Pips never wander further than this from home
}

local function len(x, z) return math.sqrt(x * x + z * z) end
local function norm(x, z)
	local m = len(x, z)
	if m < 1e-6 then return 0, 0 end
	return x / m, z / m
end

-- Nearest player (players = {{x, z, id}}); -> player, distance.
function Herd.nearest(c, players)
	local best, bestD = nil, math.huge
	for _, p in ipairs(players) do
		local d = len(p.x - c.x, p.z - c.z)
		if d < bestD then best, bestD = p, d end
	end
	return best, bestD
end

-- Steering away from blockers ({x, z, r} circles), water/boundary handled by ctx.
local function avoid(c, ctx)
	local ax, az = 0, 0
	for _, b in ipairs(ctx.blockers or {}) do
		local dx, dz = c.x - b.x, c.z - b.z
		local d = len(dx, dz)
		local reach = b.r + Herd.K.margin + 2
		if d < reach and d > 1e-4 then
			local w = (reach - d) / reach
			ax += dx / d * w * 2; az += dz / d * w * 2
		end
	end
	if ctx.boundary then
		local bx, bz, depth = ctx.boundary(c.x, c.z)
		if depth < Herd.K.margin + 3 then
			local w = (Herd.K.margin + 3 - depth) / (Herd.K.margin + 3)
			ax += bx * w * 3; az += bz * w * 3
		end
	end
	return ax, az
end

-- Hard constraint after a move: never inside a blocker or outside the bounds.
local function constrain(c, ctx)
	for _, b in ipairs(ctx.blockers or {}) do
		local dx, dz = c.x - b.x, c.z - b.z
		local d = len(dx, dz)
		local min = b.r + Herd.K.margin
		if d < min then
			if d < 1e-4 then dx, dz, d = 1, 0, 1 end
			c.x, c.z = b.x + dx / d * min, b.z + dz / d * min
		end
	end
	if ctx.clampInside then c.x, c.z = ctx.clampInside(c.x, c.z, Herd.K.margin) end
end

local function moveToward(c, dx, dz, speed, dt, ctx, turnRate)
	local ax, az = avoid(c, ctx)
	local nx, nz = norm(dx + ax, dz + az)
	if nx == 0 and nz == 0 then return end
	local want = math.atan2(nz, nx)
	if turnRate then
		local delta = (want - c.heading + math.pi) % (2 * math.pi) - math.pi
		local maxTurn = turnRate * dt
		c.heading += math.clamp(delta, -maxTurn, maxTurn)
		nx, nz = math.cos(c.heading), math.sin(c.heading)
	else
		c.heading = want
	end
	c.x += nx * speed * dt; c.z += nz * speed * dt
	c.speed = speed
	constrain(c, ctx)
end

local function setState(c, state, now)
	if c.state ~= state then c.state = state; c.stateAt = now end
	c.catchable = not Herd.UNCATCHABLE[state]
end
Herd.setState = setState

-- Graze: amble around the habitat at idle speed, drifting back if outside it.
local function graze(c, ctx, dt, now)
	local def = c.def
	local idle = (def.speed.idle or 3) * ctx.speedScale
	local hx, hz = c.home.x - c.x, c.home.z - c.z
	local fromHome = len(hx, hz)
	local wobble = math.sin((now + c.seed) * 0.55) * 0.9
	c.heading += wobble * dt
	local dx, dz = math.cos(c.heading), math.sin(c.heading)
	if fromHome > c.home.r then dx, dz = hx, hz end
	moveToward(c, dx, dz, idle * (0.6 + 0.4 * math.abs(math.sin((now + c.seed) * 0.8))), dt, ctx, 2.5)
end

local function podCentroid(c, ctx)
	local members = ctx.pods and ctx.pods[c.podId]
	if not members then return c.x, c.z end
	local sx, sz, n = 0, 0, 0
	for _, m in ipairs(members) do
		if m ~= c and not m.gone then sx += m.x; sz += m.z; n += 1 end
	end
	if n == 0 then return c.x, c.z end
	return sx / n, sz / n
end

-- Flee: away from the nearest player x 1.0 + toward the pod x podPull + avoidance.
local function flee(c, ctx, dt, player, speed)
	local ax, az = norm(c.x - player.x, c.z - player.z)
	local px, pz = podCentroid(c, ctx)
	local tx, tz = norm(px - c.x, pz - c.z)
	moveToward(c, ax + tx * Herd.K.podPull, az + tz * Herd.K.podPull, speed, dt, ctx, 6)
end

-- Boop (dash shove): 6 studs sideways over 0.25 s, then alert 0.8 s.
function Herd.boop(c, now, sx, sz)
	c.boopUntil = now + Herd.K.boopSeconds
	c.boopX, c.boopZ = sx, sz
	c.boopLeft = Herd.K.boopShove
	c.alertUntil = now + Herd.K.boopSeconds + Herd.K.boopAlert
	if c.flock then c.flock.scatterUntil = now + Herd.K.scatterSeconds end
end

local function applyBoop(c, ctx, dt, now)
	if c.boopLeft and c.boopLeft > 0 then
		-- Exactly boopShove studs over boopSeconds, whatever the step size.
		local move = math.min(c.boopLeft, Herd.K.boopShove / Herd.K.boopSeconds * dt)
		c.boopLeft -= move
		c.x += c.boopX * move; c.z += c.boopZ * move
		constrain(c, ctx)
		return true
	end
	return false
end

---------------------------------------------------------------- species
local species = {}

-- Pip Pop: clump. Alert 0.3 s, then scoot away AND toward podmates.
species.clump = function(c, ctx, dt, now)
	local player, d = Herd.nearest(c, ctx.players)
	local aware = player ~= nil and d < c.def.awareness
	if aware then c.lastThreat = now end
	if c.state == "graze" or c.state == nil then
		if aware then setState(c, "alert", now) else graze(c, ctx, dt, now) end
	elseif c.state == "alert" then
		if now - c.stateAt >= Herd.K.alertSeconds then setState(c, "flee", now) end
	elseif c.state == "flee" then
		if player and now - (c.lastThreat or 0) < Herd.K.calmSeconds then
			flee(c, ctx, dt, player, c.def.speed.flee * ctx.speedScale * (c.starter and 0.55 or 1))
		else
			setState(c, "graze", now)
		end
	end
	if c.starter then
		local hx, hz = c.x - c.home.x, c.z - c.home.z
		local d2 = len(hx, hz)
		if d2 > Herd.K.starterTether then c.x, c.z = c.home.x + hx / d2 * Herd.K.starterTether, c.home.z + hz / d2 * Herd.K.starterTether end
	end
end

-- Bunvolt: hopper. Under pressure it flees in bounds; every hopInterval it
-- crouches (0.5 s, catchable) then hops 12 studs directly away (0.7 s, uncatchable).
species.hopper = function(c, ctx, dt, now)
	local K = Herd.K
	local player, d = Herd.nearest(c, ctx.players)
	local aware = player ~= nil and d < c.def.awareness
	if aware then c.lastThreat = now end
	local state = c.state or "graze"
	if state == "crouch" then
		c.speed = 0
		if now - c.stateAt >= K.crouchSeconds then
			local from = c.threat or player or {x = c.x + 1, z = c.z}
			local hx, hz = norm(c.x - from.x, c.z - from.z)
			if hx == 0 and hz == 0 then hx, hz = 1, 0 end
			c.hopFromX, c.hopFromZ, c.hopDX, c.hopDZ = c.x, c.z, hx, hz
			c.heading = math.atan2(hz, hx)
			setState(c, "airborne", now)
		end
	elseif state == "airborne" then
		local t = math.clamp((now - c.stateAt) / K.airSeconds, 0, 1)
		c.x, c.z = c.hopFromX + c.hopDX * K.hopDistance * t, c.hopFromZ + c.hopDZ * K.hopDistance * t
		c.height = 4 * K.hopArc * t * (1 - t)
		constrain(c, ctx)
		c.speed = K.hopDistance / K.airSeconds
		if t >= 1 then
			c.height = 0
			setState(c, if aware then "flee" else "graze", now)
		end
	elseif state == "flee" then
		if not player or now - (c.lastThreat or 0) >= K.calmSeconds then
			setState(c, "graze", now)
		else
			flee(c, ctx, dt, player, c.def.speed.flee * ctx.speedScale)
			if now >= (c.nextHop or 0) then
				-- Every hopInterval under pressure, measured crouch to crouch.
				c.threat = {x = player.x, z = player.z}
				c.nextHop = now + K.hopInterval
				setState(c, "crouch", now)
			end
		end
	else
		if aware then
			c.nextHop = math.max(c.nextHop or 0, now + 0.4)
			setState(c, "flee", now)
		else
			graze(c, ctx, dt, now)
		end
	end
end

-- Cubloom: flock. Four move as one block; turns follow the leader's heading after
-- a 0.4 s lean (all four lean first). A boop scatters the flock for 3 s.
species.flock = function(c, ctx, dt, now)
	local f = c.flock
	if not f then species.clump(c, ctx, dt, now); return end
	if f.steppedAt ~= now then
		f.steppedAt = now
		local alive = {}
		for _, m in ipairs(f.members) do if not m.gone then table.insert(alive, m) end end
		f.alive = alive
		if #alive > 0 then
			local cx, cz = 0, 0
			for _, m in ipairs(alive) do cx += m.x; cz += m.z end
			f.x, f.z = cx / #alive, cz / #alive
		end
		local probe = {x = f.x, z = f.z}
		local player, d = Herd.nearest(probe, ctx.players)
		local aware = player ~= nil and d < c.def.awareness
		if aware then
			local want = math.atan2(f.z - player.z, f.x - player.x)
			local delta = math.abs((want - f.heading + math.pi) % (2 * math.pi) - math.pi)
			if delta > 0.6 and not f.turning then
				f.turning = true; f.turnAt = now; f.target = want
			elseif not f.turning then
				f.target = want
			end
			f.lastThreat = now
		end
		if f.turning and now - f.turnAt >= Herd.K.flockTurnDelay then
			f.turning = false; f.heading = f.target
		elseif not f.turning and f.target then
			f.heading = f.target
		end
		f.fleeing = f.lastThreat ~= nil and now - f.lastThreat < Herd.K.calmSeconds
		local speed = (if f.fleeing then c.def.speed.flee else c.def.speed.idle) * ctx.speedScale
		if f.turning then speed *= 0.3 end
		if not f.fleeing then
			local hx, hz = f.home.x - f.x, f.home.z - f.z
			if len(hx, hz) > f.home.r then f.heading = math.atan2(hz, hx)
			else f.heading += math.sin((now + f.seed) * 0.4) * 0.5 * dt end
			f.target = nil
		end
		-- Move the block's centre with avoidance, then each member to its slot.
		local block = {x = f.x, z = f.z, heading = f.heading}
		moveToward(block, math.cos(f.heading), math.sin(f.heading), speed, dt, ctx, if f.turning then 0 else 3)
		f.heading = block.heading
		f.x, f.z, f.speed = block.x, block.z, speed
	end
	if f.scatterUntil and now < f.scatterUntil then
		-- Split: each member flees on its own for 3 s (usually a mistake).
		local player = Herd.nearest(c, ctx.players)
		if player then flee(c, ctx, dt, player, c.def.speed.flee * ctx.speedScale) end
		setState(c, "scatter", now)
		return
	end
	local slot = c.slot or 1
	local ox = ((slot - 1) % 2 - 0.5) * Herd.K.flockSpacing
	local oz = (math.floor((slot - 1) / 2) - 0.5) * Herd.K.flockSpacing
	local ch, sh = math.cos(f.heading), math.sin(f.heading)
	local tx = f.x + ox * sh + oz * ch
	local tz = f.z - ox * ch + oz * sh
	local k = math.min(1, dt * 6)
	c.x += (tx - c.x) * k; c.z += (tz - c.z) * k
	constrain(c, ctx)
	c.heading = if f.turning then f.target or f.heading else f.heading
	c.speed = f.speed or 0
	setState(c, if f.turning then "lean" elseif f.fleeing then "flee" else "graze", now)
end

-- Flutterwink: percher. Lands on a perch for 4 s (catchable); flies a lazy
-- figure-eight 9 studs up between perches for 5-7 s (uncatchable). A player
-- inside awareness while it is perched makes it take off after 0.6 s.
species.percher = function(c, ctx, dt, now)
	local K = Herd.K
	local perches = c.perches or ctx.perches or {}
	if #perches == 0 then species.clump(c, ctx, dt, now); return end
	c.perchIndex = c.perchIndex or 1
	local state = c.state or "perched"
	if state == "perched" or state == "graze" then
		if state ~= "perched" then setState(c, "perched", now) end
		local p = perches[c.perchIndex]
		c.x, c.z, c.height, c.speed = p.x, p.z, p.h or 6, 0
		local player, d = Herd.nearest(c, ctx.players)
		if player and d < c.def.awareness and not c.takeoffAt then c.takeoffAt = now + K.takeoffDelay end
		if now - c.stateAt >= K.perchSeconds or (c.takeoffAt and now >= c.takeoffAt) then
			c.takeoffAt = nil
			c.fromX, c.fromZ, c.fromH = c.x, c.z, c.height
			c.perchIndex = c.perchIndex % #perches + 1
			c.flightSeconds = K.flightMin + (K.flightMax - K.flightMin) * ((c.seed * 7.31) % 1)
			c.seed += 1.7
			setState(c, "flying", now)
		end
	elseif state == "flying" then
		local p = perches[c.perchIndex]
		local t = math.clamp((now - c.stateAt) / c.flightSeconds, 0, 1)
		-- Lazy figure-eight around the straight line between perches.
		local lx, lz = c.fromX + (p.x - c.fromX) * t, c.fromZ + (p.z - c.fromZ) * t
		local dx, dz = norm(p.x - c.fromX, p.z - c.fromZ)
		local wide = math.sin(t * math.pi * 2) * 6 * math.sin(t * math.pi)
		local prevX, prevZ = c.x, c.z
		c.x, c.z = lx - dz * wide, lz + dx * wide
		local cruise = K.flightHeight
		c.height = if t < 0.15 then c.fromH + (cruise - c.fromH) * (t / 0.15)
			elseif t > 0.85 then (p.h or 6) + (cruise - (p.h or 6)) * ((1 - t) / 0.15) else cruise
		local mx, mz = c.x - prevX, c.z - prevZ
		if len(mx, mz) > 1e-4 then c.heading = math.atan2(mz, mx) end
		c.speed = len(mx, mz) / math.max(dt, 1e-3)
		c.glowPerch = if c.flightSeconds - (now - c.stateAt) <= K.perchGlowLead then c.perchIndex else nil
		if t >= 1 then c.glowPerch = nil; setState(c, "perched", now) end
	end
end

-- Event herds: feeding (ignore players outside feedIgnore until the scatter
-- time), then flee outward; stampede runners charge along a route.
species.feeder = function(c, ctx, dt, now)
	local player, d = Herd.nearest(c, ctx.players)
	if c.feedUntil and now < c.feedUntil and not (player and d < Herd.K.feedIgnore) then
		setState(c, "feeding", now)
		local hx, hz = c.home.x - c.x, c.home.z - c.z
		if len(hx, hz) > 1.5 then moveToward(c, hx, hz, 2, dt, ctx) else c.speed = 0 end
		return
	end
	c.feedUntil = nil
	c.behaviorAfter(c, ctx, dt, now)
end

species.runner = function(c, ctx, dt, now)
	local route = c.route
	local speed = c.routeSpeed
	c.routeT = (c.routeT or 0) + speed * dt
	local x, z, hx, hz, done = Herd.alongRoute(route, c.routeT - c.lag)
	if done then c.finished = true; return end
	-- Swerve up to 4 studs around a body in the path.
	local player, d = Herd.nearest({x = x, z = z}, ctx.players)
	local sx, sz = 0, 0
	if player and d < 4 then
		local ax, az = norm(x - player.x, z - player.z)
		sx, sz = ax * (4 - d), az * (4 - d)
	end
	c.x, c.z = x - hz * c.lane + sx, z + hx * c.lane + sz
	c.heading = math.atan2(hz, hx)
	c.speed = speed
	setState(c, if c.routeT - c.lag < 0 then "graze" else "charging", now)
end

-- Route sampling: points {{x, z}, ...}, distance s -> x, z, unit direction, finished.
function Herd.routeLength(points)
	local total = 0
	for i = 1, #points - 1 do total += len(points[i + 1][1] - points[i][1], points[i + 1][2] - points[i][2]) end
	return total
end
function Herd.alongRoute(points, s)
	if s <= 0 then
		local dx, dz = norm(points[2][1] - points[1][1], points[2][2] - points[1][2])
		return points[1][1] + dx * s, points[1][2] + dz * s, dx, dz, false
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local l = len(b[1] - a[1], b[2] - a[2])
		if s <= l then
			local dx, dz = norm(b[1] - a[1], b[2] - a[2])
			return a[1] + dx * s, a[2] + dz * s, dx, dz, false
		end
		s -= l
	end
	local a, b = points[#points - 1], points[#points]
	local dx, dz = norm(b[1] - a[1], b[2] - a[2])
	return b[1], b[2], dx, dz, true
end

-- One server step. ctx = {players = {{x, z, id}}, blockers, boundary(x, z) -> nx, nz, depth,
--   clampInside(x, z, margin), pods = {podId -> members}, speedScale, perches}.
function Herd.step(c, ctx, dt, now)
	if c.gone then return end
	if c.cinchedUntil and now < c.cinchedUntil then setState(c, "cinched", now); return end
	if c.dazedUntil and now < c.dazedUntil then setState(c, "dazed", now); c.speed = 0; return end
	if applyBoop(c, ctx, dt, now) then
		if c.state ~= "airborne" and c.state ~= "flying" then setState(c, "alert", now) end
		return
	end
	if c.alertUntil and now < c.alertUntil and c.state ~= "airborne" and c.state ~= "flying" then
		setState(c, "alert", now); c.speed = 0; return
	end
	local behavior = species[c.behavior or c.def.behavior] or species.clump
	behavior(c, ctx, dt, now)
	c.catchable = not Herd.UNCATCHABLE[c.state]
end

-- Bounds helpers for a bounds ring {{x, z}, ...}: boundary(x, z) -> inward unit
-- normal and depth inside (negative outside); clampInside keeps a margin.
function Herd.boundsTools(bounds)
	local function nearest(x, z)
		local bestD, bx, bz = math.huge, x, z
		local n = #bounds
		for i = 1, n do
			local a, b = bounds[i], bounds[i % n + 1]
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local l2 = dx * dx + dz * dz
			local u = if l2 == 0 then 0 else math.clamp(((x - a[1]) * dx + (z - a[2]) * dz) / l2, 0, 1)
			local px, pz = a[1] + dx * u, a[2] + dz * u
			local d = len(x - px, z - pz)
			if d < bestD then bestD, bx, bz = d, px, pz end
		end
		return bestD, bx, bz
	end
	local function inside(x, z)
		local result = false
		local n = #bounds
		for i = 1, n do
			local a, b = bounds[i], bounds[i % n + 1]
			if (a[2] > z) ~= (b[2] > z) and x < (b[1] - a[1]) * (z - a[2]) / (b[2] - a[2]) + a[1] then result = not result end
		end
		return result
	end
	local cx, cz = 0, 0
	for _, p in ipairs(bounds) do cx += p[1] / #bounds; cz += p[2] / #bounds end
	local function boundary(x, z)
		local d, px, pz = nearest(x, z)
		local isIn = inside(x, z)
		local nx, nz
		if d < 1e-4 then nx, nz = norm(cx - x, cz - z)
		elseif isIn then nx, nz = norm(x - px, z - pz)
		else nx, nz = norm(px - x, pz - z) end
		return nx, nz, if isIn then d else -d
	end
	local function clampInside(x, z, margin)
		local nx, nz, depth = boundary(x, z)
		if depth >= margin then return x, z end
		return x + nx * (margin - depth), z + nz * (margin - depth)
	end
	return boundary, clampInside, inside
end

Herd.species = species
return Herd
