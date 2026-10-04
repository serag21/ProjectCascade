local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local CascadeState = require(ReplicatedStorage:WaitForChild("Cascade"):WaitForChild("CascadeState"))

local cascadeRoot = ReplicatedStorage:WaitForChild("Cascade")
local eventsFolder = cascadeRoot:FindFirstChild("Events") or Instance.new("Folder")
eventsFolder.Name = "Events"
eventsFolder.Parent = cascadeRoot

local cascadeEvent = eventsFolder:FindFirstChild("CascadeEvent") or Instance.new("RemoteEvent")
cascadeEvent.Name = "CascadeEvent"
cascadeEvent.Parent = eventsFolder

local state = CascadeState.new()

local world = workspace:FindFirstChild("CascadeFacility")
if world then
    world:Destroy()
end

local oldBaseplate = workspace:FindFirstChild("Baseplate")
if oldBaseplate and oldBaseplate:IsA("BasePart") then
    oldBaseplate:Destroy()
end

world = Instance.new("Folder")
world.Name = "CascadeFacility"
world.Parent = workspace

local geometry = Instance.new("Folder")
geometry.Name = "Geometry"
geometry.Parent = world

local interactables = Instance.new("Folder")
interactables.Name = "Interactables"
interactables.Parent = world

local effects = Instance.new("Folder")
effects.Name = "Effects"
effects.Parent = world

local function createPart(name: string, size: Vector3, cframe: CFrame, material: Enum.Material, color: Color3, parent: Instance, transparency: number?, canCollide: boolean?)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cframe
    p.Anchored = true
    p.Material = material
    p.Color = color
    p.Transparency = transparency or 0
    p.CanCollide = if canCollide == nil then true else canCollide
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function wall(name: string, size: Vector3, position: Vector3)
    return createPart(
        name,
        size,
        CFrame.new(position),
        Enum.Material.Concrete,
        Color3.fromRGB(42, 47, 55),
        geometry
    )
end

local function trim(name: string, size: Vector3, position: Vector3, color: Color3?)
    return createPart(
        name,
        size,
        CFrame.new(position),
        Enum.Material.Metal,
        color or Color3.fromRGB(90, 98, 108),
        geometry
    )
end

local function addBillboard(parent: BasePart, text: string, size: UDim2, offset: Vector3)
    local gui = Instance.new("BillboardGui")
    gui.Name = "Sign"
    gui.Adornee = parent
    gui.Size = size
    gui.StudsOffsetWorldSpace = offset
    gui.AlwaysOnTop = true
    gui.MaxDistance = 70
    gui.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 0.15
    label.BackgroundColor3 = Color3.fromRGB(11, 15, 20)
    label.BorderSizePixel = 0
    label.Text = text
    label.TextColor3 = Color3.fromRGB(226, 232, 240)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 22
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = label

    local stroke = Instance.new("UIStroke")
    stroke.Transparency = 0.65
    stroke.Thickness = 1
    stroke.Parent = label

    return gui
end

local function addStatusLamp(parent: BasePart, offset: Vector3, color: Color3, enabled: boolean)
    local lamp = Instance.new("Part")
    lamp.Name = "StatusLamp"
    lamp.Size = Vector3.new(0.45, 0.45, 0.18)
    lamp.CFrame = parent.CFrame * CFrame.new(offset)
    lamp.Anchored = true
    lamp.CanCollide = false
    lamp.Material = Enum.Material.Neon
    lamp.Color = color
    lamp.Transparency = if enabled then 0 else 0.55
    lamp.Parent = parent

    local light = Instance.new("PointLight")
    light.Name = "LampGlow"
    light.Color = color
    light.Brightness = if enabled then 0.8 else 0
    light.Range = 5
    light.Parent = lamp

    return lamp, light
end

