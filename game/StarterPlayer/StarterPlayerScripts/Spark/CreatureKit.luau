-- Client-built creatures (WP-06). The server sends only HerdNet entries; the
-- client builds each Spark from design/fable/data/models (Design.Models) at
-- tuning.creatures.globalScale: one invisible anchored Root (PrimaryPart) and
-- the listed parts, unanchored, massless, non-colliding and welded to Root.
-- Ellipsoids are a Part with a SpecialMesh of type Sphere sized to the part.
-- Cosmetic only: every catch is decided from server positions.
local CreatureKit = {}

local INK = {27, 36, 64}
local WHITE = {255, 249, 231}
local GOLD = {255, 217, 90}
local BLUSH = {255, 150, 170}

-- CreatureView gait family per species (hopper / glider / roller / walker).
CreatureKit.FAMILY = {pip = "orb", bunvolt = "ears", cubloom = "cube", flutter = "moth"}

local function lerpRgb(a, b, t)
	return {a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t}
end

-- Pure: resolve a part colour name to RGB for a species palette.
function CreatureKit.colorOf(name, palette, golden)
	if golden and (name == "body" or name == "bodyDark") then return if name == "body" then GOLD else lerpRgb(GOLD, INK, 0.3) end
	if name == "body" then return palette.body end
	if name == "accent" then return if golden then {255, 244, 190} else palette.accent end
	if name == "bodyDark" then return lerpRgb(palette.body, INK, 0.3) end
	if name == "ink" then return INK end
	if name == "white" then return WHITE end
	if name == "gold" then return GOLD end
	if name == "blush" then return BLUSH end
	if type(name) == "table" then return name end
	return palette.body
end

-- Pure: the part specs for a species at a scale (count is the silhouette budget).
function CreatureKit.specs(models, speciesId, scale)
	local model = models.meadow_creatures.species[speciesId]
	if not model then return nil end
	local out = {}
	for _, part in ipairs(model.parts) do
		table.insert(out, {name = part.name, shape = part.shape, color = part.color,
			size = {part.size[1] * scale, part.size[2] * scale, part.size[3] * scale},
			pos = {part.pos[1] * scale, part.pos[2] * scale, part.pos[3] * scale},
			rot = part.rot or {0, 0, 0}})
	end
	return out
end

-- Roblox: build a model. ctx = {Models, Creatures (Design), scale, golden}.
function CreatureKit.build(speciesId, ctx)
	local specs = CreatureKit.specs(ctx.Models, speciesId, ctx.scale)
	local def = ctx.Creatures.byId[speciesId]
	if not specs or not def then return nil end
	local model = Instance.new("Model")
	model.Name = "Spark_" .. speciesId
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide, root.CanTouch, root.CanQuery = false, false, false
	root.CastShadow = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	for _, spec in ipairs(specs) do
		local p = Instance.new("Part")
		-- CreatureView blinks parts named Pupil and squashes the part named Body.
		p.Name = if spec.name == "body" then "Body" elseif string.sub(spec.name, 1, 4) == "eye_" then "Pupil" else spec.name
		local rgb = CreatureKit.colorOf(spec.color, def.palette, ctx.golden)
		p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		p.Material = if string.sub(spec.name, 1, 4) == "eye_" then Enum.Material.Glass else Enum.Material.SmoothPlastic
		p.Anchored = false
		p.Massless = true
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.CastShadow = spec.name == "body"
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		local size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
		local rot = CFrame.Angles(math.rad(spec.rot[1]), math.rad(spec.rot[2]), math.rad(spec.rot[3]))
		if spec.shape == "cylinder" then
			-- Data axis is local Y; Roblox cylinders run along X.
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(size.Y, size.X, size.Z)
			rot = rot * CFrame.Angles(0, 0, math.pi / 2)
		else
			p.Size = Vector3.new(math.max(0.05, size.X), math.max(0.05, size.Y), math.max(0.05, size.Z))
			if spec.shape == "ellipsoid" then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = p
			end
		end
		p.CFrame = CFrame.new(spec.pos[1], spec.pos[2], spec.pos[3]) * rot
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, p
		weld.Parent = p
		p.Parent = model
	end
	model:SetAttribute("Species", speciesId)
	model:SetAttribute("Silhouette", CreatureKit.FAMILY[speciesId] or "orb")
	if ctx.golden then model:SetAttribute("Golden", true) end
	return model
end

return CreatureKit
