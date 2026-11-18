* 90_orientation_check.do -- numerical check of the orientation of duvm's price-elasticity matrix.
*
* Simulated data with a known asymmetric price response:
*   share of good a:  responds to its own price only           (theta_aa = -0.010, theta_ab = 0)
*   share of good b:  responds to the price of a and its own   (theta_ba = +0.020, theta_bb = -0.010)
* With mean shares of 0.05, the implied elasticities are about
*   e[a,a] = -1.2   e[a,b] = 0     e[b,a] = +0.4   e[b,b] = -1.2
* If rows are the good whose quantity responds and columns the good whose price changes, the matrix
* without the symmetry restriction (C_NS_ep, WELCOM Table 06) must show about +0.4 in cell [b,a] and
* about 0 in cell [a,b]. The script stops with an error otherwise.
*
* Usage: do code/stata/90_orientation_check.do   (after 01_setup.do; called by 00_master.do stage "check")

clear
set seed 20261117
set obs 800
gen long cl = _n
gen double lpa = rnormal(0, 0.25)
gen double lpb = rnormal(0, 0.25)
expand 12
bysort cl: gen int hh = _n
gen double x = exp(rnormal(14, 0.5))
gen int size = 1 + floor(5 * runiform())
gen double wa = 0.05 - 0.010 * lpa + 0.000 * lpb + rnormal(0, 0.004)
gen double wb = 0.05 + 0.020 * lpa - 0.010 * lpb + rnormal(0, 0.004)
replace wa = max(wa, 0.001)
replace wb = max(wb, 0.001)
gen double luva = 7 + lpa + rnormal(0, 0.10)
gen double luvb = 8 + lpb + rnormal(0, 0.10)
gen double z = rnormal()   // duvm needs at least one household control

capture mkdir "$WORK_DIR/check"
quietly cd "$WORK_DIR/check"
quietly duvm a b, hhsize(size) expend(x) cluster(cl) indcon(z) csb(0) boot(0) dregres(0) dec(4)
matrix NS = C_NS_ep[1..2, 1..2]
matrix rownames NS = quantity_a quantity_b
matrix colnames NS = price_a price_b
matrix list NS, format(%9.3f) title("duvm, quality-corrected, no symmetry restriction (C_NS_ep)")
matrix SY = e(elprice)
matrix list SY, format(%9.3f) title("duvm e(elprice), symmetry-restricted")

local eba = NS[2, 1]
local eab = NS[1, 2]
display as text "cell [b,a] (quantity of b, price of a) = " %6.3f `eba' "   expected about +0.40"
display as text "cell [a,b] (quantity of a, price of b) = " %6.3f `eab' "   expected about  0.00"
if !(`eba' > 0.25 & `eba' < 0.55 & abs(`eab') < 0.10) {
    display as error "orientation check FAILED: the matrix is not (rows = quantity, columns = price)"
    exit 9
}
display as result "orientation check passed: rows = good whose quantity responds; columns = good whose price changes"
tempname fh
file open `fh' using "$OUT_DIAG/welcom_orientation_check.csv", write replace
file write `fh' "cell,meaning,simulated_truth,duvm_no_symmetry" _n
file write `fh' "a_a,quantity of a wrt price of a,-1.2," (NS[1,1]) _n
file write `fh' "a_b,quantity of a wrt price of b,0," (NS[1,2]) _n
file write `fh' "b_a,quantity of b wrt price of a,0.4," (NS[2,1]) _n
file write `fh' "b_b,quantity of b wrt price of b,-1.2," (NS[2,2]) _n
file close `fh'
quietly cd "$ROOT"
