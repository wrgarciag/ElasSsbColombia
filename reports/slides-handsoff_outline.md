# Storyboard: `slides-handsoff.Rmd`

20-minute research handoff on the ENPH beverage-elasticity revision. This file holds the triage, the timed storyboard, the evidence behind each slide and the presenter notes. Numbers quoted here are those of run `20261117a` at the time of writing; the deck itself reads every estimate from that run's bundle, so if this file and the PDF disagree, the PDF is right.

## Triage

| Item | Choice |
| --- | --- |
| Source | `manuscript/manuscript.Rmd` and its bundle `data/processed/manuscript/20261117a/` (authoritative for methods and results); `docs/reproducibility_audit.md` revision 2, `docs/Paper_20_1012_ElasticiBeverages.pdf` and the legacy rerun logs in `output/replication/legacy_run/` (historical evidence); `docs/blockers.md`, `docs/corrections_log.md`, `docs/methods.md`, `docs/welcom_method.md`, `docs/estimation_alternatives.md`; the 2023 Food Policy review (confidential, paraphrased only). |
| Audience | Co-author working deck (ethos 30 / pathos 10 / logos 60): decisions and open questions documented, uncertainty visible, a little more text allowed. |
| Minutes | 20 for the main talk: title, 17 content slides, closing. Backup (16 slides) and references (2 pages) are outside the 20 minutes. |
| One sentence | Where ENPH observes prices, SB purchases respond to them (−0.89; −1.24 to −0.59); spirits, wine and the SSB split need data this survey does not hold. |
| Run | `20261117a`, fixed in `params$run_id`. The deck repeats the manuscript's checks (one run id across manifest, values and results; `config.yml` and `models.csv` hashes; bundle complete; inference available) and stops if any fails. Inference is preliminary: 100 of 500 replications for the 18 main and tercile models; 4 of 100 for the 14 sensitivity models. |
| Standard | `dev/beautiful-deck.md` does not exist; the deck follows `dev/beautiful-deck-SKILL.md`. |

## Timed storyboard

