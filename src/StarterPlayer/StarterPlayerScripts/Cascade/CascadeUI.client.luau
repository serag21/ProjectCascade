-- Project Cascade | Site 07 | Playtest Build 03
-- Mission-level HUD, environmental feedback, evidence, and proximity-driven fear response.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local cascadeRoot = ReplicatedStorage:WaitForChild("Cascade")
local eventFolder = cascadeRoot:WaitForChild("Events")
local eventRemote = eventFolder:WaitForChild("CascadeEvent")

local existing = playerGui:FindFirstChild("CascadeUI")
if existing then existing:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CascadeUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 30
gui.Parent = playerGui

local function round(parent: Instance, radius: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, transparency: number, thickness: number)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Transparency = transparency
    s.Thickness = thickness
    s.Parent = parent
    return s
end

local function label(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, font: Enum.Font, textSize: number, color: Color3, xAlign: Enum.TextXAlignment?, yAlign: Enum.TextYAlignment?)
    local t = Instance.new("TextLabel")
    t.Name = name
    t.BackgroundTransparency = 1
    t.Position = position
    t.Size = size
    t.Font = font
    t.TextSize = textSize
    t.TextColor3 = color
    t.Text = text
    t.TextWrapped = true
    t.TextXAlignment = xAlign or Enum.TextXAlignment.Left
    t.TextYAlignment = yAlign or Enum.TextYAlignment.Center
    t.Parent = parent
    return t
end

local panel = Instance.new("Frame")
panel.Name = "MissionPanel"
panel.Position = UDim2.fromOffset(22, 20)
panel.Size = UDim2.fromOffset(430, 116)
panel.BackgroundColor3 = Color3.fromRGB(9, 14, 21)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = gui
round(panel, 9)
stroke(panel, Color3.fromRGB(82, 133, 157), 0.32, 1)

local accent = Instance.new("Frame")
accent.Name = "Accent"
accent.Size = UDim2.new(0, 4, 1, -18)
accent.Position = UDim2.fromOffset(0, 9)
accent.BackgroundColor3 = Color3.fromRGB(81, 187, 214)
accent.BorderSizePixel = 0
accent.Parent = panel
round(accent, 3)

local buildLabel = label(panel, "BuildLabel", "SITE 07   /   FIELD PLAYTEST 03", UDim2.fromOffset(17, 9), UDim2.new(1, -32, 0, 18), Enum.Font.GothamBold, 12, Color3.fromRGB(106, 190, 211))
buildLabel.TextXAlignment = Enum.TextXAlignment.Left

local missionLabel = label(panel, "MissionLabel", "MISSION", UDim2.fromOffset(17, 29), UDim2.new(1, -32, 0, 15), Enum.Font.GothamBold, 10, Color3.fromRGB(137, 151, 168))
missionLabel.TextXAlignment = Enum.TextXAlignment.Left

local objectiveText = label(
    panel,
    "ObjectiveText",
    "Restore the observation array's signal. Then get out.",
    UDim2.fromOffset(17, 46),
    UDim2.new(1, -32, 0, 39),
    Enum.Font.GothamMedium,
    17,
    Color3.fromRGB(232, 238, 243)
)
objectiveText.TextYAlignment = Enum.TextYAlignment.Top
objectiveText.TextXAlignment = Enum.TextXAlignment.Left

local statusText = label(panel, "StatusText", "SITE 07  /  GRID OFFLINE", UDim2.fromOffset(17, 88), UDim2.new(1, -32, 0, 16), Enum.Font.GothamBold, 10, Color3.fromRGB(204, 159, 96))
statusText.TextXAlignment = Enum.TextXAlignment.Left

local toast = Instance.new("Frame")
toast.Name = "EventToast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.fromScale(0.5, 1.12)
toast.Size = UDim2.fromOffset(610, 94)
toast.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
toast.BackgroundTransparency = 0.06
toast.BorderSizePixel = 0
toast.Parent = gui
round(toast, 9)
local toastStroke = stroke(toast, Color3.fromRGB(90, 132, 153), 0.48, 1)

