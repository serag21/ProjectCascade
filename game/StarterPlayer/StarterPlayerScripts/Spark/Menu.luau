-- Collection / setup menu. Renders server snapshots only; every button sends a
-- named Action that the server validates. Stable names support live UI QA.
local GuiService = game:GetService("GuiService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Spark")
local Config = require(Shared:WaitForChild("Config"))
local Profile = require(Shared:WaitForChild("Profile"))
local Loadout = require(Shared:WaitForChild("Loadout"))
local Progression = require(Shared:WaitForChild("Progression"))
local Ui = require(script.Parent.Ui)
local palette, make, round, label, button = Ui.palette, Ui.make, Ui.round, Ui.label, Ui.button

local Menu = {}
Menu.Tabs = {"Play", "Goals", "Album", "Upgrades", "Style", "Records", "Settings"}

-- Thresholds always come from Config.Medals (balance lives in one place).
local function medalFor(score)
	local m = Config.Medals
	if score >= m.Radiant then return "Radiant" elseif score >= m.Gold then return "Gold" elseif score >= m.Silver then return "Silver"
	elseif score >= m.Bronze then return "Bronze" end
	return "Unranked"
end
local function heatMultiplier(heat) return Loadout.stats({}, {}, heat).scoreMultiplier end
-- Human text for the chain ladder derived from live rules (chainStep / max tier).
function Menu.chainLadder()
	local base = Loadout.stats({}, {}, 0)
	local step, cap = base.chainStep or 3, base.maxMultiplier or 4
	local parts = {}
	for tier = 2, cap do
		table.insert(parts, "x"..tier..(if tier == cap then " STAMPEDE" else "").." from a "..((tier - 1) * step + 1).."-chain")
	end
	return table.concat(parts, " • ")
end
Menu.medalFor = medalFor

-- Pure tab-strip geometry (tested): fixed-width scroll on narrow panels.
function Menu.tabGeometry(available, count)
	local width = math.floor(available / count)
	if width >= 80 then return {width=width, canvas=available, scroll=false} end
	return {width=84, canvas=84 * count, scroll=true}
end

