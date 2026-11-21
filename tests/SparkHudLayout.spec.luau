-- WP-07 (T-UI1): HUD v2 placements reproduce ui_layout.json at the three
-- reference viewports exactly; no overlap between elements or with reserved
-- Roblox controls; persistent coverage <= 9 %. Plus the slice cue wiring:
-- every one of the 22 slice cues resolves to its asset or its named fallback.
local Hud=require("../game/StarterPlayer/StarterPlayerScripts/Spark/Hud")
local Sfx=require("../game/StarterPlayer/StarterPlayerScripts/Spark/Sfx")
local Overlay=require("../game/StarterPlayer/StarterPlayerScripts/Spark/Overlay")
local Coach=require("../game/StarterPlayer/StarterPlayerScripts/Spark/Coach")
local LoopFx=require("../game/StarterPlayer/StarterPlayerScripts/Spark/LoopFx")
local UiLayout=require("../game/ReplicatedStorage/Spark/Design/UiLayout")
local Slice=require("../game/ReplicatedStorage/Spark/Design/Slice")
local Tuning=require("../game/ReplicatedStorage/Spark/Design/Tuning")
local Catalog=require("../game/ReplicatedStorage/Spark/AudioCatalog")
local assertions=0
local function check(c,m) assertions+=1; assert(c,m) end
local function equal(a,b,m) check(a==b,(m or "Mismatch")..": "..tostring(a).." ~= "..tostring(b)) end
local function overlap(a,b) return a[1]<b[1]+b[3] and b[1]<a[1]+a[3] and a[2]<b[2]+b[4] and b[2]<a[2]+a[4] end
local transient={}
for _,e in ipairs(UiLayout.elements) do if e.transient then transient[e.id]=true end end
for name,vp in pairs(UiLayout.viewports) do
	local W,H=vp.size[1],vp.size[2]
	local placed,area={},0
	for id,rect in pairs(vp.rects) do
		local p=Hud.place(UiLayout,name,id)
		check(p~=nil,name.." places "..id)
		local abs=Hud.absolute(p,W,H)
		for i=1,4 do check(math.abs(abs[i]-rect[i])<1e-9,name.." "..id.." rect["..i.."] equals ui_layout.json") end
		-- Anchored placement holds at a different screen size (same offsets from its anchor).
		local wide=Hud.absolute(p,W+200,H+100)
		check(wide[3]==rect[3] and wide[4]==rect[4],"size independent of screen")
		placed[id]=abs
		if not transient[id] then area+=abs[3]*abs[4] end
		for _,r in pairs(vp.reserved or {}) do check(not overlap(abs,r),name.." "..id.." clears reserved controls") end
	end
	for a,ra in pairs(placed) do
		for b,rb in pairs(placed) do
			-- chain sits under score by design (same column, no pixel overlap).
			if a<b then check(not overlap(ra,rb),name.." "..a.." vs "..b.." overlap") end
		end
	end
	check(area/(W*H)<=UiLayout.rules.maxCoverage+1e-9,string.format("%s persistent coverage %.3f",name,area/(W*H)))
end
equal(Hud.viewportFor(1280,684,false),"desktop_1280x684"); equal(Hud.viewportFor(756,354,true),"phone_756x354")
equal(Hud.viewportFor(1024,732,true),"tablet_1024x732")
equal(Hud.clock(65),"1:05"); equal(Hud.clock(0.2),"0:01")
equal(Hud.bankTier(Tuning.parade.bankMultiplier,4),1.25); equal(Hud.bankTier(Tuning.parade.bankMultiplier,12),2)
-- Toasts: one visible, queue of 3, 1.6 s each.
local q=Hud.newToasts()
equal(Hud.pushToast(q,"a",0),"a"); Hud.pushToast(q,"b",0); Hud.pushToast(q,"c",0); Hud.pushToast(q,"d",0); Hud.pushToast(q,"e",0)
equal(#q.queue,3,"queue max 3"); equal(Hud.stepToast(q,1.5),"a"); equal(Hud.stepToast(q,1.7),"c","oldest dropped when full")

-- Cue wiring: every slice cue resolves; new WAVs and existing ones map to catalog files.
local resolved=Sfx.resolve(Slice.cues,Catalog)
local count=0
for _,cue in ipairs(Slice.cues.sfx) do
	count+=1
	local r=resolved[cue.id]
	check(r~=nil,"cue resolved: "..cue.id)
	local file=Sfx.parseAsset(cue.asset)
	local key
	for k,e in pairs(Catalog) do if type(e)=="table" and e.file==file then key=k end end
	check(key~=nil,"cue asset is in the catalog: "..cue.id.." ("..tostring(file)..")")
	local fb=Sfx.parseFallback(cue.fallback)
	if fb.kind=="silent" then equal(r.source,"silent",cue.id.." silent until uploaded")
	else check(r.source=="fallback" and type(r.soundId)=="string","fallback wired: "..cue.id) end
	if fb.kind=="asset" then equal(r.soundId,fb.path,cue.id.." built-in path"); check(math.abs(r.speed-fb.speed)<1e-9,cue.id.." speed") end
end
equal(count,22,"22 slice cues")
-- Uploading an id switches the cue to it.
local withId=table.clone(Catalog); withId.loop_close=table.clone(Catalog.loop_close); withId.loop_close.id="123"
equal(Sfx.resolve(Slice.cues,withId).loop_close.soundId,"rbxassetid://123","uploaded id wins")
check(math.abs(Sfx.popSpeed(4)-2^(7/12))<1e-12 and math.abs(LoopFx.pentatonic(8)-2^(16/12))<1e-12,"pentatonic ladder")

-- F8/F9 and coaching helpers.
equal(Overlay.percentile({5,1,3,2,4},0.5),3); equal(Overlay.percentile({},0.95),0)
local controls=Overlay.controls(Tuning)
equal(#controls,7,"F9 has the seven slice controls")
for _,c in ipairs(controls) do
	check(c.value>=c.range[1] and c.value<=c.range[2],"F9 default inside range "..c.key)
	local v=c.value
	for _=1,50 do c.value=Overlay.stepValue(c,1) end
	check(math.abs(c.value-c.range[2])<c.step,"F9 clamps to the range top "..c.key)
	c.value=v
end
local shown={}
equal(Coach.next(shown,"roundStart",0),"circle"); equal(Coach.next(shown,"roundStart",0),nil,"once")
equal(Coach.next(shown,"firstCatch",0),"bigger"); equal(Coach.next(shown,"bunvoltEscape",1),"snap")
equal(Coach.next({},"firstCatch",3),nil,"never after round 3")
for _,line in pairs(Coach.LINES) do check(#line<=40,"hint <= 40 chars") end
local ring=LoopFx.resample({{x=0,z=0},{x=10,z=0},{x=10,z=10},{x=0,z=10}},24)
equal(#ring,24); check(math.abs(ring[7].x-10)<1e-9 and math.abs(ring[7].z)<1e-9,"arc-length resample")
equal(LoopFx.sizeTier(5),"5-7"); equal(LoopFx.sizeTier(9),"8+")
print("SparkHudLayout: "..assertions.." assertions passed")
