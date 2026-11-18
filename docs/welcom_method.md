# What WELCOM's `duvm` estimates and how this project calls it

This note documents the estimator behind every elasticity in Tables 3–6. It is based on the pinned source `code/stata/ado/d/duvm.ado` (WELCOM 3.60, 13 October 2021; SHA-256 in `code/stata/ado/ado_manifest.csv`), its help file `duvm.sthlp`, and Deaton (1988, 1990, 1997). Line numbers refer to the pinned `duvm.ado`. WELCOM is used unmodified.

The manuscript being revised reports WELCOM 2.1. The copy installed on the analysis machine, and pinned here, is 3.60: the Stata package record shows 2.30 installed on 5 March 2023 and overwritten by 3.60 on 8 May 2023. Version 2.1 is not available, so results are tied to 3.60.

## 1. Model and estimating equations

`duvm` is Abdelkrim Araar's packaging of the Stata code in Deaton (1997, ch. 5). For each good *g*, household *h* in cluster *c*:

- Unit-value equation: `ln v_ghc = a1_g + b1_g ln x_hc + g1_g'z_hc + f1_gc + u1_ghc`
- Budget-share equation: `w_ghc = a0_g + b0_g ln x_hc + g0_g'z_hc + f0_gc + u0_ghc`

where `x` is household expenditure, `z` are household controls, and `f` are cluster effects that absorb the common cluster price.

**Stage 1, within clusters (`st1reg`, l.270–359).** For each good:

1. `areg luv<g> lnx lnhhsize controls [aw=w], absorb(cluster)` on households with a unit value (l.281). `b1_g` is the quality elasticity (l.290); the residual variance is the measurement-error variance of the unit value, `ome_g` (l.286).
2. If `csb(1)`: a probit of "share is not zero" on the same regressors, and the inverse Mills ratio `lambda = phi(xb)/Phi(xb)` computed for **every** household (l.312–327).
3. `areg w<g> lnx lnhhsize controls [lambda] [aw=w], absorb(cluster)` on **all** households, buyers and non-buyers (l.330). `b0_g` is the coefficient of `lnx` (l.335); the residual variance is `sig_g`.
4. A third regression gives the covariance `lam_g` between the two residuals (l.340–341).
5. `y1 = luv − x'b` and `y0 = w − x'b` keep the cluster effects (l.299, l.336).

**Stage 2, between clusters.** `y0` and `y1` are averaged by cluster (`clustit`, l.375–394), regressed on region and survey-round dummies and replaced by the residuals (`purge`, l.414–428). With `S = cov(y1_c)` and `R = cov(y1_c, y0_c)` across clusters (`mkcov`, l.125–140), the errors-in-variables estimator is

`B = (S − diag(ome/n1))^{-1} (R − diag(lam/n0))` (`fixmat`, l.433–443; l.778–781),

where `n0`, `n1` are harmonic means over clusters of the number of households and of households with a unit value (`mkns`, l.398–411).

**Stage 3, elasticities.** `mkels` (l.31–48) converts `B` into price elasticities using Deaton's quality correction; `complet` (l.54–106) adds a residual "all other goods" category so that shares sum to one, with a hard-coded quality elasticity of 0.25 for that residual good (l.72); the symmetry-restricted estimator follows (l.837–862).

## 2. What the exported numbers are

| Export (`stat`) | Source in `duvm` | Meaning |
|---|---|---|
| `price` | `e(elprice)` = `C_SY_ep` (l.1116) | Price elasticity of quantity, quality-corrected, with Slutsky symmetry imposed. **Primary.** |
| `price_nosym` | `C_NS_ep` (WELCOM Table 06) | Same without the symmetry restriction |
| `price_noquality` | `B_NS_ep` (WELCOM Table 04) | Without quality correction or symmetry |
| `expenditure` | `e(elincome)` = `1 − b1 + b0/wbar` (l.120) | Elasticity of quantity with respect to total expenditure |
| `quality` | `b1` | Elasticity of the unit value with respect to total expenditure |

