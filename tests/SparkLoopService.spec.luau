-- WP-04: server loop claims. Validation and resolution vectors through
-- LoopService, and the adversarial set (design/fable/10 section 6): every one
-- grants nothing and increments rejection telemetry.
local Loop=require("../game/ReplicatedStorage/Spark/Loop")
local Tuning=require("../game/ReplicatedStorage/Spark/Design/Tuning")
local Arenas=require("../game/ReplicatedStorage/Spark/Design/Arenas")
local LoopService=require("../game/ServerScriptService/Spark/LoopService")
local V=require("./vectors/loop_vectors")
local T=Loop.tuning(Tuning)
local assertions=0
local function check(c,m) assertions+=1; assert(c,m) end
local function equal(a,b,m) check(a==b,(m or "Mismatch")..": "..tostring(a).." ~= "..tostring(b)) end
local function poly2(list,withG)
	local out={}
	for i,p in ipairs(list) do out[i]={x=p[1],z=p[2],g=if withG then (p[3] or 0) else 0} end
	return out
end
local function pathOf(list)
	local out={}
	for i,s in ipairs(list) do out[i]={x=s[1],z=s[2],t=s[3],g=s[4] or 0} end
	return out
end
local function service() return LoopService.new(Loop,T,{rate=Tuning.ribbon.claimRateLimitPerSecond}) end

-- Validation vectors through the service; acceptance moves ribbonStart (no replay).
local rejectedVectors={}
for _,v in ipairs(V.validation) do
	local svc,sess=service(),LoopService.session()
	sess.path=pathOf(v.serverPath); sess.ribbonStart=v.ribbonStart
	local claim={poly=poly2(v.polygon),viewClock=0,arrivedAt=v.now}
	local ok,reason,serverArea=LoopService.validate(svc,sess,claim,v.now,nil,nil)
	equal(ok,v.expect.ok,v.name.." ok"); equal(reason,v.expect.reason,v.name.." reason")
	if ok then
		check(math.abs(serverArea-v.expect.serverArea)<=0.1001,v.name.." serverArea "..tostring(serverArea))
		equal(sess.ribbonStart,v.now,v.name.." ribbonStart moves to the accepted claim")
		equal(svc.telemetry.accepted,1)
		-- Replay of the same polygon: the path before ribbonStart can no longer prove it.
		local replay=LoopService.validate(svc,sess,{poly=poly2(v.polygon),viewClock=0,arrivedAt=v.now+0.2},v.now+0.2,nil,nil)
		equal(replay,false,v.name.." replay refused")
		check(svc.telemetry.rejected>=1,"replay counted")
		-- TIGHT comes from the server area, never the client polygon.
		if v.name=="corner_cut_allowed_not_tight" then
			check(Loop.area(poly2(v.polygon))<Loop.area(sess.path) and not Loop.isTight(3,serverArea,T),"shrunk claim does not earn TIGHT")
		end
	else
		equal(svc.telemetry.rejected,1,v.name.." rejection counted")
		equal(svc.telemetry.reasons[reason],1,v.name.." reason counted")
		table.insert(rejectedVectors,v.name)
	end
