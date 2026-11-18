# Claude Code prompt: 20-minute ENPH beverage-elasticity handoff deck

Work in the `work-personal-ssbelasticity` repository. Create a **high-level, 20-minute presentation** in R Markdown Beamer at **`reports/slides-handsoff.Rmd`**. Keep that exact filename. This is a research handoff and discussion with collaborators: explain the evidence, what the audit established, how the rebuilt estimation differs, what the current manuscript reports, and the decisions still pending.

Use **`dev/beautiful-deck.md`** as the deck-writing and review standard. Adapt **`reports/beamer_preamble.tex`** to this project, and use **APA author–year citations from `manuscript/references.bib`**. Deliver the deck source and a rendered PDF if the toolchain and required saved results are available. Do the work, rather than returning only a proposed outline.

**Consult `manuscript/manuscript.Rmd` in full before outlining or drafting the slides.** Use its current account of the ENPH data, measurement decisions, model, estimation, results, limitations, and pending work to guide the presentation. Follow its links to saved results and supporting tables; keep the deck consistent with the manuscript and flag any unresolved discrepancies with the audit or legacy paper.

## 1. Read the project before drafting

Read repository instructions (`AGENTS.md`, `CLAUDE.md`, if present), then:

- `dev/beautiful-deck.md`. If missing, locate the supplied `beautiful-deck-SKILL.md` or equivalent project copy and use it; report the fallback.
- `reports/beamer_preamble.tex`, existing Beamer decks, and any deck-specific addons and compile gate.
- **The current `manuscript/manuscript.Rmd`**, its rendered PDF if available, and `manuscript/references.bib`.
- The latest reproducibility audit/diagnosis, including `reproducibility_audit*.md`, its replication results, comparison tables, logs, and any subsequent updates. Locate the former paper (`Paper_20_1012_ElasticiBeverages.pdf`, `paper_20_10_12*.pdf`, or its actual repository equivalent) to check published tables and wording.
- Any available review notes or annotations relevant to reporting and interpretation. Use only comments and findings supported by the actual sources.
- Current model configuration, reporting scripts, manifests, and saved manuscript results. Inspect the actual objects before deciding which figures and estimates to show.

Treat the current manuscript and its matching validated result bundle as authoritative for updated methods and results. Treat the audit and legacy paper as historical evidence. If later evidence resolves an audit uncertainty, report the resolved status and its source. Do not carry an old problem forward as an open problem without checking.

Write a short storyboard with assertion titles, evidence sources, and speaking times beside the deck. Proceed directly to implementation using the brief below; no intermediate outline approval is needed for this task. Aim for roughly **16–18 main slides including the opening and closing**, with a timed narrative totaling 20 minutes; backup and reference slides are outside that limit. Adjust slide count to preserve pacing and readability.

## 2. Narrative and content

Organize the talk around four parts, in this order. Use an opening that states the research problem and stakes before moving into the survey. Keep the technical details in backup and presenter notes.

### A. Explain ENPH as it is actually used in estimation — about 4 minutes

Explain Colombia's 2016–2017 National Household Budget Survey (ENPH), the household universe and estimation sample, and the urban/rural coverage. Draw sample counts and population totals from the current saved results; distinguish the legacy sample from the rebuilt universe and analytic sample.

Use one compact measurement map to show **survey instrument → expenditure → usable quantity → unit value → role in estimation**. Verify the details against the current code and manuscript:

- Urban household diary: 14 days; rural household questionnaire: weekly. These provide at-home spending, quantities, and units.
- Personal diaries, away-from-home records, and monthly-recall purchases contribute expenditure but lack usable physical units for constructing unit values. Spirits and wine are collected in the monthly-recall module.
- Purchases are converted to monthly amounts using the documented DANE rules. Measures describe purchases, not individual intake.
- Separate coded purchases, identifiable beverage-only text records, and composite purchases such as meals with drinks. Explain why a composite purchase's full value cannot be assigned to the beverage.
- Explain the beverage groups briefly. Distinguish **sweetened beverages (SB)** from identifiable **sugar-sweetened beverages (SSB)**: the classifications cannot separate SSB from non-sugar-sweetened beverages. Keep dairy and hot drinks distinct in the rebuilt analysis.
- Define off-trade and combined markets. The combined market adds away-from-home expenditure but uses the same observed at-home unit values. There is no separately identified on-trade price-elasticity model under the current measurement design.

