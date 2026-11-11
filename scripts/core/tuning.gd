class_name Tuning
extends RefCounted
## The tuning registry (EQ-15): the driving, AI, traffic, drafting, launch, power-up, scoring
## and camera numbers, and the look of the world (WORLD: the wet road, the tour's sundown, the
## headlights), each with a default, a range and a step. The game reads them here
## (`Tuning.v("driving/steer_rate")`) where it once read constants. Overrides come from
## `user://tuning.cfg` (or `--tuning-file=PATH`), which the debug panel (F3, EQ-16) writes;
## tests and golden traces run on the defaults (use_defaults). Not an autoload: a self-updated
## game keeps its installed autoload list (see test_updater).

const PATH := "user://tuning.cfg"
const PRESET_DIR := "user://tuning_presets"
const LOG_PATH := "user://tuning_log.txt"
## The areas, in the debug panel's page order. A key is "area/name".
const AREAS := ["driving", "slide", "crashes", "ai", "difficulty", "balance", "traffic", "draft", "launch", "power_ups", "scoring", "camera",
	"world", "assists", "first_drive"]
const AREA_NAMES := ["DRIVING", "POWER SLIDE", "CRASHES", "AI RIVALS", "DIFFICULTY", "STAGE BALANCE", "TRAFFIC", "DRAFTING", "LAUNCH", "POWER-UPS", "SCORING",
	"CAMERA", "WORLD", "ASSISTS", "FIRST DRIVE"]
