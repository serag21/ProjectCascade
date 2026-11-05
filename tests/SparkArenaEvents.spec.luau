local Events=require("../game/ReplicatedStorage/Spark/ArenaEvents")
local Encounters=require("../game/ReplicatedStorage/Spark/Encounters")
local n=0
local function check(ok,message) n+=1; assert(ok,message) end
local ids={"meadow","canyon","aurora"}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
for biome=1,3 do
	check(not Events.hazard(24.999,1,biome).visible,"Initial grace")
	check(Events.hazard(25,1,biome).warning,"Warning begins at grace boundary")
	check(not Events.hazard(26.999,1,biome).active,"Full two-second warning")
	check(Events.hazard(27,1,biome).active,"Active boundary")
	check(Events.hazard(30.999,1,biome).active,"Four-second active window")
	check(not Events.hazard(31,1,biome).visible,"Eight-second recovery rest")
	check(not Events.hazard(38.999,1,biome).visible and Events.hazard(39,1,biome).warning,"Next cycle always warns")
	for tier=1,3 do
		local previous=nil
		for step=0,11000 do
			local t=step/100
			local h=Events.hazard(t,tier,biome)
			if h.visible then
				check(finite(h.x) and finite(h.z) and h.radius==3.5,"Bounded finite geometry")
				check(h.warning~=h.active and h.seconds>0 and h.seconds<=4,"Exclusive warning/active timing")
				check(math.sqrt(h.x*h.x+(h.z-44)^2)-h.radius>20,"Bank remains outside hazard and approach clearance")
				check(math.sqrt(h.x*h.x+(h.z-38)^2)-h.radius>16,"Spawn remains outside hazard")
				for _,x in ipairs({-26.163,26.163}) do for _,z in ipairs({-26.163,26.163}) do
					check(math.sqrt((h.x-x)^2+(h.z-z)^2)-h.radius>7,"Steering island body margin")
				end end
				-- Per-arena obstacles (D22): sweeps keep a 2.5-stud body margin from pillars/crystals too.
				check(Encounters.clearOfObstacles(biome,h.x,h.z,h.radius+2.5),"Sweep clear of this arena's obstacles")
				if previous and previous.visible then
					local distance=math.sqrt((h.x-previous.x)^2+(h.z-previous.z)^2)
					check(distance/.01<7,"Continuous warning-to-active motion capped below walking speed")
				end
				check(type(h.name)=="string" and #h.name>0 and type(h.cue)=="string","Human-readable biome cue")
			end
			previous=h
		end
	end
	for step=0,4400 do
		local t=step/10
		local event=Events.herd(t,biome)
		check(event.speedScale>=.6 and event.speedScale<=1.4,"Speed bounds")
		check(event.turnScale>=.6 and event.turnScale<=1.4,"Turning bounds")
		check(event.phase>=1 and event.phase<=5 and event.remaining>0 and event.remaining<=30,"Bounded phase timing")
		local wrapped=Events.herd(t+120,biome)
		check(event.name==wrapped.name and event.speedScale==wrapped.speedScale,"Repeatable arena event cycle")
	end
	for _,time in ipairs({0,25,55,85,110}) do
		local byId=Events.herd(time,ids[biome]); local byIndex=Events.herd(time,biome)
		check(byId.name==byIndex.name,"String/numeric arena identities agree")
	end
	local h=Events.hazard(27,1,biome);h.x=999
	check(Events.hazard(27,1,biome).x~=999,"Hazard snapshots independent")
	local event=Events.herd(55,biome);event.speedScale=999
	check(Events.herd(55,biome).speedScale<=1.4,"Event snapshots independent")
end
for _,bad in ipairs({-1,0/0,math.huge,-math.huge,"25",false,{}}) do
	check(not Events.hazard(bad,1,1).visible,"Invalid elapsed hides hazard")
	check(Events.herd(bad,1).phase==0,"Invalid elapsed neutral herd")
end
for _,bad in ipairs({0,4,-1,1.1,0/0,math.huge,"unknown",false,{}}) do
	check(not Events.hazard(27,1,bad).visible,"Invalid biome hides hazard")
	check(Events.herd(55,bad).phase==0,"Invalid biome neutral herd")
end
check(not Events.hazard(nil,1,1).visible and not Events.hazard(27,1,nil).visible,"Missing inputs safe")
for biome=1,3 do
	local a=Events.hazard(27,0/0,biome); local b=Events.hazard(27,1,biome)
	check(a.x==b.x and a.z==b.z,"Invalid difficulty defaults safely")
	local high=Events.hazard(27,999,biome);local max=Events.hazard(27,3,biome)
	check(high.x==max.x and high.z==max.z,"Difficulty ceiling")
	local huge=Events.hazard(1e308,3,biome)
	check(not huge.visible or (finite(huge.x) and finite(huge.z)),"Huge finite time never creates NaN geometry")
end
check(Events.herd(25,1).name~=Events.herd(25,2).name and Events.herd(55,2).turnScale~=Events.herd(55,3).turnScale,"Biomes change behavior, not only names")
print("PASS SparkArenaEvents: "..n.." assertions (pure paths and event timing; no rendering/physics)")
