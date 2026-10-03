#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

usage() {
    echo 'Usage: sh tests/run.sh [all|unit|integration|core|actionbars|castbar|dungeonmaps|editmode|unitframes|experience|quests|tooltips]' >&2
}
[ "$#" -le 1 ] || { usage; exit 2; }
selector=${1:-all}
case "$selector" in
    all|unit|integration|core|actionbars|castbar|dungeonmaps|editmode|unitframes|experience|quests|tooltips) ;;
    *) usage; exit 2 ;;
esac

passed=0
failed=0
failures=''
run() {
    label="$1${2:+ [$2]}"
    echo "RUN: $label"
    if luajit "$@"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        failures="$failures
  $label"
        echo "FAIL: $label" >&2
    fi
}

# Discover every scenario; fixtures and compatibility entrypoints live outside
# these two layers. Keep variants here so selectors run the complete domain.
if ! files=$(find tests/unit tests/integration -type f -name '*.lua'); then
    echo 'Test discovery failed; no scenarios were run.' >&2
    exit 1
fi
files=$(printf '%s\n' "$files" | sort)
for file in $files; do
    relative=${file#tests/}
    layer=${relative%%/*}
    relative=${relative#*/}
    domain=${relative%%/*}
    case "$selector" in all|"$layer"|"$domain") ;; *) continue ;; esac
    run "$file"
    case "$file" in
        tests/integration/core/settings.lua) for variant in de disabled modules-disabled; do run "$file" "$variant"; done ;;
        tests/integration/core/profiles.lua|tests/integration/experience/experience.lua|tests/integration/tooltips/tooltip.lua) run "$file" de ;;
        tests/integration/actionbars/editmode.lua) run "$file" de; run "$file" late ;;
        tests/integration/editmode/integration.lua) for mode in editMode performance neither; do run "$file" "$mode"; done ;;
    esac
done
[ "$passed" -gt 0 ] || [ "$failed" -gt 0 ] || { echo "No tests selected: $selector" >&2; exit 1; }
echo "RESULT: $passed passed, $failed failed ($selector)"
if [ "$failed" -gt 0 ]; then
    printf 'Failed scenarios:%s\n' "$failures" >&2
    exit 1
fi
