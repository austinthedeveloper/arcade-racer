extends Node
## Main scene: the front end (title, mode select, options, stage select, car select) and the
## race it starts. An exported desktop game opens on the update screen first (UpdateScreen).
## Race dev flags (--autodrive, --stage=N, --race) skip the menus and go straight to a race;
## --online=host or --online=join:CODE straight into a room (online_from_flags).
## Left idle on the title, it plays an attract-mode demo race (Attract) until any input.

enum Screen { TITLE, MODES, OPTIONS, STAGES, CARS, RACE, REMAP, UPDATE, WHEEL, ONLINE, STATS, PROFILES, FINALE, CREDITS, CONTROLS, STICKERS, COMPLETION, DAILY }

const RACE_SCENE := preload("res://scenes/race.tscn")
const RACE_FLAGS := ["--autodrive", "--race", "--stage="]
const STAGED_JOYPAD := 99  # stage_unplug's joypad
## Under the tour's finale and the credits: NIGHT DRIVE (Radio), or where the build has no
## radio/ folder (the Web), NEON FM's first song.
static func finale_song() -> String:
	return "synthwave_night_drive" if SoundBank.path_for("synthwave_night_drive") != "" else "station_synthwave"

var screen := Screen.TITLE
var mode_index := 0  # into ModeSelect.Item, the last mode picked
var stage_index := 0  # into Stages
var car_index := 0  # into Cars
## The MIRROR toggle on stage select (WS-6): races a stage mirrored where that's open
## (mirror_for). Not saved; --mirror turns it on.
var mirror := false
## The daily run's day (MP-14, Daily.day_key): 0 for today on this machine's calendar;
## --day=YYYYMMDD stages another (screenshots).
var day := 0
var menu: MenuScreen
var race: Node  # race.gd, while racing
## The online room (ON-2), from HOST or JOIN until it's left; polled every tick, menus or race.
var online: OnlineSession
## Makes the line HOST and JOIN open: through the relay; tests and screenshots set an in-memory one.
var make_link: Callable = func() -> NetLink: return RelayLink.new()
## --online=host / join:CODE (online_from_flags): "host" or "join", or "" from the menus.
var auto_online := ""
var auto_players := 2  # --players=N: the host starts once this many are in
var auto_races := 1  # --races=N: rematches (ON-9) before the finishes are printed and it quits
var _auto_done := 0  # races finished so far
var _auto_again := false  # this race's finish has been seen: READY said, the next stage picked
var _auto_started := false
var bots: Array = []  # --online=bot: the made-up guests (OnlineBot)
var _bot_relay: LoopLink.Relay
var _auto_room_said := false
## Seconds on the title with no input before a demo starts. --attract-delay=N sets it
## (the e2e sets it directly).
var attract_delay := Attract.IDLE_SECONDS
var idle := 0.0  # seconds on the title with no input
var tour_step := 0  # the attract tour's next step (Attract.step), counting on across loops
var attract_time := 0.0  # seconds the tour's controls card has been up
var on_quit := Callable()  # in place of quitting (quit), for tests
## Menu ticks to ignore after a demo ends, so the press that ended it doesn't also pick
## something on the title.
var _swallow := 0

var calibration: CalibrationWizard
var debug_overlay: InputDebugOverlay
var debug_panel: DebugPanel
var _layer: CanvasLayer
var _menu_shot := ""
## What's new (WhatsNew) may come up on the title: not for a staged screenshot (--menu-shot),
## which neither shows it nor marks it seen; --screen=whats_new stages it.
var news_allowed := true
## The onboarding (who's driving AC-16, the wheel's first run WH-16, the first drive MP-15)
## may come up: not for a staged screenshot (--menu-shot) unless it stages one of them, and
## the first drive not in a race the dev flags started or a screenshot (--first-drive asks
## for it there).
## WhosDriving.enabled turns all of it off (the test runners).
var onboarding := true
var first_drive_allowed := true
## Where the options screen goes back to (close_options): the title unless whoever opened
## it says otherwise.
var _options_back := Callable()
var _options_back_name := "the title screen"


