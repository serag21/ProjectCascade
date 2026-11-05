-- Intermission podium (FINAL_PRODUCTION_PLAN §6.1): up to three POSITIVE awards
-- for the arena's shared round. Never shows a ranking of everyone or a last place.
local Podium = {}

local AWARD_COLORS = {
	TopParade = Color3.fromRGB(255, 214, 90),
	LongestChain = Color3.fromRGB(120, 230, 190),
	GoldenCatcher = Color3.fromRGB(255, 190, 70),
	BestFlanker = Color3.fromRGB(150, 200, 255),
	StaticBuster = Color3.fromRGB(200, 170, 255),
}

-- Pure: display lines for an awards array (used by tests and the panel).
function Podium.lines(awards, localUserId)
	local lines = {}
	if type(awards) ~= "table" then return lines end
	for _, award in ipairs(awards) do
		if type(award) == "table" and type(award.title) == "string" then
			local you = award.userId == localUserId
			table.insert(lines, {
				kind = award.kind,
				title = string.upper(award.title),
				name = if you then "YOU" else tostring(award.name or "Player"),
				value = tostring(math.floor(tonumber(award.value) or 0)),
				you = you,
			})
		end
	end
	return lines
end

-- Build three award cards inside `parent` (a Frame). Returns update(awards, localUserId).
function Podium.mount(parent, make, round, palette)
	local strip = make("Frame", parent, {Name = "Podium", BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 64),
		Position = UDim2.fromOffset(20, 0), Visible = false})
	local cards = {}
	for index = 1, 3 do
		local card = make("Frame", strip, {Name = "Award" .. index, Size = UDim2.new(1 / 3, -6, 1, 0),
			Position = UDim2.new((index - 1) / 3, 3, 0, 0), BackgroundColor3 = palette.paper, BorderSizePixel = 0})
		round(card, 12)
		make("UIStroke", card, {Thickness = 2, Color = palette.gold})
		local title = make("TextLabel", card, {Name = "AwardTitle", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 18),
			Position = UDim2.fromOffset(4, 4), Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = palette.ink, Text = ""})
		local name = make("TextLabel", card, {Name = "AwardName", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 22),
			Position = UDim2.fromOffset(4, 22), Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = palette.purple, Text = ""})
		local value = make("TextLabel", card, {Name = "AwardValue", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 16),
			Position = UDim2.fromOffset(4, 45), Font = Enum.Font.GothamMedium, TextScaled = true, TextColor3 = palette.ink, Text = ""})
		for _, labelObject in ipairs({title, name, value}) do
			make("UITextSizeConstraint", labelObject, {MinTextSize = 8, MaxTextSize = 16})
		end
		cards[index] = {frame = card, title = title, name = name, value = value, stroke = card:FindFirstChildOfClass("UIStroke")}
	end
	return function(awards, localUserId)
		local lines = Podium.lines(awards, localUserId)
		strip.Visible = #lines > 0
		for index, card in ipairs(cards) do
			local line = lines[index]
			card.frame.Visible = line ~= nil
			if line then
				card.title.Text = line.title
				card.name.Text = line.name
				card.value.Text = line.value
				if card.stroke then card.stroke.Color = AWARD_COLORS[line.kind] or palette.gold end
				card.frame.BackgroundColor3 = if line.you then Color3.fromRGB(255, 246, 214) else palette.paper
			end
		end
		return #lines
	end
end

return Podium
