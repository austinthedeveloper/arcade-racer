#!/bin/sh
# Puts the Web build on the Azure Storage static website (the $web container of
# the sundownrun account, https://sundownrun.z13.web.core.windows.net/), then
# removes anything left there from an older build. Argument: the web zip
# (build/release/SundownRun-<version>-web.zip) or an unzipped build folder.
# AZURE_STORAGE_ACCOUNT picks another account. Needs the az CLI signed in with
# Storage Blob Data Contributor on the account (the release workflow's web job
# signs in with OIDC; docs/10-releases.md has the setup).
set -eu
src=${1:?usage: tools/deploy_web.sh <web zip or folder>}
account=${AZURE_STORAGE_ACCOUNT:-sundownrun}

if [ -d "$src" ]; then
	dir=$src
else
	dir=$(mktemp -d)
	trap 'rm -rf "$dir"' EXIT
	unzip -q "$src" -d "$dir"
fi
[ -f "$dir/index.html" ] || { echo "no index.html in $src"; exit 2; }

# Every file is checked again on each visit (no-cache keeps the ETag), so a new
# release shows at once; the content types are set here because not every
# system knows .wasm and .pck. Azure serves blobs as they are stored, so the
# .wasm and .js go up gzipped (the .wasm 39 MB to 10 MB) with Content-Encoding;
# Godot's loader counts progress against index.html's file sizes, not the
# header. The .pck hardly shrinks and goes up as it is.
type_of() {
	case "$1" in
		*.html) echo "text/html; charset=utf-8" ;;
		*.js) echo "text/javascript; charset=utf-8" ;;
		*.wasm) echo "application/wasm" ;;
		*.png) echo "image/png" ;;
		*.json) echo "application/json" ;;
		*) echo "application/octet-stream" ;;
	esac
}

blob() { az storage blob "$@" --account-name "$account" --container-name '$web' --auth-mode login --only-show-errors; }

# index.html last, so a visitor mid-deploy never loads a page for files not up yet.
# The export's .import files are editor leftovers and stay out.
names=$(cd "$dir" && find . -type f ! -name index.html ! -name '*.import' | sed 's|^\./||' | sort)
for name in $names index.html; do
	file=$dir/$name
	encoding=""
	case "$name" in *.wasm | *.js)
		gzip -9 -n -c "$dir/$name" > "$dir/$name.gz"
		file=$dir/$name.gz
		encoding=gzip ;;
	esac
	echo "  $name${encoding:+ (gzip)}"
	blob upload --file "$file" --name "$name" --overwrite --no-progress \
		--content-type "$(type_of "$name")" --content-cache-control "no-cache" \
		${encoding:+--content-encoding "$encoding"} >/dev/null
	[ -z "$encoding" ] || rm "$file"
done

for name in $(blob list --query "[].name" -o tsv); do
	case "$name" in *.import) ;; *) [ -f "$dir/$name" ] && continue ;; esac
	echo "  removed $name"
	blob delete --name "$name"
done
echo "deployed to $(az storage account show -n "$account" --query primaryEndpoints.web -o tsv --only-show-errors)"
