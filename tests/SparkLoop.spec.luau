-- WP-02: Loop.luau matches tools/loop_reference.py on every vector in
-- design/fable/data/test_vectors.json, plus 1,000 seeded random walks (no error, no NaN).
local Loop=require("../game/ReplicatedStorage/Spark/Loop")
local Tuning=require("../game/ReplicatedStorage/Spark/Design/Tuning")
local V=require("./vectors/loop_vectors")
local T=Loop.tuning(Tuning)
local assertions=0
local function check(condition,message) assertions+=1; assert(condition,message) end
local function equal(a,b,message) check(a==b,(message or "Mismatch")..": "..tostring(a).." ~= "..tostring(b)) end
local function near(a,b,tol,message) check(a~=nil and b~=nil and math.abs(a-b)<=tol,(message or "Mismatch")..": "..tostring(a).." vs "..tostring(b)) end
local function round1(v) return math.floor(v*10+0.5)/10 end

-- The vectors were generated with the same tuning the game reads.
for key,value in pairs(V.tuning) do equal(T[key],value,"tuning "..key.." matches the vectors") end

local function poly2(list,withG)
	local out={}
	for i,p in ipairs(list) do out[i]={x=p[1],z=p[2],g=if withG then (p[3] or 0) else 0} end
	return out
end