func _ready() -> void:
	# Errors and the last log lines to user://logs/ (EQ-20; --log-dir=DIR elsewhere). The test
	# runners install theirs into scratch first, so this one is then kept out.
	CrashLog.install(DevArgs.value("--log-dir", CrashLog.DIR))
	_layer = CanvasLayer.new()
	_layer.layer = 2  # over the race, for options from its pause menu
	add_child(_layer)
	Tuning.boot(DevArgs.value("--tuning-file", Tuning.PATH))
	debug_overlay = InputDebugOverlay.new()
	calibration = CalibrationWizard.new()
	debug_panel = DebugPanel.new()
	var top := CanvasLayer.new()
	top.layer = 3
	add_child(top)
	top.add_child(debug_overlay)
	top.add_child(calibration)
	top.add_child(debug_panel)
	var quick := false
	var pause_shot := false
	var unplug_shot := false
	var replug_shot := ""  # --screen=replugged (a different wheel) or replugged:same
	var debug_page := ""  # --screen=debug[:page]: the tuning panel, over a race given race flags
	var controls_shot := false  # --screen=pause:controls: the controls card over the paused race
	var car := DevArgs.value("--car")
	if car != "":
		car_index = maxi(0, Cars.LIST.find(Cars.find(car)))
	mirror = DevArgs.has("--mirror")
	day = int(DevArgs.value("--day", "0"))
	news_allowed = DevArgs.value("--menu-shot") == ""
	onboarding = news_allowed
	var mode := DevArgs.value("--mode")
	if mode != "":
		mode_index = ModeSelect.Item.get(mode.to_upper(), mode_index)
	for arg in OS.get_cmdline_user_args():
		for flag: String in RACE_FLAGS:
			quick = quick or arg.begins_with(flag)
		if arg == "--screen=pause" or arg == "--screen=pause:controls":
			pause_shot = true
			controls_shot = arg.ends_with(":controls")
		elif arg == "--screen=unplugged":
			pause_shot = true
			unplug_shot = true
		elif arg.begins_with("--screen=replugged"):
			pause_shot = true
			unplug_shot = true
			replug_shot = arg.get_slice(":", 1) if arg.contains(":") else "different"
		elif arg == "--screen=results":
			quick = true  # a race, staged to a finish (race.gd)
		elif arg.begins_with("--screen=debug"):
			debug_page = arg.get_slice(":", 1) if arg.contains(":") else Tuning.AREAS[0]
		elif arg.begins_with("--screen="):
			_open(arg.get_slice("=", 1))
		elif arg.begins_with("--menu-shot="):
			_menu_shot = arg.get_slice("=", 1)
		elif arg.begins_with("--attract-delay="):
			attract_delay = float(arg.get_slice("=", 1))
	first_drive_allowed = (not quick and news_allowed) or DevArgs.has("--first-drive")
	var auto := DevArgs.value("--online")
	if auto != "":
		online_from_flags(auto, int(DevArgs.value("--players", "2")))
	elif quick or pause_shot:
		start_race()
	elif menu == null and race == null:  # (--screen=demo starts a race)
		if Updates.state != Updater.State.OFF:
			show_update()
		else:
			show_title()
	if unplug_shot:
		stage_unplug()
		if replug_shot != "":
			stage_replug(replug_shot == "same")
	elif pause_shot:
		race.pause()
		if controls_shot:
			race.pause_menu.open_controls()
	if debug_page != "":
		if menu == null and race == null:
			show_title()
		debug_panel.open(maxi(0, DebugPanel.page_named(debug_page)))
	if _menu_shot != "":
		_save_menu_shot(300 if quick else (240 if is_demo() else 30))  # a demo gets going first


func _physics_process(dt: float) -> void:
	for b: OnlineBot in bots:
		b.tick(dt, race)
	if online != null:
		online.poll(dt)
		if auto_online != "":
			_auto_online_tick()
		if online != null and online.started:
			start_online_race()  # the host started (again): everyone into the race
	var woke := Attract.is_input(InputRouter.state, InputRouter.menu)
	if is_demo():
		if woke and _menu_shot == "":  # (a staged shot of the tour is hands-off, whatever a pad says)
			end_demo()
		elif race == null:  # the tour's controls card
			attract_time += dt
			if attract_time >= Attract.CONTROLS_SECONDS:
				next_attract_step()
		return
	if screen == Screen.RACE or menu == null or calibration.visible or debug_panel.visible:
		return
	if _swallow > 0:
		_swallow -= 1
		return
	if screen == Screen.TITLE:
		var reading := menu is TitleScreen and (menu as TitleScreen).busy()  # (what's new, a question up)
		idle = 0.0 if woke or reading else idle + dt
		if idle >= attract_delay:
			start_demo()
			return
	menu.handle(InputRouter.menu)


