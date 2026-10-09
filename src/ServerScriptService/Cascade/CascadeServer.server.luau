-- Project Cascade | Site 07 | Playtest Build 03
-- Server-authoritative procedural facility, causal interactions, ambience and pursuit AI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local CascadeState = require(ReplicatedStorage:WaitForChild("Cascade"):WaitForChild("CascadeState"))
local state = CascadeState.new()

-- Forward declarations keep interaction callbacks bound to the intended local instances.
local facilityLights = {}
local emergencyStatusLights = {}
local redAlarmLights = {}
local lowerRouteLights = {}
local exitRouteLights = {}
local maintenanceDoor: BasePart? = nil
local arrayGate: BasePart? = nil
local signalShutter: BasePart? = nil
local exitRouteGate: BasePart? = nil
local exitDoor: BasePart? = nil
local exitTrigger: BasePart? = nil
local powerConsole: BasePart? = nil
local arrayConsole: BasePart? = nil
local pumpConsole: BasePart? = nil
local pumpPrompt: ProximityPrompt? = nil
local pumpHousing: BasePart? = nil
local floodwater: BasePart? = nil
local arrayCore: Model? = nil
local arrayEnergyLight: PointLight? = nil
local signalConsole: BasePart? = nil
local signalPrompt: ProximityPrompt? = nil
local containmentDoor: BasePart? = nil
local atmosphere: Atmosphere? = nil
local machineHum: Sound? = nil
local pumpStartSound: Sound? = nil
local alarmSound: Sound? = nil
local darkWorldMusic: Sound? = nil
local creatureModel: Model? = nil
local creatureHumanoid: Humanoid? = nil
local creatureRoot: BasePart? = nil
local creatureGrowl: Sound? = nil
local creatureActive = false

local rootFolder = ReplicatedStorage:WaitForChild("Cascade")
local eventsFolder = rootFolder:FindFirstChild("Events") or Instance.new("Folder")
eventsFolder.Name = "Events"
eventsFolder.Parent = rootFolder
local eventRemote = eventsFolder:FindFirstChild("CascadeEvent") or Instance.new("RemoteEvent")
eventRemote.Name = "CascadeEvent"
eventRemote.Parent = eventsFolder

local previousWorld = workspace:FindFirstChild("CascadeFacility")
if previousWorld then previousWorld:Destroy() end
local oldBaseplate = workspace:FindFirstChild("Baseplate")
if oldBaseplate and oldBaseplate:IsA("BasePart") then oldBaseplate:Destroy() end

local world = Instance.new("Folder")
world.Name = "CascadeFacility"
world.Parent = workspace
world:SetAttribute("BuildVersion", 3)

local architecture = Instance.new("Folder")
architecture.Name = "Architecture"
architecture.Parent = world
local props = Instance.new("Folder")
props.Name = "Props"
props.Parent = world
local interactables = Instance.new("Folder")
interactables.Name = "Interactables"
interactables.Parent = world
local effects = Instance.new("Folder")
effects.Name = "Effects"
effects.Parent = world
local audioPoints = Instance.new("Folder")
audioPoints.Name = "AudioPoints"
audioPoints.Parent = world

local function part(name: string, size: Vector3, cf: CFrame, material: Enum.Material, color: Color3, parent: Instance, transparency: number?, collidable: boolean?)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Anchored = true
    p.Material = material
    p.Color = color
    p.Transparency = transparency or 0
    p.CanCollide = if collidable == nil then true else collidable
    p.CastShadow = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function wall(name: string, size: Vector3, position: Vector3, parent: Instance?)
    return part(name, size, CFrame.new(position), Enum.Material.Concrete, Color3.fromRGB(34, 40, 49), parent or architecture)
end

local function addSign(adornee: BasePart, text: string, width: number?, height: number?, offset: Vector3?, accent: Color3?)
    local gui = Instance.new("BillboardGui")
    gui.Name = "ReadableSign"
    gui.Adornee = adornee
    gui.Size = UDim2.fromOffset(width or 220, height or 46)
    gui.StudsOffsetWorldSpace = offset or Vector3.new(0, 3.4, 0)
    gui.AlwaysOnTop = false
    gui.MaxDistance = 62
    gui.LightInfluence = 0.35
    gui.Parent = adornee

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromScale(1, 1)
    panel.BackgroundColor3 = Color3.fromRGB(10, 15, 21)
    panel.BackgroundTransparency = 0.14
    panel.BorderSizePixel = 0
    panel.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = panel

    local stroke = Instance.new("UIStroke")
    stroke.Color = accent or Color3.fromRGB(83, 112, 133)
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = panel

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -14, 1, -4)
    label.Position = UDim2.fromOffset(7, 2)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(227, 235, 241)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 15
    label.TextWrapped = true
    label.TextScaled = false
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = panel
    return gui
end

local function pointLight(parent: Instance, name: string, color: Color3, brightness: number, range: number, enabled: boolean?)
    local light = Instance.new("PointLight")
    light.Name = name
    light.Color = color
    light.Brightness = brightness
    light.Range = range
    light.Shadows = true
    light.Enabled = enabled ~= false
    light.Parent = parent
    return light
end

local function surfaceLight(parent: Instance, name: string, color: Color3, brightness: number, range: number, face: Enum.NormalId, enabled: boolean?)
    local light = Instance.new("SurfaceLight")
    light.Name = name
    light.Color = color
    light.Brightness = brightness
    light.Range = range
    light.Face = face
    light.Shadows = true
    light.Enabled = enabled ~= false
    light.Parent = parent
    return light
end

local function makeSound(parent: Instance, id: string, name: string, volume: number, looped: boolean, speed: number?, maxDistance: number?)
    local s = Instance.new("Sound")
    s.Name = name
    s.SoundId = "rbxassetid://" .. id
    s.Volume = volume
    s.Looped = looped
    s.PlaybackSpeed = speed or 1
    s.RollOffMode = Enum.RollOffMode.InverseTapered
    s.RollOffMinDistance = 8
    s.RollOffMaxDistance = maxDistance or 90
    s.Parent = parent
    return s
end

local function oneShot(parent: Instance, id: string, name: string, volume: number, speed: number?, maxDistance: number?)
    local s = makeSound(parent, id, name, volume, false, speed, maxDistance)
    s:Play()
    Debris:AddItem(s, 20)
    return s
end

