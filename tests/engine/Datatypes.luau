--!nocheck
-- Fake Roblox datatypes for headless tests. Immutable by convention; math
-- follows Roblox semantics closely enough for gameplay code (vectors, CFrame
-- rotation matrices, colours, UDim2, sequences, Random). Not physics.
local DT = {}

local function typed(name)
	return {__typename = name}
end
local function member(name, key)
	error(tostring(key) .. " is not a valid member of " .. name, 3)
end
local function num(v, default)
	if v == nil then return default or 0 end
	if type(v) ~= "number" then error("number expected, got " .. type(v), 3) end
	return v
end
DT.typed = typed

------------------------------------------------------------------ Vector3
local V3 = typed("Vector3")
local function v3(x, y, z) return setmetatable({X = x, Y = y, Z = z}, V3) end
local function isV3(v) return getmetatable(v) == V3 end
DT.isVector3 = isV3
local v3methods = {}
function v3methods.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function v3methods.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function v3methods.Lerp(a, b, t) return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end
function v3methods.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	return math.abs(a.X - b.X) <= eps and math.abs(a.Y - b.Y) <= eps and math.abs(a.Z - b.Z) <= eps
end
function v3methods.Abs(a) return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end
function v3methods.Floor(a) return v3(math.floor(a.X), math.floor(a.Y), math.floor(a.Z)) end
function v3methods.Ceil(a) return v3(math.ceil(a.X), math.ceil(a.Y), math.ceil(a.Z)) end
function v3methods.Sign(a) return v3(math.sign(a.X), math.sign(a.Y), math.sign(a.Z)) end
function v3methods.Min(a, b) return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
function v3methods.Max(a, b) return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
function v3methods.Angle(a, b)
	local d = v3methods.Dot(a, b) / math.max(1e-12, math.sqrt(v3methods.Dot(a, a) * v3methods.Dot(b, b)))
	return math.acos(math.clamp(d, -1, 1))
end
V3.__index = function(v, key)
	if key == "Magnitude" or key == "magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if key == "Unit" or key == "unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		-- Roblox returns NaN components for a zero vector's Unit.
		return v3(v.X / m, v.Y / m, v.Z / m)
	end
	if key == "x" then return v.X elseif key == "y" then return v.Y elseif key == "z" then return v.Z end
	local m = v3methods[key]
	if m then return m end
	member("Vector3", key)
end
V3.__newindex = function(_, key) error(tostring(key) .. " cannot be assigned to", 2) end
local function needV3(v, op) if not isV3(v) then error("invalid argument to Vector3 " .. op .. " (" .. type(v) .. ")", 3) end end
V3.__add = function(a, b) needV3(a, "+"); needV3(b, "+"); return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) needV3(a, "-"); needV3(b, "-"); return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	needV3(a, "*"); needV3(b, "*")
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	if type(a) == "number" then return v3(a / b.X, a / b.Y, a / b.Z) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__idiv = function(a, b) return v3(a.X // b, a.Y // b, a.Z // b) end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return string.format("%g, %g, %g", a.X, a.Y, a.Z) end
DT.Vector3 = {
	new = function(x, y, z) return v3(num(x), num(y), num(z)) end,
	zero = v3(0, 0, 0), one = v3(1, 1, 1), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1),
	FromNormalId = function() return v3(0, 1, 0) end,
}
DT.v3 = v3

------------------------------------------------------------------ Vector2
local V2 = typed("Vector2")
local function v2(x, y) return setmetatable({X = x, Y = y}, V2) end
V2.__index = function(v, key)
	if key == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y) end
	if key == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y); return v2(v.X / m, v.Y / m) end
	if key == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y end end
	if key == "Lerp" then return function(a, b, t) return v2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end end
	if key == "Cross" then return function(a, b) return a.X * b.Y - a.Y * b.X end end
	member("Vector2", key)
end
V2.__newindex = V3.__newindex
V2.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b)
	if type(a) == "number" then return v2(a * b.X, a * b.Y) end
	if type(b) == "number" then return v2(a.X * b, a.Y * b) end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b) if type(b) == "number" then return v2(a.X / b, a.Y / b) end return v2(a.X / b.X, a.Y / b.Y) end
V2.__unm = function(a) return v2(-a.X, -a.Y) end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
V2.__tostring = function(a) return string.format("%g, %g", a.X, a.Y) end
DT.Vector2 = {new = function(x, y) return v2(num(x), num(y)) end, zero = v2(0, 0), one = v2(1, 1), xAxis = v2(1, 0), yAxis = v2(0, 1)}

