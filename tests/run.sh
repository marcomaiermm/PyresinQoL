#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

for test in tests/*.lua; do
    luajit "$test"
done
for variant in de disabled modules-disabled; do
    luajit tests/menu.lua "$variant"
done
luajit tests/experience.lua de
luajit tests/tooltip.lua de
for mode in editMode performance neither; do
    luajit tests/editmode-integration.lua "$mode"
done
