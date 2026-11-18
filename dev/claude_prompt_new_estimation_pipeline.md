# Claude Code prompt: build a new reproducible beverage-elasticity pipeline

Implement a new, adequate, end-to-end estimation pipeline for alcoholic and sweetened beverage demand in Colombia using ENPH 2016–2017. **This is no longer a replication exercise.** The primary outcome is a complete set of revised paper tables and estimates. Deliver working code and run it as far as available inputs and software allow; do not stop at an audit or proposed structure. Use the manuscript, latest reproducibility audit, `M0SSBElasticity.R`, its sourced scripts, and available documentation as context. This instruction supersedes the replication-first objective in earlier planning documents.

**Econometric estimation uses the WELCOM Stata routine for Deaton's unit-value model, as in the original analysis.** WELCOM is the primary and only estimator for the tables and manuscript in this round. Potential estimator-level improvements or corrections are identified, documented and flagged for later work, not implemented as primary results now (see *Alternatives register*).

## Objective and preservation of logic

Preserve the full substantive scope and all valid processing logic: survey-module coverage, coded and text-recovered purchases, urban/rural households, purchase channels, consumption, expenditure, demographics, income, and relevant beverage categories. Trace each legacy operation into the new pipeline; do not silently omit a module, variable, adjustment, or sample restriction. Preserve intended logic rather than confirmed coding errors in data construction or in how the estimator is called. Document every correction, its rationale, and the affected variables or estimands. Do not force agreement with old manuscript estimates, reproduce bugs for compatibility, or build a parallel legacy-replication mode.

Distinguish two kinds of issues:

- **Data-construction and calling-side errors** (e.g., wrong merges, unit conversions, classification, mismatched variables passed to WELCOM, wrong cluster or weight variable, misused options): correct them now.
- **Estimator-level methodological concerns** (how WELCOM itself treats zeros, weights, quality, clusters, selection or inference): keep WELCOM's behavior, document the concern, and record it in the alternatives register for later.

Inspect the current repository first. Keep raw inputs and archived code/results intact. Implement the new pipeline under `code/`, and update the README to describe the actual implementation. Use project-relative paths and one configuration source; support machine-specific Stata executable paths through a git-ignored local override.

## Required separation and folders

**R handles all input loading, data construction, cleaning, descriptive statistics, validation, and final reporting. Stata handles econometric estimation with WELCOM and associated inference only.** Stata should read analysis-ready files, validate their contract, run WELCOM, and export machine-readable estimates, covariance matrices (where available), diagnostics, and estimation-sample identifiers. Do not repeat survey merges, classification, quantity conversions, or demographic construction in Stata. Transformations, selection equations, quality adjustments and inference performed internally by WELCOM stay with WELCOM.

Use this nested structure, adapting names only where existing conventions make it necessary:

| Folder | Purpose |
| --- | --- |
| `config/` | Paths, parameters, seeds, model specifications, and local overrides |
| `metadata/` | Input manifest, variable dictionary, module/recall mappings, classification rules, unit conversions, alternatives register |
| `data-raw/` | Existing immutable raw inputs; retain their current location |
| `data/interim/01_import/` | Typed module imports |
| `data/interim/02_households/` | Demographics, design variables, income, total expenditure |
| `data/interim/03_consumption/` | Harmonized and classified transaction-level records |
| `data/interim/04_prices/` | Quantity/expenditure aggregates and observed unit values |
| `data/processed/` | Final analysis-ready `.dta` and `.rds` files plus dictionaries |
| `code/R/lib/` | Reusable functions without execution side effects |
| `code/R/01_load/` | Input inventory and import |
| `code/R/02_households/` | Demographics, income, total expenditure, survey design |
| `code/R/03_consumption/` | Harmonization, classification, quantities and purchase aggregation |
| `code/R/04_prices/` | Observed unit values, price-cluster definitions, estimation exports |
| `code/R/05_validate/` | Data checks, descriptive statistics, sample flow |
| `code/R/06_report/` | Tables and figures from exported estimates |
| `code/stata/` | Master, setup, WELCOM wrappers, main specifications, robustness and inference |
| `code/stata/ado/` | Pinned, project-local copy of WELCOM and its dependencies |
| `output/estimates/<run_id>/` | Point estimates, SEs, CIs, covariance matrices and model metadata |
| `output/diagnostics/<run_id>/` | Classification, missingness, units, clusters, exclusions, estimation diagnostics |
| `output/tables/<run_id>/` | Descriptive, elasticity and sensitivity tables |
| `output/figures/<run_id>/` | Generated figures |
| `output/logs/<run_id>/` | R/Stata logs and execution manifest |
| `docs/` | Methods, decisions, legacy-to-new mapping, alternatives register and remaining limitations |

