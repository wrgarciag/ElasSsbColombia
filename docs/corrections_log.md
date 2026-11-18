# Change log: data-construction and calling-side corrections

Every difference between the legacy pipeline (`code/legacy/`) and the new one (`code/R/`, `code/stata/`) that changes a number. Each entry gives the legacy behaviour, the rule now applied, the reason, and what it affects. Calling-side corrections to WELCOM (W1–W9) are in `docs/welcom_method.md`, section 4. Estimator-level concerns that are **not** corrected are in `docs/estimation_alternatives.md`.

Counts are from run `20261117a` (`output/diagnostics/20261117a/`).

## Household universe, income and expenditure

| # | Legacy | Now | Why | Affects |
|---|---|---|---|---|
| C-01 | 4,267 households dropped: no beverage record, or 16+ litres per adjusted member per day (`SSBConsuGasCorrected.R:34–48`) | All 87,201 households are the universe; 87,197 are estimation-eligible (87,198 off-trade). Households without a beverage purchase enter with zero shares | Dropping non-buyers removes true zeros; the 16-litre rule had no stated basis and depended on fabricated litres | Every table |
| C-02 | `GastoTotal` has no source code and matches no DANE aggregate (log correlation 0.84 with GTUG); values below 1,000 or outside 6×IQR set to missing and imputed with an unseeded `mice` | DANE's monthly current expenditure of the spending unit (`GCUG`), untouched | Reproducible, documented, no imputation | Shares, expenditure regressor, Tables 3–6 |
| C-03 | Income `IT` = sum of 47 person-level items, trimmed and imputed with `mice`; terciles unweighted (37/31/32% of weighted households) | DANE's total income of the spending unit (`IT`), untouched; weighted terciles of per-capita income. The person-level sum is rebuilt only as a reconciliation check | Reproducible; terciles are population terciles | Table 1, Table 4 |
| C-04 | Head education "Primaria" for every unclassified value, including missing | Primary only for `P6210 == 3`; unknown is its own category (20 heads) | Mislabelled default | Table 1; controls |

## Classification

| # | Legacy | Now | Why | Affects |
|---|---|---|---|---|
| C-05 | **Text recovery assigned the full amount of any record whose description mentioned a beverage word**, e.g. the price of "pizza y gaseosa" became SB spending and "café y pan" hot-drink spending | A description identifies a beverage purchase only if every word is a token of one beverage category or a neutral qualifier (size, container, count, flavour). Composite descriptions are flagged and their amount is not attributed | The amount paid for a meal is not the amount paid for the drink. 185,000 composite records (sample value COP 1.2 billion) against 15,000 pure beverage records | "Coded + text" panels of Table 2; M1 vs M5; on-trade shares |
| C-06 | Beer recovered from text, and all on-trade alcohol (code 11110601), classified as Spirits | Text beer tokens map to Beer. Code 11110601 is split into beer or spirits only when the description is a pure beer or spirits description; otherwise it stays unallocated | Coding error (`fclasicoicop.R:208`) and a generic code | Beer and spirits, combined market |
| C-07 | Ice (012203) counted as Water | Excluded | Not drinking water | Water |
| C-08 | Plant-based drinks (012209) counted as SB; powdered concentrates (012207) and fresh juices away from home (11110302) left out | All three are outside SB in the primary data and inside it in sensitivity S1 | Sweetening cannot be established; concentrates are sold by weight | SB; S1 |
| C-09 | "Dairy" = milk + hot drinks in the corrected panels, milk only in the coded panels | Two categories everywhere: dairy drinks (litres) and hot drinks (kilograms at home) | Incompatible definitions across panels and incompatible physical units | Tables 2–6 have six categories |
| C-10 | Flavoured milk drinks (01149908) unclassified; ready-to-drink chocolate milk (01210205) in hot drinks | Both in dairy drinks | They are dairy drinks sold by volume | Dairy, hot drinks |
| C-11 | "refajo" in text → SB | Beer | COICOP places bottled refajo in class 0213 | Beer, SB (small) |
| C-12 | Water sold under the soft-drink code away from home (11110301) stayed SB | Moved to Water when the description is purely water | Mis-coded records | Water, SB (small) |

## Recall periods and Capítulo C

