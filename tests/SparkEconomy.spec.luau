-- Economy acceptance bounds (design spec A10) using the real production modules
-- via tools/economy_model.luau. Synthetic archetypes, NOT player data: these
-- bounds protect intended pacing from accidental regressions only.
local Model=require("../tools/economy_model")
local Config=require("../game/ReplicatedStorage/Spark/Config")
local report,results=Model.report(1500)
print(report)
local n=0
local function check(ok,message) n+=1; if not ok then error(message,2) end end
local function h(m,key) return Model.hours(m[key]) or math.huge end
local novice,regular,expert=results[1].milestones,results[2].milestones,results[3].milestones
for name,m in pairs({novice=novice,regular=regular,expert=expert}) do
	check(m.rank2==1,name..": first finished round unlocks perks (rank 2)")
	check(h(m,"canyon")<=0.5,name..": second arena within the first half hour")
	check(h(m,"rank50")>=15,name..": rank 50 is a long-term goal (>=15h)")
end
check(h(novice,"allUpgrades")>=0.25 and h(novice,"allUpgrades")<=2,"Novice maxes upgrades in 15min-2h")
check(h(regular,"rank10")>=0.4 and h(regular,"rank10")<=3,"Regular rank 10 in 0.4-3h")
check(h(regular,"rank15")>=1 and h(regular,"rank15")<=5,"Regular third perk slot in 1-5h")
check(h(regular,"rank50")>=25 and h(regular,"rank50")<=80,"Regular rank 50 in 25-80h")
check(h(novice,"rank50")>h(regular,"rank50") and h(regular,"rank50")>h(expert,"rank50"),"Skill speeds progress")
check(h(expert,"rank50")*3>=h(novice,"rank50"),"...but never more than 3x (no runaway gap)")
check(h(regular,"allRadiant")>=1.5,"Radiant collection takes 1.5h+ for regulars")
check(h(regular,"gilded12")>=3,"Gilded collection is a multi-session goal")
check(h(regular,"allTrails")>=3,"Cosmetic sink lasts several hours")
check(results[1].median>=Config.Medals.Bronze and results[1].median<Config.Medals.Gold,"Novice median: Bronze/Silver")
check(results[2].median>=Config.Medals.Silver and results[2].median<Config.Medals.Radiant,"Regular median: Silver/Gold")
check(results[3].p90>=Config.Medals.Radiant,"Experts can reach Radiant")
check(novice.heat5==nil,"Heat 5 is not reached by novices")
print("PASS SparkEconomy: "..n.." pacing assertions (synthetic archetypes; balance hypothesis, not player data)")
