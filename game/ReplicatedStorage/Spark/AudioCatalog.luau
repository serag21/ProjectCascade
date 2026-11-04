-- Original WAV assets are versioned in assets/audio and reproducible without downloads.
-- Empty IDs are intentional: no Roblox upload/account action has been performed.
-- Assign only owner-authorized uploaded assets and verify experience permissions in Studio.
-- The runtime must not construct rbxassetid:// from an empty string.
--
-- `fallback` values are Roblox CLIENT BUILT-IN content files (no upload, no
-- permission grant). They are UNVERIFIED PLACEHOLDERS: confirm each path plays
-- in Studio and replace with the uploaded originals (id) before release.
-- When `id` is set it always wins over `fallback`. Music has no fallback.
return {
	catch={id="",file="catch.wav",volume=0.32,duration=0.34,fallback="rbxasset://sounds/electronicpingshort.wav",fallbackVolume=0.22},
	bank={id="",file="bank.wav",volume=0.40,duration=0.85,fallback="rbxasset://sounds/electronicpingshort.wav",fallbackVolume=0.3,fallbackSpeed=0.7},
	dash={id="",file="dash.wav",volume=0.24,duration=0.30,fallback="rbxasset://sounds/swordlunge.wav",fallbackVolume=0.18,fallbackSpeed=1.3},
	upgrade={id="",file="upgrade.wav",volume=0.40,duration=1.10,fallback="rbxasset://sounds/button.wav",fallbackVolume=0.3},
	round_reward={id="",file="round_reward.wav",volume=0.42,duration=1.90,fallback="rbxasset://sounds/electronicpingshort.wav",fallbackVolume=0.3,fallbackSpeed=0.85},
	zap={id="",file="",volume=0.3,duration=0.4,fallback="rbxasset://sounds/clickfast.wav",fallbackVolume=0.25,fallbackSpeed=0.8},
	pop={id="",file="",volume=0.3,duration=0.3,fallback="rbxasset://sounds/button.wav",fallbackVolume=0.25,fallbackSpeed=1.4},
	ui={id="",file="",volume=0.25,duration=0.3,fallback="rbxasset://sounds/button.wav",fallbackVolume=0.2},
	music={id="",file="pop_meadow_loop.wav",volume=0.22,duration=16,looped=true},
}
