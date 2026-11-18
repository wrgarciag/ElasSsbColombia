# Reproducibility audit and refactoring plan: beverage elasticities (ENPH 2016–17)

**Revision 2 — 2026-11-17.** This revision covers the files added since revision 1 (2026-11-12):

- `code/legacy/`: latest legacy code;
- `data/processed/DataEstimates4.dta`;
- `data/processed/DataEstimates5 (2).dta`;
- `data/interim/NomenclaturaCoicopDaneEnph.csv`.

It also reports a **replication test** (§1.6). The unmodified legacy R and Stata scripts were run against these inputs, writing only to a scratch folder.

No repository file was moved or edited except this report. Data checks report aggregates only. Software: R 4.5.1, haven 2.5.5, data.table 1.17.8, Stata 17 MP, WELCOM 2.30.

Labels used throughout:

- **[B] Blocker.** Confirmed. Stops a run or prevents reproducing the paper.
- **[E] Error or inconsistency.** Confirmed. The code runs, but the output is wrong or does not match its documentation.
- **[V] Needs verification.** The repository alone cannot settle it.
- **[OK] Checked and fine.**
- **[Fixed]** Resolved by the new files.
- **[Corrected]** Revision 1 got this wrong; corrected here.

---

## 0. Bottom line

1. **The data side now reproduces the manuscript.**
   - Run unchanged, apart from path and encoding shims (§1.6), the legacy R code rebuilds `DataEstimates4`'s **coded** beverage spending exactly for SB, beer, milk, hot drinks and spirits+wine, in all 82,934 households.
   - Feeding the supplied `DataEstimates5` through the unchanged price and `duvm` scripts reproduces **manuscript Table 2** within ±0.01 at 3,000 COP/USD: all 25 "Corrected / Full market" cells, and 24 of 25 "Corrected / Off trade" cells once its permuted consumption column is realigned.
   - `SSBElasticityPaperDescribe.do` on `DataEstimates5` reproduces **Table 1**, including the income rows.
2. **The elasticities do not reproduce.** The unchanged full-market and off-trade `duvm` scripts run end to end.
   - Expenditure elasticities come close for SB and Dairy (full-market SB 0.895 against 0.88 reported), but less so for the alcohol and water categories.
   - Own-price elasticities do not: SB is −0.44 against −0.50 (full market) and −0.47 against −0.36 (off trade), and spirits and water are further off (§1.6).

   The inputs match Table 2, so the gap is downstream of the data. Candidates, in order:
   - (a) the WELCOM version: 2.30 is installed, the paper reports 2.1;
   - (b) the cluster variable: the paper reports 354 clusters, while `substr(VIVIENDA,1,8)` gives 384;
   - (c) which `duvm` table was transcribed (with or without symmetry);
   - (d) an earlier `DataEstimates5` draw, since `mice` runs without a seed.

   No `duvm` log from the paper exists to settle this.
3. **Still missing or broken** (§1.5):
   - code that builds `GastoTotal` and the other `DataEstimates4` columns (the supplied DE4 now stands in as a frozen input);
   - code for Models 4 and 6;
   - the coded-only (Model 5) and on-trade do-files, which stop on `Gasto_Wine not found`;
   - `SSBRevisedPaper_Prices.R` and `_Codi.R`, which stop in the on-trade channel because no beer is left there;
   - seeds;
   - a `duvm` log or saved results for any published number.

   New blocker: the legacy R code fails under R ≥ 4.2 (UTF-8 sessions) unless the ENPH text is re-encoded from CP1252.
4. **Corrections to revision 1:**
   - The `DataEstimates5.dta` committed to git is **byte-identical to `DataEstimates4.dta`** (SHA-256 `7a50dad4…`). It was mislabelled; it is not a bad output of the imputation. The supplied `DataEstimates5 (2).dta` matches `SSBDImputacion.R` exactly (§2.13).
   - **No 8-character cluster mixes urban and rural households.** The 74 clusters flagged in revision 1 mix two rural `P3` codes (2 and 3, which share one label).
   - `$path` is defined in a master do-file that never calls the `duvm` scripts.
   - The tiny bootstrap SEs are real `duvm` output, not transcription errors.
5. **The measurement problems stand** and are now quantified on rebuilt output (§2):
   - every household gets a "price" for every good: 95% of beer prices are regression predictions for non-buyers;
   - the outlier and threshold rules turn 8–11% of buyers into non-buyers;
   - Capítulo C quantities are fabricated;
   - weight units are treated as liters;
   - "Dairy" means milk + hot drinks in the Corrected panel but milk only in the Codified panel;
   - every beverage record in the less-frequent-purchases module gets a monthly factor of 1, whatever its frequency (a type-coercion bug; 1,624 bimonthly-to-annual records, mostly spirits);
   - ice (012203) counts as water;
   - plant-based drinks (012209) count as SB;
   - beer recovered from text, and all on-trade alcohol, count as spirits;
   - the Model 5 "without consumption correction" comparison also changes the outlier rule (k=3 vs 1.5) and the category set.
6. **Labels.**
   - The reported "income elasticity" is a total-expenditure elasticity computed on beverage-budget shares (§2.11).
   - SB cannot be split into SSB and NSSB (§2.12).

**Urgent, separate from reproducibility.** Commit `7a51561` on `origin/main` (GitHub) still contains:

- `data/processed/DataEstimates5.dta`, a household-level microdata derivative identical to DE4;
- `docs/FP Review.pdf`, the confidential review;
- `output/old/EstimacionesV2.xlsx`, which includes licensed Euromonitor data.

The working-tree deletion of `DataEstimates5.dta` does not remove it from history. The new files `DataEstimates4.dta`, `DataEstimates5 (2).dta` and the nomenclature CSV are **not git-ignored**, so `git add .` would publish them again. `.gitignore` excludes only `/data-raw/`.

---

## 1. Inventory

### 1.1 Scripts

