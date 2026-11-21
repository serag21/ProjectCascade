-- WP-01: the generated design modules load, mirror the JSON shape, and every id
-- referenced across them resolves. Freshness against the JSON is the separate
-- design-data-fresh check (tools/gen_design_data.py --check).
local D="../game/ReplicatedStorage/Spark/Design/"
local Tuning=require(D.."Tuning")
local Creatures=require(D.."Creatures")
local Events=require(D.."Events")
local Arenas=require(D.."Arenas")
local Models=require(D.."Models")
local Slice=require(D.."Slice")
local assertions=0
local function check(condition,message) assertions+=1; assert(condition,message) end
local function equal(a,b,message) check(a==b,(message or "Mismatch")..": "..tostring(a).." ~= "..tostring(b)) end

-- Tuning entries collapse to their value; ranges live beside them.
equal(Tuning.movement.walkSpeed,24,"walk speed")
equal(Tuning.dash.charges,2); equal(#Tuning.dash.speedCurve,4)
equal(Tuning.ribbon.snapRadius,4.5); equal(Tuning.ribbon.maxVertices,56)
equal(Tuning.scoring.sizeMultiplier[8],3,"digit keys become integer keys")
equal(Tuning.scoring.sizeMultiplier[2],1.3)
equal(Tuning.Ranges.ribbon.lifetime[1],3.4); equal(Tuning.Ranges.ribbon.lifetime[2],5)
equal(Tuning.features.trialEnabled,false)
equal(Tuning.camera.pitchPresets[2],Tuning.camera.pitchDegrees,"middle preset is the default pitch")
for section,entries in pairs(Tuning) do
	if type(entries)=="table" then
		for key in pairs(entries) do check(string.sub(tostring(key),1,1)~="_","note key leaked: "..section.."."..tostring(key)) end
	end
end

-- Creatures: twelve species, every one indexed; signatures remap.
equal(#Creatures.species,12,"species count")
for _,def in ipairs(Creatures.species) do
	equal(Creatures.byId[def.id],def,"byId "..def.id)
	check(Creatures.signatureRemap[def.signature]~=nil,"signature remap for "..def.id)
	check(def.silhouette.parts<=Tuning.performance.creaturePartsMax,"part budget "..def.id)
end
for _,def in ipairs(Creatures.legends) do equal(Creatures.byId[def.id],def) end
for _,def in ipairs(Creatures.hazards) do equal(Creatures.byId[def.id],def) end

-- Arenas: three, ordered by biome; every pod species and habitat resolves.
equal(#Arenas.order,3); equal(Arenas.order[1],"meadow")
for _,id in ipairs(Arenas.order) do
	local arena=Arenas[id]
	equal(arena.id,id)
	check(#arena.bounds>=3,"bounds "..id)
	check(Arenas.inBounds(arena,arena.spawn.x,arena.spawn.z),"spawn inside bounds "..id)
	equal(#arena.bankRings,2,"two bank rings "..id)
	for _,ring in ipairs(arena.bankRings) do check(Arenas.inBounds(id,ring.x,ring.z),"bank ring inside "..ring.id) end
	local habitats={}
	for _,h in ipairs(arena.habitats) do habitats[h.id]=h end
	for _,pod in ipairs(arena.pods) do
		check(Creatures.byId[pod.species]~=nil,"pod species "..pod.species)
		check(habitats[pod.habitat]~=nil,"pod habitat "..pod.habitat)
	end
	for _,anchor in ipairs(arena.eventAnchors or {}) do
		check(Events.byId[anchor.event]~=nil,"anchor event "..anchor.event)
		if anchor.feature then check(Arenas.feature(arena,anchor.feature)~=nil,"anchor feature "..anchor.feature) end
	end
end
check(not Arenas.inBounds("meadow",200,0),"far point is out of bounds")
local meadowBlockers=Arenas.blockers("meadow")
check(#meadowBlockers>=5,"meadow blockers")
for _,f in ipairs(meadowBlockers) do check(f.solid or f.creatureBlock,"blocker flag "..f.id) end
for _,f in ipairs(Arenas.pinchWalls("meadow")) do check(f.pinch,"pinch flag "..f.id) end

-- Events: the two slice events exist with the times the route depends on.
equal(Events.byId.bloom_burst.start,30); equal(Events.byId.bloom_burst.telegraphAt,25)
equal(Events.byId.stampede.start,55); equal(Events.byId.stampede.telegraphAt,49)
equal(#Events.roundBeats,4)

-- Models: a part list for each slice species; cinch timeline present.
local meadowModels=Models.meadow_creatures
check(meadowModels~=nil,"meadow creature models")
for _,id in ipairs(Slice.species) do
	local model=meadowModels.species[id]
	check(model~=nil,"model for "..id)
	local count=0
	for _ in ipairs(model.parts) do count+=1 end
	check(count<=Creatures.byId[id].silhouette.parts,"model parts within silhouette budget "..id)
end
equal(Models.cinch_effect.ring.segments,24)

-- Slice: scope flags fail closed.
equal(Slice.arena,"meadow")
check(Slice.on("pip") and Slice.on("bunvolt") and Slice.on("cubloom") and Slice.on("flutter"),"slice species on")
check(Slice.on("bloom_burst") and Slice.on("stampede"),"slice events on")
for _,id in ipairs({"static_puff","legend","first_spark","daily_stampede","heat_and_perks","upgrades","weekly_remix","arena_travel","golden_runaway","PINCH"}) do
	check(not Slice.on(id),"off/stubbed must be off: "..id)
end
check(not Slice.on("sunshell"),"canyon species not in the slice")
check(not Slice.on("definitely_unknown"),"unknown ids fail closed")
for _,id in ipairs(Slice.species) do check(Creatures.byId[id]~=nil,"slice species resolves "..id) end
for _,cue in ipairs(Slice.cues.sfx) do check(type(cue.id)=="string" and type(cue.fallback)=="string","cue "..tostring(cue.id)) end
equal(#Slice.cues.sfx,22,"22 slice cues")
print("SparkDesignData: "..assertions.." assertions passed")
