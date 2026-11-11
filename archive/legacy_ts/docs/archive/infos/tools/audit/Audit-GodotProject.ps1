<#
 T-001 audit. Run from the Godot project root (where project.godot is):
   powershell -ExecutionPolicy Bypass -File tools\audit\Audit-GodotProject.ps1
 Optional: -Commit  (git init if needed + safe first commit)
 Output: docs\ai-context\AUDIT_T001.md  (small; give this file to the next AI)
#>
param([string]$ProjectPath = (Get-Location).Path, [switch]$Commit)
$ErrorActionPreference = "Continue"
Set-Location $ProjectPath
if (-not (Test-Path "project.godot")) { Write-Host "project.godot not found in $ProjectPath. Run this from your Godot project root." -ForegroundColor Red; exit 1 }

$out = New-Object System.Collections.Generic.List[string]
function Add-Line($t) { $out.Add($t) }
$skip = '\\(\.godot|\.git|addons)\\'

# --- project.godot ---
$pg = Get-Content "project.godot" -Raw
Add-Line "# T-001 Audit ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
Add-Line "Project path: $ProjectPath"
$name = [regex]::Match($pg, 'config/name="([^"]*)"').Groups[1].Value
$feat = [regex]::Match($pg, 'config/features=PackedStringArray\(([^)]*)\)').Groups[1].Value
$main = [regex]::Match($pg, 'run/main_scene="([^"]*)"').Groups[1].Value
Add-Line "Name: $name | Features (engine version): $feat | Main scene: $main"
$auto = [regex]::Match($pg, '(?s)\[autoload\](.*?)(\r?\n\[|\z)').Groups[1].Value.Trim()
Add-Line "Autoloads:`n$(if ($auto) { $auto } else { '(none)' })"
$inp = [regex]::Matches($pg, '(?m)^([a-z_0-9]+)=\{\s*$') | ForEach-Object { $_.Groups[1].Value }
Add-Line "Input actions: $($inp -join ', ')"

# --- godot executable ---
$godot = $null
foreach ($n in "godot","godot4","Godot","Godot_v4*") { $c = Get-Command $n -ErrorAction SilentlyContinue | Select-Object -First 1; if ($c) { $godot = $c.Source; break } }
if (-not $godot) { $godot = Get-ChildItem -Path "$env:USERPROFILE\Downloads","$env:USERPROFILE\Desktop","C:\Godot","C:\Program Files\Godot","$env:LOCALAPPDATA" -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'console' -or $true } | Select-Object -First 1 -ExpandProperty FullName }
if ($godot) { $ver = & $godot --version 2>$null; Add-Line "Godot executable: $godot (version $ver)" } else { Add-Line "Godot executable: NOT FOUND (AI will ask for the path once)" }

# --- git ---
if (Test-Path ".git") { Add-Line "Git: repo present, branch $(git rev-parse --abbrev-ref HEAD 2>$null), changes: $((git status --short 2>$null | Measure-Object).Count)" } else { Add-Line "Git: NOT a repository" }

# --- inventory ---
$files = Get-ChildItem -Recurse -File | Where-Object { $_.FullName -notmatch $skip }
Add-Line "`n## File counts by type"
$files | Group-Object { $_.Extension.ToLower() } | Sort-Object Count -Descending | Select-Object -First 15 | ForEach-Object { Add-Line "- $($_.Name): $($_.Count)" }

Add-Line "`n## Scenes (.tscn)"
$files | Where-Object Extension -eq ".tscn" | ForEach-Object { Add-Line "- $(Resolve-Path -Relative $_.FullName) ($([math]::Round($_.Length/1KB,1)) KB)" }

Add-Line "`n## Scripts (.gd): path | lines | extends | class_name | functions (max 20)"
$gd = $files | Where-Object Extension -eq ".gd"
foreach ($f in $gd) {
  $txt = Get-Content $f.FullName
  $ext = ($txt | Select-String -Pattern '^extends\s+(\S+)' | Select-Object -First 1).Matches.Groups[1].Value
  $cn  = ($txt | Select-String -Pattern '^class_name\s+(\S+)' | Select-Object -First 1).Matches.Groups[1].Value
  $fn  = ($txt | Select-String -Pattern '^\s*func\s+(\w+)' | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 20) -join ", "
  Add-Line "- $(Resolve-Path -Relative $f.FullName) | $($txt.Count) | $ext | $cn | $fn"
}

Add-Line "`n## Resources (.tres/.res/.json) and asset folders"
$files | Where-Object { $_.Extension -in ".tres",".res",".json" } | Select-Object -First 40 | ForEach-Object { Add-Line "- $(Resolve-Path -Relative $_.FullName)" }
$imgs = $files | Where-Object { $_.Extension -in ".png",".webp",".jpg" }
Add-Line "Images: $($imgs.Count) total. Top folders:"
$imgs | Group-Object { Split-Path (Resolve-Path -Relative $_.FullName) -Parent } | Sort-Object Count -Descending | Select-Object -First 12 | ForEach-Object { Add-Line "- $($_.Name): $($_.Count)" }

# --- headless parse check ---
if ($godot) {
  Add-Line "`n## Headless load check (godot --headless --quit)"
  $res = & $godot --headless --path $ProjectPath --quit 2>&1 | Select-Object -First 25
  Add-Line ('```' + "`n" + ($res -join "`n") + "`n" + '```')
}

New-Item -ItemType Directory -Force -Path "docs\ai-context" | Out-Null
$out | Set-Content "docs\ai-context\AUDIT_T001.md" -Encoding UTF8
Write-Host "Audit written: docs\ai-context\AUDIT_T001.md ($([math]::Round((Get-Item 'docs\ai-context\AUDIT_T001.md').Length/1KB,1)) KB)" -ForegroundColor Green

# --- optional safe commit ---
if ($Commit) {
  if (-not (Test-Path ".git")) { git init | Out-Null }
  if (-not (Test-Path ".gitignore")) { ".godot/`n*.translation`n.import/`nexport_presets.cfg`n*.tmp" | Set-Content ".gitignore" -Encoding UTF8 }
  git add -A; git commit -m "T-001 baseline checkpoint before AI work" | Out-Null
  Write-Host "Baseline commit done." -ForegroundColor Green
}
