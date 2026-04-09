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
  env_pkg_path <- Sys.getenv("EXDQLM_PKG_PATH", unset = "")
  env_pkg_path <- if (nzchar(env_pkg_path)) env_pkg_path else NULL
  default_pkg_path <- "/home/jaguir26/local/src/exdqlm__wt__0p4p0_article_main"

  selected_path <- pkg_path %||% env_pkg_path %||% default_pkg_path
  selected_source <- if (!is.null(pkg_path) && nzchar(pkg_path)) {
    "--pkg-path"
  } else if (!is.null(env_pkg_path)) {
    "EXDQLM_PKG_PATH"
  } else {
    "default"
  }

  list(
    path = normalizePath(selected_path, winslash = "/", mustWork = FALSE),
    source = selected_source
  )
}

resolve_load_spec <- function() {
  load_mode <- tolower(trimws(Sys.getenv("EXDQLM_LOAD_MODE", unset = "source")))
  load_mode <- if (nzchar(load_mode)) load_mode else "source"
  if (!load_mode %in% c("source", "installed")) {
    stop(
      sprintf(
        "Unsupported EXDQLM_LOAD_MODE '%s'. Use 'source' or 'installed'.",
        load_mode
      ),
      call. = FALSE
    )
  }
  installed_lib <- Sys.getenv("EXDQLM_INSTALLED_LIB", unset = "")
  installed_lib <- if (nzchar(installed_lib)) {
    normalizePath(installed_lib, winslash = "/", mustWork = FALSE)
  } else {
    NULL
  }
  list(mode = load_mode, installed_lib = installed_lib)
}

load_exdqlm <- function() {
  load_spec <- resolve_load_spec()
  if (identical(load_spec$mode, "installed")) {
    if (!is.null(pkg_path) || nzchar(Sys.getenv("EXDQLM_PKG_PATH", unset = ""))) {
      log_msg("EXDQLM_LOAD_MODE=installed: ignoring source-path overrides and loading installed exdqlm.")
    }
    if (!is.null(load_spec$installed_lib)) {
      if (!dir.exists(load_spec$installed_lib)) {
        stop(
          sprintf(
            "EXDQLM_INSTALLED_LIB does not exist: %s",
            load_spec$installed_lib
          ),
          call. = FALSE
        )
      }
      .libPaths(unique(c(load_spec$installed_lib, .libPaths())))
    }
    if (!requireNamespace("exdqlm", quietly = TRUE)) {
      stop(
        paste(
          "Installed exdqlm package not found.",
          "Set EXDQLM_INSTALLED_LIB to the library containing exdqlm or switch back to source mode.",
          sep = "\n"
        ),
        call. = FALSE
      )
    }
    pkg_loc <- tryCatch(find.package("exdqlm"), error = function(e) NA_character_)
    version <- as.character(utils::packageVersion("exdqlm"))
    log_msg(sprintf(
      "Loaded installed exdqlm (EXDQLM_LOAD_MODE=installed): %s [version %s]",
      pkg_loc,
      version
    ))
    return(invisible(TRUE))
  }

  pkg_spec <- resolve_pkg_path()
  desc_path <- file.path(pkg_spec$path, "DESCRIPTION")

  if (!dir.exists(pkg_spec$path)) {
    stop(
      sprintf(
        paste(
          "Local exdqlm package path (%s) does not exist: %s",
          "Use --pkg-path /path/to/exdqlm or set EXDQLM_PKG_PATH to a valid exdqlm source checkout.",
          sep = "\n"
        ),
        pkg_spec$source,
        pkg_spec$path
      ),
      call. = FALSE
    )
  }
  if (!file.exists(desc_path)) {
    stop(
      sprintf(
        paste(
          "Local exdqlm package path (%s) is not an R package checkout (DESCRIPTION not found): %s",
          "Use --pkg-path /path/to/exdqlm or set EXDQLM_PKG_PATH to a valid exdqlm source checkout.",
          sep = "\n"
        ),
        pkg_spec$source,
        pkg_spec$path
      ),
      call. = FALSE
    )
  }

  loader_name <- if (requireNamespace("pkgload", quietly = TRUE)) {
    "pkgload::load_all"
  } else if (requireNamespace("devtools", quietly = TRUE)) {
    "devtools::load_all"
  } else {
    stop(
      paste(
        "pkgload (preferred) or devtools is required to load local exdqlm package source.",
        "Install pkgload, or provide an environment where one of these loaders is available.",
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  if (identical(loader_name, "pkgload::load_all")) {
    pkgload::load_all(path = pkg_spec$path, quiet = TRUE, export_all = FALSE, helpers = FALSE)
  } else {
    devtools::load_all(path = pkg_spec$path, quiet = TRUE, export_all = FALSE, helpers = FALSE)
  }

  version <- as.character(utils::packageVersion("exdqlm"))
  log_msg(sprintf(
    "Loaded local exdqlm from source (%s via %s): %s [version %s]",
    pkg_spec$source,
    loader_name,
    pkg_spec$path,
    version
  ))
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
  theme_bw(base_size = cfg_style$fig$base_size) +
    theme(
      plot.title = element_text(face = "bold", hjust = 0, size = rel(1.1)),
      plot.subtitle = element_text(hjust = 0),
      legend.position = "top",
      legend.title = element_text(face = "bold"),
      strip.text = element_text(face = "bold"),
      strip.background = element_rect(fill = "#f2f2f2", color = "#d9d9d9"),
      panel.grid.major = element_line(color = "#d9d9d9", linewidth = 0.25),
      panel.grid.minor = element_blank(),
      axis.title = element_text(face = "bold"),
      panel.border = element_rect(color = "#555555", linewidth = 0.5),
      plot.margin = margin(8, 10, 8, 10)
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
    bg = cfg_style$fig$bg,
    limitsize = FALSE
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

  # Use exact key lookups; `$` on lists does partial matching and can
  # accidentally map gamma_fraction_* to gamma.
  gamma_val <- case[["gamma"]]
  frac_pos <- case[["gamma_fraction_positive"]]
  frac_neg <- case[["gamma_fraction_negative"]]

  if (!is.null(gamma_val)) {
    g <- as.numeric(gamma_val)
  } else if (!is.null(frac_pos)) {
    g <- as.numeric(frac_pos) * U
  } else if (!is.null(frac_neg)) {
    g <- as.numeric(frac_neg) * L
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