local toastTitle = label(toast, "ToastTitle", "", UDim2.fromOffset(18, 9), UDim2.new(1, -36, 0, 24), Enum.Font.GothamBold, 17, Color3.fromRGB(236, 241, 245))
toastTitle.TextXAlignment = Enum.TextXAlignment.Left
local toastBody = label(toast, "ToastBody", "", UDim2.fromOffset(18, 34), UDim2.new(1, -36, 0, 48), Enum.Font.GothamMedium, 14, Color3.fromRGB(192, 203, 214))
toastBody.TextXAlignment = Enum.TextXAlignment.Left
toastBody.TextYAlignment = Enum.TextYAlignment.Top

local toastToken = 0
local function showToast(title: string, body: string, color: Color3?)
    toastToken += 1
    local token = toastToken
    toastTitle.Text = title
    toastBody.Text = body
    toastStroke.Color = color or Color3.fromRGB(90, 132, 153)
    toast.Position = UDim2.fromScale(0.5, 1.12)
    TweenService:Create(toast, TweenInfo.new(0.27, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.fromScale(0.5, 0.92),
    }):Play()
    task.delay(4.1, function()
        if token ~= toastToken or not toast.Parent then return end
        TweenService:Create(toast, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.fromScale(0.5, 1.12),
        }):Play()
    end)
end

local evidenceCard = Instance.new("Frame")
evidenceCard.Name = "EvidenceCard"
evidenceCard.AnchorPoint = Vector2.new(0.5, 0.5)
evidenceCard.Position = UDim2.fromScale(0.5, 0.53)
evidenceCard.Size = UDim2.fromOffset(570, 254)
evidenceCard.BackgroundColor3 = Color3.fromRGB(11, 16, 22)
evidenceCard.BackgroundTransparency = 0.03
evidenceCard.Visible = false
evidenceCard.BorderSizePixel = 0
evidenceCard.Parent = gui
round(evidenceCard, 10)
stroke(evidenceCard, Color3.fromRGB(80, 154, 171), 0.25, 1)

local evidenceOverline = label(evidenceCard, "EvidenceOverline", "RECOVERED FILE  /  SITE 07", UDim2.fromOffset(22, 18), UDim2.new(1, -44, 0, 20), Enum.Font.GothamBold, 11, Color3.fromRGB(92, 191, 206))
local evidenceTitle = label(evidenceCard, "EvidenceTitle", "INCIDENT TRANSCRIPT", UDim2.fromOffset(22, 44), UDim2.new(1, -44, 0, 30), Enum.Font.GothamBold, 19, Color3.fromRGB(236, 240, 245))
local evidenceBody = label(evidenceCard, "EvidenceBody", "", UDim2.fromOffset(22, 84), UDim2.new(1, -44, 0, 133), Enum.Font.Code, 15, Color3.fromRGB(191, 202, 212))
evidenceBody.TextYAlignment = Enum.TextYAlignment.Top
evidenceBody.TextXAlignment = Enum.TextXAlignment.Left
local evidenceDismiss = Instance.new("TextButton")
evidenceDismiss.Name = "Dismiss"
evidenceDismiss.AnchorPoint = Vector2.new(1, 1)
evidenceDismiss.Position = UDim2.new(1, -20, 1, -16)
evidenceDismiss.Size = UDim2.fromOffset(116, 32)
evidenceDismiss.BackgroundColor3 = Color3.fromRGB(35, 54, 66)
evidenceDismiss.TextColor3 = Color3.fromRGB(228, 239, 244)
evidenceDismiss.Font = Enum.Font.GothamBold
evidenceDismiss.TextSize = 11
evidenceDismiss.Text = "DISMISS"
evidenceDismiss.BorderSizePixel = 0
evidenceDismiss.Parent = evidenceCard
round(evidenceDismiss, 5)
evidenceDismiss.Activated:Connect(function() evidenceCard.Visible = false end)

