#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tag_args=()
if (( $# > 1 )); then
    echo "Usage: bash tools/package.sh [vX.Y.Z]" >&2
    exit 1
fi
if (( $# == 1 )); then tag_args=(--tag "$1"); fi
# The packager only recognises a .git directory; from a worktree it would package the parent checkout.
[[ -d .git ]] || { echo "Run tools/package.sh from the main checkout, not a git worktree." >&2; exit 1; }
version=$(bash tools/check-package.sh "${tag_args[@]}")

# BigWigs v2.6.1 includes WoW Forever support. Pin the local build too.
revision=e50a250f8705041e40f2fa1ddcb280a686d65aa0
mkdir -p .release
packager=".release/packager-$revision.sh"
if [[ ! -f "$packager" ]]; then
    curl --fail --silent --show-error --location --retry 3 \
        "https://raw.githubusercontent.com/BigWigsMods/packager/$revision/release.sh" \
        --output "$packager.tmp"
    mv "$packager.tmp" "$packager"
fi
# Always build, even when a main-branch commit already carries a tag.
GITHUB_ACTIONS='' bash "$packager" -d -u -l -w 0 -p 0 -r "$PWD/dist" -n "PyresinQoL-$version"
bash tools/check-package.sh "${tag_args[@]}" --archive "dist/PyresinQoL-$version.zip"
