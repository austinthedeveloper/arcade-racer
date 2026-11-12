# The announcer: script for the voiceover

Written by `tools/announcer_script.py`; edit that, not this. The voice, and the instructions
to give the voiceover tool, are [VOICE.md](VOICE.md). **101 lines**; the same list is
[lines.csv](lines.csv), one row per file, for batching.

**Said** lines (15) are the ones the race says today: record them first, they drop straight
in. **To wire** lines (86) are recorded now and said once the race has a reason to
(variants it picks between, the stage intros, the countdown, and the rest).

## For the recording

- **One file per line**, named by its file column: `vo_go.wav`. All in one folder.
- **WAV, 24 kHz or 48 kHz, 16-bit, mono.** No music or effects; the game adds its own.
- **Trim the silence** to within 50 ms before the first sound and 100 ms after the last:
  the game times the lines and ducks the music for exactly as long as one lasts.
- **Even loudness**, about -16 LUFS each, peaks under -1 dBFS.
  `tools/prep_announcer.py` evens them out anyway, but a steady take sounds better.
- **One voice and one setting for every line** (VOICE.md). The countdown numbers above all
  must sound like one call.
- **Mind the length**: each line has a most-seconds. The driving lines have to land between
  one moment and the next, so the short ones matter most.
- The words are written as they should be said. If one comes out wrong, respell it in the
  tool and keep the id; the game shows the words as written here as the subtitle.
- Variants (`_2`, `_3`) are alternatives the game picks between, so give each a slightly
  different read too.

Then: `python3 tools/prep_announcer.py <folder>` levels them and puts the said lines in the
game (`assets/audio/sfx/`).

## Title and attract

*On the title screen as the logo lands, and now and then over the demo.*

| id | line | delivery | max s | |
|---|---|---|---|---|
| `title_1` | Sundown Run! | Big and bright, a grin in it. Arcade cabinet energy. | 1.5 | to wire |
| `title_2` | This is Sundown Run! | Big and bright, a grin in it. Arcade cabinet energy. | 2 | to wire |
| `title_press_start` | Press start, and hit the road. | Warm and easy, like a friend in the passenger seat. | 2.5 | to wire |
| `demo_1` | The sun's going down, and the road is wide open. | Cool and smooth, late-night radio. | 3.5 | to wire |
| `demo_2` | Eight stages, one clock, and nobody's stopping. | Cool and smooth, late-night radio. | 3.5 | to wire |
| `demo_3` | Your turn. Grab the wheel. | Warm and easy, like a friend in the passenger seat. | 2 | to wire |

## The start

*On the grid before the countdown, the countdown itself, GO, and a launch off the line.*

| id | line | delivery | max s | |
|---|---|---|---|---|
| `ready` | Engines ready. Here we go! | Big and bright, a grin in it. Arcade cabinet energy. | 2.5 | said |
| `ready_2` | Start your engines! | Big and bright, a grin in it. Arcade cabinet energy. | 2 | to wire |
| `ready_3` | Hands on the wheel. Eyes on the road. | Cool and smooth, late-night radio. | 2.5 | to wire |
| `count_3` | Three! | Clear and even, like the starter calling it. | 0.8 | to wire |
| `count_2` | Two! | Clear and even, like the starter calling it. | 0.8 | to wire |
| `count_1` | One! | Clear and even, like the starter calling it. | 0.8 | to wire |
| `go` | Go, go, go! | Big and bright, a grin in it. Arcade cabinet energy. | 1.5 | said |
| `go_2` | Go! | Quick and punchy, one breath, under a second. | 0.8 | to wire |
| `go_3` | Floor it! | Quick and punchy, one breath, under a second. | 1 | to wire |
| `launch` | What a launch! | Big and bright, a grin in it. Arcade cabinet energy. | 1.5 | said |
| `launch_2` | Perfect start! | Big and bright, a grin in it. Arcade cabinet energy. | 1.2 | to wire |
| `launch_3` | Out of the gate like a rocket! | Big and bright, a grin in it. Arcade cabinet energy. | 2 | to wire |

## Stages

