#!/usr/bin/env bash
# Renders a scene in a real window and saves a screenshot.
# Usage: bash tools/capture.sh res://scenes/ui/SomePanel.tscn /abs/out.png [frames] [extra args passed to _capture_setup]
G="/c/Users/Jeremy/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
cd "$(dirname "$0")/.." && timeout 120 "$G" --path . --resolution 1280x720 --script res://tests/capture.gd -- "$@" 2>&1 | grep -E "ERROR|SCRIPT|capture" | grep -v "BUG: Unreferenced\|at: unref\|leaked\|PagedAllocator" | head -40
