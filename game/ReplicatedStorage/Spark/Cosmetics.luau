-- Social cosmetics (Parade Formations, Bank Bursts, Name Tags, Rank Titles) and the
-- rank-reward table. Pure and shared: the server owns unlocks and glow purchases;
-- clients render formations, bursts and tags from replicated ids. Every price is
-- guaranteed and shown up front; nothing is random, nothing is sold for Robux and no
-- cosmetic changes gameplay. No definition strobes or flashes: bursts are one-shot
-- puffs with bounded count/speed; formations drift slowly and hold perfectly still in
-- reduced motion. Achievement titles stay in Progression; rank titles live here.
local Loadout = if script then require(script.Parent.Loadout) else require("./Loadout")
local Progression = if script then require(script.Parent.Progression) else require("./Progression")
local Cosmetics = {}
local MAX_COINS = 2000000000

local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end

Cosmetics.Categories = {"formation", "burst", "tag", "title"}
-- profile.cosmetics[category] holds the equipped id; title "" means no rank title.
Cosmetics.Defaults = {formation="line", burst="confetti", tag="default", title=""}
Cosmetics.Labels = {formation="Formation", burst="Bank Burst", tag="Name Tag", title="Title"}
Cosmetics.BurstShapes = {"confetti", "stars", "bubbles", "petals", "hearts", "rings", "ribbons", "glitter", "sparks", "leaves"}
Cosmetics.GlowGiftPerRank = 25
Cosmetics.MaxFollowers = 12
-- Follower offsets in the player's root space: x right, y up, z behind (+z).
Cosmetics.FormationBounds = {minDistance=1.5, maxDistance=9, minZ=-1.5, minY=-1.8, maxY=1.5}

-- Exactly one way to obtain each non-default item: rank (free), price (guaranteed
-- glow, optionally rank-gated) or achievement. premium=true marks milestone rewards.
Cosmetics.Formations = {
	{id="line", name="Parade Line", default=true, description="A tidy two-file trot right behind you."},
	{id="zigzag", name="Zigzag Trot", rank=7, description="Your parade zigs and zags in a bright chain."},
	{id="pairwave", name="Pair Wave", rank=18, description="Side-by-side pairs ripple like a gentle wave."},
	{id="conga", name="Conga Snake", rank=23, description="One long, wiggly single-file conga line."},
	{id="orbit", name="Orbit Loop", rank=25, premium=true, description="Your Sparks circle all the way around you."},
	{id="vee", name="Comet Vee", rank=31, description="A flying V with you at the point."},
	{id="star", name="Star Parade", rank=40, premium=true, description="Sparks trace a slowly turning five-point star."},
	{id="crown", name="Crown Arc", rank=45, premium=true, description="A royal arc behind you with raised crown points."},
	{id="heart", name="Sweetheart", price=2500, rank=6, description="Sparks trace a heart that drifts around its outline."},
	{id="spiral", name="Spiral Swirl", price=6000, rank=16, description="A rising swirl that turns as you run."},
	{id="infinity", name="Infinity Loop", price=9000, rank=27, description="A figure-eight ribbon weaving over and under."},
	{id="bloom", name="Flower Bloom", price=12000, rank=42, description="A five-petal flower that slowly turns."},
}