local function tweenCFrame(instance: BasePart, destination: CFrame, duration: number?)
    local tween = TweenService:Create(
        instance,
        TweenInfo.new(duration or 1.15, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
        {CFrame = destination}
    )
    tween:Play()
    return tween
end

local function openVerticalDoor(door: BasePart)
    if door:GetAttribute("Open") then return end
    door:SetAttribute("Open", true)
    oneShot(door, "7792922595", "HydraulicDoor", 0.65, 0.9, 70)
    tweenCFrame(door, door.CFrame + Vector3.new(0, door.Size.Y + 2, 0), 1.45)
end

local function addPrompt(console: BasePart, objectText: string, actionText: string, action: string, initiallyEnabled: boolean?)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = action .. "Prompt"
    prompt.ObjectText = objectText
    prompt.ActionText = actionText
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.HoldDuration = 0.28
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt.Style = Enum.ProximityPromptStyle.Default
    prompt.Enabled = initiallyEnabled ~= false
    prompt.Parent = console

    prompt.Triggered:Connect(function(player)
        if action == "ReadArchive" then
            eventRemote:FireClient(player, "Evidence", {
                title = "RECOVERED AUDIO TRANSCRIPT",
                text = "TECH: The array is not transmitting outward. It is replying to a signal already inside the facility. Shut it down.\n\nARCHIVE: Recording ends at 02:17. Three minutes of the file are missing.",
            })
            oneShot(console, "135540168785024", "ArchiveStatic", 0.13, 0.8, 32)
            return
        end

        if action == "Escape" and (not state.signalSent) then
            eventRemote:FireClient(player, "Event", {title = "SEALED", text = "The outside lock has not released."})
            return
        end

        local result = CascadeState.apply(state, action)
        if not result.ok then
            eventRemote:FireClient(player, "Event", {title = "SYSTEM", text = result.message or "No response."})
            return
        end

        local title = "FACILITY RESPONSE"
        if action == "RestorePower" then
            title = "POWER RESTORED"
        elseif action == "StabilizePump" then
            title = "DRAINAGE ENGAGED"
        elseif action == "ActivateArray" then
            title = "OBSERVATION ARRAY ACTIVE"
        elseif action == "TransmitSignal" then
            title = "SIGNAL TRANSMITTED"
        end
        eventRemote:FireAllClients("Event", {title = title, text = result.message or "The facility changed."})

        for _, eventName in result.events do
            if eventName == "PowerRestored" then
                for _, light in facilityLights do
                    light.Enabled = true
                end
                for _, lamp in emergencyStatusLights do
                    if lamp and lamp:IsA("BasePart") then
                        lamp.Transparency = 0
                        local glow = lamp:FindFirstChildWhichIsA("PointLight")
                        if glow then glow.Enabled = true end
                    end
                end
                if machineHum and not machineHum.IsPlaying then
                    machineHum:Play()
                end
                if powerConsole then
                    local lamp = powerConsole:FindFirstChild("PowerStatus")
                    if lamp and lamp:IsA("BasePart") then
                        lamp.Color = Color3.fromRGB(91, 223, 166)
                        pointLight(lamp, "ActiveGlow", Color3.fromRGB(80, 245, 176), 0.9, 7)
                    end
                end
                eventRemote:FireAllClients("Status", {text = "FACILITY SYSTEMS  /  ONLINE"})
            elseif eventName == "MaintenanceDoorOpened" then
                if maintenanceDoor then openVerticalDoor(maintenanceDoor) end
            elseif eventName == "PumpsStarted" then
                if pumpPrompt then pumpPrompt.Enabled = true end
                if pumpStartSound then
                    pumpStartSound:Play()
                end
                if pumpConsole then
                    local lamp = pumpConsole:FindFirstChild("PumpStatus")
                    if lamp and lamp:IsA("BasePart") then
                        lamp.Color = Color3.fromRGB(245, 181, 81)
                        pointLight(lamp, "PumpWakeGlow", Color3.fromRGB(245, 170, 60), 0.65, 6)
                    end
                end
                eventRemote:FireAllClients("WorldCue", {kind = "DistantMachinery"})
            elseif eventName == "DrainageStarted" then
                state.environment = "Draining"
                if floodwater then
                    TweenService:Create(
                        floodwater,
                        TweenInfo.new(6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                        {Position = floodwater.Position - Vector3.new(0, 4.8, 0)}
                    ):Play()
                end
                if arrayGate then openVerticalDoor(arrayGate) end
                if pumpPrompt then pumpPrompt.Enabled = false end
                for _, lamp in lowerRouteLights do
                    lamp.Transparency = 0.05
                    local glow = lamp:FindFirstChild("RouteGlow")
                    if glow and glow:IsA("PointLight") then glow.Enabled = true end
                end
                if pumpConsole then
                    local lamp = pumpConsole:FindFirstChild("PumpStatus")
                    if lamp and lamp:IsA("BasePart") then
                        lamp.Color = Color3.fromRGB(87, 227, 177)
                        pointLight(lamp, "DrainCompleteGlow", Color3.fromRGB(80, 255, 185), 0.9, 7)
                    end
                end
                oneShot(pumpHousing or pumpConsole, "9113910297", "DrainageCycle", 0.8, 0.85, 100)
                eventRemote:FireAllClients("WorldCue", {kind = "WaterDraining"})
                eventRemote:FireAllClients("Status", {text = "LOWER TRANSFER  /  PRESSURE FALLING"})
            elseif eventName == "ArrayRouteOpened" then
                if arrayGate then openVerticalDoor(arrayGate) end
            elseif eventName == "ArrayActivated" then
                if arrayCore then
                    local pivotValue = Instance.new("CFrameValue")
                    pivotValue.Value = arrayCore:GetPivot()
                    local connection = pivotValue:GetPropertyChangedSignal("Value"):Connect(function()
                        if arrayCore and arrayCore.Parent then arrayCore:PivotTo(pivotValue.Value) end
                    end)
                    local target = pivotValue.Value * CFrame.Angles(math.rad(8), math.rad(35), math.rad(-5))
                    local tween = TweenService:Create(pivotValue, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Value = target})
                    tween:Play()
                    tween.Completed:Connect(function()
                        connection:Disconnect()
                        pivotValue:Destroy()
                    end)
                end
                if arrayEnergyLight then
                    arrayEnergyLight.Color = Color3.fromRGB(105, 199, 255)
                    arrayEnergyLight.Brightness = 4.5
                    arrayEnergyLight.Range = 42
                end
                eventRemote:FireAllClients("WorldCue", {kind = "ArrayPulse"})
            elseif eventName == "CascadeStarted" then
                Lighting.Brightness = 0.35
                Lighting.ClockTime = 0
                Lighting.FogEnd = 150
                Lighting.FogColor = Color3.fromRGB(13, 19, 29)
                if atmosphere then
                    atmosphere.Density = 0.38
                    atmosphere.Haze = 3
                    atmosphere.Color = Color3.fromRGB(98, 116, 147)
                    atmosphere.Decay = Color3.fromRGB(28, 33, 46)
                end
                for _, lamp in emergencyStatusLights do
                    if lamp and lamp:IsA("BasePart") then
                        lamp.Transparency = 0
                        local glow = lamp:FindFirstChildWhichIsA("PointLight")
                        if glow then glow.Enabled = true end
                    end
                end
                for _, lamp in redAlarmLights do
                    lamp.Enabled = true
                end
                if alarmSound then alarmSound:Play() end
                if darkWorldMusic then darkWorldMusic:Play() end
                oneShot(arrayCore and arrayCore.PrimaryPart or world, "135540168785024", "CascadeSting", 0.7, 0.82, 120)
                eventRemote:FireAllClients("Status", {text = "CONTAINMENT FAILURE  /  MOTION DETECTED"})
                eventRemote:FireAllClients("WorldCue", {kind = "CascadeStarted"})
                task.spawn(function()
                    for i = 1, 7 do
                        task.wait(0.3 + math.random() * 0.45)
                        for _, light in facilityLights do
                            if math.random() < 0.28 then light.Enabled = false end
                        end
                        task.wait(0.09)
                        for _, light in facilityLights do light.Enabled = state.power end
                    end
                end)
            elseif eventName == "ContainmentReleased" then
                if containmentDoor then openVerticalDoor(containmentDoor) end
                if creatureModel then
                    creatureModel:SetAttribute("Active", true)
                    creatureActive = true
                    task.delay(1.5, function()
                        if creatureRoot and creatureRoot.Parent then
                            oneShot(creatureRoot, "74103327872448", "CreatureAwakens", 0.9, 0.82, 120)
                        end
                    end)
                end
            elseif eventName == "SignalRoomOpened" then
                if signalShutter then openVerticalDoor(signalShutter) end
                if signalPrompt then signalPrompt.Enabled = true end
            elseif eventName == "SignalTransmitted" then
                if exitRouteGate then openVerticalDoor(exitRouteGate) end
                if exitDoor then openVerticalDoor(exitDoor) end
                if exitTrigger then exitTrigger.CanTouch = true end
                for _, lamp in exitRouteLights do
                    lamp.Transparency = 0
                    local glow = lamp:FindFirstChild("ExitGlow")
                    if glow and glow:IsA("PointLight") then glow.Enabled = true end
                end
                eventRemote:FireAllClients("Status", {text = "OUTER SEAL  /  RELEASED"})
                eventRemote:FireAllClients("WorldCue", {kind = "ExitOpened"})
            elseif eventName == "RunCompleted" then
                creatureActive = false
                if creatureModel then creatureModel:SetAttribute("Active", false) end
                if alarmSound and alarmSound.IsPlaying then alarmSound:Stop() end
                eventRemote:FireAllClients("RunComplete", {text = "RUN COMPLETE  —  THE SIGNAL WAS NOT ALONE"})
            end
        end
    end)

    return prompt
end

-- Night-time interior lighting and restrained atmosphere.
Lighting.Technology = Enum.Technology.Future
Lighting.GlobalShadows = true
Lighting.ClockTime = 0.15
Lighting.Brightness = 0.65
Lighting.ExposureCompensation = -0.25
Lighting.EnvironmentDiffuseScale = 0.18
Lighting.EnvironmentSpecularScale = 0.22
Lighting.Ambient = Color3.fromRGB(17, 22, 31)
Lighting.OutdoorAmbient = Color3.fromRGB(8, 11, 18)
Lighting.FogColor = Color3.fromRGB(18, 25, 37)
Lighting.FogStart = 35
Lighting.FogEnd = 205
pcall(function() SoundService.AmbientReverb = Enum.ReverbType.Hangar end)

atmosphere = Lighting:FindFirstChild("CascadeAtmosphere") or Instance.new("Atmosphere")
atmosphere.Name = "CascadeAtmosphere"
atmosphere.Density = 0.27
atmosphere.Offset = 0.05
atmosphere.Color = Color3.fromRGB(156, 176, 202)
atmosphere.Decay = Color3.fromRGB(43, 51, 69)
atmosphere.Glare = 0
atmosphere.Haze = 1.6
atmosphere.Parent = Lighting

local colorCorrection = Lighting:FindFirstChild("CascadeGrade") or Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "CascadeGrade"
colorCorrection.Brightness = -0.05
colorCorrection.Contrast = 0.12
colorCorrection.Saturation = -0.12
colorCorrection.TintColor = Color3.fromRGB(194, 210, 232)
colorCorrection.Parent = Lighting

local bloom = Lighting:FindFirstChild("CascadeBloom") or Instance.new("BloomEffect")
bloom.Name = "CascadeBloom"
bloom.Intensity = 0.32
bloom.Size = 18
bloom.Threshold = 1.65
bloom.Parent = Lighting

-- Global bed: a long industrial hum plus a subtle fluorescent buzz.
local ambience = makeSound(SoundService, "171186876", "FacilityAmbience", 0.13, true, 0.82)
ambience.RollOffMaxDistance = 10000
ambience:Play()
local lightHum = makeSound(SoundService, "4227579935", "FluorescentHum", 0.055, true, 0.84)
lightHum.RollOffMaxDistance = 10000
lightHum:Play()

machineHum = makeSound(SoundService, "171186876", "PowerGridHum", 0.19, true, 0.98)
machineHum.RollOffMaxDistance = 10000
pumpStartSound = nil
alarmSound = nil
darkWorldMusic = nil

-- Build site shell.
part("Foundation", Vector3.new(260, 2, 180), CFrame.new(0, -0.5, 5), Enum.Material.Concrete, Color3.fromRGB(33, 39, 48), architecture)
part("Ceiling", Vector3.new(260, 2, 180), CFrame.new(0, 20, 5), Enum.Material.Metal, Color3.fromRGB(20, 26, 34), architecture)
wall("NorthWall", Vector3.new(260, 18, 3), Vector3.new(0, 9, 95))
wall("WestWall", Vector3.new(3, 18, 180), Vector3.new(-130, 9, 5))
wall("EastWall", Vector3.new(3, 18, 180), Vector3.new(130, 9, 5))
wall("SouthWallLeft", Vector3.new(198, 18, 3), Vector3.new(-31, 9, -85))
wall("SouthWallRight", Vector3.new(38, 18, 3), Vector3.new(111, 9, -85))

-- Door frames and partitions. The gaps are intentional route connections.
wall("WestWingSouth", Vector3.new(2.5, 18, 60), Vector3.new(-45, 9, -55))
wall("WestWingNorth", Vector3.new(2.5, 18, 105), Vector3.new(-45, 9, 42.5))
wall("ArrayWingSouth", Vector3.new(2.5, 18, 80), Vector3.new(48, 9, -45))
wall("ArrayWingNorthSouth", Vector3.new(2.5, 18, 5), Vector3.new(48, 9, 17.5))
wall("ArrayWingNorthNorth", Vector3.new(2.5, 18, 59), Vector3.new(48, 9, 65.5))
wall("SignalRoomWallLeft", Vector3.new(42, 18, 2.5), Vector3.new(-24, 9, 40))
wall("SignalRoomWallRight", Vector3.new(27, 18, 2.5), Vector3.new(34.5, 9, 40))
wall("RecordsRoomWallSouth", Vector3.new(70, 18, 2.5), Vector3.new(-87, 9, 41.5))
wall("PumpRoomDivider", Vector3.new(2.5, 18, 42), Vector3.new(-72, 9, 63))

-- Ceiling cross-beams, cable trays and consistent industrial trim.
for _, z in ipairs({-70, -45, -20, 5, 30, 55, 80}) do
    part("CeilingBeam", Vector3.new(254, 0.65, 1.3), CFrame.new(0, 18.8, z), Enum.Material.Metal, Color3.fromRGB(48, 57, 68), props)
end
for _, x in ipairs({-112, -80, -45, -10, 25, 58, 92, 117}) do
    part("SupportColumn", Vector3.new(1.6, 18, 1.6), CFrame.new(x, 9, 0), Enum.Material.Metal, Color3.fromRGB(54, 63, 74), props)
end
part("MainCableTray", Vector3.new(235, 1, 2.4), CFrame.new(0, 17.2, 8), Enum.Material.Metal, Color3.fromRGB(29, 43, 55), props)
part("UtilityPipeA", Vector3.new(238, 0.75, 0.75), CFrame.new(0, 16.1, 12), Enum.Material.Metal, Color3.fromRGB(76, 102, 112), props)
part("UtilityPipeB", Vector3.new(238, 0.55, 0.55), CFrame.new(0, 16.7, 14), Enum.Material.Metal, Color3.fromRGB(111, 79, 65), props)

-- Painted floor lanes and caution bars. They are subtle orientation cues, not target markers.
for x = -120, 118, 12 do
    part("FloorExpansionJoint", Vector3.new(0.11, 0.025, 175), CFrame.new(x, 0.525, 5), Enum.Material.Metal, Color3.fromRGB(47, 57, 67), props, 0, false)
end
for z = -78, 88, 12 do
    part("FloorExpansionJoint", Vector3.new(256, 0.025, 0.11), CFrame.new(0, 0.525, z), Enum.Material.Metal, Color3.fromRGB(47, 57, 67), props, 0, false)
end
for i = 0, 7 do
    part("CautionStripe", Vector3.new(2.4, 0.04, 0.55), CFrame.new(-33 + i * 3.1, 0.56, -25), Enum.Material.Neon, Color3.fromRGB(178, 128, 61), props, 0.25, false)
end

-- Room-identification signs use fixed, readable text sizes rather than stretched SurfaceGuis.
local function wallSign(name: string, text: string, position: Vector3, accent: Color3?)
    local anchor = part(name, Vector3.new(0.2, 0.2, 0.2), CFrame.new(position), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), props, 1, false)
    addSign(anchor, text, 270, 45, Vector3.new(0, 0, 0), accent)
    return anchor
