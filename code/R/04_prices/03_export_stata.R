# Stage 04c: analysis-ready estimation files, written in exactly the form WELCOM's `duvm` needs.
#
# WELCOM input contract (derived from duvm.sthlp and duvm.ado; see docs/welcom_method.md):
#   for every good <g> in the name list:  w<g>   budget share, non-missing, 0 for non-buyers
#                                         luv<g> log unit value, MISSING when no unit value is observed
#   expend()  household expenditure in levels (duvm takes the log itself) -> exptot
#   hhsize()  household size in levels (duvm takes the log itself)        -> hhsize
#   cluster() numeric cluster id; region()/subround() constant within cluster
#   hweight() weight; indcat() categorical controls; indcon() continuous controls
# No placeholder is needed for non-buyers' unit values: duvm's first-stage regressions drop missing luv.
# Output: data/processed/estimation/est_<variant>_<market>.dta/.rds, a dictionary and a contract file.

run_export_stata <- function(cfg, run_id) {
  hh <- readRDS(p_interim(cfg, "02_households", "households.rds"))
  hc <- readRDS(p_interim(cfg, "04_prices", "household_category.rds"))
  cats <- cfg$categories$ids
  out_dir <- p_processed(cfg, "estimation")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  hh[, regctl := as.integer(factor(region_area))]
  hh[, region7 := as.integer(factor(region))]
  hh[, covar_complete := !is.na(head_age) & !is.na(head_male) & !is.na(educ) & !is.na(hhsize) & hhsize >= 1]
  hh[, n_market := .N, by = clus_market]
  base <- hh[, .(hhid, clus_market, clus_segment, n_market,
                 wgt_market = weight_market_mean / mean(weight_market_mean),
                 wgt_segment = weight_segment_mean / mean(weight_segment_mean),
                 wgt_hh_raw = weight, exptot, hhsize, head_age, head_male, single, children, educ,
                 regctl, region7, quarter_id, rural, tercile = income_tercile, exptot_valid, covar_complete)]

  contract <- list(); flow <- list(); dict_done <- FALSE; dsets <- list()
  for (vn in unique(hc$variant)) for (mk in c("home", "combined")) {
    x <- hc[variant == vn & market == mk]
    wide_w <- dcast(x, hhid ~ category, value.var = "share")
    setnames(wide_w, cats, paste0("w", cats))
    x[, luv := fifelse(uv_use, log(uv), NA_real_)]
    wide_l <- dcast(x, hhid ~ category, value.var = "luv")
    setnames(wide_l, cats, paste0("luv", cats))
    fl <- x[, .(share_sum = sum(share), share_invalid = any(share_invalid), spend_outlier_any = as.integer(any(spend_outlier)),
                any_beverage = as.integer(any(buyer))), by = hhid]
    d <- Reduce(function(a, b) merge(a, b, by = "hhid"), list(base, wide_w, wide_l, fl))
    d[, share_invalid := share_invalid | (!is.na(share_sum) & share_sum > cfg$outliers$expenditure_share_max)]
    d[, in_sample := as.integer(exptot_valid & covar_complete & !share_invalid & n_market >= cfg$price_clusters$min_households)]
    d[, urban := as.integer(rural == 0)]

    # goods that WELCOM can estimate: a unit value must be observed in enough clusters
    sup <- x[uv_use == TRUE & hhid %in% d[in_sample == 1, hhid]][hh[, .(hhid, clus_market)], on = "hhid", nomatch = 0][
      , .(unit_values = .N, clusters = uniqueN(clus_market)), by = category]
    sup <- merge(data.table(category = cats), sup, by = "category", all.x = TRUE)
    sup[is.na(unit_values), `:=`(unit_values = 0L, clusters = 0L)]
    sup[, estimable := clusters >= 30]
    sup[, `:=`(dataset = paste0("est_", vn, "_", mk), variant = vn, market = mk)]
    contract[[length(contract) + 1L]] <- sup

    keep <- c("hhid", "in_sample", "clus_market", "clus_segment", "wgt_market", "wgt_segment", "wgt_hh_raw",
              "exptot", "hhsize", "head_age", "head_male", "single", "children", "educ", "regctl", "region7",
              "quarter_id", "rural", "urban", "tercile", "spend_outlier_any", "any_beverage",
              paste0("w", cats), paste0("luv", cats))
    d <- d[, ..keep]
    # ---- contract checks before anything reaches Stata ----
    ds <- d[in_sample == 1]
    for (g in cats) {
      wv <- ds[[paste0("w", g)]]; lv <- ds[[paste0("luv", g)]]
      check(!anyNA(wv) && all(wv >= 0 & wv <= 1), sprintf("%s/%s: budget share of %s outside [0,1] or missing", vn, mk, g))
      check(all(is.na(lv) | wv > 0), sprintf("%s/%s: unit value of %s present for a non-buyer", vn, mk, g))
      check(all(is.na(lv) | is.finite(lv)), sprintf("%s/%s: non-finite log unit value for %s", vn, mk, g))
    }
    check(ds[, all(uniqueN(regctl) == 1 & uniqueN(quarter_id) == 1), by = clus_market][, all(V1)],
          "region cell or quarter not constant within the primary price cluster")
    check(ds[, all(uniqueN(regctl) == 1 & uniqueN(quarter_id) == 1), by = clus_segment][, all(V1)],
          "region cell or quarter not constant within the survey segment")
    check(!anyNA(ds[, .(exptot, hhsize, head_age, head_male, single, children, educ, wgt_market, wgt_segment)]), "missing regressors in the estimation sample")
    dsets[[paste0("est_", vn, "_", mk)]] <- d
    assert_unique(d, "hhid", paste("estimation file", vn, mk))

    haven::write_dta(as.data.frame(d), file.path(out_dir, paste0("est_", vn, "_", mk, ".dta")), version = 14)
    saveRDS(d, file.path(out_dir, paste0("est_", vn, "_", mk, ".rds")))
    flow[[length(flow) + 1L]] <- data.table(dataset = paste0("est_", vn, "_", mk), households = nrow(d),
                                            in_sample = sum(d$in_sample), urban_in_sample = sum(d$in_sample == 1 & d$urban == 1))
    if (!dict_done) {
      dict <- data.table(variable = names(d), type = vapply(d, function(z) class(z)[1], ""))
      desc <- c(hhid = "Household identifier (ENPH DIRECTORIO)",
                in_sample = "1 = eligible for estimation (positive total expenditure, complete covariates, valid budget shares, cluster of 2+ households)",
                clus_market = "Primary price cluster: local market = municipality x area (urban/rest) x collection quarter",
                clus_segment = "Alternative price cluster (sensitivity S5): survey segment (municipality + sector)",
                wgt_market = "Estimation weight: market-cluster mean of the expansion factor, scaled to mean 1 (constant within clus_market)",
                wgt_segment = "Estimation weight for the segment clusters (constant within clus_segment, mean 1)",
                wgt_hh_raw = "ENPH household expansion factor FEX_C (unscaled)",
                exptot = "Monthly current expenditure of the spending unit, COP (DANE GCUG); denominator of every budget share",
                hhsize = "Number of household members (P6008)", head_age = "Age of household head, years (P6040)",
                head_male = "Household head is male (P6020 == 1)", single = "Single-member household",
                children = "Any member aged 0-5", educ = "Head education: 1 none/preschool, 2 primary, 3 secondary/media, 4 higher, 9 unknown",
                regctl = "Regional control cell: DANE region x (urban/rest)", region7 = "DANE region (7)",
                quarter_id = "Collection quarter (1 = 2016Q3 ... 4 = 2017Q2)", rural = "1 = centros poblados y rural disperso (P3 != 1)",
                urban = "1 = cabecera (P3 == 1)", tercile = "Weighted tercile of per-capita household income (DANE IT / members)",
                spend_outlier_any = "1 = household flagged for extreme monthly spending in at least one category (used only in the outlier sensitivity)",
                any_beverage = "1 = household has a valid purchase in at least one category")
      for (g in cats) {
        desc[paste0("w", g)] <- sprintf("WELCOM field: share of monthly %s purchases in exptot (0 for non-buyers)", g)
        desc[paste0("luv", g)] <- sprintf("WELCOM field: log observed unit value of %s, COP per %s; missing when no valid unit value is observed", g,
                                          cfg$categories$quantity_unit[match(g, cats)])
      }
      dict[, description := desc[variable]]
      write_csv(dict, p_meta(cfg, "variable_dictionary.csv"))
      write_csv(dict, file.path(out_dir, "dictionary.csv"))
      dict_done <- TRUE
    }
  }
  contract <- rbindlist(contract)
  write_csv(contract, file.path(out_dir, "welcom_contract.csv"))
  write_csv(contract, p_out(cfg, "diagnostics", run_id, "welcom_contract.csv"))
  write_csv(rbindlist(flow), p_out(cfg, "diagnostics", run_id, "estimation_files.csv"))

  # ---- per-model contract: which goods have enough unit-value support in THAT model's sample and clusters ----
  # A good enters a model only if its unit value is observed in at least `min_clusters_with_unit_value` clusters
  # and the within-cluster unit-value regression has at least `min_within_cluster_df` degrees of freedom
  # (unit values minus clusters with a unit value); otherwise the measurement-error variance cannot be estimated.
  # Models of the same comparison group (the income terciles) use the goods that pass in every member.
  mods <- fread(p_root(cfg, "config", "models.csv"), encoding = "UTF-8", na.strings = "")
  e <- cfg$estimation
  pm <- rbindlist(lapply(seq_len(nrow(mods)), function(i) {
    d <- dsets[[mods$dataset[i]]]
    check(!is.null(d), paste("models.csv refers to an unknown dataset:", mods$dataset[i]))
    ds <- d[eval(parse(text = mods$sample[i]))]
    cl <- ds[[mods$cluster[i]]]
    dg <- if (is.na(mods$drop_goods[i])) character() else strsplit(as.character(mods$drop_goods[i]), " ")[[1]]
    rbindlist(lapply(cats, function(g) {
      ok <- !is.na(ds[[paste0("luv", g)]])
      data.table(model_id = mods$model_id[i], role = mods$role[i], good = g, households = nrow(ds),
                 unit_values = sum(ok), clusters_with_unit_value = uniqueN(cl[ok]),
                 within_cluster_df = sum(ok) - uniqueN(cl[ok]),
                 dropped_by_specification = g %chin% dg)
    }))
  }))
  pm[, supported := clusters_with_unit_value >= e$min_clusters_with_unit_value & within_cluster_df >= e$min_within_cluster_df]
  pm[, market := sub("^[^_]+_", "", model_id)]
  pm[, supported_group := supported]
  pm[role == "tercile", supported_group := all(supported), by = .(market, good)]
  pm[, estimable := supported_group & !dropped_by_specification]
  pm[, reason := fcase(estimable, "",
                       dropped_by_specification, "excluded by the model specification",
                       unit_values == 0, "no unit values (no physical quantities collected)",
                       !supported, "too few unit values in this model's sample",
                       default = "too few unit values in another model of the same comparison group")]
  write_csv(pm, file.path(out_dir, "welcom_contract_models.csv"))
  write_csv(pm, p_out(cfg, "diagnostics", run_id, "welcom_contract_models.csv"))
  write_stata_params(cfg)
  log_msg("Goods per model: ", paste(pm[, .(g = paste(good[estimable], collapse = " ")), by = model_id][, .N, by = g][, paste0("[", g, "] x", N)], collapse = "; "))
  invisible(contract)
}
