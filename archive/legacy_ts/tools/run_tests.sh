#!/usr/bin/env bash
# Linux/CI twin of tools/Run-Tests.ps1: same suites, same PASS rule.
#   GODOT=/path/to/godot tools/run_tests.sh
# Writes tools/last_test_run.txt and exits with the number of failed suites.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG=tools/last_test_run.txt
echo "Godot: $GODOT ($("$GODOT" --version 2>/dev/null))  $(date '+%Y-%m-%d %H:%M')" > "$LOG"

echo "=== import" | tee -a "$LOG"
timeout 900 "$GODOT" --headless --path . --import > tools/import_log.txt 2>&1
grep -E "ERROR|Parse Error|SCRIPT ERROR" tools/import_log.txt | head -40 | tee -a "$LOG"

suites=(
  "core|--script res://tests/test_core.gd|ALL PASSED"
  "summons v2|--script res://tests/test_summons.gd|ALL PASSED"
  "ui smoke|res://tests/smoke_ui.tscn --quit-after 3000|SMOKE OK"
  "sandbox|res://tests/smoke_sandbox.tscn --quit-after 3000|ALL PASSED"
  "memorial v3|--script res://tests/test_memorial.gd|ALL PASSED"
  "combat|res://tests/smoke_combat.tscn --quit-after 3000|ALL PASSED"
  "mission|res://tests/smoke_mission.tscn --quit-after 3000|ALL PASSED"
  "animation|res://tests/smoke_anim.tscn --quit-after 3000|ALL PASSED"
  "art|res://tests/smoke_art.tscn --quit-after 3000|ALL PASSED"
  "simulation|--script res://tests/test_simulation.gd|ALL PASSED"
  "deep systems|--script res://tests/test_deep_systems.gd|ALL PASSED"
  "procedural|--script res://tests/test_procedural.gd|ALL PASSED"
  "combat core|res://tests/smoke_combat_core.tscn --quit-after 3000|ALL PASSED"
  "orders|res://tests/smoke_orders.tscn --quit-after 3000|ALL PASSED"
  "skills|res://tests/smoke_skills.tscn --quit-after 3000|ALL PASSED"
  "vfx|res://tests/smoke_vfx.tscn --quit-after 3000|ALL PASSED"
  "items|--script res://tests/test_items.gd|ALL PASSED"
  "hq|--script res://tests/test_hq.gd|ALL PASSED"
  "town|--script res://tests/test_town.gd|ALL PASSED"
  "boot|res://tests/smoke_boot.tscn --quit-after 3000|ALL PASSED"
  "tower|res://tests/smoke_tower.tscn --quit-after 3000|ALL PASSED"
  "expedition|res://tests/smoke_expedition.tscn --quit-after 5000|ALL PASSED"
  "slice|res://tests/smoke_slice.tscn --quit-after 6000|ALL PASSED"
  "ui full|res://tests/smoke_ui_full.tscn --quit-after 6000|ALL PASSED"
  "map safety|res://tests/smoke_map_safety.tscn --quit-after 3000|ALL PASSED"
  "tactics|res://tests/smoke_tactics.tscn --quit-after 3000|ALL PASSED"
  "wilds|res://tests/smoke_wilds.tscn --quit-after 3000|ALL PASSED"
  "master|res://tests/smoke_master.tscn --quit-after 3000|ALL PASSED"
  "combat ai|res://tests/smoke_ai.tscn|ALL PASSED"
  "bots|res://tests/smoke_bots.tscn|ALL PASSED"
  "juice|res://tests/smoke_juice.tscn --quit-after 3000|ALL PASSED"
  "fixes|res://tests/smoke_fixes.tscn|ALL PASSED"
  "pista a|res://tests/smoke_pista_a.tscn --quit-after 3000|ALL PASSED"
  "loot|res://tests/smoke_loot.tscn|ALL PASSED"
  "dev console|res://tests/smoke_dev_console.tscn --quit-after 3000|ALL PASSED"
  "sim|-s res://tools/sim/run_sim.gd -- --config tools/sim/configs/test_smoke.json --check-determinism --quiet|ALL PASSED"
)
bad=0
for s in "${suites[@]}"; do
  IFS='|' read -r name args ok <<< "$s"
  # shellcheck disable=SC2086
  out=$(timeout 400 "$GODOT" --headless --path . $args 2>&1); code=$?
  if [ $code -eq 0 ] && grep -qF "$ok" <<< "$out" && ! grep -q "FAIL  " <<< "$out" && ! grep -q "SCRIPT ERROR" <<< "$out"; then
    echo "PASS  $name" | tee -a "$LOG"
  else
    echo "FAIL  $name (exit=$code)" | tee -a "$LOG"
    grep -E "FAIL|ERROR|Parse|SCRIPT|at:" <<< "$out" | head -25 | sed 's/^/      /' | tee -a "$LOG"
    bad=$((bad + 1))
  fi
done
echo "Failed suites: $bad / ${#suites[@]}" | tee -a "$LOG"
exit $bad
