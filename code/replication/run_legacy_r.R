# Legacy replication, R side.
#
# Runs the UNMODIFIED legacy scripts in code/legacy/ to rebuild the beverage records and the
# unit-value files that the legacy duvm do-files read. Nothing in code/legacy/ is edited; the shims below
# only supply what M0SSBElasticity.R would have set and make the code run under R >= 4.2.
#
# Usage, from the repository root (or pass the root as the first argument):
#   Rscript code/replication/run_legacy_r.R [repo_root]
#
# Inputs (not in git):
#   data-raw/enph/*.sav                              ENPH 2016-17 modules
#   data/interim/NomenclaturaCoicopDaneEnph.csv     COICOP nomenclature (Latin-1)
#   data/processed/DataEstimates4.dta               frozen legacy dataset (no code builds it; see audit B1-B3)
#   data/processed/DataEstimates5.dta               frozen legacy dataset; "DataEstimates5 (2).dta" is accepted
# Outputs:
#   data/interim/legacy_run/        household-level intermediates (git-ignored by a .gitignore written here)
#   output/replication/legacy_run/  aggregate checks: de4_comparison.csv, stage_results.txt, sessionInfo.txt
#
# Shims (see docs/reproducibility_audit.md section 1.6):
#   1. M0 parameters copied verbatim (M0SSBElasticity.R l.59-91); M0 itself is not sourced (rm, setwd, font_import).
#   2. wdd_in points at data-raw/enph/; the nomenclature path is redirected to data/interim/.
#   3. read.spss(..., reencode = "CP1252"): ENPH free text is CP1252; R >= 4.2 on Windows runs in UTF-8.
#   4. DataEstimates4/5 are copied into the output folder, where the legacy scripts expect them.

t0 <- Sys.time()
stamp <- function(x) cat(sprintf("\n### [%s min] %s\n", format(round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)), x))

args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(if (length(args) >= 1) args[1] else ".", winslash = "/")
legacy <- file.path(root, "code/legacy")
if (!file.exists(file.path(legacy, "fclasicoicop.R"))) stop("Run from the repository root or pass it as the first argument: ", root)

out    <- file.path(root, "data/interim/legacy_run")
logdir <- file.path(root, "output/replication/legacy_run")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
dir.create(logdir, recursive = TRUE, showWarnings = FALSE)
writeLines(c("# Household-level intermediates from code/replication/run_legacy_r.R. Never commit.", "*", "!.gitignore"),
           file.path(out, ".gitignore"))

suppressPackageStartupMessages({
  library(data.table); library(foreign); library(readstata13); library(ggplot2); library(Hmisc); library(survey)
  library(dplyr); library(magrittr); library(tidyr); library(fixest); library(fastDummies); library(mice); library(haven)
})
options(dplyr.summarise.inform = FALSE)
writeLines(capture.output(sessionInfo()), file.path(logdir, "sessionInfo.txt"))

# --- Shim 1: parameters exactly as M0SSBElasticity.R l.48-91 ---
wd_code <- paste0(legacy, "/")
wdd_in  <- paste0(root, "/data-raw/enph/")
wdd_out <- paste0(out, "/")
wd_resu <- paste0(out, "/resu/"); wdr_gra <- paste0(out, "/graf/")
prural <- TRUE; psample <- FALSE; pstata <- FALSE
v.precio <- 2258
pqlitro <- 1; pqlitSSB <- 1; pglitSSB <- 2500; pqlitMD <- 0.5; pqlitHot <- 0.35
pqlitBeer <- 1; pglitBeer <- 5000; pqlitWa <- 1; pglitWa <- 1000
pqlitSpi <- 1; pglitSpi <- 10000; pqlitWi <- 1; pglitWi <- 28000

# --- Shim 4: frozen legacy datasets ---
de4 <- file.path(root, "data/processed/DataEstimates4.dta")
de5 <- Filter(file.exists, file.path(root, "data/processed", c("DataEstimates5.dta", "DataEstimates5 (2).dta")))[1]
if (!file.exists(de4) || is.na(de5)) stop("DataEstimates4.dta and DataEstimates5.dta must be in data/processed/")
stopifnot(file.copy(de4, file.path(out, "DataEstimates4.dta"), overwrite = TRUE),
          file.copy(de5, file.path(out, "DataEstimates5.dta"), overwrite = TRUE))
cat("DataEstimates5 source:", basename(de5), "\n")