## key: [default, min, max, step, what it is]. tools/tuning_adopt.py rewrites the defaults in
## place, so keep one value to a line, the default first.
const TABLE := {
	"driving/accel_time": [3.2, 1.5, 6.0, 0.1, "seconds of full throttle to top speed (top speed over this is ACCEL)"],
	"driving/accel_start": [1.3, 0.5, 2.5, 0.05, "acceleration multiplier from a standstill"],
	"driving/accel_fade": [0.8, 0.0, 1.5, 0.05, "how much of accel_start is gone by top speed"],
	"driving/braking_time": [1.4, 0.5, 4.0, 0.1, "seconds of full brake from top speed to a stop"],
	"driving/coast_time": [6.0, 2.0, 15.0, 0.5, "seconds coasting from top speed to a stop"],
	"driving/offroad_decel_time": [1.8, 0.5, 5.0, 0.1, "seconds off the road from top speed down to the off-road limit"],
	"driving/offroad_limit": [3.5, 1.5, 8.0, 0.1, "off the road the car keeps top speed over this"],
	"driving/steer_rate": [2.2, 1.0, 4.0, 0.05, "road half-widths per second at full lock and top speed"],
	"driving/centrifugal": [0.3, 0.0, 0.8, 0.01, "how hard curves pull the car outward"],
	"driving/steer_smoothing": [12.0, 2.0, 30.0, 1.0, "how fast the shown steering follows the input, per second"],
	"driving/air_steer": [0.35, 0.0, 1.0, 0.05, "share of the steering left in the air"],
	"driving/gravity": [12000.0, 4000.0, 24000.0, 500.0, "world units per second squared: lower jumps further"],
	"driving/takeoff_speed": [0.4, 0.0, 1.0, 0.05, "share of top speed under which a crest doesn't launch the car"],
	"driving/overspeed_decay": [0.4, 0.1, 2.0, 0.05, "share of top speed per second shed back down after nitro"],
	"driving/nitro_time": [3.0, 1.0, 6.0, 0.1, "seconds one nitro burns (a car's nitro_time scales it)"],
	"driving/nitro_speed": [1.25, 1.0, 1.6, 0.01, "top speed multiplier while nitro burns"],
	"driving/nitro_accel": [1.8, 1.0, 3.0, 0.05, "acceleration multiplier while nitro burns"],
	"slide/speed": [0.5, 0.2, 1.0, 0.05, "share of top speed a power slide starts at, at least"],
	"slide/brake": [0.5, 0.1, 1.0, 0.05, "brake that starts a slide, at least"],
	"slide/steer": [0.5, 0.1, 1.0, 0.05, "lock that starts a slide, at least"],
	"slide/hold": [0.3, 0.0, 1.0, 0.05, "lock the same way that keeps it going"],
	"slide/exit_speed": [0.35, 0.1, 1.0, 0.05, "share of top speed under which it ends"],
	"slide/turn": [1.5, 1.0, 3.0, 0.05, "steering multiplier while sliding: a tighter line"],
	"slide/decel": [0.1, 0.0, 0.5, 0.01, "share of top speed per second the slide scrubs off"],
	"crashes/crash_time": [1.6, 0.5, 4.0, 0.1, "seconds a roadside crash lasts"],
	"crashes/crash_braking": [1.2, 0.3, 3.0, 0.1, "share of top speed per second a crashed car slows"],
	"crashes/recover_rate": [1.5, 0.5, 4.0, 0.1, "road half-widths per second a crashed car slides back"],
	"crashes/hit_overlap": [0.8, 0.4, 1.0, 0.05, "share of two cars' half-widths that must overlap to touch"],
	"crashes/crash_closing": [0.5, 0.1, 1.0, 0.05, "share of top speed of closing speed that crashes, not bumps"],
	"crashes/bump_keep": [0.85, 0.5, 1.0, 0.01, "share of the car's speed a bump leaves you, at least"],
	"crashes/traffic_spin_time": [0.6, 0.2, 2.0, 0.05, "seconds a spin off the back of traffic lasts"],
	"crashes/traffic_spin_keep": [0.7, 0.2, 1.0, 0.05, "share of the hit car's speed you keep after the spin"],
	"crashes/sideswipe_loss": [0.05, 0.0, 0.3, 0.01, "share of your speed a side-swipe scrubs off"],
	"crashes/head_on_time": [1.0, 0.3, 3.0, 0.1, "seconds a head-on with oncoming traffic lasts"],
	"crashes/head_on_keep": [0.25, 0.0, 1.0, 0.05, "share of your speed you keep after a head-on"],
	"crashes/tumble_slow": [0.5, 0.2, 1.5, 0.05, "share of a crash's length it lasts hit at a standstill (RC-22)"],
	"crashes/tumble_fast": [1.1, 0.5, 2.0, 0.05, "and hit at top speed; between, by the speed of the hit"],
	"crashes/big_hit": [0.75, 0.0, 1.0, 0.05, "share of top speed a hit needs for the slow motion"],
	"crashes/slowmo_time": [0.35, 0.0, 1.0, 0.05, "seconds (real time) a big hit holds the slow motion (none with reduce motion)"],
	"crashes/slowmo_scale": [0.3, 0.1, 1.0, 0.05, "how fast the race runs in it"],
	"crashes/respawn_ghost": [1.0, 0.0, 3.0, 0.1, "seconds a car is ghosted once its crash is over, so nothing hits it at once"],
	"ai/line_gain": [0.09, 0.0, 0.3, 0.01, "road half-widths toward the inside per unit of curve ahead"],
	"ai/line_max": [0.55, 0.0, 1.0, 0.05, "furthest inside the racing line goes"],
	"ai/steer_gain": [1.5, 0.5, 4.0, 0.1, "how hard a rival steers toward its line"],
	"ai/corner_grip": [0.85, 0.5, 1.0, 0.01, "share of full lock a bend may take at speed"],
	"ai/lift_time": [0.5, 0.1, 2.0, 0.05, "seconds behind a car with nowhere to go before lifting"],
	"ai/brake_time": [0.25, 0.05, 1.0, 0.05, "and before braking"],
	"ai/nitro_speed": [0.85, 0.3, 1.0, 0.05, "share of top speed before a rival fires nitro"],
	"ai/nitro_rate": [0.6, 0.0, 3.0, 0.1, "chance per second of nitro once everything allows it"],
	"ai/block_range": [1500.0, 0.0, 4000.0, 100.0, "world units behind that an aggressive rival blocks within"],
	"ai/block_time": [1.5, 0.0, 5.0, 0.1, "seconds it blocks at most"],
	"ai/block_rest": [5.0, 0.0, 15.0, 0.5, "seconds it lets a car by after"],
	"ai/swerve_rate": [0.25, 0.0, 2.0, 0.05, "chance per second an erratic rival picks a new line"],
	"ai/band_range": [4000.0, 500.0, 15000.0, 250.0, "world units from the player where the rubber band is full"],
	"ai/band_max": [0.08, 0.0, 0.3, 0.01, "most the rubber band changes a rival's speed, either way"],
	"ai/contact_slowdown": [0.97, 0.8, 1.0, 0.01, "share of the front car's speed the car behind drops to on contact"],
	"ai/side_push_loss": [0.02, 0.0, 0.2, 0.01, "share of speed a side contact between racers scrubs off"],
	"difficulty/easy_pace": [0.94, 0.8, 1.1, 0.01, "easy: every rival's pace times this"],
	"difficulty/easy_ease": [0.08, 0.0, 0.3, 0.01, "easy: most a rival ahead of you gives up (the rubber band)"],
	"difficulty/easy_boost": [0.02, 0.0, 0.3, 0.01, "easy: most a rival behind you gains"],
	"difficulty/normal_pace": [1.0, 0.8, 1.1, 0.01, "normal: every rival's pace times this"],
	"difficulty/normal_ease": [0.05, 0.0, 0.3, 0.01, "normal: most a rival ahead of you gives up"],
	"difficulty/normal_boost": [0.04, 0.0, 0.3, 0.01, "normal: most a rival behind you gains"],
	"difficulty/hard_pace": [1.03, 0.8, 1.1, 0.01, "hard: every rival's pace times this"],
	"difficulty/hard_ease": [0.02, 0.0, 0.3, 0.01, "hard: most a rival ahead of you gives up"],
	"difficulty/hard_boost": [0.06, 0.0, 0.3, 0.01, "hard: most a rival behind you gains"],
	"difficulty/easy_clock": [1.1, 0.5, 2.0, 0.05, "easy: each checkpoint's time bonus times this, on top of the timer option (RC-23)"],
	"difficulty/normal_clock": [1.0, 0.5, 2.0, 0.05, "normal: each checkpoint's time bonus times this"],
	"difficulty/hard_clock": [0.9, 0.5, 2.0, 0.05, "hard: each checkpoint's time bonus times this (the autodrive still makes it, test_golden)"],
	"balance/palm_coast": [1.0, 0.9, 1.1, 0.01, "Palm Coast: every rival's pace times this, on top of the difficulty's"],
	"balance/redrock": [1.0, 0.9, 1.1, 0.01, "Redrock Canyon: every rival's pace times this, on top of the difficulty's"],
	"balance/neon": [1.0, 0.9, 1.1, 0.01, "Neon Strip: every rival's pace times this, on top of the difficulty's"],
	"balance/timberline": [1.0, 0.9, 1.1, 0.01, "Timberline Pass: every rival's pace times this, on top of the difficulty's"],
	"balance/bayou": [1.0, 0.9, 1.1, 0.01, "Bayou Causeway: every rival's pace times this, on top of the difficulty's"],
	"balance/harvest": [1.0, 0.9, 1.1, 0.01, "Harvest Valley: every rival's pace times this, on top of the difficulty's"],
	"balance/thunder": [1.0, 0.9, 1.1, 0.01, "Thunderhead Highway: every rival's pace times this, on top of the difficulty's"],
	"balance/skyline": [1.0, 0.9, 1.1, 0.01, "Skyline Finale: every rival's pace times this, on top of the difficulty's"],
	"traffic/signal_time": [1.0, 0.0, 3.0, 0.1, "seconds a car signals before it changes lanes"],
	"traffic/changer_share": [0.5, 0.0, 1.0, 0.05, "share of the cars with signals that change lanes"],
	"traffic/change_retry": [1.5, 0.2, 5.0, 0.1, "seconds before trying again when the next lane is taken"],
	"traffic/merge_speed": [0.8, 0.2, 3.0, 0.1, "road half-widths per second moving over where lanes merge"],
	"traffic/fling_time": [0.8, 0.2, 3.0, 0.1, "seconds a rammed car flies"],
	"traffic/fling_speed": [4.0, 1.0, 10.0, 0.25, "road half-widths per second it flies sideways"],
	"traffic/return_speed": [1.2, 0.2, 4.0, 0.1, "road half-widths per second it drifts back to its lane"],
	"traffic/spawn_clear": [40, 0, 150, 5, "segments past a blind crest, a tunnel mouth or the start where no traffic spawns"],
	"traffic/behind_clear": [100, 0, 300, 10, "segments behind the start where nothing spawns, to roll up to the grid in the countdown"],
	"traffic/oncoming_clear": [150, 0, 400, 10, "segments ahead of the start where nothing spawns coming the other way, to meet the grid"],
	"traffic/busy": [2.5, 1.0, 5.0, 0.1, "traffic per segment on a busy stretch (a town), against an ordinary one's 1"],
	"traffic/quiet": [0.4, 0.0, 1.0, 0.05, "and on a quiet one (a causeway, the switchbacks)"],
	"traffic/horn_reach": [2500.0, 500.0, 6000.0, 100.0, "world units ahead the horn reaches a car in your path"],
	"traffic/horn_delay": [0.5, 0.0, 2.0, 0.05, "seconds before a honked car gives way"],
	"traffic/horn_nudge": [0.15, 0.0, 0.25, 0.01, "road half-widths it keeps over in its lane when the next one is taken"],
	"traffic/horn_hold": [3.0, 0.5, 8.0, 0.25, "seconds it keeps over"],
	"traffic/blind_crest": [0.3, 0.1, 1.0, 0.05, "slope change over a crest that hides the road beyond it"],
	"draft/length": [1200.0, 300.0, 3000.0, 100.0, "world units behind a car its wake reaches"],
	"draft/width": [0.35, 0.1, 1.0, 0.05, "road half-widths either side of its center"],
	"draft/min_speed": [0.5, 0.0, 1.0, 0.05, "share of top speed under which a racer leaves no wake"],
	"draft/keep_up": [0.8, 0.3, 1.0, 0.05, "share of a big vehicle's speed you must keep to use its wake"],
	"draft/fill_time": [1.5, 0.3, 5.0, 0.1, "seconds in the wake to fill the meter"],
	"draft/decay_time": [1.0, 0.2, 5.0, 0.1, "seconds out of it to empty"],
	"draft/boost_time": [3.0, 0.5, 8.0, 0.1, "seconds the slipstream boost lasts"],
	"draft/speed_mult": [1.08, 1.0, 1.3, 0.01, "top speed multiplier while it lasts"],
	"launch/window_before": [0.3, 0.0, 1.0, 0.05, "seconds before GO the gas may go down for a launch"],
	"launch/window_after": [0.15, 0.0, 1.0, 0.05, "and after"],
	"launch/boost_time": [1.0, 0.2, 3.0, 0.1, "seconds of launch acceleration"],
	"launch/boost_accel": [1.7, 1.0, 3.0, 0.05, "acceleration multiplier while it lasts"],
	"launch/bog_time": [0.7, 0.0, 2.0, 0.1, "seconds bogged down after a jumped start"],
	"launch/bog_accel": [0.35, 0.0, 1.0, 0.05, "acceleration multiplier while bogged"],
	"launch/roll_time": [1.5, 0.0, 3.0, 0.1, "last seconds of the countdown the field rolls forward"],
	"launch/roll_speed": [300.0, 0.0, 1500.0, 50.0, "world units per second it rolls at"],
	"power_ups/clock_bonus": [3.0, 0.0, 10.0, 1.0, "seconds a clock pickup adds"],
	"power_ups/ram_time": [5.0, 1.0, 15.0, 0.5, "seconds the ram plate lasts"],
	"power_ups/ghost_time": [4.0, 1.0, 15.0, 0.5, "seconds the ghost lasts"],
	"power_ups/catch_up_places": [2, 0, 7, 1, "the last this many places get a nitro back at each checkpoint (easy and normal)"],
	"power_ups/reach": [0.3, 0.1, 1.0, 0.05, "road half-widths from a pickup's center that take it"],
	"scoring/near_miss": [1, 0, 10, 1, "points for a near miss"],
	"scoring/near_miss_room": [0.0, -0.3, 0.5, 0.05, "road half-widths between the two cars' sides that count as near"],
	"scoring/near_miss_speed": [0.6, 0.0, 1.0, 0.05, "share of top speed a near miss needs, at least"],
	"scoring/chain_window": [2.0, 0.5, 5.0, 0.1, "seconds after a near miss the next one chains (x2, x3...)"],
	"scoring/chain_max": [5, 1, 10, 1, "most a chain multiplies a near miss's points by"],
	"scoring/air": [1, 0, 10, 1, "points for AIR"],
	"scoring/big_air": [2, 0, 10, 1, "points for BIG AIR"],
	"scoring/air_time": [0.5, 0.1, 2.0, 0.1, "seconds off the ground for AIR"],
	"scoring/big_air_time": [1.0, 0.2, 3.0, 0.1, "seconds off the ground for BIG AIR"],
	"scoring/clean_section": [3, 0, 10, 1, "points for a section without contact"],
	"scoring/no_crash": [5, 0, 20, 1, "points for a race without a crash"],
	"scoring/draft": [1, 0, 10, 1, "points for a slipstream boost"],
	"camera/height": [1000.0, 400.0, 2500.0, 50.0, "world units the camera rides above the road"],
	"camera/depth": [0.84, 0.5, 1.5, 0.01, "1 / tan(half the field of view): lower is wider"],
	"camera/far_height": [1450.0, 400.0, 3000.0, 50.0, "CHASE FAR view (WS-15): world units above the road"],
	"camera/far_distance": [2600.0, 1500.0, 5000.0, 100.0, "and world units behind the car"],
	"camera/bumper_height": [450.0, 150.0, 1500.0, 25.0, "BUMPER view: world units above the road"],
	"camera/bumper_distance": [150.0, 50.0, 1500.0, 25.0, "and world units behind the car's nose"],
	"camera/shake_crash": [5.0, 0.0, 15.0, 0.5, "screen pixels of shake on a crash"],
	"camera/shake_landing": [3.0, 0.0, 10.0, 0.5, "on a landing"],
	"camera/shake_takeoff": [1.5, 0.0, 10.0, 0.5, "leaving the road over a crest"],
	"camera/shake_offroad": [1.5, 0.0, 10.0, 0.5, "off the road at top speed"],
	"camera/shake_settle": [12.0, 1.0, 40.0, 1.0, "pixels per second back to still"],
	"camera/nitro_fov_stretch": [0.05, 0.0, 0.2, 0.01, "share the view widens while nitro burns"],
	"camera/nitro_fov_rate": [0.15, 0.01, 1.0, 0.01, "share per second the stretch eases in and out"],
	"world/tour_start_hour": [15.0, 6.0, 24.0, 0.25, "Grand Tour: the time of day on the first stage (WS-16)"],
	"world/tour_end_hour": [22.0, 6.0, 24.0, 0.25, "and on the last; the stages between step evenly"],
	"world/sundown_tint": [1.0, 0.0, 1.0, 0.05, "how far a stage shown later than its own hour takes that light"],
	"world/sprite_tint": [0.8, 0.0, 1.0, 0.05, "share of it on the sprites and cars"],
	"world/shadow_stretch": [2.5, 1.0, 5.0, 0.1, "cars' shadows this many times as long with the sun low"],
	"world/headlight_alpha": [0.45, 0.0, 1.0, 0.05, "how bright the headlights' pool on the road is, at the car (WS-17)"],
	"world/headlight_reach": [3200.0, 500.0, 8000.0, 100.0, "world units ahead the pool reaches"],
	"world/headlight_near": [0.3, 0.05, 1.0, 0.05, "the pool's half-width at the car, in road half-widths"],
	"world/headlight_spread": [0.7, 0.1, 2.0, 0.05, "and at its far end"],
	"world/tail_glow": [0.6, 0.0, 1.0, 0.05, "how bright the tail lights glow in the dark"],
	"world/wet_sheen": [1.6, 0.0, 3.0, 0.05, "how far the wet road goes toward the sky's color, times the weather's wet"],
	"world/wet_gloss": [0.12, 0.0, 0.5, 0.01, "share of that sheen right under the car (the far road has all of it)"],
	"world/reflect_alpha": [0.55, 0.0, 1.0, 0.05, "how strongly the sky and the skyline reflect in the wet road"],
	"world/reflect_reach": [120, 0, 300, 10, "segments ahead the reflections are drawn (each is another draw)"],
	"world/reflect_stretch": [2.6, 1.0, 6.0, 0.1, "how far down the road a reflection is drawn out into streaks"],
	"world/puddle_share": [0.3, 0.0, 1.0, 0.05, "share of the near road's segments with a puddle"],
	"world/puddle_glint": [0.65, 0.0, 1.0, 0.05, "how bright a puddle's highlight is"],
	"world/puddle_reach": [60, 0, 200, 5, "segments ahead that puddles are drawn"],
	"assists/co_pilot_gain": [1.5, 0.5, 4.0, 0.1, "co-pilot: lock per road half-width off its lane's middle"],
	"assists/co_pilot_edge": [4.0, 0.0, 10.0, 0.5, "co-pilot: extra lock per half-width past the outer lanes, back toward the road"],
	"assists/co_pilot_nudge": [0.6, 0.1, 1.0, 0.05, "co-pilot: share of the steering a full push of the player's takes over"],
	"first_drive/gas_hold": [1.0, 0.2, 3.0, 0.1, "first drive (MP-15): seconds of gas that clear HOLD THE GAS"],
	"first_drive/steer_hold": [0.5, 0.1, 2.0, 0.1, "seconds of steering that clear STEER"],
	"first_drive/steer_speed": [0.15, 0.0, 0.6, 0.05, "share of top speed before STEER comes up"],
	"first_drive/nitro_speed": [0.3, 0.0, 0.8, 0.05, "share of top speed before NITRO comes up"],
	"first_drive/straight_reach": [40, 10, 120, 5, "segments ahead that must run straight for NITRO"],
	"first_drive/straight_curve": [0.5, 0.0, 3.0, 0.1, "the most curve there that still counts as straight"],
	"first_drive/bend_reach": [30, 5, 100, 5, "segments ahead a bend brings up POWER SLIDE"],
	"first_drive/bend_curve": [3.0, 1.0, 6.0, 0.25, "the least curve that counts as a bend to slide"],
	"first_drive/truck_reach": [4000.0, 1000.0, 10000.0, 250.0, "world units ahead a big vehicle brings up DRAFT"],
	"first_drive/min_show": [2.0, 0.5, 6.0, 0.25, "seconds a prompt stays up at least, the road allowing it or not"],
	"first_drive/withdraw": [1.0, 0.0, 4.0, 0.25, "seconds of the road no longer allowing it before it goes back to wait"],
	"first_drive/gap": [1.5, 0.0, 5.0, 0.25, "seconds between one prompt and the next"],
}