-- colors: 2-4 RGB bytes; count: particles per burst (6..24); speed: studs/s (4..16).
Cosmetics.Bursts = {
	{id="confetti", name="Confetti Pop", default=true, shape="confetti", count=16, speed=9, colors={{255,214,72},{255,132,177},{114,232,164},{120,200,255}}},
	{id="bubblefizz", name="Bubble Fizz", rank=11, shape="bubbles", count=12, speed=5, colors={{150,225,255},{170,255,230}}},
	{id="petalbreeze", name="Petal Breeze", rank=17, shape="petals", count=14, speed=6, colors={{255,170,210},{255,210,170},{255,240,250}}},
	{id="starshower", name="Star Shower", rank=21, shape="stars", count=12, speed=10, colors={{255,225,90},{255,250,200}}},
	{id="meadowleaves", name="Meadow Leaves", rank=26, shape="leaves", count=14, speed=6, colors={{130,230,120},{200,245,120},{255,215,90}}},
	{id="halorings", name="Halo Rings", rank=28, shape="rings", count=6, speed=5, colors={{120,220,255},{200,170,255}}},
	{id="candyconfetti", name="Candy Confetti", rank=33, shape="confetti", count=20, speed=11, colors={{255,140,190},{140,220,255},{255,240,140},{180,255,180}}},
	{id="auroraribbons", name="Aurora Ribbons", rank=35, premium=true, shape="ribbons", count=10, speed=8, colors={{170,150,255},{120,240,220},{255,150,230}}},
	{id="sparklerfan", name="Sparkler Fan", rank=37, shape="sparks", count=18, speed=13, colors={{255,200,90},{255,150,80},{255,240,180}}},
	{id="ribbontwirl", name="Ribbon Twirl", rank=41, shape="ribbons", count=8, speed=7, colors={{255,120,150},{255,220,120}}},
	{id="glitterrain", name="Glitter Rain", rank=43, shape="glitter", count=24, speed=4, colors={{255,235,150},{200,230,255},{255,200,240}}},
	{id="wishingstars", name="Wishing Stars", rank=46, shape="stars", count=16, speed=12, colors={{170,200,255},{255,255,220},{220,170,255}}},
	{id="grandparade", name="Grand Parade", rank=49, shape="confetti", count=24, speed=12, colors={{255,214,90},{255,120,160},{120,220,255},{170,255,170}}},
	{id="heartflutter", name="Heart Flutter", price=1500, shape="hearts", count=12, speed=7, colors={{255,110,150},{255,180,200}}},
	{id="lagoonbubbles", name="Lagoon Bubbles", price=2500, rank=9, shape="bubbles", count=16, speed=6, colors={{70,205,255},{120,255,220},{220,255,255}}},
	{id="sunsetpetals", name="Sunset Petals", price=4000, rank=19, shape="petals", count=18, speed=7, colors={{255,150,90},{255,200,120},{230,130,210}}},
	{id="cometsparks", name="Comet Sparks", price=6500, rank=32, shape="sparks", count=20, speed=15, colors={{200,240,255},{120,170,255},{255,255,255}}},
	{id="galaxyglitter", name="Galaxy Glitter", price=10000, rank=44, shape="glitter", count=24, speed=6, colors={{170,150,255},{255,170,250},{170,230,255}}},
	{id="goldenglitter", name="Golden Glitter", achievement="gilded_album", shape="glitter", count=20, speed=6, colors={{255,214,80},{255,245,180}}},
	{id="stampedestars", name="Stampede Stars", achievement="stampede", shape="stars", count=14, speed=11, colors={{255,190,90},{255,130,170},{255,240,150}}},
}

