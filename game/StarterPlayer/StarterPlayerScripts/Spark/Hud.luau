-- HUD v2 (WP-07) from design/fable/data/ui_layout.json (Design.UiLayout).
-- Rects are authored at three reference viewports and placed by anchor
-- (top-left / top-center / top-right / bottom-center / bottom-right), so the
-- same offsets hold at any screen size. World-first: loop payouts and technique
-- tags appear in the 3D world (LoopFx), never as HUD panels. One toast line at
-- a time (queue <= 3, 1.6 s each). Panels: ink at 35 % transparency, 10 px
-- corners, no strokes; paper text.
local Hud = {}

Hud.INK = {27, 36, 64}
Hud.PAPER = {255, 249, 231}
Hud.GOLD = {255, 217, 90}

-- Pure: which reference viewport to use for a screen size and input mode.
function Hud.viewportFor(width, height, touch)
	if touch then
		return if height < 500 then "phone_756x354" else "tablet_1024x732"
	end
	return "desktop_1280x684"
end

local function anchorOf(layout, id)
	for _, e in ipairs(layout.elements) do if e.id == id then return e.anchor, e end end
	return "top-left", nil
end
Hud.anchorOf = anchorOf

-- Pure: UDim2 components for an element at a reference viewport.
-- -> {xs, xo, ys, yo, w, h} or nil when the element is absent at that viewport.
function Hud.place(layout, viewport, id)
	local vp = layout.viewports[viewport]
	local r = vp and vp.rects[id]
	if not r then return nil end
	local W, H = vp.size[1], vp.size[2]
	local anchor = anchorOf(layout, id)
	local x, y, w, h = r[1], r[2], r[3], r[4]
	local xs, xo, ys, yo = 0, x, 0, y
	if string.find(anchor, "center", 1, true) then xs, xo = 0.5, x - W / 2 end
	if string.find(anchor, "right", 1, true) then xs, xo = 1, x - W end
	if string.find(anchor, "bottom", 1, true) then ys, yo = 1, y - H end
	return {xs = xs, xo = xo, ys = ys, yo = yo, w = w, h = h}
end

-- Pure: absolute rect of a placement on a screen of size (width, height).
function Hud.absolute(placement, width, height)
	return {placement.xs * width + placement.xo, placement.ys * height + placement.yo, placement.w, placement.h}
end

-- Pure: m:ss
function Hud.clock(seconds)
	seconds = math.max(0, math.ceil(seconds or 0))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- Pure: bank multiplier for a parade size from the tuning tiers.
function Hud.bankTier(tiers, carried)
	local m = 1
	for _, tier in ipairs(tiers) do if carried >= tier[1] then m = tier[2] end end
	return m
end

-- Pure: toast queue (max 3 waiting, 1.6 s each, one visible).
function Hud.newToasts() return {queue = {}, current = nil, untilT = 0} end
function Hud.pushToast(q, text, now)
	if #q.queue >= 3 then table.remove(q.queue, 1) end
	table.insert(q.queue, text)
	return Hud.stepToast(q, now)
end
function Hud.stepToast(q, now)
	if q.current and now < q.untilT then return q.current end
	q.current = table.remove(q.queue, 1)
	q.untilT = if q.current then now + 1.6 else 0
	return q.current
end

---------------------------------------------------------------- Roblox side
local function rgb(v) return Color3.fromRGB(v[1], v[2], v[3]) end

