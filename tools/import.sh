#!/usr/bin/env bash
# Imports/re-imports all project assets headlessly. Serialized with a lock so parallel agents don't collide.
# Usage (from the DeepMine folder): bash tools/import.sh
G="/c/Users/Jeremy/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
LOCK="${TMPDIR:-/tmp}/deepmine_import.lock"
for i in $(seq 1 180); do mkdir "$LOCK" 2>/dev/null && break; sleep 2; done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
cd "$(dirname "$0")/.." && timeout 300 "$G" --headless --path . --import 2>&1 | grep -E "ERROR|error|SCRIPT" | grep -v "BUG: Unreferenced\|at: unref" | head -40
echo "import done"
