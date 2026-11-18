# Estimation alternatives register

Places where another estimator, option or data treatment could improve or correct the estimates. **None is implemented.** Tables 1–6 and the manuscript use WELCOM's `duvm` only; no alternative estimate is reported anywhere. The machine-readable version is `metadata/alternatives_register.csv`; both files are written by `code/R/tools/write_alternatives_register.py`.

Evidence is from run `20261117a` (point estimates for all models; 100 bootstrap replications for the main and tercile models). References were checked against Crossref, RePEc and DANE on 2026-11-17.

## Summary

| ID | Topic | Priority | Effort | Affected |
|---|---|---|---|---|
| A-01 | Selection correction | High | High: new estimator outside WELCOM | Table 6, column M1, every cell; Table 3 marginally; all tercile and sensitivity models (they use csb 1). |
| A-02 | Zero purchases | High | High | All elasticities, most for beer and water. |
| A-03 | Survey weights: household counts | High | Medium: re-implement stage 2 (about 200 lines) or patch WELCOM | Tables 3-5, all weighted models. |
| A-05 | Strata, PSUs and inference | High | Low for municipality-level resampling (one option in the worker); high for a design-based variance | All standard errors and confidence intervals (Tables 3-6, A3-A4, A7). |
| A-06 | Unit values: quality and measurement error | High | Medium (article-level unit values are available in the household diary); high for external prices | All price elasticities; water most. |
| A-07 | Sparse goods and cluster size | High | Medium | Beer rows of Tables 3, 5 and 6; SB through the cross-equation restriction; Table 4 (four-good system). |
| A-08 | Spirits and wine | High | High | Spirits rows and columns of Tables 3-6; cross-price effects between SB and spirits. |
| A-17 | Identification from regional price variation | High | High | All price elasticities; interpretation as demand responses. |
| A-04 | Survey weights: cluster means | Medium | Low once A-03 is done | None in the delivered tables (neutralised by the calling choice); S6 (raw household weights) is affected. |
| A-09 | On-trade market | Medium | High | Combined-market panels of Tables 3-6 (same unit values as off-trade); no on-trade panel. |
| A-10 | Composite purchases in free text | Medium | Medium | Table 2 panels C-D; M1 vs M5; combined-market budget shares. |
| A-12 | Uncertainty from data construction | Medium | Medium | All standard errors. |
| A-14 | Theoretical restrictions | Medium | Low for reporting both matrices; medium for a symmetry test | Table 5 off-diagonal cells; Table 3 marginally. |
| A-16 | Recall periods and Capitulo C | Medium | Low once DANE's rule is known | Budget shares and prevalence in all tables. |
| A-11 | Conditional vs unconditional demand | Low | High | Interpretation of Tables 3-6. |
| A-15 | Overlapping markets | Low | Low for bootstrapped differences; high for separate goods | Comparisons between the two panels of Tables 3-6. |
| A-13 | WELCOM's own standard errors | Low (handled) | None | None in the delivered tables (the external bootstrap is used). |

## Entries

### A-01. Selection correction

- **Issue.** duvm's csb(1) adds an inverse Mills ratio from a probit on the same regressors as the share equation (no exclusion restriction) and enters it in a regression that includes the zero shares. It is not applied to the unit-value equation.
- **Evidence.** duvm.ado l.312-330. Expenditure elasticities, M1 (csb 1) vs M2 (csb 0), combined market: SB 0.52 vs 0.83; beer -3.58 vs 1.60; water 0.03 vs 1.10; dairy drinks 0.20 vs 0.72; hot drinks 0.37 vs 0.70. Own-price elasticities barely move (SB -0.890 vs -0.889).
- **Affected.** Table 6, column M1, every cell; Table 3 marginally; all tercile and sensitivity models (they use csb 1).
- **Proposed alternative.** A censored demand system estimated in two steps (probit, then share equations augmented with Phi and phi terms), or a selection model with an exclusion restriction applied to purchasers only.
- **References.** Heckman (1979), Econometrica 47(1):153-161, doi:10.2307/1912352; Shonkwiler & Yen (1999), AJAE 81(4):972-982, doi:10.2307/1244339
- **Expected impact.** Large for expenditure elasticities (the M1-M2 gap is 0.3 to 5 points); direction for a proper correction unknown. Small for own-price elasticities.
- **Effort / priority.** High: new estimator outside WELCOM / High
- **Prerequisites.** A credible exclusion restriction, or acceptance of functional-form identification; a decision on the estimator.

