#!/usr/bin/env bash
# Ejecuta todas las suites headless de PixelCombat en Godot 4.7.x.
#
#   GODOT=/ruta/a/godot bash tools/run_tests.sh
#
# Escribe el resultado completo en tools/last_test_run.txt y el log de
# importación en tools/import_log.txt. Sale con código 1 si la importación o
# cualquier suite falla.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY="$ROOT/tools/last_test_run.txt"
IMPORT_LOG="$ROOT/tools/import_log.txt"
GODOT_BIN="${GODOT:-godot}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [ ! -x "$GODOT_BIN" ]; then
    echo "Godot no encontrado: $GODOT_BIN (define la variable GODOT)" >&2
    exit 1
fi

SUITES=(
    "core/tests/test_tick.gd"
    "net/tests/test_net.gd"
    "net/tests/test_reconciliation.gd"
    "combat/tests/test_stats.gd"
    "combat/tests/test_skill.gd"
    "combat/tests/test_effect_pipeline.gd"
    "combat/tests/test_hit_authority.gd"
    "combat/tests/test_rogue.gd"
    "combat/tests/test_warrior.gd"
    "tests/test_warrior_sim.gd"
    "tests/test_warrior_data.gd"
    "tests/test_asset_licenses.gd"
    "tests/test_facing.gd"
    "tests/test_tutorial.gd"
    "tests/test_campfire.gd"
    "tests/test_city_life.gd"
    "tests/test_floor_bot.gd"
    "tests/test_level_cap.gd"
    "tests/test_story_floors.gd"
    "tests/test_accessibility.gd"
    "tests/test_music.gd"
    "tests/test_rules.gd"
    "tests/test_duels.gd"
    "tests/test_input_delay.gd"
    "tests/test_collision_sweep.gd"
    "tests/test_input_conflicts.gd"
    "tests/test_save_robustness.gd"
    "tests/test_sim_fuzz.gd"
    "tests/test_memory_leaks.gd"
    "tests/test_dodge.gd"
    "tests/test_kits.gd"
    "tests/test_combat_depth.gd"
    "tests/test_services.gd"
    "tests/test_narrative.gd"
    "tests/test_quests.gd"
    "tests/test_world_sanity.gd"
    "tests/test_warrior_kit.gd"
    "tests/test_rogue_kit.gd"
    "tests/test_mage_kit.gd"
    "tests/test_skill_catalog.gd"
    "tests/test_skills.gd"
    "tests/test_ultimate.gd"
    "tests/test_basics.gd"
    "tests/test_enemies.gd"
    "tests/test_progression.gd"
    "tests/test_special.gd"
    "tests/test_classes.gd"
    "tests/test_projectiles.gd"
    "tests/test_class_skills.gd"
    "tests/test_balance.gd"
    "tests/test_ranged_boss.gd"
    "tests/test_status.gd"
    "tests/test_tower.gd"
    "tests/test_items.gd"
    "tests/test_gathering.gd"
    "tests/test_crafting.gd"
    "tests/test_tilegrid.gd"
    "tests/test_mapgen.gd"
    "tests/test_missions.gd"
    "tests/test_fx.gd"
    "tests/test_scene_smoke.tscn"
    "tests/test_creator.tscn"
    "tests/test_menus.tscn"
)

: >"$SUMMARY"
: >"$IMPORT_LOG"

cd "$ROOT" || exit 1

echo "== Import =="
"$GODOT_BIN" --headless --path . --import 2>&1 | tee "$IMPORT_LOG" | tail -n 20
IMPORT_EXIT=${PIPESTATUS[0]}
if [ "$IMPORT_EXIT" -ne 0 ]; then
    # Importacion en frio: Godot 4.7.2 a veces termina con segfault; el segundo
    # intento reutiliza la cache y suele pasar.
    echo "Import fallo (exit $IMPORT_EXIT); reintentando una vez"
    "$GODOT_BIN" --headless --path . --import 2>&1 | tee "$IMPORT_LOG" | tail -n 20
    IMPORT_EXIT=${PIPESTATUS[0]}
fi
if [ "$IMPORT_EXIT" -ne 0 ]; then
    echo "IMPORT FAILED (exit $IMPORT_EXIT); revisa tools/import_log.txt"
    echo "IMPORT FAILED (exit $IMPORT_EXIT)" >>"$SUMMARY"
else
    echo "Import OK"
fi

FAILED=()

for suite in "${SUITES[@]}"; do
    echo
    echo "== $suite =="
    echo "===== $suite =====" >>"$SUMMARY"
    if [[ "$suite" == *.tscn ]]; then RUN_ARGS=("res://$suite"); else RUN_ARGS=(--script "$suite"); fi
    SUITE_LOG="$(mktemp)"
    "$GODOT_BIN" --headless --path . "${RUN_ARGS[@]}" 2>&1 | tee -a "$SUMMARY" "$SUITE_LOG"
    EXIT=${PIPESTATUS[0]}
    # Un SCRIPT ERROR (fallo de ejecucion) deja el resto de la suite sin correr aunque Godot salga con 0.
    if [ "$EXIT" -eq 0 ] && grep -q "SCRIPT ERROR" "$SUITE_LOG"; then EXIT=1; fi
    rm -f "$SUITE_LOG"
    if [ "$EXIT" -ne 0 ]; then
        FAILED+=("$suite")
        echo "FAIL $suite (exit $EXIT)"
        echo "RESULT: FAIL (exit $EXIT)" >>"$SUMMARY"
    else
        echo "PASS $suite"
    fi
    echo >>"$SUMMARY"
done

echo
if [ "$IMPORT_EXIT" -ne 0 ] || [ "${#FAILED[@]}" -gt 0 ]; then
    echo "== RESULTADO: FAIL =="
    [ "$IMPORT_EXIT" -ne 0 ] && echo "  import: failed"
    for suite in "${FAILED[@]}"; do
        echo "  $suite"
    done
    echo "== RESULTADO: FAIL ==" >>"$SUMMARY"
    exit 1
fi

echo "== RESULTADO: PASS (${#SUITES[@]} suites) =="
echo "== RESULTADO: PASS (${#SUITES[@]} suites) ==" >>"$SUMMARY"
