# R driver for the beverage-elasticity pipeline.
#
# Usage (from any directory):
#   Rscript code/R/00_run.R <stage> [--run-id=<id>]
#
# Stages
#   load         01_load        input inventory, typed ENPH import
#   households   02_households demographics, design variables, income, total expenditure
#   consumption  03_consumption harmonised and classified purchase records
#   prices       04_prices      household aggregates, unit values, price clusters, Stata exports
#   validate     05_validate    checks, Tables 1-2, sample flow, diagnostics
#   construct    all of the above, in order (everything that precedes Stata)
#   report       06_report      collect Stata estimates, Tables 3-6, figures, manuscript bundle
#   manuscript   07_manuscript  render manuscript/manuscript.Rmd to output/manuscript/<run_id>/
#
# R never estimates the demand system: Stata (code/stata/00_master.do) does, between `construct` and `report`.

args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", args[grep("^--file=", args)])
script_dir <- if (length(script)) dirname(normalizePath(script, winslash = "/")) else file.path(getwd(), "code", "R")
targs <- commandArgs(trailingOnly = TRUE)
stage <- if (length(targs) && !grepl("^--", targs[1])) targs[1] else "construct"
run_id <- sub("^--run-id=", "", targs[grep("^--run-id=", targs)])
if (!length(run_id)) run_id <- Sys.getenv("RUN_ID", unset = "")
if (!nzchar(run_id)) run_id <- format(Sys.time(), "%Y%m%d-%H%M")

options(warn = 1, stringsAsFactors = FALSE, scipen = 999, datatable.print.class = FALSE)

for (f in list.files(file.path(script_dir, "lib"), pattern = "[.]R$", full.names = TRUE)) source(f, encoding = "UTF-8")
root <- find_root(script_dir)
cfg <- load_config(root)
set.seed(cfg$seeds$r_master)

stage_dirs <- c(load = "01_load", households = "02_households", consumption = "03_consumption",
                prices = "04_prices", validate = "05_validate", report = "06_report", manuscript = "07_manuscript")
stage_fun <- list(
  load        = function() { run_inventory(cfg, run_id); run_import(cfg, run_id) },
  households  = function() { run_households(cfg, run_id); run_income_expenditure(cfg, run_id) },
  consumption = function() { run_harmonize(cfg, run_id); run_classify_quantify(cfg, run_id) },
  prices      = function() { run_aggregate(cfg, run_id); run_price_clusters(cfg, run_id); run_export_stata(cfg, run_id) },
  validate    = function() { run_checks(cfg, run_id); run_descriptives(cfg, run_id) },
  report      = function() { run_collect_estimates(cfg, run_id); run_tables(cfg, run_id); run_figures(cfg, run_id)
                             run_bundle(cfg, run_id); run_completeness(cfg, run_id) },
  manuscript  = function() { run_render_manuscript(cfg, run_id) }
)
todo <- if (stage == "construct") c("load", "households", "consumption", "prices", "validate") else stage
if (!all(todo %in% names(stage_fun))) stop("Unknown stage: ", stage)

log_dir <- file.path(root, cfg$paths$output, "logs", run_id)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
log_file <- file(file.path(log_dir, sprintf("r_%s.log", stage)), open = "wt", encoding = "UTF-8")
sink(log_file, split = TRUE); sink(log_file, type = "message")
on_exit <- function() { sink(type = "message"); sink(); close(log_file) }

ok <- tryCatch({
  log_msg("Run ", run_id, " | stage ", stage, " | root ", root)
  for (s in todo) {
    for (f in list.files(file.path(script_dir, stage_dirs[[s]]), pattern = "[.]R$", full.names = TRUE)) source(f, encoding = "UTF-8")
    t0 <- Sys.time()
    log_msg("=== Stage: ", s, " ===")
    stage_fun[[s]]()
    log_msg("=== Stage ", s, " done in ", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " min ===")
  }
  write_run_manifest(cfg, run_id, stage)
  TRUE
}, error = function(e) {
  log_msg("ERROR: ", conditionMessage(e))
  FALSE
})
on_exit()
if (!ok) quit(save = "no", status = 1)