### A-02. Zero purchases

- **Issue.** Zeros are treated as observations of a linear share equation. duvm has no model of structural non-consumption or of infrequent purchase during a short recall window.
- **Evidence.** Share of non-buyers in the combined market: beer 91%, spirits and wine 89%, water 83%, SB 43%, hot drinks 33%, dairy drinks 29% (Table 2). Recall windows are 7 or 14 days for most purchases.
- **Affected.** All elasticities, most for beer and water.
- **Proposed alternative.** Double-hurdle or infrequency-of-purchase models; censored QUAIDS or EASI systems.
- **References.** Shonkwiler & Yen (1999), AJAE 81(4):972-982, doi:10.2307/1244339; Banks, Blundell & Lewbel (1997), REStat 79(4):527-539, doi:10.1162/003465397557015; Lewbel & Pendakur (2009), AER 99(3):827-863, doi:10.1257/aer.99.3.827
- **Expected impact.** Unknown.
- **Effort / priority.** High / High
- **Prerequisites.** Same as A-01, plus price measures for every good in the system.

### A-03. Survey weights: household counts

- **Issue.** duvm measures the number of households per cluster (n0, n1 in the measurement-error correction) as a sum of weights. No scaling of the weights reproduces the true counts for every good.
- **Evidence.** duvm.ado l.384-389. Primary off-trade model, WELCOM's count vs the true harmonic mean: households per cluster 183 vs 36.8; unit values per cluster SB 31.3 vs 7.3, hot drinks 47.5 vs 12.0, water 10.0 vs 3.7, dairy drinks 12.3 vs 8.8, beer 1.9 vs 1.8 (model_goods.csv). The correction is therefore too small for every good except beer. Unweighted model M3 uses exact counts: SB -0.98 vs -0.89 (combined), but 3 of M3's first 100 bootstrap replications give an SB elasticity beyond +/-5 (bootstrap SD 18.4; percentile interval -5.55 to -0.28). With raw expansion factors (S6) counts are in the thousands: SB -0.98.
- **Affected.** Tables 3-5, all weighted models.
- **Proposed alternative.** An implementation of Deaton's estimator that uses weights for means and regressions but true household counts in the correction.
- **References.** Deaton (1990), J. Econometrics 44(3):281-309, doi:10.1016/0304-4076(90)90060-7; Deaton (1997), The Analysis of Household Surveys, ch. 5
- **Expected impact.** Under-correction attenuates the price coefficient and pulls own-price elasticities toward -1. For SB the weighted estimates (-0.89) are already further from -1 than the unweighted one (-0.98), so the net effect of weighting is not only this term; size unknown.
- **Effort / priority.** Medium: re-implement stage 2 (about 200 lines) or patch WELCOM / High
- **Prerequisites.** Decision to leave WELCOM or to maintain a patched copy.

### A-04. Survey weights: cluster means

- **Issue.** duvm's weighted cluster mean divides by the mean weight of all households in the cluster, including those without a unit value. With household-varying weights and missing unit values the cluster mean log unit value is rescaled by a cluster-specific factor.
- **Evidence.** duvm.ado l.361-370 (mwegen). Within-segment coefficient of variation of the expansion factor: median 0.20; within local markets 0.31 (price_cluster_sizes.csv). The pipeline avoids the problem by passing cluster-constant weights.
- **Affected.** None in the delivered tables (neutralised by the calling choice); S6 (raw household weights) is affected.
- **Proposed alternative.** Corrected weighted means (weights summed over the same households in numerator and denominator), allowing household-level weights.
- **References.** Deaton (1997), The Analysis of Household Surveys, ch. 5
- **Expected impact.** Would allow household-level weights; expected effect on the delivered estimates small.
- **Effort / priority.** Low once A-03 is done / Medium
- **Prerequisites.** Same as A-03.

### A-05. Strata, PSUs and inference

