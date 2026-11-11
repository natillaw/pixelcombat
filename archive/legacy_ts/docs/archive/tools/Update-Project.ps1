<#
 Finds your real Tactical Summoners folder and safely copies the Drop B changes into it.

 STEP 1 (only looks, changes nothing):
   powershell -ExecutionPolicy Bypass -File tools\Update-Project.ps1
   (optional: -Roots "D:\Games","C:\Users\you\Documents")
 STEP 2 (apply to the folder it recommended):
   powershell -ExecutionPolicy Bypass -File tools\Update-Project.ps1 -Apply "C:\path\to\your\project"

 How it picks: it compares every project.godot folder it finds with the Drop A you gave me
 (exact file hashes). The folder that matches the most, and was edited most recently, is the one.
 Apply makes a ZIP backup first, then: copies new files, upgrades files you never touched,
 and NEVER overwrites a file you changed: the Drop B version is saved next to it as <file>.dropB
#>
param([string[]]$Roots = @(), [string]$Apply = "")
$ErrorActionPreference = "Continue"
$here = Split-Path $PSScriptRoot -Parent                      # the extracted Drop B folder
$man = Get-Content (Join-Path $PSScriptRoot "manifest.json") -Raw | ConvertFrom-Json
$A = @{}; $man.dropA.PSObject.Properties | ForEach-Object { $A[$_.Name] = $_.Value }
$B = @{}; $man.dropB.PSObject.Properties | ForEach-Object { $B[$_.Name] = $_.Value }

function Get-NormHash([string]$path) {
  $t = [IO.File]::ReadAllText($path) -replace "`r`n", "`n"
  $sha = [Security.Cryptography.SHA256]::Create()
  ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($t)) | ForEach-Object { $_.ToString("x2") }) -join ""
}
function Join-Rel([string]$root, [string]$rel) { Join-Path $root ($rel -replace "/", [IO.Path]::DirectorySeparatorChar) }

# ---------------- APPLY ----------------
if ($Apply) {
  $target = (Resolve-Path $Apply).Path
  if (-not (Test-Path (Join-Path $target "project.godot"))) { Write-Host "No project.godot in $target" -ForegroundColor Red; exit 1 }
  if ((Resolve-Path $here).Path -eq $target) { Write-Host "Target is the Drop B folder itself. Pick YOUR project folder." -ForegroundColor Red; exit 1 }

  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $bak = Join-Path (Split-Path $target -Parent) ("backup_before_dropB_" + $stamp + ".zip")
  Write-Host "Backing up to $bak ..."
  $items = Get-ChildItem $target -Force | Where-Object { $_.Name -ne ".godot" } | ForEach-Object { $_.FullName }
  Compress-Archive -Path $items -DestinationPath $bak -Force
  Write-Host "Backup done." -ForegroundColor Green

  $copied = 0; $upgraded = 0; $same = 0; $conflicts = @()
  foreach ($rel in $B.Keys | Sort-Object) {
    $src = Join-Rel $here $rel
    $dst = Join-Rel $target $rel
    if (-not (Test-Path $src)) { continue }
    $dir = Split-Path $dst -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (-not (Test-Path $dst)) { Copy-Item $src $dst; $copied++; continue }
    $h = Get-NormHash $dst
    if ($h -eq $B[$rel]) { $same++; continue }
    if ($A.ContainsKey($rel) -and $h -eq $A[$rel]) { Copy-Item $src $dst -Force; $upgraded++; continue }
    Copy-Item $src ($dst + ".dropB") -Force
    $conflicts += $rel
  }
  # assets and Godot .uid files: only add what is missing, never overwrite
  foreach ($extra in @("assets")) {
    $s = Join-Path $here $extra
    if (Test-Path $s) {
      Get-ChildItem $s -Recurse -File | ForEach-Object {
        $r = $_.FullName.Substring($here.Length).TrimStart('\','/')
        $d = Join-Path $target $r
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path (Split-Path $d -Parent) | Out-Null; Copy-Item $_.FullName $d }
      }
    }
  }
  Get-ChildItem (Join-Path $here "scripts") -Recurse -Filter *.uid | ForEach-Object {
    $r = $_.FullName.Substring($here.Length).TrimStart('\','/')
    $d = Join-Path $target $r
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path (Split-Path $d -Parent) | Out-Null; Copy-Item $_.FullName $d }
  }

  Write-Host "`nNew files copied: $copied   Upgraded (you had not touched them): $upgraded   Already identical: $same" -ForegroundColor Green
  if ($conflicts.Count -gt 0) {
    Write-Host "`nYOU CHANGED these files, so I did NOT overwrite them. Drop B's version is saved next to each as .dropB:" -ForegroundColor Yellow
    $conflicts | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    Write-Host "Tell the AI: 'merge the .dropB files into mine' and give it those pairs."
  } else { Write-Host "No conflicts." -ForegroundColor Green }
  Write-Host "`nNext: open the project in Godot once, then run tools\Run-Tests.ps1"
  Write-Host "Undo: extract $bak over the folder."
  exit 0
}

