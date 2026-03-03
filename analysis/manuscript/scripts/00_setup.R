`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

if (!exists("repo_root")) {
  stop("repo_root is not defined. Run via analysis/run_all.R.", call. = FALSE)
}

required_pkgs <- c("yaml", "matrixStats", "coda", "dlm")
for (p in required_pkgs) {
  if (!requireNamespace(p, quietly = TRUE)) {
    stop(sprintf("Package '%s' is required for manuscript stage.", p), call. = FALSE)
  }
}

log_msg <- function(msg) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), msg))
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
}

analysis_root <- file.path(repo_root, "analysis")
stage_root <- file.path(analysis_root, "manuscript")
output_root <- file.path(stage_root, "outputs")
figures_dir <- file.path(output_root, "figures")
tables_dir <- file.path(output_root, "tables")
logs_dir <- file.path(output_root, "logs")

for (d in c(figures_dir, tables_dir, logs_dir)) ensure_dir(d)

cfg_params <- yaml::read_yaml(file.path(analysis_root, "config", "params_manuscript.yml"))
selected_profile <- profile %||% "standard"
if (!selected_profile %in% names(cfg_params$profiles)) {
  stop(
    sprintf(
      "Unknown manuscript profile '%s'. Valid: %s",
      selected_profile,
      paste(names(cfg_params$profiles), collapse = ", ")
    ),
    call. = FALSE
  )
}
cfg_profile <- cfg_params$profiles[[selected_profile]]

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
  path <- resolve_pkg_path()
  if (!is.null(path)) {
    if (!requireNamespace("devtools", quietly = TRUE)) {
      stop("devtools is required to load local exdqlm package source.", call. = FALSE)
    }
    devtools::load_all(path = path, quiet = TRUE, export_all = FALSE, helpers = FALSE)
    log_msg(sprintf("Loaded local exdqlm from source: %s", path))
    return(invisible(TRUE))
  }

  if (requireNamespace("exdqlm", quietly = TRUE)) {
    suppressPackageStartupMessages(library(exdqlm))
    log_msg(sprintf("Loaded installed exdqlm: %s", as.character(utils::packageVersion("exdqlm"))))
    return(invisible(TRUE))
  }

  stop("exdqlm package not installed and no valid local package path found.", call. = FALSE)
}

load_exdqlm()

required_fns <- c(
  "polytrendMod", "seasMod", "as.exdqlm",
  "exdqlmMCMC", "exdqlmISVB", "exdqlmLDVB",
  "transfn_exdqlmISVB", "exdqlmDiagnostics",
  "exdqlmPlot", "compPlot", "exdqlmForecast"
)
missing_fns <- required_fns[!vapply(required_fns, function(f) {
  exists(f, where = asNamespace("exdqlm"), mode = "function", inherits = FALSE)
}, logical(1))]
if (length(missing_fns) > 0L) {
  stop(sprintf("Missing required exdqlm functions: %s", paste(missing_fns, collapse = ", ")), call. = FALSE)
}

options(
  exdqlm.use_cpp_mcmc = TRUE,
  exdqlm.cpp_mcmc_mode = "fast",
  exdqlm.cpp_threads = 1L
)

artifact_registry <- data.frame(
  artifact_id = character(),
  artifact_type = character(),
  relative_path = character(),
  manuscript_target = character(),
  status = character(),
  notes = character(),
  stringsAsFactors = FALSE
)

run_notes <- data.frame(
  topic = character(),
  detail = character(),
  stringsAsFactors = FALSE
)

register_artifact <- function(artifact_id,
                              artifact_type,
                              relative_path,
                              manuscript_target = "",
                              status = "reproduced",
                              notes = "") {
  artifact_registry <<- rbind(
    artifact_registry,
    data.frame(
      artifact_id = artifact_id,
      artifact_type = artifact_type,
      relative_path = relative_path,
      manuscript_target = manuscript_target,
      status = status,
      notes = notes,
      stringsAsFactors = FALSE
    )
  )
}

register_note <- function(topic, detail) {
  run_notes <<- rbind(
    run_notes,
    data.frame(topic = as.character(topic), detail = as.character(detail), stringsAsFactors = FALSE)
  )
}

save_png_plot <- function(filename, expr,
                          width = cfg_params$figures$width,
                          height = cfg_params$figures$height,
                          res = cfg_params$figures$res,
                          pointsize = cfg_params$figures$pointsize) {
  path <- file.path(figures_dir, filename)
  grDevices::png(filename = path, width = width, height = height, units = "in", res = res, pointsize = pointsize)
  on.exit(grDevices::dev.off(), add = TRUE)
  eval.parent(substitute(expr))
  invisible(path)
}

capture_output_file <- function(filename, expr) {
  path <- file.path(logs_dir, filename)
  txt <- utils::capture.output(eval.parent(substitute(expr)))
  writeLines(txt, con = path)
  invisible(path)
}

quantile_draws_from_fit <- function(mfit) {
  if (is.null(mfit$samp.theta) || is.null(mfit$model$FF)) {
    stop("Model object does not contain samp.theta/model$FF.", call. = FALSE)
  }

  theta <- mfit$samp.theta
  d <- dim(theta)
  if (length(d) != 3L) {
    stop("samp.theta must be a 3D array.", call. = FALSE)
  }
  p <- d[1]
  TT <- d[2]
  n_samp <- d[3]
  FF <- matrix(mfit$model$FF, nrow = p, ncol = TT)
  qdraw <- matrix(NA_real_, nrow = TT, ncol = n_samp)
  for (i in seq_len(n_samp)) {
    qdraw[, i] <- colSums(FF * theta[, , i])
  }
  qdraw
}

quantile_summary_from_fit <- function(mfit, cr.percent = 0.95) {
  half.alpha <- (1 - cr.percent) / 2
  draws <- quantile_draws_from_fit(mfit)
  TT <- nrow(draws)
  x_vals <- if (!is.null(mfit$y) && length(mfit$y) == TT) grDevices::xy.coords(mfit$y)$x else seq_len(TT)
  list(
    x = x_vals,
    map = rowMeans(draws),
    lb = matrixStats::rowQuantiles(draws, probs = half.alpha),
    ub = matrixStats::rowQuantiles(draws, probs = cr.percent + half.alpha)
  )
}

plot_quantile_summary <- function(qsum, col = "purple", add = TRUE, lwd = 1.5) {
  if (!add) {
    plot(qsum$x, qsum$map, type = "n")
  }
  lines(qsum$x, qsum$map, col = col, lwd = lwd)
  lines(qsum$x, qsum$lb, col = col, lwd = 0.8, lty = 2)
  lines(qsum$x, qsum$ub, col = col, lwd = 0.8, lty = 2)
}

save_table_csv <- function(df, filename, artifact_id, manuscript_target = "", status = "reproduced", notes = "") {
  path <- file.path(tables_dir, filename)
  utils::write.csv(df, file = path, row.names = FALSE)
  register_artifact(
    artifact_id = artifact_id,
    artifact_type = "table",
    relative_path = file.path("analysis", "manuscript", "outputs", "tables", filename),
    manuscript_target = manuscript_target,
    status = status,
    notes = notes
  )
  invisible(path)
}

write_tracker <- function() {
  tracker_csv <- file.path(tables_dir, "manuscript_repro_tracker.csv")
  utils::write.csv(artifact_registry, tracker_csv, row.names = FALSE)

  notes_csv <- file.path(tables_dir, "manuscript_repro_notes.csv")
  utils::write.csv(run_notes, notes_csv, row.names = FALSE)

  md_path <- file.path(tables_dir, "manuscript_repro_tracker.md")
  con <- file(md_path, open = "wt")
  on.exit(close(con), add = TRUE)
  writeLines("# Manuscript Reproducibility Tracker", con)
  writeLines("", con)
  writeLines(sprintf("Generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), con)
  writeLines(sprintf("Profile: %s", selected_profile), con)
  writeLines(sprintf("Seed: %s", seed_value), con)
  writeLines("", con)
  writeLines("## Artifact Status", con)
  writeLines("", con)
  if (nrow(artifact_registry) == 0L) {
    writeLines("No artifacts registered.", con)
  } else {
    for (i in seq_len(nrow(artifact_registry))) {
      r <- artifact_registry[i, ]
      writeLines(
        sprintf(
          "- [%s] `%s` -> `%s` (%s). %s",
          r$status, r$artifact_id, r$relative_path, r$manuscript_target, r$notes
        ),
        con
      )
    }
  }
  writeLines("", con)
  writeLines("## Notes", con)
  writeLines("", con)
  if (nrow(run_notes) == 0L) {
    writeLines("- none", con)
  } else {
    for (i in seq_len(nrow(run_notes))) {
      writeLines(sprintf("- %s: %s", run_notes$topic[i], run_notes$detail[i]), con)
    }
  }

  register_artifact(
    artifact_id = "manuscript_repro_tracker",
    artifact_type = "table",
    relative_path = "analysis/manuscript/outputs/tables/manuscript_repro_tracker.csv",
    manuscript_target = "all",
    status = "reproduced",
    notes = "Machine-readable artifact status tracker."
  )
}

write_session_info <- function() {
  path <- file.path(logs_dir, "sessionInfo.txt")
  sink(path)
  on.exit(sink(), add = TRUE)
  cat(sprintf("Seed: %s\n", seed_value))
  cat(sprintf("Profile: %s\n", selected_profile))
  cat(sprintf("Date: %s\n\n", as.character(Sys.time())))
  print(sessionInfo())
}

promote_publication_figures <- function() {
  promote <- cfg_params$promotion$figures
  if (length(promote) == 0L) {
    log_msg("No manuscript promotion list found in config.")
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

  log_msg(sprintf("Promoted %d manuscript figure(s) to Figures/", length(promote)))
}

register_note("api_update", "Deprecated exdqlmChecks replaced with exdqlmDiagnostics.")
register_note("api_update", "Deprecated y= usage removed from exdqlmPlot/compPlot/exdqlmForecast calls.")
register_note("ldvb_note", "Added ISVB vs LDVB comparison figure for dynamic Sunspots example.")

log_msg(sprintf("00_setup complete (profile=%s)", selected_profile))