- **Marshallian or Hicksian.** Uncompensated (Marshallian). The expenditure effect is not netted out.
- **Matrix orientation.** `B[H,G]` is the effect of the price of *H* on the share of *G*; `mkels` transposes it (l.33, l.42). In `e(elprice)`, **rows are the good whose quantity responds and columns the good whose price changes.** This is also checked numerically: `code/stata/90_orientation_check.do` simulates two goods where only the quantity of *b* responds to the price of *a* (true elasticities −1.2, 0, +0.4, −1.2) and `duvm` returns −1.198, 0.001, 0.403, −1.199 in cells `[a,a]`, `[a,b]`, `[b,a]`, `[b,b]` (`output/diagnostics/<run_id>/welcom_orientation_check.csv`).
- **Conditional or unconditional.** `complet` builds the residual good as `1 − sum(w)`. The routine therefore assumes that `w` are shares of the **total** budget and `expend()` is **total** expenditure. Elasticities are unconditional on the beverage budget.
- **Expenditure, not income.** `e(elincome)` is an elasticity with respect to whatever is passed in `expend()`. This project passes total household current expenditure, so the estimates are expenditure elasticities.

## 3. Input contract

For every name `g` in the list: `w<g>` (budget share) and `luv<g>` (log unit value). From the source:

| Field | Requirement | Why |
|---|---|---|
| `w<g>` | Non-missing; 0 for non-buyers | `_1 = (w != 0)` treats a missing share as a purchase (l.314); `mkwbar` averages it |
| `luv<g>` | **Missing** when no unit value is observed | Stage-1 unit-value regressions use available observations only, as in Deaton. No placeholder is needed |
| `expend()`, `hhsize()` | Levels, strictly positive | `duvm` takes logs (l.650–652) |
| `cluster()` | One variable | Absorbed in stage 1; unit of stage 2 |
| `region()`, `subround()` | Constant within cluster | Stage 2 keeps the first household of each cluster (l.725) |
| `hweight()` | Optional; default 1 | See section 5 |
| `indcat()`, `indcon()` | Household controls | Entered as `i.var` and as continuous |

R writes these fields (`code/R/04_prices/03_export_stata.R`) and checks the contract; Stata checks it again (`elas_validate` in `code/stata/10_programs.do`).

## 4. Calling-side corrections relative to the legacy do-files

| # | Legacy call | Problem | New call |
|---|---|---|---|
| W1 | `luv` = log of a price defined for every household; 95% of beer "prices" were regression predictions for non-buyers | Imputed values enter stage 1 as observed unit values | `luv` is missing unless the household has a valid observed unit value |
| W2 | Shares of the five-beverage basket (`Gasto_g / totalexp`) with `expend(GastoTotal)` | `duvm` assumes total-budget shares (section 2). Basket shares sum to one, so the residual good has share zero and the complete-system step is degenerate; the "expenditure elasticity" mixes two budgets | Shares of total household current expenditure; `expend()` is the same total |
| W3 | `region(x3)` with `x3 = xrural` | "Regional effects" were only an urban/rural dummy | `region(regctl)`: DANE region × urban/rest (11 cells); `subround(quarter_id)` for the collection quarter |
| W4 | `cluster(psu)` from the first 8 characters of `VIVIENDA` | Arbitrary truncation of the dwelling identifier: 112 of 384 clusters span several quarters | Local market: municipality × area (urban / rest) × collection quarter (486 clusters). Survey segments are sensitivity S5; see `docs/methods.md` §5 for why |
| W5 | `hweight(FEX_C)`: household expansion factors, mean about 165 | `duvm` counts households per cluster as the **sum of weights**, so `n0`, `n1` were in the hundreds and the measurement-error correction vanished | Section 5 |
| W6 | `GastoTotal`: no source code, trimmed and imputed with an unseeded `mice` | Undocumented regressor | DANE's current expenditure of the spending unit (GCUG), neither trimmed nor imputed |
| W7 | Spirits passed with a "unit value" equal to spending per record | ENPH collects spirits and wine without quantities | Spirits and wine are not passed to `duvm` (not estimable) |
| W8 | `hgroup(Tercil)` with unweighted sample terciles | Terciles carried 37/31/32% of the weighted population | Weighted terciles; one `duvm` call per tercile, which is what `hgroup()` does internally (l.1039–1053) |
| W9 | No seed | Not reproducible | Seeds in `config/config.yml` |

