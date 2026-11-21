-- Spark Stampede client (Checkpoint 1 slice, WP-07): wiring only. All rewards,
-- catches and scores originate on the server. Modules:
--   Movement (predicted dash, bounce caps), SparkCamera (raised chase camera),
--   Ribbon (local loop ribbon + claims), CreatureView + CreatureKit (herd from
--   HerdNet v2), LoopFx (cinch, pops, payout tags), Hud (HUD v2 from
--   ui_layout.json), Sfx (22 slice cues), Decor (arena dressing), Menu.
-- Studio only: F8 overlay v2 (with the build ID) and the F9 tuning panel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
-- The default player list covers the score HUD. Retry while CoreScripts initialize.
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
		if ok then return end
		task.wait(.5)
	end
end)
local Shared = ReplicatedStorage:WaitForChild("Spark")
local Design = Shared:WaitForChild("Design")
local Config = require(Shared:WaitForChild("Config"))
local HerdNet = require(Shared:WaitForChild("HerdNet"))
local Loop = require(Shared:WaitForChild("Loop"))
local GroundMap = require(Shared:WaitForChild("GroundMap"))
local DesignTuning = require(Design:WaitForChild("Tuning"))
local DesignArenas = require(Design:WaitForChild("Arenas"))
local DesignModels = require(Design:WaitForChild("Models"))
local DesignCreatures = require(Design:WaitForChild("Creatures"))
local DesignSlice = require(Design:WaitForChild("Slice"))
local DesignUi = require(Design:WaitForChild("UiLayout"))
local Menu = require(script.Parent:WaitForChild("Menu"))
local CreatureView = require(script.Parent:WaitForChild("CreatureView"))
local CreatureKit = require(script.Parent:WaitForChild("CreatureKit"))
local Movement = require(script.Parent:WaitForChild("Movement"))
local SparkCamera = require(script.Parent:WaitForChild("SparkCamera"))
local Ribbon = require(script.Parent:WaitForChild("Ribbon"))
local Decor = require(script.Parent:WaitForChild("Decor"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local LoopFx = require(script.Parent:WaitForChild("LoopFx"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Coach = require(script.Parent:WaitForChild("Coach"))
local AudioCatalog = require(Shared:WaitForChild("AudioCatalog"))
local buildInfoModule = Shared:FindFirstChild("BuildInfo")
local BuildInfo = if buildInfoModule then require(buildInfoModule) else {id = "dev (not installed from a build)"}
local remotes = Shared:WaitForChild("Remotes")
local Action = remotes:WaitForChild("Action")
local State = remotes:WaitForChild("State")
local Feedback = remotes:WaitForChild("Feedback")
local HerdFeed = remotes:WaitForChild("HerdNet")

local playerGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "SparkHUD"; gui.ResetOnSpawn = false; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = false
gui.Parent = playerGui
local fxFolder = workspace:FindFirstChild("SparkFx") or Instance.new("Folder")
fxFolder.Name = "SparkFx"; fxFolder.Parent = workspace
local creaturesFolder = workspace:FindFirstChild("SparkCreatures") or Instance.new("Folder")
creaturesFolder.Name = "SparkCreatures"; creaturesFolder.Parent = workspace
-- Parade followers are creatures, not effects: they stay out of the SparkFx part budget.
local paradeFolder = workspace:FindFirstChild("SparkParade") or Instance.new("Folder")
paradeFolder.Name = "SparkParade"; paradeFolder.Parent = workspace

local latest = nil -- last server state with the cached profile merged in
local cachedProfile = nil
local stateAt = 0
local overrides = {} -- F9 (Studio only, session only)
local classicCamera = false

local function inRound() return latest ~= nil and (latest.phase == "Playing" or latest.phase == "Warmup") end
local function reduced() return cachedProfile ~= nil and cachedProfile.settings.reducedMotion == true end
local function setting(key, default)
	local v = cachedProfile and cachedProfile.settings and cachedProfile.settings[key]
	if v == nil then return default end
	return v
end
local function arenaIndex() return (latest and latest.biome) or 1 end
local clientMaps = {}
local function mapFor(index)
	if not clientMaps[index] then
		local biome = Config.Biomes[index]
		local def = biome and DesignArenas[biome.id]
		local legacy = false
		for _, id in ipairs(DesignTuning.features.worldLegacy or {}) do if biome and id == biome.id then legacy = true end end
		clientMaps[index] = if def and not legacy then GroundMap.build(def) else GroundMap.flat(biome and biome.id or "?")
	end
	return clientMaps[index]
end
local function arenaOrigin() return Vector3.new((arenaIndex() - 1) * 300, 0, 0) end
local function speciesColor(id)
	local def = DesignCreatures.byId[id]
	return if def then Color3.fromRGB(def.palette.body[1], def.palette.body[2], def.palette.body[3]) else Color3.new(1, 1, 1)
end
local function creatureScale() return overrides.creatureScale or DesignTuning.creatures.globalScale end

-- Audio -------------------------------------------------------------------------
local sfx = Sfx.new({cues = DesignSlice.cues, catalog = AudioCatalog,
	enabled = function() return setting("sfx", true) ~= false end,
	volume = function() return math.clamp(tonumber(setting("sfxVolume", 0.8)) or 0.8, 0, 1) end})
local music = Instance.new("Sound"); music.Name = "SparkMusic"; music.Looped = true; music.Parent = SoundService
local finaleLayer = Instance.new("Sound"); finaleLayer.Name = "SparkMusicFinale"; finaleLayer.Looped = true; finaleLayer.Parent = SoundService
local function catalogId(key)
	local e = AudioCatalog[key]
	return if e and type(e.id) == "string" and e.id ~= "" then Sfx.assetUri(e.id) else nil
end
-- Music: music_meadow, plus music_meadow_finale faded in from 85 s. Music has no
-- built-in fallback: silent until the owner uploads (audio not judged at Checkpoint 1).
local function updateMusic(now)
	local base, layer = catalogId("music_meadow"), catalogId("music_meadow_finale")
	local volume = if setting("music", true) == false then 0 else math.clamp(tonumber(setting("musicVolume", 0.6)) or 0.6, 0, 1)
	if base and not music.IsPlaying then music.SoundId = base; music:Play() end
	if layer and not finaleLayer.IsPlaying then finaleLayer.SoundId = layer; finaleLayer:Play(); finaleLayer.TimePosition = music.TimePosition end
	music.Volume = 0.28 * volume
	local finale = latest ~= nil and latest.finale == true
	local want = if finale then 0.28 * volume else 0
	finaleLayer.Volume += (want - finaleLayer.Volume) * math.min(1, (now or 0) * 1.5) -- ~0.7 s fade
end

-- HUD and menu ------------------------------------------------------------------
local menu
local movement
local SparkCameraRef -- assigned once the camera exists (Settings: Camera Classic)
local hud = Hud.new({layout = DesignUi, gui = gui,
	onMenu = function() if menu then menu.open(if menu.isOpen() then nil else "Album") end end,
	onDash = function() if movement then movement.press() end end})
local function miniature(id, parent)
	local m = CreatureKit.build(id, {Models = DesignModels, Creatures = DesignCreatures, scale = 0.8})
	if not m then
		m = Instance.new("Model")
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Ball; part.Size = Vector3.new(2, 2, 2); part.Anchored = true
		part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		local def = Config.Creatures[1]
		for _, d in ipairs(Config.Creatures) do if d.id == id then def = d end end
		part.Color = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
		part.Parent = m
		m.PrimaryPart = part
	end
	m.Parent = parent
	return m
end
menu = Menu.new({gui = gui, data = function() return latest end,
	fire = function(action, payload) Action:FireServer(action, payload) end,
	miniature = miniature,
	controllerActive = function() return string.match(UserInputService:GetLastInputType().Name, "^Gamepad") ~= nil end,
	toast = function(text) hud.toast(text, os.clock()) end,
	boards = function() return nil end,
	photoMode = function() gui.Enabled = false end,
	inviteFriends = function() pcall(function() game:GetService("SocialService"):PromptGameInvite(player) end) end,
	onBadgeChanged = function(on) hud.setBadge(on) end,
	cameraClassic = function() return classicCamera end,
	setCameraClassic = function(on) classicCamera = on; if SparkCameraRef then SparkCameraRef.setClassic(on) end end,
	onChanged = function() end})

-- Camera, dash, ribbon -----------------------------------------------------------
local creatureView
local sparkCamera = SparkCamera.new({tuning = DesignTuning, reduced = reduced,
	shouldRun = function() return latest ~= nil and (latest.phase == "Playing" or latest.phase == "Warmup" or latest.phase == "Results") end,
	onPreset = function(pitch) hud.toast(string.format("Camera pitch %d°", pitch), os.clock()) end})
SparkCameraRef = sparkCamera
movement = Movement.new({player = player, tuning = DesignTuning, GroundMap = GroundMap,
	groundMap = function() return mapFor(arenaIndex()) end,
	arenaDef = function() local biome = Config.Biomes[arenaIndex()]; return biome and DesignArenas[biome.id] end,
	canDash = function() return inRound() and not menu.isOpen() end,
	sound = function(name) if name == "bounce_cap" then sfx.play("bounce_cap") end end,
	onDash = function(started, dash)
		if started then
			Action:FireServer("Dash")
			sparkCamera.kick()
			sfx.play("dash_go", if dash.charges == 0 then 1.19 else 1)
		else
			sfx.play("dash_empty")
		end
	end})
local loopT = Loop.tuning(DesignTuning)
local loopFx = LoopFx.new({fxFolder = fxFolder, cinch = DesignModels.cinch_effect, sfx = sfx, reduced = reduced,
	color = Color3.fromRGB(255, 236, 96), popStagger = DesignTuning.ribbon.popStagger, resultTimeout = DesignTuning.ribbon.resultTimeout,
	groundY = function(x, z) return GroundMap.height(mapFor(arenaIndex()), x, z) end,
	origin = arenaOrigin, speciesColor = speciesColor,
	onStampede = function(n) hud.toast(string.format("STAMPEDE! %d in one ring", n), os.clock()) end})
local coach -- first-round coaching (Coach.new below)
-- Client prediction: which rendered creatures are inside the closed ring.
local function predict(poly)
	local ids = {}
	if not creatureView then return ids end
	for _, id in ipairs(creatureView.ids()) do
		local x, z, state = creatureView.position(id)
		if x and Loop.contains(poly, x, z, loopT.inflate) and state ~= 4 and state ~= 6 then table.insert(ids, id) end
	end
	return ids
end
local ribbon = Ribbon.new({player = player, Loop = Loop, T = loopT, GroundMap = GroundMap, width = DesignTuning.ribbon.width,
	rate = DesignTuning.ribbon.claimRateLimitPerSecond, fxFolder = fxFolder, camera = sparkCamera,
	groundMap = function() return mapFor(arenaIndex()) end,
	origin = arenaOrigin,
	active = function() return inRound() end,
	viewClock = function() return if creatureView then creatureView.renderClock() else 0 end,
	send = function(payload) Action:FireServer("Loop", payload) end,
	onClose = function(poly) loopFx.close(poly, predict(poly), os.clock()); if coach then coach.loopClosed() end end,
	onSlip = function() end,
	onPreview = function(near) if near then sfx.play("ribbon_near_close") end end})

-- Herd: client-built creatures from HerdNet v2 ------------------------------------
local perf = {herdBytes = 0, frames = {}, herdWindow = {}}
creatureView = CreatureView.new({folder = creaturesFolder, camera = function() return workspace.CurrentCamera end,
	reducedMotion = reduced, localUserId = player.UserId, guiParent = playerGui,
	build = function(entry)
		return CreatureKit.build(entry.species, {Models = DesignModels, Creatures = DesignCreatures,
			scale = creatureScale(), golden = HerdNet.has(entry.flags, "golden")})
	end,
	release = function(model) model:Destroy() end,
	groundAt = function(x, z) return GroundMap.height(mapFor(arenaIndex()), x, z) end,
	quality = function()
		local ok, level = pcall(function() return UserSettings().GameSettings.SavedQualityLevel.Value end)
		return if ok and type(level) == "number" and level > 0 then level else 10
	end})
local lastHop = {}
HerdFeed.OnClientEvent:Connect(function(packet)
	if type(packet) == "buffer" then perf.herdBytes += buffer.len(packet) end
	local decoded = HerdNet.unpack(packet)
	if not decoded then return end
	creatureView.ingest({arena = decoded.arena, origin = Vector3.new((decoded.arena - 1) * 300, 0, 0), clock = decoded.clock,
		receivedAt = os.clock(), entries = decoded.entries})
	-- Bunvolt crouch: shrinking ground ring + the hop wind-up voice (gameplay information).
	for _, e in ipairs(decoded.entries) do
		if e.state == 3 and lastHop[e.id] ~= 3 then
			local origin = Vector3.new((decoded.arena - 1) * 300, 0, 0)
			local g = GroundMap.height(mapFor(decoded.arena), e.x, e.z)
			loopFx.hopRing(origin + Vector3.new(e.x, g, e.z))
			sfx.play("boop", 0.625) -- pop.wav @ 0.5 (boop cue is pop @ 0.8)
		end
		lastHop[e.id] = e.state
	end
end)

-- Parade: each player's carried Sparks follow them (client-built, bounded 12) ----
local followers = {}
local function speciesOf(entry)
	if type(entry) ~= "string" then return nil end
	return if string.sub(entry, 1, 1) == "*" then string.sub(entry, 2) else entry
end
local function updateParade(other)
	local previous = followers[other]
	if previous then for _, m in ipairs(previous.models) do m:Destroy() end end
	local models = {}
	for _, entry in ipairs(string.split(other:GetAttribute("SparkParade") or "", ",")) do
		local id = speciesOf(entry)
		if id and id ~= "" and #models < 12 then
			local m = CreatureKit.build(id, {Models = DesignModels, Creatures = DesignCreatures, scale = 0.62,
				golden = string.sub(entry, 1, 1) == "*"})
			if m then m.Parent = paradeFolder; table.insert(models, m) end
		end
	end
	followers[other] = {models = models}
end
local function watchParade(other)
	other:GetAttributeChangedSignal("SparkParade"):Connect(function() updateParade(other) end)
	updateParade(other)
end
for _, other in ipairs(Players:GetPlayers()) do watchParade(other) end
Players.PlayerAdded:Connect(watchParade)
Players.PlayerRemoving:Connect(function(other)
	local f = followers[other]
	if f then for _, m in ipairs(f.models) do m:Destroy() end end
	followers[other] = nil
end)

-- First-round coaching (WP-08): ghost ring + three hints ---------------------------
coach = Coach.new({hud = hud, loopFx = loopFx, data = function() return latest end,
	origin = arenaOrigin, groundY = function(x, z) return GroundMap.height(mapFor(arenaIndex()), x, z) end})

-- Server state ----------------------------------------------------------------------
local lastBeat = nil
State.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	if type(data.profile) == "table" then cachedProfile = data.profile end
	data.profile = cachedProfile
	if not data.profile then return end
	local previous = latest
	latest = data
	stateAt = os.clock()
	if previous ~= nil and previous.phase ~= data.phase and data.phase == "Results" then sfx.play("round_time") end
	hud.setScore(data.mastery and data.mastery.score or 0, os.clock())
	if data.phaseName then hud.setPhase(data.phaseName, os.clock()) end
	coach.state(data)
	menu.live(data)
	if menu.isOpen() then menu.render() end
	-- Slice results sheet: score, provisional medal, best loop size, next round countdown.
	if data.phase == "Results" then
		local r = data.lastResult or {}
		hud.results({score = r.score or (data.mastery and data.mastery.score) or 0, medal = r.medal or (data.mastery and data.mastery.medal),
			bestLoop = data.mastery and data.mastery.bestLoop or 0, nextIn = data.nextRoundIn})
	else
		hud.results(nil)
	end
end)

-- Feedback ----------------------------------------------------------------------------
Feedback.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	local extra = if type(data.extra) == "table" then data.extra else {}
	local now = os.clock()
	if data.kind == "Loop" then
		ribbon.result(nil)
		loopFx.result(extra, now)
		for _, c in ipairs(extra.caught or {}) do
			if type(c) == "table" and c.creatureId then creatureView.remove(c.creatureId) end
		end
		if coach then coach.loopResult(extra) end
	elseif data.kind == "RibbonCut" then
		ribbon.cut()
	elseif data.kind == "Bank" then
		if typeof(extra.position) == "Vector3" and not extra.automatic then loopFx.bank(extra.position, extra.count or 1) end
		hud.toast(data.text, now)
	elseif data.kind == "BankBurst" then
		-- Another player's bank: a quieter fountain, no sound.
	elseif data.kind == "Round" then
		hud.toast(data.text, now)
		if extra.cycleStart then sfx.play("round_go") end
	elseif data.kind == "Event" then
		hud.toast(data.text, now)
		if extra.event == "bloom_burst" then sfx.play(if extra.open then "bloom_open" else "bloom_chime") end
		if extra.event == "stampede" and extra.horn then sfx.play("stampede_horn") end
	elseif data.kind == "Hint" then
		hud.hint(data.text, now)
	elseif data.kind == "Results" or data.kind == "Quest" or data.kind == "Assist" or data.kind == "Error" then
		hud.toast(data.text, now)
	end
	if data.kind == "Loop" and (extra.multiplier or 1) > 1 and coach then coach.chain(extra.multiplier) end
end)

-- Input -----------------------------------------------------------------------------
-- Dash on Shift or E (E keeps old muscle memory doing something), B / RT on gamepad.
-- Motion starts in this input frame (Movement.press); the server only budgets it.
ContextActionService:BindAction("SparkDash", function(_, state)
	if state ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() or menu.isOpen() then return Enum.ContextActionResult.Pass end
	movement.press()
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.E, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("SparkMenu", function(_, state)
	if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then menu.open(if menu.isOpen() then nil else "Album") end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.M, Enum.KeyCode.Tab, Enum.KeyCode.ButtonStart)
ContextActionService:BindAction("SparkPhoto", function(_, state)
	if state ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	gui.Enabled = not gui.Enabled
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.H)

-- Studio-only debug: F8 overlay v2 and F9 tuning panel ------------------------------
local Overlay = require(script.Parent:WaitForChild("Overlay"))
if RunService:IsStudio() then
	Overlay.start({gui = gui, playerGui = playerGui, fxFolder = fxFolder, creaturesFolder = creaturesFolder,
		perf = perf, buildId = BuildInfo, data = function() return latest end,
		arenaModel = function()
			local w = workspace:FindFirstChild("SparkWorld")
			return w and w:FindFirstChild(Config.Biomes[arenaIndex()].id)
		end,
		tuning = DesignTuning,
		apply = function(key, value)
			overrides[key] = value
			if key == "lifetime" or key == "snapRadius" then
				loopT = Loop.tuning(DesignTuning, {lifetime = overrides.lifetime, snapRadius = overrides.snapRadius})
				ribbon.retune(loopT)
			elseif key == "dashDistance" then movement.retune({distance = value})
			elseif key == "walkSpeed" then movement.retune({walk = value})
			elseif key == "pitch" then sparkCamera.retune({pitch = value})
			elseif key == "distance" then sparkCamera.retune({distance = value})
			end
			Action:FireServer("Tune", {[key] = value})
		end})
end

-- Frame loop --------------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	table.insert(perf.frames, {at = now, dt = dt})
	while #perf.frames > 0 and now - perf.frames[1].at > 5 do table.remove(perf.frames, 1) end
	creatureView.render(now)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	-- Parade followers trail behind each player in a line.
	for other, f in pairs(followers) do
		local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		for index, m in ipairs(f.models) do
			if otherRoot then
				local offset = otherRoot.CFrame * CFrame.new((index % 2 - 0.5) * 1.4, -2.6, 3 + index * 1.6)
				local hop = if reduced() then 0 else math.abs(math.sin(now * 6 + index)) * 0.4
				m:PivotTo(CFrame.new(offset.Position + Vector3.new(0, hop, 0)) * otherRoot.CFrame.Rotation)
			else
				m:PivotTo(CFrame.new(0, -1000, 0))
			end
		end
	end
	if latest then
		local elapsed = now - stateAt
		local remaining = if latest.phase == "Results" then (latest.nextRoundIn or 0) - elapsed else (latest.remaining or 0) - elapsed
		local m = latest.mastery or {}
		local carry = {}
		for _, entry in ipairs(string.split(player:GetAttribute("SparkParade") or "", ",")) do
			local id = speciesOf(entry)
			if id and id ~= "" then table.insert(carry, id) end
		end
		local d = movement.dash
		Movement.refill(d, now)
		hud.update({remaining = remaining, carry = carry, capacity = latest.capacity or 12,
			chainMult = m.multiplier or 1, chainLeft = math.max(0, (m.chainSeconds or 0) - elapsed), chainSpan = m.chainWindow,
			charges = d.charges, maxCharges = d.maxCharges, nextCharge = Movement.nextChargeIn(d, now), recharge = d.recharge,
			rounds = cachedProfile and cachedProfile.rounds or 0, reduced = reduced(), palette = speciesColor,
			bankTiers = DesignTuning.parade.bankMultiplier}, now)
		-- 3-2-1 before a round, buzzer handled on the phase change.
		local beat = math.ceil(remaining)
		if latest.phase == "Results" and beat ~= lastBeat and beat >= 1 and beat <= 3 then
			sfx.play("round_count"); hud.toast(tostring(beat), now)
		end
		lastBeat = beat
		updateMusic(dt)
		coach.frame(now, root)
	end
end)

-- Client-only arena dressing, lighting profile and occluder fade (WP-05).
task.spawn(function()
	local worldRoot = workspace:WaitForChild("SparkWorld", 60)
	local arenaModel = worldRoot and worldRoot:WaitForChild("meadow", 60)
	local def = DesignArenas.meadow
	if not arenaModel or not def or not arenaModel:GetAttribute("DataDriven") then return end
	Decor.start({def = def, origin = Vector3.new(0, 0, 0), GroundMap = GroundMap, arenaModel = arenaModel,
		reducedMotion = reduced(),
		getPhase = function() return latest and latest.phaseName end,
		getTarget = function()
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			return root and root.Position + Vector3.new(0, 1.5, 0)
		end})
end)
Action:FireServer("Ready")
-- Ready is idempotent; retries cover a slow server-world build without a dead HUD.
task.spawn(function() for _ = 1, 10 do task.wait(2); if latest and latest.phase ~= "Loading" then return end; Action:FireServer("Ready") end end)
