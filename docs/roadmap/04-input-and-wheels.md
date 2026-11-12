# WH: Input and Wheels

Wheel-first controls are a design pillar. This group finishes `docs/02-technical-design.md`
section 4: the options still missing, force feedback, and testing on the hardware players use.

## Built today

`InputRouter` reads gamepads and wheels per device, not through the InputMap. Profiles per
joypad GUID in `user://input_profiles.cfg`. The F2 calibration wizard handles inverted, 0..1 and
combined pedals. The F1 overlay shows raw axes and the resulting `DriveInput`. Menus are
wheel-drivable, and an unmapped pad no longer scrolls them (WH-10). Remapping of every action on
every device (WH-2). Steering and braking assists (WH-6). Auto gas. Each wheel's range, steering
lock, deadzone and linearity on Controls > WHEEL SETTINGS, with the curve they make (WH-1).
Unplugging the wheel or pad that's driving pauses the race and says so; plugging it back in
carries on with the same profile (WH-7).

## Features

| ID | Feature | Size | Month | Needs | Done when |
|---|---|---|---|---|---|
| WH-1 ✓ | **Steering lock and range in Options.** Hardware range, in-game lock, deadzone and linearity per profile, editable on the Options screen (or a Wheel sub-screen). | S | 1 | | `test_options` and `test_device_profile` cover save and load; a wheel-driven screenshot |
| WH-2 ✓ | **Remapping.** A screen to bind nitro, shift up and down, horn, pause and view for every device; keyboard keys too. Conflicts flagged. | M | 5 | | Bindings persist per device; the e2e smoke rebinds nitro and uses it |
| WH-3 | **Force feedback extension.** A GDExtension wrapping SDL haptics: spring (centering), constant force (curve pull and off-road drift), periodic (rumble on dirt), jolts on bumps and crashes. An `FFB` autoload with `set_spring`, `pull`, `rumble`, `jolt` that is a no-op when unsupported. Strength slider in Options. | L | 5 | EQ-11 | The autoload has tests through a fake backend; the extension builds in CI for macOS and Windows; a hands-on check on Austin's wheel |
| WH-4 | **Known-wheel profiles.** A table of starting profiles by device name or GUID for common wheels (Logitech G29, G920, G923; Thrustmaster T150, T300, TMX; Fanatec; Moza), so a known wheel skips the wizard and only confirms. | S | 5 | WH-9 | `test_device_profile` checks each entry round-trips; the wizard offers "use the known profile" |
| WH-5 | **Windows wheel pass.** Test the wheel, pedals, FFB and the web build on Windows; document Steam Input interference and the vendor centering-spring setting. | S | 5 | WH-3 | A short compatibility table in the README |
| WH-6 ✓ | **Assists.** Gamepad steering assist (pulls toward the lane center at speed) and a beginner braking assist (brakes into sharp curves). Options in AC-3. | S | 6 | | Tests that the assists never exceed their caps; traces unchanged because they are off by default |
| WH-7 ✓ | **Hot-plug during a race.** A disconnected device pauses the race with a message; reconnecting resumes with the same profile. | S | 2 | | Test through `Input.joy_connection_changed` with a fake device |
| WH-8 | **Web gamepad check.** Verify browser axis mapping for common pads; calibration profile in browser storage survives a reload. | S | 6 | EQ-10 | Manual check noted in the README |
| WH-9 ✓ | **Answer open question 3.** Which wheel and pedals Austin owns becomes the first known profile and the FFB test rig. | S | 1 | | `docs/04-open-questions.md` updated |
| WH-10 ✓ | **Options scroll forever with a wheel.** Played with a wheel: Options scrolled down forever, every visit. A device read as a pad (no name match) took its up/down from axis 1, which on a wheel or pedal set without a gamepad mapping is often a pedal resting at full travel. Unmapped pads no longer move the menus up and down, and steer through Options like a wheel. | S | 1 | | A resting pedal on axis 1 doesn't move the list; an unmapped pad steers through Options |
| WH-11 | **Pedals on axes 4 and 5.** An unmapped pad reads axes 4 and 5 as brake and throttle, so a resting pedal can hold the gas in a race or keep the pad active. Only a profile that says so reads them, and a resting value is never a press. (Code done: `InputRouter.pad_pedals` reads an unmapped pad's pedals only from a calibrated profile, from their rest; `test_input_router` covers it with a fake pad. Waiting on the TMX check, WH-15.) | S | 1 | WH-10 | `test_input_router` with a fake pad whose axis 5 rests at -1 ✓; checked on the TMX (WH-15) |
| WH-12 ✓ | **Replug countdown.** Plugging the wheel back in counts 3, 2, 1 before the race resumes, and says when the device that came back is a different one. | S | 1 | WH-7 | `test_hot_plug` covers the countdown and a different GUID; a screenshot of the count |
| WH-13 ✓ | **Gamepad rumble.** Crashes, bumps, landings, nitro and off-road through `Input.start_joy_vibration`, with a rumble slider in Options > Controls. | S | 1 | | A plain function maps events to strength and length, tested; the slider at 0 sends nothing |
| WH-14 | **Button glyphs.** Xbox, PlayStation, generic pad and wheel glyphs in the hints, the remap screen and the pause menu, picked from the active device's name; text labels stay the fallback. | M | 2 | WH-2 | A glyph lookup test per device family; screenshots of the remap screen on two families |
| WH-15 | **TMX play session.** Austin drives a race and the menus on the Thrustmaster TMX: calibration, rotation and lock (WH-1), the F1 overlay, unplug and replug (WH-7), paddles; its profile becomes the first entry in WH-4 and the notes list what to fix. | S | 1 | WH-9 | Notes filed as issues; the TMX entry in `DeviceProfile`'s known table with a test |
| WH-16 ✓ | **Wheel first run.** A wheel with no saved profile, plugged in at the title, gets a prompt to calibrate now (or use its known profile, WH-4) instead of being left to find the calibration in Options. | S | 4 | WH-4 | Test the prompt shows once per unknown device and not for a pad; a screenshot |
| WH-17 | **Wheel report.** F4 on the calibration screen copies the device's name, GUID, axes and buttons as the game sees them, for a bug report or a new known profile (WH-4); the README gets a table of wheels known to work. | S | 6 | WH-4 | Test the report's lines from a fake device; the README table |
| WH-18 | **Two players, two devices.** A PRESS A BUTTON TO JOIN screen assigns each player a device (pad, wheel, touch, or the keyboard split in halves), shown with its glyph. Unplugging pauses for that player only. | M | 7 | MP-18, WH-7 | Tests for assignment, the split keyboard and an unplug; a menu screenshot |
| WH-19 | **Shifter.** An H-pattern shifter for manual gears; a clutch pedal stays ignored. Needs a shifter to test. | S | 13 | RC-10, WH-2 | Test the gear from each slot; remap screen shows it |

## Open decisions

- Does the FFB extension also cover Linux, for a later Steam Deck build? Default: build it, do not test it.
- Should clutch pedals be bindable to anything (say, the horn)? Default: ignored.

## Test notes

Everything here already runs through plain functions (`DeviceProfile`, `CalibrationWizard.capture`),
so new options get unit tests. The FFB extension is tested through a fake backend; the real
hardware check is manual and recorded in the README's compatibility table.