| # | Legacy | Now | Why | Affects |
|---|---|---|---|---|
| C-13 | Urban household diary: factor 30/14 for every record | Pocket spending of the main shopper (scope = 2) uses 30/7 | The questionnaire collects it for the first 7 days only | Urban SB, water, beer |
| C-14 | Non-purchase acquisitions (gifts, own production, taken from a business) included with factor 1 | Excluded from spending and unit values; kept and counted (`acquisition_form.csv`) | They are not purchases and have no purchase frequency | All categories (about 3% of records) |
| C-15 | Urban Capítulo C: kept food groups the household **would** buy during the diary (`NC2_CC_P3_S2 == 1`), with a fabricated quantity of 1 | Kept only when the group is bought monthly, bimonthly or quarterly **and not** inside the reference period; value of the last purchase scaled by frequency; no quantity | The legacy rule double-counts diary purchases and invents litres | Dairy, hot drinks, SB |
| C-16 | Rural Capítulo C: all rows including "never"; missing SB amounts replaced by COP 2,500 | Same rule as C-15 (also fortnightly); "never", "bought last week" and sporadic rows excluded | Fabricated spending | Rural dairy, hot drinks, SB |
| C-17 | Less-frequent module: frequency factors intended, but every record received factor 1 because of a type bug (`SSBEConsuBasesUrbano.R:502`) | DANE's published table for previous-month sections (Metodología General ENPH, DSO-ENPH-MET-001 v2, §2.1.5, Tabla 3): amount kept for weekly, fortnightly, monthly and sporadic purchases; divided by 2, 3, 6 and 12 for bimonthly, quarterly, half-yearly and yearly purchases | The legacy code did not apply the rule it intended; the denominator of the budget shares (DANE's GCUG) is built with these factors. Sensitivity S3 keeps the reported previous-month total instead | Spirits and wine spending (about 1,600 records); a few beer records |

## Quantities and unit values

| # | Legacy | Now | Why | Affects |
|---|---|---|---|---|
| C-18 | Weight units converted to pounds and treated as litres (`g/500`) | Litre goods take quantities only from volume units; liquid dairy recorded in grams is converted at 1.03 kg per litre; goods sold by weight (coffee, chocolate, tea) are measured in kilograms | Unit error | Dairy and hot-drink unit values and quantities |
| C-19 | Unit "Otra" = 1 litre | DANE's recorded equivalence of the purchase (grams or cm³) is used; without it there is no quantity | The equivalence reproduces the per-litre price of directly recorded purchases (median COP 2,500 vs 2,000 per litre for soft drinks; per-unit reading gives 880) | 3–13% of at-home records |
| C-20 | Modules without a unit field: one "unit" = 1 litre (SB, beer, water, spirits), 0.5 (milk), 0.35 (hot drinks) | No physical quantity; spending is kept | A count of items is not a volume | Unit values come from the household diary and the rural weekly module only |
| C-21 | `festconsu`: purchases above 50 units had both quantity and spending replaced by constants | Not applied; implausible quantities are flagged and not used for unit values | Fabrication | Quantities |
| C-22 | Spirits and wine: quantity 1 per record, so the "unit value" was spending per record | No unit value: ENPH collects them without quantities | Manufactured price | Spirits and wine are not estimable in Tables 3–6 |
| C-23 | A price for every household: non-buyers received a regression prediction | Unit values only for households with a valid positive purchase and quantity | Imputed values are not observed prices | Tables 2–6 |
| C-24 | Household spending and quantities outside 1.5×IQR set to zero, turning 8–11% of buyers into non-buyers; spending below COP 100 dropped; unit values outside 6×IQR dropped | Nothing is recoded to zero. Unit values outside a robust log-scale band (3.5 MAD) are flagged and not passed to WELCOM, the household keeping its share. Extreme spenders are flagged and excluded only in sensitivity S4. Amounts below COP 100 remain invalid | Outliers are not zeros | Prevalence, shares, unit values |
| C-25 | Model 5 ("without consumption correction") also changed the outlier rule (k = 3 instead of 1.5) and the category set | M5 changes only the purchase records used (coded only), on the same households | Clean comparison | Tables 3 and 6, M5 |

## Price clusters and model set

| # | Legacy | Now | Why | Affects |
|---|---|---|---|---|
| C-30 | Clusters = first 8 characters of `VIVIENDA` (384 groups; 112 span several quarters) | Local market: municipality × area (urban/rest) × collection quarter (486 clusters). Survey segments are sensitivity S5 | Defined from geography and time; see `docs/methods.md` §5 for the diagnostics and for the revision of the first-pass choice (segments) | Tables 3–6 |
| C-31 | Every good in every model, including terciles | A good enters a model only with enough unit-value support in that model's sample; tercile models share one list (beer excluded) | The tercile-1 beer equation had 35 within-cluster degrees of freedom | Table 4 |

## Infrastructure

| # | Legacy | Now |
|---|---|---|
| C-26 | CP1252 text broke `tolower()` under R ≥ 4.2 | Strings are converted to valid UTF-8 at import |
| C-27 | Hard-coded paths, `font_import()`, `rm(list = ls())`, circular read of `DataEstimates4`, duplicate writers of the same file names | Project-relative paths from one configuration file; staged driver; one writer per file |
| C-28 | No seeds | Seeds in `config/config.yml` for R, the external bootstrap and WELCOM's own bootstrap |
| C-29 | USD figures at an undocumented 3,000 COP/USD | COP is canonical; USD columns are produced only if a rate and its source are set in the configuration (none is set) |