------------------------------------------------------------------ CFrame
-- Rotation stored row-major: r = {m00,m01,m02,m10,m11,m12,m20,m21,m22}.
-- Columns are RightVector, UpVector and -LookVector, as in Roblox.
local CF = typed("CFrame")
local function cf(x, y, z, r) return setmetatable({X = x, Y = y, Z = z, _r = r}, CF) end
local IDENTITY_R = {1, 0, 0, 0, 1, 0, 0, 0, 1}
local function isCF(v) return getmetatable(v) == CF end
DT.isCFrame = isCF
local function mulR(a, b)
	return {
		a[1] * b[1] + a[2] * b[4] + a[3] * b[7], a[1] * b[2] + a[2] * b[5] + a[3] * b[8], a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7], a[4] * b[2] + a[5] * b[5] + a[6] * b[8], a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7], a[7] * b[2] + a[8] * b[5] + a[9] * b[8], a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
	}
end
local function rotate(r, x, y, z) return r[1] * x + r[2] * y + r[3] * z, r[4] * x + r[5] * y + r[6] * z, r[7] * x + r[8] * y + r[9] * z end
local function transpose(r) return {r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9]} end
local function inverse(c)
	local t = transpose(c._r)
	local x, y, z = rotate(t, -c.X, -c.Y, -c.Z)
	return cf(x, y, z, t)
end
-- Roblox keeps rotations orthonormal (quaternion storage). Re-orthonormalize
-- products so long chains of PivotTo never drift into overflow/NaN.
local function orthonormal(r)
	local x1, y1, z1 = r[1], r[4], r[7]
	local lx = math.sqrt(x1 * x1 + y1 * y1 + z1 * z1)
	if lx < 1e-12 then return r end
	x1, y1, z1 = x1 / lx, y1 / lx, z1 / lx
	local x2, y2, z2 = r[2], r[5], r[8]
	local d = x1 * x2 + y1 * y2 + z1 * z2
	x2, y2, z2 = x2 - d * x1, y2 - d * y1, z2 - d * z1
	local ly = math.sqrt(x2 * x2 + y2 * y2 + z2 * z2)
	if ly < 1e-12 then return r end
	x2, y2, z2 = x2 / ly, y2 / ly, z2 / ly
	local x3, y3, z3 = y1 * z2 - z1 * y2, z1 * x2 - x1 * z2, x1 * y2 - y1 * x2
	return {x1, x2, x3, y1, y2, y3, z1, z2, z3}
end
local function mul(a, b) local x, y, z = rotate(a._r, b.X, b.Y, b.Z); return cf(a.X + x, a.Y + y, a.Z + z, orthonormal(mulR(a._r, b._r))) end
local function fromAxes(px, py, pz, right, up, back)
	return cf(px, py, pz, {right.X, up.X, back.X, right.Y, up.Y, back.Y, right.Z, up.Z, back.Z})
end
local function lookAt(at, target, up)
	up = up or v3(0, 1, 0)
	local look = target - at
	local m = look.Magnitude
	if m < 1e-9 then return cf(at.X, at.Y, at.Z, IDENTITY_R) end
	look = look / m
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then right = look:Cross(v3(0, 0, 1)) end
	if right.Magnitude < 1e-6 then right = look:Cross(v3(1, 0, 0)) end
	right = right.Unit
	local upv = right:Cross(look)
	return fromAxes(at.X, at.Y, at.Z, right, upv, -look)
end
local function rx(a) local c, s = math.cos(a), math.sin(a); return {1, 0, 0, 0, c, -s, 0, s, c} end
local function ry(a) local c, s = math.cos(a), math.sin(a); return {c, 0, s, 0, 1, 0, -s, 0, c} end
local function rz(a) local c, s = math.cos(a), math.sin(a); return {c, -s, 0, s, c, 0, 0, 0, 1} end
local cfmethods = {}
function cfmethods.Inverse(c) return inverse(c) end
function cfmethods.ToWorldSpace(a, b) return mul(a, b) end
function cfmethods.ToObjectSpace(a, b) return mul(inverse(a), b) end
function cfmethods.PointToWorldSpace(a, v) local x, y, z = rotate(a._r, v.X, v.Y, v.Z); return v3(a.X + x, a.Y + y, a.Z + z) end
function cfmethods.PointToObjectSpace(a, v) return cfmethods.PointToWorldSpace(inverse(a), v) end
function cfmethods.VectorToWorldSpace(a, v) return v3(rotate(a._r, v.X, v.Y, v.Z)) end
function cfmethods.VectorToObjectSpace(a, v) return v3(rotate(transpose(a._r), v.X, v.Y, v.Z)) end
function cfmethods.GetComponents(c) local r = c._r; return c.X, c.Y, c.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9] end
cfmethods.components = cfmethods.GetComponents
function cfmethods.Lerp(a, b, t)
	-- Position interpolation; rotation snaps at the midpoint (adequate for tests).
	return cf(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t, if t < 0.5 then a._r else b._r)