-- ctx: gui, data()->latest(with cached profile), fire(action,payload), miniature(id,parent),
-- controllerActive()->bool, onChanged(), toast(text), boards()->cached boards
function Menu.new(ctx)
	local self = {selected=nil, tabButtons={}, boardKind="alltime", boardBiome=nil}
	local shade = make("Frame", ctx.gui, {Name="Overlay", Size=UDim2.fromScale(1,1), BackgroundColor3=palette.ink,
		BackgroundTransparency=.3, Visible=false, ZIndex=5})
	local panel = make("Frame", shade, {Name="Panel", AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5),
		Size=UDim2.fromOffset(640,500), BackgroundColor3=palette.paper, BorderSizePixel=0, ZIndex=6})
	round(panel, 20)
	local title = label(panel, "YOUR SPARKS", 24, UDim2.fromOffset(22,14), UDim2.new(1,-80,0,38)); title.ZIndex = 7
	title.Name = "Title"; title.TextScaled = true; title.TextWrapped = false
	make("UITextSizeConstraint", title, {MinTextSize=12, MaxTextSize=24})
	local content = make("ScrollingFrame", panel, {Name="Content", Position=UDim2.fromOffset(16,108), Size=UDim2.new(1,-32,1,-124),
		BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=5, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
		Selectable=true, ZIndex=7})
	local tabs = make("ScrollingFrame", panel, {Name="Tabs", Position=UDim2.fromOffset(16,62), Size=UDim2.new(1,-32,0,40),
		BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3, ScrollingDirection=Enum.ScrollingDirection.X,
		CanvasSize=UDim2.fromOffset(608,0), ElasticBehavior=Enum.ElasticBehavior.Never, ZIndex=7})
	self.shade, self.panel, self.content, self.tabs = shade, panel, content, tabs

	local close
	local function data() return ctx.data() end
	function self.isOpen() return self.selected ~= nil end
	function self.open(name)
		self.selected = name
		shade.Visible = name ~= nil
		if name then
			self.render()
			local b = self.tabButtons[name]
			if b and tabs.AbsoluteCanvasSize.X > tabs.AbsoluteSize.X then
				tabs.CanvasPosition = Vector2.new(math.max(0, b.Position.X.Offset - 40), 0)
			end
		end
		if ctx.controllerActive() then
			GuiService.SelectedObject = if name then self.tabButtons[name] else nil
		elseif not name and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
			GuiService.SelectedObject = nil
		end
		ctx.onChanged()
	end
	close = button(panel, "×", UDim2.new(1,-54,0,14), UDim2.fromOffset(38,38), palette.gold, function() self.open(nil) end)
	close.ZIndex = 8; close.Name = "CloseButton"
	for index, name in ipairs(Menu.Tabs) do
		local b = button(tabs, name, UDim2.fromOffset((index-1)*87, 0), UDim2.fromOffset(83,34), palette.mint, function() self.open(name) end)
		b.Name = name; b.TextSize = 13; b.ZIndex = 8; b.TextScaled = true
		make("UITextSizeConstraint", b, {MinTextSize=10, MaxTextSize=14})
		self.tabButtons[name] = b
	end
	for index, name in ipairs(Menu.Tabs) do
		local b = self.tabButtons[name]
		b.NextSelectionLeft = self.tabButtons[Menu.Tabs[(index-2) % #Menu.Tabs + 1]]
		b.NextSelectionRight = self.tabButtons[Menu.Tabs[index % #Menu.Tabs + 1]]
		b.NextSelectionUp = close; b.NextSelectionDown = content
	end
	close.NextSelectionDown = self.tabButtons.Play
	content.NextSelectionUp = self.tabButtons.Play

	function self.resize(width, height)
		local w = math.min(640, math.max(240, width - 24))
		panel.Size = UDim2.fromOffset(w, math.min(560, math.max(200, height - 64)))
		local geometry = Menu.tabGeometry(w - 32, #Menu.Tabs)
		for index, name in ipairs(Menu.Tabs) do
			local b = self.tabButtons[name]
			b.Position = UDim2.fromOffset((index-1) * geometry.width, 0)
			b.Size = UDim2.fromOffset(geometry.width - 4, 34)
		end
		tabs.CanvasSize = UDim2.fromOffset(geometry.canvas, 0)
	end

	local function row(height, name)
		local r = make("Frame", content, {Name=name or "Row", Size=UDim2.new(1,-6,0,height), BackgroundColor3=palette.row, BorderSizePixel=0, ZIndex=8})
		round(r, 12)
		return r
	end
	local function rowText(r, text, size, y, color)
		local t = label(r, text, size, UDim2.fromOffset(14,y), UDim2.new(1,-28,0,size+14), color)
		t.Name = "Line_"..y; t.ZIndex = 9
		return t
	end
	local function rowButton(r, text, y, color, callback, name)
		local b = button(r, text, UDim2.fromOffset(14,y), UDim2.new(1,-28,0,38), color or palette.gold, callback)
		b.ZIndex = 9; b.Name = name or "ActionButton"
		b.TextScaled = true; make("UITextSizeConstraint", b, {MinTextSize=10, MaxTextSize=17})
		return b
	end
	local function header(text, name)
		local r = make("TextLabel", content, {Name=name or "Header", Text=text, TextSize=15, Font=Enum.Font.GothamBlack,
			BackgroundTransparency=1, TextColor3=palette.purple, Size=UDim2.new(1,-6,0,26), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=8})
		return r
	end
	local function progressBar(r, y, fraction, fill)
		local frame = Ui.bar(r, "Progress", UDim2.fromOffset(14,y), UDim2.new(1,-28,0,8), Color3.fromRGB(210,212,236), fill or palette.mint)
		frame.ZIndex = 9; frame.Fill.ZIndex = 10
		frame.Fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		return frame
	end
	local function playing() local d = data(); return d ~= nil and d.phase == "Playing" end
	local function titleOf(p)
		local text = Progression.titleText(p)
		return if text == "" then "None" else text
	end

	local renderers = {}
	renderers.Play = function(d, p)
		local note = row(56, "RoundSetup")
		rowText(note, if playing() then "Round in progress • Perks and Heat lock until results"
			else "Set up your next round, then CHASE AGAIN", 14, 6)
		rowText(note, "Rank "..(Ui.get(d,"rank","rank") or 1).." • Perk slots "..(d.perkSlots or 0).." • Heat unlocked "..(d.heatUnlocked or 0), 12, 30, palette.purple)
		header("ARENAS")
		for index, biome in ipairs(Config.Biomes) do
			local unlocked = p.totalBanked >= biome.unlock
			local r = row(118, "Arena_"..biome.id); rowText(r, biome.name, 19, 6); rowText(r, biome.description, 13, 34)
			rowButton(r, if unlocked then (if d.biome == index then "YOU ARE HERE" else "TRAVEL") else "Bank "..biome.unlock.." Sparks to unlock",
				72, Color3.fromRGB(table.unpack(biome.accent)), function()
					if unlocked then ctx.fire("Biome", index); self.open(nil) end
				end, "TravelButton")
		end
		header("HEAT • optional difficulty")
		local heatUnlocked, current = d.heatUnlocked or 0, p.heat or 0
		local heatRow = row(128, "HeatSelector")
		for heat = 0, Loadout.MaxHeat do
			local open = heat <= heatUnlocked
			local b = button(heatRow, if open then tostring(heat) else "LOCK", UDim2.new(heat/6, if heat==0 then 14 else 4, 0, 8),
				UDim2.new(1/6, -8, 0, 38), if heat == current then palette.gold elseif open then palette.mint else palette.muted, function()
					if playing() then ctx.toast("Change Heat after this round"); return end
					if not open then ctx.toast("Earn Silver ("..Loadout.SilverScore..") at Heat "..(heat-1).." to unlock"); return end
					ctx.fire("Heat", heat)
				end)
			b.Name = "Heat_"..heat; b.ZIndex = 9; b.TextSize = 14
		end
		local def = Loadout.Heat[current]
		rowText(heatRow, "Heat "..current.." • "..(if def then def.name else "").." • Score x"..string.format("%.1f", heatMultiplier(current)), 15, 52)
		rowText(heatRow, if def then def.description else "", 12, 78, palette.purple)
		rowText(heatRow, if heatUnlocked < Loadout.MaxHeat then "Next: Silver ("..Loadout.SilverScore..") at Heat "..heatUnlocked.." unlocks Heat "..(heatUnlocked+1) else "All Heat levels unlocked", 11, 100, palette.purple)
		local slots = d.perkSlots or 0
		local equipped = p.loadout or {}
		header("PERKS • "..#equipped.." / "..slots.." equipped")
		if slots == 0 then
			local r = row(44, "PerksLocked"); rowText(r, "Finish your first round (Rank 2) to unlock perks", 13, 8)
		end
		local rank = Ui.get(d, "rank", "rank") or 1
		for _, perk in ipairs(Loadout.Perks) do
			local on = table.find(equipped, perk.id) ~= nil
			local r = row(122, "Perk_"..perk.id)
			rowText(r, perk.name..(if on then "  •  EQUIPPED" else ""), 17, 5, if on then palette.purple else palette.ink)
			rowText(r, "+ "..perk.up, 13, 31, Color3.fromRGB(40,140,96))
			rowText(r, "- "..perk.down, 13, 51, Color3.fromRGB(176,70,70))
			local text = if rank < perk.rank then "Reach rank "..perk.rank elseif on then "REMOVE" else "EQUIP"
			rowButton(r, text, 76, if on then palette.paper elseif rank < perk.rank then palette.muted else palette.gold, function()
				if playing() then ctx.toast("Change perks after this round"); return end
				if rank < perk.rank then ctx.toast("Reach rank "..perk.rank.." to unlock "..perk.name); return end
				local nextList = {}
				for _, id in ipairs(equipped) do if id ~= perk.id then table.insert(nextList, id) end end
				if not on then
					if #nextList >= slots then ctx.toast("All perk slots full • remove one first"); return end
					table.insert(nextList, perk.id)
				end
				ctx.fire("Loadout", nextList)
			end, "PerkButton")
		end
	end

	local function goalRows(block, kindLabel, glow)
		local goals = block and block.goals or {}
		if #goals == 0 then
			local r = row(44, kindLabel.."Pending"); rowText(r, "Start a round to reveal "..string.lower(kindLabel).." goals", 13, 8)
			return
		end
		for _, id in ipairs(goals) do
			local goal = Progression.GoalById[id]
			if goal then
				local progress = math.min(goal.target, tonumber(block.progress and block.progress[id]) or 0)
				local claimed = block.claimed and block.claimed[id]
				local r = row(98, "Goal_"..id)
				rowText(r, goal.name, 16, 5)
				rowText(r, progress.." / "..goal.target..(if goal.scope == "round" then " in one round" else ""), 12, 28, palette.purple)
				progressBar(r, 48, progress / goal.target)
				rowButton(r, if claimed then "CLAIMED" elseif progress >= goal.target then "CLAIM "..glow.." GLOW" else "Reward: "..glow.." glow",
					54, if progress >= goal.target and not claimed then palette.gold else palette.mint, function() ctx.fire("Goal", id) end, "ClaimButton")
			end
		end
	end
	renderers.Goals = function(d, p)
		header("DAILY SPARKS • new set each UTC day • no streaks")
		goalRows(p.daily, "Daily", Progression.DailyGlow)
		if p.daily and p.daily.bonus then local r = row(36, "DailyBonus"); rowText(r, "Daily set bonus collected!", 13, 6) end
		header("WEEKLY SPARKS • resets Monday UTC")
		goalRows(p.weekly, "Weekly", Progression.WeeklyGlow)
		if d.rally then
			local rally = d.rally
			local r = row(112, "ArenaRally")
			rowText(r, "ARENA RALLY • "..rally.total.." / "..rally.target.." banked", 17, 5)
			rowText(r, "Solo or together: bank ordinary Sparks in 45 seconds", 13, 34)
			rowText(r, "Each active contributor earns 8 glow • First catches excluded", 12, 60)
			rowText(r, if rally.complete then "COMPLETE • Next rally in "..rally.remaining.."s" else "Your contribution: "..rally.contribution.." • "..rally.remaining.."s left", 12, 84)
		end
		if d.mastery and d.mastery.challenge then
			local goal = d.mastery.challenge
			local r = row(120, "RoundChallenge")
			rowText(r, goal.name.." • "..goal.progress.." / "..goal.target, 17, 5)
			rowText(r, goal.description, 13, 34)
			rowText(r, if goal.complete then "COMPLETE • 100 skill secured" else "Bank to secure 100 bonus skill • No glow cost", 13, 65)
			rowText(r, "Best chain: "..p.mastery.bestChain.." • Goals cleared: "..p.mastery.completed, 12, 91)
		end
		header("MILESTONES")
		for _, quest in ipairs(Config.Quests) do
			local progress = Profile.questProgress(p, quest)
			local claimed = p.quests[quest.id]
			local r = row(if quest.description then 136 else 104, "Quest_"..quest.id)
			rowText(r, quest.name.." • "..math.min(progress, quest.target).." / "..quest.target, 17, 5)
			if quest.description then rowText(r, quest.description, 13, 35) end
			local b = button(r, if claimed then "COMPLETE" elseif progress >= quest.target then "CLAIM "..quest.reward.." GLOW" else "Reward: "..quest.reward.." glow",
				UDim2.fromOffset(14, if quest.description then 85 else 53), UDim2.new(1,-28,0,38),
				if progress >= quest.target then palette.gold else palette.mint, function() ctx.fire("Quest", quest.id) end)
			b.ZIndex = 9; b.Name = "ClaimButton"
		end
		local earned = 0
		for _, a in ipairs(Progression.Achievements) do if p.achievements and p.achievements[a.id] then earned += 1 end end
		header("ACHIEVEMENTS • "..earned.." / "..#Progression.Achievements)
		for _, a in ipairs(Progression.Achievements) do
			local has = p.achievements and p.achievements[a.id] == true
			local r = row(if a.title and has then 108 else 66, "Achievement_"..a.id)
			rowText(r, (if has then "★ " else "☆ ")..a.name.."  •  +"..a.xp.." XP", 15, 5, if has then palette.purple else palette.ink)
			rowText(r, a.description..(if a.title then "  •  Title: "..a.title else ""), 12, 30)
			if a.title and has then
				local wearing = p.style and p.style.title == a.id
				rowButton(r, if wearing then "WEARING • tap to remove" else "WEAR TITLE", 62, if wearing then palette.paper else palette.gold,
					function() ctx.fire("Title", if wearing then "" else a.id) end, "TitleButton")
			end
		end
	end

	renderers.Album = function(_, p)
		local intro = row(80, "CollectionSummary"); rowText(intro, Profile.speciesCount(p).." / 12 discovered • Your collection stays with you", 15, 4)
		local tiers = {}
		for _, mutation in ipairs(Config.Mutations) do table.insert(tiers, mutation.threshold.." → "..mutation.name) end
		local gildedCount = 0
		for _, def in ipairs(Config.Creatures) do if p.gilded and p.gilded[def.id] then gildedCount += 1 end end
		rowText(intro, table.concat(tiers, "  •  ").."  •  Gilded "..gildedCount.." / "..#Config.Creatures, 13, 44)
		for _, def in ipairs(Config.Creatures) do
			local count = p.album[def.id] or 0
			local r = row(108, "Album_"..def.id)
			local view = make("ViewportFrame", r, {Name="Preview", Position=UDim2.fromOffset(8,8), Size=UDim2.fromOffset(92,92), BackgroundTransparency=1, ZIndex=9,
				Ambient=Color3.fromRGB(200,200,200), LightColor=Color3.new(1,1,1), LightDirection=Vector3.new(-1,-1,-1)})
			local mini = ctx.miniature(def.id, view); mini:PivotTo(CFrame.new())
			local bounds, size = mini:GetBoundingBox()
			local distance = math.max(6, size.Magnitude * .5 / math.sin(math.rad(20)))
			local target = bounds.Position
			local camera = make("Camera", view, {CFrame=CFrame.lookAt(target + Vector3.new(.3,.18,-1).Unit * distance, target), FieldOfView=40})
			view.CurrentCamera = camera
			local gilded = p.gilded and p.gilded[def.id]
			local name = label(r, def.name.."  •  "..def.rarity..(if gilded then "  •  GILDED" else ""), 17, UDim2.fromOffset(110,10), UDim2.new(1,-122,0,26))
			name.ZIndex = 9; name.Name = "SpeciesName"; name.TextScaled = true
			make("UITextSizeConstraint", name, {MinTextSize=11, MaxTextSize=17})
			local description = label(r, def.trait, 13, UDim2.fromOffset(110,39), UDim2.new(1,-122,0,30)); description.ZIndex = 9
			description.Name = "Trait"
			local mutation = (p.mutations and p.mutations[def.id]) or 0
			local status = label(r, if count == 0 then "Find in "..Config.Biomes[def.biome].name
				else count.." banked"..(if mutation > 0 and Config.Mutations[mutation] then "  •  "..Config.Mutations[mutation].name else ""),
				13, UDim2.fromOffset(110,73), UDim2.new(1,-122,0,24), palette.purple)
			status.ZIndex = 9; status.Name = "Status"
		end
	end

	renderers.Upgrades = function(_, p)
		for _, key in ipairs({"boots","magnet","basket"}) do
			local upgrade = Config.Upgrades[key]; local level = p.upgrades[key]; local price = upgrade.costs[level+1]
			local r = row(130, "Upgrade_"..key); rowText(r, upgrade.name.." • Level "..level, 18, 6); rowText(r, upgrade.description, 14, 37)
			local b = button(r, if price then "UPGRADE • "..price.." GLOW" else "FULLY UPGRADED", UDim2.fromOffset(14,80), UDim2.new(1,-28,0,38),
				palette.gold, function() if price then ctx.fire("Upgrade", key) end end)
			b.ZIndex = 9; b.Name = "UpgradeButton"
		end
		local tip = row(60, "UpgradeTip"); rowText(tip, "Upgrades are permanent. Perks (Play tab) are swappable side-grades.", 13, 8)
	end

	renderers.Style = function(d, p)
		local style = p.style or {trail="none", title=""}
		local summary = row(66, "StyleSummary")
		rowText(summary, "Trail: "..((Progression.TrailById[style.trail] or {name="None"}).name).."  •  Title: "..titleOf(p), 15, 6)
		rowText(summary, "All styles are earned or bought with glow at a fixed price. Nothing random.", 12, 34, palette.purple)
		local rank = Ui.get(d, "rank", "rank") or 1
		for _, trail in ipairs(Progression.Trails) do
			local unlocked = Progression.styleUnlocked(p, trail)
			local equipped = style.trail == trail.id
			local r = row(104, "Trail_"..trail.id)
			for index, rgb in ipairs(trail.colors) do
				local swatch = make("Frame", r, {Name="Swatch"..index, Position=UDim2.new(1,-74+(index-1)*30,0,10), Size=UDim2.fromOffset(24,24),
					BackgroundColor3=Color3.fromRGB(table.unpack(rgb)), BorderSizePixel=0, ZIndex=9})
				round(swatch, 12)
			end
			rowText(r, trail.name..(if equipped then "  •  EQUIPPED" else ""), 17, 6, if equipped then palette.purple else palette.ink)
			local how
			if unlocked then how = "Unlocked"
			elseif trail.achievement then how = "Earn: "..((Progression.AchievementById[trail.achievement] or {name=trail.achievement}).name)
			elseif trail.rank and trail.price then how = "Rank "..trail.rank.." • "..trail.price.." glow"..(if rank < trail.rank then " (rank "..rank..")" else "")
			elseif trail.rank and rank < trail.rank then how = "Reach rank "..trail.rank
			elseif trail.price then how = trail.price.." glow" else how = "Locked" end
			rowText(r, how, 12, 32, palette.purple)
			local text = if equipped then "EQUIPPED" elseif unlocked then "EQUIP"
				elseif trail.price and not (trail.rank and rank < trail.rank) and not trail.achievement then "BUY • "..trail.price.." GLOW" else "LOCKED"
			rowButton(r, text, 56, if equipped then palette.paper elseif text == "LOCKED" then palette.muted else palette.gold, function()
				if equipped then return end
				if text == "LOCKED" then ctx.toast(how); return end
				ctx.fire("Style", trail.id)
			end, "StyleButton")
		end
	end

	renderers.Records = function(d, p)
		header("YOUR BEST SCORES • per arena and Heat")
		for _, biome in ipairs(Config.Biomes) do
			local scores = (p.records and p.records[biome.id]) or {}
			local r = row(92, "Record_"..biome.id)
			rowText(r, biome.name, 17, 5)
			local parts, parts2 = {}, {}
			for heat = 0, Loadout.MaxHeat do
				local score = tonumber(scores[heat+1]) or 0
				local text = "H"..heat.." "..score..(if score >= Config.Medals.Bronze then " ("..string.sub(medalFor(score),1,1)..")" else "")
				table.insert(if heat < 3 then parts else parts2, text)
			end
			rowText(r, table.concat(parts, "   "), 13, 34, palette.purple)
			rowText(r, table.concat(parts2, "   "), 13, 58, palette.purple)
		end
		local boards = ctx.boards()
		self.boardBiome = self.boardBiome or d.biome or 1
		local biome = Config.Biomes[self.boardBiome] or Config.Biomes[1]
		header("LEADERBOARD • "..string.upper(biome.name).." • "..(if self.boardKind == "weekly" then "THIS WEEK" else "ALL TIME"))
		local pick = row(50, "BoardPicker")
		for index, b in ipairs(Config.Biomes) do
			local chip = button(pick, b.name, UDim2.new((index-1)/4, 10, 0, 6),
				UDim2.new(1/4, -8, 0, 38), if index == self.boardBiome then palette.gold else palette.mint, function() self.boardBiome = index; self.render() end)
			chip.Name = "Board_"..b.id; chip.ZIndex = 9; chip.TextScaled = true
			make("UITextSizeConstraint", chip, {MinTextSize=9, MaxTextSize=14})
		end
		local kind = button(pick, if self.boardKind == "weekly" then "WEEK" else "ALL", UDim2.new(3/4, 10, 0, 6), UDim2.new(1/4, -20, 0, 38), palette.paper, function()
			self.boardKind = if self.boardKind == "weekly" then "alltime" else "weekly"; self.render()
		end)
		kind.Name = "BoardKind"; kind.ZIndex = 9
		local rows = Ui.get(boards, biome.id, self.boardKind)
		if type(rows) ~= "table" or #rows == 0 then
			local r = row(44, "BoardEmpty"); rowText(r, "No scores yet • set one and claim the top spot!", 13, 8)
		else
			for _, entry in ipairs(rows) do
				local r = row(34, "BoardRow_"..tostring(entry.rank))
				rowText(r, "#"..tostring(entry.rank).."  "..tostring(entry.name or "Player").."  •  "..tostring(entry.score), 14, 4)
			end
		end
		local note = row(40, "BoardNote"); rowText(note, "Leaderboards refresh every 2 minutes. Scores include Heat multipliers.", 11, 6, palette.purple)
	end

	renderers.Settings = function(d, p)
		for _, setting in ipairs({{"reducedMotion","Reduced motion"},{"music","Music"},{"sfx","Sound effects"},{"competition","Opt in: session scores"}}) do
			local r = row(64, "Setting_"..setting[1])
			local b = button(r, setting[2]..": "..(if p.settings[setting[1]] then "ON" else "OFF"), UDim2.fromOffset(12,10), UDim2.new(1,-24,0,44), palette.mint,
				function() ctx.fire("Settings", {[setting[1]]=not p.settings[setting[1]]}) end)
			b.ZIndex = 9; b.Name = "ToggleButton"
		end
		local r = row(96, "ControlsHelp"); rowText(r, "Move: WASD / thumbstick • Jump: Space / A", 14, 7)
		rowText(r, "Catch: E / X • Dash: Shift / B • Bank: R / Y", 14, 34)
		rowText(r, "Menu: M / Select • All rewards earned in play", 13, 61)
		local help = row(196, "MasteryHelp")
		rowText(help, "Close + facing = PRECISE • Dash THROUGH Sparks to catch several", 13, 7)
		rowText(help, "Chain catches: "..Menu.chainLadder(), 13, 33)
		rowText(help, "Herd Sparks through the SPARK GATE • Dash through the STAMPEDE RUN", 13, 59)
		rowText(help, "Purple statics zap you: dodge, or DASH through to pop them", 13, 85)
		rowText(help, "Zaps scatter carried Sparks • recatch them!", 13, 111)
		rowText(help, "Bank before the BUZZER or carried style bonus is lost", 13, 137)
		rowText(help, "Banked score, glow and collection are always safe", 13, 163)
		if p.settings.competition then
			local scores = row(130, "SessionScores")
			rowText(scores, "Optional session scores • current rounds", 14, 4)
			for index, entry in ipairs(d.ranking or {}) do rowText(scores, entry.name.." • "..entry.score, 13, 8 + index * 24) end
		end
	end

	function self.render()
		local focused = GuiService.SelectedObject
		local focusedRow = if focused and focused.Parent and focused:IsDescendantOf(content) then focused.Parent.Name else nil
		local focusedName = if focusedRow then focused.Name else nil
		for _, child in ipairs(content:GetChildren()) do child:Destroy() end
		make("UIListLayout", content, {Padding=UDim.new(0,9), SortOrder=Enum.SortOrder.LayoutOrder})
		local d = data()
		if not d or not d.profile or not self.selected then return end
		local p = d.profile
		title.Text = string.upper(self.selected).."  •  "..p.coins.." GLOW"
		local renderer = renderers[self.selected]
		if renderer then renderer(d, p) end
		local order = 0
		for _, child in ipairs(content:GetChildren()) do
			if child:IsA("GuiObject") then order += 1; child.LayoutOrder = order end
		end
		local firstAction = nil
		for _, r in ipairs(content:GetChildren()) do
			if r:IsA("GuiButton") then firstAction = r; break end
			for _, child in ipairs(r:GetChildren()) do
				if child:IsA("GuiButton") then firstAction = child; break end
			end
			if firstAction then break end
		end
		for _, b in pairs(self.tabButtons) do b.NextSelectionDown = firstAction or content end
		if focusedRow and ctx.controllerActive() then
			local replacementRow = content:FindFirstChild(focusedRow)
			GuiService.SelectedObject = (replacementRow and replacementRow:FindFirstChild(focusedName)) or self.tabButtons[self.selected]
		end
	end

	-- Countdown refresh without rebuilding controls or stealing gamepad focus.
	function self.live(d)
		if self.selected ~= "Goals" or not d or not d.rally then return end
		local rallyRow = content:FindFirstChild("ArenaRally")
		local countdown = rallyRow and rallyRow:FindFirstChild("Line_84")
		if countdown then
			countdown.Text = if d.rally.complete then "COMPLETE • Next rally in "..d.rally.remaining.."s"
				else "Your contribution: "..d.rally.contribution.." • "..d.rally.remaining.."s left"
		end
	end

	return self
end

return Menu
