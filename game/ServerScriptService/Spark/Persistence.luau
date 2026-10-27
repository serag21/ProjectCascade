local Profile = if script then require(game:GetService("ReplicatedStorage").Spark.Profile) else require("../../ReplicatedStorage/Spark/Profile")
local Persistence = {}
Persistence.__index = Persistence

-- UpdateAsync is the only storage operation: loading also atomically acquires a lease.
-- Production passes {sessionId=GUID, wait=task.wait}; clock must return Unix seconds.
-- Autosave every 30s, lease default 120s. A failed load NEVER creates a writable session.
function Persistence.new(store, clock, options)
	options = options or {}
	assert(type(store) == "table" or typeof(store) == "Instance", "store required")
	return setmetatable({
		store=store, clock=clock or os.time, wait=options.wait or function() end,
		id=options.sessionId or tostring({}), retries=math.clamp(options.retries or 3,1,5),
		leaseSeconds=math.max(options.leaseSeconds or 120,30), sessions={}, busy={},
	}, Persistence)
end

local function keyFor(userId)
	if type(userId) ~= "number" or userId ~= userId or userId == math.huge or userId == -math.huge or userId % 1 ~= 0 then return nil end
	-- Negative user ids are valid for Studio local clients. Their stores must be isolated.
	return "player:" .. tostring(userId)
end

local function unpackRecord(raw)
	if raw == nil then return Profile.new(), nil, "new" end
	if type(raw) ~= "table" then return nil, nil, "corrupt" end
	if raw.kind == "SparkProfile" then
		if raw.version ~= 1 then return nil, nil, "future-version" end
		if type(raw.data) ~= "table" then return nil, nil, "corrupt" end
		local lease = raw.lease
		if lease ~= nil and (type(lease) ~= "table" or type(lease.id) ~= "string"
			or type(lease.expiresAt) ~= "number" or lease.expiresAt ~= lease.expiresAt
			or lease.expiresAt == math.huge or lease.expiresAt == -math.huge) then return nil, nil, "corrupt" end
		local profile, status = Profile.sanitize(raw.data)
		return profile, lease, status
	end
	-- Accept the original raw v1 profile for a single atomic migration.
	if raw.kind ~= nil then return nil, nil, "future-version" end
	local profile, status = Profile.sanitize(raw)
	return profile, nil, status
end

function Persistence:_update(key, transform)
	local lastError
	for attempt=1,self.retries do
		local ok, result = pcall(function() return self.store:UpdateAsync(key, transform) end)
		if ok then return true, result end
		lastError = tostring(result)
		if attempt < self.retries then self.wait(0.25 * 2^(attempt-1)) end
	end
	-- Diagnostics remain server-side, not in client-facing status or saved data.
	self.lastError = lastError
	return false, nil
end

function Persistence:load(userId)
	local key = keyFor(userId)
	if not key then return nil, "invalid-user" end
	if self.busy[key] then return nil, "busy" end
	local existing = self.sessions[key]
	if existing then
		if self.clock() >= existing.expiresAt then
			self.sessions[key]=nil
			return nil, "lease-lost"
		end
		return existing.profile, "ready"
	end
	self.busy[key] = true
	local reason = "unavailable"
	local ok, record = self:_update(key, function(raw)
		local profile, lease, status = unpackRecord(raw)
		if not profile then reason=status; return nil end
		local now = self.clock()
		if lease and lease.id ~= self.id and lease.expiresAt > now then reason="locked"; return nil end
		reason="ready"
		return {kind="SparkProfile",version=1,data=profile,lease={id=self.id,expiresAt=now+self.leaseSeconds}}
	end)
	self.busy[key] = nil
	if not ok then return nil, "unavailable" end
	if reason ~= "ready" or type(record) ~= "table" then return nil, reason end
	local profile, lease = unpackRecord(record)
	if not profile then return nil, "corrupt" end
	-- The service can yield after committing the transform. A returned lease may
	-- already be expired (or superseded); never grant a new local earning window.
	if not lease or lease.id ~= self.id or lease.expiresAt <= self.clock() then return nil, "lease-lost" end
	self.sessions[key] = {profile=profile,expiresAt=lease.expiresAt}
	return profile, "ready"
end

function Persistence:_write(userId, profile, release)
	local key = keyFor(userId)
	if not key then return false, "invalid-user" end
	if self.busy[key] then return false, "busy" end
	local session = self.sessions[key]
	if not session then return false, "not-loaded" end
	if self.clock() >= session.expiresAt then self.sessions[key]=nil; return false, "lease-lost" end
	if type(profile) ~= "table" then return false, "corrupt" end
	local snapshot, invalid = Profile.sanitize(profile)
	if not snapshot then return false, invalid end
	snapshot.lastSeen = math.floor(self.clock())
	self.busy[key] = true
	local reason = "lease-lost"
	local ok, record = self:_update(key, function(raw)
		local stored, lease = unpackRecord(raw)
		local now = self.clock()
		if not stored or not lease or lease.id ~= self.id or lease.expiresAt <= now then reason="lease-lost"; return nil end
		reason=if release then "released" else "saved"
		return {kind="SparkProfile",version=1,data=snapshot,
			lease=if release then nil else {id=self.id,expiresAt=now+self.leaseSeconds}}
	end)
	self.busy[key] = nil
	if not ok then return false, "unavailable" end
	if not record or reason == "lease-lost" then self.sessions[key]=nil; return false, "lease-lost" end
	if release then
		self.sessions[key]=nil
	else
		local stored, lease = unpackRecord(record)
		if not stored or not lease or lease.id ~= self.id or lease.expiresAt <= self.clock() then
			self.sessions[key]=nil
			return false, "lease-lost"
		end
		session.expiresAt=lease.expiresAt
		-- Keep live profile reference: caller may legitimately mutate it while the request yields.
		session.profile=profile
	end
	return true, reason
end

-- Absolute acknowledged deadline, not response-arrival time. A pending request
-- never extends it until a valid future lease is actually returned.
function Persistence:leaseDeadline(userId)
	local key = keyFor(userId)
	local session = key and self.sessions[key]
	return session and session.expiresAt or nil
end

function Persistence:save(userId, profile) return self:_write(userId, profile, false) end
function Persistence:release(userId, profile) return self:_write(userId, profile, true) end
return Persistence
