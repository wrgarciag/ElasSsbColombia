# Stage 06b: Tables 1-6 and supplementary tables, as machine-readable CSV and publication-ready LaTeX.
# Tables 1-2 come from output/tables/<run_id>/*.csv written by the validate stage; Tables 3-6 come from the
# shared results object. Nothing is typed in by hand.
#
# Registry (stable ids; see metadata/table_registry.csv):
#   T1 demographics | T2 consumption | T3 own-price by specification | T4 own-price by income tercile
#   T5 price-elasticity matrices | T6 expenditure elasticities by specification
#   A1 sample flow | A2 measurement coverage | A3-A4 supplementary sensitivity | A5 price clusters
#   A6 model summary | A7 confidence intervals | A8 WELCOM's own bootstrap output

table_registry <- function() data.table(
  table_id = c("T1", "T2", "T3", "T4", "T5", "T6", "A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8"),
  file_stem = c("table1_demographics", "table2_consumption", "table3_own_price", "table4_terciles", "table5_price_matrix",
                "table6_expenditure", "tableA1_sample_flow", "tableA2_measurement_coverage", "tableA3_sensitivity_own_price",
                "tableA4_sensitivity_expenditure", "tableA5_price_clusters", "tableA6_model_summary",
                "tableA7_confidence_intervals", "tableA8_welcom_native_se"),
  title = c("Household demographics", "Beverage purchase statistics", "Own-price elasticities and specification sensitivity",
            "Own-price elasticities by household income tercile", "Own- and cross-price elasticity matrices",
            "Expenditure elasticities and specification sensitivity", "Sample flow", "Measurement coverage",
            "Supplementary sensitivity: own-price elasticities", "Supplementary sensitivity: expenditure elasticities",
            "Price-cluster diagnostics", "Model summary", "Confidence intervals for the primary specification",
            "WELCOM's own bootstrap output compared with the external cluster bootstrap"),
  source = c("data/processed/estimation/est_primary_combined + households (R)", "data/interim/04_prices/household_category (R)",
             rep("output/estimates/<run_id>/estimates_long.csv (Stata, WELCOM duvm)", 4),
             "R", "R", rep("output/estimates/<run_id>/estimates_long.csv (Stata, WELCOM duvm)", 2), "R",
             "output/estimates/<run_id>/model_meta.csv", "output/estimates/<run_id>/estimates_long.csv",
             "output/estimates/<run_id>/welcom_native.csv"),
  models = c("", "", "M1-M6 x {home, combined}", "M1, T1-T3 x {home, combined}", "M1 x {home, combined}",
             "M1-M6 x {home, combined}", "", "", "M1, S1-S6 x {home, combined}", "M1, S1-S6 x {home, combined}", "", "all",
             "M1 x {home, combined}", "M1 x {home, combined}"),
  script = "code/R/06_report/02_tables.R")

market_labels <- function(cfg) c(home = cfg$markets$home$label, combined = cfg$markets$combined$label)

boot_note <- function(res, ids) {
  s <- res$status[model_id %in% ids]
  if (!res$has_inference || all(s$completed == 0)) return("Standard errors are not available: the external cluster bootstrap has not been run for this output.")
  ok <- s[reportable == TRUE]
  if (nrow(ok) == 0) return("Standard errors are not available for these models: too few cluster-bootstrap replications have been completed.")
  rng <- range(ok$completed)
  txt <- if (rng[1] == rng[2]) sprintf("%d", rng[1]) else sprintf("%d--%d", rng[1], rng[2])
  no_se <- sort(unique(sub("_.*$", "", s[reportable == FALSE, model_id])))
  paste0("Standard errors in brackets are standard deviations over ", txt, " cluster-bootstrap replications in which price clusters ",
         "are resampled within region cells and the whole WELCOM estimation is repeated (", sum(ok$failed), " failed replications). ",
         "\\textsuperscript{**} $p<0.01$, \\textsuperscript{*} $p<0.05$ (two-sided, normal approximation).",
         if (length(no_se)) paste0(" ", paste(no_se, collapse = ", "), ": too few completed replications; point estimates only.") else "",
         if (any(!s$reached_target & s$reportable)) " The replication target set in the configuration has not been reached for every model; inference is preliminary." else "")
}

