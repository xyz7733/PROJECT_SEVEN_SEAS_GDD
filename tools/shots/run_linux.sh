#!/usr/bin/env bash
# Runs a screenshot scenario on a Linux machine without a display, using
# xvfb-run and Mesa's software renderer. The game uses a throwaway profile,
# so no saves or settings are read or written.
#
#   bash tools/shots/run_linux.sh SCENARIO.gd OUT_DIR [--locale zh_CN] [--ui 1.5]
#
# GODOT overrides the editor binary (default: the bundled Linux editor).
set -euo pipefail

if [ $# -lt 2 ]; then
	echo "usage: $0 SCENARIO.gd OUT_DIR [--locale zh_CN] [--ui 1.5]" >&2
	exit 2
fi
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
godot="${GODOT:-$root/tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
scenario="$(realpath "$1")"
out="$(realpath -m "$2")"
shift 2

profile="$(mktemp -d)"
trap 'rm -rf "$profile"' EXIT
mkdir -p "$out"
export XDG_DATA_HOME="$profile/data" XDG_CONFIG_HOME="$profile/config" XDG_CACHE_HOME="$profile/cache"

xvfb-run -a -s "-screen 0 1280x720x24" "$godot" --path "$root/game" \
	--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 \
	res://tests/shots.tscn -- --out "$out" --scenario "$scenario" "$@"