end
function cfmethods.ToEulerAnglesXYZ(c)
	local r = c._r
	local y = math.asin(math.clamp(r[3], -1, 1))
	return math.atan2(-r[6], r[9]), y, math.atan2(-r[2], r[1])
end
function cfmethods.ToOrientation(c)
	local r = c._r
	local x = math.asin(math.clamp(-r[6], -1, 1))
	return x, math.atan2(r[3], r[9]), math.atan2(r[4], r[5])
end
cfmethods.ToEulerAnglesYXZ = cfmethods.ToOrientation
function cfmethods.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	if math.abs(a.X - b.X) > eps or math.abs(a.Y - b.Y) > eps or math.abs(a.Z - b.Z) > eps then return false end
	for i = 1, 9 do if math.abs(a._r[i] - b._r[i]) > eps then return false end end
	return true
end
function cfmethods.Orthonormalize(c) return c end
CF.__index = function(c, key)
	if key == "Position" or key == "p" then return v3(c.X, c.Y, c.Z) end
	local r = c._r
	if key == "LookVector" or key == "lookVector" then return v3(-r[3], -r[6], -r[9]) end
	if key == "RightVector" or key == "XVector" then return v3(r[1], r[4], r[7]) end
	if key == "UpVector" or key == "YVector" then return v3(r[2], r[5], r[8]) end
	if key == "ZVector" then return v3(r[3], r[6], r[9]) end
	if key == "Rotation" then return cf(0, 0, 0, r) end
	if key == "x" then return c.X elseif key == "y" then return c.Y elseif key == "z" then return c.Z end
	local m = cfmethods[key]
	if m then return m end
	member("CFrame", key)
end
CF.__newindex = V3.__newindex
CF.__mul = function(a, b)
	if isCF(b) then return mul(a, b) end
	if isV3(b) then return cfmethods.PointToWorldSpace(a, b) end
	error("invalid argument #2 to CFrame * (" .. type(b) .. ")", 2)
end
CF.__add = function(a, b) needV3(b, "+"); return cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z, a._r) end
CF.__sub = function(a, b) needV3(b, "-"); return cf(a.X - b.X, a.Y - b.Y, a.Z - b.Z, a._r) end
CF.__eq = function(a, b) return cfmethods.FuzzyEq(a, b, 0) end
CF.__tostring = function(c) return string.format("%g, %g, %g, ...", c.X, c.Y, c.Z) end
local function angles(x, y, z) return cf(0, 0, 0, mulR(mulR(rx(num(x)), ry(num(y))), rz(num(z)))) end
DT.CFrame = {
	identity = cf(0, 0, 0, IDENTITY_R),
	new = function(a, b, c, ...)
		local n = select("#", ...)
		if a == nil then return cf(0, 0, 0, IDENTITY_R) end
		if isV3(a) then
			if isV3(b) then return lookAt(a, b) end
			return cf(a.X, a.Y, a.Z, IDENTITY_R)
		end
		if n == 0 then return cf(num(a), num(b), num(c), IDENTITY_R) end
		local rest = {...}
		if n == 4 then -- quaternion qx,qy,qz,qw
			local qx, qy, qz, qw = rest[1], rest[2], rest[3], rest[4]
			return cf(a, b, c, {
				1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw),
				2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw),
				2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy)})
		end
		if n == 9 then return cf(a, b, c, rest) end
		error("Invalid number of arguments to CFrame.new", 2)
	end,
	lookAt = function(at, target, up) needV3(at, "lookAt"); needV3(target, "lookAt"); return lookAt(at, target, up) end,
	Angles = angles, fromEulerAnglesXYZ = angles,
	fromEulerAnglesYXZ = function(x, y, z) return cf(0, 0, 0, mulR(mulR(ry(y), rx(x)), rz(z))) end,
	fromOrientation = function(x, y, z) return cf(0, 0, 0, mulR(mulR(ry(y), rx(x)), rz(z))) end,
	fromAxisAngle = function(axis, a)
		local u = axis.Unit; local c, s, t = math.cos(a), math.sin(a), 1 - math.cos(a)
		return cf(0, 0, 0, {
			t * u.X * u.X + c, t * u.X * u.Y - s * u.Z, t * u.X * u.Z + s * u.Y,
			t * u.X * u.Y + s * u.Z, t * u.Y * u.Y + c, t * u.Y * u.Z - s * u.X,
			t * u.X * u.Z - s * u.Y, t * u.Y * u.Z + s * u.X, t * u.Z * u.Z + c})
	end,
	fromMatrix = function(p, x, y, z)
		z = z or x:Cross(y)
		return cf(p.X, p.Y, p.Z, {x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z})
	end,
}
DT.cf = cf

