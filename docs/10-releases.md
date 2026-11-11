# Releases

How a version of Sundown Run gets out, and the decisions behind it (EQ-9). The mechanics
(`tools/export.sh`, `.github/workflows/release.yml`, the auto-updater) are in the README's
Releases section.

## Cadence

One tag a month, at the end of each roadmap month. The first months ran ahead of this table
(v0.5.2 was out by 2026-11-07); from the second year (`docs/roadmap/00-overview.md`) it reads:

| Tag | Month | Roadmap milestone |
|---|---|---|
| v0.6.0 | Feb 2027 | M4, the first five minutes |
| v0.7.0 | Mar 2027 | M5, the 1.0 candidate |
| v1.0.0 | Apr 2027 | M6, 1.0 |
| v1.1.0 to v1.8.0 | May to Dec 2027 | M7 to M14, one minor a month |
| v2.0.0 | Jan 2028 | M15, seasons and 2.0 |

A fix between them is a patch tag (v0.2.1). A tag with a suffix (v0.3.0-beta) is marked as a
pre-release on GitHub, and the auto-updater still offers it.

## Cutting a release

1. `tools/test.sh` and `tools/shots.sh` pass on main.
2. In `CHANGELOG.md`, rename **Unreleased** to `[x.y.z] - YYYY-MM-DD` and start a new empty
   **Unreleased** above it. Every line says what a player notices, not which file changed.
3. Set `config/version="x.y.z"` in `project.godot`. `test_export` checks that the changelog has
   a section for this version, so a bump without notes fails the tests.
   In the same change, write this version's save fixture (EQ-27):
   `godot --headless --path . -s res://tests/write_save_fixture.gd` writes the save, settings and wheel
   profile files this build makes into `tests/fixtures/saves/vx.y.z/`. Commit the folder;
   `test_save_compat` fails without it, and loads every release's folder from then on.
4. Merge that, then `git tag vx.y.z && git push origin vx.y.z`.
5. The release workflow stops at once if `tools/changelog.py` finds no section for the tag;
   otherwise it runs the tests, exports, and publishes the release with the changelog section
   as "What's new" above the download notes. `tools/export.sh` also bundles that section
   (`tools/changelog.py --json`, as `assets/whats_new.json`), and the title screen shows it
   once to players who updated (PR-17). Bullets show by their name, the words before the
   first ": ", so start each with a short name ("Photo key (PR-21): ...").
6. Start the previous release's desktop build and check it updates itself to the new one, and
   that the title shows what's new in it once.

## The save promise (EQ-27)

From 1.0 a save, settings and wheel profile file from any released version loads in every
later one, with every value in it. `tests/fixtures/saves/` keeps one folder per release, each
holding exactly what that version wrote (`tests/save_fixture.gd` has the values; the folders
for v0.1.0 to v0.5.2 were recreated from each tag's save code). `test_save_compat` loads each
one in the current build: every option and every best time as the release saved it, keys a
release didn't have at their defaults, and a save in the current version (with a `.bak` of
the old file, EQ-21) after. A format change therefore needs a migration step
(`CfgVersion.migrate`), never a reinterpretation of an old key. A folder is never edited once
committed.

## Decision: no code signing yet (2026-11-01)

The builds stay unsigned on Windows and ad-hoc signed (not notarized) on macOS until the 1.0
candidate at least. Austin decided this on 2026-11-01.

- **Why:** the players are friends and family, who can get past the first-launch warning with
  the steps in the release notes. Signing costs money every year: the Apple Developer Program is
  $99 a year, and Windows signing runs from about $10 a month (Azure Trusted Signing) to a few
  hundred dollars a year for a certificate. Notarization also adds secrets and a slow Apple
  step to the release workflow.
- **What players see:** Windows SmartScreen says the app is unrecognized (*More info*, *Run
  anyway*). macOS Gatekeeper blocks the first open (right-click, *Open*, or
  `xattr -cr "/Applications/Sundown Run.app"` if it says the app is damaged). The release
  notes and the README say so.
- **The updater is not affected:** it downloads a `.pck`, not an executable, and checks its
  SHA-256 against the release's manifest, so updates need no new signature and raise no
  warning.
