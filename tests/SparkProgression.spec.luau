-- Production Profile + Challenge integration only. No engine or DataStore claims.
local Config=require("../game/ReplicatedStorage/Spark/Config")
local Profile=require("../game/ReplicatedStorage/Spark/Profile")
local Challenge=require("../game/ReplicatedStorage/Spark/Challenge")
local assertions=0
local function check(ok,message) assertions+=1; assert(ok,message) end
local function equal(a,b,message) check(a==b,(message or "Mismatch")..": "..tostring(a).." ~= "..tostring(b)) end
local function clone(p) return Profile.sanitize(p) end
local function quest(id)
	for _,q in ipairs(Config.Quests) do if q.id==id then return q end end
	error("Missing quest "..id)
end
local function finishRound(p,biome,index)
	local round=Challenge.new(index or (p.rounds+1))
	for n=1,6 do
		check(Challenge.capture(round,n,{distance=3,facing=1,value=3,starter=false,captureId=n,dashAge=.2}),"Legitimate skilled capture")
	end
	check(Challenge.bank(round,7)>0,"Score banked")
	local active=Challenge.snapshot(round,8)
	local before=clone(p)
	check(not Profile.recordMastery(p,biome,active,p.rounds+1),"Active round cannot earn permanent mastery")
	equal(p.mastery.precision,before.mastery.precision,"No progress before finish")
	local summary=Challenge.finish(round,110)
	p.rounds+=1
	Profile.recordMastery(p,biome,summary,p.rounds)
	return summary
end

do
	local p=Profile.sanitize({version=1,rounds=9,coins=57,album={pip=3},quests={first_haul=true}})
	equal(p.coins,57); equal(p.album.pip,3); check(p.quests.first_haul,"Keep old earned claims")
	equal(p.mastery.precision,0); equal(p.mastery.dashCatches,0)
	equal(p.mastery.lastRecordedRound,9,"Migration receipt starts at old completed rounds")
	local prior=Profile.sanitize({rounds=12,mastery={bestScore=420,bestChain=7,completed=3,bestByBiome={meadow=420}}})
	equal(prior.mastery.lastRecordedRound,12); equal(prior.mastery.completed,3)
	equal(prior.mastery.bestScore,420); equal(prior.mastery.precision,0,"Do not invent historical timing evidence")
	local p2=clone(p); p2.mastery.precision=99
	equal(p.mastery.precision,0,"Nested state remains independent")
end

do
	local bad={rounds=5,mastery={precision=0/0,dashCatches=math.huge,lastRecordedRound=99,unknown=5,bestByBiome={fake=900}}}
	bad.mastery.self=bad
	local p=Profile.sanitize(bad)
	equal(p.mastery.precision,0); equal(p.mastery.dashCatches,0); equal(p.mastery.lastRecordedRound,5)
	check(p.mastery.unknown==nil and p.mastery.self==nil and p.mastery.bestByBiome.fake==nil,"Whitelist new data")
	local bounded=Profile.sanitize({mastery={precision=1e30,dashCatches=-3}})
	equal(bounded.mastery.precision,1000000); equal(bounded.mastery.dashCatches,0)
end

