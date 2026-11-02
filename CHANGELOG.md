# Changelog

What changed in each release of Sundown Run, newest first. Add a line under **Unreleased** with
every change a player would notice. Before a tag, rename **Unreleased** to the version and date;
the release workflow puts that section at the top of the GitHub Release notes
(`tools/changelog.py`), and refuses a tag without one. See [docs/10-releases.md](docs/10-releases.md).

## [Unreleased]

### Added

- Photo key (PR-21): F12 saves a picture of the race without the HUD to the game's
  screenshots folder, with a shutter click and a flash (Options > Accessibility > FLASH tones
  it down). Bind it to a pad or wheel button on the remap screen as PHOTO.

## [0.4.0] - 2026-11-02

### Added

- Play in the browser: every release from now on is also at
  https://sundownrun.z13.web.core.windows.net/, always the latest version.
- Oncoming traffic (RC-11): on Palm Coast, Redrock, Timberline, Bayou and Harvest the left
  lanes carry traffic coming the other way, drawn from the front with its headlights on (CP-6).
  Meeting one head-on is a longer spin than running into the back of a car; a ram plate knocks
  it aside, a ghost goes through it, and a close pass is a near miss. Neon Strip, Thunderhead
  and Skyline are divided roads with traffic one way only.
- Lane-change tells (RC-11): some everyday cars change lanes now and then, flashing a turn
  signal for a second first. A new tan sedan joins the traffic.
- Tuning panel (EQ-15, EQ-16): F3 in a race or the menus opens a panel of the game's driving,
  AI, traffic, drafting, launch, power-up, scoring and camera numbers. Nudge any of them and it
  applies at once (the HUD says TUNED), save and load presets, and slow the race down, jump
  along the stage, give yourself a power-up, set the clock or send a wave of traffic. Changes
  are kept for the next run and logged.
- Keyboard steering feel (AC-11): Options > Controls sets how fast a held steering key reaches
  full lock and how fast the steering comes back when you let go, each from SNAPPIEST to
  SMOOTHEST. STANDARD steers exactly as before.
- Reduce motion (AC-13): one switch in Options > Accessibility turns off the camera shake, the
  nitro view stretch, the scenery rising and dipping with the hills, and the rain streaks.
- Auto-pause (AC-15): switching to another window, or sending a phone browser tab to the
  background, pauses the race. Online races carry on, as they always do.
- Gamepad rumble (WH-13): the pad you drive with rumbles on crashes, bumps, landings, nitro and
  off the road. Options > Controls > RUMBLE sets how strongly, 0 for none.
- Medals (MP-9): every stage has bronze, silver and gold times, a little tighter on Hard and a
  little looser on Easy. Your best time's medal hangs on each postcard on the stage map, stage
  select shows the chosen stage's times beside its postcard, and the results show the medal a
  run earned.
- Stage intro card (PR-16): during the countdown a card slides in with the stage's name, its
  weather, its length (in miles or kilometres, after the units option), and your best time and
  medal there, and slides away before GO.
- Stats page (MP-11): STATS on the title shows your races, wins, crashes, near misses and
  distance driven, with your favourite car and stage. Kept in your save; a save from an earlier
  version starts with the races and wins its best times show.
- Near-miss chains (RC-15): near misses within two seconds of each other chain, and the burst
  says so (NEAR MISS x2, x3...). Each one in a chain scores more, up to five times the points;
  a two-second gap or a crash breaks it.
- Callout pacing (PR-15): CHECKPOINT and TIME EXTENDED now come up as one burst with both
  lines, the same burst won't pop up again within three seconds (a growing near-miss chain
  still does), and winning shows FINISH! first, then 1ST PLACE.
- HUD legibility (PR-14): no HUD text is smaller than 8 pixels any more (the MPH label and the
  car names on the results were 7), and the key hints in the corner are a little brighter.
- Rival cards and radar (RC-18): before GO, a card for each rival on the grid shows the
  driver, their car and how they drive (clean, aggressive or erratic). In the race, small arrows
  over your car point up for a rival less than a second ahead and down for one less than a
  second behind, placed by where they are across the road.

### Changed

- Rivals keep to their own side of an undivided road and pass on the other side only with
  room; a rival stuck on the tail of a car pulls out to pass it.
- Rain stops under cover (WS-12): on Thunderhead the rain lets up as you pass under an
  overpass, and thunder heard from under one (or in any tunnel or covered bridge) comes
  muffled and quieter.
- Skyline's harbor (WS-14): the city's lights reflected in the water now stay right under the
  towers they reflect through every bend and hill, instead of sliding off to one side.
- Fairer traffic (RC-14): no car waits just over a jump or a big blind hilltop, just inside a
  tunnel or covered bridge, or right ahead of where you start, and nothing coming the other way
  meets the grid. A car you knock off the road comes back in a lane with room.
- Traffic has a rhythm along each stage (RC-20): towns, the Strip, downtown Skyline and the
  stops along the way are busy; Redrock's open desert and Timberline's snowy summit are empty;
  causeways, bridges, the wheat fields, the switchbacks and the road works are quiet. Nothing
  drives up to the grid from behind during the countdown any more.
