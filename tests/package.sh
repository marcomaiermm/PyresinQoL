#!/bin/sh
# Compatibility entrypoint for local development and CI.
exec bash "$(dirname "$0")/tooling/package.sh" "$@"
