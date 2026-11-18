# Legacy-to-new logic map

Where each legacy operation went. "C-nn" and "W-n" refer to `docs/corrections_log.md` and `docs/welcom_method.md` §4. Legacy files are in `code/legacy/` and are not modified.

## R

| Legacy file / operation | New location | Status |
|---|---|---|
| `M0SSBElasticity.R`: paths, `prural`, `pqlit*`, `pglit*` parameters, `source()` order | `config/config.yml`, `code/R/00_run.R` | Paths and order kept as configuration. The litres-per-unit and price-per-litre constants are **dropped** (C-20, C-21) |
| `SSBDInput.R`: read 15 `.sav` modules and the nomenclature | `01_load/01_inventory.R`, `01_load/02_import_enph.R`; `metadata/enph_modules.csv`, `metadata/input_manifest.csv` | Kept. `haven` instead of `foreign`; UTF-8 (C-26); record keys checked. The two "Mercados" modules and "Medio de pago" are inventoried but not used, as before |
| `SSBDHousehold.R`: head covariates, rural, household size, single, children | `02_households/01_households.R` | Kept; education mapping corrected (C-04); segment, municipality, quarter and region cell added |
| `SSBDIncome.R`: person-level income sum, per-capita income, terciles | `02_households/02_income_expenditure.R` | Rebuilt as a check; DANE `IT` is the reported income; terciles weighted (C-03) |
| *(no code)* `GastoTotal` | `02_households/02_income_expenditure.R` | Replaced by DANE `GCUG` (C-02) |
| `SSBDImputacion.R`: trimming and `mice` imputation of income and expenditure | — | **Dropped** (C-02, C-03): nothing is imputed |
| `fclasicoicop.R::fclasidrinks` | `lib/classify.R::classify_coicop`, `metadata/category_map.csv` | Kept as a versioned table; corrections C-06 to C-10 |
| `fclasicoicop.R::fchanneldrinks` | `03_consumption/02_classify_quantify.R` (`market`) | Kept: COICOP divisions 01–02 are off-trade, 11 is on-trade |
| `fclasicoicop.R::ftextdrinks` | `lib/classify.R::classify_text`, `metadata/text_rules.csv` | Kept as a versioned table; pure-description rule (C-05); beer and refajo fixed (C-06, C-11) |
| `fclasicoicop.R::festconsu` | — | **Dropped** (C-21) |
| `fclasicoicop.R::remove_outliers` | `lib/utils.R::flag_log_mad`, `04_prices/01_aggregate.R` | Replaced by flags (C-24) |
| `SSBEConsuBasesUrbano.R` / `SSBEConsuBasesRural.R`: one block per module (meals away, personal diary, Capítulo C, household diary, less-frequent) | `03_consumption/01_harmonize.R` (one harmonised file), `03_consumption/02_classify_quantify.R` | All ten purchase modules and both Capítulo C modules kept. Recall factors: `metadata/frequency_factors.csv` (C-13, C-17). Units: `metadata/unit_conversions.csv` (C-18 to C-20). Capítulo C: `metadata/capc_group_map.csv` (C-15, C-16). The vestigial read of `DataEstimates4` is gone |
| `SSBConsuGasCorrected.R`: universe filter, survey totals, `DataEstimates4` | `05_validate/02_descriptives.R` (sample flow, Table 2) | Universe filter dropped (C-01). Undefined objects no longer needed |
| `SSBRevisedPaper_Prices.R`: household spending, quantities, unit values by channel; outlier rules; price imputation for non-buyers; Dairy merge | `04_prices/01_aggregate.R` | Channels kept (off-trade, on-trade, combined as a union of records). Imputation dropped (C-23); outliers flagged (C-24); Dairy merge undone (C-09) |
| `SSBRevisedPaper_Prices_Codi.R`: coded-only version | `04_prices/01_aggregate.R` (variant `coded_only`) | One parameterised function; same rules as the primary data (C-25) |
| Quality-adjusted price block (`Prices.R:217–452`) | — | **Dropped**: it never ran (stopped earlier) and mis-aligned rows; WELCOM does the quality correction |
| `Cluster = substr(VIVIENDA, 1, 8)` | `04_prices/02_price_clusters.R` | Replaced by the survey segment; the legacy definition is kept for diagnostics only (W4) |
| `write.dta` of `UnitValuePrices_*`, `UnitValueGasto_*` | `04_prices/03_export_stata.R` → `data/processed/estimation/est_<variant>_<market>.dta` | One analysis-ready file per data variant and market, with a dictionary and a WELCOM contract file |
| `SSBEDescriptive.R`, `SSBEConsumption.R`, `SSBDExpenditure.R`, `SSBDPrices.R`, `SSBDEPrices.R`, `SSBEConsuAna.R`, `SSBEEPaper.R`, `SSBEBootstrap.R`, `Paper2Density.R`, `SSBRevisedPaper.R`, `SSBRevisedPaper_Gasto.R`, `SSBRevisedPaper_PricesV2.R` | — | Not part of the manuscript path (pre-revision or QUAIDS-era). Not ported |

## Stata

| Legacy file / operation | New location | Status |
|---|---|---|
| `SSBElasticityPaperRevised_{total,hogar}_duvm.do`: merges, shares, logs, `duvm` Models 1–3 | `code/stata/20_point_estimates.do` with `config/models.csv` | Merges, shares and logs moved to R. `duvm` calls corrected (W1–W9) |
| `..._codi_duvm.do` (Model 5; failed on `Gasto_Wine`) | `M5_*` rows of `config/models.csv` | Runs on the coded-only data variant |
| `..._fuera_duvm.do` (on-trade; inputs never produced) | — | **Not estimable**: no on-trade purchase carries a physical quantity. Blocker B-2 |
| Models 4 and 6 (no code) | `M4_*`, `M6_*` rows of `config/models.csv` | Implemented |
| `hgroup(Tercil)` | `T1_*`–`T3_*` rows | One `duvm` call per tercile (W8) |
| `boot(100)` | `30_bootstrap_worker.do`, `40_inference.do` | External cluster bootstrap around `duvm`; WELCOM's own output exported for reference |
| `SSBElasticityPaperDescribe.do` (Table 1) | `code/R/05_validate/02_descriptives.R` | Moved to R |
| QUAIDS-era do-files (`SSBElasticityPaper.do`, `...Revised.do`, `...RevisedQuintil.do`, `...Revised_{hogar,total,fuera}.do`, `...NewRoutine.do`, `...V2.do`) | — | Not the manuscript's method. Not ported |

## Outputs

| Legacy | New |
|---|---|
| Stata log only | `output/estimates/<run_id>/`: `point_long.csv`, `estimates_long.csv`, `covariance_long.csv`, `spec_differences.csv`, `bootstrap_status.csv`, `model_meta.csv`, `model_goods.csv`, `welcom_native.csv` |
| Hand-transcribed tables | `output/tables/<run_id>/`: Tables 1–6 and A1–A8 as CSV and LaTeX, plus `table_completeness.csv` |
| — | `data/processed/manuscript/<run_id>/`: results object, named values, manifest; `manuscript/manuscript.Rmd` renders from it |
