local Challenge=require("../game/ReplicatedStorage/Spark/Challenge")
local assertions=0
local function check(condition,message) assertions+=1; assert(condition,message) end
local function equal(actual,expected,message) check(actual==expected,(message or "Mismatch")..": "..tostring(actual).." ~= "..tostring(expected)) end
local function catch(state,now,options)
	local data={distance=6,facing=.8,value=3,starter=false,captureId=tostring(now)}
	for key,value in pairs(options or {}) do data[key]=value end
	local ok,result=Challenge.capture(state,now,data)
	check(ok,tostring(result)); return result
end

-- Timing, precision and dash edges are inclusive; no bonus for loose positioning.
do
	local s=Challenge.new(1)
	local r=catch(s,1,{distance=4,facing=.7,dashAge=.55})
	equal(r.points,51); equal(r.precision,true); equal(r.dash,true)
	r=catch(s,1.65,{distance=4.001,facing=.7,dashAge=.5501})
	equal(r.points,16); equal(r.precision,false); equal(r.dash,false)
	r=catch(s,2.3,{distance=3,facing=.6999})
	equal(r.precision,false)
	equal(Challenge.snapshot(s).score,0,"Unbanked points must not appear secured")
	equal(Challenge.bank(s,3),83); equal(Challenge.bank(s,3),0,"Bank is idempotent")
end

-- Six-second chain boundary and capped multiplier; waiting preserves haul value.
do
	local s=Challenge.new(2)
	for i=1,10 do
		local r=catch(s,i)
		equal(r.multiplier,math.min(3,1+math.floor((i-1)/3)))
	end
	equal(Challenge.snapshot(s,16).chain,10)
	equal(Challenge.snapshot(s,16.001).chain,0)
	local before=Challenge.snapshot(s).pending
	equal(catch(s,17).chain,1)
	equal(Challenge.snapshot(s).pending,before+16)
	local award=Challenge.bank(s,18)
	equal(award,before+116,"Completed rhythm challenge grants bonus once")
	equal(Challenge.snapshot(s).challenge.complete,true)
	catch(s,19); equal(Challenge.bank(s,20),16,"Goal cannot pay twice")
end

-- Misses threaten carried mastery bonus without removing baseline or secured score.
do
	local s=Challenge.new(1)
	catch(s,1,{distance=2,dashAge=.2})
	local ok,lost=Challenge.miss(s,2,"miss")
	equal(ok,true); equal(lost,35); equal(Challenge.snapshot(s).pending,16)
	equal(Challenge.snapshot(s).chain,0)
	equal(Challenge.bank(s,3),16)
	catch(s,4,{distance=2,dashAge=.2})
	Challenge.miss(s,5,"hazard")
	equal(Challenge.snapshot(s).score,16,"Secured score survives a hazard")
	equal(catch(s,6).chain,1,"Recovery starts immediately")
	equal(Challenge.bank(s,7),32)
end

-- Onboarding cannot inflate scores, chains, challenges, or largest haul.
do
	local s=Challenge.new(3)
	for i=1,3 do equal(catch(s,i,{starter=true,distance=1,dashAge=0}).points,0) end
	equal(Challenge.bank(s,4),0); equal(Challenge.snapshot(s).captures,0)
	equal(Challenge.snapshot(s).challenge.progress,0)
	for i=5,7 do catch(s,i) end
	equal(Challenge.bank(s,8),148)
	equal(Challenge.snapshot(s).bestHaul,3); equal(Challenge.snapshot(s).challenge.complete,true)
end

-- Rejected requests never advance the clock, alter points or reserve a capture ID.
do
	local s=Challenge.new(1)
	catch(s,10)
	local before=Challenge.snapshot(s)
	for _,bad in ipairs({0/0,math.huge,-math.huge,-1,9}) do
		local ok=Challenge.capture(s,bad,{distance=1,facing=1,value=3,starter=false,captureId="bad"})
		equal(ok,false); equal(Challenge.bank(s,bad),0)
		equal(Challenge.miss(s,bad),false)
		equal(Challenge.finish(s,bad).finished,false)
	end
	for _,patch in ipairs({{distance=0/0},{distance=-1},{facing=math.huge},{facing=1.1},{value=math.huge},
		{value=-1},{dashAge=-.1},{dashAge=0/0},{starter="false"},{captureId={}},{captureId=string.rep("x",65)}}) do
		local data={distance=1,facing=1,value=3,starter=false,captureId="bad"}
		for key,value in pairs(patch) do data[key]=value end
		equal(Challenge.capture(s,11,data),false)
	end
	equal(Challenge.snapshot(s).pending,before.pending); equal(s.lastEvent,10)
	equal(catch(s,11,{captureId="bad"}).points,16,"Rejected ID remains available")
	equal(Challenge.capture(s,12,{distance=1,facing=1,value=3,starter=false,captureId="bad"}),false)
	equal(Challenge.capture(s,11.1,{distance=1,facing=1,value=3,starter=false,captureId="new"}),false)
	equal(Challenge.snapshot(s).captures,2)
end

-- Precision goal, deterministic difficulty, medals, and finish lifecycle.
do
	for i=1,30 do
		local a,b=Challenge.new(i),Challenge.new(i)
		equal(a.goal.id,b.goal.id); equal(a.goal.target,b.goal.target)
		equal(a.difficulty,math.min(3,1+math.floor((i-1)/3)))
	end
	local s=Challenge.new(1)
	for i=1,3 do catch(s,i,{distance=1}) end
	equal(Challenge.snapshot(s).challenge.complete,false,"Goal seals at bank")
	equal(Challenge.bank(s,4),193); equal(Challenge.snapshot(s).medal,"Bronze")
	for i=5,12 do catch(s,i,{distance=1,dashAge=.1}) end
	local final=Challenge.finish(s,13)
	equal(final.medal,"Gold"); equal(final.pending,0); equal(final.finished,true)
	equal(Challenge.finish(s,14).score,final.score)
	equal(Challenge.bank(s,15),0); equal(Challenge.miss(s,15),false)
	equal(Challenge.capture(s,15,{distance=1,facing=1,value=3,starter=false}),false)
	final.challenge.target=10000
	check(Challenge.snapshot(s).challenge.target~=10000,"Snapshot must not expose mutable goal state")
end

-- Long randomized action schedule maintains bounded, monotonic secured score.
do
	local random=Random -- CLI has no engine Random; use deterministic arithmetic instead.
	local seed=7168
	local function nextInt() seed=(seed*48271)%2147483647; return seed end
	for round=1,12 do
		local s=Challenge.new(round)
		local now,lastScore=0,0
		for i=1,120 do
			now+=.7
			local choice=nextInt()%5
			if choice<3 then
				catch(s,now,{distance=if nextInt()%2==0 then 3 else 7,dashAge=if nextInt()%2==0 then .3 else 1})
			elseif choice==3 then Challenge.miss(s,now) else Challenge.bank(s,now) end
			local view=Challenge.snapshot(s,now)
			check(view.score>=lastScore and view.score<=1000000,"Secured score must stay bounded and monotonic")
			check(view.pending>=0 and view.multiplier>=1 and view.multiplier<=3,"Score/chain bounds")
			lastScore=view.score
		end
		local final=Challenge.finish(s,now+1)
		check(final.score>=lastScore and final.pending==0,"Finalization safely banks remaining points")
	end
end
print(string.format("PASS SparkChallenge: %d assertions (pure Luau, no Studio)",assertions))
