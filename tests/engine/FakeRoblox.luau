--!nocheck
-- Headless fake Roblox engine for offline QA of SPARK STAMPEDE.
--
-- What it validates against the real Roblox API dump (RobloxApi.luau):
--   * Instance.new class names, creatability; service names.
--   * Property/method/event names on each class hierarchy, read-only and
--     security-restricted members, value types (enum type, datatype, class).
--   * Attribute value types, remote payload shapes (mixed/sparse tables,
--     functions, cycles), module return conventions.
-- What it does NOT model: physics, collision, rendering, replication latency
-- or filtering, real DataStore limits/latency, input devices, sound playback.
-- Server and clients share one DataModel; remotes route between contexts.
local Api = require("./RobloxApi")
local DT = require("./Datatypes")

local Fake = {}

-------------------------------------------------------------------- API index
local classCache = {}
local function parseProp(code)
	local i, readOnly, unreadable = 1, false, false
	while true do
		local ch = string.sub(code, i, i)
		if ch == "!" then readOnly = true elseif ch == "?" then unreadable = true else break end
		i += 1
	end
	return {readOnly = readOnly, unreadable = unreadable, cat = string.sub(code, i, i), type = string.sub(code, i + 1)}
end
local function words(s, into)
	for w in string.gmatch(s, "%S+") do into[w] = true end
	return into
end
local function classInfo(name)
	local cached = classCache[name]
	if cached ~= nil then return cached or nil end
	local raw = Api.classes[name]
	if not raw then classCache[name] = false; return nil end
	local info = {name = name, props = {}, funcs = {}, events = {}, isA = {[name] = true},
		notCreatable = string.find(raw.t, "N") ~= nil, service = string.find(raw.t, "S") ~= nil}
	if raw.s ~= "" and raw.s ~= "<<<ROOT>>>" then
		local super = classInfo(raw.s)
		if super then
			for k, v in pairs(super.props) do info.props[k] = v end
			for k in pairs(super.funcs) do info.funcs[k] = true end
			for k in pairs(super.events) do info.events[k] = true end
			for k in pairs(super.isA) do info.isA[k] = true end
		end
	end
	for k, v in pairs(raw.p) do info.props[k] = parseProp(v) end
	words(raw.f, info.funcs); words(raw.e, info.events)
	classCache[name] = info
	return info
end
Fake.classInfo = classInfo

-------------------------------------------------------------------- Enums
local EnumItemMt = DT.typed("EnumItem")
local EnumMt = DT.typed("Enum")
local enumCache = {}
local function enumOf(name)
	if enumCache[name] then return enumCache[name] end
	local spec = Api.enums[name]
	if not spec then return nil end
	local enum = setmetatable({_name = name, _items = {}, _order = {}}, EnumMt)
	for entry in string.gmatch(spec, "%S+") do
		local itemName, value = string.match(entry, "^(.-):(%-?%d+)$")
		local item = setmetatable({Name = itemName, Value = tonumber(value), EnumType = enum}, EnumItemMt)
		enum._items[itemName] = item
		table.insert(enum._order, item)
	end
	enumCache[name] = enum
	return enum
end
EnumMt.__index = function(enum, key)
	local items = rawget(enum, "_items")
	if items[key] then return items[key] end
	if key == "GetEnumItems" then return function(self) return table.clone(rawget(self, "_order")) end end
	if key == "FromName" then return function(self, n) return rawget(self, "_items")[n] end end
	if key == "FromValue" then
		return function(self, v) for _, it in ipairs(rawget(self, "_order")) do if it.Value == v then return it end end end
	end
	error(tostring(key) .. " is not a valid member of \"Enum." .. rawget(enum, "_name") .. "\"", 2)
end
EnumMt.__tostring = function(enum) return rawget(enum, "_name") end
EnumItemMt.__index = function(item, key)
	if key == "IsA" then return function(self, n) return rawget(self, "EnumType")._name == n end end
	error(tostring(key) .. " is not a valid member of EnumItem", 2)
end
EnumItemMt.__tostring = function(item) return "Enum." .. rawget(item, "EnumType")._name .. "." .. rawget(item, "Name") end
local EnumsMt = DT.typed("Enums")
EnumsMt.__index = function(_, key)
	local enum = enumOf(key)
	if not enum then error(tostring(key) .. " is not a valid member of \"Enum\"", 2) end
	return enum
end
local EnumGlobal = setmetatable({}, EnumsMt)
Fake.Enum = EnumGlobal