*As a stage begins, once, after the countdown's first beat (one of the two).*

| id | line | delivery | max s | |
|---|---|---|---|---|
| `stage_palm_coast_1` | Welcome to Palm Coast Boulevard! Sun, surf, and six lanes through town. | Big and bright, a grin in it. Arcade cabinet energy. | 4.5 | to wire |
| `stage_palm_coast_2` | Palm Coast. Windows down, radio up. | Cool and smooth, late-night radio. | 3 | to wire |
| `stage_redrock_1` | Redrock Canyon! Open desert, big air, and a canyon that bites. | Big and bright, a grin in it. Arcade cabinet energy. | 4.5 | to wire |
| `stage_redrock_2` | Out in the desert now. Watch the road pinch in the canyon. | Warm and easy, like a friend in the passenger seat. | 4 | to wire |
| `stage_neon_1` | The Neon Strip! The brightest, busiest road in the game. | Big and bright, a grin in it. Arcade cabinet energy. | 4 | to wire |
| `stage_neon_2` | Midnight on the Strip. Every light in town is on. | Cool and smooth, late-night radio. | 3.5 | to wire |
| `stage_timberline_1` | Timberline Pass! Up into the pines, and over the summit. | Big and bright, a grin in it. Arcade cabinet energy. | 4 | to wire |
| `stage_timberline_2` | Snow on the summit today. Easy on the grip. | Warm and easy, like a friend in the passenger seat. | 3.5 | to wire |
| `stage_bayou_1` | Bayou Causeway! Long roads over open water. | Big and bright, a grin in it. Arcade cabinet energy. | 3.5 | to wire |
| `stage_bayou_2` | Dawn on the bayou. Mind the fog, and mind the gators. | Dry and playful; let the joke land, don't push it. | 4 | to wire |
| `stage_harvest_1` | Harvest Valley! Rolling hills and golden fields. | Big and bright, a grin in it. Arcade cabinet energy. | 3.5 | to wire |
| `stage_harvest_2` | Out in the farm country. Hold on over those crests. | Warm and easy, like a friend in the passenger seat. | 3.5 | to wire |
| `stage_thunder_1` | Thunderhead Highway! There's a storm on the way. | Big and bright, a grin in it. Arcade cabinet energy. | 3.5 | to wire |
| `stage_thunder_2` | Rain on the road and lightning in the sky. Stay sharp. | Urgent, leaning in. The clock is the enemy. | 3.5 | to wire |
| `stage_skyline_1` | The Skyline Finale! The last road, and the longest. | Big and bright, a grin in it. Arcade cabinet energy. | 4 | to wire |
| `stage_skyline_2` | Downtown, top of the world. This is it. | Cool and smooth, late-night radio. | 3 | to wire |
| `stage_mirror` | Mirror mode! Everything's the other way round. | Dry and playful; let the joke land, don't push it. | 3 | to wire |

## Checkpoints and the clock

*At a checkpoint, as time is added, the last checkpoint, and when the clock runs low or out.*

| id | line | delivery | max s | |
|---|---|---|---|---|
| `checkpoint` | Checkpoint! | Quick and punchy, one breath, under a second. | 1 | said |
| `checkpoint_2` | Checkpoint! Keep it going! | Big and bright, a grin in it. Arcade cabinet energy. | 1.8 | to wire |
| `checkpoint_3` | Made it! | Quick and punchy, one breath, under a second. | 0.8 | to wire |
| `time_extended` | Time extended! | Big and bright, a grin in it. Arcade cabinet energy. | 1.5 | said |
| `time_extended_2` | More time on the clock! | Big and bright, a grin in it. Arcade cabinet energy. | 1.8 | to wire |
| `last_checkpoint` | Last checkpoint! The finish is up ahead! | Big and bright, a grin in it. Arcade cabinet energy. | 2.5 | to wire |
| `hurry` | Hurry up! | Urgent, leaning in. The clock is the enemy. | 1 | said |
| `hurry_2` | The clock's running out! | Urgent, leaning in. The clock is the enemy. | 1.8 | to wire |
| `hurry_3` | Come on, come on, come on! | Urgent, leaning in. The clock is the enemy. | 1.5 | to wire |
| `ten_seconds` | Ten seconds! | Urgent, leaning in. The clock is the enemy. | 1 | to wire |
| `time_up` | Out of time! | Sympathetic, kind, a 'next time' feel. Never mocking. | 1.5 | said |
| `time_up_2` | Time's up. So close. | Sympathetic, kind, a 'next time' feel. Never mocking. | 2 | to wire |

