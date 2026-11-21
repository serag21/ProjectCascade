-- Pod spawning and respawn from arena data (WP-06). Pure apart from the
-- injected `make(def, x, z, extras)` that turns a spawn into a creature record.
-- Rules (Design.Tuning.density): base live cap per arena, respawn after
-- podRespawnSeconds x 1/(0.6 + 0.4 x players), never within
-- podRespawnMinPlayerDistance of a player (a spare habitat is used instead), and
-- species pod sizes from the arena's pods list. Cubloom pods share one flock
-- record; Flutterwinks share the arena's perch flowers.
local Habitat = {}

local function len(x, z) return math.sqrt(x * x + z * z) end

-- arena: Design.Arenas[id]; creatures: Design.Creatures; density: Tuning.density.
function Habitat.new(arena, creatures, density, seed)
	local habitats = {}
	for _, h in ipairs(arena.habitats) do habitats[h.id] = h end
	local perches = {}
	for _, f in ipairs(arena.features) do
		if f.type == "perch_flower" then table.insert(perches, {id = f.id, x = f.x, z = f.z, h = f.h or 6}) end
	end
	local pods = {}
	for index, pod in ipairs(arena.pods) do
		table.insert(pods, {id = arena.id .. ":" .. index, species = pod.species, habitat = pod.habitat, count = pod.count,
			members = {}, respawnAt = nil, def = creatures.byId[pod.species]})
	end
	local spares = {}
	for _, id in ipairs(arena.spareHabitats or {}) do if habitats[id] then table.insert(spares, habitats[id]) end end
	return {arena = arena, habitats = habitats, spares = spares, perches = perches, pods = pods, density = density,
		state = seed or 12345, podMembers = {}}
end

local function rand(h)
	h.state = (h.state * 16807) % 2147483647
	return h.state / 2147483647
end
Habitat.rand = rand

local function alive(pod)
	local n = 0
	for _, m in ipairs(pod.members) do if not m.gone then n += 1 end end
	return n
end
Habitat.alive = alive

function Habitat.liveCount(h)
	local n = 0
	for _, pod in ipairs(h.pods) do n += alive(pod) end
	return n
end

local function clearOfPlayers(habitat, players, distance)
	for _, p in ipairs(players) do
		if len(p.x - habitat.x, p.z - habitat.z) < distance then return false end
	end
	return true
end

-- Respawn delay for a pod given the number of players in the arena.
function Habitat.delay(h, pod, players)
	local own = pod.def and pod.def.pod and pod.def.pod.respawnSeconds
	local lo, hi = h.density.podRespawnSeconds[1], h.density.podRespawnSeconds[2]
	local base = own or (lo + (hi - lo) * rand(h))
	return base / (0.6 + 0.4 * math.max(1, players))
end

-- Spawn one pod's members at its habitat (or a spare when a player is too close).
-- -> true when spawned.
function Habitat.spawnPod(h, pod, now, players, make)
	local home = h.habitats[pod.habitat]
	local minDistance = h.density.podRespawnMinPlayerDistance
	if not clearOfPlayers(home, players, minDistance) then
		home = nil
		for _, spare in ipairs(h.spares) do
			if clearOfPlayers(spare, players, minDistance) then home = spare; break end
		end
	end
	if not home then return false end
	if Habitat.liveCount(h) + pod.count > h.density.baseLiveCapPerArena then return false end
	table.clear(pod.members)
	local flock
	if pod.def.behavior == "flock" then
		flock = {members = {}, x = home.x, z = home.z, heading = rand(h) * math.pi * 2, seed = rand(h) * 20,
			home = {x = home.x, z = home.z, r = home.r}}
	end
	local spread = math.min(3, (home.r or 4) * 0.4)
	for slot = 1, pod.count do
		local a = slot * 2.4 + rand(h) * 0.6
		local r = if pod.count == 1 then 0 else spread * (0.6 + 0.4 * rand(h))
		local x, z = home.x + math.cos(a) * r, home.z + math.sin(a) * r
		local c = make(pod.def, x, z, {podId = pod.id, home = {x = home.x, z = home.z, r = home.r},
			flock = flock, slot = slot, perches = if pod.def.behavior == "percher" then h.perches else nil})
		table.insert(pod.members, c)
		if flock then table.insert(flock.members, c) end
	end
	h.podMembers[pod.id] = pod.members
	pod.respawnAt = nil
	pod.spawnedAt = now
	return true
end

function Habitat.seed(h, now, make)
	for _, pod in ipairs(h.pods) do Habitat.spawnPod(h, pod, now, {}, make) end
end

-- players: {{x, z}} in this arena. Schedules and performs respawns.
function Habitat.step(h, now, players, make)
	local spawned = 0
	for _, pod in ipairs(h.pods) do
		if alive(pod) == 0 then
			if pod.respawnAt == nil then
				pod.respawnAt = now + Habitat.delay(h, pod, #players)
			elseif now >= pod.respawnAt then
				if Habitat.spawnPod(h, pod, now, players, make) then
					spawned += 1
				else
					pod.respawnAt = now + 1 -- blocked (player nearby or cap): retry shortly
				end
			end
		end
	end
	return spawned
end

return Habitat
