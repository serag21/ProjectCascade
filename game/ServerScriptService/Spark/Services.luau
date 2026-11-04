-- Optional platform services with injected dependencies so they are testable
-- offline. Every platform call is pcall-wrapped: a failing analytics or
-- leaderboard backend can never block gameplay, saves or rewards.
local Services = {}

-- Roblox AnalyticsService funnels/economy. No personal data or chat is sent.
-- Onboarding steps are ordered and must stay stable once live data exists.
Services.FunnelSteps = {join=1, first_action=2, first_catch=3, first_bank=4, first_round=5, first_upgrade=6, replay=7}
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
		return call(function() analyticsService:LogCustomEvent(player, string.sub(name, 1, 40), value or 1) end)
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