## 5. Survey weights inside `duvm`, and the weight passed here

`duvm` uses `hweight()` in four places: (a) as `aweight` in the stage-1 regressions and `pweight` in the probit; (b) in the average budget shares; (c) in the cluster means of `y0`, `y1`; (d) as the **count** of households per cluster, `n0c = sum(w)` and `n1c = sum(w over households with a unit value)` (l.384–389), which feed the measurement-error correction.

Two properties of the code matter once unit values are correctly missing for non-buyers:

1. **Cluster means (`mwegen`, l.361–370).** The numerator averages `y × w` over households with a unit value, but the denominator averages `w` over all households of the cluster. If weights vary within a cluster, the cluster mean of `y1` is multiplied by (mean weight of buyers / mean weight of all households). Within ENPH segments the expansion factor varies (median coefficient of variation 0.20). `y1` is a log price level of about 7–10, so this factor would add noise several times larger than the real between-cluster price variation.
2. **Counts as sums of weights.** Deaton's correction needs the number of households. With raw expansion factors the "counts" are in the hundreds or thousands and the correction disappears. With weights scaled to mean one they can fall below one for small-weight clusters; the correction then exceeds the between-cluster variance, `S − diag(ome/n1)` stops being positive definite, `syminv` returns zeros and every own-price elasticity collapses to −1.000 with zero cross effects. This was observed on these data with segment clusters.

The calling-side choice that keeps WELCOM's weighting and avoids both problems:

- **Cluster-constant weight.** Each household carries the mean expansion factor of its price cluster. Property 1 no longer applies, and each cluster still counts in proportion to the population it represents.
- **Harmonic-mean-one scaling.** The weight is multiplied by a constant so that its harmonic mean across clusters is one (`elas_prepare` in `10_programs.do`). `aweight`s are scale-invariant everywhere else in `duvm`, so the scale matters only for the counts. This scale keeps the counts of the right order and never below one; it does not reproduce the true counts, and no single scale can do so for every good.

| Primary off-trade model (`model_goods.csv`) | Households | SB | Beer | Water | Dairy drinks | Hot drinks |
|---|---|---|---|---|---|---|
| True harmonic mean per cluster | 36.8 | 7.3 | 1.8 | 3.7 | 8.8 | 12.0 |
| WELCOM's count with the weight passed here | 183 | 31.3 | 1.9 | 10.0 | 12.3 | 47.5 |
| WELCOM's count with raw expansion factors (S6) | 7,667 | 1,410 | 60 | 428 | 741 | 2,020 |

WELCOM's counts are too large for every good except beer, so its measurement-error correction is too small and price coefficients are attenuated (own-price elasticities pulled toward −1). The unweighted model M3 uses exact counts and is the check on this: SB is −0.98 in M3 against −0.89 in M1 (combined market). M3 is less stable under resampling, though: with the full correction, 3 of its first 100 bootstrap replications give an SB elasticity beyond ±5 (one at −185), so its standard deviation is 18.4 while its percentile interval is −5.55 to −0.28. With segment clusters (S5) the same scaling gives 9.0 households against a true 9.1, but the correction is then large relative to the signal. This is entry A-03 in the alternatives register. S6 passes raw household expansion factors, as the legacy call did.

## 6. Zero purchases and the selection option

- **Zeros.** Non-buyers enter the budget-share regressions with `w = 0`. They do not enter the unit-value regression. `duvm` has no structural model of non-consumption (no double hurdle, no censored system).
- **`csb(1)`.** The inverse Mills ratio from a probit of purchase on the stage-1 regressors is added to the share regression, estimated on all households. This differs from a Heckman correction in two ways: there is no exclusion restriction (the probit and the share equation have the same regressors, so identification rests on the functional form), and the term is added to a regression that includes the zeros rather than to a regression on purchasers only. It is not applied to the unit-value equation, where selection into observing a unit value operates.
- **Consequence.** The option changes `b0`, and therefore the expenditure elasticities, much more than the price elasticities. M1 uses `csb(1)` because that is the treatment WELCOM offers and the legacy analysis intended; M2 switches it off. The estimand is the same; only the functional form of the share equation changes.

