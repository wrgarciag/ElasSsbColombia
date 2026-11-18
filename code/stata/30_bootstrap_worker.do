* 30_bootstrap_worker.do -- external cluster bootstrap that WRAPS duvm (duvm is called unchanged).
*
* Why an external bootstrap: duvm's boot() resamples cluster-level residual means with the household-level
* first stage held fixed, reports the standard error of the bootstrap MEAN, mis-indexes the cells of its
* standard-error table and gives no valid standard error for expenditure elasticities
* (docs/welcom_method.md, section 7). Here each replication redraws whole price clusters of households
* (within region cells) and reruns the complete duvm estimation, so first-stage uncertainty is included
* and the full joint distribution of all elasticities is available.
*
* Design
*  - replication r uses seed SEED_BOOT + r for EVERY model, so models estimated on the same households
*    (M1-M5, S1-S3, S6) share their resamples and their differences can be bootstrapped pairwise;
*  - worker k of W handles replications r with mod(r-1, W) == k-1; one file per replication, so the stage
*    is resumable and all models advance together;
*  - failed replications are recorded (stat == "rc", value = return code), never silently dropped.
*
* Arguments: worker number, number of workers.

args worker nworkers
if "`worker'" == "" local worker 1
if "`nworkers'" == "" local nworkers 1

elas_load_models
capture mkdir "$WORK_DIR/w`worker'"
quietly cd "$WORK_DIR/w`worker'"
capture set processors $STATA_PROCESSORS

* Schedule (so that every table becomes reportable as early as possible):
*   pass 1  main and tercile models ("final"), replications 1 .. BOOT_FIRST_PASS      -> rep_<r>.dta
*   pass 2  supplementary sensitivity models ("sens"), replications 1 .. BOOT_SENS     -> srep_<r>.dta
*   pass 3  main and tercile models, replications BOOT_FIRST_PASS+1 .. BOOT_FINAL      -> rep_<r>.dta
local p1 = min($BOOT_FIRST_PASS, $BOOT_FINAL)
forvalues pass = 1/3 {
    if `pass' == 1 {
        local cls "final"
        local lo 1
        local hi `p1'
        local pre "rep"
    }
    if `pass' == 2 {
        local cls "sens"
        local lo 1
        local hi $BOOT_SENS
        local pre "srep"
    }
    if `pass' == 3 {
        local cls "final"
        local lo = `p1' + 1
        local hi $BOOT_FINAL
        local pre "rep"
    }
    if `lo' > `hi' continue
    forvalues r = `lo'/`hi' {
        if mod(`r' - 1, `nworkers') != `worker' - 1 continue
        local rr : display %04.0f `r'
        capture confirm file "$BOOT_DIR/`pre'_`rr'.dta"
        if !_rc continue

        tempname bh
        postfile `bh' str20 model_id int rep str20 stat str10 row str10 col double value ///
            using "$WORK_DIR/w`worker'/rep_tmp.dta", replace
        forvalues i = 1/$N_MODELS {
            frame models: local bc = bootclass[`i']
            if "`bc'" != "`cls'" continue
            quietly elas_prepare `i'
            set seed `= $SEED_BOOT + `r''
            bsample, strata($M_strata) cluster($M_cluster) idcluster(bcl)
            capture quietly elas_duvm bcl 0
            local rc = _rc
            post `bh' ("$M_model_id") (`r') ("rc") ("") ("") (`rc')
            if !`rc' elas_post `bh' `r'
        }
        postclose `bh'
        copy "$WORK_DIR/w`worker'/rep_tmp.dta" "$BOOT_DIR/`pre'_`rr'.dta", replace
        display as text "worker `worker': pass `pass' replication `r' done at `c(current_time)'"
    }
}
quietly cd "$ROOT"
