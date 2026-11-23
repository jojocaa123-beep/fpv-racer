#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
report_dir="$project_dir/reports"
mkdir -p "$report_dir"
for suite in physics_smoke input_and_laps motion_steering feedback lap_drive; do
    if "$godot_bin" --headless --debug --path "$project_dir" --audio-driver Dummy \
        --fixed-fps 60 --script "res://tests/$suite.gd" > "$report_dir/$suite.log" 2>&1; then
        cat "$report_dir/$suite.log"
    else
        cat "$report_dir/$suite.log" >&2
        exit 1
    fi
    if rg -q '^(ERROR:|SCRIPT ERROR:|WARNING:|FAIL )' "$report_dir/$suite.log"; then
        echo "A suite $suite emitiu erro ou aviso." >&2
        exit 1
    fi
done
