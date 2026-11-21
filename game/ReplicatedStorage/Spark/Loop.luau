-- Ribbon loops: closure, containment, server validation, lag-compensated
-- resolution and loop scoring. A function-for-function port of
-- design/fable/tools/loop_reference.py (the spec); data/test_vectors.json is
-- asserted against this module by tests/SparkLoop.spec.luau. Pure: no Roblox
-- globals, shared by the client (prediction, payout preview) and the server.
--
-- Ribbon point:   {x, z, t, d, g}  (time, cumulative path distance, ground level)
-- Polygon vertex: {x, z, g}
-- Server sample:  {x, z, t, g}
-- History sample: {clock, x, z, g, catchable}
-- Tuning (T): the flat table from Loop.tuning(Design.Tuning).
local Loop = {}

-- Flatten the generated design tuning into the reference's T table. Optional
-- overrides (Studio-only F9 panel) replace individual keys for this session.
function Loop.tuning(design, overrides)
	local r, s, p = design.ribbon, design.scoring, design.parade
	local T = {
		lifetime = r.lifetime, maxLength = r.maxLength, spacing = r.sampleSpacing, snapRadius = r.snapRadius,
		snapMinPath = r.snapMinPathDistance, minPerimeter = r.minPerimeter, minArea = r.minArea,
		maxVertices = r.maxVertices, tolerance = r.serverPathTolerance, inflate = r.captureInflate,
		layerTolerance = r.layerTolerance, viewClockMaxAge = r.viewClockMaxAge, pathGapMax = r.pathGapMax,
		claimDefer = r.claimDeferSeconds, resultTimeout = r.resultTimeout,
		sizeMult = s.sizeMultiplier, techBonus = s.techBonusEach, chainTiers = s.chainTiers,
		chainWindow = s.chainWindow, chainWindowPer = s.chainWindowPerCreature, chainWindowMax = s.chainWindowMax,
		chainLinks = s.chainLinks, tightBase = s.tightAreaBase, tightPer = s.tightAreaPerCreature,
		finaleMult = s.finaleMultiplier, snapWindow = s.snapWindow,
		bankTiers = p.bankMultiplier, capacity = p.capacity, overflowScale = p.overflowScoreScale,
	}
	local maxKey = 0
	for k in pairs(T.sizeMult) do if type(k) == "number" and k > maxKey then maxKey = k end end
	T.sizeMultMax = maxKey
	if overrides then for k, v in pairs(overrides) do T[k] = v end end
	return T
end

local function hypot(dx, dz) return math.sqrt(dx * dx + dz * dz) end
local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end

---------------------------------------------------------------- ribbon
function Loop.new() return {} end

-- Append when >= spacing from the last sample; expire by lifetime and by length.
function Loop.push(ribbon, x, z, t, T, g)
	g = g or 0
	local added
	local n = #ribbon
	if n > 0 then
		local last = ribbon[n]
		local step = hypot(x - last.x, z - last.z)
		if step < T.spacing then
			added = false
		else
			table.insert(ribbon, {x = x, z = z, t = t, d = last.d + step, g = g}); added = true
		end
	else
		table.insert(ribbon, {x = x, z = z, t = t, d = 0, g = g}); added = true
	end
	while #ribbon > 1 and (ribbon[1].t < t - T.lifetime or ribbon[#ribbon].d - ribbon[1].d > T.maxLength) do
		table.remove(ribbon, 1)
	end
	return added
end

-- Ribbon cut: forget every point at or before fromTime.
function Loop.truncate(ribbon, fromTime)
	local kept = {}
	for _, p in ipairs(ribbon) do if p.t > fromTime then table.insert(kept, p) end end
	table.clear(ribbon)
	for i, p in ipairs(kept) do ribbon[i] = p end
end

-- Proper intersection of segments ab and cd -> u along ab, ix, iz (or nil).
local function segIntersect(ax, az, bx, bz, cx, cz, dx, dz)
	local rx, rz = bx - ax, bz - az
	local sx, sz = dx - cx, dz - cz
	local den = rx * sz - rz * sx
	if math.abs(den) < 1e-9 then return nil end
	local qx, qz = cx - ax, cz - az
	local u = (qx * sz - qz * sx) / den
	local w = (qx * rz - qz * rx) / den
	if u >= 0 and u <= 1 and w >= 0 and w <= 1 then return u, ax + rx * u, az + rz * u end
	return nil
end

local function segDist(px, pz, a, b)
	local dx, dz = b.x - a.x, b.z - a.z
	local l2 = dx * dx + dz * dz
	local u = if l2 == 0 then 0 else math.max(0, math.min(1, ((px - a.x) * dx + (pz - a.z) * dz) / l2))
	return hypot(px - (a.x + dx * u), pz - (a.z + dz * u)), u