local threatEdge = Instance.new("Frame")
threatEdge.Name = "ThreatEdge"
threatEdge.BackgroundTransparency = 1
threatEdge.Size = UDim2.fromScale(1, 1)
threatEdge.BorderSizePixel = 0
threatEdge.Parent = gui
local threatStroke = Instance.new("UIStroke")
threatStroke.Color = Color3.fromRGB(216, 39, 42)
threatStroke.Thickness = 13
threatStroke.Transparency = 1
threatStroke.Parent = threatEdge

local threatLabel = label(gui, "ThreatLabel", "", UDim2.new(1, -280, 1, -88), UDim2.fromOffset(252, 24), Enum.Font.GothamBold, 12, Color3.fromRGB(255, 114, 102))
threatLabel.AnchorPoint = Vector2.new(1, 1)
threatLabel.Position = UDim2.new(1, -24, 1, -24)
threatLabel.TextXAlignment = Enum.TextXAlignment.Right
threatLabel.Visible = false

local flashlightEnabled = true
local flashlight = Instance.new("SpotLight")
flashlight.Name = "CascadeFlashlight"
flashlight.Color = Color3.fromRGB(213, 230, 255)
flashlight.Brightness = 2.45
flashlight.Range = 48
flashlight.Angle = 62
flashlight.Shadows = true
flashlight.Enabled = flashlightEnabled

local flashlightButton = Instance.new("TextButton")
flashlightButton.Name = "FlashlightToggle"
flashlightButton.Position = UDim2.fromOffset(22, 145)
flashlightButton.Size = UDim2.fromOffset(198, 38)
flashlightButton.BackgroundColor3 = Color3.fromRGB(14, 23, 32)
flashlightButton.BackgroundTransparency = 0.1
flashlightButton.BorderSizePixel = 0
flashlightButton.Text = "FLASHLIGHT  [F]  ON"
flashlightButton.Font = Enum.Font.GothamBold
flashlightButton.TextSize = 12
flashlightButton.TextColor3 = Color3.fromRGB(151, 218, 227)
flashlightButton.Parent = gui
round(flashlightButton, 6)
stroke(flashlightButton, Color3.fromRGB(82, 143, 160), 0.42, 1)

local function updateFlashlight()
    flashlightButton.Text = "FLASHLIGHT  [F]  " .. (if flashlightEnabled then "ON" else "OFF")
    flashlightButton.TextColor3 = if flashlightEnabled then Color3.fromRGB(151, 218, 227) else Color3.fromRGB(153, 162, 172)
    flashlightButton.BackgroundColor3 = if flashlightEnabled then Color3.fromRGB(14, 28, 37) else Color3.fromRGB(19, 21, 25)
    flashlight.Enabled = flashlightEnabled
end

local function toggleFlashlight()
    flashlightEnabled = not flashlightEnabled
    updateFlashlight()
end
flashlightButton.Activated:Connect(toggleFlashlight)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F then
        toggleFlashlight()
    end
end)

local flash = Instance.new("Frame")
flash.Name = "MomentFlash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(175, 219, 241)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 25
flash.Parent = gui

local function flashScreen(color: Color3, initialTransparency: number, duration: number)
    flash.BackgroundColor3 = color
    flash.BackgroundTransparency = initialTransparency
    TweenService:Create(flash, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 1,
    }):Play()
end

local panicSound = Instance.new("Sound")
panicSound.Name = "CascadePanicSting"
panicSound.SoundId = "rbxassetid://135540168785024"
panicSound.Volume = 0.28
panicSound.Parent = SoundService

local threatGrade = Lighting:FindFirstChild("CascadePlayerThreatGrade")
if not threatGrade then
    threatGrade = Instance.new("ColorCorrectionEffect")
    threatGrade.Name = "CascadePlayerThreatGrade"
    threatGrade.Brightness = 0
    threatGrade.Contrast = 0.08
    threatGrade.Saturation = -0.05
    threatGrade.TintColor = Color3.fromRGB(220, 230, 243)
    threatGrade.Parent = Lighting