# Estimates of one statistic for a set of models in wide form (goods x models), one market.
wide_cells <- function(res, cfg, stat_name, mk, specs, own_only = TRUE) {
  goods <- res$categories
  e <- res$est[stat == stat_name & market == mk & spec %chin% specs]
  if (stat_name == "price" && own_only) e <- e[row == col]
  rbindlist(lapply(goods, function(g) rbindlist(lapply(specs, function(s) {
    x <- e[row == g & spec == s]
    if (nrow(x) == 0) data.table(good = g, spec = s, estimate = NA_real_, se = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_, p_normal = NA_real_, reps = NA_integer_)
    else x[, .(good = g, spec = s, estimate, se, ci_lo, ci_hi, p_normal, reps = reps_completed)]
  }))))
}

# Goods left out of some (not all) of the models shown, with the reason recorded in the per-model contract.
partial_ne_note <- function(res, specs) {
  x <- res$contract[spec %chin% specs & estimable == FALSE & !good %chin% res$not_estimable]
  if (nrow(x) == 0) return(NULL)
  z <- x[, .(models = paste(sort(unique(spec)), collapse = ", "), reason = reason[1]), by = good]
  paste0(paste(sprintf("%s is not estimated in %s (%s)", res$labels[z$good], z$models, z$reason), collapse = "; "),
         ". A good enters a model only if its unit value is observed in enough clusters of that model's sample; models compared with each other (the income terciles) use the same goods.")
}

spec_table <- function(res, cfg, stat_name, specs, spec_heads, caption, label, extra_notes) {
  mk_lab <- market_labels(cfg); goods <- res$categories; labs <- res$labels
  body <- character(); csv <- list()
  for (mk in c("home", "combined")) {
    w <- wide_cells(res, cfg, stat_name, mk, specs)
    w[, market := mk]; csv[[mk]] <- w
    body <- c(body, tex_panel(mk_lab[[mk]], length(specs) + 1))
    for (g in goods) {
      x <- w[good == g][match(specs, spec)]
      body <- c(body, tex_row(labs[[g]], fmt_est(x$estimate, x$p_normal)))
      if (any(!is.na(x$se))) body <- c(body, tex_row("", fmt_se(x$se)))
    }
    m <- res$models[market == mk & spec %chin% specs][match(specs, spec)]
    body <- c(body, "\\addlinespace", tex_row("Households", fmt_int(m$n_households)), tex_row("Price clusters", fmt_int(m$n_clusters)))
  }
  ids <- res$models[spec %chin% specs, model_id]
  notes <- c(extra_notes, boot_note(res, ids),
             if (length(res$not_estimable)) paste0("n.e.: not estimable. ENPH records no physical quantity for ",
                                                   tolower(paste(res$labels[res$not_estimable], collapse = ", ")),
                                                   ", so no unit value exists and the good cannot enter the unit-value model."),
             partial_ne_note(res, specs))
  tex <- latex_table(caption, label, paste0("l", strrep("r", length(specs))), tex_row("", spec_heads), body, notes, size = "\\footnotesize")
  list(csv = rbindlist(csv), tex = tex)
}

