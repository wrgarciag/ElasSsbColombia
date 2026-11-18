# Stage 03a: harmonise the expenditure modules into one transaction-level file.
#
# One row per recorded acquisition (or per Capitulo C food-group answer), with a stable key,
# the module of origin and the raw fields needed downstream. Nothing is classified or converted here.
# Legacy mapping: SSBEConsuBasesUrbano.R, SSBEConsuBasesRural.R (module by module).
#
# Rows kept: any COICOP code in the beverage-relevant divisions, plus every row of the modules that
# carry a free-text description (text recovery needs the non-beverage codes too).

beverage_relevant_code <- function(code) grepl("^(0114|0121|0122|021|1111)", code)

harmonise_module <- function(cfg, m) {
  d <- readRDS(p_interim(cfg, "01_import", paste0(m$module_id, ".rds")))
  g <- function(v, as = identity) if (!is.na(v) && nzchar(v)) as(d[[v]]) else rep(NA, nrow(d))
  num <- function(x) suppressWarnings(as.numeric(x))
  int <- function(x) suppressWarnings(as.integer(x))
  out <- data.table(
    module_id = m$module_id, hhid = d$DIRECTORIO,
    seq_e = d$SECUENCIA_ENCUESTA, seq_p = d$SECUENCIA_P, orden = d$ORDEN,
    code = as.character(g(m$code_var)), text = as.character(g(m$text_var)),
    qty_raw = num(g(m$qty_var)), unit_raw = int(g(m$unit_var)),
    equiv_raw = num(g(m$equiv_var)), equiv_unit_raw = int(g(m$equiv_unit_var)),
    value_raw = num(g(m$value_var)), freq = int(g(m$freq_var)), form = int(g(m$form_var)),
    place = int(g(m$place_var)), scope = int(g(m$scope_var)), answered = int(g(m$answered_var)),
    cap = as.character(g(m$cap_var)))
  out[, txn_id := paste(module_id, hhid, seq_e, seq_p, orden, sep = "|")]
  has_text <- !is.na(m$text_var) && nzchar(m$text_var)
  out <- out[!is.na(code) & nzchar(code)]
  if (!has_text) out <- out[beverage_relevant_code(code)]
  out
}

harmonise_capc <- function(cfg, m, group_map) {
  d <- readRDS(p_interim(cfg, "01_import", paste0(m$module_id, ".rds")))
  d <- d[NC2_CC_P1 %in% as.integer(group_map$group_code)]
  data.table(module_id = m$module_id, hhid = d$DIRECTORIO,
             seq_e = d$SECUENCIA_ENCUESTA, seq_p = d$SECUENCIA_P, orden = d$ORDEN,
             code = sprintf("CAPC_%02d", as.integer(d$NC2_CC_P1)), text = NA_character_,
             qty_raw = NA_real_, unit_raw = NA_integer_, equiv_raw = NA_real_, equiv_unit_raw = NA_integer_,
             value_raw = as.numeric(d$NC2_CC_P3_S1), freq = as.integer(d$NC2_CC_P2), form = NA_integer_,
             place = NA_integer_, scope = NA_integer_, answered = as.integer(d$NC2_CC_P3_S2), cap = "C",
             txn_id = paste(m$module_id, d$DIRECTORIO, d$SECUENCIA_ENCUESTA, d$SECUENCIA_P, d$ORDEN, sep = "|"))
}

run_harmonize <- function(cfg, run_id) {
  mods <- fread(p_meta(cfg, "enph_modules.csv"), encoding = "UTF-8", na.strings = "")[used == "yes"]
  group_map <- fread(p_meta(cfg, "capc_group_map.csv"), encoding = "UTF-8")
  purchase_mods <- mods[!module_id %in% c("households", "persons", "urb_capc", "rur_capc")]
  parts <- list()
  for (i in seq_len(nrow(purchase_mods))) {
    parts[[purchase_mods$module_id[i]]] <- harmonise_module(cfg, as.list(purchase_mods[i]))
  }
  for (cm in c("urb_capc", "rur_capc")) parts[[cm]] <- harmonise_capc(cfg, as.list(mods[module_id == cm]), group_map)
  tx <- rbindlist(parts, use.names = TRUE)
  assert_unique(tx, "txn_id", "harmonised transactions")
  hh <- readRDS(p_interim(cfg, "02_households", "households.rds"))
  check(all(tx$hhid %in% hh$hhid), "transactions for households missing from the household file")

  dir.create(p_interim(cfg, "03_consumption"), recursive = TRUE, showWarnings = FALSE)
  saveRDS(tx, p_interim(cfg, "03_consumption", "transactions_raw.rds"), compress = FALSE)
  summ <- tx[, .(rows = .N, households = uniqueN(hhid), with_text = sum(!is.na(text) & nzchar(text)),
                 with_quantity = sum(!is.na(qty_raw)), with_unit = sum(!is.na(unit_raw)),
                 with_value = sum(!is.na(value_raw))), by = module_id]
  write_csv(summ, p_out(cfg, "diagnostics", run_id, "harmonised_rows_by_module.csv"))
  log_msg("Harmonised ", nrow(tx), " rows from ", length(parts), " modules")
  invisible(tx)
}