end

local threatBlur = Lighting:FindFirstChild("CascadePlayerThreatBlur")
if not threatBlur then
    threatBlur = Instance.new("BlurEffect")
    threatBlur.Name = "CascadePlayerThreatBlur"
    threatBlur.Size = 0
    threatBlur.Parent = Lighting
end

local runComplete = false
local panicCueAt = 0
local currentThreat = 0
local targetFov = 70
local cameraBaseFov = 70
local lastBuild = 3
local function announceBuild(version: number)
    lastBuild = version
    buildLabel.Text = "SITE 07   /   FIELD PLAYTEST " .. string.format("%02d", version)
end

eventRemote.OnClientEvent:Connect(function(kind, payload)
    payload = payload or {}
    if kind == "Objective" then
        objectiveText.Text = payload.text or objectiveText.Text
    elseif kind == "Status" then
        statusText.Text = payload.text or statusText.Text
        local text = string.upper(statusText.Text)
        if string.find(text, "OFFLINE") or string.find(text, "SEALED") then
            statusText.TextColor3 = Color3.fromRGB(204, 159, 96)
        elseif string.find(text, "FAILURE") or string.find(text, "CASCADE") then
            statusText.TextColor3 = Color3.fromRGB(245, 90, 86)
        else
            statusText.TextColor3 = Color3.fromRGB(104, 211, 173)
        end
    elseif kind == "Event" then
        local title = payload.title or "FACILITY RESPONSE"
        local color = Color3.fromRGB(90, 156, 177)
        if string.find(string.upper(title), "POWER") then
            color = Color3.fromRGB(105, 196, 170)
        elseif string.find(string.upper(title), "CASCADE") or string.find(string.upper(title), "CONTAINMENT") then
            color = Color3.fromRGB(225, 67, 66)
        end
        showToast(title, payload.text or "", color)
    elseif kind == "Evidence" then
        evidenceTitle.Text = payload.title or "RECOVERED FILE"
        evidenceBody.Text = payload.text or ""
        evidenceCard.Visible = true
        flashScreen(Color3.fromRGB(95, 182, 207), 0.92, 0.45)
    elseif kind == "WorldCue" then
        if payload.kind == "DistantMachinery" then
            showToast("SOMETHING STARTED BELOW", "A heavy motor catches, then settles into a rough rhythm.", Color3.fromRGB(93, 168, 185))
        elseif payload.kind == "WaterDraining" then
            showToast("THE WATER IS MOVING", "You hear a deep rush through the transfer corridor.", Color3.fromRGB(73, 167, 205))
            flashScreen(Color3.fromRGB(65, 170, 210), 0.97, 0.7)
        elseif payload.kind == "ArrayPulse" then
            flashScreen(Color3.fromRGB(99, 196, 245), 0.83, 1.0)
            showToast("SIGNAL LOCK", "The array is turning toward something beyond the glass.", Color3.fromRGB(85, 177, 224))
        elseif payload.kind == "CascadeStarted" then
            flashScreen(Color3.fromRGB(172, 26, 33), 0.68, 1.25)
            showToast("CONTAINMENT FAILURE", "The alarm is not coming from the array room.", Color3.fromRGB(230, 59, 60))
        elseif payload.kind == "ExitOpened" then
            showToast("OUTER SEAL RELEASED", "The exit route is lit. Move.", Color3.fromRGB(111, 210, 171))
        end
    elseif kind == "Threat" then
        currentThreat = math.clamp(1 - ((payload.distance or 40) - 7) / 42, 0, 1)
        if payload.hit then
            flashScreen(Color3.fromRGB(220, 27, 34), 0.52, 0.7)
            showToast("IT GOT HOLD OF YOU", "Get space before it reaches you again.", Color3.fromRGB(222, 49, 52))
        end
    elseif kind == "Build" then
        announceBuild(payload.version or 3)
    elseif kind == "RunComplete" then
        runComplete = true
        threatLabel.Visible = false
        statusText.Text = "SITE 07  /  EVACUATED"
        statusText.TextColor3 = Color3.fromRGB(104, 211, 173)
        showToast("RUN COMPLETE", payload.text or "You made it out.", Color3.fromRGB(104, 211, 173))
        flashScreen(Color3.fromRGB(188, 224, 233), 0.72, 1.3)
    end
end)

