# Stage 02a: household universe, demographics of the household head, composition, survey design
# variables and geography. Every variable is built from a documented ENPH source variable
# (see metadata/variable_dictionary.csv).
#
# Legacy mapping: SSBDHousehold.R. Corrections:
#  - education "Primaria" was the default for every unclassified code (including missing); it is now
#    assigned only to P6210 == 3, and unknown education is its own category;
#  - the household universe is all ENPH households (the legacy file dropped 4,267 of them later on);
#  - design PSU (municipality) and survey segment are separated from the price cluster.

run_households <- function(cfg, run_id) {
  hh <- readRDS(p_interim(cfg, "01_import", "households.rds"))
  pe <- readRDS(p_interim(cfg, "01_import", "persons.rds"))
  assert_unique(hh, "DIRECTORIO", "households")
  assert_unique(pe, c("DIRECTORIO", "ORDEN"), "persons")
  check(all(pe$DIRECTORIO %in% hh$DIRECTORIO), "persons without a household record")

  # --- Geography and design ---------------------------------------------------------------
  # VIVIENDA = municipality(5, DIVIPOLA) | sector(4) | section(2) | block(4) | dwelling(4)
  check(all(nchar(hh$VIVIENDA) == 23), "unexpected VIVIENDA format")
  parts <- tstrsplit(hh$VIVIENDA, "|", fixed = TRUE)
  check(length(parts) == 5, "VIVIENDA does not have 5 '|'-separated parts")
  d <- hh[, .(hhid = DIRECTORIO, vivienda = VIVIENDA,
              municipality = parts[[1]], sector = parts[[2]], section = parts[[3]], block = parts[[4]],
              region = REGION, domain = DOMINIO, area_class = as.integer(P3),
              period = PERIODO, weight = as.numeric(FEX_C),
              hhsize = as.integer(P6008))]
  d[, department := substr(municipality, 1, 2)]
  d[, segment := paste0(municipality, "|", sector)]            # survey segment: municipality + sector
  d[, seg8 := substr(vivienda, 1, 8)]                           # legacy cluster (municipality + 2 digits)
  d[, design_psu := municipality]                               # approximation: PSU id is not released
  d[, design_stratum := paste0(domain, "|", fifelse(area_class == 1L, "cabecera", "resto"))]
  d[, rural := as.integer(area_class != 1L)]                    # P3: 1 cabecera; 2,3 centros poblados y rural disperso
  d[, year := as.integer(substr(period, 1, 4))]
  d[, month := as.integer(substr(period, 5, 6))]
  d[, quarter := paste0(year, "Q", (month - 1L) %/% 3L + 1L)]
  d[, quarter_id := as.integer(factor(quarter, levels = sort(unique(quarter))))]
  d[, region_area := paste0(region, " / ", fifelse(rural == 1L, "rest", "urban"))]

  # which food questionnaire the household answered (urban diary vs rural weekly)
  urb_ids <- unique(readRDS(p_interim(cfg, "01_import", "urb_capc.rds"))$DIRECTORIO)
  rur_ids <- unique(readRDS(p_interim(cfg, "01_import", "rur_capc.rds"))$DIRECTORIO)
  check(length(intersect(urb_ids, rur_ids)) == 0, "households with both urban and rural food questionnaires")
  d[, food_form := fifelse(hhid %in% rur_ids, "rural_weekly", fifelse(hhid %in% urb_ids, "urban_diary", "none"))]

  # --- Household composition ---------------------------------------------------------------
  comp <- pe[, .(n_persons = .N,
                 n_heads = sum(P6050 == 1, na.rm = TRUE),
                 n_child_0_5 = sum(P6040 <= cfg$sample$child_age_max, na.rm = TRUE),
                 n_under_15 = sum(P6040 < 15, na.rm = TRUE),
                 n_adults_18 = sum(P6040 >= 18, na.rm = TRUE)), by = .(hhid = DIRECTORIO)]
  check(all(comp$n_heads == 1), "households without exactly one head")
  d <- merge(d, comp, by = "hhid", all.x = TRUE)
  check(!anyNA(d$n_persons), "households without person records")
  d[, hhsize_matches_roster := hhsize == n_persons]
  d[, single := as.integer(hhsize == 1L)]
  d[, children := as.integer(n_child_0_5 > 0)]

  # --- Head of household -------------------------------------------------------------------
  head <- pe[P6050 == 1, .(hhid = DIRECTORIO, head_sex = as.integer(P6020), head_age = as.integer(P6040),
                           head_educ_raw = as.integer(P6210))]
  d <- merge(d, head, by = "hhid", all.x = TRUE)
  d[, head_male := as.integer(head_sex == 1L)]                  # P6020: 1 hombre, 2 mujer
  # P6210: 1 ninguno, 2 preescolar, 3 basica primaria, 4 basica secundaria, 5 media, 6 superior, 9 no sabe
  d[, educ := fcase(head_educ_raw %in% c(1L, 2L), 1L,
                    head_educ_raw == 3L, 2L,
                    head_educ_raw %in% c(4L, 5L), 3L,
                    head_educ_raw == 6L, 4L,
                    default = 9L)]
  d[, educ_label := c("None", "Primary", "Secondary", "Higher", NA, NA, NA, NA, "Unknown")[educ]]
  d[, `:=`(educ_none = as.integer(educ == 1L), educ_primary = as.integer(educ == 2L),
           educ_secondary = as.integer(educ == 3L), educ_higher = as.integer(educ == 4L),
           educ_unknown = as.integer(educ == 9L))]

  assert_unique(d, "hhid", "household file")
  check(nrow(d) == nrow(hh), "household count changed")
  dir.create(p_interim(cfg, "02_households"), recursive = TRUE, showWarnings = FALSE)
  saveRDS(d, p_interim(cfg, "02_households", "households.rds"))

  diag <- data.table(
    item = c("households", "persons", "municipalities (design PSU proxy)", "survey segments", "legacy 8-character clusters",
             "collection months", "households answering urban diary", "households answering rural weekly form",
             "households with no food questionnaire", "household size differs from roster count",
             "head education unknown", "weight total (households)"),
    value = c(nrow(d), nrow(pe), uniqueN(d$municipality), uniqueN(d$segment), uniqueN(d$seg8), uniqueN(d$period),
              sum(d$food_form == "urban_diary"), sum(d$food_form == "rural_weekly"), sum(d$food_form == "none"),
              sum(!d$hhsize_matches_roster), sum(d$educ == 9L), round(sum(d$weight))))
  write_csv(diag, p_out(cfg, "diagnostics", run_id, "household_universe.csv"))
  log_msg("Households: ", nrow(d), "; segments: ", uniqueN(d$segment), "; no food questionnaire: ", sum(d$food_form == "none"))
  invisible(d)
}
