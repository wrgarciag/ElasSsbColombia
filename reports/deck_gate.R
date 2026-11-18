#!/usr/bin/env Rscript
# deck_gate.R -- source checks, clean render and zero-warning gate for an
# R Markdown Beamer deck. Base R + rmarkdown only. Edits nothing.
#   Rscript deck_gate.R path/to/deck.Rmd            full gate (checks + render + log)
#   Rscript deck_gate.R path/to/deck.Rmd --check    source checks only, no render
#   Rscript deck_gate.R path/to/deck.Rmd --draft    allow open [VERIFY ...] markers
#   add --minutes=20 to check the slide count against the talk length
args <- commandArgs(trailingOnly = TRUE)
rmd  <- args[!startsWith(args, "--")][1]
if (is.na(rmd) || !file.exists(rmd)) stop("usage: Rscript deck_gate.R deck.Rmd [--check] [--draft]")
check_only <- "--check" %in% args
draft      <- "--draft" %in% args
minutes    <- as.numeric(sub("^--minutes=", "", grep("^--minutes=", args, value = TRUE)[1]))
rmd  <- normalizePath(rmd, winslash = "/")
dir  <- dirname(rmd)
stem <- tools::file_path_sans_ext(basename(rmd))
fails <- character(); warns <- character(); notes <- character()
FAIL <- function(...) fails <<- c(fails, paste0(...))
WARN <- function(...) warns <<- c(warns, paste0(...))
NOTE <- function(...) notes <<- c(notes, paste0(...))
cut_to <- function(x, n) ifelse(nchar(x) > n, paste0(substr(x, 1, n - 1), "~"), x)
squish <- function(x) gsub(r"(\s+)", " ", x)

# ---- read the deck -----------------------------------------------------------
src   <- readLines(rmd, warn = FALSE, encoding = "UTF-8")
ydash <- which(trimws(src) == "---")
ystop <- if (length(ydash) >= 2) ydash[2] else 0
yaml  <- src[seq_len(ystop)]
fence <- grepl(paste0(r"(^\s*)", strrep("`", 3)), src)
k     <- cumsum(fence)
in_chunk   <- (k %% 2 == 1) | fence
chunk_open <- fence & (k %% 2 == 1) & grepl(r"(\{\s*r\b)", src) & !grepl(r"(include\s*=\s*F)", src)
text <- ifelse(in_chunk, "", src)
text[seq_len(ystop)] <- ""
text <- gsub("<!--.*?-->", "", text, perl = TRUE)

yval <- function(key) {
  m <- grep(paste0(r"(^\s*)", key, r"(\s*:)"), yaml, value = TRUE)
  if (!length(m)) return(NA_character_)
  gsub(r"(^["']|["']$)", "", trimws(sub("^[^:]*:", "", m[1])))
}
if (!isTRUE(yval("citation_package") == "biblatex"))
  FAIL("YAML: output must set citation_package: biblatex")
if (!any(grepl(r"(beamer_addons\.tex)", yaml)))
  FAIL("YAML: includes: in_header must list beamer_addons.tex after the preamble")
if (!isTRUE(yval("latex_engine") == "xelatex")) WARN("YAML: latex_engine is not xelatex")
if (any(grepl(r"(^\s*(biblio-style|natbiboptions|csl)\s*:)", yaml)))
  FAIL("YAML: remove biblio-style / natbiboptions / csl; beamer_addons.tex sets APA")
if (any(grepl(r"(warning\s*=\s*(FALSE|F)\b|suppressWarnings\s*\()", src)))
  FAIL("R warnings are hidden (warning = FALSE or suppressWarnings); show and fix them")

