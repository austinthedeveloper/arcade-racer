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

## Open decisions

- AI rivals in an online race (the host's seed, the host driving them)? Default: none for now,
  the room is the field.
- Names: players show as P1 to P4 with their car. A name entry can come later.
- Catch-up between players (the rivals' rubber band)? Default: none online.
