#!/bin/sh
# Puts the Web build on the Azure Static Web App behind
# https://sundownrun.austinthedeveloper.com, replacing the last one. Argument: the
# web zip (build/release/SundownRun-<version>-web.zip) or an unzipped build folder.
# --prepare=DIR only writes the site to DIR (an empty or new folder), to look at.
# Needs node, and the az CLI signed in as someone who may read the site's deployment
# token (the release workflow's web job signs in with OIDC; docs/10-releases.md).
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
app=sundownrun
group=sundownrun
url=https://sundownrun.austinthedeveloper.com
prepare=""
src=""
for arg in "$@"; do
	case "$arg" in
		--prepare=*) prepare=${arg#--prepare=} ;;
		*) src=$arg ;;
	esac
done
[ -n "$src" ] || { echo "usage: tools/deploy_swa.sh <web zip or folder> [--prepare=DIR]"; exit 2; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
site=${prepare:-$tmp/site}
mkdir -p "$site"
if [ -n "$(ls -A "$site")" ]; then echo "$site isn't empty"; exit 2; fi
if [ -d "$src" ]; then cp -R "$src/." "$site"; else unzip -q "$src" -d "$site"; fi
for name in index.html index.js index.pck index.wasm; do
	[ -f "$site/$name" ] || { echo "no $name in $src"; exit 2; }
done
# The export's .import files are editor leftovers.
find "$site" -name '*.import' -exec rm {} +

# Static Web Apps doesn't compress .wasm, so the page fetches a gzipped copy and
# unpacks it (web/wasm_gzip.js); the plain one stays for browsers that can't.
gzip -9 -n -c "$site/index.wasm" > "$site/index.wasm.gz"
cp "$root/web/wasm_gzip.js" "$root/web/staticwebapp.config.json" "$site/"
sed 's|<script src="index.js"></script>|<script src="wasm_gzip.js"></script>&|' "$site/index.html" > "$tmp/index.html"
grep -q 'wasm_gzip.js' "$tmp/index.html" || { echo "index.html has no index.js script to put wasm_gzip.js before"; exit 1; }
cp "$tmp/index.html" "$site/index.html"
if [ -n "$prepare" ]; then echo "prepared in $site"; exit 0; fi

token=$(az staticwebapp secrets list --name "$app" --resource-group "$group" --query properties.apiKey -o tsv --only-show-errors)
[ -n "$token" ] || { echo "no deployment token for $app"; exit 1; }
[ -z "${GITHUB_ACTIONS:-}" ] || echo "::add-mask::$token"
# From an empty folder, so the CLI reads no config of its own.
mkdir "$tmp/run"
case "$site" in /*) ;; *) site=$PWD/$site ;; esac
(cd "$tmp/run" && SWA_CLI_DEPLOYMENT_TOKEN="$token" npx --yes @azure/static-web-apps-cli@2.1.0 \
	deploy "$site" --env production --no-use-keychain)

# The page and the game are the ones just uploaded.
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
	if curl -fsS --max-time 60 -o "$tmp/pck" "$url/index.pck" && cmp -s "$tmp/pck" "$site/index.pck" \
		&& curl -fsS --max-time 20 "$url/" | grep -q wasm_gzip.js \
		&& curl -fsS --max-time 60 -o "$tmp/gz" "$url/index.wasm.gz" && cmp -s "$tmp/gz" "$site/index.wasm.gz"; then
		echo "deployed to $url"
		exit 0
	fi
	sleep 10
done
echo "$url isn't serving the build just uploaded"
exit 1