**Where the code lives.** The 23 R scripts in `code/legacy/` are byte-identical to those in `code/old/`. `code/legacy/` is a superset: it adds 7 Stata do-files, and its `SSBElasticityPaperRevised_total_duvm.do` differs from `code/old/` by one blank line. Keep one frozen copy (recommended: `code/legacy/`) and drop the duplicate once it is committed.

**R (`code/legacy/`).** Line numbers are unchanged from revision 1. "M0" means the script is sourced by `M0SSBElasticity.R`.

| File | Role | In M0? | Reads → writes | Status |
|---|---|---|---|---|
| `M0SSBElasticity.R` | Driver, parameters, `source()` calls | — | — → `DataEstimates.rds/.dta` (l.141–142) | [B] Hard-coded roots (l.36–49). `font_import()` (l.28) blocks `Rscript`. l.141–142 overwrite the pre-revision `DataEstimates.dta`. |
| `fclasicoicop.R` | Classifier, channel, unit and outlier functions | l.96 | — | [E] §2.4. Its text rules differ from those that built DE4 (§1.6). |
| `SSBDInput.R` | Loads the nomenclature and 15 `.sav` modules | l.100 | CSV + `.sav` → `dt_*` | [Fixed] CSV supplied. It is read from the same folder as the `.sav` files (`wdd_in`) but sits in `data/interim/`. The CSV is Latin-1 and parses fine with `fread`. `dt_coicop` is never used downstream. [OK] The stray positional `r` argument (l.27) is never evaluated. |
| `SSBDHousehold.R` | Head and household covariates | l.106 | → `Data` | [OK] keys (§2.1) |
| `SSBDIncome.R` | Person-level income | l.110 | → `Data$IT` | [V]/[E] §2.11 |
| `SSBEConsuAna.R` | Household beverage spending | l.115 | `Dt*.rds` → `DataSSB.rds` | [B] Runs before the `.rds` files exist (M0 l.127–128) |
| `SSBDEPrices.R` | Pre-revision mean prices | l.121 | → `DataPrice.csv` | [E] Comment says median, code uses p5 |
| `SSBEConsuBasesUrbano.R` | Urban modules → monthly liters and spend | l.127 | `dt_*` → `Dt*.rds`, `DtConsuUrbanoTotal.rds` | Runs (§1.6). l.4 reads DE4 into `Data`, which is never used again: a vestigial read that needs DE4 to exist and discards the `Data` built earlier. [B] under R ≥ 4.2: `tolower()` fails on CP1252 text unless re-encoded. [E] Module-15 monthly factors are coerced to 1 (l.502; §2.2). |
| `SSBEConsuBasesRural.R` | Rural modules | l.128 | → `Dt*.rds`, `DtConsuRuralTotal.rds` | Runs. [E] §2.3, §2.5. |
| `SSBConsuGasCorrected.R` | Survey totals; builds DE4 | l.130 | → `DataEstimates4.dta` | [B] Undefined objects (l.24, 27, 99, 130, 144, 172, 400, 567, 682). No code creates `GastoTotal`. DE4 is now supplied as a frozen input. |
| `SSBDImputacion.R` | Trims and imputes IT and GastoTotal (`mice`) | l.131 | DE4 → DE5 | [OK] The supplied DE5 matches its rule exactly (§2.13). [B] No seed, so DE5 cannot be regenerated identically. |
| `SSBRevisedPaper_Prices.R` | Unit values and spending by channel; Dairy merge; k=1.5/6 | l.134 | DE5 + `Dt*Total.rds` → `UnitValuePrices_*`, `UnitValueGasto_*`, `QualityAdjustedPrices_*` | Writes Total and Hogar files that reproduce Table 2 (§1.6). [B] Stops in the Fuera loop (`contrasts can be applied only to factors with 2 or more levels`) because no household has on-trade beer. The Fuera and `QualityAdjustedPrices_*` files are never written. |
| `SSBRevisedPaper_Prices_Codi.R` | Coded only; k=3; milk and hot drinks separate | l.135 | → `*_Codi.dta` | Same Fuera failure. Hogar and Total files are written. |
| `SSBRevisedPaper_PricesV2.R` | Transaction-level trimming; writes the same file names as `Prices.R` | no | — | [V] It is not the source of the 5-good files: it has no Dairy merge |
| `SSBRevisedPaper.R`, `SSBRevisedPaper_Gasto.R` | `Gasto_*`, `MeanUnitValues*`, `QualityAdjustedPrices_*` | no | DE4/DE5 → … | Feeds the QUAIDS-era do-files |
| Others (`SSBDExpenditure.R`, `SSBDPrices.R`, `SSBEConsumption.R`, `SSBEDescriptive.R`, `SSBEEPaper.R`, `SSBEBootstrap.R`, `Paper2Density.R`) | Pre-revision descriptives | no | — | [E] `SSBEDescriptive.R:4` overwrites `DataEstimates.rds` with NULL. `SSBEEPaper.R:4` is invalid. |

