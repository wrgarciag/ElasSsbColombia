# Elasticities of Alcoholic and Sweetened Beverages in Colombia

Analysis repository for **Revisiting Elasticities of Alcoholic and Non-alcoholic Beverages in Colombia** (Norman Maldonado and William García). It builds beverage purchases, unit values and budget shares from the ENPH 2016–2017 household budget survey, estimates own-price, cross-price and expenditure elasticities with WELCOM's Deaton unit-value model, and renders the manuscript from the saved estimates.

- **R** loads the survey, builds and validates the data, and produces tables, figures and the manuscript.
- **Stata** only estimates: it runs WELCOM's `duvm` on analysis-ready files and exports estimates and inference.

This is a new pipeline, not a replication of the earlier estimates. The earlier revision plan is kept in `dev/README.md`; the legacy code is frozen in `code/legacy/` (and `code/old/`), with a wrapper that reruns it unchanged in `code/replication/`.

## Run

From PowerShell (not Git Bash, which rewrites Stata's `/e` flag):

```powershell
powershell -ExecutionPolicy Bypass -File run_pipeline.ps1 -Stage all -RunId 20261117a
```

`all` runs the seven stages below in order. `-Stage` also takes one stage or a comma-separated list, run in the order given; `-Workers <n>` overrides the number of parallel bootstrap instances (`parallel_workers` in the configuration, 12).

| Stage | What runs | Time on the development machine |
|---|---|---|
| `construct` | `Rscript code/R/00_run.R construct`: inventory, import, households, purchases, unit values, Stata files, checks, Tables 1–2 | 6 min |
| `check` | Stata: `duvm` on simulated data with a known price response; stops if the matrix orientation (rows = quantity, columns = price) is wrong; result in `output/diagnostics/<run_id>/welcom_orientation_check.csv` | 15 min for `check` and `point` together |
| `point` | Stata: one `duvm` call per model in `config/models.csv` (32 models: M1–M6, terciles T1–T3, sensitivity S1–S7, each for the off-trade and combined markets) | |
| `bootstrap` | Stata: external cluster bootstrap, 12 parallel instances, resumable | about 8 hours for the full run (about 75 main replications an hour) |
| `inference` | Stata: standard errors, percentile intervals, covariance matrices | 2 min |
| `report` | `Rscript code/R/00_run.R report`: Tables 3–6 and A1–A8, figures, completeness check, manuscript bundle | 1 min |
| `manuscript` | `Rscript code/R/00_run.R manuscript`: `manuscript/manuscript.Rmd` → PDF | 1 min |

The bootstrap writes one file per replication, so it can be stopped and restarted with the same command, and `inference` + `report` + `manuscript` can be run on the replications completed so far (the tables state how many were used). Changing anything that alters the estimation files in `data/processed/estimation/` invalidates existing replications: delete them before rerunning.

Individual R stages: `Rscript code/R/00_run.R <load|households|consumption|prices|validate|report|manuscript> --run-id=<id>` (`construct` runs `load` to `validate`). Individual Stata stages: `StataMP-64.exe /e do code/stata/00_master.do "<root>" <run_id> <check|point|boot|inference>`; batch Stata returns no exit code, so each stage writes `output/logs/<run_id>/stata_<stage>.ok` on success and the wrapper checks it. There are no unit tests: `validate`, `check` and the completeness check at the end of `report` are the checks.

**Current run.** `20261117a` has run every stage. The bootstrap was stopped after the first pass at the authors' request: 100 replications for the 18 main and tercile models and 4 for the 14 sensitivity models, against a target of 500 (`docs/blockers.md`, B-4). Standard errors in Tables 3–6 are therefore preliminary, and Tables A3–A4 report point estimates only. To resume:

```powershell
powershell -ExecutionPolicy Bypass -File run_pipeline.ps1 -Stage bootstrap,inference,report,manuscript -RunId 20261117a
```

Standalone manuscript render, after `report`:

```powershell
Rscript -e "rmarkdown::render('manuscript/manuscript.Rmd', params = list(run_id = '20261117a'), output_dir = 'output/manuscript/20261117a')"
```

The render stops if the bundle for that run is missing, belongs to another run, was built with a different `config/config.yml` or `config/models.csv`, or is incomplete or lacks bootstrap inference. For a draft, set `ALLOW_INCOMPLETE=1` before the `manuscript` stage (or pass `allow_incomplete = TRUE` in `params`).

### Setup

1. Put the ENPH `.sav` modules in `data-raw/enph/` (file names in `metadata/enph_modules.csv`).
2. Copy `config/local.example.yml` to `config/local.yml` and set the Stata and Rscript executables, the pandoc folder and a local scratch folder for Stata.
3. Software used: R 4.5.1 with the packages in `renv.lock`; Stata 17 MP; WELCOM 3.60 and estout, pinned in `code/stata/ado/` (no installation needed; see `code/stata/ado/WELCOM_VERSION.md`); TinyTeX with `booktabs`, `threeparttable`, `float`, `caption`, `setspace`, `pdflscape`; pandoc (the copy shipped with RStudio works).

`renv.lock` was written from the installed library by `code/R/tools/write_renv_lock.R` without installing `renv`. The pipeline never installs or updates R, Stata or LaTeX packages. Python is needed only for `code/R/tools/write_alternatives_register.py`, which regenerates `metadata/alternatives_register.csv` and `docs/estimation_alternatives.md`.

## Layout

| Path | Contents |
|---|---|
| `config/config.yml` | Paths, parameters, seeds, replication counts. `config/models.csv`: model registry. `config/local.yml`: machine-specific, git-ignored. `config/stata_params.do`: generated from the two YAML files for Stata |
| `metadata/` | Input manifest with checksums, module registry, COICOP and text classification rules, Capítulo C groups, frequency factors, unit conversions, variable dictionary, price-cluster definitions, table registry, alternatives register |
| `data-raw/` | ENPH modules and questionnaires (immutable, git-ignored) |
| `data/interim/01_import` … `04_prices` | Typed imports; households; classified transactions; household × category aggregates (git-ignored) |
| `data/processed/estimation/` | Analysis-ready `.dta`/`.rds` files, dictionary and WELCOM contract (git-ignored) |
| `data/processed/bootstrap/`, `estimation_samples/`, `manuscript/<run_id>/`, `stata_work/` | Bootstrap replications, sample identifiers, manuscript bundle, Stata working folders (git-ignored) |
| `code/R/lib/` | Functions without side effects |
| `code/R/01_load` … `07_manuscript` | Stages, in order |
| `code/R/tools/` | `write_renv_lock.R`, `write_alternatives_register.py` |
| `code/stata/` | `00_master.do`, setup, WELCOM wrappers, point estimates, bootstrap worker, inference, orientation check |
| `code/stata/ado/` | Pinned WELCOM and estout with checksums |
| `code/legacy/`, `code/old/` | Frozen legacy code (not edited) |
| `code/replication/` | Reruns the legacy code unchanged (`run_legacy.ps1`); outputs in `output/replication/`. See its README |
| `output/estimates/<run_id>/` | Point estimates, SEs, CIs, covariance matrices, model metadata |
| `output/diagnostics/<run_id>/` | Classification, units, Capítulo C, clusters, validation checks |
| `output/tables/<run_id>/`, `output/figures/<run_id>/` | Tables (CSV and LaTeX) and figures |
| `output/manuscript/<run_id>/` | Rendered PDF and `.tex` |
| `output/logs/<run_id>/` | R and Stata logs, stage manifests (git-ignored) |
| `output/old/` | Outputs of the legacy estimation |
| `manuscript/` | `manuscript.Rmd`, `preamble.tex`, `references.bib`; LaTeX scratch in `_render/` (git-ignored) |
| `reports/` | Beamer preamble and APA citation style for slides |
| `docs/` | Methods, WELCOM note, corrections log, legacy map, alternatives, blockers, earlier manuscript, DANE ENPH methodology |
| `dev/` | Earlier revision plan and the briefs that produced the pipeline (historical) |

## What the pipeline produces

| Table | Content | Source |
|---|---|---|
| 1 | Household demographics | R |
| 2 | Purchase prevalence, spending, shares, unit values, quantities; four panels | R |
| 3 | Own-price elasticities, six specifications, off-trade and combined | WELCOM |
| 4 | Own-price elasticities by income tercile | WELCOM |
| 5 | Own- and cross-price matrices (rows = quantity, columns = price) | WELCOM |
| 6 | Expenditure elasticities, six specifications | WELCOM |
| A1–A8 | Sample flow, measurement coverage, seven further sensitivity analyses, price clusters, model summary, confidence intervals, WELCOM's own bootstrap output | R and WELCOM |

Categories: SB, beer, spirits and wine, water, dairy drinks, hot drinks. Estimates are uncompensated price elasticities and elasticities with respect to total household expenditure, both unconditional on the beverage budget. `output/tables/<run_id>/table_completeness.csv` lists every required cell and its status.

## Documentation

| File | Purpose |
|---|---|
| `docs/methods.md` | What the data construction and estimation do |
| `docs/welcom_method.md` | What `duvm` estimates, its input contract, how it is called and why inference is external |
| `docs/corrections_log.md` | Every data-construction correction against the legacy code |
| `docs/legacy_to_new_map.md` | Where each legacy operation went |
| `docs/estimation_alternatives.md`, `metadata/alternatives_register.csv` | Estimator-level improvements flagged for later; none is implemented |
| `docs/blockers.md` | Unresolved blockers |
| `docs/reproducibility_audit.md` | Audit of the legacy pipeline that preceded this work |
| `docs/Paper_20_1012_ElasticiBeverages.pdf` | Earlier version of the manuscript (source of the legacy tables) |
| `docs/DSO-ENPH-MET-001-V2.pdf` | DANE's ENPH methodology |

## Data protection

Microdata, household-level intermediates, estimation samples, bootstrap files, logs, `config/local.yml` and the review documents are git-ignored. Outputs under `output/estimates`, `output/tables`, `output/figures` and `output/diagnostics` are aggregates. Commit `7a51561` on `origin/main` still contains a household-level file, the confidential review and a licensed spreadsheet (see `docs/blockers.md`); the pipeline does not rewrite Git history.
