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
    "tests/test_dodge.gd",
    "tests/test_skill_catalog.gd",
    "tests/test_skills.gd"
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
        & $Godot --headless --path . --script $suite 2>&1 |
            Tee-Object -FilePath $summaryPath -Append |
            ForEach-Object { Write-Host $_ }
        $exit = $LASTEXITCODE
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