-- Bright text, dark stroke (WCAG contrast >= 4.5); optional darker frame behind it.
-- frameTransparency 1 means no frame.
Cosmetics.Tags = {
	{id="default", name="Classic", default=true, text={255,255,255}, stroke={40,40,70}, frameTransparency=1},
	{id="skypop", name="Sky Pop", rank=16, text={160,228,255}, stroke={15,50,105}, frameTransparency=1},
	{id="lemonfizz", name="Lemon Fizz", rank=19, text={255,240,120}, stroke={105,70,0}, frameTransparency=1},
	{id="coralglow", name="Coral Glow", rank=22, text={255,180,160}, stroke={110,30,35}, frameTransparency=1},
	{id="grapesoda", name="Grape Soda", rank=24, text={220,185,255}, stroke={60,20,110}, frameTransparency=1},
	{id="seafoam", name="Seafoam", rank=27, text={165,255,220}, stroke={10,75,70}, frameTransparency=1},
	{id="sunburst", name="Sunburst Frame", rank=30, premium=true, text={255,250,220}, stroke={110,50,0}, frame={190,100,10}, frameTransparency=0.35},
	{id="bubblegumpop", name="Bubblegum Pop", rank=32, text={255,195,232}, stroke={115,20,85}, frameTransparency=1},
	{id="twilight", name="Twilight", rank=34, text={215,215,255}, stroke={30,25,90}, frame={60,50,140}, frameTransparency=0.5},
	{id="peachsorbet", name="Peach Sorbet", rank=36, text={255,220,185}, stroke={120,60,30}, frameTransparency=1},
	{id="icepop", name="Ice Pop", rank=38, text={220,248,255}, stroke={20,70,120}, frame={40,110,170}, frameTransparency=0.55},
	{id="limelight", name="Limelight", rank=42, text={215,255,150}, stroke={40,90,15}, frameTransparency=1},
	{id="sherbet", name="Sherbet", rank=44, text={255,235,210}, stroke={150,45,80}, frame={180,60,110}, frameTransparency=0.5},
	{id="moonbeam", name="Moonbeam", rank=47, text={245,245,255}, stroke={55,55,115}, frame={70,70,150}, frameTransparency=0.5},
	{id="cherrypop", name="Cherry Pop", price=1000, text={255,160,180}, stroke={110,0,35}, frameTransparency=1},
	{id="mintframe", name="Mint Frame", price=2000, rank=4, text={230,255,240}, stroke={15,85,60}, frame={30,140,100}, frameTransparency=0.45},
	{id="oceanframe", name="Ocean Frame", price=3500, rank=14, text={225,245,255}, stroke={10,50,110}, frame={30,100,180}, frameTransparency=0.4},
	{id="sunsetframe", name="Sunset Frame", price=5000, rank=24, text={255,240,220}, stroke={120,30,50}, frame={200,80,70}, frameTransparency=0.35},
	{id="royalframe", name="Royal Frame", price=8000, rank=36, text={255,230,140}, stroke={55,15,95}, frame={100,50,170}, frameTransparency=0.3},
	{id="diamondframe", name="Diamond Frame", price=15000, rank=48, text={255,255,255}, stroke={30,60,120}, frame={50,120,190}, frameTransparency=0.25},
	{id="goldrush", name="Gold Rush", achievement="golden_10", text={255,225,110}, stroke={100,50,0}, frame={150,90,0}, frameTransparency=0.4},
	{id="radianthalo", name="Radiant Halo", achievement="radiant_medal", text={255,255,255}, stroke={130,40,130}, frame={170,70,170}, frameTransparency=0.35},
	{id="legendcrest", name="Legend Crest", achievement="heat_5_gold", text={255,240,170}, stroke={90,25,25}, frame={170,50,40}, frameTransparency=0.3},
	{id="collector", name="Collector's Badge", achievement="whole_bunch", text={200,255,230}, stroke={20,70,80}, frame={30,120,120}, frameTransparency=0.4},
}

-- Title text shown above the head, unlocked purely by rank.
Cosmetics.RankTitles = {
	{id="title_rookie", name="Rookie Wrangler", rank=5},
	{id="title_wrangler", name="Spark Wrangler", rank=10},
	{id="title_trailblazer", name="Trailblazer", rank=15},
	{id="title_scout", name="Stampede Scout", rank=20},
	{id="title_captain", name="Herd Captain", rank=25},
	{id="title_champion", name="Parade Champion", rank=30},
	{id="title_virtuoso", name="Spark Virtuoso", rank=35},
	{id="title_maestro", name="Dash Maestro", rank=40},
	{id="title_royalty", name="Parade Royalty", rank=45},
	{id="title_legend", name="Living Legend", rank=50},
}

local items, byId = {}, {}
Cosmetics.ByCategory = {formation=Cosmetics.Formations, burst=Cosmetics.Bursts, tag=Cosmetics.Tags, title=Cosmetics.RankTitles}
for _, category in ipairs(Cosmetics.Categories) do
	for _, item in ipairs(Cosmetics.ByCategory[category]) do
		item.category = category
		byId[item.id] = item
		table.insert(items, item)
	end
end
Cosmetics.Items = items
Cosmetics.ById = byId
local totalPrice = 0
for _, item in ipairs(items) do totalPrice += item.price or 0 end
Cosmetics.TotalPrice = totalPrice

local function rankFree(item)
	return item.rank ~= nil and item.price == nil and item.achievement == nil and not item.default
end