# ---- bibliography ------------------------------------------------------------
read_bib <- function(path) {
  x  <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = " ")
  ch <- strsplit(x, "")[[1]]
  depth <- cumsum(ch == "{") - cumsum(ch == "}")
  st <- gregexpr(r"(@[A-Za-z]+\s*\{)", x)[[1]]
  out <- list()
  if (st[1] < 0) return(out)
  for (i in seq_along(st)) {
    s <- st[i]; o <- s + attr(st, "match.length")[i] - 1
    if (s > 1 && depth[s - 1] != 0) next
    type <- tolower(gsub("[@{[:space:]]", "", substr(x, s, o)))
    if (type %in% c("comment", "string", "preamble")) next
    e <- o + which(depth[(o + 1):length(depth)] == 0)[1]
    if (is.na(e)) next
    idx <- (o + 1):(e - 1)
    cm  <- idx[ch[idx] == "," & depth[idx] == 1]
    if (!length(cm)) next
    key <- trimws(paste(ch[(o + 1):(cm[1] - 1)], collapse = ""))
    b <- c(cm, e)
    f <- list()
    for (j in seq_len(length(b) - 1)) {
      if (b[j + 1] - b[j] < 2) next
      p <- paste(ch[(b[j] + 1):(b[j + 1] - 1)], collapse = "")
      m <- regmatches(p, regexec(r"(^\s*([A-Za-z_-]+)\s*=\s*(.*)$)", p))[[1]]
      if (length(m) == 3) f[[tolower(m[2])]] <- squish(gsub(r"(^[{"]|[}"]$)", "", trimws(m[3])))
    }
    out[[length(out) + 1]] <- list(key = key, type = type, f = f)
  }
  out
}
authors <- function(a) if (is.null(a)) character() else trimws(strsplit(a, r"(\s+and\s+)")[[1]])
surname <- function(n) gsub("[{}]", "", if (grepl(",", n)) trimws(sub(",.*", "", n)) else
  if (grepl(r"(^\{.*\}$)", n)) n else sub(r"(.*\s)", "", n))
addons <- if (file.exists(file.path(dir, "beamer_addons.tex")))
  readLines(file.path(dir, "beamer_addons.tex"), warn = FALSE) else character()
bibrel <- yval("bibliography")
bibpath <- if (is.na(bibrel)) NA else file.path(dir, bibrel)
bib <- list()
if (is.na(bibpath) || !file.exists(bibpath)) {
  FAIL("YAML: bibliography file not found: ", bibrel)
} else bib <- read_bib(bibpath)
bibkeys <- vapply(bib, function(e) e$key, "")
if (anyDuplicated(bibkeys)) FAIL("duplicate keys in .bib: ",
                                 paste(unique(bibkeys[duplicated(bibkeys)]), collapse = ", "))

# ---- citations ---------------------------------------------------------------
txt  <- paste(text, collapse = "\n")
cite_re <- r"(\\[A-Za-z]*cite[A-Za-z]*\*?(\[[^]]*\])*\{[^}]*\})"
lat  <- regmatches(txt, gregexpr(cite_re, txt))[[1]]
lkey <- trimws(unlist(strsplit(gsub(r"(^.*\{|\}$)", "", lat), ",")))
pan  <- regmatches(txt, gregexpr(r"((?<![\w\\.])@[A-Za-z][\w:+/-]*)", txt, perl = TRUE))[[1]]
cited <- unique(c(lkey, sub("^@", "", pan)))
cited <- cited[nzchar(cited)]
if ("*" %in% cited) FAIL("nocite{*} prints the whole library; cite only what a slide uses")
cited <- setdiff(cited, "*")
for (m in setdiff(cited, bibkeys)) FAIL("cited key not in ", basename(bibpath), ": ", m)