run_tables <- function(cfg, run_id) {
  res <- readRDS(file.path(bundle_dir(cfg, run_id), "results.rds"))
  tdir <- function(f) p_out(cfg, "tables", run_id, f)
  need <- c("table1_demographics.csv", "table2_consumption.csv", "sample_flow.csv", "measurement_coverage.csv")
  check(all(file.exists(tdir(need))), "descriptive tables missing: run the 'validate' stage for this run id first")
  reg <- table_registry()
  write_csv(reg, p_meta(cfg, "table_registry.csv"))
  cats <- res$categories; labs <- res$labels
  units <- setNames(cfg$categories$quantity_unit, cats)
  mk_lab <- market_labels(cfg)
  hh <- readRDS(p_interim(cfg, "02_households", "households.rds"))
  terc <- fread(p_out(cfg, "diagnostics", run_id, "income_terciles.csv"))
  m1 <- res$models[spec == "M1"]
  wv <- paste0("WELCOM ", res$welcom$version)

  # ---------------- Table 1 ----------------
  t1 <- fread(tdir("table1_demographics.csv")); n1 <- fread(tdir("table1_notes.csv"))
  nv <- setNames(n1$value, n1$item)
  money <- t1$variable %chin% c("income", "income_pc", "exptot")
  body <- tex_row(tex_escape(t1$label)[1], "", "", "", "")[0]
  for (i in seq_len(nrow(t1))) {
    d <- if (money[i]) 0 else 2
    body <- c(body, tex_row(tex_escape(t1$label[i]), fmt_num(t1$mean[i], d), fmt_num(t1$sd[i], d),
                            fmt_num(t1$min[i], if (money[i] || t1$min[i] == round(t1$min[i])) 0 else 2),
                            fmt_num(t1$max[i], 0)))
  }
  notes1 <- c(sprintf("Estimation-eligible households (combined-market file): unweighted $N = %s$; sum of expansion factors $= %s$ households. Means and standard deviations are weighted by the ENPH expansion factor; minima and maxima are observed values.",
                      fmt_int(nv[["households_unweighted"]]), fmt_int(nv[["population_weight_total"]])),
              sprintf("Sex: 1 = male (P6020). Children: any member aged 0--%d. Education of the head (P6210): none or preschool; primary; secondary (b\\'asica secundaria or media); higher. %s heads report unknown education.",
                      cfg$sample$child_age_max, fmt_int(nv[["head_education_unknown"]])),
              sprintf("Income is DANE's total monthly income of the spending unit and expenditure is DANE's monthly current expenditure, both in 2016--2017 Colombian pesos (COP) and neither trimmed nor imputed; %s households report zero income.",
                      fmt_int(nv[["zero_income_households"]])))
  tex1 <- latex_table("Household demographics", "tab:demographics", "lrrrr",
                      tex_row("Variable", "Mean", "Std. dev.", "Min", "Max"), body, notes1)
  write_tex(tex1, tdir("table1_demographics.tex"))

  # ---------------- Table 2 ----------------
  t2 <- fread(tdir("table2_consumption.csv"))
  panel_lab <- c(coded_only__home = "A. Coded purchases only --- off-trade", coded_only__combined = "B. Coded purchases only --- combined market",
                 primary__home = "C. Coded and text-identified purchases --- off-trade", primary__combined = "D. Coded and text-identified purchases --- combined market")
  body <- character()
  for (p in names(panel_lab)) {
    x <- t2[panel == p][match(cats, category)]
    body <- c(body, tex_panel(panel_lab[[p]], 8))
    for (i in seq_len(nrow(x))) body <- c(body, tex_row(
      labs[[x$category[i]]], fmt_num(x$prevalence[i], 3), fmt_int(x$mean_spend_buyers_cop[i]),
      fmt_num(x$mean_share_beverage_basket[i], 3), fmt_num(100 * x$mean_share_total_expenditure[i], 3),
      ifelse(is.na(x$mean_unit_value_cop[i]), "n.a.", fmt_int(x$mean_unit_value_cop[i])),
      ifelse(is.na(x$mean_quantity_recorded[i]), "n.a.", fmt_num(x$mean_quantity_recorded[i], 2)),
      fmt_num(100 * x$spend_share_with_quantity[i], 1)))
  }
  hd2 <- c(tex_row("", "(1)", "(2)", "(3)", "(4)", "(5)", "(6)", "(7)"),
           tex_row("", "Purchase", "Spending,", "Share of", "Share of", "Unit", "Recorded", "Spending with"),
           tex_row("", "prevalence", "purchasers", "beverage", "total exp.", "value", "quantity", "quantity"),
           tex_row("", "", "(COP)", "basket", "(\\%)", "(COP)", "per month", "(\\%)"))
  nsmp <- t2[, .(n = n_households[1]), by = panel]
  notes2 <- c(
    sprintf("Weighted statistics for estimation-eligible households ($N = %s$ in panels A--C, %s in panel D). Monetary values in 2016--2017 COP per month.",
            fmt_int(nsmp[panel == "primary__home", n]), fmt_int(nsmp[panel == "primary__combined", n])),
    "(1) Share of eligible households with at least one valid purchase. (2) Mean monthly spending among purchasing households. (3) Mean share of the category in the household's spending on the six beverage categories, among households buying any of them. (4) Mean share of the category in total household current expenditure, all eligible households (the budget share used in estimation).",
    sprintf("(5) Mean observed unit value among households with a valid positive quantity: COP per litre, and COP per kilogram for %s. (6) Mean monthly quantity from purchases with a recorded volume or weight, averaged over all eligible households (litres; kilograms for %s); purchases without a recorded quantity are not counted, so (6) is a lower bound. (7) Share of category spending covered by recorded quantities.",
            tolower(labs[["hot"]]), tolower(labs[["hot"]])),
    "n.a.: not available. ENPH collects spirits and wine in a monthly-recall module without quantities. Away-from-home purchases carry no physical quantity, so columns (5) and (6) rest on at-home purchases in every panel.",
    "Text-identified purchases are records whose description names a single beverage and nothing else; all of them are away-from-home purchases, so panels A and C coincide.")
  tex2 <- latex_table("Beverage purchase statistics", "tab:consumption", "lrrrrrrr", hd2, body, notes2, size = "\\scriptsize")
  write_tex(tex2, tdir("table2_consumption.tex"))

  # ---------------- Tables 3 and 6 ----------------
  specs <- paste0("M", 1:6)
  heads <- c("M1", "M2", "M3", "M4", "M5", "M6")
  spec_note <- paste0("Columns: M1 primary specification (WELCOM \\texttt{duvm} with the selection term, sampling weights averaged within price clusters and region-by-area controls; coded and text-identified purchases; urban and rural households). ",
                      "M2 without the selection term. M3 without sampling weights. M4 without regional controls. M5 coded purchases only. M6 urban households only (a different target population). ",
                      "Each column changes one element of M1.")
  est_note3 <- paste0("Uncompensated (Marshallian) own-price elasticities of quantity from Deaton's unit-value model as implemented in ", wv,
                      " (quality-corrected, symmetry-restricted), unconditional on the beverage budget: budget shares and the expenditure regressor use total household current expenditure.")
  t3 <- spec_table(res, cfg, "price", specs, heads, "Own-price elasticities and specification sensitivity", "tab:ownprice", c(est_note3, spec_note))
  write_csv(t3$csv, tdir("table3_own_price.csv")); write_tex(t3$tex, tdir("table3_own_price.tex"))
  est_note6 <- paste0("Elasticities of quantity with respect to total household current expenditure (not income) from ", wv,
                      " \\texttt{duvm}: $1-\\beta^1_g+\\beta^0_g/\\bar w_g$, where $\\beta^0_g$ and $\\beta^1_g$ are the coefficients of log expenditure in the budget-share and unit-value regressions. Regional controls enter only the between-cluster stage, so M4 equals M1 by construction.")
  t6 <- spec_table(res, cfg, "expenditure", specs, heads, "Expenditure elasticities and specification sensitivity", "tab:expenditure", c(est_note6, spec_note))
  write_csv(t6$csv, tdir("table6_expenditure.csv")); write_tex(t6$tex, tdir("table6_expenditure.tex"))

  # ---------------- Table 4 ----------------
  specs4 <- c("M1", "T1", "T2", "T3")
  cutn <- sprintf("Terciles of per-capita total household income (DANE total income divided by household members), with cut-offs at COP %s and COP %s per month chosen so that each tercile holds one third of weighted households; households with zero income (%s) are in tercile 1.",
                  fmt_int(terc$cut_upper[1]), fmt_int(terc$cut_upper[2]), fmt_int(sum(terc$zero_income)))
  t4 <- spec_table(res, cfg, "price", specs4, c("All households", "Tercile 1", "Tercile 2", "Tercile 3"),
                   "Own-price elasticities by household income tercile", "tab:terciles",
                   c(est_note3, "Each tercile column is a separate WELCOM estimation of the primary specification on that tercile's households; no estimate is rescaled from the full sample.", cutn))
  write_csv(t4$csv, tdir("table4_terciles.csv")); write_tex(t4$tex, tdir("table4_terciles.tex"))

  # ---------------- Table 5 ----------------
  goods_est <- setdiff(cats, res$not_estimable)
  body <- character(); csv5 <- list()
  for (mk in c("home", "combined")) {
    e <- res$est[stat == "price" & spec == "M1" & market == mk]
    csv5[[mk]] <- e[, .(market, row, col, estimate, se, ci_lo, ci_hi, p_normal, reps = reps_completed)]
    body <- c(body, tex_panel(mk_lab[[mk]], length(goods_est) + 1))
    for (g in goods_est) {
      x <- e[row == g][match(goods_est, col)]
      body <- c(body, tex_row(labs[[g]], fmt_est(x$estimate, x$p_normal)))
      if (any(!is.na(x$se))) body <- c(body, tex_row("", fmt_se(x$se)))
    }
  }
  notes5 <- c(paste0("Primary specification (M1). Rows: beverage whose quantity responds. Columns: beverage whose price changes. Diagonal cells are the own-price elasticities of Tables~\\ref{tab:ownprice} and~\\ref{tab:terciles}. ",
                     "Uncompensated elasticities, quality-corrected, with the symmetry restriction imposed by \\texttt{duvm}; unconditional on the beverage budget."),
              boot_note(res, m1$model_id),
              sprintf("%s cannot be included (no physical quantities in ENPH). The joint bootstrap covariance matrix of all cells is in \\texttt{output/estimates/%s/covariance\\_long.csv}.",
                      paste(labs[res$not_estimable], collapse = ", "), tex_escape(run_id)))
  tex5 <- latex_table("Own- and cross-price elasticity matrices", "tab:matrix", paste0("l", strrep("r", length(goods_est))),
                      tex_row("Quantity of $\\downarrow$ / price of $\\rightarrow$", labs[goods_est]), body, notes5, size = "\\footnotesize")
  write_csv(rbindlist(csv5), tdir("table5_price_matrix.csv")); write_tex(tex5, tdir("table5_price_matrix.tex"))

  # ---------------- A1 sample flow ----------------
  fl <- fread(tdir("sample_flow.csv"))
  texA1 <- latex_table("Sample flow", "tab:sampleflow", "p{10.5cm}rr", tex_row("Step", "Households", "Weighted"),
                       vapply(seq_len(nrow(fl)), function(i) tex_row(tex_escape(fl$step[i]), fmt_int(fl$households[i]), fmt_int(fl$weighted_households[i])), ""),
                       "No household is dropped for having no beverage purchase: such households enter with zero budget shares. The legacy analysis file is shown for reference only.", size = "\\footnotesize")
  write_csv(fl, tdir("tableA1_sample_flow.csv")); write_tex(texA1, tdir("tableA1_sample_flow.tex"))

  # ---------------- A2 measurement coverage ----------------
  cv <- fread(tdir("measurement_coverage.csv"))[market %chin% c("home", "combined")]
  body <- character()
  for (mk in c("home", "combined")) {
    x <- cv[market == mk][match(cats, category)]
    body <- c(body, tex_panel(mk_lab[[mk]], 8))
    for (i in seq_len(nrow(x))) body <- c(body, tex_row(labs[[x$category[i]]], fmt_int(x$buyers[i]), fmt_int(x$buyers_with_recorded_quantity[i]),
      fmt_int(x$unit_values_used[i]), fmt_int(x$unit_value_outliers_flagged[i]), fmt_num(100 * x$spend_share_with_recorded_quantity[i], 1),
      fmt_num(100 * x$spend_share_text_identified[i], 1), fmt_int(x$households_composite_mention_and_no_attributable_purchase[i])))
  }
  texA2 <- latex_table("Measurement coverage by beverage and market (primary data)", "tab:coverage", "lrrrrrrr",
                       c(tex_row("", "Buying", "\\ldots with", "Unit values", "Unit values", "Spending with", "Text-identified", "Composite"),
                         tex_row("", "households", "quantity", "used", "flagged", "quantity (\\%)", "spending (\\%)", "mention only")),
                       body,
                       c("Unweighted household counts; spending shares are weighted. `Unit values flagged' are observed unit values outside the robust log-scale band and not passed to WELCOM; the household keeps its budget share.",
                         "`Composite mention only': households whose only evidence of buying the beverage is a description that also lists other items (for example a meal with a drink); the amount cannot be attributed and the household counts as a non-buyer of that beverage."),
                       size = "\\scriptsize")
  write_csv(cv, tdir("tableA2_measurement_coverage.csv")); write_tex(texA2, tdir("tableA2_measurement_coverage.tex"))

  # ---------------- A3 / A4 supplementary sensitivity ----------------
  specsS <- c("M1", paste0("S", 1:7))
  sn <- paste0("S1 broad SB definition. S2 unit values from directly recorded units only. S3 reference-period scaling of recall periods. ",
               "S4 extreme spenders excluded. S5 price clusters defined as survey segments. S6 raw household expansion factors passed to WELCOM (legacy calling convention). S7 beer left out of the system. ",
               "S1--S3 change measurements on the same households; S4 changes the sample.")
  a3 <- spec_table(res, cfg, "price", specsS, specsS, "Supplementary sensitivity analyses: own-price elasticities", "tab:sensown", c(est_note3, sn))
  write_csv(a3$csv, tdir("tableA3_sensitivity_own_price.csv")); write_tex(a3$tex, tdir("tableA3_sensitivity_own_price.tex"))
  a4 <- spec_table(res, cfg, "expenditure", specsS, specsS, "Supplementary sensitivity analyses: expenditure elasticities", "tab:sensexp", c(est_note6, sn))
  write_csv(a4$csv, tdir("tableA4_sensitivity_expenditure.csv")); write_tex(a4$tex, tdir("tableA4_sensitivity_expenditure.tex"))

  # ---------------- A5 price clusters ----------------
  pc <- fread(p_out(cfg, "diagnostics", run_id, "price_cluster_variation.csv"))[market == "home" & cluster_def %chin% c("market", "segment")]
  ps <- fread(p_out(cfg, "diagnostics", run_id, "price_cluster_sizes.csv"))
  body <- character()
  for (cd in c("market", "segment")) {
    z <- ps[cluster_def == cd]
    body <- c(body, tex_panel(sprintf("%s: %s clusters, median %s households (10th--90th percentile %s--%s)",
                                      c(market = "Local market: municipality $\\times$ area $\\times$ quarter (primary)", segment = "Survey segment (sensitivity S5)")[[cd]],
                                      fmt_int(z$clusters), fmt_int(z$median_size), fmt_int(z$p10_size), fmt_int(z$p90_size)), 7))
    x <- pc[cluster_def == cd][match(cats, category)]
    for (i in seq_len(nrow(x))) body <- c(body, tex_row(labs[[x$category[i]]], fmt_int(x$unit_values[i]), fmt_int(x$clusters_with_unit_value[i]),
      fmt_num(x$harmonic_unit_values_per_cluster[i], 1), fmt_num(x$sd_log_uv[i], 2), fmt_num(x$share_variance_between[i], 2), fmt_num(x$reliability_cluster_mean[i], 2)))
  }
  texA5 <- latex_table("Price-cluster diagnostics (off-trade unit values)", "tab:clusters", "lrrrrrr",
                       c(tex_row("", "Unit", "Clusters with", "Unit values per", "SD of log", "Between-cluster", "Reliability of"),
                         tex_row("", "values", "a unit value", "cluster (harmonic)", "unit value", "variance share", "cluster mean")),
                       body,
                       c("Neither definition mixes urban and rural households. A local market spans one collection quarter; a survey segment one month and lies inside one local market.",
                         "Between-cluster variance share: one-way decomposition of the log unit value; it mixes price differences with differences in quality and package size.",
                         "Reliability of the cluster mean: share of the variance of cluster-mean log unit values that is not within-cluster sampling noise, $1-(s^2_w/\\tilde n)/\\mathrm{var}(\\bar v_c)$, with $\\tilde n$ the harmonic mean of unit values per cluster."),
                       size = "\\footnotesize")
  write_csv(pc, tdir("tableA5_price_clusters.csv")); write_tex(texA5, tdir("tableA5_price_clusters.tex"))

  # ---------------- A6 model summary ----------------
  ms <- res$models[order(market, spec), .(model_id, label, sample, csb, weight, region, cluster, n_households, n_clusters,
                                         boot_completed, boot_failed, boot_target)]
  texA6 <- latex_table("Model summary", "tab:models", "lp{5.2cm}rrrrr",
                       tex_row("Model", "Specification", "Households", "Clusters", "Replications", "Failed", "Target"),
                       vapply(seq_len(nrow(ms)), function(i) tex_row(tex_escape(ms$model_id[i]), tex_escape(ms$label[i]), fmt_int(ms$n_households[i]),
                                                                     fmt_int(ms$n_clusters[i]), fmt_int(ms$boot_completed[i]), fmt_int(ms$boot_failed[i]), fmt_int(ms$boot_target[i])), ""),
                       paste0("All models are estimated with ", wv, " \\texttt{duvm}. Replications: completed external cluster-bootstrap replications."), size = "\\scriptsize")
  write_csv(ms, tdir("tableA6_model_summary.csv")); write_tex(texA6, tdir("tableA6_model_summary.tex"))

  # ---------------- A7 confidence intervals (primary specification) ----------------
  ci <- res$est[spec == "M1" & ((stat == "price" & row == col) | stat == "expenditure"),
                .(market, stat, good = row, estimate, se, ci_lo, ci_hi, p_normal, reps = reps_completed)]
  body <- character()
  for (mk in c("home", "combined")) {
    body <- c(body, tex_panel(mk_lab[[mk]], 5))
    for (g in goods_est) {
      a <- ci[market == mk & stat == "price" & good == g]; b <- ci[market == mk & stat == "expenditure" & good == g]
      body <- c(body, tex_row(labs[[g]], fmt_est(a$estimate), fmt_ci(a$ci_lo, a$ci_hi), fmt_est(b$estimate), fmt_ci(b$ci_lo, b$ci_hi)))
    }
  }
  texA7 <- latex_table("Primary specification: point estimates and 95\\% percentile bootstrap confidence intervals", "tab:ci", "lrrrr",
                       tex_row("", "Own-price", "95\\% CI", "Expenditure", "95\\% CI"), body,
                       "Percentile intervals from the external cluster bootstrap (2.5th and 97.5th percentiles of the replications).", size = "\\footnotesize")
  write_csv(ci, tdir("tableA7_confidence_intervals.csv")); write_tex(texA7, tdir("tableA7_confidence_intervals.tex"))

  # ---------------- A8 WELCOM's own bootstrap output vs the external bootstrap ----------------
  if (!is.null(res$native) && nrow(res$native)) {
    nat <- copy(res$native); nat[is.na(col), col := ""]
    own <- nat[row == col & stat %chin% c("welcom_table09_as_printed", "welcom_boot_sd_correct_cell")]
    own <- dcast(own, model_id + row ~ stat, value.var = "value")
    ext <- res$est[spec == "M1" & stat == "price" & row == col, .(model_id, row, market, estimate, external_se = se)]
    a8 <- merge(ext, own, by = c("model_id", "row"))
    body <- character()
    for (mk in c("home", "combined")) {
      body <- c(body, tex_panel(mk_lab[[mk]], 5))
      x <- a8[market == mk][match(goods_est, row)]
      for (i in seq_len(nrow(x))) body <- c(body, tex_row(labs[[x$row[i]]], fmt_est(x$estimate[i]), fmt_num(x$welcom_table09_as_printed[i], 4),
                                                          fmt_num(x$welcom_boot_sd_correct_cell[i], 4), fmt_num(x$external_se[i], 4)))
    }
    texA8 <- latex_table("Own-price elasticities: WELCOM's own bootstrap output and the external cluster bootstrap", "tab:native", "lrrrr",
                         c(tex_row("", "Estimate", "WELCOM", "WELCOM replications:", "External cluster"),
                           tex_row("", "", "Table 09", "SD of correct cell", "bootstrap SE")),
                         body,
                         c(sprintf("WELCOM Table 09 is printed by \\texttt{duvm} with \\texttt{boot(%d)}: it is the standard error of the mean of the replications, taken from a cell that does not correspond to the own-price elasticity for goods other than the first, with the first-stage regressions held fixed.", cfg$estimation$welcom_native_boot),
                           "Third column: standard deviation of WELCOM's own replications for the correct cell (first stage still fixed). Fourth column: the standard error used in this paper."),
                         size = "\\footnotesize")
    write_csv(a8, tdir("tableA8_welcom_native_se.csv")); write_tex(texA8, tdir("tableA8_welcom_native_se.tex"))
  }
  log_msg("Tables written to ", tdir(""))
  invisible(TRUE)
}
