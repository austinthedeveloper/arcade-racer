#!/bin/sh
# The common dev runs in one word each (EQ-24). Extra arguments go to the game after `--`.
#   tools/dev.sh play                    the game from the title
#   tools/dev.sh race [stage] [args]     straight into a race on a stage (1 to 8), you driving
#   tools/dev.sh auto [stage] [args]     the same, autodriven
#   tools/dev.sh shots [stage] [frames]  an autodriven race with screenshots to build/shots
#   tools/dev.sh menu <screen> [args]    a menu screenshot to build/menu.png (--screen=, see CLAUDE.md)
#   tools/dev.sh test [filter]           tools/test.sh
#   tools/dev.sh import                  re-import (after adding a class_name script)
cd "$(dirname "$0")/.." || exit 2
. tools/find_godot.sh
cmd=${1:-play}
[ $# -gt 0 ] && shift
stage() { case "${1:-}" in [0-9]*) echo "--stage=$1" ;; *) echo "--stage=1" ;; esac; }
case "$cmd" in
  play) exec "$GODOT" --path . -- "$@" ;;
  race|auto)
    s=$(stage "${1:-}"); case "${1:-}" in [0-9]*) shift ;; esac
    [ "$cmd" = auto ] && set -- --autodrive "$@"
    exec "$GODOT" --path . -- "$s" "$@" ;;
  shots)
    s=$(stage "${1:-}"); case "${1:-}" in [0-9]*) shift ;; esac
    mkdir -p build/shots
    exec "$GODOT" --path . -- "$s" --autodrive --screenshots="${1:-200,700}" --shot-dir="$PWD/build/shots" ;;
  menu)
    [ $# -gt 0 ] || { echo "usage: tools/dev.sh menu <screen> [args]" >&2; exit 2; }
    screen=$1; shift
    mkdir -p build
    exec "$GODOT" --path . -- --screen="$screen" --menu-shot="$PWD/build/menu.png" "$@" ;;
  test) exec tools/test.sh "$@" ;;
  import) exec "$GODOT" --headless --path . --import ;;
  *) sed -n '2,9p' "$0" >&2; exit 2 ;;
esac
