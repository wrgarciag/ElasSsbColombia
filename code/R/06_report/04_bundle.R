# Stage 06d: manuscript input bundle, data/processed/manuscript/<run_id>/.
#   results.rds     shared results object (stage 06a)
#   values.rds      named values for inline reporting in manuscript.Rmd (also values.json for inspection)
#   manifest.json   links every component (tables, figures, estimates, data, configuration) to this run
# The manuscript loads this bundle; it never reruns data processing or estimation.

est_value <- function(res, spec_id, mk, stat_name, r, cc = r) {
  x <- res$est[spec == spec_id & market == mk & stat == stat_name & row == r & (stat_name != "price" | col == cc)]
  if (nrow(x) != 1) return(list(est = NA_real_, se = NA_real_, lo = NA_real_, hi = NA_real_, p = NA_real_))
  list(est = x$estimate, se = x$se, lo = x$ci_lo, hi = x$ci_hi, p = x$p_normal)
}

run_bundle <- function(cfg, run_id) {
  res <- readRDS(file.path(bundle_dir(cfg, run_id), "results.rds"))
  tdir <- p_out(cfg, "tables", run_id, ""); fdir <- p_out(cfg, "figures", run_id, "")
  cats <- res$categories; goods_est <- setdiff(cats, res$not_estimable)
  t1 <- fread(file.path(tdir, "table1_demographics.csv")); t2 <- fread(file.path(tdir, "table2_consumption.csv"))
  fl <- fread(file.path(tdir, "sample_flow.csv")); cv <- fread(file.path(tdir, "measurement_coverage.csv"))
  ps <- fread(p_out(cfg, "diagnostics", run_id, "price_cluster_sizes.csv"))
  pcv <- fread(p_out(cfg, "diagnostics", run_id, "price_cluster_variation.csv"))
  terc <- fread(p_out(cfg, "diagnostics", run_id, "income_terciles.csv"))
  recon <- fread(p_out(cfg, "diagnostics", run_id, "income_expenditure_reconciliation.csv"))
  txt <- fread(p_out(cfg, "diagnostics", run_id, "text_recovery.csv"))
  hhu <- fread(p_out(cfg, "diagnostics", run_id, "household_universe.csv"))
  t1v <- function(v, what = "mean") t1[variable == v][[what]]
  t2v <- function(vn, mk, g, what) t2[variant == vn & market == mk & category == g][[what]]

  v <- list(run_id = run_id, welcom_version = res$welcom$version, welcom_date = res$welcom$date,
            n_enph = hhu[item == "households", value], n_persons = hhu[item == "persons", value],
            n_segments = hhu[item == "survey segments", value], n_municipalities = hhu[item == "municipalities (design PSU proxy)", value],
            weight_total = hhu[item == "weight total (households)", value],
            n_sample_combined = res$models[model_id == "M1_combined", n_households],
            n_sample_home = res$models[model_id == "M1_home", n_households],
            n_clusters_m1 = res$models[model_id == "M1_combined", n_clusters],
            n_urban = res$models[model_id == "M6_combined", n_households],
            n_no_beverage = fl[step %like% "no beverage purchase", households],
            n_legacy = 82934,
            head_male = t1v("head_male"), hhsize = t1v("hhsize"), rural = t1v("rural"), head_age = t1v("head_age"),
            income_mean = t1v("income"), exptot_mean = t1v("exptot"),
            tercile_cut1 = terc$cut_upper[1], tercile_cut2 = terc$cut_upper[2],
            boot_min = min(res$status$completed), boot_max = max(res$status$completed),
            boot_main_min = min(res$status[bootclass == "final", completed]),
            boot_target = cfg$estimation$boot_reps_final, boot_failed = sum(res$status$failed),
            inference_final = all(res$status$reached_target),
            # the manuscript's results (Tables 3-6) rest on the main and tercile models; the supplementary
            # sensitivity models may still lack inference and are then shown as point estimates only
            inference_available = res$has_inference && all(res$status[bootclass == "final", reportable]),
            sens_inference_available = res$has_inference && all(res$status[bootclass == "sens", reportable]),
            boot_sens_min = min(res$status[bootclass == "sens", completed]),
            goods_estimable = goods_est, goods_not_estimable = res$not_estimable,
            cluster_median_size = ps[cluster_def == "market", median_size], n_market_clusters = ps[cluster_def == "market", clusters],
            segment_median_size = ps[cluster_def == "segment", median_size],
            composite_records = txt[outcome %like% "composite", sum(records)],
            text_identified_records = txt[outcome %like% "text-identified", sum(records)],
            income_recon_cor = recon[measure %like% "^Income", cor_log],
            child_age_max = cfg$sample$child_age_max)
  # descriptive values by category
  for (g in cats) {
    v[[paste0("prev_home_", g)]] <- t2v("primary", "home", g, "prevalence")
    v[[paste0("prev_comb_", g)]] <- t2v("primary", "combined", g, "prevalence")
    v[[paste0("prev_comb_coded_", g)]] <- t2v("coded_only", "combined", g, "prevalence")
    v[[paste0("spend_comb_", g)]] <- t2v("primary", "combined", g, "mean_spend_buyers_cop")
    v[[paste0("spend_home_", g)]] <- t2v("primary", "home", g, "mean_spend_buyers_cop")
    v[[paste0("share_tot_comb_", g)]] <- t2v("primary", "combined", g, "mean_share_total_expenditure")
    v[[paste0("uv_", g)]] <- t2v("primary", "home", g, "mean_unit_value_cop")
    v[[paste0("qty_", g)]] <- t2v("primary", "home", g, "mean_quantity_recorded")
    v[[paste0("qcov_home_", g)]] <- t2v("primary", "home", g, "spend_share_with_quantity")
    v[[paste0("n_uv_", g)]] <- t2v("primary", "home", g, "n_unit_values")
    v[[paste0("text_share_comb_", g)]] <- cv[market == "combined" & category == g, spend_share_text_identified]
    v[[paste0("composite_only_", g)]] <- cv[market == "combined" & category == g, households_composite_mention_and_no_attributable_purchase]
    v[[paste0("clusters_uv_", g)]] <- pcv[cluster_def == "market" & market == "home" & category == g, clusters_with_unit_value]
    v[[paste0("between_share_", g)]] <- pcv[cluster_def == "market" & market == "home" & category == g, share_variance_between]
    v[[paste0("reliability_", g)]] <- pcv[cluster_def == "market" & market == "home" & category == g, reliability_cluster_mean]
    v[[paste0("reliability_segment_", g)]] <- pcv[cluster_def == "segment" & market == "home" & category == g, reliability_cluster_mean]
  }
  # elasticities: own-price and expenditure, all main / tercile / sensitivity specs, both markets
  el <- list()
  v$goods_terciles <- res$contract[model_id == "T1_combined" & estimable == TRUE, good]
  for (sp in unique(res$models$spec)) for (mk in c("home", "combined")) for (g in goods_est) {
    el[[paste("own", sp, mk, g, sep = "_")]] <- est_value(res, sp, mk, "price", g)
    el[[paste("exp", sp, mk, g, sep = "_")]] <- est_value(res, sp, mk, "expenditure", g)
  }
  for (mk in c("home", "combined")) for (r in goods_est) for (cc in goods_est)
    el[[paste("cross", mk, r, cc, sep = "_")]] <- est_value(res, "M1", mk, "price", r, cc)
  v$el <- el
  saveRDS(v, file.path(bundle_dir(cfg, run_id), "values.rds"))
  jsonlite::write_json(v, file.path(bundle_dir(cfg, run_id), "values.json"), auto_unbox = TRUE, pretty = TRUE, digits = NA, null = "null")

  files <- function(dir, pat) { f <- list.files(dir, pattern = pat, full.names = TRUE)
    data.table(file = sub(paste0(cfg$root, "/"), "", normalizePath(f, winslash = "/"), fixed = TRUE), sha256 = vapply(f, sha256_file, "")) }
  est_dir <- file.path(cfg$root, cfg$paths$output, "estimates", run_id)
  stage_manifests <- lapply(list.files(p_out(cfg, "logs", run_id, ""), pattern = "^manifest_r_.*[.]json$", full.names = TRUE), jsonlite::read_json)
  g <- git_commit(cfg$root)
  man <- list(
    run_id = run_id, created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    complete = NA, inference_final = v$inference_final, inference_available = v$inference_available,
    git_commit = g$commit, git_dirty = g$dirty,
    config_sha256 = sha256_file(p_root(cfg, "config", "config.yml")), models_sha256 = sha256_file(p_root(cfg, "config", "models.csv")),
    input_manifest_sha256 = sha256_file(p_meta(cfg, "input_manifest.csv")),
    estimator = list(name = "WELCOM duvm", version = res$welcom$version, date = res$welcom$date,
                     duvm_sha256 = sha256_file(p_root(cfg, cfg$paths$stata_ado, "d", "duvm.ado")),
                     stata = unique(res$models$stata_version)),
    seeds = cfg$seeds,
    bootstrap = list(target_main = cfg$estimation$boot_reps_final, target_sensitivity = cfg$estimation$boot_reps_sensitivity,
                     completed_min = v$boot_min, completed_max = v$boot_max, failed = v$boot_failed),
    r = list(version = R.version.string, packages = as.list(installed.packages()[intersect(pipeline_packages(), rownames(installed.packages())), "Version"])),
    estimation_data = files(p_processed(cfg, "estimation"), "[.]dta$"),
    estimates = files(est_dir, "[.]csv$"), tables = files(tdir, "[.](csv|tex)$"), figures = files(fdir, "[.]pdf$"),
    stage_manifests = stage_manifests)
  jsonlite::write_json(man, file.path(bundle_dir(cfg, run_id), "manifest.json"), auto_unbox = TRUE, pretty = TRUE, null = "null")
  log_msg("Bundle written to ", bundle_dir(cfg, run_id))
  invisible(v)
}
