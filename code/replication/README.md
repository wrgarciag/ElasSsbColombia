# Legacy replication

These scripts rerun the legacy pipeline in `code/legacy/` **unchanged**, so its outputs can be compared with the manuscript. They are the Phase 1 baseline described in [docs/reproducibility_audit.md](../../docs/reproducibility_audit.md), §1.6. They do not fix any of the problems the audit lists. They only provide what the legacy scripts expected from the original machines.

## Run

From PowerShell or cmd, not Git Bash (Git Bash rewrites Stata's `/e` flag):

```bash
powershell -ExecutionPolicy Bypass -File code\replication\run_legacy.ps1
```

This takes about 14 minutes: about 6 for R and 8 for Stata. A rerun on 2026-11-17 reproduced every result line in the archived logs in `output/replication/legacy_run_2026-11-17/`. You can also run the two halves separately:

```bash
Rscript code/replication/run_legacy_r.R
```

```bash
"C:/Program Files/Stata17/StataMP-64.exe" /e do code/replication/run_duvm_legacy.do
```

Run the Stata half from the repository root, or pass the root path as the do-file's argument. Override the executable paths with `RSCRIPT_EXE` and `STATA_EXE`.

## Inputs (not in git)

| File | Notes |
|---|---|
| `data-raw/enph/*.sav` | ENPH 2016–17 modules |
| `data/interim/NomenclaturaCoicopDaneEnph.csv` | COICOP nomenclature (Latin-1) |
| `data/processed/DataEstimates4.dta` | Frozen. No code builds it (`GastoTotal` and several covariates have no source). |
| `data/processed/DataEstimates5.dta` | Frozen. `SSBDImputacion.R` builds it with an unseeded `mice`, so it cannot be regenerated identically. `DataEstimates5 (2).dta` is also accepted. |

Software used on 2026-11-17: R 4.5.1 (packages in `output/replication/legacy_run/sessionInfo.txt`), Stata 17 MP, and WELCOM 2.30 installed in `c:/ado/plus`. The manuscript reports WELCOM 2.1.

## What the scripts do

`run_legacy_r.R` sources `fclasicoicop.R` → `SSBDInput.R` → `SSBEConsuBasesUrbano.R` → `SSBEConsuBasesRural.R`. It then compares the rebuilt spending with `DataEstimates4`, and finally runs `SSBRevisedPaper_Prices.R` and `SSBRevisedPaper_Prices_Codi.R`. Its shims, all outside the legacy files:

1. It copies the parameters from `M0SSBElasticity.R` (l.59–91) instead of sourcing it, because `M0` runs `rm(list=ls())`, `setwd()` and an interactive `font_import()`.
2. It points the input path at `data-raw/enph/` and redirects the nomenclature path to `data/interim/`.
3. It reads the `.sav` files with `reencode = "CP1252"`. Without this, `ftextdrinks()` fails under R ≥ 4.2 with "invalid multibyte string".
4. It copies `DataEstimates4/5` into `data/interim/legacy_run/`, where the legacy scripts look for them.

`run_duvm_legacy.do` runs the four `*_duvm.do` files. It sets `global path`, `set seed 20261117` before each file, a working directory in `data/interim/legacy_run/stata_work/` (where `duvm` writes `bootall.dta` and `tempclus.dta`), and one log per file.

## Outputs

| Path | Content | Commit? |
|---|---|---|
| `data/interim/legacy_run/` | Household-level `.rds`/`.dta` intermediates | **No.** A `.gitignore` written by the R script excludes them. |
| `output/replication/legacy_run/` | `r_run.log`, `de4_comparison.csv`, `stage_results.txt`, `sessionInfo.txt`, `duvm_*.log` | Aggregates only |
| `output/replication/legacy_run_2026-11-17/` | Archived baseline from the audit run, plus the original scratch wrappers | Aggregates only |

## Expected results (2026-11-17 baseline)

- **Coded spending** in `de4_comparison.csv` is identical to `DataEstimates4` for SB, beer, milk, hot drinks and spirits (+ DE4's Wine) in all 82,934 households. Coded water differs for 1.5% of households.
- **Text-recovered spending differs** from `DataEstimates4`: the text rules changed after December 2022.
- **Both `Prices` scripts stop in the Fuera loop** ("contrasts can be applied only to factors with 2 or more levels") because no household has on-trade beer. The Total and Hogar files are written before the error. `stage_results.txt` records this as an error, and the run continues.
- **`duvm_total.log` and `duvm_hogar.log`** run Models 1–3. Their `sum di* ei* w* p* q*` output reproduces manuscript Table 2 (Corrected panels) at 3,000 COP/USD.
- **Elasticities do not match** manuscript Tables 3–6. See the audit, §1.6.
- **`duvm_total_codi.log` and `duvm_hogar_codi.log`** stop with `variable Gasto_Wine not found` (r(111)).
