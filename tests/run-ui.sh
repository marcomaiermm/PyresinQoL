#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root=$(pwd -P)
image=pyresinqol-ui:forever
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
docker build --target headless --iidfile "$build_dir/image-id" -t "$image" -f tests/ui/Dockerfile tests/ui
# Tags may be replaced by another checkout; retain this build's immutable ID.
image=$(< "$build_dir/image-id")

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
    # run-tests reports assertion failures; lua-errors also rejects startup errors.
    run "$resolution" --exec-lua "local w, h = GetPhysicalScreenSize(); assert(w == $width and h == $height, 'Unexpected UI viewport'); assert(PyresinQoLSettingsFrame and PyresinQoLDB, 'PyresinQoL did not initialize')" lua-errors
    run "$resolution" --exec-lua "PyresinQoLUITestResolution = {$width, $height}; $test_setup" run-tests PyresinQoL
done
