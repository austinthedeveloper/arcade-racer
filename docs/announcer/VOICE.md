# The announcer's voice

One voice for every line in [SCRIPT.md](SCRIPT.md). This page is who they are, the instructions
to paste into the voiceover tool, and a short audition to pick the voice with. The placeholder
"voice" in the game today is synthesized patter (`tools/make_audio.py`); this replaces it.

## Who they are

The voice of Sundown Run: a late-80s arcade cabinet announcer who sounds like they also host
the highway radio at sundown. Big when the moment is big (GO, the win, a jump), cool and easy
in between, never shouting for the sake of it. They are on the player's side: they cheer a
close one, wince at a crash, and are kind about a loss. Family friendly, never mean, never
sarcastic at the player. An original character with no name; they don't imitate any real
announcer, actor or game.

Think: the warmth of a late-night DJ, the punch of a starter's call, a smile you can hear.

**Not**: a monster-truck rally ("SUNDAY SUNDAY SUNDAY"), a cartoon, a robot, a movie trailer,
or a sports broadcast. No fake accent. No echo or radio filter baked in; the game mixes it.

## Instructions for the voiceover tool

Paste this as the voice instructions (the "instructions", "style" or "prompt" field). Every
line also has its own delivery note in SCRIPT.md and lines.csv; give that as the line's
direction where the tool takes one, after these.

```text
Voice: An original late-1980s arcade racing game announcer who also sounds like a sundown
highway radio host. Mid-range to low, a little warm grit, clear diction. Not a monster-truck
announcer, not a cartoon, not a movie trailer, not a sports broadcaster.

Affect: Confident and on the player's side. Big for the big moments, cool and easy in between.

Tone: Upbeat and warm, a smile you can hear. Kind when the player loses. Never sarcastic at
the player, never mean, family friendly.

Pacing: Brisk. Short lines are one breath and land hard on the last word. Longer lines flow
like a radio host's intro, with a small lift before the payoff. No long pauses inside a line.

Emotion: Real excitement on wins, jumps and close calls; a sympathetic wince on crashes;
urgency, not panic, when the clock runs low.

Pronunciation: Say the words exactly as written. "Sundown Run" is two clear words with the
stress on "Sun". Numbers as words. Stage names clearly: Palm Coast Boulevard, Redrock Canyon,
Neon Strip, Timberline Pass, Bayou Causeway (BY-oo KAWZ-way), Harvest Valley, Thunderhead
Highway, Skyline Finale (fih-NAL-ee).

Delivery: Dry studio read, close to the mic. No music, no effects, no reverb, no radio filter.
Start speaking immediately and stop cleanly at the end; no breaths or tails.
```

## Settings

- **Pick one voice and keep it for the whole script**, with the same instructions, speed and
  settings for every line. Re-recording one line later must sound like the rest, so write down
  the voice, model and settings next to the recordings (a `manifest.json` from the tool is ideal).
- **The voice**: audition two or three of the tool's voices on the lines below and pick by ear.
  A lower, warmer voice suits it better than a bright one. Pickleball '94's announcer used
  `ash`; a different voice here keeps the two games apart, but `ash` with these instructions
  is a fine fallback.
- **Speed**: normal (1.0). If the driving lines run over their most-seconds, re-read them
  faster (1.1 or 1.15) rather than cutting words, and keep that speed for every short line.
- **Format**: 24 kHz (the tool's own rate is fine) or 48 kHz, 16-bit, mono WAV.

## The audition

Record these six with each voice you're choosing between. They cover the range: the big call,
the cool intro, the punchy one-word line, the urgent one, the joke and the kind one.

| id | line | what it tests |
|---|---|---|
| `go` | Go, go, go! | the big call: punch without shouting |
| `stage_neon_2` | Midnight on the Strip. Every light in town is on. | the cool radio read |
| `big_air` | Big air! | one breath, under a second |
| `hurry_2` | The clock's running out! | urgency, not panic |
| `crash_1` | Ooh. That one's going to leave a mark. | the dry joke |
| `finish_off_podium` | Off the podium this time. You'll get them next run. | kind, not mocking |

Pick the one that sounds like the same person across all six.

## Into the game

```sh
python3 tools/prep_announcer.py ~/Recordings/sundown_announcer   # trims, levels, puts the said lines in the game
```

It reads every `vo_<id>.wav` in the folder:
- Trims the silence and evens out the loudness.
- Resamples to 24 kHz.
- Writes each line the race says today over its placeholder in `assets/audio/sfx/`.
- Lists the "to wire" lines it kept back, and any id that isn't in the script.

Then `godot --headless --path . --import` and listen in a race. The said lines work at once.
The rest wait for the code that says them. SCRIPT.md marks which are which.
