# Traffic Vehicles

Generic civilian vehicles. Each needs a rear view (same direction traffic) and a front view (oncoming). All original, unbranded designs. Use the sprite-sheet suffix from the style guide.

## TRF-01 Everyday cars lineup
- **Output:** `assets/concept/traffic/trf01_cars.png`
- **Aspect:** 16:9
- **Round:** 2

```
Sprite sheet for an arcade racing game: six original unbranded everyday civilian cars in a row, seen straight from behind: a small round compact hatchback, a family sedan, a boxy station wagon, a minivan, a tiny bubble city car, and a convertible. Varied cheerful paint colors (mint, beige, sky blue, maroon, white, lemon). Same scale, isolated on a flat solid magenta #FF00FF background, no text, no plates. {STYLE}
```

## TRF-02 Everyday cars, front views
- **Output:** `assets/concept/traffic/trf02_cars_front.png`
- **Aspect:** 16:9
- **Round:** 3

```
Sprite sheet for an arcade racing game: the same six original civilian cars (compact hatchback, family sedan, station wagon, minivan, bubble city car, convertible) seen straight from the front with headlights on, as oncoming traffic. Same scale, isolated on a flat solid magenta #FF00FF background, no text, no plates. {STYLE}
```

## TRF-03 Big vehicles
- **Output:** `assets/concept/traffic/trf03_big.png`
- **Aspect:** 16:9
- **Round:** 2

```
Sprite sheet for an arcade racing game: large original unbranded vehicles seen straight from behind: a semi truck with a tall trailer, a yellow school-style bus with no text, a city box truck, a camper RV, and a car-carrier trailer loaded with small cars. Bold silhouettes, big taillights, isolated on a flat solid magenta #FF00FF background, no text. {STYLE}
```

## TRF-04 Stage-specific traffic
- **Output:** `assets/concept/traffic/trf04_stage_specials.png`
- **Aspect:** 16:9
- **Round:** 3

```
Sprite sheet for an arcade racing game, vehicles seen from behind: a beach surf van with surfboards on the roof, a vintage open-top tour bus with neon trim, a logging truck carrying pine logs, a green farm tractor, a pickup towing an airboat, and a classic taxi with a blank roof sign. Same scale, isolated on a flat solid magenta #FF00FF background, no text. {STYLE}
```

## Round 4 additions

The slicer (`tools/make_car_sprites.py`) finds each vehicle as one connected shape, so every sheet asks for clear gaps between vehicles. Keep the left-to-right order as written: the tool names sprites by position.

## TRF-05 Big vehicles, front views
- **Output:** `assets/concept/traffic/trf05_big_front.png`
- **Aspect:** 16:9
- **Round:** 4

```
Sprite sheet for an arcade racing game: the same five large original unbranded vehicles as oncoming traffic, seen straight from the front with headlights on: a semi truck cab with a tall trailer behind it, a yellow school-style bus with no text, a city box truck, a camper RV, and a car-carrier truck loaded with small cars. Same scale, each vehicle separate with clear gaps, isolated on a flat solid magenta #FF00FF background, no text, no plates. {STYLE}
```

## TRF-06 More everyday cars
- **Output:** `assets/concept/traffic/trf06_cars_more.png`
- **Aspect:** 16:9
- **Round:** 4

```
Sprite sheet for an arcade racing game: six more original unbranded civilian vehicles in a row, seen straight from behind: a small two-door pickup truck, a boxy compact SUV with a spare tire on the back, a long low 1970s-style coupe, a tall square delivery minivan, a three-wheeled tuk-tuk style microcar, and a small hatchback with a roof box. Varied cheerful paint colors (coral, forest green, cream, navy, orange, lilac). Same scale, each vehicle separate with clear gaps, isolated on a flat solid magenta #FF00FF background, no text, no plates. {STYLE}
```

## TRF-07 More everyday cars, front views
- **Output:** `assets/concept/traffic/trf07_cars_more_front.png`
- **Aspect:** 16:9
- **Round:** 4

```
Sprite sheet for an arcade racing game: the same six original civilian vehicles (small pickup, boxy compact SUV, long 1970s-style coupe, square delivery minivan, three-wheeled tuk-tuk microcar, hatchback with roof box) seen straight from the front with headlights on, as oncoming traffic. Same scale, each vehicle separate with clear gaps, isolated on a flat solid magenta #FF00FF background, no text, no plates. {STYLE}
```

## TRF-08 Work and service vehicles
- **Output:** `assets/concept/traffic/trf08_service.png`
- **Aspect:** 16:9
- **Round:** 4

```
Sprite sheet for an arcade racing game, original unbranded work vehicles seen straight from behind: a tow truck with a hook boom, a cement mixer truck with a striped drum, a round fuel tanker truck, a garbage truck, a slow street sweeper with flashing amber lights, and an ice cream truck with a giant cone shape on the roof. Bold silhouettes, big taillights, same scale, each vehicle separate with clear gaps, isolated on a flat solid magenta #FF00FF background, no text, no plates. {STYLE}
```

## TRF-09 Stage-specific traffic, set 2
- **Output:** `assets/concept/traffic/trf09_stage_specials_2.png`
- **Aspect:** 16:9
- **Round:** 4

```
Sprite sheet for an arcade racing game, original unbranded vehicles seen from behind, one for each place: a pink pedicab-style beach cruiser jeep with a fringed canopy roof, a red canyon tour jeep with roll bars, a white stretch limousine with neon underglow, a snowplow truck with a raised blade, a fishing pickup towing a small flat-bottom boat, a combine harvester with its reel folded up, a storm chaser van with a radar dish on the roof, and a double-decker city tour bus. Same scale, each vehicle separate with clear gaps, isolated on a flat solid magenta #FF00FF background, no text. {STYLE}
```

## TRF-10 Turn signal and brake light frames
- **Output:** `assets/concept/traffic/trf10_light_states.png`
- **Aspect:** 16:9
- **Reference image:** `assets/concept/traffic/trf01_cars_A_v1.png` (the family sedan)
- **Round:** 4

```
Sprite sheet for an arcade racing game: the same original beige family sedan seen straight from behind, four times in a row, identical in every way except the lights: taillights off, both brake lights glowing bright red, left amber turn signal blinking on, right amber turn signal blinking on. Same size and position in every frame, each car separate with clear gaps, isolated on a flat solid magenta #FF00FF background, no text, no plates. {STYLE}
```

Traffic that changes lanes flashes a turn signal first (docs/01-game-design.md, section 9). If the generator can't hold the car steady, the light glows can be cut from this sheet and drawn over any traffic sprite in engine.
