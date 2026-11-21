-- Layered ground height per arena (WP-05). Pure and shared: the server carves
-- Terrain from GroundMap.surface, and both server and client build the same
-- 4-stud lookup grid from it, so creature heights, ribbon ground levels (g) and
-- the Terrain agree by construction. In Studio the server additionally samples
-- real raycasts against the grid once at start (World) and logs the deviation.
--
-- height(map, x, z, nearY) returns the ground of the layer under nearY. The
-- Meadow has one layer; two-layer places (the Canyon Arch, stage 2) add a layer
-- list per cell. Coordinates are arena-relative studs.
local GroundMap = {}

GroundMap.CELL = 4
GroundMap.WATER_DEPTH = 1.5 -- basin floor below the surrounding ground
GroundMap.WATER_LEVEL = -0.35 -- water surface (ankle deep)
GroundMap.RIM_SLOPE = 0.35 -- ground rise per stud outside the bounds ring
GroundMap.RIM_MAX = 9

local function smooth(t) -- 1 at the centre, 0 at the edge, zero slope at both ends
	t = math.clamp(t, 0, 1)
	return 0.5 * (1 + math.cos(math.pi * t))
end

local function segDist(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local l2 = dx * dx + dz * dz
	local u = if l2 == 0 then 0 else math.clamp(((px - ax) * dx + (pz - az) * dz) / l2, 0, 1)
	local qx, qz = ax + dx * u - px, az + dz * u - pz
	return math.sqrt(qx * qx + qz * qz)
end
GroundMap.segDist = segDist

-- Distance to a polyline of {x, z} pairs (open) or the bounds ring (closed).
function GroundMap.polylineDistance(points, x, z, closed)
	local best = math.huge
	local n = #points
	local last = if closed then n else n - 1
	for i = 1, last do
		local a, b = points[i], points[i % n + 1]
		local d = segDist(x, z, a[1], a[2], b[1], b[2])
		if d < best then best = d end
	end
	return best
end

local function inPolygon(poly, x, z)
	local inside = false
	local n = #poly
	for i = 1, n do
		local a, b = poly[i], poly[i % n + 1]
		if (a[2] > z) ~= (b[2] > z) and x < (b[1] - a[1]) * (z - a[2]) / (b[2] - a[2]) + a[1] then
			inside = not inside
		end
	end
	return inside
end
GroundMap.inPolygon = inPolygon

-- Water depth factor 0..1 at (x, z): 1 inside a pond/creek, easing over a 3.5-stud bank
-- (gentle enough for 4-stud Terrain voxels and for wading out).
function GroundMap.waterFactor(arena, x, z)
	local best = 0
	for _, f in ipairs(arena.features or {}) do
		if f.type == "water" and f.rx then
			local k = math.sqrt(((x - f.x) / f.rx) ^ 2 + ((z - f.z) / f.rz) ^ 2)
			local edge = (k - 1) * math.min(f.rx, f.rz) -- studs outside the ellipse (negative inside)
			best = math.max(best, math.clamp(1 - (edge + 1.5) / 3.5, 0, 1))
		elseif f.type == "water_band" and f.points then
			local d = GroundMap.polylineDistance(f.points, x, z, false) - (f.width or 6) / 2
			best = math.max(best, math.clamp(1 - (d + 1) / 3.5, 0, 1))
		end
	end
	return best
end

-- The analytic ground surface (top of the playable ground) at arena-relative x, z.
-- Visual-only sand trail from the spawn gate to the north bank ring (render reference).
GroundMap.TRAILS = {
	meadow = {{0, 70}, {0, 58}, {8, 49}, {2, 34}, {0, 16}, {0, 1}, {-3, -14}, {-6, -40}, {-2, -64}},
}

-- Gentle rolling noise (amplitude < 0.8 studs) so open ground is not a table top.
function GroundMap.roll(x, z)
	return 0.45 * math.sin(x * 0.06) * math.cos(z * 0.05) + 0.3 * math.sin((x + z) * 0.11)
end

function GroundMap.surface(arena, x, z)
	local y = if arena.id == "meadow" then GroundMap.roll(x, z) else 0
	for _, e in ipairs(arena.elevation or {}) do
		if e.type == "hill" then
			local d = math.sqrt((x - e.x) ^ 2 + (z - e.z) ^ 2)
			if d < e.r then y += e.y * smooth(d / e.r) end
		end
	end
	local water = GroundMap.waterFactor(arena, x, z)
	if water > 0 then y -= GroundMap.WATER_DEPTH * water end
	if arena.bounds and not inPolygon(arena.bounds, x, z) then
		local d = GroundMap.polylineDistance(arena.bounds, x, z, true)
		y = math.max(y, y + math.min(GroundMap.RIM_MAX, math.max(0, d - 3) * GroundMap.RIM_SLOPE))
	end
	return y
end

-- Build the lookup grid. `sampler(x, z)` defaults to the analytic surface.
function GroundMap.build(arena, sampler)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in ipairs(arena.bounds or {{-80, -80}, {80, -80}, {80, 80}, {-80, 80}}) do
		minX, maxX = math.min(minX, p[1]), math.max(maxX, p[1])
		minZ, maxZ = math.min(minZ, p[2]), math.max(maxZ, p[2])
	end
	local cell = GroundMap.CELL
	minX, minZ = math.floor((minX - 16) / cell) * cell, math.floor((minZ - 16) / cell) * cell
	maxX, maxZ = math.ceil((maxX + 16) / cell) * cell, math.ceil((maxZ + 16) / cell) * cell
	local nx, nz = (maxX - minX) / cell + 1, (maxZ - minZ) / cell + 1
	local heights = table.create(nx * nz)
	sampler = sampler or function(x, z) return GroundMap.surface(arena, x, z) end
	for j = 0, nz - 1 do
		for i = 0, nx - 1 do
			heights[j * nx + i + 1] = sampler(minX + i * cell, minZ + j * cell)
		end
	end
	return {id = arena.id, minX = minX, minZ = minZ, nx = nx, nz = nz, cell = cell, layers = {heights}, flat = false}
end

-- A flat map for legacy arenas (disc floors at y = 0).
function GroundMap.flat(id)
	return {id = id, flat = true, layers = {}}
end

local function layerHeight(map, heights, x, z)
	local cell = map.cell
	local fx = math.clamp((x - map.minX) / cell, 0, map.nx - 1)
	local fz = math.clamp((z - map.minZ) / cell, 0, map.nz - 1)
	local i0, j0 = math.floor(fx), math.floor(fz)
	local i1, j1 = math.min(i0 + 1, map.nx - 1), math.min(j0 + 1, map.nz - 1)
	local u, v = fx - i0, fz - j0
	local h00 = heights[j0 * map.nx + i0 + 1]
	local h10 = heights[j0 * map.nx + i1 + 1]
	local h01 = heights[j1 * map.nx + i0 + 1]
	local h11 = heights[j1 * map.nx + i1 + 1]
	return (h00 * (1 - u) + h10 * u) * (1 - v) + (h01 * (1 - u) + h11 * u) * v
end

-- Ground of the layer under nearY (the highest layer at or below nearY + 1.5);
-- with nearY nil, the lowest layer.
function GroundMap.height(map, x, z, nearY)
	if map == nil or map.flat then return 0 end
	local best
	for _, heights in ipairs(map.layers) do
		local h = layerHeight(map, heights, x, z)
		if nearY == nil then
			if best == nil or h < best then best = h end
		elseif h <= nearY + 1.5 and (best == nil or h > best) then
			best = h
		end
	end
	if best == nil then best = layerHeight(map, map.layers[1], x, z) end
	return best
end

-- Registry: one map per arena index, built lazily from the design data.
local registry = {}
function GroundMap.set(index, map) registry[index] = map end
function GroundMap.get(index) return registry[index] end

return GroundMap
