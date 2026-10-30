#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: bash repo/publish.sh PACKAGE.sfx\n' >&2
}

if [[ $# -ne 1 || ! -f "$1" ]]; then
    usage
    exit 2
fi
for tool in unzip jq sha256sum; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Error: %s is required to publish a package.\n' "$tool" >&2
        exit 1
    fi
done

root=$(cd "$(dirname "$0")/.." && pwd)
repo_dir="$root/repo/arm64"
index="$repo_dir/packages.json"
package_file=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

unzip -tq "$package_file" >/dev/null
if ! unzip -Z1 "$package_file" | grep -Fxq 'install.sh'; then
    printf 'Error: package archive must contain install.sh at its root.\n' >&2
    exit 1
fi
unzip -p "$package_file" manifest.json > "$workdir/manifest.json"
jq -e 'type == "object" and (.name | type == "string") and (.version | type == "string") and (.architecture | type == "string") and ((.dependencies // []) | type == "array")' \
    "$workdir/manifest.json" >/dev/null || {
        printf 'Error: package manifest needs name, version, and architecture strings.\n' >&2
        exit 1
    }

name=$(jq -r '.name' "$workdir/manifest.json")
version=$(jq -r '.version' "$workdir/manifest.json")
architecture=$(jq -r '.architecture | ascii_downcase' "$workdir/manifest.json")
if [[ ! "$name" =~ ^[a-z0-9][a-z0-9+._-]{0,63}$ || ! "$version" =~ ^[A-Za-z0-9][A-Za-z0-9+._-]{0,63}$ ]]; then
    printf 'Error: package name or version contains unsupported characters.\n' >&2
    exit 1
fi
case "$architecture" in
    all|termux|arm64|aarch64|arm64-v8a) ;;
    *) printf 'Error: %s is not an ARM64 Termux package.\n' "$architecture" >&2; exit 1 ;;
esac

mkdir -p "$repo_dir"
if [[ ! -f "$index" ]]; then printf '[]\n' > "$index"; fi
jq -e 'type == "array"' "$index" >/dev/null || {
    printf 'Error: %s must contain a JSON array.\n' "$index" >&2
    exit 1
}

archive_name="${name}-${version}-termux.sfx"
digest=$(sha256sum "$package_file" | cut -d ' ' -f 1)
jq --slurpfile package "$workdir/manifest.json" --arg url "$archive_name" --arg sha256 "$digest" \
    'map(select(.name != $package[0].name)) + [($package[0] + {url: $url, sha256: $sha256})] | sort_by(.name)' \
    "$index" > "$workdir/packages.json"

cp "$package_file" "$workdir/$archive_name"
mv -f "$workdir/$archive_name" "$repo_dir/$archive_name"
mv -f "$workdir/packages.json" "$index"
printf '[+] Published %s %s to %s\n' "$name" "$version" "$repo_dir"
