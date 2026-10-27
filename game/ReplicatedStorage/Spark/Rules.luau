-- Pure authority rules shared by the server and offline adversarial tests.
local Rules = {}

function Rules.finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end

function Rules.distance(a, b)
	if not Rules.validPosition(a) or not Rules.validPosition(b) then return math.huge end
	local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(x*x + y*y + z*z)
end

function Rules.validPosition(position)
	return type(position)=="table" and Rules.finite(position.x) and Rules.finite(position.y) and Rules.finite(position.z)
end

-- Consumes a single accumulated displacement budget shared by heartbeat and actions.
-- Burst credit is bounded; calling more frequently never grants more travel distance.
-- Only server-authorized teleports may reset this state.
function Rules.movement(state, position, now, limits)
	if not Rules.finite(now) or not Rules.validPosition(position) or not Rules.validPosition(state.position) then
		if Rules.finite(now) then state.blockedUntil=now+1.5 end
		return false, "Invalid position"
	end
	local elapsed=math.clamp(now-state.at,0,0.75)
	local start=now-elapsed
	local dashTime=if state.dashStarted and state.dashUntil then math.max(0,math.min(now,state.dashUntil)-math.max(start,state.dashStarted)) else 0
	local refill=limits.speed*elapsed+math.max(0,65-limits.speed)*dashTime
	state.credit=math.min(limits.burst or 10,(state.credit or 0)+refill)
	state.at=now
	local dx,dz=position.x-limits.origin.x,position.z-limits.origin.z
	local reason
	if dx*dx+dz*dz > limits.radius*limits.radius then reason="Arena bounds"
	elseif position.y < limits.minY or position.y > limits.maxY then reason="Height bounds"
	else
		local x,z=position.x-state.position.x,position.z-state.position.z
		local distance=math.sqrt(x*x+z*z)
		if distance>state.credit+0.001 then reason="Implausible approach"
		else state.credit=math.max(0,state.credit-distance) end
	end
	if reason then state.blockedUntil=now+1.5; return false,reason end
	state.position={x=position.x,y=position.y,z=position.z}
	return true, "Accepted"
end

function Rules.allow(bucket, key, now, interval)
	if not Rules.finite(now) then return false end
	local previous = bucket[key]
	if previous and now - previous < interval then return false end
	bucket[key] = now
	return true
end

-- One finite onboarding allocation per loaded session. Replay never resets it;
-- persistent totalBanked prevents returning players from renewing free catches.
function Rules.issueStarters(session, totalBanked)
	if session.starterIssued then return 0 end
	session.starterIssued=true
	if not Rules.finite(totalBanked) or totalBanked<0 then return 0 end
	return math.max(0,3-math.floor(totalBanked))
end

function Rules.herdSpawn(angle, radius)
	return {x=math.cos(angle)*radius,y=2.2,z=math.min(12,math.sin(angle)*radius)}
end

-- Ordinary creatures stay beyond bank reach even with a fully upgraded magnet.
-- Starter creatures use separate finite home circles and do not call this helper.
function Rules.outsideBank(position, bank)
	local dx,dz=position.x-bank.x,position.z-bank.z
	local distance=math.sqrt(dx*dx+dz*dz)
	if distance>=28 then return position end
	-- Re-enter toward the infield, also clear of the southern steering islands.
	return {x=position.x,y=position.y,z=bank.z-28}
end

function Rules.canCapture(player, creature, now, radius, capacity)
	if player.phase ~= "Playing" or player.ready ~= true then return false, "Not playing" end
	if player.carry >= capacity then return false, "Bank your parade first" end
	if creature.claimed then return false, "Already caught" end
	if creature.starterOwner~=nil then
		if creature.starterOwner~=player.userId then return false, "Another player's first catch" end
		if not Rules.finite(player.totalBanked) or player.totalBanked>=3 then return false, "Starter allowance complete" end
	end
	if player.biome ~= creature.biome then return false, "Different arena" end
	if not Rules.finite(now) or not Rules.finite(radius) or radius <= 0 then return false, "Invalid" end
	if player.suspiciousUntil and now < player.suspiciousUntil then return false, "Movement settling" end
	local distance = Rules.distance(player.position, creature.position)
	if not Rules.finite(distance) or distance > radius then return false, "Move closer" end
	return true, "Caught"
end

function Rules.event(elapsed)
	if elapsed >= 85 then return "GOLDEN HOUR", 1.2 end
	if elapsed >= 55 then return "TAILWIND", 1.4 end
	if elapsed >= 25 then return "HERD PARADE", 0.8 end
	return "WARM UP", 0.65
end

function Rules.roundPhase(started, now, duration)
	local remaining = math.max(0, math.ceil(duration - math.max(0, now-started)))
	return if remaining == 0 then "Results" else "Playing", remaining
end

return Rules
