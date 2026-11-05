-- Collection / setup menu. Renders server snapshots only; every button sends a
-- named Action that the server validates. Stable names support live UI QA.
-- Tabs reveal progressively (FINAL_PRODUCTION_PLAN §6.3.2). The reveal schedule,
-- badge logic and render fingerprint are pure functions (marked block below) that
-- tests/test_spark_menu.py runs in the Luau CLI against the real shared modules.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Spark")
local Config = require(Shared:WaitForChild("Config"))
local Profile = require(Shared:WaitForChild("Profile"))
local Loadout = require(Shared:WaitForChild("Loadout"))
local Progression = require(Shared:WaitForChild("Progression"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Trial = require(Shared:WaitForChild("Trial"))
local Ui = require(script.Parent.Ui)
local palette, make, round, label, button = Ui.palette, Ui.make, Ui.round, Ui.label, Ui.button

local Menu = {}

-- BEGIN PURE MENU (tests/test_spark_menu.py runs this block in the Luau CLI; it must
-- only use Config/Profile/Loadout/Progression/Cosmetics/Trial/Menu and Luau builtins.)
Menu.Tabs = {"Play", "Goals", "Album", "Upgrades", "Style", "Records", "Settings"}
-- Disclosure schedule (UI pacing from plan §6.3.2, not balance). Prices are always
-- read from Config.Upgrades / Progression.Trails / Cosmetics.
Menu.Reveal = {playRounds=1, goalsRounds=3, recordsRounds=1, styleRank=3}
Menu.TrialGoal = "d_trial"
Menu.ClaimPrefix = "claim:"
Menu.VolumeStep = 0.1
Menu.SettingKeys = {"reducedMotion", "music", "sfx", "competition", "showOnPodium", "holdCatch", "highContrast",
	"uiScale", "musicVolume", "sfxVolume"}
Menu.DefaultSignatureStars = {10, 25, 50}
Menu.SignatureHints = {
	DASH="Dash-catch it",
	PRECISE="Catch it close and facing",
	TOGETHER="Catch it in a multi-dash or herd it through a gate",
	RHYTHM="Catch it while your chain is x2+",
}
Menu.EncounterNames = {gate="Spark Gate", stampede="Stampede Run", starfall="Starfall"}

local function number(value)
	return if type(value) == "number" and value == value and value > -math.huge and value < math.huge then value else 0
end
local function field(t, key)
	return if type(t) == "table" then t[key] else nil
end

function Menu.rankOf(data)
	local rank = field(field(data, "rank"), "rank")
	if type(rank) == "number" and rank == rank then return rank end
	return Progression.rank(field(field(data, "profile"), "xp"))
end

function Menu.cheapestUpgrade()
	local cheapest = math.huge
	for _, upgrade in pairs(Config.Upgrades) do
		local cost = upgrade.costs[1]
		if type(cost) == "number" and cost < cheapest then cheapest = cost end
	end
	return cheapest
end

local function anyUpgrade(p)
	for key in pairs(Config.Upgrades) do
		if number(field(p.upgrades, key)) > 0 then return true end
	end
	return false
end
local function anyOwned(owned)
	if type(owned) ~= "table" then return false end
	for _, value in pairs(owned) do
		if value == true then return true end
	end
	return false
end

function Menu.hasRecord(p)
	local records = field(p, "records")
	for _, biome in ipairs(Config.Biomes) do
		local row = field(records, biome.id)
		if type(row) == "table" then
			for heat = 0, Loadout.MaxHeat do
				if number(row[heat + 1]) > 0 then return true end
			end
		end
	end
	return false
end

-- Safe wrapper: Progression.styleUnlocked expects a full sanitized profile.
function Menu.trailUnlocked(p, trail)
	if type(field(p, "style")) ~= "table" or type(p.style.owned) ~= "table" or type(p.achievements) ~= "table" then
		return trail.id == "none"
	end
	return Progression.styleUnlocked(p, trail)
end

-- Priced trails and cosmetics buyable right now: rank met, not owned, enough glow.
function Menu.affordableStyles(p, rank)
	local list = {}
	if type(p) ~= "table" then return list end
	local coins = number(p.coins)
	local ownedTrails = field(field(p, "style"), "owned")
	for _, trail in ipairs(Progression.Trails) do
		if trail.price and not trail.achievement and not field(ownedTrails, trail.id)
			and coins >= trail.price and rank >= (trail.rank or 0) then
			table.insert(list, trail.id)
		end
	end
	for _, item in ipairs(Cosmetics.Items) do
		if item.price and not item.achievement and coins >= item.price and rank >= (item.rank or 0)
			and not Cosmetics.isUnlocked(p, item) then
			table.insert(list, item.id)
		end
	end
	return list
end

-- Ordered tab names to show for the latest server state {profile, rank, phase, trial}.
function Menu.visibleTabs(data)
	local p = field(data, "profile")
	local show = {Album=true, Settings=true}
	if type(p) == "table" then
		local rounds = number(p.rounds)
		local rank = Menu.rankOf(data)
		show = {
			Album=true, Settings=true,
			Play=rounds >= Menu.Reveal.playRounds,
			Goals=rounds >= Menu.Reveal.goalsRounds,
			Upgrades=number(p.coins) >= Menu.cheapestUpgrade() or anyUpgrade(p),
			Style=rank >= Menu.Reveal.styleRank or #Menu.affordableStyles(p, rank) > 0
				or anyOwned(field(p.style, "owned")) or anyOwned(field(p.cosmetics, "owned")),
			Records=rounds >= Menu.Reveal.recordsRounds
				and (Menu.hasRecord(p) or number(field(field(data, "trial"), "best")) > 0),
		}
	end
	local list = {}
	for _, tab in ipairs(Menu.Tabs) do
		if show[tab] then table.insert(list, tab) end
	end
	return list
end

-- Goal definition for an id; "d_trial" (daily Daily Stampede goal) always gets its own name.
function Menu.goalFor(id)
	local goal = Progression.GoalById[id]
	if id == Menu.TrialGoal then
		return {id=id, kind="daily", name="Finish today's Daily Stampede", target=if goal then goal.target else 1}
	end
	return goal
end

function Menu.signatureThresholds()
	-- Optional Config field added with the signature server patch; defaults until then.
	local custom = Config["SignatureStars"]
	return if type(custom) == "table" and #custom > 0 then custom else Menu.DefaultSignatureStars
end
function Menu.signatureStars(count)
	local stars = 0
	for _, threshold in ipairs(Menu.signatureThresholds()) do
		if number(count) >= threshold then stars += 1 end
	end
	return stars
end
function Menu.starText(stars, total)
	return string.rep("★", stars)..string.rep("☆", math.max(0, total - stars))
end

function Menu.medalWith(score, medals)
	medals = if type(medals) == "table" then medals else Config.Medals
	score = number(score)
	for _, name in ipairs({"Radiant", "Gold", "Silver", "Bronze"}) do
		local threshold = medals[name]
		if type(threshold) == "number" and score >= threshold then return name end
	end
	return "Unranked"
end

-- Volume step on the server's 0.05 grid, clamped to 0..1.
function Menu.stepVolume(value, direction)
	local stepped = number(value) + (if direction < 0 then -Menu.VolumeStep else Menu.VolumeStep)
	return math.clamp(math.floor(stepped * 20 + 0.5) / 20, 0, 1)
end

-- The one active title tag: a rank title (profile.cosmetics.title) or an achievement
-- title (profile.style.title). The server keeps them exclusive.
function Menu.activeTitle(p)
	if type(p) ~= "table" then return nil end
	local rankText = Cosmetics.titleText(p)
	if rankText ~= "" then return {kind="rank", id=p.cosmetics.title, name=rankText} end
	if type(p.style) == "table" and type(p.achievements) == "table" then
		local text = Progression.titleText(p)
		if text ~= "" then return {kind="achievement", id=p.style.title, name=text} end
	end
	return nil
end

-- Status line and button text for one style entry (trail, cosmetic or title).
-- action: "none" (equipped), "equip", "buy" or "locked" (hint says why).
function Menu.itemStatus(p, rank, item, unlocked, equipped)
	if equipped then return {status="EQUIPPED", button="EQUIPPED", action="none"} end
	if unlocked then return {status="OWNED (tap to equip)", button="EQUIP", action="equip"} end
	if item.achievement then
		local achievement = Progression.AchievementById[item.achievement]
		local name = if achievement then achievement.name else tostring(item.achievement)
		return {status="ACHIEVEMENT: "..name, button="LOCKED • ACHIEVEMENT", action="locked",
			hint=if achievement then name..": "..achievement.description else "Earn "..name}
	end
	if item.price then
		if item.rank and rank < item.rank then
			return {status="RANK "..item.rank.." • "..item.price.." glow", button="RANK "..item.rank.." • "..item.price.." GLOW",
				action="locked", hint="Reach rank "..item.rank.." first"}
		end
		local coins = math.floor(number(field(p, "coins")))
		if coins >= item.price then
			return {status=item.price.." glow • fixed price", button="BUY • "..item.price.." GLOW", action="buy"}
		end
		return {status=item.price.." glow • you have "..coins, button="NEED "..(item.price - coins).." MORE GLOW",
			action="locked", hint="Collect "..(item.price - coins).." more glow"}
	end
	if item.rank then
		return {status="FREE AT RANK "..item.rank, button="FREE AT RANK "..item.rank, action="locked",
			hint="Reach rank "..item.rank.." to unlock"}
	end
	return {status="Locked", button="LOCKED", action="locked", hint="Keep playing to unlock"}
end

-- Things worth a look, per tab: keys prefixed "claim:" always badge; other keys
-- badge until the tab is opened while they exist (see Menu.badgesFrom).
function Menu.attention(data)
	local keys = {}
	for _, tab in ipairs(Menu.Tabs) do keys[tab] = {} end
	local p = field(data, "profile")
	if type(p) ~= "table" then return keys end
	local rank = Menu.rankOf(data)
	local claim = Menu.ClaimPrefix
	if type(p.quests) == "table" and type(p.album) == "table" and type(p.mastery) == "table" and type(p.mastery.bestByBiome) == "table" then
		for _, quest in ipairs(Config.Quests) do
			if not p.quests[quest.id] and Profile.questProgress(p, quest) >= quest.target then
				keys.Goals[claim.."quest:"..quest.id] = true
			end
		end
	end
	for _, block in ipairs({p.daily, p.weekly}) do
		if type(block) == "table" and type(block.goals) == "table" then
			for _, id in ipairs(block.goals) do
				local goal = Menu.goalFor(id)
				if goal and not field(block.claimed, id) and number(field(block.progress, id)) >= goal.target then
					keys.Goals[claim.."goal:"..id] = true
				end
			end
		end
	end
	local coins = number(p.coins)
	for key, upgrade in pairs(Config.Upgrades) do
		local level = number(field(p.upgrades, key))
		local price = upgrade.costs[level + 1]
		if price and coins >= price then keys.Upgrades["buy:"..key..":"..level] = true end
	end
	for _, id in ipairs(Menu.affordableStyles(p, rank)) do keys.Style["buy:"..id] = true end
	for _, trail in ipairs(Progression.Trails) do
		if trail.id ~= "none" and not trail.price and Menu.trailUnlocked(p, trail) then keys.Style["own:"..trail.id] = true end
	end
	for _, item in ipairs(Cosmetics.Items) do
		if not item.default and not item.price and Cosmetics.isUnlocked(p, item) then keys.Style["own:"..item.id] = true end
	end
	for _, perk in ipairs(Loadout.Perks) do
		if rank >= perk.rank then keys.Play["perk:"..perk.id] = true end
	end
	local trial = field(data, "trial")
	if type(trial) == "table" and trial.available == true and trial.rewardedToday ~= true and trial.active ~= true then
		keys.Play["trial:"..tostring(trial.day)] = true
	end
	for _, def in ipairs(Config.Creatures) do
		if number(field(p.album, def.id)) > 0 then keys.Album["species:"..def.id] = true end
		local stars = Menu.signatureStars(field(p.signatures, def.id))
		if stars > 0 then keys.Album["star:"..def.id..":"..stars] = true end
	end
	return keys
end

-- seen[tab]: nil = revealed but never opened (NEW); true or a key set = opened, and
-- keys in the set were already on show then. Returns {tab=true} for visible tabs only.
function Menu.badgesFrom(keys, visibleList, seen)
	seen = if type(seen) == "table" then seen else {}
	local result = {}
	for _, tab in ipairs(visibleList) do
		local acknowledged = seen[tab]
		local badge = acknowledged == nil
		if not badge then
			for key in pairs(keys[tab] or {}) do
				if string.sub(key, 1, #Menu.ClaimPrefix) == Menu.ClaimPrefix or type(acknowledged) ~= "table" or not acknowledged[key] then
					badge = true
					break
				end
			end
		end
		if badge then result[tab] = true end
	end
	return result
end
function Menu.badges(data, seen)
	return Menu.badgesFrom(Menu.attention(data), Menu.visibleTabs(data), seen)
end

local function tally(t)
	local n, total = 0, 0
	if type(t) == "table" then
		for _, value in pairs(t) do
			n += 1
			if type(value) == "number" then total += value elseif value == true then total += 1 end
		end
	end
	return n..":"..total
end
local function goalDigest(block)
	if type(block) ~= "table" or type(block.goals) ~= "table" then return "" end
	local parts = {}
	for _, id in ipairs(block.goals) do
		table.insert(parts, tostring(id).."="..number(field(block.progress, id))..(if field(block.claimed, id) then "c" else ""))
	end
	return table.concat(parts, ",")
end

-- Everything the menu draws or reveals from, minus per-tick counters (rally/round
-- clocks), so open panels rebuild only when something they show changed.
function Menu.fingerprint(data)
	local p = field(data, "profile")
	if type(p) ~= "table" then return "" end
	local parts = {tostring(data.profileRevision), tostring(data.phase), tostring(data.mode), tostring(data.biome),
		tostring(data.heatUnlocked), tostring(data.perkSlots), tostring(Menu.rankOf(data)),
		number(p.coins), number(p.rounds), number(p.xp), number(p.totalBanked), number(p.heat)}
	table.insert(parts, if type(p.loadout) == "table" then table.concat(p.loadout, ",") else "")
	for key in pairs(Config.Upgrades) do table.insert(parts, number(field(p.upgrades, key))) end
	local style, cosmetics = field(p, "style"), field(p, "cosmetics")
	table.insert(parts, tostring(field(style, "trail")).."/"..tostring(field(style, "title")).."/"..tally(field(style, "owned")))
	table.insert(parts, tostring(field(cosmetics, "formation")).."/"..tostring(field(cosmetics, "burst")).."/"
		..tostring(field(cosmetics, "tag")).."/"..tostring(field(cosmetics, "title")).."/"..tally(field(cosmetics, "owned")))
	for _, key in ipairs(Menu.SettingKeys) do table.insert(parts, tostring(field(p.settings, key))) end
	table.insert(parts, tally(p.signatures))
	table.insert(parts, tally(p.album)); table.insert(parts, tally(p.gilded)); table.insert(parts, tally(p.mutations))
	table.insert(parts, tally(p.quests)); table.insert(parts, tally(p.achievements))
	local mastery = field(p, "mastery")
	table.insert(parts, number(field(mastery, "bestChain")).."/"..number(field(mastery, "precision")).."/"
		..number(field(mastery, "dashCatches")).."/"..number(field(mastery, "completed")))
	local daily, weekly = field(p, "daily"), field(p, "weekly")
	table.insert(parts, tostring(field(daily, "day")).."/"..tostring(field(daily, "rerolled")).."/"..tostring(field(daily, "bonus"))
		.."/"..goalDigest(daily))
	table.insert(parts, tostring(field(weekly, "week")).."/"..goalDigest(weekly))
	table.insert(parts, tostring(Menu.hasRecord(p)))
	local remix = field(data, "remix")
	if type(remix) == "table" then table.insert(parts, "remix:"..tostring(remix.id)) end
	local trial = field(data, "trial")
	if type(trial) == "table" then
		table.insert(parts, table.concat({tostring(trial.available), tostring(trial.active), tostring(trial.rewardedToday),
			tostring(trial.day), tostring(trial.biome), tostring(trial.encounter), tostring(trial.reason),
			number(trial.best), number(trial.runsToday), number(trial.xpRunsLeft)}, "/"))
		local board = {}
		if type(trial.board) == "table" then
			for index = 1, math.min(#trial.board, 10) do
				local entry = trial.board[index]
				table.insert(board, tostring(field(entry, "userId")).."="..number(field(entry, "score")))
			end
		end
		table.insert(parts, #board..":"..table.concat(board, ","))
	else
		table.insert(parts, "notrial")
	end
	return table.concat(parts, "|")
end
-- END PURE MENU

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

Menu.StyleCategories = {
	{id="trail", label="Trails"}, {id="formation", label="Formations"}, {id="burst", label="Bursts"},
	{id="tag", label="Name Tags"}, {id="title", label="Titles"},
}
local DEFAULT_SETTINGS = Profile.new().settings
local CENTER = UDim2.fromScale(.5, .5)
local OPEN_TWEEN = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GREEN, RED = Color3.fromRGB(40,140,96), Color3.fromRGB(176,70,70)
local TRIAL_CARD = Color3.fromRGB(255,246,214)

-- ctx: gui, data()->latest(with cached profile), fire(action,payload), miniature(id,parent),
-- controllerActive()->bool, onChanged(), toast(text). Optional: boards() (unused since
-- D16), photoMode() hides the HUD, inviteFriends() opens the invite prompt (no reward),
-- onBadgeChanged(hasBadge) fires when the "!" state flips (also menu.hasBadge()).
function Menu.new(ctx)
	local self = {selected=nil, tabButtons={}, tabBadges={}, styleCategory="trail",
		visible={Album=true, Settings=true}, visibleList={"Album", "Settings"}, revealed={}, seen=nil, badgeSet={},
		panelWidth=640, rendered="", liveFingerprint=nil, rerollArmed=nil}
	local me = Players.LocalPlayer
	local shade = make("Frame", ctx.gui, {Name="Overlay", Size=UDim2.fromScale(1,1), BackgroundColor3=palette.ink,
		BackgroundTransparency=.3, Visible=false, ZIndex=5})
	local panel = make("Frame", shade, {Name="Panel", AnchorPoint=Vector2.new(.5,.5), Position=CENTER,
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
	local openTween = nil
	local function data() return ctx.data() end
	local function reducedMotion()
		local d = data()
		return field(field(field(d, "profile"), "settings"), "reducedMotion") == true
	end
	local function popIn()
		if openTween then openTween:Cancel(); openTween = nil end
		if reducedMotion() then panel.Position = CENTER; return end
		panel.Position = CENTER + UDim2.fromOffset(0, 14)
		openTween = TweenService:Create(panel, OPEN_TWEEN, {Position=CENTER})
		openTween:Play()
	end

	-- Tab strip: only revealed tabs, reflowed; gamepad left/right wraps over them.
	local function layoutTabs()
		local list = self.visibleList
		local geometry = Menu.tabGeometry(self.panelWidth - 32, math.max(1, #list))
		for _, name in ipairs(Menu.Tabs) do self.tabButtons[name].Visible = self.visible[name] == true end
		for index, name in ipairs(list) do
			local b = self.tabButtons[name]
			b.Position = UDim2.fromOffset((index-1) * geometry.width, 0)
			b.Size = UDim2.fromOffset(geometry.width - 4, 34)
			b.NextSelectionLeft = self.tabButtons[list[(index-2) % #list + 1]]
			b.NextSelectionRight = self.tabButtons[list[index % #list + 1]]
			b.NextSelectionUp = close
		end
		tabs.CanvasSize = UDim2.fromOffset(geometry.canvas, 0)
		local anchor = self.tabButtons[self.selected or list[1]] or self.tabButtons.Album
		close.NextSelectionDown = anchor
		content.NextSelectionUp = anchor
	end

	local function updateBadges(keys)
		local set = Menu.badgesFrom(keys, self.visibleList, self.seen)
		for name, badge in pairs(self.tabBadges) do badge.Visible = set[name] == true end
		local had = next(self.badgeSet) ~= nil
		self.badgeSet = set
		local has = next(set) ~= nil
		if has ~= had and ctx.onBadgeChanged then ctx.onBadgeChanged(has) end
	end

	-- Reveals stick for the session so a purchase never makes a tab vanish again.
	local function refreshTabs(d)
		if not d or type(d.profile) ~= "table" then return end
		for _, name in ipairs(Menu.visibleTabs(d)) do self.revealed[name] = true end
		local list = {}
		for _, name in ipairs(Menu.Tabs) do
			if self.revealed[name] or name == "Album" or name == "Settings" then table.insert(list, name) end
		end
		local changed = table.concat(list, ",") ~= table.concat(self.visibleList, ",")
		self.visibleList = list
		self.visible = {}
		for _, name in ipairs(list) do self.visible[name] = true end
		if changed then layoutTabs() end
		local keys = Menu.attention(d)
		if self.seen == nil then
			-- Session baseline: what already exists at join is not "new" (claims still badge).
			self.seen = {}
			for _, name in ipairs(list) do self.seen[name] = keys[name] end
		end
		if self.selected and self.visible[self.selected] then self.seen[self.selected] = keys[self.selected] end
		updateBadges(keys)
	end

	function self.isOpen() return self.selected ~= nil end
	function self.hasBadge() return next(self.badgeSet) ~= nil end
	function self.badges() return table.clone(self.badgeSet) end
	function self.visibleTabs() return table.clone(self.visibleList) end
	function self.open(name)
		if name then
			refreshTabs(data())
			if not self.visible[name] then name = "Album" end
		end
		local wasOpen = self.selected ~= nil
		self.selected = name
		shade.Visible = name ~= nil
		if name then
			self.render()
			local b = self.tabButtons[name]
			if b and tabs.AbsoluteCanvasSize.X > tabs.AbsoluteSize.X then
				tabs.CanvasPosition = Vector2.new(math.max(0, b.Position.X.Offset - 40), 0)
			end
			if not wasOpen then popIn() end
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
		-- "!" is text, not colour alone.
		local badge = make("TextLabel", b, {Name="Badge", Text="!", TextSize=12, Font=Enum.Font.GothamBlack, TextColor3=palette.ink,
			BackgroundColor3=palette.warm, BorderSizePixel=0, Position=UDim2.new(1,-19,0,2), Size=UDim2.fromOffset(16,16),
			Visible=false, ZIndex=9})
		round(badge, 8)
		self.tabButtons[name] = b
		self.tabBadges[name] = badge
	end
	layoutTabs()

	function self.resize(width, height)
		local w = math.min(640, math.max(240, width - 24))
		self.panelWidth = w
		panel.Size = UDim2.fromOffset(w, math.min(560, math.max(200, height - 64)))
		layoutTabs()
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
	local function rowButton(r, text, y, color, callback, name, height)
		local b = button(r, text, UDim2.fromOffset(14,y), UDim2.new(1,-28,0,height or 38), color or palette.gold, callback)
		b.ZIndex = 9; b.Name = name or "ActionButton"
		b.TextScaled = true; make("UITextSizeConstraint", b, {MinTextSize=10, MaxTextSize=17})
		return b
	end
	local function header(text, name)
		local r = make("TextLabel", content, {Name=name or "Header", Text=text, TextSize=15, Font=Enum.Font.GothamBlack,
			BackgroundTransparency=1, TextColor3=palette.purple, Size=UDim2.new(1,-6,0,26), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=8})
		return r
	end
	local function note(text, name, height)
		local r = row(height or 44, name)
		local t = rowText(r, text, 13, 8)
		t.Size = UDim2.new(1,-28,0,(height or 44) - 12)
		return r
	end
	local function progressBar(r, y, fraction, fill)
		local frame = Ui.bar(r, "Progress", UDim2.fromOffset(14,y), UDim2.new(1,-28,0,8), Color3.fromRGB(210,212,236), fill or palette.mint)
		frame.ZIndex = 9; frame.Fill.ZIndex = 10
		frame.Fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		return frame
	end
	local function playing() local d = data(); return d ~= nil and d.phase == "Playing" end
	local function inTrial(d) return field(d, "mode") == "trial" or field(field(d, "trial"), "active") == true end
	local function setting(p, key)
		local value = field(p.settings, key)
		if value == nil then value = DEFAULT_SETTINGS[key] end
		return value
	end
	local function trialMedals(trial)
		local medals = field(trial, "medals")
		return if type(medals) == "table" then medals else Trial.Medals
	end
	local function bestLine(trial)
		local best = math.floor(number(field(trial, "best")))
		local medals = trialMedals(trial)
		if best <= 0 then return "No finish yet today • Bronze at "..number(medals.Bronze), "Unranked" end
		local medal = Menu.medalWith(best, medals)
		return "Your best today: "..best.." ("..medal..")", medal
	end
	-- Today's Daily Stampede board (the only public leaderboard, decision D16).
	local function dailyBoard(trial, name)
		local board = if type(field(trial, "board")) == "table" then trial.board else {}
		local entries = {}
		for index = 1, math.min(#board, 10) do
			if type(board[index]) == "table" then table.insert(entries, board[index]) end
		end
		local list = row(if #entries == 0 then 64 else 38 + #entries * 24, name)
		rowText(list, "TODAY'S DAILY STAMPEDE — TOP 10", 14, 6, palette.purple)
		if #entries == 0 then
			rowText(list, "No runs yet today — be the first!", 13, 32)
		else
			for index, entry in ipairs(entries) do
				local mine = me ~= nil and entry.userId == me.UserId
				local line = rowText(list, "#"..tostring(entry.rank or index).."  "..tostring(entry.name or "Player").."  •  "
					..tostring(entry.score or 0)..(if mine then "  (you)" else ""), 13, 32 + (index-1) * 24, if mine then palette.purple else palette.ink)
				if mine then line.Font = Enum.Font.GothamBlack end
			end
		end
		return list
	end

	local renderers = {}
	local function trialCard(d)
		local trial = if type(d.trial) == "table" then d.trial else {}
		local active = inTrial(d)
		local card = row(178, "DailyStampede")
		card.BackgroundColor3 = TRIAL_CARD
		local heading = rowText(card, "DAILY STAMPEDE", 19, 6)
		heading.Font = Enum.Font.GothamBlack
		local text, medal = bestLine(trial)
		if medal ~= "Unranked" then
			heading.Size = UDim2.new(1,-128,0,33)
			local pill = label(card, Ui.medals[medal].label, 12, UDim2.new(1,-108,0,10), UDim2.fromOffset(94,24))
			pill.Name = "Medal"; pill.ZIndex = 9; pill.BackgroundTransparency = 0; pill.BackgroundColor3 = Ui.medals[medal].color
			pill.TextXAlignment = Enum.TextXAlignment.Center
			round(pill, 12)
		end
		local biome = Config.Biomes[number(trial.biome)]
		local encounter = Menu.EncounterNames[trial.encounter]
		rowText(card, (if biome then biome.name else "Trial Grounds")..(if encounter then " • "..encounter else "")
			.." • "..Trial.RunSeconds.."s solo run", 14, 34)
		rowText(card, "Same course for everyone today • upgrades and perks don't count", 12, 56, palette.purple)
		local runs = math.floor(number(trial.runsToday))
		rowText(card, text..(if runs > 0 then " • runs today: "..runs else ""), 14, 78)
		local left = if type(trial.xpRunsLeft) == "number" then trial.xpRunsLeft else math.max(0, Trial.XpRunsPerDay - runs)
		rowText(card, if trial.rewardedToday == true then "Today's reward claimed • XP runs left: "..math.floor(number(left))
			else "First finish today: +"..Trial.FirstRunGlow.." glow • +"..Trial.FirstRunXp.." XP", 12, 100,
			if trial.rewardedToday == true then palette.purple else GREEN)
		local available = trial.available == true
		local reason = if type(trial.reason) == "string" and trial.reason ~= "" then trial.reason else "Not available right now"
		local start = rowButton(card, if active then "LEAVE RUN" elseif available then "START" else reason, 124,
			if active then palette.warm elseif available then palette.gold else palette.muted, function()
				if active then ctx.fire("Trial", "leave"); self.open(nil)
				elseif available then ctx.fire("Trial", "start"); self.open(nil)
				else ctx.toast(reason) end
			end, "TrialButton", 46)
		start.AutoButtonColor = active or available
		if type(d.trial) == "table" then dailyBoard(trial, "DailyBoard") end
	end

	renderers.Play = function(d, p)
		local trialMode = inTrial(d)
		-- Weekly Remix (plan §6.9.3): this week's server-wide modifier and when it changes.
		local remix = field(d, "remix")
		if type(remix) == "table" and type(remix.name) == "string" then
			local card = row(70, "WeeklyRemix")
			local heading = rowText(card, "THIS WEEK'S REMIX • "..string.upper(remix.name), 15, 6)
			heading.Font = Enum.Font.GothamBlack
			local days = math.floor(number(remix.endsIn) / 86400)
			rowText(card, tostring(remix.description or "")..(if days >= 1 then " • "..days.."d left" else " • ends today"), 13, 36, palette.purple)
		end
		if type(d.trial) == "table" or trialMode then trialCard(d) end
		local noteRow = row(56, "RoundSetup")
		rowText(noteRow, if trialMode then "Daily Stampede run • finish or leave to change your setup"
			elseif playing() then "Round in progress • Perks and Heat lock until results"
			else "Set up your next round, then CHASE AGAIN", 14, 6)
		rowText(noteRow, "Rank "..(Ui.get(d,"rank","rank") or 1).." • Perk slots "..(d.perkSlots or 0).." • Heat unlocked "..(d.heatUnlocked or 0), 12, 30, palette.purple)
		local locked = "Finish or leave the Daily Stampede first"
		header("ARENAS")
		if trialMode then
			note(locked, "ArenasLocked")
		else
			for index, biome in ipairs(Config.Biomes) do
				local unlocked = p.totalBanked >= biome.unlock
				local r = row(118, "Arena_"..biome.id); rowText(r, biome.name, 19, 6); rowText(r, biome.description, 13, 34)
				rowButton(r, if unlocked then (if d.biome == index then "YOU ARE HERE" else "TRAVEL") else "Bank "..biome.unlock.." Sparks to unlock",
					72, Color3.fromRGB(table.unpack(biome.accent)), function()
						if unlocked then ctx.fire("Biome", index); self.open(nil) end
					end, "TravelButton")
			end
		end
		header("HEAT • optional difficulty")
		local heatUnlocked, current = d.heatUnlocked or 0, p.heat or 0
		if trialMode then
			note(locked, "HeatLocked")
		else
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
		end
		local slots = d.perkSlots or 0
		local equipped = p.loadout or {}
		header("PERKS • "..#equipped.." / "..slots.." equipped")
		if trialMode then
			note(locked, "PerksLocked")
			return
		end
		if slots == 0 then
			local r = row(44, "PerksLocked"); rowText(r, "Finish your first round (Rank 2) to unlock perks", 13, 8)
		end
		local rank = Ui.get(d, "rank", "rank") or 1
		for _, perk in ipairs(Loadout.Perks) do
			local on = table.find(equipped, perk.id) ~= nil
			local r = row(122, "Perk_"..perk.id)
			rowText(r, perk.name..(if on then "  •  EQUIPPED" else ""), 17, 5, if on then palette.purple else palette.ink)
			rowText(r, "+ "..perk.up, 13, 31, GREEN)
			rowText(r, "- "..perk.down, 13, 51, RED)
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

	local function goalRows(block, kindLabel, glow, canReroll)
		local goals = block and block.goals or {}
		if #goals == 0 then
			local r = row(44, kindLabel.."Pending"); rowText(r, "Start a round to reveal "..string.lower(kindLabel).." goals", 13, 8)
			return
		end
		for _, id in ipairs(goals) do
			local goal = Menu.goalFor(id)
			if goal then
				local target = math.max(1, goal.target)
				local progress = math.min(target, tonumber(block.progress and block.progress[id]) or 0)
				local claimed = block.claimed and block.claimed[id]
				local complete = progress >= target
				local rerollable = canReroll and id ~= Menu.TrialGoal and not claimed and not complete
				local r = row(110, "Goal_"..id)
				rowText(r, goal.name, 16, 5)
				rowText(r, progress.." / "..target..(if goal.scope == "round" then " in one round" else ""), 12, 28, palette.purple)
				progressBar(r, 48, progress / target)
				local claim = rowButton(r, if claimed then "CLAIMED" elseif complete then "CLAIM "..glow.." GLOW" else "Reward: "..glow.." glow",
					58, if complete and not claimed then palette.gold else palette.mint, function() ctx.fire("Goal", id) end, "ClaimButton", 44)
				if rerollable then
					claim.Size = UDim2.new(1,-142,0,44)
					local armed = self.rerollArmed == id
					local reroll = button(r, if armed then "SURE?" else "REROLL", UDim2.new(1,-122,0,58), UDim2.fromOffset(108,44),
						if armed then palette.warm else palette.paper, function()
							if self.rerollArmed == id then
								self.rerollArmed = nil
								ctx.fire("Reroll", id)
								return
							end
							self.rerollArmed = id
							ctx.toast("Tap again to swap this goal • one free reroll per day")
							self.render()
							task.delay(4, function()
								if self.rerollArmed == id then
									self.rerollArmed = nil
									if self.selected == "Goals" then self.render() end
								end
							end)
						end)
					reroll.Name = "RerollButton"; reroll.ZIndex = 9; reroll.TextSize = 15
				end
			end
		end
	end
	renderers.Goals = function(d, p)
		local canReroll = type(p.daily) == "table" and p.daily.rerolled ~= true
		header(if canReroll then "DAILY SPARKS • new each UTC day • 1 free reroll" else "DAILY SPARKS • new set each UTC day • no streaks")
		goalRows(p.daily, "Daily", Progression.DailyGlow, canReroll)
		if p.daily and p.daily.bonus then local r = row(36, "DailyBonus"); rowText(r, "Daily set bonus collected!", 13, 6) end
		header("WEEKLY SPARKS • resets Monday UTC")
		goalRows(p.weekly, "Weekly", Progression.WeeklyGlow, false)
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
		local active = Menu.activeTitle(p)
		for _, a in ipairs(Progression.Achievements) do
			local has = p.achievements and p.achievements[a.id] == true
			local r = row(if a.title and has then 108 else 66, "Achievement_"..a.id)
			rowText(r, (if has then "★ " else "☆ ")..a.name.."  •  +"..a.xp.." XP", 15, 5, if has then palette.purple else palette.ink)
			rowText(r, a.description..(if a.title then "  •  Title: "..a.title else ""), 12, 30)
			if a.title and has then
				local wearing = active ~= nil and active.kind == "achievement" and active.id == a.id
				rowButton(r, if wearing then "WEARING • tap to remove" else "WEAR TITLE", 62, if wearing then palette.paper else palette.gold,
					function() ctx.fire("Title", if wearing then "" else a.id) end, "TitleButton")
			end
		end
	end

	renderers.Album = function(_, p)
		local thresholds = Menu.signatureThresholds()
		local signatures = if type(p.signatures) == "table" then p.signatures else {}
		local anySignature, totalStars = false, 0
		for _, def in ipairs(Config.Creatures) do
			if def.signature ~= nil then anySignature = true end
			totalStars += Menu.signatureStars(signatures[def.id])
		end
		local intro = row(if anySignature then 102 else 80, "CollectionSummary")
		rowText(intro, Profile.speciesCount(p).." / "..#Config.Creatures.." discovered • Your collection stays with you", 15, 4)
		local tiers = {}
		for _, mutation in ipairs(Config.Mutations) do table.insert(tiers, mutation.threshold.." → "..mutation.name) end
		local gildedCount = 0
		for _, def in ipairs(Config.Creatures) do if p.gilded and p.gilded[def.id] then gildedCount += 1 end end
		rowText(intro, table.concat(tiers, "  •  ").."  •  Gilded "..gildedCount.." / "..#Config.Creatures, 13, 44)
		if anySignature then
			rowText(intro, "Signature stars "..totalStars.." / "..(#thresholds * #Config.Creatures).." • catch each Spark its own way", 12, 72, palette.purple)
		end
		for _, def in ipairs(Config.Creatures) do
			local count = p.album[def.id] or 0
			local signature = def.signature
			local signatureCount = math.floor(number(signatures[def.id]))
			local showSignature = signature ~= nil or signatureCount > 0
			local r = row(if showSignature then 154 else 108, "Album_"..def.id)
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
			if showSignature then
				local hint = if signature then Menu.SignatureHints[signature] else nil
				local technique = label(r, "◆ "..(if signature then tostring(signature) else "SIGNATURE")..(if hint then " • "..hint else ""),
					12, UDim2.fromOffset(110,98), UDim2.new(1,-122,0,28))
				technique.Name = "Signature"; technique.ZIndex = 9
				local stars = Menu.signatureStars(signatureCount)
				local nextThreshold = thresholds[stars + 1]
				local starLine = label(r, Menu.starText(stars, #thresholds).."  Signature catches: "..signatureCount
					..(if nextThreshold then " • next ★ at "..nextThreshold else " • all stars!"), 12, UDim2.fromOffset(110,126),
					UDim2.new(1,-122,0,22), palette.purple)
				starLine.Name = "SignatureStars"; starLine.ZIndex = 9
			end
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

	-- Style ------------------------------------------------------------------------
	local function swatches(r, colors)
		local n = math.min(#colors, 4)
		for index = 1, n do
			local swatch = make("Frame", r, {Name="Swatch"..index, Position=UDim2.new(1, -14 - (n - index + 1) * 28, 0, 10),
				Size=UDim2.fromOffset(24,24), BackgroundColor3=Color3.fromRGB(table.unpack(colors[index])), BorderSizePixel=0, ZIndex=9})
			round(swatch, 12)
		end
		return n * 28 + 8
	end
	local function tagPreview(r, item)
		local framed = type(item.frame) == "table"
		local preview = make("TextLabel", r, {Name="TagPreview", Text=if me then me.DisplayName else "Sparky", TextScaled=true,
			Font=Enum.Font.GothamBlack, TextColor3=Color3.fromRGB(table.unpack(item.text)), TextStrokeColor3=Color3.fromRGB(table.unpack(item.stroke)),
			TextStrokeTransparency=0, BackgroundColor3=if framed then Color3.fromRGB(table.unpack(item.frame)) else palette.ink,
			BackgroundTransparency=if framed then (item.frameTransparency or 0.4) else 0.2, BorderSizePixel=0,
			Position=UDim2.new(1,-138,0,8), Size=UDim2.fromOffset(124,28), ZIndex=9})
		round(preview, 8)
		make("UITextSizeConstraint", preview, {MinTextSize=10, MaxTextSize=18})
		return 132
	end
	local function styleRow(rowName, item, unlocked, equipped, rank, p, press, description, decorate)
		local info = Menu.itemStatus(p, rank, item, unlocked, equipped)
		local height = if description then 138 else 108
		local r = row(height, rowName)
		local reserved = if decorate then decorate(r) else 0
		local nameLabel = rowText(r, item.name..(if equipped then "  •  EQUIPPED" else ""), 17, 6, if equipped then palette.purple else palette.ink)
		nameLabel.Size = UDim2.new(1, -28 - reserved, 0, 31)
		local statusLabel = rowText(r, info.status, 12, 34, palette.purple)
		statusLabel.Size = UDim2.new(1, -28 - reserved, 0, 22)
		if description then
			local t = rowText(r, description, 12, 56)
			t.Size = UDim2.new(1,-28,0,28)
		end
		rowButton(r, info.button, height - 52, if info.action == "none" then palette.paper elseif info.action == "locked" then palette.muted else palette.gold,
			function()
				if info.action == "none" then return end
				if info.action == "locked" then ctx.toast(info.hint or info.status); return end
				press()
			end, "StyleButton", 44)
		return r
	end

	renderers.Style = function(d, p)
		local style = if type(p.style) == "table" then p.style else {trail="none", title="", owned={}}
		local cosmetics = if type(p.cosmetics) == "table" then p.cosmetics else {}
		local rank = Menu.rankOf(d)
		local active = Menu.activeTitle(p)
		local function current(category) return Cosmetics.resolve(category, cosmetics[category]) end
		local summary = row(84, "StyleSummary")
		rowText(summary, "Trail: "..((Progression.TrailById[style.trail] or {name="None"}).name).."  •  Formation: "
			..((current("formation") or {name="None"}).name), 14, 6)
		rowText(summary, "Burst: "..((current("burst") or {name="None"}).name).."  •  Tag: "..((current("tag") or {name="None"}).name)
			.."  •  Title: "..(if active then active.name else "None"), 14, 30)
		rowText(summary, "Everything is earned or bought with glow at a fixed price. Nothing random.", 12, 56, palette.purple)

		-- Category sub-tabs: one row when wide, 3 + 2 when narrow.
		local wide = self.panelWidth >= 500
		local picker = row(if wide then 56 else 106, "StyleCategories")
		for index, category in ipairs(Menu.StyleCategories) do
			local perRow = if wide then #Menu.StyleCategories elseif index <= 3 then 3 else 2
			local column = if wide or index <= 3 then index - 1 else index - 4
			local y = if wide or index <= 3 then 6 else 56
			local on = self.styleCategory == category.id
			local chip = button(picker, category.label, UDim2.new(column / perRow, 6, 0, y), UDim2.new(1 / perRow, -10, 0, 44),
				if on then palette.gold else palette.mint, function()
					if self.styleCategory == category.id then return end
					self.styleCategory = category.id
					self.render()
				end)
			chip.Name = "Category_"..category.id; chip.ZIndex = 9; chip.TextScaled = true
			make("UITextSizeConstraint", chip, {MinTextSize=9, MaxTextSize=15})
		end

		local category = self.styleCategory
		if category == "trail" then
			header("TRAILS • follow you as you run")
			for _, trail in ipairs(Progression.Trails) do
				styleRow("Trail_"..trail.id, trail, Menu.trailUnlocked(p, trail), style.trail == trail.id, rank, p,
					function() ctx.fire("Style", trail.id) end, nil, function(r) return swatches(r, trail.colors) end)
			end
		elseif category == "title" then
			header("TITLES • one tag above your head")
			local none = row(98, "Title_none")
			rowText(none, "No title"..(if active == nil then "  •  EQUIPPED" else ""), 17, 6, if active == nil then palette.purple else palette.ink)
			rowText(none, "Hide your title tag", 12, 34, palette.purple)
			rowButton(none, if active == nil then "EQUIPPED" else "WEAR NO TITLE", 46, if active == nil then palette.paper else palette.gold, function()
				if active == nil then return end
				-- Clear through the channel that set it (Style "" clears rank titles; Title "" achievement titles).
				if active.kind == "achievement" then ctx.fire("Title", "") else ctx.fire("Style", {category="title", id=""}) end
			end, "StyleButton", 44)
			header("RANK TITLES • free as you rank up")
			for _, item in ipairs(Cosmetics.RankTitles) do
				local equipped = active ~= nil and active.kind == "rank" and active.id == item.id
				styleRow("Title_"..item.id, item, Cosmetics.isUnlocked(p, item), equipped, rank, p,
					function() ctx.fire("Style", {category="title", id=item.id}) end)
			end
			header("ACHIEVEMENT TITLES • earned in play")
			for _, a in ipairs(Progression.Achievements) do
				if a.title then
					local equipped = active ~= nil and active.kind == "achievement" and active.id == a.id
					local unlocked = type(p.achievements) == "table" and p.achievements[a.id] == true
					styleRow("AchievementTitle_"..a.id, {id=a.id, name=a.title, achievement=a.id}, unlocked, equipped, rank, p,
						function() ctx.fire("Title", a.id) end, "From "..a.name..": "..a.description)
				end
			end
		else
			local labels = {formation="FORMATIONS • how your carried Sparks follow you", burst="BANK BURSTS • the pop everyone sees when you bank",
				tag="NAME TAGS • your name above your head"}
			header(labels[category] or string.upper(category))
			local equippedItem = current(category)
			for _, item in ipairs(Cosmetics.ByCategory[category] or {}) do
				local decorate = nil
				if category == "burst" then decorate = function(r) return swatches(r, item.colors) end
				elseif category == "tag" then decorate = function(r) return tagPreview(r, item) end end
				local prefix = if category == "formation" then "Formation_" elseif category == "burst" then "Burst_" else "Tag_"
				styleRow(prefix..item.id, item, Cosmetics.isUnlocked(p, item), equippedItem ~= nil and equippedItem.id == item.id, rank, p,
					function() ctx.fire("Style", {category=category, id=item.id}) end, item.description, decorate)
			end
		end
	end

	renderers.Records = function(d, p)
		local trial = if type(d.trial) == "table" then d.trial else nil
		if trial then
			local text, medal = bestLine(trial)
			local best = row(44, "DailyBest")
			rowText(best, text, 14, 8, if medal ~= "Unranked" then palette.purple else palette.ink)
			dailyBoard(trial, "DailyBoard")
		else
			note("Today's Daily Stampede board appears here once it opens", "DailyPending")
		end
		header("Your records (full rounds only)", "RecordsHeader")
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
		note("Records are personal. The Daily Stampede top 10 is the only public board.", "RecordsNote", 40)
	end

	renderers.Settings = function(d, p)
		local function toggle(key, text)
			local on = setting(p, key) == true
			local r = row(64, "Setting_"..key)
			local b = button(r, text..": "..(if on then "ON" else "OFF"), UDim2.fromOffset(12,10), UDim2.new(1,-24,0,44),
				if on then palette.mint else palette.paper, function() ctx.fire("Settings", {[key]=not on}) end)
			b.ZIndex = 9; b.Name = "ToggleButton"
		end
		local function volume(key, text)
			local value = math.clamp(number(setting(p, key)), 0, 1)
			local r = row(64, "Setting_"..key)
			local caption = label(r, text..": "..math.floor(value * 100 + 0.5).."%", 15, UDim2.fromOffset(14,10), UDim2.new(1,-150,0,44))
			caption.Name = "Value"; caption.ZIndex = 9
			local function step(direction)
				local nextValue = Menu.stepVolume(value, direction)
				if nextValue == value then return end
				value = nextValue
				caption.Text = text..": "..math.floor(value * 100 + 0.5).."%"
				ctx.fire("Settings", {[key]=value})
			end
			local minus = button(r, "−", UDim2.new(1,-126,0,10), UDim2.fromOffset(54,44), palette.mint, function() step(-1) end)
			minus.Name = "Minus"; minus.ZIndex = 9; minus.TextSize = 24
			local plus = button(r, "+", UDim2.new(1,-66,0,10), UDim2.fromOffset(54,44), palette.mint, function() step(1) end)
			plus.Name = "Plus"; plus.ZIndex = 9; plus.TextSize = 24
		end
		header("COMFORT")
		toggle("reducedMotion", "Reduced motion")
		toggle("highContrast", "High-contrast targets")
		toggle("holdCatch", "Hold to catch")
		local scales = Profile.UiScales
		local currentScale = number(setting(p, "uiScale"))
		local scaleRow = row(102, "Setting_uiScale")
		rowText(scaleRow, "UI scale: "..math.floor(currentScale * 100 + 0.5).."%", 15, 8)
		for index, value in ipairs(scales) do
			local on = math.abs(currentScale - value) < 1e-6
			local percent = math.floor(value * 100 + 0.5)
			local b = button(scaleRow, percent.."%", UDim2.new((index-1)/#scales, 12 - 24*(index-1)/#scales, 0, 46),
				UDim2.new(1/#scales, -24/#scales - 6, 0, 44), if on then palette.gold else palette.mint, function()
					if not on then ctx.fire("Settings", {uiScale=value}) end
				end)
			b.Name = "Scale_"..percent; b.ZIndex = 9; b.TextSize = 16
		end
		header("SOUND")
		toggle("music", "Music")
		volume("musicVolume", "Music volume")
		toggle("sfx", "Sound effects")
		volume("sfxVolume", "SFX volume")
		header("SOCIAL")
		toggle("showOnPodium", "Show me on the podium")
		toggle("competition", "Opt in: session scores")
		if ctx.inviteFriends then
			local invite = row(102, "InviteFriends")
			rowText(invite, "Play together any time • always optional", 13, 8)
			rowButton(invite, "INVITE FRIENDS", 46, palette.sky, function() ctx.inviteFriends() end, "InviteButton", 44)
		end
		local photo = row(108, "PhotoMode")
		local photoText = rowText(photo, "Photo mode: press H (or the button) to hide the HUD", 14, 6)
		photoText.Size = UDim2.new(1,-28,0,40)
		rowButton(photo, "PHOTO MODE", 54, palette.paper, function()
			if ctx.photoMode then self.open(nil); ctx.photoMode() else ctx.toast("Press H to hide the HUD") end
		end, "PhotoButton", 44)
		header("CONTROLS")
		local hold = setting(p, "holdCatch") == true
		local r = row(124, "ControlsHelp"); rowText(r, "Move: WASD / thumbstick • Jump: Space / A", 14, 7)
		rowText(r, if hold then "Catch: hold E / X / CATCH (Hold to catch is on)" else "Catch: E / X / tap CATCH", 14, 34)
		rowText(r, "Dash: Shift / B • Bank: R / Y", 14, 61)
		rowText(r, "Menu: M / Select • Photo: H • All rewards earned in play", 13, 88)
		local help = row(196, "MasteryHelp")
		rowText(help, "Close + facing = PRECISE • Dash THROUGH Sparks to catch several", 13, 7)
		rowText(help, "Chain catches: "..Menu.chainLadder(), 13, 33)
		rowText(help, "Herd Sparks through the SPARK GATE • Dash through the STAMPEDE RUN", 13, 59)
		rowText(help, "Purple statics zap you: dodge, or DASH through to pop them", 13, 85)
		rowText(help, "Zaps scatter carried Sparks • recatch them!", 13, 111)
		rowText(help, "Bank before the BUZZER or carried style bonus is lost", 13, 137)
		rowText(help, "Banked score, glow and collection are always safe", 13, 163)
		if setting(p, "competition") == true then
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
		refreshTabs(d)
		if not self.visible[self.selected] then
			self.selected = "Album"
			refreshTabs(d)
		end
		local p = d.profile
		self.rendered = Menu.fingerprint(d)
		title.Text = string.upper(self.selected).."  •  "..p.coins.." GLOW"
		for name, b in pairs(self.tabButtons) do b.BackgroundColor3 = if name == self.selected then palette.gold else palette.mint end
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
		content.NextSelectionUp = self.tabButtons[self.selected]
		close.NextSelectionDown = self.tabButtons[self.selected]
		if focusedRow and ctx.controllerActive() then
			local replacementRow = content:FindFirstChild(focusedRow)
			GuiService.SelectedObject = (replacementRow and replacementRow:FindFirstChild(focusedName)) or self.tabButtons[self.selected]
		end
	end

	-- Called with every state update: reveals/badges and rebuilds only when the menu
	-- fingerprint changed; otherwise just keeps the rally countdown current without
	-- rebuilding controls or stealing gamepad focus.
	function self.live(d)
		if not d or type(d.profile) ~= "table" then return end
		local fingerprint = Menu.fingerprint(d)
		if fingerprint ~= self.liveFingerprint then
			self.liveFingerprint = fingerprint
			refreshTabs(d)
			if self.selected and not self.visible[self.selected] then self.open("Album"); return end
			if self.selected and fingerprint ~= self.rendered then self.render(); return end
		end
		if self.selected ~= "Goals" or not d.rally then return end
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
