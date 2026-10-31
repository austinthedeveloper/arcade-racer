# Audio

Every sound here is a **placeholder** synthesized by `tools/make_audio.py` (retro
pulse/saw/noise, mono 16-bit 22.05 kHz WAV). Rebuild them with:

```sh
python3 tools/make_audio.py
```

## Swapping in a sound pack

The game asks for sounds by **cue name** (`scripts/audio/sound_bank.gd`). For each cue it plays
the first of `<folder>/<cue>.ogg`, `.wav`, `.mp3` that exists. So to replace a placeholder:

1. Drop the new file in the same folder with the cue's name, e.g. `sfx/crash.ogg`.
   An `.ogg` wins over the generated `.wav`, so you can leave the placeholder in place
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
| `offroad` | sfx | yes | Driving on the dirt/grass, louder with speed |
| `nitro` | sfx | no | A nitro charge fires |
| `crash` | sfx | no | Crashing into traffic or a roadside object |
| `bump` | sfx | no | Nudging slower traffic without crashing |
| `land` | sfx | no | Touching down after a jump |
| `beep` | sfx | no | Countdown 3, 2, 1 |
| `go` | sfx | no | GO |
| `tick` | sfx | no | Each second under 10 s left on the clock |
| `checkpoint` | sfx | no | Passing a checkpoint |
| `finish` | sfx | no | Crossing the finish line |
| `crowd` | sfx | no | The crowd roaring and clapping at the finish line, with `finish`; mixed loud |
| `time_up` | sfx | no | The clock runs out |
| `music_race` | music | yes | From the countdown until the finish or time up |

The engine loops are about 56 Hz (`engine_low`) and 112 Hz (`engine_high`) at a pitch of 1.0.

Music and effects play on their own `Music` and `SFX` buses; the Master bus has a hard limiter.
