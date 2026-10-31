# WH: Input and Wheels

Wheel-first controls are a design pillar. This group finishes `docs/02-technical-design.md`
section 4: the options still missing, force feedback, and testing on the hardware players use.

## Built today

`InputRouter` reads gamepads and wheels per device, not through the InputMap. Profiles per
joypad GUID in `user://input_profiles.cfg`. The F2 calibration wizard handles inverted, 0..1 and
combined pedals. The F1 overlay shows raw axes and the resulting `DriveInput`. Menus are
wheel-drivable. Auto gas. Steering lock is a profile value with no UI (360 of 900 degrees).

## Features

| ID | Feature | Size | Month | Needs | Done when |
|---|---|---|---|---|---|
| WH-1 | **Steering lock and range in Options.** Hardware range, in-game lock, deadzone and linearity per profile, editable on the Options screen (or a Wheel sub-screen). | S | 1 | | `test_options` and `test_device_profile` cover save and load; a wheel-driven screenshot |
| WH-2 | **Remapping.** A screen to bind nitro, shift up and down, horn, pause and view for every device; keyboard keys too. Conflicts flagged. | M | 5 | | Bindings persist per device; the e2e smoke rebinds nitro and uses it |
| WH-3 | **Force feedback extension.** A GDExtension wrapping SDL haptics: spring (centering), constant force (curve pull and off-road drift), periodic (rumble on dirt), jolts on bumps and crashes. An `FFB` autoload with `set_spring`, `pull`, `rumble`, `jolt` that is a no-op when unsupported. Strength slider in Options. | L | 5 | EQ-11 | The autoload has tests through a fake backend; the extension builds in CI for macOS and Windows; a hands-on check on Austin's wheel |
| WH-4 | **Known-wheel profiles.** A table of starting profiles by device name or GUID for common wheels (Logitech G29, G920, G923; Thrustmaster T150, T300, TMX; Fanatec; Moza), so a known wheel skips the wizard and only confirms. | S | 5 | WH-9 | `test_device_profile` checks each entry round-trips; the wizard offers "use the known profile" |
| WH-5 | **Windows wheel pass.** Test the wheel, pedals, FFB and the web build on Windows; document Steam Input interference and the vendor centering-spring setting. | S | 5 | WH-3 | A short compatibility table in the README |
| WH-6 | **Assists.** Gamepad steering assist (pulls toward the lane center at speed) and a beginner braking assist (brakes into sharp curves). Options in AC-3. | S | 6 | | Tests that the assists never exceed their caps; traces unchanged because they are off by default |
| WH-7 | **Hot-plug during a race.** A disconnected device pauses the race with a message; reconnecting resumes with the same profile. | S | 2 | | Test through `Input.joy_connection_changed` with a fake device |
| WH-8 | **Web gamepad check.** Verify browser axis mapping for common pads; calibration profile in browser storage survives a reload. | S | 6 | EQ-10 | Manual check noted in the README |
| WH-9 | **Answer open question 3.** Which wheel and pedals Austin owns becomes the first known profile and the FFB test rig. | S | 1 | | `docs/04-open-questions.md` updated |

## Open decisions

- Does the FFB extension also cover Linux, for a later Steam Deck build? Default: build it, do not test it.
- Should clutch pedals be bindable to anything (say, the horn)? Default: ignored.

## Test notes

Everything here already runs through plain functions (`DeviceProfile`, `CalibrationWizard.capture`),
so new options get unit tests. The FFB extension is tested through a fake backend; the real
hardware check is manual and recorded in the README's compatibility table.