function Hud.new(ctx)
	local UserInputService = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")
	local layout, gui = ctx.layout, ctx.gui
	local self = {elements = {}, toasts = Hud.newToasts(), viewport = nil}
	local INK, PAPER, GOLD = rgb(Hud.INK), rgb(Hud.PAPER), rgb(Hud.GOLD)

	local function panel(id, transparency)
		local f = Instance.new("Frame")
		f.Name = "Hud_" .. id
		f.BackgroundColor3 = INK
		f.BackgroundTransparency = transparency or 0.35
		f.BorderSizePixel = 0
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = f
		f.Parent = gui
		self.elements[id] = f
		return f
	end
	local function text(parent, size, font, color)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Font = font or Enum.Font.GothamBold
		l.TextSize = size
		l.TextColor3 = color or PAPER
		l.Text = ""
		l.Parent = parent
		return l
	end

	-- timer, phase, score, chain, toast, hint
	local timer = panel("timer"); local timerText = text(timer, 24, Enum.Font.GothamBold)
	local phase = panel("phase", 1); local phaseText = text(phase, 13, Enum.Font.GothamBold, GOLD)
	local score = panel("score"); local scoreText = text(score, 20, Enum.Font.GothamBold)
	local chain = panel("chain"); local chainText = text(chain, 13, Enum.Font.GothamBold, GOLD)
	chainText.Size = UDim2.new(0, 44, 1, 0); chainText.TextXAlignment = Enum.TextXAlignment.Left
	chainText.Position = UDim2.fromOffset(6, 0)
	local chainBar = Instance.new("Frame"); chainBar.Name = "Bar"; chainBar.BorderSizePixel = 0
	chainBar.BackgroundColor3 = GOLD; chainBar.Position = UDim2.new(0, 50, 0.5, -3); chainBar.Size = UDim2.new(1, -58, 0, 6)
	chainBar.Parent = chain
	local toast = panel("toast"); local toastText = text(toast, 14, Enum.Font.GothamMedium)
	local hint = panel("hint"); local hintText = text(hint, 15, Enum.Font.GothamBold)
	-- parade: 12 capacity pips + bank multiplier chip
	local parade = panel("parade")
	local pips = {}
	for i = 1, 21 do
		local pip = Instance.new("Frame")
		pip.Name = "Pip" .. i; pip.BorderSizePixel = 0; pip.Size = UDim2.fromOffset(11, 11)
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = pip
		pip.Parent = parade
		pips[i] = pip
	end
	local tierChip = text(parade, 13, Enum.Font.GothamBold, GOLD)
	tierChip.Name = "BankTier"; tierChip.Size = UDim2.new(0, 46, 1, 0); tierChip.Position = UDim2.new(1, -48, 0, 0)
	-- menu button
	local menu = Instance.new("TextButton")
	menu.Name = "Hud_menu"; menu.Text = "≡"; menu.TextSize = 24; menu.Font = Enum.Font.GothamBold
	menu.TextColor3 = PAPER; menu.BackgroundColor3 = INK; menu.BackgroundTransparency = 0.35; menu.BorderSizePixel = 0
	local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 10); mc.Parent = menu
	menu.Parent = gui
	self.elements.menu = menu
	local badge = Instance.new("Frame"); badge.Name = "Badge"; badge.Size = UDim2.fromOffset(10, 10)
	badge.Position = UDim2.new(1, -8, 0, -2); badge.BackgroundColor3 = GOLD; badge.BorderSizePixel = 0; badge.Visible = false
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0.5, 0); bc.Parent = badge
	badge.Parent = menu
	menu.Activated:Connect(function() if ctx.onMenu then ctx.onMenu() end end)
	-- dash charges (keyboard/gamepad) and the touch dash button
	local dash = panel("dash", 1)
	local diamonds = {}
	for i = 1, 3 do
		local d = Instance.new("Frame")
		d.Name = "Charge" .. i; d.Size = UDim2.fromOffset(22, 22); d.Rotation = 45; d.BorderSizePixel = 0
		d.BackgroundColor3 = INK; d.BackgroundTransparency = 0.35; d.ClipsDescendants = true
		local fill = Instance.new("Frame"); fill.Name = "Fill"; fill.BorderSizePixel = 0; fill.BackgroundColor3 = GOLD
		fill.AnchorPoint = Vector2.new(0, 1); fill.Position = UDim2.fromScale(0, 1); fill.Size = UDim2.fromScale(1, 1)
		fill.Parent = d
		d.Parent = dash
		diamonds[i] = d
	end
	local dashKey = text(dash, 11, Enum.Font.GothamMedium); dashKey.Name = "Key"
	dashKey.Size = UDim2.new(1, 0, 0, 12); dashKey.Position = UDim2.new(0, 0, 1, -10); dashKey.Text = "SHIFT / E"
	local dashButton = Instance.new("TextButton")
	dashButton.Name = "Hud_dashButton"; dashButton.Text = "DASH"; dashButton.Font = Enum.Font.GothamBold; dashButton.TextSize = 18
	dashButton.TextColor3 = rgb(Hud.INK); dashButton.BackgroundColor3 = GOLD; dashButton.BorderSizePixel = 0
	local dbc = Instance.new("UICorner"); dbc.CornerRadius = UDim.new(0.5, 0); dbc.Parent = dashButton
	dashButton.Parent = gui
	dashButton.Activated:Connect(function() if ctx.onDash then ctx.onDash() end end)
	self.elements.dashButton = dashButton

	-- Place everything at the current viewport.
	function self.layout()
		local camera = workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Vector2.new(1280, 684)
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local vp = Hud.viewportFor(size.X, size.Y, touch)
		self.viewport = vp
		for id, element in pairs(self.elements) do
			local p = Hud.place(layout, vp, id)
			element.Visible = p ~= nil
			if p then
				element.Position = UDim2.new(p.xs, p.xo, p.ys, p.yo)
				element.Size = UDim2.fromOffset(p.w, p.h)
			end
		end
		-- Input-specific: diamonds for keyboard/gamepad, the round button for touch.
		dash.Visible = Hud.place(layout, vp, "dash") ~= nil
		dashButton.Visible = Hud.place(layout, vp, "dashButton") ~= nil
		local pipSize = math.max(6, math.min(11, math.floor(((Hud.place(layout, vp, "parade") or {w = 236}).w - 60) / 12) - 2))
		for i, pip in ipairs(pips) do
			pip.Size = UDim2.fromOffset(pipSize, pipSize)
			pip.Position = UDim2.new(0, 8 + (i - 1) * (pipSize + 2), 0.5, -pipSize / 2)
		end
	end
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(self.layout)
	end
	self.layout()
	phase.Visible = false; toast.Visible = false; hint.Visible = false

	local shownScore, scoreTarget, scoreFrom, scoreAt = 0, 0, 0, 0
	local phaseUntil, lastPhase = 0, nil
	local hintUntil = 0
	function self.setScore(value, now)
		if value ~= scoreTarget then scoreFrom, scoreTarget, scoreAt = shownScore, value, now end
	end
	function self.setPhase(name, now)
		if name and name ~= lastPhase then
			lastPhase = name
			phaseText.Text = name
			phaseUntil = now + 3
		end
	end
	function self.toast(message, now) Hud.pushToast(self.toasts, message, now) end
	function self.hint(message, now, seconds)
		hintText.Text = message
		hintUntil = now + (seconds or 6)
	end
	function self.clearHint() hintUntil = 0 end
	function self.setBadge(on) badge.Visible = on == true end

	-- Per-frame update. s = {remaining, phaseName, carry = {species...}, capacity,
	--   score, chainMult, chainLeft, chainSpan, charges, maxCharges, nextCharge, recharge,
	--   rounds, reduced, palette(species) -> Color3, bankTiers}
	function self.update(s, now)
		timerText.Text = Hud.clock(s.remaining)
		local gold = (s.remaining or 0) <= 25
		timerText.TextColor3 = if gold then GOLD else PAPER
		local pulse = gold and (s.remaining or 0) <= 10 and not s.reduced
		timerText.TextSize = if pulse then 24 + 3 * math.max(0, math.sin(now * math.pi * 2)) else 24
		phase.Visible = now < phaseUntil
		phaseText.TextTransparency = math.clamp(1 - (phaseUntil - now) / 0.6, 0, 1)
		local a = math.clamp((now - scoreAt) / 0.3, 0, 1)
		shownScore = math.floor(scoreFrom + (scoreTarget - scoreFrom) * a + 0.5)
		scoreText.Text = tostring(shownScore)
		local active = (s.chainMult or 1) > 1 or (s.chainLeft or 0) > 0
		chain.Visible = active and (s.chainMult or 1) > 1
		chainText.Text = "x" .. tostring(s.chainMult or 1)
		chainBar.Size = UDim2.new(math.clamp((s.chainLeft or 0) / math.max(1, s.chainSpan or 7), 0, 1), -58, 0, 6)
		local carry, capacity = s.carry or {}, s.capacity or 12
		for i, pip in ipairs(pips) do
			pip.Visible = i <= capacity
			local species = carry[i]
			pip.BackgroundColor3 = if species and s.palette then s.palette(species) else INK
			pip.BackgroundTransparency = if species then 0 else 0.2
		end
		local tier = Hud.bankTier(s.bankTiers or {}, #carry)
		tierChip.Text = if #carry > 0 then "x" .. tostring(tier) else ""
		local current = Hud.stepToast(self.toasts, now)
		toast.Visible = current ~= nil
		toastText.Text = current or ""
		hint.Visible = now < hintUntil
		-- Dash charges: filled diamonds, the recharging one fills radially (bottom-up).
		local maxCharges = s.maxCharges or 2
		for i, d in ipairs(diamonds) do
			d.Visible = i <= maxCharges
			d.Position = UDim2.new(0.5, (i - (maxCharges + 1) / 2) * 32 - 11, 0, 4)
			local fill = d:FindFirstChild("Fill")
			local amount = if i <= (s.charges or 0) then 1 elseif i == (s.charges or 0) + 1 and s.recharge
				then 1 - math.clamp((s.nextCharge or 0) / s.recharge, 0, 1) else 0
			fill.Size = UDim2.fromScale(1, amount)
			fill.BackgroundTransparency = if amount >= 1 then 0 else 0.45
		end
		dashKey.Visible = (s.rounds or 0) < 3
		dashButton.BackgroundTransparency = if (s.charges or 0) > 0 then 0 else 0.45
	end

	-- Slice results sheet (WP-08): score, provisional medal, best loop size, next-round countdown.
	local sheet = Instance.new("Frame")
	sheet.Name = "ResultsSheet"; sheet.BackgroundColor3 = INK; sheet.BackgroundTransparency = 0.2; sheet.BorderSizePixel = 0
	local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 14); sc.Parent = sheet
	sheet.Visible = false
	sheet.Parent = gui
	local sheetScore = text(sheet, 40, Enum.Font.GothamBlack); sheetScore.Name = "Score"
	sheetScore.Size = UDim2.new(0.34, 0, 0.6, 0); sheetScore.Position = UDim2.fromScale(0.02, 0.08)
	local sheetMedal = text(sheet, 20, Enum.Font.GothamBold, GOLD); sheetMedal.Name = "Medal"
	sheetMedal.Size = UDim2.new(0.34, 0, 0.25, 0); sheetMedal.Position = UDim2.fromScale(0.02, 0.66)
	local sheetLoop = text(sheet, 18, Enum.Font.GothamBold); sheetLoop.Name = "BestLoop"
	sheetLoop.Size = UDim2.new(0.3, 0, 0.8, 0); sheetLoop.Position = UDim2.fromScale(0.36, 0.1)
	local sheetNext = text(sheet, 16, Enum.Font.GothamMedium); sheetNext.Name = "Next"
	sheetNext.Size = UDim2.new(0.3, 0, 0.8, 0); sheetNext.Position = UDim2.fromScale(0.68, 0.1)
	self.sheet = sheet
	function self.results(r)
		local small = self.viewport == "phone_756x354"
		local rect = if small then layout.results.phone.rect else layout.results.desktop.rect
		local vp = layout.viewports[self.viewport]
		sheet.Position = UDim2.new(0.5, rect[1] - vp.size[1] / 2, 1, rect[2] - vp.size[2])
		sheet.Size = UDim2.fromOffset(rect[3], rect[4])
		if not r then sheet.Visible = false; return end
		sheet.Visible = true
		sheetScore.Text = tostring(r.score or 0)
		sheetMedal.Text = if r.medal and r.medal ~= "Unranked" then string.upper(r.medal) else "KEEP GOING"
		sheetLoop.Text = string.format("BEST LOOP\n%d Spark%s", r.bestLoop or 0, if (r.bestLoop or 0) == 1 then "" else "s")
		sheetNext.Text = if r.nextIn then string.format("NEXT ROUND\nin %ds", math.max(0, math.ceil(r.nextIn))) else "NEXT ROUND\nsoon"
	end
	self.tween = TweenService
	return self
end

return Hud
