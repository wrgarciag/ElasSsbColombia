# Stage 06a: collect the estimates exported by Stata into ONE shared results object.
# Every elasticity table (3-6), figure and inline number is generated from this object, so a value that
# appears in several tables cannot differ between them.
#
# Output: data/processed/manuscript/<run_id>/results.rds  (list: est, models, goods, status, cov, diffs, native)
#         output/estimates/<run_id>/results_labelled.csv  (unrounded long format with labels)

bundle_dir <- function(cfg, run_id) {
  d <- p_processed(cfg, "manuscript", run_id)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

run_collect_estimates <- function(cfg, run_id) {
  est_dir <- file.path(cfg$root, cfg$paths$output, "estimates", run_id)
  need <- c("point_long.csv", "model_meta.csv", "model_goods.csv")
  miss <- need[!file.exists(file.path(est_dir, need))]
  check(length(miss) == 0, paste0("Stata point estimates missing for run ", run_id, ": ", paste(miss, collapse = ", "),
                                 ". Run the 'point' stage first."))
  rd <- function(f) fread(file.path(est_dir, f), na.strings = c("", "NA", "."), colClasses = list(character = c("model_id")))
  models <- rd("model_meta.csv")
  spec <- fread(p_root(cfg, "config", "models.csv"), encoding = "UTF-8")
  models <- merge(models, spec[, .(model_id, label, change_vs_m1)], by = "model_id", all.x = TRUE)
  check(all(spec$model_id %in% models$model_id), "models in config/models.csv without Stata output")
  check(all(models$rc == 0), paste("duvm failed for:", paste(models[rc != 0, model_id], collapse = ", ")))
  goods <- rd("model_goods.csv")

  has_inf <- file.exists(file.path(est_dir, "estimates_long.csv"))
  if (has_inf) {
    est <- rd("estimates_long.csv")
    status <- rd("bootstrap_status.csv")
    cov <- rd("covariance_long.csv")
    diffs <- rd("spec_differences.csv")
  } else {
    est <- rd("point_long.csv")
    setnames(est, "value", "estimate")
    est[, c("se", "ci_lo", "ci_hi", "p_normal", "reps") := .(NA_real_, NA_real_, NA_real_, NA_real_, 0L)]
    status <- data.table(model_id = models$model_id, attempted = 0L, failed = 0L, completed = 0L)
    cov <- NULL; diffs <- NULL
  }
  for (v in c("row", "col")) est[is.na(get(v)), (v) := ""]
  est <- merge(est, models[, .(model_id, spec, market, role, bootclass)], by = "model_id")
  status <- merge(models[, .(model_id, bootclass)], status, by = "model_id", all.x = TRUE)
  for (v in c("attempted", "failed", "completed")) status[is.na(get(v)), (v) := 0L]
  status[, target := fifelse(bootclass == "final", cfg$estimation$boot_reps_final, cfg$estimation$boot_reps_sensitivity)]
  status[, `:=`(reached_target = completed >= target, reportable = completed >= cfg$estimation$boot_reps_minimum_report)]
  est <- merge(est, status[, .(model_id, reps_completed = completed, reportable)], by = "model_id")
  # inference is shown only for models with enough completed replications
  est[reportable == FALSE, c("se", "ci_lo", "ci_hi", "p_normal") := NA_real_]

  cats <- cfg$categories$ids; labs <- setNames(cfg$categories$labels, cats)
  est[, `:=`(row_label = labs[row], col_label = labs[col])]
  est[, estimand := fcase(
    stat == "price", "Uncompensated (Marshallian) price elasticity of quantity; quality-corrected; symmetry-restricted (duvm e(elprice))",
    stat == "price_nosym", "Uncompensated price elasticity; quality-corrected; without the symmetry restriction (duvm Table 06)",
    stat == "price_noquality", "Uncompensated price elasticity; without quality correction or symmetry (duvm Table 04)",
    stat == "expenditure", "Elasticity of quantity with respect to total household expenditure (duvm e(elincome))",
    stat == "quality", "Elasticity of the unit value with respect to total household expenditure (quality elasticity)")]
  est[, conditioning := "Unconditional: budget shares and the expenditure regressor both use total household current expenditure (DANE GCUG)"]
  est[, matrix_orientation := fifelse(stat %like% "^price", "row = good whose quantity responds; col = good whose price changes", "")]

  wv <- welcom_version(cfg)
  models[, `:=`(estimator = "WELCOM duvm (Deaton unit-value model)", welcom = paste0(wv$version, " (", wv$date, ")"))]
  models <- merge(models, status[, .(model_id, boot_attempted = attempted, boot_failed = failed, boot_completed = completed,
                                     boot_target = target, reached_target, reportable)], by = "model_id")
  not_est <- setdiff(cats, unique(est[stat == "price", row]))
  contract <- fread(p_processed(cfg, "estimation", "welcom_contract_models.csv"))
  contract <- merge(contract, models[, .(model_id, spec)], by = "model_id")

  res <- list(run_id = run_id, est = est, models = models, goods = goods, status = status, cov = cov, diffs = diffs,
              native = if (file.exists(file.path(est_dir, "welcom_native.csv"))) rd("welcom_native.csv") else NULL,
              has_inference = has_inf, not_estimable = not_est, contract = contract, categories = cats, labels = labs,
              welcom = wv)
  saveRDS(res, file.path(bundle_dir(cfg, run_id), "results.rds"))
  write_csv(est, file.path(est_dir, "results_labelled.csv"))
  write_csv(models, file.path(est_dir, "models_summary.csv"))
  log_msg("Collected ", nrow(est), " estimates for ", nrow(models), " models; inference: ", has_inf,
          "; replications completed (min/median/max): ", paste(c(min(status$completed), median(status$completed), max(status$completed)), collapse = "/"),
          "; not estimable: ", paste(not_est, collapse = ", "))
  invisible(res)
}
