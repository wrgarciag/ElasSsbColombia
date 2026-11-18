# Beverage classification: versioned COICOP rules (metadata/category_map.csv) and versioned text
# rules (metadata/text_rules.csv). Functions only; no side effects.

read_category_map <- function(cfg, variant = "primary") {
  cm <- fread(p_meta(cfg, "category_map.csv"), colClasses = "character", encoding = "UTF-8")
  want <- variant
  base <- cm[cm$variant == "primary"]
  if (want != "primary") {
    alt <- cm[cm$variant == want]
    base <- rbind(base[!code_prefix %in% alt$code_prefix], alt)
  }
  base[, plen := nchar(code_prefix)]
  setorder(base, -plen)   # longest prefix wins
  base[]
}

# Longest-prefix COICOP match. Returns category, market and quantity basis for each code.
classify_coicop <- function(code, cmap) {
  out <- data.table(category = rep(NA_character_, length(code)), market = NA_character_,
                    quantity_basis = NA_character_, rule_prefix = NA_character_)
  for (i in seq_len(nrow(cmap))) {
    hit <- is.na(out$rule_prefix) & startsWith(code, cmap$code_prefix[i])
    if (any(hit, na.rm = TRUE)) {
      hit[is.na(hit)] <- FALSE
      set(out, which(hit), c("category", "market", "quantity_basis", "rule_prefix"),
          list(cmap$category[i], cmap$market[i], cmap$quantity_basis[i], cmap$code_prefix[i]))
    }
  }
  out
}

normalise_text <- function(x) {
  x <- stringi::stri_trans_general(x, "Latin-ASCII")
  x <- tolower(x)
  x <- gsub("[^a-z0-9]+", " ", x)
  trimws(gsub("\\s+", " ", x))
}

read_text_rules <- function(cfg) {
  tr <- fread(p_meta(cfg, "text_rules.csv"), colClasses = "character", encoding = "UTF-8", na.strings = NULL)
  list(version = unique(tr$rule_version),
       phrases = tr[type == "phrase", .(pattern, value)],
       tokens = setNames(tr[type == "token", value], tr[type == "token", pattern]),
       neutral = tr[type == "neutral", pattern],
       connector = tr[type == "connector", pattern])
}

# Classify free-text descriptions.
# A description identifies a beverage purchase only when, after phrase replacement, every word is
# either a token of ONE beverage category or a neutral qualifier (size, container, count, flavour).
# Descriptions that mention a beverage together with other items ("pizza y gaseosa") are flagged as
# composite: the amount paid cannot be attributed to the beverage and is not counted as beverage
# spending (the legacy rule assigned the full amount of the meal to the beverage).
# Returns a data.table: text_category, text_pure, text_mentions (any beverage token), text_composite.
classify_text <- function(text, rules) {
  ut <- unique(text[!is.na(text) & nzchar(text)])
  nt <- normalise_text(ut)
  for (i in seq_len(nrow(rules$phrases))) {
    nt <- gsub(paste0("(?<![a-z0-9])(?:", rules$phrases$pattern[i], ")(?![a-z0-9])"), rules$phrases$value[i], nt, perl = TRUE)
  }
  toks <- stringi::stri_split_fixed(nt, " ")
  long <- data.table(id = rep(seq_along(toks), lengths(toks)), tok = unlist(toks, use.names = FALSE))
  long <- long[nzchar(tok)]
  long[, cat := rules$tokens[tok]]
  long[, is_neutral := tok %chin% rules$neutral | grepl("^[0-9]+(ml|cc|l|lt|lts|oz|gr|g)?$", tok)]
  long[, is_connector := tok %chin% rules$connector]
  res <- long[, .(n_cat = uniqueN(cat[!is.na(cat)]), first_cat = cat[!is.na(cat)][1],
                  n_other = sum(is.na(cat) & !is_neutral & !is_connector), n_conn = sum(is_connector)), by = id]
  u <- data.table(text = ut, id = seq_along(ut))
  u <- merge(u, res, by = "id", all.x = TRUE)
  u[is.na(n_cat), `:=`(n_cat = 0L, n_other = 0L, n_conn = 0L)]
  u[, text_mentions := n_cat > 0]
  u[, text_pure := n_cat == 1 & n_other == 0 & n_conn == 0]
  u[, text_composite := text_mentions & !text_pure]
  u[, text_category := fifelse(text_pure, first_cat, NA_character_)]
  u[, text_mention_category := fifelse(n_cat == 1, first_cat, fifelse(n_cat > 1, "multiple", NA_character_))]
  idx <- match(text, ut)   # computed outside [.data.table, where `text` would resolve to the column
  setorder(u, id)
  out <- u[idx, .(text_category, text_pure, text_mentions, text_composite, text_mention_category)]
  out[is.na(text_mentions), `:=`(text_pure = FALSE, text_mentions = FALSE, text_composite = FALSE)]
  out[]
}