-------------------------------------------------------------------- Engine
function Fake.new(options)
	options = options or {}
	local engine = {now = 0, baseTime = options.baseTime or 1793750400, errors = {}, output = {}, warnings = {},
		remoteIssues = {}, calls = {}, analytics = {}, kicks = {}, frame = 0, studio = options.studio ~= false,
		instanceCount = 0, created = 0, destroyedCount = 0}
	local recs = setmetatable({}, {__mode = "k"})
	local threadContext = setmetatable({}, {__mode = "k"})
	local sleepers, deferred = {}, {}
	local serverContext = {kind = "server"}
	engine.serverContext = serverContext

	local function fail(message)
		error(message, 3)
	end
	local function currentContext()
		local co = coroutine.running()
		return (co and threadContext[co]) or engine.defaultContext or serverContext
	end
	local function record(kind, message)
		table.insert(engine[kind], message)
		if options.echo then print("[" .. kind .. "] " .. message) end
	end
	engine.record = record

	----------------------------------------------------------------- typeof
	local function typeof(v)
		local t = type(v)
		if t == "table" then
			if recs[v] then return "Instance" end
			local mt = getmetatable(v)
			if type(mt) == "table" then
				local name = rawget(mt, "__typename")
				if name then return name end
			end
		end
		return t
	end
	engine.typeof = typeof
	-- Real Roblox: Vector3 is the native "vector" type; Instances, other
	-- datatypes, enums and signals are "userdata". Game guards rely on this.
	local function robloxType(v)
		local t = type(v)
		if t == "table" then
			local name = typeof(v)
			if name == "Vector3" then return "vector" end
			if name ~= "table" then return "userdata" end
		end
		return t
	end
	engine.type = robloxType

	----------------------------------------------------------------- scheduler
	local function resume(co, ...)
		if coroutine.status(co) ~= "suspended" then return end
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			record("errors", tostring(err) .. "\n" .. debug.traceback(co))
		end
	end
	local function spawn(fnOrThread, ctx, ...)
		local co = if type(fnOrThread) == "thread" then fnOrThread else coroutine.create(fnOrThread)
		threadContext[co] = threadContext[co] or ctx or currentContext()
		resume(co, ...)
		return co
	end
	engine.spawn = spawn
	local cancelled = setmetatable({}, {__mode = "k"})
	local function sleep(seconds)
		local co = coroutine.running()
		if not co or not coroutine.isyieldable() then error("attempt to yield from outside a coroutine", 3) end
		local started = engine.now
		table.insert(sleepers, {wake = engine.now + math.max(0, seconds or 0), co = co, frame = engine.frame})
		coroutine.yield()
		return engine.now - started
	end
	local task = {}
	function task.spawn(f, ...) return spawn(f, nil, ...) end
	function task.defer(f, ...)
		local co = if type(f) == "thread" then f else coroutine.create(f)
		threadContext[co] = threadContext[co] or currentContext()
		table.insert(deferred, {co = co, args = table.pack(...)})
		return co
	end
	function task.delay(t, f, ...)
		local args = table.pack(...)
		local co = if type(f) == "thread" then f else coroutine.create(function() f(table.unpack(args, 1, args.n)) end)
		threadContext[co] = threadContext[co] or currentContext()
		table.insert(sleepers, {wake = engine.now + math.max(0, t or 0), co = co, frame = engine.frame, start = true})
		return co
	end
	function task.wait(t) return sleep(t) end
	function task.cancel(co)
		cancelled[co] = true
		pcall(coroutine.close, co)
	end
	function task.synchronize() end
	function task.desynchronize() end
	engine.task = task

	local virtualOs = {
		clock = function() return engine.now end,
		time = function(t) if t ~= nil then return os.time(t) end return engine.baseTime + math.floor(engine.now) end,
		date = os.date, difftime = os.difftime,
	}
	engine.os = virtualOs

	----------------------------------------------------------------- signals
	local SignalMt = DT.typed("RBXScriptSignal")
	local ConnectionMt = DT.typed("RBXScriptConnection")
	local signalMethods = {}
	local function newSignal(name)
		return setmetatable({_name = name or "Signal", _connections = {}, _waiting = {}}, SignalMt)
	end
	function signalMethods.Connect(self, fn)
		if type(fn) ~= "function" then error("Attempt to connect failed: Passed value is not a function", 2) end
		local connection = setmetatable({Connected = true, _fn = fn, _ctx = currentContext(), _signal = self}, ConnectionMt)
		table.insert(self._connections, connection)
		return connection
	end
	signalMethods.ConnectParallel = signalMethods.Connect
	function signalMethods.Once(self, fn)
		local connection
		connection = signalMethods.Connect(self, function(...)
			connection:Disconnect()
			fn(...)
		end)
		return connection
	end
	function signalMethods.Wait(self)
		local co = coroutine.running()
		if not co or not coroutine.isyieldable() then error("Wait must be called from a coroutine", 2) end
		table.insert(self._waiting, co)
		return coroutine.yield()
	end
	SignalMt.__index = function(_, key) return signalMethods[key] or error(tostring(key) .. " is not a valid member of RBXScriptSignal", 2) end
	ConnectionMt.__index = function(_, key)
		if key == "Disconnect" then
			return function(c)
				if not rawget(c, "Connected") then return end
				rawset(c, "Connected", false)
				local list = rawget(c, "_signal")._connections
				local index = table.find(list, c)
				if index then table.remove(list, index) end
			end
		end
		error(tostring(key) .. " is not a valid member of RBXScriptConnection", 2)
	end
	local function fire(signal, ...)
		if not signal then return end
		local list = table.clone(signal._connections)
		for _, connection in ipairs(list) do
			if rawget(connection, "Connected") then
				local co = coroutine.create(connection._fn)
				threadContext[co] = connection._ctx
				resume(co, ...)
			end
		end
		local waiting = signal._waiting
		signal._waiting = {}
		for _, co in ipairs(waiting) do resume(co, ...) end
	end
	engine.newSignal = newSignal
	engine.fire = fire

	----------------------------------------------------------------- instances
	local InstanceMt = {}
	local methods = {}       -- name -> function(rec, ...) for any class that has it in the API
	local classMethods = {}  -- className -> name -> impl (overrides, includes test-only)
	local getters, setters = {}, {}
	local defaults = {}

	local function recOf(v) return recs[v] end
	engine.recOf = recOf
	local function className(rec) return rec.class.name end
	local function fullName(rec)
		local parts = {}
		local r = rec
		while r and r.class.name ~= "DataModel" do
			table.insert(parts, 1, r.props.Name)
			r = r.parent and recs[r.parent]
		end
		return table.concat(parts, ".")
	end
	engine.fullName = function(inst) return fullName(recs[inst]) end

	local function isA(rec, name) return rec.class.isA[name] == true end

	local function makeInstance(name, internal)
		local info = classInfo(name)
		if not info then error("Unable to create an Instance of type \"" .. tostring(name) .. "\"", 3) end
		if (info.notCreatable or info.service) and not internal then
			error("Unable to create an Instance of type \"" .. name .. "\"", 3)
		end
		local proxy = setmetatable({}, InstanceMt)
		local rec = {class = info, props = {Name = name}, children = {}, parent = nil, attrs = {}, signals = {},
			propSignals = {}, attrSignals = {}, destroyed = false, parentLocked = false, internal = {}, proxy = proxy, tags = {}}
		recs[proxy] = rec
		engine.instanceCount += 1
		engine.created += 1
		local init = defaults[name]
		if init then init(rec) end
		for _, ancestor in ipairs({"BasePart", "GuiObject", "LayerCollector"}) do
			if name ~= ancestor and info.isA[ancestor] and defaults[ancestor] then defaults[ancestor](rec) end
		end
		return proxy, rec
	end
	engine.makeInstance = makeInstance

	local function eventSignal(rec, name)
		local s = rec.signals[name]
		if not s then s = newSignal(rec.class.name .. "." .. name); rec.signals[name] = s end
		return s
	end
	engine.eventSignal = function(inst, name) return eventSignal(recs[inst], name) end

	local function descendants(rec, into)
		into = into or {}
		for _, child in ipairs(rec.children) do
			table.insert(into, child)
			descendants(recs[child], into)
		end
		return into
	end

	local function setParent(rec, newParent)
		if rec.parentLocked then
			error("The Parent property of " .. rec.props.Name .. " is locked, current parent: NULL, new parent " .. (newParent and recs[newParent].props.Name or "NULL"), 3)
		end
		if newParent ~= nil then
			local target = recs[newParent]
			if not target then error("Parent must be an Instance", 3) end
			if newParent == rec.proxy then error("Attempt to set " .. rec.props.Name .. " as its own parent", 3) end
			local r = target
			while r do
				if r == rec then error("Attempt to set parent of " .. rec.props.Name .. " to " .. target.props.Name .. " would result in circular reference", 3) end
				r = r.parent and recs[r.parent]
			end
			if target.destroyed then error("The Parent property of " .. target.props.Name .. " is locked", 3) end
		end
		local old = rec.parent
		if old == newParent then return end
		local moving = {rec.proxy}
		descendants(rec, moving)
		if old then
			local oldRec = recs[old]
			local index = table.find(oldRec.children, rec.proxy)
			if index then table.remove(oldRec.children, index) end
			local a = oldRec
			while a do
				for _, item in ipairs(moving) do fire(a.signals.DescendantRemoving, item) end
				a = a.parent and recs[a.parent]
			end
			fire(oldRec.signals.ChildRemoved, rec.proxy)
		end
		rec.parent = newParent
		if newParent then
			local target = recs[newParent]
			table.insert(target.children, rec.proxy)
			fire(target.signals.ChildAdded, rec.proxy)
			local a = target
			while a do
				for _, item in ipairs(moving) do fire(a.signals.DescendantAdded, item) end
				a = a.parent and recs[a.parent]
			end
		end
		for _, item in ipairs(moving) do fire(recs[item].signals.AncestryChanged, rec.proxy, newParent) end
		fire(rec.propSignals.Parent)
		fire(rec.signals.Changed, "Parent")
	end

	local function findChild(rec, name)
		for _, child in ipairs(rec.children) do
			if recs[child].props.Name == name then return child end
		end
		return nil
	end

	----------------------------------------------------------------- value validation
	local DATATYPES_ACCEPTING_STRING = {Content = true, ContentId = true}
	local function checkValue(rec, key, meta, value)
		local cat, kind = meta.cat, meta.type
		if cat == "P" then
			if kind == "bool" then if type(value) ~= "boolean" then return false end
			elseif kind == "string" or kind == "Content" then if type(value) ~= "string" then return false end
			elseif kind == "int" or kind == "int64" or kind == "float" or kind == "double" then
				if type(value) ~= "number" then return false end
			end
			return true
		elseif cat == "D" then
			if DATATYPES_ACCEPTING_STRING[kind] and type(value) == "string" then return true end
			if kind == "Content" then return type(value) == "string" or typeof(value) == "Content" end
			return typeof(value) == kind
		elseif cat == "E" then
			if typeof(value) == "EnumItem" then return rawget(value, "EnumType")._name == kind end
			local enum = enumOf(kind)
			if type(value) == "number" then return enum and enum:FromValue(value) ~= nil end
			if type(value) == "string" then return enum and rawget(enum, "_items")[value] ~= nil end
			return false
		elseif cat == "C" then
			if value == nil then return true end
			local target = recs[value]
			return target ~= nil and target.class.isA[kind] == true
		elseif cat == "F" then
			return value == nil or type(value) == "function"
		end
		return true
	end
	local function coerceEnum(meta, value)
		if meta.cat == "E" and typeof(value) ~= "EnumItem" then
			local enum = enumOf(meta.type)
			if type(value) == "number" then return enum:FromValue(value) end
			return rawget(enum, "_items")[value]
		end
		return value
	end

	local function defaultFor(meta)
		local cat, kind = meta.cat, meta.type
		if cat == "P" then
			if kind == "bool" then return false end
			if kind == "string" or kind == "Content" then return "" end
			return 0
		elseif cat == "D" then
			if kind == "Vector3" then return DT.Vector3.zero end
			if kind == "Vector2" then return DT.Vector2.zero end
			if kind == "CFrame" then return DT.CFrame.identity end
			if kind == "Color3" then return DT.Color3.new(1, 1, 1) end
			if kind == "UDim2" then return DT.UDim2.new(0, 0, 0, 0) end
			if kind == "UDim" then return DT.UDim.new(0, 0) end
			if kind == "NumberRange" then return DT.NumberRange.new(0) end
			if kind == "NumberSequence" then return DT.NumberSequence.new(0) end
			if kind == "ColorSequence" then return DT.ColorSequence.new(DT.Color3.new(1, 1, 1)) end
			if kind == "Content" or kind == "ContentId" then return "" end
			return nil
		elseif cat == "E" then
			local enum = enumOf(kind)
			return enum and rawget(enum, "_order")[1]
		end
		return nil
	end

	local function propChanged(rec, key)
		fire(rec.propSignals[key])
		fire(rec.signals.Changed, key)
	end
	local function rawSet(rec, key, value)
		local old = rec.props[key]
		rec.props[key] = value
		rec.explicit = rec.explicit or {}
		rec.explicit[key] = true
		if old ~= value then propChanged(rec, key) end
	end
	engine.setInternal = function(inst, key, value) rawSet(recs[inst], key, value) end
	engine.getInternal = function(inst, key) return recs[inst].props[key] end

	local function getProperty(rec, key, meta)
		if meta.unreadable then error(key .. " is not a valid member of " .. rec.class.name .. " (restricted)", 3) end
		local getter = getters[key]
		if getter then
			local handled, value = getter(rec)
			if handled then return value end
		end
		local value = rec.props[key]
		if value == nil and not (rec.explicit and rec.explicit[key]) then
			value = defaultFor(meta)
			if value ~= nil then rec.props[key] = value end
		end
		return value
	end

	InstanceMt.__typename = "Instance"
	InstanceMt.__index = function(self, key)
		local rec = recs[self]
		if type(key) ~= "string" then error("invalid index", 2) end
		local meta = rec.class.props[key]
		if meta then return getProperty(rec, key, meta) end
		local override = classMethods[rec.class.name] and classMethods[rec.class.name][key]
		if not override then
			for ancestor in pairs(rec.class.isA) do
				local list = classMethods[ancestor]
				if list and list[key] then override = list[key]; break end
			end
		end
		if override then return override end
		if rec.class.funcs[key] then
			return methods[key] or function(this, ...)
				local name = rec.class.name .. "." .. key
				engine.calls[name] = (engine.calls[name] or 0) + 1
				if key == "LogOnboardingFunnelStepEvent" or string.sub(key, 1, 3) == "Log" then
					table.insert(engine.analytics, {method = key, args = table.pack(...)})
				end
				return nil
			end
		end
		if rec.class.events[key] then return eventSignal(rec, key) end
		local child = findChild(rec, key)
		if child then return child end
		error(key .. " is not a valid member of " .. rec.class.name .. " \"" .. fullName(rec) .. "\"", 2)
	end
	InstanceMt.__newindex = function(self, key, value)
		local rec = recs[self]
		local meta = rec.class.props[key]
		if not meta then error(tostring(key) .. " is not a valid member of " .. rec.class.name .. " \"" .. fullName(rec) .. "\"", 2) end
		if meta.readOnly then error("Unable to assign property " .. key .. ". Property is read only", 2) end
		if key == "Parent" then setParent(rec, value); return end
		if not checkValue(rec, key, meta, value) then
			error(string.format("Unable to assign property %s. %s expected, got %s", key, meta.type, typeof(value)), 2)
		end
		if type(value) == "number" and value ~= value and meta.cat == "P" and meta.type ~= "string" then
			record("warnings", "NaN assigned to " .. rec.class.name .. "." .. key .. " at " .. fullName(rec))
		end
		value = coerceEnum(meta, value)
		local setter = setters[key]
		if setter and setter(rec, value) then return end
		rawSet(rec, key, value)
	end
	InstanceMt.__tostring = function(self) return recs[self].props.Name end
	InstanceMt.__eq = rawequal

	----------------------------------------------------------------- getters/setters
	local function partCFrame(rec) return rec.props.CFrame or DT.CFrame.identity end
	getters.Position = function(rec)
		if isA(rec, "BasePart") then return true, partCFrame(rec).Position end
		return false
	end
	setters.Position = function(rec, value)
		if not isA(rec, "BasePart") then return false end
		local c = partCFrame(rec)
		rawSet(rec, "CFrame", DT.cf(value.X, value.Y, value.Z, c._r))
		propChanged(rec, "Position")
		return true
	end
	setters.CFrame = function(rec, value)
		if not isA(rec, "BasePart") then return false end
		rawSet(rec, "CFrame", value)
		return true
	end
	getters.Parent = function(rec) return true, rec.parent end
	getters.ClassName = function(rec) return true, rec.class.name end
	getters.LocalPlayer = function(rec)
		if rec.class.name ~= "Players" then return false end
		local ctx = currentContext()
		return true, ctx.player
	end
	local function absoluteSize(rec)
		if rec.class.isA.LayerCollector then return DT.Vector2.new(1280, 720) end
		if rec.class.name == "Camera" then return DT.Vector2.new(1280, 720) end
		local parentRec = rec.parent and recs[rec.parent]
		local parentSize = if parentRec and (parentRec.class.isA.GuiBase2d) then absoluteSize(parentRec) else DT.Vector2.new(1280, 720)
		local size = rec.props.Size
		if typeof(size) ~= "UDim2" then return parentSize end
		return DT.Vector2.new(parentSize.X * size.X.Scale + size.X.Offset, parentSize.Y * size.Y.Scale + size.Y.Offset)
	end
	getters.AbsoluteSize = function(rec)
		if rec.class.isA.GuiBase2d then return true, absoluteSize(rec) end
		return false
	end
	getters.ViewportSize = function(rec)
		if rec.class.name == "Camera" then return true, DT.Vector2.new(1280, 720) end
		return false
	end

	local WHITE_TRUE = {"Visible", "Enabled", "Archivable", "AutoButtonColor", "ResetOnSpawn", "RespectFilteringEnabled"}
	defaults.Instance = nil
	defaults.BasePart = function(rec)
		rec.props.Size = DT.Vector3.new(4, 1.2, 2); rec.props.CFrame = DT.CFrame.identity
		rec.props.CanCollide = true; rec.props.CanTouch = true; rec.props.CanQuery = true; rec.props.CastShadow = true
		rec.props.Color = DT.Color3.fromRGB(163, 162, 165); rec.props.Locked = false
	end
	defaults.GuiObject = function(rec)
		rec.props.Visible = true; rec.props.BackgroundTransparency = 0; rec.props.Size = DT.UDim2.new(0, 100, 0, 100)
		rec.props.BackgroundColor3 = DT.Color3.fromRGB(163, 162, 165); rec.props.Active = false
	end
	defaults.LayerCollector = function(rec) rec.props.Enabled = true; rec.props.ResetOnSpawn = true end
	defaults.Humanoid = function(rec)
		rec.props.Health = 100; rec.props.MaxHealth = 100; rec.props.WalkSpeed = 16; rec.props.JumpPower = 50
		rec.props.MoveDirection = DT.Vector3.zero
	end
	defaults.Sound = function(rec) rec.props.Volume = 0.5; rec.props.PlaybackSpeed = 1 end
	defaults.Camera = function(rec) rec.props.FieldOfView = 70 end
	for _, className in ipairs({"ParticleEmitter", "Trail", "Beam", "PointLight", "SpotLight", "SurfaceLight", "Highlight",
		"BillboardGui", "SurfaceGui", "ScreenGui", "ProximityPrompt", "UIStroke"}) do
		local previous = defaults[className]
		defaults[className] = function(rec) if previous then previous(rec) end rec.props.Enabled = true end
	end
	engine.defaultsTrue = WHITE_TRUE

	----------------------------------------------------------------- generic methods
	local function self_(proxy, method)
		local rec = recs[proxy]
		if not rec then error("Expected ':' not '.' calling member function " .. method, 3) end
		return rec
	end
	function methods.FindFirstChild(proxy, name, recursive)
		local rec = self_(proxy, "FindFirstChild")
		local child = findChild(rec, name)
		if child or not recursive then return child end
		for _, d in ipairs(descendants(rec)) do if recs[d].props.Name == name then return d end end
		return nil
	end
	function methods.FindFirstChildOfClass(proxy, name)
		for _, child in ipairs(self_(proxy, "FindFirstChildOfClass").children) do
			if recs[child].class.name == name then return child end
		end
		return nil
	end
	function methods.FindFirstChildWhichIsA(proxy, name, recursive)
		local rec = self_(proxy, "FindFirstChildWhichIsA")
		local list = if recursive then descendants(rec) else rec.children
		for _, child in ipairs(list) do if isA(recs[child], name) then return child end end
		return nil
	end
	function methods.FindFirstDescendant(proxy, name)
		for _, d in ipairs(descendants(self_(proxy, "FindFirstDescendant"))) do if recs[d].props.Name == name then return d end end
		return nil
	end
	local function ancestorWhere(proxy, predicate)
		local r = recs[proxy]
		local p = r.parent
		while p do
			if predicate(recs[p]) then return p end
			p = recs[p].parent
		end
		return nil
	end
	function methods.FindFirstAncestor(proxy, name) return ancestorWhere(proxy, function(r) return r.props.Name == name end) end
	function methods.FindFirstAncestorOfClass(proxy, name) return ancestorWhere(proxy, function(r) return r.class.name == name end) end
	function methods.FindFirstAncestorWhichIsA(proxy, name) return ancestorWhere(proxy, function(r) return isA(r, name) end) end
	function methods.WaitForChild(proxy, name, timeout)
		local rec = self_(proxy, "WaitForChild")
		local found = findChild(rec, name)
		if found then return found end
		local started, warned = engine.now, false
		while true do
			sleep(0)
			found = findChild(rec, name)
			if found then return found end
			if timeout and engine.now - started >= timeout then return nil end
			if not timeout and not warned and engine.now - started >= 5 then
				warned = true
				record("warnings", "Infinite yield possible on '" .. fullName(rec) .. ":WaitForChild(\"" .. name .. "\")'")
			end
		end
	end
	function methods.GetChildren(proxy) return table.clone(self_(proxy, "GetChildren").children) end
	function methods.GetDescendants(proxy) return descendants(self_(proxy, "GetDescendants")) end
	function methods.IsA(proxy, name) return isA(self_(proxy, "IsA"), name) end
	function methods.IsDescendantOf(proxy, other)
		return ancestorWhere(proxy, function(r) return r.proxy == other end) ~= nil
	end
	function methods.IsAncestorOf(proxy, other) return methods.IsDescendantOf(other, proxy) end
	function methods.GetFullName(proxy) return fullName(self_(proxy, "GetFullName")) end
	local function destroy(rec)
		if rec.destroyed then return end
		for _, child in ipairs(table.clone(rec.children)) do destroy(recs[child]) end
		if rec.parent then setParent(rec, nil) end
		rec.destroyed = true; rec.parentLocked = true
		fire(rec.signals.Destroying)
		for _, signal in pairs(rec.signals) do
			for _, c in ipairs(table.clone(signal._connections)) do rawset(c, "Connected", false) end
			signal._connections = {}
		end
		engine.instanceCount -= 1
		engine.destroyedCount += 1
	end
	function methods.Destroy(proxy) destroy(self_(proxy, "Destroy")) end
	methods.Remove = function(proxy) setParent(self_(proxy, "Remove"), nil) end
	function methods.ClearAllChildren(proxy)
		for _, child in ipairs(table.clone(self_(proxy, "ClearAllChildren").children)) do destroy(recs[child]) end
	end
	local function clone(rec)
		if rec.props.Archivable == false then return nil end
		local proxy, copy = makeInstance(rec.class.name, true)
		for k, v in pairs(rec.props) do copy.props[k] = v end
		if rec.explicit then copy.explicit = table.clone(rec.explicit) end
		for k, v in pairs(rec.attrs) do copy.attrs[k] = v end
		for k, v in pairs(rec.internal) do copy.internal[k] = v end
		copy.tags = table.clone(rec.tags)
		for _, child in ipairs(rec.children) do
			local childCopy = clone(recs[child])
			if childCopy then
				local cr = recs[childCopy]
				cr.parent = proxy
				table.insert(copy.children, childCopy)
			end
		end
		-- Object references inside the clone are remapped like Roblox does.
		return proxy
	end
	function methods.Clone(proxy) return clone(self_(proxy, "Clone")) end
	local ATTRIBUTE_TYPES = {["nil"] = true, boolean = true, number = true, string = true, UDim = true, UDim2 = true,
		BrickColor = true, Color3 = true, Vector2 = true, Vector3 = true, CFrame = true, NumberSequence = true,
		ColorSequence = true, NumberRange = true, Rect = true, Font = true, EnumItem = true}
	function methods.SetAttribute(proxy, name, value)
		local rec = self_(proxy, "SetAttribute")
		if type(name) ~= "string" or #name == 0 or #name > 100 or string.match(name, "[^%w_]") then
			error("Attribute name '" .. tostring(name) .. "' is invalid", 2)
		end
		if string.sub(name, 1, 3) == "RBX" then error("Attribute name reserved", 2) end
		if not ATTRIBUTE_TYPES[typeof(value)] then error("Unable to set attribute " .. name .. ": " .. typeof(value) .. " is not a supported attribute type", 2) end
		local old = rec.attrs[name]
		rec.attrs[name] = value
		if old ~= value then fire(rec.attrSignals[name]); fire(rec.signals.AttributeChanged, name) end
	end
	function methods.GetAttribute(proxy, name) return self_(proxy, "GetAttribute").attrs[name] end
	function methods.GetAttributes(proxy) return table.clone(self_(proxy, "GetAttributes").attrs) end
	function methods.GetAttributeChangedSignal(proxy, name)
		local rec = self_(proxy, "GetAttributeChangedSignal")
		rec.attrSignals[name] = rec.attrSignals[name] or newSignal("AttributeChanged:" .. name)
		return rec.attrSignals[name]
	end
	function methods.GetPropertyChangedSignal(proxy, name)
		local rec = self_(proxy, "GetPropertyChangedSignal")
		if not rec.class.props[name] then error(tostring(name) .. " is not a valid property name.", 2) end
		rec.propSignals[name] = rec.propSignals[name] or newSignal("Changed:" .. name)
		return rec.propSignals[name]
	end
	function methods.AddTag(proxy, tag) self_(proxy, "AddTag").tags[tag] = true end
	function methods.RemoveTag(proxy, tag) self_(proxy, "RemoveTag").tags[tag] = nil end
	function methods.HasTag(proxy, tag) return self_(proxy, "HasTag").tags[tag] == true end
	function methods.GetTags(proxy) local t = {}; for k in pairs(self_(proxy, "GetTags").tags) do table.insert(t, k) end; return t end
	function methods.GetActor() return nil end

	-- PVInstance / Model / BasePart geometry
	local function parts(rec)
		local list = {}
		if isA(rec, "BasePart") then table.insert(list, rec) end
		for _, d in ipairs(descendants(rec)) do local r = recs[d]; if isA(r, "BasePart") then table.insert(list, r) end end
		return list
	end
	local function boundingBox(rec)
		local list = parts(rec)
		if #list == 0 then return DT.CFrame.identity, DT.Vector3.zero end
		local minX, minY, minZ, maxX, maxY, maxZ = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
		for _, part in ipairs(list) do
			local c, s = partCFrame(part), part.props.Size
			local r = c._r
			local hx = math.abs(r[1]) * s.X / 2 + math.abs(r[2]) * s.Y / 2 + math.abs(r[3]) * s.Z / 2
			local hy = math.abs(r[4]) * s.X / 2 + math.abs(r[5]) * s.Y / 2 + math.abs(r[6]) * s.Z / 2
			local hz = math.abs(r[7]) * s.X / 2 + math.abs(r[8]) * s.Y / 2 + math.abs(r[9]) * s.Z / 2
			minX = math.min(minX, c.X - hx); maxX = math.max(maxX, c.X + hx)
			minY = math.min(minY, c.Y - hy); maxY = math.max(maxY, c.Y + hy)
			minZ = math.min(minZ, c.Z - hz); maxZ = math.max(maxZ, c.Z + hz)
		end
		return DT.CFrame.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2), DT.Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
	end
	local function pivotOf(rec)
		if isA(rec, "BasePart") then return partCFrame(rec) end
		local primary = rec.props.PrimaryPart
		if primary and recs[primary] then return partCFrame(recs[primary]) end
		if rec.props.WorldPivot and rec.explicit and rec.explicit.WorldPivot then return rec.props.WorldPivot end
		return (boundingBox(rec))
	end
	function methods.GetPivot(proxy) return pivotOf(self_(proxy, "GetPivot")) end
	function methods.PivotTo(proxy, target)
		local rec = self_(proxy, "PivotTo")
		if typeof(target) ~= "CFrame" then error("Unable to cast to CFrame", 2) end
		local current = pivotOf(rec)
		local delta = target * current:Inverse()
		for _, part in ipairs(parts(rec)) do rawSet(part, "CFrame", delta * partCFrame(part)) end
		if not isA(rec, "BasePart") then rec.props.WorldPivot = target; rec.explicit = rec.explicit or {}; rec.explicit.WorldPivot = true end
	end
	methods.SetPrimaryPartCFrame = methods.PivotTo
	function methods.GetPrimaryPartCFrame(proxy) return pivotOf(self_(proxy, "GetPrimaryPartCFrame")) end
	function methods.GetBoundingBox(proxy) return boundingBox(self_(proxy, "GetBoundingBox")) end
	function methods.GetExtentsSize(proxy) local _, s = boundingBox(self_(proxy, "GetExtentsSize")); return s end
	function methods.ScaleTo(proxy, factor)
		local rec = self_(proxy, "ScaleTo")
		if type(factor) ~= "number" or factor <= 0 then error("Model:ScaleTo scale must be positive", 2) end
		local current = rec.internal.scale or 1
		local ratio = factor / current
		local pivot = pivotOf(rec)
		for _, part in ipairs(parts(rec)) do
			local c = partCFrame(part)
			local offset = pivot:PointToObjectSpace(c.Position) * ratio
			local position = pivot:PointToWorldSpace(offset)
			rawSet(part, "CFrame", DT.cf(position.X, position.Y, position.Z, c._r))
			part.props.Size = part.props.Size * ratio
		end
		rec.internal.scale = factor
	end
	function methods.GetScale(proxy) return self_(proxy, "GetScale").internal.scale or 1 end
	function methods.MoveTo(proxy, position)
		local rec = self_(proxy, "MoveTo")
		if isA(rec, "Humanoid") then rec.internal.moveTarget = position; return end
		methods.PivotTo(proxy, DT.CFrame.new(position))
	end
	function methods.GetMass(proxy) local s = self_(proxy, "GetMass").props.Size; return s.X * s.Y * s.Z * 0.7 end
	function methods.GetNetworkOwner() return nil end

	----------------------------------------------------------------- DataModel and services
	local game, gameRec = makeInstance("DataModel", true)
	gameRec.props.Name = "Game"
	engine.game = game
	local services = {}
	local function getService(name)
		if services[name] then return services[name] end
		local info = classInfo(name)
		if not info or not info.service then error("'" .. tostring(name) .. "' is not a valid Service name", 3) end
		local proxy, rec = makeInstance(name, true)
		rec.props.Name = name
		services[name] = proxy
		setParent(rec, game)
		return proxy
	end
	engine.service = getService
	classMethods.DataModel = {
		GetService = function(_, name) return getService(name) end,
		FindService = function(_, name) return services[name] end,
		BindToClose = function(_, fn) table.insert(engine.closeHandlers, {fn = fn, ctx = currentContext()}) end,
		IsLoaded = function() return true end,
	}
	engine.closeHandlers = {}
	gameRec.props.JobId = "fake-job-0001"; gameRec.props.PlaceId = options.placeId or 127090454461830
	gameRec.props.GameId = 10769277416; gameRec.explicit = {JobId = true, PlaceId = true, GameId = true}

	local workspace = getService("Workspace")
	local camera, cameraRec = makeInstance("Camera", true)
	cameraRec.props.Name = "Camera"
	setParent(cameraRec, workspace)
	recs[workspace].props.CurrentCamera = camera
	recs[workspace].props.Gravity = 196.2
	engine.workspace = workspace
	for _, name in ipairs({"Players", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "Lighting", "StarterGui",
		"StarterPack", "StarterPlayer", "SoundService", "RunService", "Debris", "TweenService", "HttpService",
		"DataStoreService", "UserInputService", "ContextActionService", "GuiService", "AnalyticsService", "BadgeService",
		"CollectionService", "TextService", "MarketplaceService"}) do getService(name) end
	local starterPlayerScripts, sps = makeInstance("StarterPlayerScripts", true)
	sps.props.Name = "StarterPlayerScripts"
	setParent(sps, services.StarterPlayer)
	local lightingRec = recs[services.Lighting]
	lightingRec.props.Brightness = 2; lightingRec.props.ClockTime = 14

	local Players = services.Players
	local RunService = services.RunService
	classMethods.RunService = {
		IsStudio = function() return engine.studio end,
		IsServer = function() return currentContext().kind == "server" end,
		IsClient = function() return currentContext().kind == "client" end,
		IsRunning = function() return true end,
		IsRunMode = function() return false end,
		IsEdit = function() return false end,
		BindToRenderStep = function(_, name, _priority, fn) engine.renderSteps[name] = {fn = fn, ctx = currentContext()} end,
		UnbindFromRenderStep = function(_, name) engine.renderSteps[name] = nil end,
	}
	engine.renderSteps = {}

	-- Players
	local players = {}
	engine.players = players
	classMethods.Players = {
		GetPlayers = function()
			local list = {}
			for _, child in ipairs(recs[Players].children) do if recs[child].class.name == "Player" then table.insert(list, child) end end
			return list
		end,
		GetPlayerByUserId = function(_, id)
			for _, p in ipairs(players) do if recs[p].props.UserId == id and p.Parent == Players then return p end end
			return nil
		end,
		GetPlayerFromCharacter = function(_, character)
			for _, p in ipairs(players) do if recs[p].props.Character == character then return p end end
			return nil
		end,
		GetNameFromUserIdAsync = function(_, id)
			sleep(0)
			if type(id) ~= "number" then error("Unable to cast to int64", 2) end
			return "Player" .. tostring(id)
		end,
	}
	classMethods.Player = {
		Kick = function(proxy, message)
			table.insert(engine.kicks, {userId = recs[proxy].props.UserId, message = message})
			engine.removePlayer(proxy)
		end,
		LoadCharacter = function(proxy) engine.spawnCharacter(proxy) end,
		IsInGroup = function() return false end,
		GetRankInGroup = function() return 0 end,
		GetMouse = function() return nil end,
	}

	----------------------------------------------------------------- remotes
	local function payloadCopy(value, path, seen, issues)
		local t = typeof(value)
		if t == "function" or t == "thread" then
			table.insert(issues, path .. ": " .. t .. " cannot be sent (becomes nil)")
			return nil
		end
		if t ~= "table" then return value end
		if seen[value] then table.insert(issues, path .. ": cyclic table cannot be sent"); return nil end
		seen[value] = true
		local count, maxIndex, stringKeys, otherKeys = 0, 0, 0, 0
		for k in pairs(value) do
			count += 1
			if type(k) == "number" and k >= 1 and k % 1 == 0 then maxIndex = math.max(maxIndex, k)
			elseif type(k) == "string" then stringKeys += 1
			else otherKeys += 1 end
		end
		local arrayCount = count - stringKeys - otherKeys
		if stringKeys > 0 and arrayCount > 0 then table.insert(issues, path .. ": mixed array/dictionary table loses keys over a remote") end
		if otherKeys > 0 then table.insert(issues, path .. ": non-string, non-index keys are not supported") end
		if stringKeys == 0 and arrayCount > 0 and maxIndex ~= arrayCount then
			table.insert(issues, path .. ": sparse array (holes) truncates over a remote")
		end
		if getmetatable(value) ~= nil then table.insert(issues, path .. ": metatable is dropped") end
		local copy = {}
		for k, v in pairs(value) do copy[k] = payloadCopy(v, path .. "." .. tostring(k), seen, issues) end
		seen[value] = nil
		return copy
	end
	local function copyArgs(label, ...)
		local args = table.pack(...)
		local issues = {}
		for i = 1, args.n do args[i] = payloadCopy(args[i], label .. "[" .. i .. "]", {}, issues) end
		for _, issue in ipairs(issues) do
			if not engine.remoteIssueSeen then engine.remoteIssueSeen = {} end
			if not engine.remoteIssueSeen[issue] then engine.remoteIssueSeen[issue] = true; table.insert(engine.remoteIssues, issue) end
		end
		return args
	end
	engine.remoteLog = {}
	local function clientSignal(rec, player)
		rec.internal.clientSignals = rec.internal.clientSignals or {}
		local s = rec.internal.clientSignals[player]
		if not s then s = newSignal("OnClientEvent"); rec.internal.clientSignals[player] = s end
		return s
	end
	getters.OnClientEvent = nil
	classMethods.RemoteEvent = {
		FireServer = function(proxy, ...)
			local ctx = currentContext()
			if ctx.kind ~= "client" then error("FireServer can only be called from the client", 2) end
			local args = copyArgs(recs[proxy].props.Name .. ":FireServer", ...)
			fire(eventSignal(recs[proxy], "OnServerEvent"), ctx.player, table.unpack(args, 1, args.n))
		end,
		FireClient = function(proxy, player, ...)
			if currentContext().kind ~= "server" then error("FireClient can only be called from the server", 2) end
			if not recs[player] or recs[player].class.name ~= "Player" then error("FireClient: player argument must be a Player object", 2) end
			local rec = recs[proxy]
			local args = copyArgs(rec.props.Name .. ":FireClient", ...)
			local log = engine.remoteLog
			engine.remoteSeq = (engine.remoteSeq or 0) + 1
			table.insert(log, {remote = rec.props.Name, player = player, args = args, at = engine.now, seq = engine.remoteSeq})
			if #log > 4000 then table.remove(log, 1) end
			fire(clientSignal(rec, player), table.unpack(args, 1, args.n))
		end,
		FireAllClients = function(proxy, ...)
			for _, p in ipairs(classMethods.Players.GetPlayers()) do classMethods.RemoteEvent.FireClient(proxy, p, ...) end
		end,
	}
	-- UnreliableRemoteEvent: same routing, but Roblox drops payloads over ~900 bytes.
	local function payloadBytes(args)
		local total = 0
		local function measure(v)
			local t = type(v)
			if t == "buffer" then total += buffer.len(v)
			elseif t == "string" then total += #v
			elseif t == "number" then total += 8
			elseif t == "table" then for k, x in pairs(v) do measure(k); measure(x) end
			else total += 1 end
		end
		for i = 1, args.n do measure(args[i]) end
		return total
	end
	engine.unreliableDropped = 0
	classMethods.UnreliableRemoteEvent = {
		FireServer = classMethods.RemoteEvent.FireServer,
		FireClient = function(proxy, player, ...)
			local args = table.pack(...)
			if payloadBytes(args) > 900 then
				engine.unreliableDropped += 1
				local issue = recs[proxy].props.Name .. ": unreliable payload over 900 bytes is dropped"
				if not engine.remoteIssueSeen then engine.remoteIssueSeen = {} end
				if not engine.remoteIssueSeen[issue] then engine.remoteIssueSeen[issue] = true; table.insert(engine.remoteIssues, issue) end
				return
			end
			classMethods.RemoteEvent.FireClient(proxy, player, ...)
		end,
		FireAllClients = function(proxy, ...)
			for _, p in ipairs(classMethods.Players.GetPlayers()) do classMethods.UnreliableRemoteEvent.FireClient(proxy, p, ...) end
		end,
	}
	-- OnClientEvent depends on which client is asking.
	local baseIndex = InstanceMt.__index
	InstanceMt.__index = function(self, key)
		if key == "OnClientEvent" then
			local rec = recs[self]
			if rec.class.name == "RemoteEvent" or rec.class.name == "UnreliableRemoteEvent" then
				local ctx = currentContext()
				if ctx.kind ~= "client" then return eventSignal(rec, "OnClientEventServerSide") end
				return clientSignal(rec, ctx.player)
			end
		end
		return baseIndex(self, key)
	end
	engine.clientFire = function(player, remote, ...)
		local ctx = {kind = "client", player = player}
		local results
		local co = coroutine.create(function(...) results = table.pack(pcall(remote.FireServer, remote, ...)) end)
		threadContext[co] = ctx
		resume(co, ...)
		if results and not results[1] then error(results[2], 2) end
	end
	classMethods.BindableEvent = {Fire = function(proxy, ...) fire(eventSignal(recs[proxy], "Event"), ...) end}

	----------------------------------------------------------------- data stores
	local stores = {}
	engine.stores = stores
	engine.storeFailures = 0
	local function storeFor(kind, name, scope)
		local key = kind .. ":" .. name .. ":" .. tostring(scope or "global")
		if stores[key] then return stores[key] end
		local proxy, rec = makeInstance(if kind == "ordered" then "OrderedDataStore" else "DataStore", true)
		rec.props.Name = name
		rec.internal.values = {}
		stores[key] = proxy
		return proxy
	end
	local function maybeFail()
		sleep(0)
		if engine.storeFailures > 0 then
			engine.storeFailures -= 1
			error("502: API Services rejected request (injected)", 3)
		end
	end
	local function deep(v) if type(v) ~= "table" then return v end local c = {}; for k, x in pairs(v) do c[k] = deep(x) end; return c end
	local function storeMethods()
		return {
			GetAsync = function(proxy, key) maybeFail(); return deep(recs[proxy].internal.values[key]) end,
			SetAsync = function(proxy, key, value) maybeFail(); recs[proxy].internal.values[key] = deep(value) end,
			RemoveAsync = function(proxy, key) maybeFail(); local v = recs[proxy].internal.values[key]; recs[proxy].internal.values[key] = nil; return v end,
			IncrementAsync = function(proxy, key, delta)
				maybeFail(); local values = recs[proxy].internal.values
				values[key] = (values[key] or 0) + (delta or 1); return values[key]
			end,
			UpdateAsync = function(proxy, key, transform)
				maybeFail()
				local values = recs[proxy].internal.values
				local result = transform(deep(values[key]), nil)
				if result ~= nil then
					local issues = {}
					payloadCopy(result, "DataStore[" .. key .. "]", {}, issues)
					for _, issue in ipairs(issues) do table.insert(engine.remoteIssues, issue) end
					values[key] = deep(result)
				end
				return deep(values[key]), nil
			end,
			GetSortedAsync = function(proxy, ascending, pageSize)
				maybeFail()
				local rows = {}
				for k, v in pairs(recs[proxy].internal.values) do table.insert(rows, {key = k, value = v}) end
				table.sort(rows, function(a, b)
					if a.value == b.value then return a.key < b.key end
					if ascending then return a.value < b.value end
					return a.value > b.value
				end)
				local page = {}
				for i = 1, math.min(#rows, pageSize or 50) do page[i] = rows[i] end
				local pages, pagesRec = makeInstance("DataStorePages", true)
				pagesRec.internal.page = page
				pagesRec.props.IsFinished = #rows <= (pageSize or 50)
				return pages
			end,
		}
	end
	classMethods.DataStore = storeMethods()
	classMethods.OrderedDataStore = storeMethods()
	classMethods.DataStorePages = {
		GetCurrentPage = function(proxy) return recs[proxy].internal.page end,
		AdvanceToNextPageAsync = function(proxy) recs[proxy].internal.page = {}; recs[proxy].props.IsFinished = true end,
	}
	classMethods.DataStoreService = {
		GetDataStore = function(_, name, scope) return storeFor("global", name, scope) end,
		GetOrderedDataStore = function(_, name, scope) return storeFor("ordered", name, scope) end,
		GetGlobalDataStore = function() return storeFor("global", "__global") end,
	}

	----------------------------------------------------------------- misc services
	local guid = 0
	classMethods.HttpService = {
		GenerateGUID = function(_, wrap)
			guid += 1
			local id = string.format("%08X-0000-4000-8000-%012X", guid, guid)
			return if wrap == false then id else "{" .. id .. "}"
		end,
		JSONEncode = function(_, value)
			local function encode(v)
				local t = type(v)
				if t == "nil" then return "null" elseif t == "boolean" or t == "number" then return tostring(v)
				elseif t == "string" then return string.format("%q", v)
				elseif t == "table" then
					if #v > 0 then local parts = {}; for _, x in ipairs(v) do table.insert(parts, encode(x)) end; return "[" .. table.concat(parts, ",") .. "]" end
					local parts = {}
					for k, x in pairs(v) do table.insert(parts, string.format("%q", tostring(k)) .. ":" .. encode(x)) end
					return "{" .. table.concat(parts, ",") .. "}"
				end
				error("Can't convert to JSON", 3)
			end
			return encode(value)
		end,
	}
	classMethods.Debris = {AddItem = function(_, item, lifetime)
		task.delay(lifetime or 10, function()
			local rec = recs[item]
			if rec and not rec.destroyed then destroy(rec) end
		end)
	end}
	classMethods.TweenService = {
		Create = function(_, instance, info, goals)
			if not recs[instance] then error("TweenService:Create instance expected", 2) end
			if typeof(info) ~= "TweenInfo" then error("TweenService:Create TweenInfo expected", 2) end
			for key, value in pairs(goals) do
				local meta = recs[instance].class.props[key]
				if not meta or meta.readOnly then error("TweenService:Create property " .. tostring(key) .. " is not tweenable", 2) end
				if not checkValue(recs[instance], key, meta, value) then error("TweenService:Create property " .. key .. " type mismatch", 2) end
			end
			local tween, tweenRec = makeInstance("Tween", true)
			tweenRec.internal.target = instance; tweenRec.internal.goals = goals; tweenRec.internal.info = info
			return tween
		end,
		GetValue = function(_, alpha) return alpha end,
	}
	classMethods.Tween = {
		Play = function(proxy)
			local rec = recs[proxy]
			local target = recs[rec.internal.target]
			rec.internal.serial = (rec.internal.serial or 0) + 1
			local serial = rec.internal.serial
			task.delay(rec.internal.info.Time, function()
				if rec.internal.serial ~= serial or not target or target.destroyed then return end
				for key, value in pairs(rec.internal.goals) do
					local setter = setters[key]
					if not (setter and setter(target, value)) then rawSet(target, key, value) end
				end
				fire(eventSignal(rec, "Completed"), EnumGlobal.PlaybackState.Completed)
			end)
		end,
		Cancel = function(proxy) local rec = recs[proxy]; rec.internal.serial = (rec.internal.serial or 0) + 1 end,
		Pause = function(proxy) local rec = recs[proxy]; rec.internal.serial = (rec.internal.serial or 0) + 1 end,
	}
	classMethods.UserInputService = {
		GetLastInputType = function() return engine.lastInputType or EnumGlobal.UserInputType.Keyboard end,
		GetFocusedTextBox = function() return nil end,
		IsKeyDown = function() return false end,
		GetConnectedGamepads = function() return {} end,
		GetGamepadConnected = function() return false end,
	}
	recs[services.UserInputService].props.KeyboardEnabled = true
	recs[services.UserInputService].props.MouseEnabled = true
	engine.boundActions = {}
	classMethods.ContextActionService = {
		BindAction = function(_, name, fn, _touch, ...)
			engine.boundActions[name] = {fn = fn, ctx = currentContext(), inputs = {...}}
		end,
		BindActionAtPriority = function(_, name, fn, _touch, _priority, ...)
			engine.boundActions[name] = {fn = fn, ctx = currentContext(), inputs = {...}}
		end,
		UnbindAction = function(_, name) engine.boundActions[name] = nil end,
	}
	classMethods.StarterGui = {
		SetCoreGuiEnabled = function(_, kind, enabled)
			if typeof(kind) ~= "EnumItem" then error("SetCoreGuiEnabled expects CoreGuiType", 2) end
		end,
		SetCore = function() end,
		GetCore = function() return nil end,
	}
	classMethods.Sound = {
		Play = function(proxy) rawSet(recs[proxy], "IsPlaying", true); rawSet(recs[proxy], "Playing", true) end,
		Stop = function(proxy) rawSet(recs[proxy], "IsPlaying", false); rawSet(recs[proxy], "Playing", false) end,
		Pause = function(proxy) rawSet(recs[proxy], "IsPlaying", false) end,
		Resume = function(proxy) rawSet(recs[proxy], "IsPlaying", true) end,
	}
	classMethods.Humanoid = {
		TakeDamage = function(proxy, amount) local rec = recs[proxy]; rawSet(rec, "Health", math.max(0, rec.props.Health - amount)) end,
		ChangeState = function() end,
		GetState = function() return EnumGlobal.HumanoidStateType.Running end,
	}
	classMethods.Camera = {
		WorldToViewportPoint = function(_, v) return DT.Vector3.new(640, 360, v.Z), true end,
		WorldToScreenPoint = function(_, v) return DT.Vector3.new(640, 360, v.Z), true end,
	}
	classMethods.Workspace = {
		GetServerTimeNow = function() return engine.baseTime + engine.now end,
		Raycast = function() return nil end,
	}
	classMethods.BadgeService = {
		AwardBadge = function(_, userId, badgeId) table.insert(engine.analytics, {method = "AwardBadge", args = table.pack(userId, badgeId)}); return true end,
		UserHasBadgeAsync = function() return false end,
	}
	-- Argument shapes follow the documented AnalyticsService signatures.
	local analyticsSignatures = {
		LogOnboardingFunnelStepEvent = function(step, name) return type(step) == "number" and step >= 1 and step % 1 == 0 and (name == nil or type(name) == "string") end,
		LogEconomyEvent = function(flow, currency, amount, balance, transactionType, sku)
			return typeof(flow) == "EnumItem" and rawget(flow, "EnumType")._name == "AnalyticsEconomyFlowType"
				and type(currency) == "string" and type(amount) == "number" and amount == amount and type(balance) == "number"
				and type(transactionType) == "string" and (sku == nil or type(sku) == "string")
		end,
		LogCustomEvent = function(name, value) return type(name) == "string" and (value == nil or type(value) == "number") end,
	}
	classMethods.AnalyticsService = {}
	for _, name in ipairs({"LogOnboardingFunnelStepEvent", "LogEconomyEvent", "LogCustomEvent", "LogProgressionEvent",
		"LogProgressionStartEvent", "LogProgressionCompleteEvent", "LogProgressionFailEvent", "LogFunnelStepEvent"}) do
		classMethods.AnalyticsService[name] = function(_, player, ...)
			if not recs[player] or recs[player].class.name ~= "Player" then error(name .. ": Player expected", 2) end
			local validate = analyticsSignatures[name]
			if validate and not validate(...) then error(name .. ": invalid argument types", 2) end
			table.insert(engine.analytics, {method = name, player = player, args = table.pack(...)})
		end
	end

	----------------------------------------------------------------- players & characters
	local nextPlayer = 0
	function engine.addPlayer(userId, name)
		nextPlayer += 1
		userId = userId or nextPlayer
		local player, rec = makeInstance("Player", true)
		rec.props.Name = name or ("Player" .. tostring(userId))
		rec.props.DisplayName = rec.props.Name
		rec.props.UserId = userId
		rec.explicit = {Character = true}
		for _, child in ipairs({"PlayerGui", "Backpack", "PlayerScripts"}) do
			local inst, childRec = makeInstance(child, true)
			childRec.props.Name = child
			setParent(childRec, player)
		end
		table.insert(players, player)
		setParent(rec, Players)
		fire(eventSignal(recs[Players], "PlayerAdded"), player)
		return player
	end
	function engine.removePlayer(player)
		local rec = recs[player]
		if not rec or rec.parent == nil then return end
		fire(eventSignal(recs[Players], "PlayerRemoving"), player)
		local character = rec.props.Character
		if character and recs[character] then destroy(recs[character]) end
		setParent(rec, nil)
		local index = table.find(players, player)
		if index then table.remove(players, index) end
	end
	function engine.spawnCharacter(player, position)
		local rec = recs[player]
		local old = rec.props.Character
		if old and recs[old] and not recs[old].destroyed then destroy(recs[old]) end
		local model, modelRec = makeInstance("Model", true)
		modelRec.props.Name = rec.props.Name
		local root, rootRec = makeInstance("Part", true)
		rootRec.props.Name = "HumanoidRootPart"; rootRec.props.Size = DT.Vector3.new(2, 2, 1)
		rootRec.props.CFrame = DT.CFrame.new(position or DT.Vector3.new(0, 5, 0)); rootRec.props.Transparency = 1
		setParent(rootRec, model)
		local head, headRec = makeInstance("Part", true)
		headRec.props.Name = "Head"; headRec.props.Size = DT.Vector3.new(2, 1, 1)
		headRec.props.CFrame = rootRec.props.CFrame * DT.CFrame.new(0, 1.5, 0)
		setParent(headRec, model)
		local humanoid, humanoidRec = makeInstance("Humanoid", true)
		humanoidRec.props.Name = "Humanoid"
		setParent(humanoidRec, model)
		modelRec.props.PrimaryPart = root
		setParent(modelRec, workspace)
		rawSet(rec, "Character", model)
		fire(eventSignal(rec, "CharacterAdded"), model)
		return model
	end
	function engine.root(player)
		local character = recs[player].props.Character
		return character and methods.FindFirstChild(character, "HumanoidRootPart")
	end
	-- Moves the root at most `speed` studs/second toward target (no physics).
	function engine.walkToward(player, target, speed, dt)
		local root = engine.root(player)
		if not root then return end
		local rootRec = recs[root]
		local c = partCFrame(rootRec)
		local here = c.Position
		local flat = DT.Vector3.new(target.X - here.X, 0, target.Z - here.Z)
		local distance = flat.Magnitude
		local humanoid = methods.FindFirstChildOfClass(recs[player].props.Character, "Humanoid")
		if distance < 0.05 then
			if humanoid then rawSet(recs[humanoid], "MoveDirection", DT.Vector3.zero) end
			return true
		end
		local step = math.min(distance, speed * dt)
		local direction = flat / distance
		local nextPos = here + direction * step
		rawSet(rootRec, "CFrame", DT.CFrame.lookAt(DT.Vector3.new(nextPos.X, target.Y, nextPos.Z), DT.Vector3.new(nextPos.X, target.Y, nextPos.Z) + direction))
		if humanoid then rawSet(recs[humanoid], "MoveDirection", direction) end
		return distance - step < 0.05
	end

	----------------------------------------------------------------- script loading
	local moduleCache = {server = setmetatable({}, {__mode = "k"})}
	local function baseEnv()
		return {
			game = game, workspace = workspace, Game = game, Workspace = workspace,
			Instance = {new = function(name, parent)
				if type(name) ~= "string" then error("Instance.new expects a class name string", 2) end
				local proxy, rec = makeInstance(name, false)
				if parent ~= nil then setParent(rec, parent) end
				return proxy
			end, fromExisting = function(existing) return clone(recs[existing]) end},
			Vector3 = DT.Vector3, Vector2 = DT.Vector2, CFrame = DT.CFrame, Color3 = DT.Color3, UDim = DT.UDim, UDim2 = DT.UDim2,
			ColorSequence = DT.ColorSequence, ColorSequenceKeypoint = DT.ColorSequenceKeypoint,
			NumberSequence = DT.NumberSequence, NumberSequenceKeypoint = DT.NumberSequenceKeypoint,
			NumberRange = DT.NumberRange, TweenInfo = DT.TweenInfo, Rect = DT.Rect, BrickColor = DT.BrickColor,
			PhysicalProperties = DT.PhysicalProperties, Font = DT.Font, Random = DT.Random,
			DateTime = {now = function() return {UnixTimestamp = engine.baseTime + math.floor(engine.now), UnixTimestampMillis = math.floor((engine.baseTime + engine.now) * 1000)} end},
			Enum = EnumGlobal, task = task, typeof = typeof, os = virtualOs,
			tick = function() return engine.baseTime + engine.now end, time = function() return engine.now end,
			wait = function(t) return sleep(t or 0), engine.now end, delay = task.delay, spawn = task.defer,
			print = function(...)
				local parts = table.pack(...)
				for i = 1, parts.n do parts[i] = tostring(parts[i]) end
				record("output", table.concat(parts, " ", 1, parts.n))
			end,
			warn = function(...)
				local parts = table.pack(...)
				for i = 1, parts.n do parts[i] = tostring(parts[i]) end
				record("warnings", table.concat(parts, " ", 1, parts.n))
			end,
			math = math, string = string, table = table, coroutine = coroutine, utf8 = utf8, bit32 = bit32,
			buffer = buffer, debug = {traceback = debug.traceback, info = debug.info, profilebegin = function() end, profileend = function() end},
			pairs = pairs, ipairs = ipairs, next = next, select = select, type = robloxType, tostring = tostring, tonumber = tonumber,
			pcall = pcall, xpcall = xpcall, error = error, assert = assert, setmetatable = setmetatable, getmetatable = getmetatable,
			rawget = rawget, rawset = rawset, rawequal = rawequal, rawlen = rawlen, unpack = table.unpack, newproxy = newproxy,
			gcinfo = gcinfo, shared = engine.shared, _VERSION = "Luau",
		}
	end
	engine.shared = {}
	local loadModule
	local function makeEnv(scriptProxy, ctx)
		local env = baseEnv()
		env.script = scriptProxy
		env.require = function(target)
			if typeof(target) ~= "Instance" then error("Attempted to call require with invalid argument(s).", 2) end
			return loadModule(target, ctx)
		end
		env._G = engine.globals[ctx.key] or {}
		engine.globals[ctx.key] = env._G
		return env
	end
	engine.globals = {}
	local function compile(rec, ctx)
		local source = rec.internal.source
		if type(source) ~= "string" then error("Script " .. fullName(rec) .. " has no source", 3) end
		local chunk, err = loadstring(source, "@" .. (rec.internal.path or fullName(rec)))
		if not chunk then error("Compile error in " .. fullName(rec) .. ": " .. tostring(err), 3) end
		setfenv(chunk, makeEnv(rec.proxy, ctx))
		return chunk
	end
	loadModule = function(target, ctx)
		local rec = recs[target]
		if rec.class.name ~= "ModuleScript" then error("Attempted to call require with a non-ModuleScript", 3) end
		local cache = moduleCache[ctx.key]
		if not cache then cache = {}; moduleCache[ctx.key] = cache end
		local entry = cache[rec]
		if entry then
			if entry.loading then error("Requested module was required recursively", 3) end
			if entry.failed then error("Requested module experienced an error while loading", 3) end
			return entry.value
		end
		entry = {loading = true}
		cache[rec] = entry
		local chunk = compile(rec, ctx)
		local results = table.pack(pcall(chunk))
		entry.loading = false
		if not results[1] then
			entry.failed = true
			record("errors", "Module " .. fullName(rec) .. " failed: " .. tostring(results[2]))
			error("Requested module experienced an error while loading", 3)
		end
		if results.n ~= 2 then
			entry.failed = true
			error("Module code did not return exactly one value: " .. fullName(rec), 3)
		end
		entry.value = results[2]
		return entry.value
	end
	serverContext.key = "server"

	local function ensureFolder(parent, name)
		local existing = findChild(recs[parent], name)
		if existing then return existing end
		local proxy, rec = makeInstance("Folder", true)
		rec.props.Name = name
		setParent(rec, parent)
		return proxy
	end
	-- sources: { ["ReplicatedStorage/Spark/Config.luau"] = text, ... } relative to game/.
	function engine.mount(sources)
		local paths = {}
		for path in pairs(sources) do table.insert(paths, path) end
		table.sort(paths)
		for _, path in ipairs(paths) do
			local parts = string.split(path, "/")
			local serviceName = table.remove(parts, 1)
			local parent = getService(serviceName)
			if serviceName == "StarterPlayer" then
				local first = table.remove(parts, 1)
				assert(first == "StarterPlayerScripts", "Unsupported StarterPlayer path " .. path)
				parent = starterPlayerScripts
			end
			local fileName = table.remove(parts)
			for _, folder in ipairs(parts) do parent = ensureFolder(parent, folder) end
			local name, class = string.gsub(fileName, "%.luau$", ""), "ModuleScript"
			if string.match(name, "%.server$") then class = "Script"; name = string.gsub(name, "%.server$", "")
			elseif string.match(name, "%.client$") then class = "LocalScript"; name = string.gsub(name, "%.client$", "") end
			local proxy, rec = makeInstance(class, true)
			rec.props.Name = name
			rec.internal.source = sources[path]
			rec.internal.path = "game/" .. path
			setParent(rec, parent)
		end
	end
	local function runScript(rec, ctx)
		local co = coroutine.create(function()
			local chunk = compile(rec, ctx)
			chunk()
		end)
		threadContext[co] = ctx
		resume(co)
	end
	function engine.startServer()
		local list = {}
		for _, d in ipairs(descendants(recs[services.ServerScriptService])) do
			if recs[d].class.name == "Script" then table.insert(list, recs[d]) end
		end
		for _, rec in ipairs(list) do runScript(rec, serverContext) end
	end
	function engine.startClient(player)
		local ctx = {kind = "client", player = player, key = "client:" .. tostring(recs[player].props.UserId)}
		local playerScripts = findChild(recs[player], "PlayerScripts")
		for _, child in ipairs(recs[starterPlayerScripts].children) do
			local copy = clone(recs[child])
			setParent(recs[copy], playerScripts)
		end
		local list = {}
		for _, d in ipairs(descendants(recs[playerScripts])) do
			if recs[d].class.name == "LocalScript" then table.insert(list, recs[d]) end
		end
		for _, rec in ipairs(list) do runScript(rec, ctx) end
		return ctx
	end
	-- Run test code as if a client script of `player` (for remotes, LocalPlayer).
	function engine.asClient(player, fn, ...)
		local ctx = {kind = "client", player = player, key = "client:" .. tostring(recs[player].props.UserId)}
		local co = coroutine.create(fn)
		threadContext[co] = ctx
		resume(co, ...)
	end
	function engine.pressAction(name, state)
		local binding = engine.boundActions[name]
		if not binding then error("No bound action " .. tostring(name), 2) end
		local co = coroutine.create(binding.fn)
		threadContext[co] = binding.ctx
		resume(co, name, state or EnumGlobal.UserInputState.Begin, nil)
	end

	----------------------------------------------------------------- time
	local function runDue()
		local guard = 0
		while true do
			guard += 1
			if guard > 100000 then record("errors", "scheduler: runaway resumption loop"); return end
			if #deferred > 0 then
				local batch = deferred
				deferred = {}
				for _, item in ipairs(batch) do
					if not cancelled[item.co] then resume(item.co, table.unpack(item.args, 1, item.args.n)) end
				end
			else
				local due, index = nil, nil
				for i, s in ipairs(sleepers) do
					-- task.wait(0) resumes on the next frame, never in the same frame.
					if s.wake <= engine.now and s.frame < engine.frame and (not due or s.wake < due.wake) then due, index = s, i end
				end
				if not due then return end
				table.remove(sleepers, index)
				if not cancelled[due.co] then resume(due.co, engine.now - (due.wake - 0)) end
			end
		end
	end
	function engine.step(dt)
		engine.frame += 1
		engine.now += dt
		for _, binding in pairs(engine.renderSteps) do
			local co = coroutine.create(binding.fn)
			threadContext[co] = binding.ctx
			resume(co, dt)
		end
		fire(recs[RunService].signals.RenderStepped, dt)
		fire(recs[RunService].signals.Stepped, engine.now, dt)
		fire(recs[RunService].signals.Heartbeat, dt)
		fire(recs[RunService].signals.PostSimulation, dt)
		runDue()
	end
	-- Advance virtual time; onStep(now, dt) runs before each frame (test input).
	function engine.advance(seconds, onStep, dt)
		dt = dt or (1 / 30)
		local target = engine.now + seconds
		while engine.now < target - 1e-9 do
			local d = math.min(dt, target - engine.now)
			if onStep then onStep(engine.now, d) end
			engine.step(d)
		end
	end
	function engine.shutdown(limit)
		local handlers = engine.closeHandlers
		local done = 0
		for _, handler in ipairs(handlers) do
			local co = coroutine.create(function() handler.fn(); done += 1 end)
			threadContext[co] = handler.ctx
			resume(co)
		end
		local started = engine.now
		while done < #handlers and engine.now - started < (limit or 30) do engine.step(1 / 30) end
		return done == #handlers, engine.now - started
	end
	function engine.countInstances(root)
		return #descendants(recs[root or game])
	end
	function engine.sleepers() return #sleepers end

	return engine
end

return Fake