-- closure: replay the samples with the live head = the new sample.
for _,v in ipairs(V.closure) do
	local ribbon=Loop.new()
	local result
	for i,s in ipairs(v.samples) do
		Loop.push(ribbon,s[1],s[2],s[3],T)
		local poly,kind=Loop.tryClose(ribbon,T,{x=s[1],z=s[2],t=s[3],g=0})
		if poly then
			result={atSample=i-1,kind=kind,vertices=#poly,area=Loop.area(poly),perimeter=Loop.perimeter(poly)}
			break
		end
	end
	local e=v.expect
	if e.closes then
		check(result~=nil,v.name.." should close")
		equal(result.atSample,e.atSample,v.name.." atSample"); equal(result.kind,e.kind,v.name.." kind")
		equal(result.vertices,e.vertices,v.name.." vertices")
		near(result.area,e.area,0.1001,v.name.." area"); near(result.perimeter,e.perimeter,0.1001,v.name.." perimeter")
	else
		check(result==nil,v.name.." must not close")
	end
end
equal(#V.closure,13,"closure vector count")

-- containment
for _,v in ipairs(V.containment) do
	equal(Loop.contains(poly2(v.polygon),v.x,v.z,v.inflate),v.expect,"containment "..v.name)
end
equal(#V.containment,9)

-- validation
local function path4(list)
	local out={}
	for i,s in ipairs(list) do out[i]={x=s[1],z=s[2],t=s[3],g=s[4] or 0} end
	return out
end
for _,v in ipairs(V.validation) do
	local poly=poly2(v.polygon)
	local ok,reason,serverArea=Loop.validate(poly,path4(v.serverPath),v.now,v.ribbonStart,T)
	equal(ok,v.expect.ok,v.name.." ok"); equal(reason,v.expect.reason,v.name.." reason")
	if v.expect.serverArea then near(serverArea,v.expect.serverArea,0.1,v.name.." serverArea") else equal(serverArea,nil,v.name.." serverArea") end
	near(Loop.area(poly),v.expect.clientArea,0.1001,v.name.." clientArea")
end
equal(#V.validation,14)

-- resolution
local function creatures(list)
	local out={}
	for i,c in ipairs(list) do
		local h={}
		for j,s in ipairs(c.history) do h[j]={clock=s[1],x=s[2],z=s[3],g=s[4],catchable=s[5]} end
		out[i]={id=c.id,history=h}
	end
	return out
end
local function sameList(a,b,message)
	equal(#a,#b,message.." count")
	for i=1,#b do equal(a[i],b[i],message.." ["..i.."]") end
end
for _,v in ipairs(V.resolution) do
	local caught,escaped=Loop.resolve(poly2(v.polygon,true),creatures(v.creatures),v.viewClock,v.now,T)
	sameList(caught,v.expect.caught,v.name.." caught"); sameList(escaped,v.expect.escaped,v.name.." escaped")
end
equal(#V.resolution,7)

-- scoring
for _,v in ipairs(V.scoring) do
	local r=Loop.scoreLoop(v.values,v.techs,v.linksBefore,T,v.finale,v.carried)
	for _,key in ipairs({"points","links","multiplier","kept","overflow"}) do equal(r[key],v.expect[key],v.name.." "..key) end
end
equal(#V.scoring,9)
for _,v in ipairs(V.bank) do
	local points,mult=Loop.bankPoints(v.values,T)
	equal(points,v.expect.points,v.name.." points"); equal(mult,v.expect.multiplier,v.name.." multiplier")
end
equal(#V.bank,7)
for n,links in pairs(V.chain.linksForLoopSize) do equal(Loop.chainLinks(tonumber(n),T),links,"links for "..n) end
for k,mult in pairs(V.chain.multiplierAtLinks) do equal(Loop.chainMult(tonumber(k),T),mult,"multiplier at "..k) end
for n,window in pairs(V.chain.windowAfterLoopSize) do near(Loop.chainWindow(tonumber(n),T),window,1e-9,"window after "..n) end

-- TIGHT: pods by the server area; singles only with a species threshold.
check(Loop.isTight(3,140,T)); check(not Loop.isTight(3,149,T)); check(Loop.isTight(3,148,T))
check(not Loop.isTight(1,20,T),"a lone creature without a threshold is never TIGHT")
check(Loop.isTight(1,330,T,330)); check(not Loop.isTight(1,331,T,330))

-- Wire format round trip at 0.1-stud precision; malformed buffers refused.
do
	local poly={{x=1.24,z=-3.06},{x=10,z=0},{x=-75.55,z=72.01}}
	local back=Loop.decode(Loop.encode(poly))
	equal(#back,3)
	for i,p in ipairs(poly) do near(back[i].x,p.x,0.051,"x "..i); near(back[i].z,p.z,0.051,"z "..i) end
	equal(Loop.decode("nope"),nil); equal(Loop.decode(buffer.create(0)),nil)
	local bad=buffer.create(5); buffer.writeu8(bad,0,3)
	equal(Loop.decode(bad),nil,"length must match the count")
end

-- Truncate (ribbon cut) keeps only later points.
do
	local r=Loop.new()
	for i=0,10 do Loop.push(r,i*3,0,i*0.1,T) end
	Loop.truncate(r,0.5)
	check(#r>0 and r[1].t>0.5,"truncate drops points at or before the cut")
end

-- 1,000 seeded random walks: no error, no NaN in any polygon or score.
do
	local rng=Random and Random.new(7) or nil
	local seed=12345
	local function rand()
		if rng then return rng:NextNumber() end
		seed=(seed*1103515245+12345)%2147483648
		return seed/2147483648
	end
	local closed=0
	for walk=1,1000 do
		local ribbon=Loop.new()
		local x,z,heading,t=0,0,rand()*math.pi*2,0
		local turn=(rand()-0.5)*1.4
		for _=1,90 do
			heading+=turn*0.1+(rand()-0.5)*0.6
			local speed=if rand()<0.1 then 60 else 24
			x+=math.cos(heading)*speed*0.05; z+=math.sin(heading)*speed*0.05; t+=0.05
			Loop.push(ribbon,x,z,t,T,0)
			local poly,kind=Loop.tryClose(ribbon,T,{x=x,z=z,t=t,g=0})
			if poly then
				closed+=1
				check(kind=="snap" or kind=="cross","kind")
				check(#poly>=3 and #poly<=T.maxVertices,"vertex count in walk "..walk)
				local a,p=Loop.area(poly),Loop.perimeter(poly)
				check(a==a and p==p and a>=T.minArea and p>=T.minPerimeter,"finite area/perimeter in walk "..walk)
				local cx,cz=Loop.centroid(poly)
				check(cx==cx and cz==cz,"finite centroid")
				local back=Loop.decode(Loop.encode(poly))
				check(back~=nil and #back==#poly,"wire round trip in walk "..walk)
				local s=Loop.scoreLoop({3,4},{"SNAP"},0,T,false,0)
				check(s.points==s.points,"score finite")
				table.clear(ribbon)
			end
		end
	end
	check(closed>50,"random walks close loops ("..closed..")")
end
print("SparkLoop: "..assertions.." assertions passed")