cat("\n== CITATION LEDGER (read each row against the source) ==\n")
ent <- bib[match(intersect(cited, bibkeys), bibkeys)]
for (e in ent) {
  f <- e$f; au <- authors(f$author)
  yr <- if (!is.null(f$year)) f$year else if (!is.null(f$date)) substr(f$date, 1, 4) else "n.d."
  cat(sprintf("  %-28s %s%s (%s). %s | %s\n", e$key,
              if (length(au)) surname(au[1]) else "[no author]",
              if (length(au) > 1) sprintf(" +%d", length(au) - 1) else "", yr,
              cut_to(if (is.null(f$title)) "[no title]" else f$title, 58),
              if (is.null(f$journal)) e$type else f$journal))
  if (is.null(f$author) && is.null(f$editor)) WARN(e$key, ": no author in .bib")
  if (is.null(f$year) && is.null(f$date)) WARN(e$key, ": no year in .bib (prints as n.d.)")
  if (is.null(f$title)) WARN(e$key, ": no title in .bib")
  if (e$type == "article" && is.null(f$journal)) WARN(e$key, ": article without journal")
  if (!is.null(f$doi) && !grepl(r"(^10\.\d{4,9}/[^\s;]+$)", f$doi, perl = TRUE) ||
      isTRUE(grepl("/ASSET/", f$doi)))
    NOTE(e$key, ": malformed DOI in .bib (trimmed at render)")
  if (isTRUE(grepl(r"(\s)", f$url))) NOTE(e$key, ": several URLs in one field (first kept at render)")
  if (any(grepl(r"((?<!\\)[%&#])", c(f$title, f$journal), perl = TRUE)))
    NOTE(e$key, ": unescaped % & # in title/journal (escaped at render)")
  if (isTRUE(grepl(r"(^(\w+)\s*-+\s*\1$)", f$pages, perl = TRUE)))
    NOTE(e$key, ": page range repeats one value (collapsed at render)")
  if (isTRUE(grepl(r"(\s\d{4}\s+\d+:\d+$)", f$journal)))
    NOTE(e$key, ": volume/issue appended to journal name (trimmed at render)")
  if (!is.null(f$title)) {
    w <- regmatches(f$title, gregexpr("[A-Za-z][A-Za-z'-]{3,}", f$title))[[1]][-1]
    if (length(w) >= 3 && mean(grepl("^[A-Z]", w)) > 0.6)
      WARN(e$key, ": title stored in Title Case; APA prints sentence case (fix in the reference manager)")
  }
  grp <- au[!grepl(",", au) & !grepl(r"(^\{.*\}$)", au) &
            grepl(r"(^[A-Z]{2,}\b|Collaborat|Group|Consortium|Committee|Countdown|Network|Organization|Team$)", au)]
  for (g in grp) {
    if (any(grepl(gsub(r"(\s+)", r"(\\s+)", g), addons, fixed = TRUE)))
      NOTE(e$key, ": group author '", g, "' (braced at render)")
    else WARN(e$key, ": author '", g, "' looks like a group name; needs {braces} or a deck-specific repair")
  }
}
jn <- unlist(lapply(bib, function(e) e$f$journal))
jnorm <- tolower(sub(r"(^the\s+)", "", jn, ignore.case = TRUE))
for (j in unique(jnorm[duplicated(jnorm)])) {
  v <- unique(jn[jnorm == j])
  if (length(v) > 1) NOTE("journal spelled inconsistently in .bib: ", paste(v, collapse = " / "))
}

# hand-typed attributions: author and year must be printed by a cite command
plain <- gsub(cite_re, " ", txt)
plain <- gsub("`r [^`]*`", " ", plain)
nm <- r"([^\s\d,;:()&\\{}]*)"
att_re <- paste0(r"(\b([A-Z][a-z])", nm, r"()((?:\s+(?:and|&)\s+[A-Z])", nm,
                 r"()?)((?:\s+et\s+al\.?)?)\\?,?\s*\(?((?:19|20)\d{2})[a-z]?\))")
att <- unique(regmatches(plain, gregexpr(att_re, plain, perl = TRUE))[[1]])
first_sn <- vapply(bib, function(e) { a <- authors(e$f$author); if (length(a)) surname(a[1]) else "" }, "")
byear <- vapply(bib, function(e) if (is.null(e$f$year)) "" else e$f$year, "")
for (a in att) {
  sn <- sub(paste0("^([A-Z][a-z]", nm, ").*$"), r"(\1)", a, perl = TRUE)
  yr <- regmatches(a, regexpr(r"((19|20)\d{2})", a))
  hit <- which(first_sn == sn & byear == yr)
  if (length(hit)) FAIL("hand-typed attribution '", squish(a), r"(': write \textcite{)", bibkeys[hit[1]], "}")
  else if (grepl(r"(et\s+al)", a)) FAIL("attribution '", squish(a), "' matches no entry in the .bib")
  else WARN("possible uncited attribution: '", squish(a), "'")
}

