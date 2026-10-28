-- Pure round mastery scoring. Call only after server capture ownership/range checks.
-- Skill score is separate from glow/collection: mistakes never remove saved progress.
local Challenge = {}
-- Main enforces .65s. Leave a small timing margin here because its authorization
-- and this score transaction are sampled at different instants on the server.
local CHAIN_SECONDS, CAPTURE_INTERVAL, MAX_SCORE = 6, 0.60, 1000000
local goals = {
	{id="precision", name="Close Call", description="Face Sparks and catch within 4 studs", target=3},
	{id="chain", name="Keep the Rhythm", description="Catch within 6 seconds of each other", target=6},
	{id="haul", name="Bring the Parade", description="Bank a group of ordinary Sparks", target=3},
}
local function finite(n)
	return type(n)=="number" and n==n and math.abs(n)<math.huge
end
local function clockValid(state, now)
	return finite(now) and now>=0 and now>=state.lastEvent
end
local function activeChain(state, now)
	if not state.lastCatch or now-state.lastCatch>CHAIN_SECONDS then return 0 end
	return state.chain
end
local function multiplier(chain)
	return math.min(3,1+math.floor(math.max(0,chain-1)/3))
end
local function progress(state)
	if state.goal.id=="precision" then return state.precision end
	if state.goal.id=="chain" then return state.bestChain end
	return state.bestHaul
end
local function medal(score)
	if score>=800 then return "Gold" elseif score>=400 then return "Silver" elseif score>=150 then return "Bronze" end
	return "Unranked"
end

