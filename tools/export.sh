#!/bin/sh
# Exports the Windows, macOS, Web and Linux builds (export_presets.cfg) and zips
# each into build/release/SundownRun-<version>-<platform>.zip. Needs the
# Godot export templates for the editor's version installed. Argument: the
# version for the file names and the macOS bundle (default: the
# project.godot config/version). Set GODOT to use a binary that isn't
# `godot` on the PATH.
set -eu
cd "$(dirname "$0")/.." || exit 2
GODOT=${GODOT:-godot}
version=${1:-$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)}
version=${version#v}
[ -n "$version" ] || { echo "no version given or in project.godot"; exit 2; }

rm -rf build
mkdir -p build/windows build/macos build/web build/linux build/release
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

# The macOS bundle carries the version; set it in a copy of the presets.
cp export_presets.cfg build/export_presets.cfg.orig
trap 'cp build/export_presets.cfg.orig export_presets.cfg' EXIT
sed -i.bak -e "s/^application\/short_version=.*/application\/short_version=\"$version\"/" \
           -e "s/^application\/version=.*/application\/version=\"$version\"/" \
           -e "s/^application\/file_version=.*/application\/file_version=\"$version.0\"/" \
           -e "s/^application\/product_version=.*/application\/product_version=\"$version.0\"/" \
           export_presets.cfg
rm -f export_presets.cfg.bak

log=build/export.log
for preset in Windows macOS Web Linux; do
  echo "exporting $preset"
  path=$(awk -v p="$preset" '/^name=/{n=($0=="name=\""p"\"")} n&&/^export_path=/{gsub(/export_path=|"/,"");print;exit}' export_presets.cfg)
  "$GODOT" --headless --path . --export-release "$preset" "$path" >>"$log" 2>&1 || true
  # Godot can exit 0 on a failed export; the file is the real check.
  if [ ! -s "$path" ] || grep -q "ERROR:" "$log"; then
    cat "$log"; echo "FAIL: $preset export"; exit 1
  fi
done

out="$PWD/build/release"
(cd build/windows && zip -q -9 "$out/SundownRun-$version-windows.zip" SundownRun.exe)
cp build/macos/SundownRun.zip "$out/SundownRun-$version-macos.zip"
(cd build/web && zip -q -9 -r "$out/SundownRun-$version-web.zip" .)
(cd build/linux && zip -q -9 "$out/SundownRun-$version-linux.zip" SundownRun.x86_64)
ls -l build/release
