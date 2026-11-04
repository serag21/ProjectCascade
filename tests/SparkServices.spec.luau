-- Optional platform services: analytics and leaderboards never block gameplay.
local Services=require("../game/ServerScriptService/Spark/Services")
local n=0
local function check(ok,message) n+=1; if not ok then error(message,2) end end
local enum={AnalyticsEconomyFlowType={Sink="Sink",Source="Source"},
	AnalyticsEconomyTransactionType={Shop={Name="Shop"},Gameplay={Name="Gameplay"}}}
local log={}
local service={}
function service:LogOnboardingFunnelStepEvent(player,step,name) table.insert(log,{"funnel",step,name}) end
function service:LogEconomyEvent(player,flow,currency,amount,balance,kind,sku) table.insert(log,{"economy",flow,currency,amount,balance,kind,sku}) end
function service:LogCustomEvent(player,name,value) table.insert(log,{"custom",name,value}) end
local a=Services.analytics(service,enum,true)
check(a.funnel({}, "first_catch") and log[1][2]==3,"Funnel step numbering")
check(not a.funnel({}, "bogus") and #log==1,"Unknown step ignored")
check(a.economy({}, "sink",20,17,"upgrade_boots") and log[2][2]=="Sink" and log[2][6]=="Shop" and log[2][4]==20,"Economy sink")
check(a.economy({}, "source",5.7,40,"bank") and log[3][4]==5 and log[3][6]=="Gameplay","Economy source floors")
check(not a.economy({}, "source",0,40,"bank") and not a.economy({}, "source",0/0,40,"x"),"Zero/NaN skipped")
check(a.custom({}, "golden_catch",2) and log[#log][2]=="golden_catch","Custom")
local broken=setmetatable({},{__index=function() return function() error("platform down") end end})
local b=Services.analytics(broken,enum,true)
check(not b.funnel({}, "join") and not b.economy({}, "sink",1,1,"x") and b.errors==2,"Failures are contained")
local off=Services.analytics(service,enum,false)
local before=#log; off.funnel({}, "join"); check(#log==before,"Disabled in Studio")
-- leaderboards
local provider=Services.memoryOrderedStore()
local lb=Services.leaderboard(provider,{"meadow","canyon"},function(now) return math.floor(now/604800) end)
check(lb.submit(1,"meadow",500,1000)==2,"Writes all-time and weekly")
check(lb.submit(2,"meadow",900,1000)==2 and lb.submit(1,"meadow",300,1000)==2,"Lower score accepted call but keeps max")
check(lb.submit(3,"lava",900,1000)==0 and lb.submit(3,"meadow",0/0,1000)==0 and lb.submit("x","meadow",5,1000)==0 and lb.submit(3,"meadow",-5,1000)==0,"Invalid submissions")
local boards=lb.refresh(1000,function(id) return "P"..id end)
local all=boards.meadow.alltime
check(#all==2 and all[1].userId==2 and all[1].score==900 and all[2].userId==1 and all[2].score==500 and all[1].name=="P2","Sorted, max kept")
check(#boards.canyon.alltime==0 and lb.version==1,"Empty board")
-- new week: weekly resets, all-time persists
lb.submit(1,"meadow",100,1000+604800)
local week2=lb.refresh(1000+604800,function(id) return "P"..id end)
check(#week2.meadow.weekly==1 and week2.meadow.weekly[1].score==100 and week2.meadow.alltime[1].score==900,"Weekly rollover")
for i=10,30 do lb.submit(i,"canyon",i,1000) end
check(#lb.refresh(1000,function() return "x" end).canyon.alltime==10,"Top 10 only")
-- failing backend keeps last good boards
local failing=Services.leaderboard(function() error("throttled") end,{"meadow"},function() return 1 end)
check(failing.submit(1,"meadow",50,1)==0 and failing.failures==2,"Submit failure contained")
local kept=failing.refresh(1,function() return "x" end)
check(kept.meadow and #kept.meadow.alltime==0 and failing.failures==4,"Refresh failure contained")
print("PASS SparkServices: "..n.." assertions (analytics/leaderboard doubles; no platform calls)")