end
check(#rejectedVectors>=6,"six or more rejected validation vectors grant nothing ("..#rejectedVectors..")")

-- Resolution vectors through the service (clamped rewind, states, level rule).
for _,v in ipairs(V.resolution) do
	local svc=service()
	local candidates={}
	for i,c in ipairs(v.creatures) do
		local h={}
		for j,s in ipairs(c.history) do h[j]={clock=s[1],x=s[2],z=s[3],g=s[4],catchable=s[5]} end
		candidates[i]={id=c.id,history=h}
	end
	local viewClock=math.min(v.now,math.max(v.viewClock,v.now-T.viewClockMaxAge))
	local caught,escaped=LoopService.resolve(svc,{poly=poly2(v.polygon,true),viewClock=viewClock},candidates,v.now)
	local want={}
	for _,id in ipairs(v.expect.caught) do want[id]=true end
	equal(#caught,#v.expect.caught,v.name.." caught count")
	for _,id in ipairs(caught) do check(want[id],v.name.." caught "..id) end
	equal(#escaped,#v.expect.escaped,v.name.." escaped count")
end

-- Adversarial set: receive() shape checks, rate limit, clamped view clock.
do
	local svc,sess=service(),LoopService.session()
	local ring={}
	for i=0,23 do local a=i*math.pi/12; ring[i+1]={x=8*math.cos(a),z=8*math.sin(a)} end
	local good=Loop.encode(ring)
	for _,payload in ipairs({nil,"poly",{poly="x",kind="snap",viewClock=1},{poly=good,kind="teleport",viewClock=1},
		{poly=good,kind="snap",viewClock=0/0},{poly=good,kind="snap",viewClock=math.huge},{poly=good,kind="snap"}}) do
		local claim,reason=LoopService.receive(svc,sess,payload,10,50)
		check(claim==nil and reason=="malformed","malformed payload refused")
	end
	-- viewClock in the future clamps to now; 10 s in the past clamps to now - 0.35.
	local future=LoopService.receive(svc,sess,{poly=good,kind="snap",viewClock=80},10,50)
	equal(future.viewClock,50,"future viewClock clamped to now")
	local stale=LoopService.receive(svc,sess,{poly=good,kind="snap",viewClock=40},10.1,50)
	check(math.abs(stale.viewClock-(50-T.viewClockMaxAge))<1e-9,"stale viewClock clamped to now - 0.35")
	-- 500 claims in one second: only the rate limit's worth are even queued.
	local svc2,sess2=service(),LoopService.session()
	local queued=0
	for i=1,500 do
		if LoopService.receive(svc2,sess2,{poly=good,kind="snap",viewClock=1},20+i/1000,1) then queued+=1 end
	end
	equal(queued,Tuning.ribbon.claimRateLimitPerSecond,"500 claims in a second: 3 queued")
	check(svc2.telemetry.reasons["rate-limited"]==497,"rate-limited claims counted")
	-- With no server path (fresh teleport / intermission reset) nothing validates.
	LoopService.reset(svc2,sess2,21)
	for _,claim in ipairs(sess2.deferred) do check(false,"reset must drop deferred claims") end
	local ok,reason=LoopService.validate(svc2,sess2,{poly=Loop.decode(good)},21.2,nil,nil)
	check(not ok and reason=="no-path","no path after a server teleport: "..tostring(reason))
	-- Huge coordinates (i16 clamp) or another arena's coordinates are out of bounds.
	local far={}
	for i,p in ipairs(ring) do far[i]={x=p.x+3000,z=p.z} end
	local decoded=Loop.decode(Loop.encode(far))
	local ok2,reason2=LoopService.validate(svc2,sess2,{poly=decoded},21.3,Arenas.meadow.bounds,nil)
	check(not ok2 and reason2=="out-of-bounds","far polygon out of bounds: "..tostring(reason2))
end

-- Deferral: a claim waits for the server path to reach its last vertex (<= 0.25 s).
do
	local svc,sess=service(),LoopService.session()
	local ring={}
	for i=0,23 do local a=i*math.pi/12; ring[i+1]={x=8*math.cos(a),z=8*math.sin(a)} end
	local claim=LoopService.receive(svc,sess,{poly=Loop.encode(ring),kind="snap",viewClock=1},5,1)
	check(claim~=nil)
	equal(#LoopService.due(svc,sess,5.1),0,"held while the path has not reached the head")
	LoopService.record(svc,sess,ring[24].x,ring[24].z,5.12,0)
	equal(#LoopService.due(svc,sess,5.13),1,"released as soon as the path reaches the head")
	local claim2=LoopService.receive(svc,sess,{poly=Loop.encode(ring),kind="cross",viewClock=1},6,1)
	check(claim2~=nil)
	LoopService.record(svc,sess,40,40,6.05,0)
	equal(#LoopService.due(svc,sess,6.2),0)
	equal(#LoopService.due(svc,sess,6.26),1,"released at the 0.25 s deferral limit regardless")
end

-- SNAP from server arrival times; bank-ring crossing; path recording.
do
	local svc=service()
	check(LoopService.snap(svc,10,{arrivedAt=10.3}),"SNAP inside the window")
	check(LoopService.snap(svc,10,{arrivedAt=10.5}),"SNAP inside window + slack")
	check(not LoopService.snap(svc,10,{arrivedAt=10.6}),"no SNAP after window + slack")
	check(not LoopService.snap(svc,nil,{arrivedAt=10}),"no dash, no SNAP")
	local ring={x=0,z=58,r=5}
	check(LoopService.crossesRing(0,66,0,52,ring),"running through the ring banks")
	check(LoopService.crossesRing(4,66,4,52,ring),"through the edge of the ring banks")
	check(not LoopService.crossesRing(7,66,7,52,ring),"passing beside it does not")
	local sess=LoopService.session()
	check(LoopService.record(svc,sess,0,0,1,0)==nil,"first sample")
	check(LoopService.record(svc,sess,1,0,1.1,0)==nil and #sess.path==1,"samples under 2 studs are skipped")
	check(LoopService.record(svc,sess,2.5,0,1.2,0)~=nil and #sess.path==2,"sample appended")
	LoopService.record(svc,sess,10,0,9,0)
	check(sess.path[1].t>=3,"path keeps 6 s")
	local hist={}
	for i=0,20 do LoopService.pushHistory(hist,i*0.1,i,0,0,true) end
	check(#hist<=7 and hist[#hist].clock==2,"creature history keeps ~0.5 s")
	equal(LoopService.p99({1,2,3}),3)
end
-- T-L5 (unit): two loops over one creature. The first claim caught it; the second
-- claimant's ring held it too -> contested (ASSIST), never a second catch.
do
	local svc=service()
	local ring={}
	for i=0,23 do local a=i*math.pi/12; ring[i+1]={x=8*math.cos(a),z=8*math.sin(a),g=0} end
	local history={{clock=19.9,x=1,z=1,g=0,catchable=true},{clock=20,x=1,z=1,g=0,catchable=true}}
	local recent={[7]={by=1,at=100,biome=1,history=history}}
	local claim={poly=ring,viewClock=20}
	check(LoopService.contested(svc,recent,claim,2,1,100.4,20),"second claimant over the same creature is contested")
	check(not LoopService.contested(svc,recent,claim,1,1,100.4,20),"the catcher's own later loop is not a contest")
	check(not LoopService.contested(svc,recent,claim,2,2,100.4,20),"another arena is not a contest")
	local outside={{clock=20,x=30,z=30,g=0,catchable=true}}
	check(not LoopService.contested(svc,{[8]={by=1,at=100,biome=1,history=outside}},claim,2,1,100.4,20),"outside the ring is not a contest")
	check(not LoopService.contested(svc,recent,claim,2,1,101.2,20) and recent[7]==nil,"contest credit expires after 1 s")
end
print("SparkLoopService: "..assertions.." assertions passed")
