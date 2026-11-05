-- HerdNet wire format: round trip, quantization bounds, packet splitting, malformed
-- and corrupt input rejection, clamping and a seeded fuzz. Pure Luau buffers; no
-- RemoteEvent, network or engine is exercised here.
local HerdNet=require("../game/ReplicatedStorage/Spark/HerdNet")
local n=0
local function check(ok,message) n+=1; if not ok then error(message,2) end end
local TAU=2*math.pi
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function arc(a,b) local d=math.abs(a-b)%TAU; return math.min(d,TAU-d) end
local function clampQ(v) return math.clamp(math.floor(v*10+0.5),-32768,32767)/10 end

-- Constants ------------------------------------------------------------------
check(HerdNet.Version==1 and HerdNet.MaxPacketBytes==900 and HerdNet.HeaderBytes==8 and HerdNet.EntryBytes==10,"Wire constants")
check(HerdNet.EntriesPerPacket==89 and HerdNet.HeaderBytes+HerdNet.EntriesPerPacket*HerdNet.EntryBytes<=HerdNet.MaxPacketBytes
	and HerdNet.HeaderBytes+(HerdNet.EntriesPerPacket+1)*HerdNet.EntryBytes>HerdNet.MaxPacketBytes,"Packet capacity is maximal")
local bits={fleeing=1,dazed=2,golden=4,runner=8,startled=16,trial=32}
local count=0
for name,bit in pairs(HerdNet.Flags) do count+=1; check(bits[name]==bit,"Flag "..name) end
check(count==6,"Exactly six flags")

