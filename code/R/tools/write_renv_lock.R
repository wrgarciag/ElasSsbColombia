# Writes renv.lock (renv lockfile format, version 1) from the packages installed on this machine,
# WITHOUT installing renv or any other package. It records the pipeline's packages and their recursive
# dependencies so that `renv::restore()` can rebuild the library elsewhere.
#
# Usage (repository root):  Rscript code/R/tools/write_renv_lock.R

args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", args[grep("^--file=", args)])
root <- normalizePath(file.path(dirname(script), "..", "..", ".."), winslash = "/")
source(file.path(root, "code", "R", "lib", "utils.R"))
source(file.path(root, "code", "R", "lib", "manifest.R"))

ip <- installed.packages()
direct <- c(pipeline_packages(), "pdftools")
missing <- setdiff(direct, rownames(ip))
if (length(missing)) stop("pipeline packages not installed: ", paste(missing, collapse = ", "))
deps <- unique(unlist(tools::package_dependencies(direct, db = ip, which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE)))
all_pk <- sort(unique(c(direct, deps)))
base_pk <- rownames(ip)[!is.na(ip[, "Priority"]) & ip[, "Priority"] == "base"]
all_pk <- setdiff(intersect(all_pk, rownames(ip)), base_pk)

pk <- lapply(all_pk, function(p) {
  d <- utils::packageDescription(p)
  x <- list(Package = p, Version = d$Version, Source = "Repository",
            Repository = if (!is.null(d$Repository)) d$Repository else "CRAN")
  req <- setdiff(unique(unlist(tools::package_dependencies(p, db = ip, which = c("Depends", "Imports", "LinkingTo")))), base_pk)
  if (length(req)) x$Requirements <- as.list(sort(req))
  x
})
names(pk) <- all_pk
lock <- list(
  R = list(Version = paste(R.version$major, R.version$minor, sep = "."),
           Repositories = list(list(Name = "CRAN", URL = "https://cloud.r-project.org"))),
  Packages = pk)
jsonlite::write_json(lock, file.path(root, "renv.lock"), auto_unbox = TRUE, pretty = TRUE)
cat("renv.lock written:", length(pk), "packages; R", lock$R$Version, "\n")