Keep household-level estimation samples and bootstrap intermediates under git-ignored `data/` subfolders, not public aggregate outputs. Update `.gitignore` for raw/interim/processed data, local configuration, licensed inputs and logs. Do not delete files or rewrite Git history as part of this task.

## R implementation requirements

1. Inventory real files and dependencies; record source/version, checksums and missing inputs. Repair execution order and circular dependencies. Eliminate interactive font setup, global workspace dependence and duplicate writers.
2. Import modules with labels and stable household/person/transaction keys. Validate merge cardinalities and prevent duplicate purchases across household and personal modules. Retain provenance and transformation flags.
3. Build demographics, education, household composition, design weights, strata and PSUs explicitly from documented source variables. Separate design PSUs from price clusters. Construct income and total expenditure independently, reconciling against DANE aggregates where available. Do not invent `GastoTotal` or recover undocumented variables by arbitrary imputation.
4. Harmonize recall periods using module-specific questionnaires and DANE methodology. Distinguish physical quantities, spending, frequency and purchase form. Use defensible conversions; do not assume every unspecified unit is one liter, mix kilograms with liters, or manufacture prices from expenditure assumptions.
5. Version COICOP and text rules. Correct beer-versus-spirits classification; distinguish dairy from hot drinks. Include wine only if identifiable. Keep SB where ENPH cannot identify SSB separately from NSSB; do not infer sugar content from absent information.
6. Handle Capítulo C explicitly: respect non-purchase responses, avoid fabricated quantities/spending and double counting, and exclude records without defensible physical quantities from unit values while retaining valid expenditure information where appropriate.
7. Preserve true zeros, distinguish missing/invalid quantities, and retain the eligible household universe. Flag and report outliers rather than recoding them to zero. Export observed unit values only for valid positive purchases; never treat imputed non-buyer unit values as observed prices.
8. Build home, away-from-home and combined-market datasets with explicit coverage limits and no summing of overlapping markets. Prepare all regressors, outcomes and identifiers needed by Stata, with named units and denominators.
9. **Export inputs in exactly the form WELCOM's documented syntax requires.** Derive the input contract from WELCOM's help file and source (variable types, how non-buyers' shares and unit values must be coded, cluster/weight/stratum variables, expenditure variable). If WELCOM needs a value R would not otherwise produce (e.g., a placeholder for non-buyer unit values), create it as a clearly named, WELCOM-specific field, document it, and keep it out of all descriptive statistics.

## Econometric estimation: WELCOM as the primary estimator

Use Deaton's unit-value framework as implemented in WELCOM for all estimates in Tables 3–6 and the manuscript.

- **Pin and document WELCOM.** Identify the exact WELCOM command(s) used by the legacy Stata step, install them in `code/stata/ado/`, record version, source and checksums, and do not update silently. Do not modify, patch, or replace WELCOM internals.
- **Document what WELCOM estimates.** Using its help file, source code and methodological references, write `docs/welcom_method.md` covering: the model and estimating equations; whether elasticities are Marshallian or Hicksian and conditional or unconditional; the budget-share denominator and expenditure regressor it expects; and how it handles survey weights, zero purchases, quality effects, price clusters, any selection (inverse Mills ratio) correction, and standard errors/bootstrap. Label every exported estimate accordingly.
- **Call WELCOM correctly.** Fix calling-side errors in the legacy specification, e.g., budget shares built on a different denominator from the expenditure regressor, wrong cluster or weight variables, misuse of options, or regressors mismatched with the stated model. Choose the budget-share denominator and expenditure aggregate that are consistent with what WELCOM assumes, and label results as conditional (beverage budget) or unconditional (total expenditure) accordingly. Label expenditure elasticities as expenditure elasticities; do not call them income elasticities.
- **Price clusters.** Define clusters from geography/time in R, report cluster sizes, within-/between-cluster variation and urban/rural mixing as diagnostics, and pass them to WELCOM. Do not choose a cluster definition to match the manuscript's reported count.
- **Zeros, selection and weights.** Use WELCOM's built-in options. M1 uses the zero/selection treatment and weighting that WELCOM supports and that the legacy analysis intended; M2 and M3 switch those options off. If WELCOM does not support a feature, report that explicitly, state its consequence, and add it to the alternatives register.
- **Inference.** Use WELCOM's own standard errors and/or bootstrap. Seed all stochastic steps. If WELCOM supports bootstrap, pilot stability and use a configurable final count of at least 500 when feasible, recording failed replications. If WELCOM does not return the full joint covariance matrix needed for Table 5 or for cross-table comparisons, it is acceptable to wrap repeated WELCOM calls in an external, cluster-resampling bootstrap; this wraps the routine and does not modify it. Document exactly which uncertainty sources are and are not captured.
- **Outputs.** Export own-price, cross-price and expenditure elasticities with SEs, CIs, covariance matrices where available, sample sizes, cluster counts, specification and market labels. Set rows to responding quantities and columns to changing prices. Interpret substitution/complementarity using the correct direction and uncertainty.
- **Sensitivity.** Implement focused sensitivity analyses that stay within WELCOM: classification, quantity/unit rules, outliers, zeros/selection option, weights, rural inclusion, channels and price-cluster definitions. Clearly distinguish a deliberately different population from a same-sample specification comparison.

Do not promise unbiased or causal estimates. Report remaining identification and measurement limitations. If an essential input or WELCOM requirement cannot be resolved, continue independent stages and fail the affected stage with a precise blocker; do not fabricate data, silently substitute proxies, or label partial output as final.

## Alternatives register: flag improvements for later

While building and running the WELCOM pipeline, identify places where an alternative estimator, option or data treatment could improve or correct the estimates. **Flag them; do not implement them as primary results, and do not report alternative estimates in Tables 1–6 or the manuscript results.**

- Write `docs/estimation_alternatives.md` and a machine-readable `metadata/alternatives_register.csv` with, for each entry: ID; issue; evidence (code location, diagnostic output, or reference); affected estimates, tables and cells; proposed alternative; methodological references (verified); expected direction or size of impact if it can be assessed from diagnostics, otherwise "unknown"; implementation effort; priority; and any data or software prerequisites.
- Candidate topics to review (include only those that the inspection actually supports): WELCOM's treatment of zero purchases and structural non-consumption; the validity of its selection correction and exclusion restrictions; support for survey weights, strata and PSUs in estimation and inference; quality adjustment and measurement error in unit values; identification with small or urban/rural-mixed clusters; conditional versus unconditional estimands and a two-stage budgeting step; uncertainty from generated regressors built in R; missing joint covariance; imposition of theoretical restrictions; and treatment of overlapping home/away-from-home markets.
- Use the pipeline's diagnostics (cluster sizes, zero shares, within-cluster price variation, missing-quantity rates, sensitivity results) as supporting evidence where possible.
- Keep the code modular so an alternative estimator can later be added as a new model ID in `config/` without changing data construction or reporting.
- Summarize the highest-priority entries in the manuscript's limitations section in plain terms, without presenting unimplemented alternatives as findings.

## Primary deliverable: complete paper tables and estimates

**The goal is to produce the revised paper's estimates and all six substantive tables from the raw data, not merely a runnable pipeline.** Find and review `paper_20_10_12*.pdf` in the repository, matching case-insensitively and checking naming variants such as `Paper_20_1012_ElasticiBeverages*.pdf`. Record the exact manuscript version used. The supplied version contains Tables 1–6 on printed pages 18–23. Review the body and table notes together because some in-text table references and labels are inconsistent. Exclude the cover letter and Highlights from the analytical deliverables.

Implement the following table registry, with stable table IDs and explicit source datasets, model IDs, aggregation definitions and reporting scripts:

| Table | Required computations | Required panels and columns |
| --- | --- | --- |
| **1. Household demographics** | Household-head sex, age, rural status, household size, single-member household, presence of children, education indicators (none/primary/secondary/higher), total household income and income per member | Weighted mean and SD, observed minimum and maximum; unweighted sample N and population weight total in notes. Define sex coding, child age threshold, income period/currency, and education mappings. Use the corrected analysis sample and document sample differences. |
| **2. Beverage consumption statistics** | For every beverage: positive-purchase prevalence; mean monthly expenditure among purchasing households; mean budget share; observed mean unit value; mean monthly quantity | Four panels: coded purchases only × off-trade/combined market, and coded plus text-recovered purchases × off-trade/combined market. Original rows: SB, Beer, Spirits, Water, Dairy. Report monthly physical units and monetary units explicitly. |
| **3. Own-price elasticities and specification sensitivity** | Each beverage's own-price elasticity (WELCOM), its SE, CI and significance | Off-trade and combined-market panels; six specification columns defined below. Replace the old claim of demonstrated “bias” with specification sensitivity unless bias is actually identified. |
| **4. Own-price elasticities by household income tercile** | Each beverage's own-price elasticity (WELCOM) for the full sample and each of three income terciles, with inference | Off-trade and combined-market panels; columns Total, Tercile 1, Tercile 2, Tercile 3. Define weighted tercile cutoffs, income measure (household or per capita), eligibility, and treatment of zero/missing income. Export subgroup sample and cluster counts. |
| **5. Own- and cross-price elasticity matrices** | Full K × K primary-model (WELCOM) price-elasticity matrix, including diagonal own-price effects, with joint covariance and cell-level inference | Separate off-trade and combined-market matrices. Original K=5 (SB, Beer, Spirits, Water, Dairy). Rows = quantity responding; columns = price changing. Diagonals must equal the corresponding primary-model results in Tables 3 and 4. |
| **6. Expenditure elasticities and specification sensitivity** | Each beverage's elasticity with respect to the model's expenditure aggregate (WELCOM), with SE, CI and significance | Off-trade and combined-market panels; the same six specification columns as Table 3. Relabel the manuscript's “Income elasticities” unless a genuine income specification is estimated. State household-total-expenditure versus beverage-budget conditioning. |

### Specification columns for Tables 3 and 6

All six columns are estimated with WELCOM; they differ only in options, inputs or sample.

1. **M1:** primary WELCOM specification, with its supported treatment of zeros/selection, survey weights, justified regional controls, coded plus text-recovered purchases, and urban/rural coverage.
2. **M2:** otherwise identical WELCOM specification without the zero-purchase/selection option used in M1. State exactly which component is removed and whether the estimand changes.
3. **M3:** otherwise identical WELCOM specification without sampling weights.
4. **M4:** otherwise identical WELCOM specification without the regional controls actually used in M1. Do not silently interpret “region” as rural status.
5. **M5:** coded purchases only, excluding the text-recovered component. Specify whether this changes only measurements or also household eligibility; add a common-sample comparison where informative.
6. **M6:** urban households only. Label the changed target population and report sample/cluster counts; do not describe every difference as estimation bias.

Implement all six contrasts where WELCOM and the data support them. If a contrast cannot be run in WELCOM (e.g., an option is unavailable), explain why, identify the affected table cells explicitly, add the gap to the alternatives register, and provide a justified WELCOM-based sensitivity specification where possible. Never revert to known data-construction errors merely to populate a column.

### Table definitions and consistency requirements

- Table 2 mirrors the paper's estimands: prevalence uses the eligible household denominator; expenditure is conditional on positive purchases; mean monthly quantity is unconditional over eligible households where measurable. Report valid-observation denominators and measurement coverage so unavailable quantities are not converted to zeros. Compute unit values among records/households with valid positive expenditure and quantity, and state precisely how they are aggregated and weighted.
- The original Table 2 budget shares refer to the beverage basket. Keep that descriptive measure clearly labeled; add the total-expenditure shares if the WELCOM specification uses them. Do not confuse the two denominators.
- Produce monetary descriptives in COP as the canonical output. Provide USD columns only if the exchange-rate source, date/basis and conversion are documented; never hard-code the manuscript's old USD figures.
- “Corrected” in Table 2 denotes the inclusion of text-recovered purchases, not a guarantee of unbiased measurement. Use clearer panel labels. Correct apparent row permutations, spelling and copied SEs by deriving every cell from data.
- Preserve the five paper categories only where defensible. If correcting the Dairy/hot-drinks or alcohol classification requires additional categories, expand rows and matrices consistently across tables; do not combine incompatible physical units just to retain five rows. Export a category crosswalk and explain any market/category not separately identifiable.
- Estimate subgroup models with WELCOM; do not obtain Table 4 by mechanically rescaling aggregate estimates. Derive significance marks from actual unrounded estimates and valid inference. Retain manuscript-compatible SE-in-brackets formatting if useful, and export 95% CIs separately or alongside it.
- Primary-model full-sample estimates must be identical wherever repeated across Tables 3–6. Generate them from a shared results object rather than separate manually copied values. Attach estimand, sample N, cluster count, weights, controls, WELCOM version and options, and bootstrap settings to each model.
- Automatically export Tables 1–6 as machine-readable CSV and publication-ready LaTeX or an existing supported manuscript format under `output/tables/<run_id>/`. Save unrounded long-format estimates and covariance matrices under `output/estimates/<run_id>/`. Generate a table-completeness check that identifies every required panel, model, beverage and statistic, distinguishes valid zeros from unavailable results, and fails if a supported required result is silently omitted.
- Include an additional sample-flow table and measurement/estimation diagnostics as supplementary outputs. Refresh any summary numbers used in the abstract/results from these same saved estimates. The old point estimates, sample sizes and signs are historical context, not numerical acceptance criteria.

## Updated manuscript: R Markdown → LaTeX → PDF

**Creating `manuscript/manuscript.Rmd` is explicitly within scope.** The R and Stata pipeline must produce all datasets, estimates, uncertainty measures, tables, figures and summary statistics needed to compile an updated manuscript from that file using R Markdown and LaTeX to PDF. Deliver the manuscript source and successfully rendered PDF, not only the analytical outputs.

- Use the existing paper as the starting point for the manuscript structure and narrative. Update methods, results, discussion and limitations to reflect the implemented analysis. The methods section describes the WELCOM estimator and its options as used; the limitations section summarizes the main flagged alternatives from the register. Incorporate Tables 1–6 and necessary supplementary diagnostics; explain any justified changes in categories, estimands or table structure. Do not retain claims contradicted by the updated results.
- Have Stata export estimation results and R assemble a documented manuscript input bundle (for example, `data/processed/manuscript/<run_id>/`) containing reusable table objects, figures or figure paths, and named values for inline reporting. Include a manifest linking every component to the same validated run, model specifications and data versions. Keep display-ready tables/figures in the corresponding `output/` subfolders. Do not mix outputs from different runs.
- Parameterize `manuscript.Rmd` with an explicit `run_id` or input-manifest path. Load the saved analytical bundle rather than rerunning data processing or estimation inside the manuscript. Populate all estimated numerical statements—including the abstract, results, sample sizes, confidence intervals and subgroup comparisons—from named values or code-generated text. Do not hard-code analytical findings. Distinguish fixed sourced background facts from computed estimates.
- Generate publication-ready LaTeX tables directly from validated outputs, with captions, labels, notes, units, sample sizes and uncertainty. Use reliable table/figure cross-references and the project's `references.bib`; verify citation keys and add verified methodological references (including WELCOM) when needed. Avoid absolute paths and interactive dependencies.
- Configure a documented R Markdown PDF format and LaTeX engine. Record required R packages and LaTeX dependencies. Add a render stage to the root-level wrapper after R reporting, with a standalone command such as `Rscript -e 'rmarkdown::render("manuscript/manuscript.Rmd", params=list(run_id="RUN_ID"))'`; implement the actual command and output paths consistently with the chosen configuration. The render must fail clearly if required inputs are missing, stale or incompatible.
- Write the final PDF to `output/manuscript/<run_id>/`, with rendering logs in `output/logs/<run_id>/`. Keep `manuscript/` for editable sources and supporting templates; isolate temporary LaTeX files from analytical data and final deliverables.
- Render and inspect the PDF for table width, page breaks, readable figures, resolved citations/cross-references, and agreement between prose and tables. Deliver a complete readable updated manuscript; document unresolved analytical blockers separately rather than filling missing results with fabricated estimates or presenting incomplete tables as final.

## Execution, validation and deliverables

Create `code/R/00_run.R`, `code/stata/00_master.do`, and a root-level wrapper that runs R construction → Stata estimation (WELCOM) → R reporting → manuscript rendering from a clean session, stops on errors, and supports individual stages. Record software/package/ado versions (including WELCOM), configuration, input checksums, Git commit, seeds and run identifiers. Capture R dependencies in `renv.lock`; pin or document Stata dependencies without silently updating them.

Add meaningful checks for merge keys, totals across stages, recall/unit conversion, zero/missing status, classification, price support, sample exclusions, compatible budget shares, the WELCOM input contract and estimator outputs. Export a complete sample-flow table and diagnostics; build manuscript-ready tables from saved results rather than hand transcription. Validate reproducibility of deterministic inputs and seeded estimates, without requiring agreement with old results.

Deliver implemented code, `manuscript/manuscript.Rmd`, its rendered PDF, a clean-run command, generated validated outputs where feasible, concise methods documentation (including `docs/welcom_method.md`), a legacy-to-new logic map, a change log explaining data-construction and calling-side corrections, the alternatives register (`docs/estimation_alternatives.md` and `metadata/alternatives_register.csv`), and an exact list of unresolved blockers. Proceed with implementation and verification now; do not return only another plan.
