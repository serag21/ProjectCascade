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
gui.Parent = playerGui

local objectiveFrame = Instance.new("Frame")
objectiveFrame.Name = "Objective"
objectiveFrame.AnchorPoint = Vector2.new(0.5, 0)
objectiveFrame.Position = UDim2.fromScale(0.5, 0.045)
objectiveFrame.Size = UDim2.fromOffset(620, 72)
objectiveFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
objectiveFrame.BackgroundTransparency = 0.12
objectiveFrame.BorderSizePixel = 0
objectiveFrame.Parent = gui

local objectiveTitle = Instance.new("TextLabel")
objectiveTitle.BackgroundTransparency = 1
objectiveTitle.Position = UDim2.fromOffset(18, 8)
objectiveTitle.Size = UDim2.new(1, -36, 0, 22)
objectiveTitle.Font = Enum.Font.GothamBold
objectiveTitle.TextSize = 14
objectiveTitle.TextXAlignment = Enum.TextXAlignment.Left
objectiveTitle.TextColor3 = Color3.fromRGB(170, 190, 205)
objectiveTitle.Text = "CURRENT OBJECTIVE"
objectiveTitle.Parent = objectiveFrame

local objectiveText = Instance.new("TextLabel")
objectiveText.BackgroundTransparency = 1
objectiveText.Position = UDim2.fromOffset(18, 30)
objectiveText.Size = UDim2.new(1, -36, 0, 32)
objectiveText.Font = Enum.Font.GothamMedium
objectiveText.TextSize = 21
objectiveText.TextXAlignment = Enum.TextXAlignment.Left
objectiveText.TextColor3 = Color3.new(1, 1, 1)
objectiveText.Text = "Activate the observation array."
objectiveText.Parent = objectiveFrame

local toast = Instance.new("Frame")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.fromScale(0.5, 1.08)
toast.Size = UDim2.fromOffset(700, 108)
toast.BackgroundColor3 = Color3.fromRGB(14, 18, 24)
toast.BackgroundTransparency = 0.04
toast.BorderSizePixel = 0
toast.Parent = gui

local toastTitle = Instance.new("TextLabel")
toastTitle.BackgroundTransparency = 1
toastTitle.Position = UDim2.fromOffset(20, 12)
toastTitle.Size = UDim2.new(1, -40, 0, 28)
toastTitle.Font = Enum.Font.GothamBold
toastTitle.TextSize = 22
toastTitle.TextXAlignment = Enum.TextXAlignment.Left
toastTitle.TextColor3 = Color3.new(1, 1, 1)
toastTitle.Text = "MISSION"
toastTitle.Parent = toast

local toastText = Instance.new("TextLabel")
toastText.BackgroundTransparency = 1
toastText.Position = UDim2.fromOffset(20, 44)
toastText.Size = UDim2.new(1, -40, 0, 48)
toastText.Font = Enum.Font.GothamMedium
toastText.TextSize = 17
toastText.TextWrapped = true
toastText.TextXAlignment = Enum.TextXAlignment.Left
toastText.TextColor3 = Color3.fromRGB(205, 215, 225)
toastText.Text = ""
toastText.Parent = toast

local function showToast(title: string, text: string)
    toastTitle.Text = title
    toastText.Text = text

    toast.Position = UDim2.fromScale(0.5, 1.08)

    TweenService:Create(
        toast,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.fromScale(0.5, 0.90)}
    ):Play()

    task.delay(3.2, function()
        if toast.Parent then
            TweenService:Create(
                toast,
                TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {Position = UDim2.fromScale(0.5, 1.08)}
            ):Play()
        end
    end)
end

cascadeEvent.OnClientEvent:Connect(function(kind, payload)
    if kind == "Objective" then
        objectiveText.Text = payload.text or ""
    elseif kind == "Event" then
        showToast(payload.title or "CASCADE", payload.text or "")
    elseif kind == "Door" then
        showToast("DOOR OPEN", "A route through the facility has opened.")
    end
end)