-- Rank rewards ----------------------------------------------------------------
-- Derived from the source data so perks, slots, trails and cosmetics cannot drift:
-- perks, then slots, trails, formations, bursts, tags, titles; an otherwise empty
-- rank becomes a Glow Gift (rank x 25 glow) that the server must grant.
local rankRewards = {}
for rank = 2, Progression.MaxRank do rankRewards[rank] = {} end
local function addReward(rank, reward)
	local list = rankRewards[rank]
	if list then table.insert(list, reward) end
end
for _, perk in ipairs(Loadout.Perks) do addReward(perk.rank, {kind="perk", id=perk.id, name="Perk: "..perk.name}) end
for rank = 3, Progression.MaxRank do
	local slots = Loadout.slots(rank)
	if slots > Loadout.slots(rank - 1) then
		addReward(rank, {kind="slot", amount=slots, name=if slots == 3 then "Third perk slot" else "Perk slot "..slots})
	end
end
for _, trail in ipairs(Progression.Trails) do
	if trail.rank and not trail.price and not trail.achievement then
		addReward(trail.rank, {kind="trail", id=trail.id, name="Trail: "..trail.name})
	end
end
for _, item in ipairs(items) do
	if rankFree(item) then
		addReward(item.rank, {kind=item.category, id=item.id, premium=item.premium == true or nil,
			name=Cosmetics.Labels[item.category]..": "..item.name})
	end
end
for rank = 2, Progression.MaxRank do
	if #rankRewards[rank] == 0 then
		local amount = rank * Cosmetics.GlowGiftPerRank
		addReward(rank, {kind="glow", amount=amount, name="Glow Gift: +"..amount.." glow"})
	end
end
Cosmetics.RankRewards = rankRewards

local function rankArg(rank)
	return math.clamp(math.floor(if finite(rank) then rank else 1), 1, Progression.MaxRank)
end
-- Display strings for every reward crossed going fromRank -> toRank (result callouts).
function Cosmetics.unlocksBetween(fromRank, toRank)
	local list = {}
	for rank = rankArg(fromRank) + 1, rankArg(toRank) do
		for _, reward in ipairs(rankRewards[rank] or {}) do table.insert(list, reward.name) end
	end
	return list
end
-- Glow Gift total to grant when crossing fromRank -> toRank.
function Cosmetics.glowBetween(fromRank, toRank)
	local total = 0
	for rank = rankArg(fromRank) + 1, rankArg(toRank) do
		for _, reward in ipairs(rankRewards[rank] or {}) do
			if reward.kind == "glow" then total += reward.amount end
		end
	end
	return total
end

-- Catalog queries -------------------------------------------------------------
function Cosmetics.category(id)
	local item = type(id) == "string" and byId[id] or nil
	return if item then item.category else nil
end
-- The item to render for a replicated id; falls back to the category default.
function Cosmetics.resolve(category, id)
	local item = type(id) == "string" and byId[id] or nil
	if item and item.category == category then return item end
	local default = Cosmetics.Defaults[category]
	return if default then byId[default] else nil
end

function Cosmetics.isUnlocked(profile, item)
	if type(item) == "string" then item = byId[item] end
	if type(item) ~= "table" or byId[item.id] ~= item then return false end
	if item.default then return true end
	profile = if type(profile) == "table" then profile else {}
	local cosmetics = profile.cosmetics
	if item.price and type(cosmetics) == "table" and type(cosmetics.owned) == "table" and cosmetics.owned[item.id] == true then
		return true
	end
	if item.achievement then
		return type(profile.achievements) == "table" and profile.achievements[item.achievement] == true
	end
	if rankFree(item) then return Progression.rank(profile.xp) >= item.rank end
	return false
end

-- Clean save data. Owned is whitelisted to priced items; equips must name an item of
-- the right category. Unlock status is NOT checked here: call stripUnearned(profile).
function Cosmetics.sanitize(raw)
	local result = {owned={}, formation=Cosmetics.Defaults.formation, burst=Cosmetics.Defaults.burst,
		tag=Cosmetics.Defaults.tag, title=Cosmetics.Defaults.title}
	if type(raw) ~= "table" then return result end
	local owned = rawget(raw, "owned")
	if type(owned) == "table" then
		for _, item in ipairs(items) do
			if item.price and rawget(owned, item.id) == true then result.owned[item.id] = true end
		end
	end
	for _, category in ipairs(Cosmetics.Categories) do
		local value = rawget(raw, category)
		local item = type(value) == "string" and byId[value] or nil
		if item and item.category == category then result[category] = item.id end
	end
	return result
