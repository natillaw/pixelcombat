<#
 Runs every headless test for Tactical Summoners. No editor needed.
   powershell -ExecutionPolicy Bypass -File tools\Run-Tests.ps1
 Optional: -Godot "C:\path\to\Godot_v4.x.exe"
 Prints one PASS/FAIL line per suite and writes tools\last_test_run.txt.
 Strict verification of process exit codes and success markers.
#>
param([string]$Godot = "")
$ErrorActionPreference = "Continue"
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not (Test-Path "project.godot")) { Write-Host "Run from the project (project.godot not found)." -ForegroundColor Red; exit 1 }

if (-not $Godot) {
  foreach ($n in "godot","godot4","Godot") { $c = Get-Command $n -ErrorAction SilentlyContinue | Select-Object -First 1; if ($c) { $Godot = $c.Source; break } }
}
if (-not $Godot) {
  $Godot = Get-ChildItem -Path "$env:USERPROFILE\Downloads","$env:USERPROFILE\Desktop","C:\Godot","C:\Program Files\Godot","$env:LOCALAPPDATA","D:\" -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch "console" } | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $Godot) { Write-Host "Godot not found. Re-run with -Godot 'C:\path\to\Godot.exe'" -ForegroundColor Red; exit 1 }
Write-Host "Using Godot: $Godot"

$log = New-Object System.Collections.Generic.List[string]
$log.Add("Godot: $Godot  ($(& $Godot --version 2>$null))  $(Get-Date -Format 'yyyy-MM-dd HH:mm')")

# import first so new class_name scripts are registered
& $Godot --headless --path . --import *> $null

$suites = @(
  @{ name = "core";          args = @("--script", "res://tests/test_core.gd");                          ok = "ALL PASSED" },
  @{ name = "summons v2";    args = @("--script", "res://tests/test_summons.gd");                       ok = "ALL PASSED" },
  @{ name = "ui smoke";      args = @("res://tests/smoke_ui.tscn", "--quit-after", "3000");             ok = "SMOKE OK" },
  @{ name = "sandbox";       args = @("res://tests/smoke_sandbox.tscn", "--quit-after", "3000");        ok = "ALL PASSED" },
  @{ name = "memorial v3";   args = @("--script", "res://tests/test_memorial.gd");                         ok = "ALL PASSED" },
  @{ name = "combat";        args = @("res://tests/smoke_combat.tscn", "--quit-after", "3000");         ok = "ALL PASSED" },
  @{ name = "mission";       args = @("res://tests/smoke_mission.tscn", "--quit-after", "3000");        ok = "ALL PASSED" },
  @{ name = "animation";     args = @("res://tests/smoke_anim.tscn", "--quit-after", "3000");           ok = "ALL PASSED" },
  @{ name = "art";           args = @("res://tests/smoke_art.tscn", "--quit-after", "3000");            ok = "ALL PASSED" },
  @{ name = "simulation";    args = @("--script", "res://tests/test_simulation.gd");                    ok = "ALL PASSED" },
  @{ name = "deep systems";  args = @("--script", "res://tests/test_deep_systems.gd");                  ok = "ALL PASSED" },
  @{ name = "procedural";    args = @("--script", "res://tests/test_procedural.gd");                    ok = "ALL PASSED" },
  @{ name = "combat core";   args = @("res://tests/smoke_combat_core.tscn", "--quit-after", "3000");    ok = "ALL PASSED" },
  @{ name = "orders";        args = @("res://tests/smoke_orders.tscn", "--quit-after", "3000");         ok = "ALL PASSED" },
  @{ name = "skills";        args = @("res://tests/smoke_skills.tscn", "--quit-after", "3000");         ok = "ALL PASSED" },
  @{ name = "vfx";           args = @("res://tests/smoke_vfx.tscn", "--quit-after", "3000");            ok = "ALL PASSED" },
  @{ name = "hq";            args = @("--script", "res://tests/test_hq.gd");                           ok = "ALL PASSED" },
  @{ name = "items";         args = @("--script", "res://tests/test_items.gd");                        ok = "ALL PASSED" },
  @{ name = "town";          args = @("--script", "res://tests/test_town.gd");                         ok = "ALL PASSED" },
  @{ name = "boot";          args = @("res://tests/smoke_boot.tscn", "--quit-after", "3000");           ok = "ALL PASSED" },
  @{ name = "tower";         args = @("res://tests/smoke_tower.tscn", "--quit-after", "3000");          ok = "ALL PASSED" },
  @{ name = "expedition";    args = @("res://tests/smoke_expedition.tscn", "--quit-after", "5000");     ok = "ALL PASSED" },
  @{ name = "slice";         args = @("res://tests/smoke_slice.tscn", "--quit-after", "6000");          ok = "ALL PASSED" },
  @{ name = "ui full";       args = @("res://tests/smoke_ui_full.tscn", "--quit-after", "6000");        ok = "ALL PASSED" },
  @{ name = "map safety";    args = @("res://tests/smoke_map_safety.tscn", "--quit-after", "3000");     ok = "ALL PASSED" },
  @{ name = "tactics";       args = @("res://tests/smoke_tactics.tscn", "--quit-after", "3000");       ok = "ALL PASSED" },
  @{ name = "wilds";         args = @("res://tests/smoke_wilds.tscn", "--quit-after", "3000");         ok = "ALL PASSED" },
  @{ name = "master";        args = @("res://tests/smoke_master.tscn", "--quit-after", "3000");        ok = "ALL PASSED" },
  @{ name = "combat ai";     args = @("res://tests/smoke_ai.tscn");                                    ok = "ALL PASSED" },
  @{ name = "bots";          args = @("res://tests/smoke_bots.tscn");                                  ok = "ALL PASSED" },
  @{ name = "juice";         args = @("res://tests/smoke_juice.tscn", "--quit-after", "3000");        ok = "ALL PASSED" },
  @{ name = "fixes";         args = @("res://tests/smoke_fixes.tscn");                                 ok = "ALL PASSED" },
  @{ name = "pista a";       args = @("res://tests/smoke_pista_a.tscn", "--quit-after", "3000");      ok = "ALL PASSED" },
  @{ name = "loot";          args = @("res://tests/smoke_loot.tscn");                                  ok = "ALL PASSED" },
  @{ name = "dev console";   args = @("res://tests/smoke_dev_console.tscn", "--quit-after", "3000");   ok = "ALL PASSED" },
  @{ name = "sim";           args = @("-s", "res://tools/sim/run_sim.gd", "--", "--config", "tools/sim/configs/test_smoke.json", "--check-determinism", "--quiet"); ok = "ALL PASSED" }
)
$bad = 0
foreach ($s in $suites) {
  $out = & $Godot --headless --path . @($s.args) 2>&1 | Out-String
  $exitCode = $LASTEXITCODE
  $pass = ($exitCode -eq 0) -and ($out -match [regex]::Escape($s.ok)) -and ($out -notmatch "FAIL  ") -and ($out -notmatch "SCRIPT ERROR")
  if ($pass) { Write-Host ("PASS  " + $s.name) -ForegroundColor Green } else { Write-Host ("FAIL  " + $s.name) -ForegroundColor Red; $bad++ }
  $log.Add("=== $($s.name): " + $(if ($pass) { "PASS" } else { "FAIL (exit=$exitCode)" }))
  if (-not $pass) { $log.Add(($out -split "`n" | Where-Object { $_ -match "FAIL|ERROR|Parse|SCRIPT" } | Select-Object -First 25) -join "`n") }
}
$log | Set-Content "tools\last_test_run.txt" -Encoding UTF8
Write-Host "`nResult written to tools\last_test_run.txt  ($bad suite(s) failed)"
exit $bad
