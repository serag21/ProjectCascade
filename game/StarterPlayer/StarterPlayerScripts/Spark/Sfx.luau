-- The 22 Checkpoint 1 audio cues (WP-07), resolved from Design.Slice cues and
-- AudioCatalog. An uploaded catalog id always wins; until the owner uploads,
-- each cue uses exactly the fallback slice.json names: a built-in rbxasset
-- path, another catalog entry's fallback, or silence. Audio is NOT judged at
-- Checkpoint 1 (no uploads), so the fallbacks are unverified placeholders.
local Sfx = {}

-- Catalog ids are written by tools/set_audio_ids.py as "rbxassetid://N"; accept a bare N too.
function Sfx.assetUri(id)
	if string.sub(id, 1, 13) == "rbxassetid://" then return id end
	return "rbxassetid://" .. id
end

-- Pure: parse "existing: ui_click.wav @ speed 1.6" / "new: loop_close.wav" -> file, speed.
function Sfx.parseAsset(text)
	if type(text) ~= "string" then return nil, 1 end
	local file = string.match(text, "([%w_]+%.wav)")
	local speed = tonumber(string.match(text, "@ speed ([%d%.]+)")) or 1
	return file, speed
end

-- Pure: parse a fallback string -> {kind = "asset"|"catalog"|"silent", path|key, speed}.
function Sfx.parseFallback(text)
	if type(text) ~= "string" or string.find(text, "none", 1, true) == 1 then return {kind = "silent"} end
	local speed = tonumber(string.match(text, "@ speed ([%d%.]+)")) or 1
	local path = string.match(text, "(rbxasset://[%w_/%.]+)")
	if path then return {kind = "asset", path = path, speed = speed} end
	local key = string.match(text, "catalog fallback of '([%w_]+)'")
	if key then return {kind = "catalog", key = key, speed = speed} end
	return {kind = "silent"}
end

-- Pure: resolve every slice cue against the catalog.
-- -> map id -> {soundId = string?, speed, volume, source = "uploaded"|"fallback"|"silent"}
function Sfx.resolve(sliceCues, catalog)
	local byFile = {}
	for key, entry in pairs(catalog) do
		if type(entry) == "table" and entry.file and not byFile[entry.file] then byFile[entry.file] = key end
	end
	local out = {}
	for _, cue in ipairs(sliceCues.sfx) do
		local file, speed = Sfx.parseAsset(cue.asset)
		local key = file and byFile[file]
		local entry = key and catalog[key]
		local result
		if entry and type(entry.id) == "string" and entry.id ~= "" then
			result = {soundId = Sfx.assetUri(entry.id), speed = speed, volume = entry.volume or 0.3, source = "uploaded", key = key}
		else
			local fb = Sfx.parseFallback(cue.fallback)
			if fb.kind == "asset" then
				result = {soundId = fb.path, speed = fb.speed, volume = (entry and entry.fallbackVolume) or 0.22, source = "fallback", key = key}
			elseif fb.kind == "catalog" then
				local other = catalog[fb.key]
				if other and type(other.id) == "string" and other.id ~= "" then
					result = {soundId = Sfx.assetUri(other.id), speed = fb.speed, volume = other.volume or 0.3, source = "uploaded", key = fb.key}
				elseif other and other.fallback then
					result = {soundId = other.fallback, speed = fb.speed * (other.fallbackSpeed or 1),
						volume = other.fallbackVolume or 0.2, source = "fallback", key = fb.key}
				else
					result = {source = "silent", speed = 1, volume = 0}
				end
			else
				result = {source = "silent", speed = 1, volume = 0}
			end
		end
		out[cue.id] = result
	end
	return out
end

-- Pentatonic pop ladder: PlaybackSpeed = 2^(step/12) for step 0,2,4,7,9,12,14,16.
Sfx.PENTATONIC = {0, 2, 4, 7, 9, 12, 14, 16}
function Sfx.popSpeed(index)
	local step = Sfx.PENTATONIC[((index - 1) % #Sfx.PENTATONIC) + 1]
	return 2 ^ (step / 12)
end

---------------------------------------------------------------- Roblox side
-- ctx: {cues (Slice.cues), catalog, enabled() -> bool, volume() -> 0..1}
function Sfx.new(ctx)
	local SoundService = game:GetService("SoundService")
	local resolved = Sfx.resolve(ctx.cues, ctx.catalog)
	local self = {resolved = resolved, played = {}}
	local pool = {}
	local folder = Instance.new("Folder")
	folder.Name = "SparkSfx"
	folder.Parent = SoundService
	local function voice()
		for _, s in ipairs(pool) do if not s.IsPlaying then return s end end
		if #pool >= 12 then return pool[1] end
		local s = Instance.new("Sound")
		s.Name = "Cue"
		s.Parent = folder
		table.insert(pool, s)
		return s
	end
	-- play(id, speedMultiplier?)
	function self.play(id, speed)
		self.played[id] = (self.played[id] or 0) + 1
		local r = resolved[id]
		if not r or r.source == "silent" or not r.soundId then return nil end
		if ctx.enabled and not ctx.enabled() then return nil end
		local s = voice()
		s:Stop()
		s.SoundId = r.soundId
		s.PlaybackSpeed = r.speed * (speed or 1)
		s.Volume = r.volume * (if ctx.volume then ctx.volume() else 1)
		s:Play()
		return s
	end
	-- Looped cue (stampede rumble) with a stop handle.
	function self.loop(id)
		local r = resolved[id]
		if not r or r.source == "silent" or not r.soundId then return {stop = function() end} end
		local s = Instance.new("Sound")
		s.SoundId = r.soundId; s.Looped = true; s.PlaybackSpeed = r.speed
		s.Volume = r.volume * (if ctx.volume then ctx.volume() else 1)
		s.Parent = folder
		if not ctx.enabled or ctx.enabled() then s:Play() end
		return {stop = function() s:Stop(); s:Destroy() end}
	end
	return self
end

return Sfx
