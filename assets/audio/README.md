# Audio

Every sound here is original, synthesized by `tools/make_audio.py`, so there is nothing to
license: additive engines with uneven cylinder firing, struck-metal and glass modes for
crashes, resonant-filtered noise for tires, wind and gravel, FM bells and filtered brass
with a small room reverb for the chimes and fanfares. Mono 16-bit 44.1 kHz WAV; Godot
compresses them on import. Rebuild them with (it prints each file's length and loudness,
for leveling in `SoundBank.CUES`):

```sh
python3 tools/make_audio.py                 # every sound
python3 tools/make_audio.py --only=crash    # just one (still the same file a full run writes)
```

## Swapping in a sound pack

The game asks for sounds by **cue name** (`scripts/audio/sound_bank.gd`). For each cue it plays
the first of `<folder>/<cue>.ogg`, `.wav`, `.mp3` that exists. So to replace a placeholder:

1. Drop the new file in the same folder with the cue's name, e.g. `sfx/crash.ogg`.
   An `.ogg` wins over the generated `.wav`, so you can leave the generated one in place
   (or delete it).
2. Open the project in Godot once so it imports the file.
3. Adjust the cue's volume in `SoundBank.CUES` if it sits too loud or quiet in the mix.

Looping is set in code, so you don't need to touch the import settings. Loops should be
seamless; the engine loops are pitch-shifted, so a steady single-note recording works best.

## Cues

| Cue | Folder | Loops | When it plays |
|---|---|---|---|
| `engine_low` | sfx | yes | Always; low-revs engine, pitch follows the gears. Fades out at high revs |
| `engine_high` | sfx | yes | Fades in at high revs, pitch follows the gears |
| `skid` | sfx | yes | Hard braking at speed, full lock at speed, sliding after a crash |
| `rival` | sfx | yes | The nearest rival's engine, louder the closer it is (either side), pitch from its revs |
| `offroad` | sfx | yes | Driving on the dirt/grass, louder with speed |
| `wind` | sfx | yes | Wind over the car, from about 15% speed up to full at top speed; quieter in the air |
| `draft` | sfx | yes | Buffeting air in a slipstream, with the draft meter |
| `horn` | sfx | yes | While the horn button is held (H on the keyboard, L3 on a pad; remappable) |
| `nitro` | sfx | no | A nitro charge fires |
| `crash` | sfx | no | Crashing into traffic or a roadside object |
| `bump` | sfx | no | Nudging slower traffic without crashing |
| `land` | sfx | no | Touching down after a jump |
| `whoosh` | sfx | no | Passing a traffic car or rival close alongside (or it passing you), panned to its side |
| `draft_boost` | sfx | no | The slipstream boost kicks in |
| `pickup_nitro` | sfx | no | Picking up a nitro canister (or a mystery hubcap that opens into one) |
| `pickup_clock` | sfx | no | Picking up extra seconds |
| `pickup_ram` | sfx | no | Picking up the ram plate |
| `pickup_ghost` | sfx | no | Picking up ghost |
| `beep` | sfx | no | Countdown 3, 2, 1 |
| `go` | sfx | no | GO |
| `tick` | sfx | no | Each second under 10 s left on the clock |
| `checkpoint` | sfx | no | Passing a checkpoint |
| `finish` | sfx | no | Crossing the finish line |
| `crowd` | sfx | no | The crowd roaring and clapping at the finish line, with `finish`; mixed loud |
| `time_up` | sfx | no | The clock runs out |
| `thunder` | sfx | no | A beat after a lightning flash, on a stage with lightning (Thunderhead) |
| `music_race` | music | yes | From the countdown until the finish or time up |

The engine loops are about 56 Hz (`engine_low`) and 112 Hz (`engine_high`) at a pitch of 1.0.

Music and effects play on their own `Music` and `SFX` buses; the Master bus has a hard limiter.
Whooshes play on `SFX Left` or `SFX Right`, panned buses that feed `SFX`, so the effects volume
covers them. There is no power-slide sound yet: power slides (RC-8) aren't built.