end
Loop.segDist = segDist

function Loop.area(poly)
	local n, sum = #poly, 0
	for i = 1, n do
		local a, b = poly[i], poly[i % n + 1]
		sum += a.x * b.z - b.x * a.z
	end
	return math.abs(sum) / 2
end

function Loop.perimeter(poly)
	local n, sum = #poly, 0
	for i = 1, n do
		local a, b = poly[i], poly[i % n + 1]
		sum += hypot(b.x - a.x, b.z - a.z)
	end
	return sum
end

function Loop.centroid(poly)
	local sx, sz = 0, 0
	for _, p in ipairs(poly) do sx += p.x; sz += p.z end
	return sx / #poly, sz / #poly
end

local function resample(poly, n)
	local count = #poly
	if count <= n then return poly end
	local out = {}
	for i = 0, n - 1 do out[i + 1] = poly[math.floor(i * count / n) + 1] end
	return out
end

local function vertex(p) return {x = p.x, z = p.z, g = p.g} end

-- -> polygon, kind ("snap" | "cross") or nil, reason. Does not mutate the ribbon.
-- head = the player's CURRENT position {x, z, t, g}; it need not be a stored sample.
-- Snap is tested first against ribbon SEGMENTS; a true crossing is the fallback for
-- a head that jumped over the ribbon between frames. Only ribbon at least
-- snapMinPath back along the path can close.
function Loop.tryClose(ribbon, T, head)
	local n = #ribbon
	if n < 2 then return nil, "short" end
	local last = ribbon[n]
	head = head or last
	local stored = head.x == last.x and head.z == last.z
	local prev = if stored then ribbon[n - 1] else last
	local headD = last.d + hypot(head.x - last.x, head.z - last.z)
	local hg = if head.g ~= nil then head.g else last.g
	local poly, kind
	local bestU, bestX, bestZ, bestI
	for i = 1, n - 1 do
		if headD - ribbon[i + 1].d < T.snapMinPath then break end
		local u, ix, iz = segIntersect(prev.x, prev.z, head.x, head.z, ribbon[i].x, ribbon[i].z, ribbon[i + 1].x, ribbon[i + 1].z)
		if u and (bestU == nil or u < bestU) then bestU, bestX, bestZ, bestI = u, ix, iz, i end
	end
	if bestU then
		poly = {{x = bestX, z = bestZ, g = ribbon[bestI + 1].g}}
		local stop = if stored then n - 1 else n
		for j = bestI + 1, stop do table.insert(poly, vertex(ribbon[j])) end
		kind = "cross"
	else
		local nearD, nearI, nearU
		for i = 1, n - 1 do
			if headD - ribbon[i + 1].d < T.snapMinPath then break end
			local dist, u = segDist(head.x, head.z, ribbon[i], ribbon[i + 1])
			if dist <= T.snapRadius and (nearD == nil or dist <= nearD) then nearD, nearI, nearU = dist, i, u end
		end
		if nearD == nil then return nil, "open" end
		local a, b = ribbon[nearI], ribbon[nearI + 1]
		poly = {{x = a.x + (b.x - a.x) * nearU, z = a.z + (b.z - a.z) * nearU, g = a.g}}
		for j = nearI + 1, n do table.insert(poly, vertex(ribbon[j])) end
		if not stored then table.insert(poly, {x = head.x, z = head.z, g = hg}) end
		kind = "snap"
	end
	poly = resample(poly, T.maxVertices)
	if #poly < 3 then return nil, "short" end
	if Loop.perimeter(poly) < T.minPerimeter then return nil, "perimeter" end
	if Loop.area(poly) < T.minArea then return nil, "area" end
	return poly, kind
end

-- Snap preview: the nearest closable ribbon point within `radius` of the head.
-- -> x, z, distance (or nil). Same eligibility rule as tryClose's snap.
function Loop.snapPoint(ribbon, T, head, radius)
	local n = #ribbon
	if n < 2 then return nil end
	local last = ribbon[n]
	local headD = last.d + hypot(head.x - last.x, head.z - last.z)
	local nearD, nearX, nearZ
	for i = 1, n - 1 do
		if headD - ribbon[i + 1].d < T.snapMinPath then break end
		local a, b = ribbon[i], ribbon[i + 1]
		local dist, u = segDist(head.x, head.z, a, b)
		if dist <= radius and (nearD == nil or dist <= nearD) then
			nearD, nearX, nearZ = dist, a.x + (b.x - a.x) * u, a.z + (b.z - a.z) * u
		end
	end
	if nearD == nil then return nil end
	return nearX, nearZ, nearD
end

-- Stage 2 (WP-13): pinch-wall closure. Stub until then.
function Loop.tryPinch(_ribbon, _walls, _T) return nil, nil end