## Any key or button: a player is there. It ends a demo, and the press goes no further.
func _input(event: InputEvent) -> void:
	if not Attract.is_wake_event(event):
		return
	idle = 0.0
	if is_demo():
		end_demo()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if race != null:  # the race has its own F1 / F2
		return
	if event.is_action_pressed("debug_input"):
		debug_overlay.visible = not debug_overlay.visible
	elif event.is_action_pressed("calibrate") and not calibration.visible:
		calibration.open()


## The title, with START (0) or OPTIONS (1) picked.
func show_title(item := 0) -> void:
	if Updater.supported():
		Updates.mark_good()  # a start on an update got this far: keep it
	var t := TitleScreen.new()
	t.index = item
	if news_allowed:
		t.news = WhatsNew.take()
		t.news_version = Updater.version()
	t.offers = onboarding_on()
	t.asking = onboarding_on() and WhosDriving.due(SaveData)
	_set_menu(t, Screen.TITLE)


## Whether the onboarding comes up (onboarding, WhosDriving.enabled).
func onboarding_on() -> bool:
	return onboarding and WhosDriving.enabled


## Whether a race on `stage` starts as the first drive (MP-15): a new profile's first race on
## Palm Coast (FirstDrive.wanted), from the menus, not a demo or online.
func first_drive_for(stage: int, demo: bool) -> bool:
	return WhosDriving.enabled and first_drive_allowed and not demo and FirstDrive.wanted(stage, SaveData)


## CONTROLS on the title (PR-22): the controls card, back to the title on CONTROLS.
func show_controls() -> void:
	var c := ControlsCard.new()
	c.on_back = show_title.bind(TitleScreen.items().find("CONTROLS"))
	_set_menu(c, Screen.CONTROLS)


## The update check, before the title. `staged` (tests and --screen=update) shows that
## updater instead of the Updates autoload.
func show_update(staged: Updater = null) -> void:
	var u := UpdateScreen.new()
	if staged != null:
		u.updater = staged
		u.add_child(staged)
	_set_menu(u, Screen.UPDATE)


## Mode select, on the last mode picked (or `item`).
func show_mode_select(item := -1) -> void:
	var m := ModeSelect.new()
	m.index = mode_index if item < 0 else item
	_set_menu(m, Screen.MODES)


## The options, from the title unless `back` (with its name for the BACK row's help) says
## where they go back to; on `page` (an OptionsScreen.Page) when given, with the cursor on
## `row` (an OptionsScreen.Row) when given.
func show_options(back := Callable(), back_name := "the title screen", page := -1, row := -1) -> void:
	var o := OptionsScreen.new()
	o.back_name = back_name
	if page >= 0:
		o.page = page
		o.index = 0  # on the page bar, so the page shows which it is
	if row >= 0:
		o.go_to(row)
	_options_back = back
	_options_back_name = back_name
	_set_menu(o, Screen.OPTIONS)


## Controls > REMAP BUTTONS.
func show_remap() -> void:
	_set_menu(RemapScreen.new(), Screen.REMAP)


## Back from remapping: the options again, on REMAP BUTTONS, still going back where they did.
func close_remap() -> void:
	show_options(_options_back, _options_back_name, OptionsScreen.Page.CONTROLS, OptionsScreen.Row.REMAP)
	menu.in_race = race != null


## Controls > WHEEL SETTINGS.
func show_wheel() -> void:
	_set_menu(WheelScreen.new(), Screen.WHEEL)


## Back from the wheel settings: the options again, on WHEEL SETTINGS.
func close_wheel() -> void:
	show_options(_options_back, _options_back_name, OptionsScreen.Page.CONTROLS, OptionsScreen.Row.WHEEL)
	menu.in_race = race != null


## QUIT on the title: closes the game. Tests set `on_quit` so the run carries on.
func quit() -> void:
	if on_quit.is_valid():
		on_quit.call()
	else:
		get_tree().quit()