# --- Shim 2: nomenclature location ---
nomen <- file.path(root, "data/interim/NomenclaturaCoicopDaneEnph.csv")
.fread0 <- data.table::fread
fread <- function(file, ...) {
  if (!missing(file) && grepl("NomenclaturaCoicop", file)) file <- nomen
  .fread0(file, ...)
}

# --- Shim 3: encoding ---
.rs0 <- foreign::read.spss
read.spss <- function(file, ...) .rs0(file, ..., reencode = "CP1252")

run <- function(f) {
  stamp(paste("source", f))
  r <- tryCatch({ source(file.path(legacy, f), local = FALSE); "ok" }, error = function(e) paste("ERROR:", conditionMessage(e)))
  cat("   ->", r, "\n")
  r
}

res <- list()
res[["fclasicoicop.R"]]         <- run("fclasicoicop.R")
res[["SSBDInput.R"]]            <- run("SSBDInput.R")
res[["SSBEConsuBasesUrbano.R"]] <- run("SSBEConsuBasesUrbano.R")
res[["SSBEConsuBasesRural.R"]]  <- run("SSBEConsuBasesRural.R")

# --- Check: rebuilt spending vs DataEstimates4 (mimics SSBConsuGasCorrected.R l.626-680) ---
if (res[["SSBEConsuBasesUrbano.R"]] == "ok" && res[["SSBEConsuBasesRural.R"]] == "ok") {
  stamp("compare rebuilt spending with DataEstimates4")
  d4  <- as.data.table(read_dta(de4))
  tot <- as.data.table(rbind(readRDS(file.path(out, "DtConsuUrbanoTotal.rds")),
                             readRDS(file.path(out, "DtConsuRuralTotal.rds")), fill = TRUE))
  g <- tot[, .(gastomes = sum(GastoMes)), by = .(DIRECTORIO, Item, Texto)][!is.na(gastomes)][DIRECTORIO %in% d4$DIRECTORIO]
  cmp <- list()
  for (variant in c("all", "codi", "texto")) {
    gg <- switch(variant, all = g, codi = g[Texto == 0], texto = g[Texto == 1])
    w <- dcast(gg[, .(v = sum(gastomes)), by = .(DIRECTORIO, Item)], DIRECTORIO ~ Item, value.var = "v", fill = 0)
    pref <- switch(variant, all = "Gasto_", codi = "GastoCodi_", texto = "GastoTexto_")
    mm <- merge(d4[, c("DIRECTORIO", grep(paste0("^", pref), names(d4), value = TRUE)), with = FALSE], w,
                by = "DIRECTORIO", all.x = TRUE)
    for (it in c("SSB", "Beer", "Water", "MilkDerivatives", "HotDrinks", "Spirits")) {
      new <- if (it %in% names(mm)) mm[[it]] else rep(0, nrow(mm)); new[is.na(new)] <- 0
      old <- mm[[paste0(pref, it)]]; old[is.na(old)] <- 0
      if (it == "Spirits") { ow <- mm[[paste0(pref, "Wine")]]; ow[is.na(ow)] <- 0; old <- old + ow }   # DE4 kept Wine apart
      cmp[[length(cmp) + 1]] <- data.table(records = variant, item = it, households = nrow(mm),
        share_identical = round(mean(abs(new - old) < 0.5), 4), buyers_de4 = sum(old > 0), buyers_rebuilt = sum(new > 0),
        spend_ratio_rebuilt_to_de4 = round(sum(new) / sum(old), 4))
    }
  }
  cmp <- rbindlist(cmp)
  print(cmp)
  fwrite(cmp, file.path(logdir, "de4_comparison.csv"))
}

# --- Unit-value files read by code/legacy/*_duvm.do (both stop in the Fuera loop; Total and Hogar are written first) ---
res[["SSBRevisedPaper_Prices.R"]]      <- run("SSBRevisedPaper_Prices.R")
res[["SSBRevisedPaper_Prices_Codi.R"]] <- run("SSBRevisedPaper_Prices_Codi.R")

stamp("done")
need <- c("UnitValuePrices_Total.dta", "UnitValueGasto_Total.dta", "UnitValuePrices_Hogar.dta", "UnitValueGasto_Hogar.dta")
lines <- c(sprintf("run: %s  R %s", format(t0, "%Y-%m-%d %H:%M"), getRversion()),
           sprintf("%-32s %s", names(res), unlist(res)),
           sprintf("%-32s %s", need, ifelse(file.exists(file.path(out, need)), "written", "MISSING")))
writeLines(lines, file.path(logdir, "stage_results.txt"))
cat(lines, sep = "\n")
if (!all(file.exists(file.path(out, need)))) quit(status = 1)
