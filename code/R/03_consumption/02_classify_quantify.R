# Stage 03b: classify beverage records, convert recall periods to a month, convert physical
# quantities, and flag validity. One row per beverage-related record; flags instead of deletions.
#
# Legacy mapping: fclasidrinks(), ftextdrinks(), festconsu() in fclasicoicop.R and the FactorMensual /
# qestandar / pqlitro blocks of SSBEConsuBases{Urbano,Rural}.R. Corrections are listed in
# docs/corrections_log.md (C-03 to C-14).

recall_days_for <- function(tx, cfg) {
  r <- cfg$recall
  fcase(tx$module_id %in% c("urb_diary", "urb_meals_hh") & !is.na(tx$scope) & tx$scope == 2L, as.numeric(r$urban_shopper_pocket_days),
        tx$module_id %in% c("urb_diary", "urb_meals_hh"), as.numeric(r$urban_household_diary_days),
        tx$module_id %in% c("urb_personal", "urb_meals_personal"), as.numeric(r$urban_personal_diary_days),
        tx$module_id %in% c("rur_weekly", "rur_meals_hh", "rur_personal", "rur_meals_personal"), as.numeric(r$rural_week_days),
        default = NA_real_)
}

monthly_factors <- function(tx, cfg) {
  ff <- fread(p_meta(cfg, "frequency_factors.csv"), encoding = "UTF-8", na.strings = "")
  fixed <- setNames(ff[primary_rule == "fixed", primary_factor], ff[primary_rule == "fixed", freq_code])
  base <- cfg$recall$days_per_month / tx$recall_days
  prim <- base
  fx <- fixed[as.character(tx$freq)]
  prim[!is.na(fx)] <- fx[!is.na(fx)]
  design <- base
  # Less-frequent module, previous-month sections (all beverage records are in J11): DANE's Tabla 3
  # (Metodologia General ENPH, DSO-ENPH-MET-001 v2, section 2.1.5): the amount is kept for weekly,
  # fortnightly, monthly and sporadic purchases and divided by 2 / 3 / 6 / 12 for bimonthly, quarterly,
  # half-yearly and yearly purchases. The reference-period variant keeps the reported monthly total.
  lf <- tx$module_id == "lessfreq_items"
  lf_div <- c(`6` = 1 / 2, `7` = 1 / 3, `10` = 1 / 6, `8` = 1 / 12)[as.character(tx$freq)]
  prim[lf] <- cfg$recall$less_frequent_month_factor * fifelse(is.na(lf_div[lf]), 1, lf_div[lf])
  design[lf] <- cfg$recall$less_frequent_month_factor
  list(primary = prim, design = design)
}

convert_quantity <- function(tx, cfg) {
  u <- cfg$units; dens <- 1.03
  q <- tx$qty_raw; un <- tx$unit_raw; eq <- tx$equiv_raw; eu <- tx$equiv_unit_raw; b <- tx$quantity_basis
  vol <- fcase(un == 1L, q / 1000, un == 2L, q, un == 4L, q * u$ml_per_us_fl_oz / 1000,
               un == 8L & eu %in% c(2L, 3L) & eq > 0, eq / 1000, default = NA_real_)
  kg <- fcase(un == 3L, q / u$g_per_kg, un == 5L, q * u$g_per_lb / u$g_per_kg, un == 6L, q,
              un == 7L, q * u$g_per_arroba / u$g_per_kg, un == 8L & eu == 1L & eq > 0, eq / u$g_per_kg, default = NA_real_)
  qty <- fcase(b == "litre", vol,
               b == "litre_or_density", fifelse(!is.na(vol), vol, kg / dens),
               b == "kilogram", kg, default = NA_real_)
  rule <- fcase(is.na(b) | b == "none", "category_without_physical_unit",
                is.na(un), "module_without_unit_field",
                !is.na(qty) & b == "litre_or_density" & is.na(vol), "weight_to_litre_density_1.03",
                !is.na(qty) & un == 8L, "other_unit_dane_equivalence",
                !is.na(qty), "direct_unit",
                un == 8L, "other_unit_without_equivalence",
                b %in% c("litre", "litre_or_density"), "weight_unit_for_volume_good",
                default = "volume_unit_for_weight_good")
  list(qty = qty, rule = rule)
}