Make clear that **recorded expenditure does not imply an observed price**. Use that fact to transition into the audit.

### B. Explain what the audit reproduced, what it did not, and why — about 5 minutes

Present this as an evidence diagnosis, with a **charming, warm, constructive, and collegial tone**. Recognize the substantial work behind the former analysis and begin with what was successfully recovered and reproduced. Describe problems as shared opportunities to strengthen the paper; focus on the code, evidence, and reporting rather than on individuals. Use natural language such as “We recovered much of the original analysis” and “The audit helped us identify where the estimates need a firmer foundation,” only where supported. Avoid blame, sarcasm, defensiveness, or a prosecutorial list of mistakes. Warmth should come from generous framing and clear explanations, without minimizing confirmed errors or uncertainty. Separate **reproducibility**, **measurement/estimator problems**, and **reporting/interpretation flaws**. Reproducing an output does not validate its method; a failed replication does not establish which suspected cause is responsible.

Use a compact replication scorecard, with detailed table-by-table comparisons in backup. The supplied revision-2 audit provides the following historical baseline; verify it against the latest repository evidence before presenting it:

- The unchanged legacy R code, with external path and encoding shims, reproduced coded spending exactly for SB, beer, milk, hot drinks, and spirits plus wine in the 82,934-household legacy input. Water and text-recovered purchases did not all match, reflecting category and classifier differences.
- Legacy Table 1 demographics and income rows reproduced from the supplied frozen input.
- Legacy Table 2's corrected full-market panel reproduced within the audit tolerance; off-trade nearly reproduced after realigning a permuted consumption column, with a remaining SB purchase-share discrepancy. Coded-only panels reproduced only partly, and their “Dairy” definition differed.
- Own-price, cross-price, and income-tercile results were not fully reproduced. Some total-expenditure elasticities were close, especially SB and dairy; this was not full replication of the elasticity tables.
- Models 1–3 ran. The coded-only and on-trade paths had missing-variable/input failures; code for legacy Models 4 and 6 was not found in the audit.

If helpful, show **one** historical numeric example, clearly labeled as published versus legacy rerun, rather than overwhelming the audience with the full comparison. The audit reports SB own-price estimates of −0.438 versus −0.503 for full-market Model 1 and −0.469 versus −0.355 off-trade. Verify these against the audit table/log; never label them as the updated estimates.

For the unresolved replication gaps, distinguish confirmed blockers from candidate explanations: WELCOM 2.1 reported versus 2.30 used in the audit; 354 reported versus 384 reconstructed clusters; symmetry-table choice; unseeded imputation; and missing original logs or construction code. **These are audit-era hypotheses or missing evidence, not proven explanations.** Do not repeat the superseded claim that legacy clusters mixed urban and rural households: revision 2 explicitly corrected it.

Summarize the substantive flaws by consequence, using only a few examples on main slides:

- Predicted prices for non-buyers were passed as observed unit values; unsupported quantity assumptions and weight-to-volume conversions weakened price measurement.
- Trimming rules turned buyers into non-buyers; composite text spending, misclassification, and inconsistent category definitions affected consumption measures.
- Beverage-budget shares were combined with total expenditure; the estimand and labels were inconsistent.
- The routine's internal bootstrap held the household stage fixed, contributing to misleadingly small uncertainty estimates.

Cover **identified reporting and interpretation flaws with warmth and tact**, using independently verified audit findings and available review notes. Useful verified examples include shifted demographic row labels, the permuted consumption column, inconsistent dairy definitions, “income” used for total-expenditure elasticities, undocumented cross-price matrix orientation, confounded Model 5 comparisons, and claims of alcohol substitution inconsistent with the reported signs. Distinguish genuine transcription errors from very small standard errors that were real software output. Frame each issue around what clearer reporting or a correction contributes to the paper, and acknowledge what the original analysis already established.

