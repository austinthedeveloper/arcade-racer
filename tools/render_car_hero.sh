#!/bin/sh
# A car's car select picture from its 3D model: Blender renders it on a stretch of coast road
# (tools/blender/render_car_hero.py, same camera and sun for every car), then
# tools/make_car_heroes.py puts the title screen's coast behind it and writes
# assets/sprites/ui/car_<car>.png.
#   tools/render_car_hero.sh vega [--model=path.glb] [--samples=96]
# The model defaults to assets/models/<car>.glb. BLENDER and PYTHON as in tools/render_car.sh.
set -eu
cd "$(dirname "$0")/.." || exit 2
car=${1:?usage: tools/render_car_hero.sh <car> [--model=path] [--samples=N]}
shift
model=assets/models/$car.glb
samples=96
for arg in "$@"; do
	case "$arg" in
		--model=*) model=${arg#--model=} ;;
		--samples=*) samples=${arg#--samples=} ;;
		*) echo "unknown option $arg"; exit 2 ;;
	esac
done
[ -f "$model" ] || { echo "no model at $model"; exit 2; }
if [ -z "${BLENDER:-}" ]; then
	BLENDER=$(command -v blender || true)
	[ -n "$BLENDER" ] || BLENDER=/Applications/Blender.app/Contents/MacOS/Blender
fi
[ -x "$BLENDER" ] || { echo "Blender not found: brew install --cask blender, or set BLENDER"; exit 2; }
PYTHON=${PYTHON:-python3}
out=build/car_heroes
rm -f "$out/$car.png" "$out/$car.horizon"
"$BLENDER" -b --factory-startup -P tools/blender/render_car_hero.py -- \
	--model "$model" --car="$car" --samples="$samples" --out "$out/$car.png" | grep -E "^framed|^rendered|Error|Traceback" || true
[ -f "$out/$car.horizon" ] || { echo "Blender wrote no picture"; exit 1; }
"$PYTHON" tools/make_car_heroes.py "$out" . "$car"