run_classify_quantify <- function(cfg, run_id) {
  tx <- readRDS(p_interim(cfg, "03_consumption", "transactions_raw.rds"))
  cmap <- read_category_map(cfg, "primary")
  cmap_broad <- read_category_map(cfg, "broad_sb")
  rules <- read_text_rules(cfg)
  group_map <- fread(p_meta(cfg, "capc_group_map.csv"), encoding = "UTF-8")
  cats <- cfg$categories$ids

  is_capc <- tx$module_id %in% c("urb_capc", "rur_capc")
  cc <- classify_coicop(tx$code, cmap)
  cb <- classify_coicop(tx$code, cmap_broad)
  tc <- classify_text(tx$text, rules)
  tx <- cbind(tx, cc[, .(code_category = category, quantity_basis, rule_prefix)], tc)
  tx[, code_category_broad := cb$category]
  tx[, quantity_basis_broad := cb$quantity_basis]

  # --- category and source ------------------------------------------------------------------
  tx[, `:=`(category = NA_character_, source = NA_character_)]
  tx[code_category %chin% cats, `:=`(category = code_category, source = "coded")]
  tx[code == "11110301" & text_pure & text_category == "water", `:=`(category = "water", source = "text")]
  tx[code_category == "alc_generic", category := "alc_unallocated"]
  tx[code_category == "alc_generic" & text_pure & text_category %chin% c("beer", "spirits"),
     `:=`(category = text_category, source = "text")]
  tx[(is.na(code_category) | code_category == "excluded") & text_pure, `:=`(category = text_category, source = "text")]
  tx[is.na(category) & code_category == "excluded", category := "excluded_code"]
  gm <- setNames(group_map$category, sprintf("CAPC_%02d", group_map$group_code))
  gmix <- setNames(group_map$mixed_group == "yes", sprintf("CAPC_%02d", group_map$group_code))
  tx[is_capc, `:=`(category = gm[code], source = "capc")]
  tx[, capc_mixed_group := is_capc & gmix[code] %in% TRUE]
  tx[source == "text", quantity_basis := "none"]
  # broad-SB variant (classification sensitivity): only the coded component changes
  tx[, category_broad := category]
  tx[code_category_broad == "sb" & (is.na(category) | category == "excluded_code"), category_broad := "sb"]
  tx[, source_broad := fifelse(category_broad == "sb" & (is.na(source)), "coded", source)]

  tx[, composite_only := is.na(category) & text_composite]
  n_all <- nrow(tx)
  tx <- tx[!is.na(category) | !is.na(category_broad) | composite_only]
  log_msg("Beverage-related records kept: ", nrow(tx), " of ", n_all)

  # --- market (purchase channel) ------------------------------------------------------------
  tx[, market := fifelse(startsWith(code, "11"), "away", "home")]

  # --- acquisition form, amount validity ----------------------------------------------------
  tx[, is_capc := module_id %in% c("urb_capc", "rur_capc")]
  tx[, is_purchase := (!is_capc & !is.na(form) & form == 1L)]
  tx[, value_valid := !is.na(value_raw) & value_raw >= cfg$money$min_valid_value_cop]
  cap_freq_ok <- list(urb_capc = c(5L, 6L, 7L), rur_capc = c(4L, 5L, 6L, 7L))
  tx[is_capc == TRUE, capc_status := fcase(
    freq == 11L, "never",
    is.na(value_raw), "no_value_asked_or_reported",
    answered == 1L, "bought_inside_reference_period",
    freq == 9L, "sporadic_frequency_undefined",
    (module_id == "urb_capc" & freq %in% cap_freq_ok$urb_capc) | (module_id == "rur_capc" & freq %in% cap_freq_ok$rur_capc), "eligible",
    default = "other")]
  tx[is_capc == TRUE, is_purchase := capc_status == "eligible"]

  # --- monthly conversion -------------------------------------------------------------------
  tx[, recall_days := recall_days_for(tx, cfg)]
  mf <- monthly_factors(tx, cfg)
  tx[, `:=`(factor_primary = mf$primary, factor_design = mf$design)]
  ffix <- c(`4` = 2, `5` = 1, `6` = 0.5, `7` = 1 / 3)
  tx[is_capc == TRUE, `:=`(factor_primary = ffix[as.character(freq)], factor_design = 0)]
  tx[is_capc == TRUE & !is_purchase, factor_primary := NA_real_]

  tx[, use_spend := is_purchase & value_valid & !is.na(factor_primary)]
  tx[, value_month := fifelse(use_spend, value_raw * factor_primary, NA_real_)]
  tx[, value_month_design := fifelse(use_spend & !is_capc, value_raw * factor_design, NA_real_)]

  # --- physical quantities ------------------------------------------------------------------
  cq <- convert_quantity(tx, cfg)
  tx[, `:=`(qty_std = cq$qty, qty_rule = cq$rule)]
  tx[, qty_unit := fcase(quantity_basis %in% c("litre", "litre_or_density"), "litre", quantity_basis == "kilogram", "kilogram", default = NA_character_)]
  lim <- cfg$units
  tx[, qty_plausible := !is.na(qty_std) & fifelse(qty_unit == "litre",
        qty_std >= lim$min_plausible_litres_per_record & qty_std <= lim$max_plausible_litres_per_record,
        qty_std >= lim$min_plausible_kg_per_record & qty_std <= lim$max_plausible_kg_per_record)]
  tx[!is.na(qty_std) & !qty_plausible, qty_rule := "implausible_quantity"]
  tx[, qty_valid := use_spend & qty_plausible]           # valid positive purchase with a defensible physical quantity
  tx[, qty_month := fifelse(qty_valid, qty_std * factor_primary, NA_real_)]
  tx[, qty_month_design := fifelse(qty_valid, qty_std * factor_design, NA_real_)]
  tx[, qty_direct_volume := qty_valid & qty_rule == "direct_unit"]   # for the unit-rule sensitivity

  saveRDS(tx, p_interim(cfg, "03_consumption", "transactions.rds"), compress = FALSE)

  # --- diagnostics --------------------------------------------------------------------------
  lab <- setNames(cfg$categories$labels, cats)
  d1 <- tx[!is.na(category), .(records = .N, households = uniqueN(hhid), purchases = sum(is_purchase),
                               valid_spend = sum(use_spend), valid_quantity = sum(qty_valid),
                               monthly_spend_sample_cop = sum(value_month, na.rm = TRUE)),
           keyby = .(category, market, source, module_id)]
  write_csv(d1, p_out(cfg, "diagnostics", run_id, "classification_by_module.csv"))
  d2 <- tx[!is.na(category) & is_purchase & !is_capc, .N, keyby = .(category, market, qty_rule)]
  d2[, share := round(N / sum(N), 4), by = .(category, market)]
  write_csv(d2, p_out(cfg, "diagnostics", run_id, "quantity_rules.csv"))
  d3 <- tx[is_capc == TRUE, .N, keyby = .(module_id, code, category, capc_status)]
  write_csv(d3, p_out(cfg, "diagnostics", run_id, "capitulo_c_status.csv"))
  d4 <- tx[!is.na(text) & nzchar(text) & (text_mentions | source == "text"),
           .(records = .N, households = uniqueN(hhid), value_sample_cop = sum(value_raw, na.rm = TRUE)),
           keyby = .(module_id, mention = text_mention_category, pure = text_pure,
                     outcome = fcase(source == "text", "text-identified beverage purchase",
                                     source == "coded", "already coded as a beverage",
                                     composite_only, "composite purchase: amount not attributable",
                                     default = "other"))]
  write_csv(d4, p_out(cfg, "diagnostics", run_id, "text_recovery.csv"))
  d5 <- tx[source == "coded" & text_pure & text_category != category, .N, keyby = .(code, category, text_category)]
  write_csv(d5, p_out(cfg, "diagnostics", run_id, "code_text_disagreements.csv"))
  d6 <- tx[!is.na(category) & !is_capc, .(records = .N, value_sample_cop = sum(value_raw, na.rm = TRUE)),
           keyby = .(category, form = fifelse(is.na(form), 0L, form))]
  write_csv(d6, p_out(cfg, "diagnostics", run_id, "acquisition_form.csv"))
  log_msg("Classified: ", paste(tx[category %chin% cats & use_spend, .N, keyby = category][, paste0(category, "=", N)], collapse = ", "))
  invisible(tx)
}