## Options opened from mode select come back to it.
func show_options_from_modes() -> void:
	show_options(show_mode_select.bind(ModeSelect.Item.OPTIONS), "mode select")


## Leaves the options for wherever they were opened from.
func close_options() -> void:
	var back := _options_back
	_options_back = Callable()
	if back.is_valid():
		back.call()
	else:
		show_title(1)


## A playable mode picked on mode select. ONLINE picks the car first; the host picks the
## stage in the lobby. SURVIVAL's road is set (it starts on Palm Coast): just the car. The
## DAILY RUN picks everything: its card.
func choose_mode(item: int) -> void:
	mode_index = item
	if item == ModeSelect.Item.ONLINE or item == ModeSelect.Item.SURVIVAL:
		show_car_select()
	elif item == ModeSelect.Item.DAILY_RUN:
		show_daily()
	else:
		show_stage_select()


## Back from car select: stage select, or mode select for ONLINE and SURVIVAL (which have none).
func car_select_back() -> void:
	if mode_index == ModeSelect.Item.ONLINE or mode_index == ModeSelect.Item.SURVIVAL:
		show_mode_select()
	else:
		show_stage_select()


## The daily run's day: `day`, or today (Daily.today).
func daily_day() -> int:
	return day if day > 0 else Daily.today()


## The daily run's card (MP-14): the day's stage, car, weather and traffic, and your tries.
func show_daily() -> void:
	var d := DailyCard.new()
	d.day = daily_day()
	d.pick = Daily.pick(d.day)
	_set_menu(d, Screen.DAILY)


## ONLINE after car select: host or join, then the room's lobby (when in one).
func show_online() -> void:
	_set_menu(OnlineScreen.new(), Screen.ONLINE)


## HOST or JOIN on the online screen: a room on `link` (RelayLink, or LoopLink in tests).
func open_room(link: NetLink) -> void:
	leave_room()
	var car: String = Cars.get_car(car_index)["id"]
	online = OnlineSession.hosting_on(link, car)


## --online=host or --online=join:CODE, for racing two windows hands-off: straight into a
## room on the stage (--stage=N) and car (--car=ID) given, the host starting once `players`
## are in. The room's code is printed ("online room BXKM") and, with --room-file=PATH,
## written there; with --autodrive each game drives itself. --online=bot hosts on an in-memory
## relay with made-up guests (OnlineBot) for screenshots: --bot-speed=F of top speed (0.8),
## --bot-lag=MS on their line, --bot-drop=S the first leaves at that race time. Once every racer has finished,
## the finishes are printed; with --races=N each game says READY and the host picks the next
## stage (ON-9), N races in all; then the game quits.
func online_from_flags(flag: String, players := 2) -> void:
	mode_index = ModeSelect.Item.ONLINE
	auto_players = clampi(players, 1, OnlineSession.MAX_PLAYERS)
	auto_races = maxi(1, int(DevArgs.value("--races", "1")))
	var stage := DevArgs.value("--stage")
	if stage != "":
		stage_index = clampi(int(stage) - 1, 0, Stages.count() - 1)
	show_online()
	if flag == "bot":
		_bot_relay = LoopLink.Relay.new()
		make_link = func() -> NetLink: return LoopLink.new(_bot_relay)
	var link: NetLink = make_link.call()
	open_room(link)
	if flag == "host" or flag == "bot":
		auto_online = "host"
		link.call("host")
	elif flag.begins_with("join:"):
		auto_online = "join"
		link.call("join", flag.trim_prefix("join:"))
	else:
		push_error("--online=host, --online=join:CODE or --online=bot, not %s" % flag)
	if flag == "bot":
		var cars := ["car_mesa", "car_kestrel", "car_bruiser"]
		for i in auto_players - 1:
			var b := OnlineBot.joining(_bot_relay, link.room, cars[i % cars.size()], int(DevArgs.value("--bot-lag", "0")))
			b.speed = Cfg.MAX_SPEED * float(DevArgs.value("--bot-speed", "0.8"))
			if i == 0 and DevArgs.value("--bot-drop") != "":
				b.drop_at = float(DevArgs.value("--bot-drop"))
			bots.append(b)


