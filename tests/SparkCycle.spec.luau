-- Synchronized Stampede Cycles: phase math, late-join rules, completion and
-- positive podium awards. Pure module; no engine.
local Cycle=require("../game/ReplicatedStorage/Spark/Cycle")
local Encounters=require("../game/ReplicatedStorage/Spark/Encounters")
local ArenaEvents=require("../game/ReplicatedStorage/Spark/ArenaEvents")
local n=0
local function check(ok,message) n+=1; if not ok then error(message,2) end end

check(Cycle.Length==Cycle.Play+Cycle.Intermission,"Cycle composition")
check(Encounters.Cycle==Cycle.Length,"Encounters share the cycle length")
for second=0,1199 do
	local clock=second/10*1.0 + 3*Cycle.Length
	local at=Cycle.at(clock)
	check(at.t>=0 and at.t<Cycle.Length,"t bounded")
	check((at.phase=="Play")==(at.t<Cycle.Play),"Phase boundary")
	check(math.abs(at.nextStartIn-(Cycle.Length-at.t))<1e-9,"Next start")
	check(at.finale==(at.phase=="Play" and at.playRemaining<=Cycle.FinaleSeconds),"Finale window")
end
check(Cycle.at(0/0).t==0 and Cycle.at(-5).t==0 and Cycle.at(math.huge).t==0,"Bad clocks")

-- Join rules for every 0.5 s offset.
for step=0,239 do
	local clock=1000*Cycle.Length+step*0.5
	local at=Cycle.at(clock)
	local plan=Cycle.joinPlan(clock)
	check(plan.endsAt>clock,"Plan ends in the future")
	if plan.mode=="round" then
		check(at.phase=="Play" and at.playRemaining>=Cycle.MinPartial,"Round only with enough play left")
		check(plan.endsAt==at.playEnd,"Round ends at the shared buzzer")
		check(plan.full==(at.t<=Cycle.FullGrace),"Full flag only near start")
	else
		check(at.phase=="Intermission" or at.playRemaining<Cycle.MinPartial,"Warm-up otherwise")
		check(plan.endsAt==at.nextStart and not plan.full,"Warm-up lasts to the next start")
		-- Nobody waits more than one intermission plus the short tail of a round.
		check(plan.endsAt-clock<=Cycle.MinPartial+Cycle.Intermission,"Bounded warm-up")
	end
end
local auto=Cycle.fullRound(5*Cycle.Length+0.2)
check(auto.full and auto.endsAt==5*Cycle.Length+Cycle.Play and auto.startsAt==5*Cycle.Length,"Auto-start round")

-- Golden finale and buzzer line up for every player of a cycle.
for t=0,119 do
	local g=Encounters.golden(t,1,1)
	if g.spawn then check(t>=Encounters.GoldenAt and t<Cycle.Play,"Golden only in the finale") end
	check(not (Encounters.gate(t,1).active and t>=Cycle.Play),"No encounter in intermission")
	check(not (Encounters.stampede(t,2).active and t>=Cycle.Play),"No runs in intermission")
	local e=ArenaEvents.herd(t,1)
	check(e.phase>=1 and e.remaining>0,"Herd phase defined across the whole cycle")
end
check(Encounters.golden(Encounters.GoldenAt+1,1,1).expiresIn<=Cycle.Play-Encounters.GoldenAt,"Golden leaves at the buzzer")

check(not Cycle.completed(2) and Cycle.completed(3) and not Cycle.completed(0/0) and not Cycle.completed(nil),"Completion rule")

-- Awards: positive, distinct winners, opt-out respected, deterministic.
local entries={
	{userId=1,name="A",score=900,bestChain=12,golden=0,assists=0,herded=0,pops=1},
	{userId=2,name="B",score=1200,bestChain=6,golden=1,assists=2,herded=1,pops=0},
	{userId=3,name="C",score=300,bestChain=4,golden=0,assists=5,herded=3,pops=4},
	{userId=4,name="D",score=5000,bestChain=20,golden=2,assists=9,herded=9,pops=9,showOnPodium=false},
}
local awards=Cycle.awards(entries)
check(#awards==3,"Three awards")
local winners={}
for _,a in ipairs(awards) do check(a.userId~=4,"Opt-out respected"); winners[a.userId]=(winners[a.userId] or 0)+1; check(type(a.title)=="string" and a.value>0,"Award shape") end
check(winners[1]==1 and winners[2]==1 and winners[3]==1,"Distinct winners when possible")
check(awards[1].kind=="TopParade" and awards[1].userId==2,"Top parade first")
local solo=Cycle.awards({{userId=7,name="Solo",score=400,bestChain=8,golden=1,assists=0,herded=0,pops=2}})
check(#solo==3 and solo[1].userId==7,"Solo player gets personal highlights")
check(#Cycle.awards({{userId=8,name="Idle",score=0,bestChain=0,golden=0,assists=0,herded=0,pops=0}})==0,"No award for nothing")
check(#Cycle.awards(nil)==0 and #Cycle.awards({1,"x"})==0,"Malformed entries")
local tie=Cycle.awards({{userId=9,name="X",score=500,bestChain=5},{userId=3,name="Y",score=500,bestChain=5}})
check(tie[1].userId==3,"Ties break on userId")
for trial=1,200 do
	local list={}
	for i=1,4 do table.insert(list,{userId=i+trial,name="P"..i,score=(i*trial)%997,bestChain=(i+trial)%17,golden=(i*7+trial)%3,
		assists=(trial+i)%5,herded=i%2,pops=(trial*i)%4,showOnPodium=(i+trial)%5~=0}) end
	local a=Cycle.awards(list)
	check(#a<=3,"At most three")
	local again=Cycle.awards(list)
	for i=1,#a do check(a[i].userId==again[i].userId and a[i].kind==again[i].kind,"Deterministic") end
end
print("PASS SparkCycle: "..n.." assertions (cycle phases, late join, completion, podium awards; pure)")