end

local function ensure(profile)
	local cosmetics = profile.cosmetics
	if type(cosmetics) ~= "table" then
		cosmetics = Cosmetics.sanitize(nil)
		profile.cosmetics = cosmetics
	end
	if type(cosmetics.owned) ~= "table" then cosmetics.owned = {} end
	for category, default in pairs(Cosmetics.Defaults) do
		if type(cosmetics[category]) ~= "string" then cosmetics[category] = default end
	end
	return cosmetics
end

-- Resets every equipped item the profile has not unlocked. Returns true if changed.
function Cosmetics.stripUnearned(profile)
	if type(profile) ~= "table" then return false end
	local cosmetics = ensure(profile)
	local changed = false
	for _, category in ipairs(Cosmetics.Categories) do
		local default = Cosmetics.Defaults[category]
		local id = cosmetics[category]
		if id ~= default then
			local item = byId[id]
			if not (item and item.category == category and Cosmetics.isUnlocked(profile, item)) then
				cosmetics[category] = default
				changed = true
			end
		end
	end
	return changed
end

-- Equip if unlocked; otherwise buy at its guaranteed glow price (rank gate first).
-- Returns ok, message, pricePaid. Nothing changes on failure.
function Cosmetics.equip(profile, category, id)
	if type(profile) ~= "table" then return false, "No profile", 0 end
	if type(category) ~= "string" or Cosmetics.Defaults[category] == nil then return false, "Unknown category", 0 end
	if category == "title" and id == "" then
		ensure(profile).title = ""
		return true, "Title cleared", 0
	end
	local item = type(id) == "string" and byId[id] or nil
	if not item then return false, "Unknown cosmetic", 0 end
	if item.category ~= category then return false, "That is not a "..Cosmetics.Labels[category], 0 end
	if Cosmetics.isUnlocked(profile, item) then
		ensure(profile)[category] = item.id
		return true, item.name.." equipped", 0
	end
	if not item.price then
		if item.achievement then
			local achievement = Progression.AchievementById[item.achievement]
			return false, "Earn the "..(if achievement then achievement.name else "matching").." achievement to unlock", 0
		end
		return false, "Reach rank "..tostring(item.rank).." to unlock", 0
	end
	if item.rank and Progression.rank(profile.xp) < item.rank then return false, "Reach rank "..item.rank.." first", 0 end
	local coins = if finite(profile.coins) then math.floor(profile.coins) else 0
	if coins < item.price then return false, "Collect more glow", 0 end
	local cosmetics = ensure(profile)
	profile.coins = math.clamp(coins - item.price, 0, MAX_COINS)
	cosmetics.owned[item.id] = true
	cosmetics[category] = item.id
	return true, item.name.." unlocked and equipped", item.price
end

-- Equipped rank-title text if still unlocked, else "".
function Cosmetics.titleText(profile)
	local cosmetics = if type(profile) == "table" then profile.cosmetics else nil
	local id = if type(cosmetics) == "table" then cosmetics.title else nil
	local item = if type(id) == "string" then byId[id] else nil
	return if item and item.category == "title" and Cosmetics.isUnlocked(profile, item) then item.name else ""
end

-- Formation geometry ----------------------------------------------------------
local TAU = 2 * math.pi
local BASE_Y = -1 -- miniatures ride just below the root, like the legacy parade line
local bounds = Cosmetics.FormationBounds