- **Issue.** duvm ignores the survey design. The external bootstrap resamples price clusters within region cells, not the survey's primary sampling units within strata, which the public file does not identify.
- **Evidence.** No stratum or PSU variable in the ENPH public-use file; 178 municipalities serve as a PSU proxy. Bootstrap clusters are 483 municipality x area x quarter cells, so the four quarters of a municipality are resampled independently.
- **Affected.** All standard errors and confidence intervals (Tables 3-6, A3-A4, A7).
- **Proposed alternative.** Resample municipalities (all their quarters together) within strata; or design-based replicate weights from DANE; wild-cluster refinements for few clusters per region cell.
- **References.** Cameron, Gelbach & Miller (2008), REStat 90(3):414-427, doi:10.1162/rest.90.3.414
- **Expected impact.** Standard errors probably understated; size unknown. Current SB standard error: 0.18 (combined), 0.21 (off-trade).
- **Effort / priority.** Low for municipality-level resampling (one option in the worker); high for a design-based variance / High
- **Prerequisites.** DANE design identifiers for a design-based variance.

### A-06. Unit values: quality and measurement error

- **Issue.** Unit values mix price with quality, package size and outlet type. Deaton's correction removes the part of quality that moves with expenditure under separability; other sources remain.
- **Evidence.** Water: standard deviation of the log unit value 1.05 and 75% of its variance between clusters (bulk containers vs bottles; weighted median COP 556 vs mean COP 1,219 per litre). Quality elasticities b1: SB 0.05, beer 0.10, water 0.07, dairy drinks 0.07, hot drinks 0.03. Reliability of cluster-mean unit values: SB 0.68, beer 0.29 (price_cluster_variation.csv).
- **Affected.** All price elasticities; water most.
- **Proposed alternative.** Unit values by 8-digit article and package size before aggregation; quality-adjusted unit values; market price data (DANE consumer price index micro-prices by city) as instruments or regressors.
- **References.** McKelvey (2011), JDE 95(2):157-169, doi:10.1016/j.jdeveco.2010.05.004; Gibson & Kim (2019), JDE 137:66-77, doi:10.1016/j.jdeveco.2018.11.008; Cox & Wohlgenant (1986), AJAE 68(4):908-919, doi:10.2307/1242137
- **Expected impact.** Could be large for water; direction unknown.
- **Effort / priority.** Medium (article-level unit values are available in the household diary); high for external prices / High
- **Prerequisites.** City-level price data from DANE for the external-price route.

### A-07. Sparse goods and cluster size

- **Issue.** Beer has few unit values, so its within-cluster variance, between-cluster covariances and symmetry-restricted estimates are fragile. Results depend on the cluster definition.
- **Evidence.** Beer: 1,065 unit values in 251 of 483 clusters; 35 within-cluster degrees of freedom in the lowest tercile (dropped from the tercile models). Own-price, off-trade: beer -1.54 (M1), -5.04 (M3), +0.15 with segment clusters (S5). SB with segment clusters (S5): -0.45 combined, -0.22 off-trade, against -0.89 and -0.81 with local markets. Dropping beer from the system (S7) moves SB from -0.89 to -0.80 (combined).
- **Affected.** Beer rows of Tables 3, 5 and 6; SB through the cross-equation restriction; Table 4 (four-good system).
- **Proposed alternative.** Aggregate beer with other alcohol when prices exist (see A-08); shrinkage or hierarchical estimation of cluster prices; month-level markets where sample size allows.
- **References.** Deaton (1990), J. Econometrics 44(3):281-309, doi:10.1016/0304-4076(90)90060-7; Gibson & Kim (2019), JDE 137:66-77, doi:10.1016/j.jdeveco.2018.11.008
- **Expected impact.** Large for beer. For SB the cluster definition moves the estimate by about 0.4.
- **Effort / priority.** Medium / High
- **Prerequisites.** None for alternative cluster definitions; A-08 for aggregation.

### A-08. Spirits and wine

- **Issue.** ENPH collects spirits and wine only as monthly amounts, without quantities, so the unit-value model cannot include them.
- **Evidence.** 0 of 12,097 spirits and wine purchase records have a quantity (quantity_rules.csv). 10.7% of households buy them; mean spending among buyers COP 74,242 a month (Table 2).
- **Affected.** Spirits rows and columns of Tables 3-6; cross-price effects between SB and spirits.
- **Proposed alternative.** A demand system with external prices for alcoholic beverages (city-month price indices) for all goods or for alcohol only.
- **References.** Deaton & Muellbauer (1980), AER 70(3):312-326; Banks, Blundell & Lewbel (1997), REStat 79(4):527-539, doi:10.1162/003465397557015; Lewbel & Pendakur (2009), AER 99(3):827-863, doi:10.1257/aer.99.3.827
- **Expected impact.** Not assessable.
- **Effort / priority.** High / High
- **Prerequisites.** Price series for spirits, wine and beer by city and month (DANE price index micro-data or commercial retail data).

