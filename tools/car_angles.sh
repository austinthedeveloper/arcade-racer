#!/bin/sh
# Car-angle review sheet: every car in each steering frame on level road and on hills up and
# down (tools/car_angles.gd), then one HTML page to look through them (tools/car_angles.py).
#
#   tools/car_angles.sh                     # all cars -> build/car_angles/car_angles.html
#   tools/car_angles.sh --car=car_mesa      # one car (any tools/car_angles.gd flag passes through)
#
# Needs a display (it renders windowed). GODOT picks the Godot binary (default: godot on the
# PATH), SHOTS_PYTHON the Python with PIL (default: python3), ANGLES_DIR where it all goes.
cd "$(dirname "$0")/.." || exit 2
GODOT=${GODOT:-godot}
PY=${SHOTS_PYTHON:-python3}
out=${ANGLES_DIR:-build/car_angles}
rm -rf "$out" && mkdir -p "$out"
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --path . --audio-driver Dummy -s res://tools/car_angles.gd -- --out="$(cd "$out" && pwd)" "$@" \
  >"$out/godot.log" 2>&1 || { echo "Godot failed (see $out/godot.log)"; exit 1; }
[ -f "$out/index.json" ] || { echo "no shots written (see $out/godot.log)"; exit 1; }
"$PY" tools/car_angles.py "$out" "$out/car_angles.html"