end
wallSign("WelcomeSign", "SITE 07  /  OBSERVATION & SIGNAL RESEARCH", Vector3.new(0, 11, -80), Color3.fromRGB(94, 166, 198))
wallSign("PowerSign", "POWER DISTRIBUTION", Vector3.new(-43, 11, -15), Color3.fromRGB(223, 165, 76))
wallSign("PumpSign", "WATER TRANSFER  /  LOWER SERVICE", Vector3.new(-46, 11, 25), Color3.fromRGB(73, 167, 195))
wallSign("ArraySign", "OBSERVATION ARRAY  /  AUTHORIZED PERSONNEL", Vector3.new(48, 11, 23), Color3.fromRGB(83, 184, 220))
wallSign("ControlSign", "SIGNAL CONTROL  /  RECORDING ACTIVE", Vector3.new(10, 11, 46), Color3.fromRGB(124, 155, 206))
wallSign("ContainmentSign", "CONTAINMENT 03  /  DO NOT CYCLE POWER", Vector3.new(96, 11, 24), Color3.fromRGB(200, 76, 75))

-- Sliding blast doors.
maintenanceDoor = part("MaintenanceDoor", Vector3.new(3, 11, 15), CFrame.new(-45, 5.5, -17.5), Enum.Material.Metal, Color3.fromRGB(59, 71, 82), architecture)
addSign(maintenanceDoor, "MAINTENANCE", 185, 40, Vector3.new(0, 6.5, 0))
arrayGate = part("ArrayAccessGate", Vector3.new(3, 10, 20), CFrame.new(48, 5, 5), Enum.Material.Metal, Color3.fromRGB(58, 73, 86), architecture)
addSign(arrayGate, "TRANSFER GATE", 185, 40, Vector3.new(0, 6, 0))
signalShutter = part("SignalShutter", Vector3.new(24, 10, 3), CFrame.new(9, 5, 40), Enum.Material.Metal, Color3.fromRGB(61, 72, 85), architecture)
addSign(signalShutter, "SIGNAL CONTROL", 185, 40, Vector3.new(0, 6, 0))
exitRouteGate = part("ExitRouteGate", Vector3.new(60, 10, 3), CFrame.new(95, 5, -39), Enum.Material.Metal, Color3.fromRGB(61, 72, 85), architecture)
addSign(exitRouteGate, "OUTER ROUTE", 185, 40, Vector3.new(0, 6, 0))
exitDoor = part("EmergencyExitDoor", Vector3.new(24, 12, 3), CFrame.new(80, 6, -85), Enum.Material.Metal, Color3.fromRGB(69, 78, 90), architecture)
addSign(exitDoor, "SURFACE ACCESS", 200, 40, Vector3.new(0, 7, 0))

