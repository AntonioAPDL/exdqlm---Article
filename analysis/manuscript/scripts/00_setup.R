`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

if (!exists("repo_root")) {
  stop("repo_root is not defined. Run via analysis/run_all.R.", call. = FALSE)
}

required_pkgs <- c("yaml", "matrixStats", "coda", "dlm", "FNN")
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
cache_dir <- file.path(output_root, "cache")

for (d in c(figures_dir, tables_dir, logs_dir, cache_dir)) ensure_dir(d)

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

targets <- if (exists("targets")) as.character(targets) else character(0)
targets <- targets[nzchar(targets)]
targeted_run <- length(targets) > 0L
force_refit <- isTRUE(force_refit)

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

# High-contrast LDVB palette used across LD-only counterpart artifacts.
ldvb_cols <- list(
  m1 = "#E69F00",
  m2 = "#0072B2",
  m1_aux = "#CC79A7",
  m2_aux = "#009E73"
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

cache_file <- function(key) {
  file.path(cache_dir, sprintf("%s_%s.rds", key, selected_profile))
}

load_or_fit_cache <- function(key, expr, note = NULL) {
  path <- cache_file(key)
  if (file.exists(path) && !force_refit) {
    if (!is.null(note)) log_msg(sprintf("Loading cache for %s", key))
    return(readRDS(path))
  }
  if (!is.null(note)) log_msg(sprintf("Fitting cache for %s", key))
  val <- eval.parent(substitute(expr))
  saveRDS(val, path)
  val
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

time_window_to_index <- function(ts_ref, t_from, t_to) {
  tx <- grDevices::xy.coords(ts_ref)$x
  idx <- which(tx >= t_from & tx <= t_to)
  if (length(idx) == 0L) return(c(1L, length(tx)))
  c(min(idx), max(idx))
}

target_enabled <- function(id, aliases = character()) {
  if (!targeted_run) return(TRUE)
  any(c(id, aliases) %in% targets)
}

plot_quantile_summary <- function(qsum, col = "purple", add = TRUE, lwd = 1.5) {
  if (!add) {
    plot(qsum$x, qsum$map, type = "n")
  }
  lines(qsum$x, qsum$map, col = col, lwd = lwd)
  lines(qsum$x, qsum$lb, col = col, lwd = 0.8, lty = 2)
  lines(qsum$x, qsum$ub, col = col, lwd = 0.8, lty = 2)
}

component_summary_from_fit <- function(mfit, index, just.theta = FALSE, cr.percent = 0.95) {
  theta <- mfit$samp.theta
  d <- dim(theta)
  if (length(d) != 3L) stop("samp.theta must be a 3D array.", call. = FALSE)
  TT <- d[2]
  n_samp <- d[3]
  if (cr.percent <= 0 || cr.percent >= 1) stop("cr.percent must be between 0 and 1", call. = FALSE)
  half.alpha <- (1 - cr.percent) / 2

  if (!just.theta) {
    p <- length(index)
    FF <- array(mfit$model$FF[index, ], dim = c(p, TT, n_samp))
    theta_sub <- array(theta[index, , ], dim = c(p, TT, n_samp))
    draws <- colSums(FF * theta_sub)
  } else {
    if (length(index) != 1L) stop("when just.theta=TRUE, index must have length 1", call. = FALSE)
    draws <- matrix(theta[index, , ], nrow = TT, ncol = n_samp)
  }

  x_vals <- if (!is.null(mfit$y) && length(mfit$y) == TT) grDevices::xy.coords(mfit$y)$x else seq_len(TT)
  list(
    x = x_vals,
    map = rowMeans(draws),
    lb = matrixStats::rowQuantiles(draws, probs = half.alpha),
    ub = matrixStats::rowQuantiles(draws, probs = cr.percent + half.alpha)
  )
}

plot_component_summary <- function(csum, add = TRUE, col = "purple", lwd = 1.5) {
  if (!add) {
    graphics::plot(csum$x, csum$map, type = "n", xlab = "time", ylab = "component CrIs", ylim = range(c(csum$lb, csum$ub), na.rm = TRUE))
  }
  graphics::lines(csum$x, csum$map, col = col, lwd = lwd)
  graphics::lines(csum$x, csum$lb, col = col, lwd = 0.8, lty = 2)
  graphics::lines(csum$x, csum$ub, col = col, lwd = 0.8, lty = 2)
}

forecast_from_fit <- function(start.t, k, m1, fFF = NULL, fGG = NULL, plot = TRUE, add = FALSE, cols = c("purple", "magenta"), cr.percent = 0.95, y_data = NULL) {
  y <- if (!is.null(y_data)) as.numeric(y_data) else as.numeric(m1$y)
  if (length(y) == 0L) stop("y_data must be provided when fitted object has no y series.", call. = FALSE)
  p <- dim(m1$model$GG)[1]
  TT <- dim(m1$model$GG)[3]
  if (cr.percent <= 0 || cr.percent >= 1) {
    stop("cr.percent must be between 0 and 1", call. = FALSE)
  }
  if (is.null(fFF)) {
    if (TT - start.t < k) {
      stop("fFF and fGG must be provided for forecasts extending past the length of the estimated model", call. = FALSE)
    }
    fFF <- m1$model$FF[, (start.t + 1):(start.t + k)]
    fGG <- m1$model$GG[, , (start.t + 1):(start.t + k)]
  } else {
    fFF <- as.matrix(fFF)
    if (nrow(fFF) != p) stop("dimension of fFF must match fitted model", call. = FALSE)
    if (!any(ncol(fFF) == c(1, k))) stop("fFF must have 1 or k columns", call. = FALSE)
    fGG <- as.array(fGG)
    if (any(dim(fGG)[1:2] != p)) stop("dimension of fGG must match fitted model", call. = FALSE)
    if (!is.na(dim(fGG)[3]) && dim(fGG)[3] != k) {
      stop("fGG must be matrix or array of depth k", call. = FALSE)
    }
  }
  fFF <- matrix(fFF, p, k)
  fGG <- array(fGG, c(p, p, TT))

  df.mat <- exdqlm:::make_df_mat(m1$df, m1$dim.df, p)
  fm <- m1$theta.out$fm[, start.t]
  fC <- m1$theta.out$fC[, , start.t]
  fa <- matrix(NA_real_, p, k)
  fR <- array(NA_real_, c(p, p, k))
  ff <- rep(NA_real_, k)
  fQ <- rep(NA_real_, k)
  for (i in seq_len(k)) {
    if (i == 1L) {
      fa[, 1] <- fGG[, , i] %*% fm
      fR[, , 1] <- fGG[, , i] %*% fC %*% t(fGG[, , i]) + df.mat * fC
      ff[1] <- t(fFF[, i]) %*% fa[, 1]
      fQ[1] <- t(fFF[, i]) %*% fR[, , 1] %*% fFF[, i]
    } else {
      fa[, i] <- fGG[, , i] %*% fa[, i - 1]
      fR[, , i] <- fGG[, , i] %*% fR[, , i - 1] %*% t(fGG[, , i]) + df.mat * fR[, , i - 1]
      ff[i] <- t(fFF[, i]) %*% fa[, i]
      fQ[i] <- t(fFF[, i]) %*% fR[, , i] %*% fFF[, i]
    }
  }
  m1_plot <- m1
  m1_plot$y <- y
  retlist <- list(start.t = start.t, k = k, cr.percent = cr.percent, m1 = m1_plot, fa = fa, fR = fR, ff = ff, fQ = fQ)
  class(retlist) <- "exdqlmForecast"
  if (plot) plot(retlist, cols = cols, add = add)
  invisible(retlist)
}

diagnostics_from_fit <- function(m1, m2 = NULL, plot = TRUE, cols = c("red", "blue"), ref = NULL, y_data = NULL) {
  y_full <- if (!is.null(y_data)) as.numeric(y_data) else as.numeric(m1$y)
  has_y <- length(y_full) > 0L
  nrow_or_len <- function(x) if (is.null(dim(x))) length(x) else nrow(x)

  m1_msfe_full <- as.numeric(m1$map.standard.forecast.errors)
  m1_post_full <- m1$samp.post.pred
  tt_candidates <- c(length(m1_msfe_full), nrow_or_len(m1_post_full))
  if (has_y) tt_candidates <- c(tt_candidates, length(y_full))

  if (!is.null(m2)) {
    m2_msfe_full <- as.numeric(m2$map.standard.forecast.errors)
    m2_post_full <- m2$samp.post.pred
    tt_candidates <- c(tt_candidates, length(m2_msfe_full), nrow_or_len(m2_post_full))
  }

  TT <- min(tt_candidates, na.rm = TRUE)
  if (!is.finite(TT) || TT < 2L) stop("Insufficient aligned observations for diagnostics.", call. = FALSE)

  y <- if (has_y) y_full[seq_len(TT)] else seq_len(TT)
  m1_msfe <- m1_msfe_full[seq_len(TT)]
  m1_post_pred <- m1_post_full[seq_len(TT), , drop = FALSE]
  cols <- c(matrix(cols, 2, 1))

  m1.uts <- stats::pnorm(m1_msfe)
  if (is.null(ref)) {
    ref <- stats::rnorm(TT)
  } else {
    ref <- c(ref)
    if (length(ref) != TT) stop("ref must have size equal to diagnostics span", call. = FALSE)
  }
  m1.KL <- mean(FNN::KL.divergence(ref, m1_msfe))
  if (has_y) {
    m1.loss <- matrix(NA_real_, TT, dim(m1_post_pred)[2])
    for (t in seq_len(TT)) {
      m1.loss[t, ] <- exdqlm:::CheckLossFn(m1$p0, y[t] - m1_post_pred[t, ])
    }
    m1.pplc <- sum(rowMeans(m1.loss))
  } else {
    m1.pplc <- NA_real_
  }
  m1.qq <- stats::qqnorm(m1_msfe, plot = FALSE)
  m1.acf <- stats::acf(m1.uts, plot = FALSE)

  retlist <- list(
    m1.uts = m1.uts, m1.KL = m1.KL, m1.pplc = m1.pplc,
    m1.qq = m1.qq, m1.acf = m1.acf, m1.rt = m1$run.time,
    m1.msfe = m1_msfe, y = y
  )

  if (!is.null(m2)) {
    if (!is.null(m1$p0) && !is.null(m2$p0) && m1$p0 != m2$p0) {
      stop("m1 and m2 must target the same quantile p0", call. = FALSE)
    }
    m2_msfe <- m2_msfe_full[seq_len(TT)]
    m2_post_pred <- m2_post_full[seq_len(TT), , drop = FALSE]
    m2.uts <- stats::pnorm(m2_msfe)
    if (has_y) {
      m2.loss <- matrix(NA_real_, TT, dim(m2_post_pred)[2])
      for (t in seq_len(TT)) {
        m2.loss[t, ] <- exdqlm:::CheckLossFn(m2$p0, y[t] - m2_post_pred[t, ])
      }
      m2.pplc <- sum(rowMeans(m2.loss))
    } else {
      m2.pplc <- NA_real_
    }
    retlist$m2.msfe <- m2_msfe
    retlist$m2.uts <- m2.uts
    retlist$m2.KL <- mean(FNN::KL.divergence(ref, m2_msfe))
    retlist$m2.pplc <- m2.pplc
    retlist$m2.qq <- stats::qqnorm(m2_msfe, plot = FALSE)
    retlist$m2.acf <- stats::acf(m2.uts, plot = FALSE)
    retlist$m2.rt <- m2$run.time
  }
  class(retlist) <- "exdqlmDiagnostic"
  if (plot) plot(retlist, cols = cols)
  invisible(retlist)
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
register_note("backend", "MCMC runs use C++ backend options exdqlm.use_cpp_mcmc=TRUE and exdqlm.cpp_mcmc_mode='fast'.")

log_msg(sprintf("00_setup complete (profile=%s)", selected_profile))