### A-09. On-trade market

- **Issue.** Away-from-home purchases have amounts but no quantities, so unit values are off-trade and the on-trade market cannot be modelled.
- **Evidence.** Every away-from-home record is flagged category_without_physical_unit. On-trade spending is 25% of combined SB spending.
- **Affected.** Combined-market panels of Tables 3-6 (same unit values as off-trade); no on-trade panel.
- **Proposed alternative.** Treat off-trade and on-trade as separate goods with separate price measures (restaurant price indices, or per-serving unit values).
- **References.** Deaton (1997), The Analysis of Household Surveys, ch. 5
- **Expected impact.** Unknown.
- **Effort / priority.** High / Medium
- **Prerequisites.** Serving sizes or on-trade price indices.

### A-10. Composite purchases in free text

- **Issue.** Records that mention a beverage together with other items cannot be attributed, so on-trade beverage spending and prevalence are understated.
- **Evidence.** About 185,000 composite records against 15,000 text-identified purchases (text_recovery.csv). 9,019 households mention SB only inside composite purchases (Table A2). Text-identified purchases are 0.9% of combined-market SB spending.
- **Affected.** Table 2 panels C-D; M1 vs M5; combined-market budget shares.
- **Proposed alternative.** Allocate a beverage component with the distribution of prices of pure beverage records in the same module and city, reported as bounds.
- **References.** None cited.
- **Expected impact.** Would raise on-trade SB prevalence (up to about 10 percentage points of households) and spending; effect on elasticities unknown.
- **Effort / priority.** Medium / Medium
- **Prerequisites.** A defensible allocation rule; to be reported as sensitivity only.

### A-11. Conditional vs unconditional demand

- **Issue.** duvm is a one-stage, unconditional system in which beverages are under 4% of the budget. A two-stage budgeting structure is not modelled.
- **Evidence.** Mean shares of total expenditure: dairy drinks 1.27%, hot drinks 0.84%, SB 0.77%, spirits and wine 0.38%, beer 0.32%, water 0.12%.
- **Affected.** Interpretation of Tables 3-6.
- **Proposed alternative.** Two-stage budgeting: a first stage for the beverage group and a second stage within it, reporting conditional and unconditional elasticities.
- **References.** Deaton & Muellbauer (1980), AER 70(3):312-326
- **Expected impact.** Unknown.
- **Effort / priority.** High / Low
- **Prerequisites.** Price index for the beverage group.

### A-12. Uncertainty from data construction

- **Issue.** Classification, unit conversion, outlier flags and income terciles are computed once in R and held fixed across bootstrap replications.
- **Evidence.** Sensitivity of the SB own-price elasticity (combined) to construction rules: broad SB definition -0.75, direct units only -0.74, reference-period recall -0.75, against -0.89 in M1 (Table A3).
- **Affected.** All standard errors.
- **Proposed alternative.** Recompute flags and terciles inside each replication; or report rule uncertainty as a range next to the sampling interval.
- **References.** None cited.
- **Expected impact.** Intervals somewhat too narrow; the rule-based range for SB is about 0.15.
- **Effort / priority.** Medium / Medium
- **Prerequisites.** None.

### A-13. WELCOM's own standard errors

- **Issue.** duvm's boot() reports the standard error of the mean of the replications, reads most cells from the wrong position, fills the expenditure-elasticity errors from another matrix, holds stage 1 fixed and returns no covariance matrix.
- **Evidence.** duvm.ado l.143-155, l.446-553, l.899-908. SB own-price, combined: WELCOM Table 09 prints 0.030; the standard deviation of its own 100 replications is 0.302 (= 0.030 x sqrt(101)) (welcom_native.csv, Table A8).
- **Affected.** None in the delivered tables (the external bootstrap is used).
- **Proposed alternative.** Report the defects to the WELCOM authors; keep the external bootstrap.
- **References.** Cameron, Gelbach & Miller (2008), REStat 90(3):414-427, doi:10.1162/rest.90.3.414
- **Expected impact.** Already handled.
- **Effort / priority.** None / Low (handled)
- **Prerequisites.** None.

