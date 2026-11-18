# Stage 07: render manuscript/manuscript.Rmd -> LaTeX -> PDF from the manuscript bundle of one run.
#
# Standalone equivalent (from the repository root, with pandoc on the PATH or RSTUDIO_PANDOC set):
#   Rscript -e "rmarkdown::render('manuscript/manuscript.Rmd', params = list(run_id = 'RUN_ID'), output_dir = 'output/manuscript/RUN_ID')"
#
# The manuscript reads data/processed/manuscript/<run_id>/ and output/{tables,figures}/<run_id>/ only.
# It stops if the bundle is missing, belongs to another run, was built with a different configuration,
# or is incomplete (unless allow_incomplete = TRUE is passed deliberately).
# Output: output/manuscript/<run_id>/manuscript.pdf and manuscript.tex; the R log of the render is
# output/logs/<run_id>/r_manuscript.log; LaTeX scratch files stay in manuscript/_render/ (git-ignored).

run_render_manuscript <- function(cfg, run_id, allow_incomplete = identical(Sys.getenv("ALLOW_INCOMPLETE"), "1")) {
  if (!rmarkdown::pandoc_available()) {
    pd <- cfg$local$pandoc_dir
    check(!is.null(pd) && dir.exists(pd), "pandoc not found: set pandoc_dir in config/local.yml")
    Sys.setenv(RSTUDIO_PANDOC = pd)
    rmarkdown::find_pandoc(cache = FALSE, dir = pd)
  }
  check(rmarkdown::pandoc_available(), "pandoc is not available")
  tb <- dirname(Sys.which("pdflatex"))
  if (!nzchar(tb)) {
    tt <- tryCatch(tinytex::tinytex_root(), error = function(e) "")
    cand <- file.path(tt, "bin", "windows")
    if (dir.exists(cand)) Sys.setenv(PATH = paste(cand, Sys.getenv("PATH"), sep = .Platform$path.sep))
  }
  check(nzchar(Sys.which("pdflatex")), "pdflatex not found (TinyTeX or another LaTeX distribution is required)")

  out_dir <- p_out(cfg, "manuscript", run_id, "")
  rmd <- p_root(cfg, "manuscript", "manuscript.Rmd")
  check(file.exists(rmd), "manuscript/manuscript.Rmd not found")
  # tinytex must not install LaTeX packages silently: missing packages are an error to be resolved by the user
  options(tinytex.install_packages = FALSE)
  res <- rmarkdown::render(rmd, output_format = "pdf_document", output_file = "manuscript.pdf", output_dir = out_dir,
                           params = list(run_id = run_id, allow_incomplete = allow_incomplete),
                           envir = new.env(parent = globalenv()), quiet = FALSE, clean = TRUE)
  pdf <- file.path(out_dir, "manuscript.pdf")
  check(file.exists(pdf), "manuscript PDF was not produced")
  info <- list(run_id = run_id, pdf = sub(paste0(cfg$root, "/"), "", normalizePath(pdf, winslash = "/"), fixed = TRUE),
               pdf_sha256 = sha256_file(pdf), pages = tryCatch(pdftools::pdf_info(pdf)$pages, error = function(e) NA),
               rendered = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), allow_incomplete = allow_incomplete,
               rmarkdown = as.character(packageVersion("rmarkdown")), pandoc = as.character(rmarkdown::pandoc_version()))
  jsonlite::write_json(info, file.path(out_dir, "render_info.json"), auto_unbox = TRUE, pretty = TRUE)
  log_msg("Manuscript rendered: ", pdf, " (", info$pages, " pages)")
  invisible(pdf)
}
