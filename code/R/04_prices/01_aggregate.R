# Stage 04a: household x category x market aggregates and observed unit values.
#
# For every measurement variant and market the stage builds, per household and category:
#   spend      monthly spending on purchases (COP); 0 for households without a valid purchase (true zero)
#   qty        monthly physical quantity from purchases with a defensible quantity (litres or kg); NA if none
#   spend_q    spending on those same purchases
#   uv         observed unit value = spend_q / qty (COP per litre or kg); NA for non-buyers and for buyers
#              whose purchases carry no physical quantity. Unit values are never imputed.
#
# Markets are unions of disjoint purchase records: home (off-trade), away (on-trade), combined = both.
# Legacy mapping: SSBRevisedPaper_Prices.R / _Prices_Codi.R. Corrections C-15 to C-19 in docs/corrections_log.md.

measurement_variants <- function() list(
  primary       = list(label = "Coded and text-identified purchases", cat = "category", src = c("coded", "capc", "text"),
                       value = "value_month", qty = "qty_month", qty_ok = "qty_valid"),
  coded_only    = list(label = "Coded purchases only", cat = "category", src = c("coded", "capc"),
                       value = "value_month", qty = "qty_month", qty_ok = "qty_valid"),
  broad_sb      = list(label = "Broad SB definition (adds powdered concentrates, plant-based drinks, fresh juices away from home)",
                       cat = "category_broad", src = c("coded", "capc", "text"),
                       value = "value_month", qty = "qty_month", qty_ok = "qty_valid"),
  units_direct  = list(label = "Unit values only from purchases recorded directly in volume or weight units",
                       cat = "category", src = c("coded", "capc", "text"),
                       value = "value_month", qty = "qty_month", qty_ok = "qty_direct_volume"),
  recall_design = list(label = "Reference-period scaling (30 / recall days) for every diary purchase; no Capitulo C",
                       cat = "category", src = c("coded", "text"),
                       value = "value_month_design", qty = "qty_month_design", qty_ok = "qty_valid"))

aggregate_variant <- function(tx, v, cats) {
  src_col <- if (v$cat == "category_broad") "source_broad" else "source"
  d <- tx[get(v$cat) %chin% cats & get(src_col) %chin% v$src & use_spend == TRUE & !is.na(get(v$value)),
          .(hhid, category = get(v$cat), market, value = get(v$value),
            qok = get(v$qty_ok) %in% TRUE, qty = get(v$qty), src = get(src_col))]
  one <- function(dd, mk) dd[, .(spend = sum(value), spend_q = sum(value[qok]), qty = sum(qty[qok]),
                                 n_rec = .N, n_rec_q = sum(qok), spend_text = sum(value[src == "text"]),
                                 spend_capc = sum(value[src == "capc"])), by = .(hhid, category)][, market := mk]
  rbind(one(d[market == "home"], "home"), one(d[market == "away"], "away"), one(d, "combined"))
}

run_aggregate <- function(cfg, run_id) {
  tx <- readRDS(p_interim(cfg, "03_consumption", "transactions.rds"))
  hh <- readRDS(p_interim(cfg, "02_households", "households.rds"))
  cats <- cfg$categories$ids
  vars <- measurement_variants()
  grid <- CJ(hhid = hh$hhid, category = cats, market = c("home", "away", "combined"))

  out <- list()
  for (vn in names(vars)) {
    a <- aggregate_variant(tx, vars[[vn]], cats)
    a <- merge(grid, a, by = c("hhid", "category", "market"), all.x = TRUE)   # full household x category x market universe
    for (cn in c("spend", "spend_q", "n_rec", "n_rec_q", "spend_text", "spend_capc")) set(a, which(is.na(a[[cn]])), cn, 0)
    a[n_rec_q == 0 | is.na(qty) | qty <= 0, qty := NA_real_]                 # no measured quantity is NOT zero litres
    a[, buyer := spend > 0]
    a[, uv := fifelse(!is.na(qty), spend_q / qty, NA_real_)]
    a[, variant := vn]
    out[[vn]] <- a
  }
  hc <- rbindlist(out)
  hc <- merge(hc, hh[, .(hhid, exptot, exptot_valid, weight)], by = "hhid")
  hc[, share := fifelse(exptot_valid, spend / exptot, NA_real_)]

  # ---- flags (nothing is recoded to zero) ----
  k_uv <- cfg$outliers$unit_value_log_mad_k
  hc[, uv_outlier := FALSE]
  hc[!is.na(uv), uv_outlier := flag_log_mad(uv, k_uv), by = .(variant, market, category)]
  hc[, uv_use := !is.na(uv) & !uv_outlier]
  hc[, spend_outlier := FALSE]
  hc[buyer == TRUE, spend_outlier := flag_log_mad(spend, cfg$outliers$expenditure_log_mad_k), by = .(variant, market, category)]
  hc[, share_invalid := !is.na(share) & share > cfg$outliers$expenditure_share_max]

  dir.create(p_interim(cfg, "04_prices"), recursive = TRUE, showWarnings = FALSE)
  saveRDS(hc, p_interim(cfg, "04_prices", "household_category.rds"), compress = FALSE)

  diag <- hc[, .(households = .N, buyers = sum(buyer), buyers_with_quantity = sum(buyer & !is.na(qty)),
                 unit_values_observed = sum(!is.na(uv)), unit_value_outliers = sum(uv_outlier),
                 unit_values_used = sum(uv_use), spend_outliers = sum(spend_outlier), share_above_one = sum(share_invalid),
                 spend_share_with_quantity = round(sum(spend_q * weight) / sum(spend * weight), 4),
                 spend_share_text = round(sum(spend_text * weight) / sum(spend * weight), 4),
                 spend_share_capc = round(sum(spend_capc * weight) / sum(spend * weight), 4)),
             keyby = .(variant, market, category)]
  write_csv(diag, p_out(cfg, "diagnostics", run_id, "household_category_measurement.csv"))
  log_msg("Household x category x market x variant rows: ", nrow(hc))
  invisible(hc)
}
