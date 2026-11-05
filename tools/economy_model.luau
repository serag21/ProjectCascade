-- Economy/progression model driven by the REAL production modules.
-- Synthetic players generate catch/bank/miss/zap events per round; the real
-- Challenge, Profile and Progression code turns them into score, glow, XP,
-- upgrades, album and goals. Output is a balance HYPOTHESIS, not player data.
-- Usage: .tools/luau/luau tests/SparkEconomy.spec.luau (prints the markdown
--        table and asserts the design-spec acceptance bounds).
local Config=require("../game/ReplicatedStorage/Spark/Config")
local Profile=require("../game/ReplicatedStorage/Spark/Profile")
local Challenge=require("../game/ReplicatedStorage/Spark/Challenge")
local Loadout=require("../game/ReplicatedStorage/Spark/Loadout")
local Progression=require("../game/ReplicatedStorage/Spark/Progression")
local Cosmetics=require("../game/ReplicatedStorage/Spark/Cosmetics")
local Trial=require("../game/ReplicatedStorage/Spark/Trial")

local Model={}
Model.RoundMinutes=120/60 -- one synchronized Stampede Cycle (110 s play + 10 s intermission)
Model.TrialMinutes=(Trial.RunSeconds+10)/60 -- one Daily Stampede run + results/retry

-- Behaviour per archetype (per round). Rates are per catch unless noted.
Model.Archetypes={
	{id="novice",catches=14,precision=.2,dash=.1,multiPerRound=0.3,herded=0.4,pops=0.3,zaps=2,golden=.12,miss=.25,bankEvery=5,
		roundsPerDay=8,maxHeat=0,perks={"reach","pockets","rhythm"},trialRuns=1},
	{id="regular",catches=24,precision=.4,dash=.25,multiPerRound=2,herded=2,pops=2,zaps=1,golden=.4,miss=.12,bankEvery=7,
		roundsPerDay=12,maxHeat=2,perks={"slipstream","rhythm","pockets"},trialRuns=2},
	{id="expert",catches=36,precision=.65,dash=.45,multiPerRound=5,herded=4,pops=5,zaps=.4,golden=.8,miss=.05,bankEvery=9,
		roundsPerDay=20,maxHeat=5,perks={"slipstream","breaker","rhythm"},trialRuns=4},
}

local function lcg(seed)
	local state=seed
	return function()
		state=(state*1103515245+12345)%2147483648
		return state/2147483648
	end
end
local function count(rand,mean)
	-- small-mean Poisson-ish integer with the right expectation
	local n=math.floor(mean); if rand()<mean-n then n+=1 end
	return n
end

local function speciesFor(biome)
	local list={}
	for _,c in ipairs(Config.Creatures) do if c.biome==biome or c.biome==Config.Biomes[biome].id then table.insert(list,c) end end
	return list
end
local arenaSpecies={speciesFor(1),speciesFor(2),speciesFor(3)}