------------------------------------------------------------------ Color3
local C3 = typed("Color3")
local function c3(r, g, b) return setmetatable({R = r, G = g, B = b}, C3) end
C3.__index = function(c, key)
	if key == "r" then return c.R elseif key == "g" then return c.G elseif key == "b" then return c.B end
	if key == "Lerp" then return function(a, b, t) return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end end
	if key == "ToHSV" then
		return function(x)
			local max, min = math.max(x.R, x.G, x.B), math.min(x.R, x.G, x.B)
			local d = max - min; local h = 0
			if d > 0 then
				if max == x.R then h = ((x.G - x.B) / d) % 6 elseif max == x.G then h = (x.B - x.R) / d + 2 else h = (x.R - x.G) / d + 4 end
				h /= 6
			end
			return h, if max > 0 then d / max else 0, max
		end
	end
	if key == "ToHex" then return function(x) return string.format("%02X%02X%02X", math.floor(x.R * 255 + .5), math.floor(x.G * 255 + .5), math.floor(x.B * 255 + .5)) end end
	member("Color3", key)
end
C3.__newindex = V3.__newindex
C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
C3.__tostring = function(c) return string.format("%g, %g, %g", c.R, c.G, c.B) end
DT.Color3 = {
	new = function(r, g, b) return c3(num(r), num(g), num(b)) end,
	fromRGB = function(r, g, b) return c3(num(r) / 255, num(g) / 255, num(b) / 255) end,
	fromHSV = function(h, s, v)
		local i = math.floor(h * 6); local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		i %= 6
		if i == 0 then return c3(v, t, p) elseif i == 1 then return c3(q, v, p) elseif i == 2 then return c3(p, v, t)
		elseif i == 3 then return c3(p, q, v) elseif i == 4 then return c3(t, p, v) end
		return c3(v, p, q)
	end,
	fromHex = function(hex)
		hex = string.gsub(hex, "#", "")
		return c3(tonumber(string.sub(hex, 1, 2), 16) / 255, tonumber(string.sub(hex, 3, 4), 16) / 255, tonumber(string.sub(hex, 5, 6), 16) / 255)
	end,
}

------------------------------------------------------------------ UDim / UDim2
local UD = typed("UDim")
local function udim(s, o) return setmetatable({Scale = s, Offset = o}, UD) end
UD.__index = function(_, key) member("UDim", key) end
UD.__newindex = V3.__newindex
UD.__add = function(a, b) return udim(a.Scale + b.Scale, a.Offset + b.Offset) end
UD.__sub = function(a, b) return udim(a.Scale - b.Scale, a.Offset - b.Offset) end
UD.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end
DT.UDim = {new = function(s, o) return udim(num(s), num(o)) end}
local UD2 = typed("UDim2")
local function udim2(x, y) return setmetatable({X = x, Y = y}, UD2) end
UD2.__index = function(u, key)
	if key == "Width" then return u.X elseif key == "Height" then return u.Y end
	if key == "Lerp" then
		return function(a, b, t)
			return udim2(udim(a.X.Scale + (b.X.Scale - a.X.Scale) * t, a.X.Offset + (b.X.Offset - a.X.Offset) * t),
				udim(a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t))
		end
	end
	member("UDim2", key)
end
UD2.__newindex = V3.__newindex
UD2.__add = function(a, b) return udim2(a.X + b.X, a.Y + b.Y) end
UD2.__sub = function(a, b) return udim2(a.X - b.X, a.Y - b.Y) end
UD2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
UD2.__tostring = function(u) return string.format("{%g, %g}, {%g, %g}", u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset) end
DT.UDim2 = {
	new = function(a, b, c, d)
		if getmetatable(a) == UD then return udim2(a, b) end
		return udim2(udim(num(a), num(b)), udim(num(c), num(d)))
	end,
	fromOffset = function(x, y) return udim2(udim(0, num(x)), udim(0, num(y))) end,
	fromScale = function(x, y) return udim2(udim(num(x), 0), udim(num(y), 0)) end,
}

------------------------------------------------------------------ Sequences / ranges / misc
local function simple(name, fields)
	local mt = typed(name)
	mt.__index = function(_, key) member(name, key) end
	mt.__newindex = V3.__newindex
	return function(values) return setmetatable(values, mt) end, mt
