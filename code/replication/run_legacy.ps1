# Runs the legacy replication end to end: R stages, then the Stata duvm do-files.
# Usage (any working directory):  powershell -ExecutionPolicy Bypass -File code\replication\run_legacy.ps1
# Override executables with $env:RSCRIPT_EXE and $env:STATA_EXE.
# Takes about 14 minutes: ~6 for R, ~8 for Stata (100 bootstrap replications per model).

$ErrorActionPreference = "Stop"
$root   = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$logdir = Join-Path $root "output\replication\legacy_run"
New-Item -ItemType Directory -Force -Path $logdir | Out-Null

$rscript = if ($env:RSCRIPT_EXE) { $env:RSCRIPT_EXE } else { "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" }
$stata   = if ($env:STATA_EXE)   { $env:STATA_EXE }   else { "C:\Program Files\Stata17\StataMP-64.exe" }
$rootFwd = $root -replace '\\', '/'

Write-Output "[$(Get-Date -Format HH:mm)] R stages -> $logdir\r_run.log"
$r = Start-Process -FilePath $rscript -NoNewWindow -Wait -PassThru `
       -ArgumentList ('"' + "$rootFwd/code/replication/run_legacy_r.R" + '"'), ('"' + $rootFwd + '"') `
       -RedirectStandardOutput (Join-Path $logdir "r_run.log") -RedirectStandardError (Join-Path $logdir "r_run_messages.log")
if ($r.ExitCode -ne 0) { throw "R stage failed (exit $($r.ExitCode)); see $logdir\r_run.log and stage_results.txt" }

Write-Output "[$(Get-Date -Format HH:mm)] Stata duvm -> $logdir\duvm_*.log"
$s = Start-Process -FilePath $stata -WorkingDirectory $logdir -Wait -PassThru -WindowStyle Hidden `
       -ArgumentList "/e", "do", ('"' + "$rootFwd/code/replication/run_duvm_legacy.do" + '"'), ('"' + $rootFwd + '"')
Select-String -Path (Join-Path $logdir "run_duvm_legacy.log") -Pattern "^duvm_.*rc=" | ForEach-Object { $_.Line }
Write-Output "[$(Get-Date -Format HH:mm)] done (Stata exit $($s.ExitCode))"