## 7. Standard errors: WELCOM's `boot()` and the external bootstrap

`boot(B)` (l.881–914 and `bootindi`, l.446–553):

1. resamples **cluster-level** records (`tempclus`) and repeats stage 2 only. Stage 1 (`b0`, `b1`, `ome`, `lam`, average shares) is held fixed, so first-stage uncertainty is ignored;
2. reports `sqrt(e(V))` after `mean` (l.902–907), the standard error **of the mean of the replications**, which is the bootstrap standard deviation divided by `sqrt(B+1)` and shrinks as `B` grows;
3. reads cell `(i,j)` from position `(i−1)K + j` of a vector that stores a `(K+1)×(K+1)` matrix column by column (`vecmx`, l.208–223; loop at l.899–908). For `K = 5` only the `(1,1)` cell is the right one; for example the value printed as the own-price standard error of the second good belongs to the cross elasticity `(1,2)`;
4. fills the "expenditure elasticity" standard errors from the first column of the uncorrected price-elasticity matrix (`vtodat`, l.150). Expenditure elasticities depend only on stage 1, so the routine has no valid standard error for them.

`duvm` also returns no covariance matrix. For these reasons the reported inference comes from an **external cluster bootstrap that wraps `duvm`** (`code/stata/30_bootstrap_worker.do`): price clusters are resampled with replacement within region cells (`bsample, strata() cluster() idcluster()`), and the complete `duvm` estimation is rerun on each resample with `boot(0)`. `duvm` itself is not changed.

- Standard error = standard deviation of the replications; 95% interval = 2.5th and 97.5th percentiles; joint covariance of all price and expenditure elasticities in `output/estimates/<run_id>/covariance_long.csv`.
- Replication `r` uses seed `SEED + r` for every model, so models estimated on the same households share resamples and their differences can be compared pairwise (`spec_differences.csv`).
- Failed replications are counted in `bootstrap_status.csv`.
- **Captured:** sampling of clusters, including all stage-1 regressions, average shares and the selection term.
- **Not captured:** uncertainty in rules fixed in R (classification, unit conversion, outlier flags, income terciles); the survey's stratification and unequal selection probabilities beyond the cluster-level weights; non-sampling error.

For reference, WELCOM's own Table 09 values and the standard deviation of its replications are exported for the primary models (`welcom_native.csv`, Table A8).

## 8. Features WELCOM does not support

| Feature | Status | Consequence |
|---|---|---|
| Strata and PSUs in estimation or inference | Not supported | Design-based variance is not available; inference is by cluster bootstrap |
| Household-level weights with missing unit values | Distorted cluster means (section 5) | Segment-constant weights are passed |
| Exclusion restriction or a censored demand system | Not supported | Selection results rest on functional form |
| Goods without unit values | Cannot enter the system | Spirits and wine are not estimable |
| Joint covariance matrix | Not returned | Obtained from the external bootstrap |
| Compensated (Hicksian) elasticities | Not returned | Only Marshallian elasticities are reported |

Each row has an entry in `docs/estimation_alternatives.md`.

## References

- Deaton, A. (1988). Quality, quantity, and spatial variation of price. *American Economic Review*, 78(3), 418–430.
- Deaton, A. (1990). Price elasticities from survey data: extensions and Indonesian results. *Journal of Econometrics*, 44(3), 281–309.
- Deaton, A. (1997). *The Analysis of Household Surveys*. Johns Hopkins University Press for the World Bank. Chapter 5.
- Araar, A., Malásquez, E., Olivieri, S., & Rodríguez-Castelán, C. WELCOM: a tool to simulate the welfare impacts of competition (World Bank). `duvm` help file and source, version 3.60.
