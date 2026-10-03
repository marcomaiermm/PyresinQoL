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
luajit tests/profiles.lua de
luajit tests/actionbars-editmode.lua de
luajit tests/actionbars-editmode.lua late
for mode in editMode performance neither; do
    luajit tests/editmode-integration.lua "$mode"
done
