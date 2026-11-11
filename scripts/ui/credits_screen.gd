class_name CreditsScreen
extends MenuScreen
## The credits (PR-23), from CREDITS on the title and after the Grand Tour's finale (MP-16):
## who made the game, the tools and the fonts with their licenses, and the note that every
## sound is synthesized in code. The roll scrolls by itself; holding any key or button
## speeds it up (FAST), back leaves. At the end (or on back) it goes to the title. After
## the tour it rolls over the harbor (TourFinale.draw_harbor) instead of the title's sunset.
## README.md's Credits section names the same tools and fonts (tests/test_credits.gd).

const SPEED := 24.0  # pixels a second
const FAST := 6.0  # times faster while a key or button is held
const START_Y := 120.0  # where the first line starts: the title up at once, the rest below
const COLUMN_MARGIN := 18.0  # the column's room either side of the widest line
const END_PAUSE := 2.0  # seconds the last line sits in the middle before the roll ends
## Each line's kind: its text size, color and the space it takes.
const STYLE := {
	"title": {"size": 30, "color": GOLD, "height": 44},
	"head": {"size": 11, "color": SKY, "height": 30},
	"name": {"size": 15, "color": Color.WHITE, "height": 20},
	"small": {"size": 9, "color": Color(1, 1, 1, 0.85), "height": 14},
	"gap": {"size": 0, "color": Color.WHITE, "height": 24},
}
## The roll, top to bottom: [kind, text]. Each tool and font is a "name" with its license
## under it in "small".
const LINES := [
	["title", "SUNDOWN RUN"],
	["small", "An original arcade road racer"],
	["gap", ""],
	["head", "MADE BY"],
	["name", "Austin Stewart"],
	["small", "with Claude, by Anthropic"],
	["gap", ""],
	["head", "DESIGN, CODE AND ART DIRECTION"],
	["name", "Austin Stewart and Claude"],
	["small", "written together in Claude Code"],
	["gap", ""],
	["head", "MUSIC AND SOUND"],
	["name", "Synthesized in code"],
	["small", "Every engine, crash, song, sting and announcer line is made by"],
	["small", "tools/make_audio.py from oscillators, noise and filters:"],
	["small", "no samples, no recordings, no sound libraries."],
	["gap", ""],
	["head", "ON THE RADIO"],
	["name", "98.3 THE CANYON"],
	["name", "104.7 NEON FM"],
	["name", "92.1 SOUL STOP"],
	["name", "107.9 PULSE"],
	["small", "Twenty original songs, all synthesized"],
	["gap", ""],
	["head", "TOOLS"],
	["name", "Godot Engine 4.7"],
	["small", "MIT License"],
	["name", "Python 3"],
	["small", "PSF License: the sprite, audio and release tools"],
	["name", "Pillow"],
	["small", "MIT-CMU License"],
	["name", "NumPy"],
	["small", "BSD 3-Clause License"],
	["name", "SciPy"],
	["small", "BSD 3-Clause License"],
	["name", "Blender"],
	["small", "GPL 2.0 or later: renders the cars from their models"],
	["name", "Tripo"],
	["small", "image to 3D: the cars' models"],
	["name", "Claude Code"],
	["small", "by Anthropic"],
	["gap", ""],
	["head", "FONTS"],
	["name", "Open Sans SemiBold"],
	["small", "Godot's built-in font, SIL Open Font License 1.1"],
	["gap", ""],
	["head", "ART"],
	["name", "Generated concept art"],
	["small", "from the prompts in assets/prompts/, cut into sprites by the tools in tools/"],
	["gap", ""],
	["gap", ""],
	["head", "THANKS FOR PLAYING"],
	["name", "See you on the coast road"],
]

var harbor := false  # after the tour: over Skyline's harbor
var scroll := 0.0  # pixels the roll has moved up
var fast := false  # a key or button held this tick
var _layers := {}


func _ready() -> void:
	super._ready()
	if harbor:
		_layers = TourFinale.harbor_layers()


## Every line's words in one string, for the test against README.md.
static func text() -> String:
	var out: Array[String] = []
	for line: Array in LINES:
		out.append(line[1])
	return "\n".join(out)


## The roll's height in pixels, first line to last.
static func height() -> float:
	var h := 0.0
	for line: Array in LINES:
		h += STYLE[line[0]]["height"]
	return h


## How far the roll goes before it's over: the last line up to the middle of the screen.
static func scroll_end() -> float:
	return START_Y + height() - Cfg.SCREEN_H / 2.0


## Pixels the roll moves in `dt` seconds, `held` a key or button.
static func step(dt: float, held: bool) -> float:
	return dt * SPEED * (FAST if held else 1.0)


## Moves the roll on; true once it's over (and the END_PAUSE after it).
func advance(dt: float, held: bool) -> bool:
	scroll = minf(scroll + step(dt, held), scroll_end() + END_PAUSE * SPEED)
	return scroll >= scroll_end() + END_PAUSE * SPEED


## The dark column the roll runs down: as wide as its widest line and a margin, full height.
static func column() -> Rect2:
	var widest := 0.0
	for line: Array in LINES:
		var st: Dictionary = STYLE[line[0]]
		if st["size"] > 0:
			widest = maxf(widest, UiText.width(line[1], st["size"]))
	var cw := minf(widest + 2.0 * COLUMN_MARGIN, Cfg.SCREEN_W)
	return Rect2((Cfg.SCREEN_W - cw) / 2.0, 0, cw, Cfg.SCREEN_H)


func handle(m: MenuInput) -> void:
	if m.back_pressed:
		Audio.play("beep")
		game.close_credits()
		return
	fast = Input.is_anything_pressed() or m.confirm_pressed
	if advance(1.0 / Engine.physics_ticks_per_second, fast):
		game.close_credits()


func _draw() -> void:
	if harbor:
		TourFinale.draw_harbor(self, _layers, time * 4.0)
		draw_rect(Rect2(0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H), Color(NIGHT, 0.6))
	else:
		_backdrop(0.72)
	var w := float(Cfg.SCREEN_W)
	draw_rect(column(), Color(NIGHT, 0.7))  # the text never sits straight on the busy art (AC-17)
	var y := START_Y - scroll
	for line: Array in LINES:
		var st: Dictionary = STYLE[line[0]]
		var h: float = st["height"]
		if y > -h and y < Cfg.SCREEN_H + h and st["size"] > 0:
			_text_centered(Vector2(w / 2.0, y + st["size"]), line[1], st["size"], st["color"])
		y += h
	# fade the roll in at the bottom and out at the top
	for k in 12:
		var a := (1.0 - k / 12.0) * 0.8
		var c := Color(NIGHT, a)
		draw_rect(Rect2(0, k * 2.0, w, 2), c)
		draw_rect(Rect2(0, Cfg.SCREEN_H - 22 - k * 2.0, w, 2), c)
	var hint := "Hold any key: faster   Esc: back" if InputRouter.state.kind == DriveInput.Kind.KEYBOARD \
		else "Hold any button: faster   B: back"
	_footer(hint)