---------------------------------------------------------------- containment
-- Non-zero winding: a point enclosed by ANY turn of the ribbon is inside.
local function pip(x, z, poly)
	local wn, n = 0, #poly
	for i = 1, n do
		local a, b = poly[i], poly[i % n + 1]
		local x1, z1, x2, z2 = a.x, a.z, b.x, b.z
		local side = (x2 - x1) * (z - z1) - (x - x1) * (z2 - z1)
		if z1 <= z then
			if z2 > z and side > 0 then wn += 1 end
		elseif z2 <= z and side < 0 then
			wn -= 1
		end
	end
	return wn ~= 0
end

function Loop.edgeDistance(x, z, poly)
	local best = math.huge
	local n = #poly
	for i = 1, n do
		local d = segDist(x, z, poly[i], poly[i % n + 1])
		if d < best then best = d end
	end
	return best
end

function Loop.contains(poly, x, z, inflate)
	inflate = inflate or 0
	return pip(x, z, poly) or (inflate > 0 and Loop.edgeDistance(x, z, poly) <= inflate)
end

-- Height rule: the creature's ground level against the nearest polygon vertex's.
function Loop.layerOk(poly, x, z, g, T)
	local nearest, best = nil, math.huge
	for _, p in ipairs(poly) do
		local d = (p.x - x) ^ 2 + (p.z - z) ^ 2
		if d < best then best, nearest = d, p end
	end
	return math.abs((nearest.g or 0) - g) <= T.layerTolerance
end

-- Stage 2 stubs (Starwhirl coverage, ribbon cuts).
function Loop.enclosedFraction(_ribbon, _x, _z) return 0 end
function Loop.nearestSegment(_ribbon, _x, _z) return nil, math.huge end

---------------------------------------------------------------- server validation
local function roundTo(value, places)
	local m = 10 ^ places
	return math.floor(value * m + 0.5) / m
end

