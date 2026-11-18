# Unresolved blockers

Exact list of what the pipeline cannot deliver, why, and what would resolve it. Nothing here is filled with a proxy. Counts are from run `20261117a`.

## Affecting the paper's tables

| # | Blocker | Affected cells | Evidence | What would resolve it |
|---|---|---|---|---|
| B-1 | **Spirits and wine have no physical quantities.** ENPH collects them only in the monthly-recall module (Cuadernillo 3, section J11), which asks for the amount paid. No unit value exists, so the good cannot enter WELCOM's unit-value model | Spirits row of Tables 3, 4 and 6; spirits row and column of Table 5; unit value and quantity of spirits in Table 2. Reported as "n.e." / "n.a." | `output/diagnostics/<run>/quantity_rules.csv`: 0 of 12,097 spirits and wine purchase records have a quantity; `welcom_contract.csv`: `estimable = FALSE` | An external price source for spirits and wine by city and month, and an estimator that accepts price indices (register entry A-08) |
| B-2 | **On-trade purchases have no physical quantities.** Away-from-home records carry a count of items and an amount | No on-trade ("fuera") model; combined-market unit values equal off-trade unit values | `quantity_rules.csv`: every away record is `category_without_physical_unit` | Serving-size information or restaurant price indices (A-09) |
| B-3 | **Beer is too sparse for a reliable estimate.** 1,065 usable unit values in 251 of 483 price clusters; reliability of the cluster-mean unit value 0.29; 35 within-cluster degrees of freedom in the lowest income tercile | Beer rows of Tables 3, 5 and 6 are reported with a caution in the text; beer is not estimable in Table 4 (left out of the three tercile models by the support rule) | `price_cluster_variation.csv`, Table A5 | Larger price clusters for beer or external prices (A-07) |
| B-4 | **Bootstrap stopped at the first 100 replications** (at the authors' request; the configured target is 500). The 18 main and tercile models have 100 replications (one failed, in M3 off-trade). The 14 sensitivity models have 4 and are reported as point estimates only | Standard errors, intervals and significance marks in Tables 3–6 are preliminary; Tables A3–A4 have no standard errors. Each table states the number of replications used | `output/estimates/20261117a/bootstrap_status.csv` | `run_pipeline.ps1 -Stage bootstrap,inference,report,manuscript -RunId 20261117a` resumes from the existing replication files (about 75 main replications an hour on 12 workers; about 7 more hours) |
| B-5 | **SSB cannot be separated from NSSB.** COICOP and the descriptions carry no sweetener information | Every SB cell refers to sweetened beverages as a whole | Audit §2.12 | Product-level data with sweetener content |
| B-6 | **Composite purchases cannot be attributed.** 185,000 away-from-home records mention a beverage together with other items | On-trade spending and prevalence are understated by an unknown amount; M5 differs little from M1 | `text_recovery.csv`, Table A2 | An allocation model, treated as a sensitivity analysis (A-10) |

## Affecting documentation or provenance

| # | Blocker | Consequence | What would resolve it |
|---|---|---|---|
| B-7 | **WELCOM 2.1 is not available.** The pinned version is 3.60 | Results cannot be tied to the version cited in the earlier manuscript | The 2.1 package, if the authors still have it |
| B-8 | **No stratum or PSU identifiers in the public ENPH file** | Design-based variance is not possible; municipality and domain × area are proxies used only for description | DANE's restricted design variables |
| B-9 | **DANE does not document how Capítulo C enters its expenditure aggregate** | The rule used here (last purchase × frequency, only when not bought inside the reference period) follows the questionnaire wording, not a published DANE rule. S3 drops Capítulo C | DANE's processing documentation |
| B-10 | **Legacy `GastoTotal` and five other legacy columns have no source code** | Not reproduced; replaced by DANE aggregates | The original script, only if a comparison with the legacy values is wanted |
| B-11 | **No exchange-rate source for USD columns** | Tables are in COP only | A documented rate and basis in `config/config.yml` (`money`) |
| B-12 | **`renv` is not installed** | `renv.lock` was written from the installed library and has not been tested with `renv::restore()` | Install `renv` and run `renv::restore()` on a clean machine |

## Outside the pipeline (needs a decision by the authors)

| # | Item |
|---|---|
| B-13 | Commit `7a51561` on `origin/main` contains `data/processed/DataEstimates5.dta` (household-level), `docs/FP Review.pdf` (confidential) and `output/old/EstimacionesV2.xlsx` (licensed data). `.gitignore` now prevents re-adding them, but removing them from history requires rewriting it, which this task does not do |
| B-14 | Redistribution terms of the WELCOM files pinned in `code/stata/ado/` should be checked before the repository is made public |
