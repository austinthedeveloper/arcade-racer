# Game Design Document

**Working title:** SUNDOWN RUN (placeholder, easy to change)
**Genre:** Arcade road racer, pseudo-3D, sprite-based
**Engine:** Godot 4.x
**Inputs:** Keyboard, standard gamepads, steering wheel + pedals
**Status:** Concept / pre-production

---

## 1. Elevator pitch

A loud, sunny, over-the-top arcade road racer. You blast across a fictional country in a hot car, weaving through traffic, launching off hill crests, and hitting nitro past seven rivals before the checkpoint clock runs out. Every race is a scenic postcard: beaches, canyons, neon cities, mountain passes. It should feel great on a gamepad and *even better* on a wheel and pedals.

It lives in the same genre as the 90s coin-op cross-country racers, but all tracks, cars, names, music, and art are original. The look is classic scaled-sprite pseudo-3D (think late-16-bit / early-32-bit arcade road renderers), not polygon 3D.

## 2. Design pillars

1. **Speed you can feel.** Huge sense of velocity: fast road stripes, sprites rushing past, screen shake on crests, wind and engine roar. Top speed should feel slightly dangerous.
2. **Easy to drive, hard to master.** No tuning menus or realistic grip models. Steering, gas, brake, nitro. Skill comes from lines through traffic, drafting, and nitro timing.
3. **Spectacle over simulation.** Cars fly off crests, crashes are cartoonish tumbles, the announcer yells. Nothing punishes the player for more than a few seconds.
4. **Wheel-first controls, gamepad-friendly.** Analog steering and analog pedals are first-class citizens, not an afterthought.
5. **Postcard locations.** Every stage has a distinct palette, skyline, and set of roadside sprites. You should be able to identify a stage from a single screenshot.

## 3. Core loop

```
Pick mode -> pick car (+ color) -> race stage -> results (position, time, bonus) -> unlocks -> next stage
```

Inside a race:

```
Accelerate -> read the road (curves, hills, traffic) -> steer / brake / draft -> 
hit nitro on straights -> pass rivals -> reach checkpoint (time extend) -> finish
```

## 4. Game modes

| Mode | Description | Priority |
|---|---|---|
| **Grand Tour** | Series of linked stages across the fictional country. Finish in the top 3 to advance. Cumulative standings. | MVP+ |
| **Single Race** | Any unlocked stage, any car, 7 AI rivals plus traffic. | MVP |
| **Time Attack** | Solo against the clock, ghost of your best run. | Post-MVP |
| **Free Drive** | No timer, no rivals. Good for testing wheel settings. | Dev / Post-MVP |
| **Split-screen 2P** | Two players, one screen. | Stretch |

## 5. Race rules

- **Field:** Player + 7 AI rivals, plus civilian traffic in both directions.
- **Rolling start** from a grid on a starting straight with a countdown (3, 2, 1, GO). A well-timed throttle on GO gives a small launch boost.
- **Checkpoint timer:** Arcade style. Each stage has 3 or 4 checkpoints that add time. If the timer hits zero, game over (Grand Tour lets you continue once).
- **Finish:** Placing determines points and unlocks. Bonus points for near misses, air time, and clean sections.
- **Stage length:** About 2 to 3 minutes per stage at a decent pace.

## 6. Driving model (feel targets, not physics)

All movement happens in "track space": distance along the road (`z`) and lateral offset from the center (`x`). There is no real tire model.

| Element | Behavior |
|---|---|
| **Acceleration** | Strong low-end punch, tapering toward top speed. Car stats change the curve. |
| **Top speed** | Displayed in MPH (KPH optional). Roughly 180 to 220 displayed, tuned for feel. |
| **Steering** | Lateral speed scales with current speed. Gamepad gets speed-sensitive smoothing; wheel gets direct 1:1 response. |
| **Centrifugal pull** | Curves push the car toward the outside. Faster = more push. This is the main skill check. |
| **Braking** | Strong. Brake while steering at high speed starts a **power slide** (visual drift, tighter turn, small speed loss). |
| **Off-road** | Grass/sand/snow slows you down and shakes the camera. Not instant death. |
| **Nitro** | 3 charges per race (car dependent). About 3 seconds of extra top speed and acceleration, with flame FX and FOV stretch. |
| **Drafting** | Sitting close behind a rival or truck builds a slipstream meter, then a small speed boost. |
| **Air time** | Cresting a hill fast makes the car leave the road briefly. Bigger crests = bigger jumps. Land straight for a bonus; land badly for a wobble. |
| **Collisions** | Light contact = bump and speed loss. Hitting traffic or roadside objects head-on at speed = **big crash**: car tumbles off-screen-style, respawns in the road center about 2 seconds later at low speed. |
| **Gears** | Automatic by default. Manual (paddles or buttons) optional, with a tiny top-end advantage. |

## 7. Cars

Eight original cars at launch, all fictional. No real makes, badges, or logos. Each has 4 to 6 paint colors.