- Catch-up nitro (RC-16): reach a checkpoint in the last two places on easy or normal and you
  get one nitro charge back (NITRO +1). Hard gives nothing.
- The horn moves traffic (RC-13): honk close behind a slower car and after a beat it signals
  and moves over a lane, away from you, or keeps to the edge of its lane if the next one is
  taken. Big rigs, buses and the stage's locals ignore it.

## [0.3.1] - 2026-11-01

### Fixed

- A game that updated itself from 0.2.0 to 0.3.0 showed a blank screen when a race started.
  0.3.1 fixes it: updated games and fresh downloads both race.

## [0.3.0] - 2026-11-01

### Added

- Online races (ON-1 to ON-3): ONLINE on mode select. Host a room and share its four letters, or
  join one; up to four players on Windows, macOS, Linux and the Web build, through the same
  relay as Pickleball '94. The host picks the stage; no clock, no AI rivals, first over the line
  wins.
- Touch controls (ON-4, ON-5): on a phone or tablet's browser, steer, gas, brake, nitro and
  pause on screen while racing, and a D-pad with OK and BACK in the menus.
- Roads change width: Thunderhead's road works and the Timberline summit narrow to two lanes,
  and Palm Coast's town and Skyline's downtown open out into six-lane boulevards (WS-7).
- Power slides: brake while steering at speed to slide through a bend, turning tighter for a
  little speed, with squealing tires and smoke; hold the steering to keep it going (RC-8).
- Manual gears, in Options > Accessibility: shift up and down yourself (E and Q, Y and LB on a
  pad, or your wheel's paddles once bound in Remap) for a little more top speed; the engine and
  the tach follow your gear. Automatic stays the default. Nitro on a pad is now RB only, as Y
  shifts up (RC-10).
- Stage select is a map of the country: each stage's postcard pinned where it is, the tour
  route drawn between them, stages not reached yet dimmed (PR-8).
- Mirror mode: win a stage and you can race it flipped left for right, from stage select in
  Single Race, Time Attack and Free Drive (Up switches it). Saves that already won stages
  have their mirrors open (WS-6).
- Stage flow: each stage's finish runs into the next stage's colors and scenery, and the
  results fade the sky over to it before you go on (WS-8).

### Changed

- Distant roadside scenery no longer shimmers: palms, buildings and signs far down the road
  are drawn from smaller, smoothed copies, all on the same pixel grid (CP-9).
- A wheel works the menus like a gamepad: its D-pad moves, A selects, B goes back. Steering
  and the pedals no longer move through menus, and only A (or your pause button) selects.
- QUIT on the title screen closes the game (not in the browser build).
- Running into the back of traffic is a short spin that drops you in behind the car, not a
  full stop: about a second lost instead of nearly three. A gentle bump keeps more speed too.
- Rubbing doors with a rival scrubs speed once when you touch, not every frame you stay
  side by side (that used to hold you at a crawl).
- The starting grid is spaced out: more room between the rivals and in front of you.

## [0.2.0] - 2026-11-01

### Added

- The game updates itself: download once, and each start checks GitHub Releases for a newer
  version (EQ-14). 0.1.0 has no updater, so the next version is downloaded by hand once.
- A game icon on every platform (PR-13).
- Steering lock and wheel rotation in Options, for wheels set to 900 degrees or more (WH-1).
- Plugging a pad or wheel in mid-race pauses and offers it; unplugging one pauses too (WH-7).
- Grip per surface: wet roads, dirt, sand and snow each hold differently (RC-12).
- Thunderhead weather: rain, a wet road sheen, lightning and thunder (WS-2).
- Parallax: every stage's background in several layers moving at their own pace (WS-3).
- Starburst callouts for near misses, big air, drafting and more (PR-5).
- A new HUD: speedometer, position, clock and power-ups redrawn (PR-6).
- A colorblind-safe HUD option (AC-4).
- New sounds: passing cars whoosh by on their side, wind rises with speed, rivals' engines
  close by, the slipstream buffets, each power-up has its own pickup sound, and the horn
  button honks (PR-1, PR-3).
- A radio with four stations of original music: rock, synthwave, funk and techno. Pick one
  on car select or in Options, or leave it on shuffle; M changes station mid-race (PR-2).
- An announcer calls the countdown, GO, checkpoints, near misses, big air, the final stretch
  and your finish, with the music dipping under it (PR-4).
- Subtitles for the announcer, on by default (Options > Accessibility) (AC-5).

### Changed

- Every sound effect remade: fuller engines, crunchier crashes, bells and brass for the chimes
  and fanfares, and a new mix (PR-1).
- Faster road drawing, so busy stages hold 60 fps on slower machines (EQ-7).
- Cleaner car and prop edges (CP-7).

### Fixed

- A wheel no longer scrolls the Options screen down forever (WH-10).

## [0.1.0] - 2026-10-31

### Added

- The first release: eight stages, twelve cars, rivals, traffic and power-ups.
- Grand Tour, Single Race, Time Attack with a ghost, and Free Drive, on three difficulties.
- Keyboard, gamepad and wheel support, with a calibration wizard (F2) and remappable buttons.
- Builds for Windows, macOS and the web, and an unsupported Linux build for testing.
