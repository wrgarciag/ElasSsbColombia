# Shared helpers: project root, configuration, logging, checks, weighted statistics.
# No execution side effects: this file only defines functions.

suppressPackageStartupMessages({
  library(data.table)
})

find_root <- function(start = getwd()) {
  p <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(p, "ElasSsbColombia.Rproj"))) return(p)
    parent <- dirname(p)
    if (identical(parent, p)) stop("Repository root (ElasSsbColombia.Rproj) not found above ", start)
    p <- parent
  }
}

load_config <- function(root) {
  cfg <- yaml::read_yaml(file.path(root, "config", "config.yml"))
  local_file <- file.path(root, "config", "local.yml")
  cfg$local <- if (file.exists(local_file)) yaml::read_yaml(local_file) else list()
  if (!is.null(cfg$local$parallel_workers)) cfg$estimation$parallel_workers <- cfg$local$parallel_workers
  cfg$root <- root
  cfg
}

p_root <- function(cfg, ...) file.path(cfg$root, ...)
p_interim <- function(cfg, ...) file.path(cfg$root, cfg$paths$interim, ...)
p_processed <- function(cfg, ...) file.path(cfg$root, cfg$paths$processed, ...)
p_meta <- function(cfg, ...) file.path(cfg$root, cfg$paths$metadata, ...)
p_out <- function(cfg, kind, run_id, ...) {
  d <- file.path(cfg$root, cfg$paths$output, kind, run_id)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  file.path(d, ...)
}

log_msg <- function(...) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M:%S"), paste0(..., collapse = "")))
  flush.console()
}

# Hard assertion with an informative message; used for merge keys and contracts.
check <- function(cond, msg) {
  if (!isTRUE(cond)) stop("CHECK FAILED: ", msg, call. = FALSE)
  invisible(TRUE)
}

assert_unique <- function(dt, keys, what) {
  n_dup <- nrow(dt) - uniqueN(dt, by = keys)
  check(n_dup == 0, sprintf("%s: %d duplicate rows on key (%s)", what, n_dup, paste(keys, collapse = ", ")))
}

# Collects named check results for the validation report instead of stopping.
new_check_log <- function() {
  e <- new.env()
  e$rows <- list()
  e
}
record_check <- function(lg, stage, name, passed, detail = "", severity = "error") {
  lg$rows[[length(lg$rows) + 1L]] <- data.table(stage = stage, check = name, passed = isTRUE(passed),
                                                severity = severity, detail = as.character(detail))
  if (!isTRUE(passed) && severity == "error") log_msg("  CHECK FAILED [", stage, "] ", name, ": ", detail)
  invisible(isTRUE(passed))
}
check_log_table <- function(lg) rbindlist(lg$rows)

sha256_file <- function(path) digest::digest(file = path, algo = "sha256")

# ---- Weighted statistics (frequency/expansion weights, as in Stata's aweight summarize) ----
w_mean <- function(x, w) {
  ok <- !is.na(x) & !is.na(w)
  if (!any(ok)) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}
w_sd <- function(x, w) {
  ok <- !is.na(x) & !is.na(w)
  n <- sum(ok)
  if (n < 2) return(NA_real_)
  m <- w_mean(x[ok], w[ok])
  sqrt(sum(w[ok] * (x[ok] - m)^2) / sum(w[ok]) * n / (n - 1))
}
w_quantile <- function(x, w, probs) {
  ok <- !is.na(x) & !is.na(w)
  x <- x[ok]; w <- w[ok]
  o <- order(x); x <- x[o]; w <- w[o]
  cw <- cumsum(w) / sum(w)
  vapply(probs, function(p) x[which(cw >= p)[1]], numeric(1))
}

# Robust outlier flag on the log scale: |log x - median| > k * 1.4826 * MAD.
flag_log_mad <- function(x, k) {
  lx <- log(x)
  med <- stats::median(lx, na.rm = TRUE)
  s <- stats::mad(lx, na.rm = TRUE)
  if (is.na(s) || s == 0) return(rep(FALSE, length(x)))
  !is.na(lx) & abs(lx - med) > k * s
}

write_csv <- function(dt, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  fwrite(dt, path, bom = FALSE)
  invisible(path)
}

git_commit <- function(root) {
  out <- tryCatch(system2("git", c("-C", shQuote(root), "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
                  error = function(e) NA_character_)
  dirty <- tryCatch(length(system2("git", c("-C", shQuote(root), "status", "--porcelain"), stdout = TRUE, stderr = FALSE)) > 0,
                    error = function(e) NA)
  list(commit = if (length(out)) out[1] else NA_character_, dirty = dirty)
}
