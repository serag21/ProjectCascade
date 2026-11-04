-- Pure round mastery scoring. Call only after server capture ownership/range checks.
-- Skill score is separate from glow/collection: mistakes never remove saved progress.
local Challenge = {}
-- Main enforces .65s. Leave a small timing margin here because its authorization
-- and this score transaction are sampled at different instants on the server.
local CHAIN_SECONDS, CAPTURE_INTERVAL, MAX_SCORE = 6, 0.60, 1000000
local CHECKPOINTS={22,44,66,88,110}
local SAMPLE_TOLERANCE=.5
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
-- Legacy defaults keep pure-module callers stable. Main always passes
-- Loadout.stats(...) so live rounds use perks, heat, haul and the x4 tier.
local DEFAULT_RULES={chainSeconds=CHAIN_SECONDS,maxMultiplier=3,precisionFacing=0.7,haulCap=1,
	scoreMultiplier=1,dashBonus=20,popPoints=40,herdMultiplier=1,goldenMultiplier=1,finaleFactor=1.25,chainStep=3,
	medals={Bronze=150,Silver=400,Gold=800,Radiant=1400}}
local HAUL_STEP,MULTI_BONUS,HERD_BONUS,ASSIST_BONUS,GOLDEN_BONUS=0.05,25,40,30,250
local function rulesFrom(raw)
	local rules=table.clone(DEFAULT_RULES)
	if type(raw)~="table" then return rules end
	local function pick(key,low,high)
		local value=raw[key]
		if type(value)=="number" and value==value and value>=low and value<=high then rules[key]=value end
	end
	pick("chainSeconds",2,12); pick("maxMultiplier",1,4); pick("precisionFacing",0,1)
	pick("haulCap",1,2); pick("scoreMultiplier",1,3); pick("dashBonus",0,40); pick("popPoints",0,120)
	pick("herdMultiplier",1,3); pick("goldenMultiplier",1,3); pick("chainStep",2,8)
	if type(raw.medals)=="table" then
		local m=raw.medals
		if type(m.Bronze)=="number" and type(m.Silver)=="number" and type(m.Gold)=="number" and type(m.Radiant)=="number"
			and 0<m.Bronze and m.Bronze<m.Silver and m.Silver<m.Gold and m.Gold<m.Radiant then
			rules.medals={Bronze=m.Bronze,Silver=m.Silver,Gold=m.Gold,Radiant=m.Radiant}
		end
	end
	return rules
end
local function activeChain(state, now)
	if not state.lastCatch or now-state.lastCatch>state.rules.chainSeconds then return 0 end
	return state.chain
end
local function multiplier(chain,cap,step)
	return math.min(cap or 3,1+math.floor(math.max(0,chain-1)/(step or 3)))
end
local function progress(state)
	if state.goal.id=="precision" then return state.precision end
	if state.goal.id=="chain" then return state.bestChain end
	return state.bestHaul
end
local function medal(score,m)
	m=m or DEFAULT_RULES.medals
	if score>=m.Radiant then return "Radiant" end
	if score>=m.Gold then return "Gold" elseif score>=m.Silver then return "Silver" elseif score>=m.Bronze then return "Bronze" end
	return "Unranked"
end

-- Recorded observations, not interpolated historical scores. Missing samples stay missing.
function Challenge.sanitizeBestRun(raw)
	local result={score=0,checkpoints={}}
	if type(raw)~="table" or not finite(raw.score) or raw.score<0 or raw.score>MAX_SCORE then return result end
	result.score=math.floor(raw.score)
	if type(raw.checkpoints)~="table" or result.score==0 then return result end
	local previous=0
	for _,boundary in ipairs(CHECKPOINTS) do
		local key=tostring(boundary)
		local sample=raw.checkpoints[key]
		if type(sample)=="table" and finite(sample.score) and sample.score%1==0
			and sample.score>=previous and sample.score<=result.score and finite(sample.sampledAt)
			and sample.sampledAt>=boundary and sample.sampledAt<=(if boundary==110 then 120 else boundary+SAMPLE_TOLERANCE)
			and (boundary~=110 or sample.score==result.score) then
			result.checkpoints[key]={score=sample.score,sampledAt=sample.sampledAt}
			previous=sample.score
		end
	end
	return result
end
local function copyCheckpoints(checkpoints)
	local copy={}
	for _,boundary in ipairs(CHECKPOINTS) do
		local key=tostring(boundary); local sample=checkpoints[key]
		if sample then copy[key]={score=sample.score,sampledAt=sample.sampledAt} end
	end
	return copy
end