local function chooseArena(profile,round)
	-- Rotate through unlocked arenas, favouring the newest.
	local unlocked={}
	for index,biome in ipairs(Config.Biomes) do if profile.totalBanked>=biome.unlock then table.insert(unlocked,index) end end
	if #unlocked==1 then return 1 end
	if round%3==0 then return unlocked[1+(round//3)%#unlocked] end
	return unlocked[#unlocked]
end

local function spend(profile)
	local bought={}
	local progress=true
	while progress do
		progress=false
		local cheapest,price=nil,math.huge
		for key,upgrade in pairs(Config.Upgrades) do
			local cost=upgrade.costs[profile.upgrades[key]+1]
			if cost and cost<price then cheapest,price=key,cost end
		end
		if cheapest and profile.coins>=price then Profile.buy(profile,cheapest); table.insert(bought,cheapest); progress=true end
	end
	-- Then cosmetic trails by ascending price (a long-tail sink).
	for _,trail in ipairs(Progression.Trails) do
		if trail.price and not profile.style.owned[trail.id] and profile.coins>=trail.price
			and (not trail.rank or Progression.rank(profile.xp)>=trail.rank) then
			Progression.style(profile,trail.id)
		end
	end
	-- Then priced formations, bank bursts and name tags (D20 long-tail sink).
	local rank=Progression.rank(profile.xp)
	local priced={}
	for _,item in ipairs(Cosmetics.Items) do
		if item.price and not Cosmetics.isUnlocked(profile,item) and (not item.rank or rank>=item.rank) then table.insert(priced,item) end
	end
	table.sort(priced,function(a,b) return a.price<b.price or (a.price==b.price and a.id<b.id) end)
	for _,item in ipairs(priced) do
		if profile.coins>=item.price then Cosmetics.equip(profile,item.category,item.id) end
	end
	return bought
end

-- One simulated run of `duration` seconds. opts.trial: normalized Daily Stampede
-- (no glow/album banking, its own scaling); otherwise a normal shared round.
local function simulate(profile,archetype,rand,challenge,stats,biome,duration,opts)
	local species=arenaSpecies[biome]
	local heat=if opts.trial then 0 else profile.heat
	local heatPenalty=1-0.04*heat
	local scale=duration/110*(if opts.trial then 1.1 else 1) -- 20 private Sparks: no competition for targets
	local catches=math.floor(archetype.catches*scale*heatPenalty*math.min(1.25,1+stats.capacity/80))
	local carry={}
	local t=2
	local spacing=(duration-10)/math.max(1,catches)
	local id=0
	local eventScale=if opts.trial then duration/110 else 1
	local multi=count(rand,archetype.multiPerRound*eventScale)
	local herded=count(rand,if biome~=2 then archetype.herded*eventScale else 0)
	local pops=count(rand,archetype.pops*eventScale)
	local zaps=count(rand,archetype.zaps*eventScale*(1+0.15*heat))
	local golden=rand()<archetype.golden*(if opts.trial then 1.5 else 1)
	local caught=0
	local function bankNow(at)
		if not opts.trial then Profile.bank(profile,carry) end
		carry={}; Challenge.bank(challenge,at,{finale=duration-at<=25})
	end
	local events={}
	for _=1,catches do table.insert(events,"catch") end
	for _=1,multi do table.insert(events,"multi") end
	for _=1,herded do table.insert(events,"herd") end
	for _=1,pops do table.insert(events,"pop") end
	for _=1,zaps do table.insert(events,"zap") end
	if golden then table.insert(events,"golden") end
	-- deterministic shuffle
	for i=#events,2,-1 do local j=1+math.floor(rand()*i); events[i],events[j]=events[j],events[i] end
	local sinceBank=0
	for _,event in ipairs(events) do
		t+=spacing*(0.6+rand()*0.6)
		if t>=duration-1 then break end
		if #carry>=stats.capacity then bankNow(t); sinceBank=0 end
		local def=species[1+math.floor(rand()*#species)]
		id+=1
		if event=="catch" then
			if rand()<archetype.miss then Challenge.miss(challenge,t,"miss") end
			Challenge.capture(challenge,t,{distance=if rand()<archetype.precision then 3 else 7,facing=1,value=def.value,starter=false,
				captureId=id,dashAge=if rand()<archetype.dash then 0.2 else nil})
			table.insert(carry,def.id); sinceBank+=1; caught+=1
		elseif event=="multi" then
			for index=1,2 do
				id+=1
				Challenge.capture(challenge,t,{distance=2,facing=1,value=def.value,starter=false,captureId=id,kind="dash",multiIndex=index})
				table.insert(carry,def.id)
			end
			sinceBank+=2; caught+=2
		elseif event=="herd" then
			Challenge.capture(challenge,t,{distance=0,facing=1,value=def.value,starter=false,captureId=id,kind="herd"})
			table.insert(carry,def.id); sinceBank+=1; caught+=1
		elseif event=="golden" then
			local rare=species[1+math.floor(rand()*#species)]
			Challenge.capture(challenge,t,{distance=5,facing=1,value=rare.value,starter=false,captureId=id,kind="golden"})
			table.insert(carry,"*"..rare.id); sinceBank+=1; caught+=1
		elseif event=="pop" then
			Challenge.award(challenge,t,"pop")
		elseif event=="zap" then
			Challenge.miss(challenge,t,"zap")
			local bases={}
			for _=1,math.min(stats.zapScatter,#carry) do table.remove(carry); table.insert(bases,20) end
			Challenge.scatter(challenge,t,bases)
		end
		if sinceBank>=archetype.bankEvery and #carry>0 then
			t+=3 -- walk to the gate
			bankNow(t); sinceBank=0
		end
	end
	Challenge.buzzer(challenge,duration)
	if #carry>0 then bankNow(duration) end
	return Challenge.finish(challenge,duration),caught
end

-- Simulate one 110s round for an archetype. Returns the Challenge summary.
function Model.round(profile,archetype,rand,roundSerial,now)
	local biome=chooseArena(profile,roundSerial)
	-- Heat: highest unlocked up to the archetype's comfort ceiling.
	profile.heat=math.min(archetype.maxHeat,Loadout.heatUnlocked(profile.records))
	profile.loadout=Loadout.sanitize(archetype.perks,Progression.rank(profile.xp))
	local stats=Loadout.stats(profile.upgrades,profile.loadout,profile.heat)
	local challenge=Challenge.new(profile.rounds+1,nil,stats)
	local summary=simulate(profile,archetype,rand,challenge,stats,biome,110,{})
	profile.rounds+=1
	Profile.recordMastery(profile,Config.Biomes[biome].id,summary,profile.rounds)
	Progression.applyRound(profile,summary,biome,profile.heat,profile.rounds,now)
	return summary,biome
end

-- One Daily Stampede run: normalized rules, settled by the production Trial.settle.
function Model.trial(profile,archetype,rand,now)
	local day=Trial.day(now)
	local plan=Trial.plan(day)
	local stats=Trial.stats()
	local challenge=Challenge.new(7+day%12,nil,stats)
	local summary,caught=simulate(profile,archetype,rand,challenge,stats,plan.biome,Trial.RunSeconds,{trial=true})
	return Trial.settle(profile,day,math.floor(summary.score),caught,summary.checkpoints,now),summary
end

function Model.run(archetype,maxRounds,seed)
	local rand=lcg(seed or 1)
	local profile=Profile.new()
	local now=1793750400
	local milestones={}
	local minutes=0
	local roundsAt={}
	local function mark(key) if not milestones[key] then milestones[key]=minutes/60; roundsAt[key]=profile.rounds end end
	local scores,medals={},{}
	local trialScores,trialMedals,trialGlow,trialXp={},{},0,0
	for round=1,maxRounds do
		if round>1 and (round-1)%archetype.roundsPerDay==0 then now+=86400 end
		local summary=Model.round(profile,archetype,rand,round,now)
		minutes+=Model.RoundMinutes
		-- Daily Stampede after the second round of each day (unlocks after round 2).
		if (round-1)%archetype.roundsPerDay==1 and profile.rounds>=2 then
			for _=1,archetype.trialRuns do
				local settled=Model.trial(profile,archetype,rand,now)
				minutes+=Model.TrialMinutes
				table.insert(trialScores,settled.score)
				local medal=Trial.medal(settled.score); trialMedals[medal]=(trialMedals[medal] or 0)+1
				trialGlow+=settled.glow; trialXp+=settled.xp
			end
		end
		table.insert(scores,summary.score); medals[summary.medal]=(medals[summary.medal] or 0)+1
		for _,quest in ipairs(Config.Quests) do Profile.claim(profile,quest.id) end
		for _,id in ipairs(profile.daily.goals) do Progression.claimGoal(profile,id) end
		for _,id in ipairs(profile.weekly.goals) do Progression.claimGoal(profile,id) end
		spend(profile)
		local rank=Progression.rank(profile.xp)
		for _,r in ipairs({2,5,10,15,20,30,40,50}) do if rank>=r then mark("rank"..r) end end
		local maxed=true
		for key,upgrade in pairs(Config.Upgrades) do if profile.upgrades[key]<#upgrade.costs then maxed=false end end
		if maxed then mark("allUpgrades") end
		if profile.totalBanked>=Config.Biomes[2].unlock then mark("canyon") end
		if profile.totalBanked>=Config.Biomes[3].unlock then mark("aurora") end
		local species,prism,radiant,gilded=0,0,0,0
		for _,c in ipairs(Config.Creatures) do
			local n=profile.album[c.id] or 0
			if n>0 then species+=1 end
			if n>=Config.Mutations[2].threshold then prism+=1 end
			if n>=Config.Mutations[3].threshold then radiant+=1 end
			if profile.gilded[c.id] then gilded+=1 end
		end
		if gilded>=12 then mark("gilded12") end
		local allTrails=true
		for _,trail in ipairs(Progression.Trails) do
			if trail.price and not profile.style.owned[trail.id] then allTrails=false end
		end
		if allTrails then mark("allTrails") end
		local allCosmetics=allTrails
		for _,item in ipairs(Cosmetics.Items) do
			if item.price and not Cosmetics.isUnlocked(profile,item) then allCosmetics=false end
		end
		if allCosmetics then mark("allCosmetics") end
		if species>=12 then mark("album12") end
		if prism>=12 then mark("allPrism") end
		if radiant>=12 then mark("allRadiant") end
		if Loadout.heatUnlocked(profile.records)>=1 then mark("heat1") end
		if Loadout.heatUnlocked(profile.records)>=5 then mark("heat5") end
	end
	table.sort(scores); table.sort(trialScores)
	local achievements=0; for _ in pairs(profile.achievements) do achievements+=1 end
	return {milestones=milestones,roundsAt=roundsAt,median=scores[math.max(1,#scores//2)],p90=scores[math.max(1,math.floor(#scores*.9))],
		medals=medals,profile=profile,achievements=achievements,rounds=maxRounds,hours=minutes/60,
		trialMedian=trialScores[math.max(1,#trialScores//2)] or 0,trialP90=trialScores[math.max(1,math.floor(#trialScores*.9))] or 0,
		trialRuns=#trialScores,trialMedals=trialMedals,trialGlow=trialGlow,trialXp=trialXp}
end

-- Milestones are stored in hours of play (rounds + Daily Stampede runs).
function Model.hours(value) return value end

local function fmt(hours,rounds)
	if not hours then return "not reached" end
	return string.format("%d rounds (%.1f h)",rounds or 0,hours)
end
function Model.report(maxRounds)
	local lines={"| Milestone | "..table.concat((function() local t={} for _,a in ipairs(Model.Archetypes) do table.insert(t,a.id) end return t end)()," | ").." |",
		"| --- | --- | --- | --- |"}
	local results={}
	for index,a in ipairs(Model.Archetypes) do results[index]=Model.run(a,maxRounds,1000+index) end
	for _,key in ipairs({"rank2","rank5","rank10","rank15","rank20","rank30","rank40","rank50","canyon","aurora","allUpgrades","album12","allPrism","allRadiant","gilded12","allTrails","allCosmetics","heat1","heat5"}) do
		local row={key}
		for index in ipairs(Model.Archetypes) do table.insert(row,fmt(results[index].milestones[key],results[index].roundsAt[key])) end
		table.insert(lines,"| "..table.concat(row," | ").." |")
	end
	local med={"median score"}; local p90={"p90 score"}; local ach={"achievements after run"}; local glow={"glow balance after run"}
	local tmed={"Daily Stampede median (medal)"}; local tp90={"Daily Stampede p90 (medal)"}; local truns={"Daily Stampede runs / glow / XP"}
	local hours={"hours played"}
	for index in ipairs(Model.Archetypes) do
		local r=results[index]
		table.insert(med,tostring(r.median)); table.insert(p90,tostring(r.p90))
		table.insert(ach,tostring(r.achievements)); table.insert(glow,tostring(r.profile.coins))
		table.insert(tmed,string.format("%d (%s)",r.trialMedian,Trial.medal(r.trialMedian)))
		table.insert(tp90,string.format("%d (%s)",r.trialP90,Trial.medal(r.trialP90)))
		table.insert(truns,string.format("%d / %d / %d",r.trialRuns,r.trialGlow,r.trialXp))
		table.insert(hours,string.format("%.1f",r.hours))
	end
	for _,row in ipairs({med,p90,ach,glow,tmed,tp90,truns,hours}) do table.insert(lines,"| "..table.concat(row," | ").." |") end
	return table.concat(lines,"\n"),results
end

return Model
