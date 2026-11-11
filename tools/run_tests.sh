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
    "tests/test_dodge.gd"
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
    "$GODOT_BIN" --headless --path . --script "$suite" 2>&1 | tee -a "$SUMMARY"
    EXIT=${PIPESTATUS[0]}
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
