#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root=$(pwd -P)
image=${WOW_UI_IMAGE:-}
lane=all
case ${1:-} in
    --matrix|--contracts|--isolation|--locale-scale) lane=${1#--}; shift ;;
esac
if (( $# )); then resolutions=("$@")
else mapfile -t resolutions < tests/ui/resolutions.txt
fi
(( ${#resolutions[@]} > 0 )) || { echo 'UI resolution matrix is empty.' >&2; exit 1; }
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
if [[ $lane == all || $lane == contracts ]]; then
    printf 'error("ui-startup-sentinel")\n' > "$probe_dir/Probe.lua"
    check_error_guard ui-startup-sentinel
    printf '\n' > "$probe_dir/Probe.lua"
    check_error_guard ui-exec-sentinel --exec-lua 'error("ui-exec-sentinel")'
fi

test_dir="$root/tests/ui"
# Opt-in modules (Quests, Flyouts) must run for their native UI flows; ADDON_LOADED reads the
# defaults before any --exec-lua, so overlay them on.
sed 's/, enabledByDefault = false//' Core/Modules.lua > "$build_dir/Modules.lua"
fixture_mounts=(
    --mount "type=bind,src=$build_dir/Modules.lua,dst=/app/Interface/AddOns/PyresinQoL/Core/Modules.lua,readonly"
)
run() {
    local resolution=$1
    shift
    docker run --rm --network none \
        --env "WOW_SIM_SCREEN_SIZE=$resolution" \
        --mount "type=bind,src=$root,dst=/app/Interface/AddOns/PyresinQoL,readonly" \
        --mount "type=bind,src=$test_dir,dst=/app/Interface/AddOns/PyresinQoL/tests,readonly" \
        "${fixture_mounts[@]}" \
        "$image" --no-saved-vars "$@"
}
# Blizzard redirects print() to chat; keep assertion diagnostics in the CI log.
test_setup='print = function(...)
    for i = 1, select("#", ...) do
        io.stdout:write(tostring((select(i, ...))), "\t")
    end
    io.stdout:write("\n")
end'

if [[ $lane == all || $lane == contracts ]]; then
    test_dir="$build_dir/harness"
    mkdir -p "$test_dir"
    cp tests/ui/00-helpers.lua "$test_dir/"
    cp tests/tooling/ui-harness.lua "$test_dir/10-contracts.lua"
    if run 1280x720 --exec-lua "PyresinQoLUITestLane = 'contracts'; $test_setup" run-tests PyresinQoL > "$build_dir/harness.log" 2>&1; then
        cat "$build_dir/harness.log" >&2
        echo 'UI harness swallowed an intentional error.' >&2
        exit 1
    fi
    for marker in ui-harness-timer-sentinel ui-harness-update-sentinel ui-harness-cleanup-sentinel \
        ui-harness-cleanup-timer-sentinel ui-harness-recovery-complete \
        'intentional timer failure' 'intentional update failure' 'intentional cleanup failure' 'intentional cleanup-timer failure'; do
        if ! grep -Fq "$marker" "$build_dir/harness.log"; then
            cat "$build_dir/harness.log" >&2
            echo "UI harness contract missing: $marker" >&2
            exit 1
        fi
    done
    if ! sed $'s/\033\\[[0-9;]*m//g' "$build_dir/harness.log" | grep -Eq '^[0-9]+ tests, [0-9]+ passed, 4 failed$'; then
        cat "$build_dir/harness.log" >&2
        echo 'UI harness must reject exactly the four injected failures.' >&2
        exit 1
    fi
    echo 'Verified rejection: four UI callback/cleanup errors; handlers restored and following flows usable'
fi

test_dir="$root/tests/ui"
if [[ $lane == all || $lane == matrix ]]; then
for resolution in "${resolutions[@]}"; do
    echo "Testing Forever UI at $resolution"
    width=${resolution%x*}
    height=${resolution#*x}
    # The patched runner rejects startup/probe errors before scoped UI flows.
    run "$resolution" --exec-lua "PyresinQoLUITestResolution = {$width, $height}; $test_setup" run-tests PyresinQoL
done
fi

if [[ $lane == all || $lane == isolation ]]; then
    test_dir="$build_dir/isolation"
    mkdir -p "$test_dir"
    cp tests/ui/00-helpers.lua "$test_dir/"
    cp tests/tooling/ui-isolation.lua "$test_dir/01-baseline.lua"
    index=10
    for scenario in profiles profile-transitions castbar auras; do
        cp "tests/ui/$scenario.lua" "$test_dir/$index-$scenario.lua"
        index=$((index + 1))
    done
    cp tests/tooling/ui-isolation.lua "$test_dir/19-check.lua"
    index=20
    for scenario in auras castbar profile-transitions profiles; do
        cp "tests/ui/$scenario.lua" "$test_dir/$index-$scenario.lua"
        index=$((index + 1))
    done
    cp tests/tooling/ui-isolation.lua "$test_dir/29-check.lua"
    echo 'Testing repeated UI flows in forward and reverse order in one simulator'
    run 1280x720 --exec-lua "PyresinQoLUITestLane = 'isolation'; $test_setup" run-tests PyresinQoL
fi

if [[ $lane == all || $lane == locale-scale ]]; then
    test_dir="$build_dir/locale"
    mkdir -p "$test_dir"
    cp tests/ui/00-helpers.lua "$test_dir/"
    cp tests/ui/variants/locale-scale.lua "$test_dir/10-locale-scale.lua"
    # Overlay an existing file: a new nested-bind destination would create a
    # placeholder in the host checkout, even with the outer addon mount read-only.
    cat tests/tooling/ui-locale.lua Core/Localization.lua > "$build_dir/Localization.lua"
    fixture_mounts+=(
        --mount "type=bind,src=$build_dir/Localization.lua,dst=/app/Interface/AddOns/PyresinQoL/Core/Localization.lua,readonly"
    )
    echo 'Testing addon German labels at UIParent scale 1.25 (native Blizzard strings remain enUS)'
    run 1280x720 --exec-lua "PyresinQoLUITestLane = 'locale-scale'; UIParent:SetScale(1.25); $test_setup" run-tests PyresinQoL
fi
