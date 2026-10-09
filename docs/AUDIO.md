# Site 07 Audio Plan — Field Playtest 03

Audio is part of the gameplay information, not just decoration. Use silence/low ambience early, then layer mechanical state changes and escalate when the array is activated.

## Intended mix by phase

### Before power
- Low, steady facility/mechanical hum.
- Quiet fluorescent/electrical buzz.
- Distant metallic impacts at irregular 18–31 second intervals.
- Containment subject can move audibly behind glass, but should not dominate the mix.

### Primary power restored
- A metal door starts moving.
- Power-grid hum becomes more noticeable.
- The pump motor starts in the service area; a short client cue hints that machinery has begun nearby.

### Drainage starts
- A localized machinery/drain sound.
- Water movement cue as the surface lowers.
- Route lights provide visual confirmation.

### Observation array active
- Short sting/pulse.
- The array visibly turns.
- Alarm begins and lighting changes; selected main fixtures flicker/go dark.
- Containment door rises; the subject wakes and starts pursuing.

### Pursuit / escape
- Creature footsteps while moving and growls at intervals/proximity.
- Client-side proximity effect increases as distance closes: subtle red edge, minor blur/FOV shift/shake, occasional sting.
- Signal transmitted opens the exit route and gives a short cue.

## Candidate Creator Store sound IDs

These IDs are wired into the procedural prototype as initial candidates; **they have not been verified at runtime inside this experience**. Audio permissions can depend on experience owner/access settings. Watch Studio Output for load/permission errors and replace assets that fail or sound wrong.

- `171186876` — low industrial/machine hum candidate.
- `4227579935` — fluorescent/electrical hum candidate.
- `7792922595` — hydraulic/metal door movement candidate.
- `9113910297` — machine/pump startup candidate.
- `5348162330` — facility alarm candidate.
- `74103327872448` — creature growl candidate.
- `1244506786` — creature footstep loop candidate.
- `135540168785024` — short horror sting/static candidate.
- `3611209852` — distant heavy-metal impact candidate.
- `9044889073` — low horror/tension music candidate.

## Mixing rules

- Keep ambient bed and buzz quiet enough that interaction prompts, evidence, and system cues remain clear.
- Avoid continuous loud alarms before a consequential event.
- Make machine sounds spatial when players should infer where a system is located.
- A sound cue reinforces a visible state change; do not rely on sound alone for mandatory information.
- If an ID fails to load, replace it with a permission-verified Creator Store asset in a dedicated audio pass rather than guessing at random IDs.