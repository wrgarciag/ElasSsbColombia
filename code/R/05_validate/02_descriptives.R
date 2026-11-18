# Stage 05b: descriptive statistics computed in R from the analysis-ready data.
#   table1_demographics.csv   Table 1 (weighted mean and SD, observed min and max)
#   table2_consumption.csv    Table 2 (four panels: coded only / coded + text  x  off-trade / combined)
#   sample_flow.csv           household sample flow
#   measurement_coverage.csv  supplementary: what is and is not measured, by category and market
# All statistics use observed values only: unit values of non-buyers do not exist and are not used.

analysis_sample <- function(cfg, variant = "primary", market = "combined") {
  readRDS(p_processed(cfg, "estimation", sprintf("est_%s_%s.rds", variant, market)))[in_sample == 1, hhid]
}

run_descriptives <- function(cfg, run_id) {
  hh <- readRDS(p_interim(cfg, "02_households", "households.rds"))
  hc <- readRDS(p_interim(cfg, "04_prices", "household_category.rds"))
  tx <- readRDS(p_interim(cfg, "03_consumption", "transactions.rds"))
  cats <- cfg$categories$ids
  labs <- setNames(cfg$categories$labels, cats)
  units <- setNames(cfg$categories$quantity_unit, cats)
  tdir <- function(f) p_out(cfg, "tables", run_id, f)

  # ---------------- Table 1 ----------------
  ids <- analysis_sample(cfg)
  s <- hh[hhid %in% ids]
  vars <- list(
    head_male = "Household head is male (1 = male, 0 = female)", head_age = "Age of household head (years)",
    rural = "Rural (centros poblados and dispersed rural = 1)", hhsize = "Household members",
    single = "Single-member household", children = "Children aged 0-5 in the household",
    educ_none = "Head education: none or preschool", educ_primary = "Head education: primary",
    educ_secondary = "Head education: secondary", educ_higher = "Head education: higher",
    income = "Total monthly household income (COP)", income_pc = "Monthly income per member (COP)",
    exptot = "Total monthly current expenditure (COP)")
  t1 <- rbindlist(lapply(names(vars), function(v) data.table(
    variable = v, label = vars[[v]], mean = w_mean(s[[v]], s$weight), sd = w_sd(s[[v]], s$weight),
    min = min(s[[v]], na.rm = TRUE), max = max(s[[v]], na.rm = TRUE), n_valid = sum(!is.na(s[[v]])))))
  t1[, `:=`(n_households = nrow(s), weight_total = sum(s$weight))]
  write_csv(t1, tdir("table1_demographics.csv"))
  t1n <- data.table(item = c("households_unweighted", "population_weight_total", "head_education_unknown",
                             "zero_income_households", "households_all_enph"),
                    value = c(nrow(s), sum(s$weight), sum(s$educ == 9L), sum(s$income <= 0), nrow(hh)))
  write_csv(t1n, tdir("table1_notes.csv"))

  # ---------------- Table 2 ----------------
  panels <- CJ(variant = c("coded_only", "primary"), market = c("home", "combined"), sorted = FALSE)
  t2 <- rbindlist(lapply(seq_len(nrow(panels)), function(i) {
    vn <- panels$variant[i]; mk <- panels$market[i]
    pid <- analysis_sample(cfg, vn, mk)
    x <- hc[variant == vn & market == mk & hhid %in% pid]
    x[, basket := sum(spend), by = hhid]                      # beverage basket: the six categories
    x[, basket_share := fifelse(basket > 0, spend / basket, NA_real_)]
    x[, .(panel = paste(vn, mk, sep = "__"), variant = vn, market = mk,
          n_households = .N, weight_total = sum(weight),
          prevalence = w_mean(as.numeric(buyer), weight),
          n_buyers = sum(buyer),
          mean_spend_buyers_cop = w_mean(spend[buyer], weight[buyer]),
          mean_share_beverage_basket = w_mean(basket_share, weight),
          n_basket = sum(!is.na(basket_share)),
          mean_share_total_expenditure = w_mean(share, weight),
          mean_unit_value_cop = w_mean(uv[uv_use], weight[uv_use]),
          median_unit_value_cop = if (any(uv_use)) w_quantile(uv[uv_use], weight[uv_use], 0.5) else NA_real_,
          n_unit_values = sum(uv_use),
          mean_quantity_recorded = w_mean(fifelse(is.na(qty), 0, qty), weight),
          mean_quantity_buyers_with_quantity = w_mean(qty[!is.na(qty)], weight[!is.na(qty)]),
          n_buyers_with_quantity = sum(!is.na(qty)),
          spend_share_with_quantity = sum(spend_q * weight) / sum(spend * weight)),
      by = category]
  }))
  t2[, `:=`(label = labs[category], quantity_unit = units[category])]
  t2[n_unit_values == 0, `:=`(mean_unit_value_cop = NA_real_, median_unit_value_cop = NA_real_,
                              mean_quantity_recorded = NA_real_, mean_quantity_buyers_with_quantity = NA_real_)]
  t2[, category := factor(category, levels = cats)]
  setorder(t2, variant, market, category)
  write_csv(t2, tdir("table2_consumption.csv"))

  # ---------------- sample flow ----------------
  est <- readRDS(p_processed(cfg, "estimation", "est_primary_combined.rds"))
  esth <- readRDS(p_processed(cfg, "estimation", "est_primary_home.rds"))
  hx <- merge(hh, est[, .(hhid, in_sample, any_beverage)], by = "hhid")
  flow <- data.table(
    step = c("ENPH 2016-2017 households (public-use file)",
             "... answering the urban 14-day diary",
             "... answering the rural weekly questionnaire",
             "With positive DANE current expenditure",
             "With complete household-head covariates",
             "With valid budget shares (no category or total above total expenditure), combined market",
             "In a price cluster (local market) of at least two households = estimation-eligible, combined market",
             "Estimation-eligible, off-trade market",
             "... of which urban (cabeceras)",
             "... of which rural",
             "... with at least one valid beverage purchase (combined market)",
             "... with no beverage purchase recorded (kept as true zeros)",
             "Legacy analysis file (households with a beverage record and below 16 litres per person-day)"),
    households = c(nrow(hh), sum(hh$food_form == "urban_diary"), sum(hh$food_form == "rural_weekly"),
                   sum(hh$exptot_valid), sum(hh$exptot_valid & !is.na(hh$head_age) & !is.na(hh$educ)),
                   NA, sum(est$in_sample), sum(esth$in_sample),
                   hx[in_sample == 1, sum(rural == 0)], hx[in_sample == 1, sum(rural == 1)],
                   hx[in_sample == 1, sum(any_beverage == 1)], hx[in_sample == 1, sum(any_beverage == 0)], 82934),
    weighted_households = c(sum(hh$weight), hh[food_form == "urban_diary", sum(weight)], hh[food_form == "rural_weekly", sum(weight)],
                            hh[exptot_valid == TRUE, sum(weight)], hh[exptot_valid == TRUE & !is.na(head_age), sum(weight)],
                            NA, hx[in_sample == 1, sum(weight)], hh[hhid %in% esth[in_sample == 1, hhid], sum(weight)],
                            hx[in_sample == 1 & rural == 0, sum(weight)], hx[in_sample == 1 & rural == 1, sum(weight)],
                            hx[in_sample == 1 & any_beverage == 1, sum(weight)], hx[in_sample == 1 & any_beverage == 0, sum(weight)], NA))
  inval <- hc[variant == "primary" & market == "combined", .(bad = any(share_invalid) | sum(share) > 1), by = hhid]
  flow[6, `:=`(households = sum(hh$exptot_valid) - sum(inval$bad, na.rm = TRUE),
               weighted_households = hh[!hhid %in% inval[bad == TRUE, hhid], sum(weight)])]
  write_csv(flow, tdir("sample_flow.csv"))

  # ---------------- measurement coverage (supplementary) ----------------
  cov <- hc[variant == "primary" & hhid %in% ids,
            .(buyers = sum(buyer), buyers_weighted_share = w_mean(as.numeric(buyer), weight),
              buyers_with_recorded_quantity = sum(buyer & !is.na(qty)),
              unit_values_used = sum(uv_use), unit_value_outliers_flagged = sum(uv_outlier),
              spend_outliers_flagged = sum(spend_outlier),
              spend_share_with_recorded_quantity = sum(spend_q * weight) / sum(spend * weight),
              spend_share_text_identified = sum(spend_text * weight) / sum(spend * weight),
              spend_share_capitulo_c = sum(spend_capc * weight) / sum(spend * weight)),
            keyby = .(market, category)]
  comp <- tx[composite_only == TRUE & hhid %in% ids & !is.na(text_mention_category) & text_mention_category != "multiple",
             .(households_with_composite_mention = uniqueN(hhid), composite_records = .N), by = .(category = text_mention_category)]
  buy <- hc[variant == "primary" & market == "combined" & buyer == TRUE, .(hhid, category)]
  comp_only <- tx[composite_only == TRUE & hhid %in% ids & text_mention_category %chin% cats,
                  .(hhid, category = text_mention_category)][!buy, on = c("hhid", "category")][
                    , .(households_composite_mention_and_no_attributable_purchase = uniqueN(hhid)), by = category]
  cov <- merge(cov, comp, by = "category", all.x = TRUE)
  cov <- merge(cov, comp_only, by = "category", all.x = TRUE)
  cov[market != "combined", c("households_with_composite_mention", "composite_records",
                              "households_composite_mention_and_no_attributable_purchase") := NA]
  cov[, label := labs[category]]
  write_csv(cov, tdir("measurement_coverage.csv"))
  write_csv(cov, p_out(cfg, "diagnostics", run_id, "measurement_coverage.csv"))
  log_msg("Descriptives written: Table 1 (N = ", nrow(s), "), Table 2 (", nrow(t2), " rows), sample flow, coverage")
  invisible(TRUE)
}
