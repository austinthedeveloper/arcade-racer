# Changelog

What changed in each release of Sundown Run, newest first. Add a line under **Unreleased** with
every change a player would notice. Before a tag, rename **Unreleased** to the version and date;
the release workflow puts that section at the top of the GitHub Release notes
(`tools/changelog.py`), and refuses a tag without one. See [docs/10-releases.md](docs/10-releases.md).

## [Unreleased]

### Added

- Online players go by their profile's name and avatar (ON-8): the lobby shows each one's
  picture and name, and the race's standings, notices and results their names, instead of P1
  to P4. A player on an older build still shows as P2.
- Sticker book (MP-12): twenty-four stickers to collect, from a first win and a chain of five
  near misses to a win mirrored, gold on every stage and the Grand Tour won. Each comes once,
  with a chime and a NEW STICKER card after the line, and shows on the results. Find the book
  beside STATS on the title (left and right switch the pages).
- Completion page (MP-17): what's left, stage by stage: finished, won, the three medals and a
  mirrored win ticked off with a percentage for each, and the whole game's percentage with the
  stickers and the cars. The third page beside STATS.
- UI scale: Options > Accessibility > UI scale, Normal or Large. Large draws the HUD a quarter
  bigger (the clock, the place, the route bar, nitro, the speedometer, the subtitles and the
  rest), everything still on screen and clear of everything else, and the menus' text bigger.
- The attract mode tours the game: left on the title, the demo races run on one after another
  through every stage, each in the next car with a title card saying which, and the controls
  card shows once a loop before the title comes back.
- Survival (MP-13), on mode select: one endless road. Cross a stage's finish line and you drive
  straight on into the next stage you've reached, round and back to Palm Coast, with more
  traffic on every leg and more cars up the road at every checkpoint. Each checkpoint still
  adds time, but a little less than the last, until it adds none: the run ends when the clock
  does, and the score is how far you got. The HUD shows the distance against your best, and
  the results the road you took. Your best is kept per profile.
- Daily Run (MP-14), on mode select: one stage, car, weather and traffic mix a day, the same
  for everyone, raced alone against the clock. Its card shows today's pick and your best three
  tries today; any car or stage can come up, reached or not.
- Every car has its own engine note (PR-18): a buzzy, high-revving small engine (Solano Spyder,
  Dune Skipper, Halo EV, Cyclone), a deep, lumpy V8 (Bruiser 440, Mesa Rumbler, Phantom, Hauler)
  and a turbo with a whine that spools up and a pop on each upshift (Vega GT, Kestrel R,
  Tempest LM, Zenith X).

### Changed

- Every stage now changes width somewhere. Redrock Canyon runs six lanes wide across the open
  desert, then pinches to two lanes in the heart of the canyon. Neon Strip opens into a
  six-lane boulevard after the tunnel. Bayou Causeway's first causeway is an old two-lane road
  over the water, and Harvest Valley has a two-lane farm road through the wheat. Medal times
  on those four stages moved to match.
- The music is louder and the effects quieter by default (music 10 with more headroom,
  effects 7). Volumes you set yourself are kept.

### Fixed

- The engine, tire squeal and wind no longer hang on after the finish: they fade out under
  the instant replay and the results, and once the clock runs out and the car stops.

## [0.7.0] - 2026-11-11

### Added

- Grand Tour ending (MP-16): finishing the tour ends on a finale instead of stage select: the
  top three on the podium under the Skyline bridge with fireworks over the harbor, the final
  tour standings, then an end card for where you finished (the champion, a podium place or the
  rest), and the credits rolling over the harbor.
- Credits (PR-23): CREDITS on the title rolls who made the game, the tools and the font with
  their licenses, and how every sound is synthesized in code. It scrolls by itself; hold any
  key or button to speed it up.
- Radio v2 (PR-24): four new songs on every station, twenty in all, played in turn with the
  station's own sting between them, and a now-playing tag on the HUD as each song starts.
  Still all synthesized in code. The browser version keeps one song per station, to stay
  quick to load.
- First drive (MP-15): a new driver's first race on Palm Coast is a guided run, one prompt at a
  time when the road allows (gas, steer, nitro on a straight, draft a truck, a power slide), each
  cleared by doing it. SKIP FIRST DRIVE on the pause menu; it never comes back once done or skipped.