function Challenge.new(roundIndex,previousBestRun,rawRules)
	local index=if finite(roundIndex) then math.clamp(math.floor(roundIndex),1,1000000) else 1
	local difficulty=math.min(3,1+math.floor((index-1)/3))
	local goal=goals[(index-1)%#goals+1]
	return {roundIndex=index,difficulty=difficulty,
		goal={id=goal.id,name=goal.name,description=goal.description,target=goal.target+difficulty-1},
		score=0,pendingBase=0,pendingBonus=0,pendingCount=0,chain=0,bestChain=0,bestHaul=0,
		precision=0,dashCatches=0,captures=0,misses=0,lostBonus=0,lastEvent=0,lastCatch=nil,
		lastCapture=nil,seen={},goalComplete=false,finished=false,
		checkpoints={},checkpointElapsed=0,previousBest=Challenge.sanitizeBestRun(previousBestRun),
		rules=rulesFrom(rawRules),multiCatches=0,bestMulti=0,herded=0,assists=0,pops=0,zaps=0,golden=0,
		buzzerLost=0,scattered=0,finaleBanks=0,bestBank=0}
end

-- Main samples before heartbeat transactions, and again after final auto-bank/finish.
-- A delayed heartbeat never fabricates earlier split scores. Final observation is
-- allowed only after finish and by 120s; a longer stall leaves that sample absent.
function Challenge.checkpoint(state,elapsed)
	if not finite(elapsed) or elapsed<state.checkpointElapsed or elapsed<0 or elapsed>120 then return false end
	state.checkpointElapsed=elapsed
	for _,boundary in ipairs(CHECKPOINTS) do
		local key=tostring(boundary)
		local upper=if boundary==110 then 120 else boundary+SAMPLE_TOLERANCE
		if not state.checkpoints[key] and elapsed>=boundary and elapsed<=upper
			and ((boundary==110 and state.finished) or (boundary~=110 and not state.finished)) then
			state.checkpoints[key]={score=state.score,sampledAt=elapsed}
			return true
		end
	end
	return false
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
	local personalBest={target=state.previousBest.score}
	if state.previousBest.score>0 then
		for _,boundary in ipairs(CHECKPOINTS) do
			local key=tostring(boundary)
			local current,previous=state.checkpoints[key],state.previousBest.checkpoints[key]
			if current and previous then
				personalBest.checkpoint=boundary; personalBest.delta=current.score-previous.score
				personalBest.sampledAt=current.sampledAt; personalBest.previousSampledAt=previous.sampledAt
			end
		end
	end
	return {score=state.score,pending=state.pendingBase+state.pendingBonus,
		checkpoints=copyCheckpoints(state.checkpoints),personalBest=personalBest,
		pendingBonus=state.pendingBonus,chain=chain,multiplier=multiplier(chain,state.rules.maxMultiplier,state.rules.chainStep),
		chainSeconds=if chain>0 then math.max(0,state.rules.chainSeconds-(at-state.lastCatch)) else 0,
		chainWindow=state.rules.chainSeconds,maxMultiplier=state.rules.maxMultiplier,
		scoreMultiplier=state.rules.scoreMultiplier,pendingCount=state.pendingCount,
		multiCatches=state.multiCatches,bestMulti=state.bestMulti,herded=state.herded,assists=state.assists,
		pops=state.pops,zaps=state.zaps,golden=state.golden,buzzerLost=state.buzzerLost,
		scattered=state.scattered,finaleBanks=state.finaleBanks,bestBank=state.bestBank,
		precision=state.precision,dashCatches=state.dashCatches,bestChain=state.bestChain,
		bestHaul=state.bestHaul,captures=state.captures,misses=state.misses,lostBonus=state.lostBonus,
		medal=medal(state.score,state.rules.medals),difficulty=state.difficulty,finished=state.finished,
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
	local kind=catch.kind or "normal"
	if kind~="normal" and kind~="dash" and kind~="herd" and kind~="golden" then return false,"Invalid capture kind" end
	local multiIndex=catch.multiIndex
	if multiIndex~=nil and (not finite(multiIndex) or multiIndex%1~=0 or multiIndex<1 or multiIndex>8) then return false,"Invalid capture" end
	-- Only button catches are rate limited; dash-through/herd/golden are server events
	-- bounded by unique IDs, dash cooldown and the round capture ceiling below.
	if kind=="normal" and state.lastCapture and now-state.lastCapture+0.000001<CAPTURE_INTERVAL then return false,"Capture too soon" end
	-- Maximum is above any 110s round at the minimum capture interval, bounding memory.
	if state.captures>=512 then return false,"Round capture limit" end
	state.lastEvent=now
	if kind=="normal" then state.lastCapture=now end
	if id~=nil then state.seen[id]=true end
	if catch.starter then
		return true,{points=0,precision=false,dash=false,chain=activeChain(state,now),multiplier=1,starter=true}
	end
	state.chain=activeChain(state,now)+1; state.lastCatch=now
	state.bestChain=math.max(state.bestChain,state.chain)
	state.captures+=1; state.pendingCount+=1
	local rules=state.rules
	local precise=kind=="normal" and catch.distance<=4 and catch.facing>=rules.precisionFacing
	local dash=kind=="dash" or (catch.dashAge~=nil and catch.dashAge<=0.55)
	local multi=kind=="dash" and multiIndex~=nil and multiIndex>=2
	if precise then state.precision+=1 end
	if dash then state.dashCatches+=1 end
	if multi then state.multiCatches+=1 end
	if kind=="dash" and multiIndex then state.bestMulti=math.max(state.bestMulti,multiIndex) end
	if kind=="herd" then state.herded+=1 end
	if kind=="golden" then state.golden+=1 end
	local base=10+math.floor(catch.value)*2
	local style=(if precise then 15 else 0)+(if dash then rules.dashBonus else 0)+(if multi then MULTI_BONUS else 0)
		+(if kind=="herd" then math.floor(HERD_BONUS*rules.herdMultiplier) else 0)
		+(if kind=="golden" then math.floor(GOLDEN_BONUS*rules.goldenMultiplier) else 0)
	local factor=multiplier(state.chain,rules.maxMultiplier,rules.chainStep)
	local bonus=(base+style)*factor-base
	state.pendingBase=math.min(MAX_SCORE,state.pendingBase+base)
	state.pendingBonus=math.min(MAX_SCORE,state.pendingBonus+bonus)
	return true,{points=base+bonus,precision=precise,dash=dash,multi=multi,kind=kind,chain=state.chain,
		multiplier=factor,starter=false}
end

-- Non-catch skill events. A pop refreshes an active chain's timer without
-- extending its length; an assist rewards flanking a teammate's herded Spark.
function Challenge.award(state, now, kind)
	if state.finished or not clockValid(state,now) then return false,0 end
	if kind~="pop" and kind~="assist" then return false,0 end
	if state.pops+state.assists>=512 then return false,0 end
	state.lastEvent=now
	local points
	if kind=="pop" then
		state.pops+=1; points=state.rules.popPoints
		if activeChain(state,now)>0 then state.lastCatch=now end
	else
		state.assists+=1; points=math.floor(ASSIST_BONUS*state.rules.herdMultiplier)
	end
	state.pendingBonus=math.min(MAX_SCORE,state.pendingBonus+points)
	return true,points
end

-- Carried Sparks knocked loose by a zap leave the parade, so their unbanked base
-- points leave too (prevents re-catch double counting). Bonus loss is a miss.
function Challenge.scatter(state, now, bases)
	if state.finished or not clockValid(state,now) or type(bases)~="table" then return 0 end
	local removed=0
	for index=1,math.min(#bases,16) do
		local base=bases[index]
		if finite(base) and base>=0 and state.pendingCount>0 then
			state.pendingCount-=1; state.pendingBase=math.max(0,state.pendingBase-math.floor(base)); removed+=1
		end
	end
	state.scattered=math.min(1000000,state.scattered+removed); state.lastEvent=now
	return removed
end

-- Round end: the automatic bank keeps base points but the carried style bonus
-- is forfeited, so banking before the buzzer is a meaningful decision.
function Challenge.buzzer(state, now)
	if state.finished or not clockValid(state,now) then return 0 end
	local lost=state.pendingBonus
	state.pendingBonus=0; state.buzzerLost=math.min(MAX_SCORE,state.buzzerLost+lost); state.lastEvent=now
	return lost
end

-- A miss/hazard loses only the current unbanked skill bonus. Catch base points,
-- banked score, glow and collection remain intact; next catch immediately recovers.
function Challenge.miss(state, now, _reason)
	if state.finished or not clockValid(state,now) then return false,0 end
	if _reason=="zap" then state.zaps=math.min(1000000,state.zaps+1) end
	state.lastEvent=now; state.chain=0; state.lastCatch=nil
	local lost=state.pendingBonus
	state.pendingBonus=0; state.lostBonus=math.min(MAX_SCORE,state.lostBonus+lost)
	state.misses=math.min(1000000,state.misses+1)
	return true,lost
end

-- options.finale: server says this bank is in the round's final 25 seconds.
function Challenge.bank(state, now, options)
	if state.finished or not clockValid(state,now) then return 0 end
	state.lastEvent=now
	if state.pendingCount==0 then
		-- Pops/assists can leave style with no carried Spark; it waits for a haul.
		return 0
	end
	local rules=state.rules
	state.bestHaul=math.max(state.bestHaul,state.pendingCount)
	local haul=math.min(rules.haulCap,1+HAUL_STEP*(state.pendingCount-1))
	local points=state.pendingBase+math.floor(state.pendingBonus*haul)
	local finale=type(options)=="table" and options.finale==true
	if finale then points=math.floor(points*rules.finaleFactor); state.finaleBanks+=1 end
	if not state.goalComplete and progress(state)>=state.goal.target then
		state.goalComplete=true; points+=100
	end
	points=math.floor(points*rules.scoreMultiplier)
	local applied=math.min(points,MAX_SCORE-state.score)
	state.bestBank=math.max(state.bestBank,applied)
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