## Where overrides are read from and saved to; "" keeps them in memory only (tests).
static var path := PATH
static var preset_dir := PRESET_DIR
static var log_path := LOG_PATH
static var _over := {}  # key -> value, only the ones that differ from the default
static var _booted := false


## A value: the override, or the default.
static func v(key: String) -> float:
	return _over.get(key, TABLE[key][0])


## A whole-number value (points).
static func i(key: String) -> int:
	return roundi(v(key))


static func default_of(key: String) -> float:
	return TABLE[key][0]


static func min_of(key: String) -> float:
	return TABLE[key][1]


static func max_of(key: String) -> float:
	return TABLE[key][2]


static func step_of(key: String) -> float:
	return TABLE[key][3]


static func help(key: String) -> String:
	return TABLE[key][4]


## Whether the value counts whole numbers (points): its default is an int.
static func whole(key: String) -> bool:
	return TABLE[key][0] is int


## The keys of an area (AREAS), in table order.
static func keys_in(area: String) -> Array[String]:
	var out: Array[String] = []
	for k: String in TABLE:
		if k.get_slice("/", 0) == area:
			out.append(k)
	return out


## Sets a value, clamped to its range and snapped to its step (from its minimum). Back at the
## default, the override goes. Returns the value it took.
static func set_value(key: String, value: float) -> float:
	if not TABLE.has(key):
		return NAN
	var to := clampf(snappedf(value - min_of(key), step_of(key)) + min_of(key), min_of(key), max_of(key))
	if whole(key):
		to = roundf(to)
	if is_equal_approx(to, default_of(key)):
		_over.erase(key)
		return default_of(key)
	_over[key] = to
	return to


