# Root wrapper: R construction -> Stata estimation (WELCOM) -> R reporting -> manuscript rendering.
#
# Clean run from a fresh session (PowerShell, any working directory):
#   powershell -ExecutionPolicy Bypass -File run_pipeline.ps1 -Stage all -RunId 20261117a
#
# Individual stages (comma-separated list allowed, run in the order given):
#   construct   Rscript code/R/00_run.R construct       inputs -> analysis-ready files, checks, Tables 1-2
#   check       Stata 00_master.do check                matrix-orientation check of duvm on simulated data
#   point       Stata 00_master.do point                one WELCOM duvm call per model
#   bootstrap   Stata 00_master.do boot (parallel)      external cluster bootstrap; resumable
#   inference   Stata 00_master.do inference            SEs, CIs, covariance matrices
#   report      Rscript code/R/00_run.R report          Tables 3-6, figures, completeness check, manuscript bundle
#   manuscript  Rscript code/R/00_run.R manuscript      renders manuscript/manuscript.Rmd to PDF
#
# Executables come from config/local.yml (git-ignored; copy config/local.example.yml).
# The script stops at the first failing stage. Stata's batch mode returns no exit code, so each Stata
# stage must leave a marker file output/logs/<run_id>/stata_<stage>.ok.

param(
  [string]$Stage = "all",
  [string]$RunId = "",
  [int]$Workers = 0
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$rootFwd = $root -replace '\\', '/'

function Get-ConfigValue([string]$file, [string]$key, [string]$default) {
  if (Test-Path $file) {
    $m = Select-String -Path $file -Pattern ("^\s*" + $key + "\s*:\s*(.+?)\s*(#.*)?$") | Select-Object -First 1
    if ($m) { return $m.Matches[0].Groups[1].Value.Trim().Trim('"') }
  }
  return $default
}
$local   = Join-Path $root "config\local.yml"
$config  = Join-Path $root "config\config.yml"
$rscript = Get-ConfigValue $local "rscript_exe" "Rscript.exe"
$stata   = Get-ConfigValue $local "stata_exe" "StataMP-64.exe"
if ($Workers -le 0) { $Workers = [int](Get-ConfigValue $local "parallel_workers" (Get-ConfigValue $config "parallel_workers" "4")) }
if (-not $RunId) { $RunId = Get-Date -Format "yyyyMMdd-HHmm" }
$logDir = Join-Path $root "output\logs\$RunId"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$env:RUN_ID = $RunId

function Write-Step([string]$msg) { Write-Output ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg) }

function Invoke-RStage([string]$name) {
  Write-Step "R stage '$name' (run $RunId)"
  & $rscript "$rootFwd/code/R/00_run.R" $name "--run-id=$RunId"
  if ($LASTEXITCODE -ne 0) { throw "R stage '$name' failed; see $logDir\r_$name.log" }
}

function Start-StataStage([string]$name, [string]$worker = "", [string]$nworkers = "") {
  $tag = if ($name -eq "boot" -and $worker) { "boot_w$worker" } else { $name }
  $ok = Join-Path $logDir "stata_$tag.ok"
  if (Test-Path $ok) { Remove-Item $ok -Force }
  $work = Join-Path $root "data\processed\stata_work\$RunId\launch_$tag"
  New-Item -ItemType Directory -Force -Path $work | Out-Null
  $argList = @("/e", "do", ('"' + "$rootFwd/code/stata/00_master.do" + '"'), ('"' + $rootFwd + '"'), $RunId, $name)
  if ($worker) { $argList += @($worker, $nworkers) }
  $p = Start-Process -FilePath $stata -WorkingDirectory $work -ArgumentList $argList -PassThru -WindowStyle Hidden
  return [pscustomobject]@{ Process = $p; Tag = $tag; Ok = $ok }
}

function Wait-StataStage($jobs) {
  foreach ($j in $jobs) { $j.Process.WaitForExit() }
  $failed = @($jobs | Where-Object { -not (Test-Path $_.Ok) })
  if ($failed.Count -gt 0) {
    throw ("Stata stage(s) did not finish: " + (($failed | ForEach-Object { $_.Tag }) -join ", ") + "; see $logDir\stata_<stage>.log")
  }
}

$stages = if ($Stage -eq "all") { @("construct", "check", "point", "bootstrap", "inference", "report", "manuscript") } else { $Stage -split "," }
Write-Step "Run $RunId | stages: $($stages -join ' -> ') | bootstrap workers: $Workers"
foreach ($s in $stages) {
  switch ($s.Trim()) {
    "construct"  { Invoke-RStage "construct" }
    "check"      { Write-Step "Stata: WELCOM matrix-orientation check on simulated data"; Wait-StataStage @(Start-StataStage "check") }
    "point"      { Write-Step "Stata: WELCOM point estimates"; Wait-StataStage @(Start-StataStage "point") }
    "bootstrap"  {
      Write-Step "Stata: external cluster bootstrap with $Workers workers (resumable)"
      $jobs = 1..$Workers | ForEach-Object { Start-StataStage "boot" "$_" "$Workers" }
      Wait-StataStage $jobs
    }
    "inference"  { Write-Step "Stata: inference"; Wait-StataStage @(Start-StataStage "inference") }
    "report"     { Invoke-RStage "report" }
    "manuscript" { Invoke-RStage "manuscript" }
    default      { throw "Unknown stage '$s'" }
  }
}
Write-Step "Done: run $RunId"
