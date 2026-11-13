class_name SplitScreen
extends RefCounted
## Split-screen two player (MP-18): two players on one screen, player 1 on the top half and
## player 2 on the bottom, each 640x180 with its own sky, road and FX from its own camera
## (CameraView.SPLIT), sharing the road, the rivals and the traffic. The race (race.gd,
## `players`) does the driving; this is the layout and the rules a test can reach.
##
## Both players' cars are the online model's extra player cars (RivalCar.remote_player): a
## RivalCar not driven by an AIDriver, which the rivals' code leaves alone (`remote`) and the
## standings and the road renderer take like any other car. Player 1's is the race's `player`
## (a RivalCar, so player 2's road can draw it); player 2's is in `rivals.cars`, so player 1's
## road, the contacts and the standings have it.
##
## Hooks for later stories, not features here: two-player car and stage select (MP-19, player 2
## gets SplitScreen.second_car), the split HUD's polish (PR-27, SplitHud), device assignment
## (WH-18, InputRouter.split_pad) and per-player assists (AC-19, Race.split_input).

const PLAYERS := 2
const HALF := Vector2(Cfg.SCREEN_W, Cfg.SCREEN_H / 2.0)
## The horizon's row in a half: about a third down, sky above, the road and the car below.
const HORIZON := 60.0
## Pixels the car's base sits clear of the bottom of its half, at the least.
const CAR_MARGIN := 4.0
const NAMES := ["P1", "P2"]
## Each player's color (the HUD's tag, the results' rows): told apart by the P1/P2 tag too.
const COLORS := [Color("#ffd23a"), Color("#3ad0ff")]


## The rect of player `slot`'s half on the 640x360 screen: P1 on top, P2 below.
static func half_rect(slot: int) -> Rect2:
	return Rect2(Vector2(0.0, HALF.y * clampi(slot, 0, PLAYERS - 1)), HALF)


## The rows of the full 640x360 frame a half shows, from the top: the road, the background and
## the FX draw their usual frame, moved up this far and clipped to the half, so the horizon
## lands on HORIZON.
static func crop_top() -> float:
	return Cfg.HORIZON_Y - HORIZON


## Whether the split camera's car fits its half (`depth` the renderer's camera depth): its
## base on screen, cropped, above the half's bottom edge.
static func car_fits(depth: float) -> bool:
	return CameraView.car_base(CameraView.SPLIT, depth).y - crop_top() <= HALF.y - CAR_MARGIN


## A player's car in a split race, slot 0 or 1: the online model's player car
## (RivalCar.remote_player, named P1 / P2), sliding like the player's (rivals don't).
static func human(car: Dictionary, slot: int) -> RivalCar:
	var r := RivalCar.remote_player(car, slot)
	r.slides = true
	return r


## Player 2's car until two-player select (MP-19): the next car on from player 1's in
## Cars.LIST that `open` (car id -> bool) says is unlocked, round the list; player 1's own
## when no other is open.
static func second_car(first_id: String, open: Callable) -> String:
	var i := Cars.LIST.find(Cars.find(first_id))
	for n in range(1, Cars.LIST.size()):
		var id: String = Cars.LIST[(i + n) % Cars.LIST.size()]["id"]
		if open.call(id):
			return id
	return first_id


## Where player `slot` starts across the road: side by side behind the grid, P1 on the left
## (mirrored with the stage: `side`, Track.side).
static func grid_x(slot: int, side: float) -> float:
	return (-0.35 if slot == 0 else 0.35) * side