func _auto_online_tick() -> void:
	if online.phase == OnlineSession.Phase.CLOSED:
		print("online closed: ", online.error)
		_quit_auto(1)
		return
	if not _auto_room_said and online.phase != OnlineSession.Phase.DIALING:
		_auto_room_said = true
		print("online room ", online.link.room, " slot ", online.slot)
		var path := DevArgs.value("--room-file")
		if path != "":
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f != null:
				f.store_string(online.link.room)
	if auto_online == "host" and not _auto_started and online.phase == OnlineSession.Phase.LOBBY \
			and online.players.size() >= auto_players:
		_auto_started = true
		online.choose(stage_index, mirror)
		online.start()
	if race != null and online.go and not _auto_again and not online.racers.is_empty() \
			and online.racers.all(func(s: int) -> bool: return online.finishes.has(s) or online.gone.has(s)):
		_auto_again = true
		_auto_done += 1
		print("online race %d on %s: finishes %s gone %s" % [_auto_done, Stages.stage_name(online.stage), online.finishes, online.gone])
		if _auto_done >= auto_races:
			if bots.is_empty():  # (with bots, the results stay up for a screenshot)
				_quit_auto(0)
			return
		if online.hosting():
			online.choose(OnlineScreen.next_stage(online.stage, 1), false)
		online.ready_again()


func _quit_auto(code: int) -> void:
	auto_online = ""
	if on_quit.is_valid():
		on_quit.call()
	else:
		get_tree().quit(code)


## Leaves the room, if in one.
func leave_room() -> void:
	if online != null:
		online.leave()
		online = null


## The host started: the race on its stage, with everyone in the room.
func start_online_race() -> void:
	if race != null:
		_drop_race()
	online.started = false
	_auto_again = false
	stage_index = online.stage
	_set_menu(null, Screen.RACE)
	race = RACE_SCENE.instantiate()
	race.stage_index = online.stage
	race.car_id = online.car_id
	race.mirror = online.mirror
	race.tour = false
	race.online = online
	if auto_online != "" and DevArgs.has("--autodrive"):
		race.drive_itself()  # (a rematch: the dev flags were the first race's)
	race.debug_overlay = debug_overlay
	race.calibration = calibration
	race.debug_panel = debug_panel
	race.quit_requested.connect(_on_race_quit)
	race.race_over.connect(_on_race_over)
	race.options_requested.connect(_on_race_options)
	add_child(race)


## The Grand Tour's ending (MP-16), on `page` (a TourFinale.Page): the podium, the standings
## and the end card for `standings` (Tour.standings), then the credits over the harbor.
func show_finale(standings: Array[Dictionary], car_id: String, page := TourFinale.Page.PODIUM) -> void:
	var f := TourFinale.new()
	f.standings = standings
	f.car_id = car_id
	f.page = page
	_set_menu(f, Screen.FINALE)
	if Audio.music_cue != finale_song():
		Audio.play_music(finale_song())


## The credits (PR-23): from the title, or after the tour (`after_tour`: over the harbor,
## the finale's song playing on).
func show_credits(after_tour := false) -> void:
	var c := CreditsScreen.new()
	c.harbor = after_tour
	_set_menu(c, Screen.CREDITS)
	if Audio.music_cue != finale_song():
		Audio.play_music(finale_song())


## The credits are over (or left): the title, on CREDITS.
func close_credits() -> void:
	Audio.stop_music()
	show_title(maxi(0, TitleScreen.items().find("CREDITS")))


## The stats page (MP-11), from the title.
func show_stats() -> void:
	_set_menu(StatsScreen.new(), Screen.STATS)


## The sticker book (MP-12), beside the stats page.
func show_stickers() -> void:
	_set_menu(StickerScreen.new(), Screen.STICKERS)


## The completion page (MP-17), beside the stickers.
func show_completion() -> void:
	_set_menu(CompletionScreen.new(), Screen.COMPLETION)


## The stats page's tab `page` (StatsScreen.Page): stats, stickers or completion.
func show_records(page: int) -> void:
	match posmod(page, StatsScreen.PAGES.size()):
		StatsScreen.Page.STICKERS:
			show_stickers()
		StatsScreen.Page.COMPLETION:
			show_completion()
		_:
			show_stats()


