# Stage 01a: inventory of real input files, with sizes and SHA-256 checksums.
# Writes metadata/input_manifest.csv (aggregate metadata only; safe to commit).

run_inventory <- function(cfg, run_id) {
  mods <- fread(p_meta(cfg, "enph_modules.csv"), encoding = "UTF-8")
  raw_dir <- p_root(cfg, cfg$paths$raw_enph)

  rows <- lapply(seq_len(nrow(mods)), function(i) {
    f <- file.path(raw_dir, mods$file[i])
    ex <- file.exists(f)
    data.table(input_id = mods$module_id[i], kind = "ENPH module (.sav)",
               path = file.path(cfg$paths$raw_enph, mods$file[i]), exists = ex,
               bytes = if (ex) file.size(f) else NA_real_,
               sha256 = if (ex) sha256_file(f) else NA_character_,
               used = mods$used[i],
               source = "DANE, Encuesta Nacional de Presupuestos de los Hogares 2016-2017, public-use microdata")
  })
  man <- rbindlist(rows)

  extra <- list(
    list("coicop_nomenclature", "DANE COICOP nomenclature for ENPH", "metadata/coicop_nomenclature_dane_enph.csv",
         "DANE nomenclature supplied with the legacy project (data/interim/NomenclaturaCoicopDaneEnph.csv), converted to UTF-8"),
    list("manuscript_pdf", "Manuscript used as starting point", "docs/Paper_20_1012_ElasticiBeverages.pdf",
         "Maldonado & Garcia, version dated 2026-11-12"),
    list("welcom_duvm", "WELCOM duvm.ado (pinned copy)", "code/stata/ado/d/duvm.ado",
         "WELCOM (World Bank), copied from the local Stata PLUS directory; see code/stata/ado/WELCOM_VERSION.md")
  )
  for (q in list.files(p_root(cfg, cfg$paths$questionnaires), pattern = "[.]pdf$")) {
    extra[[length(extra) + 1L]] <- list(paste0("questionnaire_", gsub("[^A-Za-z0-9]+", "_", tools::file_path_sans_ext(q))),
                                        "ENPH questionnaire (PDF)", file.path(cfg$paths$questionnaires, q), "DANE")
  }
  man2 <- rbindlist(lapply(extra, function(e) {
    f <- p_root(cfg, e[[3]]); ex <- file.exists(f)
    data.table(input_id = e[[1]], kind = e[[2]], path = e[[3]], exists = ex,
               bytes = if (ex) file.size(f) else NA_real_,
               sha256 = if (ex) sha256_file(f) else NA_character_, used = "yes", source = e[[4]])
  }))
  man <- rbind(man, man2)
  write_csv(man, p_meta(cfg, "input_manifest.csv"))

  missing_used <- man[exists == FALSE & used == "yes" & kind == "ENPH module (.sav)"]
  check(nrow(missing_used) == 0, paste("Missing required ENPH modules:", paste(missing_used$path, collapse = "; ")))
  log_msg("Inventory: ", nrow(man), " inputs; ", sum(!man$exists), " missing (non-blocking: ",
          paste(man[exists == FALSE, input_id], collapse = ", "), ")")
  invisible(man)
}
