-- Synchronized Stampede Cycles (FINAL_PRODUCTION_PLAN §6.1). Every arena shares
-- one 120 s cycle: 110 s of play, then a 10 s intermission (podium, countdown).
-- Late joiners play at once: a partial round when >=40 s of play remain, else a
-- scoreless warm-up until the next cycle starts. Pure and shared by server/client.
local Cycle = {}
Cycle.Length = 120
Cycle.Play = 110
Cycle.Intermission = 10
Cycle.MinPartial = 40
Cycle.FullGrace = 3      -- joined within 3 s of the start still counts as a full round
Cycle.FinaleSeconds = 25
Cycle.CompletionCatches = 3

local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end

-- clock: seconds on the shared arena clock (os.clock()-arenaEpoch on the server).
function Cycle.at(clock)
	if not finite(clock) or clock<0 then clock=0 end
	local index=math.floor(clock/Cycle.Length)
	local start=index*Cycle.Length
	local t=clock-start
	local playing=t<Cycle.Play
	return {
		index=index, start=start, t=t,
		phase=if playing then "Play" else "Intermission",
		playEnd=start+Cycle.Play, nextStart=start+Cycle.Length,
		playRemaining=if playing then Cycle.Play-t else 0,
		nextStartIn=start+Cycle.Length-clock,
		finale=playing and Cycle.Play-t<=Cycle.FinaleSeconds,
	}
end

-- What a player who becomes ready at `clock` should do.
-- mode "round": play now until `endsAt`; `full` when joined within the grace.
-- mode "warmup": free practice until `endsAt` (the next cycle start), no score.
function Cycle.joinPlan(clock)
	local at=Cycle.at(clock)
	if at.phase=="Play" and at.playRemaining>=Cycle.MinPartial then
		return {mode="round",full=at.t<=Cycle.FullGrace,startsAt=clock,endsAt=at.playEnd,cycle=at.index}
	end
	return {mode="warmup",full=false,startsAt=clock,endsAt=at.nextStart,cycle=at.index+1}
end

-- The round that starts exactly at a cycle boundary (auto-start after intermission).
function Cycle.fullRound(clock)
	local at=Cycle.at(clock)
	return {mode="round",full=true,startsAt=at.start,endsAt=at.playEnd,cycle=at.index}
end

-- Round credit (completion XP, round counters, goals) needs real participation.
function Cycle.completed(captures)
	return finite(captures) and captures>=Cycle.CompletionCatches
end

-- Positive-only podium awards. entries: {userId,name,score,bestChain,golden,
-- assists,herded,pops,showOnPodium}. Returns up to 3 awards, preferring distinct
-- winners; ties break on score then userId. Never ranks anyone last.
local categories = {
	{kind="TopParade", title="Top Parade", value=function(e) return e.score end, minimum=1},
	{kind="LongestChain", title="Longest Chain", value=function(e) return e.bestChain end, minimum=3},
	{kind="GoldenCatcher", title="Golden Catcher", value=function(e) return e.golden end, minimum=1},
	{kind="BestFlanker", title="Best Flanker", value=function(e) return (e.assists or 0)+(e.herded or 0) end, minimum=1},
	{kind="StaticBuster", title="Static Buster", value=function(e) return e.pops end, minimum=1},
}
Cycle.AwardKinds = categories
local function number(n) return if finite(n) then n else 0 end
function Cycle.awards(entries)
	local eligible={}
	if type(entries)~="table" then return {} end
	for _,e in ipairs(entries) do
		if type(e)=="table" and e.showOnPodium~=false and finite(e.userId) then table.insert(eligible,e) end
	end
	local candidates={}
	for order,category in ipairs(categories) do
		local best,bestValue=nil,nil
		for _,e in ipairs(eligible) do
			local value=number(category.value(e))
			if value>=category.minimum then
				if best==nil or value>bestValue
					or (value==bestValue and (number(e.score)>number(best.score)
						or (number(e.score)==number(best.score) and e.userId<best.userId))) then
					best,bestValue=e,value
				end
			end
		end
		if best then table.insert(candidates,{kind=category.kind,title=category.title,userId=best.userId,
			name=tostring(best.name or "Player"),value=bestValue,order=order}) end
	end
	local chosen,used={}, {}
	for pass=1,2 do
		for _,award in ipairs(candidates) do
			if #chosen>=3 then break end
			local fresh=not used[award.userId]
			if (pass==1 and fresh) or (pass==2 and not award.taken) then
				if pass==1 or not table.find(chosen,award) then
					award.taken=true; used[award.userId]=true; table.insert(chosen,award)
				end
			end
		end
	end
	table.sort(chosen,function(a,b) return a.order<b.order end)
	for _,award in ipairs(chosen) do award.taken=nil; award.order=nil end
	return chosen
end

return Cycle
