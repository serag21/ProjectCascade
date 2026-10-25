-- Original WAV assets are versioned in assets/audio and reproducible without downloads.
-- Empty IDs are intentional: no Roblox upload/account action has been performed.
-- Assign only owner-authorized uploaded assets and verify experience permissions in Studio.
-- The runtime must not construct rbxassetid:// from an empty string.
return {
	catch={id="",file="catch.wav",volume=0.32,duration=0.34},
	bank={id="",file="bank.wav",volume=0.40,duration=0.85},
	dash={id="",file="dash.wav",volume=0.24,duration=0.30},
	upgrade={id="",file="upgrade.wav",volume=0.40,duration=1.10},
	round_reward={id="",file="round_reward.wav",volume=0.42,duration=1.90},
	music={id="",file="pop_meadow_loop.wav",volume=0.22,duration=16,looped=true},
}
