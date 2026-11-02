#!/bin/sh
# A player car's strips from its 3D model (CP-1): Blender renders the 21 frames
# (tools/blender/render_car.py), then tools/make_car_renders.py shrinks them into
# build/car_renders/<car>/strips/ with a review page, compare.html, beside the
# concept-sheet strips. --install also writes them into assets/sprites/cars/.
#   tools/render_car.sh vega [--install] [--model=path.glb] [--forward=y] [--style=cel]
# The model defaults to assets/models/<car>.glb. BLENDER picks the Blender binary
# (default: blender on the PATH, or the macOS app); PYTHON one with the sprite
# tools' libraries (tools/requirements.txt).
set -eu
cd "$(dirname "$0")/.." || exit 2
car=${1:?usage: tools/render_car.sh <car> [--install] [--model=path] [--forward=axis]}
shift
model=assets/models/$car.glb
forward=y
style=shaded
install=""
for arg in "$@"; do
	case "$arg" in
		--install) install=--install ;;
		--model=*) model=${arg#--model=} ;;
		--forward=*) forward=${arg#--forward=} ;;
		--style=*) style=${arg#--style=} ;;
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
out=build/car_renders/$car
rm -rf "$out"
"$BLENDER" -b --factory-startup -P tools/blender/render_car.py -- \
	--model "$model" --out "$out" --forward="$forward" --style="$style" | grep -E "^rendered|Error|Traceback" || true
[ -f "$out/level_3.png" ] || { echo "Blender wrote no frames"; exit 1; }
"$PYTHON" tools/make_car_renders.py "$out" "$car" $install
