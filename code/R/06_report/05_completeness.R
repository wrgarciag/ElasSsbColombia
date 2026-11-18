# Stage 06e: table-completeness and consistency check.
# Lists every required panel x model x beverage x statistic of Tables 1-6 and classifies each cell as
#   available            estimate (and inference, where required) present
#   not_estimable        documented structural gap (no unit values for the good): reported as n.e., not as zero
#   missing_inference    estimate present, bootstrap inference absent or below the reportable minimum
#   missing              a supported result is absent  -> the stage FAILS
# It also verifies that the primary-model estimates are identical wherever they are repeated (Tables 3, 4, 5).

run_completeness <- function(cfg, run_id) {
  res <- readRDS(file.path(bundle_dir(cfg, run_id), "results.rds"))
  tdir <- function(f) p_out(cfg, "tables", run_id, f)
  cats <- res$categories; ne <- res$not_estimable
  req <- list()
  add <- function(tab, panel, model, good, stat) req[[length(req) + 1L]] <<- data.table(table_id = tab, panel = panel, model = model, good = good, statistic = stat)
  for (mk in c("home", "combined")) {
    for (g in cats) {
      for (s in paste0("M", 1:6)) { add("T3", mk, s, g, "price"); add("T6", mk, s, g, "expenditure") }
      for (s in c("M1", "T1", "T2", "T3")) add("T4", mk, s, g, "price")
      for (g2 in cats) add("T5", mk, "M1", paste(g, g2, sep = ">"), "price")
    }
  }
  req <- rbindlist(req)
  e <- res$est
  look <- function(mk, sp, good, st) {
    rc <- strsplit(good, ">", fixed = TRUE)[[1]]; r <- rc[1]; cc <- if (length(rc) == 2) rc[2] else rc[1]
    x <- e[market == mk & spec == sp & stat == st & row == r & (st != "price" | col == cc)]
    ok <- res$contract[spec == sp & market == mk & good %chin% c(r, cc), all(estimable)]
    if (r %chin% ne || cc %chin% ne || !ok) return("not_estimable")
    if (nrow(x) != 1 || is.na(x$estimate)) return("missing")
    if (is.na(x$se)) return("missing_inference")
    "available"
  }
  req[, status := mapply(look, panel, model, good, statistic)]

  # descriptive tables: every row must exist; unit value / quantity for goods without quantities are "not_measured"
  t1 <- fread(tdir("table1_demographics.csv")); t2 <- fread(tdir("table2_consumption.csv"))
  d1 <- data.table(table_id = "T1", panel = "all", model = "", good = t1$variable, statistic = "mean/sd/min/max",
                   status = fifelse(is.na(t1$mean) | is.na(t1$sd), "missing", "available"))
  d2 <- rbindlist(lapply(c("prevalence", "mean_spend_buyers_cop", "mean_share_beverage_basket", "mean_unit_value_cop", "mean_quantity_recorded"), function(s)
    t2[, .(table_id = "T2", panel = panel, model = "", good = as.character(category), statistic = s,
           status = fifelse(!is.na(get(s)), "available", fifelse(s %chin% c("mean_unit_value_cop", "mean_quantity_recorded") & n_unit_values == 0, "not_measured", "missing")))]))
  check(nrow(t2) == 4 * length(cats), "Table 2 does not have 4 panels x all categories")
  out <- rbind(req, d1, d2)

  # consistency: primary full-sample estimates identical across Tables 3, 4 and 5
  t3 <- fread(tdir("table3_own_price.csv")); t4 <- fread(tdir("table4_terciles.csv")); t5 <- fread(tdir("table5_price_matrix.csv"))
  a <- t3[spec == "M1" & !is.na(estimate), .(market, good, e3 = estimate)]
  b <- t4[spec == "M1" & !is.na(estimate), .(market, good, e4 = estimate)]
  cdiag <- t5[row == col, .(market, good = row, e5 = estimate)]
  cmp <- Reduce(function(x, y) merge(x, y, by = c("market", "good")), list(a, b, cdiag))
  consistent <- nrow(cmp) > 0 && cmp[, all(e3 == e4 & e4 == e5)]

  summ <- out[, .N, keyby = .(table_id, status)]
  write_csv(out, tdir("table_completeness.csv"))
  write_csv(summ, tdir("table_completeness_summary.csv"))
  n_missing <- out[status == "missing", .N]; n_noinf <- out[status == "missing_inference", .N]
  complete <- n_missing == 0 && consistent
  mf <- file.path(bundle_dir(cfg, run_id), "manifest.json")
  man <- jsonlite::read_json(mf)
  man$complete <- complete
  man$completeness <- list(required_cells = nrow(out), available = out[status == "available", .N],
                           not_estimable = out[status == "not_estimable", .N], not_measured = out[status == "not_measured", .N],
                           missing_inference = n_noinf, missing = n_missing, primary_estimates_consistent_across_tables = consistent)
  jsonlite::write_json(man, mf, auto_unbox = TRUE, pretty = TRUE, null = "null")
  log_msg("Completeness: ", nrow(out), " required cells; available ", out[status == "available", .N], "; not estimable ",
          out[status == "not_estimable", .N], "; not measured ", out[status == "not_measured", .N], "; missing inference ", n_noinf,
          "; missing ", n_missing, "; primary estimates consistent across tables: ", consistent)
  check(consistent, "primary-model estimates differ between Tables 3, 4 and 5")
  check(n_missing == 0, sprintf("%d supported required results are missing (see table_completeness.csv)", n_missing))
  if (n_noinf > 0) log_msg("WARNING: ", n_noinf, " cells have point estimates without reportable inference (bootstrap incomplete).")
  invisible(out)
}