local function addPrompt(console: BasePart, objectText: string, actionText: string, action: string)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = action .. "Prompt"
    prompt.ActionText = actionText
    prompt.ObjectText = objectText
    prompt.HoldDuration = 0.2
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt.Parent = console

    prompt.Triggered:Connect(function()
        if state.objective == "Complete" then
            return
        end

        local result = CascadeState.apply(state, action)
        if not result.ok then
            cascadeEvent:FireAllClients("Event", {
                title = "SYSTEM",
                text = result.message or "That system is not ready.",
            })
            return
        end

        cascadeEvent:FireAllClients("Event", {
            title = "SYSTEM",
            text = result.message or "State changed.",
        })

        for _, eventName in result.events do
            if eventName == "PowerRestored" then
                local lightModel = world:FindFirstChild("FacilityLights")
                if lightModel then
                    for _, item in lightModel:GetDescendants() do
                        if item:IsA("PointLight") or item:IsA("SurfaceLight") then
                            item.Enabled = true
                        end
                    end
                end

                local door = geometry:FindFirstChild("MaintenanceDoor")
                if door and door:IsA("BasePart") then
                    TweenService:Create(
                        door,
                        TweenInfo.new(1.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                        {CFrame = door.CFrame + Vector3.new(0, 9, 0)}
                    ):Play()
                end

                cascadeEvent:FireAllClients("Status", {text = "FACILITY: ONLINE"})
            elseif eventName == "PumpsStarted" then
                local pumpConsole = interactables:FindFirstChild("DrainageControl")
                if pumpConsole and pumpConsole:IsA("BasePart") then
                    local prompt = pumpConsole:FindFirstChildWhichIsA("ProximityPrompt")
                    if prompt then
                        prompt.Enabled = true
                    end
                end
                if pumpConsole and pumpConsole:IsA("BasePart") then
                    local lamp = pumpConsole:FindFirstChild("StatusLamp")
                    if lamp and lamp:IsA("BasePart") then
                        lamp.Transparency = 0
                        local glow = lamp:FindFirstChild("LampGlow")
                        if glow and glow:IsA("PointLight") then
                            glow.Brightness = 0.8
                        end
                    end
                end
                cascadeEvent:FireAllClients("World", {kind = "PumpsStarted"})
            elseif eventName == "DrainageStarted" then
                local gate = geometry:FindFirstChild("LowerRouteGate")
                if gate and gate:IsA("BasePart") then
                    TweenService:Create(
                        gate,
                        TweenInfo.new(1.0, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                        {CFrame = gate.CFrame + Vector3.new(0, 9, 0)}
                    ):Play()
                end

                local water = effects:FindFirstChild("FloodWater")
                if water and water:IsA("BasePart") then
                    TweenService:Create(
                        water,
                        TweenInfo.new(5.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        {Position = water.Position - Vector3.new(0, 5.4, 0)}
                    ):Play()
                end

                local lowerLights = effects:FindFirstChild("LowerRouteLights")
                if lowerLights then
                    for _, lamp in lowerLights:GetChildren() do
                        if lamp:IsA("BasePart") then
                            lamp.Transparency = 0
                        end
                    end
                end

                cascadeEvent:FireAllClients("Status", {text = "LOWER LEVEL: DRAINING"})
            elseif eventName == "EnvironmentChanged" then
                Lighting.Brightness = 1.2
                Lighting.Ambient = Color3.fromRGB(52, 58, 72)
                Lighting.OutdoorAmbient = Color3.fromRGB(27, 31, 40)

                local atmosphere = Lighting:FindFirstChild("CascadeAtmosphere")
                if atmosphere and atmosphere:IsA("Atmosphere") then
                    atmosphere.Density = 0.42
                    atmosphere.Haze = 2
                end

                local arrayCore = geometry:FindFirstChild("ArrayCore")
                if arrayCore and arrayCore:IsA("Model") then
                    local pivotValue = Instance.new("CFrameValue")
                    pivotValue.Value = arrayCore:GetPivot()
                    pivotValue:GetPropertyChangedSignal("Value"):Connect(function()
                        if arrayCore.Parent then
                            arrayCore:PivotTo(pivotValue.Value)
                        end
                    end)

                    local pivotTween = TweenService:Create(
                        pivotValue,
                        TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                        {Value = pivotValue.Value * CFrame.Angles(0, math.rad(55), math.rad(10))}
                    )
                    pivotTween:Play()
                    pivotTween.Completed:Connect(function()
                        pivotValue:Destroy()
                    end)
                end

                local shutter = geometry:FindFirstChild("SignalShutter")
                if shutter and shutter:IsA("BasePart") then
                    TweenService:Create(
                        shutter,
                        TweenInfo.new(1.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                        {CFrame = shutter.CFrame + Vector3.new(0, 8, 0)}
                    ):Play()
                end

                cascadeEvent:FireAllClients("Status", {text = "CASCADE: ACTIVE"})
            elseif eventName == "CascadeStarted" then
                local alarm = effects:FindFirstChild("AlarmLight")
                if alarm and alarm:IsA("PointLight") then
                    task.spawn(function()
                        for _ = 1, 18 do
                            alarm.Enabled = not alarm.Enabled
                            task.wait(0.22)
                        end
                        alarm.Enabled = true
                    end)
                end
            elseif eventName == "SignalRoomOpened" then
                local signalConsole = interactables:FindFirstChild("SignalConsole")
                if signalConsole and signalConsole:IsA("BasePart") then
                    signalConsole.Transparency = 0
                    signalConsole.CanCollide = true
                    local prompt = signalConsole:FindFirstChildWhichIsA("ProximityPrompt")
                    if prompt then
                        prompt.Enabled = true
                    end
                end

                cascadeEvent:FireAllClients("World", {kind = "SignalRoomOpened"})
            elseif eventName == "EmergencyExitOpened" then
                local exitDoor = geometry:FindFirstChild("EmergencyExitDoor")
                if exitDoor and exitDoor:IsA("BasePart") then
                    TweenService:Create(
                        exitDoor,
                        TweenInfo.new(1.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                        {CFrame = exitDoor.CFrame + Vector3.new(0, 9, 0)}
                    ):Play()
                end

                local exitLights = effects:FindFirstChild("ExitRouteLights")
                if exitLights then
                    for _, lamp in exitLights:GetChildren() do
                        if lamp:IsA("BasePart") then
                            lamp.Transparency = 0
                        end
                    end
                end

                cascadeEvent:FireAllClients("Status", {text = "EMERGENCY EXIT: OPEN"})
            elseif eventName == "RunCompleted" then
                cascadeEvent:FireAllClients("Status", {text = "RUN: COMPLETE"})
            end
        end
    end)

    return prompt
end

-- Lighting baseline
Lighting.Brightness = 0.8
Lighting.Ambient = Color3.fromRGB(26, 30, 37)
Lighting.OutdoorAmbient = Color3.fromRGB(18, 21, 26)

local atmosphere = Lighting:FindFirstChild("CascadeAtmosphere") or Instance.new("Atmosphere")
atmosphere.Name = "CascadeAtmosphere"
atmosphere.Density = 0.22
atmosphere.Offset = 0.05
atmosphere.Color = Color3.fromRGB(196, 205, 220)
atmosphere.Decay = Color3.fromRGB(90, 98, 112)
atmosphere.Glare = 0
atmosphere.Haze = 0.8
atmosphere.Parent = Lighting

-- Main floor and shell
createPart("Floor", Vector3.new(170, 1, 120), CFrame.new(0, 0, 5), Enum.Material.Concrete, Color3.fromRGB(62, 67, 75), geometry)

wall("NorthWall", Vector3.new(170, 16, 2), Vector3.new(0, 8, 65))
wall("SouthWall", Vector3.new(170, 16, 2), Vector3.new(0, 8, -55))
wall("WestWall", Vector3.new(2, 16, 120), Vector3.new(-85, 8, 5))
wall("EastWall", Vector3.new(2, 16, 120), Vector3.new(85, 8, 5))

-- Room partitions with deliberate sightlines
wall("MaintenancePartitionSouth", Vector3.new(2, 16, 45), Vector3.new(-32, 8, -32.5))
wall("MaintenancePartitionNorth", Vector3.new(2, 16, 65), Vector3.new(-32, 8, 32.5))
wall("ObservationPartitionSouth", Vector3.new(2, 16, 65), Vector3.new(27, 8, -22.5))
wall("ObservationPartitionNorth", Vector3.new(2, 16, 45), Vector3.new(27, 8, 42.5))
wall("ControlPartition", Vector3.new(52, 16, 2), Vector3.new(1, 8, 44))

-- Entrance sightline
local glass = createPart(
    "ObservationWindow",
    Vector3.new(36, 11, 0.5),
    CFrame.new(47, 7, 43),
    Enum.Material.Glass,
    Color3.fromRGB(105, 152, 184),
    geometry,
    0.42,
    false
)
addBillboard(glass, "OBSERVATION ARRAY", UDim2.fromOffset(240, 58), Vector3.new(0, 7, 0))

-- Doors
local maintenanceDoor = createPart("MaintenanceDoor", Vector3.new(3, 9, 10), CFrame.new(-32, 4.5, -5), Enum.Material.Metal, Color3.fromRGB(81, 88, 98), geometry)
addBillboard(maintenanceDoor, "MAINTENANCE", UDim2.fromOffset(210, 48), Vector3.new(0, 6, 0))

local lowerRouteGate = createPart("LowerRouteGate", Vector3.new(2.8, 8, 10), CFrame.new(27, 4, 15), Enum.Material.Metal, Color3.fromRGB(71, 77, 88), geometry)
addBillboard(lowerRouteGate, "LOWER ACCESS", UDim2.fromOffset(190, 46), Vector3.new(0, 6, 0))

local signalShutter = createPart("SignalShutter", Vector3.new(2.8, 8, 15), CFrame.new(1, 4, 44), Enum.Material.Metal, Color3.fromRGB(71, 77, 88), geometry)
addBillboard(signalShutter, "CONTROL ROOM", UDim2.fromOffset(190, 46), Vector3.new(0, 6, 0))

local exitDoor = createPart("EmergencyExitDoor", Vector3.new(3, 9, 10), CFrame.new(72, 4.5, -53.5), Enum.Material.Metal, Color3.fromRGB(84, 91, 102), geometry)
addBillboard(exitDoor, "EMERGENCY EXIT", UDim2.fromOffset(230, 48), Vector3.new(0, 6, 0))

-- Observation array
local arrayModel = Instance.new("Model")
arrayModel.Name = "ArrayCore"
arrayModel.Parent = geometry

local arrayBase = createPart("ArrayBase", Vector3.new(12, 2, 12), CFrame.new(48, 1, 18), Enum.Material.Metal, Color3.fromRGB(91, 98, 108), arrayModel)
arrayModel.PrimaryPart = arrayBase

for i = 1, 4 do
    local angle = math.rad((i - 1) * 90)
    local pos = Vector3.new(48 + math.cos(angle) * 4.2, 7, 18 + math.sin(angle) * 4.2)
    local mast = createPart("ArrayMast" .. i, Vector3.new(1, 10, 1), CFrame.new(pos), Enum.Material.Metal, Color3.fromRGB(116, 124, 136), arrayModel)
    local tip = createPart("ArrayTip" .. i, Vector3.new(1.8, 1.8, 1.8), CFrame.new(pos + Vector3.new(0, 5.2, 0)), Enum.Material.Neon, Color3.fromRGB(110, 185, 255), arrayModel, 0, false)
end

local arrayGlow = Instance.new("PointLight")
arrayGlow.Brightness = 1.8
arrayGlow.Range = 26
arrayGlow.Color = Color3.fromRGB(98, 168, 235)
arrayGlow.Parent = arrayBase

-- Consoles
local powerConsole = createPart("PrimaryPower", Vector3.new(4, 4, 2), CFrame.new(-55, 2.5, 8), Enum.Material.Metal, Color3.fromRGB(86, 95, 106), interactables)
addBillboard(powerConsole, "PRIMARY POWER", UDim2.fromOffset(220, 50), Vector3.new(0, 3.2, 0))
addStatusLamp(powerConsole, Vector3.new(0, 0, -1.05), Color3.fromRGB(255, 185, 70), false)
addPrompt(powerConsole, "Primary Power", "Restore Power", "RestorePower")

local pumpConsole = createPart("DrainageControl", Vector3.new(4, 4, 2), CFrame.new(-48, 2.5, 28), Enum.Material.Metal, Color3.fromRGB(86, 95, 106), interactables)
addBillboard(pumpConsole, "DRAINAGE CONTROL", UDim2.fromOffset(250, 50), Vector3.new(0, 3.2, 0))
addStatusLamp(pumpConsole, Vector3.new(0, 0, -1.05), Color3.fromRGB(95, 220, 164), false)
local pumpPrompt = addPrompt(pumpConsole, "Drainage Control", "Stabilize Drainage", "StabilizePump")
pumpPrompt.Enabled = false

local arrayConsole = createPart("ArrayConsole", Vector3.new(4, 4, 2), CFrame.new(48, 2.5, 5), Enum.Material.Metal, Color3.fromRGB(86, 95, 106), interactables)
addBillboard(arrayConsole, "ARRAY CONTROL", UDim2.fromOffset(205, 50), Vector3.new(0, 3.2, 0))
addStatusLamp(arrayConsole, Vector3.new(0, 0, -1.05), Color3.fromRGB(105, 174, 255), false)
addPrompt(arrayConsole, "Observation Array", "Activate Array", "ActivateArray")

local signalConsole = createPart("SignalConsole", Vector3.new(4, 4, 2), CFrame.new(22, 2.5, 53), Enum.Material.Metal, Color3.fromRGB(86, 95, 106), interactables, 1, false)
addBillboard(signalConsole, "SIGNAL CONSOLE", UDim2.fromOffset(220, 50), Vector3.new(0, 3.2, 0))
addStatusLamp(signalConsole, Vector3.new(0, 0, -1.05), Color3.fromRGB(255, 215, 98), false)
local signalPrompt = addPrompt(signalConsole, "Signal Console", "Transmit Signal", "TransmitSignal")
signalPrompt.Enabled = false

local exitConsole = createPart("ExitConsole", Vector3.new(4, 4, 2), CFrame.new(72, 2.5, -45), Enum.Material.Metal, Color3.fromRGB(86, 95, 106), interactables)
addBillboard(exitConsole, "EVACUATION CONTROL", UDim2.fromOffset(245, 50), Vector3.new(0, 3.2, 0))
addStatusLamp(exitConsole, Vector3.new(0, 0, -1.05), Color3.fromRGB(255, 84, 84), false)
local exitPrompt = addPrompt(exitConsole, "Emergency Exit", "Escape", "Escape")
exitPrompt.Enabled = false

-- Flooded lower route
local water = createPart(
    "FloodWater",
    Vector3.new(96, 1.5, 20),
    CFrame.new(5, 5.7, 28),
    Enum.Material.Glass,
    Color3.fromRGB(38, 116, 160),
    effects,
    0.28,
    false
)
local waterLight = Instance.new("PointLight")
waterLight.Color = Color3.fromRGB(45, 138, 198)
waterLight.Brightness = 0.8
waterLight.Range = 30
waterLight.Parent = water

local lowerLights = Instance.new("Folder")
lowerLights.Name = "LowerRouteLights"
lowerLights.Parent = effects
for x = -10, 55, 13 do
    local lamp = createPart("RouteLamp", Vector3.new(1.2, 0.25, 1.2), CFrame.new(x, 2.2, 28), Enum.Material.Neon, Color3.fromRGB(100, 200, 255), lowerLights, 0.55, false)
end

-- Facility lights
local lightModel = Instance.new("Folder")
lightModel.Name = "FacilityLights"
lightModel.Parent = world
for x = -55, 70, 15 do
    local fixture = createPart("CeilingLight", Vector3.new(7, 0.25, 1.5), CFrame.new(x, 15, -8), Enum.Material.Neon, Color3.fromRGB(208, 216, 224), lightModel, 0.12, false)
    local light = Instance.new("PointLight")
    light.Brightness = 0.9
    light.Range = 28
    light.Color = Color3.fromRGB(220, 228, 238)
    light.Enabled = false
    light.Parent = fixture
end

-- Cascade alarm and route lighting
local alarm = Instance.new("PointLight")
alarm.Name = "AlarmLight"
alarm.Color = Color3.fromRGB(255, 55, 55)
alarm.Brightness = 3
alarm.Range = 40
alarm.Enabled = false
alarm.Parent = signalShutter

local exitLights = Instance.new("Folder")
exitLights.Name = "ExitRouteLights"
exitLights.Parent = effects
for z = -45, 20, 13 do
    local lamp = createPart("ExitLamp", Vector3.new(1.1, 0.25, 1.1), CFrame.new(70, 2.2, z), Enum.Material.Neon, Color3.fromRGB(255, 62, 62), exitLights, 0.65, false)
end

-- Small readable environmental hints
local signAnchor = createPart("MissionSignAnchor", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 7, -51), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), geometry, 1, false)
addBillboard(signAnchor, "OBSERVATION FACILITY  //  SITE 07", UDim2.fromOffset(360, 56), Vector3.new(0, 0, 0))

-- Spawn
local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
if spawn then
    spawn.Position = Vector3.new(0, 3, -43)
    spawn.Size = Vector3.new(7, 1, 7)
    spawn.Neutral = true
    spawn.Anchored = true
else
    spawn = Instance.new("SpawnLocation")
    spawn.Size = Vector3.new(7, 1, 7)
    spawn.Position = Vector3.new(0, 3, -43)
    spawn.Neutral = true
    spawn.Anchored = true
    spawn.Parent = workspace
end

local function sendCurrentState(player: Player)
    cascadeEvent:FireClient(player, "Objective", {
        text = "Activate the observation array and transmit the recovery signal.",
    })

    local statusText = "FACILITY: OFFLINE"
    if state.objective == "ReachArray" then
        statusText = "FACILITY: ONLINE"
    elseif state.objective == "TransmitSignal" then
        statusText = "CASCADE: ACTIVE"
    elseif state.objective == "Escape" then
        statusText = "EMERGENCY EXIT: OPEN"
    elseif state.objective == "Complete" then
        statusText = "RUN: COMPLETE"
    end

    cascadeEvent:FireClient(player, "Status", {text = statusText})
end

Players.PlayerAdded:Connect(function(player)
    task.delay(1, function()
        if player.Parent then
            sendCurrentState(player)
        end
    end)
end)

for _, player in Players:GetPlayers() do
    task.defer(sendCurrentState, player)
end

cascadeEvent:FireAllClients("Objective", {
    text = "Activate the observation array and transmit the recovery signal.",
})
cascadeEvent:FireAllClients("Status", {text = "FACILITY: OFFLINE"})