## Who is driving (MP-10), from PROFILE on the title.
func show_profiles() -> void:
	_set_menu(ProfileScreen.new(), Screen.PROFILES)


func show_stage_select() -> void:
	var s := StageSelect.new()
	s.index = stage_index
	_set_menu(s, Screen.STAGES)


func show_car_select() -> void:
	var c := CarSelect.new()
	c.index = car_index
	_set_menu(c, Screen.CARS)


## Leaves the menus for a race on the chosen stage and car (ONLINE: for the room).
func start_race() -> void:
	if mode_index == ModeSelect.Item.ONLINE:
		show_online()
		return
	if mode_index == ModeSelect.Item.DAILY_RUN:
		var p := Daily.pick(daily_day())
		_spawn_race(int(p["stage"]), maxi(0, Cars.LIST.find(Cars.find(p["car"]))), false)
		return
	_spawn_race(stage_index, car_index, false)


## The title sat idle: the attract tour's next step (PR-20, Attract.step), an autodriven
## demo race on the next stage and car in turn or the controls card. The player's own stage
## and car picks stay as they were.
func start_demo() -> void:
	var s := Attract.step(tour_step, Stages.count(), Attract.tour_cars_now())
	tour_step += 1
	idle = 0.0
	if s["kind"] == Attract.Step.CONTROLS:
		var c := ControlsCard.new()
		c.attract = true
		attract_time = 0.0
		_set_menu(c, Screen.CONTROLS)
		return
	_spawn_race(s["stage"], s["car"], true)


## In the attract tour: a demo race, or its controls card.
func is_demo() -> bool:
	if race != null:
		return race.demo
	return menu is ControlsCard and (menu as ControlsCard).attract


## A step of the tour ran its length: on to the next, or at the end of a loop the title.
func next_attract_step() -> void:
	if Attract.ends_loop(tour_step - 1, Stages.count()):
		end_demo()
		return
	if race != null:
		_drop_race()
	start_demo()


## Input during the tour (or a loop ending): back to the title.
func end_demo() -> void:
	if race != null:
		_drop_race()
	show_title()
	_swallow = 10


## A race in the mode picked, or a demo (no mode: a lone Single Race, with rivals).
func _spawn_race(stage: int, car: int, demo: bool) -> void:
	_set_menu(null, Screen.RACE)
	race = RACE_SCENE.instantiate()
	race.stage_index = stage
	race.car_id = Cars.get_car(car)["id"]
	race.demo = demo
	race.tour = not demo and mode_index == ModeSelect.Item.GRAND_TOUR
	race.time_attack = not demo and mode_index == ModeSelect.Item.TIME_ATTACK
	race.free_drive = not demo and mode_index == ModeSelect.Item.FREE_DRIVE
	race.survival = not demo and mode_index == ModeSelect.Item.SURVIVAL
	if not demo and mode_index == ModeSelect.Item.DAILY_RUN:
		race.daily = Daily.pick(daily_day())
	race.mirror = not demo and mirror_for(stage)
	race.first_drive_on = first_drive_for(stage, demo)
	race.debug_overlay = debug_overlay
	race.calibration = calibration
	race.debug_panel = debug_panel
	race.quit_requested.connect(_on_race_quit)
	race.race_over.connect(_on_race_over)
	race.options_requested.connect(_on_race_options)
	add_child(race)


## Whether a race on `stage` goes mirrored: the toggle on, in a mode that offers it
## (mirror_offered), and the stage's mirror open (Unlocks).
func mirror_for(stage: int) -> bool:
	return mirror and mirror_offered() and Unlocks.mirror_unlocked(stage)


## Mirror mode is for a single stage: a Single Race, Time Attack or Free Drive. The Grand
## Tour and Survival run on through stages whose mirrors may not be open, so they race them
## as built; the daily run is the same road for everyone.
func mirror_offered() -> bool:
	return not mode_index in [ModeSelect.Item.GRAND_TOUR, ModeSelect.Item.SURVIVAL, ModeSelect.Item.DAILY_RUN]


func _on_race_quit() -> void:
	if is_demo():
		next_attract_step()  # (a demo quits when it's run its length)
		return
	_drop_race()
	leave_room()
	show_title()


