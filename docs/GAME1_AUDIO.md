# SPARK STAMPEDE — original audio production

## Status and provenance

Created 2026-10-25 in this repository with `tools/generate_audio.py`, using Python 3.14.2 standard-library math, seeded noise and PCM encoding on Windows. No downloaded samples, sound fonts, MIDI, music quotations, purchased assets, external composers, or third-party audio libraries are incorporated. The exact melodies, voicings, rhythms and synthesis are authored in the generator. This records production provenance; platform upload/moderation and ownership settings still require verification.

Six finished source WAVs exist locally. **No audio has been uploaded to Roblox, assigned an asset ID, heard in Studio, or approved by listening QA.** `game/ReplicatedStorage/Spark/AudioCatalog.luau` intentionally has empty `id` strings. The files must not be described as live game audio until uploads, experience permissions and engine playback have been tested. Runtime fallback cues are separate from these original compositions.

## Sound direction

- Catch: a short rounded three-note sparkle, with a fast soft attack and little tail so frequent actions do not build a loud wash.
- Bank: a rising major arpeggio with a lower chord, visibly distinct in length from an individual catch.
- Dash: a filtered airy sweep with a quiet rising oscillator; no explosive transient.
- Upgrade: an extended upward gesture with a bright ninth at its peak.
- Round reward: a 1.9-second resolved melodic celebration, leaving space for score text.
- Pop Meadow music: original 120 BPM, eight-bar, 16-second groove. Rounded mallet melody, quiet off-beat plucks, warm sine-based pads, soft bass, kick and brushed percussion. Late note tails wrap to the start of the buffer, producing a continuous repeating bed for a 110-second round. It is one shared initial composition; biome-specific arrangements remain future polish.

Mix the catalog at its conservative default volumes, with separate Music and SFX toggles. Keep no more than six simultaneous SFX voices and avoid restarting music on every state update. Sound should reinforce visual confirmations, never be required to understand an objective. These mix recommendations still need actual concurrent-action and phone/headphone listening.

## Reproduction and verification

From the repository root:

```powershell
python tools/generate_audio.py
python tools/generate_audio.py --verify
.\.tools\luau\luau-compile.exe game/ReplicatedStorage/Spark/AudioCatalog.luau
```

Generation writes the six WAV files and `assets/audio/manifest.json`. Verification independently decodes the committed files, checks no full-scale clipping, bounded peak and DC offset, silent SFX boundaries, the loop duration and boundary discontinuity, total size, and exact manifest checksums. It does not measure perceptual loudness/LUFS, prove musical quality, or simulate Roblox playback. The manifest is the authoritative full SHA-256 inventory. Reproduction on a different Python/libm platform may differ in the last quantization bit; inspect and regenerate the manifest intentionally in that case.

Observed verification on 2026-10-25: both generator and read-only verifier passed; AudioCatalog compiled with Luau 0.744. All audio is 44,100 Hz, 16-bit PCM. Total WAV size is **3,218,682 bytes (3.07 MiB)**, below the 10 MB budget.

| File | Duration | Channels | Peak dBFS | RMS dBFS | Bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| `catch.wav` | 0.34 s | 1 | -6.38 | -19.32 | 30,032 |
| `bank.wav` | 0.85 s | 1 | -5.19 | -18.99 | 75,014 |
| `dash.wav` | 0.30 s | 1 | -9.37 | -23.53 | 26,504 |
| `upgrade.wav` | 1.10 s | 1 | -5.19 | -19.55 | 97,064 |
| `round_reward.wav` | 1.90 s | 1 | -4.73 | -19.76 | 167,624 |
| `pop_meadow_loop.wav` | 16.00 s | 2 | -6.38 | -23.90 | 2,822,444 |

The music's measured boundary step is 0.004669 full-scale; SFX start/end boundary steps are zero. That numerical check catches large boundary clicks but is not an audible loop certification.

## Pending Studio integration and release gates

1. Confirm intended experience ownership and an authorized asset-upload workflow; no upload/account operation was performed during offline production.
2. Upload the original WAVs, record exact asset IDs and experience access, then populate only the `id` fields in AudioCatalog.
3. Verify content loads for a non-owner test client, volumes remain restrained, and sounds destroy themselves when complete.
4. Audition 10 rapid catches, dash/catch overlap, banking, upgrade and full-round reward. Check no unpleasant overlap or loudness jump.
5. Audition three loop seams and two full rounds on headphones and phone speakers; adjust repetitive melody/mix based on listening.
6. Verify Music and SFX settings persist across rejoin and remain independent. Test audio failures without breaking gameplay or leaving confusing warnings.

Do not mark audio QA passed from waveform arithmetic alone.