| # | Part | Assertion title (as rendered) | Single element | Evidence | Time | Clock |
| --- | --- | --- | --- | --- | --- | --- |
| – | Title | Rebuilt from ENPH, sweetened-beverage demand responds to price; spirits, wine and SSB need other data | Title page | — | 0:20 | 0:20 |
| 1 | Opening | Rebuilt from raw ENPH, SB demand is more price-responsive than first reported | Contrast: earlier −0.50 vs rebuilt −0.89 (interval −1.24 to −0.59); boundary box | Legacy paper Table 3 p. 20; `values.rds` (`own_M1_combined_sb`) | 1:10 | 1:30 |
| 2 | A. Survey | The rebuilt sample keeps all 87,201 ENPH households, non-buyers included | Three numbers: legacy 82,934; universe 87,201; eligible 87,197 | `values.rds` (`n_legacy`, `n_enph`, `n_sample_combined`, `n_urban`, `n_no_beverage`, `weight_total`); Table A1 | 0:50 | 2:20 |
| 3 | A. Survey | Only two instruments record quantities, so only they yield unit values | Measurement map: instrument → spending → quantity → unit value → role | `docs/methods.md` §1, §3; manuscript Data and Measurement | 1:20 | 3:40 |
| 4 | A. Survey | A text record counts as a drink purchase only if it names nothing else | Six groups; 15,041 pure vs 184,408 composite text records | `values.rds` (`text_identified_records`, `composite_records`, `text_share_comb_sb`); corrections C-05, C-09 | 0:55 | 4:35 |
| 5 | A. Survey | Spending is not a price: no spirits or wine purchase records a quantity | Bar chart: share of off-trade spending with a recorded quantity | `values.rds` (`qcov_home_*`); `output/diagnostics/20261117a/quantity_rules.csv` | 0:45 | 5:20 |
| 6 | B. Audit | We recovered the original data steps; the elasticity tables did not reproduce | Scorecard: reproduced / partly / not reproduced | Audit rev. 2 §0, §1.5, §1.6, §2.13 | 1:30 | 6:50 |
| 7 | B. Audit | Same inputs, same scripts, different SB elasticities: the cause is still open | Published vs rerun SB own-price; missing evidence vs untested candidates | Legacy Table 3; `duvm_total.log:584`, `duvm_hogar.log:583`; audit §1.5, §2.10 | 1:10 | 8:00 |
| 8 | B. Audit | The audit points to four places where estimates needed firmer ground | 2×2 panels by consequence: prices, zeros, budgets, uncertainty | Audit §2.3, §2.6, §2.9, §2.10, §2.11 | 1:05 | 9:05 |
| 9 | B. Audit | Clearer labels resolve several puzzles in the published tables | Two-column table: published vs revision | Legacy paper abstract and Tables 2, 5, 6; audit §1.6, §2.4, §2.11 | 0:55 | 10:00 |
| 10 | C. Estimates | Unit values mix price, quality and noise; markets help separate them | Diagram of Deaton's decomposition | Manuscript §2.1; `docs/welcom_method.md` §1 | 1:15 | 11:15 |
| 11 | C. Estimates | Each correction answers an audit finding and leaves a stated limit | Problem → correction → limitation table | `docs/corrections_log.md`; `docs/welcom_method.md` §4–7; manuscript Limitations | 1:15 | 12:30 |
| 12 | C. Estimates | SB's own-price elasticity is −0.89 in M1, and regional controls matter most | Coefficient plot, M1–M6, both markets, percentile intervals | `results.rds` (`est`, stat `price`) | 1:45 | 14:15 |
| 13 | C. Estimates | Expenditure elasticities hinge on the selection term: SB 0.52 vs 0.83 | Dumbbell plot, M1 vs M2, five goods | `values.rds` (`exp_M1_*`, `exp_M2_*`) | 1:15 | 15:30 |
| 14 | C. Estimates | Tercile and cross-price patterns are suggestive, not yet robust | Tercile table and three cross-price facts | `values.rds` (`own_T*`, `cross_combined_*`); `results.rds` (`price_nosym`) | 1:00 | 16:30 |
| 15 | D. Next steps | The rebuild runs end to end; inference and data gaps remain open | Completed / awaiting verification / new analysis or data | `docs/blockers.md`; `results.rds` (`status`); alternatives register | 1:00 | 17:30 |
| 16 | D. Next steps | Spirits and wine need prices from outside ENPH, not another model run | Two numbers and four steps | `values.rds` (`prev_comb_spirits`); `quantity_rules.csv`; B-1, A-08, C-06, C-22 | 1:20 | 18:50 |
| 17 | D. Next steps | Four decisions would unblock the next version | Decision list for the authors | B-4, B-13; A-01, A-03; review comment on policy use | 0:55 | 19:45 |
| – | Close | Where ENPH observes prices, SB purchases respond to them (−0.89; −1.24 to −0.59). Spirits, wine and the SSB split need data this survey does not hold. | Standout sentence | `values.rds` | 0:15 | 20:00 |

Part totals: opening 1:30, A 3:50, B 4:40, C 6:30, D 3:30.

## Presenter notes

**1. Opening.** Taxes work through prices, so any error in the elasticity flows into revenue and health projections. The earlier version reported −0.50 and called it bias-corrected; the rebuilt primary estimate is −0.89, and its interval lies below −0.50. Several corrections separate the two numbers and we have not decomposed their contributions. The interval includes −1. Keep the boundary box in view: purchases, SB not SSB, cross-market price differences rather than a causal tax effect.

**2. Sample.** The legacy file dropped 4,267 households (no beverage record, or 16 or more litres per adjusted member a day). The rebuild keeps every household; the four that are not estimation-eligible have an invalid share or are alone in their price cluster. Non-buyers stay in as zeros.

**3. Measurement map.** Only the urban 14-day household diary and the rural weekly questionnaire carry quantities and units. Personal diaries and away-from-home records give item counts; usual purchases by food group (Capítulo C) and the monthly-recall module give amounts only. Spirits and wine are collected in the monthly-recall module. Monthly amounts follow DANE's frequency factors (backup); they describe purchases, not intake.

**4. Classification.** SB covers soft drinks, malt drinks, packaged juices and teas, and energy drinks; ENPH cannot separate sugar-sweetened from non-sugar-sweetened drinks, so "SB", not "SSB". Dairy drinks (litres) and hot drinks (kilograms at home) are separate goods now. The legacy text rule assigned the whole price of "pizza y gaseosa" to SB; the rebuild counts a text record only if it names a single beverage. Text purchases add under 1% of SB spending, which is why M5 differs little from M1. This understates away-from-home spending by an unknown amount.

