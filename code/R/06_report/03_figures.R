# Stage 06c: figures from the shared results object and the descriptive data.
#   fig1_own_price_specs.pdf     own-price elasticities, M1-M6, with 95% percentile bootstrap intervals
#   fig2_expenditure_specs.pdf   expenditure elasticities, M1-M6
#   fig3_unit_values.pdf         distribution of observed log unit values by beverage (off-trade)

run_figures <- function(cfg, run_id) {
  suppressPackageStartupMessages(library(ggplot2))
  res <- readRDS(file.path(bundle_dir(cfg, run_id), "results.rds"))
  fdir <- function(f) p_out(cfg, "figures", run_id, f)
  labs <- res$labels; mk_lab <- market_labels(cfg)
  goods_est <- setdiff(res$categories, res$not_estimable)
  th <- theme_minimal(base_size = 9) + theme(panel.grid.minor = element_blank(), legend.position = "bottom",
                                              strip.text = element_text(face = "bold"), plot.title = element_text(size = 10))
  spec_plot <- function(stat_name, ylab, ref, file) {
    e <- res$est[spec %chin% paste0("M", 1:6) & stat == stat_name & (stat_name != "price" | row == col)]
    e[, `:=`(good = factor(labs[row], levels = labs[goods_est]), mk = factor(mk_lab[market], levels = mk_lab))]
    # Interval bars are truncated at a robust range per beverage (estimates +/- 1.5 x the median interval width),
    # so that a specification with a very wide interval does not flatten the panel. Truncation is stated in the caption.
    if (any(!is.na(e$ci_lo))) {
      e[, w := median(ci_hi - ci_lo, na.rm = TRUE), by = row]
      e[, `:=`(lim_lo = min(estimate) - 1.5 * w, lim_hi = max(estimate) + 1.5 * w), by = row]
      e[, truncated := !is.na(ci_lo) & (ci_lo < lim_lo | ci_hi > lim_hi)]
      e[, `:=`(ci_lo = pmax(ci_lo, lim_lo), ci_hi = pmin(ci_hi, lim_hi))]
    } else e[, truncated := FALSE]
    p <- ggplot(e, aes(x = spec, y = estimate)) +
      geom_hline(yintercept = ref, linewidth = 0.3, colour = "grey50") +
      { if (any(!is.na(e$ci_lo))) geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi, linetype = truncated), width = 0.15, linewidth = 0.35, colour = "grey30") } +
      scale_linetype_manual(values = c(`FALSE` = "solid", `TRUE` = "dashed"), guide = "none") +
      geom_point(aes(shape = spec == "M1"), size = 1.6, colour = "#1f4e79") +
      scale_shape_manual(values = c(`TRUE` = 16, `FALSE` = 1), guide = "none") +
      facet_grid(good ~ mk, scales = "free_y") + labs(x = NULL, y = ylab) + th
    ggsave(fdir(file), p, width = 6.5, height = 7.2, device = "pdf")
    invisible(p)
  }
  spec_plot("price", "Own-price elasticity", -1, "fig1_own_price_specs.pdf")
  spec_plot("expenditure", "Expenditure elasticity", 1, "fig2_expenditure_specs.pdf")

  hc <- readRDS(p_interim(cfg, "04_prices", "household_category.rds"))
  u <- hc[variant == "primary" & market == "home" & uv_use == TRUE, .(category, l = log10(uv))]
  u[, good := factor(labs[category], levels = labs[goods_est])]
  p3 <- ggplot(u, aes(x = l)) + geom_histogram(bins = 60, fill = "#1f4e79", colour = NA) +
    facet_wrap(~good, scales = "free", ncol = 3) +
    labs(x = "log10 of the observed unit value (COP per litre; per kilogram for hot drinks)", y = "Households") + th
  ggsave(fdir("fig3_unit_values.pdf"), p3, width = 6.5, height = 4, device = "pdf")
  log_msg("Figures written to ", fdir(""))
  invisible(TRUE)
}
