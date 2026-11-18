# LaTeX table helpers (booktabs + threeparttable). Functions only.

tex_escape <- function(x) {
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("([&%$#_{}])", "\\\\\\1", x)
  x <- gsub("~", "\\\\textasciitilde{}", x)
  gsub("\\^", "\\\\textasciicircum{}", x)
}

fmt_num <- function(x, digits = 3) ifelse(is.na(x), "", formatC(x, format = "f", digits = digits, big.mark = ","))
fmt_int <- function(x) ifelse(is.na(x), "", formatC(round(x), format = "d", big.mark = ","))

# Significance marks from the unrounded estimate and its bootstrap SE (two-sided normal p-value).
sig_stars <- function(p) ifelse(is.na(p), "", ifelse(p < 0.01, "**", ifelse(p < 0.05, "*", "")))

fmt_est <- function(est, p = NA, digits = 3) {
  ifelse(is.na(est), "n.e.", paste0(sub("^-", "$-$", formatC(est, format = "f", digits = digits)),
                                    ifelse(sig_stars(p) == "", "", paste0("\\textsuperscript{", sig_stars(p), "}"))))
}
fmt_se <- function(se, digits = 3) ifelse(is.na(se), "", paste0("[", formatC(se, format = "f", digits = digits), "]"))
fmt_ci <- function(lo, hi, digits = 3) ifelse(is.na(lo), "", paste0("(", sub("^-", "$-$", formatC(lo, format = "f", digits = digits)), ", ",
                                                                   sub("^-", "$-$", formatC(hi, format = "f", digits = digits)), ")"))

tex_row <- function(...) paste0(paste(c(...), collapse = " & "), " \\\\")
tex_panel <- function(title, ncol) paste0("\\addlinespace\\multicolumn{", ncol, "}{l}{\\textit{", title, "}} \\\\")

# body: character vector of complete LaTeX rows (use tex_row / tex_panel / "\\midrule").
latex_table <- function(caption, label, align, header, body, notes = NULL, size = "\\small", landscape = FALSE,
                        placement = "!htbp") {
  out <- c(
    if (landscape) "\\begin{landscape}",
    paste0("\\begin{table}[", placement, "]"), "\\centering", "\\begin{threeparttable}",
    paste0("\\caption{", caption, "}"), paste0("\\label{", label, "}"), size,
    paste0("\\begin{tabular}{", align, "}"), "\\toprule", header, "\\midrule", body, "\\bottomrule", "\\end{tabular}",
    if (length(notes)) c("\\begin{tablenotes}[flushleft]", "\\footnotesize", paste0("\\item ", notes), "\\end{tablenotes}"),
    "\\end{threeparttable}", "\\end{table}",
    if (landscape) "\\end{landscape}")
  out
}

write_tex <- function(lines, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, open = "wb"); on.exit(close(con))
  writeLines(enc2utf8(lines), con, useBytes = TRUE)
  invisible(path)
}