**5. Transition.** A recorded amount is not a price. Unit values exist only where a quantity was recorded, and for spirits and wine there is none. The combined market adds away-from-home spending but uses the same at-home unit values, so the deck never claims an on-trade price elasticity. That is the bridge to the audit.

**6. Scorecard.** Start with what worked: the unchanged legacy code rebuilt coded spending exactly and reproduced Tables 1 and 2. Partly: off-trade Table 2 after realigning a permuted column (SB purchase share 0.65 vs 0.67 remains); coded-only panels use a different dairy definition; water and text-recovered spending changed with the classifier. Not reproduced: the price elasticities. Reproducing an output does not validate its method.

**7. The gap.** One example only, labelled historical. Candidate causes are hypotheses: WELCOM 2.1 (reported) vs 2.30 (used in the audit; 3.60 is pinned now), 354 vs 384 clusters, which `duvm` table was copied (Table 07, with symmetry, is no closer than Table 06), and an unseeded imputation draw. No log or saved result exists to decide among them. Do not mention the earlier "clusters mixed urban and rural households" claim except to say revision 2 withdrew it, if asked.

**8. Four consequences.** Frame as where the paper needed firmer ground. Predicted prices for non-buyers entered as observed unit values (95% of beer "prices"); grams were treated as litres. Outlier rules turned 8–11% of buyers into non-buyers. Beverage-basket shares were paired with a total-expenditure regressor, which made the "income" elasticity a mix of two budgets. The routine's own bootstrap held the first stage fixed, so standard errors of 0.003–0.006 understated uncertainty; those small values were real software output, not typos.

**9. Reporting.** Each item has a constructive fix already in the rebuild. The abstract read substitution toward alcohol while the text and Table 5 reported negative responses to the SB price; orientation was not documented. Other items (identical SEs across goods, 82% urban in the text vs 0.22 rural in Table 1, the confounded Model 5 comparison) are in backup.

**10. Deaton's idea.** Spending divided by quantity mixes the market price, the quality the household chooses and noise. Within a local market the price is common, so differences between households reveal how quality and shares move with total spending. Between markets, average shares against average unit values, after removing quality and measurement error, reveal the price response. The key assumption is one price per municipality × area × quarter. Equations are in backup.

**11. Corrections.** Read one row as an example, not all five. Limitations to name: sparse beer and noisy water unit values; a selection term identified only by functional form; unconditional Marshallian elasticities; price variation that comes from regional differences; 100 of 500 replications and no survey-design variance. WELCOM's weighting is an approximation (household counts as sums of weights; register A-03).

**12. SB own-price.** M1 is −0.89 combined and −0.81 off-trade. M2 and M5 barely move; M3 (unweighted) is −0.98 but unstable under resampling, which is why its interval runs off the axis; M6 changes the population. M4, without regional controls, moves SB to −0.25: price differences between regions are confounded with taste differences, and the estimate leans on the regional controls. Say "specification sensitivity", not "bias". Inference is preliminary.

**13. Expenditure.** The selection term is a function of the same regressors as the share equation, including expenditure, and it enters a regression that includes the zeros, so it acts through functional form. It moves expenditure elasticities a lot and price elasticities very little. M1 stays the primary model; the manuscript reads M2 as the more interpretable expenditure response. Beer's −3.58 in M1 is an artefact, not an inferior good. These are total-expenditure elasticities, not income elasticities.

**14. Terciles and cross-price.** SB point estimates shrink toward zero from the lowest to the highest income tercile, but the lowest and highest intervals overlap and each tercile model has fewer unit values per cluster. Six of 20 cross-price intervals exclude zero, and six of 20 cells change sign without the symmetry restriction. Beer is sparse and spirits are absent, so no claim about substitution toward alcohol. Full matrices in backup; rows respond, columns change price.

**15. Status.** Completed: the rebuild from raw modules, all 32 models, the manuscript render from this run, the scripted legacy rerun. Awaiting verification: the bootstrap (resumable; about 7 more hours on 12 workers) and documentation mismatches (backup). New data or analysis: spirits and wine prices, on-trade quantities, the SSB split, and estimator alternatives (selection, weight counts, design-based inference, symmetry tests). Nothing is filled with a proxy.

**16. Spirits and wine.** About 11% of households buy them, but none of the 12,097 purchase records has a quantity: the monthly-recall module asks for the amount paid. Sequence: verify the instruments and separate true spirits and wine from beer that the legacy code filed as spirits; review the legacy estimates, whose "unit value" was spending per record; assess identification with an external price series matched by city, month, product and channel; only then decide on estimation. Do not promise an ENPH-only elasticity.

