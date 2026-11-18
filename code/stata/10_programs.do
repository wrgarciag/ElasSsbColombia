* 10_programs.do -- thin wrappers around WELCOM's duvm. WELCOM itself is never modified.
*
* elas_load_models   reads config/models.csv into frame `models'
* elas_prepare i     loads the estimation file of model i, applies its sample, builds the call weight
* elas_validate      checks the WELCOM input contract on the data in memory
* elas_duvm c b      calls duvm with cluster variable c and boot(b)
* elas_post ...      posts the matrices left by duvm in long form

capture program drop elas_load_models
program define elas_load_models
    capture frame drop models
    frame create models
    frame models {
        import delimited using "$ROOT/config/models.csv", varnames(1) stringcols(_all) bindquote(strict) clear
        count
        global N_MODELS = r(N)
    }
end

capture program drop elas_goods
program define elas_goods, rclass
    * goods with enough unit-value support in this model's sample (written by R: welcom_contract_models.csv)
    args model
    capture frame drop _contract
    frame create _contract
    frame _contract {
        import delimited using "$EST_DIR/welcom_contract_models.csv", varnames(1) stringcols(_all) clear
        keep if model_id == "`model'" & estimable == "TRUE"
        levelsof good, local(est) clean
    }
    frame drop _contract
    local goods
    foreach g of global GOOD_ORDER {
        if `: list g in est' local goods `goods' `g'
    }
    return local goods `goods'
end

capture program drop elas_prepare
program define elas_prepare
    args i
    foreach v in model_id spec market dataset sample csb weight region cluster bootclass role {
        frame models: local val = `v'[`i']
        global M_`v' `"`val'"'
    }
    use "$EST_DIR/$M_dataset.dta", clear
    keep if $M_sample
    elas_goods $M_model_id
    global M_goods `r(goods)'
    global M_ngoods : word count $M_goods

    local keepv hhid $M_cluster exptot hhsize $CTRL_CAT $CTRL_CON quarter_id regctl
    foreach g of global M_goods {
        local keepv `keepv' w`g' luv`g'
    }
    if "$M_weight" != "none" local keepv `keepv' $M_weight
    local keepv : list uniq keepv
    keep `keepv'

    * Weight passed to hweight().
    *  - wgt_market / wgt_segment are constant within the price cluster. They are rescaled here so that
    *    their harmonic mean across clusters is one: duvm measures the number of households per cluster as a
    *    SUM OF WEIGHTS (clustit/mkns), and this scaling keeps those "counts" on the scale of real household
    *    counts, which is what Deaton's measurement-error correction needs. aweights are scale-invariant
    *    everywhere else in duvm. See docs/welcom_method.md, section 5.
    *  - wgt_hh_raw is passed unchanged (legacy calling convention; sensitivity S6 only).
    global M_wopt
    capture drop wcall
    if "$M_weight" == "wgt_hh_raw" {
        global M_wopt hweight(wgt_hh_raw)
    }
    else if "$M_weight" != "none" {
        tempvar tag inv
        bysort $M_cluster (hhid): gen byte `tag' = _n == 1
        gen double `inv' = 1 / $M_weight
        quietly summarize `inv' if `tag', meanonly
        gen double wcall = $M_weight * r(mean)
        global M_wopt hweight(wcall)
    }
    global M_ropt
    if "$M_region" != "none" global M_ropt region($M_region)
    global M_strata = cond("$M_region" == "none", "regctl", "$M_region")
    sort $M_cluster hhid
end

capture program drop elas_validate
program define elas_validate
    * WELCOM input contract (duvm.sthlp / duvm.ado): w<g> non-missing in [0,1]; luv<g> missing or finite and only
    * for households with w<g> > 0; positive expenditure and household size; numeric cluster; region and
    * subround constant within cluster; positive weight.
    isid hhid
    foreach g of global M_goods {
        confirm numeric variable w`g' luv`g'
        assert !missing(w`g') & w`g' >= 0 & w`g' <= 1
        assert missing(luv`g') | w`g' > 0
        quietly count if !missing(luv`g')
        if r(N) < 30 {
            display as error "contract: fewer than 30 unit values for `g'"
            exit 459
        }
    }
    assert exptot > 0 & !missing(exptot)
    assert hhsize >= 1 & !missing(hhsize)
    foreach v in $CTRL_CAT $CTRL_CON quarter_id {
        assert !missing(`v')
    }
    confirm numeric variable $M_cluster
    foreach v in quarter_id $M_strata {
        tempvar sdv
        quietly bysort $M_cluster: egen double `sdv' = sd(`v')
        assert `sdv' == 0 | missing(`sdv')
        drop `sdv'
    }
    if "$M_weight" != "none" & "$M_weight" != "wgt_hh_raw" {
        assert wcall > 0 & !missing(wcall)
        tempvar sdw
        quietly bysort $M_cluster: egen double `sdw' = sd(wcall)
        assert `sdw' < 1e-8 | missing(`sdw')
    }
    sort $M_cluster hhid
end

capture program drop elas_duvm
program define elas_duvm
    args clusvar nboot
    duvm $M_goods, hhsize(hhsize) expend(exptot) $M_wopt cluster(`clusvar') $M_ropt subround(quarter_id) ///
        indcat($CTRL_CAT) indcon($CTRL_CON) csb($M_csb) boot(`nboot') dregres(0) dec(4)
end

* Post the results duvm leaves behind. e(elprice) = quality-corrected, symmetry-restricted price elasticities
* (rows: good whose quantity responds; columns: good whose price changes); e(elincome) = expenditure elasticities.
capture program drop elas_post
program define elas_post
    args handle rep
    local K = $M_ngoods
    tempname EP EI CN BN Q
    matrix `EP' = e(elprice)
    matrix `EI' = e(elincome)
    matrix `CN' = C_NS_ep
    matrix `BN' = B_NS_ep
    matrix `Q'  = QUAL_SY_E
    forvalues a = 1/`K' {
        local ga : word `a' of $M_goods
        post `handle' ("$M_model_id") (`rep') ("expenditure") ("`ga'") ("") (`EI'[1, `a'])
        post `handle' ("$M_model_id") (`rep') ("quality") ("`ga'") ("") (`Q'[1, `a'])
        forvalues b = 1/`K' {
            local gb : word `b' of $M_goods
            post `handle' ("$M_model_id") (`rep') ("price") ("`ga'") ("`gb'") (`EP'[`a', `b'])
            post `handle' ("$M_model_id") (`rep') ("price_nosym") ("`ga'") ("`gb'") (`CN'[`a', `b'])
            if `rep' == 0 post `handle' ("$M_model_id") (`rep') ("price_noquality") ("`ga'") ("`gb'") (`BN'[`a', `b'])
        }
    }
end