### C. Explain the updated model and estimation in the current manuscript — about 7 minutes

Explain Deaton's unit-value approach intuitively: expenditure divided by quantity mixes market price, household quality choice, and measurement error. Household comparisons within markets help separate quality from expenditure effects; variation between markets then informs price responses after correction. State the common-price-within-market assumption. Put the full equations and derivation in backup; at most one simple equation is needed in the main talk.

Show a short **problem → implemented correction → remaining limitation** comparison tied to the current implementation:

- Rebuild from raw ENPH modules, document sample flow, retain zero-purchase households in share equations, and use DANE expenditure/income totals as described in the manuscript.
- Construct unit values only from valid observed positive quantities; do not predict unit values for non-buyers. Flag invalid/extreme unit values without deleting their household budget shares.
- Use budget shares and the expenditure regressor defined on the same total household budget.
- Use municipality × urban/rural area × collection quarter price clusters and regional/quarter controls; retain survey-segment clusters as sensitivity analysis.
- Describe WELCOM/`duvm`, quality and measurement-error corrections, symmetry restrictions, weighting approximation, and the external cluster bootstrap in plain language. Read the actual WELCOM version and bootstrap completion status from the selected run.

Show the primary model and its five one-change alternatives compactly: M1 with selection term, weights, regional controls, coded plus identifiable text purchases, urban plus rural households; M2 without the selection term; M3 without weights; M4 without regional controls; M5 coded purchases only; M6 urban households only. Explain that **M6 changes the target population**, whereas M2–M5 use the same households as M1. Clearly distinguish this current grid from the incomplete legacy grid.

Then present the **actual current results**, with emphasis on SB:

- Own-price estimates for combined and off-trade markets, with available percentile intervals and specification sensitivity. Prefer a readable coefficient plot derived from the saved results, redesigned for slides.
- The substantive lesson from M1 versus M2 total-expenditure elasticities. The manuscript regards M2 as more interpretable for expenditure responses; explain why the selection term without an exclusion restriction can drive functional-form effects. Do not silently redefine M2 as the primary model.
- A brief account of income-tercile and cross-price findings only if supported and useful. Cross-price rows indicate the quantity responding; columns indicate the price changing. Discuss sensitivity to symmetry and sparse beer unit values. Put full matrices in backup.

Use **Marshallian/uncompensated**, **unconditional on the beverage budget**, and **total-expenditure elasticity** accurately. Explain technical terms briefly or move them to backup. Do not call these causal tax effects, describe specification changes as demonstrated bias, assert a robust alcohol-substitution result, or treat an estimate near −1 as strong evidence when the data are weakly informative. Let the selected results determine the assertion titles.

### D. Close with next steps and decisions, including spirits and wine — about 4 minutes

End with a short, prioritized work plan that distinguishes **completed**, **awaiting verification**, and **new analysis/data needed**, based on actual current project status. Do not present historical refactoring proposals as still pending if already implemented.

Give **spirits and wine** explicit attention:

1. Verify their source modules, coding, recall period, quantity/unit fields, and category separation; distinguish true spirits/wine records from historically misclassified beer.
2. Review the provenance and validity of the former spirits/wine estimates. The current manuscript says their price elasticities cannot be estimated from ENPH unit values because usable quantities are absent. Present this as the current finding, subject to checking the original instruments—not as an ordinary model waiting to be run.
3. Identify what would make estimation possible: an appropriate external price series, linked product/outlet data, or another justified design. Explain that any proposed external prices require matching to geography, time, product coverage, and purchase channels. Do not fabricate prices or restore the legacy quantity assumptions.
4. Separate reviewing old estimates, evaluating identification, and producing new estimates. Do not promise that a new ENPH-only spirits/wine elasticity will be feasible.

