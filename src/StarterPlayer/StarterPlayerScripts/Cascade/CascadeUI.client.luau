local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local cascadeRoot = ReplicatedStorage:WaitForChild("Cascade")
local events = cascadeRoot:WaitForChild("Events")
local cascadeEvent = events:WaitForChild("CascadeEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "CascadeUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local function corner(parent: Instance, radius: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
end

local mission = Instance.new("Frame")
mission.Name = "Mission"
mission.AnchorPoint = Vector2.new(0, 0)
mission.Position = UDim2.fromOffset(24, 24)
mission.Size = UDim2.fromOffset(410, 92)
mission.BackgroundColor3 = Color3.fromRGB(13, 17, 23)
mission.BackgroundTransparency = 0.18
mission.BorderSizePixel = 0
mission.Parent = gui
corner(mission, 10)

local missionStroke = Instance.new("UIStroke")
missionStroke.Color = Color3.fromRGB(103, 119, 139)
missionStroke.Transparency = 0.55
missionStroke.Thickness = 1
missionStroke.Parent = mission

local missionLabel = Instance.new("TextLabel")
missionLabel.BackgroundTransparency = 1
missionLabel.Position = UDim2.fromOffset(16, 10)
missionLabel.Size = UDim2.new(1, -32, 0, 18)
missionLabel.Font = Enum.Font.GothamBold
missionLabel.TextSize = 12
missionLabel.TextColor3 = Color3.fromRGB(152, 168, 187)
missionLabel.TextXAlignment = Enum.TextXAlignment.Left
missionLabel.Text = "CASCADE  •  PLAYTEST BUILD 02"
missionLabel.Parent = mission

local objectiveText = Instance.new("TextLabel")
objectiveText.BackgroundTransparency = 1
objectiveText.Position = UDim2.fromOffset(16, 31)
objectiveText.Size = UDim2.new(1, -32, 0, 38)
objectiveText.Font = Enum.Font.GothamMedium
objectiveText.TextSize = 18
objectiveText.TextWrapped = true
objectiveText.TextColor3 = Color3.fromRGB(236, 240, 245)
objectiveText.TextXAlignment = Enum.TextXAlignment.Left
objectiveText.TextYAlignment = Enum.TextYAlignment.Top
objectiveText.Text = "Activate the observation array and transmit the recovery signal."
objectiveText.Parent = mission

local statusText = Instance.new("TextLabel")
statusText.Name = "Status"
statusText.BackgroundTransparency = 1
statusText.Position = UDim2.fromOffset(16, 71)
statusText.Size = UDim2.new(1, -32, 0, 14)
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 10
statusText.TextColor3 = Color3.fromRGB(116, 190, 168)
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.Text = "BUILD 02 // FACILITY OFFLINE"
statusText.Parent = mission

local toast = Instance.new("Frame")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.fromScale(0.5, 1.08)
toast.Size = UDim2.fromOffset(640, 94)
toast.BackgroundColor3 = Color3.fromRGB(12, 16, 22)
toast.BackgroundTransparency = 0.08
toast.BorderSizePixel = 0
toast.Parent = gui
corner(toast, 10)

local toastStroke = Instance.new("UIStroke")
toastStroke.Color = Color3.fromRGB(125, 142, 163)
toastStroke.Transparency = 0.62
toastStroke.Thickness = 1
toastStroke.Parent = toast

local toastTitle = Instance.new("TextLabel")
toastTitle.BackgroundTransparency = 1
toastTitle.Position = UDim2.fromOffset(18, 12)
toastTitle.Size = UDim2.new(1, -36, 0, 24)
toastTitle.Font = Enum.Font.GothamBold
toastTitle.TextSize = 18
toastTitle.TextColor3 = Color3.fromRGB(241, 244, 248)
toastTitle.TextXAlignment = Enum.TextXAlignment.Left
toastTitle.Text = ""
toastTitle.Parent = toast

local toastText = Instance.new("TextLabel")
toastText.BackgroundTransparency = 1
toastText.Position = UDim2.fromOffset(18, 38)
toastText.Size = UDim2.new(1, -36, 0, 42)
toastText.Font = Enum.Font.GothamMedium
toastText.TextSize = 15
toastText.TextWrapped = true
toastText.TextColor3 = Color3.fromRGB(195, 204, 214)
toastText.TextXAlignment = Enum.TextXAlignment.Left
toastText.TextYAlignment = Enum.TextYAlignment.Top
toastText.Text = ""
toastText.Parent = toast

local toastVisiblePosition = UDim2.fromScale(0.5, 0.9)
local toastHiddenPosition = UDim2.fromScale(0.5, 1.08)
local toastToken = 0

local function showToast(title: string, text: string)
    toastToken += 1
    local token = toastToken

    toastTitle.Text = title
    toastText.Text = text
    toast.Position = toastHiddenPosition

    TweenService:Create(
        toast,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = toastVisiblePosition}
    ):Play()

    task.delay(3.5, function()
        if token ~= toastToken or not toast.Parent then
            return
        end

        TweenService:Create(
            toast,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = toastHiddenPosition}
        ):Play()
    end)
end

cascadeEvent.OnClientEvent:Connect(function(kind, payload)
    if kind == "Objective" then
        objectiveText.Text = payload.text or objectiveText.Text
    elseif kind == "Status" then
        statusText.Text = payload.text or statusText.Text
    elseif kind == "Event" then
        showToast(payload.title or "SYSTEM", payload.text or "")
    elseif kind == "World" then
        if payload.kind == "PumpsStarted" then
            showToast("SYSTEMS ONLINE", "You hear pumps and machinery starting somewhere below.")
        elseif payload.kind == "SignalRoomOpened" then
            showToast("A NEW SPACE HAS OPENED", "Something moved inside the control room.")
        end
    end
end)
