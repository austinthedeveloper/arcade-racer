# Art Prompts: Round 4

Written 2026-10-30. Two parts: the prompts that are written but not generated yet, and the new round 4 prompts (more player cars, traffic, level pieces, and a power-up proposal).

All prompts follow `assets/prompts/00-style-guide.md`: swap `{STYLE}` for STYLE-A and add the negative prompt. Save results under each prompt's **Output** path with the `_A_v1` suffix (or the version the prompt names).

## 1. Not generated yet

Checked every prompt's Output path against `assets/concept/` (140 images, the same on Austin's Mac and in the repo).

**Never generated:**

| Prompt | File | Notes |
|---|---|---|
| CAR-VEGA-05 Downhill steering sheet | `assets/prompts/cars/car_vega.md` | Give the generator `car_vega_steer_sheet_A_v2.png` as the reference. 3-frame and 1-frame fallbacks are in the file. The game stretches the level strip until this exists. |
| CAR-VEGA-06 Uphill steering sheet | `assets/prompts/cars/car_vega.md` | Same as above. |
| BG-SKYLINE-01R Fictional Skyline reroll | `assets/prompts/backgrounds/skyline.md` | Stage 8 is on hold until this exists. |

**Generated from an old design, need a rerun with the current prompt text:**

| Prompt | Why |
|---|---|
| CAR-VEGA-02 Orthographic views | The v1 image shows the round 1 Vega. Use `car_vega_hero_A_v2.png` as the reference. |
| CAR-VEGA-04 Crash tumble | Same. |
| CAR-BRUISER-02 to 04 | Wait for the Bruiser reroll below, then rerun with its description. |

**New reroll prompts for the five cars round 2 flagged as real-car lookalikes:** CAR-BRUISER-01R, CAR-SOL-01R, CAR-PHANTOM-01R, CAR-KESTREL-01R, CAR-MESA-01R. Each is at the bottom of its car file. Generate the hero first; if it reads as original, rerun that car's 02 to 04 with the new description and the new hero as the reference image.

## 2. New prompts

| Area | File | Prompts |
|---|---|---|
| Player cars | `cars/car_tempest.md`, `car_skipper.md`, `car_halo.md`, `car_cyclone.md` | 4 new cars, 4 prompts each (hero, views, steering, crash) |
| Car rerolls | `cars/car_bruiser.md`, `car_sol.md`, `car_phantom.md`, `car_kestrel.md`, `car_mesa.md` | 5 hero rerolls (01R) |
| Traffic | `traffic/traffic.md` | TRF-05 to TRF-10: big vehicle front views, 6 more everyday cars (rear and front), work vehicles, 8 more stage specials, turn signal and brake light frames |
| Drive-through pieces | `roadside/drive-through.md` | 11: Neon tunnel entrance, interior ring and sign gantry; Timberline covered bridge entrance and interior truss; Redrock rock arch; Bayou truss bridge; Harvest railway trestle; Thunderhead overpass; Skyline bridge pylon; Palm Coast welcome arch |
| Shared race pieces | `roadside/shared.md` | 5: checkpoint gate, start gantry with lights, road signs, barriers, crowds |
| Stage extras | `roadside/<stage>.md` | RS-*-05 for all 8 stages: six more props each |
| Power-ups | `powerups/powerups.md` | 4: pickups, HUD icons, effects, crate opening |

Suggested order: the three never-generated prompts first (they unblock hills and Skyline), then the drive-through and shared pieces (they unblock the tunnel, bridge and checkpoint gates in game), then the car rerolls, then everything else.

### New player cars (proposal)

Stats and unlocks are suggestions to fill out the roster; nothing in the game uses them yet.

| ID | Name | Archetype | Accel | Top speed | Handling | Unlock | Rear-view hook |
|---|---|---|---|---|---|---|---|
| `car_tempest` | Tempest LM | Endurance prototype | 3 | 5 | 4 | Stage 7 | Long tail, center shark fin, thin vertical light strips |
| `car_skipper` | Dune Skipper | Sand-rail buggy | 5 | 2 | 4 (half off-road penalty) | Stage 2 | Open tube cage, paddle tires |
| `car_halo` | Halo EV | Electric streamliner | 5 | 4 | 3 (4 shorter nitros) | Stage 6 | One big glowing ring taillight |
| `car_cyclone` | Cyclone | Reverse trike | 4 | 3 | 5 | Stage 4 | One fat center tire, front wheels on exposed arms |

### Drive-through pieces

The renderer has no sprite type that spans the road yet, which is why the Neon tunnel and the Timberline covered bridge are not in the game. The prompts ask for straight-on, symmetrical pieces with the opening filled with magenta, so the keyed sprite is a frame the road shows through. Tunnels and the covered bridge also get an interior ring, which the renderer repeats every few segments while the car is inside. Building the sprite type is separate work.

## 3. Power-ups (proposal)

Open question: does the game want power-ups at all? The genre usually has none, so this set is small, optional, and never a weapon. Default if approved: on in Single Race and Grand Tour, with an option to turn them off.

| Pickup | Effect | Why it fits |
|---|---|---|
| Nitro can | +1 nitro charge, up to the car's max | Rewards a risky line without a new system |
| Time clock | +3 s on the checkpoint timer | Arcade timer pressure, a small comeback tool |
| Ram plate | 5 s: traffic you hit is knocked flying instead of crashing you | Spectacle; traffic flying is fun to watch |
| Ghost | 4 s: drive through traffic and rivals | A clean escape from a traffic jam |
| Mystery crate | One of the above, weighted toward players further back | Mild, visible rubber banding |

Placement: two to four per stage, off the racing line or next to traffic, so taking one is a choice with a risk. One held slot on the HUD; nitro can and time clock apply on pickup, the others on a button press (the nitro button while the slot is full, or a separate button). Art prompts are in `assets/prompts/powerups/powerups.md`.
