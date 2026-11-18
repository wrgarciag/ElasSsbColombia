# Stage 04b: price clusters (defined from geography and survey time, never from a target count)
# and their diagnostics. Price clusters are separate from the design PSU proxy (municipality).
#
#   market    municipality x area (urban / rest) x collection quarter. PRIMARY. A cluster is a local market in
#             a quarter: households in it face the same shops and the same period. Never mixes urban and rural.
#   segment   municipality + sector: the survey segment (about 10 neighbouring households interviewed in the
#             same month). SENSITIVITY S5. Segments of one city are not separate markets, and with 1-4 unit
#             values per segment the cluster means are dominated by measurement error (see the reliability
#             column below and docs/methods.md, section 5).
#   seg8      first 8 characters of VIVIENDA (legacy definition); comparison diagnostics only.

price_cluster_definitions <- function() data.table(
  cluster_def = c("market", "segment", "seg8"),
  label = c("Local market: municipality x area (urban / rest) x collection quarter",
            "Survey segment (municipality + sector), single collection month",
            "Legacy: first 8 characters of the dwelling identifier"),
  role = c("primary", "sensitivity S5", "diagnostic only"))

run_price_clusters <- function(cfg, run_id) {
  hh <- readRDS(p_interim(cfg, "02_households", "households.rds"))
  hc <- readRDS(p_interim(cfg, "04_prices", "household_category.rds"))
  hh[, clus_market := as.integer(factor(paste(municipality, rural, quarter)))]
  hh[, clus_segment := as.integer(factor(segment))]
  hh[, clus_seg8 := as.integer(factor(seg8))]
  # Cluster-constant weights (see docs/welcom_method.md, section 5).
  hh[, weight_market_mean := mean(weight), by = clus_market]
  hh[, weight_segment_mean := mean(weight), by = clus_segment]
  saveRDS(hh, p_interim(cfg, "02_households", "households.rds"))
  write_csv(price_cluster_definitions(), p_meta(cfg, "price_cluster_definitions.csv"))

  defs <- c("market", "segment", "seg8")
  size <- rbindlist(lapply(defs, function(dn) {
    z <- hh[, .(n = .N, months = uniqueN(period), quarters = uniqueN(quarter), urban = any(rural == 0), rur = any(rural == 1),
                regions = uniqueN(region_area), w_cv = sd(weight) / mean(weight)), by = c(paste0("clus_", dn))]
    data.table(cluster_def = dn, clusters = nrow(z), households = sum(z$n), min_size = min(z$n),
               p10_size = quantile(z$n, .1), median_size = median(z$n), p90_size = quantile(z$n, .9), max_size = max(z$n),
               harmonic_mean_size = 1 / mean(1 / z$n),
               clusters_below_5 = sum(z$n < 5), singletons = sum(z$n == 1),
               clusters_mixing_urban_rural = sum(z$urban & z$rur), clusters_spanning_quarters = sum(z$quarters > 1),
               clusters_spanning_months = sum(z$months > 1),
               clusters_spanning_region_cells = sum(z$regions > 1), median_within_cluster_weight_cv = median(z$w_cv, na.rm = TRUE))
  }))
  write_csv(size, p_out(cfg, "diagnostics", run_id, "price_cluster_sizes.csv"))

  # Within / between variation of observed log unit values, buyer support and the reliability of the
  # cluster-mean unit value, by cluster definition. Reliability = share of the variance of cluster means
  # that is not within-cluster sampling noise: 1 - (within variance / harmonic number of unit values) / variance of means.
  pv <- list()
  for (dn in defs) {
    cl <- hh[, .(hhid, clus = get(paste0("clus_", dn)), rural)]
    for (mk in c("home", "combined")) {
      d <- merge(hc[variant == "primary" & market == mk], cl, by = "hhid")
      for (g in cfg$categories$ids) {
        x <- d[category == g]
        u <- x[uv_use == TRUE, .(clus, l = log(uv))]
        nb <- x[, .(buyers = sum(buyer), uvs = sum(uv_use), n = .N), by = clus]
        if (nrow(u) < 3) {
          pv[[length(pv) + 1L]] <- data.table(cluster_def = dn, market = mk, category = g, unit_values = nrow(u),
                                              clusters_total = nrow(nb), clusters_with_buyer = sum(nb$buyers > 0))
          next
        }
        u[, m := mean(l), by = clus]
        cm <- u[, .(m = m[1], k = .N), by = clus]
        ncl <- nrow(cm)
        ssw <- sum((u$l - u$m)^2); ssb <- sum((u$m - mean(u$l))^2)
        dfw <- nrow(u) - ncl; dfb <- ncl - 1
        s2w <- if (dfw > 0) ssw / dfw else NA_real_
        hn <- 1 / mean(1 / cm$k)
        pv[[length(pv) + 1L]] <- data.table(
          cluster_def = dn, market = mk, category = g, unit_values = nrow(u),
          clusters_total = nrow(nb), clusters_with_buyer = sum(nb$buyers > 0),
          clusters_with_unit_value = sum(nb$uvs > 0), clusters_with_2plus_unit_values = sum(nb$uvs >= 2),
          median_unit_values_per_cluster_with_any = median(nb$uvs[nb$uvs > 0]),
          harmonic_unit_values_per_cluster = hn, within_cluster_df = dfw,
          sd_log_uv = sd(u$l), share_variance_between = ssb / (ssb + ssw),
          reliability_cluster_mean = max(0, 1 - (s2w / hn) / var(cm$m)),
          anova_F = if (dfw > 0) (ssb / dfb) / s2w else NA_real_,
          anova_p = if (dfw > 0) pf((ssb / dfb) / s2w, dfb, dfw, lower.tail = FALSE) else NA_real_,
          zero_share = mean(!x$buyer))
      }
    }
  }
  write_csv(rbindlist(pv, fill = TRUE), p_out(cfg, "diagnostics", run_id, "price_cluster_variation.csv"))
  log_msg("Price clusters: ", paste(size$cluster_def, size$clusters, sep = "=", collapse = ", "))
  invisible(size)
}