Other priorities may include completing bootstrap targets, reviewing sparse beer and noisy water unit values, estimator/selection alternatives, weighting and survey-design inference, and testing restrictions. Verify which are truly pending. Include the decisions collaborators need to make; do not assign people or deadlines without evidence.

Close with one evidence-supported sentence linking credible elasticity estimates to transparent measurement and remaining identification limits. The main talk should end on that message, with backup material afterward.

## 3. Presentation and technical requirements

- Keep this a **spoken, high-level deck**, not a compressed paper or code walkthrough. Use assertion titles, one main idea per slide, generous white space, short labels, readable visuals, and concise presenter notes. Explain why corrections matter before technical mechanics. Put algebra, full tables, model grids, detailed audit evidence, and diagnostics in backup.
- Follow `dev/beautiful-deck.md` for layout, source comments, citation checking, and visual review. Suggested backups: replication table; reporting issues and verified reviewer comments; survey measurement map; Deaton equations; exact specification grid; full price matrices; bootstrap status/diagnostics; spirits/wine feasibility.
- **Adapting `reports/beamer_preamble.tex` is explicitly authorized.** Preserve its clean house style while replacing unrelated Indonesia CVD, World Bank, Disease Control Priorities, or scenario labels with accurate Colombia beverage-study branding and metadata. Do not imply institutional sponsorship. Check other decks before changing shared definitions; use deck-local overrides/addons for changes that would disrupt them. Keep unrelated decks usable.
- Configure `rmarkdown::beamer_presentation`, XeLaTeX, and APA citations from `../manuscript/references.bib`, resolving paths correctly from `reports/`. Use the supported APA bibliography stack, with existing verified citation keys only. Generate references automatically for cited works. Do not hand-type author–year citations or edit the reference-manager bibliography. The supplied `apa.csl` is available if needed by the chosen citation workflow; do not combine incompatible CSL and biblatex configurations.
- Use references already in the manuscript for DANE/ENPH, Deaton, WELCOM, selection, and bootstrap methods after confirming their keys and supporting content. Internal audit findings and comments should have accurate internal source labels/notes, not invented academic citations.
- **Load the same validated run as the manuscript.** Reuse its `run_id`, `results.rds`, `values.rds`, and `manifest.json` approach; verify run consistency, configuration hashes, completeness, and inference status. Display or record run provenance in notes/backup. Do not mix runs or choose a different latest run during rendering.
- Read numeric analysis claims from saved objects through inline R, including numbers in titles. Do not copy estimates from memory or infer values from the unevaluated manuscript source. For legacy audit examples, trace values to an audit table or log and document the source. Check assertions against the loaded values.
- **Do not rerun the estimation pipeline as part of knitting.** Reuse outputs or rebuild presentation figures from saved summaries. If a required bundle is absent, report the exact dependency and producing command/script when known; deliver an honestly labeled draft without invented results. An explicit draft option may allow incomplete inference, with visible preliminary labels. Missing estimates should appear as pending/unavailable, never as zero or dummy values.
- Do not modify raw data, legacy scripts, production estimation scripts, manuscript text, or bibliography to create the deck. Limit implementation changes to the requested deck, justified preamble adaptations, and necessary deck-support files.
- Compile and inspect every rendered slide, including backup and references. Fix overflow, clipped labels, undefined citations, missing glyphs, and warnings at their source; do not shrink text or suppress warnings to make a slide fit. Use the existing gate with a 20-minute budget if available. If the toolchain, fonts, data, or evidence prevent a clean final render, report that precisely and distinguish an unverified source/draft from a validated PDF.

## 4. Deliverables and completion report

Provide:

1. `reports/slides-handsoff.Rmd` and, when successfully rendered, `reports/slides-handsoff.pdf`.
2. A concise storyboard/timing file and any necessary deck-specific support files.
3. A short completion note listing the files created/changed, main-talk timing, selected analysis run, render/review status, and unresolved evidence needs—especially bootstrap completion and spirits/wine feasibility.

The result should let a collaborator understand **what ENPH measures, which former findings can be reconstructed, what changed in the updated analysis, and what evidence or decisions are needed next** within 20 minutes.
