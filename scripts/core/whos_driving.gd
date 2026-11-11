class_name WhosDriving
extends RefCounted
## Who's driving (AC-16): on the first boot, and for each new profile (MP-10), the title asks
## one question before anything else, and the answer sets the assists. It only sets options
## that already exist, so each stays changeable in Options afterwards:
##   KID    auto gas, the co-pilot (AC-14, which brakes for the bends too), EASY
##   NEW    the steering and braking assists, EASY
##   RACER  none of them, NORMAL
## SaveData.driver_asked keeps it from asking the same profile twice (TitleScreen draws it).

enum Answer { KID, NEW, RACER }

const NAMES := ["KID", "NEW", "RACER"]
## The line under each answer on the title.
const LINES := ["Auto gas and a co-pilot steer for you.", "Steering and braking help, easy rivals.",
	"No help. Normal rivals and clock."]
const QUESTION := "WHO'S DRIVING?"
const DEFAULT := Answer.NEW  # where the cursor starts

## Whether the onboarding (who's driving, the wheel's first run, the first drive) comes up at
## all. The test runners turn it off, so a suite going through the title or into a race on a
## fresh save sees the game as it was; the onboarding's own tests and the e2e smoke turn it on.
static var enabled := true


## What `answer` sets: option name (a Settings property) -> value. Difficulty goes through
## Settings.set_difficulty, so the timer option follows it as on the options screen.
static func options_for(answer: int) -> Dictionary:
	match answer:
		Answer.KID:
			return {"auto_gas": true, "co_pilot": true, "steer_assist": false, "brake_assist": false,
				"difficulty": Difficulty.Level.EASY}
		Answer.NEW:
			return {"auto_gas": false, "co_pilot": false, "steer_assist": true, "brake_assist": true,
				"difficulty": Difficulty.Level.EASY}
	return {"auto_gas": false, "co_pilot": false, "steer_assist": false, "brake_assist": false,
		"difficulty": Difficulty.Level.NORMAL}


## Puts `answer`'s options on `settings` (the Settings autoload, or a stand-in) and saves them.
static func apply(answer: int, settings: Node) -> void:
	var opts := options_for(answer)
	for key: String in opts:
		if key == "difficulty":
			settings.set_difficulty(opts[key])
		else:
			settings.set(key, opts[key])
	settings.save()


## The answer the options as they are now match, or -1 (they've been changed since).
static func answer_of(settings: Node) -> int:
	for a in Answer.size():
		var opts := options_for(a)
		var same := true
		for key: String in opts:
			same = same and settings.get(key) == opts[key]
		if same:
			return a
	return -1


## Whether the title should ask now: onboarding on and this profile not asked yet.
static func due(save_data: Node) -> bool:
	return enabled and not save_data.driver_asked