-- Recessed light fixtures: powered lights initially off, small emergency lamps remain dim.
facilityLights = {}
emergencyStatusLights = {}
redAlarmLights = {}
lowerRouteLights = {}
exitRouteLights = {}

local function addCeilingLight(x: number, z: number, color: Color3, brightness: number, range: number)
    local fixture = part("CeilingFixture", Vector3.new(6, 0.3, 1.4), CFrame.new(x, 18.2, z), Enum.Material.Neon, color, props, 0.35, false)
    local light = pointLight(fixture, "FixtureLight", color, brightness, range, false)
    table.insert(facilityLights, light)
    return fixture, light
end
for _, pos in ipairs({
    Vector3.new(0, 0, -66), Vector3.new(-20, 0, -46), Vector3.new(-20, 0, -12),
    Vector3.new(-82, 0, -16), Vector3.new(-95, 0, 24), Vector3.new(-87, 0, 65),
    Vector3.new(15, 0, 8), Vector3.new(23, 0, 26), Vector3.new(72, 0, -17),
    Vector3.new(85, 0, 12), Vector3.new(104, 0, 36), Vector3.new(10, 0, 59),
    Vector3.new(26, 0, 76), Vector3.new(82, 0, -58), Vector3.new(82, 0, -76),
}) do
    addCeilingLight(pos.X, pos.Z, Color3.fromRGB(174, 204, 220), 1.1, 32)
end

local function addRouteLamp(parent: Instance, name: string, pos: Vector3, color: Color3, enabled: boolean)
    local lamp = part(name, Vector3.new(0.55, 0.35, 0.55), CFrame.new(pos), Enum.Material.Neon, color, parent, if enabled then 0 else 0.7, false)
    local glow = pointLight(lamp, name .. "Glow", color, 0.7, 9, enabled)
    return lamp, glow
end
for z = -68, -45, 7 do
    local lamp = addRouteLamp(effects, "EmergencyAmber", Vector3.new(-15, 1.1, z), Color3.fromRGB(223, 144, 64), true)
    table.insert(emergencyStatusLights, lamp)
end
for z = -65, 80, 15 do
    local lamp, glow = addRouteLamp(effects, "ExitRouteLamp", Vector3.new(112, 1.4, z), Color3.fromRGB(230, 65, 61), false)
    glow.Name = "ExitGlow"
    table.insert(exitRouteLights, lamp)
end
for _, pos in ipairs({Vector3.new(47, 1.5, 15), Vector3.new(47, 1.5, -1), Vector3.new(30, 1.5, 7)}) do
    local lamp, glow = addRouteLamp(effects, "LowerTransferLamp", pos, Color3.fromRGB(88, 205, 234), false)
    glow.Name = "RouteGlow"
    table.insert(lowerRouteLights, lamp)
end
for _, pos in ipairs({Vector3.new(48, 12, 28), Vector3.new(112, 12, 27), Vector3.new(80, 12, -40)}) do
    local lamp, glow = addRouteLamp(effects, "RedAlarmBeacon", pos, Color3.fromRGB(255, 53, 52), false)
    glow.Name = "AlarmGlow"
    table.insert(redAlarmLights, glow)
end

-- Set-dressing helper: repeatable, consistent industrial props.
local function createCrate(position: Vector3, size: Vector3, color: Color3?)
    local box = part("SupplyCrate", size, CFrame.new(position), Enum.Material.Metal, color or Color3.fromRGB(62, 73, 84), props)
    for side = -1, 1, 2 do
        part("CrateBrace", Vector3.new(size.X + 0.08, 0.12, 0.12), box.CFrame * CFrame.new(0, side * (size.Y * 0.28), -(size.Z / 2 + 0.07)), Enum.Material.Metal, Color3.fromRGB(119, 130, 139), props)
    end
    return box
end

local function serverRack(position: Vector3)
    local rack = part("ServerRack", Vector3.new(4.2, 8, 2.5), CFrame.new(position), Enum.Material.Metal, Color3.fromRGB(27, 34, 43), props)
    for y = -2.7, 2.8, 1.35 do
        local shelf = part("RackShelf", Vector3.new(3.75, 0.12, 2.2), rack.CFrame * CFrame.new(0, y, -0.1), Enum.Material.Metal, Color3.fromRGB(58, 72, 85), props)
        local led = part("RackLED", Vector3.new(0.12, 0.25, 0.08), shelf.CFrame * CFrame.new(1.55, 0, -1.13), Enum.Material.Neon, if math.random() < 0.65 then Color3.fromRGB(61, 204, 170) else Color3.fromRGB(203, 79, 69), props, 0, false)
        pointLight(led, "LEDGlow", led.Color, 0.15, 3)
    end
    return rack
end

local function addPipeRun(startPos: Vector3, endPos: Vector3, diameter: number, color: Color3)
    local delta = endPos - startPos
    local mid = (startPos + endPos) / 2
    local p = part("PipeRun", Vector3.new(diameter, delta.Magnitude, diameter), CFrame.lookAt(mid, endPos) * CFrame.Angles(math.rad(90), 0, 0), Enum.Material.Metal, color, props)
    p.Shape = Enum.PartType.Cylinder
    return p
end