### A-14. Theoretical restrictions

- **Issue.** The reported matrix imposes Slutsky symmetry and completes the system with a residual good whose quality elasticity is fixed at 0.25 inside duvm.
- **Evidence.** duvm.ado l.72, l.837-862. Combined market, with vs without symmetry: SB own-price -0.890 vs -0.879; beer -0.92 vs -0.80; SB quantity with respect to the dairy price -0.08 vs +0.40; hot drinks with respect to the SB price +0.29 vs -0.23 (price_nosym in estimates_long.csv).
- **Affected.** Table 5 off-diagonal cells; Table 3 marginally.
- **Proposed alternative.** Report restricted and unrestricted matrices side by side and test symmetry; sensitivity to the residual good's quality elasticity (needs a modified routine).
- **References.** Deaton (1990), J. Econometrics 44(3):281-309, doi:10.1016/0304-4076(90)90060-7; Deaton & Muellbauer (1980), AER 70(3):312-326
- **Expected impact.** Own-price effects robust; cross-price signs are not.
- **Effort / priority.** Low for reporting both matrices; medium for a symmetry test / Medium
- **Prerequisites.** None for reporting both.

### A-15. Overlapping markets

- **Issue.** The combined market contains the off-trade market, so the two panels are not independent and their difference is not an on-trade estimate.
- **Evidence.** Same households and unit values in both panels; only the budget shares differ.
- **Affected.** Comparisons between the two panels of Tables 3-6.
- **Proposed alternative.** Joint estimation with off-trade and on-trade as separate goods (see A-09); bootstrap the difference between panels using the shared resamples.
- **References.** None cited.
- **Expected impact.** Unknown.
- **Effort / priority.** Low for bootstrapped differences; high for separate goods / Low
- **Prerequisites.** A-09 for separate goods.

### A-16. Recall periods and Capitulo C

- **Issue.** Monthly amounts follow DANE's frequency factors, which understate purchases made less often than the diary window unless Capitulo C captures them. How DANE uses Capitulo C is not documented, and it has no alcohol group.
- **Evidence.** S3 (30 / recall days for every diary purchase, no Capitulo C): SB own-price -0.75 vs -0.89 (combined), -0.61 vs -0.81 (off-trade). Capitulo C supplies 2% of SB, 8% of dairy and 23% of hot-drink spending (household_category_measurement.csv).
- **Affected.** Budget shares and prevalence in all tables.
- **Proposed alternative.** Confirm DANE's processing rules; treat purchase frequency as a model of usual expenditure.
- **References.** DANE (2020), Metodologia General ENPH, DSO-ENPH-MET-001 v2
- **Expected impact.** For SB about 0.15 to 0.2 on the own-price elasticity.
- **Effort / priority.** Low once DANE's rule is known / Medium
- **Prerequisites.** DANE's processing documentation for Capitulo C.

### A-17. Identification from regional price variation

- **Issue.** Price effects are identified from differences between municipalities within region x area x quarter cells. Removing the regional controls changes the SB estimate more than any other specification change.
- **Evidence.** SB own-price without regional controls (M4): -0.25 combined and -0.14 off-trade, against -0.89 and -0.81 (Table 3). 178 municipalities in 11 region-area cells.
- **Affected.** All price elasticities; interpretation as demand responses.
- **Proposed alternative.** Use policy-driven price changes (the 2023 tax on sweetened beverages) with later survey waves; city-level price indices as instruments.
- **References.** Deaton (1988), AER 78(3):418-430; Gibson & Kim (2019), JDE 137:66-77, doi:10.1016/j.jdeveco.2018.11.008
- **Expected impact.** Unknown; determines whether the estimates can be read causally.
- **Effort / priority.** High / High
- **Prerequisites.** Post-2023 expenditure data or external price data.

## Adding an alternative later

Data construction and reporting do not depend on the estimator. A new estimator is a new Stata (or R) program that reads `data/processed/estimation/est_<variant>_<market>.dta` and writes rows to `point_long.csv` and the bootstrap files in the same long format (`model_id, rep, stat, row, col, value`), with new `model_id`s registered in `config/models.csv`. Tables and the manuscript read only that format.
