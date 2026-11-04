local Persistence = require("../game/ServerScriptService/Spark/Persistence")
local Profile = require("../game/ReplicatedStorage/Spark/Profile")
local tests=0
local function test(name,run) run();tests+=1;print("PASS "..name) end
local function fixture()
	local clock={now=1000}
	local store={values={},calls=0,failures=0,transforms=1}
	function store:UpdateAsync(key,fn)
		self.calls+=1
		if self.failures>0 then self.failures-=1;error("simulated transport failure") end
		local result
		for _=1,self.transforms do result=fn(self.values[key]) end
		if result~=nil then self.values[key]=result end
		return result
	end
	local function adapter(id)
		return Persistence.new(store,function()return clock.now end,{sessionId=id,retries=3})
	end
	return store,clock,adapter
end
test("new load save release and rejoin restore progression",function()
	local store,_,adapter=fixture(); local a=adapter("A")
	local p,s=a:load(123);assert(p and s=="ready")
	Profile.bank(p,{"pip","bunvolt","cubloom"});assert(a:save(123,p));assert(a:release(123,p))
	local restored,status=adapter("B"):load(123)
	assert(status=="ready" and restored.totalBanked==3 and restored.coins==15 and restored.album.cubloom==1)
	assert(store.values["player:123"].lease.id=="B")
end)
test("live lease excludes concurrent server; expiry permits safe takeover",function()
	local store,clock,adapter=fixture();local a,b=adapter("A"),adapter("B")
	local p=a:load(5);local q,status=b:load(5);assert(q==nil and status=="locked")
	clock.now=1121; q,status=b:load(5);assert(q and status=="ready")
	p.coins=999;local ok,why=a:save(5,p);assert(not ok and why=="lease-lost")
	assert(store.values["player:5"].data.coins==0)
end)
test("failed load never permits write or release overwrite",function()
	local store,_,adapter=fixture();store.failures=3;local a=adapter("A")
	local p,status=a:load(2);assert(p==nil and status=="unavailable" and store.calls==3)
	assert(not a:save(2,Profile.new()) and not a:release(2,Profile.new()))
	assert(store.calls==3 and store.values["player:2"]==nil)
end)
test("transient failures retry and updates tolerate repeated transform",function()
	local store,_,adapter=fixture();store.failures=2;store.transforms=3
	local a=adapter("A");local p=a:load(8);assert(p and store.calls==3)
	Profile.bank(p,{"pip"});assert(a:save(8,p));assert(store.values["player:8"].data.coins==3)
end)
test("corrupt and future records are never replaced",function()
	local store,_,adapter=fixture()
	for i,raw in ipairs({"corrupt",{version=3},{kind="SparkProfile",version=1},{kind="SparkProfile",version=1,data=Profile.new(),lease={id="x",expiresAt=math.huge}}}) do
		local key="player:"..i;store.values[key]=raw
		local a=adapter("A");local p=a:load(i);assert(p==nil and store.values[key]==raw)
		assert(not a:save(i,Profile.new()))
	end
end)
test("save failure preserves stored data and permits subsequent safe retry",function()
	local store,_,adapter=fixture();local a=adapter("A");local p=a:load(9)
	p.coins=100;store.failures=3;local ok,status=a:save(9,p)
	assert(not ok and status=="unavailable" and store.values["player:9"].data.coins==0)
	assert(a:save(9,p) and store.values["player:9"].data.coins==100)
end)
test("reentrant save cannot overwrite a pending write",function()
	local store,_,adapter=fixture();local a=adapter("A");local p=a:load(6)
	local original=store.UpdateAsync
	function store:UpdateAsync(key,fn)
		local ok,why=a:save(6,p);assert(not ok and why=="busy")
		return original(self,key,fn)
	end
	assert(a:save(6,p))
end)
test("release failure keeps lease; success is final and cannot be written again",function()
	local store,_,adapter=fixture();local a=adapter("A");local p=a:load(12)
	store.failures=3;assert(not a:release(12,p));assert(a:release(12,p))
	local calls=store.calls;assert(not a:save(12,p) and store.calls==calls)
end)
test("legacy profiles migrate; negative Studio ids work; invalid ids do not write",function()
	local store,_,adapter=fixture();local old=Profile.new();old.coins=34;store.values["player:-1"]=old
	local a=adapter("A");local p=a:load(-1);assert(p.coins==34 and store.values["player:-1"].kind=="SparkProfile")
	local calls=store.calls;assert(a:load("bad")==nil and a:load(0/0)==nil and a:load(2.5)==nil and store.calls==calls)
end)
test("expired local session cannot pretend a repeated load is ready",function()
	local _,clock,adapter=fixture();local a=adapter("A");assert(a:load(19))
	clock.now=1120;local p,status=a:load(19);assert(not p and status=="lease-lost")
end)
test("nil and future-version saves cannot replace a loaded profile",function()
	local store,_,adapter=fixture();local a=adapter("A");local p=a:load(20)
	p.coins=20;assert(a:save(20,p));local calls=store.calls
	assert(not a:save(20,nil) and not a:save(20,{version=3}))
	assert(store.calls==calls and store.values["player:20"].data.coins==20)
end)
test("load response arriving at expiry cannot create a writable session",function()
	local store,clock,adapter=fixture();local a=adapter("A");local original=store.UpdateAsync
	function store:UpdateAsync(key,fn)
		local result=original(self,key,fn);clock.now+=120;return result
	end
	local p,status=a:load(30)
	assert(p==nil and status=="lease-lost" and a:leaseDeadline(30)==nil)
	local calls=store.calls;assert(not a:save(30,Profile.new()) and store.calls==calls)
end)
test("renewal response arriving expired cannot confirm a new earning window",function()
	local store,clock,adapter=fixture();local a=adapter("A");local p=a:load(31)
	assert(a:leaseDeadline(31)==1120)
	clock.now=1030;local original=store.UpdateAsync
	function store:UpdateAsync(key,fn)
		local result=original(self,key,fn);clock.now+=121;return result
	end
	p.coins=9;local ok,status=a:save(31,p)
	assert(not ok and status=="lease-lost" and a:leaseDeadline(31)==nil)
	assert(store.values["player:31"].data.coins==9) -- write may have committed; lease is still unusable
	local calls=store.calls;assert(not a:save(31,p) and store.calls==calls)
end)
test("valid delayed responses expose only their remaining absolute lease",function()
	local store,clock,adapter=fixture();local a=adapter("A");local original=store.UpdateAsync
	function store:UpdateAsync(key,fn)
		local result=original(self,key,fn);clock.now+=40;return result
	end
	local p=a:load(32);assert(p and clock.now==1040 and a:leaseDeadline(32)==1120)
	assert(a:save(32,p) and clock.now==1080 and a:leaseDeadline(32)==1160)
end)
test("failed renewal cannot move the last acknowledged deadline",function()
	local store,clock,adapter=fixture();local a=adapter("A");local p=a:load(33)
	clock.now=1030;store.failures=3
	assert(not a:save(33,p) and a:leaseDeadline(33)==1120)
	assert(a:leaseDeadline("bad")==nil)
end)
test("server takeover during a delayed load is not overwritten",function()
	local store,clock,adapter=fixture();local a,b=adapter("A"),adapter("B")
	local original=store.UpdateAsync;local waiting=false
	function store:UpdateAsync(key,fn)
		local result=original(self,key,fn)
		if not waiting then
			waiting=true;clock.now+=121
			local p=b:load(34);assert(p);p.coins=77;assert(b:save(34,p))
		end
		return result
	end
	local p,status=a:load(34);assert(not p and status=="lease-lost")
	assert(store.values["player:34"].lease.id=="B" and store.values["player:34"].data.coins==77)
end)
test("late release acknowledgement is still final and creates no local lease",function()
	local store,clock,adapter=fixture();local a=adapter("A");local p=a:load(35);local original=store.UpdateAsync
	function store:UpdateAsync(key,fn)
		local result=original(self,key,fn);clock.now+=121;return result
	end
	local ok,status=a:release(35,p)
	assert(ok and status=="released" and a:leaseDeadline(35)==nil and store.values["player:35"].lease==nil)
end)
print(string.format("SparkPersistence: %d tests passed",tests))