## Driving

*During the race, for the moment it calls; never two within a second or two.*

| id | line | delivery | max s | |
|---|---|---|---|---|
| `near_miss` | Whoa, close one! | Big and bright, a grin in it. Arcade cabinet energy. | 1.5 | said |
| `near_miss_2` | Too close! | Quick and punchy, one breath, under a second. | 1 | to wire |
| `near_miss_3` | Threaded the needle! | Big and bright, a grin in it. Arcade cabinet energy. | 1.5 | to wire |
| `near_miss_chain` | Another one! You're on fire! | Big and bright, a grin in it. Arcade cabinet energy. | 2 | to wire |
| `big_air` | Big air! | Quick and punchy, one breath, under a second. | 1 | said |
| `big_air_2` | Look at that hang time! | Big and bright, a grin in it. Arcade cabinet energy. | 1.8 | to wire |
| `big_air_3` | Airborne! | Quick and punchy, one breath, under a second. | 1 | to wire |
| `final_stretch` | Final stretch! Bring it home! | Big and bright, a grin in it. Arcade cabinet energy. | 2 | said |
| `final_stretch_2` | Home stretch! Everything you've got! | Big and bright, a grin in it. Arcade cabinet energy. | 2.2 | to wire |
| `slipstream` | In the slipstream! | Quick and punchy, one breath, under a second. | 1.2 | to wire |
| `slingshot` | Slingshot! | Quick and punchy, one breath, under a second. | 1 | to wire |
| `nitro` | Nitro! | Quick and punchy, one breath, under a second. | 0.8 | to wire |
| `power_slide` | Power slide! | Quick and punchy, one breath, under a second. | 1 | to wire |
| `crash_1` | Ooh. That one's going to leave a mark. | Dry and playful; let the joke land, don't push it. | 2.2 | to wire |
| `crash_2` | Shake it off! Get back out there! | Warm and easy, like a friend in the passenger seat. | 2 | to wire |
| `crash_3` | Back on your wheels! | Warm and easy, like a friend in the passenger seat. | 1.2 | to wire |
| `off_road` | Back on the road! | Warm and easy, like a friend in the passenger seat. | 1.2 | to wire |

## Position

*When the player takes the lead, loses it, or passes a rival.*

| id | line | delivery | max s | |
|---|---|---|---|---|
| `first_place` | You have the lead! | Big and bright, a grin in it. Arcade cabinet energy. | 1.5 | said |
| `first_place_2` | Out in front! | Big and bright, a grin in it. Arcade cabinet energy. | 1.2 | to wire |
| `first_place_3` | Number one, and pulling away! | Big and bright, a grin in it. Arcade cabinet energy. | 2 | to wire |
| `lost_lead` | They've taken the lead! Get it back! | Urgent, leaning in. The clock is the enemy. | 2 | to wire |
| `passed_rival` | Got 'em! | Quick and punchy, one breath, under a second. | 0.8 | to wire |
| `passed_rival_2` | One more down! | Quick and punchy, one breath, under a second. | 1.2 | to wire |
| `rival_behind` | Somebody's right on your bumper! | Urgent, leaning in. The clock is the enemy. | 1.8 | to wire |

## Power-ups

*As the player picks one up (the mystery box says the one it gave).*

| id | line | delivery | max s | |
|---|---|---|---|---|
| `pickup_nitro` | Nitro on board! | Big and bright, a grin in it. Arcade cabinet energy. | 1.2 | to wire |
| `pickup_clock` | Extra time! | Big and bright, a grin in it. Arcade cabinet energy. | 1 | to wire |
| `pickup_ram` | Battering ram! Clear the road! | Big and bright, a grin in it. Arcade cabinet energy. | 2 | to wire |
| `pickup_ghost` | Ghost mode! Drive right through them! | Dry and playful; let the joke land, don't push it. | 2.2 | to wire |

