-- Shared, solo-completable banking sprint. No client totals, no personal-score inflation.
-- Main calls only for ordinary Sparks actually banked at the gate, never auto-bank.
local Rally={Seconds=45,Target=6,Reward=8}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
function Rally.new(now)
	assert(finite(now) and now>=0,"Invalid rally epoch")
	return {started=now,lastEvent=now,cycle=0,total=0,contributors={},complete=false}
end
local function advance(state,now)
	if not finite(now) or now<state.lastEvent then return false end
	local cycle=math.floor((now-state.started)/Rally.Seconds)
	if cycle~=state.cycle then
		state.cycle=cycle; state.total=0; state.contributors={}; state.complete=false
	end
	state.lastEvent=now
	return true
end
function Rally.snapshot(state,now,userId)
	if not advance(state,now) then now=state.lastEvent end
	return {cycle=state.cycle,total=state.total,target=Rally.Target,complete=state.complete,
		remaining=math.max(0,math.ceil(Rally.Seconds-(now-state.started)%Rally.Seconds)),
		contribution=state.contributors[userId] or 0,reward=Rally.Reward}
end
function Rally.deposit(state,now,userId,count)
	if not finite(userId) or userId%1~=0 or not finite(count) or count%1~=0 or count<1 or count>14 then return {} end
	if not advance(state,now) or state.complete then return {} end
	if not state.contributors[userId] then
		local size=0; for _ in pairs(state.contributors) do size+=1 end
		if size>=64 then return {} end
	end
	state.contributors[userId]=math.min(Rally.Target,(state.contributors[userId] or 0)+count)
	state.total=math.min(Rally.Target,state.total+count)
	local rewards={}
	if state.total>=Rally.Target then
		state.complete=true -- transition before returning any awards; repeated deposits never pay twice
		for id in pairs(state.contributors) do table.insert(rewards,id) end
		table.sort(rewards)
	end
	return rewards
end
function Rally.leave(state,userId)
	-- Team progress is retained; departed players cannot receive or reclaim credit on rejoin.
	state.contributors[userId]=nil
end
return Rally
