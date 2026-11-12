# Elasticities of Alcoholic and Sugar-Sweetened Beverages in Colombia

Revision repository for **Revisiting Elasticities of alcoholic and non-alcoholic Beverages in Colombia**, by Norman Maldonado and William García. It organizes replication, refinement of estimates, and responses to Food Policy reviewer comments, using **R for data processing** and **Stata for econometric estimation**.

## Research question and contribution

How do purchases of alcoholic and sugar-sweetened beverages respond to changes in their own prices, other beverage prices, and household resources? The revised paper will emphasize **both beverage groups** and the implications of their joint demand for Colombia's tax reform debate.

The proposed contribution combines own-price and cross-price estimates for beer, spirits, and sweetened beverages; a transparent assessment of measurement and specification choices; distributional heterogeneity; and illustrative tax scenarios with uncertainty. Novelty must be demonstrated against specific studies, without claiming to eliminate all sources of bias.

**Scope clarification:** the manuscript reports that the ENPH does not reliably distinguish sugar-sweetened beverages (SSB) from beverages containing non-sugar sweeteners (NSSB). The observable category **sweetened beverages (SB)** will therefore be retained where appropriate. A policy motivation concerning SSB taxation does not turn an SB elasticity into an SSB-specific elasticity. Beer and spirits should have dedicated results and discussion; water and dairy complete the demand system.

## Current status

This is an **initial repository structure and revision plan**, ready to import into GitHub. It includes documentation, tracking matrices, data contracts, and R/Stata templates. It does not contain microdata, the original estimation programs, or recalculated estimates. Analysis scripts stop explicitly until the necessary inputs and original implementation are incorporated. No remote repository has been published.

Source documents: the attached manuscript dated November 12, 2026, and the Food Policy review dated July 2023. Manuscript results are replication targets, not independently verified estimates. The original PDFs are not included in the repository export; retain them in a folder accessible to the research team.

## Repository organization

| Path | Contents |
| --- | --- |
| `code/R/` | Import, harmonization, classification, dataset construction, descriptive statistics, and external validation |
| `code/stata/` | Replication, elasticities, inference, robustness, heterogeneity, and tax scenarios |
| `config/` | Relative paths, specifications, and decisions requiring confirmation |
| `data/raw/` | Immutable original microdata, excluded from Git |
| `data/interim/` | Intermediate datasets, excluded from Git |
| `data/processed/` | Harmonized dataset for Stata, excluded from Git |
| `data/external/` | External surveys and other sources, excluded from Git |
| `metadata/` | Data contracts, dictionaries, manifests, and classification rules |
| `docs/` | Reviewer response, manuscript audit, literature, validation, and tax analysis plan |
| `outputs/tables/`, `outputs/figures/` | Generated and reviewed results |
| `outputs/logs/` | Local execution logs, excluded from Git |
| `manuscript/` | Revised text, appendices, and response letter |
| `.github/` | Issue and pull request templates |

## Quick start

1. Extract the ZIP and open a terminal in `work-personal-ssbelasticity/`.
2. Review `docs/revision_plan.md`, assign owners in `docs/reviewer_response.csv`, and inventory the original programs.
3. Place authorized inputs in `data/raw/`; record provenance, version, and permissions in `metadata/input_manifest.csv`.
4. Complete variable and unit mappings in `metadata/`. Document any assumptions about the original variables.
5. From the repository root, run the initial R check:

   ```bash
   Rscript code/R/00_run.R preflight
   ```

6. Implement and run data processing:

   ```bash
   Rscript code/R/00_run.R process
   ```

7. In Stata, from the repository root:

   ```stata
   do code/stata/00_master.do preflight
   do code/stata/00_master.do estimate
   ```

The initial check only verifies the folder structure. `process` and `estimate` stop while the analytical stages remain templates, preventing unfinished analyses from being presented as completed replication.

### Reproducible environment

The manuscript reports **Stata 17**, **WELCOM 2.1**, 354 clusters, and 100 bootstrap replications. These are starting points to audit against the original files, rather than a validated configuration. Confirm which clusters identify common prices and distinguish them from the survey's primary sampling units (PSUs).

The R templates use only base R. When implementing processing, record the R version and dependencies; generate and verify `renv.lock` if packages are added. Exporting to `.dta` will require a tool such as `haven`, with its version recorded. Document the source, version, and help files of the Stata routines actually used; do not install or update packages silently. Retain the seed, specification, and execution log for each run.

## Workflow

### 1. Replicate before refining