-- Basic round trip -------------------------------------------------------------
local sample={
	{id=1,x=12.34,z=-5.67,heading=1.0,flags=HerdNet.Flags.fleeing},
	{id=4294967295,x=0,z=0,heading=0,flags=255},
	{id=0,x=-41.95,z=43.05,heading=TAU-0.001,flags=HerdNet.Flags.golden+HerdNet.Flags.trial},
	{id=77,x=3,z=4,heading=-math.pi/2},
}
local packets=HerdNet.pack(2,12.25,sample)
check(#packets==1 and type(packets[1])=="buffer","Small herd fits one packet")
check(buffer.len(packets[1])==8+4*10,"Exact packet length")
local state,reason=HerdNet.unpack(packets[1])
check(state~=nil,"Round trip decodes: "..tostring(reason))
assert(state)
check(state.version==1 and state.arena==2 and state.clock==12.25,"Header round trip")
check(#state.entries==4,"Entry count")
for index,entry in ipairs(sample) do
	local got=state.entries[index]
	check(got.id==entry.id,"Exact id "..index)
	check(math.abs(got.x-entry.x)<=0.05+1e-9 and math.abs(got.z-entry.z)<=0.05+1e-9,"Position quantization "..index)
	check(arc(got.heading,entry.heading)<=TAU/256 and got.heading>=0 and got.heading<TAU,"Heading quantization "..index)
	check(got.flags==(entry.flags or 0),"Flags round trip (missing flags = 0) "..index)
end
check(HerdNet.has(state.entries[3].flags,"golden") and HerdNet.has(state.entries[3].flags,"trial")
	and not HerdNet.has(state.entries[3].flags,"dazed"),"Decoded flags readable")

-- Quantization sweep -------------------------------------------------------------
local sweep={}
for i=0,999 do
	table.insert(sweep,{id=i,x=-3000+i*6.0013,z=2999-i*5.9971,heading=-10+i*0.02003,flags=i%64})
end
for _,packet in ipairs(HerdNet.pack(9,1,sweep)) do
	local decoded=HerdNet.unpack(packet); assert(decoded)
	for _,got in ipairs(decoded.entries) do
		local src=sweep[got.id+1]
		check(math.abs(got.x-src.x)<=0.05+1e-9 and math.abs(got.z-src.z)<=0.05+1e-9,"Quantization error <= 0.05 studs")
		check(arc(got.heading,src.heading)<=TAU/256+1e-12,"Heading error <= 2pi/256")
		check(got.flags==src.flags,"Sweep flags")
	end
end
-- Worst case is exactly half a step: rounding never exceeds it.
local half=HerdNet.unpack(HerdNet.pack(1,0,{{id=1,x=0.05,z=-0.05,heading=TAU/512,flags=0}})[1]); assert(half)
check(math.abs(half.entries[1].x-0.05)<=0.05+1e-9 and math.abs(half.entries[1].z+0.05)<=0.05+1e-9,"Half-step rounding bounded")

-- Splitting -------------------------------------------------------------------------
local herd={}
for i=1,120 do table.insert(herd,{id=1000+i,x=(i%40)-20,z=(i%17)-8,heading=i*0.1,flags=i%32}) end
local split=HerdNet.pack(3,99.5,herd)
check(#split==2,"120 entries need two packets")
local recovered={}
for index,packet in ipairs(split) do
	check(buffer.len(packet)<=HerdNet.MaxPacketBytes,"Each packet <= 900 bytes")
	local decoded=HerdNet.unpack(packet); assert(decoded)
	check(decoded.arena==3 and decoded.clock==99.5,"Each packet carries full header")
	check(#decoded.entries==(if index==1 then 89 else 31),"Greedy split sizes")
	for _,entry in ipairs(decoded.entries) do table.insert(recovered,entry) end
end
check(#recovered==120,"All entries recovered")
for i=1,120 do
	check(recovered[i].id==1000+i,"Order preserved "..i)
	check(recovered[i].x==(i%40)-20 and recovered[i].z==(i%17)-8 and recovered[i].flags==i%32,"Split values exact "..i)
end
local function sized(k)
	local t={}
	for i=1,k do t[i]={id=i,x=0,z=0,heading=0} end
	return t
end
check(#HerdNet.pack(1,0,sized(89))==1 and #HerdNet.pack(1,0,sized(90))==2 and #HerdNet.pack(1,0,sized(178))==2
	and #HerdNet.pack(1,0,sized(179))==3,"Split boundaries")
local empty=HerdNet.pack(1,5,{})
check(#empty==1 and buffer.len(empty[1])==8,"Empty herd still sends one header-only packet")
local emptyState=HerdNet.unpack(empty[1]); assert(emptyState)
check(#emptyState.entries==0 and emptyState.clock==5,"Empty packet decodes")
check(#HerdNet.pack(1,0,nil)==1 and #HerdNet.pack(1,0,"herd")==1,"Non-table entries treated as empty herd")

-- Invalid arena / clock ------------------------------------------------------------
for _,bad in ipairs({0,256,-1,1.5,0/0,math.huge,"1",false}) do
	local result,why=HerdNet.pack(bad,0,sample)
	check(type(result)=="table" and #result==0 and type(why)=="string","Invalid arena packs nothing: "..tostring(bad))
end
for _,bad in ipairs({0/0,math.huge,-math.huge,1e300,"5",{}}) do
	local decoded=HerdNet.unpack(HerdNet.pack(1,bad,sample)[1]); assert(decoded)
	check(decoded.clock==0,"Unencodable clock becomes 0: "..tostring(bad))
end
local bigClock=HerdNet.unpack(HerdNet.pack(255,86399.37,sample)[1]); assert(bigClock)
check(bigClock.arena==255 and math.abs(bigClock.clock-86399.37)<0.01,"f32 clock precision over a day of seconds")

-- Malformed / corrupt buffers ----------------------------------------------------------
local good=HerdNet.pack(4,1,sample)[1]
local function copy(src,len)
	local out=buffer.create(len)
	buffer.copy(out,0,src,0,math.min(len,buffer.len(src)))
	return out
end
for _,bad in ipairs({nil,"packet",{},42,true,buffer}) do
	local result,why=HerdNet.unpack(bad)
	check(result==nil and why=="Not a buffer","Non-buffer rejected")
end
for len=0,7 do
	local result,why=HerdNet.unpack(buffer.create(len))
	check(result==nil and why=="Too short","Short buffer rejected "..len)
end
local truncated=copy(good,buffer.len(good)-1)
check(HerdNet.unpack(truncated)==nil,"Truncated packet rejected")
check(select(2,HerdNet.unpack(truncated))=="Length mismatch","Truncation reason")
local extended=copy(good,buffer.len(good)+1)
check(HerdNet.unpack(extended)==nil,"Trailing garbage rejected")
local wrongVersion=copy(good,buffer.len(good)); buffer.writeu8(wrongVersion,0,2)
check(select(2,HerdNet.unpack(wrongVersion))=="Wrong version","Wrong version rejected")
local zeroVersion=copy(good,buffer.len(good)); buffer.writeu8(zeroVersion,0,0)
check(HerdNet.unpack(zeroVersion)==nil,"Version zero rejected")
local overCount=copy(good,buffer.len(good)); buffer.writeu16(overCount,2,5)
check(select(2,HerdNet.unpack(overCount))=="Length mismatch","Count above payload rejected")
local underCount=copy(good,buffer.len(good)); buffer.writeu16(underCount,2,3)
check(select(2,HerdNet.unpack(underCount))=="Length mismatch","Count below payload rejected")
local hugeCount=copy(good,buffer.len(good)); buffer.writeu16(hugeCount,2,65535)
check(HerdNet.unpack(hugeCount)==nil,"Huge count rejected without allocation")
local zeroArena=copy(good,buffer.len(good)); buffer.writeu8(zeroArena,1,0)
check(select(2,HerdNet.unpack(zeroArena))=="Invalid arena","Arena zero rejected")
local nanClock=copy(good,buffer.len(good)); buffer.writef32(nanClock,4,0/0)
check(select(2,HerdNet.unpack(nanClock))=="Invalid clock","NaN clock rejected")
local infClock=copy(good,buffer.len(good)); buffer.writef32(infClock,4,math.huge)
check(HerdNet.unpack(infClock)==nil,"Infinite clock rejected")
local oversize=buffer.create(8+90*10); buffer.writeu8(oversize,0,1); buffer.writeu8(oversize,1,1); buffer.writeu16(oversize,2,90)
check(select(2,HerdNet.unpack(oversize))=="Too long","Packets above 900 bytes rejected")

-- Clamping ---------------------------------------------------------------------------------
local extreme=HerdNet.unpack(HerdNet.pack(1,0,{
	{id=1,x=1e6,z=-1e6,heading=0},
	{id=2,x=1e308,z=-1e308,heading=1e308},
	{id=3,x=3276.7,z=-3276.8,heading=-1e308},
	{id=4,x=3276.76,z=-3276.86,heading=7*TAU+0.5},
	{id=5,x=-0.04,z=0.04,heading=-0},
})[1]); assert(extreme)
local e=extreme.entries
check(#e==5,"Extreme finite entries are kept, not dropped")
check(e[1].x==3276.7 and e[1].z==-3276.8,"Large coordinates clamp to int16 range")
check(e[2].x==3276.7 and e[2].z==-3276.8,"Near-max doubles clamp without overflow")
check(e[3].x==3276.7 and e[3].z==-3276.8,"Exact range ends survive")
check(e[4].x==3276.7 and e[4].z==-3276.8,"Rounding past range end clamps")
check(e[5].x==0 and e[5].z==0,"Tiny values round to zero")
for _,entry in ipairs(e) do check(entry.heading>=0 and entry.heading<TAU and finite(entry.heading),"Huge headings reduce safely") end
check(arc(e[4].heading,0.5)<=TAU/256,"Multi-turn heading wraps")

-- Malformed entries skipped -------------------------------------------------------------
local mixed={
	{id=10,x=1,z=1,heading=0},
	{id=11,x=0/0,z=1,heading=0},
	{id=12,x=1,z=math.huge,heading=0},
	{id=13,x=1,z=1,heading=0/0},
	{id=14,x=1,z=1,heading=-math.huge},
	{id=-1,x=1,z=1,heading=0},
	{id=4294967296,x=1,z=1,heading=0},
	{id=1.5,x=1,z=1,heading=0},
	{id="15",x=1,z=1,heading=0},
	{id=0/0,x=1,z=1,heading=0},
	{id=16,x=1,z=1,heading=0,flags=256},
	{id=17,x=1,z=1,heading=0,flags=-1},
	{id=18,x=1,z=1,heading=0,flags=1.5},
	{id=19,x=1,z=1,heading=0,flags="1"},
	{id=20,x="1",z=1,heading=0},
	"not an entry",
	{x=1,z=1,heading=0},
	{id=21,x=2,z=-2,heading=1,flags=3},
}
local mixedPackets=HerdNet.pack(1,0,mixed)
check(#mixedPackets==1,"Mixed batch packs")
local kept=HerdNet.unpack(mixedPackets[1]); assert(kept)
check(#kept.entries==2 and kept.entries[1].id==10 and kept.entries[2].id==21,"Only well-formed entries kept, order preserved")
check(kept.entries[2].x==2 and kept.entries[2].z==-2 and kept.entries[2].flags==3,"Survivor intact")
local allBad=HerdNet.pack(1,0,{{id=1,x=0/0,z=0,heading=0}})
check(#allBad==1 and buffer.len(allBad[1])==8,"All-malformed batch is an empty packet, not an error")

-- lerpHeading / has --------------------------------------------------------------------------
local function near(a,b,message) check(arc(a,b)<1e-9,message.." ("..tostring(a).." vs "..tostring(b)..")") end
near(HerdNet.lerpHeading(0.1,TAU-0.1,0.5),0,"Shortest arc crosses zero (up)")
near(HerdNet.lerpHeading(TAU-0.1,0.1,0.5),0,"Shortest arc crosses zero (down)")
near(HerdNet.lerpHeading(0,math.pi/2,0.5),math.pi/4,"Plain interpolation")
near(HerdNet.lerpHeading(-math.pi/2,math.pi/2+0.2,0.5),math.pi+0.1,"Negative input takes the short way")
near(HerdNet.lerpHeading(1,2,0),1,"t=0 is a")
near(HerdNet.lerpHeading(1,2,1),2,"t=1 is b")
near(HerdNet.lerpHeading(1,2,-3),1,"t clamped low")
near(HerdNet.lerpHeading(1,2,9),2,"t clamped high")
near(HerdNet.lerpHeading(1,2,0/0),2,"Non-finite t snaps to b")
near(HerdNet.lerpHeading(0/0,2,0.5),2,"Non-finite a falls back to b")
near(HerdNet.lerpHeading(1,math.huge,0.5),1,"Non-finite b falls back to a")
check(HerdNet.lerpHeading(0/0,0/0,0.5)==0,"Both invalid -> 0")
near(HerdNet.lerpHeading(1e308,-1e308,0.5),HerdNet.lerpHeading(math.fmod(1e308,TAU),math.fmod(-1e308,TAU),0.5),"Huge finite angles safe")
for i=0,400 do
	local a,b,t=i*0.37-70,i*-0.53+40,(i%11)/10
	local h=HerdNet.lerpHeading(a,b,t)
	check(h>=0 and h<TAU,"Result normalized")
	check(arc(h,a)<=arc(a,b)*t+1e-9 and arc(h,b)<=arc(a,b)*(1-t)+1e-9,"Never takes the long way")
end
check(HerdNet.has(5,"fleeing") and HerdNet.has(5,"golden") and not HerdNet.has(5,"dazed"),"has decodes bits")
check(HerdNet.has(63,"trial") and HerdNet.has(63,"startled") and HerdNet.has(63,"runner"),"All flags readable")
check(not HerdNet.has(0,"fleeing") and not HerdNet.has(255,"bogus") and not HerdNet.has(255,nil) and not HerdNet.has(255,1),"Unknown names false")
check(not HerdNet.has(0/0,"fleeing") and not HerdNet.has(1.5,"fleeing") and not HerdNet.has(-1,"fleeing") and not HerdNet.has("1","fleeing"),"Malformed flags false")

-- Seeded fuzz: 2000 random batches ---------------------------------------------------------
math.randomseed(20261105)
local packetsSeen,entriesSeen,corruptRejected,corruptAccepted=0,0,0,0
for round=1,2000 do
	local arena=math.random(1,255)
	local clock=math.random()*100000
	local size=math.random(0,260)
	local batch,expected={},{}
	for i=1,size do
		local entry={id=math.random(0,65535)*65536+math.random(0,65535),x=(math.random()-0.5)*8000,z=(math.random()-0.5)*8000,
			heading=(math.random()-0.5)*40,flags=math.random(0,255)}
		local roll=math.random(1,20)
		if roll==1 then entry.x=0/0 elseif roll==2 then entry.id=-entry.id-1 elseif roll==3 then entry.heading=math.huge
		elseif roll==4 then entry.flags=256 else table.insert(expected,entry) end
		batch[i]=entry
	end
	local out=HerdNet.pack(arena,clock,batch)
	check(#out==math.max(1,math.ceil(#expected/89)),"Fuzz packet count "..round)
	local cursor=0
	for _,packet in ipairs(out) do
		packetsSeen+=1
		check(buffer.len(packet)<=900,"Fuzz packet size")
		local decoded=HerdNet.unpack(packet); assert(decoded,"Fuzz decode")
		check(decoded.arena==arena and math.abs(decoded.clock-clock)<=math.max(1e-6,clock*1e-7),"Fuzz header")
		for _,got in ipairs(decoded.entries) do
			cursor+=1; entriesSeen+=1
			local src=expected[cursor]
			check(src~=nil and got.id==src.id,"Fuzz order/id")
			check(got.x==clampQ(src.x) and got.z==clampQ(src.z),"Fuzz position (clamped quantization)")
			check(math.abs(got.x-math.clamp(src.x,-3276.8,3276.7))<=0.05+1e-9,"Fuzz error bound")
			check(arc(got.heading,src.heading)<=TAU/256+1e-9 and got.flags==src.flags,"Fuzz heading/flags")
		end
		-- Corrupt a copy: random truncation or byte flip must never throw.
		local len=buffer.len(packet)
		local bad=copy(packet,if round%2==0 then math.random(0,len) else len)
		if buffer.len(bad)>0 then
			local at=math.random(0,buffer.len(bad)-1)
			buffer.writeu8(bad,at,(buffer.readu8(bad,at)+math.random(1,255))%256)
		end
		local ok,result=pcall(HerdNet.unpack,bad)
		check(ok,"Corrupt input never throws")
		if result==nil then corruptRejected+=1 else
			corruptAccepted+=1
			check(buffer.len(bad)==8+#result.entries*10 and result.version==1 and result.arena>=1 and finite(result.clock),
				"Accepted corrupt packet is still structurally valid (payload byte flips are undetectable)")
		end
	end
	check(cursor==#expected,"Fuzz recovered every valid entry")
end
-- Random byte soup.
for _=1,2000 do
	local len=math.random(0,1000)
	local soup=buffer.create(len)
	for i=0,len-1 do buffer.writeu8(soup,i,math.random(0,255)) end
	if len>=1 and math.random()<0.5 then buffer.writeu8(soup,0,1) end
	local ok,result=pcall(HerdNet.unpack,soup)
	check(ok,"Byte soup never throws")
	check(result==nil or (len<=900 and len==8+#result.entries*10),"Byte soup accepted only when structurally valid")
end
print(string.format("PASS SparkHerdNet: %d assertions (pure buffer codec; %d fuzz packets, %d entries, %d/%d corrupt copies rejected/structurally-valid; no network)",
	n,packetsSeen,entriesSeen,corruptRejected,corruptAccepted))