function Challenge.new(roundIndex)
	local index=if finite(roundIndex) then math.clamp(math.floor(roundIndex),1,1000000) else 1
	local difficulty=math.min(3,1+math.floor((index-1)/3))
	local goal=goals[(index-1)%#goals+1]
	return {roundIndex=index,difficulty=difficulty,
		goal={id=goal.id,name=goal.name,description=goal.description,target=goal.target+difficulty-1},
		score=0,pendingBase=0,pendingBonus=0,pendingCount=0,chain=0,bestChain=0,bestHaul=0,
		precision=0,dashCatches=0,captures=0,misses=0,lostBonus=0,lastEvent=0,lastCatch=nil,
		lastCapture=nil,seen={},goalComplete=false,finished=false}
end

-- Telegraph before each short sweep. One bounded hazard per player; never near
-- the bank/spawn. Client draws this server-computed position, not a hit decision.
function Challenge.hazard(elapsed,difficulty)
	if not finite(elapsed) or elapsed<25 then return {visible=false,active=false} end
	local tier=if finite(difficulty) then math.clamp(difficulty,1,3) else 1
	local cycle=(elapsed-25)%14
	if cycle>=6 then return {visible=false,active=false} end
	local angle=(elapsed-25)*(0.14+tier*.03)
	return {visible=true,active=cycle>=2,warning=cycle<2,
		x=math.cos(angle)*18,z=math.sin(angle)*18,radius=3.5,
		seconds=if cycle<2 then 2-cycle else 6-cycle}
end

function Challenge.snapshot(state, now)
	local at=if finite(now) then math.max(now,state.lastEvent) else state.lastEvent
	local chain=if state.finished then 0 else activeChain(state,at)
	return {score=state.score,pending=state.pendingBase+state.pendingBonus,
		pendingBonus=state.pendingBonus,chain=chain,multiplier=multiplier(chain),
		chainSeconds=if chain>0 then math.max(0,CHAIN_SECONDS-(at-state.lastCatch)) else 0,
		precision=state.precision,dashCatches=state.dashCatches,bestChain=state.bestChain,
		bestHaul=state.bestHaul,captures=state.captures,misses=state.misses,lostBonus=state.lostBonus,
		medal=medal(state.score),difficulty=state.difficulty,finished=state.finished,
		challenge={id=state.goal.id,name=state.goal.name,description=state.goal.description,
			target=state.goal.target,progress=math.min(state.goal.target,progress(state)),complete=state.goalComplete}}
end

function Challenge.capture(state, now, catch)
	if state.finished then return false,"Round finished" end
	if not clockValid(state,now) or type(catch)~="table" then return false,"Invalid capture" end
	if not finite(catch.distance) or catch.distance<0 or catch.distance>64
		or not finite(catch.facing) or catch.facing < -1 or catch.facing > 1
		or not finite(catch.value) or catch.value<0 or catch.value>100
		or (catch.dashAge~=nil and (not finite(catch.dashAge) or catch.dashAge<0))
		or type(catch.starter)~="boolean" then return false,"Invalid capture" end
	local id=catch.captureId
	if id~=nil then
		local validId=(type(id)=="string" and #id>0 and #id<=64)
			or (finite(id) and id>=0 and id%1==0)
		if not validId then return false,"Invalid capture ID" end
		if state.seen[id] then return false,"Duplicate capture" end
	end
	if state.lastCapture and now-state.lastCapture+0.000001<CAPTURE_INTERVAL then return false,"Capture too soon" end
	-- Maximum is above any 110s round at the minimum capture interval, bounding memory.
	if state.captures>=512 then return false,"Round capture limit" end
	state.lastEvent=now; state.lastCapture=now
	if id~=nil then state.seen[id]=true end
	if catch.starter then
		return true,{points=0,precision=false,dash=false,chain=activeChain(state,now),multiplier=1,starter=true}
	end
	state.chain=activeChain(state,now)+1; state.lastCatch=now
	state.bestChain=math.max(state.bestChain,state.chain)
	state.captures+=1; state.pendingCount+=1
	local precise=catch.distance<=4 and catch.facing>=0.7
	local dash=catch.dashAge~=nil and catch.dashAge<=0.55
	if precise then state.precision+=1 end
	if dash then state.dashCatches+=1 end
	local base=10+math.floor(catch.value)*2
	local factor=multiplier(state.chain)
	local bonus=(base+(if precise then 15 else 0)+(if dash then 20 else 0))*factor-base
	state.pendingBase=math.min(MAX_SCORE,state.pendingBase+base)
	state.pendingBonus=math.min(MAX_SCORE,state.pendingBonus+bonus)
	return true,{points=base+bonus,precision=precise,dash=dash,chain=state.chain,multiplier=factor,starter=false}
end

-- A miss/hazard loses only the current unbanked skill bonus. Catch base points,
-- banked score, glow and collection remain intact; next catch immediately recovers.
function Challenge.miss(state, now, _reason)
	if state.finished or not clockValid(state,now) then return false,0 end
	state.lastEvent=now; state.chain=0; state.lastCatch=nil
	local lost=state.pendingBonus
	state.pendingBonus=0; state.lostBonus=math.min(MAX_SCORE,state.lostBonus+lost)
	state.misses=math.min(1000000,state.misses+1)
	return true,lost
end

function Challenge.bank(state, now)
	if state.finished or not clockValid(state,now) then return 0 end
	state.lastEvent=now
	if state.pendingCount==0 then return 0 end
	state.bestHaul=math.max(state.bestHaul,state.pendingCount)
	local points=state.pendingBase+state.pendingBonus
	if not state.goalComplete and progress(state)>=state.goal.target then
		state.goalComplete=true; points+=100
	end
	local applied=math.min(points,MAX_SCORE-state.score)
	state.score+=applied; state.pendingBase=0; state.pendingBonus=0; state.pendingCount=0
	return applied
end

-- Call after the server's round-end auto-bank. Never accepts client score totals.
function Challenge.finish(state, now)
	if state.finished then return Challenge.snapshot(state,now) end
	if not clockValid(state,now) then return Challenge.snapshot(state) end
	Challenge.bank(state,now)
	state.finished=true; state.chain=0; state.lastCatch=nil
	return Challenge.snapshot(state,now)
end

return Challenge
