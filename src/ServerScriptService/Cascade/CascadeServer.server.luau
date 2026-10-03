local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local CascadeState = require(ReplicatedStorage:WaitForChild("Cascade"):WaitForChild("CascadeState"))

local cascadeRoot = ReplicatedStorage:WaitForChild("Cascade")
local events = cascadeRoot:FindFirstChild("Events")
if not events then
    events = Instance.new("Folder")
    events.Name = "Events"
    events.Parent = cascadeRoot
end

local cascadeEvent = events:FindFirstChild("CascadeEvent")
if not cascadeEvent then
    cascadeEvent = Instance.new("RemoteEvent")
    cascadeEvent.Name = "CascadeEvent"
    cascadeEvent.Parent = events
end

local state = CascadeState.new()

local function fire(kind: string, payload)
    cascadeEvent:FireAllClients(kind, payload)
end

local world = workspace:FindFirstChild("CascadeFacility")
if world then
    world:Destroy()
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

local function part(name: string, size: Vector3, cframe: CFrame, material: Enum.Material, color: Color3, parent: Instance, transparency: number?)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cframe
    p.Anchored = true
    p.Material = material
    p.Color = color
    p.Transparency = transparency or 0
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function wall(name: string, size: Vector3, position: Vector3, parent: Instance)
    return part(name, size, CFrame.new(position), Enum.Material.Concrete, Color3.fromRGB(48, 52, 58), parent)
end

local function labelOn(partInstance: BasePart, text: string)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "Label"
    gui.Face = Enum.NormalId.Front
    gui.AlwaysOnTop = true
    gui.CanvasSize = Vector2.new(800, 240)
    gui.Parent = partInstance

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.6
    label.Parent = gui
end

local function createPrompt(name: string, display: string, actionText: string, parent: BasePart, action: string)
    local marker = Instance.new("Part")
    marker.Name = name
    marker.Size = Vector3.new(3, 3, 3)
    marker.Anchored = true
    marker.Material = Enum.Material.Neon
    marker.Color = Color3.fromRGB(255, 190, 70)
    marker.Parent = interactables

    marker.Position = parent.Position + Vector3.new(0, 2.2, 0)
    marker.CanCollide = false

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = action .. "Prompt"
    prompt.ActionText = actionText
    prompt.ObjectText = display
    prompt.HoldDuration = 0.25
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = marker

    labelOn(marker, display)

    prompt.Triggered:Connect(function()
        if state.objective == "Complete" then
            return
        end

        local result = CascadeState.apply(state, action)
        if not result.ok then
            fire("Event", {
                title = "NOT READY",
                text = result.message or "That action cannot be used yet.",
            })
            return
        end

        if action == "RestorePower" then
            fire("Event", {
                title = "POWER RESTORED",
                text = "Facility systems online. A maintenance route opened.",
            })
            fire("Objective", { text = "Reach the observation array." })
        elseif action == "ActivateArray" then
            fire("Event", {
                title = "ENVIRONMENTAL CHANGE",
                text = "The facility just entered an unstable state.",
            })
            fire("Objective", { text = "Transmit the recovery signal." })
        elseif action == "TransmitSignal" then
            fire("Event", {
                title = "SIGNAL TRANSMITTED",
                text = "The facility is collapsing into emergency mode.",
            })
            fire("Objective", { text = "Escape through the main entrance." })
        elseif action == "Escape" then
            fire("Event", {
                title = "RUN COMPLETE",
                text = "You made it out.",
            })
            fire("Objective", { text = "Complete" })
        end

        for _, eventName in result.events do
            if eventName == "DoorOpened" then
                local maintenanceDoor = world:FindFirstChild("MaintenanceDoor", true)
                if maintenanceDoor and maintenanceDoor:IsA("BasePart") then
                    TweenService:Create(
                        maintenanceDoor,
                        TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        {CFrame = maintenanceDoor.CFrame + Vector3.new(0, 12, 0)}
                    ):Play()
                    fire("Door", {name = "MaintenanceDoor"})
                end
            elseif eventName == "EnvironmentChanged" then
                local transformWall = world:FindFirstChild("TransformWall", true)
                if transformWall and transformWall:IsA("BasePart") then
                    TweenService:Create(
                        transformWall,
                        TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                        {CFrame = transformWall.CFrame * CFrame.Angles(0, math.rad(-90), 0) + Vector3.new(0, 0, -8)}
                    ):Play()
                end

                Lighting.Brightness = 1
                Lighting.Ambient = Color3.fromRGB(60, 70, 95)
                Lighting.OutdoorAmbient = Color3.fromRGB(35, 40, 55)
            elseif eventName == "CascadeStarted" then
                local alarmLight = world:FindFirstChild("CascadeLight", true)
                if alarmLight and alarmLight:IsA("PointLight") then
                    task.spawn(function()
                        for _ = 1, 12 do
                            alarmLight.Enabled = not alarmLight.Enabled
                            task.wait(0.28)
                        end
                        alarmLight.Enabled = true
                    end)
                end
            end
        end
    end)

    return marker, prompt
