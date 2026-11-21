-- Server loop claims (WP-04): design/fable/10 section 5.
--
-- The client draws the ribbon from its own positions; the server never trusts
-- the drawing. It proves the claimed polygon against the path it observed
-- (positions that passed Rules.movement), then decides each catch from its own
-- creature history at the client's view clock. Techniques and scores come only
-- from server data. Pure apart from the injected clocks: everything Roblox-side
-- (sessions, creatures, feedback) stays in Main.
local LoopService = {}

local function finite(n) return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge end

-- ctx: {Loop, T (Loop.tuning), pathSeconds = 6, minStep = 2, rate = 3/s}
function LoopService.new(Loop, T, options)
	options = options or {}
	return {
		Loop = Loop, T = T,
		pathSeconds = options.pathSeconds or 6,
		minStep = options.minStep or 2,
		rate = options.rate or 3,
		snapSlack = options.snapSlack or 0.15,
		telemetry = {accepted = 0, rejected = 0, reasons = {}, deviations = {}},
	}
end

function LoopService.session()
	return {path = {}, ribbonStart = -math.huge, deferred = {}, sent = {}, lastBankRing = nil, deviations = {}}
end

-- Server-authorised discontinuity (teleport, respawn, round start): forget the
-- path so nothing before it can be claimed.
function LoopService.reset(svc, sess, now)
	table.clear(sess.path)
	table.clear(sess.deferred)
	sess.ribbonStart = now
	sess.lastBankRing = nil
end

