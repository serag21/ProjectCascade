-- Studio-only debug (WP-07): F8 overlay v2 (design/fable/11 section 6) and the
-- F9 tuning panel (session only). Never built in live servers.
--   F8: build ID; frame ms p50/p95 (last 5 s); effect parts (visible BaseParts
--   under workspace.SparkFx); effect instances (Beams + Trails + enabled emitters
--   + enabled BillboardGuis under SparkFx and PlayerGui); creatures / creature
--   parts; arena parts (arena model + SparkDecor); herd KB/s; claimDeviation p99.
--   F9: ribbon lifetime, snap radius, dash distance, walk speed, camera
--   pitch/distance, creature scale, within Tuning.Ranges.
local Overlay = {}

-- Pure: percentile of a list of numbers (nearest rank).
function Overlay.percentile(list, p)
	if #list == 0 then return 0 end
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[math.clamp(math.ceil(#sorted * p), 1, #sorted)]
end

-- Pure: F9 controls from tuning (value, range, step).
function Overlay.controls(T)
	local R = T.Ranges
	return {
		{key = "lifetime", label = "Ribbon lifetime", value = T.ribbon.lifetime, range = R.ribbon.lifetime, step = 0.2},
		{key = "snapRadius", label = "Snap radius", value = T.ribbon.snapRadius, range = R.ribbon.snapRadius, step = 0.25},
		{key = "dashDistance", label = "Dash distance", value = T.dash.distance, range = R.dash.distance, step = 1},
		{key = "walkSpeed", label = "Walk speed", value = T.movement.walkSpeed, range = R.movement.walkSpeed, step = 1},
		{key = "pitch", label = "Camera pitch", value = T.camera.pitchDegrees, range = R.camera.pitchDegrees, step = 2},
		{key = "distance", label = "Camera distance", value = T.camera.distance, range = R.camera.distance, step = 2},
		{key = "creatureScale", label = "Creature scale", value = T.creatures.globalScale, range = R.creatures.globalScale, step = 0.05},
	}
end

-- Pure: step a control value within its range (rounded to the step grid).
function Overlay.stepValue(control, direction)
	local v = control.value + direction * control.step
	v = math.clamp(v, control.range[1], control.range[2])
	return math.floor(v / control.step + 0.5) * control.step
end

function Overlay.counters(ctx)
	local frames = {}
	for _, f in ipairs(ctx.perf.frames) do table.insert(frames, f.dt * 1000) end
	local effectParts, effectInstances = 0, 0
	for _, item in ipairs(ctx.fxFolder:GetDescendants()) do
		if item:IsA("BasePart") and item.Transparency < 1 then effectParts += 1 end
		if item:IsA("Beam") or item:IsA("Trail") or (item:IsA("ParticleEmitter") and item.Enabled)
			or (item:IsA("BillboardGui") and item.Enabled) then effectInstances += 1 end
	end
	for _, item in ipairs(ctx.playerGui:GetDescendants()) do
		if (item:IsA("BillboardGui") and item.Enabled) or item:IsA("Beam") or item:IsA("Trail") then effectInstances += 1 end
	end
	local creatures, creatureParts = 0, 0
	for _, model in ipairs(ctx.creaturesFolder:GetChildren()) do
		creatures += 1
		for _, item in ipairs(model:GetDescendants()) do if item:IsA("BasePart") then creatureParts += 1 end end
	end
	local arenaParts = 0
	local arena = ctx.arenaModel()
	for _, root in ipairs({arena, workspace:FindFirstChild("SparkDecor")}) do
		if root then
			for _, item in ipairs(root:GetDescendants()) do
				if item:IsA("BasePart") and item.Transparency < 1 then arenaParts += 1 end
			end
		end
	end
	return {p50 = Overlay.percentile(frames, 0.5), p95 = Overlay.percentile(frames, 0.95),
		effectParts = effectParts, effectInstances = effectInstances, creatures = creatures,
		creatureParts = creatureParts, arenaParts = arenaParts}
end

function Overlay.start(ctx)
	local ContextActionService = game:GetService("ContextActionService")
	local T = ctx.tuning
	local P = T.performance
	local label = Instance.new("TextLabel")
	label.Name = "PerfOverlay"
	label.Size = UDim2.fromOffset(330, 168); label.Position = UDim2.new(0, 12, 0, 52)
	label.BackgroundColor3 = Color3.fromRGB(27, 36, 64); label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(255, 249, 231); label.Font = Enum.Font.Code; label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left; label.TextYAlignment = Enum.TextYAlignment.Top
	label.Visible = false; label.Parent = ctx.gui
	local herdWindow = {}
	ContextActionService:BindAction("SparkPerfOverlay", function(_, state)
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		label.Visible = not label.Visible
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F8)
	task.spawn(function()
		while true do
			task.wait(1)
			table.insert(herdWindow, ctx.perf.herdBytes); ctx.perf.herdBytes = 0
			while #herdWindow > 5 do table.remove(herdWindow, 1) end
			if label.Visible then
				local c = Overlay.counters(ctx)
				local herd = 0
				for _, b in ipairs(herdWindow) do herd += b end
				herd = herd / math.max(1, #herdWindow) / 1024
				local d = ctx.data()
				local build = ctx.buildId
				label.Text = string.format(
					"BUILD %s\n%s\nframe ms p50 %.1f / p95 %.1f  [%.1f / 16.7]\neffect parts %d  [<= %d]\neffect instances %d  [<= %d]\ncreatures %d / parts %d  [<= 30 / %d]\narena parts %d  [<= %d]\nherd %.2f KB/s  [<= %.1f avg]\nclaim deviation p99 %.2f studs  (F9: tuning)",
					tostring(build.id), tostring(build.commit or ""), c.p50, c.p95, P.frameMsDesktopP50, c.effectParts, P.localEffectParts,
					c.effectInstances, P.effectInstances, c.creatures, c.creatureParts, P.creaturePartsTotal,
					c.arenaParts, P.arenaPartsVisibleMax, herd, P.herdBytesPerSecondAvg / 1000,
					tonumber(d and d.claimP99) or 0)
			end
		end
	end)
	-- F9 tuning panel.
	local panel = Instance.new("Frame")
	panel.Name = "TuningPanel"; panel.Size = UDim2.fromOffset(300, 300); panel.Position = UDim2.new(0, 12, 0, 228)
	panel.BackgroundColor3 = Color3.fromRGB(27, 36, 64); panel.BackgroundTransparency = 0.2; panel.Visible = false
	panel.Parent = ctx.gui
	local controls = Overlay.controls(T)
	for index, control in ipairs(controls) do
		local row = Instance.new("TextLabel")
		row.Name = "Tune_" .. control.key
		row.Size = UDim2.new(1, -96, 0, 34); row.Position = UDim2.fromOffset(8, 8 + (index - 1) * 40)
		row.BackgroundTransparency = 1; row.TextColor3 = Color3.fromRGB(255, 249, 231); row.Font = Enum.Font.GothamMedium
		row.TextSize = 14; row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = string.format("%s: %s", control.label, tostring(control.value))
		row.Parent = panel
		for side, sign in ipairs({-1, 1}) do
			local b = Instance.new("TextButton")
			b.Name = if sign < 0 then "Minus" else "Plus"
			b.Size = UDim2.fromOffset(38, 30); b.Position = UDim2.new(1, -88 + (side - 1) * 44, 0, 10 + (index - 1) * 40)
			b.Text = if sign < 0 then "−" else "+"; b.Font = Enum.Font.GothamBold; b.TextSize = 18
			b.BackgroundColor3 = Color3.fromRGB(255, 217, 90); b.Parent = panel
			b.Activated:Connect(function()
				control.value = Overlay.stepValue(control, sign)
				row.Text = string.format("%s: %s", control.label, tostring(control.value))
				ctx.apply(control.key, control.value)
			end)
		end
	end
	ContextActionService:BindAction("SparkTuningPanel", function(_, state)
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		panel.Visible = not panel.Visible
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F9)
	return {label = label, panel = panel}
end

return Overlay
