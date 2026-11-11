# Plays Tactical Summoners in its own window (not embedded in the editor), so full screen (F11) works.
# Usage: powershell -ExecutionPolicy Bypass -File tools\Play.ps1 [-Godot "C:\path\to\Godot_v4.x.exe"]
param([string]$Godot = "")
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
if (-not $Godot) {
  foreach ($n in "godot","godot4","Godot") { $c = Get-Command $n -ErrorAction SilentlyContinue | Select-Object -First 1; if ($c) { $Godot = $c.Source; break } }
}
if (-not $Godot) {
  $Godot = Get-ChildItem -Path "$env:USERPROFILE\Downloads","$env:USERPROFILE\Desktop","C:\Godot","C:\Program Files\Godot","$env:LOCALAPPDATA","D:\" -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch "console" } | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $Godot) { Write-Host "Godot not found. Re-run with -Godot 'C:\path\to\Godot.exe'" -ForegroundColor Red; exit 1 }
& $Godot --path .
