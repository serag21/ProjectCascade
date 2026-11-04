-- Long-term progression: rank curve, achievements, daily/weekly goals, cosmetics,
-- profile v2 migration and economy invariants. Pure production modules only.
local Config=require("../game/ReplicatedStorage/Spark/Config")
local Profile=require("../game/ReplicatedStorage/Spark/Profile")
local Progression=require("../game/ReplicatedStorage/Spark/Progression")
local Loadout=require("../game/ReplicatedStorage/Spark/Loadout")
local Challenge=require("../game/ReplicatedStorage/Spark/Challenge")
local n=0
local function check(ok,message) n+=1; if not ok then error(message,2) end end
local DAY=86400
local NOW=1793750400 -- 2026-11-04 UTC midnight-ish fixed clock

-- Rank curve -----------------------------------------------------------------
check(Progression.xpFor(1)==0 and Progression.rank(0)==1 and Progression.rank(-5)==1 and Progression.rank(0/0)==1,"Rank floor")
local last=-1
for r=1,50 do local x=Progression.xpFor(r); check(x>last,"Monotonic XP "..r); check(Progression.rank(x)==r,"Rank at threshold "..r)
	if r>1 then check(Progression.rank(x-1)==r-1,"Just below threshold "..r) end; last=x end
check(Progression.rank(1e12)==50 and Progression.rankProgress(1e12).fraction==1,"Cap 50")
check(Progression.roundXp(0)==50 and Progression.roundXp(800)==250 and Progression.roundXp(-10)==50,"Round XP")
check(Progression.rank(Progression.roundXp(120))>=2,"Any modest first round reaches rank 2 (perks)")

