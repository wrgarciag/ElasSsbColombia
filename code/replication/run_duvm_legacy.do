* Legacy replication, Stata side.
*
* Runs the four UNMODIFIED legacy duvm do-files in code/legacy/ on the files written by
* code/replication/run_legacy_r.R. This driver only sets $path, a seed, the working directory and the logs.
*
* Usage (batch, from PowerShell or cmd; Git Bash rewrites /e):
*   StataMP-64.exe /e do "<root>/code/replication/run_duvm_legacy.do" "<root>"
* or interactively from the repository root:
*   do code/replication/run_duvm_legacy.do
*
* Logs: output/replication/legacy_run/duvm_<model>.log
* duvm writes bootall.dta and tempclus.dta to the working directory, so it runs in data/interim/legacy_run/stata_work/.
* Expected (2026-11-17): total and hogar run all three models; total_codi and hogar_codi stop with
* "variable Gasto_Wine not found" r(111) (audit blocker B8).

version 17
args root
if `"`root'"' == "" local root = c(pwd)
local root = subinstr(`"`root'"', "\", "/", .)
confirm file "`root'/code/legacy/SSBElasticityPaperRevised_total_duvm.do"

global path "`root'/data/interim/legacy_run"
confirm file "$path/DataEstimates5.dta"
confirm file "$path/UnitValuePrices_Total.dta"

local logdir "`root'/output/replication/legacy_run"
capture mkdir "`root'/output/replication"
capture mkdir "`logdir'"
capture mkdir "$path/stata_work"
set more off

foreach m in total hogar total_codi hogar_codi {
    clear all
    set seed 20261117
    quietly cd "$path/stata_work"
    log using "`logdir'/duvm_`m'.log", text replace
    which duvm
    capture noisily do "`root'/code/legacy/SSBElasticityPaperRevised_`m'_duvm.do"
    local rc_`m' = _rc
    capture log close
}

quietly cd "`root'"
foreach m in total hogar total_codi hogar_codi {
    display as text "duvm_`m': rc=`rc_`m''"
}
