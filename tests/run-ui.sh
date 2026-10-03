#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root=$(pwd -P)
image=${WOW_UI_IMAGE:-}
if (( $# )); then resolutions=("$@")
else mapfile -t resolutions < tests/ui/resolutions.txt
fi
for resolution in "${resolutions[@]}"; do
    [[ $resolution =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]] || {
        echo "Invalid UI resolution: $resolution (expected WIDTHxHEIGHT)." >&2
        exit 1
    }
done
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT
if [[ -n "$image" ]]; then
    [[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo 'WOW_UI_IMAGE must be an immutable image ID.' >&2; exit 1; }
    docker image inspect "$image" >/dev/null
else
    docker build --target headless --iidfile "$build_dir/image-id" -t pyresinqol-ui:forever -f tests/ui/Dockerfile tests/ui
    # Tags may be replaced by another checkout; retain this build's immutable ID.
    image=$(< "$build_dir/image-id")
fi

# A passing fixture must still fail on startup or probe errors.
probe_dir="$build_dir/probe"
mkdir -p "$probe_dir/tests"
printf '## Interface: 16001\nProbe.lua\n' > "$probe_dir/UIProbe.toc"
printf 'test("passing fixture", function() assertTrue(true) end)\n' > "$probe_dir/tests/probe.lua"
check_error_guard() {
    local sentinel=$1
    shift
    if docker run --rm --network none --env WOW_SIM_SCREEN_SIZE=1280x720 \
        --mount "type=bind,src=$probe_dir,dst=/app/Interface/AddOns/UIProbe,readonly" \
        "$image" --no-saved-vars "$@" run-tests UIProbe > "$build_dir/probe.log" 2>&1; then
        cat "$build_dir/probe.log" >&2
        echo "Simulator ignored $sentinel." >&2
        exit 1
    fi
    if ! grep -Fq "$sentinel" "$build_dir/probe.log"; then
        cat "$build_dir/probe.log" >&2
        echo "Expected $sentinel rejection was not observed." >&2
        exit 1
    fi
    echo "Verified rejection: $sentinel"
}
printf 'error("ui-startup-sentinel")\n' > "$probe_dir/Probe.lua"
check_error_guard ui-startup-sentinel
printf '\n' > "$probe_dir/Probe.lua"
check_error_guard ui-exec-sentinel --exec-lua 'error("ui-exec-sentinel")'

run() {
    local resolution=$1
    shift
    docker run --rm --network none \
        --env "WOW_SIM_SCREEN_SIZE=$resolution" \
        --mount "type=bind,src=$root,dst=/app/Interface/AddOns/PyresinQoL,readonly" \
        --mount "type=bind,src=$root/tests/ui,dst=/app/Interface/AddOns/PyresinQoL/tests,readonly" \
        "$image" --no-saved-vars "$@"
}
# Blizzard redirects print() to chat; keep assertion diagnostics in the CI log.
test_setup='print = function(...)
    for i = 1, select("#", ...) do
        io.stdout:write(tostring((select(i, ...))), "\t")
    end
    io.stdout:write("\n")
end'
for resolution in "${resolutions[@]}"; do
    echo "Testing Forever UI at $resolution"
    width=${resolution%x*}
    height=${resolution#*x}
    # The patched runner rejects startup/probe errors before scoped UI flows.
    run "$resolution" --exec-lua "PyresinQoLUITestResolution = {$width, $height}; $test_setup" run-tests PyresinQoL
done