-- Append an accepted position (arena-relative x, z; ground level g) at server time t.
-- Returns the previous sample (for bank-ring segment tests) when one was appended.
function LoopService.record(svc, sess, x, z, t, g)
	if not (finite(x) and finite(z) and finite(t)) then return nil end
	local path = sess.path
	local last = path[#path]
	if last and (x - last.x) ^ 2 + (z - last.z) ^ 2 < svc.minStep * svc.minStep then
		-- Standing still is continuous presence, not a hole: refresh the last sample's
		-- time so a pause before a ring never reads as a path gap (found in WP-06).
		if t - last.t >= 0.5 then last.t = t end
		return nil
	end
	table.insert(path, {x = x, z = z, t = t, g = g or 0})
	while #path > 1 and path[1].t < t - svc.pathSeconds do table.remove(path, 1) end
	return last
end

-- The live head: positions are only appended every 2 studs, so a claim whose
-- final vertex is the player's current position also gets the latest accepted
-- position as a provisional head (never stored).
function LoopService.pathWithHead(sess, head)
	if not head then return sess.path end
	local last = sess.path[#sess.path]
	if last and last.x == head.x and last.z == head.z then return sess.path end
	local copy = table.clone(sess.path)
	table.insert(copy, head)
	return copy
end

local function reject(svc, reason)
	svc.telemetry.rejected += 1
	svc.telemetry.reasons[reason] = (svc.telemetry.reasons[reason] or 0) + 1
	return nil, reason
end

-- Shape check and rate limit for an incoming claim. payload = {poly = buffer,
-- kind = "snap"|"cross", viewClock = number}. -> claim table, or nil + reason.
function LoopService.receive(svc, sess, payload, now, herdNow)
	if type(payload) ~= "table" then return reject(svc, "malformed") end
	local kind = payload.kind
	if kind ~= "snap" and kind ~= "cross" then return reject(svc, "malformed") end
	if not finite(payload.viewClock) or not finite(herdNow) then return reject(svc, "malformed") end
	local poly = svc.Loop.decode(payload.poly)
	if not poly then return reject(svc, "malformed") end
	local recent = 0
	for i = #sess.sent, 1, -1 do
		if now - sess.sent[i] < 1 then recent += 1 else table.remove(sess.sent, i) end
	end
	if recent >= svc.rate then return reject(svc, "rate-limited") end
	table.insert(sess.sent, now)
	-- viewClock is the only time the client sends; it is clamped to [herdNow - age, herdNow].
	local viewClock = math.min(herdNow, math.max(payload.viewClock, herdNow - svc.T.viewClockMaxAge))
	local claim = {poly = poly, kind = kind, viewClock = viewClock, arrivedAt = now, herdArrived = herdNow}
	table.insert(sess.deferred, claim)
	return claim
end

-- Deferral: hold a claim until the server path's newest sample is within
-- tolerance of the polygon's last vertex, at most claimDefer seconds.
function LoopService.ready(svc, sess, claim, now)
	if now - claim.arrivedAt >= svc.T.claimDefer then return true end
	local last = sess.path[#sess.path]
	local head = claim.poly[#claim.poly]
	return last ~= nil and (last.x - head.x) ^ 2 + (last.z - head.z) ^ 2 <= svc.T.tolerance ^ 2
end

-- Claims whose deferral is over, oldest first (removed from the queue).
function LoopService.due(svc, sess, now)
	local out = {}
	local keep = {}
	for _, claim in ipairs(sess.deferred) do
		if LoopService.ready(svc, sess, claim, now) then table.insert(out, claim) else table.insert(keep, claim) end
	end
	sess.deferred = keep
	return out
end

-- Validate against the server path. On success ribbonStart moves to now, so the
-- same stretch of path can never prove a second claim (replays fail).
-- -> ok, reason, serverArea, deviation
function LoopService.validate(svc, sess, claim, now, bounds, head)
	local ok, reason, serverArea, deviation = svc.Loop.validate(claim.poly, LoopService.pathWithHead(sess, head), now,
		sess.ribbonStart, svc.T, bounds)
	if not ok then
		reject(svc, reason)
		return false, reason
	end
	svc.telemetry.accepted += 1
	sess.ribbonStart = now
	table.insert(sess.deviations, deviation or 0)
	if #sess.deviations > 200 then table.remove(sess.deviations, 1) end
	table.insert(svc.telemetry.deviations, deviation or 0)
	if #svc.telemetry.deviations > 500 then table.remove(svc.telemetry.deviations, 1) end
	-- Ground level of each vertex comes from the server path, never the client.
	for _, p in ipairs(claim.poly) do
		local best, g = math.huge, 0
		for _, s in ipairs(sess.path) do
			local d = (s.x - p.x) ^ 2 + (s.z - p.z) ^ 2
			if d < best then best, g = d, s.g end
		end
		p.g = g
	end
	return true, "ok", serverArea, deviation
end

-- p99 of recorded claim deviations (largest vertex-to-path distance per accepted claim).
function LoopService.p99(list)
	if #list == 0 then return 0 end
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[math.max(1, math.ceil(#sorted * 0.99))]
end

-- Creature history (0.5 s at the 10 Hz snapshot ticks): {clock, x, z, g, catchable}.
function LoopService.pushHistory(history, clock, x, z, g, catchable, keep)
	table.insert(history, {clock = clock, x = x, z = z, g = g, catchable = catchable})
	keep = keep or 0.55
	while #history > 2 and history[1].clock < clock - keep do table.remove(history, 1) end
end

-- Resolve against candidate creatures ({id, history}); caught ids sorted into pop
-- order (farthest from the centroid first, nearest last).
function LoopService.resolve(svc, claim, candidates, herdNow)
	local caught, escaped = svc.Loop.resolve(claim.poly, candidates, claim.viewClock, herdNow, svc.T)
	local cx, cz = svc.Loop.centroid(claim.poly)
	local clock = math.min(herdNow, math.max(claim.viewClock, herdNow - svc.T.viewClockMaxAge))
	local byId = {}
	for _, c in ipairs(candidates) do byId[c.id] = c end
	local distance = {}
	for _, id in ipairs(caught) do
		local x, z = svc.Loop.sampleAt(byId[id].history, clock)
		distance[id] = (x - cx) ^ 2 + (z - cz) ^ 2
	end
	table.sort(caught, function(a, b)
		if distance[a] ~= distance[b] then return distance[a] > distance[b] end
		return a < b
	end)
	return caught, escaped
end

-- Contested catches (two loops over one creature): `recent` maps creature id ->
-- {by = userId, at = server time, biome, history}. Returns true when this claim's
-- polygon also held a creature another player caught within the last second;
-- that second claimant earns an ASSIST instead of nothing. Expired entries are pruned.
function LoopService.contested(svc, recent, claim, userId, biome, now, herdNow)
	local hit = false
	for id, entry in pairs(recent) do
		if now - entry.at > 1 then
			recent[id] = nil
		elseif not hit and entry.by ~= userId and entry.biome == biome then
			local inside = svc.Loop.resolve(claim.poly, {{id = id, history = entry.history}}, claim.viewClock, herdNow, svc.T)
			if #inside > 0 then hit = true end
		end
	end
	return hit
end

-- SNAP: the loop closed within snapWindow (+ slack) of a dash start, both measured
-- by server arrival time (same latency, so the interval is preserved).
function LoopService.snap(svc, dashAt, claim)
	if not dashAt then return false end
	local gap = claim.arrivedAt - dashAt
	return gap >= -0.05 and gap <= svc.T.snapWindow + svc.snapSlack
end

-- Bank rings: did the path segment a->b pass within r of a ring centre?
function LoopService.crossesRing(ax, az, bx, bz, ring)
	local dx, dz = bx - ax, bz - az
	local l2 = dx * dx + dz * dz
	local u = if l2 == 0 then 0 else math.clamp(((ring.x - ax) * dx + (ring.z - az) * dz) / l2, 0, 1)
	local qx, qz = ax + dx * u - ring.x, az + dz * u - ring.z
	return qx * qx + qz * qz <= (ring.r or 5) ^ 2
end

return LoopService
