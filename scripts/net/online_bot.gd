class_name OnlineBot
extends RefCounted
## A made-up guest for screenshots of an online race (--online=bot, game.online_from_flags):
## an OnlineSession on the in-memory relay whose "car" runs straight down its grid slot at a
## steady speed, so an online race can be looked at without a second window. It loads at
## once, finishes when it reaches the line, and with drop_at leaves partway (a disconnect).

var session: OnlineSession
var car := PlayerCar.new()
var speed := Cfg.MAX_SPEED * 0.8  # --bot-speed=F: that share of top speed
var drop_at := NAN  # --bot-drop=S: leaves the room at that race time
var finished := false


## A bot in `relay`'s room `room`, in car `car_id`, its messages `lag_ms` late (--bot-lag).
static func joining(relay: LoopLink.Relay, room: String, car_id: String, lag_ms := 0) -> OnlineBot:
	var b := OnlineBot.new()
	var l := LoopLink.new(relay)
	l.lag_ms = lag_ms
	l.join(room)
	b.session = OnlineSession.joining_on(l, car_id)
	return b


## A tick: its room polled; on the grid with `race` (race.gd, or null in the lobby), then off
## at its speed once the race is on, sending its car as a game does. Over the line it says READY.
func tick(dt: float, race: Node) -> void:
	var s := session
	s.poll(dt)
	if s.phase == OnlineSession.Phase.CLOSED:
		return
	if s.started:
		s.started = false
		finished = false
		s.loaded()
	if race == null or race.player == null or not s.go:
		return
	if race.counting_down():
		car.distance = race.player.distance
		car.x = OnlineSession.grid_x(s.slot) * race.track.side()
		car.speed = 0.0
		return
	if not is_nan(drop_at) and race.race_time >= drop_at:
		s.leave()
		return
	car.speed = speed
	car.distance += speed * dt
	s.send_car(car)
	if not finished and car.distance >= race.finish_distance:
		finished = true
		s.finish(race.race_time)
		s.ready_again()  # (READY for the next, as a player would on the results)
