-- Shared client UI primitives. Presentation only; never decides rewards.
local Ui = {}

Ui.palette = {
	ink=Color3.fromRGB(28,35,66), paper=Color3.fromRGB(249,249,255), gold=Color3.fromRGB(255,219,90),
	mint=Color3.fromRGB(99,237,194), purple=Color3.fromRGB(120,96,211), row=Color3.fromRGB(234,234,249),
	warm=Color3.fromRGB(255,140,90), muted=Color3.fromRGB(150,154,184), sky=Color3.fromRGB(120,200,255),
	radiant=Color3.fromRGB(255,170,245), silver=Color3.fromRGB(205,214,232), bronze=Color3.fromRGB(226,156,104),
	zap=Color3.fromRGB(255,120,120),
}
-- Multiplier tiers carry a TEXT label as well as a colour (never colour-only).
Ui.tiers = {
	{label="x1", color=Color3.fromRGB(234,234,249)},
	{label="x2", color=Color3.fromRGB(99,237,194)},
	{label="x3 HOT", color=Color3.fromRGB(255,219,90)},
	{label="x4 STAMPEDE!", color=Color3.fromRGB(255,140,200)},
}
Ui.medals = {
	Radiant={color=Ui.palette.radiant, label="RADIANT"}, Gold={color=Ui.palette.gold, label="GOLD"},
	Silver={color=Ui.palette.silver, label="SILVER"}, Bronze={color=Ui.palette.bronze, label="BRONZE"},
	Unranked={color=Ui.palette.row, label="UNRANKED"},
}

function Ui.make(class, parent, props)
	local object = Instance.new(class)
	for key, value in pairs(props or {}) do object[key] = value end
	object.Parent = parent
	return object
end
function Ui.round(object, radius)
	Ui.make("UICorner", object, {CornerRadius=UDim.new(0, radius or 14)})
end
function Ui.label(parent, text, size, position, dimensions, color)
	return Ui.make("TextLabel", parent, {Text=text, TextSize=size, Font=Enum.Font.GothamBold,
		BackgroundTransparency=1, TextColor3=color or Ui.palette.ink, Position=position, Size=dimensions,
		TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left})
end
function Ui.button(parent, text, position, dimensions, color, callback)
	local b = Ui.make("TextButton", parent, {Text=text, TextSize=17, Font=Enum.Font.GothamBold,
		BackgroundColor3=color or Ui.palette.paper, TextColor3=Ui.palette.ink, BorderSizePixel=0,
		Position=position, Size=dimensions, AutoButtonColor=true, Selectable=true})
	Ui.round(b, 12)
	b.Activated:Connect(callback)
	return b
end
function Ui.bar(parent, name, position, dimensions, back, fill)
	local frame = Ui.make("Frame", parent, {Name=name, Position=position, Size=dimensions, BackgroundColor3=back,
		BorderSizePixel=0, ClipsDescendants=true})
	Ui.round(frame, 6)
	local inner = Ui.make("Frame", frame, {Name="Fill", Size=UDim2.fromScale(0,1), BackgroundColor3=fill, BorderSizePixel=0})
	Ui.round(inner, 6)
	return frame, inner
end
function Ui.tier(multiplier)
	local value = tonumber(multiplier)
	if not value or value ~= value then value = 1 end
	return Ui.tiers[math.clamp(math.floor(value), 1, #Ui.tiers)]
end
function Ui.clock(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	return string.format("%d:%02d", math.floor(seconds/60), seconds%60)
end
-- Safe nested read for payloads that may come from an older server build.
function Ui.get(t, ...)
	local value = t
	for _, key in ipairs({...}) do
		if type(value) ~= "table" then return nil end
		value = value[key]
	end
	return value
end

return Ui