# ---- slides: titles and density ---------------------------------------------
h1 <- grepl(r"(^#\s+\S)", text)
h2 <- grepl(r"(^##(\s|$))", text) & !grepl("^###", text)
attr_re <- r"(\s*\{[^}]*\}\s*$)"
starts <- which(h2)
slides <- lapply(seq_along(starts), function(i) {
  a <- starts[i]; b <- if (i < length(starts)) starts[i + 1] - 1 else length(text)
  nxt <- which(h1[a:b]); if (length(nxt)) b <- a + nxt[1] - 2
  head <- sub(r"(^##\s*)", "", text[a])
  attr <- regmatches(head, regexpr(attr_re, head))
  body <- if (b > a) text[(a + 1):b] else character()
  bt <- paste(body, collapse = "\n")
  w <- paste(body[!grepl(r"(^\s*:::)", body)], collapse = "\n")
  w <- gsub(r"(\$\$[\s\S]*?\$\$|\$[^$\n]*\$)", " ", w, perl = TRUE)
  w <- gsub(cite_re, " ", w); w <- gsub("`r [^`]*`", " N ", w)
  w <- gsub(r"(\\(begin|end)\{[^}]*\}|\\[A-Za-z]+\*?(\[[^]]*\])?)", " ", w)
  sec <- sub(r"(^#\s+)", "", sub(attr_re, "", text[max(c(0, which(h1 & seq_along(h1) < a)))][1]))
  list(line = a, title = trimws(sub(attr_re, "", head)), attr = if (length(attr)) attr else "",
       sec = if (is.na(sec)) "" else sec,
       words = length(regmatches(w, gregexpr(r"(\S*[A-Za-z]\S*)", w))[[1]]),
       bullets = sum(grepl(r"(^\s*([-*+]|\d+\.)\s|\\item\b)", body)),
       visuals = sum(chunk_open[a:b]) + sum(grepl(r"(\\includegraphics|!\[)", body)),
       eqs = lengths(regmatches(bt, gregexpr(r"(\$\$)", bt))) %/% 2 +
         sum(grepl(r"(\\begin\{(equation|align))", body)),
       boxes = sum(grepl(r"(\\begin\{(block|alertblock|exampleblock|uncertaintyblock)\})", body)),
       sourced = any(grepl(r"(<!--\s*src:)", src[a:b])),
       first = squish(paste(body[nzchar(trimws(body))], collapse = " ")),
       stats = regmatches(w, gregexpr(r"(\d+(\.\d+)?\s*\\?%|\b\d+\.\d+\b|\b\d{1,3}(,\d{3})+\b)", w))[[1]])
})
is_close <- vapply(slides, function(s) grepl("standout", s$attr), NA)
is_bk <- vapply(slides, function(s) grepl("^(appendix|backup)", s$sec, ignore.case = TRUE), NA)
n_main <- min(c(which(is_close), which(is_bk) - 1, length(slides)))
secs <- unique(vapply(slides[seq_len(n_main)], function(s) s$sec, ""))
if (length(secs) > 5) WARN(length(secs), " section dividers in the main deck; three or four acts are enough")
label_re <- paste0("^(introduction|background|motivation|overview|outline|agenda|roadmap|aims?|objectives?|",
  "research questions?|data|data (sources?|overview)|methods?|methodology|approach|results?|findings|",
  "key findings|main results|discussion|interpretation|limitations?|conclusions?|summary|next steps|",
  "future work|planned extensions|recommendations|implications|contributions?|what is new|",
  "literature( review)?|references|questions|thank you|thanks|appendix)$|",
  r"(^(results?|methods?|discussion|limitations?|appendix|summary)\s*[:-])")
if (!any(is_close)) FAIL("no closing slide: end the main deck with  ## {.standout}  and the one sentence")
cat("\n== STORYBOARD (the titles alone must carry the argument) ==\n")
for (i in seq_along(slides)) {
  s <- slides[[i]]; main <- i <= n_main
  if (nzchar(s$sec) && (i == 1 || s$sec != slides[[i - 1]]$sec)) cat("     --", s$sec, "--\n")
  tag <- if (is_close[i]) "CLOSE " else if (main) sprintf("%5d ", i) else "  bk  "
  cat(tag, if (nzchar(s$title)) s$title else cut_to(s$first, 110), "\n")
  if (!main || is_close[i]) next
  where <- sprintf("slide %d (line %d) '%s': ", i, s$line, cut_to(s$title, 40))
  bare <- tolower(trimws(gsub("[?!.]+$", "", s$title)))
  nw <- length(strsplit(bare, r"(\s+)")[[1]])
  if (!nzchar(bare)) FAIL(where, "no title")
  else if (grepl(label_re, bare) || nw <= 2) FAIL(where, "title is a label; state the claim")
  if (nchar(s$title) > 78) WARN(where, "title over 78 characters; it will wrap")
  if (s$words > 40) WARN(where, s$words, " words on the slide; cut or split")
  if (s$bullets > 4) WARN(where, s$bullets, " bullets; find the structure or split")
  if (s$visuals > 1) WARN(where, s$visuals, " figures/tables; one per slide")
  if (s$visuals >= 1 && s$bullets >= 3) WARN(where, "figure or table plus a bullet list")
  if (s$eqs > 1) WARN(where, s$eqs, " displayed equations; one per step")
  if (s$boxes > 1) WARN(where, s$boxes, " callout boxes; one at most")
  if (length(s$stats) && !s$sourced)
    WARN(where, "typed statistic(s) ", paste(unique(trimws(s$stats)), collapse = ", "),
         "; use inline R, or verify in the source and record  <!-- src: key, page -->")
}
mw <- vapply(slides[seq_len(n_main)], function(s) s$words, 0)
n_content <- n_main - any(is_close)
cat(sprintf("\n  content slides: %d (plus title%s)   words per slide: median %g, max %g\n", n_content,
            if (any(is_close)) " and closing" else "", stats::median(mw), max(mw, 0)))