do
	local p=Profile.new()
	for _,id in ipairs({"precision_path","dash_rhythm","chain_artist","challenge_trio","arena_medalist"}) do
		check(not Profile.claim(p,id),"Cannot claim skill quest early: "..id)
	end
	local final=finishRound(p,"meadow")
	equal(p.mastery.precision,6); equal(p.mastery.dashCatches,6); equal(p.mastery.bestChain,6)
	equal(p.mastery.completed,1); equal(p.mastery.lastRecordedRound,1)
	equal(Profile.questProgress(p,quest("arena_medalist")),1)
	for _,id in ipairs({"precision_path","dash_rhythm","chain_artist"}) do
		local before=p.coins
		check(Profile.claim(p,id),"Earned finite skill reward: "..id)
		equal(p.coins,before+quest(id).reward)
		check(not Profile.claim(p,id),"Claim is one-time")
		equal(p.coins,before+quest(id).reward,"Duplicate claim never pays")
	end
	local restored=clone(p)
	check(not Profile.recordMastery(restored,"meadow",final,1),"Persisted receipt rejects same round after reload")
	equal(restored.mastery.precision,6); equal(restored.mastery.completed,1)
	check(not Profile.claim(restored,"precision_path"),"Reload preserves claims")
	finishRound(restored,"canyon",2)
	finishRound(restored,"aurora",3)
	equal(restored.mastery.precision,18); equal(restored.mastery.completed,3)
	equal(Profile.questProgress(restored,quest("arena_medalist")),3)
	check(Profile.claim(restored,"challenge_trio"),"Three different completed round goals")
	check(Profile.claim(restored,"arena_medalist"),"Per-arena score awards full tour")
	check(not Profile.claim(restored,"arena_medalist"),"Full tour paid once")
	local before=clone(restored)
	for _,serial in ipairs({0,-1,1,2,3,4,1.5,0/0,math.huge,"4",true,{}}) do
		check(not Profile.recordMastery(restored,"meadow",final,serial),"Invalid/repeated/uncompleted serial refused")
		equal(restored.mastery.precision,before.mastery.precision)
		equal(restored.mastery.completed,before.mastery.completed)
		equal(restored.mastery.lastRecordedRound,before.mastery.lastRecordedRound)
	end
end

do
	-- Reaching a goal on one arena cannot impersonate a three-arena score record.
	local p=Profile.new()
	for n=1,3 do finishRound(p,"meadow",n) end
	equal(Profile.questProgress(p,quest("arena_medalist")),1)
	check(not Profile.claim(p,"arena_medalist"),"Each arena needs its own score")
	local noSkill=Challenge.new(1)
	for n=1,3 do
		check(Challenge.capture(noSkill,n,{distance=2,facing=1,value=4,starter=true,captureId=n,dashAge=.1}),"Starter caught")
	end
	local final=Challenge.finish(noSkill,110)
	p.rounds+=1; local before=clone(p)
	Profile.recordMastery(p,"canyon",final,p.rounds)
	equal(p.mastery.precision,before.mastery.precision,"Starter cannot inflate timing quest")
	equal(p.mastery.dashCatches,before.mastery.dashCatches)
	equal(p.mastery.completed,before.mastery.completed)
	equal(Profile.questProgress(p,quest("arena_medalist")),1,"Zero score cannot earn a medal")
end

do
	local p=Profile.new(); p.rounds=1
	local summary=Challenge.finish(Challenge.new(1),110)
	for _,key in ipairs({"score","bestChain","captures","precision","dashCatches"}) do
		for _,bad in ipairs({0/0,math.huge,-1,"8",true,{}}) do
			local corrupted=table.clone(summary); corrupted[key]=bad; corrupted.challenge={complete=true}
			check(not Profile.recordMastery(p,"meadow",corrupted,1),"Malformed summary refused")
			equal(p.mastery.completed,0); equal(p.mastery.lastRecordedRound,0,"No receipt consumed on bad summary")
		end
	end
	check(not Profile.recordMastery(p,"unknown",summary,1),"Unknown arena refused")
	equal(p.mastery.lastRecordedRound,0)
	local exhausted=Profile.sanitize({rounds=1,mastery={precision=1000000,dashCatches=1000000,completed=1000000,lastRecordedRound=0}})
	local enormous={finished=true,score=1e20,bestChain=1e20,captures=1e20,precision=1e20,dashCatches=1e20,challenge={complete=true}}
	Profile.recordMastery(exhausted,"meadow",enormous,1)
	equal(exhausted.mastery.bestScore,1000000); equal(exhausted.mastery.bestChain,512)
	equal(exhausted.mastery.precision,1000000); equal(exhausted.mastery.dashCatches,1000000)
	equal(exhausted.mastery.completed,1000000)
end

do
	local p=Profile.new()
	equal(Profile.rewardRally(p),8); equal(p.coins,8)
	equal(p.mastery.bestScore,0,"Co-op glow does not inflate personal skill records")
	p.coins=1999999997
	equal(Profile.rewardRally(p),3); equal(p.coins,2000000000)
	equal(Profile.rewardRally(p),0); equal(p.coins,2000000000,"Rally respects currency cap")
end

print("PASS SparkProgression: "..assertions.." assertions (production pure modules; no engine or real persistence)")