-- bounds: arena bounds ring as {{x, z}, ...} (the arena JSON form) or nil.
-- -> ok, reason, serverArea (area of the SERVER's own path between the matched
-- times, closed; TIGHT is decided from it, never from the client polygon).
function Loop.validate(poly, path, now, ribbonStart, T, bounds)
	local n = #poly
	if n < 3 or n > T.maxVertices then return false, "vertex-count", nil end
	local boundsPoly
	if bounds then
		boundsPoly = {}
		for i, b in ipairs(bounds) do boundsPoly[i] = {x = b[1] or b.x, z = b[2] or b.z} end
	end
	for _, p in ipairs(poly) do
		if not finite(p.x) or not finite(p.z) then return false, "not-finite", nil end
		if boundsPoly and not pip(p.x, p.z, boundsPoly) then return false, "out-of-bounds", nil end
	end
	local per = Loop.perimeter(poly)
	if per < T.minPerimeter then return false, "perimeter-small", nil end
	if per > T.maxLength + T.snapRadius + 6 then return false, "perimeter-large", nil end
	if Loop.area(poly) < T.minArea then return false, "area-small", nil end
	local oldest = math.max(ribbonStart, now - T.lifetime - 0.6)
	local recent = {}
	for _, s in ipairs(path) do if s.t >= oldest then table.insert(recent, s) end end
	if #recent < 2 then return false, "no-path", nil end
	for i = 1, #recent - 1 do
		if recent[i + 1].t - recent[i].t > T.pathGapMax then return false, "path-gap", nil end
	end
	local last = recent[#recent]
	if hypot(poly[n].x - last.x, poly[n].z - last.z) > T.tolerance then return false, "head-not-reached", nil end
	local lo, hi, worst = math.huge, -math.huge, 0
	for _, p in ipairs(poly) do
		local bestD, bestT
		for i = 1, #recent - 1 do
			local a, b = recent[i], recent[i + 1]
			local dist, u = segDist(p.x, p.z, a, b)
			if bestD == nil or dist < bestD then bestD, bestT = dist, a.t + (b.t - a.t) * u end
		end
		if bestD > T.tolerance then return false, "off-path", nil end
		if bestD > worst then worst = bestD end
		if bestT < lo then lo = bestT end
		if bestT > hi then hi = bestT end
	end
	local proof = {}
	for _, s in ipairs(recent) do
		if lo <= s.t and s.t <= hi then
			if Loop.edgeDistance(s.x, s.z, poly) > T.tolerance then return false, "path-leaves-polygon", nil end
			table.insert(proof, s)
		end
	end
	local serverArea = if #proof >= 3 then roundTo(Loop.area(proof), 1) else nil
	return true, "ok", serverArea, worst
end

-- creatures: {{id, history = {{clock, x, z, g, catchable}, ...}}}. Evaluated at the
-- claim's view clock clamped to [now - viewClockMaxAge, now]. -> caught, escaped.
function Loop.sampleAt(history, clock)
	local a, b
	for _, s in ipairs(history) do
		if s.clock <= clock then a = s elseif b == nil then b = s end
	end
	local hadBefore = a ~= nil
	a = a or history[1]
	if b and hadBefore and b.clock > a.clock then
		local u = (clock - a.clock) / (b.clock - a.clock)
		return a.x + (b.x - a.x) * u, a.z + (b.z - a.z) * u, a.g, a.catchable
	end
	return a.x, a.z, a.g, a.catchable
end

function Loop.resolve(poly, creatures, viewClock, now, T)
	local clock = math.min(now, math.max(viewClock, now - T.viewClockMaxAge))
	local caught, escaped = {}, {}
	for _, c in ipairs(creatures) do
		local h = c.history
		if h and #h > 0 then
			local x, z, g, catchable = Loop.sampleAt(h, clock)
			if Loop.contains(poly, x, z, T.inflate) and Loop.layerOk(poly, x, z, g, T) then
				table.insert(if catchable then caught else escaped, c.id)
			end
		end
	end
	return caught, escaped
end

---------------------------------------------------------------- scoring
function Loop.sizeMult(n, T)
	return T.sizeMult[math.min(n, T.sizeMultMax)]
end

function Loop.chainLinks(n, T)
	local tiers = T.chainLinks
	for i = #tiers, 1, -1 do
		if n >= tiers[i][1] then return n + tiers[i][2] end
	end
	return n
end

-- Seconds the chain survives after a loop that caught n (n = 1 for a bank or a wrap).
function Loop.chainWindow(n, T)
	return math.min(T.chainWindowMax, T.chainWindow + T.chainWindowPer * math.max(0, n - 1))
end

function Loop.chainMult(links, T)
	local m = 1
	for _, tier in ipairs(T.chainTiers) do
		if links >= tier[1] then m = tier[2] end
	end
	return m
end

function Loop.isTight(n, loopArea, T, soloTightArea)
	if n >= 2 then return loopArea ~= nil and loopArea <= T.tightBase + T.tightPer * n end
	return soloTightArea ~= nil and loopArea ~= nil and loopArea <= soloTightArea
end

-- values: base values in pop order; techs: count or list of technique names.
-- The chain multiplier uses the links AFTER this loop. Creatures beyond parade
-- capacity score at overflowScale and are released.
function Loop.scoreLoop(values, techs, linksBefore, T, finale, carried)
	local n = #values
	if n == 0 then
		return {points = 0, links = linksBefore, multiplier = Loop.chainMult(linksBefore, T), kept = 0, overflow = 0}
	end
	local techCount = if type(techs) == "number" then techs else #techs
	local links = linksBefore + Loop.chainLinks(n, T)
	local mult = Loop.chainMult(links, T)
	local room = math.max(0, T.capacity - (carried or 0))
	local kept = math.min(n, room)
	local base = 0
	for i = 1, n do base += if i <= kept then values[i] else T.overflowScale * values[i] end
	local pts = base * Loop.sizeMult(n, T) * (1 + T.techBonus * techCount) * mult * (if finale then T.finaleMult else 1)
	return {points = math.floor(pts + 0.5), links = links, multiplier = mult, kept = kept, overflow = n - kept}
end

function Loop.bankPoints(values, T)
	local n, m, sum = #values, 1.0, 0
	for _, tier in ipairs(T.bankTiers) do
		if n >= tier[1] then m = tier[2] end
	end
	for _, v in ipairs(values) do sum += v end
	return math.floor(sum * m + 0.5), m
end

---------------------------------------------------------------- wire format
-- u8 count + count x (i16 x*10, i16 z*10), arena-relative. g is never sent.
local MAX_WIRE = 64
function Loop.encode(poly)
	local n = math.min(#poly, MAX_WIRE)
	local b = buffer.create(1 + 4 * n)
	buffer.writeu8(b, 0, n)
	for i = 1, n do
		local x = math.clamp(math.floor(poly[i].x * 10 + 0.5), -32768, 32767)
		local z = math.clamp(math.floor(poly[i].z * 10 + 0.5), -32768, 32767)
		buffer.writei16(b, 1 + (i - 1) * 4, x)
		buffer.writei16(b, 3 + (i - 1) * 4, z)
	end
	return b
end

function Loop.decode(b)
	if type(b) ~= "buffer" then return nil end
	local len = buffer.len(b)
	if len < 1 or len > 1 + 4 * MAX_WIRE then return nil end
	local n = buffer.readu8(b, 0)
	if len ~= 1 + 4 * n then return nil end
	local poly = table.create(n)
	for i = 1, n do
		poly[i] = {x = buffer.readi16(b, 1 + (i - 1) * 4) / 10, z = buffer.readi16(b, 3 + (i - 1) * 4) / 10}
	end
	return poly
end

return Loop
