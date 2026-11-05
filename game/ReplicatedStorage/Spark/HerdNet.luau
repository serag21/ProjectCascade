-- Compact server->client creature state packets for an UnreliableRemoteEvent (~10 Hz).
-- Pure and engine-independent (Luau `buffer` library, little-endian). Unreliable
-- delivery may drop or reorder any packet, so every packet is self-contained: a full
-- header plus absolute per-creature state. Clients keep the newest clock per id and
-- interpolate; a lost packet only delays the creatures it carried by one tick.
--
-- Header (8 bytes):  u8 version | u8 arena (1..255) | u16 count | f32 clock
-- Entry (10 bytes):  u32 id | i16 round(x*10) | i16 round(z*10) | u8 heading | u8 flags
-- x/z are arena-relative studs (0.1 stud steps, clamped to the int16 range, i.e.
-- -3276.8..3276.7). heading is radians quantized to 256 steps over [0, 2pi).
-- clock should be a small relative clock (arena/round seconds): f32 keeps ~7
-- significant digits, so absolute Unix time would lose whole minutes.
local HerdNet = {}
HerdNet.Version = 1
HerdNet.MaxPacketBytes = 900
HerdNet.HeaderBytes = 8
HerdNet.EntryBytes = 10
-- 89 entries -> 898 bytes, the most that fits under MaxPacketBytes.
HerdNet.EntriesPerPacket = math.floor((HerdNet.MaxPacketBytes - HerdNet.HeaderBytes) / HerdNet.EntryBytes)
HerdNet.Flags = {fleeing=1, dazed=2, golden=4, runner=8, startled=16, trial=32}

local TAU = 2 * math.pi
local INT16_MIN, INT16_MAX = -32768, 32767
local UINT32_MAX = 4294967295
local F32_MAX = 3.4e38

local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end

-- Exact (fmod is exact in IEEE 754) reduction into [0, TAU), safe for huge finite inputs.
local function normalize(angle)
	local r = math.fmod(angle, TAU)
	if r < 0 then r += TAU end
	if r >= TAU then r = 0 end
	return r
end

local function position(value)
	local q = math.floor(value * 10 + 0.5)
	if q < INT16_MIN then return INT16_MIN elseif q > INT16_MAX then return INT16_MAX end
	return q
end

local function headingByte(angle)
	return math.floor(normalize(angle) / TAU * 256 + 0.5) % 256
end

-- Returns a sanitized entry or nil when the entry is malformed (skipped, never fatal).
local function sanitize(entry)
	if type(entry) ~= "table" then return nil end
	local id, x, z, heading, flags = entry.id, entry.x, entry.z, entry.heading, entry.flags
	if flags == nil then flags = 0 end
	if not finite(id) or id % 1 ~= 0 or id < 0 or id > UINT32_MAX then return nil end
	if not finite(x) or not finite(z) or not finite(heading) then return nil end
	if not finite(flags) or flags % 1 ~= 0 or flags < 0 or flags > 255 then return nil end
	return id, position(x), position(z), headingByte(heading), flags
end

-- arena: integer 1..255. clock: number (non-finite or beyond f32 range -> 0).
-- entries: array of {id=uint32, x=number, z=number, heading=radians, flags=0..255}.
-- Returns an array of buffers, each <= MaxPacketBytes, entries kept in input order.
-- Zero valid entries still yields one header-only packet ("this arena is empty").
-- An invalid arena returns an empty array plus a reason.
function HerdNet.pack(arena, clock, entries)
	if not finite(arena) or arena % 1 ~= 0 or arena < 1 or arena > 255 then return {}, "Invalid arena" end
	local time = if finite(clock) and math.abs(clock) <= F32_MAX then clock else 0
	local ids, xs, zs, headings, flagList = {}, {}, {}, {}, {}
	if type(entries) == "table" then
		for _, entry in ipairs(entries) do
			local id, x, z, heading, flags = sanitize(entry)
			if id then
				table.insert(ids, id); table.insert(xs, x); table.insert(zs, z)
				table.insert(headings, heading); table.insert(flagList, flags)
			end
		end
	end
	local total, per = #ids, HerdNet.EntriesPerPacket
	local packets = {}
	local first = 1
	repeat
		local count = math.min(per, total - first + 1)
		local buf = buffer.create(HerdNet.HeaderBytes + count * HerdNet.EntryBytes)
		buffer.writeu8(buf, 0, HerdNet.Version)
		buffer.writeu8(buf, 1, arena)
		buffer.writeu16(buf, 2, count)
		buffer.writef32(buf, 4, time)
		local offset = HerdNet.HeaderBytes
		for index = first, first + count - 1 do
			buffer.writeu32(buf, offset, ids[index])
			buffer.writei16(buf, offset + 4, xs[index])
			buffer.writei16(buf, offset + 6, zs[index])
			buffer.writeu8(buf, offset + 8, headings[index])
			buffer.writeu8(buf, offset + 9, flagList[index])
			offset += HerdNet.EntryBytes
		end
		table.insert(packets, buf)
		first += count
	until first > total
	return packets
end

-- Returns {version, arena, clock, entries={{id,x,z,heading,flags},...}} or nil, reason.
function HerdNet.unpack(buf)
	if type(buf) ~= "buffer" then return nil, "Not a buffer" end
	local length = buffer.len(buf)
	if length < HerdNet.HeaderBytes then return nil, "Too short" end
	if length > HerdNet.MaxPacketBytes then return nil, "Too long" end
	local version = buffer.readu8(buf, 0)
	if version ~= HerdNet.Version then return nil, "Wrong version" end
	local arena = buffer.readu8(buf, 1)
	if arena < 1 then return nil, "Invalid arena" end
	local count = buffer.readu16(buf, 2)
	if length ~= HerdNet.HeaderBytes + count * HerdNet.EntryBytes then return nil, "Length mismatch" end
	local clock = buffer.readf32(buf, 4)
	if not finite(clock) then return nil, "Invalid clock" end
	local entries = table.create(count)
	local offset = HerdNet.HeaderBytes
	for index = 1, count do
		entries[index] = {
			id = buffer.readu32(buf, offset),
			x = buffer.readi16(buf, offset + 4) / 10,
			z = buffer.readi16(buf, offset + 6) / 10,
			heading = buffer.readu8(buf, offset + 8) * TAU / 256,
			flags = buffer.readu8(buf, offset + 9),
		}
		offset += HerdNet.EntryBytes
	end
	return {version=version, arena=arena, clock=clock, entries=entries}
end

-- Shortest-arc heading interpolation; t is clamped to [0,1] (non-finite t snaps to b).
-- Result is in [0, 2pi). A non-finite endpoint falls back to the other one (or 0).
function HerdNet.lerpHeading(a, b, t)
	if not finite(a) then return if finite(b) then normalize(b) else 0 end
	if not finite(b) then return normalize(a) end
	local alpha = if finite(t) then math.clamp(t, 0, 1) else 1
	local from, to = normalize(a), normalize(b)
	local delta = to - from
	if delta > math.pi then delta -= TAU elseif delta < -math.pi then delta += TAU end
	return normalize(from + delta * alpha)
end

-- has(flags, "golden") -> boolean. Unknown names and malformed flags are false.
function HerdNet.has(flags, name)
	local bit = if type(name) == "string" then HerdNet.Flags[name] else nil
	if not bit or not finite(flags) or flags % 1 ~= 0 or flags < 0 or flags > UINT32_MAX then return false end
	return bit32.btest(flags, bit)
end

return HerdNet
