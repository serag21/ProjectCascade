-- Original WAV assets are versioned in assets/audio and reproducible without downloads
-- (tools/generate_audio.py; inventory, loudness and hashes in assets/audio/manifest.json).
-- Empty IDs are intentional: no Roblox upload/account action has been performed.
-- Assign only owner-authorized uploaded assets and verify experience permissions in Studio.
-- The runtime must not construct rbxassetid:// from an empty string.
-- Fill IDs with: python tools/set_audio_ids.py ids.json  (rewrites only id fields).
-- Keep ONE `key={...},` entry per line with plain values (no functions/expressions):
-- tools/set_audio_ids.py and `generate_audio.py --verify` parse this file.
--
-- `fallback` values are Roblox CLIENT BUILT-IN content files (no upload, no
-- permission grant). They are UNVERIFIED PLACEHOLDERS: confirm each path plays
-- in Studio and replace with the uploaded originals (id) before release.
-- When `id` is set it always wins over `fallback`. Music has no fallback.
-- `fallbackSpeed` is meant for the built-in fallback only, not the uploaded original.
--
-- Arena music: each base loop names its FINALE intensity layer (`finale`); the layer
-- has identical length/tempo (`layerOf` points back) so it can be started in sync
-- and faded in on top. Volumes/durations are authoring defaults, unverified by ear.
return {
	catch={id="",file="catch.wav",volume=0.32,duration=0.34,fallback="rbxasset://sounds/electronicpingshort.wav",fallbackVolume=0.22},
	bank={id="",file="bank.wav",volume=0.40,duration=0.85,fallback="rbxasset://sounds/electronicpingshort.wav",fallbackVolume=0.3,fallbackSpeed=0.7},
	dash={id="",file="dash.wav",volume=0.24,duration=0.30,fallback="rbxasset://sounds/swordlunge.wav",fallbackVolume=0.18,fallbackSpeed=1.3},
	upgrade={id="",file="upgrade.wav",volume=0.40,duration=1.10,fallback="rbxasset://sounds/button.wav",fallbackVolume=0.3},
	round_reward={id="",file="round_reward.wav",volume=0.42,duration=1.90,fallback="rbxasset://sounds/electronicpingshort.wav",fallbackVolume=0.3,fallbackSpeed=0.85},
	zap={id="",file="zap.wav",volume=0.28,duration=0.46,fallback="rbxasset://sounds/clickfast.wav",fallbackVolume=0.25,fallbackSpeed=0.8},
	pop={id="",file="pop.wav",volume=0.22,duration=0.20,fallback="rbxasset://sounds/button.wav",fallbackVolume=0.25,fallbackSpeed=1.4},
	ui={id="",file="ui_click.wav",volume=0.30,duration=0.07,fallback="rbxasset://sounds/button.wav",fallbackVolume=0.2},
	music={id="",file="pop_meadow_loop.wav",volume=0.22,duration=16,looped=true},
	-- 2026-11 original cue set (tools/generate_audio.py)
	gate_open={id="",file="gate_open.wav",volume=0.32,duration=1.30},
	golden_spawn={id="",file="golden_spawn.wav",volume=0.32,duration=1.50},
	golden_catch={id="",file="golden_catch.wav",volume=0.32,duration=1.10,fallback="rbxasset://sounds/electronicpingshort.wav",fallbackVolume=0.28},
	stampede_rumble={id="",file="stampede_rumble.wav",volume=0.30,duration=2.80},
	chain_tier={id="",file="chain_tier.wav",volume=0.25,duration=0.55,fallback="rbxasset://sounds/electronicpingshort.wav",fallbackVolume=0.2},
	countdown={id="",file="countdown.wav",volume=0.30,duration=0.22,fallback="rbxasset://sounds/electronicpingshort.wav",fallbackVolume=0.2},
	start_whistle={id="",file="start_whistle.wav",volume=0.32,duration=0.80},
	buzzer={id="",file="buzzer.wav",volume=0.30,duration=0.95},
	rank_up={id="",file="rank_up.wav",volume=0.34,duration=1.60},
	ui_click={id="",file="ui_click.wav",volume=0.30,duration=0.07,fallback="rbxasset://sounds/button.wav",fallbackVolume=0.2},
	ui_claim={id="",file="ui_claim.wav",volume=0.30,duration=0.60,fallback="rbxasset://sounds/electronicpingshort.wav",fallbackVolume=0.22},
	signature={id="",file="signature.wav",volume=0.28,duration=0.90},
	starstruck={id="",file="starstruck.wav",volume=0.28,duration=1.00},
	-- Arena loops (22.05 kHz) + FINALE layers: same length/tempo, start together, fade the layer in.
	music_meadow={id="",file="music_meadow.wav",volume=0.28,duration=17.143,looped=true,bpm=112,bars=8,finale="music_meadow_finale"},
	music_meadow_finale={id="",file="music_meadow_finale.wav",volume=0.28,duration=17.143,looped=true,bpm=112,bars=8,layerOf="music_meadow"},
	music_canyon={id="",file="music_canyon.wav",volume=0.28,duration=18.286,looped=true,bpm=105,bars=8,finale="music_canyon_finale"},
	music_canyon_finale={id="",file="music_canyon_finale.wav",volume=0.28,duration=18.286,looped=true,bpm=105,bars=8,layerOf="music_canyon"},
	music_aurora={id="",file="music_aurora.wav",volume=0.28,duration=21.333,looped=true,bpm=90,bars=8,finale="music_aurora_finale"},
	music_aurora_finale={id="",file="music_aurora_finale.wav",volume=0.28,duration=21.333,looped=true,bpm=90,bars=8,layerOf="music_aurora"},
}
