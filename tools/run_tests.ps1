# Ejecuta todas las suites headless de PixelCombat en Godot 4.7.x.
#
#   pwsh -File tools/run_tests.ps1
#   pwsh -File tools/run_tests.ps1 -Godot "C:\ruta\a\godot_console.exe"
#
# También acepta la variable de entorno GODOT. Escribe el resultado completo en
# tools/last_test_run.txt y el log de importación en tools/import_log.txt.
# Sale con código 1 si la importación o cualquier suite falla.

[CmdletBinding()]
param(
    [string]$Godot = $env:GODOT
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$summaryPath = Join-Path $PSScriptRoot "last_test_run.txt"
$importLogPath = Join-Path $PSScriptRoot "import_log.txt"

if (-not $Godot) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'),
        (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $Godot = $candidate
            break
        }
    }
}

if (-not $Godot) {
    Write-Error "Godot no encontrado. Pasa -Godot <ruta> o define la variable GODOT."
}
if (-not (Test-Path $Godot)) {
    Write-Error "El ejecutable de Godot no existe: $Godot"
}

$suites = @(
    "core/tests/test_tick.gd",
    "net/tests/test_net.gd",
    "net/tests/test_reconciliation.gd",
    "combat/tests/test_stats.gd",
    "combat/tests/test_skill.gd",
    "combat/tests/test_effect_pipeline.gd",
    "combat/tests/test_hit_authority.gd",
    "combat/tests/test_rogue.gd",
    "combat/tests/test_warrior.gd",
    "tests/test_warrior_sim.gd",
    "tests/test_warrior_data.gd",
    "tests/test_asset_licenses.gd",
    "tests/test_facing.gd",
    "tests/test_tutorial.gd",
    "tests/test_campfire.gd",
    "tests/test_city_life.gd",
    "tests/test_floor_bot.gd",
    "tests/test_level_cap.gd",
    "tests/test_story_floors.gd",
    "tests/test_accessibility.gd",
    "tests/test_music.gd",
    "tests/test_rules.gd",
    "tests/test_duels.gd",
    "tests/test_input_delay.gd",
    "tests/test_collision_sweep.gd",
    "tests/test_input_conflicts.gd",
    "tests/test_save_robustness.gd",
    "tests/test_sim_fuzz.gd",
    "tests/test_memory_leaks.gd",
    "tests/test_dodge.gd",
    "tests/test_kits.gd",
    "tests/test_combat_depth.gd",
    "tests/test_services.gd",
    "tests/test_narrative.gd",
    "tests/test_quests.gd",
    "tests/test_world_sanity.gd",
    "tests/test_warrior_kit.gd",
    "tests/test_rogue_kit.gd",
    "tests/test_mage_kit.gd",
    "tests/test_skill_catalog.gd",
    "tests/test_skills.gd",
    "tests/test_ultimate.gd",
    "tests/test_basics.gd",
    "tests/test_enemies.gd",
    "tests/test_enemy_roster.gd",
    "tests/test_playtest_log.gd",
    "tests/test_environment.gd",
    "tests/test_camps.gd",
    "tests/test_villages.gd",
    "tests/test_heroes.gd",
    "tests/test_skill_spanish.gd",
    "tests/test_authored_floors.gd",
    "tests/test_discoveries.gd",
    "tests/test_floor_modifiers.gd",
    "tests/test_progression.gd",
    "tests/test_special.gd",
    "tests/test_classes.gd",
    "tests/test_projectiles.gd",
    "tests/test_class_skills.gd",
    "tests/test_balance.gd",
    "tests/test_ranged_boss.gd",
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
    "tests/test_creator.tscn",
    "tests/test_menus.tscn"
)

"" | Set-Content -Path $summaryPath -Encoding utf8
"" | Set-Content -Path $importLogPath -Encoding utf8

Push-Location $root
try {
    Write-Host "== Import =="
    & $Godot --headless --path . --import 2>&1 | Tee-Object -FilePath $importLogPath | Out-Null
    $importExit = $LASTEXITCODE
    if ($importExit -ne 0) {
        # En una importacion en frio Godot 4.7.2 a veces termina con segfault;
        # el segundo intento reutiliza la cache y suele pasar.
        Write-Host "Import fallo (exit $importExit); reintentando una vez"
        & $Godot --headless --path . --import 2>&1 | Tee-Object -FilePath $importLogPath | Out-Null
        $importExit = $LASTEXITCODE
    }
    if ($importExit -ne 0) {
        Write-Host "IMPORT FAILED (exit $importExit); revisa $importLogPath"
        "IMPORT FAILED (exit $importExit)" | Add-Content -Path $summaryPath -Encoding utf8
    } else {
        Write-Host "Import OK"
    }

    $failed = @()
    foreach ($suite in $suites) {
        Write-Host ""
        Write-Host "== $suite =="
        "===== $suite =====" | Add-Content -Path $summaryPath -Encoding utf8
        $runArgs = if ($suite -like '*.tscn') { @("res://$suite") } else { @('--script', $suite) }
        $suiteLines = @()
        & $Godot --headless --path . @runArgs 2>&1 |
            Tee-Object -FilePath $summaryPath -Append |
            ForEach-Object { Write-Host $_; $suiteLines += "$_" }
        $exit = $LASTEXITCODE
        # Un SCRIPT ERROR deja el resto de la suite sin correr aunque Godot salga con 0.
        if ($exit -eq 0 -and ($suiteLines | Where-Object { $_ -match 'SCRIPT ERROR' })) { $exit = 1 }
        if ($exit -ne 0) {
            $failed += $suite
            Write-Host "FAIL $suite (exit $exit)"
            "RESULT: FAIL (exit $exit)" | Add-Content -Path $summaryPath -Encoding utf8
        } else {
            Write-Host "PASS $suite"
        }
        "" | Add-Content -Path $summaryPath -Encoding utf8
    }

    Write-Host ""
    if ($importExit -ne 0 -or $failed.Count -gt 0) {
        Write-Host "== RESULTADO: FAIL =="
        if ($importExit -ne 0) {
            Write-Host "  import: failed"
        }
        foreach ($suite in $failed) {
            Write-Host "  $suite"
        }
        "== RESULTADO: FAIL ==" | Add-Content -Path $summaryPath -Encoding utf8
        exit 1
    }

    Write-Host "== RESULTADO: PASS ($($suites.Count) suites) =="
    "== RESULTADO: PASS ($($suites.Count) suites) ==" | Add-Content -Path $summaryPath -Encoding utf8
} finally {
    Pop-Location
}
