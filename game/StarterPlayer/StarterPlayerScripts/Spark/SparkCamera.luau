-- Raised chase camera (WP-03): Tuning.camera (pitch 46, distance 38, FOV 68,
-- 5-stud look-ahead, +6 distance while the ribbon is longer than 55 studs).
-- Yaw is the player's (RMB drag, touch drag off UI, right stick); pitch is
-- clamped and stepped by the [ and ] debug presets. Position smoothing 0.12 s;
-- never rolls, never shakes. CameraType is Scriptable only while active;
-- Classic restores the Roblox camera with zoom clamped 28..55.
local SparkCamera = {}

SparkCamera.SMOOTH = 0.12
SparkCamera.CLASSIC_ZOOM = {28, 55}
SparkCamera.LONG_RIBBON = 55

-- Pure: camera offset from the focus point for yaw/pitch (radians) and distance.
function SparkCamera.offset(yaw, pitch, distance)
	local flat = math.cos(pitch) * distance
	return math.sin(yaw) * flat, math.sin(pitch) * distance, math.cos(yaw) * flat
end

-- Pure: step through presets. index 1..#presets, delta -1/+1 (clamped).
function SparkCamera.step(index, delta, count)
	return math.clamp(index + delta, 1, count)
end

-- Pure exponential smoothing factor for a time constant.
function SparkCamera.alpha(dt, tau)
	if tau <= 0 then return 1 end
	return 1 - math.exp(-dt / tau)
end

function SparkCamera.new(ctx)
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local ContextActionService = game:GetService("ContextActionService")
	local player = Players.LocalPlayer
	local tuning = ctx.tuning.camera
	local presets = tuning.pitchPresets
	local self = {
		classic = false, active = false,
		presetIndex = table.find(presets, tuning.pitchDegrees) or math.ceil(#presets / 2),
		pitch = math.rad(tuning.pitchDegrees), distance = tuning.distance, fov = tuning.fov,
		yaw = 0, ribbonLength = 0, kickUntil = 0, focus = nil, look = Vector3.zero,
	}
	local dragging = false
	local stickYaw = 0

	function self.setPreset(index)
		self.presetIndex = math.clamp(index, 1, #presets)
		self.pitch = math.rad(math.clamp(presets[self.presetIndex], 38, 54))
	end
	-- F9 overrides (Studio only): pitch degrees and distance within the tuning range.
	function self.retune(values)
		if values.pitch then self.pitch = math.rad(math.clamp(values.pitch, 38, 54)) end
		if values.distance then self.distance = values.distance end
	end
	function self.kick()
		if ctx.reduced and ctx.reduced() then return end
		self.kickUntil = os.clock() + 0.08
	end
	function self.setClassic(on)
		self.classic = on == true
		if self.classic then self.release() end
	end

	function self.release()
		local camera = workspace.CurrentCamera
		if camera and camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = 70
		end
		player.CameraMinZoomDistance = SparkCamera.CLASSIC_ZOOM[1]
		player.CameraMaxZoomDistance = SparkCamera.CLASSIC_ZOOM[2]
		self.active = false
	end

	-- Yaw input. RMB drag (mouse locked while held), touch drag on empty screen,
	-- right stick. Keys [ and ] step the pitch presets (slice debug).
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton2 and not processed then
			dragging = true
			if self.active then UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			dragging = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stickYaw = 0
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if not self.active then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
			self.yaw -= input.Delta.X * 0.006
		elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
			self.yaw -= input.Delta.X * 0.008
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stickYaw = if math.abs(input.Position.X) > 0.15 then input.Position.X else 0
		end
	end)
	ContextActionService:BindAction("SparkCameraPreset", function(_, state, input)
		if state ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		local delta = if input.KeyCode == Enum.KeyCode.LeftBracket then -1 else 1
		-- Presets are ordered steepest first (54, 46, 38): [ = steeper, ] = flatter.
		self.setPreset(SparkCamera.step(self.presetIndex, delta, #presets))
		if ctx.onPreset then ctx.onPreset(presets[self.presetIndex]) end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.LeftBracket, Enum.KeyCode.RightBracket)

	RunService:BindToRenderStep("SparkCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local want = not self.classic and root ~= nil and (ctx.shouldRun == nil or ctx.shouldRun())
		if not camera then return end
		if not want then
			if self.active then self.release() end
			return
		end
		if not self.active then
			self.active = true
			camera.CameraType = Enum.CameraType.Scriptable
			-- Start behind the character's facing so the first frame is not a jump.
			local look = root.CFrame.LookVector
			self.yaw = math.atan2(-look.X, -look.Z)
			self.focus = root.Position
		end
		self.yaw -= stickYaw * dt * 2.4
		-- Look-ahead along the movement direction, smoothed.
		local move = humanoid and humanoid.MoveDirection or Vector3.zero
		local wantLook = Vector3.new(move.X, 0, move.Z) * tuning.lookAhead
		self.look = self.look:Lerp(wantLook, SparkCamera.alpha(dt, 0.35))
		local target = root.Position + Vector3.new(0, 1.5, 0) + self.look
		self.focus = if self.focus then self.focus:Lerp(target, SparkCamera.alpha(dt, SparkCamera.SMOOTH)) else target
		local distance = self.distance + (if self.ribbonLength > SparkCamera.LONG_RIBBON then tuning.loopZoomOut else 0)
		self.currentDistance = if self.currentDistance then self.currentDistance + (distance - self.currentDistance) * SparkCamera.alpha(dt, 0.4) else distance
		local ox, oy, oz = SparkCamera.offset(self.yaw, self.pitch, self.currentDistance)
		local position = self.focus + Vector3.new(ox, oy, oz)
		camera.CFrame = CFrame.lookAt(position, self.focus)
		local kick = if os.clock() < self.kickUntil and ctx.tuning.dash.fovKickDegrees then ctx.tuning.dash.fovKickDegrees else 0
		camera.FieldOfView = self.fov + kick
	end)
	return self
end

return SparkCamera