# ---------------- SCAN ----------------
if ($Roots.Count -eq 0) {
  $Roots = @($env:USERPROFILE, $HOME) | Where-Object { $_ } | Select-Object -Unique
  foreach ($d in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
    if ($d.Root -and $d.Root -notin $Roots -and $d.Root -ne "$env:SystemDrive\") { $Roots += $d.Root }
  }
}
Write-Host "Searching: $($Roots -join ', ')  (a minute at most)"
$found = foreach ($r in $Roots) {
  if (Test-Path $r) { Get-ChildItem $r -Filter project.godot -Recurse -File -Depth 7 -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '[\\/]\.godot[\\/]' -and $_.FullName -notmatch 'AppData|node_modules|\$Recycle' } }
}
$rows = @()
foreach ($f in ($found | Sort-Object FullName -Unique)) {
  $dir = $f.DirectoryName
  if ((Resolve-Path $dir).Path -eq (Resolve-Path $here).Path) { continue }
  $hit = 0
  foreach ($rel in $A.Keys) { $p = Join-Rel $dir $rel; if ((Test-Path $p) -and ((Get-NormHash $p) -eq $A[$rel])) { $hit++ } }
  $gd = Get-ChildItem $dir -Recurse -Filter *.gd -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '[\\/]\.godot[\\/]' }
  $newest = ($gd | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
  $rows += [pscustomobject]@{
    MatchDropA = "{0}/{1}" -f $hit, $A.Count
    Pct        = [math]::Round(100.0 * $hit / $A.Count)
    HasSummons = (Test-Path (Join-Path $dir "scripts"))
    GdFiles    = $gd.Count
    LastEdit   = if ($newest) { $newest.LastWriteTime } else { [datetime]::MinValue }
    Folder     = $dir
  }
}
if ($rows.Count -eq 0) { Write-Host "No Godot projects found. Re-run with -Roots 'D:\where\you\keep\it'" -ForegroundColor Red; exit 1 }
$rows = $rows | Sort-Object @{e='Pct';Descending=$true}, @{e='LastEdit';Descending=$true}
Write-Host ""
$rows | Format-Table MatchDropA, Pct, GdFiles, LastEdit, Folder -AutoSize | Out-String -Width 250 | Write-Host
$best = $rows | Select-Object -First 1
Write-Host "Best guess: $($best.Folder)" -ForegroundColor Green
Write-Host "  ($($best.MatchDropA) files identical to the Drop A you sent me, last edited $($best.LastEdit))"
if ($best.Pct -lt 40) { Write-Host "  Low match: your real folder may have changed a lot since Drop A, or it is somewhere not searched." -ForegroundColor Yellow }
Write-Host "`nIf that is right, run:"
Write-Host "  powershell -ExecutionPolicy Bypass -File tools\Update-Project.ps1 -Apply `"$($best.Folder)`""