-- Main entrance / reception. The outside is sealed off by the roof; the room is intentionally moody.
local entryDesk = part("ReceptionDesk", Vector3.new(13, 3.2, 3), CFrame.new(18, 1.6, -61), Enum.Material.Metal, Color3.fromRGB(42, 51, 61), props)
part("DeskTop", Vector3.new(13.4, 0.22, 3.3), entryDesk.CFrame * CFrame.new(0, 1.7, 0), Enum.Material.Metal, Color3.fromRGB(87, 99, 111), props)
local deadMonitor = part("DarkMonitor", Vector3.new(2.8, 2, 0.35), CFrame.new(16, 4.2, -60), Enum.Material.Glass, Color3.fromRGB(12, 22, 31), props)
addSign(deadMonitor, "NO SIGNAL", 100, 30, Vector3.new(0, 1.8, 0), Color3.fromRGB(96, 118, 139))
createCrate(Vector3.new(-15, 1.5, -55), Vector3.new(3, 3, 3))
createCrate(Vector3.new(-10, 1, -48), Vector3.new(2, 2, 2), Color3.fromRGB(62, 63, 60))
part("BrokenCeilingPanel", Vector3.new(7, 0.18, 3), CFrame.new(26, 17.2, -46) * CFrame.Angles(0, 0, math.rad(14)), Enum.Material.Metal, Color3.fromRGB(57, 67, 75), props, 0, false)

-- Power / maintenance room: switchgear cabinets, cable conduits and an actual blast door.
for i = 0, 3 do
    local rack = part("PowerCabinet", Vector3.new(4.4, 8, 3.2), CFrame.new(-109 + i * 13, 4, -4), Enum.Material.Metal, Color3.fromRGB(46, 58, 68), props)
    part("CabinetFace", Vector3.new(3.6, 6.7, 0.14), rack.CFrame * CFrame.new(0, 0, -1.68), Enum.Material.Metal, Color3.fromRGB(25, 35, 43), props)
    for j = 1, 4 do
        part("Switch", Vector3.new(0.25, 0.5, 0.18), rack.CFrame * CFrame.new(-1.1 + j * 0.42, 0.9, -1.79), Enum.Material.Neon, if j == 1 then Color3.fromRGB(221, 93, 68) else Color3.fromRGB(77, 122, 140), props, 0, false)
    end
end
addPipeRun(Vector3.new(-120, 13.8, 22), Vector3.new(-54, 13.8, 22), 1, Color3.fromRGB(67, 107, 119))
addPipeRun(Vector3.new(-120, 12.5, 26), Vector3.new(-54, 12.5, 26), 0.65, Color3.fromRGB(125, 80, 61))

powerConsole = part("PrimaryPowerConsole", Vector3.new(5.4, 4.4, 2.4), CFrame.new(-29, 2.8, -34), Enum.Material.Metal, Color3.fromRGB(55, 66, 78), interactables)
addSign(powerConsole, "PRIMARY POWER", 218, 44, Vector3.new(0, 3.3, 0), Color3.fromRGB(210, 159, 77))
local powerLamp = part("PowerStatus", Vector3.new(0.5, 0.5, 0.16), powerConsole.CFrame * CFrame.new(0, 1.15, -1.28), Enum.Material.Neon, Color3.fromRGB(239, 171, 65), powerConsole, 0, false)
pointLight(powerLamp, "StandbyGlow", Color3.fromRGB(239, 171, 65), 0.25, 5, false)
addPrompt(powerConsole, "Primary Grid", "Engage", "RestorePower")

-- A dark archive side room with optional story, shelving, and an unlit terminal.
for i = 0, 4 do
    local cabinet = part("ArchiveShelf", Vector3.new(2, 7, 12), CFrame.new(-116 + i * 13, 3.5, 61), Enum.Material.Metal, Color3.fromRGB(42, 49, 58), props)
    for shelfY = -2.2, 2.2, 1.5 do
        part("ArchiveShelfLip", Vector3.new(2.15, 0.14, 12.2), cabinet.CFrame * CFrame.new(0, shelfY, 0), Enum.Material.Metal, Color3.fromRGB(81, 88, 98), props)
    end
end
local archiveTerminal = part("ArchiveTerminal", Vector3.new(3.5, 3, 1.8), CFrame.new(-56, 2, 66), Enum.Material.Metal, Color3.fromRGB(45, 56, 67), interactables)
addSign(archiveTerminal, "INCIDENT ARCHIVE", 210, 40, Vector3.new(0, 2.5, 0), Color3.fromRGB(104, 156, 184))
local archiveScreen = part("ArchiveScreen", Vector3.new(2.4, 1.4, 0.12), archiveTerminal.CFrame * CFrame.new(0, 0.9, -0.95), Enum.Material.Neon, Color3.fromRGB(28, 99, 116), props, 0.12, false)
pointLight(archiveScreen, "ScreenGlow", Color3.fromRGB(48, 158, 181), 0.4, 7)
addPrompt(archiveTerminal, "Incident Archive", "Review", "ReadArchive")

-- Drainage room with large pump, pipes and water-level marks.
pumpHousing = part("DrainagePumpHousing", Vector3.new(11, 5.2, 8), CFrame.new(-91, 2.6, 24), Enum.Material.Metal, Color3.fromRGB(38, 66, 76), props)
addSign(pumpHousing, "TRANSFER PUMP  /  D-03", 225, 42, Vector3.new(0, 3.5, 0), Color3.fromRGB(80, 176, 194))
for i = 0, 2 do
    local wheel = part("PumpWheel", Vector3.new(0.8, 3, 3), CFrame.new(-97 + i * 5, 3.7, 19), Enum.Material.Metal, Color3.fromRGB(100, 119, 131), props)
    wheel.Shape = Enum.PartType.Cylinder
    wheel.CFrame = wheel.CFrame * CFrame.Angles(0, 0, math.rad(90))
    pointLight(wheel, "PumpIndicator", Color3.fromRGB(72, 152, 173), 0.15, 3)
end
addPipeRun(Vector3.new(-119, 8.5, 33), Vector3.new(-55, 8.5, 33), 1.2, Color3.fromRGB(74, 116, 127))
addPipeRun(Vector3.new(-119, 6.4, 37), Vector3.new(-55, 6.4, 37), 0.65, Color3.fromRGB(147, 92, 65))
pumpConsole = part("DrainageControl", Vector3.new(4.6, 4.1, 2.2), CFrame.new(-58, 2.55, 19), Enum.Material.Metal, Color3.fromRGB(51, 65, 76), interactables)
addSign(pumpConsole, "DRAINAGE CONTROL", 238, 42, Vector3.new(0, 3.2, 0), Color3.fromRGB(79, 172, 190))
local pumpLamp = part("PumpStatus", Vector3.new(0.45, 0.45, 0.16), pumpConsole.CFrame * CFrame.new(0, 1.12, -1.16), Enum.Material.Neon, Color3.fromRGB(214, 151, 71), pumpConsole, 0, false)
pointLight(pumpLamp, "PumpStandbyGlow", Color3.fromRGB(219, 153, 71), 0.25, 5, false)
pumpPrompt = addPrompt(pumpConsole, "Drainage Control", "Stabilize Flow", "StabilizePump", false)

-- Flooded transfer corridor, visible from the central hall through reinforced glass.
local waterWindow = part("TransferWindow", Vector3.new(0.6, 7.5, 25), CFrame.new(14, 4.7, 18), Enum.Material.Glass, Color3.fromRGB(38, 107, 137), architecture, 0.62, true)
part("FloodWater", Vector3.new(60, 1.8, 22), CFrame.new(16, 1.75, 5), Enum.Material.Glass, Color3.fromRGB(35, 124, 160), effects, 0.32, false)
floodwater = effects:FindFirstChild("FloodWater")
local waterGlowPart = part("WaterGlowSource", Vector3.new(1, 1, 1), CFrame.new(16, 1.7, 5), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), effects, 1, false)
pointLight(waterGlowPart, "WaterGlow", Color3.fromRGB(32, 126, 183), 1.5, 45)

