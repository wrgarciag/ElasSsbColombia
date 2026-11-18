* 00_master.do -- Stata side of the pipeline: WELCOM (duvm) estimation and inference only.
* Stata reads the analysis-ready files written by R, validates the WELCOM input contract, runs duvm and
* exports machine-readable results. No survey merges, classification or unit conversion happen here.
*
* Usage (batch; launch from PowerShell or cmd, not Git Bash):
*   StataMP-64.exe /e do "<root>/code/stata/00_master.do" "<root>" <run_id> <stage> [worker] [nworkers]
* Stages
*   check      90_orientation_check.do numerical check of the matrix orientation on simulated data
*   point      20_point_estimates.do   one duvm call per model in config/models.csv
*   boot       30_bootstrap_worker.do  external cluster bootstrap (worker `worker' of `nworkers'; resumable)
*   inference  40_inference.do         SEs, percentile CIs, covariance matrices, specification differences
*   all        point, boot (single worker), inference
* A marker file output/logs/<run_id>/stata_<stage>[_w<k>].ok is written when the stage finishes without error;
* the root wrapper uses it because Stata's batch mode does not return an exit code.

version 17
clear all
set more off
args root run_id stage worker nworkers
if `"`root'"' == "" local root = c(pwd)
local root = subinstr(`"`root'"', "\", "/", .)
if "`run_id'" == "" local run_id "dev"
if "`stage'" == "" local stage "all"
global ROOT "`root'"
global RUN_ID "`run_id'"
confirm file "$ROOT/code/stata/01_setup.do"

capture mkdir "$ROOT/output/logs"
capture mkdir "$ROOT/output/logs/$RUN_ID"
local tag "`stage'"
if "`stage'" == "boot" & "`worker'" != "" local tag "boot_w`worker'"
capture erase "$ROOT/output/logs/$RUN_ID/stata_`tag'.ok"
capture log close _all
log using "$ROOT/output/logs/$RUN_ID/stata_`tag'.log", text replace name(main)

do "$ROOT/code/stata/01_setup.do"
display "Run $RUN_ID | stage `stage' | Stata `c(stata_version)' `c(flavor)' | WELCOM $WELCOM_VERSION | processors `c(processors)'"
which duvm

if inlist("`stage'", "check", "all")     do "$ROOT/code/stata/90_orientation_check.do"
if inlist("`stage'", "point", "all")     do "$ROOT/code/stata/20_point_estimates.do"
if "`stage'" == "boot"                   do "$ROOT/code/stata/30_bootstrap_worker.do" `worker' `nworkers'
if "`stage'" == "all"                    do "$ROOT/code/stata/30_bootstrap_worker.do" 1 1
if inlist("`stage'", "inference", "all") do "$ROOT/code/stata/40_inference.do"

tempname fh
file open `fh' using "$ROOT/output/logs/$RUN_ID/stata_`tag'.ok", write replace
file write `fh' "`stage' finished `c(current_date)' `c(current_time)'" _n
file close `fh'
log close main
