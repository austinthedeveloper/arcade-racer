#!/bin/sh
# Screenshot regression: renders a fixed set of menu and race screenshots and compares
# them with the references in tests/shots/ (tools/shots.py: a difference hash plus a
# color difference, within tolerances). Exits non-zero on a mismatch; failing shots get
# a side-by-side diff image next to them.
#
#   tools/shots.sh            # render and compare
#   tools/shots.sh --update   # render and rewrite tests/shots/ (after a deliberate visual change)
#
# Needs a display: it renders windowed (the headless dummy driver draws nothing). On Linux
# without one, run it under xvfb-run (CI does). Frames run at a fixed 60 fps, so animation
# lands on the same frame every run whatever the machine's speed.
# GODOT picks the Godot binary (default: godot on the PATH), SHOTS_PYTHON the Python with
# PIL (default: python3; pip install -r tools/requirements.txt), SHOTS_DIR where the
# rendered shots go (default: a temp dir, kept on a failure), SHOTS_GODOT_ARGS extra Godot
# arguments (CI: --rendering-driver opengl3 --display-driver x11).
cd "$(dirname "$0")/.." || exit 2
GODOT=${GODOT:-godot}
PY=${SHOTS_PYTHON:-python3}
mode=compare
[ "$1" = "--update" ] && mode=update
out=${SHOTS_DIR:-$(mktemp -d)}
mkdir -p "$out"

"$PY" tools/shots.py selftest >/dev/null || { "$PY" tools/shots.py selftest; exit 1; }
"$GODOT" --headless --path . --import >/dev/null 2>&1

run() {  # name, then Godot arguments
  name=$1; shift
  # shellcheck disable=SC2086  # (SHOTS_GODOT_ARGS splits into arguments)
  if ! "$GODOT" --path . --fixed-fps 60 --audio-driver Dummy $SHOTS_GODOT_ARGS "$@" >"$out/$name.log" 2>&1; then
    echo "  FAIL $name: Godot exited non-zero (see $out/$name.log)"; return 1
  fi
}

menu() {  # name, screen
  run "$1" -- --screen="$2" --menu-shot="$out/$1.png"
}

race() {  # name, frame, then race flags
  name=$1; frame=$2; shift 2
  run "$name" --quit-after $((frame + 120)) -- --autodrive --screenshots="$frame" --shot-dir="$out/$name.d" "$@" || return 1
  mv "$out/$name.d/frame_$(printf %05d "$frame").png" "$out/$name.png" 2>/dev/null \
    || { echo "  FAIL $name: no frame $frame saved (see $out/$name.log)"; return 1; }
  rm -rf "$out/$name.d"
}

status=0
menu menu_title title || status=1
menu menu_options options || status=1
menu menu_stages stages || status=1
menu menu_cars cars || status=1
race race_palm 300 --stage=1 || status=1
race race_stage3 260 --stage=3 --at-segment=400 || status=1

"$PY" tools/shots.py "$mode" "$out" tests/shots || status=1
if [ $status -eq 0 ] && [ -z "$SHOTS_DIR" ]; then
  rm -rf "$out"
elif [ $status -ne 0 ]; then
  echo "rendered shots kept in $out"
fi
exit $status