**Stata (`code/legacy/`).** Two families: the `duvm` scripts (these match the manuscript's method) and the QUAIDS-era scripts (`aidsills`/`quaidsce`).

| File | Purpose | Inputs | Status |
|---|---|---|---|
| `SSBElasticityPaperRevised_total_duvm.do` | Full market, Models 1–3, 5 goods | DE5, `UnitValuePrices_Total`, `UnitValueGasto_Total` | **Runs** given `$path` (§1.6). [E] Final `log close` with no open log (l.10 vs l.149). No `set seed`. |
| `…_hogar_duvm.do` | Off-trade, Models 1–3 | `…_Hogar` | **Runs** (§1.6) |
| `…_total_codi_duvm.do`, `…_hogar_codi_duvm.do` | Model 5 (coded only), 6 goods + Wine | `…_Codi` | [B] Confirmed: `variable Gasto_Wine not found`, r(111). [E] Estimates milk and hot drinks separately, while Table 3 Model 5 reports a single "Dairy". |
| `…_fuera_duvm.do` | On-trade | `…_Fuera` | [B] Input files are never produced. Also expects Wine. |
| **`SSBElasticityPaper.do`** (new) | Master for the QUAIDS pipeline | — | Defines `$pmain`, `$pcode`, `$path`, `$presu`, `$prtab` (l.16–23; William's profile). Runs `Describe.do` and `Revised_hogar.do`. **Does not call any `duvm` script.** `log close` with no open log (l.9 vs l.44). |
| **`SSBElasticityPaperDescribe.do`** (new) | Table 1 | DE5 | `estpost summarize … [aweight=FEX_C]` → `$prtab\demographics.csv`. [OK] Reproduces Table 1 (§2.13). |
| **`SSBElasticityPaperRevised.do`**, **`…RevisedQuintil.do`**, **`…Revised_fuera.do`** (new) | 8-model `aidsills` grid | DE4; region×dominio×tercile (or quintile) mean unit values; `Gasto_*` | Source of the archived Jan–Feb 2023 logs in `output/old/`. [E] Drops `FEX_C` and replaces zero budget shares with the normal pdf (l.133–137). Mills-ratio bug (l.122). "Model 4" is labelled "no quadratic" but the command includes `quadratic` (l.256 vs 260). |
| **`SSBElasticityPaperRevised_hogar.do`**, **`…_total.do`** (new) | `aidsills` + `quaidsce` | DE5, `QualityAdjustedPrices_*`, `UnitValueGasto_*` | [B] `QualityAdjustedPrices_*` is no longer produced (see `Prices.R` row). `_total.do` runs its probit loop over `i=4/7`, but `di7` is commented out, giving r(111). Mills-ratio bug (l.155). |
| **`SSBElasticityPaperNewRoutine.do`** (new) | Exploratory `quaidsce` | DE4, `QualityAdjustedPrices_Hogar`, `Gasto_Hogar` | `sample 10` without a seed (l.147). Mills-ratio bug (l.174). |
| `SSBElasticityPaperV2.do` | Pre-revision `aidsills` | `DataEstimates.dta` | [E] Mills-ratio bug (l.106, l.245) |

**Model coverage.**

| Manuscript model | Code |
|---|---|
| Model 1 (`csb(1)`) | Exists and runs |
| Model 2 (`csb(0)`) | Exists and runs |
| Model 3 (unweighted) | Exists and runs |
| Model 5 (coded only) | Exists but fails |
| Model 4 (without regional effects) | None |
| Model 6 (without rural households) | None |

The QUAIDS-era files use "Model 4" and "Model 6" for different specifications. [B]

### 1.2 Data, dictionaries and classification rules

ENPH modules, recall periods and module roles are unchanged from revision 1 (15 `.sav` files in `data-raw/enph/`). DANE's household file also contains its own `IT`.

| Supplied file | SHA-256 (first 8) | Content | Notes |
|---|---|---|---|
| `data/processed/DataEstimates4.dta` | `7a50dad4` | 82,934 × 61; dated 2022-12-13 | Identical to the `DataEstimates5.dta` in commit `7a51561`. Holds `GastoTotal`, the education dummies, `FEX_C_2`, `consumoPot`, … with no source code. Its `*_Wine` columns and text categories come from an older classifier. |
| `data/processed/DataEstimates5 (2).dta` | `3898ace4` | 82,934 × 61 | Output of `SSBDImputacion.R` (§2.13). The `" (2)"` suffix looks like a download duplicate: give it the canonical name the scripts expect and record the hash. |
| `data/interim/NomenclaturaCoicopDaneEnph.csv` | — | 1,066 eight-digit articles; Latin-1 | Reference metadata, not interim data: move it to `metadata/` or `data-raw/`. One beverage code seen in the data, 01140104 (milk subclass), is absent; it is harmless because classification uses 6 digits. |

Still missing:

- code for `GastoTotal` and the other DE4-only columns [B];
- the DANE data dictionary (the `VIVIENDA` structure is now partly decoded, §2.10);
- DANE's mensualización methodology;
- download provenance;
- the text-classification method of ref. [25];
- the source of the 3,000 COP/USD rate used in Table 2 (inferred in §1.6);
- WELCOM 2.1;
- any `duvm` log or results file from the paper.

### 1.3 Environment, versions, seeds, paths

- **R.** Every package `M0` loads is installed. The rerun used foreign 0.8-90, data.table 1.17.8, dplyr 1.1.4, tidyr 1.3.1, fixest 0.14.2, fastDummies 1.7.6, readstata13 0.11.0, mice 3.18.0 and haven 2.5.5. The 2023 versions are unknown and there is no `renv.lock`. `weighted.quantile()` (`SSBConsuGasCorrected.R`) is still unresolved.
- **New [B]: encoding.** R ≥ 4.2 on Windows runs in UTF-8. 5,701 descriptions in the urban household meals-out module are CP1252, and `ftextdrinks`' `tolower()` stops with `invalid multibyte string`. Fix: `read.spss(…, reencode = "CP1252")` (used as a shim in §1.6), or record that the original ran in a CP1252 session (R < 4.2).
- **Stata.** WELCOM **2.30** is installed (`c:/ado/plus/stata.trk`); the paper reports 2.1 [V]. A full-market run (3 models × 100 bootstrap replications) took about 9 minutes, off-trade about 3.5. `duvm` writes `bootall.dta` and `tempclus.dta` to the working directory, so set the working directory outside the repository. When launching Stata from Git Bash, `/e` is rewritten as a drive path and Stata opens an idle window; launch from PowerShell or cmd, or set `MSYS2_ARG_CONV_EXCL`.
- **Seeds: none in the legacy code.** `mice` (`SSBDImputacion.R:18`), `duvm` `boot(100)` (`bsample`, `duvm.ado:458`) and `sample 10` (`NewRoutine.do:147`) all run unseeded.
- **Paths.**
  - R: three hard-coded roots (`M0:36–44`).
  - The `duvm` do-files use `$path`, which only `SSBElasticityPaper.do` defines; that master does not call them, so they were run interactively after setting the global.
  - The QUAIDS-era do-files hard-code three Windows profiles (`William`, `wrgar`, `wgarcia`).

### 1.4 Data flow as implemented (after the new files)

```
.sav (15) ─SSBDInput (needs CP1252 re-encoding on R ≥ 4.2)─► dt_*
dt_* ─SSBEConsuBasesUrbano/Rural─► Dt*.rds, DtConsu{Urbano,Rural}Total.rds        [runs; reproduces DE4 coded spend]
   (DE4 read at Urbano l.4 is vestigial)
DtConsu*Total + {GastoTotal, covariates: NO CODE} ─SSBConsuGasCorrected─► DE4      [B: use supplied DE4 as frozen input]
DE4 ─SSBDImputacion (mice, no seed)─► DE5                                          [supplied DE5 matches the rule]
DE5 + DtConsu*Total ─Prices / Prices_Codi─► UnitValue{Prices,Gasto}_{Total,Hogar}[_Codi]  [runs; Fuera loop fails]
DE5 + UnitValue*_{Total,Hogar} ─*_duvm.do─► log only                               [runs; Table 2 matches; elasticities differ]
DE5 ─SSBElasticityPaperDescribe.do─► demographics.csv                              [Table 1 matches]
```

### 1.5 Blockers and their status

| # | Item | Status |
|---|---|---|
| B1 | No code for `GastoTotal` | **Open.** The supplied DE4 provides the values as a frozen input. |
| B2 | No code for the DE4-only covariates (education dummies, `FEX_C_2`, `consumoPot`, …) | **Open.** Values are available in DE4. |
| B3 | Undefined objects in `SSBConsuGasCorrected.R` | **Open.** Bypassed by using DE4. |
| B4 | Circular DE4 read in `SSBEConsuBasesUrbano.R:4` | **Downgraded.** Vestigial once DE4 exists. |
| B5 | `SSBEConsuAna.R` runs before its inputs exist | **Open.** Not needed for the elasticity path. |
| B6 | Nomenclature CSV missing | **Fixed.** Wrong folder relative to `wdd_in`. |
| B7 | `$path` undefined; trailing `log close` | **Partly explained.** Defined only in the QUAIDS master. |
| B8 | Codi/Fuera do-files need Wine and separate milk/hot-drink variables | **Confirmed by run:** r(111) |
| B9 | No code for Models 4 and 6 | **Open** |
| B10 | No `duvm` log or results from the paper | **Open.** Outputs are now regenerable except on-trade and Model 5. |
| B11 | `font_import()` blocks `Rscript` | **Open** (avoided by not sourcing `M0`) |
| B12 | **New:** CP1252 text fails under R ≥ 4.2 | **Open** (shim available) |
| B13 | **New:** `Prices*.R` stop in the Fuera loop (no on-trade beer) | **Open** |
| B14 | **New:** `mice` unseeded, so DE5 cannot be regenerated identically | **Open.** Keep the supplied DE5 as the frozen reference. |
| B15 | **New:** installed WELCOM 2.30 vs reported 2.1 | **Open.** Leading suspect for the elasticity gap. |

### 1.6 Replication test (2026-11-17)

**Method.** The unmodified legacy scripts were run into a scratch folder, in this order:

1. `fclasicoicop.R` → `SSBDInput.R` → `SSBEConsuBasesUrbano.R` → `SSBEConsuBasesRural.R`.
2. Comparison with DE4.
3. `SSBRevisedPaper_Prices.R` and `_Codi.R` on the supplied DE5.
4. The four `duvm` do-files in Stata batch mode.

Shims, all outside the legacy files:

- `M0`'s parameters copied into a wrapper (no `rm`, `setwd` or `font_import`);
- input and output paths;
- the nomenclature path redirected;
- `read.spss(reencode = "CP1252")`;
- in Stata: `global path`, `set seed 20261117`, a log, and a working directory in scratch.

**Saved and re-verified.** The shims are now in [`code/replication/`](../code/replication/README.md): `run_legacy.ps1` runs `run_legacy_r.R`, then `run_duvm_legacy.do`, in about 14 minutes. The original run's logs and scratch wrappers are archived in `output/replication/legacy_run_2026-11-17/`. A rerun from the repository on 2026-11-17 reproduced every result line in those logs exactly: summary statistics, elasticities, and bootstrap SEs under the same seed. Its outputs are in `output/replication/legacy_run/`. Household-level intermediates go to `data/interim/legacy_run/`, which the R script git-ignores.

**R side: rebuilt spending vs `DataEstimates4`** (82,934 households; DE4 Spirits + Wine compared with rebuilt Spirits):

| Category | Coded spend: households identical | Text-recovered spend | Combined spend: households identical |
|---|---|---|---|
| SB | 100% | 29,534 vs 28,809 text buyers | 96.3% |
| Beer | 100% | **0 vs 526 text buyers** (now classed as Spirits) | 99.4% |
| Spirits (+ Wine) | 100% | 879 vs 188 | 99.1% |
| Milk and derivatives | 100% | 4,645 vs 4,778 | 99.8% |
| Hot drinks | 100% | 23,154 vs 18,333 | 87.3% |
| Water | 98.5% (21,301 vs 20,598 buyers; likely ice, 012203, added later) | 1,455 vs 21 | 96.8% |

The coded pipeline is reproduced. The text rules (`ftextdrinks`) and the water codes changed after DE4 was built in December 2022, and DE4's Wine category was later folded into Spirits.

**Table 2 (manuscript) vs rerun.** The rerun's `sum di* ei* w* p* q* [aw=FEX_C]` output was converted at 3,000 COP/USD.

- *Corrected / Full market:* all 25 cells agree within ±0.01. Examples: SB 0.78 / 8.65 / 0.33 / 1.02 / 8.40, and Dairy 0.86 / 12.07 / 0.55 / 1.49 / 8.80.
- *Corrected / Off trade:* 24 of 25 cells agree once the consumption column is realigned.
  - SB purchase share is 0.65 in the rerun against 0.67 reported. The Codified panel reports 0.65.
  - **The Consumption column is permuted.** Stata prints `q5 q1 q3 q4 q2`, and the published Beer, Spirits and Water values (0.10, 2.79, 0.48) are the rerun's spirits, water and beer values (0.098, 2.794, 0.476).
- *Codified panels:* Beer and the "Dairy" row match the rerun's `_Codi` files exactly (e.g. off-trade 0.75 / 8.36 / 0.42 / 7.37). The Dairy row is **milk only**: hot drinks are excluded, unlike the Corrected panel. SB, spirits and water differ slightly (off-trade SB 0.67 / 4.64 vs 0.65 / 4.38), so the paper's `_Codi` files came from a somewhat different run.
- Every "Unit value" cell is the mean over all households, including the regression-imputed prices of non-buyers (§2.9).

**Elasticities: rerun vs manuscript.** Rerun own-price values come from `duvm` Table 06 (quality-corrected, no symmetry); Table 07 (with symmetry) is no closer.

Expenditure elasticities, manuscript Table 6 vs rerun (each cell: rerun / manuscript):

| | SB | Beer | Spirits | Water | Dairy |
|---|---|---|---|---|---|
| Full, Model 1 | 0.895 / 0.88 | 3.311 / 3.32 | 3.442 / 3.22 | 3.061 / 3.08 | 0.859 / 0.86 |
| Full, Model 2 | 0.887 / 0.87 | 1.313 / 1.25 | 1.333 / 1.12 | 1.146 / 1.12 | 0.833 / 0.82 |
| Full, Model 3 | 0.832 / 0.81 | 2.496 / 2.39 | 3.215 / 2.96 | 1.872 / 1.86 | 0.851 / 0.84 |
| Off, Model 1 | 0.912 / 0.88 | 3.306 / 3.52 | 4.618 / 5.31 | 2.919 / 2.04 | 0.912 / 0.89 |
| Off, Model 2 | 0.912 / 0.90 | 1.299 / 1.24 | 1.368 / 1.18 | 1.118 / 1.09 | 0.878 / 0.86 |
| Off, Model 3 | 0.772 / 0.70 | 4.094 / 1.78 | 5.487 / 4.88 | 1.149 / 1.35 | 0.830 / 0.79 |

Own-price elasticities, manuscript Table 3 vs rerun (each cell: rerun / manuscript):

| | SB | Beer | Spirits | Water | Dairy |
|---|---|---|---|---|---|
| Full, Model 1 | −0.438 / −0.503 | −0.171 / −0.174 | −0.311 / −0.767 | −2.039 / −1.473 | −0.251 / −0.286 |
| Full, Model 2 | −0.441 / −0.502 | −0.190 / −0.155 | −0.342 / −0.807 | −2.105 / −1.528 | −0.256 / −0.294 |
| Full, Model 3 | −0.387 / −0.492 | −0.427 / +1.441 | −0.363 / −0.557 | −1.749 / −1.563 | −0.223 / −0.270 |
| Off, Model 1 | −0.469 / −0.355 | −0.377 / −0.568 | −0.581 / −0.620 | −1.895 / −1.492 | −0.157 / −0.185 |
| Off, Model 2 | −0.471 / −0.348 | −0.427 / −0.590 | −0.684 / −0.709 | −2.018 / −1.521 | −0.162 / −0.190 |
| Off, Model 3 | −0.580 / −0.408 | −0.466 / −0.448 | −0.557 / −0.288 | −1.594 / −1.490 | −0.130 / −0.158 |

SB own-price elasticity by income tercile (Table 4): full market rerun −0.424 / −0.386 / −0.354 vs reported −0.522 / −0.442 / −0.428; off-trade rerun −0.371 / −0.266 / −0.255 vs reported −0.364 / −0.323 / −0.247.

**Reading the results.**

- Same inputs, same do-files: expenditure elasticities are close for SB and Dairy (within 0.07) and further off elsewhere (off-trade water Model 1: 2.92 vs 2.04; off-trade beer Model 3: 4.09 vs 1.78). Own-price elasticities are not close. Own-price elasticities depend on between-cluster price variation. That fits a different `duvm` implementation (WELCOM 2.1 vs 2.30) or a different cluster variable (354 vs 384), more than a data difference.
- Rerun bootstrap SEs are as small as the published ones (SB own-price 0.004 full / 0.006 off vs [0.003] / [0.004] published). They are `duvm` output (§2.10), not transcription errors.
- Identical SEs across goods (Table 6, off-trade SB and Beer) remain transcription errors.

---

## 2. Measurement audit

Revision 1's findings stand unless marked otherwise. This section lists what changed and the new quantification.

### 2.1 Identifiers and merge keys

- [OK] `DIRECTORIO` is the household key (87,201 unique); `VIVIENDA` is the dwelling. There is exactly one head per household, and the legacy head merge matches all households. No exact duplicate rows exist in the urban diary.
- [E] There is still no sample-flow documentation. The 4,267 excluded households (no beverage record, or 16 or more liters per adjusted member per day; `SSBConsuGasCorrected.R:34–48`) are encoded only in DE4.

### 2.2 Recall periods and monthly conversion

Unchanged from revision 1:

- the base factors (30/14 for the urban diary, 30/7 elsewhere) match the questionnaires, and the frequency codes match the `.sav` labels; the Capítulo C comments in the code are wrong;
- rescaling by stated purchase frequency understates rarer purchases about 14/30 in expectation for population totals [E];
- non-purchase acquisitions keep factor 1 [E];
- Capítulo C "Nunca" is never dropped [E].

**New [E]: the less-frequent-purchases module (15) loses its monthly factors.** `SSBEConsuBasesUrbano.R:502` initialises `FactorMensual := NA`, which creates a *logical* column. The later subset assignments of 0.5, 1/3, 1/12 and 1/6 (l.504–541) are coerced to `TRUE`, i.e. 1. data.table warns once ("0.166667 … taken as TRUE"). In the rebuilt `DtMfrecArt.rds`, every one of the 13,695 beverage records has factor 1. That includes 1,624 records reported as bimonthly, quarterly, annual or semestral (1,592 of them spirits), whose monthly spending is overstated 2–12×. All beverage records in this module fall in subchapters J11 and L11 (last-month recall). The bug is in the legacy code, so it also affects the published numbers. Fix: initialise with `NA_real_`.

### 2.3 Physical units and liters

Unchanged:

- weight units are converted to pounds and treated as liters (22.6% of urban diary beverage rows are in grams) [E];
- unit "Otra" becomes 1 liter (7.4%) [E];
- modules without a unit field assume fixed liters per unit [E];
- `festconsu` imputes both quantity and spending above 50 units [E];
- Capítulo C quantities are fabricated [E].

**Resolved [V]:** Table 2 converts COP to USD at **3,000 COP/USD**. The code holds no such constant; `v.precio = 2258` is unused. Document the rate and its source.

### 2.4 Coded and text classification

With the nomenclature now available:

| Code | DANE label | Legacy category | Finding |
|---|---|---|---|
| 012203 | **Hielo** (ice) | Water (`fclasicoicop.R:133`) | [E] Ice is not drinking water. It probably explains the extra rebuilt water buyers vs DE4 (2,866 urban diary rows). |
| 012207 | Concentrados para preparar refrescos | Excluded | [V] Sweetened powdered or concentrate drinks are left out of SB (24,930 urban diary rows). Document or include. |
| 012209 | **Bebidas a base de arroz, soya, coco, quinua, almendra** (horchata, plant yogurt) | **SB** (l.142) | [E] Plant-based drinks counted as SB (269 urban diary rows) |
| 012206 | Refrescos líquidos empacados (jugos, té frío, hidratantes) | SB | OK; packaged juices and teas sit inside SB |
| 0121xx | Café molido; chocolate en pastillas (con y sin azúcar); té en polvo | HotDrinks, then "Dairy" | Bought by weight; becomes "liters" (§2.3) |
| 0212 | Vino, champaña, jerez | Spirits | DE4 still had Wine separate |
| 11110201 | Bebidas calientes away from home (tinto, café con leche, chocolate, aromática, leche, avena) | HotDrinks | |
| 11110301 | Gaseosa y otros refrescos away from home | SB | 40 rows of water inside |
| 11110302 | Jugos naturales away from home | Not classified | Fresh juice counts toward neither SB nor anything else |
| 11110305 | Masato, mazamorra, chicha, avena helada, malteada, agua de panela fría | Not classified | Chicha can be alcoholic [V] |
| 11110601 | Bebidas alcohólicas (cerveza, aguardiente, ron) in shops and fondas | **Spirits** | On-trade beer becomes Spirits |

The rest of revision 1's §2.4 stands:

- beer recovered from text goes to Spirits (l.208);
- Capítulo C group 24 (which includes water) is all labelled SB;
- "chocolate" matches chocolatina snacks;
- rule order decides conflicting matches;
- there is no versioned rule table.

**New [E].** The text rules in the current code differ from those that built DE4 (§1.6). The Corrected numbers in the manuscript match the current rules, not DE4's `GastoTexto_*` columns.

**New [E]: inconsistent "Dairy".** In Table 2, Codified "Dairy" is milk only, while Corrected "Dairy" is milk plus hot drinks (`Prices.R:39`). The coded-only Stata scripts estimate milk and hot drinks as separate goods, while Table 3 Model 5 reports one "Dairy".

### 2.5 Double counting and fabricated records

Unchanged:

- **Urban Capítulo C:** keeps `NC2_CC_P3_S2==1`, i.e. items bought *during* the diary period. That is likely double counting: 13,880 rows in groups 8/10/22/24 [E].
- **Rural Capítulo C:** includes 9,011 "Nunca" rows, and gives SB rows a fabricated 2,500 COP [E].

### 2.6 Zeros vs missing (quantified on the rebuilt full-market files)

- [E] Outliers become zeros (`Prices.R:58–59, 91`), and spending below 100 is set to NA (l.27). Compared with buyers in the rebuilt records, the full-market `UnitValueGasto_Total` keeps 61,086 of 66,531 SB buyers (−8.2%), 4,267 of 4,653 beer buyers (−8.3%), 13,036 of 14,611 spirits buyers (−10.8%), and 20,437 of 22,179 water buyers (−7.9%). The dropped buyers enter `duvm` as non-buyers.
- [E] The universe excludes households with no beverage record (§2.1).

### 2.7 Weights

Unchanged:

- terciles and imputation are unweighted: DE5's sample terciles carry 37% / 31% / 32% of the weighted population [E];
- `FEX_C_2` (integer weights) has no source code [V].

### 2.8 Purchase channels

Unchanged, plus:

- **New [E]:** no household has on-trade beer (0 records). Beer in shops (11110601) and beer recovered from text are both Spirits, so on-trade price imputation fails (B13).
- On-trade elasticities for spirits mix beer, wine and spirits.

### 2.9 Unit values and the price passed to `duvm` (quantified)

- [E] In the rebuilt `UnitValuePrices_Total`, all 82,934 households have a price for every good. Non-buyers with a regression-imputed price: SB 21,848; beer 78,667 (95%); spirits 69,898; water 62,497; Dairy 13,260. `duvm`'s first stage (`duvm.ado:281`) treats them as observed unit values. Deaton's estimator uses unit values only for buyers.
- [Fixed] DE5 has IT ≥ 1,000, so the `log(IT)` problem (−Inf for IT = 0) affects DE4 only.
- [E] The quality-adjusted price block (`Prices.R:217–452`) misaligns rows. It now never runs, because the script stops earlier.

### 2.10 Price clusters vs survey PSUs

- [Corrected] **No 8-character cluster mixes urban and rural households.** In the full ENPH, 0 of 384 clusters contain both `P3=1` (cabecera) and `P3∈{2,3}`. In DE5, 237 clusters are urban and 147 rural. The 74 clusters flagged in revision 1 mix `P3` codes 2 and 3, which share the label "Centros poblados y rural disperso", and so span two DOMINIO values. `region(x3)` is constant within clusters. [OK]
- `VIVIENDA` structure: the first 5 characters are the DIVIPOLA municipality code (178 municipalities), followed by `|` and digits. The 8-character cluster is therefore municipality plus a 2-digit sub-area: median 49 households, maximum 1,125. A 10-character prefix gives 8,454 groups in DE5.
- [V] **354 vs 384 clusters.** None of the definitions tested yields 354:
  - prefixes of 7, 8 or 9 characters give 325, 384 and 1,078;
  - clusters with at least 10 households: 374; with at least 20: 339;
  - urban clusters only: 237.

  Recover the cluster variable actually used. Deaton's method needs clusters within which households face a common price; the cluster is also `duvm`'s bootstrap unit.
- [E, methodological] `duvm`'s bootstrap resamples cluster-level aggregates (`tempclus`, `duvm.ado:446–549`) with the first stage held fixed. This explains the very small SEs (0.001–0.006), which understate uncertainty.

### 2.11 Expenditure vs income elasticities, and the share definition

Unchanged:

- `expend(exptotal)` is `GastoTotal` (log total household expenditure). In the paper's runs this is DE5's imputed and trimmed version, with 1,690 households imputed. Relabel "income" as "expenditure".
- Shares are beverage-budget shares while the regressor is total expenditure. The resulting expenditure elasticity equals η_g − η_bev + 1, net of the quality term. Choose an unconditional or a conditional specification [E].
- `GastoTotal` has no source code [B1].

### 2.12 Can SB be split into SSB / NSSB?

No; unchanged. Among 141,145 SB-like free-text records, 4 mention zero, light, diet or sin azúcar. The nomenclature confirms that COICOP describes product type, not sweetener. The label "chocolate con y sin azúcar" for hot chocolate is the only explicit sweetener reference.

### 2.13 Reconciling the manuscript

| Item | Manuscript | Evidence (rev. 2) | Status |
|---|---|---|---|
| N | 82,934 | DE4 = DE5 = 82,934 | Matches |
| Table 1 demographics | 0.63 … 0.21 | DE5 weighted: identical | Matches (row labels shifted down one row in the PDF) |
| Table 1 income | 1,814,759 (SD 1,903,735), min 1,000, max 12.9M; per member 668,827 (SD 890,345), 200–12.8M | DE5: 1,814,759 (SD 1,903,735 with Stata's N/(N−1) factor), 1,000–12,861,000; 668,827 (SD 890,345), 200–12,825,000 | **[Fixed] Matches** via `SSBElasticityPaperDescribe.do` |
| DE5 provenance | — | DE4 → DE5 changes exactly the households flagged by `SSBDImputacion.R`: IT 1,809, GastoTotal 1,690 (below 1,000 or outside 6×IQR). Terciles recompute exactly. 1 household has `Quintil` NA (the top value; `cut(right=FALSE)`). | [OK] (unseeded) |
| Table 2 Corrected | Full market and off-trade | Rerun matches within ±0.01; off-trade consumption column permuted; off-trade SB purchase proportion 0.65 vs 0.67 | Mostly matches (§1.6) |
| Table 2 Codified | — | Beer and milk match the `_Codi` files; "Dairy" is milk only; SB, spirits and water differ slightly | Partly matches |
| Table 3 own-price | Models 1–6 | Models 1–3 rerun, not matching; Model 5 fails; Models 4 and 6 have no code | **Not reproduced** |
| Table 4 terciles | — | Rerun differs (SB full −0.42 vs −0.52) | Not reproduced |
| Table 5 cross-price | — | Rerun matrices differ; orientation still undocumented (rows/columns of `duvm` output) | Not reproduced; [V] orientation |
| Table 6 expenditure | Models 1–6 | Models 1–3: SB and Dairy within 0.07; beer and water within 0.12 in the full market; spirits off by 0.2–0.7; off-trade water Model 1 2.92 vs 2.04; off-trade beer Model 3 4.09 vs 1.78 | Close for SB/Dairy only |
| SEs | Very small | Rerun SEs equally small (`duvm` bootstrap design) | Real output; methodological issue (§2.10) |
| Clusters | 354 | 384 | **Mismatch** [V] |
| WELCOM | 2.1 | 2.30 installed | **Mismatch** [V], leading suspect |
| Model 5 comparison | "without consumption correction" | Also changes outlier k (3 vs 1.5) and the category set (milk and hot drinks separate) | [E] Confounded |
| Abstract vs Table 5 | "substitution toward alcohol supported" | Negative cross-price elasticities | Inconsistent |

---

## 3. Proposed structure

The target layout is unchanged from revision 1, with these adjustments for the new files:

```
code/legacy/                 # single frozen copy of the legacy code (remove the code/old duplicate after committing)
code/replication/            # wrapper shims that run code/legacy unchanged (R wrapper + Stata run_*.do)
data/processed/legacy/       # DataEstimates4.dta, DataEstimates5.dta (canonical name), with SHA-256 in metadata/input_manifest.csv
metadata/coicop_nomenclature.csv   # from data/interim/NomenclaturaCoicopDaneEnph.csv, converted to UTF-8, original kept
```

The rest of the target tree is as in revision 1:

```
config/ (paths.yml, params.yml, specs.csv)
metadata/ (input_manifest.csv, enph_modules.csv, category_map.csv, text_rules.csv, frequency_factors.csv,
           unit_conversions.csv, data_dictionary.md)
data-raw/ (immutable ENPH) · data/interim/ · data/analysis/ · data/external/   (all git-ignored)
code/R/   00_run.R · lib/ · 01_load/ · 02_clean/ · 03_build/ · 04_describe/
code/stata/ 00_master.do · 00_setup.do · ado/ · 10_replicate/ · 20_estimate/ · 30_robustness/ · 40_tables/
output/ tables/ figures/ logs/<run_id>/ replication/ old/
docs/ · manuscript/ · renv.lock
```

### 3.1 Mapping legacy files to the new layout

| Legacy (`code/legacy/`) | New location | Notes |
|---|---|---|
| `M0SSBElasticity.R` parameters | `config/params.yml`, `code/R/00_run.R` | No `font_import()` |
| `fclasicoicop.R` | `lib/classify.R`, `lib/units.R`, `lib/outliers.R`; `metadata/category_map.csv`, `text_rules.csv` | Version the text rules; DE4 used an older set |
| `SSBDInput.R` | `01_load/01_import_enph.R` | Read with explicit `reencode="CP1252"` |
| `SSBDHousehold.R`, `SSBDIncome.R` | `02_clean/02a_household.R`, `02b_income.R` | Reconcile with DANE `IT` |
| *(missing)* | `02_clean/02c_total_expenditure.R` | Rebuild `GastoTotal`; validate against DE4 |
| `SSBEConsuBasesUrbano.R`, `…Rural.R` | `02_clean/02d_beverage_records.R` | Drop the vestigial DE4 read |
| `SSBConsuGasCorrected.R` | `03_build/03a_universe.R` + `04_describe/04a_descriptives.R` | |
| `SSBDImputacion.R` | `02_clean/02c_total_expenditure.R` | Seeded and weighted |
| `SSBRevisedPaper_Prices*.R` | `03_build/03b_unit_values.R`, `03c_clusters.R`, `03d_export_stata.R` | One parameterised script; must not fail when a channel has no buyers |
| `SSBElasticityPaperDescribe.do` | `code/stata/40_tables/table1.do` | Already reproduces Table 1 |
| `*_duvm.do` | `code/stata/10_replicate/` | Add seed, path, saved matrices; fix Codi/Fuera |
| QUAIDS-era do-files (`SSBElasticityPaper.do`, `…Revised*.do`, `…NewRoutine.do`, `V2`) | Stay in `code/legacy/` | Not the manuscript's method |

Stage contracts and execution order are as in revision 1, §3.2. The replication stage S5 may start from the frozen DE4 and DE5 until B1 and B2 are closed.

---

## 4. Prioritized plan

### Phase 0: Containment

1. Check the visibility of the GitHub repository. If it is public or shared, purge `data/processed/DataEstimates5.dta`, `docs/FP Review.pdf` and `output/old/EstimacionesV2.xlsx` from history.
2. Add `data/**/*.dta`, `data/**/*.rds`, `data/interim/*.csv`, `docs/*Review*` and the licensed spreadsheets to `.gitignore` **before** any `git add`.
3. Commit `code/legacy/` (code only), remove the `code/old/` duplicate, and tag the state as `legacy-2023`.
4. Rename the DE5 file to its canonical name. Record SHA-256 hashes for DE4, DE5, the nomenclature and every `.sav` in `metadata/input_manifest.csv`.

### Phase 1: Restore the original run

**Now feasible for Models 1–3; the run in §1.6 is the baseline.**

1. **Run recipe — done (2026-11-17).** `code/replication/` holds the R and Stata drivers and a PowerShell launcher, and a rerun reproduced the archived results exactly. What remains is to commit it, together with `output/replication/`, which contains aggregates only.
2. **Recover what blocks exact elasticities:**
   - WELCOM 2.1 (`duvm.ado`), or the version actually used;
   - the cluster variable that gives 354;
   - any `duvm` log or Excel output behind Tables 3–6, and which `duvm` table was transcribed (06 or 07);
   - the code that builds `GastoTotal` and the other DE4 columns;
   - Model 4 and Model 6 code;
   - the classifier version that kept Wine separate (it is needed by the Codi and Fuera do-files);
   - the `_Codi` files behind Table 2's Codified panel.
3. **Rerun Models 1–3 with WELCOM 2.1** and with the recovered cluster variable, then compare again.
4. **Checkpoints:**
   - **C1.** N = 82,934 (passed).
   - **C2.** Table 1 (passed).
   - **C3.** Table 2 Corrected (passed, apart from the transcription errors).
   - **C4.** Clusters: 354 explained.
   - **C5.** Model 1 own-price and expenditure elasticities within ±0.01 of the manuscript.
   - **C6.** Models 2–6.
5. **If C5 cannot be met,** treat the reconstructed run as the reference, document each discrepancy, and explain the change in the response letter.

### Phase 2: Reconcile the manuscript tables

- Generate every table from code (`duvm` matrices → `40_tables/`).
- Fix the Table 1 row labels, the permuted Table 2 consumption column and the Codified "Dairy" definition. Document the 3,000 COP/USD rate.
- State matrix orientation (rows = responding quantity, columns = price), Marshallian or Hicksian, and conditional or unconditional. Relabel "income" as "expenditure".
- Document the sample flow, the cluster definition and the category contents: "Dairy" includes hot drinks; on-trade "Spirits" includes beer and wine; ice counts as water; plant-based drinks count as SB.
- Make Model 5 a clean comparison: same outlier rule and same goods as Model 1.

### Phase 3: Refactor while preserving results

As in revision 1. The regression targets are now concrete:

- coded spending equal to DE4;
- Table 1 equal to DE5;
- Table 2 equal to the §1.6 rerun;
- `duvm` point estimates identical to the §1.6 logs given the same inputs and seed.

### Phase 4: Methodological updates

Order as in revision 1:

1. Make shares and expenditure consistent.
2. Unit values for buyers only.
3. Zeros vs missing.
4. Capítulo C.
5. Units.
6. Recall periods.
7. Categories, now also: drop ice from water, decide on plant-based drinks and on concentrates (012207), map text beer to Beer, and let on-trade beer exist.
8. Clusters.
9. Inference: a bootstrap that re-estimates the first stage, more replications, seeds.
10. Selection.
11. Models 4 and 6.

### Proposed master execution

From the repository root, in PowerShell or cmd (not Git Bash, which rewrites `/e`):

```bash
Rscript code/R/00_run.R all --mode legacy
```

```bash
"C:/Program Files/Stata17/StataMP-64.exe" /e do code/stata/00_master.do all legacy
```

Each run writes `output/logs/<run_id>/manifest.json` with the git commit, a config hash, input SHA-256s, R/package/Stata/WELCOM versions and seeds. Set Stata's working directory to `output/logs/<run_id>/` so `duvm`'s `bootall.dta` and `tempclus.dta` stay out of the source tree.
