# Runs the UNMODIFIED legacy R stages into a scratch folder to test reproducibility.
# Shims (no edits to legacy files): parameters copied from M0SSBElasticity.R (minus fonts/rm/setwd),
# paths pointed at the repo inputs, the nomenclature CSV redirected, DE4/DE5 copied to the scratch output folder.
t0 <- Sys.time(); stamp <- function(x) cat(sprintf("\n### [%s] %s\n", format(round(difftime(Sys.time(), t0, units = "mins"), 1)), x))
root   <- "C:/Users/wrgar/OneDrive - UW/02Work/Miscellaneous/ssb-colombia/ElasSsbColombia"
legacy <- file.path(root, "code/legacy")
S      <- "C:/Users/wrgar/AppData/Local/Temp/claude/b23658276da87ad8/710aa0c7-f7c9-49cb-997a-5f1cdd64596c/scratchpad/legacy_run"
dir.create(file.path(S, "out"), recursive = TRUE, showWarnings = FALSE)
suppressPackageStartupMessages({
  library(data.table); library(foreign); library(readstata13); library(ggplot2); library(Hmisc); library(survey)
  library(dplyr); library(magrittr); library(tidyr); library(fixest); library(fastDummies); library(mice); library(haven)
})
options(dplyr.summarise.inform = FALSE)
cat("Package versions:\n"); for (p in c("data.table","foreign","readstata13","dplyr","tidyr","fixest","fastDummies","mice","haven","survey"))
  cat(" ", p, as.character(packageVersion(p)), "\n")

# --- parameters exactly as M0SSBElasticity.R l.48-91 ---
wd_code <- paste0(legacy, "/"); wdd_in <- paste0(root, "/data-raw/enph/"); wdd_out <- paste0(S, "/out/")
wd_resu <- paste0(S, "/resu/"); wdr_gra <- paste0(S, "/graf/")
prural <- TRUE; psample <- FALSE; pstata <- FALSE
v.precio <- 2258; pqlitro <- 1; pqlitSSB <- 1; pglitSSB <- 2500; pqlitMD <- 0.5; pqlitHot <- 0.35
pqlitBeer <- 1; pglitBeer <- 5000; pqlitWa <- 1; pglitWa <- 1000; pqlitSpi <- 1; pglitSpi <- 10000; pqlitWi <- 1; pglitWi <- 28000

# --- shims ---
file.copy(file.path(root, "data/processed/DataEstimates4.dta"), file.path(wdd_out, "DataEstimates4.dta"), overwrite = TRUE)
file.copy(file.path(root, "data/processed/DataEstimates5 (2).dta"), file.path(wdd_out, "DataEstimates5.dta"), overwrite = TRUE)
.fread0 <- data.table::fread
fread <- function(file, ...) { if (!missing(file) && grepl("NomenclaturaCoicop", file)) file <- file.path(root, "data/interim/NomenclaturaCoicopDaneEnph.csv"); .fread0(file, ...) }

# Encoding shim: R >= 4.2 on Windows runs in UTF-8; ENPH free text is CP1252. Reproduces a CP1252 session's strings.
.rs0 <- foreign::read.spss
read.spss <- function(file, ...) .rs0(file, ..., reencode = "CP1252")

run <- function(f) { stamp(paste("source", f)); r <- tryCatch({ sink(file.path(S, paste0(f, ".console.txt"))); source(file.path(legacy, f), local = FALSE); "ok" },
  error = function(e) paste("ERROR:", conditionMessage(e)), finally = sink()); cat("   ->", r, "\n"); r }

stopifnot(run("fclasicoicop.R") == "ok")
r1 <- run("SSBDInput.R")
r2 <- run("SSBEConsuBasesUrbano.R")
r3 <- run("SSBEConsuBasesRural.R")

# --- Compare rebuilt spending with DataEstimates4 (mimic SSBConsuGasCorrected.R l.626-680) ---
stamp("compare with DataEstimates4")
d4 <- as.data.table(read_dta(file.path(root, "data/processed/DataEstimates4.dta")))
tot <- as.data.table(rbind(readRDS(file.path(wdd_out, "DtConsuUrbanoTotal.rds")), readRDS(file.path(wdd_out, "DtConsuRuralTotal.rds")), fill = TRUE))
cat("total_2 rows:", nrow(tot), " items:", paste(sort(unique(tot$Item)), collapse = ","), "\n")
g <- tot[, .(gastomes = sum(GastoMes)), by = .(DIRECTORIO, Item, Texto)][!is.na(gastomes)][DIRECTORIO %in% d4$DIRECTORIO]
for (variant in c("all", "codi", "texto")) {
  gg <- switch(variant, all = g, codi = g[Texto == 0], texto = g[Texto == 1])
  w <- dcast(gg[, .(v = sum(gastomes)), by = .(DIRECTORIO, Item)], DIRECTORIO ~ Item, value.var = "v", fill = 0)
  pref <- switch(variant, all = "Gasto_", codi = "GastoCodi_", texto = "GastoTexto_")
  mm <- merge(d4[, c("DIRECTORIO", grep(paste0("^", pref), names(d4), value = TRUE)), with = FALSE], w, by = "DIRECTORIO", all.x = TRUE)
  for (it in c("SSB", "Beer", "Water", "MilkDerivatives", "HotDrinks", "Spirits")) {
    new <- mm[[it]]; new[is.na(new)] <- 0
    old <- mm[[paste0(pref, it)]]; old[is.na(old)] <- 0
    if (it == "Spirits" && paste0(pref, "Wine") %in% names(mm)) { ow <- mm[[paste0(pref, "Wine")]]; ow[is.na(ow)] <- 0; old <- old + ow }
    cat(sprintf("  %-6s %-16s households=%d exact(|diff|<0.5)=%.4f  purchasers old/new=%d/%d  sum old/new=%.4f\n", variant, it,
                nrow(mm), mean(abs(new - old) < 0.5), sum(old > 0), sum(new > 0), sum(new) / sum(old)))
  }
}

# --- Unit-value files exactly as the paper's duvm do-files expect ---
r4 <- if (r2 == "ok" && r3 == "ok") run("SSBRevisedPaper_Prices.R") else "skipped"
r5 <- if (r2 == "ok" && r3 == "ok") run("SSBRevisedPaper_Prices_Codi.R") else "skipped"
stamp("files written"); print(list.files(wdd_out))
cat("\nStage results:", r1, "|", r2, "|", r3, "|", r4, "|", r5, "\n")