-- Observation chamber and an array that visibly rotates under strain.
arrayCore = Instance.new("Model")
arrayCore.Name = "ObservationArrayCore"
arrayCore.Parent = props
local arrayCenter = Vector3.new(82, 8.5, 11)
local arrayBase = part("ArrayBase", Vector3.new(14, 1.3, 14), CFrame.new(82, 1.1, 11), Enum.Material.Metal, Color3.fromRGB(45, 63, 76), arrayCore)
arrayCore.PrimaryPart = arrayBase
part("ArrayColumn", Vector3.new(4.5, 12, 4.5), CFrame.new(82, 7, 11), Enum.Material.Metal, Color3.fromRGB(56, 76, 90), arrayCore)
for ringIndex = 1, 3 do
    local radius = 4.4 + ringIndex * 1.1
    local yCenter = 5.8 + ringIndex * 2
    for segment = 1, 12 do
        local angle = math.rad((segment - 1) * 30)
        local pos = Vector3.new(arrayCenter.X + math.cos(angle) * radius, yCenter + math.sin(angle) * radius, arrayCenter.Z + (ringIndex - 2) * 1.2)
        local bar = part("ArrayRingSegment", Vector3.new(0.55, 0.42, 1.7), CFrame.new(pos) * CFrame.Angles(0, 0, angle), Enum.Material.Neon, Color3.fromRGB(73, 166, 205), arrayCore, 0.14, false)
    end
end
local arrayEnergyNode = part("ArrayEnergyNode", Vector3.new(2.2, 2.2, 2.2), CFrame.new(82, 8, 11), Enum.Material.Neon, Color3.fromRGB(103, 204, 255), arrayCore, 0.05, false)
arrayEnergyLight = pointLight(arrayEnergyNode, "ArrayPulseLight", Color3.fromRGB(77, 173, 230), 1.6, 28, true)
local arrayObservationGlass = part("ObservationGlass", Vector3.new(0.6, 9, 18), CFrame.new(48, 5.5, 28), Enum.Material.Glass, Color3.fromRGB(70, 139, 164), architecture, 0.58, true)
arrayConsole = part("ArrayControl", Vector3.new(4.5, 4, 2.4), CFrame.new(66, 2.5, -3), Enum.Material.Metal, Color3.fromRGB(49, 64, 76), interactables)
addSign(arrayConsole, "ARRAY CONTROL", 208, 42, Vector3.new(0, 3, 0), Color3.fromRGB(83, 185, 219))
local arrayLamp = part("ArrayStatus", Vector3.new(0.45, 0.45, 0.16), arrayConsole.CFrame * CFrame.new(0, 1.1, -1.26), Enum.Material.Neon, Color3.fromRGB(72, 171, 210), arrayConsole, 0, false)
pointLight(arrayLamp, "ArrayStatusGlow", Color3.fromRGB(70, 172, 220), 0.3, 5, false)
addPrompt(arrayConsole, "Observation Array", "Engage", "ActivateArray")

-- Control room: desks, consoles, recording equipment, and the shutter that reacts to the array.
for i = 0, 2 do
    local rack = serverRack(Vector3.new(-14 + i * 12, 4, 70))
end
local controlDesk = part("ControlDesk", Vector3.new(20, 2.4, 4), CFrame.new(14, 1.2, 61), Enum.Material.Metal, Color3.fromRGB(39, 48, 60), props)
for i = 0, 3 do
    local monitor = part("SignalMonitor", Vector3.new(3.5, 2.2, 0.25), controlDesk.CFrame * CFrame.new(-7 + i * 4.7, 1.3, -1.8), Enum.Material.Glass, Color3.fromRGB(14, 35, 46), props, 0.12, false)
    part("MonitorScreen", Vector3.new(3, 1.7, 0.08), monitor.CFrame * CFrame.new(0, 0, -0.17), Enum.Material.Neon, Color3.fromRGB(33, 103, 120), props, 0.1, false)
end
signalConsole = part("SignalConsole", Vector3.new(4.4, 4, 2), CFrame.new(11, 2.5, 76), Enum.Material.Metal, Color3.fromRGB(50, 63, 75), interactables)
addSign(signalConsole, "RECOVERY TRANSMITTER", 250, 44, Vector3.new(0, 3, 0), Color3.fromRGB(128, 157, 214))
local signalLamp = part("SignalStatus", Vector3.new(0.45, 0.45, 0.16), signalConsole.CFrame * CFrame.new(0, 1.1, -1.08), Enum.Material.Neon, Color3.fromRGB(220, 167, 71), signalConsole, 0, false)
pointLight(signalLamp, "SignalStandbyGlow", Color3.fromRGB(220, 167, 71), 0.25, 5, false)
signalPrompt = addPrompt(signalConsole, "Recovery Transmitter", "Transmit", "TransmitSignal", false)
for i = 1, 4 do
    local cable = part("SignalCable", Vector3.new(0.18, 0.18, 15), CFrame.new(-5 + i * 3.2, 0.7, 66), Enum.Material.Neon, Color3.fromRGB(25, 76, 91), props, 0.2, false)
end

-- Containment cell in the observation wing. It is visible through glass long before its door opens.
local cellX, cellZ = 102, 35
local glassColor = Color3.fromRGB(53, 101, 125)
part("ContainmentGlassWest", Vector3.new(2, 11, 38), CFrame.new(82, 5.5, cellZ), Enum.Material.Glass, glassColor, architecture, 0.58, true)
part("ContainmentGlassNorth", Vector3.new(34, 11, 2), CFrame.new(99, 5.5, 54), Enum.Material.Glass, glassColor, architecture, 0.58, true)
part("ContainmentGlassEast", Vector3.new(2, 11, 38), CFrame.new(116, 5.5, cellZ), Enum.Material.Glass, glassColor, architecture, 0.58, true)
part("ContainmentGlassSouthLeft", Vector3.new(14, 11, 2), CFrame.new(89, 5.5, 16), Enum.Material.Glass, glassColor, architecture, 0.58, true)
part("ContainmentGlassSouthRight", Vector3.new(13, 11, 2), CFrame.new(109.5, 5.5, 16), Enum.Material.Glass, glassColor, architecture, 0.58, true)
containmentDoor = part("ContainmentDoor", Vector3.new(7, 10, 2.5), CFrame.new(99.5, 5, 16), Enum.Material.Metal, Color3.fromRGB(57, 70, 81), architecture)
addSign(containmentDoor, "CONTAINMENT 03", 205, 42, Vector3.new(0, 6, 0), Color3.fromRGB(191, 76, 77))
local redCellLamp = part("CellWarning", Vector3.new(2.4, 0.3, 0.4), CFrame.new(99, 10.8, 14.4), Enum.Material.Neon, Color3.fromRGB(191, 48, 48), props, 0.1, false)
pointLight(redCellLamp, "CellWarningGlow", Color3.fromRGB(210, 45, 45), 0.8, 10, true)
for i = 0, 3 do
    part("ContainmentMark", Vector3.new(0.3, 7, 0.3), CFrame.new(86 + i * 8, 3.5, 15), Enum.Material.Metal, Color3.fromRGB(86, 96, 106), props)
end

-- Final escape corridor and an exterior landing beyond the door.
wall("ExitCorridorWest", Vector3.new(2, 15, 45), Vector3.new(65, 7.5, -61))
wall("ExitCorridorEast", Vector3.new(2, 15, 45), Vector3.new(125, 7.5, -61))
part("ExteriorLanding", Vector3.new(55, 1, 34), CFrame.new(80, -0.55, -105), Enum.Material.Concrete, Color3.fromRGB(29, 37, 46), architecture)
for i = 0, 4 do
    local lamp = part("ExteriorFloodlight", Vector3.new(0.35, 7, 0.35), CFrame.new(57 + i * 11.5, 3.5, -116), Enum.Material.Metal, Color3.fromRGB(62, 77, 92), props)
    pointLight(lamp, "FloodlightBeam", Color3.fromRGB(143, 189, 211), 0.65, 22, true)
end
exitTrigger = part("ExitThreshold", Vector3.new(24, 8, 7), CFrame.new(80, 4, -101), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), effects, 1, false)
exitTrigger.CanTouch = false
exitTrigger.Touched:Connect(function(hit)
    if state.signalSent and not state.escaped then
        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        if player then
            local result = CascadeState.apply(state, "Escape")
            if result.ok then
                eventRemote:FireAllClients("RunComplete", {text = "RUN COMPLETE  —  THE SIGNAL WAS NOT ALONE"})
                eventRemote:FireAllClients("Status", {text = "SITE 07  /  EVACUATED"})
                creatureActive = false
                if creatureModel then creatureModel:SetAttribute("Active", false) end
                if alarmSound and alarmSound.IsPlaying then alarmSound:Stop() end
            end
        end
    end
end)