end
local colorKey, colorKeyMt = simple("ColorSequenceKeypoint")
local numberKey, numberKeyMt = simple("NumberSequenceKeypoint")
DT.ColorSequenceKeypoint = {new = function(t, c) return colorKey({Time = num(t), Value = c}) end}
DT.NumberSequenceKeypoint = {new = function(t, v, e) return numberKey({Time = num(t), Value = num(v), Envelope = num(e)}) end}
local colorSeq = simple("ColorSequence")
DT.ColorSequence = {new = function(a, b)
	if type(a) == "table" and getmetatable(a) == nil then return colorSeq({Keypoints = a}) end
	if getmetatable(a) ~= C3 then error("ColorSequence.new expects Color3", 2) end
	b = b or a
	return colorSeq({Keypoints = {colorKey({Time = 0, Value = a}), colorKey({Time = 1, Value = b})}})
end}
local numberSeq = simple("NumberSequence")
DT.NumberSequence = {new = function(a, b)
	if type(a) == "table" and getmetatable(a) == nil then
		for _, k in ipairs(a) do if getmetatable(k) ~= numberKeyMt then error("NumberSequence keypoints expected", 2) end end
		return numberSeq({Keypoints = a})
	end
	a = num(a); b = num(b, a)
	return numberSeq({Keypoints = {numberKey({Time = 0, Value = a, Envelope = 0}), numberKey({Time = 1, Value = b, Envelope = 0})}})
end}
local range = simple("NumberRange")
DT.NumberRange = {new = function(a, b) a = num(a); return range({Min = a, Max = num(b, a)}) end}
local tweenInfo = simple("TweenInfo")
DT.TweenInfo = {new = function(t, style, direction, repeatCount, reverses, delay)
	return tweenInfo({Time = num(t, 1), EasingStyle = style, EasingDirection = direction, RepeatCount = repeatCount or 0,
		Reverses = reverses or false, DelayTime = delay or 0})
end}
local rect = simple("Rect")
DT.Rect = {new = function(a, b, c, d)
	if getmetatable(a) == V2 then return rect({Min = a, Max = b, Width = b.X - a.X, Height = b.Y - a.Y}) end
	return rect({Min = v2(num(a), num(b)), Max = v2(num(c), num(d)), Width = num(c) - num(a), Height = num(d) - num(b)})
end}
local brick = simple("BrickColor")
DT.BrickColor = {new = function(name) return brick({Name = tostring(name), Color = c3(0.6, 0.6, 0.6)}) end}
DT.BrickColor.White = function() return DT.BrickColor.new("White") end
local physical = simple("PhysicalProperties")
DT.PhysicalProperties = {new = function(d, f, e, fw, ew) return physical({Density = d, Friction = f, Elasticity = e, FrictionWeight = fw or 1, ElasticityWeight = ew or 1}) end}
local font = simple("Font")
DT.Font = {new = function(family, weight, style) return font({Family = family, Weight = weight, Style = style}) end,
	fromEnum = function(item) return font({Family = tostring(item), Weight = nil, Style = nil}) end}

------------------------------------------------------------------ Random (deterministic)
local RandomMt = typed("Random")
local randomMethods = {}
local function nextRaw(state)
	-- 48-bit LCG (Java style) kept in double-safe arithmetic.
	state._s = (state._s * 25214903917 + 11) % 281474976710656
	return state._s / 281474976710656
end
function randomMethods.NextNumber(self, min, max)
	local u = nextRaw(self)
	if min == nil then return u end
	return min + (max - min) * u
end
function randomMethods.NextInteger(self, min, max)
	if max < min then error("invalid argument #2 to 'NextInteger' (interval is empty)", 2) end
	return min + math.floor(nextRaw(self) * (max - min + 1))
end
function randomMethods.NextUnitVector(self)
	local z = self:NextNumber(-1, 1); local a = self:NextNumber(0, math.pi * 2); local r = math.sqrt(1 - z * z)
	return v3(r * math.cos(a), r * math.sin(a), z)
end
function randomMethods.Shuffle(self, t)
	for i = #t, 2, -1 do local j = self:NextInteger(1, i); t[i], t[j] = t[j], t[i] end
end
function randomMethods.Clone(self) return setmetatable({_s = self._s}, RandomMt) end
RandomMt.__index = function(_, key) return randomMethods[key] or member("Random", key) end
DT.Random = {new = function(seed) return setmetatable({_s = (math.floor(num(seed, 1)) % 281474976710656 + 281474976710656) % 281474976710656}, RandomMt) end}

return DT