**17. Decisions.** Four questions, no owners or dates assigned: resume the bootstrap before results circulate; seek external alcohol prices or declare them out of scope; keep the WELCOM-only scope or add estimator alternatives and tax scenarios with intervals (the 2023 review asked how the elasticity informs a tax); purge household data and the confidential review from git history (blocker B-13) before any sharing.

**Close.** Read the sentence and stop. Backup follows.

## Backup (outside the 20 minutes)

| Title | Evidence |
| --- | --- |
| Published and rerun own-price elasticities diverge for Models 1–3 | Audit §1.6 table (typed once, historical) |
| Rerun expenditure elasticities came close only for SB and dairy | Audit §1.6 table (typed once, historical) |
| Reporting issues differ in kind: transcription, definition and interpretation | Legacy paper pp. 7–8 and Tables 1–6, checked in this session; audit §1.6, §2.4, §2.11, §2.13 |
| The 2023 review asked mainly for context and policy use, not new estimators | Food Policy review (confidential; paraphrased) |
| Monthly amounts follow DANE's frequency factors, module by module | `docs/methods.md` §3; DANE (2020); C-13, C-17 |
| Deaton's model pairs a unit-value and a budget-share equation | Manuscript §2.1; `docs/welcom_method.md` §1 |
| The main grid changes one element of M1 at a time; terciles re-estimate M1 | `results.rds` (`models`) |
| Seven sensitivity models move SB between −0.98 and −0.45 | `values.rds` (`own_S*`); point estimates only |
| Water is price-elastic; dairy and hot drinks sit near −1, a sign of weak information | `values.rds` (`own_M1_*`) |
| Primary cross-price matrices: rows respond, columns change price | `values.rds` (`cross_*`) |
| Without the symmetry restriction, 6 of 20 cross-price cells change sign | `results.rds` (`price`, `price_nosym`) |
| Local markets give SB, dairy and hot drinks more reliable mean unit values | `values.rds` (`reliability_*`) |
| Inference is preliminary, and WELCOM's printed standard errors are not usable | `results.rds` (`status`, `native`) |
| Spirits and wine: ENPH records spending, and estimation would need prices | B-1, A-08, C-06, C-22; `docs/methods.md` §3 |
| Run 20261117a is the manuscript's run, and every number here comes from it | `manifest.json`; `output/manuscript/20261117a/render_info.json` |
| Documentation mismatches to resolve before circulating | See below |

## Discrepancies found while building the deck

- `docs/legacy_to_new_map.md` says the legacy cluster was "replaced by the survey segment". The manuscript, `docs/methods.md` §5 and correction C-30 use local markets (municipality × area × quarter), with segments as sensitivity S5. The map looks stale.
- `docs/welcom_method.md` §8 says "segment-constant weights are passed"; §5 and the code pass weights constant within local markets.
- Audit revision 2 (§2.13) says the Table 1 row labels are "shifted down one row in the PDF". The Table 1 in `docs/Paper_20_1012_ElasticiBeverages.pdf` (p. 18) reads aligned, so this deck does not use that item. The audit may have referred to another copy.
- The legacy text says 82% of households are urban, while its Table 1 reports 0.22 rural (verified in the PDF; listed in backup).
- `dev/beautiful-deck.md` is missing; the skill copy `dev/beautiful-deck-SKILL.md` was used.

## Gate review items and how they were handled

- Words per slide above 40 on most content slides. The deck is a co-author working deck, where the standard allows a little more text. The densest slides (measurement map, corrections table, reporting table, scorecard) were cut and spaced after reading the rendered pages. The word counts also include table markup and the raw LaTeX of panel macros.
- Slide 12 title "over 78 characters": the count includes the inline R code; the rendered title has 75 characters and fits on one line.
- Slide 14 "table plus a bullet list": a deliberate two-part contrast (terciles beside cross-price); each half has one element.
- Eight `.bib` titles stored in Title Case (APA prints them as stored): DANE2018ENPH, DANE2020ENPHMetodologia, UN2018COICOP, MaldonadoGarciaJimenez2022Consumption, Deaton1988QualityQuantityPrice, Deaton1997HouseholdSurveys, CameronGelbachMiller2008, Heckman1979Selection. Fix in the reference manager, not in the deck.