-- Steam/vent effects make the space feel operational. They are restrained and localized.
local function addSteamVent(position: Vector3, rate: number)
    local vent = part("SteamVent", Vector3.new(1.4, 0.3, 1.4), CFrame.new(position), Enum.Material.Metal, Color3.fromRGB(67, 81, 91), props)
    local attachment = Instance.new("Attachment")
    attachment.Parent = vent
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "Steam"
    emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
    emitter.Rate = rate
    emitter.Lifetime = NumberRange.new(1.8, 3.1)
    emitter.Speed = NumberRange.new(1.1, 2.5)
    emitter.SpreadAngle = Vector2.new(18, 18)
    emitter.Rotation = NumberRange.new(0, 360)
    emitter.RotSpeed = NumberRange.new(-14, 14)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.45),
        NumberSequenceKeypoint.new(0.6, 1.25),
        NumberSequenceKeypoint.new(1, 1.7),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.62),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Color = ColorSequence.new(Color3.fromRGB(144, 163, 176), Color3.fromRGB(87, 101, 116))
    emitter.Parent = attachment
    return vent
end
addSteamVent(Vector3.new(-56, 8.6, 31), 4)
addSteamVent(Vector3.new(38, 8.6, 27), 3)
addSteamVent(Vector3.new(119, 8.6, -57), 2)

-- Create the creature rig. It remains behind glass until the array wakes it.
local function makeJoint(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
    local joint = Instance.new("Motor6D")
    joint.Name = name
    joint.Part0 = part0
    joint.Part1 = part1
    joint.C0 = c0
    joint.C1 = c1
    joint.Parent = part0
    return joint
end

local function makeCreature()
    local model = Instance.new("Model")
    model.Name = "ContainmentSubject"
    model:SetAttribute("Active", false)
    model:SetAttribute("BuildVersion", 3)

    local base = Vector3.new(101, 4.8, 35)
    local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(base), Enum.Material.SmoothPlastic, Color3.fromRGB(10, 12, 17), model, 1, false)
    root.Anchored = false
    root.CanCollide = false
    root.CastShadow = false

    local torso = part("Torso", Vector3.new(2.8, 3.3, 1.3), CFrame.new(base), Enum.Material.SmoothPlastic, Color3.fromRGB(9, 12, 18), model)
    torso.Anchored = false
    torso.CanCollide = true

    local head = part("Head", Vector3.new(1.5, 1.65, 1.25), CFrame.new(base + Vector3.new(0, 2.45, -0.05)), Enum.Material.SmoothPlastic, Color3.fromRGB(5, 7, 12), model, 0, false)
    head.Anchored = false
    head.CanCollide = false

    local leftArm = part("Left Arm", Vector3.new(0.85, 3.5, 0.9), CFrame.new(base + Vector3.new(-1.8, -0.15, 0)), Enum.Material.SmoothPlastic, Color3.fromRGB(8, 10, 15), model, 0, false)
    local rightArm = part("Right Arm", Vector3.new(0.85, 3.5, 0.9), CFrame.new(base + Vector3.new(1.8, -0.15, 0)), Enum.Material.SmoothPlastic, Color3.fromRGB(8, 10, 15), model, 0, false)
    local leftLeg = part("Left Leg", Vector3.new(1, 2.8, 1), CFrame.new(base + Vector3.new(-0.62, -2.3, 0)), Enum.Material.SmoothPlastic, Color3.fromRGB(12, 15, 21), model)
    local rightLeg = part("Right Leg", Vector3.new(1, 2.8, 1), CFrame.new(base + Vector3.new(0.62, -2.3, 0)), Enum.Material.SmoothPlastic, Color3.fromRGB(12, 15, 21), model)
    for _, limb in ipairs({leftArm, rightArm, leftLeg, rightLeg}) do
        limb.Anchored = false
        limb.Massless = true
    end

    makeJoint("RootJoint", root, torso, CFrame.new(), CFrame.new())
    makeJoint("Neck", torso, head, CFrame.new(0, 1.6, 0), CFrame.new(0, -0.75, 0))
    local leftShoulder = makeJoint("Left Shoulder", torso, leftArm, CFrame.new(-1.2, 0.8, 0), CFrame.new(0.45, 1.25, 0))
    local rightShoulder = makeJoint("Right Shoulder", torso, rightArm, CFrame.new(1.2, 0.8, 0), CFrame.new(-0.45, 1.25, 0))
    local leftHip = makeJoint("Left Hip", torso, leftLeg, CFrame.new(-0.65, -1.3, 0), CFrame.new(0, 1.25, 0))
    local rightHip = makeJoint("Right Hip", torso, rightLeg, CFrame.new(0.65, -1.3, 0), CFrame.new(0, 1.25, 0))

    local eyeLeft = part("Eye", Vector3.new(0.29, 0.12, 0.07), head.CFrame * CFrame.new(-0.38, 0.12, -0.63), Enum.Material.Neon, Color3.fromRGB(255, 45, 42), model, 0, false)
    local eyeRight = part("Eye", Vector3.new(0.29, 0.12, 0.07), head.CFrame * CFrame.new(0.38, 0.12, -0.63), Enum.Material.Neon, Color3.fromRGB(255, 45, 42), model, 0, false)
    for _, eye in ipairs({eyeLeft, eyeRight}) do
        eye.Anchored = false
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = head
        weld.Part1 = eye
        weld.Parent = eye
        pointLight(eye, "EyeGlow", Color3.fromRGB(255, 31, 25), 0.85, 9, true)
    end

    local humanoid = Instance.new("Humanoid")
    humanoid.Name = "Humanoid"
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.WalkSpeed = 15
    humanoid.JumpPower = 38
    humanoid.MaxHealth = 500
    humanoid.Health = 500
    humanoid.BreakJointsOnDeath = false
    humanoid.RequiresNeck = true
    humanoid.Parent = model

    model.PrimaryPart = root
    model.Parent = world
    pcall(function() root:SetNetworkOwner(nil) end)

    local footSound = makeSound(root, "1244506786", "SubjectFootsteps", 0.18, true, 1.25, 65)
    local growlSound = makeSound(root, "74103327872448", "SubjectGrowl", 0.6, false, 0.8, 100)
    local joints = {
        leftShoulder = leftShoulder,
        rightShoulder = rightShoulder,
        leftHip = leftHip,
        rightHip = rightHip,
        leftShoulderBase = leftShoulder.C0,
        rightShoulderBase = rightShoulder.C0,
        leftHipBase = leftHip.C0,
        rightHipBase = rightHip.C0,
    }

    task.spawn(function()
        local startClock = os.clock()
        local lastStep = 0
        while model.Parent and humanoid.Health > 0 do
            local t = os.clock() - startClock
            local moving = root.AssemblyLinearVelocity.Magnitude > 2 and creatureActive
            if moving then
                local swing = math.sin(t * 8) * 0.48
                joints.leftHip.C0 = joints.leftHipBase * CFrame.Angles(swing, 0, 0)
                joints.rightHip.C0 = joints.rightHipBase * CFrame.Angles(-swing, 0, 0)
                joints.leftShoulder.C0 = joints.leftShoulderBase * CFrame.Angles(-swing * 0.7, 0, -0.15)
                joints.rightShoulder.C0 = joints.rightShoulderBase * CFrame.Angles(swing * 0.7, 0, 0.15)
                if not footSound.IsPlaying then footSound:Play() end
            else
                if footSound.IsPlaying then footSound:Stop() end
                joints.leftHip.C0 = joints.leftHipBase
                joints.rightHip.C0 = joints.rightHipBase
                joints.leftShoulder.C0 = joints.leftShoulderBase
                joints.rightShoulder.C0 = joints.rightShoulderBase
            end
            task.wait(0.08)
        end
    end)

    return model, humanoid, root, growlSound
