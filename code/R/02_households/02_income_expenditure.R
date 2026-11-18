# Stage 02b: household income and total expenditure.
#
# Total expenditure. The legacy `GastoTotal` has no source code and does not match any DANE aggregate
# (audit B1). It is NOT reused. The ENPH household file carries DANE's own monthly aggregates for the
# spending unit: GTUG (total), GCUG (current), GCMUG (current, monetary). The pipeline uses GCUG as the
# household's total consumption expenditure and keeps the others for reconciliation.
#
# Income. Two measures are built and reconciled:
#   income_dane        DANE's IT (total income of the spending unit), used for Table 1 and terciles;
#   income_person_sum  the legacy person-level sum (SSBDIncome.R) rebuilt from the person file, as an
#                      independent check. It is not used in estimation.
# Nothing is imputed: zero and missing values are kept and counted.

legacy_income_vars <- function() list(
  monthly = c("P6500", "P7070", "P6510S1", "P1653S2A1", "P1653S3A1", "P1653S4A1", "P6180S2", "P6590S1",
              "P6600S1", "P6620S1", "P6610S1", "P6585S1A1", "P6585S2A1", "P6585S3A1", "P1653S1A1",
              "P6630S3A1", "P6779S1", "P7422S1", "P7472S1", "P7500S1A1", "P7500S4A1", "P7500S5A1",
              "P7500S2A1", "P7500S3A1", "P9460S1", "P8612S1", "P8612S2"),
  annual = c("P6630S1A1", "P6630S2A1", "P6630S4A1", "P6630S5A1", "P7510S1A1", "P7510S2A1", "P7510S4A1",
             "P7510S5A1", "P7510S6A1", "P7510S10A1", "P7510S9A1", "P1668S1A1", "P1668S1A4", "P1668S2A2",
             "P1668S2A4", "P1668S4A2", "P1668S4A4", "P8610S1"),
  business = "P6750", business_months = "P6760")

run_income_expenditure <- function(cfg, run_id) {
  hh <- readRDS(p_interim(cfg, "01_import", "households.rds"))
  pe <- readRDS(p_interim(cfg, "01_import", "persons.rds"))
  d <- readRDS(p_interim(cfg, "02_households", "households.rds"))

  agg <- hh[, .(hhid = DIRECTORIO, income_dane = as.numeric(IT), income_current_dane = as.numeric(ICGU),
                exp_total_dane = as.numeric(GTUG), exp_current_dane = as.numeric(GCUG),
                exp_current_monetary_dane = as.numeric(GCMUG))]

  # Independent person-level income sum (monthly COP), following the legacy list of sources.
  v <- legacy_income_vars()
  miss <- setdiff(unlist(v), names(pe))
  check(length(miss) == 0, paste("income source variables missing from the person file:", paste(miss, collapse = ", ")))
  num <- function(x) { x <- as.numeric(x); x[is.na(x)] <- 0; x }
  inc <- pe[, .(hhid = DIRECTORIO)]
  inc[, monthly := rowSums(sapply(v$monthly, function(k) { x <- num(pe[[k]]); if (k == "P6500") x[x < 100] <- 0; x }))]
  inc[, annual := rowSums(sapply(v$annual, function(k) num(pe[[k]]))) / 12]
  months <- as.numeric(pe[[v$business_months]])
  inc[, business := fifelse(!is.na(months) & months > 0, num(pe[[v$business]]) / months, 0)]
  inc <- inc[, .(income_person_sum = sum(monthly + annual + business)), by = hhid]
  agg <- merge(agg, inc, by = "hhid", all.x = TRUE)

  d <- merge(d, agg, by = "hhid", all.x = TRUE)
  check(!anyNA(d$exp_current_dane), "missing DANE current expenditure")
  d[, exptot := exp_current_dane]                         # expenditure aggregate passed to WELCOM
  d[, exptot_valid := !is.na(exptot) & exptot >= cfg$sample$min_total_expenditure_cop]
  d[, income := income_dane]
  d[, income_pc := income / hhsize]
  d[, exptot_pc := exptot / hhsize]

  # Weighted terciles of per-capita income (population terciles: each holds one third of weighted households).
  cut_pts <- w_quantile(d$income_pc, d$weight, c(1 / 3, 2 / 3))
  d[, income_tercile := 1L + (income_pc > cut_pts[1]) + (income_pc > cut_pts[2])]
  saveRDS(d, p_interim(cfg, "02_households", "households.rds"))

  recon <- rbind(
    d[, .(measure = "Income: DANE IT vs person-level sum", n = .N,
          mean_a = w_mean(income_dane, weight), mean_b = w_mean(income_person_sum, weight),
          cor_log = cor(log1p(income_dane), log1p(income_person_sum)),
          share_within_10pct = mean(abs(income_person_sum - income_dane) <= 0.1 * pmax(income_dane, 1)),
          zeros_a = sum(income_dane <= 0), zeros_b = sum(income_person_sum <= 0))],
    d[, .(measure = "Expenditure: DANE current (GCUG) vs DANE total (GTUG)", n = .N,
          mean_a = w_mean(exp_current_dane, weight), mean_b = w_mean(exp_total_dane, weight),
          cor_log = cor(log(exp_current_dane), log(exp_total_dane)),
          share_within_10pct = mean(abs(exp_total_dane - exp_current_dane) <= 0.1 * exp_current_dane),
          zeros_a = sum(exp_current_dane <= 0), zeros_b = sum(exp_total_dane <= 0))],
    d[, .(measure = "Expenditure: DANE current (GCUG) vs current monetary (GCMUG)", n = .N,
          mean_a = w_mean(exp_current_dane, weight), mean_b = w_mean(exp_current_monetary_dane, weight),
          cor_log = cor(log(exp_current_dane), log1p(exp_current_monetary_dane), use = "complete.obs"),
          share_within_10pct = mean(abs(exp_current_monetary_dane - exp_current_dane) <= 0.1 * exp_current_dane, na.rm = TRUE),
          zeros_a = sum(exp_current_dane <= 0), zeros_b = sum(exp_current_monetary_dane <= 0, na.rm = TRUE))])
  write_csv(recon, p_out(cfg, "diagnostics", run_id, "income_expenditure_reconciliation.csv"))
  terc <- d[, .(households = .N, weighted_households = sum(weight), min_income_pc = min(income_pc),
                max_income_pc = max(income_pc), zero_income = sum(income <= 0)), keyby = income_tercile]
  terc[, `:=`(cut_lower = c(NA, cut_pts)[income_tercile], cut_upper = c(cut_pts, NA)[income_tercile])]
  write_csv(terc, p_out(cfg, "diagnostics", run_id, "income_terciles.csv"))
  log_msg("Income/expenditure: weighted mean exptot ", round(w_mean(d$exptot, d$weight)),
          "; tercile cut-offs (COP per capita) ", paste(round(cut_pts), collapse = ", "))
  invisible(d)
}
