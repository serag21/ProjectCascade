local Profile=require("../game/ReplicatedStorage/Spark/Profile")
local Challenge=require("../game/ReplicatedStorage/Spark/Challenge")
local Config=require("../game/ReplicatedStorage/Spark/Config")
local checks=0
local function check(ok,message) checks+=1; assert(ok,message) end

local old=Profile.sanitize({version=1,coins=42,album={pip=2},totalBanked=2,rounds=1})
check(old.coins==42 and old.album.pip==2 and old.mastery.bestScore==0,"Old collection migrates without resetting currency")
check(old.settings.competition==false,"Competition must be opt-in")
local malformed=Profile.sanitize({mastery={bestScore=0/0,bestChain=math.huge,completed=-1,bestByBiome={fake=999}},settings={competition="true"}})
check(malformed.mastery.bestScore==0 and malformed.mastery.bestChain==0 and malformed.mastery.completed==0,"Sanitize malformed mastery")
check(not malformed.mastery.bestByBiome.fake and not malformed.settings.competition,"Whitelist records/settings")

local p=Profile.new()
local s=Challenge.new(1)
local carry={}
for i=1,3 do
	local ok=Challenge.capture(s,i,{distance=2,facing=1,value=3,starter=false,captureId=i,dashAge=.2})
	check(ok,"Validated close dash catch")
	table.insert(carry,"pip")
end
local coins=p.coins
Challenge.miss(s,4,"sweep")
check(p.coins==coins and #carry==3,"Bump cannot mutate collection/currency/carry")
local glow=Profile.bank(p,carry)
local secured=Challenge.bank(s,4.1)
check(glow==12 and secured==148,"Retain base and challenge bonus after losing carried style bonus")
local final=Challenge.finish(s,110)
check(Profile.recordMastery(p,Config.Biomes[1].id,final),"First scored round sets PB")
check(p.mastery.bestScore==148 and p.mastery.completed==1 and p.mastery.bestChain==3,"Persist completed round record")
local restored=Profile.sanitize(p)
check(restored.mastery.bestScore==148 and restored.mastery.bestByBiome[Config.Biomes[1].id]==148,"Save sanitizer preserves records")
restored.mastery.bestByBiome[Config.Biomes[1].id]=0
check(p.mastery.bestByBiome[Config.Biomes[1].id]==148,"Sanitized nested records are independent")
check(not Profile.recordMastery(p,"invalid",final),"Unknown arenas cannot acquire records")
check(not Profile.recordMastery(p,Config.Biomes[1].id,{finished=false,score=999999}),"Unfinished round cannot set record")
local empty=Challenge.finish(Challenge.new(2),110)
check(not Profile.recordMastery(p,Config.Biomes[1].id,empty) and p.mastery.bestScore==148,"Poor replay never lowers PB")

check(not Challenge.hazard(24.999,1).visible,"Grace period")
check(Challenge.hazard(25,1).warning and not Challenge.hazard(26.999,1).active,"Two-second warning")
check(Challenge.hazard(27,1).active and not Challenge.hazard(31,1).visible,"Bounded active window")
check(not Challenge.hazard(0/0,1).visible,"Bad clock never spawns hazard")
for tier=1,3 do
	for tenth=0,1100 do
		local h=Challenge.hazard(tenth/10,tier)
		if h.visible then
			check(math.abs(h.x*h.x+h.z*h.z-324)<.001,"Sweep stays on authored infield orbit")
			check(math.sqrt(h.x*h.x+(h.z-44)^2)-h.radius>20,"Spawn/bank remain clear")
		end
	end
end
print("PASS SparkMasteryIntegration: "..checks.." assertions (pure production modules; no engine/rendering)")
