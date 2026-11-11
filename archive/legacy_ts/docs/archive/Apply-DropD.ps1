<#
 Applies Drop D (T-022 asset inbox + T-023 code animations) to your project.
   powershell -ExecutionPolicy Bypass -File .\Apply-DropD.ps1 -Project "C:\path\to\tactical_summoners"
 Backs up every file it overwrites into <project>\_backup_dropD\ first. Then run tools\Run-Tests.ps1.
#>
param([Parameter(Mandatory = $true)][string]$Project)
$ErrorActionPreference = "Stop"
$Project = (Resolve-Path $Project).Path
if (-not (Test-Path (Join-Path $Project "project.godot"))) { Write-Host "No project.godot in $Project" -ForegroundColor Red; exit 1 }
$here = $PSScriptRoot
$bak = Join-Path $Project "_backup_dropD"
$files = Get-ChildItem $here -Recurse -File -Force | Where-Object { $_.Name -ne "Apply-DropD.ps1" }
$n = 0; $b = 0
foreach ($f in $files) {
  $rel = $f.FullName.Substring($here.Length).TrimStart("\", "/")
  $dst = Join-Path $Project $rel
  New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
  if (Test-Path $dst) {
    $bd = Join-Path $bak $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $bd -Parent) | Out-Null
    Copy-Item $dst $bd -Force; $b++
  }
  Copy-Item $f.FullName $dst -Force; $n++
}
Write-Host "Copied $n files ($b backed up to _backup_dropD)." -ForegroundColor Green
Write-Host "Next: powershell -ExecutionPolicy Bypass -File $Project\tools\Run-Tests.ps1   (expect 8 suites PASS)"
