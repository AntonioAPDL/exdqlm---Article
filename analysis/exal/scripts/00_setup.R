`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

if (!exists("repo_root")) {
  stop("repo_root is not defined. Run via analysis/run_all.R.", call. = FALSE)
}

required_pkgs <- c("ggplot2", "yaml")
for (p in required_pkgs) {
  if (!requireNamespace(p, quietly = TRUE)) {
    stop(sprintf("Package '%s' is required.", p), call. = FALSE)
  }
}

suppressPackageStartupMessages({
  library(ggplot2)
})

log_msg <- function(msg) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), msg))
}

analysis_root <- file.path(repo_root, "analysis")
stage_root <- file.path(analysis_root, "exal")
output_root <- file.path(stage_root, "outputs")
figures_dir <- file.path(output_root, "figures")
tables_dir <- file.path(output_root, "tables")
logs_dir <- file.path(output_root, "logs")

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
}

for (d in c(figures_dir, tables_dir, logs_dir)) ensure_dir(d)

cfg_params <- yaml::read_yaml(file.path(analysis_root, "config", "params_exal.yml"))
cfg_style <- yaml::read_yaml(file.path(analysis_root, "config", "style.yml"))

seed_value <- seed_override %||% cfg_params$seed
set.seed(seed_value)

resolve_pkg_path <- function() {
  cand <- unique(c(
    pkg_path,
    file.path(dirname(repo_root), "exdqlm__wt__0.3.0-cpp"),
    "/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp"
  ))
  cand <- cand[!is.na(cand) & nzchar(cand)]
  cand <- cand[dir.exists(cand)]
  if (length(cand) == 0L) return(NULL)
  cand[[1]]
}

load_exdqlm <- function() {
  if (requireNamespace("exdqlm", quietly = TRUE)) {
    suppressPackageStartupMessages(library(exdqlm))
    log_msg(sprintf("Loaded installed exdqlm: %s", as.character(utils::packageVersion("exdqlm"))))
    return(invisible(TRUE))
  }

  path <- resolve_pkg_path()
  if (is.null(path)) {
    stop("exdqlm package not installed and no valid local package path found.", call. = FALSE)
  }
  if (!requireNamespace("devtools", quietly = TRUE)) {
    stop("devtools is required to load local exdqlm package source.", call. = FALSE)
  }

  devtools::load_all(path = path, quiet = TRUE, export_all = FALSE, helpers = FALSE)
  log_msg(sprintf("Loaded local exdqlm from source: %s", path))
  invisible(TRUE)
}

load_exdqlm()

if (!"exdqlm" %in% loadedNamespaces()) {
  stop("exdqlm namespace is not loaded.", call. = FALSE)
}

required_fns <- c("dexal", "pexal", "qexal", "rexal", "get_gamma_bounds")
missing_fns <- required_fns[!vapply(required_fns, function(f) {
  exists(f, where = asNamespace("exdqlm"), mode = "function", inherits = FALSE)
}, logical(1))]
if (length(missing_fns) > 0L) {
  stop(sprintf("Missing required exdqlm functions: %s", paste(missing_fns, collapse = ", ")), call. = FALSE)
}

exal_theme <- function() {
  theme_minimal(base_size = cfg_style$fig$base_size) +
    theme(
      plot.title = element_text(face = "bold", hjust = 0.5),
      plot.subtitle = element_text(hjust = 0.5),
      legend.position = "top",
      panel.grid.minor = element_blank(),
      axis.title = element_text(face = "bold")
    )
}

figure_registry <- data.frame(
  file = character(),
  description = character(),
  section = character(),
  main_text_candidate = logical(),
  stringsAsFactors = FALSE
)

table_registry <- data.frame(
  file = character(),
  description = character(),
  stringsAsFactors = FALSE
)

register_figure <- function(file, description, section = "exAL", main_text_candidate = FALSE) {
  figure_registry <<- rbind(
    figure_registry,
    data.frame(
      file = file,
      description = description,
      section = section,
      main_text_candidate = as.logical(main_text_candidate),
      stringsAsFactors = FALSE
    )
  )
}

register_table <- function(file, description) {
  table_registry <<- rbind(
    table_registry,
    data.frame(file = file, description = description, stringsAsFactors = FALSE)
  )
}

save_plot_file <- function(plot_obj, filename, description, section = "exAL", main_text_candidate = FALSE) {
  path <- file.path(figures_dir, filename)
  ggplot2::ggsave(
    filename = path,
    plot = plot_obj,
    width = cfg_style$fig$width,
    height = cfg_style$fig$height,
    dpi = cfg_style$fig$dpi,
    bg = cfg_style$fig$bg
  )
  register_figure(filename, description, section, main_text_candidate)
  invisible(path)
}

save_table_file <- function(df, filename, description) {
  path <- file.path(tables_dir, filename)
  utils::write.csv(df, file = path, row.names = FALSE)
  register_table(filename, description)
  invisible(path)
}

resolve_case_gamma <- function(case) {
  p0 <- as.numeric(case$p0)
  bounds <- exdqlm::get_gamma_bounds(p0)
  L <- as.numeric(bounds[["L"]])
  U <- as.numeric(bounds[["U"]])
  eps <- 1e-6

  if (!is.null(case$gamma)) {
    g <- as.numeric(case$gamma)
  } else if (!is.null(case$gamma_fraction_positive)) {
    g <- as.numeric(case$gamma_fraction_positive) * U
  } else if (!is.null(case$gamma_fraction_negative)) {
    g <- as.numeric(case$gamma_fraction_negative) * L
  } else {
    stop("Case does not define gamma or gamma fraction.", call. = FALSE)
  }

  g <- min(max(g, L + eps), U - eps)
  g
}

gamma_triplet <- function(p0, frac_neg, frac_pos) {
  b <- exdqlm::get_gamma_bounds(p0)
  L <- as.numeric(b[["L"]])
  U <- as.numeric(b[["U"]])
  eps <- 1e-6

  g_neg <- max(frac_neg * L, L + eps)
  g_pos <- min(frac_pos * U, U - eps)
  c(g_neg = g_neg, g_zero = 0.0, g_pos = g_pos)
}

write_session_info <- function() {
  ensure_dir(logs_dir)
  sink(file.path(logs_dir, "sessionInfo.txt"))
  on.exit(sink(), add = TRUE)
  cat(sprintf("Seed: %s\n", seed_value))
  cat(sprintf("Date: %s\n\n", as.character(Sys.time())))
  print(sessionInfo())
}

promote_publication_figures <- function() {
  promote <- cfg_params$promotion$figures
  if (length(promote) == 0L) {
    log_msg("No promotion list found in config.")
    return(invisible(NULL))
  }

  target_dir <- file.path(repo_root, "Figures")
  ensure_dir(target_dir)

  for (f in promote) {
    src <- file.path(figures_dir, f)
    dst <- file.path(target_dir, f)
    if (!file.exists(src)) {
      stop(sprintf("Promotion source figure missing: %s", src), call. = FALSE)
    }
    ok <- file.copy(src, dst, overwrite = TRUE)
    if (!ok) stop(sprintf("Failed to copy %s to Figures/", f), call. = FALSE)
  }

  log_msg(sprintf("Promoted %d figure(s) to Figures/", length(promote)))
}

palette_vals <- c(
  cfg_style$palette$primary,
  cfg_style$palette$secondary,
  cfg_style$palette$tertiary,
  cfg_style$palette$quaternary,
  cfg_style$palette$neutral
)

log_msg("00_setup complete")