## One step up (`dir` 1) or down (-1), `times` steps at once (a held key).
static func nudge(key: String, dir: int, times := 1) -> float:
	return set_value(key, v(key) + signi(dir) * step_of(key) * times)


static func reset(key: String) -> void:
	_over.erase(key)


static func reset_all() -> void:
	_over.clear()


static func tuned(key: String) -> bool:
	return _over.has(key)


## Whether anything differs from the defaults (the HUD's TUNED badge).
static func any_tuned() -> bool:
	return not _over.is_empty()


## The overrides, key -> value.
static func overrides() -> Dictionary:
	return _over.duplicate()


## Loads the overrides once per run, from `file` (the default or `--tuning-file`). A missing
## file is the defaults.
static func boot(file := PATH) -> void:
	if _booted:
		return
	_booted = true
	path = file
	load_file(path)


## Tests and golden traces: the defaults, and nothing read or written (boot does nothing).
static func use_defaults() -> void:
	_booted = true
	path = ""
	_over.clear()


## Replaces the overrides with a file's. Unknown keys are skipped, values clamped. A missing
## or unreadable file is the defaults. Returns false when it couldn't be read.
static func load_file(file: String) -> bool:
	_over.clear()
	if file == "" or not FileAccess.file_exists(file):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(file) != OK:
		return false
	for area in cfg.get_sections():
		for name in cfg.get_section_keys(area):
			var key: String = area + "/" + name
			var val: Variant = cfg.get_value(area, name)
			if TABLE.has(key) and (val is float or val is int):
				set_value(key, val)
	return true


