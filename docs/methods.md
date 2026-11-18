# Methods: data construction and estimation

Concise description of what the pipeline does. Rules are stored as tables in `metadata/`; parameters in `config/config.yml`; the estimator is documented in `docs/welcom_method.md`; differences from the legacy code in `docs/corrections_log.md`.

## 1. Data

ENPH 2016–2017 (DANE), public-use microdata: 87,201 households and 291,590 persons, collected from July 2016 to June 2017. Thirteen of the sixteen modules are used (`metadata/enph_modules.csv`; checksums in `metadata/input_manifest.csv`).

| Module | Questionnaire | Reference period | Has quantity and unit | Has free text |
|---|---|---|---|---|
| Urban household diary | Cuadernillo 2 urbano | 14 days (shopper's pocket spending: first 7) | Yes | No |
| Urban meals and drinks away (household) | Cuadernillo 2 urbano | 14 days (7 for the shopper's own) | Count only | Yes |
| Urban personal diary; meals and drinks away (personal) | Cuadernillo 4 | 7 days | Count only | Meals module only |
| Rural weekly purchases; meals away; personal | Cuadernillo 2 rural | Previous week | Weekly purchases only | Meals module only |
| Capítulo C, urban and rural | Cuadernillo 2 | Usual frequency and value of last purchase by food group | No | No |
| Less-frequent purchases | Cuadernillo 3 | Previous calendar month (section J11) | No | No |
| Households; persons | Cuadernillo 1 | — | — | — |

## 2. Households

- **Universe.** All ENPH households. Estimation-eligible: positive total expenditure, complete head covariates, every budget share and their sum at most one, and a price cluster of at least two households (87,197 households in the combined-market file; `tableA1_sample_flow.csv`).
- **Covariates.** Sex of the head (1 = male), age, household size (`P6008`), single-member household, any child aged 0–5, head's education (none or preschool; primary; secondary or media; higher; unknown).
- **Design variables.** Weight `FEX_C`. The public file has no stratum or PSU identifier; the municipality (first five characters of `VIVIENDA`) is kept as a PSU proxy and domain × area as a stratum proxy. They are not used by WELCOM.
- **Total expenditure.** DANE's monthly current expenditure of the spending unit (`GCUG`). It is the denominator of every budget share and the expenditure regressor.
- **Income.** DANE's total income of the spending unit (`IT`); weighted terciles of income per member. Reconciled against a person-level sum (`income_expenditure_reconciliation.csv`).

## 3. Beverage purchases

**Classification** (`metadata/category_map.csv`, `metadata/text_rules.csv`, `metadata/capc_group_map.csv`).

| Category | Coded content | Physical unit |
|---|---|---|
| SB | Carbonated soft drinks, malt drinks, packaged juices/iced tea/sports drinks, energy drinks; soft drinks served away from home | Litre |
| Beer | Beer and bottled refajo; on-trade alcohol described only as beer | Litre |
| Spirits and wine | Aguardiente, rum, whisky and similar, liqueurs, other spirits, wine; on-trade alcohol described only as spirits or wine | None collected |
| Water | Bottled and tank water | Litre |
| Dairy drinks | Liquid and powdered milk, yogurt, kumis, flavoured milk drinks; milk and yogurt served away from home | Litre |
| Hot drinks | Coffee, drinking chocolate and cocoa, tea and infusions; hot drinks served away from home | Kilogram (at home) |

- SB cannot be split into sugar-sweetened and non-sugar-sweetened drinks: COICOP codes and descriptions carry no sweetener information.
- Wine is identifiable by code, but ENPH collects it, like spirits, without quantities and only 1,700 records exist; it is reported together with spirits.
- **Text-identified purchases** are records without a beverage code whose description, after normalisation, contains only tokens of one beverage category and neutral qualifiers. A description that also lists other items is a composite purchase: flagged, counted, not attributed.
- **Sources.** `coded` (COICOP), `text`, `capc` (Capítulo C food group). "Coded only" data use `coded` and `capc`.

**Purchases only.** Records acquired by purchase (`forma == 1`) with an amount of at least COP 100. Gifts, own production and goods taken from a household business are kept in the transaction file and excluded from spending.

**Monthly conversion** (`metadata/frequency_factors.csv`). The factors are DANE's (Metodología General ENPH, DSO-ENPH-MET-001 v2, §2.1.5, Tablas 1–3 and 6). DANE's questionnaires combine a short reference period with the usual purchase frequency, and Capítulo C captures low-frequency purchases made outside the reference period.

| Stated frequency | Factor |
|---|---|
| Daily, several times a week, weekly, or missing | 30 / reference days (2.14 for 14 days; 4.29 for 7 days) |
| Fortnightly | 2 |
| Monthly / bimonthly / quarterly | 1 / 0.5 / 0.33 |
| Sporadic | 1 for an observed purchase; excluded for Capítulo C |
| Less-frequent module (previous month's total) | 1; divided by 2 / 3 / 6 / 12 if bought bimonthly / quarterly / half-yearly / yearly |

Capítulo C adds the value of the last purchase, scaled by frequency, only for groups bought monthly, bimonthly or quarterly (also fortnightly in the rural form) and **not** bought inside the reference period. Sensitivity S3 replaces this scheme with pure reference-period scaling and no Capítulo C.

**Quantities** (`metadata/unit_conversions.csv`). Only the urban household diary and the rural weekly module record a unit. Volume units convert to litres; weight units to kilograms; "other" units use DANE's recorded equivalence in grams or cm³; liquid dairy recorded by weight converts at 1.03 kg per litre. Records outside 0.05–400 litres or 0.001–100 kg are flagged. Everything else has no physical quantity.

**Markets.** Off-trade = COICOP divisions 01–02 (including personal purchases of packaged drinks); on-trade = division 11. Combined = the union of the two sets of records.

## 4. Household aggregates and unit values

For each household, category, market and data variant: monthly spending (zero if no valid purchase), monthly quantity from purchases with a valid quantity (missing if none), and the unit value = spending on those purchases / their quantity. Budget share = spending / total expenditure.

- Unit values exist only for buyers with a measured quantity. They are never imputed.
- Unit values outside median ± 3.5 robust standard deviations of the log, by category, market and variant, are flagged and not passed to WELCOM.
- Extreme spenders (5 robust standard deviations of log spending) are flagged; excluded only in S4.
- Because on-trade purchases have no quantities, unit values are the same in the off-trade and combined data; the markets differ in budget shares.

## 5. Price clusters

**Primary: the local market in a quarter**, i.e. municipality × area (urban / rest) × collection quarter: 486 clusters, median 54 households, none mixing urban and rural households. Households in a cluster face the same shops in the same period, which is the assumption of the unit-value model. Regional controls are DANE region × urban/rest (11 cells) plus the collection quarter, both constant within a cluster.

**Sensitivity S5: the survey segment** (municipality + sector code of `VIVIENDA`): 8,460 groups of about 10 neighbouring households interviewed in one month, each inside one local market.

Why the market and not the segment. The pipeline was first run with segments as the primary cluster. That choice was revised after the first complete set of point estimates, for two reasons that do not depend on the size of any elasticity:

1. *Markets.* Segments of the same city are not separate markets. Differences in unit values between segments of one city in one month reflect outlet type, package size and neighbourhood composition, which the model would read as price variation.
2. *Reliability.* A segment holds 1–4 unit values per beverage, so its mean unit value is mostly sampling noise: the reliability of the cluster mean for SB is 0.57 with segments and 0.68 with markets (dairy drinks 0.73 and 0.87; hot drinks 0.65 and 0.80). With segments the errors-in-variables correction multiplies the between-cluster coefficient by a large factor that depends on WELCOM's weight-based household counts (`docs/welcom_method.md` §5), and splitting segments by income tercile leaves about two households per cluster: the first-tercile model could not be computed and the other two gave positive SB elasticities.

The first-pass estimates with segment clusters are archived in `output/diagnostics/<run_id>/first_pass_segment_clusters/`, and S5 reports the segment-based estimates with their own bootstrap. Diagnostics for both definitions: `price_cluster_sizes.csv`, `price_cluster_variation.csv`, Table A5. The cluster definition was not chosen to match the 354 clusters reported in the earlier manuscript.

**Support rule.** A beverage enters a model only if, in that model's sample, its unit value is observed in at least 30 clusters and the within-cluster regression has at least 50 degrees of freedom (`config/config.yml`, `welcom_contract_models.csv`). The three tercile models use the goods that pass in all three: beer fails in the lowest tercile (115 unit values in 80 clusters) and is left out of the tercile models.

## 6. Estimation

WELCOM `duvm` (Deaton's unit-value model), version 3.60, called once per row of `config/models.csv`:

```
duvm sb beer water dairy hot, hhsize(hhsize) expend(exptot) hweight(wcall) cluster(clus_market)
     region(regctl) subround(quarter_id) indcat(head_male single children educ) indcon(head_age) csb(1)
```

| Model | Change from M1 | Same households as M1 |
|---|---|---|
| M1 | Primary | — |
| M2 | `csb(0)`: no selection term | Yes |
| M3 | No weights | Yes |
| M4 | No `region()` | Yes |
| M5 | Coded purchases only | Yes |
| M6 | Urban households | No (different population) |
| T1–T3 | Income terciles (four goods: beer does not meet the support rule) | No |
| S1–S3 | Broad SB; direct units only; reference-period scaling | Yes |
| S4 | Extreme spenders excluded | No |
| S5 | Survey segments as price clusters | Yes |
| S6 | Raw household expansion factors | Yes |
| S7 | Beer left out of the system | Yes |

Estimates: uncompensated price elasticities (quality-corrected, symmetry-restricted), rows = quantity, columns = price; elasticities with respect to total expenditure; both unconditional on the beverage budget.

## 7. Inference

External cluster bootstrap around `duvm` (500 replications for M and T models, 100 for S models; `docs/welcom_method.md` §7). In run `20261117a` the bootstrap was stopped after the first 100 replications of the M and T models (one failed, in M3 off-trade); the S models have 4 replications and are reported as point estimates only. The reporting stage prints standard errors for a model only when it has at least 90 completed replications, and every table states the number used. Standard error = standard deviation of replications; 95% percentile intervals; joint covariance exported. Significance marks use a two-sided normal approximation on the unrounded estimate and standard error.

## 8. Reproducibility

`run_pipeline.ps1 -Stage all -RunId <id>` runs everything. Every run writes `output/logs/<run_id>/` (R and Stata logs, stage manifests with software versions, configuration hash, input checksums, git commit, seeds) and `data/processed/manuscript/<run_id>/manifest.json`.