- **Revisit when:** the game goes on a store (itch.io's desktop app and Steam both still run
  unsigned builds, but strangers bounce off the warnings), or a player can't get past the warning.
  Then: Apple Developer ID and `notarytool` in the release workflow (the macOS preset has
  the codesign and notarization fields), and Azure Trusted Signing for the `.exe`.

## Decision: GitHub Releases only for now (2026-11-01)

The game is published only as GitHub Releases. The auto-updater reads the latest release from
the GitHub API, so every desktop build already finds updates there, and nothing else needs an
account or upkeep.

**itch.io** comes next, once the game seems worth showing to people who don't know Austin (his
call). It fits without code changes: the Web zip is an HTML upload as it is, and the desktop
zips upload as downloads (`butler push` from the release workflow, with an itch API key as a
secret). The updater keeps reading GitHub, so an itch download updates itself too. Steam comes
after that, if ever: a $100 app fee, a Steamworks account and its review.

## Web: Azure Storage static website (2026-11-02)

From 0.4.0 every tag's Web build is playable at https://sundownrun.z13.web.core.windows.net/, which Austin asked for on
2026-11-02. The release workflow's `web` job runs after the GitHub Release, unzips the Web zip
and uploads it with `tools/deploy_web.sh`, replacing the last version. Only the latest release
is online. The page is cached with `no-cache`, so a returning player gets the new version on
their next visit.

- **Azure:** resource group `sundownrun` (East US), storage account `sundownrun` (Standard LRS,
  static website on, index and 404 page `index.html`, no public blob access). Costs cents a
  month at this traffic.
- **Sign-in:** the Entra app `sundownrun-web-deploy` has *Storage Blob Data Contributor* on that
  account and nothing else. GitHub signs in as it with OIDC: its federated credential trusts
  `repo:austinthedeveloper@2235324/arcade-racer@1439840465:environment:web`, and the
  repository's `web` environment admits `v*` tags only. This repository's tokens name the
  owner and repository with their numeric IDs; a subject with the plain names
  (`repo:austinthedeveloper/arcade-racer:...`, also on the app, unused) fails the sign-in with
  AADSTS700213, as the 0.4.0 release's first run did. There are no secrets; the client, tenant and subscription
  IDs and the account name are variables on that environment.
- **No special headers needed:** the Web preset is single-threaded (`test_export` checks this),
  so no COOP/COEP headers are needed. Azure doesn't compress files on the fly, so the deploy
  script gzips the `.wasm` and `.js` itself.
- **By hand:** `az login`, then `tools/deploy_web.sh build/release/SundownRun-<version>-web.zip`.
  Your own account needs the same role on the storage account; Austin's has it.
- **Revisit when:** players want older versions (upload to `v/<version>/` as well), a custom
  domain (Azure Front Door or a CNAME, which needs HTTPS through Front Door), or itch.io takes
  over the web build.

### itch.io page draft

Ready for when the page is made. Screenshots: the Palm Coast start, Neon Strip at night, a
Thunderhead lightning strike, the car select, a results screen.

> **Sundown Run**
>
> *A sunset arcade racer: eight stages, one clock, no brakes worth mentioning.*
>
> Race the sun across a made-up country, from Palm Coast through neon cities, desert mesas,
> storm passes and snowy summits. Beat the clock to each checkpoint, weave through traffic,
> draft the seven rivals and fire nitro on the straights. Finish in the top three to go on
> to the next stage.
>
> - Eight hand-built stages with their own weather, traffic and scenery
> - Twelve cars, unlocked as you go, from a wedge supercar to a surprisingly fast delivery van
> - Grand Tour, Single Race, Time Attack against your ghost, and Free Drive
> - Plays with a keyboard, a gamepad or a steering wheel with pedals (calibration built in)
> - Auto gas, assists and a colorblind-safe HUD, so a kid can play by steering
> - Updates itself when a new version is out
>
> Windows and macOS downloads, or play in the browser. Free.
>
> Controls: arrows or WASD to drive, Space for nitro, Esc to pause. F2 calibrates a wheel.

Tags: racing, arcade, retro, pixel-art, pseudo-3d, singleplayer. Genre: Racing.
Classification: game, released (or in development until 1.0).
