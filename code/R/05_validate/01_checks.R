# Stage 05a: data checks across stages. Every check is recorded in
# output/diagnostics/<run_id>/validation_checks.csv; an error-severity failure stops the pipeline.

run_checks <- function(cfg, run_id) {
  lg <- new_check_log()
  hh <- readRDS(p_interim(cfg, "02_households", "households.rds"))
  raw <- readRDS(p_interim(cfg, "03_consumption", "transactions_raw.rds"))
  tx <- readRDS(p_interim(cfg, "03_consumption", "transactions.rds"))
  hc <- readRDS(p_interim(cfg, "04_prices", "household_category.rds"))
  cats <- cfg$categories$ids

  # ---- keys and universe ----
  record_check(lg, "households", "one row per household", uniqueN(hh$hhid) == nrow(hh), nrow(hh))
  record_check(lg, "households", "household size equals roster count", all(hh$hhsize_matches_roster),
               sprintf("%d differ", sum(!hh$hhsize_matches_roster)), "warning")
  record_check(lg, "households", "weights positive and non-missing", all(hh$weight > 0 & !is.na(hh$weight)))
  record_check(lg, "households", "every household answered exactly one food questionnaire", all(hh$food_form != "none"))
  record_check(lg, "households", "price clusters (local markets) never mix urban and rural households or quarters",
               hh[, uniqueN(rural) == 1 & uniqueN(quarter) == 1, by = clus_market][, all(V1)])
  record_check(lg, "households", "segments never mix urban and rural households",
               hh[, uniqueN(rural), by = segment][, all(V1 == 1)])
  record_check(lg, "households", "segments are interviewed in a single month",
               hh[, uniqueN(period), by = segment][, all(V1 == 1)])
  record_check(lg, "households", "every segment lies inside one price cluster",
               hh[, uniqueN(clus_market), by = segment][, all(V1 == 1)])
  record_check(lg, "households", "income terciles hold about one third of weighted households each",
               hh[, sum(weight), by = income_tercile][, all(abs(V1 / sum(V1) - 1 / 3) < 0.02)],
               paste(round(hh[, sum(weight), keyby = income_tercile][, V1 / sum(V1)], 4), collapse = " / "))
  record_check(lg, "transactions", "transaction key unique", uniqueN(tx$txn_id) == nrow(tx))
  record_check(lg, "transactions", "all transactions belong to a known household", all(tx$hhid %in% hh$hhid))
  record_check(lg, "transactions", "classified rows are a subset of harmonised rows", all(tx$txn_id %chin% raw$txn_id))

  # ---- totals across stages: classified spending must reconcile with the harmonised records ----
  raw_tot <- raw[txn_id %chin% tx[use_spend == TRUE & category %chin% cats, txn_id], sum(value_raw)]
  cls_tot <- tx[use_spend == TRUE & category %chin% cats, sum(value_raw)]
  record_check(lg, "totals", "raw amounts of classified purchases unchanged by classification", isTRUE(all.equal(raw_tot, cls_tot)))
  agg_tot <- hc[variant == "primary" & market == "combined", sum(spend)]
  tx_tot <- tx[use_spend == TRUE & category %chin% cats, sum(value_month)]
  record_check(lg, "totals", "household aggregates equal the sum of monthly transaction amounts (primary, combined)",
               isTRUE(all.equal(agg_tot, tx_tot)), sprintf("%.0f vs %.0f", agg_tot, tx_tot))
  hw <- hc[variant == "primary", .(home = sum(spend[market == "home"]), away = sum(spend[market == "away"]),
                                   comb = sum(spend[market == "combined"])), by = .(hhid, category)]
  record_check(lg, "totals", "combined market = home + away at the household level (no overlap, no double sum)",
               hw[, isTRUE(all.equal(home + away, comb))])

  # ---- recall and units ----
  pur <- tx[use_spend == TRUE & !is_capc]
  record_check(lg, "recall", "monthly factor positive for every valid purchase", pur[, all(factor_primary > 0)])
  record_check(lg, "recall", "weekly-or-more purchases use 30 / recall days",
               pur[module_id != "lessfreq_items" & (is.na(freq) | freq %in% 1:3), isTRUE(all.equal(factor_primary, 30 / recall_days))])
  record_check(lg, "recall", "shopper's pocket spending uses the 7-day window",
               tx[module_id %in% c("urb_diary", "urb_meals_hh") & scope == 2L, all(recall_days == 7)])
  record_check(lg, "recall", "less-frequent module follows DANE's previous-month table (1; 1/2, 1/3, 1/6, 1/12 for bimonthly or rarer)",
               tx[module_id == "lessfreq_items" & use_spend == TRUE,
                  isTRUE(all.equal(factor_primary, fcase(freq == 6L, 1 / 2, freq == 7L, 1 / 3, freq == 10L, 1 / 6, freq == 8L, 1 / 12, default = 1)))])
  record_check(lg, "recall", "beverage records of the less-frequent module are all in previous-month sections",
               tx[module_id == "lessfreq_items" & use_spend == TRUE, all(cap %chin% c("J11", "L11"))])
  record_check(lg, "units", "litre goods never take quantities from weight units without a density rule",
               tx[qty_valid == TRUE & quantity_basis == "litre", all(unit_raw %in% c(1L, 2L, 4L, 8L))])
  record_check(lg, "units", "weight goods never take quantities from volume units",
               tx[qty_valid == TRUE & quantity_basis == "kilogram", all(unit_raw %in% c(3L, 5L, 6L, 7L, 8L))])
  record_check(lg, "units", "modules without a unit field contribute no physical quantity",
               tx[!module_id %in% c("urb_diary", "rur_weekly"), !any(qty_valid)])
  record_check(lg, "units", "no physical quantity for spirits and wine (none is collected)",
               tx[category == "spirits", !any(qty_valid)], "ENPH collects spirits and wine without quantities", "info")

  # ---- Capitulo C ----
  record_check(lg, "capitulo_c", "'never' answers contribute no spending", tx[is_capc == TRUE & freq == 11L, !any(use_spend)])
  record_check(lg, "capitulo_c", "groups bought inside the reference period are not added (no double counting)",
               tx[is_capc == TRUE & answered == 1L, !any(use_spend)])
  record_check(lg, "capitulo_c", "Capitulo C never creates a physical quantity", tx[is_capc == TRUE, !any(qty_valid)])

  # ---- classification ----
  record_check(lg, "classification", "ice is not classified as water", tx[startsWith(code, "012203"), !any(category == "water", na.rm = TRUE)])
  record_check(lg, "classification", "generic on-trade alcohol code is split only by text",
               tx[code == "11110601" & category %chin% c("beer", "spirits"), all(source == "text")])
  record_check(lg, "classification", "text-identified purchases come only from pure beverage descriptions",
               tx[source == "text", all(text_pure)])
  record_check(lg, "classification", "composite descriptions contribute no category spending",
               tx[composite_only == TRUE, all(is.na(category))])
  record_check(lg, "classification", "non-purchase acquisitions are excluded from spending", tx[is_purchase == FALSE, !any(use_spend)])

  # ---- zero / missing status and price support ----
  record_check(lg, "zeros", "full household x category x market universe in every variant",
               hc[, .N, by = .(variant)][, all(N == nrow(hh) * length(cats) * 3)])
  record_check(lg, "zeros", "non-buyers have zero spending and no unit value", hc[buyer == FALSE, all(spend == 0 & is.na(uv))])
  record_check(lg, "zeros", "missing quantity is never coded as zero", hc[, !any(qty == 0, na.rm = TRUE)])
  record_check(lg, "prices", "unit values exist only for buyers with a valid positive quantity",
               hc[!is.na(uv), all(buyer & qty > 0 & spend_q > 0)])
  record_check(lg, "prices", "unit values positive and finite", hc[!is.na(uv), all(is.finite(uv) & uv > 0)])
  record_check(lg, "shares", "budget shares within [0,1] for households with valid total expenditure",
               hc[exptot_valid == TRUE & share_invalid == FALSE, all(share >= 0 & share <= 1)])
  ssum <- hc[variant == "primary" & market == "combined" & exptot_valid == TRUE, .(s = sum(share)), by = hhid]
  record_check(lg, "shares", "sum of beverage shares below one (primary, combined)", mean(ssum$s <= 1) > 0.999,
               sprintf("%d households above one (excluded from estimation)", sum(ssum$s > 1)), "warning")

  # ---- estimation files: WELCOM contract ----
  ct <- fread(p_processed(cfg, "estimation", "welcom_contract.csv"))
  for (ds in unique(ct$dataset)) {
    d <- readRDS(p_processed(cfg, "estimation", paste0(ds, ".rds")))[in_sample == 1]
    okc <- all(vapply(cats, function(g) !anyNA(d[[paste0("w", g)]]) && all(is.na(d[[paste0("luv", g)]]) | d[[paste0("w", g)]] > 0), logical(1)))
    record_check(lg, "welcom_contract", paste0(ds, ": shares complete; unit values only for buyers"), okc)
    record_check(lg, "welcom_contract", paste0(ds, ": weight constant within the primary cluster"),
                 d[, uniqueN(wgt_market), by = clus_market][, all(V1 == 1)])
  }
  record_check(lg, "welcom_contract", "goods without unit values are not passed to WELCOM",
               ct[estimable == FALSE, all(unit_values < 30 | clusters < 30)],
               paste("not estimable:", paste(unique(ct[estimable == FALSE, category]), collapse = ", ")), "info")

  out <- check_log_table(lg)
  write_csv(out, p_out(cfg, "diagnostics", run_id, "validation_checks.csv"))
  n_err <- out[passed == FALSE & severity == "error", .N]
  log_msg("Validation: ", nrow(out), " checks; ", out[passed == FALSE, .N], " not passed (", n_err, " errors)")
  check(n_err == 0, paste("validation errors:", paste(out[passed == FALSE & severity == "error", check], collapse = " | ")))
  invisible(out)
}