-- Profile v2 defaults and migration -----------------------------------------------
local p=Profile.new()
check(p.version==2 and p.xp==0 and p.heat==0 and #p.loadout==0 and p.style.trail=="none","v2 defaults")
for _,biome in ipairs(Config.Biomes) do check(#p.records[biome.id]==6,"Record rows") end
local v1={version=1,coins=321,totalBanked=95,rounds=12,album={pip=41,bunvolt=16,flutter=3},upgrades={boots=2,magnet=1,basket=3},
	quests={first_haul=true},mastery={bestScore=850,bestChain=9,completed=4,precision=30,dashCatches=12,bestByBiome={meadow=850,canyon=420}},
	settings={music=false}}
local m=Profile.sanitize(v1)
check(m and m.version==2 and m.coins==321 and m.album.pip==41 and m.upgrades.basket==3 and m.quests.first_haul,"v1 collection/glow/upgrades/quests kept")
check(m.mutations.pip==3 and m.mutations.bunvolt==2 and m.mutations.flutter==nil,"Radiant tier derived at 40")
check(m.records.meadow[1]==850 and m.records.canyon[1]==420 and m.records.aurora[1]==0,"v1 bests become heat-0 records")
check(m.progressReceipt==12,"Migration cannot replay old rounds into progression")
check(m.settings.music==false and m.xp==0 and m.heat==0,"Settings kept, new fields default")
check(Loadout.heatUnlocked(m.records)==1,"Migrated silver unlocks heat 1")
-- malicious v2
local evil={version=2,xp=1e30,heat=5,loadout={"goldnose","reach","reach","hack"},records={meadow={1e20,"x",0/0,-5}},
	gilded={pip=true,fake=true},stats={pops=-3,golden=1e40,bogus=5},achievements={stampede=true,fake=true},
	daily={day=5,goals={"d_catch","d_catch","nope","d_pop","d_dash","d_chain"},progress={d_catch=1e9},claimed={d_pop=true,nope=true},bonus="yes"},
	weekly={week="z",goals={"w_catch"}},style={owned={sunbeam=true,legend=true,fake=true},trail="legend",title="stampede"},progressReceipt=1e9,rounds=3}
local e=Profile.sanitize(evil)
check(e.xp==100000000,"XP clamped")
check(e.records.meadow[1]==1000000 and e.records.meadow[2]==0 and e.records.meadow[3]==0 and e.records.meadow[4]==0,"Records sanitized")
check(e.gilded.pip and not e.gilded.fake and e.stats.pops==0 and e.stats.golden==1000000 and e.stats.bogus==nil,"Stats/gilded whitelisted")
check(e.achievements.stampede and not e.achievements.fake,"Achievements whitelisted")
check(#e.daily.goals==3 and e.daily.goals[1]=="d_catch" and e.daily.goals[2]=="d_pop" and e.daily.progress.d_catch==40 and e.daily.claimed.d_pop and e.daily.bonus==false,"Daily sanitized")
check(e.weekly.week==0,"Weekly sanitized")
check(e.style.owned.sunbeam and not e.style.owned.legend and not e.style.owned.fake,"Only purchasable styles are stored as owned")
check(e.style.trail=="legend","Rank-50 trail stays equipped at max rank")
check(e.style.title=="stampede","Earned title kept")
check(e.progressReceipt==3,"Receipt bounded by rounds")
check(e.heat==Loadout.heatUnlocked(e.records),"Heat clamped to unlocked ("..e.heat..")")
check(#e.loadout==2 and e.loadout[1]=="goldnose" and e.loadout[2]=="reach","Loadout sanitized against rank")
local poor=Profile.sanitize({version=2,style={trail="legend",title="stampede"},heat=4,loadout={"reach"}})
check(poor.style.trail=="none" and poor.style.title=="" and poor.heat==0 and #poor.loadout==0,"Unearned equips stripped")
check(Profile.sanitize({version=3})==nil,"Future versions refused")
check(Profile.sanitize({xp="lots"}).xp==0,"Type confusion")

-- Golden banking --------------------------------------------------------------
local g=Profile.new()
local reward=Profile.bank(g,{"*flutter","pip","*fake","*"})
check(reward==7*3+3 and g.album.flutter==1 and g.gilded.flutter and g.totalBanked==2,"Golden triple value and gilded mark")

-- Goals -------------------------------------------------------------------------
local q=Profile.new()
check(Progression.ensureGoals(q,NOW) and #q.daily.goals==3 and #q.weekly.goals==3,"Goals rolled")
check(not Progression.ensureGoals(q,NOW+60),"Stable within a day")
local snapshot=table.concat(q.daily.goals,",")
local q2=Profile.new(); Progression.ensureGoals(q2,NOW+3600)
check(table.concat(q2.daily.goals,",")==snapshot,"Deterministic for same day and eligibility")
for _,id in ipairs(q.daily.goals) do check(Progression.GoalById[id].requires==nil,"New players only get eligible daily goals") end
local distinct={}
for d=0,30 do local r=Profile.new(); Progression.ensureGoals(r,NOW+d*DAY); distinct[table.concat(r.daily.goals,",")]=true
	local seen={}; for _,id in ipairs(r.daily.goals) do check(not seen[id],"Distinct goals"); seen[id]=true end end
local variety=0; for _ in pairs(distinct) do variety+=1 end
check(variety>=20,"Daily goals vary across a month ("..variety..")")
-- unlocking an arena mid-day does not reshuffle
q.totalBanked=500; check(not Progression.ensureGoals(q,NOW+7200) and table.concat(q.daily.goals,",")==snapshot,"Frozen goals")
-- applying rounds
local function summary(extra)
	local s={finished=true,score=520,captures=45,precision=13,dashCatches=11,multiCatches=3,herded=4,pops=6,golden=1,
		bestChain=8,assists=2,zaps=1,misses=0,bestMulti=3,bestHaul=12}
	for k,v in pairs(extra or {}) do s[k]=v end
	return s
end
local r=Profile.new(); r.rounds=1
local result=Progression.applyRound(r,summary(),1,0,1,NOW)
check(result and result.xp==Progression.roundXp(520) and result.newRecord and r.records.meadow[1]==520,"Round applied")
check(Progression.applyRound(r,summary(),1,0,1,NOW)==nil,"Receipt prevents double apply")
check(Progression.applyRound(r,summary(),1,0,2,NOW)==nil,"Serial beyond rounds rejected")
check(Progression.applyRound(r,{finished=false},1,0,1,NOW)==nil and Progression.applyRound(r,summary(),9,0,1,NOW)==nil,"Unfinished/bad biome")
check(r.stats.golden==1 and r.stats.bestMulti==3 and r.stats.bestBankCount==12 and r.stats.herded==4,"Stats aggregated")
check(r.achievements.golden_1 and r.achievements.triple_dash and r.achievements.heavy_haul,"Achievements earned")
local xpAfter=r.xp
check(#Progression.evaluateAchievements(r)==0 and r.xp==xpAfter,"Achievements grant once")
for _,id in ipairs(r.daily.goals) do
	local goal=Progression.GoalById[id]
	check((r.daily.progress[id] or 0)<=goal.target,"Progress capped")
end
-- claim goals
local claimable=nil
for _,id in ipairs(r.daily.goals) do if r.daily.progress[id]>=Progression.GoalById[id].target then claimable=id end end
check(claimable~=nil,"A daily goal completed by a strong round")
local coins=r.coins
local ok=Progression.claimGoal(r,claimable)
check(ok and r.coins>=coins+30,"Claim pays")
check(not Progression.claimGoal(r,claimable),"Claim once")
check(not Progression.claimGoal(r,"w_catch_fake") and not Progression.claimGoal(r,5),"Unknown goal")
-- all three daily claims add the set bonus exactly once
local full=Profile.new(); full.rounds=10
Progression.ensureGoals(full,NOW)
for _,id in ipairs(full.daily.goals) do full.daily.progress[id]=Progression.GoalById[id].target end
local start=full.coins
for _,id in ipairs(full.daily.goals) do check(Progression.claimGoal(full,id),"Claim "..id) end
check(full.coins==start+3*30+50 and full.daily.bonus,"Daily set bonus once")
-- new day resets without penalty
local keepCoins,keepXp=full.coins,full.xp
Progression.ensureGoals(full,NOW+DAY)
check(full.coins==keepCoins and full.xp==keepXp and next(full.daily.claimed)==nil,"New day: fresh goals, nothing lost")
check(Progression.week(NOW)==Progression.week(NOW+DAY) or Progression.week(NOW+DAY)==Progression.week(NOW)+1,"Week index")
check(Progression.week(0)==0 and Progression.week(4*DAY)==1,"Weeks start Monday UTC (1970-01-05)")

-- Styles and titles ------------------------------------------------------------
local st=Profile.new()
check(not Progression.style(st,"sunbeam"),"Cannot afford")
st.coins=1000
local okBuy=Progression.style(st,"sunbeam")
check(okBuy and st.coins==850 and st.style.owned.sunbeam and st.style.trail=="sunbeam","Guaranteed purchase")
check(Progression.style(st,"sunbeam") and st.coins==850,"Re-equip free")
check(not Progression.style(st,"lagoon"),"Rank style locked")
st.xp=Progression.xpFor(5); check(Progression.style(st,"lagoon") and st.coins==850,"Rank style free when earned")
check(not Progression.style(st,"gilded"),"Achievement style locked")
st.achievements.golden_10=true; check(Progression.style(st,"gilded"),"Achievement style")
check(not Progression.style(st,"royal"),"Royal needs rank 30 and price")
st.xp=Progression.xpFor(30); st.coins=1999; check(not Progression.style(st,"royal"),"Royal price")
st.coins=2000; check(Progression.style(st,"royal") and st.coins==0,"Royal bought")
check(not Progression.style(st,"fake") and not Progression.style(st,nil),"Unknown style")
check(not Progression.setTitle(st,"stampede"),"Unearned title")
st.achievements.stampede=true; check(Progression.setTitle(st,"stampede") and Progression.titleText(st)=="Stampeder","Title")
check(not Progression.setTitle(st,"first_spark"),"Achievement without title")
check(Progression.setTitle(st,"") and Progression.titleText(st)=="","Clear title")
-- Every trail has an obtainable path.
for _,trail in ipairs(Progression.Trails) do
	check(trail.id=="none" or trail.price or trail.rank or trail.achievement,"Trail obtainable "..trail.id)
	if trail.achievement then check(Progression.AchievementById[trail.achievement]~=nil,"Trail achievement exists") end
	check(#trail.colors==2,"Trail colors")
end
-- Unlock callouts
local unlocks=Progression.unlocksBetween(1,15)
check(table.find(unlocks,"Perk: Long Reach") and table.find(unlocks,"Third perk slot") and table.find(unlocks,"Trail: Lagoon"),"Unlock callouts")
-- Achievements reachable: each has a test that can pass on a maximal profile.
local maxp=Profile.new(); maxp.totalBanked=1000; maxp.rounds=100; maxp.mastery.bestChain=12
for _,c in ipairs(Config.Creatures) do maxp.album[c.id]=50; maxp.mutations[c.id]=3 end
for _,b in ipairs(Config.Biomes) do for h=1,6 do maxp.records[b.id][h]=1500 end end
for _,k in ipairs(Profile.StatKeys) do maxp.stats[k]=100 end
maxp.stats.bestMulti=4; maxp.stats.bestBankCount=20
Progression.evaluateAchievements(maxp)
for _,a in ipairs(Progression.Achievements) do check(maxp.achievements[a.id],"Achievement reachable "..a.id) end

-- Round-trip save of a progressed profile is lossless --------------------------
local rt=Profile.sanitize(r)
check(rt.xp==r.xp and rt.records.meadow[1]==520 and rt.stats.golden==1 and rt.daily.day==r.daily.day
	and rt.daily.claimed[claimable] and rt.achievements.golden_1 and rt.progressReceipt==1,"Lossless round trip")

-- Integration: a full round through Challenge -> recordMastery -> applyRound ---
local live=Profile.new()
local ch=Challenge.new(1,nil,Loadout.stats(live.upgrades,live.loadout,live.heat))
for i=1,12 do Challenge.capture(ch,i*0.7,{distance=2,facing=1,value=5,starter=false,captureId=i,dashAge=.2}) end
Challenge.bank(ch,9)
Challenge.buzzer(ch,110); local final=Challenge.finish(ch,110)
live.rounds=1
Profile.recordMastery(live,"meadow",final,1)
local res=Progression.applyRound(live,final,1,0,1,NOW)
check(res and live.records.meadow[1]==final.score and live.mastery.bestByBiome.meadow==final.score,"End-to-end round records")
check(Progression.rank(live.xp)>=2,"First solid round unlocks perks rank")
print("PASS SparkLongTerm: "..n.." assertions (rank, goals, achievements, styles, v2 migration; pure modules)")