end

creatureModel, creatureHumanoid, creatureRoot, creatureGrowl = makeCreature()
creatureActive = false

-- Pathfinding pursuit: line-of-sight acquisition, last-known-position memory, search, then patrol.
local lastKnownPosition: Vector3? = nil
local lastSeenAt = 0
local lastDamageAt = {}
local lastPathAt = 0
local patrolPoints = {
    Vector3.new(72, 3, 14),
    Vector3.new(28, 3, 22),
    Vector3.new(16, 3, 58),
    Vector3.new(-20, 3, 8),
    Vector3.new(-16, 3, -55),
    Vector3.new(84, 3, -60),
}
local patrolIndex = 1
local nextGrowlAt = 0
local function targetVisible(character: Model, targetRoot: BasePart): boolean
    if not creatureRoot then return false end
    local origin = creatureRoot.Position + Vector3.new(0, 1.4, 0)
    local direction = targetRoot.Position - origin
    if direction.Magnitude > 125 then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {creatureModel}
    params.IgnoreWater = true
    local hit = workspace:Raycast(origin, direction, params)
    return hit == nil or hit.Instance:IsDescendantOf(character)
end

local function nearestVisiblePlayer()
    local bestPlayer = nil
    local bestRoot = nil
    local bestHumanoid = nil
    local bestDistance = math.huge
    for _, player in Players:GetPlayers() do
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        if root and root:IsA("BasePart") and hum and hum.Health > 0 then
            local distance = (root.Position - creatureRoot.Position).Magnitude
            if distance < bestDistance and targetVisible(character, root) then
                bestPlayer = player
                bestRoot = root
                bestHumanoid = hum
                bestDistance = distance
            end
        end
    end
    return bestPlayer, bestRoot, bestHumanoid, bestDistance
end

local function moveToward(goal: Vector3)
    if not creatureHumanoid or not creatureRoot then return end
    local path = PathfindingService:CreatePath({
        AgentRadius = 2.2,
        AgentHeight = 7,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 5,
    })
    local computed = pcall(function()
        path:ComputeAsync(creatureRoot.Position, goal)
    end)
    if computed and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        local waypoint = waypoints[2] or waypoints[1]
        if waypoint then
            if waypoint.Action == Enum.PathWaypointAction.Jump then
                creatureHumanoid.Jump = true
            end
            creatureHumanoid:MoveTo(waypoint.Position)
            return
        end
    end
    creatureHumanoid:MoveTo(goal)
end

task.spawn(function()
    while creatureModel and creatureModel.Parent do
        if creatureHumanoid and creatureHumanoid.Health > 0 and creatureRoot and not creatureActive then
            local now = os.clock()
            if now - lastPathAt > 5.5 then
                lastPathAt = now
                local idlePoint = Vector3.new(math.random(93, 108), 3, math.random(25, 45))
                moveToward(idlePoint)
            end
        elseif creatureActive and creatureHumanoid and creatureHumanoid.Health > 0 and creatureRoot then
            local now = os.clock()
            local player, targetRoot, targetHumanoid, targetDistance = nearestVisiblePlayer()
            if player and targetRoot then
                lastKnownPosition = targetRoot.Position
                lastSeenAt = now
                if targetDistance < 5.5 and targetHumanoid then
                    local previous = lastDamageAt[player.UserId] or 0
                    if now - previous > 1.45 then
                        lastDamageAt[player.UserId] = now
                        targetHumanoid:TakeDamage(32)
                        eventRemote:FireClient(player, "Threat", {distance = targetDistance, hit = true})
                        if creatureGrowl then creatureGrowl:Play() end
                    end
                elseif targetDistance < 35 then
                    eventRemote:FireClient(player, "Threat", {distance = targetDistance, hit = false})
                end
            end

            local goal: Vector3
            if lastKnownPosition and (now - lastSeenAt) < 8 then
                goal = lastKnownPosition
            else
                if (creatureRoot.Position - patrolPoints[patrolIndex]).Magnitude < 7 then
                    patrolIndex = (patrolIndex % #patrolPoints) + 1
                end
                goal = patrolPoints[patrolIndex]
            end

            if now - lastPathAt > 1.15 then
                lastPathAt = now
                moveToward(goal)
            end

            if now > nextGrowlAt then
                nextGrowlAt = now + math.random(11, 19)
                if creatureGrowl then creatureGrowl:Play() end
            end
        end
        task.wait(0.18)
    end
end)

-- Low-cost random distant impacts sell that the building extends beyond the visible room.
task.spawn(function()
    local bangPoints = {
        Vector3.new(-115, 7, 48),
        Vector3.new(-5, 7, 28),
        Vector3.new(118, 7, 50),
        Vector3.new(40, 7, -57),
        Vector3.new(100, 7, -65),
    }
    while world.Parent do
        task.wait(math.random(18, 31))
        local position = bangPoints[math.random(1, #bangPoints)]
        local anchor = part("DistantImpactSource", Vector3.new(0.5, 0.5, 0.5), CFrame.new(position), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), audioPoints, 1, false)
        oneShot(anchor, "3611209852", "DistantMetalImpact", if state.cascade then 0.43 else 0.2, 0.7 + math.random() * 0.4, 100)
        Debris:AddItem(anchor, 16)
    end
end)

-- Creature wakes on the causal cascade; random motion and sounds remain after the jump in tension.
-- Ensure a valid, intentionally stable development spawn.
local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation")
if not spawnLocation then
    spawnLocation = Instance.new("SpawnLocation")
    spawnLocation.Name = "CascadeSpawn"
    spawnLocation.Parent = workspace
end
spawnLocation.Name = "CascadeSpawn"
spawnLocation.Size = Vector3.new(7, 1, 7)
spawnLocation.Position = Vector3.new(0, 0.55, -72)
spawnLocation.Anchored = true
spawnLocation.Neutral = true
spawnLocation.Transparency = 0.35
spawnLocation.Material = Enum.Material.Metal
spawnLocation.Color = Color3.fromRGB(65, 100, 116)

-- One clear identity mark proves that this is the current, newly synced build.
local buildMark = part("BuildMarker", Vector3.new(1, 1, 1), CFrame.new(0, 8, -75), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), props, 1, false)
addSign(buildMark, "SITE 07  /  FIELD PLAYTEST 03", 360, 44, Vector3.new(0, 0, 0), Color3.fromRGB(75, 174, 204))

-- Sounds are positional where a world source matters. Free-to-use Creator Store audio IDs are used.
pumpStartSound = makeSound(pumpHousing, "9113910297", "PumpStartup", 0.7, false, 0.83, 100)
alarmSound = makeSound(SoundService, "5348162330", "FacilityAlarm", 0.36, true, 0.85, 10000)
alarmSound.RollOffMaxDistance = 10000
darkWorldMusic = makeSound(SoundService, "9044889073", "CascadeTension", 0.16, true, 0.83, 10000)

-- State/UI initialization happens only after the first player joins, so late joiners receive it too.
local function sendInitialUI(player: Player)
    eventRemote:FireClient(player, "Objective", {text = "Restore the observation array's signal. Then get out."})
    eventRemote:FireClient(player, "Status", {text = "SITE 07  /  GRID OFFLINE"})
    eventRemote:FireClient(player, "Build", {version = 3})
end
Players.PlayerAdded:Connect(function(player)
    task.delay(1.1, function()
        if player.Parent then sendInitialUI(player) end
    end)
end)
for _, player in Players:GetPlayers() do
    task.defer(sendInitialUI, player)
end

eventRemote:FireAllClients("Objective", {text = "Restore the observation array's signal. Then get out."})
eventRemote:FireAllClients("Status", {text = "SITE 07  /  GRID OFFLINE"})
eventRemote:FireAllClients("Build", {version = 3})
