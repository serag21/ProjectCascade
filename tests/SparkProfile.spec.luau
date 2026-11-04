local Config = require("../game/ReplicatedStorage/Spark/Config")
local Profile = require("../game/ReplicatedStorage/Spark/Profile")
local tests = 0
local function test(name, run)
	run(); tests+=1; print("PASS " .. name)
end
test("content has twelve unique species, three arenas and distinct silhouettes",function()
	assert(#Config.Creatures==12 and #Config.Biomes==3)
	local ids, shapes = {}, {}
	for _, c in ipairs(Config.Creatures) do
		assert(not ids[c.id] and not shapes[c.shape]); ids[c.id]=true; shapes[c.shape]=true
		assert(c.biome>=1 and c.biome<=3 and c.value>0 and c.speed>0)
	end
end)
test("defaults do not share nested state",function()
	local a,b=Profile.new(),Profile.new(); a.album.pip=2; a.upgrades.boots=1
	assert(b.album.pip==nil and b.upgrades.boots==0)
end)
test("sanitization rejects future versions and non records",function()
	local p,s=Profile.sanitize({version=3}); assert(p==nil and s=="future-version")
	assert(Profile.sanitize("invalid")==nil)
end)
test("sanitization clamps malformed data and removes unknown keys/cycles",function()
	local raw={coins=0/0,totalBanked=-4,rounds=math.huge,album={pip=5.9,fake=300},
		upgrades={boots=90,magnet=-1,basket="5"},settings={sfx=false,music="yes"},quests={first_haul=true,fake=true},mutations={pip=900}}
	raw.self=raw
	local p=Profile.sanitize(raw)
	assert(p.coins==0 and p.totalBanked==0 and p.rounds==0 and p.album.pip==5 and not p.album.fake)
	assert(p.upgrades.boots==3 and p.upgrades.magnet==0 and p.upgrades.basket==0)
	assert(p.settings.sfx==false and p.settings.music==true and p.quests.first_haul and not p.quests.fake)
	assert(p.mutations.pip==1 and p.self==nil)
	raw.album.pip=700; assert(p.album.pip==5)
end)
test("banking awards value, trio bonus, discoveries and deterministic mutations",function()
	local p=Profile.new()
	local reward,new=Profile.bank(p,{"pip","pip","bunvolt","fake",{}})
	assert(reward==13 and new==2 and p.totalBanked==3 and p.album.pip==2)
	Profile.bank(p,{"pip","pip","pip"}); assert(p.mutations.pip==1)
	local catches={}; for _=1,10 do table.insert(catches,"pip") end
	Profile.bank(p,catches); assert(p.mutations.pip==2 and p.album.pip==15)
end)
test("upgrades debit once and enforce valid keys costs and level cap",function()
	local p=Profile.new(); assert(not Profile.buy(p,"boots")); assert(not Profile.buy(p,{}))
	p.coins=1000
	for _=1,3 do assert(Profile.buy(p,"boots")) end
	local total=0; for _,cost in ipairs(Config.Upgrades.boots.costs) do total+=cost end
	assert(p.coins==1000-total and p.upgrades.boots==3 and not Profile.buy(p,"boots"))
end)
test("quests cannot claim early or twice and derive collection goals",function()
	local p=Profile.new(); assert(not Profile.claim(p,"first_haul"))
	Profile.bank(p,{"pip","pip","pip"}); local coins=p.coins
	assert(Profile.claim(p,"first_haul") and p.coins==coins+10)
	assert(not Profile.claim(p,"first_haul") and p.coins==coins+10)
	assert(not Profile.claim(p,"invented") and not Profile.claim(p,{}))
	for _,c in ipairs(Config.Creatures) do p.album[c.id]=1 end
	assert(Profile.claim(p,"complete_album"))
end)
test("balances and counts remain bounded",function()
	local p=Profile.new(); p.coins=2000000000; p.totalBanked=1000000; p.album.pip=1000000
	local reward=Profile.bank(p,{"pip"}); assert(reward==0 and p.coins==2000000000 and p.totalBanked==1000000 and p.album.pip==1000000)
	assert(Profile.claim(p,"first_haul") and p.coins==2000000000)
end)
print(string.format("SparkProfile: %d tests passed",tests))
