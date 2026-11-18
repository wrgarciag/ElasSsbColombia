* 40_inference.do -- inference from the external cluster bootstrap.
* Inputs : $OUT_EST/point_long.csv (stage 20), $BOOT_DIR/rep_*.dta (stage 30)
* Outputs: $OUT_EST/estimates_long.csv      point estimate, bootstrap SE, percentile CI, p-value, replications
*          $OUT_EST/covariance_long.csv     joint bootstrap covariance of all price and expenditure elasticities, by model
*          $OUT_EST/bootstrap_status.csv    replications attempted / failed, by model
*          $OUT_EST/spec_differences.csv    differences against the primary model of the same market
* Uncertainty captured: sampling of price clusters (households resampled in whole clusters within region
* cells), including every first-stage regression. Not captured: uncertainty in the data-construction rules
* fixed in R (classification, unit conversion, outlier flags, income terciles) and the survey's own
* stratification and finite-population structure.

local files : dir "$BOOT_DIR" files "*rep_*.dta"
local nfiles : word count `files'
if `nfiles' == 0 {
    display as error "no bootstrap replications found in $BOOT_DIR"
    exit 601
}
clear
foreach f of local files {
    append using "$BOOT_DIR/`f'"
}
save "$WORK_DIR/boot_long.dta", replace

* ---- status ----
preserve
keep if stat == "rc"
gen byte failed = value != 0
collapse (count) attempted = value (sum) failed, by(model_id)
gen completed = attempted - failed
export delimited using "$OUT_EST/bootstrap_status.csv", replace
restore
drop if stat == "rc"

* ---- point estimates ----
preserve
import delimited using "$OUT_EST/point_long.csv", varnames(1) stringcols(1 3 4 5) clear
rename value estimate
drop rep
tempfile point
save `point'
restore

* ---- SE and percentile CI ----
local lo = 100 * (1 - $CI_LEVEL) / 2
local hi = 100 - `lo'
preserve
bysort model_id stat row col: egen double ci_lo = pctile(value), p(`lo')
bysort model_id stat row col: egen double ci_hi = pctile(value), p(`hi')
collapse (sd) se = value (mean) boot_mean = value (count) reps = value (first) ci_lo ci_hi, by(model_id stat row col)
merge 1:1 model_id stat row col using `point', nogenerate
gen double z = estimate / se
gen double p_normal = 2 * normal(-abs(z))
gen byte ci_excludes_zero = (ci_lo > 0 | ci_hi < 0) if !missing(ci_lo)
gen double ci_level = $CI_LEVEL
order model_id stat row col estimate se ci_lo ci_hi p_normal ci_excludes_zero reps boot_mean
sort model_id stat row col
export delimited using "$OUT_EST/estimates_long.csv", replace
restore

* ---- joint covariance by model (price and expenditure elasticities) ----
preserve
keep if inlist(stat, "price", "expenditure")
gen str40 param = stat + "__" + row + cond(col == "", "", "__" + col)
keep model_id rep param value
tempfile cv
tempname ch
postfile `ch' str20 model_id str40 param1 str40 param2 double cov int reps using `cv', replace
levelsof model_id, local(models) clean
foreach m of local models {
    quietly {
        frame put if model_id == "`m'", into(_one)
        frame _one {
            drop model_id
            levelsof param, local(pars) clean
            local np : word count `pars'
            encode param, gen(pid)
            drop param
            reshape wide value, i(rep) j(pid)
            count
            local nr = r(N)
            if `nr' > 2 {
                correlate value*, covariance
                matrix V = r(C)
                forvalues a = 1/`np' {
                    forvalues b = 1/`np' {
                        local pa : word `a' of `pars'
                        local pb : word `b' of `pars'
                        post `ch' ("`m'") ("`pa'") ("`pb'") (V[`a', `b']) (`nr')
                    }
                }
            }
        }
        frame drop _one
    }
}
postclose `ch'
use `cv', clear
export delimited using "$OUT_EST/covariance_long.csv", replace
restore

* ---- differences against the primary model (M1) of the same market ----
preserve
keep if inlist(stat, "price", "expenditure") & (stat == "expenditure" | row == col)
gen str10 market = substr(model_id, strpos(model_id, "_") + 1, .)
gen str8 spec = substr(model_id, 1, strpos(model_id, "_") - 1)
tempfile all
save `all'
keep if spec == "M1"
rename value value_m1
keep market rep stat row col value_m1
tempfile m1
save `m1'
use `all', clear
drop if spec == "M1"
merge m:1 market rep stat row col using `m1', keep(match) nogenerate
gen double d = value - value_m1
bysort model_id stat row col: egen double diff_ci_lo = pctile(d), p(`lo')
bysort model_id stat row col: egen double diff_ci_hi = pctile(d), p(`hi')
collapse (sd) diff_se = d (count) reps = d (first) diff_ci_lo diff_ci_hi spec market, by(model_id stat row col)
merge 1:1 model_id stat row col using `point', keep(match) nogenerate
rename estimate estimate_model
gen str20 m1_id = "M1_" + market
tempfile dd
save `dd'
use `point', clear
rename model_id m1_id
rename estimate estimate_m1
merge 1:m m1_id stat row col using `dd', keep(match) nogenerate
gen double difference = estimate_model - estimate_m1
* resamples are shared (paired) only for models estimated on the same households and clusters as M1
gen byte paired_resamples = inlist(spec, "M2", "M3", "M4", "M5", "S1", "S2", "S3", "S6", "S7")
order model_id spec market stat row col estimate_m1 estimate_model difference diff_se diff_ci_lo diff_ci_hi paired_resamples reps
sort market spec stat row
export delimited using "$OUT_EST/spec_differences.csv", replace
restore