- Who's driving (AC-16): the first start, and every new profile, asks KID, NEW or RACER and sets
  the assists and difficulty to match. Change them any time in Options.
- Wheel first run (WH-16): plug in a wheel the game hasn't seen and the title offers to calibrate
  it now, once per wheel. Pads are never asked.
- Controls card (PR-22): CONTROLS on the title and the pause menu shows every control for the
  keyboard, pad, wheel or touch controls, with your own rebinds.
- Save promise (EQ-27): a save, the options and wheel setups from any version since 0.1.0 load
  in this one with everything in them, and every build is checked against all of them.
- Playtest log (EQ-25): Options > Display > PLAYTEST LOG (off unless you turn it on) keeps a
  note of each race on your computer: crashes, checkpoints and where you lost time.
  tools/playtest_report.py charts a folder of them per stage. Nothing is sent anywhere.
- Update to play online (ON-14): joining a host on a newer version says UPDATE TO PLAY ONLINE
  and offers an UPDATE button, instead of only OLD VERSION.
- Corner warnings (WS-20): every sharp bend on every stage has its turn arrow on the outside
  before it and chevrons (or a rail) along its outside, and every blind crest a crest sign
  before it, mirrored stages too. Where a sign's spot is taken by a gate or a bridge, it now
  stands just beside it instead of going missing.
- Scenery pass (WS-21): two new roadside scenes on every stage (a surf break and a pier head
  on Palm Coast, a cattle crossing and a rock garden in Redrock, a searchlit premiere and a
  fountain court on the Strip, a logging camp and the ski lift's base at Timberline, a fishing
  camp and a gator crossing on the Bayou, a pumpkin patch and a hay yard in Harvest Valley,
  storm chasers and a substation on Thunderhead, a news crew and a waterfront cafe in
  Skyline), and no stretch of empty roadside longer than 30 segments on any stage: Harvest's
  wheat country and Timberline's summit gain sunflowers, corn, snowbanks and pines.

### Changed

- Easier to read (AC-17): the credits roll down a dark column instead of straight over the
  harbor, and the Grand Tour finale's podium, standings and end card wait for you to press
  on instead of moving on by themselves.
- Car select: every car's picture is now rendered from its 3D model, all from the same angle on
  the same coast road, and painted like the car you then drive.
- Rival balance (RC-21): on Easy, rivals ahead of you wait for you a little longer.
- Crash feel (RC-22): the harder the hit, the longer the car tumbles; a big hit holds a moment
  of slow motion (not with Reduce motion on); back on the road the car is see-through for a
  second, so nothing can hit it again at once. Medal times move with the new autodrive times.
- Clock per difficulty (RC-23): checkpoint time bonuses are 10% bigger on Easy and 10% smaller
  on Hard. Hard now starts you on the ARCADE timer instead of TIGHT (TIGHT is still there to
  pick): on TIGHT the start time on some stages ran out before the first checkpoint.

### Fixed

- Stuck rivals (EQ-22): a rival that ran up behind a car standing still on the road (yours
  after TIME UP, say) could sit behind it for the rest of the race; it now drives round.
- Power-ups (G7): every stage had the same five, and never a nitro can or a mystery hubcap.
  Each stage now has its own: two mystery hubcaps and three of the other four kinds. Medal
  times follow the new finish times.
- Nitro flames (EQ-26): the Cyclone's, Bruiser's and Kestrel's now come out of their own pipes.
- Missing art (EQ-26): a traffic or power-up picture that fails to load no longer crashes the
  race; that vehicle is just left off the road.

## [0.5.2] - 2026-11-07

### Changed

- New car sprites: all twelve cars are now rendered from 3D models, each with its own uphill and
  downhill views, and they all sit on the road at the same angle. The Cyclone, Zenith X and
  Tempest no longer look like they're doing a wheelie.
- Brake lights: brake lights and night tail lights glow on each car's own lamps, not above them.

## [0.5.1] - 2026-11-06

### Fixed

- Bruiser 440 steering: turning right now shows the car's right side (it used to look like a
  left turn), and the engine on top sits in the middle instead of off to the left.

## [0.5.0] - 2026-11-02

### Added

- Crash reports (EQ-20): when something goes wrong, the game writes the error and its last 200
  log lines to a report in its logs folder, and the title's version line offers F4 COPY REPORT
  (or click it) to put the report on the clipboard for a bug report.
