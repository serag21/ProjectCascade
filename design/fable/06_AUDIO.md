# 06 — Audio direction

Authoritative list: `data/audio_events.json` (37 SFX events, 12 creature voices, music stems, ambience, comfort limits). All audio is original and comes from the existing reproducible generator (`tools/generate_audio.py`); cues marked `existing` reuse a current `AudioCatalog` key.

## 1. Principles

1. **The ear tells you what the eye is busy with.** Ribbon length, snap proximity, hop wind-ups, the Prickle's turn count, the next Dune Fin mound and the Starwhirl spin-up are all audible.
2. **Reward is musical.** Pops in one loop climb a major pentatonic ladder; technique tags stack as a chord; chain tiers add notes. Bigger loops literally sound better.
3. **Music is the round clock.** Four stems enter on the round beats, so a player who never looks at the timer still knows the stampede is coming.
4. **Soft failure.** Whiff, empty dash and chain loss are gentle and brief. Nothing buzzes.

## 2. The core loop in sound (timing)

| t | Cue | Note |
| --- | --- | --- |
| continuous | `ribbon_hum` | Pitch +0…+7 semitones with ribbon length |
| within 9 studs of a snap point | `ribbon_near_close` | Two rising ticks |
| close, frame 0 | `loop_close` | Thwip + low drum |
| 0–0.30 s | `loop_cinch` | Rising whoosh |
| server result, +0.06 s each | `catch_pop` ×n | Pentatonic ladder 0,2,4,7,9,12,14,16 |
| with the last pop | `tech_stinger` | One bell per technique, as a chord |
| n ≥ 5 / n ≥ 8 | `roundup_stinger` / `stampede_stinger` | 0.4 s / 0.9 s |
| empty | `loop_whiff` | Deflating fizz |
| cut | `ribbon_cut` | String snap, clearly distinct from whiff |

Dash: `dash_go` on the input frame (second charge +3 semitones), `dash_ready` tick when a charge returns, `dash_empty` thud.

## 3. Music

| Stem | Enters | Content |
| --- | --- | --- |
| A base | 0 s | Light percussion + bass motif |
| B melody | 25 s | Lead melody |
| C drive | 49 s | Toms and claps building through the stampede telegraph; drops at 70 s (continues through a Legend) |
| D finale | 85 s | Octave-up counter melody + shaker; rising pedal in the last 10 s |

| Arena | Tempo · key | Mood and instruments |
| --- | --- | --- |
| Pop Meadow | 112 · C major | Sunny, bouncy: marimba, plucked strings, whistle lead |
| Fizz Canyon | 126 · D mixolydian | Galloping: twang pluck, hand claps, slide lead |
| Aurora Arcade | 104 · A minor → C major at the finale | Sparkling, wide: glass bells, soft arpeggio, sub pad |

Transitions: stems fade in over one bar on the beat; arena change crossfades 1.5 s; intermission keeps stem A low-passed at −6 dB; results plays an 8-bar sting; opening the menu ducks by 8 dB and never stops the music. At chain x4 a tambourine layer joins.

The existing three arena loops and finale layers supply stems A and D. Stems B and C are new work (WP-17).

## 4. Signature sounds

- **Stampede horn** (`stampede_horn`, 53 s): a warm two-note call. It is the audio logo: used at round start, in the Legend telegraph an octave lower, and in the store trailer.
- **Bank** (`bank_slam`): a glissando whose length scales with parade size.
- **Wrap bell** (`wrap_ring`): each wrap a fourth higher; the final wrap resolves.

## 5. Creature voices

One short voice per species, spatial, played on startle, plus the telegraph sound that doubles as gameplay information (table in the JSON). Limits: one voice per creature per 2 s, four per second arena-wide.

## 6. Ambience

Meadow: birdsong, creek, windmill creak. Canyon: dry wind, the falls, pebbles. Aurora: cold wind, a faint aurora drone, occasional ice creak. All positional sources are at their features.

## 7. Comfort and mix

Bus levels: music 0.5, SFX 0.8, ambience 0.35, UI 0.6. No cue above −6 dBFS after bus gain; no sustained energy above 6 kHz beyond 150 ms; ±1 semitone variation on repeats; all loops fade ≥ 80 ms; the stampede rumble is high-passed at 60 Hz for phone speakers. Existing volume sliders remain; a reduced-audio option drops distant creature voices and the x4 layer.

## 8. Not verifiable offline

Whether the mix is pleasant, whether the ladder is satisfying rather than cloying over twenty rounds, and whether the horn is recognisable can only be judged by listening in Studio after upload (`09` Q15–Q16).
