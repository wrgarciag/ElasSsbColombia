# Run manifest: software versions, configuration hash, input checksums, git state, seeds.
# One JSON per stage call under output/logs/<run_id>/; the report stage merges them into the bundle manifest.

pipeline_packages <- function() c("data.table", "haven", "yaml", "digest", "jsonlite", "stringi",
                                  "ggplot2", "knitr", "rmarkdown", "kableExtra", "bookdown", "tinytex")

write_run_manifest <- function(cfg, run_id, stage) {
  pk <- pipeline_packages()
  ip <- installed.packages()[, "Version"]
  g <- git_commit(cfg$root)
  man_file <- p_meta(cfg, "input_manifest.csv")
  m <- list(
    run_id = run_id, stage = stage, timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    r_version = R.version.string, platform = R.version$platform,
    packages = as.list(ip[intersect(pk, names(ip))]),
    git_commit = g$commit, git_dirty = g$dirty,
    config_sha256 = sha256_file(p_root(cfg, "config", "config.yml")),
    models_sha256 = if (file.exists(p_root(cfg, "config", "models.csv"))) sha256_file(p_root(cfg, "config", "models.csv")) else NA,
    input_manifest_sha256 = if (file.exists(man_file)) sha256_file(man_file) else NA,
    seeds = cfg$seeds
  )
  jsonlite::write_json(m, p_out(cfg, "logs", run_id, sprintf("manifest_r_%s.json", stage)), auto_unbox = TRUE, pretty = TRUE)
  invisible(m)
}