| ID | Name (placeholder) | Archetype | Accel | Top speed | Handling | Unlock |
|---|---|---|---|---|---|---|
| `car_vega` | Vega GT | Low wedge supercar | 4 | 5 | 3 | Start |
| `car_bruiser` | Bruiser 440 | American muscle coupe | 5 | 4 | 2 | Start |
| `car_kestrel` | Kestrel R | Rally-bred hatch | 4 | 3 | 5 | Start |
| `car_sol` | Solano Spyder | Open-top roadster | 3 | 4 | 4 | Start |
| `car_mesa` | Mesa Rumbler | Lifted 4x4 pickup | 3 | 3 | 3 (no off-road penalty) | Stage 3 |
| `car_phantom` | Phantom Interceptor | Police-style pursuit sedan (fictional livery) | 4 | 5 | 3 | Stage 5 |
| `car_hauler` | Hauler | Delivery van (joke car, surprisingly fast) | 3 | 4 | 2 | Secret |
| `car_zenith` | Zenith X | Concept hypercar | 5 | 5 | 4 | Finish Grand Tour |

Stats are 1 to 5 for the select screen. Real tuning lives in data files.

## 8. Stages (Grand Tour, fictional country)

A coast-to-coast run across an invented country. Each stage is point-to-point and flows visually into the next.

| # | Stage | Biome / mood | Signature features |
|---|---|---|---|
| 1 | **Palm Coast Boulevard** | Beach city, golden afternoon | Palm-lined boulevard, ocean on one side, boardwalk, lifeguard towers. Gentle curves; the tutorial stage. |
| 2 | **Redrock Canyon** | Desert mesas, hot noon | Long straights, big crests for air time, cactus, rock arches, a dusty diner. |
| 3 | **Neon Strip** | Night city, casino-style lights | Dense traffic, light-up signs, tunnels, wet reflective road. |
| 4 | **Timberline Pass** | Alpine forest, snow at the top | Switchback S-curves, pine trees, a covered bridge, snow banks. |
| 5 | **Bayou Causeway** | Swamp at dawn, mist | Long low bridges over water, cypress trees, fog that limits draw distance. |
| 6 | **Harvest Valley** | Farmland, wide open, sunset | Rolling hills, windmills, barns, grain silos, tractor traffic. |
| 7 | **Thunderhead Highway** | Storm plains | Rain, lightning flashes, dramatic sky, slippery road. |
| 8 | **Skyline Finale** | Big metro harbor, dusk | Suspension bridge, skyscrapers, finish under fireworks. |

**MVP:** Stage 1 only, fully dressed. Stage 2 next, to prove biome swapping. (Prototype, 2026-10-30: stages 1 to 7 are drivable back to back with art cut from the concept sheets. Skyline Finale waits for a background reroll with fictional landmarks (prompt BG-SKYLINE-01R). The Neon Strip tunnel and the Timberline covered bridge need a drive-through sprite type and are not in yet.)

### Road features (shared across stages)

- Variable road width and lane count (2 to 6 lanes)
- Curves, S-curves, hills, crests, dips
- Tunnels (ceiling sprites + darker palette)
- Road splits / forks (stretch goal: choose a route)
- Bridges (water or canyon visible below the road edge)
- Ramps / jump crests flagged in data
- Weather: clear, fog, rain, night

## 9. Traffic

- Civilian cars, trucks, buses, and stage-specific vehicles (tractor in Harvest Valley, tour bus on Neon Strip).
- Traffic drives in lanes in both directions. Oncoming traffic only on undivided roads.
- Some traffic changes lanes with a turn signal flash as a tell.
- Semi trucks are great for drafting and terrible to hit.

## 10. AI rivals

- 7 named rivals, each driving one of the playable cars in a signature color.
- Follow a racing line with personality: aggressive (blocks), clean, erratic.
- **Rubber banding:** Mild and invisible. Rivals ahead ease off slightly, rivals behind get a small boost, scaled by difficulty. Should never feel like cheating.
- Rivals also crash into traffic, which is fun to watch.

## 11. Scoring, progression, unlocks

- Points per placing, plus bonuses: near misses, air time, drafting, no crashes.
- Unlocks: cars, paint colors, stages, a "mirror mode" for each stage.
- Save data: unlocks, best times, input profiles, settings.

## 12. Presentation

- **Announcer** voice lines: countdown, "Checkpoint!", "Final lap of road!" style hype, finish calls. Original lines and VO.
- **Music:** Upbeat, original. A "radio" select before each race (rock, synthwave, funk, techno), changeable mid-race with a button.
- **HUD:** Speedometer + tach, position (e.g. 3/8), checkpoint timer, nitro charges, mini track progress bar.
- **Camera:** One chase view at launch. A low "bumper" view is a stretch goal.

## 13. Accessibility and options

- Remappable controls for every device, wheel calibration screen.
- Steering assist toggle for gamepad, automatic braking assist for beginners.
- Screen shake and flash intensity sliders (Thunderhead lightning).
- Colorblind-safe HUD elements.
- Subtitles for announcer lines.

## 14. MVP / vertical slice scope

The first playable milestone should prove the feel, not the content volume:

1. Pseudo-3D renderer with curves, hills, roadside sprites, parallax background.
2. One car, full steer/pitch sprite set.
3. Palm Coast Boulevard, fully dressed.
4. Traffic in both directions; 7 AI rivals.
5. Checkpoint timer, nitro, crash/respawn, air time on crests.
6. Keyboard, gamepad, and wheel/pedals with calibration.
7. Basic HUD, title screen, results screen.

## 15. Out of scope (for now)

- Online multiplayer
- Car customization beyond paint
- Realistic damage
- Polygon 3D cars or environments