end

part("Floor", Vector3.new(140, 1, 110), CFrame.new(0, 0, 5), Enum.Material.Concrete, Color3.fromRGB(68, 72, 78), geometry)

wall("NorthWall", Vector3.new(140, 14, 2), Vector3.new(0, 7, 60), geometry)
wall("SouthWall", Vector3.new(140, 14, 2), Vector3.new(0, 7, -50), geometry)
wall("WestWall", Vector3.new(2, 14, 110), Vector3.new(-70, 7, 5), geometry)
wall("EastWall", Vector3.new(2, 14, 110), Vector3.new(70, 7, 5), geometry)

wall("MaintenanceWall", Vector3.new(2, 14, 38), Vector3.new(-8, 7, 20), geometry)
wall("ArrayWestWall", Vector3.new(2, 14, 38), Vector3.new(36, 7, 20), geometry)
wall("UpperDivider", Vector3.new(52, 14, 2), Vector3.new(10, 7, 40), geometry)

local door = part("MaintenanceDoor", Vector3.new(3, 10, 8), CFrame.new(-8, 5, 2), Enum.Material.Metal, Color3.fromRGB(96, 103, 112), geometry)
labelOn(door, "MAINTENANCE ACCESS")

local transformWall = part("TransformWall", Vector3.new(3, 12, 18), CFrame.new(10, 6, 40), Enum.Material.Metal, Color3.fromRGB(72, 78, 90), geometry)
labelOn(transformWall, "OBSERVATION LAB")

local array = part("ObservationArray", Vector3.new(10, 14, 10), CFrame.new(52, 7, 20), Enum.Material.Metal, Color3.fromRGB(95, 100, 110), geometry)
labelOn(array, "OBSERVATION ARRAY")

local arrayGlow = Instance.new("PointLight")
arrayGlow.Brightness = 2
arrayGlow.Range = 22
arrayGlow.Color = Color3.fromRGB(100, 180, 255)
arrayGlow.Parent = array

local cascadeLight = Instance.new("PointLight")
cascadeLight.Name = "CascadeLight"
cascadeLight.Brightness = 5
cascadeLight.Range = 55
cascadeLight.Color = Color3.fromRGB(255, 70, 70)
cascadeLight.Enabled = false
cascadeLight.Parent = transformWall

local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
if spawn then
    spawn.Position = Vector3.new(0, 3, -38)
    spawn.Neutral = true
    spawn.Anchored = true
else
    spawn = Instance.new("SpawnLocation")
    spawn.Size = Vector3.new(6, 1, 6)
    spawn.Position = Vector3.new(0, 3, -38)
    spawn.Neutral = true
    spawn.Anchored = true
    spawn.Parent = workspace
end

local powerConsole = part("PowerConsole", Vector3.new(3, 4, 2), CFrame.new(-28, 2.5, 18), Enum.Material.Metal, Color3.fromRGB(90, 98, 108), interactables)
labelOn(powerConsole, "PRIMARY POWER")

local arrayConsole = part("ArrayConsole", Vector3.new(3, 4, 2), CFrame.new(50, 2.5, 4), Enum.Material.Metal, Color3.fromRGB(90, 98, 108), interactables)
labelOn(arrayConsole, "ARRAY CONTROL")

local signalConsole = part("SignalConsole", Vector3.new(3, 4, 2), CFrame.new(20, 2.5, 43), Enum.Material.Metal, Color3.fromRGB(90, 98, 108), interactables)
labelOn(signalConsole, "SIGNAL CONSOLE")

local exitConsole = part("ExitConsole", Vector3.new(3, 4, 2), CFrame.new(0, 2.5, -44), Enum.Material.Metal, Color3.fromRGB(90, 98, 108), interactables)
labelOn(exitConsole, "EVACUATE")

createPrompt("PowerInteraction", "PRIMARY POWER", "Restore Power", powerConsole, "RestorePower")
createPrompt("ArrayInteraction", "OBSERVATION ARRAY", "Activate Array", arrayConsole, "ActivateArray")
createPrompt("SignalInteraction", "SIGNAL CONSOLE", "Transmit Signal", signalConsole, "TransmitSignal")
createPrompt("ExitInteraction", "MAIN EXIT", "Escape", exitConsole, "Escape")

fire("Objective", {text = "Activate the observation array."})
fire("Event", {
    title = "MISSION",
    text = "Restore power, reach the array, and transmit the recovery signal.",
})

Players.PlayerAdded:Connect(function(player)
    task.delay(1, function()
        if player.Parent then
            local objectiveText = "Activate the observation array."
            if state.objective == "ReachArray" then
                objectiveText = "Reach the observation array."
            elseif state.objective == "TransmitSignal" then
                objectiveText = "Transmit the recovery signal."
            elseif state.objective == "Escape" then
                objectiveText = "Escape through the main entrance."
            elseif state.objective == "Complete" then
                objectiveText = "Run complete."
            end
            cascadeEvent:FireClient(player, "Objective", {text = objectiveText})
        end
    end)
end)
