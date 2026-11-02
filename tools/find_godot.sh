#!/bin/sh
# Sourced by the tools/*.sh scripts: sets GODOT to the Godot binary when it isn't set
# already. Tries `godot` and `godot4` on the PATH, then where the installers put it on
# macOS, Windows (Git Bash) and Linux. Exits with a hint when none is found.
if [ -z "${GODOT:-}" ]; then
  for g in godot godot4 Godot \
      /Applications/Godot.app/Contents/MacOS/Godot \
      "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
      "/c/Program Files/Godot/godot.exe" \
      "$HOME/.local/bin/godot" /usr/local/bin/godot /snap/bin/godot-4; do
    if command -v "$g" >/dev/null 2>&1; then GODOT=$g; break; fi
  done
fi
if [ -z "${GODOT:-}" ]; then
  echo "Godot not found: put godot on the PATH or set GODOT=/path/to/godot" >&2
  exit 2
fi