Recover and run the original version without substantive changes. Reconstruct the sample, categories, units, and markets. Reproduce manuscript tables using documented tolerances and record discrepancies. Reported benchmarks include an SB own-price elasticity of −0.50 for the expanded market and an elasticity labeled as income elasticity of 0.88. Verify whether the latter actually refers to total household expenditure.

### 2. Process data in R

- Reconcile household, individual, and expenditure modules without double-counting purchases.
- Harmonize quantities, physical units, recall periods, expenditure, and purchase channels.
- Keep coded purchases separate from purchases recovered from text, using versioned rules and reviewing ambiguous cases.
- Preserve observed zeros and distinguish them from missing values, invalid quantities, and unidentified purchases.
- Construct the complete household × category × market universe, including households with no purchases.
- Export the dataset and dictionary for Stata; generate weighted descriptive statistics by income, region, and rural status, with explicit denominators.

### 3. Estimate in Stata

First replicate Deaton's unit value model and the original treatment of zeros. Audit assumptions concerning common prices within clusters, variation between clusters, quality, and measurement error. Verify the selection procedure and its identification; an inverse Mills ratio correction does not necessarily address every mechanism generating zeros.

Produce own-price, cross-price, and expenditure/income elasticities with confidence intervals. Label matrices as **rows = category whose quantity responds; columns = category whose price changes**. State whether elasticities are Marshallian or Hicksian, and whether they are conditional on the beverage budget or relate to total expenditure. Do not impose symmetry on Marshallian elasticities without the appropriate transformation.

### 4. Assess robustness and external validity

Compare choices concerning classification, weighting, zeros, rural inclusion, extreme unit values, cluster definitions, and purchase channels. Re-estimate models on comparable samples to distinguish changes in sample composition from changes in method. Plan inference that respects the survey design and units supporting identification; increase bootstrap replications after assessing stability and feasibility.

Treat ECV and ENSIN as **candidate sources** for comparing prevalence and patterns, after verifying questionnaires, access, years, and populations covered. Household purchases, individual consumption, and dietary intake are not interchangeable. Descriptive agreement between surveys does not independently validate a price elasticity. Assess other expenditure surveys or price sources before committing to external replication.

### 5. Connect findings to the tax reform debate

Present separate and joint scenarios for alcoholic and sugar-sweetened beverages, with explicit assumptions about tax pass-through and substitution. Start with hypothetical price changes; simulating a specific reform requires checking legislation, tax bases, rates, effective dates, and product composition against current official sources.

Scenarios should distinguish changes in purchases, revenue, and monetary burdens across groups. Elasticities alone do not establish health or welfare effects. Interpretation must retain the limitations concerning SB versus SSB and beer purchased away from home. See `docs/tax_policy_plan.md`.

## Reviewer comments and deliverables

| Priority | Deliverable | Completion criterion |
| --- | --- | --- |
| P0 | Replication and audit | Sample and tables reconciled; discrepancies explained |
| P0 | Alcohol and cross-price interpretation | Signs, direction, and conclusions are consistent |
| P1 | Literature and contribution | Explicit comparison with previous studies covering both beverage groups |
| P1 | ENPH description | Categories, design, units, descriptive statistics, and sample flow documented |
| P1 | Robustness and inference | Traceable specifications and documented uncertainty |
| P1 | Tax policy application | Transparent scenarios with identification limits stated |
| P2 | External validation | Harmonized comparisons and discussion of discrepancies |
| P2 | Manuscript and response letter | Every comment linked to revisions and supporting evidence |

The tracking matrix distinguishes the reviewer's six numbered comments, the overall concern about contribution, the team's priorities, and inconsistencies identified while reading the manuscript. No task is marked as resolved.

## Collaboration and quality standards

Open one issue per comment or deliverable; use focused branches such as `revision/alcohol-literature` or `replication/unit-values`. Each analytical change should identify its inputs, rationale, affected results, and validation. Freeze the replication before modifying specifications; retain run identifiers and a decision log.

Before submission, complete the response matrix, verify that numbers and narrative match generated outputs, review uncertainty and interpretation of signs, verify references and tax policy context, and execute the complete workflow in a clean environment. A difference between specifications does not by itself establish that one is biased.

## Data, access, and publication

Do not upload microdata, individual records, free-text survey responses, or confidential review documents. `.gitignore` excludes datasets and logs by default. Review aggregate outputs before committing them. Clarify ownership and permissions for the original code with the authors; this scaffold does not assign a license to third-party materials.

To create the remote repository, start with an empty repository and follow `docs/github_import.md`. The ZIP exports the file tree without Git history or credentials.