- The browser version opens on a Sundown Run loading screen (EQ-23): a sunset, the name and a
  bar showing how much has downloaded (percent and MB), in place of Godot's logo, and a plain
  message if the browser can't run the game.
- Photo key (PR-21): F12 saves a picture of the race without the HUD to the game's
  screenshots folder, with a shutter click and a flash (Options > Accessibility > FLASH tones
  it down). Bind it to a pad or wheel button on the remap screen as PHOTO.
- What's new (PR-17): the first time the game starts after an update, the title lists what
  the new version added, changed and fixed. Enter puts it away; it doesn't come back.
- A station per stage (PR-19): with the radio on SHUFFLE, each stage starts on its own
  station: rock through Redrock, Timberline and Harvest, synthwave on Neon Strip and Skyline,
  funk on Palm Coast and the Bayou, techno into Thunderhead. A station you pick still plays
  everywhere, and the radio button still changes it mid-race.
- Co-pilot (AC-14): Options > Accessibility > CO-PILOT steers for you, keeping the car in the
  middle of its lane and round every bend, and brakes for the sharp ones. Steer to move over a
  lane; it won't let you drive off the road. With AUTO GAS too, the youngest drivers can race
  without touching a thing. Off by default.
- Replug countdown (WH-12): plugging your wheel or pad back in after it came loose counts
  3, 2, 1 before the race goes on, so you have a moment to get your hands back on it. Pause
  stops the count. Plug in a different one and it drives instead, the screen saying it's a
  different device with its own settings.
- The wet road reads (WS-13): on Thunderhead the rain-soaked road shines more, the storm sky
  and the pylons reflect in it in long streaks, and puddles catch the light on the road ahead.
  The sheen, the reflections and the puddles are on a new WORLD page of the F3 tuning panel.
- Camera views (WS-15): the VIEW button (V, or the right stick click) steps through chase near
  (as before), chase far (higher and further back) and a low bumper view without the car. The
  view is remembered, and is also on the Options DISPLAY page as CAMERA VIEW.
- Sundown across the tour (WS-16): a Grand Tour starts in the afternoon on Palm Coast and the
  sun drops stage by stage, the sky, the scenery and the cars taking the evening light and the
  shadows growing long, until Skyline is raced at night. Single races keep each stage's own
  time of day.
- Headlights at night (WS-17): on Neon Strip, Thunderhead and Skyline every car lights a pool
  of road ahead of it, the oncoming traffic's coming toward you, and the tail lights glow
  brighter in the dark.
- The hubcap in the slot (CP-14): a mystery hubcap spins in the power-up slot for half a
  second, then bursts open to show what it turned into.
- Instant replay (RC-17): after the finish, the last six seconds before the line play back
  once, every racer and the traffic as they were, before the results. Any key or button
  skips it; Enter during the finish slow-down still goes straight to the results.
- Save backups (EQ-21): before a new version updates your options, progress or wheel setups
  to its format, it keeps a copy of each file as it was (a .bak beside it). Options > Game >
  RESTORE BACKUP puts them back (it asks first).
- Player profiles (MP-10): up to four drivers, each with a name and an avatar picked from a
  list and a save of their own (progress, best times, stats, Time Attack ghosts). PROFILE on
  the title picks who is driving or makes a new driver; the title shows who it is. Your save
  so far becomes the first driver's.
- Rematch online (ON-9): after an online race the room stays open. The results show READY
  and a count of who's in ("READY 1 / 2"); the host picks the next stage there with up and
  down, and the next race starts as soon as everyone is ready. The host can also START NOW
  without waiting for the rest.
- Watch after the line (ON-10): finish an online race ahead of someone and the camera follows
  the leader of those still racing, with live standings ("WATCHING P2"), until the last car is
  in; then the results come up. Enter brings them up sooner.
- Connection quality (ON-12): a dot by the clock in an online race shows the round trip
  through the server, green under 150 ms, amber under 300 ms and red beyond (or when the room
  goes quiet), with the milliseconds beside it. If the server ever offers regions, ONLINE
  shows a SERVER picker under HOST and JOIN; today's server has one region, so it doesn't.

### Changed

- Disconnects online (ON-11): a player who drops out shows a notice ("P2 DROPPED OUT") and
  their car fades off the road instead of vanishing. The host leaving (or your connection
  going) now ends the race there with the results so far, instead of leaving you racing alone.

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