## A Single Race or Time Attack run finished: back to stage select for the next one. Online,
## back to the room's lobby (or what ended it).
func _on_race_over() -> void:
	var finale: bool = race.tour and race.after == race.After.TOUR_DONE and race.tour_state != null
	var standings: Array[Dictionary] = []
	if finale:
		standings = race.tour_state.standings()
	var car: String = race.car_id
	_drop_race()
	if finale:
		show_finale(standings, car)  # the tour is done: its ending, then the credits (MP-16)
		return
	if online != null:
		online.to_lobby()
		show_online()
		return
	if mode_index == ModeSelect.Item.SURVIVAL:
		show_car_select()  # (the run again, in this car or another)
	elif mode_index == ModeSelect.Item.DAILY_RUN:
		show_daily()  # (the card, with this try on it)
	else:
		show_stage_select()


## OPTIONS on the pause menu: the options over the paused race, then back to its menu.
func _on_race_options() -> void:
	show_options(_close_race_options, "the race")
	menu.in_race = true


func _close_race_options() -> void:
	_set_menu(null, Screen.RACE)
	race.options_closed()


func _drop_race() -> void:
	if not race.demo and not race.survival and race.daily.is_empty():
		stage_index = race.stage_index  # stage select opens on the stage the tour reached
	race.queue_free()
	race = null
	Audio.stop_music()
	Audio.set_paused(false)


func _set_menu(next: MenuScreen, to: Screen) -> void:
	if menu != null:
		menu.queue_free()
	menu = next
	screen = to
	if menu != null:
		menu.game = self
		_layer.add_child(menu)


# --- Dev helpers: `godot -- --screen=stages --menu-shot=/tmp/stages.png` -------------
# (--screen=pause starts a race and pauses it; add --at-segment=N to pause further in.
# --screen=unplugged pauses it as a wheel unplugged mid-race does; --screen=replugged then
# plugs a different wheel in (replugged:same the same one), for the 3, 2, 1 that follows.
# --car=car_mesa opens car select on that car. --screen=results stages a finish.
# --mode=single_race (a ModeSelect.Item) picks the mode stage select is in; --mirror turns
# its MIRROR toggle on.
# --screen=debug opens the F3 tuning panel (debug:camera, debug:actions etc. for a page:
# Tuning.AREAS, actions, presets), over the title, or over a race given race flags.
# --screen=stats opens the stats page (MP-11); --screen=profiles the driver picker (MP-10).
# --screen=stickers the sticker book (MP-12; stickers:5 with the cursor on the sixth sticker),
# --screen=completion the completion page (MP-17).
# --screen=daily the daily run's card (MP-14); --day=YYYYMMDD for another day's run (the card,
# mode select's DAILY RUN and --mode=daily_run races). --mode=survival with race flags races
# Survival (MP-13).
# --screen=credits rolls the credits (PR-23; credits:harbor as after the tour, credits:600 rolled on 600 px). --screen=finale
# stages the Grand Tour's ending (MP-16): finale:standings and finale:card for its later pages,
# finale:card:2 (or any place) for where the player finished; --car=ID for the player's car.
# --screen=controls the controls card (PR-22; controls:gamepad, controls:wheel, controls:touch
# for another device), --screen=pause:controls the card over a paused race.
# --screen=whos_driving asks who's driving over the title (AC-16); --screen=wheel_offer offers
# a staged wheel calibration (WH-16). Neither is saved. --first-drive makes a race the flags
# start the first drive (MP-15) when the save is a new profile's.
# --screen=whats_new shows this version's notes over the title (PR-17), without marking them seen.
# --screen=demo starts an attract-mode demo, also with --at-segment=N; demo:N the attract
# tour's Nth step (Attract.step: demo:1 is the controls card, demo:2 the second stage). --screen=update stages
# a download; update:checking, update:failed, update:full and update:ready the other states.)