if (!is.na(minutes) && n_content > minutes)
  WARN(n_content, " content slides for a ", minutes, "-minute talk; plan about one per minute")
open <- grep(r"(\[(VERIFY|CITATION NEEDED|TODO))", src)
if (length(open)) (if (draft) WARN else FAIL)(
  length(open), " open marker(s) [VERIFY/CITATION NEEDED/TODO] at line(s) ", paste(open, collapse = ", "))

report <- function() {
  if (length(notes)) cat("\n== BIB NOTES (handled at render; fix at the source when convenient) ==\n",
                         paste0("  - ", notes, "\n"), sep = "")
  if (length(warns)) cat("\n== REVIEW (resolve or justify each) ==\n", paste0("  - ", warns, "\n"), sep = "")
  if (length(fails)) cat("\n== FAIL ==\n", paste0("  x ", fails, "\n"), sep = "")
  cat(sprintf("\nGATE %s: %d failure(s), %d review item(s)\n",
              if (length(fails)) "FAILED" else "PASSED", length(fails), length(warns)))
  quit(status = if (length(fails)) 1 else 0, save = "no")
}
if (check_only || length(fails)) report()

# ---- clean render ------------------------------------------------------------
if (!nzchar(Sys.which("biber"))) {
  FAIL("biber not found; with TinyTeX run tinytex::tlmgr_install(c('biber','biblatex','biblatex-apa'))")
  report()
}
p   <- function(ext) file.path(dir, paste0(stem, ".", ext))
aux <- c("aux", "bbl", "bcf", "blg", "log", "nav", "snm", "toc", "out", "run.xml", "vrb", "tex")
unlink(p(aux))
options(tinytex.clean = FALSE)
rw <- character()
withCallingHandlers(
  tryCatch(rmarkdown::render(rmd, quiet = TRUE, envir = new.env(),
                             output_options = list(keep_tex = TRUE, pandoc_args = "--fail-if-warnings")),
           error = function(e) FAIL("render stopped: ", conditionMessage(e))),
  warning = function(w) { rw <<- c(rw, conditionMessage(w)); invokeRestart("muffleWarning") })
rd <- function(ext) if (file.exists(p(ext))) readLines(p(ext), warn = FALSE) else character()
g  <- function(re, x) grep(re, x, value = TRUE, useBytes = TRUE)
log <- rd("log"); blg <- rd("blg"); tex <- rd("tex"); bbl <- rd("bbl")
wre <- r"(^(LaTeX( Font)? Warning|(Package|Class|Module) \S+ Warning|pdfTeX warning))"
counts <- c(
  "LaTeX errors"         = length(g("^!", log)),
  "overfull/underfull"   = length(g(r"(^(Over|Under)full \\[hv]box)", log)),
  "LaTeX warnings"       = length(g(wre, log)),
  "missing characters"   = length(g("^Missing character", log)),
  "biber warnings"       = length(g("WARN|ERROR", blg)),
  "R warnings in slides" = length(g(r"(^(## |\\#\\# )(Warning|Error))", tex)),
  "R/pandoc warnings"    = length(rw))
cat("\n== COMPILE ==\n"); for (n in names(counts)) cat(sprintf("  %-22s %d\n", n, counts[[n]]))
if (!length(log)) FAIL("no LaTeX log produced")
for (n in names(counts)[counts > 0]) FAIL(counts[[n]], " ", n)
show <- c(g(paste0("^!|^(Over|Under)full|^Missing character|", wre), log), g("WARN|ERROR", blg), rw)
if (length(show)) cat(paste0("    ", utils::head(show, 25), "\n"), sep = "")
inbbl <- unique(sub(r"(^\s*\\entry\{([^}]*)\}.*$)", r"(\1)", g(r"(^\s*\\entry\{)", bbl)))
for (m in setdiff(cited, inbbl)) FAIL("cited but absent from the reference list: ", m)
for (m in setdiff(inbbl, cited)) WARN("in the reference list but not cited in slide text: ", m)
pg <- sub(r"(.*\((\d+) pages?.*)", r"(\1)", g("^Output written on", log))
cat(sprintf("  pages: %s   references: %d\n", if (length(pg)) pg[1] else "?", length(inbbl)))
if (!length(fails)) { unlink(p(aux)); unlink(file.path(dir, paste0(stem, "_files")), recursive = TRUE) }
report()
