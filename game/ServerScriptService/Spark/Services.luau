-- Optional platform services with injected dependencies so they are testable
-- offline. Every platform call is pcall-wrapped: a failing analytics or
-- leaderboard backend can never block gameplay, saves or rewards.
local Services = {}

-- Roblox AnalyticsService funnels/economy. No personal data or chat is sent.
-- Onboarding steps are ordered and FROZEN for launch (plan §6.13): never renumber
-- once live data exists; add new steps only at the end.
Services.FunnelSteps = {join=1, first_catch=2, first_bank=3, first_dash_through=4, first_round_complete=5,
	second_round_start=6, first_perk_equipped=7, first_daily_stampede=8}
function Services.analytics(analyticsService, enum, enabled)
	local self = {enabled = enabled ~= false and analyticsService ~= nil, errors = 0}
	local function call(fn)
		if not self.enabled then return false end
		local ok = pcall(fn)
		if not ok then self.errors += 1 end
		return ok
	end
	function self.funnel(player, name)
		local step = Services.FunnelSteps[name]
		if not step then return false end
		return call(function() analyticsService:LogOnboardingFunnelStepEvent(player, step, name) end)
	end
	-- flow: "source" | "sink"; amounts are server-authoritative glow values.
	function self.economy(player, flow, amount, balance, sku)
		if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then return false end
		return call(function()
			analyticsService:LogEconomyEvent(player,
				if flow == "sink" then enum.AnalyticsEconomyFlowType.Sink else enum.AnalyticsEconomyFlowType.Source,
				"Glow", math.floor(amount), math.floor(balance),
				if flow == "sink" then enum.AnalyticsEconomyTransactionType.Shop.Name else enum.AnalyticsEconomyTransactionType.Gameplay.Name,
				string.sub(tostring(sku or "unknown"), 1, 40))
		end)
	end
	function self.custom(player, name, value)
		if type(name) ~= "string" or name == "" then return false end
		local amount = if type(value) == "number" and value == value and math.abs(value) < math.huge then value else 1
		return call(function() analyticsService:LogCustomEvent(player, string.sub(name, 1, 40), amount) end)
	end
	-- Rank-ups as progression completions on one path ("Rank").
	function self.progression(player, path, level, levelName)
		if type(path) ~= "string" or type(level) ~= "number" or level ~= level or level < 1 or level % 1 ~= 0 then return false end
		return call(function()
			analyticsService:LogProgressionCompleteEvent(player, string.sub(path, 1, 40), level, string.sub(tostring(levelName or level), 1, 40))
		end)
	end
	return self
end

-- Per-arena all-time and weekly leaderboards (optional competition).
-- provider(name) -> OrderedDataStore-like {UpdateAsync, GetSortedAsync}.
function Services.leaderboard(provider, biomeIds, weekOf)
	local self = {version = 0, boards = {}, failures = 0}
	local function names(kind, biomeId, week)
		if kind == "weekly" then return "SparkWeekly_"..biomeId.."_"..week.."_v1" end
		return "SparkBest_"..biomeId.."_v1"
	end
	-- Called only with a server-verified finished round score.
	function self.submit(userId, biomeId, score, now)
		if type(userId) ~= "number" or type(score) ~= "number" or score <= 0 or score ~= score or score > 10000000 then return 0 end
		if not table.find(biomeIds, biomeId) then return 0 end
		local written = 0
		for _, kind in ipairs({"alltime", "weekly"}) do
			local ok = pcall(function()
				local store = provider(names(kind, biomeId, weekOf(now)))
				store:UpdateAsync(tostring(userId), function(old)
					local previous = if type(old) == "number" then old else 0
					if score <= previous then return nil end -- nil cancels the write
					return math.floor(score)
				end)
			end)
			if ok then written += 1 else self.failures += 1 end
		end
		return written
	end
	-- nameOf(userId) may yield; callers run refresh in its own thread.
	function self.refresh(now, nameOf)
		local next = {}
		for _, biomeId in ipairs(biomeIds) do
			next[biomeId] = {}
			for _, kind in ipairs({"alltime", "weekly"}) do
				local rows = {}
				local ok = pcall(function()
					local pages = provider(names(kind, biomeId, weekOf(now))):GetSortedAsync(false, 10)
					for rank, entry in ipairs(pages:GetCurrentPage()) do
						local userId = tonumber(entry.key)
						if userId and type(entry.value) == "number" then
							table.insert(rows, {rank=rank, userId=userId, score=math.floor(entry.value), name=nameOf(userId)})
						end
					end
				end)
				if not ok then self.failures += 1; rows = (self.boards[biomeId] and self.boards[biomeId][kind]) or {} end
				next[biomeId][kind] = rows
			end
		end
		self.boards = next
		self.version += 1
		return self.boards
	end
	-- Daily Stampede board (D16): the ONLY public leaderboard. One OrderedDataStore
	-- per UTC day; written only with server-finished, validated trial scores.
	self.daily = {day = -1, rows = {}}
	local function dailyName(day) return "SparkDaily_" .. tostring(day) .. "_v1" end
	function self.submitDaily(userId, day, score)
		if type(userId) ~= "number" or type(day) ~= "number" or day % 1 ~= 0 or type(score) ~= "number"
			or score ~= score or score <= 0 or score > 10000000 then return false end
		local ok = pcall(function()
			provider(dailyName(day)):UpdateAsync(tostring(userId), function(old)
				local previous = if type(old) == "number" then old else 0
				if score <= previous then return nil end
				return math.floor(score)
			end)
		end)
		if not ok then self.failures += 1 end
		return ok
	end
	function self.refreshDaily(day, nameOf)
		local rows = {}
		local ok = pcall(function()
			local pages = provider(dailyName(day)):GetSortedAsync(false, 10)
			for rank, entry in ipairs(pages:GetCurrentPage()) do
				local userId = tonumber(entry.key)
				if userId and type(entry.value) == "number" then
					table.insert(rows, {rank=rank, userId=userId, score=math.floor(entry.value), name=nameOf(userId)})
				end
			end
		end)
		if not ok then
			self.failures += 1
			if self.daily.day == day then return self.daily.rows end
		end
		self.daily = {day = day, rows = rows}
		self.version += 1
		return rows
	end
	return self
end

-- In-memory OrderedDataStore double for Studio/offline tests (no platform writes).
function Services.memoryOrderedStore()
	local stores = {}
	return function(name)
		stores[name] = stores[name] or {values = {}}
		local data = stores[name]
		local store = {}
		function store:UpdateAsync(key, transform)
			local result = transform(data.values[key])
			if result ~= nil then data.values[key] = result end
			return result
		end
		function store:GetSortedAsync(ascending, size)
			local rows = {}
			for key, value in pairs(data.values) do table.insert(rows, {key=key, value=value}) end
			table.sort(rows, function(a, b)
				if a.value == b.value then return a.key < b.key end
				if ascending then return a.value < b.value end
				return a.value > b.value
			end)
			while #rows > size do table.remove(rows) end
			return {GetCurrentPage = function() return rows end}
		end
		return store
	end
end

return Services