## Writes the overrides (only those) to `file`, section per area.
static func save_file(file: String) -> bool:
	if file == "":
		return false
	var cfg := ConfigFile.new()
	for key: String in _over:
		cfg.set_value(key.get_slice("/", 0), key.get_slice("/", 1), _over[key])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(file.get_base_dir()))
	return cfg.save(file) == OK


## Saves to `path` (the overrides the next run starts with), if there is one.
static func save() -> bool:
	return save_file(path)


## The named presets saved (preset_dir), sorted.
static func presets() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(preset_dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.get_extension() == "cfg":
			out.append(f.get_basename())
	out.sort()
	return out


## A preset name as a file name: letters, digits, - and _ only.
static func preset_file(name: String) -> String:
	var clean := ""
	for c in name.strip_edges().to_lower():
		clean += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "-" or c == "_" else "_"
	return preset_dir.path_join(clean + ".cfg") if clean != "" else ""


static func save_preset(name: String) -> bool:
	var f := preset_file(name)
	return f != "" and save_file(f)


static func load_preset(name: String) -> bool:
	return load_file(preset_file(name))


## Appends a line to the tuning log: when, where (stage, car, race time) and what changed.
static func log_change(line: String) -> void:
	if log_path == "":
		return
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(Time.get_datetime_string_from_system(false, true) + "  " + line)


## A value as the panel and the log show it: whole numbers plain, the rest to its step.
static func text(key: String, value: float) -> String:
	if whole(key):
		return str(roundi(value))
	var places := 0
	var step := step_of(key)
	while places < 4 and absf(step * pow(10.0, places) - roundf(step * pow(10.0, places))) > 0.0001:
		places += 1
	return ("%." + str(places) + "f") % value
