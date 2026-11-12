# ON: Online and Mobile

Racing friends over the internet, on Windows, macOS, the Web build and a phone's browser. Added
2026-11-01, when Austin moved online play from "out of these six months" to the top of the board.
It goes through the same relay as Pickleball '94's ONLINE (`github.com/austinthedeveloper/pickleball-relay`):
a tiny WebSocket server on Azure Container Apps that pairs games in rooms by a four-letter code,
so nobody forwards a port and a browser can play.

## Built today

ON-1 to ON-5 on `feature/CLD-online-relay` (2026-11-01): ONLINE on mode select, rooms through the
relay, the lobby, online races and touch controls (`docs/02-technical-design.md` sections 4.8
and 11). Not yet checked on a phone (ON-6); the relay needs its `sundown-run` change deployed.

## How an online race works

- **Rooms.** The host opens a room (`game=sundown-run`) and the relay names it, four consonants
  ("BXKM"). Up to three guests join by the code. Guests talk only to the host; the host passes
  each guest's car on to the others.
- **The lobby.** Everyone picks their own car. The host picks the stage (and MIRROR, where open
  on the host's save) and starts.
- **The race.** Every game drives its own car and its own traffic, as in a Single Race, and sends
  its car (distance, offset, steering, speed, height) 20 times a second. The other players are
  drawn as rival cars, moved on between messages at their last speed. No AI rivals, no clock:
  first over the line wins, the rest race on to finish. Contact between players is settled on
  each player's own screen, so a bump can look a little different on each.
- **Start.** The host starts once every game has loaded the stage (or after 10 s), and the
  countdown runs from that message, so the starts are within one trip through the relay
  (about 45 ms from the US).
- **Leaving.** A guest who leaves drops off the road. The host leaving ends the room for
  everyone (the relay closes it).

## Features

| ID | Feature | Size | Month | Needs | Done when |
|---|---|---|---|---|---|
| ON-1 ✓ | **Relay rooms for Sundown Run.** The relay learns a fourth game, `sundown-run`, with three guests (four players). | S | 1 | | The relay's tests cover a four-player room; deployed and `/healthz` answers |
| ON-2 ✓ | **Online lobby.** ONLINE on mode select, then car select, then HOST or JOIN. HOST shows the room; JOIN picks the four letters on a letter grid that works with keyboard, pad, wheel and touch (typing works too). The lobby lists the players and their cars; the host picks the stage and mirror and starts. Errors in capitals (NO SUCH ROOM, ROOM FULL, OLD VERSION, THE HOST LEFT). | M | 1 | ON-1 | `test_online` drives a host and two guests over an in-memory relay through the lobby; menu screenshots of the lobby and the letter grid |
| ON-3 ✓ | **Online race.** The other players on the road as rival cars, places and the results' standings across everyone, a synced countdown, finishes sent to all, leaving mid-race. No clock, no AI rivals; traffic and power-ups as in a Single Race. The pause menu doesn't stop the race. | L | 1 | ON-2 | `test_online` races two players over the in-memory relay to both finishes; a two-window race over a local relay; a screenshot with another player on the road |
| ON-4 ✓ | **Touch driving.** On-screen controls on a touchscreen (the Web build on a phone or tablet, or a touch laptop): steer left and right under the left thumb, gas, brake and nitro under the right, pause at the top. They show at the first touch and hide on a key or pad press. Multi-touch, so gas and steer hold together. | M | 1 | | `test_touch` covers the hit areas, multi-touch and release; a race screenshot with them up |
| ON-5 ✓ | **Touch menus.** The same overlay in the menus: a D-pad, OK and BACK, so every screen (letter grid included) works by touch. | S | 1 | ON-4 | `test_touch` drives a menu by touch; a menu screenshot with the overlay |
| ON-6 | **Phone browser pass.** The Web build on an iPhone and an Android phone: landscape, full screen on the first tap, sound after the first tap, a frame rate check. Notes in the README. | S | 1 | ON-4 | A short table in the README of what was checked on which phone |
| ON-7 | **Native mobile builds.** Android and iOS export presets, touch controls on by default, release zips. | M | Stretch | ON-6 | An APK from `tools/export.sh` that installs and races |
| ON-8 ✓ | **Names and avatars online.** Players show their profile's preset name and avatar (MP-10) instead of P1 to P4. *Built (2026-11-12): the name and avatar ride at the end of HELLO, LOBBY and START (an older game's, without them, shows as P2), cleaned off the wire (capitals, digits, - and ., at most 10; an avatar only a car id); the lobby shows each avatar and name, the race's board, notices and results the name, a shared name gets its slot's number (NOVA 3).* | S | 2 | MP-10 | `test_online` carries the name in the hello; a screenshot of the lobby |
| ON-9 ✓ | **Rematch.** After a finish the room stays open: the host picks the next stage, the results screen shows a READY count, and the race starts when all are in. | S | 2 | ON-3 | Lobby state machine test; a two-window run of two races |
| ON-10 ✓ | **Watch after the line.** A player who has finished follows the leader still racing, with live standings, until the last car is in or the host moves on. | S | 2 | ON-3 | Test the camera target after a finish; a screenshot |
| ON-11 ✓ | **Disconnects.** A player who drops shows a notice and their car fades out; the host leaving ends the race with the results so far. | S | 1 | ON-3 | `test_online` covers both; a screenshot of the notice |
| ON-12 ✓ | **Connection quality.** A dot on the HUD for the relay round trip (green, amber, red) and a region picker when the relay offers one. | S | 2 | ON-1 | Test the dot's color thresholds; a screenshot |
| ON-13 | **AI rivals online.** The host drives the rivals and sends their states, so a two-player room still has a field. Open decision in this doc. | M | 3 | ON-3, RC-1 | A two-window run with rivals finishing in the same order on both |
| ON-14 ✓ | **Online across versions.** A guest on an older build gets UPDATE TO PLAY ONLINE with the updater's button instead of OLD VERSION; the relay names the oldest version it accepts. *Game side built (2026-11-11): older than the host (`OnlineSession.version_refusal`, by version number) or than the relay's oldest gives UPDATE TO PLAY ONLINE and an UPDATE button (the update screen; the Web build reloads, a checkout opens the releases page); newer than the host stays OLD VERSION. Builds up to 0.5.2 keep their own OLD VERSION text. **Relay change still needed** (pickleball-relay): an optional `"oldest": "x.y.z"` in its `room` and `welcome` messages, and refusing an older `ver` with `{"op": "error", "reason": "OLD VERSION"}`; the game reads both (`RelayLink._control`) and works without them.* | S | 5 | ON-2, EQ-14 | Test the message and button for an old hello; a screenshot |
| ON-15 | **Two at one screen online.** Both split-screen players join one online room as two players. | M | 8 | MP-18, ON-3 | `test_online` with a two-player guest; a two-window run |
| ON-16 | **Room options.** The host sets traffic, power-ups, the party rule and (once ON-13 is in) the rivals for the room. | S | 8 | ON-2, MP-20 | Lobby test that guests get the host's options; a screenshot |
| ON-17 | **Quick chat.** Four set messages (GG, NICE ONE, REMATCH?, WAIT) on the D-pad in the lobby and after the finish. No typing. | S | 8 | ON-2 | Test a message reaches every player; a screenshot |
| ON-18 | **Online leaderboards.** Best times per stage, car and mirror, sent after a race with its input trace. A small service next to the relay keeps the top times and the player's own. Where it runs is Austin's call. | L | 9 | EQ-33, MP-10 | The service's tests; a race's time shows on the board in a two-window run; a menu screenshot |
| ON-19 | **Time checks.** The service replays a submitted trace headless before accepting the time and drops ones that don't match, or are from an unknown version. | M | 9 | ON-18 | Tests for a good trace, an edited one and an old version |
| ON-20 | **Race the board.** Time Attack can race the leaderboard's top ghost, the one just above you, or a friend's. | M | 9 | ON-18, MP-5 | Test the downloaded ghost replays; a screenshot with the ghost |
| ON-21 | **Share stages by code.** Upload a stage to the service and get a six-letter code; anyone can download it by the code. No browsing, a size limit. | M | 14 | WS-30, ON-18 | The service's tests; a round trip in a two-window run |
| ON-22 | **Online cup.** A monthly cup on the leaderboard service: three stages, best combined time. | M | 15 | ON-18 | Service tests for the combined time; a screenshot |

## Open decisions

- AI rivals in an online race (the host's seed, the host driving them)? Default: none for now,
  the room is the field.
- Names: players show as P1 to P4 with their car. A name entry can come later.
- Catch-up between players (the rivals' rubber band)? Default: none online.