## The finish

*Over the line, by place (no rivals: just finished), then a best time or a medal.*

| id | line | delivery | max s | |
|---|---|---|---|---|
| `finish_1` | You win! What a drive! | Big and bright, a grin in it. Arcade cabinet energy. | 2 | said |
| `finish_1_2` | Checkered flag! You win! | Big and bright, a grin in it. Arcade cabinet energy. | 2 | to wire |
| `finish_1_3` | First place! Nobody could touch you! | Big and bright, a grin in it. Arcade cabinet energy. | 2.2 | to wire |
| `finish_2` | Second place! So close! | Warm and easy, like a friend in the passenger seat. | 1.8 | said |
| `finish_2_2` | Second! Just a little more next time. | Warm and easy, like a friend in the passenger seat. | 2.2 | to wire |
| `finish_3` | Third! You made the podium! | Warm and easy, like a friend in the passenger seat. | 1.8 | said |
| `finish_3_2` | Third place, and up on the podium! | Warm and easy, like a friend in the passenger seat. | 2 | to wire |
| `finish` | Finished! Go again for the podium. | Sympathetic, kind, a 'next time' feel. Never mocking. | 2.2 | said |
| `finish_off_podium` | Off the podium this time. You'll get them next run. | Sympathetic, kind, a 'next time' feel. Never mocking. | 3 | to wire |
| `photo_finish` | Photo finish! | Big and bright, a grin in it. Arcade cabinet energy. | 1.2 | to wire |
| `new_record` | A new best time! | Big and bright, a grin in it. Arcade cabinet energy. | 1.5 | to wire |
| `medal_gold` | That's gold! | Big and bright, a grin in it. Arcade cabinet energy. | 1 | to wire |
| `medal_silver` | Silver! | Big and bright, a grin in it. Arcade cabinet energy. | 0.8 | to wire |
| `medal_bronze` | Bronze! | Warm and easy, like a friend in the passenger seat. | 0.8 | to wire |

## The Grand Tour

*At the tour's start, between stages, and at its end.*

| id | line | delivery | max s | |
|---|---|---|---|---|
| `tour_start` | The Grand Tour starts here. Eight stages, one champion. | Big and bright, a grin in it. Arcade cabinet energy. | 4 | to wire |
| `tour_next` | On to the next stage! | Big and bright, a grin in it. Arcade cabinet energy. | 1.5 | to wire |
| `tour_leading` | You're leading the Grand Tour! | Big and bright, a grin in it. Arcade cabinet energy. | 2 | to wire |
| `tour_final_stage` | The last stage. The whole tour comes down to this. | Urgent, leaning in. The clock is the enemy. | 3.5 | to wire |
| `tour_champion` | Champion of the Grand Tour! What a drive! | Big and bright, a grin in it. Arcade cabinet energy. | 3 | to wire |
| `tour_runner_up` | Second overall. A tour to be proud of. | Warm and easy, like a friend in the passenger seat. | 3 | to wire |

## Modes and menus

*As a mode starts, and at the pause menu.*

| id | line | delivery | max s | |
|---|---|---|---|---|
| `mode_time_attack` | Time Attack. Just you and the clock. | Cool and smooth, late-night radio. | 2.5 | to wire |
| `mode_free_drive` | Free Drive. No clock, no rush. Enjoy the view. | Cool and smooth, late-night radio. | 3 | to wire |
| `mode_online` | Online race! Let's see who's fastest. | Big and bright, a grin in it. Arcade cabinet energy. | 2.5 | to wire |
| `rematch` | Rematch! | Big and bright, a grin in it. Arcade cabinet energy. | 1 | to wire |
| `pause` | Taking a breather. | Warm and easy, like a friend in the passenger seat. | 1.5 | to wire |
| `resume` | Back to it! | Warm and easy, like a friend in the passenger seat. | 1 | to wire |

