# Stage 01b: typed import of the ENPH modules.
# - Reads each .sav with haven (labels kept in a per-module dictionary).
# - Text is forced to valid UTF-8 (legacy bug B12: CP1252 strings broke tolower() under R >= 4.2).
# - Adds a stable record key: module_id + DIRECTORIO + SECUENCIA_ENCUESTA + SECUENCIA_P + ORDEN.
# Output: data/interim/01_import/<module_id>.rds and metadata/variable_labels_enph.csv

to_utf8 <- function(x) {
  bad <- !validUTF8(x)
  if (any(bad)) x[bad] <- iconv(x[bad], from = "CP1252", to = "UTF-8", sub = "?")
  enc2utf8(x)
}

import_one_module <- function(cfg, module_id, file) {
  path <- file.path(p_root(cfg, cfg$paths$raw_enph), file)
  d <- haven::read_sav(path)
  labs <- rbindlist(lapply(names(d), function(v) {
    vl <- attr(d[[v]], "labels")
    data.table(module_id = module_id, variable = v,
               label = to_utf8(gsub("\\s+", " ", paste0("", attr(d[[v]], "label")))),
               value_labels = if (is.null(vl)) "" else to_utf8(paste0(vl, "=", names(vl), collapse = "; ")))
  }))
  d <- as.data.table(haven::zap_formats(haven::zap_labels(d)))
  for (v in names(d)) {
    if (is.character(d[[v]])) set(d, j = v, value = trimws(to_utf8(d[[v]])))
    attr(d[[v]], "label") <- NULL
  }
  id_vars <- intersect(c("DIRECTORIO", "SECUENCIA_ENCUESTA", "SECUENCIA_P", "ORDEN"), names(d))
  for (v in id_vars) set(d, j = v, value = as.integer(d[[v]]))
  d[, module_id := module_id]
  list(data = d, labels = labs)
}

run_import <- function(cfg, run_id) {
  mods <- fread(p_meta(cfg, "enph_modules.csv"), encoding = "UTF-8")[used == "yes"]
  out_dir <- p_interim(cfg, "01_import")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  all_labs <- list(); summ <- list()
  for (i in seq_len(nrow(mods))) {
    m <- mods$module_id[i]
    res <- import_one_module(cfg, m, mods$file[i])
    d <- res$data
    key <- c("DIRECTORIO", "SECUENCIA_ENCUESTA", "SECUENCIA_P", "ORDEN")
    n_dup <- nrow(d) - uniqueN(d, by = key)
    check(n_dup == 0, sprintf("module %s: record key not unique (%d duplicates)", m, n_dup))
    saveRDS(d, file.path(out_dir, paste0(m, ".rds")), compress = FALSE)
    all_labs[[m]] <- res$labels
    summ[[m]] <- data.table(module_id = m, rows = nrow(d), cols = ncol(d), households = uniqueN(d$DIRECTORIO),
                            key_unique = n_dup == 0)
    log_msg("Imported ", m, ": ", nrow(d), " rows, ", uniqueN(d$DIRECTORIO), " households")
    rm(d, res); gc(verbose = FALSE)
  }
  write_csv(rbindlist(all_labs), p_meta(cfg, "variable_labels_enph.csv"))
  write_csv(rbindlist(summ), p_out(cfg, "diagnostics", run_id, "import_summary.csv"))
  invisible(TRUE)
}