local function closedPath(points)
	local cumulative, total = {0}, 0
	for index, a in ipairs(points) do
		local b = points[index % #points + 1]
		total += math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		cumulative[index + 1] = total
	end
	return {points=points, cumulative=cumulative, total=total}
end
local function sampled(samples, curve)
	local points = {}
	for k = 0, samples - 1 do
		local x, z = curve(TAU * k / samples)
		table.insert(points, {x, z})
	end
	return closedPath(points)
end
-- Point at fraction s of the perimeter (even spacing by arc length). Also returns
-- the curve parameter in [0, 1) for sampled curves.
local function along(path, s)
	local points, cumulative = path.points, path.cumulative
	local target = (s % 1) * path.total
	local low, high = 1, #points
	while low < high do
		local mid = (low + high + 1) // 2
		if cumulative[mid] <= target then low = mid else high = mid - 1 end
	end
	local a, b = points[low], points[low % #points + 1]
	local span = cumulative[low + 1] - cumulative[low]
	local f = if span > 0 then math.clamp((target - cumulative[low]) / span, 0, 1) else 0
	return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, (low - 1 + f) / #points
end
local function rotate(x, z, angle)
	local c, s = math.cos(angle), math.sin(angle)
	return x * c - z * s, x * s + z * c
end

-- Two overlapping lobes and straight sides to a tip; lobes face the player (-z) so
-- the owner's chase camera sees it upright. The dip is a corner, not a cusp, so
-- followers never bunch there.
local HEART = (function()
	local cx, cz, radius, tipZ = 1.4, -0.7, 1.7, 3
	local dip = math.atan2(-math.sqrt(radius * radius - cx * cx), -cx)
	local tangent = math.atan2(tipZ - cz, -cx) - math.acos(radius / math.sqrt(cx * cx + (tipZ - cz) ^ 2))
	local right = {}
	for k = 0, 24 do
		local a = dip + (tangent - dip) * k / 24
		table.insert(right, {cx + radius * math.cos(a), cz + radius * math.sin(a)})
	end
	local points = {{0, tipZ}}
	for k = #right, 1, -1 do table.insert(points, {-right[k][1], right[k][2]}) end
	for k = 2, #right do table.insert(points, right[k]) end
	return closedPath(points)
end)()
local STAR = (function()
	local points = {}
	for k = 0, 9 do
		local radius = if k % 2 == 0 then 3.4 else 1.4
		local angle = k * math.pi / 5
		table.insert(points, {radius * math.sin(angle), -radius * math.cos(angle)})
	end
	return closedPath(points)
end)()
local INFINITY = sampled(96, function(a) return 3.6 * math.sin(a), 1.8 * math.sin(2 * a) end)
local BLOOM = sampled(100, function(a)
	local radius = 2.4 + 0.9 * math.cos(5 * a)
	return radius * math.sin(a), -radius * math.cos(a)
end)

-- Each shape takes (index, count, u = 0..1 along the parade, t seconds, m = motion
-- 1 or 0) and returns x, y, z. With m = 0 and t = 0 every shape is fully static.
local shapes = {}
shapes.line = function(i, n, _, t, m)
	local spacing = math.min(1.15, 6.4 / n) -- legacy spacing up to 5 followers
	return (i % 2 * 2 - 1) * 1.7, BASE_Y + m * math.sin(t * 4 - i) * 0.2, 2 + i * spacing
end
local ZIG = {0, 1, 0, -1}
shapes.zigzag = function(i, n, _, t, m)
	local spacing = math.min(0.9, 7 / n)
	return ZIG[(i - 1) % 4 + 1] * 2.3 + m * math.sin(t * 1.8) * 0.35, BASE_Y + m * math.sin(t * 3 - i * 0.6) * 0.12, 1.8 + i * spacing
end
shapes.pairwave = function(i, n, _, t, m)
	local pair, pairCount = math.ceil(i / 2), math.ceil(n / 2)
	local spacing = math.min(1.2, 6.2 / pairCount)
	local half = 1.3 + 0.55 * math.sin(pair * 1.2 - t * 2.5)
	local side = if i == n and n % 2 == 1 then 0 elseif i % 2 == 1 then -1 else 1
	return side * half, BASE_Y + m * 0.3 * math.sin(t * 3 - pair), 1.9 + pair * spacing
end
shapes.conga = function(i, n, _, t, m)
	local spacing = math.min(0.85, 6.8 / n)
	return 1.6 * math.sin(i * 0.75 - t * 3), BASE_Y + m * 0.1 * math.sin(t * 6 - i * 1.3), 1.8 + i * spacing
end
shapes.orbit = function(i, n, _, t, m)
	local angle = math.pi + TAU * (i - 1) / n + t * 0.8
	return 4 * math.sin(angle), BASE_Y + 0.2 + m * 0.2 * math.sin(t * 2 + i), 2 - 3.5 * math.cos(angle)
end
shapes.vee = function(i, n, _, t, m)
	local step, deepest = math.ceil(i / 2), math.ceil(n / 2)
	local scale = math.min(1, 5 / deepest)
	local side = if i % 2 == 1 then 1 else -1
	return side * step * 0.9 * scale, BASE_Y + m * 0.25 * math.sin(t * 3 - step * 0.8), 1.6 + step * 1.1 * scale
end
shapes.star = function(i, n, _, t, m)
	local x, z = along(STAR, (i - 1) / n)
	x, z = rotate(x, z, t * 0.35)
	return x, BASE_Y + 0.1 + m * 0.15 * math.sin(t * 2 + i), 5 + z
end
shapes.crown = function(i, n, u, t, m)
	local angle = if n == 1 then 0 else math.rad(-70 + 140 * u)
	local raised = math.floor(math.abs(i - (n + 1) / 2)) % 2 == 0
	return 4.2 * math.sin(angle), BASE_Y + (if raised then 1 else 0.15) + m * 0.12 * math.sin(t * 2.5 + i), 0.6 + 4.2 * math.cos(angle)
end
shapes.heart = function(i, n, _, t, m)
	local x, z = along(HEART, (i - 1) / n + t * 0.06)
	return x, BASE_Y + 0.1 + m * 0.12 * math.sin(t * 2 + i), 4.4 + z
end
shapes.spiral = function(i, _, u, t, m)
	local radius = 0.9 + 2.7 * u
	local angle = u * 3.2 * math.pi + t * 0.9
	return radius * math.sin(angle), BASE_Y - 0.3 + u + m * 0.1 * math.sin(t * 2 + i), 5.2 - radius * math.cos(angle)
end
shapes.infinity = function(i, n, _, t)
	local x, z, f = along(INFINITY, (i - 1) / n + t * 0.07)
	return x, BASE_Y + 0.1 + 0.45 * math.cos(f * TAU), 4.6 + z -- over/under at the crossing
end
shapes.bloom = function(i, n, _, t, m)
	local x, z, f = along(BLOOM, (i - 1) / n)
	x, z = rotate(x, z, t * 0.5)
	return x, BASE_Y + 0.1 + 0.3 * math.cos(5 * f * TAU) + m * 0.1 * math.sin(t * 2 + i), 5 + z
end

-- Safety net: keeps any shape inside the readable band around the player.
local function bound(x, y, z)
	if not (finite(x) and finite(y) and finite(z)) then return 0, BASE_Y, 3 end
	z = math.max(z, bounds.minZ)
	y = math.clamp(y, bounds.minY, bounds.maxY)
	local distance = math.sqrt(x * x + z * z)
	if distance < bounds.minDistance then
		if distance < 1e-6 then return 0, y, bounds.minDistance end
		local scale = bounds.minDistance / distance
		x, z = x * scale, z * scale
	elseif distance > bounds.maxDistance then
		local scale = bounds.maxDistance / distance
		x, z = x * scale, z * scale
	end
	return x, y, math.max(z, bounds.minZ)
end

-- Offset of follower `index` of `count` (1..12) for formation `id` at time t.
-- Deterministic; unknown ids fall back to the line; reduced = true is static.
-- Allocation-free variant for per-frame rendering.
function Cosmetics.formationXYZ(id, index, count, t, reduced)
	local shape = (if type(id) == "string" then shapes[id] else nil) or shapes.line
	count = math.clamp(math.floor(if finite(count) then count else 1), 1, Cosmetics.MaxFollowers)
	index = math.clamp(math.floor(if finite(index) then index else 1), 1, count)
	local still = reduced == true
	local time = if still or not finite(t) then 0 else t
	local u = if count > 1 then (index - 1) / (count - 1) else 0
	return bound(shape(index, count, u, time, if still then 0 else 1))
end
-- Same offset as a table: {x=, y=, z=} (also indexable as [1], [2], [3]).
function Cosmetics.formationOffset(id, index, count, t, reduced)
	local x, y, z = Cosmetics.formationXYZ(id, index, count, t, reduced)
	return {x=x, y=y, z=z, x, y, z}
end

return Cosmetics
