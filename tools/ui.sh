#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root=$(pwd -P)
image=pyresinqol-ui:dev
# Give each checkout its own simulator and IPC socket namespace.
container=pyresinqol-ui-$(printf '%s' "$root" | sha256sum | cut -c1-12)
resolution=${WOW_UI_RESOLUTION:-1920x1080}
[[ $resolution =~ ^([1-9][0-9]*)x([1-9][0-9]*)$ ]] || {
    echo "Invalid UI resolution: $resolution (expected WIDTHxHEIGHT)." >&2
    exit 1
}
width=${BASH_REMATCH[1]}
height=${BASH_REMATCH[2]}

wait_for_preview() {
    local attempt resolution width height
    resolution=$(docker exec "$container" printenv WOW_SIM_SCREEN_SIZE)
    width=${resolution%x*}
    height=${resolution#*x}
    for ((attempt = 0; attempt < 120; attempt++)); do
        if docker exec "$container" /app/wow-cli lua -e "local w, h = GetPhysicalScreenSize(); assert(w == $width and h == $height, 'Unexpected UI viewport'); assert(PyresinQoLSettingsFrame and PyresinQoLSettingsFrame:IsVisible())" >/dev/null 2>&1; then
            return
        fi
        [[ $(docker container inspect -f '{{.State.Running}}' "$container") == true ]] || break
        sleep 0.5
    done
    docker logs "$container" >&2
    echo 'Preview did not become ready. See the simulator log above.' >&2
    return 1
}

render_settings() {
    docker run --rm --network none \
        --env "WOW_SIM_SCREEN_SIZE=$resolution" \
        --mount "type=bind,src=$root,dst=/app/Interface/AddOns/PyresinQoL,readonly" \
        "${assets[@]}" "$image" --no-saved-vars \
        --exec-lua "local w, h = GetPhysicalScreenSize(); assert(w == $width and h == $height, 'Unexpected UI viewport'); assert(PyresinQoLSettingsFrame and PyresinQoLDB, 'Addon did not initialize'); SlashCmdList.PQOL()" lua-errors || return
    docker run --name "$render_container" --network none \
        --env "WOW_SIM_SCREEN_SIZE=$resolution" \
        --mount "type=bind,src=$root,dst=/app/Interface/AddOns/PyresinQoL,readonly" \
        "${assets[@]}" "$image" --no-saved-vars \
        --exec-lua "local w, h = GetPhysicalScreenSize(); assert(w == $width and h == $height, 'Unexpected UI viewport'); SlashCmdList.PQOL()" "$@" screenshot --width "$width" --height "$height" --filter PyresinQoLSettingsFrame -o /tmp/pyresinqol-render.webp || return
    mkdir -p dist/ui || return
    docker cp "$render_container:/tmp/pyresinqol-render.webp" "$root/dist/ui/render-$resolution.webp" || return
    echo "Headless screenshot: $root/dist/ui/render-$resolution.webp"
}

case "${1:-}" in
    preview|render|render-matrix)
        mode=$1
        shift
        display=()
        if [[ $mode == preview ]]; then
            if [[ -n ${WAYLAND_DISPLAY:-} && -S ${XDG_RUNTIME_DIR:-}/${WAYLAND_DISPLAY} ]]; then
                display+=(--mount "type=bind,src=$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY,dst=/run/user/0/wayland-0,readonly"
                    --env WAYLAND_DISPLAY=wayland-0)
            elif [[ -n ${DISPLAY:-} && -d /tmp/.X11-unix ]]; then
                display+=(--mount "type=bind,src=/tmp/.X11-unix,dst=/tmp/.X11-unix,readonly" --env "DISPLAY=$DISPLAY")
                if [[ -f ${XAUTHORITY:-} ]]; then
                    display+=(--mount "type=bind,src=$XAUTHORITY,dst=/tmp/xauthority,readonly" --env XAUTHORITY=/tmp/xauthority)
                fi
            else
                echo 'A local Wayland or X11 desktop is required for preview.' >&2
                exit 1
            fi
        fi
        assets=()
        if [[ -n ${WOW_UI_WOW_PATH:-} ]]; then
            wow_root=$(cd "$WOW_UI_WOW_PATH" && pwd -P)
            if [[ ! -d "$wow_root/Data/data" && -d "$wow_root/../Data/data" ]]; then
                wow_root=$(cd "$wow_root/.." && pwd -P)
            fi
            [[ -d "$wow_root/Data/data" && -f "$wow_root/.product.db" ]] || {
                echo 'The WoW install needs Data/data and .product.db (client subfolders are accepted).' >&2
                exit 1
            }
            assets+=(--mount "type=bind,src=$wow_root,dst=/wow,readonly"
                --env WOW_INSTALL_PATH=/wow --env WOW_SIM_CASC_PATH=/wow/Data
                --mount "type=volume,src=$container-resolver,dst=/root/.cache/asset-resolver"
                --mount "type=volume,src=$container-textures,dst=/root/.cache/wow-ui-sim/casc-extract")
        fi
        build_dir=$(mktemp -d)
        trap 'rm -rf "$build_dir"' EXIT
        docker build --target dev --iidfile "$build_dir/image-id" -t "$image" -f tests/ui/Dockerfile tests/ui
        image=$(< "$build_dir/image-id")
        if [[ $mode != preview ]]; then
            render_container=$container-render-$$
            trap 'docker rm -f "$render_container" >/dev/null 2>&1 || true; rm -rf "$build_dir"' EXIT
            resolutions=("$resolution")
            if [[ $mode == render-matrix ]]; then mapfile -t resolutions < tests/ui/resolutions.txt; fi
            status=0
            for resolution in "${resolutions[@]}"; do
                width=${resolution%x*}
                height=${resolution#*x}
                render_settings "$@" || status=1
                docker rm -f "$render_container" >/dev/null 2>&1 || true
            done
            exit "$status"
        fi
        if docker container inspect "$container" >/dev/null 2>&1; then
            docker rm -f "$container" >/dev/null
        fi
        docker run -d --name "$container" --network none \
            --env "WOW_SIM_SCREEN_SIZE=$resolution" \
            --mount "type=bind,src=$root,dst=/app/Interface/AddOns/PyresinQoL,readonly" \
            "${display[@]}" "${assets[@]}" "$image" --no-saved-vars \
            --exec-lua 'assert(PyresinQoLSettingsFrame and PyresinQoLDB, "Addon did not initialize"); SlashCmdList.PQOL()' "$@"
        wait_for_preview
        echo 'Edit the addon, then run: bash tools/ui.sh reload'
        ;;
    reload)
        # Upstream ReloadUI()/Ctrl+R only replays events; restarting rereads Lua/XML.
        docker restart "$container"
        wait_for_preview
        ;;
    lua)
        [[ $# == 2 ]] || { echo "Usage: bash tools/ui.sh lua 'Lua code'" >&2; exit 1; }
        docker exec "$container" /app/wow-cli lua -e "$2"
        ;;
    inspect)
        docker exec "$container" /app/wow-cli dump-tree --filter-key PyresinQoLSettingsFrame --visible-only
        ;;
    screenshot)
        resolution=$(docker exec "$container" printenv WOW_SIM_SCREEN_SIZE)
        width=${resolution%x*}
        height=${resolution#*x}
        mkdir -p dist/ui
        docker exec "$container" /app/wow-cli lua -e "local w, h = GetPhysicalScreenSize(); assert(w == $width and h == $height, 'Unexpected UI viewport')"
        docker exec "$container" /app/wow-cli screenshot --width "$width" --height "$height" --filter PyresinQoLSettingsFrame -o /tmp/pyresinqol-preview.webp
        docker cp "$container:/tmp/pyresinqol-preview.webp" "$root/dist/ui/preview.webp"
        echo "Screenshot: $root/dist/ui/preview.webp"
        ;;
    logs)
        docker logs "$container"
        ;;
    stop)
        docker rm -f "$container"
        ;;
    *)
        echo 'Usage: bash tools/ui.sh {preview [options]|render [options]|render-matrix [options]|reload|lua "code"|inspect|screenshot|logs|stop}' >&2
        exit 1
        ;;
esac
