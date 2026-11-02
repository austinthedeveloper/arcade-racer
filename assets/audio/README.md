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
| `skid` | sfx | yes | Hard braking at speed, full lock at speed, a power slide, sliding after a crash |
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
| `radio_tune` | sfx | no | Changing radio station (in the race or on car select) |
| `shutter` | sfx | no | The photo key (F12, or a button bound to PHOTO) saving a picture |
| `station_rock` | music | yes | 98.3 THE CANYON: rock, E minor, 144 bpm. On SHUFFLE, Redrock, Timberline and Harvest start on it |
| `station_synthwave` | music | yes | 104.7 NEON FM: synthwave, A minor, 100 bpm. Neon Strip and Skyline |
| `station_funk` | music | yes | 92.1 SOUL STOP: funk, E, 104 bpm. Palm Coast and Bayou |
| `station_techno` | music | yes | 107.9 PULSE: techno, F minor, 128 bpm. Thunderhead |

## The announcer

`scripts/audio/announcer.gd` holds the lines (`Announcer.LINES`), and `tools/make_audio.py`
reads them from there to make each `vo_<id>` cue: not words, but synthesized patter in the
line's rhythm (formant-filtered syllables through a stadium PA), the way a cartoon character
talks. The subtitle carries the words (Options > Accessibility > Subtitles, on by default).
Lines play one at a time: the finish and time up jump the queue, a near miss or big air whose
moment has passed (2 s) is dropped. The music ducks 9 dB under each line. A recorded
`sfx/vo_<id>.ogg` replaces a line; edit its words in `LINES` to match.

## The radio

`scripts/audio/radio.gd` lists the four stations. A race starts on the station chosen in
Options > Audio or on car select (the radio button, M), or a random one on SHUFFLE (the
default), from the countdown until the finish or time up. The radio button changes station
mid-race: the next one picks up at the same point in its loop, so the music never drops
out, and its name comes up over the road. On a pad the radio button is unbound until set
in Remap. Each station is one 16-bar loop (an A and a B section) rendered at 32 kHz.

The engine loops are about 56 Hz (`engine_low`) and 112 Hz (`engine_high`) at a pitch of 1.0.

Music and effects play on their own `Music` and `SFX` buses; the Master bus has a hard limiter.
Whooshes play on `SFX Left` or `SFX Right`, panned buses that feed `SFX`, so the effects volume
covers them. A power slide (RC-8) squeals on the `skid` loop, from 60% at low speed to full at top speed.
