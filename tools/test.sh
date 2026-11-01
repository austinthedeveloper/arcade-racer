#!/bin/sh
# Runs every Godot test suite headless, then the end-to-end input smoke
# (the real main scene driven through the input map), then the sprite tools'
# Python self-tests if Pillow, numpy and scipy are there. Exits non-zero if
# any fails. Optional argument: a substring filter on suite.test names (skips
# the e2e and the Python tests), or --skip=<substring> to run everything but
# the suite.test names containing it (CI: --skip=test_golden. beside a
# test_golden. job). Set GODOT to use a binary that isn't `godot`
# on the PATH, PYTHON for a Python with tools/requirements.txt.
cd "$(dirname "$0")/.." || exit 2
GODOT=${GODOT:-godot}
"$GODOT" --headless --path . --import >/dev/null 2>&1
filter() {
  grep -v -e "ObjectDB instances were leaked" -e "resources still in use" \
          -e "at: cleanup" -e "at: clear" -e "^Godot Engine" -e "^ALSA lib" \
          -e "audio drivers failed" -e "Condition \"status < 0\"" "$1"
}
out=$(mktemp)
"$GODOT" --headless --path . -s res://tests/run_tests.gd -- "$@" >"$out" 2>&1
status=$?
filter "$out"
# A script error inside a passing test still fails the run.
if grep -q "SCRIPT ERROR" "$out"; then
  echo "FAIL: script errors in the test run (see above)"; status=1
fi
case "$1" in ""|--skip=*) all=1 ;; *) all= ;; esac
if [ -n "$all" ]; then
  printf "\nend-to-end input smoke:\n"
  "$GODOT" --headless --path . -s res://tests/e2e_input.gd >"$out" 2>&1
  e2e=$?
  filter "$out"
  if grep -q "SCRIPT ERROR" "$out"; then
    echo "FAIL: script errors in the e2e run"; e2e=1
  fi
  [ $e2e -ne 0 ] && status=$e2e
  # The sprite tools' helpers (tools/test_spritelib.py), when their libraries are installed.
  PYTHON=${PYTHON:-python3}
  printf "\nsprite tool helpers:\n"
  if "$PYTHON" -c "import PIL, numpy, scipy" >/dev/null 2>&1; then
    "$PYTHON" -m unittest discover -s tools -p "test_*.py" >"$out" 2>&1 || status=1
    grep -v "^background " "$out"
  else
    echo "skipped: $PYTHON has no Pillow/numpy/scipy (pip install -r tools/requirements.txt, or set PYTHON)"
  fi
fi
rm -f "$out"
exit $status
