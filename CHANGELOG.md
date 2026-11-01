# Changelog

What changed in each release of Sundown Run, newest first. Add a line under **Unreleased** with
every change a player would notice. Before a tag, rename **Unreleased** to the version and date;
the release workflow puts that section at the top of the GitHub Release notes
(`tools/changelog.py`), and refuses a tag without one. See [docs/10-releases.md](docs/10-releases.md).

## [Unreleased]

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