func _open(which: String) -> void:
	match which:
		"stages":
			show_stage_select()
		"cars":
			show_car_select()
		"options":
			show_options()
		"remap":
			show_remap()
		"wheel":
			show_wheel()
		"modes":
			show_mode_select()
		"stats":
			show_stats()
		_ when which.begins_with("stickers"):
			show_stickers()
			if which.contains(":"):
				(menu as StickerScreen).index = clampi(int(which.get_slice(":", 1)), -1, Stickers.count() - 1)
		"completion":
			show_completion()
		"daily":
			mode_index = ModeSelect.Item.DAILY_RUN
			show_daily()
		"profiles":
			show_profiles()
		_ when which.begins_with("credits"):
			# credits, credits:harbor (as after the tour), either with :PIXELS rolled on
			var parts := which.split(":")
			show_credits(parts.has("harbor"))
			if parts.size() > 1 and parts[-1].is_valid_int():
				(menu as CreditsScreen).scroll = float(parts[-1])
		_ when which.begins_with("finale"):
			# finale[:podium|standings|card[:PLACE]]: the tour's ending on made-up standings,
			# the player PLACE overall (1 unless given)
			var parts := which.split(":")
			var page: int = TourFinale.Page.get(parts[1].to_upper(), 0) if parts.size() > 1 else 0
			var place := int(parts[2]) if parts.size() > 2 else 1
			show_finale(TourFinale.staged_standings(place), Cars.get_car(car_index)["id"], page)
		_ when which.begins_with("controls"):
			show_controls()
			var dev := ControlsCard.DEVICE_NAMES.find(which.get_slice(":", 1).to_upper()) if which.contains(":") else -1
			if dev >= 0:
				(menu as ControlsCard).device = dev
		"whos_driving":
			show_title()
			(menu as TitleScreen).asking = true
		"wheel_offer":
			show_title()
			(menu as TitleScreen).wheel_offer = "staged-wheel"
			(menu as TitleScreen).wheel_offer_name = "Logitech G29 Driving Force Racing Wheel"
		"whats_new":
			show_title()
			(menu as TitleScreen).news = WhatsNew.items(WhatsNew.notes(Updater.version()))
			(menu as TitleScreen).news_version = Updater.version()
		_ when which.begins_with("online"):
			show_online()
			(menu as OnlineScreen).stage_shot(which.get_slice(":", 1) if which.contains(":") else "menu")
		_ when which.begins_with("demo"):
			# demo, or demo:N for the attract tour's Nth step (demo:1 its controls card)
			tour_step = int(which.get_slice(":", 1)) if which.contains(":") else 0
			start_demo()
		_ when which.begins_with("update"):
			show_update(staged_updater(which.get_slice(":", 1) if which.contains(":") else "downloading"))
		_ when which.begins_with("options:"):
			show_options(Callable(), "the title screen", OptionsScreen.page_named(which.get_slice(":", 1)))
		_:
			show_title()


## The wheel driving unplugged mid-race, for --screen=unplugged: a made-up joypad (an id
## no real one has) drives, then goes, through InputRouter as a real one would.
static func stage_unplug() -> void:
	InputRouter.last_active_device = STAGED_JOYPAD
	InputRouter.joy_changed(STAGED_JOYPAD, false, "staged-wheel", "Logitech G29 Driving Force Racing Wheel")


## The wheel back for --screen=replugged (WH-12): the same one, or (`same` false) a different
## wheel on its id, so the race counts down 3, 2, 1 saying so.
static func stage_replug(same: bool) -> void:
	if same:
		InputRouter.joy_changed(STAGED_JOYPAD, true, "staged-wheel", "Logitech G29 Driving Force Racing Wheel")
	else:
		InputRouter.joy_changed(STAGED_JOYPAD, true, "staged-wheel-2", "Thrustmaster T300RS Racing Wheel")


## An updater posed in `state_name` (an Updater.State, lower case) for the update screen's
## screenshots: version 0.2.0, an 18 MB pack 40% down.
static func staged_updater(state_name: String) -> Updater:
	var u := Updater.new()
	u.state = Updater.State.get(state_name.to_upper(), Updater.State.DOWNLOADING)
	u.latest = "0.2.0"
	u.manifest = {"version": "0.2.0", "size": 18382464}
	u.staged_progress = 0.4
	if u.state == Updater.State.FAILED:
		u.error = "The download stopped."
	return u


func _save_menu_shot(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if DevArgs.has("--shot-as-window"):
		img = DevArgs.as_window(img, get_window())
	DirAccess.make_dir_recursive_absolute(_menu_shot.get_base_dir())
	img.save_png(_menu_shot)
	get_tree().quit()
