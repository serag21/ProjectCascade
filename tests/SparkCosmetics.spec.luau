-- Cosmetics catalog, rank-reward density, formation geometry, equip/buy flows and
-- save sanitization. Pure production modules only; no rendering or engine claims.
local Progression=require("../game/ReplicatedStorage/Spark/Progression")
local Loadout=require("../game/ReplicatedStorage/Spark/Loadout")
local Cosmetics=require("../game/ReplicatedStorage/Spark/Cosmetics")
local n=0
local function check(ok,message) n+=1; if not ok then error(message,2) end end
local function equal(a,b,message) check(a==b,(message or "Mismatch")..": "..tostring(a).." ~= "..tostring(b)) end
local EPS=1e-6
local ById=Cosmetics.ById

-- Catalog ----------------------------------------------------------------------
local minimum={formation=9,burst=12,tag=16,title=8}
local perCategory={formation=0,burst=0,tag=0,title=0}
local seen,itemCount={},0
for _,item in ipairs(Cosmetics.Items) do
	itemCount+=1
	check(type(item.id)=="string" and #item.id<=24 and string.match(item.id,"^[%w_]+$")~=nil,"Save-safe id (Profile v3 format): "..tostring(item.id))
	check(not seen[item.id],"Duplicate cosmetic id "..item.id); seen[item.id]=true
	check(Progression.TrailById[item.id]==nil,"Cosmetic id collides with a trail: "..item.id)
	check(ById[item.id]==item,"ById maps "..item.id)
	check(perCategory[item.category]~=nil,"Known category for "..item.id)
	perCategory[item.category]+=1
	equal(Cosmetics.category(item.id),item.category,"category("..item.id..")")
	check(type(item.name)=="string" and #item.name>0 and #item.name<=24,"Readable name for "..item.id)
	-- No strobing/flashing or chance-based fields anywhere in the catalog.
	for key in pairs(item) do
		local lower=string.lower(tostring(key))
		for _,banned in ipairs({"flash","strobe","blink","flicker","pulse","chance","odds","random","weight","robux"}) do
			check(not string.find(lower,banned,1,true),"Forbidden field "..tostring(key).." on "..item.id)
		end
	end
	-- Exactly one way to obtain each non-default item.
	local ways=(if item.default then 1 else 0)+(if item.price then 1 else 0)+(if item.achievement then 1 else 0)
		+(if item.rank and not item.price and not item.achievement and not item.default then 1 else 0)
	equal(ways,1,"One unlock path for "..item.id)
	if item.default then check(item.rank==nil and item.price==nil and item.achievement==nil,"Default is free: "..item.id) end
	if item.rank then check(item.rank%1==0 and item.rank>=2 and item.rank<=Progression.MaxRank,"Rank in 2..50: "..item.id) end
	if item.price then check(item.price%1==0 and item.price>=1000 and item.price<=15000,"Price 1,000..15,000: "..item.id) end
	if item.achievement then check(Progression.AchievementById[item.achievement]~=nil,"Achievement exists for "..item.id) end
	if item.category=="title" then check(item.rank and not item.price and not item.achievement,"Rank titles are rank-only") end
end
for category,count in pairs(perCategory) do check(count>=minimum[category],category.." count "..count.." >= "..minimum[category]) end
local mapped=0; for _ in pairs(ById) do mapped+=1 end
equal(mapped,itemCount,"Ids are globally unique")
equal(Cosmetics.Defaults.formation,"line"); equal(Cosmetics.Defaults.burst,"confetti")
equal(Cosmetics.Defaults.tag,"default"); equal(Cosmetics.Defaults.title,"")
for _,id in ipairs({"line","confetti","default"}) do check(ById[id] and ById[id].default==true,"Default item "..id) end
for category,list in pairs(Cosmetics.ByCategory) do
	local names={}
	for _,item in ipairs(list) do
		equal(item.category,category,"ByCategory "..item.id)
		check(not names[item.name],"Unique name in "..category..": "..item.name); names[item.name]=true
	end
end

local function rgb(c)
	if type(c)~="table" or #c~=3 then return false end
	for _,v in ipairs(c) do if type(v)~="number" or v%1~=0 or v<0 or v>255 then return false end end
	return true
end
local function channel(v) v=v/255; return if v<=0.03928 then v/12.92 else ((v+0.055)/1.055)^2.4 end
local function luminance(c) return 0.2126*channel(c[1])+0.7152*channel(c[2])+0.0722*channel(c[3]) end
local function contrast(a,b) local x,y=luminance(a),luminance(b); if x<y then x,y=y,x end; return (x+0.05)/(y+0.05) end
local shapes={}; for _,s in ipairs(Cosmetics.BurstShapes) do shapes[s]=true end
for _,f in ipairs(Cosmetics.Formations) do check(type(f.description)=="string" and #f.description>0,"Formation description "..f.id) end
for _,b in ipairs(Cosmetics.Bursts) do
	check(shapes[b.shape],"Burst shape "..tostring(b.shape))
	check(type(b.colors)=="table" and #b.colors>=2 and #b.colors<=4,"2-4 burst colors: "..b.id)
	for _,c in ipairs(b.colors) do check(rgb(c),"Burst RGB "..b.id); check(math.max(c[1],c[2],c[3])>=170,"Luminous burst color "..b.id) end
	check(b.count%1==0 and b.count>=6 and b.count<=24,"Burst count bounded "..b.id)
	check(b.speed>=4 and b.speed<=16,"Burst speed bounded "..b.id)
end
local achievementTags=0
for _,tag in ipairs(Cosmetics.Tags) do
	check(rgb(tag.text) and rgb(tag.stroke),"Tag RGB "..tag.id)
	check(tag.frame==nil or rgb(tag.frame),"Tag frame RGB "..tag.id)
	check(type(tag.frameTransparency)=="number" and tag.frameTransparency>=0.2 and tag.frameTransparency<=1,"Frame transparency "..tag.id)
	check(contrast(tag.text,tag.stroke)>=4.5,string.format("Text/stroke contrast %.2f for %s",contrast(tag.text,tag.stroke),tag.id))
	if tag.frame and tag.frameTransparency<1 then
		check(contrast(tag.text,tag.frame)>=3,string.format("Text/frame contrast %.2f for %s",contrast(tag.text,tag.frame),tag.id))
	end
	check(luminance(tag.text)>=0.45,"Bright tag text "..tag.id)
	if tag.achievement then achievementTags+=1 end
end
check(ById.default.frame==nil and ById.default.frameTransparency==1,"Default tag has no frame")
check(achievementTags>=3,"At least 3 achievement-only tags")
for _,id in ipairs({"golden_10","radiant_medal","heat_5_gold"}) do
	local found=false
	for _,tag in ipairs(Cosmetics.Tags) do if tag.achievement==id then found=true end end
	check(found,"Achievement tag for "..id)
end
local achievementTitles={}
for _,a in ipairs(Progression.Achievements) do if a.title then achievementTitles[a.title]=true end end
for _,title in ipairs(Cosmetics.RankTitles) do check(not achievementTitles[title.name],"Rank title distinct from achievement titles: "..title.name) end

-- Price sink -------------------------------------------------------------------
local sink,priced,sinkBy,highestGate=0,0,{formation=0,burst=0,tag=0,title=0},0
for _,item in ipairs(Cosmetics.Items) do
	if item.price then
		sink+=item.price; priced+=1; sinkBy[item.category]+=item.price
		highestGate=math.max(highestGate,item.rank or 0)
	end
end
check(sink>=60000,"Price sink "..sink.." >= 60,000")
equal(Cosmetics.TotalPrice,sink,"TotalPrice")
check(highestGate>=45,"A late rank-gated sink keeps glow meaningful past ~25 h (gate "..highestGate..")")

-- Rank rewards -------------------------------------------------------------------
local R=Cosmetics.RankRewards
check(R[1]==nil and R[51]==nil,"Rewards only for ranks 2..50")
local kinds={perk=true,slot=true,trail=true,formation=true,burst=true,tag=true,title=true,glow=true}
local glowOnly,totalRewards,glowTotal,rankTitles=0,0,0,0
local where={}
for rank=2,Progression.MaxRank do
	local list=R[rank]
	check(type(list)=="table" and #list>0,"Rank "..rank.." grants something")
	local allGlow=true
	for _,reward in ipairs(list) do
		totalRewards+=1
		check(kinds[reward.kind],"Reward kind "..tostring(reward.kind))
		check(type(reward.name)=="string" and #reward.name>0,"Reward display name")
		if reward.kind~="glow" then allGlow=false end
		if reward.kind=="glow" then equal(reward.amount,rank*25,"Glow gift amount at "..rank); glowTotal+=reward.amount
		elseif reward.kind=="perk" then check(Loadout.ById[reward.id] and Loadout.ById[reward.id].rank==rank,"Perk reward id")
		elseif reward.kind=="trail" then check(Progression.TrailById[reward.id] and Progression.TrailById[reward.id].rank==rank,"Trail reward id")
		elseif reward.kind=="slot" then equal(reward.amount,Loadout.slots(rank),"Slot count")
		else
			local item=ById[reward.id]
			check(item and item.category==reward.kind and item.rank==rank and not item.price and not item.achievement,"Cosmetic reward "..tostring(reward.id))
			if reward.kind=="title" then rankTitles+=1 end
		end
		if reward.id then where[reward.kind..":"..reward.id]=rank end
	end
	if allGlow then glowOnly+=1 end
end
check(glowOnly<=4,"At most 4 glow-only ranks ("..glowOnly..")")
check(rankTitles>=8,"At least 8 rank titles in the table")
for _,perk in ipairs(Loadout.Perks) do equal(where["perk:"..perk.id],perk.rank,"Perk "..perk.id.." in table") end
local slotRanks={}
for rank=2,50 do for _,reward in ipairs(R[rank]) do if reward.kind=="slot" then table.insert(slotRanks,rank) end end end
check(#slotRanks==1 and slotRanks[1]==15 and Loadout.slots(15)==3 and Loadout.slots(14)==2,"Third slot at rank 15 only")
for _,trail in ipairs(Progression.Trails) do
	if trail.rank and not trail.price and not trail.achievement then equal(where["trail:"..trail.id],trail.rank,"Rank trail "..trail.id) end
	if trail.price or trail.achievement then check(where["trail:"..trail.id]==nil,"Priced/achievement trail not a free rank reward: "..trail.id) end
end
for _,item in ipairs(Cosmetics.Items) do
	if item.rank and not item.price and not item.achievement then equal(where[item.category..":"..item.id],item.rank,"Rank cosmetic "..item.id.." in table")
	else check(where[item.category..":"..item.id]==nil,"Non-rank item absent from rank table: "..item.id) end
end
for rank=25,45,5 do
	local premium=false
	for _,reward in ipairs(R[rank]) do
		if (reward.kind=="formation" or reward.kind=="burst" or reward.kind=="tag") and reward.premium then premium=true end
	end
	check(premium,"Premium cosmetic at rank "..rank)
end
equal(where["trail:legend"],50,"Rank 50 gives Legend Stream")

-- unlocksBetween / glowBetween
local all=Cosmetics.unlocksBetween(1,50)
equal(#all,totalRewards,"unlocksBetween(1,50) covers every reward")
for rank=2,50 do
	local step=Cosmetics.unlocksBetween(rank-1,rank)
	equal(#step,#R[rank],"Per-rank callouts "..rank)
	for _,reward in ipairs(R[rank]) do check(table.find(all,reward.name),"Callout listed: "..reward.name) end
end
for _,legacy in ipairs(Progression.unlocksBetween(1,50)) do check(table.find(all,legacy),"Legacy callout kept: "..legacy) end
local early=Cosmetics.unlocksBetween(1,15)
check(table.find(early,"Perk: Long Reach") and table.find(early,"Third perk slot") and table.find(early,"Trail: Lagoon"),"Legacy strings")
equal(#Cosmetics.unlocksBetween(7,7),0,"No change, no callouts"); equal(#Cosmetics.unlocksBetween(50,1),0,"Backwards is empty")
equal(#Cosmetics.unlocksBetween(0,1e9),totalRewards,"Clamped range")
equal(#Cosmetics.unlocksBetween(0/0,"x"),0,"Garbage ranks are safe")
equal(Cosmetics.glowBetween(1,50),glowTotal,"glowBetween total"); equal(Cosmetics.glowBetween(10,10),0,"No glow without rank-up")

-- Rank-only items unlock exactly at their rank.
for _,item in ipairs(Cosmetics.Items) do
	if item.rank and not item.price and not item.achievement then
		check(Cosmetics.isUnlocked({xp=Progression.xpFor(item.rank)},item),"Unlocked at rank "..item.rank..": "..item.id)
		check(not Cosmetics.isUnlocked({xp=Progression.xpFor(item.rank)-1},item),"Locked below rank: "..item.id)
	end
end

-- Formation geometry -----------------------------------------------------------
local B=Cosmetics.FormationBounds
local times={0,0.05,0.37,1,2.5,7.77,13.1,59.9,1234.5,1000000.3}
local function inBounds(o,label)
	check(o.x==o.x and o.y==o.y and o.z==o.z and math.abs(o.x)<math.huge and math.abs(o.y)<math.huge,"Finite "..label)
	local d=math.sqrt(o.x*o.x+o.z*o.z)
	check(d>=B.minDistance-EPS and d<=B.maxDistance+EPS,string.format("Distance %.3f in band: %s",d,label))
	check(o.z>=B.minZ-EPS,string.format("Never in front beyond -1.5 (z=%.3f): %s",o.z,label))
	check(o.y>=B.minY-EPS and o.y<=B.maxY+EPS,string.format("Height %.3f bounded: %s",o.y,label))
	check(o[1]==o.x and o[2]==o.y and o[3]==o.z,"Array form matches: "..label)
end
local function dist(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local minSpacing,maxStep=math.huge,0
for _,f in ipairs(Cosmetics.Formations) do
	for count=1,12 do
		for _,reduced in ipairs({false,true}) do
			local staticRef={}
			for _,t in ipairs(times) do
				local ring={}
				for index=1,count do
					local label=f.id.." "..index.."/"..count.." t="..t..(if reduced then " reduced" else "")
					local o=Cosmetics.formationOffset(f.id,index,count,t,reduced)
					inBounds(o,label)
					local again=Cosmetics.formationOffset(f.id,index,count,t,reduced)
					check(again.x==o.x and again.y==o.y and again.z==o.z,"Deterministic: "..label)
					local x,y,z=Cosmetics.formationXYZ(f.id,index,count,t,reduced)
					check(x==o.x and y==o.y and z==o.z,"XYZ matches table: "..label)
					if reduced then
						if staticRef[index] then check(dist(staticRef[index],o)==0,"Reduced motion is static: "..label) else staticRef[index]=o end
					else
						local later=Cosmetics.formationOffset(f.id,index,count,t+0.05,false)
						local step=dist(o,later); maxStep=math.max(maxStep,step)
						check(step<=0.35,string.format("Gentle motion (%.3f studs per 50 ms): %s",step,label))
					end
					for _,other in ipairs(ring) do
						local gap=dist(o,other); minSpacing=math.min(minSpacing,gap)
						check(gap>=0.5,string.format("Followers do not overlap (%.3f): %s",gap,label))
					end
					table.insert(ring,o)
				end
			end
		end
	end
	local moved=false
	for index=1,6 do if dist(Cosmetics.formationOffset(f.id,index,6,0.5,false),Cosmetics.formationOffset(f.id,index,6,1.5,false))>0.05 then moved=true end end
	check(moved,"Formation animates when motion is allowed: "..f.id)
end
-- Every formation reads differently.
for a=1,#Cosmetics.Formations do
	for b=a+1,#Cosmetics.Formations do
		local fa,fb,total=Cosmetics.Formations[a].id,Cosmetics.Formations[b].id,0
		for index=1,8 do total+=dist(Cosmetics.formationOffset(fa,index,8,0,true),Cosmetics.formationOffset(fb,index,8,0,true)) end
		check(total>2,"Distinct shapes "..fa.." vs "..fb)
	end
end
-- The default line keeps the legacy client parade offsets (reduced motion, <= 5 followers).
for count=1,5 do
	for index=1,count do
		local o=Cosmetics.formationOffset("line",index,count,0,true)
		check(math.abs(o.x-(index%2*2-1)*1.7)<EPS and math.abs(o.y+1)<EPS and math.abs(o.z-(2+index*1.15))<EPS,"Legacy line "..index.."/"..count)
	end
end
-- Garbage input never errors or escapes the band.
local fallback=Cosmetics.formationOffset("nope",3,6,2,true)
local line=Cosmetics.formationOffset("line",3,6,2,true)
check(dist(fallback,line)==0,"Unknown formation falls back to line")
for _,args in ipairs({{nil,0,0},{{},-5,0/0},{"orbit",100,50},{"heart",0/0,1e9},{"star",2,3,math.huge},{"spiral",2,3,-math.huge},{"bloom","x","y","z"}}) do
	inBounds(Cosmetics.formationOffset(args[1],args[2],args[3],args[4],false),"garbage "..tostring(args[1]))
end

-- Equip / buy flows --------------------------------------------------------------
do
	local p={xp=0,coins=0,achievements={}}
	check(Cosmetics.isUnlocked(p,ById.line) and Cosmetics.isUnlocked(p,"confetti") and Cosmetics.isUnlocked(p,"default"),"Defaults unlocked")
	check(not Cosmetics.isUnlocked(p,ById.zigzag),"Rank item locked at rank 1")
	check(not Cosmetics.isUnlocked(p,{id="bloom",default=true}),"Forged item tables are rejected")
	local ok,message,paid=Cosmetics.equip(p,"formation","zigzag")
	check(not ok and paid==0 and string.find(message,"rank 7",1,true),"Rank gate message: "..message)
	p.xp=Progression.xpFor(7)
	ok,message,paid=Cosmetics.equip(p,"formation","zigzag")
	check(ok and paid==0 and p.cosmetics.formation=="zigzag" and p.coins==0,"Rank item equips free: "..message)
	equal(p.cosmetics.burst,"confetti","Missing cosmetics default in place"); equal(p.cosmetics.tag,"default"); equal(p.cosmetics.title,"")
	-- wrong category / unknown ids / bad categories change nothing
	for _,args in ipairs({{"burst","zigzag"},{"formation","hack"},{"formation",nil},{"formation",42},{"weird","line"},{"owned","heart"},{nil,"line"},{"title","stampede"},{"formation","sunbeam"}}) do
		ok,message,paid=Cosmetics.equip(p,args[1],args[2])
		check(not ok and paid==0 and p.cosmetics.formation=="zigzag" and p.coins==0,"Refused: "..tostring(args[1]).."/"..tostring(args[2]).." ("..message..")")
	end
	ok=Cosmetics.equip(nil,"formation","line"); check(not ok,"No profile")
	-- guaranteed price purchase
	p.coins=2499
	ok,message,paid=Cosmetics.equip(p,"formation","heart")
	check(not ok and paid==0 and p.coins==2499 and not p.cosmetics.owned.heart and p.cosmetics.formation=="zigzag","Cannot afford: "..message)
	p.coins=2500
	ok,message,paid=Cosmetics.equip(p,"formation","heart")
	check(ok and paid==2500 and p.coins==0 and p.cosmetics.owned.heart and p.cosmetics.formation=="heart","Bought at guaranteed price: "..message)
	check(Cosmetics.equip(p,"formation","line") and p.cosmetics.formation=="line","Back to default")
	ok,message,paid=Cosmetics.equip(p,"formation","heart")
	check(ok and paid==0 and p.coins==0,"Re-equip owned item is free")
	-- rank-gated priced item
	p.coins=1000000
	ok,message,paid=Cosmetics.equip(p,"formation","bloom")
	check(not ok and paid==0 and p.coins==1000000 and string.find(message,"rank 42",1,true),"Rank-gated price item: "..message)
	p.xp=Progression.xpFor(42)
	ok,message,paid=Cosmetics.equip(p,"formation","bloom")
	check(ok and paid==12000 and p.coins==988000,"Rank-gated purchase after rank")
	-- achievement items
	ok,message,paid=Cosmetics.equip(p,"tag","goldrush")
	check(not ok and paid==0 and p.coins==988000 and string.find(message,"Gold Rush",1,true),"Achievement gate: "..message)
	p.achievements.golden_10=true
	ok,message,paid=Cosmetics.equip(p,"tag","goldrush")
	check(ok and paid==0 and p.cosmetics.tag=="goldrush" and p.coins==988000,"Achievement tag equips free")
	-- coins never negative or trusted when malformed
	for _,bad in ipairs({0/0,-50,"999999",math.huge,-math.huge}) do
		local q={xp=0,coins=bad,achievements={}}
		ok,message,paid=Cosmetics.equip(q,"burst","heartflutter")
		local unchanged=q.coins==bad or (q.coins~=q.coins and bad~=bad)
		check(not ok and paid==0 and unchanged and (q.cosmetics==nil or not q.cosmetics.owned.heartflutter),"Malformed coins cannot buy: "..tostring(bad))
	end
	local f={xp=0,coins=1500.9,achievements={}}
	ok,message,paid=Cosmetics.equip(f,"burst","heartflutter")
	check(ok and paid==1500 and f.coins==0,"Fractional coins floor, never negative")
	-- titles
	ok,message=Cosmetics.equip(p,"title","title_rookie")
	check(ok and Cosmetics.titleText(p)=="Rookie Wrangler","Rank title equips: "..message)
	ok=Cosmetics.equip(p,"title","title_legend"); check(not ok and p.cosmetics.title=="title_rookie","Rank 50 title locked")
	ok=Cosmetics.equip(p,"title",""); check(ok and p.cosmetics.title=="" and Cosmetics.titleText(p)=="","Title cleared")
	ok=Cosmetics.equip(p,"tag",""); check(not ok,"Empty id only clears titles")
	equal(Cosmetics.titleText({cosmetics={title="title_legend"},xp=0}),"","Unearned title shows nothing")
	equal(Cosmetics.titleText(nil),""); equal(Cosmetics.titleText({cosmetics={title=5}}),"")
	-- owned flags only count for priced items
	check(not Cosmetics.isUnlocked({xp=0,cosmetics={owned={orbit=true,goldrush=true}}},"orbit"),"Owned flag cannot unlock rank items")
	check(not Cosmetics.isUnlocked({xp=0,cosmetics={owned={goldrush=true}},achievements={}},"goldrush"),"Owned flag cannot unlock achievement items")
	-- resolve
	equal(Cosmetics.resolve("burst","nope"),ById.confetti,"Resolve falls back"); equal(Cosmetics.resolve("burst","zigzag"),ById.confetti,"Resolve checks category")
	equal(Cosmetics.resolve("formation","orbit"),ById.orbit); equal(Cosmetics.resolve("title",""),nil); equal(Cosmetics.resolve("nope","line"),nil)
	equal(Cosmetics.category("nope"),nil); equal(Cosmetics.category(nil),nil)
end

-- Sanitize and stripUnearned ------------------------------------------------------
do
	local evil={owned={heart=true,orbit=true,legend=true,sunbeam=true,fake=true,bloom="yes",spiral=1,[1]=true,diamondframe=true},
		formation="hack",burst="zigzag",tag=123,title="stampede",extra=string.rep("x",1000)}
	local clean=Cosmetics.sanitize(evil)
	local ownedCount=0; for _ in pairs(clean.owned) do ownedCount+=1 end
	check(clean.owned.heart and clean.owned.diamondframe and ownedCount==2,"Owned whitelisted to priced cosmetics")
	equal(clean.formation,"line"); equal(clean.burst,"confetti","Wrong-category equip dropped"); equal(clean.tag,"default"); equal(clean.title,"")
	local keys=0; for _ in pairs(clean) do keys+=1 end
	equal(keys,5,"Only known fields survive")
	clean.owned.bloom=true; check(evil.owned.bloom=="yes","Sanitize returns fresh tables")
	local valid=Cosmetics.sanitize({owned={heart=true,royalframe=true},formation="heart",burst="halorings",tag="royalframe",title="title_captain"})
	check(valid.owned.heart and valid.owned.royalframe and valid.formation=="heart" and valid.burst=="halorings"
		and valid.tag=="royalframe" and valid.title=="title_captain","Valid data kept (unlocks checked separately)")
	for _,raw in ipairs({nil,"x",5,{owned="x"},{owned={heart="true"}}}) do
		local d=Cosmetics.sanitize(raw)
		check(d.formation=="line" and d.burst=="confetti" and d.tag=="default" and d.title=="" and next(d.owned)==nil,"Defaults for "..tostring(raw))
	end
	local p={xp=Progression.xpFor(10),coins=0,achievements={},
		cosmetics=Cosmetics.sanitize({owned={heart=true},formation="heart",burst="halorings",tag="goldrush",title="title_wrangler"})}
	check(Cosmetics.stripUnearned(p),"Something stripped")
	check(p.cosmetics.formation=="heart","Owned priced formation kept")
	check(p.cosmetics.burst=="confetti","Rank-28 burst stripped at rank 10")
	check(p.cosmetics.tag=="default","Achievement tag stripped without achievement")
	check(p.cosmetics.title=="title_wrangler" and Cosmetics.titleText(p)=="Spark Wrangler","Earned rank title kept")
	check(not Cosmetics.stripUnearned(p),"Idempotent")
	local fresh={xp=0}
	check(not Cosmetics.stripUnearned(fresh) and fresh.cosmetics.formation=="line","Missing cosmetics become defaults")
	check(not Cosmetics.stripUnearned(nil),"Nil profile safe")
	local odd={xp=0,cosmetics={owned={},formation="bloom",burst="confetti",tag="default",title="title_rookie"}}
	check(Cosmetics.stripUnearned(odd) and odd.cosmetics.formation=="line" and odd.cosmetics.title=="","Unowned priced and unearned title stripped")
end

-- Report -------------------------------------------------------------------------
print(string.format("SparkCosmetics catalog: %d formations, %d bursts, %d tags, %d rank titles (%d items)",
	perCategory.formation,perCategory.burst,perCategory.tag,perCategory.title,itemCount))
print(string.format("SparkCosmetics price sink: %d glow over %d priced items (formations %d, bursts %d, tags %d); highest rank gate %d",
	sink,priced,sinkBy.formation,sinkBy.burst,sinkBy.tag,highestGate))
print(string.format("SparkCosmetics rank table: %d rewards over ranks 2-50, %d glow-only ranks (%d glow), min follower gap %.2f studs, max step %.3f studs/50ms",
	totalRewards,glowOnly,glowTotal,minSpacing,maxStep))
for rank=2,Progression.MaxRank do
	local names={}
	for _,reward in ipairs(R[rank]) do table.insert(names,reward.name..(if reward.premium then " [premium]" else "")) end
	print(string.format("  rank %2d: %s",rank,table.concat(names," | ")))
end
print("PASS SparkCosmetics: "..n.." assertions (catalog, rank rewards, formation geometry, equip/buy, sanitize; pure modules)")
