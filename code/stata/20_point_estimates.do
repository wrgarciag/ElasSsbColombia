* 20_point_estimates.do -- one WELCOM duvm call per model in config/models.csv.
* Exports: point estimates (long), model metadata, per-good support, estimation-sample identifiers,
*          and, for the primary models, WELCOM's own bootstrap output for reference.

elas_load_models
quietly cd "$WORK_DIR"

tempname ph mh gh nh
postfile `ph' str20 model_id int rep str20 stat str10 row str10 col double value using "$WORK_DIR/point_long.dta", replace
postfile `mh' str20 model_id str8 spec str10 market str40 dataset str80 sample int csb str20 weight str12 region ///
    str20 cluster str8 bootclass str12 role double n_households double n_clusters double harmonic_n_cluster ///
    double seconds int rc str244 goods str244 command using "$WORK_DIR/model_meta.dta", replace
postfile `gh' str20 model_id str10 good double avg_share double zero_share double n_unit_values double clusters_with_uv ///
    double harmonic_n_uv double welcom_n0 double welcom_n1 double ome double sig double b0 double b1 ///
    using "$WORK_DIR/model_goods.dta", replace
postfile `nh' str20 model_id str10 row str10 col str30 stat double value using "$WORK_DIR/welcom_native.dta", replace

forvalues i = 1/$N_MODELS {
    elas_prepare `i'
    display as text _n "=== `i'/$N_MODELS  $M_model_id : $M_goods | sample: $M_sample | csb($M_csb) weight($M_weight) region($M_region) cluster($M_cluster)"
    elas_validate
    quietly count
    local N = r(N)
    tempvar tag invn
    bysort $M_cluster (hhid): gen byte `tag' = _n == 1
    bysort $M_cluster: gen double `invn' = 1 / _N
    quietly count if `tag'
    local NC = r(N)
    quietly summarize `invn' if `tag', meanonly
    local HN = 1 / r(mean)
    local K = $M_ngoods
    foreach g of global M_goods {
        quietly summarize w`g', meanonly
        quietly count if w`g' == 0
        local zs_`g' = r(N) / `N'
        quietly count if !missing(luv`g')
        local nuv_`g' = r(N)
        tempvar nb ib
        quietly bysort $M_cluster: egen double `nb' = total(!missing(luv`g'))
        quietly gen double `ib' = 1 / `nb' if `nb' > 0
        quietly count if `tag' & `nb' > 0
        local cuv_`g' = r(N)
        quietly summarize `ib' if `tag', meanonly
        local huv_`g' = 1 / r(mean)
        drop `nb' `ib'
    }
    drop `tag' `invn'
    preserve
    keep hhid
    quietly compress
    quietly save "$SAMP_DIR/$M_model_id.dta", replace
    restore

    local nb = cond("$M_spec" == "M1", $WELCOM_NATIVE_BOOT, 0)
    set seed $SEED_WELCOM_NATIVE
    timer clear 1
    timer on 1
    capture noisily quietly elas_duvm $M_cluster `nb'
    local rc = _rc
    timer off 1
    quietly timer list 1
    local secs = r(t1)
    local cmd "duvm $M_goods, hhsize(hhsize) expend(exptot) $M_wopt cluster($M_cluster) $M_ropt subround(quarter_id) indcat($CTRL_CAT) indcon($CTRL_CON) csb($M_csb)"
    post `mh' ("$M_model_id") ("$M_spec") ("$M_market") ("$M_dataset") ("$M_sample") ($M_csb) ("$M_weight") ("$M_region") ///
        ("$M_cluster") ("$M_bootclass") ("$M_role") (`N') (`NC') (`HN') (`secs') (`rc') ("$M_goods") ("`cmd'")
    if `rc' {
        display as error "duvm failed for $M_model_id (rc=`rc')"
        continue
    }
    elas_post `ph' 0
    forvalues a = 1/`K' {
        local g : word `a' of $M_goods
        post `gh' ("$M_model_id") ("`g'") (wbar[`a', 1]) (`zs_`g'') (`nuv_`g'') (`cuv_`g'') (`huv_`g'') ///
            (n0[`a', 1]) (n1[`a', 1]) (ome[`a', 1]) (sig[`a', 1]) (b0[`a', 1]) (b1[`a', 1])
    }
    display as text "    N=`N' clusters=`NC' seconds=" %5.1f `secs'
    matrix list e(elprice), format(%8.3f)
    matrix list e(elincome), format(%8.3f)

    * WELCOM's own bootstrap (reference only; see docs/welcom_method.md, section 7).
    if `nb' > 0 {
        local K1 = `K' + 1
        forvalues a = 1/`K' {
            local ga : word `a' of $M_goods
            post `nh' ("$M_model_id") ("`ga'") ("") ("welcom_table08_as_printed") (MSTEINC[1, `a'])
            forvalues b = 1/`K' {
                local gb : word `b' of $M_goods
                post `nh' ("$M_model_id") ("`ga'") ("`gb'") ("welcom_table09_as_printed") (MSTE[`a', `b'])
            }
        }
        preserve
        use "$WORK_DIR/bootall.dta", clear
        quietly drop if reps == 0
        forvalues a = 1/`K' {
            local ga : word `a' of $M_goods
            forvalues b = 1/`K' {
                local gb : word `b' of $M_goods
                local pos = (`b' - 1) * `K1' + `a'
                quietly summarize e`pos'
                post `nh' ("$M_model_id") ("`ga'") ("`gb'") ("welcom_boot_sd_correct_cell") (r(sd))
                post `nh' ("$M_model_id") ("`ga'") ("`gb'") ("welcom_boot_reps") (r(N))
            }
        }
        restore
    }
}
postclose `ph'
postclose `mh'
postclose `gh'
postclose `nh'

foreach f in point_long model_meta model_goods welcom_native {
    use "$WORK_DIR/`f'.dta", clear
    if "`f'" == "model_meta" {
        gen str20 welcom_version = "$WELCOM_VERSION"
        gen str40 stata_version = "`c(stata_version)' `c(flavor)' (born `c(born_date)')"
        gen str20 run_id = "$RUN_ID"
    }
    export delimited using "$OUT_EST/`f'.csv", replace
}
quietly cd "$ROOT"
