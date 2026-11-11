#!/bin/sh
# The soak test (EQ-22, tests/soak.gd): every stage, car and difficulty raced headless with
# random inputs. Fails on a race that breaks (tests/soak.gd says how) and on any SCRIPT ERROR
# or engine ERROR printed on the way. Arguments go to the script:
#   tools/soak.sh                              # everything: 8 stages x 12 cars x 3 difficulties
#   tools/soak.sh --quick                      # one car per stage and difficulty (a local run)
#   tools/soak.sh --stages=2 --cars=car_mesa --difficulties=hard --seed=7
#   tools/soak.sh --report                     # the autodrive's field per stage and difficulty (RC-21)
# GODOT picks the Godot binary (default: tools/find_godot.sh finds it).
cd "$(dirname "$0")/.." || exit 2
. tools/find_godot.sh
"$GODOT" --headless --path . --import >/dev/null 2>&1
out=$(mktemp)
"$GODOT" --headless --path . -s res://tests/soak.gd -- "$@" >"$out" 2>&1
status=$?
# (the leak notes at exit are the engine's, as in tools/test.sh)
grep -v -e "ObjectDB instances were leaked" -e "resources still in use" \
        -e "at: cleanup" -e "at: clear" -e "^Godot Engine" -e "^ALSA lib" \
        -e "audio drivers failed" -e "Condition \"status < 0\"" "$out" >"$out.shown"
cat "$out.shown"
if grep -q -e "SCRIPT ERROR" -e "^ERROR:" "$out.shown"; then
  echo "FAIL: errors in the soak run (see above)"; status=1
fi
rm -f "$out" "$out.shown"
exit $status
