* 01_setup.do -- environment for every Stata stage.
* Expects globals: ROOT (repository root, forward slashes), RUN_ID.
* - pins the ado path to the project-local copy of WELCOM (code/stata/ado); nothing is installed or updated
* - defines output locations
* - reads the seeds and replication counts written by R from config/config.yml (config/stata_params.do)

version 17
set more off
set linesize 200
set type double

confirm file "$ROOT/code/stata/ado/d/duvm.ado"
sysdir set PLUS "$ROOT/code/stata/ado"
sysdir set PERSONAL "$ROOT/code/stata/ado/_unused"
capture adopath - OLDPLACE
capture adopath - SITE

* Parameters exported from config/config.yml and config/local.yml by R (single configuration source).
confirm file "$ROOT/config/stata_params.do"
do "$ROOT/config/stata_params.do"

global EST_DIR   "$ROOT/data/processed/estimation"
global BOOT_DIR  "$ROOT/data/processed/bootstrap/$RUN_ID"
global SAMP_DIR  "$ROOT/data/processed/estimation_samples/$RUN_ID"
* duvm writes tempa.dta / tempclus.dta / bootall.dta to the working directory on every call. A local,
* non-synchronised scratch folder (config/local.yml: stata_scratch_dir) avoids file locks from cloud sync.
global WORK_DIR  "$ROOT/data/processed/stata_work/$RUN_ID"
if "$SCRATCH_DIR" != "" {
    capture mkdir "$SCRATCH_DIR"
    global WORK_DIR "$SCRATCH_DIR/$RUN_ID"
}
global OUT_EST   "$ROOT/output/estimates/$RUN_ID"
global OUT_DIAG  "$ROOT/output/diagnostics/$RUN_ID"
global OUT_LOG   "$ROOT/output/logs/$RUN_ID"
foreach d in "$ROOT/data/processed/bootstrap" "$BOOT_DIR" "$ROOT/data/processed/estimation_samples" "$SAMP_DIR" ///
             "$ROOT/data/processed/stata_work" "$WORK_DIR" "$ROOT/output/estimates" "$OUT_EST" ///
             "$ROOT/output/diagnostics" "$OUT_DIAG" "$ROOT/output/logs" "$OUT_LOG" {
    capture mkdir "`d'"
}

* Controls passed to duvm in every model (the model-specific options come from config/models.csv).
global CTRL_CAT "head_male single children educ"
global CTRL_CON "head_age"
global GOOD_ORDER "sb beer spirits water dairy hot"

do "$ROOT/code/stata/10_programs.do"
