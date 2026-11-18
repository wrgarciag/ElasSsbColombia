# R code

Entry point: `Rscript code/R/00_run.R <stage> --run-id=<id>`.

| Folder | Stage | Purpose |
|---|---|---|
| `lib/` | — | Functions without side effects: configuration, checks, weighted statistics, classification, LaTeX tables, Stata bridge, run manifest |
| `01_load/` | `load` | Input inventory with checksums; typed import of the ENPH modules |
| `02_households/` | `households` | Demographics, geography and design proxies; DANE income and expenditure, terciles |
| `03_consumption/` | `consumption` | Harmonised transactions; classification, monthly factors, quantities, validity flags |
| `04_prices/` | `prices` | Household × category × market aggregates, observed unit values, price clusters, Stata files and WELCOM contract |
| `05_validate/` | `validate` | Data checks; Tables 1–2, sample flow, measurement coverage |
| `06_report/` | `report` | Shared results object, Tables 3–6 and A1–A8, figures, manuscript bundle, completeness check |
| `07_manuscript/` | `manuscript` | Renders `manuscript/manuscript.Rmd` |
| `tools/` | — | `write_renv_lock.R` |

`construct` runs `load` to `validate`. Stata runs between `construct` and `report`.