local smoothedThreat = 0
local playerCharacter: Model? = nil
local playerRoot: BasePart? = nil
local function bindCharacter(character: Model)
    playerCharacter = character
    playerRoot = character:WaitForChild("HumanoidRootPart", 8) :: BasePart?
    local head = character:WaitForChild("Head", 8)
    if head and head:IsA("BasePart") then
        flashlight.Parent = head
        flashlight.Face = Enum.NormalId.Front
        updateFlashlight()
    end
end
if player.Character then task.spawn(bindCharacter, player.Character) end
player.CharacterAdded:Connect(bindCharacter)

local elapsed = 0
RunService.RenderStepped:Connect(function(dt)
    elapsed += dt
    local targetThreat = currentThreat
    local facility = Workspace:FindFirstChild("CascadeFacility")
    local subject = facility and facility:FindFirstChild("ContainmentSubject")
    local subjectRoot = subject and subject:FindFirstChild("HumanoidRootPart")
    if not runComplete and subject and subject:GetAttribute("Active") and playerRoot and subjectRoot and subjectRoot:IsA("BasePart") then
        local distance = (subjectRoot.Position - playerRoot.Position).Magnitude
        if distance < 65 then
            targetThreat = math.max(targetThreat, math.clamp(1 - (distance - 7) / 58, 0, 1))
        end
    else
        targetThreat = 0
    end
    currentThreat = math.max(0, currentThreat - dt * 0.85)
    smoothedThreat += (targetThreat - smoothedThreat) * math.min(dt * 3.4, 1)

    threatStroke.Transparency = 1 - smoothedThreat * 0.83
    threatStroke.Thickness = 4 + smoothedThreat * 14
    threatLabel.Visible = smoothedThreat > 0.08 and not runComplete
    threatLabel.Text = if smoothedThreat > 0.72 then "PROXIMITY CRITICAL" elseif smoothedThreat > 0.38 then "MOVEMENT NEARBY" else "SIGNAL DISTORTION"
    threatLabel.TextTransparency = 0.25 + (1 - smoothedThreat) * 0.6

    if threatGrade and threatGrade:IsA("ColorCorrectionEffect") then
        threatGrade.TintColor = Color3.fromRGB(220, 230, 243):Lerp(Color3.fromRGB(255, 139, 129), smoothedThreat * 0.56)
        threatGrade.Contrast = 0.08 + smoothedThreat * 0.18
        threatGrade.Saturation = -0.05 - smoothedThreat * 0.22
    end
    if threatBlur and threatBlur:IsA("BlurEffect") then
        threatBlur.Size = smoothedThreat * 3.2
    end

    local camera = Workspace.CurrentCamera
    if camera then
        camera.FieldOfView = cameraBaseFov + smoothedThreat * 5.5
        if smoothedThreat > 0.35 and not runComplete then
            local shake = smoothedThreat * 0.035
            local x = math.sin(elapsed * 16) * shake
            local y = math.cos(elapsed * 21) * shake * 0.6
            camera.CFrame = camera.CFrame * CFrame.new(x, y, 0)
        end
    end

    if smoothedThreat > 0.76 and os.clock() - panicCueAt > 18 then
        panicCueAt = os.clock()
        if panicSound then
            panicSound.PlaybackSpeed = 0.82 + math.random() * 0.24
            panicSound:Play()
        end
    end
end)

-- Prevent any stale build label from ever being silent: the HUD itself identifies the loaded client.
announceBuild(3)
