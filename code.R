#!/usr/bin/env Rscript

#' # exdqlm JSS replication script
#'
#' This file is the full manuscript replication script for the JSS article
#' "exdqlm: An R Package for Estimation and Analysis of Flexible Dynamic
#' Quantile Linear Models".
#'
#' Run from the extracted replication-materials directory with:
#'
#' ```sh
#' R CMD BATCH --vanilla code.R code.Rout
#' ```
#'
#' This script refits the four examples, regenerates the manuscript figures,
#' prints the numerical tables and selected fitted-object output, and records
#' the computational environment.
#'
#' The script is intentionally flat: it contains the setup code, helper code,
#' and example code in manuscript order.

jss_start_time <- proc.time()[[3L]]
repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
seed_override <- NULL
Sys.setenv(
  TZ = "America/New_York",
  OMP_NUM_THREADS = Sys.getenv("OMP_NUM_THREADS", unset = "1"),
  OMP_THREAD_LIMIT = Sys.getenv("OMP_THREAD_LIMIT", unset = "1"),
  OPENBLAS_NUM_THREADS = Sys.getenv("OPENBLAS_NUM_THREADS", unset = "1"),
  MKL_NUM_THREADS = Sys.getenv("MKL_NUM_THREADS", unset = "1"),
  BLIS_NUM_THREADS = Sys.getenv("BLIS_NUM_THREADS", unset = "1"),
  VECLIB_MAXIMUM_THREADS = Sys.getenv("VECLIB_MAXIMUM_THREADS", unset = "1")
)
RNGversion("4.6.0")
RNGkind("Mersenne-Twister", "Inversion", "Rejection")

cat("== exdqlm JSS replication ==\n")
cat("Run: full manuscript replication\n")
cat(sprintf("R: %s\n", R.version.string))
cat(sprintf("Working directory: %s\n", repo_root))
cat(sprintf("RNGkind: %s\n", paste(RNGkind(), collapse = " / ")))
cat("Thread environment:\n")
print(Sys.getenv(c("OMP_NUM_THREADS", "OMP_THREAD_LIMIT", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "BLIS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"), unset = NA_character_))

if (file.exists("Rplots.pdf")) unlink("Rplots.pdf", force = TRUE)
grDevices::pdf("Rplots.pdf", onefile = TRUE)
options(exdqlm.jss_rplots_active = TRUE)
on.exit({
  if (isTRUE(getOption("exdqlm.jss_rplots_active", FALSE))) {
    grDevices::dev.off()
    options(exdqlm.jss_rplots_active = FALSE)
  }
}, add = TRUE)

# ---- inlined manuscript setup ----
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

if (!exists("repo_root")) {
  stop("repo_root is not defined. Run code.R from the extracted replication directory.", call. = FALSE)
}

required_pkgs <- c("matrixStats", "coda", "dlm")
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
figures_dir <- file.path(repo_root, "figures")
tables_dir <- file.path(repo_root, "tables")
logs_dir <- file.path(repo_root, "logs")

for (d in c(figures_dir, tables_dir, logs_dir)) ensure_dir(d)

cfg_params <-
  list(seed = 20260501L, expected_exdqlm_version = "1.1.1", rng = list(
      kind = "Mersenne-Twister", normal_kind = "Inversion", sample_kind = "Rejection"),
      figures = list(width = 10L, height = 6L, res = 220L, pointsize = 11L),
      promotion = list(figures = c("ex1mcmc.png", "ex1quants.png",
      "ex2quant.png", "ex2checks.png", "ex3data.png", "ex3quantcomps.png",
      "ex3zetapsi.png", "ex3forecast.png", "ex4static.png")), run_name = "standard",
      run_settings = list(standard = list(ex1 = list(trace_seed = 20260620L,
          n_burn = 2000L, n_mcmc = 3000L, n_burn_trace = 7000L,
          n_mcmc_trace = 3000L, thin_trace = 10L, n_chains_kernel = 4L,
          n_burn_kernel = 2000L, n_mcmc_kernel = 1000L, thin_kernel_plot = 10L,
          synth_source_draws = 2000L, synth_n_samp = 5000L, forecast_window_start = 1952L,
          synth_window_start = 1880L), ex2 = list(n_is = 500L,
          n_samp = 3000L, tol = 0.05, ldvb_diag_tol = 0.01, ldvb_diag_n_samp = 3000L,
          benchmark_n_burn = 2000L, benchmark_n_mcmc = 3000L, df_grid = c(0.85,
          0.9, 0.95, 1)), ex3 = list(p0 = 0.15, selected_indices = c("noi",
      "amo"), fit_start = "1987-01-01", fit_end = "2022-12-01",
          forecast_horizon = 18L, focus_window = c(2016L, 2020L
          ), forecast_plot_start = 2020L, trend_order = 1L, seasonal_period = 12L,
          harmonics = c(1, 2, 0.1469118636), trend_df = 0.99, seasonal_df = 0.99,
          covariate_df = 1, transfer_zeta_df = 0.99, transfer_psi_df = 1,
          transfer_psi_df_grid = 1, selection_metric = "PPLC",
          trend_m0 = 3.91202300542815, trend_c0 = 1, seasonal_c0 = 1,
          climate_coef_c0 = 1, reg_c0 = 1, transfer_zeta_c0 = 0.1,
          transfer_psi_c0 = 1, gam_init = -0.1, sig_init = 0.1,
          max_iter = 600L, n_is = 500L, n_samp = 1000L, forecast_n_samp = 1000L,
          tol = 0.05, lambda_grid = c(0.7, 0.75, 0.8, 0.85, 0.9,
          0.95, 0.99)), ex4 = list(n_train = 160L, holdout_n = 800L,
          n_predictors = 8L, dataset_seed = 20260712L, dataset_seed_mode = "configured",
          cov_rho = 0.5, sigma_eps = 1.5, true_beta = c(3, 1.5,
          0, 0, 2, 0, 0, 0), p_levels = c(0.05, 0.25, 0.5), screen_target_p0 = 0.5,
          ldvb_max_iter = 260L, ldvb_max_iter_tail = 420L, ldvb_tol = 1e-04,
          rhs_tau0 = 0.15, rhs_zeta2_fixed = 9, screen_seeds = 20260711:20260718,
          screen_extra_seed_count = 8L, screen_batch_size = 4L,
          n_burn = 2000L, n_mcmc = 3000L, thin = 1L, n_samp = 3000L))),
      manuscript_benchmark_setting = "B", benchmark_settings = list(
          A = list(label = "pure-R baseline", use_cpp_kf = FALSE,
              use_cpp_builders = FALSE, use_cpp_samplers = FALSE,
              use_cpp_postpred = FALSE, use_cpp_mcmc = FALSE, cpp_mcmc_mode = "strict",
              cpp_threads = 1L), B = list(label = "manuscript-matched backend",
              use_cpp_kf = TRUE, use_cpp_builders = FALSE, use_cpp_samplers = FALSE,
              use_cpp_postpred = FALSE, use_cpp_mcmc = TRUE, cpp_mcmc_mode = "fast",
              cpp_threads = 1L)))
selected_run <- "standard"
if (!selected_run %in% names(cfg_params$run_settings)) {
  stop(
    sprintf(
      "Unknown manuscript settings '%s'. Valid: %s",
      selected_run,
      paste(names(cfg_params$run_settings), collapse = ", ")
    ),
    call. = FALSE
  )
}
cfg_run <- cfg_params$run_settings[[selected_run]]
cfg_benchmark_settings <- cfg_params$benchmark_settings %||% list()
selected_benchmark_setting <- cfg_params$manuscript_benchmark_setting %||% "B"
if (!selected_benchmark_setting %in% names(cfg_benchmark_settings)) {
  stop(
    sprintf(
      "Unknown benchmark backend settings '%s'. Valid: %s",
      selected_benchmark_setting,
      paste(names(cfg_benchmark_settings), collapse = ", ")
    ),
    call. = FALSE
  )
}

set_manuscript_rng <- function(rng_cfg = cfg_params$rng %||% list()) {
  kind <- as.character(rng_cfg$kind %||% "Mersenne-Twister")
  normal_kind <- as.character(rng_cfg$normal_kind %||% "Inversion")
  sample_kind <- as.character(rng_cfg$sample_kind %||% "Rejection")
  RNGkind(kind = kind, normal.kind = normal_kind, sample.kind = sample_kind)
  invisible(RNGkind())
}

seed_value <- seed_override %||% cfg_params$seed
selected_rng_kind <- set_manuscript_rng()
set.seed(seed_value)



resolve_pkg_path <- function(fail_if_missing = FALSE) {
  list(path = NA_character_, candidate = "installed")
}

load_exdqlm <- function() {
  suppressPackageStartupMessages(library("exdqlm"))
  found_version <- as.character(utils::packageVersion("exdqlm"))
  expected_version <- as.character(cfg_params$expected_exdqlm_version)
  log_msg(sprintf("Loaded installed exdqlm version %s", found_version))
  if (!identical(found_version, expected_version)) {
    stop(sprintf("This replication script requires exdqlm %s; found %s", expected_version, found_version), call. = FALSE)
  }
  invisible(TRUE)
}

load_exdqlm()

required_fns <- c(
  "polytrendMod", "seasMod", "as.exdqlm",
  "exdqlmMCMC", "exdqlmLDVB", "diagnostics", "exdqlmDiagnostics",
  "exdqlmPlot", "compPlot", "exdqlmForecast", "exdqlmForecastDiagnostics",
  "exalStaticLDVB", "exalStaticMCMC", "exalStaticDiagnostics",
  "quantileSynthesis"
)
missing_fns <- required_fns[!vapply(required_fns, function(f) {
  exists(f, where = asNamespace("exdqlm"), mode = "function", inherits = FALSE)
}, logical(1))]
if (length(missing_fns) > 0L) {
  stop(sprintf("Missing required exdqlm functions: %s", paste(missing_fns, collapse = ", ")), call. = FALSE)
}

apply_backend_settings <- function(settings_name = selected_benchmark_setting) {
  prof <- cfg_benchmark_settings[[settings_name]]
  if (is.null(prof)) {
    stop(sprintf("Unknown benchmark backend settings '%s'.", settings_name), call. = FALSE)
  }
  options(
    exdqlm.use_cpp_kf = isTRUE(prof$use_cpp_kf),
    exdqlm.use_cpp_builders = isTRUE(prof$use_cpp_builders),
    exdqlm.use_cpp_samplers = isTRUE(prof$use_cpp_samplers),
    exdqlm.use_cpp_postpred = isTRUE(prof$use_cpp_postpred),
    exdqlm.use_cpp_mcmc = isTRUE(prof$use_cpp_mcmc),
    exdqlm.cpp_mcmc_mode = as.character(prof$cpp_mcmc_mode %||% "fast"),
    exdqlm.cpp_threads = as.integer(prof$cpp_threads %||% 1L)
  )
  invisible(prof)
}

with_backend_settings <- function(settings_name, expr) {
  old <- options(
    exdqlm.use_cpp_kf = getOption("exdqlm.use_cpp_kf"),
    exdqlm.use_cpp_builders = getOption("exdqlm.use_cpp_builders"),
    exdqlm.use_cpp_samplers = getOption("exdqlm.use_cpp_samplers"),
    exdqlm.use_cpp_postpred = getOption("exdqlm.use_cpp_postpred"),
    exdqlm.use_cpp_mcmc = getOption("exdqlm.use_cpp_mcmc"),
    exdqlm.cpp_mcmc_mode = getOption("exdqlm.cpp_mcmc_mode"),
    exdqlm.cpp_threads = getOption("exdqlm.cpp_threads")
  )
  on.exit(options(old), add = TRUE)
  apply_backend_settings(settings_name)
  eval.parent(substitute(expr))
}

safe_system_output <- function(cmd, args = character()) {
  out <- tryCatch(
    suppressWarnings(system2(cmd, args = args, stdout = TRUE, stderr = FALSE)),
    error = function(e) character()
  )
  trimws(out[nzchar(trimws(out))])
}





source_state_snapshot <- function(path) {
  list(path = NA_character_, identifier = "CRAN package")
}

article_state_at_setup <- source_state_snapshot(repo_root)
pkg_source_at_setup <- resolve_pkg_path(fail_if_missing = FALSE)
pkg_state_at_setup <- source_state_snapshot(pkg_source_at_setup$path)

detect_cpu_model <- function() {
  if (.Platform$OS.type == "unix" && file.exists("/proc/cpuinfo")) {
    cpuinfo <- tryCatch(readLines("/proc/cpuinfo", warn = FALSE), error = function(e) character())
    hit <- grep("^model name\\s*:", cpuinfo, value = TRUE)
    if (length(hit)) {
      return(trimws(sub("^model name\\s*:\\s*", "", hit[[1]])))
    }
  }
  if (Sys.info()[["sysname"]] == "Darwin") {
    cpu_line <- safe_system_output("sysctl", c("-n", "machdep.cpu.brand_string"))
    if (length(cpu_line)) return(cpu_line[[1]])
  }
  as.character(Sys.info()[["machine"]] %||% NA_character_)
}

benchmark_settings_table <- function() {
  rows <- lapply(names(cfg_benchmark_settings), function(name) {
    prof <- cfg_benchmark_settings[[name]]
    data.frame(
      settings = name,
      label = as.character(prof$label %||% ""),
      use_cpp_kf = isTRUE(prof$use_cpp_kf),
      use_cpp_builders = isTRUE(prof$use_cpp_builders),
      use_cpp_samplers = isTRUE(prof$use_cpp_samplers),
      use_cpp_postpred = isTRUE(prof$use_cpp_postpred),
      use_cpp_mcmc = isTRUE(prof$use_cpp_mcmc),
      cpp_mcmc_mode = as.character(prof$cpp_mcmc_mode %||% NA_character_),
      cpp_threads = as.integer(prof$cpp_threads %||% NA_integer_),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

resolve_ex4_dataset_seed_for_reporting <- function(cfg_ex4 = cfg_run$ex4) {
  mode <- tolower(trimws(as.character(cfg_ex4$dataset_seed_mode %||% "configured")))
  configured_seed <- as.integer(cfg_ex4$dataset_seed %||% NA_integer_)
  if (!identical(mode, "screen_selection")) {
    return(configured_seed)
  }

  target_p0 <- as.numeric(cfg_ex4$screen_target_p0 %||% 0.50)
  selection_path <- file.path(
    tables_dir,
    sprintf("ex4_seed_screen_p%03d_selection.csv", round(100 * target_p0))
  )
  if (!file.exists(selection_path)) {
    return(configured_seed)
  }

  selected_tab <- tryCatch(utils::read.csv(selection_path, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(selected_tab) || !"selected" %in% names(selected_tab)) {
    return(configured_seed)
  }
  selected_rows <- selected_tab[selected_tab$selected %in% c(TRUE, "TRUE", "True", "true", 1, "1"), , drop = FALSE]
  if (nrow(selected_rows) != 1L) {
    return(configured_seed)
  }
  as.integer(selected_rows$seed[[1L]])
}

benchmark_environment_table <- function() {
  cpu_model <- detect_cpu_model()
  pkg_version <- tryCatch(as.character(utils::packageVersion("exdqlm")), error = function(e) NA_character_)
  ex1_len <- tryCatch({
    utils::data("LakeHuron", package = "datasets", envir = environment())
    length(datasets::LakeHuron)
  }, error = function(e) NA_integer_)
  ex2_len <- tryCatch(length(datasets::sunspot.year), error = function(e) NA_integer_)
  ex3_len <- tryCatch({
    utils::data("BTflow", package = "exdqlm", envir = environment())
    length(BTflow)
  }, error = function(e) NA_integer_)

  data.frame(
    field = c(
      "selected_run",
      "benchmark_settings",
      "seed",
      "cpu_model",
      "os",
      "r_version",
      "r_binary",
      "rscript_binary",
      "rng_kind",
      "rng_normal_kind",
      "rng_sample_kind",
      "exdqlm_version",
      "exdqlm_source",
      "runtime_definition",
      "diagnostics_runtime_included",
      "exdqlm.use_cpp_kf",
      "exdqlm.use_cpp_builders",
      "exdqlm.use_cpp_samplers",
      "exdqlm.use_cpp_postpred",
      "exdqlm.use_cpp_mcmc",
      "exdqlm.cpp_mcmc_mode",
      "exdqlm.cpp_threads",
      "ex1_length",
      "ex2_length",
      "ex3_length",
      "ex4_train_n",
      "ex4_holdout_n",
      "ex4_dataset_seed"
    ),
    value = c(
      selected_run,
      selected_benchmark_setting,
      as.character(seed_value),
      cpu_model,
      paste(Sys.info()[c("sysname", "release", "machine")], collapse = " | "),
      R.version.string,
      "<R_HOME>/bin/R",
      "<R_HOME>/bin/Rscript",
      selected_rng_kind[[1L]],
      selected_rng_kind[[2L]],
      selected_rng_kind[[3L]],
      pkg_version,
      pkg_state_at_setup$identifier,
      "fit elapsed time stored in returned fit objects (`run.time`)",
      "FALSE",
      as.character(isTRUE(getOption("exdqlm.use_cpp_kf"))),
      as.character(isTRUE(getOption("exdqlm.use_cpp_builders"))),
      as.character(isTRUE(getOption("exdqlm.use_cpp_samplers"))),
      as.character(isTRUE(getOption("exdqlm.use_cpp_postpred"))),
      as.character(isTRUE(getOption("exdqlm.use_cpp_mcmc"))),
      as.character(getOption("exdqlm.cpp_mcmc_mode")),
      as.character(getOption("exdqlm.cpp_threads")),
      as.character(ex1_len),
      as.character(ex2_len),
      as.character(ex3_len),
      as.character(cfg_run$ex4$n_train %||% NA_integer_),
      as.character(cfg_run$ex4$holdout_n %||% NA_integer_),
      as.character(resolve_ex4_dataset_seed_for_reporting(cfg_run$ex4))
    ),
    stringsAsFactors = FALSE
  )
}

sanitize_reference_paths <- function(lines) {
  r_home <- normalizePath(R.home(), winslash = "/", mustWork = FALSE)
  if (nzchar(r_home)) {
    lines <- gsub(r_home, "<R_HOME>", lines, fixed = TRUE)
  }
  lines <- sub("[[:space:]]+$", "", lines)
  lines
}

apply_backend_settings(selected_benchmark_setting)

# High-contrast LDVB palette used across LD-only counterpart outputs.
ldvb_cols <- list(
  m1 = "#E69F00",
  m2 = "#0072B2",
  m1_aux = "#CC79A7",
  m2_aux = "#009E73"
)

save_png_plot <- function(filename, expr,
                          width = cfg_params$figures$width,
                          height = cfg_params$figures$height,
                          res = cfg_params$figures$res,
                          pointsize = cfg_params$figures$pointsize) {
  path <- file.path(figures_dir, filename)
  png_type <- if (isTRUE(capabilities("cairo"))) "cairo" else getOption("bitmapType", "Xlib")
  grDevices::png(
    filename = path, width = width, height = height,
    units = "in", res = res, pointsize = pointsize,
    type = png_type
  )
  on.exit(grDevices::dev.off(), add = TRUE)
  eval.parent(substitute(expr))
  invisible(path)
}

step_output_file <- function(step_id) {
  file.path(logs_dir, sprintf("%s.txt", step_id))
}

run_step <- function(step_id, expr, note = NULL) {
  eval.parent(substitute(expr))
}

capture_output_file <- function(filename, expr) {
  path <- file.path(logs_dir, filename)
  txt <- utils::capture.output(eval.parent(substitute(expr)))
  write_log_lines(txt, path)
  invisible(path)
}

normalize_log_lines <- function(x) {
  x <- sub("[[:space:]]+$", "", x)
  while (length(x) > 0L && identical(x[[length(x)]], "")) {
    x <- x[-length(x)]
  }
  x
}

write_log_lines <- function(x, path) {
  writeLines(normalize_log_lines(x), con = path)
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

plot_component_summary <- function(csum, add = TRUE, col = "purple", lwd = 1.5,
                                   ylim = NULL, xlab = "time", ylab = "component CrIs") {
  if (!add) {
    if (is.null(ylim)) {
      ylim <- range(c(csum$lb, csum$ub), na.rm = TRUE)
    }
    graphics::plot(csum$x, csum$map, type = "n", xlab = xlab, ylab = ylab, ylim = ylim)
  }
  graphics::lines(csum$x, csum$map, col = col, lwd = lwd)
  graphics::lines(csum$x, csum$lb, col = col, lwd = 0.8, lty = 2)
  graphics::lines(csum$x, csum$ub, col = col, lwd = 0.8, lty = 2)
}

forecast_from_fit <- function(start.t, k, m1, fFF = NULL, fGG = NULL, plot = TRUE, add = FALSE,
                              cols = c("purple", "magenta"), cr.percent = 0.95, y_data = NULL,
                              return.draws = FALSE, n.samp = NULL, seed = NULL) {
  m1_input <- m1
  if (!is.null(y_data)) {
    if (length(as.numeric(y_data)) == 0L) {
      stop("y_data must contain at least one observation.", call. = FALSE)
    }
    m1_input$y <- y_data
  } else if (length(as.numeric(m1$y)) == 0L) {
    stop("y_data must be provided when fitted object has no y series.", call. = FALSE)
  }

  exdqlm::exdqlmForecast(
    start.t = start.t,
    k = k,
    m1 = m1_input,
    fFF = fFF,
    fGG = fGG,
    plot = plot,
    add = add,
    cols = cols,
    cr.percent = cr.percent,
    return.draws = return.draws,
    n.samp = n.samp,
    seed = seed
  )
}

diagnostics_from_fit <- function(m1, m2 = NULL, plot = TRUE, cols = c("red", "blue"),
                                 ref = NULL, y_data = NULL,
                                 crps_probs = seq(0.01, 0.99, by = 0.01),
                                 crps_weights = NULL,
                                 kl_k = NULL) {
  if (!is.null(y_data) && length(y_data) != length(m1$y)) {
    stop("y_data must have the same length as m1$y when supplied.", call. = FALSE)
  }
  exdqlm::diagnostics(
    m1, m2 = m2, plot = plot, cols = cols, ref = ref,
    crps_probs = crps_probs, crps_weights = crps_weights, kl_k = kl_k
  )
}

save_table_csv <- function(df, filename, ...) {
  path <- file.path(tables_dir, filename)
  utils::write.csv(df, file = path, row.names = FALSE)
  invisible(path)
}

write_replication_index <- function() {
  invisible(TRUE)
}

write_session_info <- function() {
  path <- file.path(logs_dir, "sessionInfo.txt")
  txt <- utils::capture.output({
    cat(sprintf("Seed: %s\n", seed_value))
    cat(sprintf("RNGkind: %s\n", paste(RNGkind(), collapse = " | ")))
    cat(sprintf("Date: %s\n\n", as.character(Sys.time())))
    print(sessionInfo())
  })
  txt <- sanitize_reference_paths(txt)
  write_log_lines(txt, path)
}



log_msg("Setup complete")

# ---- JSS-facing plotting override ----
save_png_plot <- function(filename, expr,
                          width = cfg_params$figures$width,
                          height = cfg_params$figures$height,
                          res = cfg_params$figures$res,
                          pointsize = cfg_params$figures$pointsize) {
  plot_expr <- substitute(expr)
  path <- file.path(figures_dir, filename)
  png_type <- if (isTRUE(capabilities("cairo"))) "cairo" else getOption("bitmapType", "Xlib")
  grDevices::png(filename = path, width = width, height = height, units = "in", res = res, pointsize = pointsize, type = png_type)
  tryCatch(
    eval.parent(plot_expr),
    finally = grDevices::dev.off()
  )
  manuscript_figures <- as.character(cfg_params$promotion$figures %||% character())
  if (isTRUE(getOption("exdqlm.jss_rplots_active", FALSE)) && filename %in% manuscript_figures) {
    eval.parent(plot_expr)
  }
  invisible(path)
}

# ---- inlined Example 4 helpers ----
ex4_p_key <- function(p0) sprintf("p%03d", round(100 * p0))

ex4_build_rhs_ctrl <- function(cfg_ex4) {
  list(
    tau0 = as.numeric(cfg_ex4$rhs_tau0),
    zeta2_fixed = as.numeric(cfg_ex4$rhs_zeta2_fixed),
    shrink_intercept = FALSE
  )
}

ex4_interval_coverage <- function(lb, ub, truth) {
  contains <- as.logical(lb <= truth & truth <= ub)
  list(
    contains = contains,
    n_contains = sum(contains),
    n_total = length(contains),
    all_contains = all(contains)
  )
}

ex4_resolve_slope_coverage <- function(method_fit, beta_true) {
  if (!is.null(method_fit$slope_coverage)) {
    cov <- method_fit$slope_coverage
    if (!is.null(cov$contains) &&
        !is.null(cov$n_contains) &&
        !is.null(cov$n_total) &&
        !is.null(cov$all_contains)) {
      return(cov)
    }
  }
  ex4_interval_coverage(
    lb = as.numeric(method_fit$beta_lb_slopes),
    ub = as.numeric(method_fit$beta_ub_slopes),
    truth = as.numeric(beta_true)
  )
}

ex4_screen_target_p0 <- function(cfg_ex4) {
  as.numeric(cfg_ex4$screen_target_p0 %||% 0.50)
}

ex4_screen_file_stem <- function(cfg_ex4) {
  sprintf("ex4_seed_screen_p%03d", round(100 * ex4_screen_target_p0(cfg_ex4)))
}

ex4_screen_candidate_batches <- function(cfg_ex4, seed_value) {
  base_seeds <- as.integer(unlist(cfg_ex4$screen_seeds %||% (seed_value + 500L + seq_len(8L))))
  base_seeds <- sort(unique(base_seeds))
  if (length(base_seeds) < 2L) {
    stop("Example 4 seed screen requires at least two candidate seeds.", call. = FALSE)
  }

  extra_seed_count <- as.integer(cfg_ex4$screen_extra_seed_count %||% 0L)
  batch_size <- as.integer(cfg_ex4$screen_batch_size %||% length(base_seeds))
  if (!is.finite(batch_size) || batch_size < 1L) batch_size <- length(base_seeds)

  batches <- list(base_seeds)
  if (extra_seed_count > 0L) {
    extra_start <- max(base_seeds) + 1L
    extra_seeds <- seq.int(extra_start, length.out = extra_seed_count)
    extra_batches <- split(extra_seeds, ceiling(seq_along(extra_seeds) / batch_size))
    batches <- c(batches, extra_batches)
  }
  batches
}

ex4_seed_selection_path <- function(cfg_ex4) {
  file.path(tables_dir, sprintf("%s_selection.csv", ex4_screen_file_stem(cfg_ex4)))
}

ex4_seed_screen_step_id <- function(dataset_seed, cfg_ex4) {
  sprintf(
    "ex4_seed_screen_seed_%d_ns%d_b%d_k%d_v2",
    as.integer(dataset_seed),
    as.integer(cfg_ex4$n_samp %||% 200L),
    as.integer(cfg_ex4$n_burn),
    as.integer(cfg_ex4$n_mcmc)
  )
}

ex4_resolve_dataset_seed <- function(cfg_ex4) {
  mode <- tolower(trimws(as.character(cfg_ex4$dataset_seed_mode %||% "configured")))
  configured_seed <- as.integer(cfg_ex4$dataset_seed %||% (seed_value + 404L))
  if (!mode %in% c("configured", "screen_selection")) {
    stop(sprintf("Unsupported Example 4 dataset_seed_mode '%s'.", mode), call. = FALSE)
  }
  if (identical(mode, "configured")) {
    return(list(
      seed = configured_seed,
      source = "configured",
      target_p0 = ex4_screen_target_p0(cfg_ex4),
      selection_file = NA_character_
    ))
  }

  selection_path <- ex4_seed_selection_path(cfg_ex4)
  if (!file.exists(selection_path)) {
    stop(
      sprintf(
        paste(
          "Example 4 is configured to use a screen-selected dataset seed, but the selection file was not found:",
          "%s",
          "Use a configured Example 4 seed before running the full replication."
        ),
        selection_path
      ),
      call. = FALSE
    )
  }

  selected_tab <- utils::read.csv(selection_path, stringsAsFactors = FALSE)
  if (!"selected" %in% names(selected_tab)) {
    stop(sprintf("Example 4 seed-selection file is missing the 'selected' column: %s", selection_path), call. = FALSE)
  }
  selected_rows <- selected_tab[isTRUE(selected_tab$selected) | selected_tab$selected %in% c(TRUE, "TRUE", "True", "true", 1, "1"), , drop = FALSE]
  if (nrow(selected_rows) != 1L) {
    stop(
      sprintf(
        "Expected exactly one selected Example 4 seed in %s, found %d.",
        selection_path,
        nrow(selected_rows)
      ),
      call. = FALSE
    )
  }

  list(
    seed = as.integer(selected_rows$seed[[1L]]),
    source = "screen_selection",
    target_p0 = ex4_screen_target_p0(cfg_ex4),
    selection_file = selection_path
  )
}

ex4_simulate_target_quantile_sample <- function(X_raw, beta_slopes, sigma_eps, p0, z = NULL) {
  if (is.null(z)) z <- stats::rnorm(nrow(X_raw))
  as.numeric(X_raw %*% beta_slopes) + sigma_eps * (z - stats::qnorm(p0))
}

ex4_run_step <- function(step_id, expr, note = NULL) {
  eval.parent(substitute(expr))
}

ex4_support_recovery <- function(beta_est, beta_true) {
  active_idx <- which(beta_true != 0)
  topk <- order(abs(beta_est), decreasing = TRUE)[seq_along(active_idx)]
  list(
    topk_support_ok = identical(sort(topk), active_idx),
    sign_support_ok = all(sign(beta_est[active_idx]) == sign(beta_true[active_idx])),
    min_active_abs = min(abs(beta_est[active_idx])),
    max_inactive_abs = max(abs(beta_est[-active_idx]))
  )
}

ex4_fit_seed <- function(dataset_seed, cfg_ex4, stop_on_failure = TRUE) {
  train_n <- as.integer(cfg_ex4$n_train)
  holdout_n <- as.integer(cfg_ex4$holdout_n)
  predictor_n <- as.integer(cfg_ex4$n_predictors)
  cov_rho <- as.numeric(cfg_ex4$cov_rho)
  sigma_eps <- as.numeric(cfg_ex4$sigma_eps)
  beta_slopes <- as.numeric(cfg_ex4$true_beta)
  p_levels <- as.numeric(cfg_ex4$p_levels)
  ldvb_max_iter <- as.integer(cfg_ex4$ldvb_max_iter)
  ldvb_max_iter_tail <- as.integer(cfg_ex4$ldvb_max_iter_tail)
  ldvb_tol <- as.numeric(cfg_ex4$ldvb_tol)
  n_samp <- as.integer(cfg_ex4$n_samp %||% 200L)
  n_burn <- as.integer(cfg_ex4$n_burn)
  n_mcmc <- as.integer(cfg_ex4$n_mcmc)
  thin <- as.integer(cfg_ex4$thin %||% 1L)

  if (length(beta_slopes) != predictor_n) {
    stop("Example 4 config mismatch: length(true_beta) must equal n_predictors.", call. = FALSE)
  }

  rhs_ctrl <- ex4_build_rhs_ctrl(cfg_ex4)
  true_beta_full <- c(0, beta_slopes)
  coef_names <- paste0("x", seq_len(predictor_n))
  active_mask <- beta_slopes != 0
  cov_mat <- cov_rho ^ as.matrix(stats::dist(seq_len(predictor_n)))

  fit_one_seed <- function() {
    set.seed(dataset_seed)

    X_train_raw <- MASS::mvrnorm(train_n, mu = rep(0, predictor_n), Sigma = cov_mat)
    X_train <- cbind(1, X_train_raw)
    X_holdout_raw <- MASS::mvrnorm(holdout_n, mu = rep(0, predictor_n), Sigma = cov_mat)
    X_holdout <- cbind(1, X_holdout_raw)
    ref_holdout <- as.numeric(X_holdout %*% true_beta_full)

    fits <- vector("list", length(p_levels))
    names(fits) <- vapply(p_levels, ex4_p_key, character(1))

    for (p0 in p_levels) {
      ldvb_budget <- if (isTRUE(all.equal(p0, 0.05))) ldvb_max_iter_tail else ldvb_max_iter
      y_train <- ex4_simulate_target_quantile_sample(X_train_raw, beta_slopes, sigma_eps, p0)
      y_holdout <- ex4_simulate_target_quantile_sample(X_holdout_raw, beta_slopes, sigma_eps, p0)

      warn_ldvb <- msg_ldvb <- character()
      fit_ldvb <- withCallingHandlers(
        exdqlm::exalStaticLDVB(
          y = y_train,
          X = X_train,
          p0 = p0,
          beta_prior = "rhs_ns",
          beta_prior_controls = rhs_ctrl,
          max_iter = ldvb_budget,
          tol = ldvb_tol,
          n.samp = n_samp,
          verbose = FALSE
        ),
        warning = function(w) {
          warn_ldvb <<- c(warn_ldvb, conditionMessage(w))
          invokeRestart("muffleWarning")
        },
        message = function(m) {
          msg_ldvb <<- c(msg_ldvb, conditionMessage(m))
          invokeRestart("muffleMessage")
        }
      )
      if (length(unique(warn_ldvb)) > 0L || length(unique(msg_ldvb)) > 0L) {
        stop(
          sprintf(
            "Example 4 LDVB was not silent at p0=%0.2f. warnings=%s messages=%s",
            p0,
            paste(unique(warn_ldvb), collapse = " | "),
            paste(unique(msg_ldvb), collapse = " | ")
          ),
          call. = FALSE
        )
      }
      if (!isTRUE(fit_ldvb$converged)) {
        stop(
          sprintf(
            "Example 4 LDVB did not converge at p0=%0.2f (iter=%d, stop=%s).",
            p0,
            as.integer(fit_ldvb$iter),
            fit_ldvb$diagnostics$convergence$stop_reason
          ),
          call. = FALSE
        )
      }

      warn_mcmc <- msg_mcmc <- character()
      fit_mcmc <- withCallingHandlers(
        exdqlm::exalStaticMCMC(
          y = y_train,
          X = X_train,
          p0 = p0,
          beta_prior = "rhs_ns",
          beta_prior_controls = rhs_ctrl,
          n.burn = n_burn,
          n.mcmc = n_mcmc,
          thin = thin,
          init.from.vb = TRUE,
          verbose = FALSE
        ),
        warning = function(w) {
          warn_mcmc <<- c(warn_mcmc, conditionMessage(w))
          invokeRestart("muffleWarning")
        },
        message = function(m) {
          msg_mcmc <<- c(msg_mcmc, conditionMessage(m))
          invokeRestart("muffleMessage")
        }
      )
      if (length(unique(warn_mcmc)) > 0L || length(unique(msg_mcmc)) > 0L) {
        stop(
          sprintf(
            "Example 4 MCMC was not silent at p0=%0.2f. warnings=%s messages=%s",
            p0,
            paste(unique(warn_mcmc), collapse = " | "),
            paste(unique(msg_mcmc), collapse = " | ")
          ),
          call. = FALSE
        )
      }
      if (!identical(fit_mcmc$mh.diagnostics$proposal, "collapsed_slice")) {
        stop(
          sprintf(
            "Example 4 expected collapsed-slice default for static MCMC at p0=%0.2f.",
            p0
          ),
          call. = FALSE
        )
      }
      if (!all(is.finite(as.numeric(fit_mcmc$samp.beta))) ||
          !all(is.finite(as.numeric(fit_mcmc$samp.sigma))) ||
          !all(is.finite(as.numeric(fit_mcmc$samp.gamma)))) {
        stop(
          sprintf("Example 4 MCMC returned non-finite draws at p0=%0.2f.", p0),
          call. = FALSE
        )
      }

      diag_holdout <- exdqlm::diagnostics(
        fit_ldvb, fit_mcmc,
        X = X_holdout,
        y = y_holdout,
        ref = ref_holdout,
        plot = FALSE
      )

      slope_idx <- seq_len(predictor_n) + 1L
      ldvb_beta_full <- as.numeric(diag_holdout$m1.beta.mean)
      ldvb_lb_full <- as.numeric(diag_holdout$m1.beta.lb)
      ldvb_ub_full <- as.numeric(diag_holdout$m1.beta.ub)
      mcmc_beta_full <- as.numeric(diag_holdout$m2.beta.mean)
      mcmc_lb_full <- as.numeric(diag_holdout$m2.beta.lb)
      mcmc_ub_full <- as.numeric(diag_holdout$m2.beta.ub)
      ldvb_beta_slopes <- ldvb_beta_full[slope_idx]
      mcmc_beta_slopes <- mcmc_beta_full[slope_idx]
      ldvb_support <- ex4_support_recovery(ldvb_beta_slopes, beta_slopes)
      mcmc_support <- ex4_support_recovery(mcmc_beta_slopes, beta_slopes)
      ldvb_slope_coverage <- ex4_interval_coverage(ldvb_lb_full[slope_idx], ldvb_ub_full[slope_idx], beta_slopes)
      mcmc_slope_coverage <- ex4_interval_coverage(mcmc_lb_full[slope_idx], mcmc_ub_full[slope_idx], beta_slopes)

      fits[[ex4_p_key(p0)]] <- list(
        p0 = p0,
        y_train = y_train,
        diag_holdout = diag_holdout,
        ldvb = list(
          converged = TRUE,
          iter = as.integer(fit_ldvb$iter),
          stop = fit_ldvb$diagnostics$convergence$stop_reason,
          runtime = as.numeric(fit_ldvb$run.time),
          beta_full = ldvb_beta_full,
          beta_slopes = ldvb_beta_slopes,
          beta_lb_slopes = ldvb_lb_full[slope_idx],
          beta_ub_slopes = ldvb_ub_full[slope_idx],
          active_rmse = sqrt(mean((ldvb_beta_slopes[active_mask] - beta_slopes[active_mask])^2)),
          inactive_mae = mean(abs(ldvb_beta_slopes[!active_mask])),
          holdout_ref_rmse = as.numeric(diag_holdout$m1.ref_rmse),
          holdout_check_loss = as.numeric(diag_holdout$m1.check_loss),
          tau = as.numeric(fit_ldvb$beta_prior$summary$tau),
          zeta2 = as.numeric(fit_ldvb$beta_prior$summary$zeta2),
          support = ldvb_support,
          slope_coverage = ldvb_slope_coverage
        ),
        mcmc = list(
          kernel = fit_mcmc$mh.diagnostics$proposal,
          runtime = as.numeric(fit_mcmc$run.time),
          beta_full = mcmc_beta_full,
          beta_slopes = mcmc_beta_slopes,
          beta_lb_slopes = mcmc_lb_full[slope_idx],
          beta_ub_slopes = mcmc_ub_full[slope_idx],
          active_rmse = sqrt(mean((mcmc_beta_slopes[active_mask] - beta_slopes[active_mask])^2)),
          inactive_mae = mean(abs(mcmc_beta_slopes[!active_mask])),
          holdout_ref_rmse = as.numeric(diag_holdout$m2.ref_rmse),
          holdout_check_loss = as.numeric(diag_holdout$m2.check_loss),
          tau = as.numeric(fit_mcmc$beta_prior$summary$tau),
          zeta2 = as.numeric(fit_mcmc$beta_prior$summary$zeta2),
          support = mcmc_support,
          slope_coverage = mcmc_slope_coverage
        )
      )
    }

    list(
      ok = TRUE,
      seed = as.integer(dataset_seed),
      train_n = train_n,
      holdout_n = holdout_n,
      predictor_n = predictor_n,
      cov_mat = cov_mat,
      cov_rho = cov_rho,
      sigma_eps = sigma_eps,
      beta_slopes = beta_slopes,
      coef_names = coef_names,
      rhs_ctrl = rhs_ctrl,
      p_levels = p_levels,
      fits = fits
    )
  }

  if (isTRUE(stop_on_failure)) {
    return(fit_one_seed())
  }

  tryCatch(
    fit_one_seed(),
    error = function(e) {
      list(
        ok = FALSE,
        seed = as.integer(dataset_seed),
        error = conditionMessage(e)
      )
    }
  )
}

ex4_summary_rows <- function(ex4_obj, cfg_ex4 = NULL) {
  ldvb_n_samp <- if (!is.null(cfg_ex4)) as.integer(cfg_ex4$n_samp %||% NA_integer_) else NA_integer_
  mcmc_n_burn <- if (!is.null(cfg_ex4)) as.integer(cfg_ex4$n_burn %||% NA_integer_) else NA_integer_
  mcmc_n_mcmc <- if (!is.null(cfg_ex4)) as.integer(cfg_ex4$n_mcmc %||% NA_integer_) else NA_integer_
  do.call(
    rbind,
    lapply(names(ex4_obj$fits), function(nm) {
      res <- ex4_obj$fits[[nm]]
      ldvb_cov <- ex4_resolve_slope_coverage(res$ldvb, ex4_obj$beta_slopes)
      mcmc_cov <- ex4_resolve_slope_coverage(res$mcmc, ex4_obj$beta_slopes)
      data.frame(
        p0 = rep(res$p0, 2L),
        method = c("LDVB", "MCMC"),
        runtime_sec = c(res$ldvb$runtime, res$mcmc$runtime),
        active_signal_rmse = c(res$ldvb$active_rmse, res$mcmc$active_rmse),
        inactive_signal_mae = c(res$ldvb$inactive_mae, res$mcmc$inactive_mae),
        holdout_quantile_rmse = c(res$ldvb$holdout_ref_rmse, res$mcmc$holdout_ref_rmse),
        holdout_check_loss = c(res$ldvb$holdout_check_loss, res$mcmc$holdout_check_loss),
        rhs_tau = c(res$ldvb$tau, res$mcmc$tau),
        rhs_zeta2 = c(res$ldvb$zeta2, res$mcmc$zeta2),
        posterior_draws = c(ldvb_n_samp, mcmc_n_mcmc),
        burn_in = c(NA_integer_, mcmc_n_burn),
        ldvb_iter = c(res$ldvb$iter, NA_integer_),
        ldvb_stop = c(res$ldvb$stop, NA_character_),
        truth_interval_cover_n = c(ldvb_cov$n_contains, mcmc_cov$n_contains),
        truth_interval_cover_total = c(ldvb_cov$n_total, mcmc_cov$n_total),
        truth_interval_cover_all = c(ldvb_cov$all_contains, mcmc_cov$all_contains),
        stringsAsFactors = FALSE
      )
    })
  )
}


# ---- ex1_lake_huron ----
need_ex1 <- TRUE
if (!need_ex1) {
  log_msg("Example 1 (Lake Huron): skipped")
} else {
  log_msg("Example 1 (Lake Huron): start")

need_ex1mcmc <- TRUE
need_ex1quants <- TRUE
need_ex1synth <- TRUE
need_ex1kernel <- FALSE
  need_ex1_runtime <- need_ex1mcmc || need_ex1quants
  need_ex1_quants_models <- need_ex1quants || need_ex1_runtime || need_ex1synth
  need_ex1_synthesis <- need_ex1quants || need_ex1synth
  need_ex1_trace_model <- need_ex1mcmc || need_ex1_runtime

  y_ts <- datasets::LakeHuron
  y <- as.numeric(y_ts)
  model <- exdqlm::polytrendMod(order = 2, m0 = c(579, 0), C0 = 10 * diag(2))

  capture_output_file("ex1_model_output.txt", {
    print(model)
  })

  nburn <- as.integer(cfg_run$ex1$n_burn)
  nmcmc <- as.integer(cfg_run$ex1$n_mcmc)
  trace_seed <- as.integer(cfg_run$ex1$trace_seed %||% seed_value)
  nburn_trace <- as.integer(cfg_run$ex1$n_burn_trace %||% nburn)
  nmcmc_trace <- as.integer(cfg_run$ex1$n_mcmc_trace %||% nmcmc)
  thin_trace <- max(1L, as.integer(cfg_run$ex1$thin_trace %||% 1L))
  n_chains_kernel <- as.integer(cfg_run$ex1$n_chains_kernel %||% 4L)
  nburn_kernel <- as.integer(cfg_run$ex1$n_burn_kernel %||% nburn)
  nmcmc_kernel <- as.integer(cfg_run$ex1$n_mcmc_kernel %||% nmcmc)
  thin_kernel_plot <- max(1L, as.integer(cfg_run$ex1$thin_kernel_plot %||% 1L))
  synth_source_draws <- max(50L, as.integer(cfg_run$ex1$synth_source_draws %||% 1000L))
  synth_n_samp <- max(100L, as.integer(cfg_run$ex1$synth_n_samp %||% 1000L))
  forecast_window_start <- as.numeric(cfg_run$ex1$forecast_window_start %||% 1952)
  synth_window_start <- as.numeric(cfg_run$ex1$synth_window_start %||% 1952)

  if (!is.finite(n_chains_kernel) || n_chains_kernel < 2L) {
    stop("Example 1 kernel comparison requires n_chains_kernel >= 2.", call. = FALSE)
  }

  M95 <- NULL
  M50_dqlm <- NULL
  M5 <- NULL
  M50_trace <- NULL
  M95_plot <- NULL
  M50_dqlm_plot <- NULL
  M5_plot <- NULL
  fc95 <- NULL
  fc50 <- NULL
  fc05 <- NULL
  ex1_synthesis <- NULL
  ex1_synthesis_bridge_check <- NULL
  sigma_trace <- NULL
  gamma_trace <- NULL
  thin_idx <- integer(0)
  sigma_trace_thin <- NULL
  gamma_trace_thin <- NULL

  with_local_seed <- function(seed, expr) {
    has_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    old_seed <- if (has_seed) get(".Random.seed", envir = .GlobalEnv, inherits = FALSE) else NULL
    on.exit({
      if (has_seed) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }, add = TRUE)
    set.seed(as.integer(seed))
    eval.parent(substitute(expr))
  }

  synthesis_forecast_origin_check <- function(syn_obs, syn_future, y_ts) {
    ts_xy <- grDevices::xy.coords(y_ts)
    dt_local <- 1 / stats::frequency(y_ts)
    observed_end_time <- tail(ts_xy$x, 1L)
    first_forecast_time <- observed_end_time + dt_local

    data.frame(
      observed_end_time = observed_end_time,
      first_forecast_time = first_forecast_time,
      data_time_step = dt_local,
      time_gap = first_forecast_time - observed_end_time,
      observed_q025 = tail(as.numeric(syn_obs$summary$q025), 1L),
      forecast_q025 = as.numeric(syn_future$summary$q025[1L]),
      q025_jump = as.numeric(syn_future$summary$q025[1L]) - tail(as.numeric(syn_obs$summary$q025), 1L),
      observed_q500 = tail(as.numeric(syn_obs$summary$q500), 1L),
      forecast_q500 = as.numeric(syn_future$summary$q500[1L]),
      q500_jump = as.numeric(syn_future$summary$q500[1L]) - tail(as.numeric(syn_obs$summary$q500), 1L),
      observed_q975 = tail(as.numeric(syn_obs$summary$q975), 1L),
      forecast_q975 = as.numeric(syn_future$summary$q975[1L]),
      q975_jump = as.numeric(syn_future$summary$q975[1L]) - tail(as.numeric(syn_obs$summary$q975), 1L),
      stringsAsFactors = FALSE
    )
  }

  add_synthesis_forecast_bridge <- function(check, band.col, border = NA) {
    graphics::polygon(
      x = c(
        check$observed_end_time,
        check$first_forecast_time,
        check$first_forecast_time,
        check$observed_end_time
      ),
      y = c(
        check$observed_q025,
        check$forecast_q025,
        check$forecast_q975,
        check$observed_q975
      ),
      col = band.col,
      border = border
    )
  }

  ex1_quant_cols <- list(
    q95 = "#8A46B2",
    q95_future = "#C48AE0",
    q50 = "#2F6FA8",
    q50_future = "#8DBFDE",
    q05 = "#2E7D5B",
    q05_future = "#85B89A"
  )

  synth_obs_col <- grDevices::adjustcolor("#F7D6DE", alpha.f = 0.40)
  synth_fore_col <- grDevices::adjustcolor("#D98A9B", alpha.f = 0.38)

  if (need_ex1_quants_models) {
    ex1_quants <- run_step(sprintf("ex1_quants_models_v4_prior579_main_2000_3000_seed%s", seed_value), {
      M95 <- exdqlm::exdqlmMCMC(
        y = y, p0 = 0.95, model = model,
        df = 0.9, dim.df = 2,
        PriorGamma = list(m_gam = -1, s_gam = 0.1, df_gam = 1),
        n.burn = nburn, n.mcmc = nmcmc,
        verbose = FALSE
      )
      M5 <- exdqlm::exdqlmMCMC(
        y = y, p0 = 0.05, model = model,
        df = 0.9, dim.df = 2,
        PriorGamma = list(m_gam = 1, s_gam = 0.1, df_gam = 1),
        n.burn = nburn, n.mcmc = nmcmc,
        verbose = FALSE
      )
      M50_dqlm <- exdqlm::exdqlmMCMC(
        y = y, p0 = 0.50, model = model,
        df = 0.9, dim.df = 2,
        gam.init = 0, fix.gamma = TRUE,
        n.burn = nburn, n.mcmc = nmcmc,
        verbose = FALSE
      )
      list(model = model, M95 = M95, M50_dqlm = M50_dqlm, M5 = M5)
    }, note = sprintf("ex1_quants_models_v4_prior579_main_2000_3000_seed%s", seed_value))

    M95 <- ex1_quants$M95
    M50_dqlm <- ex1_quants$M50_dqlm
    M5 <- ex1_quants$M5

    M95_plot <- M95
    M50_dqlm_plot <- M50_dqlm
    M5_plot <- M5
    M95_plot$y <- y_ts
    M50_dqlm_plot$y <- y_ts
    M5_plot$y <- y_ts
  }

  if (need_ex1_trace_model) {
    trace_step_id <- sprintf(
      "ex1_trace_model_v10_prior579_slice_vbinit_b%d_m%d_seed%s",
      nburn_trace,
      nmcmc_trace,
      trace_seed
    )
    ex1_trace <- run_step(trace_step_id, {
      M50_trace <- with_local_seed(trace_seed, {
        exdqlm::exdqlmMCMC(
          y = y, p0 = 0.50, model = model,
          df = 0.9, dim.df = 2,
          PriorGamma = list(m_gam = 0, s_gam = 0.1, df_gam = 1),
          init.from.vb = TRUE,
          vb_init_controls = list(method = "ldvb", verbose = FALSE),
          mh.proposal = "slice",
          n.burn = nburn_trace, n.mcmc = nmcmc_trace,
          verbose = FALSE
        )
      })
      list(M50_trace = M50_trace)
    }, note = trace_step_id)

    M50_trace <- ex1_trace$M50_trace
    sigma_trace <- as.numeric(M50_trace$samp.sigma)
    gamma_trace <- as.numeric(M50_trace$samp.gamma)
    thin_idx <- seq.int(1L, length(sigma_trace), by = thin_trace)
    sigma_trace_thin <- coda::mcmc(sigma_trace[thin_idx], thin = thin_trace)
    gamma_trace_thin <- coda::mcmc(gamma_trace[thin_idx], thin = thin_trace)
  }

  fFF <- model$FF
  fGG <- model$GG
  k_fore <- 8L
  t_end <- tail(grDevices::xy.coords(y_ts)$x, 1L)
  dt <- 1 / stats::frequency(y_ts)
  xlim_fore <- c(forecast_window_start, t_end + k_fore * dt)
  xlim_synth_obs <- c(synth_window_start, t_end)

  if (need_ex1_quants_models) {
    fc95 <- forecast_from_fit(
      start.t = length(y), k = k_fore, m1 = M95_plot,
      fFF = fFF, fGG = fGG, plot = FALSE, y_data = y_ts,
      return.draws = TRUE, n.samp = synth_source_draws, seed = seed_value + 195L
    )
    fc50 <- forecast_from_fit(
      start.t = length(y), k = k_fore, m1 = M50_dqlm_plot,
      fFF = fFF, fGG = fGG, plot = FALSE, y_data = y_ts,
      return.draws = TRUE, n.samp = synth_source_draws, seed = seed_value + 250L
    )
    fc05 <- forecast_from_fit(
      start.t = length(y), k = k_fore, m1 = M5_plot,
      fFF = fFF, fGG = fGG, plot = FALSE, y_data = y_ts,
      return.draws = TRUE, n.samp = synth_source_draws, seed = seed_value + 305L
    )
  }

  if (need_ex1_runtime) {
    capture_output_file("ex1_run_summary.txt", {
      cat(sprintf("settings=%s\n", selected_run))
      cat(sprintf("quantile run settings: n.burn=%d, n.mcmc=%d\n", nburn, nmcmc))
      cat(sprintf("trace run settings: seed=%d, n.burn=%d, n.mcmc=%d, thin=%d, saved_for_plot=%d\n\n", trace_seed, nburn_trace, nmcmc_trace, thin_trace, length(thin_idx)))
      cat("M50_trace sigma summary:\n")
      print(summary(sigma_trace))
      cat("\nM50_trace sigma summary (thinned chain used in ex1mcmc.png):\n")
      print(summary(as.numeric(sigma_trace_thin)))
      cat("\nM50_trace gamma summary:\n")
      print(summary(gamma_trace))
      cat("\nM50_trace gamma summary (thinned chain used in ex1mcmc.png):\n")
      print(summary(as.numeric(gamma_trace_thin)))
      cat("\nM50_trace joint posterior summary:\n")
      print(data.frame(
        parameter = c("sigma", "gamma"),
        mean = c(mean(sigma_trace), mean(gamma_trace)),
        q025 = c(as.numeric(stats::quantile(sigma_trace, 0.025)),
                 as.numeric(stats::quantile(gamma_trace, 0.025))),
        median = c(stats::median(sigma_trace), stats::median(gamma_trace)),
        q975 = c(as.numeric(stats::quantile(sigma_trace, 0.975)),
                 as.numeric(stats::quantile(gamma_trace, 0.975)))
      ))
      cat("\nM50_dqlm gamma fixed:\n")
      print(if (length(M50_dqlm$samp.gamma)) unique(as.numeric(M50_dqlm$samp.gamma)) else 0)
      cat("\nBackend metadata (trace model):\n")
      print(M50_trace$backend)
      cat("\nRun times (seconds):\n")
      print(c(M95 = M95$run.time, M50_trace = M50_trace$run.time, M5 = M5$run.time, M50_dqlm = M50_dqlm$run.time))
    })
  }

  if (need_ex1mcmc) {
    save_png_plot("ex1mcmc.png", {
      graphics::par(mfcol = c(2, 2), mar = c(4.1, 4.1, 2.1, 1.0))
      coda::traceplot(sigma_trace_thin, main = "sigma trace")
      coda::densplot(sigma_trace_thin, main = "sigma density")
      coda::traceplot(gamma_trace_thin, main = "gamma trace")
      coda::densplot(gamma_trace_thin, main = "gamma density")
    }, width = 8.2, height = 5.8, pointsize = 13)
  }

  if (need_ex1_synthesis) {
    ex1_synthesis <- run_step(sprintf("ex1_synthesis_v6_prior579_s3_plot_seed%s", seed_value), {
      syn_obs <- with_local_seed(seed_value + 111L, {
        exdqlm::quantileSynthesis(
          draws_list = list(M5, M50_dqlm, M95),
          p = c(0.05, 0.50, 0.95),
          enforce_isotonic = TRUE,
          rearrange = TRUE,
          T_expected = length(y),
          n_samp = synth_n_samp,
          seed = seed_value + 111L
        )
      })

      syn_future <- with_local_seed(seed_value + 333L, {
        exdqlm::quantileSynthesis(
          draws_list = list(fc05, fc50, fc95),
          p = c(0.05, 0.50, 0.95),
          enforce_isotonic = TRUE,
          rearrange = TRUE,
          T_expected = k_fore,
          n_samp = synth_n_samp,
          seed = seed_value + 333L
        )
      })

      list(
        syn_obs = syn_obs,
        syn_future = syn_future
      )
    }, note = sprintf("ex1_synthesis_v6_prior579_s3_plot_seed%s", seed_value))

    ex1_synthesis_bridge_check <- synthesis_forecast_origin_check(
      ex1_synthesis$syn_obs,
      ex1_synthesis$syn_future,
      y_ts
    )
    save_table_csv(
      ex1_synthesis_bridge_check,
      filename = "ex1_synthesis_bridge_check.csv",
      output_id = "tab_ex1_synthesis_bridge",
      manuscript_label = "auxiliary: Example 1 synthesis forecast-origin check",
      notes = "Checks that the forecast synthesis begins one Lake Huron time step after the observed-period synthesis endpoint; Figure 2(d) uses these endpoints for the visual interval bridge."
    )
  }

  if (need_ex1quants) {
    save_png_plot("ex1quants.png", {
      ts_xy <- grDevices::xy.coords(y_ts)
      idx_obs_synth <- time_window_to_index(y_ts, synth_window_start, t_end)
      idx_obs <- idx_obs_synth[1]:idx_obs_synth[2]
      x_obs_full <- ts_xy$x
      x_future <- seq(from = t_end, by = dt, length.out = k_fore + 1L)
      x_future_fore <- x_future[-1L]

      obs_q025_full <- ex1_synthesis$syn_obs$summary$q025
      obs_q975_full <- ex1_synthesis$syn_obs$summary$q975
      fut_q025 <- ex1_synthesis$syn_future$summary$q025
      fut_q975 <- ex1_synthesis$syn_future$summary$q975

      y_lim_obs_synth <- range(
        y[idx_obs],
        obs_q025_full[idx_obs], obs_q975_full[idx_obs],
        na.rm = TRUE
      )
      y_lim_zoom_synth <- range(
        y[time_window_to_index(y_ts, forecast_window_start, t_end)[1]:length(y)],
        obs_q025_full[time_window_to_index(y_ts, forecast_window_start, t_end)[1]:length(y)],
        obs_q975_full[time_window_to_index(y_ts, forecast_window_start, t_end)[1]:length(y)],
        fut_q025, fut_q975,
        na.rm = TRUE
      )

      graphics::par(mfrow = c(2, 2), mar = c(4.4, 4.1, 2.2, 1.2), oma = c(0, 0, 0.8, 0))

      plot(M95_plot, col = ex1_quant_cols$q95)
      plot(M50_dqlm_plot, add = TRUE, col = ex1_quant_cols$q50)
      plot(M5_plot, add = TRUE, col = ex1_quant_cols$q05)
      graphics::legend(
        "topright",
        lty = 1, col = c(ex1_quant_cols$q95, ex1_quant_cols$q50, ex1_quant_cols$q05),
        legend = c(expression("p"[0] == 0.95), expression("p"[0] == 0.50), expression("p"[0] == 0.05)),
        bty = "n"
      )
      graphics::title(main = "(a) Dynamic quantiles", cex.main = 0.95)

      stats::plot.ts(y_ts, xlim = xlim_fore, ylim = c(575, 581), col = "dark grey", ylab = "quantile forecast")
      plot(fc95, add = TRUE, cols = c(ex1_quant_cols$q95, ex1_quant_cols$q95_future))
      plot(fc50, add = TRUE, cols = c(ex1_quant_cols$q50, ex1_quant_cols$q50_future))
      plot(fc05, add = TRUE, cols = c(ex1_quant_cols$q05, ex1_quant_cols$q05_future))
      graphics::title(main = "(b) Forecasted quantiles", cex.main = 0.95)

      plot(
        ex1_synthesis$syn_obs,
        y = y_ts,
        time = x_obs_full,
        xlim = xlim_synth_obs,
        ylim = y_lim_obs_synth,
        show.median = FALSE,
        band.col = synth_obs_col,
        y.col = grDevices::adjustcolor("grey30", alpha.f = 0.62),
        ylab = "predictive synthesis",
        main = "(c) Observed-period synthesis"
      )
      graphics::legend(
        "bottomleft",
        legend = c("Synthesized posterior predictive interval (95%)"),
        fill = c(synth_obs_col),
        border = c(NA),
        lty = c(NA),
        lwd = c(NA),
        col = c(NA),
        bty = "n",
        bg = grDevices::adjustcolor("white", alpha.f = 0.82),
        cex = 0.68,
        y.intersp = 0.82,
        x.intersp = 0.9,
        inset = c(0.015, 0.015)
      )

      plot(
        ex1_synthesis$syn_obs,
        y = y_ts,
        time = x_obs_full,
        xlim = xlim_fore,
        ylim = y_lim_zoom_synth,
        show.median = FALSE,
        band.col = synth_obs_col,
        y.col = grDevices::adjustcolor("grey30", alpha.f = 0.62),
        ylab = "predictive synthesis",
        main = "(d) Forecast synthesis"
      )
      add_synthesis_forecast_bridge(
        ex1_synthesis_bridge_check,
        band.col = synth_fore_col
      )
      plot(
        ex1_synthesis$syn_future,
        time = x_future_fore,
        add = TRUE,
        show.median = FALSE,
        band.col = synth_fore_col
      )
      graphics::abline(v = t_end, lty = 3, col = "grey45")
      graphics::legend(
        "bottomleft",
        legend = c("Observed-period synthesis (95%)", "Forecast synthesis (95%)"),
        fill = c(synth_obs_col, synth_fore_col),
        border = c(NA, NA),
        lty = c(NA, NA),
        lwd = c(NA, NA),
        col = c(NA, NA),
        bty = "o",
        bg = grDevices::adjustcolor("white", alpha.f = 0.86),
        box.lty = 0,
        cex = 0.66,
        y.intersp = 0.82,
        x.intersp = 0.9,
        inset = c(0.015, 0.025)
      )
    }, width = 9.2, height = 6.3, pointsize = 12.5)
  }

  if (need_ex1synth) {
    capture_output_file("ex1_synthesis_summary.txt", {
      cat(sprintf("settings=%s\n", selected_run))
      cat(sprintf("source_draws=%d | synthesized_draws=%d\n", synth_source_draws, synth_n_samp))
      cat(sprintf("window_start=%s | forecast_horizon=%d\n\n", format(synth_window_start), k_fore))
      cat("Forecast-origin synthesis alignment:\n")
      print(ex1_synthesis_bridge_check)
      cat("\n")
      cat("Observed-period synthesis summary:\n")
      print(summary(ex1_synthesis$syn_obs$summary$q500))
      cat("\nForecast-period synthesis summary:\n")
      print(summary(ex1_synthesis$syn_future$summary$q500))
    })

    save_png_plot("ex1synth.png", {
      ts_xy <- grDevices::xy.coords(y_ts)
      idx_window <- time_window_to_index(y_ts, synth_window_start, t_end)
      idx_obs <- idx_window[1]:idx_window[2]
      x_obs_full <- ts_xy$x
      x_future <- seq(from = t_end, by = dt, length.out = k_fore + 1L)
      x_future_fore <- x_future[-1L]

      obs_q025_full <- ex1_synthesis$syn_obs$summary$q025
      obs_q975_full <- ex1_synthesis$syn_obs$summary$q975

      fut_q025 <- ex1_synthesis$syn_future$summary$q025
      fut_q975 <- ex1_synthesis$syn_future$summary$q975

      y_lim <- range(
        y[idx_obs],
        obs_q025_full[idx_obs], obs_q975_full[idx_obs],
        fut_q025, fut_q975,
        na.rm = TRUE
      )

      plot(
        ex1_synthesis$syn_obs,
        y = y_ts,
        time = x_obs_full,
        xlim = xlim_fore,
        ylim = y_lim,
        show.median = FALSE,
        band.col = synth_obs_col,
        y.col = grDevices::adjustcolor("grey30", alpha.f = 0.62),
        ylab = "predictive synthesis"
      )
      add_synthesis_forecast_bridge(
        ex1_synthesis_bridge_check,
        band.col = synth_fore_col
      )
      plot(
        ex1_synthesis$syn_future,
        time = x_future_fore,
        add = TRUE,
        show.median = FALSE,
        band.col = synth_fore_col
      )
      graphics::abline(v = t_end, lty = 3, col = "grey45")

      graphics::legend(
        "bottomleft",
        legend = c("Observed-period synthesis (95%)", "Forecast synthesis (95%)"),
        fill = c(synth_obs_col, synth_fore_col),
        border = c(NA, NA),
        lty = c(NA, NA),
        lwd = c(NA, NA),
        col = c(NA, NA),
        bty = "o",
        bg = grDevices::adjustcolor("white", alpha.f = 0.86),
        box.lty = 0,
        cex = 0.66,
        y.intersp = 0.82,
        x.intersp = 0.9,
        inset = c(0.015, 0.025)
      )
    })
  }

  if (need_ex1kernel) {
    compact_kernel_fit <- function(fit, kernel, seed) {
      list(
        kernel = kernel,
        seed = as.integer(seed),
        run_time = as.numeric(fit$run.time),
        sigma = as.numeric(fit$samp.sigma),
        gamma = as.numeric(fit$samp.gamma),
        accept_total = as.numeric(fit$accept.rate),
        accept_burn = as.numeric(fit$accept.rate.burn),
        accept_keep = as.numeric(fit$accept.rate.keep),
        vb_init_method = fit$vb.init.method %||% NA_character_,
        backend = fit$backend,
        mh = list(
          proposal = fit$mh.diagnostics$proposal,
          scale_final = fit$mh.diagnostics$scale_final,
          slice_width = fit$mh.diagnostics$slice_width,
          slice_max_steps = fit$mh.diagnostics$slice_max_steps,
          laplace_refresh = fit$mh.diagnostics$laplace_refresh
        )
      )
    }

    safe_rhat <- function(x) {
      out <- tryCatch(
        coda::gelman.diag(x, autoburnin = FALSE)$psrf[1, "Point est."],
        error = function(e) NA_real_
      )
      as.numeric(out)
    }

    safe_ess <- function(x) {
      out <- tryCatch(coda::effectiveSize(x), error = function(e) NA_real_)
      out <- as.numeric(out)
      if (!length(out)) return(NA_real_)
      out[[1L]]
    }

    build_kernel_diag <- function(compact_fits) {
      sigma_list <- coda::mcmc.list(lapply(compact_fits, function(f) coda::as.mcmc(f$sigma)))
      gamma_list <- coda::mcmc.list(lapply(compact_fits, function(f) coda::as.mcmc(f$gamma)))

      chain_rows <- do.call(rbind, lapply(seq_along(compact_fits), function(i) {
        fit_i <- compact_fits[[i]]
        data.frame(
          kernel = fit_i$kernel,
          chain = i,
          seed = fit_i$seed,
          runtime_sec = fit_i$run_time,
          sigma_mean = mean(fit_i$sigma),
          sigma_q025 = as.numeric(stats::quantile(fit_i$sigma, 0.025)),
          sigma_q975 = as.numeric(stats::quantile(fit_i$sigma, 0.975)),
          gamma_mean = mean(fit_i$gamma),
          gamma_q025 = as.numeric(stats::quantile(fit_i$gamma, 0.025)),
          gamma_q975 = as.numeric(stats::quantile(fit_i$gamma, 0.975)),
          accept_total = fit_i$accept_total,
          accept_burn = fit_i$accept_burn,
          accept_keep = fit_i$accept_keep,
          vb_init_method = fit_i$vb_init_method,
          stringsAsFactors = FALSE
        )
      }))

      pooled_sigma <- unlist(lapply(compact_fits, `[[`, "sigma"), use.names = FALSE)
      pooled_gamma <- unlist(lapply(compact_fits, `[[`, "gamma"), use.names = FALSE)
      summary_row <- data.frame(
        kernel = compact_fits[[1L]]$kernel,
        n_chains = length(compact_fits),
        n_burn = nburn_kernel,
        n_mcmc = nmcmc_kernel,
        runtime_total_sec = sum(chain_rows$runtime_sec),
        runtime_mean_sec = mean(chain_rows$runtime_sec),
        sigma_mean = mean(pooled_sigma),
        sigma_q025 = as.numeric(stats::quantile(pooled_sigma, 0.025)),
        sigma_q975 = as.numeric(stats::quantile(pooled_sigma, 0.975)),
        gamma_mean = mean(pooled_gamma),
        gamma_q025 = as.numeric(stats::quantile(pooled_gamma, 0.025)),
        gamma_q975 = as.numeric(stats::quantile(pooled_gamma, 0.975)),
        sigma_rhat = safe_rhat(sigma_list),
        gamma_rhat = safe_rhat(gamma_list),
        sigma_ess = safe_ess(sigma_list),
        gamma_ess = safe_ess(gamma_list),
        chain_mean_sigma_sd = stats::sd(chain_rows$sigma_mean),
        chain_mean_gamma_sd = stats::sd(chain_rows$gamma_mean),
        accept_total_mean = mean(chain_rows$accept_total, na.rm = TRUE),
        accept_total_min = suppressWarnings(min(chain_rows$accept_total, na.rm = TRUE)),
        accept_total_max = suppressWarnings(max(chain_rows$accept_total, na.rm = TRUE)),
        vb_init_method = compact_fits[[1L]]$vb_init_method,
        stringsAsFactors = FALSE
      )
      if (!all(is.finite(chain_rows$accept_total))) {
        summary_row$accept_total_mean <- NA_real_
        summary_row$accept_total_min <- NA_real_
        summary_row$accept_total_max <- NA_real_
      }

      list(
        fits = compact_fits,
        sigma_list = sigma_list,
        gamma_list = gamma_list,
        chain_rows = chain_rows,
        summary_row = summary_row
      )
    }

    run_kernel_multichain <- function(kernel, seeds) {
      fits <- vector("list", length(seeds))
      for (i in seq_along(seeds)) {
        set.seed(seeds[[i]])
        fit_i <- exdqlm::exdqlmMCMC(
          y = y, p0 = 0.50, model = model,
          df = 0.9, dim.df = 2,
          PriorGamma = list(m_gam = 0, s_gam = 0.1, df_gam = 1),
          n.burn = nburn_kernel, n.mcmc = nmcmc_kernel,
          init.from.vb = TRUE,
          vb_init_controls = list(method = "ldvb", verbose = FALSE),
          mh.proposal = kernel,
          trace.diagnostics = FALSE,
          verbose = FALSE
        )
        fits[[i]] <- compact_kernel_fit(fit_i, kernel = kernel, seed = seeds[[i]])
      }
      build_kernel_diag(fits)
    }

    ex1_kernel <- run_step("ex1_kernel_compare_v4_prior579_free_sigma_longer", {
      slice_seeds <- seed_value + 1100L + seq_len(n_chains_kernel)
      laplace_seeds <- seed_value + 1200L + seq_len(n_chains_kernel)
      list(
        slice = run_kernel_multichain("slice", slice_seeds),
        laplace_rw = run_kernel_multichain("laplace_rw", laplace_seeds)
      )
    }, note = "ex1_kernel_compare_v4_prior579_free_sigma_longer")

    kernel_summary <- do.call(
      rbind,
      list(ex1_kernel$slice$summary_row, ex1_kernel$laplace_rw$summary_row)
    )
    kernel_chain_stability <- do.call(
      rbind,
      list(ex1_kernel$slice$chain_rows, ex1_kernel$laplace_rw$chain_rows)
    )

    speed_row <- merge(
      subset(kernel_summary, kernel == "slice")[, c("runtime_mean_sec", "runtime_total_sec")],
      subset(kernel_summary, kernel == "laplace_rw")[, c("runtime_mean_sec", "runtime_total_sec")],
      by = NULL,
      suffixes = c(".slice", ".laplace_rw")
    )
    kernel_compare_note <- sprintf(
      paste(
        "Lake Huron median kernel comparison: slice vs laplace_rw.",
        "Mean runtime ratio (laplace_rw / slice) = %0.3f.",
        "sigma Rhat: slice=%0.3f, laplace_rw=%0.3f.",
        "gamma Rhat: slice=%0.3f, laplace_rw=%0.3f.",
        "sigma ESS: slice=%0.1f, laplace_rw=%0.1f.",
        "gamma ESS: slice=%0.1f, laplace_rw=%0.1f."
      ),
      speed_row$runtime_mean_sec.laplace_rw / speed_row$runtime_mean_sec.slice,
      kernel_summary$sigma_rhat[kernel_summary$kernel == "slice"],
      kernel_summary$sigma_rhat[kernel_summary$kernel == "laplace_rw"],
      kernel_summary$gamma_rhat[kernel_summary$kernel == "slice"],
      kernel_summary$gamma_rhat[kernel_summary$kernel == "laplace_rw"],
      kernel_summary$sigma_ess[kernel_summary$kernel == "slice"],
      kernel_summary$sigma_ess[kernel_summary$kernel == "laplace_rw"],
      kernel_summary$gamma_ess[kernel_summary$kernel == "slice"],
      kernel_summary$gamma_ess[kernel_summary$kernel == "laplace_rw"]
    )

    capture_output_file("ex1_kernel_compare_summary.txt", {
      cat(sprintf("settings=%s\n", selected_run))
      cat(sprintf("n.chains=%d, n.burn=%d, n.mcmc=%d, thin.plot=%d\n\n", n_chains_kernel, nburn_kernel, nmcmc_kernel, thin_kernel_plot))
      cat("Kernel summary:\n")
      print(kernel_summary)
      cat("\nPer-chain posterior stability summary:\n")
      print(kernel_chain_stability)
      cat("\nGelman diagnostics (sigma):\n")
      print(coda::gelman.diag(ex1_kernel$slice$sigma_list, autoburnin = FALSE))
      print(coda::gelman.diag(ex1_kernel$laplace_rw$sigma_list, autoburnin = FALSE))
      cat("\nGelman diagnostics (gamma):\n")
      print(coda::gelman.diag(ex1_kernel$slice$gamma_list, autoburnin = FALSE))
      print(coda::gelman.diag(ex1_kernel$laplace_rw$gamma_list, autoburnin = FALSE))
      cat("\nEffective sample sizes:\n")
      cat(sprintf("slice sigma=%0.2f gamma=%0.2f\n", ex1_kernel$slice$summary_row$sigma_ess, ex1_kernel$slice$summary_row$gamma_ess))
      cat(sprintf("laplace_rw sigma=%0.2f gamma=%0.2f\n", ex1_kernel$laplace_rw$summary_row$sigma_ess, ex1_kernel$laplace_rw$summary_row$gamma_ess))
      cat("\nNarrative note:\n")
      cat(kernel_compare_note, "\n")
    })

    save_table_csv(
      kernel_summary,
      filename = "ex1_kernel_summary.csv",
      output_id = "tab_ex1_kernel_summary",
      manuscript_label = "auxiliary: Example 1 kernel summary",
      status = "reproduced",
      notes = "Pooled sigma/gamma posterior, runtime, Rhat, and ESS summaries for free-sigma slice and laplace_rw fits."
    )

    save_table_csv(
      kernel_chain_stability,
      filename = "ex1_kernel_chain_stability.csv",
      output_id = "tab_ex1_kernel_chain_stability",
      manuscript_label = "auxiliary: Example 1 kernel chain stability",
      status = "reproduced",
      notes = "Per-chain sigma/gamma posterior summaries, runtimes, and acceptance diagnostics."
    )

    save_png_plot("ex1_kernel_compare.png", {
      chain_cols <- c("#0072B2", "#D55E00", "#009E73", "#CC79A7")
      sigma_range <- range(
        unlist(lapply(c(ex1_kernel$slice$fits, ex1_kernel$laplace_rw$fits), `[[`, "sigma"), use.names = FALSE),
        finite = TRUE
      )
      gamma_range <- range(
        unlist(lapply(c(ex1_kernel$slice$fits, ex1_kernel$laplace_rw$fits), `[[`, "gamma"), use.names = FALSE),
        finite = TRUE
      )

      plot_kernel_traces <- function(diag_obj, param, ylab, ylim, main, subtitle = NULL) {
        iter <- seq_len(length(diag_obj$fits[[1L]][[param]]))
        trace_mat <- do.call(cbind, lapply(diag_obj$fits, `[[`, param))
        graphics::matplot(
          iter,
          trace_mat,
          type = "l",
          lty = 1,
          lwd = 1,
          col = chain_cols[seq_len(ncol(trace_mat))],
          xlab = "kept iteration",
          ylab = ylab,
          ylim = ylim,
          main = main,
          sub = subtitle
        )
        graphics::legend(
          "topright",
          legend = sprintf("chain %d", seq_len(ncol(trace_mat))),
          col = chain_cols[seq_len(ncol(trace_mat))],
          lty = 1,
          bty = "n", cex = 0.8
        )
      }

      graphics::par(mfrow = c(2, 2))
      plot_kernel_traces(
        ex1_kernel$slice,
        param = "sigma",
        ylab = expression(sigma),
        ylim = sigma_range,
        main = "slice: sigma traces",
        subtitle = sprintf("mean runtime %.2fs, Rhat %.3f, ESS %.1f",
                           ex1_kernel$slice$summary_row$runtime_mean_sec,
                           ex1_kernel$slice$summary_row$sigma_rhat,
                           ex1_kernel$slice$summary_row$sigma_ess)
      )
      plot_kernel_traces(
        ex1_kernel$laplace_rw,
        param = "sigma",
        ylab = expression(sigma),
        ylim = sigma_range,
        main = "laplace_rw: sigma traces",
        subtitle = sprintf("mean runtime %.2fs, Rhat %.3f, ESS %.1f, accept %.3f",
                           ex1_kernel$laplace_rw$summary_row$runtime_mean_sec,
                           ex1_kernel$laplace_rw$summary_row$sigma_rhat,
                           ex1_kernel$laplace_rw$summary_row$sigma_ess,
                           ex1_kernel$laplace_rw$summary_row$accept_total_mean)
      )
      plot_kernel_traces(
        ex1_kernel$slice,
        param = "gamma",
        ylab = expression(gamma),
        ylim = gamma_range,
        main = "slice: gamma traces",
        subtitle = sprintf("Rhat %.3f, ESS %.1f",
                           ex1_kernel$slice$summary_row$gamma_rhat,
                           ex1_kernel$slice$summary_row$gamma_ess)
      )
      plot_kernel_traces(
        ex1_kernel$laplace_rw,
        param = "gamma",
        ylab = expression(gamma),
        ylim = gamma_range,
        main = "laplace_rw: gamma traces",
        subtitle = sprintf("Rhat %.3f, ESS %.1f, accept %.3f",
                           ex1_kernel$laplace_rw$summary_row$gamma_rhat,
                           ex1_kernel$laplace_rw$summary_row$gamma_ess,
                           ex1_kernel$laplace_rw$summary_row$accept_total_mean)
      )
    })

  }

  if (need_ex1_runtime) {
    ex1_runtime <- data.frame(
      model = c("M95", "M50_trace", "M5", "M50_dqlm"),
      run_time_seconds = c(M95$run.time, M50_trace$run.time, M5$run.time, M50_dqlm$run.time)
    )
    save_table_csv(
      ex1_runtime,
      filename = "ex1_runtime_summary.csv",
      output_id = "tab_ex1_runtime",
      manuscript_label = "Example 1 runtime statements",
      status = "approximate",
      notes = "Runtimes vary by hardware/settings; trace run intentionally uses higher iterations."
    )

  }

  log_msg("Example 1 (Lake Huron): complete")
}

# ---- ex2_sunspots ----
need_ex2 <- TRUE
if (!need_ex2) {
  log_msg("Example 2 (Sunspots): skipped")
} else {
  log_msg("Example 2 (Sunspots): start")

need_ex2quant <- TRUE
need_ex2quant_ldvb <- TRUE
need_ex2checks <- TRUE
need_ex2checks_ldvb <- TRUE
need_ex2benchmark <- TRUE
need_ex2_ldvb_diag <- TRUE
need_ex2_tables <- TRUE
need_ex2_tables_ldvb <- TRUE
  need_ex2_ldvb_core <- any(c(
    need_ex2quant, need_ex2quant_ldvb,
    need_ex2checks, need_ex2checks_ldvb,
    need_ex2_ldvb_diag, need_ex2_tables_ldvb
  ))

  full_y_ts <- datasets::sunspot.year
  n_obs <- as.integer(cfg_run$ex2$n_obs %||% length(full_y_ts))
  if (is.finite(n_obs) && n_obs > 0L && n_obs < length(full_y_ts)) {
    y_ts <- stats::ts(
      utils::tail(as.numeric(full_y_ts), n_obs),
      end = stats::end(full_y_ts),
      frequency = stats::frequency(full_y_ts)
    )
  } else {
    y_ts <- full_y_ts
  }
  y <- as.numeric(y_ts)
  sunspot_level_prior <- 50
  sunspot_level_c0 <- 2500

  dlm_trend_comp <- dlm::dlmModPoly(1, m0 = sunspot_level_prior, C0 = sunspot_level_c0)
  trend_comp <- exdqlm::as.exdqlm(dlm_trend_comp)
  seas_comp <- exdqlm::seasMod(p = 11, h = 1:4, C0 = 10 * diag(8))
  model <- trend_comp + seas_comp

  capture_output_file("ex2_model_output.txt", {
    cat("Combined GG matrix:\n")
    print(model$GG)
  })

  n_samp <- as.integer(cfg_run$ex2$n_samp)
  tol <- as.numeric(cfg_run$ex2$tol)
  ldvb_diag_tol <- as.numeric(cfg_run$ex2$ldvb_diag_tol %||% tol)
  ldvb_diag_n_samp <- as.integer(cfg_run$ex2$ldvb_diag_n_samp %||% n_samp)
  ldvb_max_iter <- as.integer(cfg_run$ex2$ldvb_max_iter %||% 200L)
  benchmark_n_burn <- as.integer(cfg_run$ex2$benchmark_n_burn %||% 1000L)
  benchmark_n_mcmc <- as.integer(cfg_run$ex2$benchmark_n_mcmc %||% 300L)
  df_grid <- as.numeric(cfg_run$ex2$df_grid)

  fit_ok <- function(x) !is.null(x) && !inherits(x, "error")
  M_sigma_ldvb <- M1_ldvb <- M2_ldvb <- NULL

  if (need_ex2_ldvb_core) {
    ex2_core_ldvb <- run_step(
      sprintf("ex2_core_models_ldvb_nsamp%d_tol%s_v6_sig2_prior50", n_samp, format(tol)),
      {
      set.seed(20262600)
      M_sigma_ldvb <- tryCatch(
        exdqlm::exdqlmLDVB(
          y = y_ts, p0 = 0.85, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          dqlm.ind = TRUE, fix.sigma = FALSE,
          n.samp = n_samp, tol = tol,
          vb_control = list(max_iter = ldvb_max_iter),
          verbose = FALSE
        ),
        error = function(e) e
      )

      set.seed(20262601)
      M1_ldvb <- tryCatch(
        exdqlm::exdqlmLDVB(
          y = y_ts, p0 = 0.85, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          dqlm.ind = TRUE, sig.init = 2, fix.sigma = FALSE,
          n.samp = n_samp, tol = tol,
          vb_control = list(max_iter = ldvb_max_iter),
          verbose = FALSE
        ),
        error = function(e) e
      )

      set.seed(20262602)
      M2_ldvb <- tryCatch(
        exdqlm::exdqlmLDVB(
          y = y_ts, p0 = 0.85, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          sig.init = 2, fix.sigma = FALSE,
          n.samp = n_samp, tol = tol,
          vb_control = list(max_iter = ldvb_max_iter),
          verbose = FALSE
        ),
        error = function(e) e
      )

      list(M_sigma_ldvb = M_sigma_ldvb, M1_ldvb = M1_ldvb, M2_ldvb = M2_ldvb)
    }, note = sprintf("ex2_core_models_ldvb_nsamp%d_tol%s_v6_sig2_prior50", n_samp, format(tol)))
    M_sigma_ldvb <- ex2_core_ldvb$M_sigma_ldvb
    M1_ldvb <- ex2_core_ldvb$M1_ldvb
    M2_ldvb <- ex2_core_ldvb$M2_ldvb
  }

  ex2_ldvb_pair_ok <- fit_ok(M1_ldvb) && fit_ok(M2_ldvb)

  capture_output_file("ex2_run_summary.txt", {
    cat(sprintf("settings=%s\n", selected_run))
    cat(sprintf("level_prior_m0=%s, level_prior_C0=%s\n", sunspot_level_prior, sunspot_level_c0))
    cat(sprintf("n.samp=%d, tol=%s, ldvb_max_iter=%d\n\n", n_samp, format(tol), ldvb_max_iter))
    if (fit_ok(M_sigma_ldvb)) {
      cat("Summary(M_sigma_ldvb$samp.sigma):\n")
      print(summary(M_sigma_ldvb$samp.sigma))
    }
    cat("\nRuntime seconds:\n")
    rt <- c()
    if (fit_ok(M_sigma_ldvb)) rt <- c(rt, M_sigma_ldvb = M_sigma_ldvb$run.time)
    if (fit_ok(M1_ldvb)) rt <- c(rt, M1_ldvb = M1_ldvb$run.time)
    if (fit_ok(M2_ldvb)) rt <- c(rt, M2_ldvb = M2_ldvb$run.time)
    print(rt)
    if (!fit_ok(M_sigma_ldvb)) {
      cat("\nLDVB status M_sigma: failed\n")
      cat(M_sigma_ldvb$message, "\n")
    }
    if (!fit_ok(M1_ldvb)) {
      cat("\nLDVB status M1: failed\n")
      cat(M1_ldvb$message, "\n")
    }
    if (fit_ok(M2_ldvb)) {
      cat("\nLDVB status: success\n")
      cat("Summary(M2_ldvb$samp.gamma):\n")
      print(summary(M2_ldvb$samp.gamma))
    } else {
      cat("\nLDVB status M2: failed\n")
      cat(M2_ldvb$message, "\n")
    }
  })

  if (need_ex2benchmark && ex2_ldvb_pair_ok) {
    benchmark_step_id <- sprintf(
      "ex2_dynamic_benchmark_%s_nsamp%d_b%d_k%d_v6_sig2_prior50",
      selected_benchmark_setting,
      n_samp,
      benchmark_n_burn,
      benchmark_n_mcmc
    )
    ex2_benchmark <- run_step(benchmark_step_id, {
      set.seed(20262801)
      M1_mcmc <- with_backend_settings(selected_benchmark_setting, {
        exdqlm::exdqlmMCMC(
          y = y_ts, p0 = 0.85, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          dqlm.ind = TRUE, fix.sigma = FALSE,
          n.burn = benchmark_n_burn, n.mcmc = benchmark_n_mcmc,
          verbose = FALSE
        )
      })

      set.seed(20262802)
      M2_mcmc <- with_backend_settings(selected_benchmark_setting, {
        exdqlm::exdqlmMCMC(
          y = y_ts, p0 = 0.85, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          fix.sigma = FALSE,
          n.burn = benchmark_n_burn, n.mcmc = benchmark_n_mcmc,
          verbose = FALSE
        )
      })

      diag_vb <- diagnostics_from_fit(M1_ldvb, M2_ldvb, plot = FALSE, y_data = y)
      diag_mcmc <- diagnostics_from_fit(M1_mcmc, M2_mcmc, plot = FALSE, y_data = y)

      list(
        M1_mcmc = M1_mcmc,
        M2_mcmc = M2_mcmc,
        diag_vb = diag_vb,
        diag_mcmc = diag_mcmc
      )
    }, note = benchmark_step_id)

    capture_output_file("ex2_benchmark_run_summary.txt", {
      cat(sprintf("settings=%s\n", selected_run))
      cat(sprintf("backend_settings=%s\n", selected_benchmark_setting))
      cat(sprintf("ldvb_n.samp=%d, benchmark_n.burn=%d, benchmark_n.mcmc=%d\n\n", n_samp, benchmark_n_burn, benchmark_n_mcmc))
      cat("LDVB benchmark diagnostics:\n")
      print(data.frame(
        model = c("DQLM", "exDQLM"),
        runtime_sec = c(ex2_benchmark$diag_vb$m1.rt, ex2_benchmark$diag_vb$m2.rt),
        KL = c(ex2_benchmark$diag_vb$m1.KL, ex2_benchmark$diag_vb$m2.KL),
        CRPS = c(ex2_benchmark$diag_vb$m1.CRPS, ex2_benchmark$diag_vb$m2.CRPS),
        pplc = c(ex2_benchmark$diag_vb$m1.pplc, ex2_benchmark$diag_vb$m2.pplc)
      ))
      cat("\nMCMC benchmark diagnostics:\n")
      print(data.frame(
        model = c("DQLM", "exDQLM"),
        runtime_sec = c(ex2_benchmark$diag_mcmc$m1.rt, ex2_benchmark$diag_mcmc$m2.rt),
        KL = c(ex2_benchmark$diag_mcmc$m1.KL, ex2_benchmark$diag_mcmc$m2.KL),
        CRPS = c(ex2_benchmark$diag_mcmc$m1.CRPS, ex2_benchmark$diag_mcmc$m2.CRPS),
        pplc = c(ex2_benchmark$diag_mcmc$m1.pplc, ex2_benchmark$diag_mcmc$m2.pplc)
      ))
      cat("\nMCMC backend metadata:\n")
      print(ex2_benchmark$M2_mcmc$backend)
    })

    ex2_benchmark_table <- data.frame(
      model = c("DQLM", "exDQLM", "DQLM", "exDQLM"),
      method = c("LDVB", "LDVB", "MCMC", "MCMC"),
      runtime_sec = c(
        ex2_benchmark$diag_vb$m1.rt,
        ex2_benchmark$diag_vb$m2.rt,
        ex2_benchmark$diag_mcmc$m1.rt,
        ex2_benchmark$diag_mcmc$m2.rt
      ),
      KL = c(
        ex2_benchmark$diag_vb$m1.KL,
        ex2_benchmark$diag_vb$m2.KL,
        ex2_benchmark$diag_mcmc$m1.KL,
        ex2_benchmark$diag_mcmc$m2.KL
      ),
      CRPS = c(
        ex2_benchmark$diag_vb$m1.CRPS,
        ex2_benchmark$diag_vb$m2.CRPS,
        ex2_benchmark$diag_mcmc$m1.CRPS,
        ex2_benchmark$diag_mcmc$m2.CRPS
      ),
      pplc = c(
        ex2_benchmark$diag_vb$m1.pplc,
        ex2_benchmark$diag_vb$m2.pplc,
        ex2_benchmark$diag_mcmc$m1.pplc,
        ex2_benchmark$diag_mcmc$m2.pplc
      ),
      backend_settings = rep(selected_benchmark_setting, 4),
      posterior_draws = rep(n_samp, 4),
      burn_in = c(NA_integer_, NA_integer_, benchmark_n_burn, benchmark_n_burn),
      n_burn = rep(benchmark_n_burn, 4),
      n_mcmc = rep(benchmark_n_mcmc, 4),
      stringsAsFactors = FALSE
    )
    save_table_csv(
      ex2_benchmark_table,
      filename = "ex2_dynamic_benchmark.csv",
      output_id = "tab_ex2_dynamic_benchmark",
      manuscript_label = "tab:ex2bench",
      status = "reproduced",
      notes = sprintf(
        "Representative dynamic LDVB versus MCMC benchmark for Example 2 under backend setting %s.",
        selected_benchmark_setting
      )
    )
  } else if (need_ex2benchmark) {
  }

  xlim_time <- c(1780, 1830)
  xlim_idx <- time_window_to_index(y_ts, xlim_time[1], xlim_time[2])
  ex2_cols <- list(
    dqlm = "#C44E52",
    exdqlm = "#4C72B0",
    obs = "#6F6F6F",
    hist_fill = grDevices::adjustcolor("#4C72B0", alpha.f = 0.22),
    hist_border = "#4C72B0"
  )

  if (need_ex2quant || need_ex2quant_ldvb) {
    plot_quant_triplet_ldvb <- function(filename, m_dqlm, m_exdqlm, p0_label) {
      m_dqlm_plot <- m_dqlm
      m_exdqlm_plot <- m_exdqlm
      m_dqlm_plot$y <- y_ts
      m_exdqlm_plot$y <- y_ts
      save_png_plot(filename, {
        graphics::layout(matrix(c(1, 1, 2, 3), nrow = 2, byrow = TRUE), heights = c(0.9, 1.1))
        graphics::par(mar = c(3.9, 4.1, 2.6, 1.2) + 0.1)
        stats::plot.ts(y_ts, col = ex2_cols$obs, ylab = "sunspot count", xlab = "year")
        graphics::title(main = "Sunspot time series")

        graphics::par(mar = c(4.4, 4.1, 2.6, 1.2) + 0.1)
        stats::plot.ts(y_ts, xlim = xlim_time, col = ex2_cols$obs, ylab = "quantile and 95% CrI", xlab = "year")
        plot(m_dqlm_plot, col = ex2_cols$dqlm, add = TRUE)
        plot(m_exdqlm_plot, col = ex2_cols$exdqlm, add = TRUE)
        graphics::legend(
          "topleft",
          legend = c("DQLM", "exDQLM"),
          col = c(ex2_cols$dqlm, ex2_cols$exdqlm),
          lty = 1,
          lwd = c(1.5, 1.5),
          bty = "n"
        )
        graphics::title(main = sprintf("LDVB fit for p0 = %s", p0_label))

        graphics::par(mar = c(4.4, 4.1, 2.6, 1.2) + 0.1)
        graphics::hist(
          as.numeric(m_exdqlm_plot$samp.gamma),
          xlab = expression(gamma),
          main = sprintf("exDQLM posterior draws of gamma (p0 = %s)", p0_label),
          col = ex2_cols$hist_fill,
          border = ex2_cols$hist_border
        )
        graphics::abline(v = stats::median(as.numeric(m_exdqlm_plot$samp.gamma), na.rm = TRUE), col = ex2_cols$exdqlm, lwd = 2)
      }, width = 9.2, height = 7.2, pointsize = 12.5)
    }

    if (ex2_ldvb_pair_ok && need_ex2quant) {
      plot_quant_triplet_ldvb("ex2quant.png", M1_ldvb, M2_ldvb, "0.85")
    } else if (need_ex2quant) {
    }

    if (ex2_ldvb_pair_ok && need_ex2quant_ldvb) {
      plot_quant_triplet_ldvb("ex2quant_ldvb.png", M1_ldvb, M2_ldvb, "0.85")
    } else {
    }

    if (need_ex2quant_ldvb) {
      ex2_extreme_ldvb <- run_step(
        sprintf("ex2_quant_grid_ldvb_nsamp%d_tol%s_v5_prior50", n_samp, format(tol)),
        {
        M99_dqlm_ldvb <- tryCatch(
          exdqlm::exdqlmLDVB(
            y = y_ts, p0 = 0.99, model = model,
            df = c(0.9, 0.85), dim.df = c(1, 8),
            # Stabilize extreme upper-tail DQLM fit under LDVB.
            dqlm.ind = TRUE, sig.init = 10, fix.sigma = FALSE,
            n.samp = n_samp, tol = tol,
            vb_control = list(max_iter = ldvb_max_iter),
            verbose = FALSE
          ),
          error = function(e) e
        )
        M99_exdqlm_ldvb <- tryCatch(
        exdqlm::exdqlmLDVB(
          y = y_ts, p0 = 0.99, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          sig.init = 2, fix.sigma = FALSE,
          n.samp = n_samp, tol = tol,
          vb_control = list(max_iter = ldvb_max_iter),
          verbose = FALSE
        ),
          error = function(e) e
        )
        M05_dqlm_ldvb <- tryCatch(
        exdqlm::exdqlmLDVB(
          y = y_ts, p0 = 0.05, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          dqlm.ind = TRUE, sig.init = 2, fix.sigma = FALSE,
          n.samp = n_samp, tol = tol,
          vb_control = list(max_iter = ldvb_max_iter),
          verbose = FALSE
        ),
          error = function(e) e
        )
        M05_exdqlm_ldvb <- tryCatch(
        exdqlm::exdqlmLDVB(
          y = y_ts, p0 = 0.05, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          sig.init = 2, fix.sigma = FALSE,
          n.samp = n_samp, tol = tol,
          vb_control = list(max_iter = ldvb_max_iter),
          verbose = FALSE
        ),
          error = function(e) e
        )
        list(
          M99_dqlm_ldvb = M99_dqlm_ldvb, M99_exdqlm_ldvb = M99_exdqlm_ldvb,
          M05_dqlm_ldvb = M05_dqlm_ldvb, M05_exdqlm_ldvb = M05_exdqlm_ldvb
        )
      }, note = sprintf("ex2_quant_grid_ldvb_nsamp%d_tol%s_v5_prior50", n_samp, format(tol)))

      ldvb_p099_ok <- fit_ok(ex2_extreme_ldvb$M99_dqlm_ldvb) && fit_ok(ex2_extreme_ldvb$M99_exdqlm_ldvb)
      ldvb_p005_ok <- fit_ok(ex2_extreme_ldvb$M05_dqlm_ldvb) && fit_ok(ex2_extreme_ldvb$M05_exdqlm_ldvb)

      if (ldvb_p099_ok) {
        plot_quant_triplet_ldvb("ex2quant_ldvb_p099.png", ex2_extreme_ldvb$M99_dqlm_ldvb, ex2_extreme_ldvb$M99_exdqlm_ldvb, "0.99")
      } else {
      }

      if (ldvb_p005_ok) {
        plot_quant_triplet_ldvb("ex2quant_ldvb_p005.png", ex2_extreme_ldvb$M05_dqlm_ldvb, ex2_extreme_ldvb$M05_exdqlm_ldvb, "0.05")
      } else {
      }
    }
  }

  if (need_ex2checks) {
    if (ex2_ldvb_pair_ok) {
      save_png_plot("ex2checks.png", {
        graphics::par(mfrow = c(2, 3))
        diagnostics_from_fit(M1_ldvb, M2_ldvb, plot = TRUE, cols = c(ex2_cols$dqlm, ex2_cols$exdqlm), y_data = y)
      }, width = 9.2, height = 6.4, pointsize = 12.5)
    } else {
    }
  }

  if (need_ex2checks_ldvb) {
    if (ex2_ldvb_pair_ok) {
      save_png_plot("ex2checks_ldvb.png", {
        graphics::par(mfrow = c(2, 3))
        diagnostics_from_fit(M1_ldvb, plot = TRUE, cols = c(ldvb_cols$m1, ldvb_cols$m1), y_data = y)
        diagnostics_from_fit(M2_ldvb, plot = TRUE, cols = c(ldvb_cols$m2, ldvb_cols$m2), y_data = y)
      })
    } else {
    }
  }

  if (need_ex2_ldvb_diag) {
    ldvb_diag <- run_step(
      sprintf("ex2_ldvb_diagnostics_fit_nsamp%d_tol%s_v6_sig2_prior50", ldvb_diag_n_samp, format(ldvb_diag_tol)),
      {
      set.seed(20262901)
      exdqlm::exdqlmLDVB(
        y = y_ts, p0 = 0.85, model = model,
        df = c(0.9, 0.85), dim.df = c(1, 8),
        sig.init = 2, fix.sigma = FALSE,
        n.samp = ldvb_diag_n_samp, tol = ldvb_diag_tol,
        vb_control = list(max_iter = ldvb_max_iter),
        verbose = FALSE
      )
    }, note = sprintf("ex2_ldvb_diagnostics_fit_nsamp%d_tol%s_v6_sig2_prior50", ldvb_diag_n_samp, format(ldvb_diag_tol)))
    seq_g <- as.numeric(ldvb_diag$seq.gamma)
    seq_s <- as.numeric(ldvb_diag$seq.sigma)
    el <- as.numeric(ldvb_diag$diagnostics$elbo)

    if (fit_ok(M1_ldvb)) {
      save_png_plot("ex2_ldvb_diagnostics.png", {
        graphics::par(mfrow = c(2, 2))

        stats::plot.ts(y, xlim = xlim_idx, col = "grey70", ylab = "quantile 95% CrIs")
        plot(M1_ldvb, col = ex2_cols$dqlm, add = TRUE)
        plot(ldvb_diag, col = ex2_cols$exdqlm, add = TRUE)
        graphics::legend(
          "topleft",
          legend = c("DQLM LDVB", "exDQLM LDVB"),
          col = c(ex2_cols$dqlm, ex2_cols$exdqlm),
          lty = 1,
          bty = "n"
        )

        graphics::plot(seq_along(seq_g), seq_g, type = "o", pch = 16, cex = 0.45, col = "darkorange", xlab = "Iteration", ylab = expression(seq(gamma)))
        graphics::plot(seq_along(seq_s), seq_s, type = "o", pch = 16, cex = 0.45, col = "darkorange", xlab = "Iteration", ylab = expression(seq(sigma)))

        if (length(el) > 1L && all(is.finite(el))) {
          de <- c(NA_real_, diff(el))
          de_rng <- range(de, na.rm = TRUE)
          el_rng <- range(el, na.rm = TRUE)
          if (is.finite(diff(de_rng)) && diff(de_rng) > 0) {
            de_scaled <- el_rng[1] + (de - de_rng[1]) * diff(el_rng) / diff(de_rng)
          } else {
            de_scaled <- rep(mean(el_rng), length(de))
          }
          graphics::plot(seq_along(el), el, type = "l", lwd = 2, col = "darkorange", xlab = "Iteration", ylab = "ELBO")
          graphics::lines(seq_along(el), de_scaled, col = "steelblue", lty = 2)
          graphics::legend("bottomright", legend = c("ELBO", "scaled delta ELBO"), col = c("darkorange", "steelblue"), lty = c(1, 2), bty = "n")
        } else {
          graphics::plot.new()
          graphics::title("ELBO trace unavailable")
        }
      })
    } else {
    }

    capture_output_file("ex2_ldvb_diagnostics_summary.txt", {
      cat(sprintf("tol=%s, n.samp=%d, iter=%d\n\n", format(ldvb_diag_tol), ldvb_diag_n_samp, ldvb_diag$iter))
      cat("seq.gamma summary:\n")
      print(summary(seq_g))
      cat("\nseq.sigma summary:\n")
      print(summary(seq_s))
      if (length(el) > 0L) {
        cat("\nELBO summary:\n")
        print(summary(el))
        if (length(el) > 1L) {
          cat("\nLast 5 delta ELBO values:\n")
          print(tail(diff(el), 5))
        }
      }
      cat("\nPosterior sample summaries:\n")
      cat("gamma: "); print(summary(as.numeric(ldvb_diag$samp.gamma)))
      cat("sigma: "); print(summary(as.numeric(ldvb_diag$samp.sigma)))
    })

  }

  if (need_ex2_tables) {
    ex2_df_scan <- run_step(
      sprintf("ex2_df_scan_ldvb_primary_nsamp%d_tol%s_v6_sig2_prior50", n_samp, format(tol)),
      {
      possible_dfs <- cbind(0.9, df_grid)
      KLs <- rep(NA_real_, nrow(possible_dfs))
      CRPSs <- rep(NA_real_, nrow(possible_dfs))
      for (i in seq_len(nrow(possible_dfs))) {
        set.seed(20262700 + i)
        temp_M <- tryCatch(
          exdqlm::exdqlmLDVB(
            y = y_ts, p0 = 0.85, model = model,
            df = possible_dfs[i, ], dim.df = c(1, 8),
            sig.init = 2, fix.sigma = FALSE,
            n.samp = n_samp, tol = tol,
            vb_control = list(max_iter = ldvb_max_iter),
            verbose = FALSE
          ),
          error = function(e) e
        )
        if (!inherits(temp_M, "error")) {
          temp_check <- diagnostics_from_fit(temp_M, plot = FALSE, y_data = y)
          KLs[i] <- temp_check$m1.KL
          CRPSs[i] <- temp_check$m1.CRPS
        }
      }
      list(possible_dfs = possible_dfs, KLs = KLs, CRPSs = CRPSs)
    }, note = sprintf("ex2_df_scan_ldvb_primary_nsamp%d_tol%s_v6_sig2_prior50", n_samp, format(tol)))

    possible_dfs <- ex2_df_scan$possible_dfs
    KLs <- ex2_df_scan$KLs
    CRPSs <- ex2_df_scan$CRPSs
    finite_crps <- is.finite(CRPSs)
    finite_kl <- is.finite(KLs)
    df_scan <- data.frame(
      trend_df = possible_dfs[, 1],
      seasonal_df = possible_dfs[, 2],
      CRPS = CRPSs,
      KL = KLs,
      rank_CRPS = rank(CRPSs, ties.method = "min", na.last = "keep"),
      rank_KL = rank(KLs, ties.method = "min", na.last = "keep")
    )
    if (any(finite_crps)) {
      best_df <- possible_dfs[which.min(CRPSs), ]
      best_df_kl <- if (any(finite_kl)) possible_dfs[which.min(KLs), ] else c(NA_real_, NA_real_)
        save_table_csv(
        df_scan,
        filename = "ex2_df_scan_kl.csv",
        output_id = "tab_ex2_df_scan",
        manuscript_label = "Example 2 discount-factor CRPS/KL selection",
        status = "reproduced",
        notes = sprintf(
          "Best pair by CRPS in this run: (%0.2f, %0.2f). Best pair by KL: (%s, %s).",
          best_df[1], best_df[2],
          format(best_df_kl[1], trim = TRUE, digits = 2),
          format(best_df_kl[2], trim = TRUE, digits = 2)
        )
      )

    } else {
      save_table_csv(
        df_scan,
        filename = "ex2_df_scan_kl.csv",
        output_id = "tab_ex2_df_scan",
        manuscript_label = "Example 2 discount-factor CRPS/KL selection",
        status = "not_reproduced",
        notes = "No finite CRPS values were obtained in the primary LDVB discount-factor scan."
      )
    }

    if (ex2_ldvb_pair_ok) {
      diag_2 <- diagnostics_from_fit(M1_ldvb, M2_ldvb, plot = FALSE, y_data = y)
      diag_table <- data.frame(
        model = c("M1_dqlm_ldvb", "M2_exdqlm_ldvb"),
        KL = c(diag_2$m1.KL, diag_2$m2.KL),
        CRPS = c(diag_2$m1.CRPS, diag_2$m2.CRPS),
        pplc = c(diag_2$m1.pplc, diag_2$m2.pplc),
        run_time_seconds = c(diag_2$m1.rt, diag_2$m2.rt)
      )
      save_table_csv(
        diag_table,
        filename = "ex2_diagnostics_summary.csv",
        output_id = "tab_ex2_diagnostics",
        manuscript_label = "Example 2 diagnostic narrative",
        status = "reproduced",
        notes = "Primary Example 2 diagnostics summary computed from the LDVB fits."
      )
    } else {
    }
  }

  if (need_ex2_tables_ldvb) {
    ex2_df_scan_ldvb <- run_step(
      sprintf("ex2_df_scan_ldvb_support_nsamp%d_tol%s_v6_sig2_prior50", n_samp, format(tol)),
      {
      possible_dfs <- cbind(0.9, df_grid)
      KLs <- rep(NA_real_, nrow(possible_dfs))
      CRPSs <- rep(NA_real_, nrow(possible_dfs))
      for (i in seq_len(nrow(possible_dfs))) {
        set.seed(20262700 + i)
        temp_M <- tryCatch(
          exdqlm::exdqlmLDVB(
            y = y_ts, p0 = 0.85, model = model,
            df = possible_dfs[i, ], dim.df = c(1, 8),
            sig.init = 2, fix.sigma = FALSE,
            n.samp = n_samp, tol = tol,
            vb_control = list(max_iter = ldvb_max_iter),
            verbose = FALSE
          ),
          error = function(e) e
        )
        if (!inherits(temp_M, "error")) {
          temp_check <- diagnostics_from_fit(temp_M, plot = FALSE, y_data = y)
          KLs[i] <- temp_check$m1.KL
          CRPSs[i] <- temp_check$m1.CRPS
        }
      }
      list(possible_dfs = possible_dfs, KLs = KLs, CRPSs = CRPSs)
    }, note = sprintf("ex2_df_scan_ldvb_support_nsamp%d_tol%s_v6_sig2_prior50", n_samp, format(tol)))

    possible_dfs_ld <- ex2_df_scan_ldvb$possible_dfs
    KLs_ld <- ex2_df_scan_ldvb$KLs
    CRPSs_ld <- ex2_df_scan_ldvb$CRPSs
    df_scan_ld <- data.frame(
      trend_df = possible_dfs_ld[, 1],
      seasonal_df = possible_dfs_ld[, 2],
      CRPS = CRPSs_ld,
      KL = KLs_ld,
      rank_CRPS = rank(CRPSs_ld, ties.method = "min", na.last = "keep"),
      rank_KL = rank(KLs_ld, ties.method = "min", na.last = "keep")
    )
    finite_crps_ld <- is.finite(CRPSs_ld)
    finite_kl_ld <- is.finite(KLs_ld)
    if (any(finite_crps_ld)) {
      best_df_ld <- possible_dfs_ld[which.min(CRPSs_ld), ]
      best_df_kl_ld <- if (any(finite_kl_ld)) possible_dfs_ld[which.min(KLs_ld), ] else c(NA_real_, NA_real_)
      save_table_csv(
        df_scan_ld,
        filename = "ex2_df_scan_kl_ldvb.csv",
        output_id = "tab_ex2_df_scan_ldvb",
        manuscript_label = "new: Example 2 discount-factor CRPS/KL selection (LDVB)",
        status = "reproduced",
        notes = sprintf(
          "Best pair by CRPS in this run: (%0.2f, %0.2f). Best pair by KL: (%s, %s).",
          best_df_ld[1], best_df_ld[2],
          format(best_df_kl_ld[1], trim = TRUE, digits = 2),
          format(best_df_kl_ld[2], trim = TRUE, digits = 2)
        )
      )
    } else {
      save_table_csv(
        df_scan_ld,
        filename = "ex2_df_scan_kl_ldvb.csv",
        output_id = "tab_ex2_df_scan_ldvb",
        manuscript_label = "new: Example 2 discount-factor CRPS/KL selection (LDVB)",
        status = "not_reproduced",
        notes = "No finite CRPS values were obtained in LDVB discount-factor scan."
      )
    }

    if (ex2_ldvb_pair_ok) {
      diag_m1_ld <- diagnostics_from_fit(M1_ldvb, plot = FALSE, y_data = y)
      diag_m2_ld <- diagnostics_from_fit(M2_ldvb, plot = FALSE, y_data = y)
      diag_table_ld <- data.frame(
        model = c("M1_dqlm_ldvb", "M2_exdqlm_ldvb"),
        KL = c(diag_m1_ld$m1.KL, diag_m2_ld$m1.KL),
        CRPS = c(diag_m1_ld$m1.CRPS, diag_m2_ld$m1.CRPS),
        pplc = c(diag_m1_ld$m1.pplc, diag_m2_ld$m1.pplc),
        run_time_seconds = c(diag_m1_ld$m1.rt, diag_m2_ld$m1.rt)
      )
      save_table_csv(
        diag_table_ld,
        filename = "ex2_diagnostics_summary_ldvb.csv",
        output_id = "tab_ex2_diagnostics_ldvb",
        manuscript_label = "new: Example 2 diagnostic narrative (LDVB)",
        status = "reproduced",
        notes = "LDVB counterpart computed with diagnostics()."
      )
    } else {
    }
  }

  log_msg("Example 2 (Sunspots): complete")
}

# ---- ex3_big_tree ----
need_ex3 <- TRUE

if (!need_ex3) {
  log_msg("Example 3 (Big Tree): skipped")
} else {
  log_msg("Example 3 (Big Tree): start")

need_ex3data <- TRUE
need_ex3forecast <- TRUE
need_ex3quantcomps <- TRUE
need_ex3zetapsi <- TRUE
need_ex3tables <- TRUE
  need_ex3_models <- any(c(need_ex3forecast, need_ex3quantcomps, need_ex3zetapsi, need_ex3tables))

  fit_ok <- function(x) !is.null(x) && !inherits(x, "error")

  with_local_seed <- function(seed, expr) {
    has_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    old_seed <- if (has_seed) get(".Random.seed", envir = .GlobalEnv, inherits = FALSE) else NULL
    on.exit({
      if (has_seed) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }, add = TRUE)
    set.seed(as.integer(seed))
    eval.parent(substitute(expr))
  }

  month_sequence_from_ts <- function(x) {
    st <- stats::start(x)
    start_date <- as.Date(sprintf("%04d-%02d-01", as.integer(st[1]), as.integer(st[2])))
    seq.Date(start_date, by = "month", length.out = length(x))
  }

  make_monthly_ts <- function(values, dates) {
    if (!length(values)) stop("Cannot create a monthly ts from zero observations.", call. = FALSE)
    start_date <- as.Date(dates[[1]])
    stats::ts(
      values,
      start = c(as.integer(format(start_date, "%Y")), as.integer(format(start_date, "%m"))),
      frequency = 12
    )
  }

  fmt_month <- function(x) format(as.Date(x), "%Y-%m")

  padded_range <- function(..., pad = 0.08) {
    vals <- unlist(list(...), use.names = FALSE)
    vals <- vals[is.finite(vals)]
    if (!length(vals)) return(c(-1, 1))
    r <- range(vals)
    if (diff(r) == 0) return(r + c(-1, 1) * max(1, abs(r[1]) * pad))
    r + c(-1, 1) * diff(r) * pad
  }

  climate_psi_title <- function(label) {
    as.expression(substitute(psi[list(LABEL, t)], list(LABEL = label)))
  }

  forecast_metrics_row <- function(model, label, forecast_obj, y_future,
                                   crps_probs, crps_weights = NULL) {
    dx <- exdqlm::diagnostics(
      forecast_obj,
      y = y_future,
      crps_probs = crps_probs,
      crps_weights = crps_weights
    )
    data.frame(
      model = model,
      label = label,
      horizon = dx$horizon,
      mean_check_loss = as.numeric(dx$m1.check_loss),
      CRPS = as.numeric(dx$m1.CRPS),
      stringsAsFactors = FALSE
    )
  }

  scale_with_training <- function(X_raw, train_idx) {
    center <- colMeans(X_raw[train_idx, , drop = FALSE])
    scale <- apply(X_raw[train_idx, , drop = FALSE], 2, stats::sd)
    if (any(!is.finite(scale)) || any(scale <= 0)) {
      stop("Training-window climate-index scaling produced non-positive standard deviations.", call. = FALSE)
    }
    X_scaled <- sweep(sweep(X_raw, 2, center, "-"), 2, scale, "/")
    colnames(X_scaled) <- colnames(X_raw)
    list(X_scaled = X_scaled, center = center, scale = scale)
  }

  build_base_forecast_mats <- function(base_model, k) {
    p <- length(base_model$m0)
    list(
      fFF = matrix(base_model$FF, nrow = p, ncol = k),
      fGG = array(base_model$GG, c(p, p, k))
    )
  }

  build_direct_forecast_mats <- function(base_model, X_future_scaled, coef_c0 = 1) {
    X_future_scaled <- as.matrix(X_future_scaled)
    reg_future <- exdqlm::regMod(
      X_future_scaled,
      m0 = rep(0, ncol(X_future_scaled)),
      C0 = diag(coef_c0, ncol(X_future_scaled))
    )
    future_model <- base_model + reg_future
    p <- length(future_model$m0)
    k <- nrow(X_future_scaled)
    list(
      fFF = matrix(future_model$FF, nrow = p, ncol = k),
      fGG = array(future_model$GG, c(p, p, k))
    )
  }

  build_transfer_forecast_mats <- function(base_model, X_future_scaled, lambda) {
    X_future_scaled <- as.matrix(X_future_scaled)
    TT <- nrow(X_future_scaled)
    temp_p <- length(base_model$m0)
    k <- ncol(X_future_scaled)
    zeta_idx <- temp_p + 1L
    psi_idx <- seq.int(temp_p + 2L, temp_p + k + 1L)
    p_aug <- temp_p + k + 1L

    base_FF <- matrix(base_model$FF, nrow = temp_p, ncol = TT)
    base_GG <- array(base_model$GG, c(temp_p, temp_p, TT))

    fFF <- matrix(0, p_aug, TT)
    fFF[seq_len(temp_p), ] <- base_FF
    fFF[zeta_idx, ] <- 1

    fGG <- array(0, c(p_aug, p_aug, TT))
    fGG[seq_len(temp_p), seq_len(temp_p), ] <- base_GG
    fGG[zeta_idx, zeta_idx, ] <- lambda
    for (j in seq_len(k)) {
      fGG[zeta_idx, psi_idx[[j]], ] <- X_future_scaled[, j]
      fGG[psi_idx[[j]], psi_idx[[j]], ] <- 1
    }

    list(fFF = fFF, fGG = fGG, zeta_idx = zeta_idx, psi_idx = psi_idx)
  }

  utils::data("BTflow", package = "exdqlm", envir = environment())
  utils::data("climateIndices", package = "exdqlm", envir = environment())
  if (!exists("BTflow") || !stats::is.ts(BTflow)) {
    stop("Required package dataset BTflow is not available as a monthly ts.", call. = FALSE)
  }
  if (!exists("climateIndices") || !is.data.frame(climateIndices)) {
    stop("Required package dataset climateIndices is not available as a data frame.", call. = FALSE)
  }

  ex3_cfg <- cfg_run$ex3
  p0 <- as.numeric(ex3_cfg$p0 %||% 0.15)
  selected_indices <- tolower(as.character(ex3_cfg$selected_indices %||% c("noi", "amo")))
  selected_indices <- selected_indices[nzchar(selected_indices)]
  if (!length(selected_indices)) {
    stop("Example 3 requires at least one selected climate index.", call. = FALSE)
  }
  missing_indices <- setdiff(selected_indices, names(climateIndices))
  if (length(missing_indices)) {
    stop(
      sprintf("climateIndices is missing selected columns: %s", paste(missing_indices, collapse = ", ")),
      call. = FALSE
    )
  }
  required_cols <- c("date", selected_indices)
  if (!"date" %in% names(climateIndices)) {
    stop("climateIndices must contain a date column.", call. = FALSE)
  }

  index_labels <- c(
    nino3 = "Nino 3",
    nao = "NAO",
    nino12 = "Nino 1+2",
    whwp = "WHWP",
    gmt = "GMT",
    oni = "ONI",
    pna = "PNA",
    noi = "NOI",
    wp = "WP",
    nino34 = "Nino 3.4",
    solar_flux = "Solar Flux",
    amo = "AMO",
    espi = "ESPI",
    tsa = "TSA",
    nino4 = "Nino 4",
    tna = "TNA",
    soi = "SOI"
  )
  selected_labels <- unname(index_labels[selected_indices])
  missing_labels <- is.na(selected_labels) | !nzchar(selected_labels)
  selected_labels[missing_labels] <- toupper(selected_indices[missing_labels])

  bt_dates <- month_sequence_from_ts(BTflow)
  flow_df <- data.frame(date = bt_dates, flow_cfs = as.numeric(BTflow))
  climate_df <- climateIndices[, required_cols, drop = FALSE]
  climate_df$date <- as.Date(climate_df$date)

  model_df <- merge(flow_df, climate_df, by = "date", all = FALSE)
  model_df <- model_df[order(model_df$date), , drop = FALSE]

  fit_start <- as.Date(ex3_cfg$fit_start %||% min(model_df$date))
  fit_end <- as.Date(ex3_cfg$fit_end %||% max(model_df$date))
  model_df <- model_df[model_df$date >= fit_start & model_df$date <= fit_end, , drop = FALSE]
  model_df <- model_df[stats::complete.cases(model_df[, c("flow_cfs", selected_indices), drop = FALSE]), , drop = FALSE]

  if (nrow(model_df) < 60L) {
    stop("Example 3 aligned data window has fewer than 60 complete monthly observations.", call. = FALSE)
  }
  if (any(!is.finite(model_df$flow_cfs)) || any(model_df$flow_cfs <= 0)) {
    stop("BTflow values used in Example 3 must be positive and finite before log transform.", call. = FALSE)
  }

  X_raw <- as.matrix(model_df[, selected_indices, drop = FALSE])
  storage.mode(X_raw) <- "double"

  flow_ts <- make_monthly_ts(model_df$flow_cfs, model_df$date)
  y_log_ts <- log(flow_ts)
  y_log <- as.numeric(y_log_ts)
  k_cov <- ncol(X_raw)

  forecast_horizon <- as.integer(ex3_cfg$forecast_horizon %||% 18L)
  if (!is.finite(forecast_horizon) || forecast_horizon < 1L || forecast_horizon >= nrow(model_df)) {
    stop("Example 3 forecast_horizon must be positive and smaller than the analysis sample.", call. = FALSE)
  }
  final_train_n <- nrow(model_df) - forecast_horizon
  final_train_idx <- seq_len(final_train_n)
  holdout_idx <- seq.int(final_train_n + 1L, nrow(model_df))

  final_scaling <- scale_with_training(X_raw, final_train_idx)
  X_final_scaled <- final_scaling$X_scaled

  y_train_ts <- make_monthly_ts(y_log[final_train_idx], model_df$date[final_train_idx])
  y_holdout <- y_log[holdout_idx]
  X_train <- X_final_scaled[final_train_idx, , drop = FALSE]
  X_holdout <- X_final_scaled[holdout_idx, , drop = FALSE]

  ex3_cols <- list(
    m0 = "#7A4BA0",
    m0_aux = "#B991CC",
    mtf = "#2E7D5B",
    mtf_aux = "#85B89A",
    mreg = "#4C72B0",
    mreg_aux = "#9EB8D9",
    idx1 = "#2D6F95",
    idx2 = "#B85C38",
    holdout = "#C47A2C",
    ref = "#C47A2C"
  )
  index_cols <- c(ex3_cols$idx1, ex3_cols$idx2, "#6B8E23", "#5F4B8B")
  index_cols <- rep(index_cols, length.out = k_cov)

  harmonics <- as.numeric(ex3_cfg$harmonics %||% c(1, 2, 0.1469118636))
  trend_order <- as.integer(ex3_cfg$trend_order %||% 1L)
  seasonal_period <- as.numeric(ex3_cfg$seasonal_period %||% 12)
  trend_df <- as.numeric(ex3_cfg$trend_df %||% 0.99)
  seasonal_df <- as.numeric(ex3_cfg$seasonal_df %||% 0.99)
  covariate_df <- as.numeric(ex3_cfg$covariate_df %||% 0.99)
  transfer_zeta_df <- as.numeric(ex3_cfg$transfer_zeta_df %||% 0.99)
  transfer_psi_df <- as.numeric(ex3_cfg$transfer_psi_df %||% 0.99)
  transfer_psi_df_grid <- as.numeric(ex3_cfg$transfer_psi_df_grid %||% transfer_psi_df)
  transfer_psi_df_grid <- sort(unique(transfer_psi_df_grid[is.finite(transfer_psi_df_grid) &
                                                             transfer_psi_df_grid > 0 &
                                                             transfer_psi_df_grid <= 1]))
  if (!length(transfer_psi_df_grid)) transfer_psi_df_grid <- transfer_psi_df
  selection_metric <- toupper(as.character(ex3_cfg$selection_metric %||% "PPLC"))
  if (!selection_metric %in% c("PPLC", "CRPS", "KL")) {
    stop("Example 3 selection_metric must be one of PPLC, CRPS, or KL.", call. = FALSE)
  }
  crps_probs <- as.numeric(ex3_cfg$crps_probs %||% seq(0.01, 0.99, by = 0.01))
  crps_probs <- sort(unique(crps_probs[is.finite(crps_probs) & crps_probs > 0 & crps_probs < 1]))
  if (!length(crps_probs)) {
    stop("Example 3 crps_probs must contain values strictly between 0 and 1.", call. = FALSE)
  }
  trend_c0 <- as.numeric(ex3_cfg$trend_c0 %||% 0.1)
  trend_m0 <- as.numeric(ex3_cfg$trend_m0 %||% log(50))
  seasonal_c0 <- as.numeric(ex3_cfg$seasonal_c0 %||% 1)
  climate_coef_c0 <- as.numeric(ex3_cfg$climate_coef_c0 %||% 1)
  reg_c0 <- as.numeric(ex3_cfg$reg_c0 %||% climate_coef_c0)
  transfer_zeta_c0 <- as.numeric(ex3_cfg$transfer_zeta_c0 %||% 0.1)
  transfer_psi_c0 <- as.numeric(ex3_cfg$transfer_psi_c0 %||% climate_coef_c0)
  gam_init <- as.numeric(ex3_cfg$gam_init %||% -0.1)
  sig_init <- as.numeric(ex3_cfg$sig_init %||% 0.1)
  n_samp <- as.integer(ex3_cfg$n_samp)
  forecast_n_samp <- as.integer(ex3_cfg$forecast_n_samp %||% n_samp)
  if (!is.finite(forecast_n_samp) || forecast_n_samp < 1L) forecast_n_samp <- n_samp
  tol <- as.numeric(ex3_cfg$tol)
  max_iter <- as.integer(ex3_cfg$max_iter %||% getOption("exdqlm.max_iter", 200L))
  if (!is.finite(max_iter) || max_iter < 1L) {
    stop("Example 3 max_iter must be a positive integer.", call. = FALSE)
  }
  old_exdqlm_max_iter <- getOption("exdqlm.max_iter", NULL)
  options(exdqlm.max_iter = max_iter)
  lambda_grid <- as.numeric(ex3_cfg$lambda_grid)
  lambda_grid <- sort(unique(lambda_grid[is.finite(lambda_grid) & lambda_grid > 0 & lambda_grid < 1]))
  if (!length(lambda_grid)) stop("Example 3 lambda_grid must contain values in (0, 1).", call. = FALSE)

  make_base_model <- function(y_train) {
    trend_comp <- exdqlm::polytrendMod(
      order = trend_order,
      m0 = trend_m0,
      C0 = trend_c0
    )
    seas_comp <- exdqlm::seasMod(
      p = seasonal_period,
      h = harmonics,
      C0 = diag(seasonal_c0, 2L * length(harmonics))
    )
    trend_comp + seas_comp
  }

  base_model_template <- make_base_model(y_train_ts)
  base_state_dim <- length(base_model_template$m0)
  seasonal_idx <- seq.int(trend_order + 1L, base_state_dim)
  direct_reg_idx <- seq.int(base_state_dim + 1L, base_state_dim + k_cov)
  transfer_zeta_idx <- base_state_dim + 1L
  transfer_psi_idx <- seq.int(base_state_dim + 2L, base_state_dim + k_cov + 1L)

  df_base <- c(trend_df, seasonal_df)
  dim_df_base <- c(trend_order, 2L * length(harmonics))
  df_direct <- c(trend_df, seasonal_df, covariate_df)
  dim_df_direct <- c(trend_order, 2L * length(harmonics), k_cov)
  tf_m0 <- rep(0, k_cov + 1L)
  tf_C0 <- diag(c(transfer_zeta_c0, rep(transfer_psi_c0, k_cov)), k_cov + 1L)

  fit_base_model <- function(y_train) {
    base_model <- make_base_model(y_train)
    fit <- exdqlm::exdqlmLDVB(
      y = y_train, p0 = p0, model = base_model,
      df = df_base, dim.df = dim_df_base,
      sig.init = sig_init, gam.init = gam_init,
      fix.sigma = FALSE,
      tol = tol, n.samp = n_samp,
      verbose = FALSE
    )
    attr(fit, "ex3_base_model") <- base_model
    fit
  }

  fit_direct_model <- function(y_train, X_train_scaled) {
    base_model <- make_base_model(y_train)
    reg_comp <- exdqlm::regMod(
      X_train_scaled,
      m0 = rep(0, ncol(X_train_scaled)),
      C0 = diag(reg_c0, ncol(X_train_scaled))
    )
    fit <- exdqlm::exdqlmLDVB(
      y = y_train, p0 = p0, model = base_model + reg_comp,
      df = df_direct, dim.df = dim_df_direct,
      sig.init = sig_init, gam.init = gam_init,
      fix.sigma = FALSE,
      tol = tol, n.samp = n_samp,
      verbose = FALSE
    )
    attr(fit, "ex3_base_model") <- base_model
    fit
  }

  fit_transfer_model <- function(y_train, X_train_scaled, lambda, psi_df) {
    base_model <- make_base_model(y_train)
    tf_df <- c(transfer_zeta_df, psi_df)
    fit <- exdqlm::exdqlmTransferLDVB(
      y = y_train, p0 = p0, model = base_model,
      df = df_base, dim.df = dim_df_base,
      X = X_train_scaled, tf.df = tf_df, lam = lambda,
      tf.m0 = tf_m0, tf.C0 = tf_C0,
      sig.init = sig_init, gam.init = gam_init,
      fix.sigma = FALSE,
      tol = tol, n.samp = n_samp,
      verbose = FALSE
    )
    attr(fit, "ex3_base_model") <- base_model
    fit
  }

  forecast_with_mats <- function(fit, k, mats, seed) {
    stats::predict(
      fit,
      start.t = length(fit$y),
      k = k,
      fFF = mats$fFF,
      fGG = mats$fGG,
      plot = FALSE,
      return.draws = TRUE,
      n.samp = forecast_n_samp,
      seed = seed
    )
  }

  ex3_diagnostics <- function(...) {
    args <- list(...)
    args$plot <- FALSE
    args$crps_probs <- crps_probs
    do.call(exdqlm::diagnostics, args)
  }

  if (need_ex3data) {
    save_png_plot("ex3data.png", {
      old_par <- graphics::par(mfrow = c(2, 1), mar = c(3.0, 4.2, 1.0, 0.8), oma = c(1.6, 0, 0, 0))
      on.exit(graphics::par(old_par), add = TRUE)

      stats::plot.ts(y_log_ts, col = "grey35", ylab = "log flow", xlab = "", lwd = 1.1)
      graphics::grid(col = "grey88")
      graphics::abline(v = grDevices::xy.coords(y_log_ts)$x[holdout_idx[[1L]]], col = ex3_cols$holdout, lty = 5, lwd = 1.2)

      tx <- as.numeric(stats::time(y_log_ts))
      graphics::plot(
        tx, X_final_scaled[, 1L], type = "l", lty = 1, lwd = 1.6,
        col = index_cols[[1L]], xlab = "", ylab = "standardized index",
        ylim = padded_range(X_final_scaled)
      )
      if (k_cov > 1L) {
        for (j in 2L:k_cov) {
          graphics::lines(tx, X_final_scaled[, j], col = index_cols[[j]], lwd = 1.6, lty = j)
        }
      }
      graphics::abline(h = 0, col = "grey65", lty = 3)
      graphics::abline(v = tx[holdout_idx[[1L]]], col = ex3_cols$holdout, lty = 5, lwd = 1.2)
      graphics::grid(col = "grey88")
      graphics::legend(
        "topleft", legend = selected_labels, col = index_cols,
        lty = seq_len(k_cov), lwd = 1.6, bty = "n", ncol = min(2L, k_cov)
      )
      graphics::mtext("time", side = 1, outer = TRUE, line = 0.4)
    })
  }

  if (need_ex3_models) {
    pkg_source_label <- paste0("exdqlm_", as.character(utils::packageVersion("exdqlm")))
    grid_tag <- paste(sprintf("%03d", round(100 * lambda_grid)), collapse = "_")
    psi_tag <- paste(sprintf("%03d", round(100 * transfer_psi_df_grid)), collapse = "_")
    window_tag <- paste(fmt_month(range(model_df$date)), collapse = "_")
    metric_tag <- gsub("[^0-9A-Za-z]+", "_", selection_metric)
    p0_tag <- sprintf("p%03d", round(100 * p0))
    prior_tag <- sprintf("m0%04d_c0%04d", round(1000 * trend_m0), round(1000 * trend_c0))
    coef_tag <- sprintf(
      "coefc0%04d_regdf%03d_zetadf%03d_psidf%s",
      round(1000 * climate_coef_c0),
      round(100 * covariate_df),
      round(100 * transfer_zeta_df),
      psi_tag
    )
    step_id <- sprintf(
      "ex3_models_trainselect_v7_threemodel_%s_%s_%s_%s_%s_%s_grid%s_%s_nsamp%d_tol%s_iter%d_h%d",
      paste(selected_indices, collapse = "_"),
      pkg_source_label,
      window_tag,
      p0_tag,
      prior_tag,
      coef_tag,
      grid_tag,
      metric_tag,
      n_samp,
      gsub("[^0-9A-Za-z]+", "_", format(tol)),
      max_iter,
      forecast_horizon
    )

    ex3_models <- run_step(step_id, {
      selection_rows <- list()
      row_id <- 0L
      for (psi_df in transfer_psi_df_grid) {
        for (i in seq_along(lambda_grid)) {
          row_id <- row_id + 1L
          lambda <- lambda_grid[[i]]
          selection_seed <- seed_value + 3500L + row_id
          log_msg(sprintf(
            "Example 3 training-selection fit %d/%d: lambda = %.3f, transfer psi df = %.3f",
            row_id, length(lambda_grid) * length(transfer_psi_df_grid), lambda, psi_df
          ))
          fit <- tryCatch(
            with_local_seed(
              selection_seed,
              fit_transfer_model(y_train_ts, X_train, lambda = lambda, psi_df = psi_df)
            ),
            error = function(e) e
          )

          row <- data.frame(
            lambda = lambda,
            transfer_zeta_df = transfer_zeta_df,
            transfer_psi_df = psi_df,
            selection_metric = selection_metric,
            selection_value = NA_real_,
            KL = NA_real_,
            KL_flipped = NA_real_,
            CRPS = NA_real_,
            PPLC = NA_real_,
            runtime = NA_real_,
            iter = NA_integer_,
            converged = NA,
            status = "ok",
            error_message = "",
            seed = selection_seed,
            stringsAsFactors = FALSE
          )

          if (!fit_ok(fit)) {
            row$status <- "fit_error"
            row$error_message <- conditionMessage(fit)
            selection_rows[[row_id]] <- row
            next
          }

          row$runtime <- as.numeric(fit$run.time %||% NA_real_)
          row$iter <- as.integer(fit$iter %||% NA_integer_)
          row$converged <- isTRUE(fit$converged)

          diag_fit <- tryCatch(
            ex3_diagnostics(fit),
            error = function(e) e
          )
          if (!fit_ok(diag_fit)) {
            row$status <- "diagnostics_error"
            row$error_message <- conditionMessage(diag_fit)
            selection_rows[[row_id]] <- row
            next
          }

          row$KL <- as.numeric(diag_fit$m1.KL %||% NA_real_)
          row$KL_flipped <- as.numeric(diag_fit$m1.KL.flip %||% NA_real_)
          row$CRPS <- as.numeric(diag_fit$m1.CRPS %||% NA_real_)
          row$PPLC <- as.numeric(diag_fit$m1.pplc %||% NA_real_)
          row$selection_value <- as.numeric(row[[selection_metric]])
          if (!is.finite(row$selection_value)) {
            row$status <- "nonfinite_metrics"
          }
          selection_rows[[row_id]] <- row
        }
      }

      selection_table <- do.call(rbind, selection_rows)
      ok <- selection_table$status == "ok" & is.finite(selection_table$selection_value)
      if (!any(ok)) {
        stop("No finite training-selection diagnostics were produced by the Example 3 transfer grid.", call. = FALSE)
      }
      eligible_idx <- which(ok)
      order_key <- order(
        selection_table$selection_value[eligible_idx],
        -selection_table$transfer_psi_df[eligible_idx],
        selection_table$CRPS[eligible_idx],
        selection_table$KL[eligible_idx],
        selection_table$lambda[eligible_idx]
      )
      selected_idx <- eligible_idx[order_key[[1L]]]
      selection_table$selected <- seq_len(nrow(selection_table)) == selected_idx
      lambda_star <- selection_table$lambda[[selected_idx]]
      psi_df_star <- selection_table$transfer_psi_df[[selected_idx]]
      log_msg(sprintf(
        "Example 3 selected transfer settings: lambda = %.3f, transfer psi df = %.3f by training %s",
        lambda_star, psi_df_star, selection_metric
      ))

      log_msg("Example 3 final fit: M0 no-transfer baseline")
      M0 <- tryCatch(
        with_local_seed(seed_value + 3600L, fit_base_model(y_train_ts)),
        error = function(e) e
      )
      log_msg("Example 3 final fit: MTF transfer-function model")
      MTF <- tryCatch(
        with_local_seed(
          seed_value + 3700L,
          fit_transfer_model(y_train_ts, X_train, lambda = lambda_star, psi_df = psi_df_star)
        ),
        error = function(e) e
      )
      log_msg("Example 3 final fit: MREG direct-regression model")
      MREG <- tryCatch(
        with_local_seed(seed_value + 3800L, fit_direct_model(y_train_ts, X_train)),
        error = function(e) e
      )

      if (!fit_ok(M0) || !fit_ok(MREG) || !fit_ok(MTF)) {
        stop("Example 3 final no-transfer, direct-regression, or transfer-function LDVB fit failed.", call. = FALSE)
      }

      base_final <- attr(M0, "ex3_base_model")
      log_msg("Example 3 forecasting and scoring final 18-month holdout")
      fc_M0 <- forecast_with_mats(
        M0,
        k = forecast_horizon,
        mats = build_base_forecast_mats(base_final, forecast_horizon),
        seed = seed_value + 4600L
      )
      fc_MTF <- forecast_with_mats(
        MTF,
        k = forecast_horizon,
        mats = build_transfer_forecast_mats(attr(MTF, "ex3_base_model"), X_holdout, lambda = lambda_star),
        seed = seed_value + 4700L
      )
      fc_MREG <- forecast_with_mats(
        MREG,
        k = forecast_horizon,
        mats = build_direct_forecast_mats(attr(MREG, "ex3_base_model"), X_holdout, coef_c0 = reg_c0),
        seed = seed_value + 4800L
      )

      forecast_metrics <- rbind(
        forecast_metrics_row("M0_no_transfer", "M0 no transfer", fc_M0, y_holdout,
                             crps_probs = crps_probs),
        forecast_metrics_row("MREG_direct_regression", "MREG direct regression", fc_MREG, y_holdout,
                             crps_probs = crps_probs),
        forecast_metrics_row("MTF_transfer_function", "MTF transfer function", fc_MTF, y_holdout,
                             crps_probs = crps_probs)
      )
      sensitivity_metrics <- forecast_metrics

      list(
        M0 = M0,
        MTF = MTF,
        MREG = MREG,
        fc_M0 = fc_M0,
        fc_MTF = fc_MTF,
        fc_MREG = fc_MREG,
        selection_table = selection_table,
        forecast_metrics = forecast_metrics,
        sensitivity_metrics = sensitivity_metrics,
        lambda_star = lambda_star,
        psi_df_star = psi_df_star,
        selected_indices = selected_indices,
        selected_labels = selected_labels,
        X_center = final_scaling$center,
        X_scale = final_scaling$scale,
        selection_metric = selection_metric,
        crps_probs = crps_probs,
        n_samp = n_samp,
        forecast_n_samp = forecast_n_samp,
        tol = tol,
        max_iter = max_iter
      )
    }, note = step_id)

    M0 <- ex3_models$M0
    MTF <- ex3_models$MTF
    MREG <- ex3_models$MREG
    fc_M0 <- ex3_models$fc_M0
    fc_MTF <- ex3_models$fc_MTF
    fc_MREG <- ex3_models$fc_MREG
    if (!fit_ok(M0) || !fit_ok(MREG) || !fit_ok(MTF)) {
      stop("Example 3 final LDVB fits failed; cannot regenerate manuscript outputs.", call. = FALSE)
    }

    M0$y <- y_train_ts
    MTF$y <- y_train_ts
    MREG$y <- y_train_ts

    lambda_star <- ex3_models$lambda_star
    psi_df_star <- ex3_models$psi_df_star
    selected_labels <- ex3_models$selected_labels
    selected_indices <- ex3_models$selected_indices
    selection_table <- ex3_models$selection_table
    forecast_metrics <- rbind(
      forecast_metrics_row("M0_no_transfer", "M0 no transfer", fc_M0, y_holdout,
                           crps_probs = crps_probs),
      forecast_metrics_row("MREG_direct_regression", "MREG direct regression", fc_MREG, y_holdout,
                           crps_probs = crps_probs),
      forecast_metrics_row("MTF_transfer_function", "MTF transfer function", fc_MTF, y_holdout,
                           crps_probs = crps_probs)
    )
    sensitivity_metrics <- forecast_metrics
    diagnostic_row <- function(model, label, fit) {
      dx <- ex3_diagnostics(fit)
      data.frame(
        model = model,
        label = label,
        KL = as.numeric(dx$m1.KL),
        KL_flipped = as.numeric(dx$m1.KL.flip),
        CRPS = as.numeric(dx$m1.CRPS),
        PPLC = as.numeric(dx$m1.pplc),
        stringsAsFactors = FALSE
      )
    }
    diagnostics_summary <- rbind(
      diagnostic_row("M0_no_transfer", "M0 no transfer", M0),
      diagnostic_row("MREG_direct_regression", "MREG direct regression", MREG),
      diagnostic_row("MTF_transfer_function", "MTF transfer function", MTF)
    )
    capture_output_file("ex3_run_summary.txt", {
      cat(sprintf("settings=%s\n", selected_run))
      cat(sprintf("package_source=%s\n", pkg_source_label))
      cat(sprintf("p0=%0.2f\n", p0))
      cat(sprintf("trend_prior_m0=%0.6f, trend_prior_C0=%0.3f\n", trend_m0, trend_c0))
      cat(sprintf("climate_coef_prior_C0=%0.3f\n", climate_coef_c0))
      cat(sprintf(
        "discount_factors=trend:%0.3f, seasonal:%0.3f, direct_coef:%0.3f, transfer_zeta:%0.3f, transfer_psi:%0.3f\n",
        trend_df, seasonal_df, covariate_df, transfer_zeta_df, psi_df_star
      ))
      cat(sprintf("data_window=%s to %s\n", fmt_month(min(model_df$date)), fmt_month(max(model_df$date))))
      cat(sprintf("final_training_window=%s to %s\n", fmt_month(model_df$date[min(final_train_idx)]), fmt_month(model_df$date[max(final_train_idx)])))
      cat(sprintf("forecast_holdout_window=%s to %s\n", fmt_month(model_df$date[min(holdout_idx)]), fmt_month(model_df$date[max(holdout_idx)])))
      cat(sprintf("n_observations=%d, n_train=%d, n_holdout=%d\n", nrow(model_df), length(final_train_idx), length(holdout_idx)))
      cat(sprintf("selected_indices=%s\n", paste(selected_labels, collapse = ", ")))
      cat(sprintf("n.samp=%d, forecast_n.samp=%d, tol=%s, max_iter=%d\n", ex3_models$n_samp, ex3_models$forecast_n_samp, format(ex3_models$tol), ex3_models$max_iter))
      cat(sprintf("lambda_star_by_training_%s=%0.3f\n", tolower(ex3_models$selection_metric), lambda_star))
      cat(sprintf("transfer_psi_df_star=%0.3f\n\n", psi_df_star))
      cat("Training transfer grid diagnostics:\n")
      print(selection_table)
      cat("\nFinal-training covariate scaling:\n")
      print(data.frame(index = selected_indices, label = selected_labels, center = ex3_models$X_center, scale = ex3_models$X_scale))
      cat("\nMTF$median.kt:\n")
      print(MTF$median.kt)
      cat("\nRun times:\n")
      print(c(M0 = M0$run.time, MTF = MTF$run.time, MREG = if (fit_ok(MREG)) MREG$run.time else NA_real_))
      cat("\nConvergence:\n")
      print(data.frame(
        model = c("M0", "MTF", "MREG"),
        iter = c(M0$iter %||% NA_integer_, MTF$iter %||% NA_integer_, if (fit_ok(MREG)) MREG$iter %||% NA_integer_ else NA_integer_),
        converged = c(isTRUE(M0$converged), isTRUE(MTF$converged), if (fit_ok(MREG)) isTRUE(MREG$converged) else NA)
      ))
      cat("\nFinal-training package diagnostics from diagnostics():\n")
      print(diagnostics_summary)
      cat("\nFinal holdout forecast metrics from diagnostics():\n")
      print(forecast_metrics)
      cat("\nSensitivity forecast metrics:\n")
      print(sensitivity_metrics)
    })

    model_dataset <- data.frame(
      date = model_df$date,
      flow_cfs = model_df$flow_cfs,
      log_flow = y_log,
      phase = ifelse(seq_len(nrow(model_df)) %in% holdout_idx, "forecast_holdout", "training"),
      model_train = seq_len(nrow(model_df)) %in% final_train_idx,
      model_holdout = seq_len(nrow(model_df)) %in% holdout_idx,
      X_final_scaled,
      check.names = FALSE
    )
    save_table_csv(
      model_dataset,
      filename = "ex3_model_dataset.csv",
      output_id = "tab_ex3_model_dataset",
      manuscript_label = "Example 3 modeling dataset",
      status = "reproduced",
      notes = "Aligned Big Tree flow and climate-index data used by Example 3, with training and forecast-holdout phase labels."
    )

    covariate_scaling <- data.frame(
      index = selected_indices,
      label = selected_labels,
      center = as.numeric(ex3_models$X_center),
      scale = as.numeric(ex3_models$X_scale),
      stringsAsFactors = FALSE
    )
    save_table_csv(
      covariate_scaling,
      filename = "ex3_covariate_scaling.csv",
      output_id = "tab_ex3_covariate_scaling",
      manuscript_label = "Example 3 covariate scaling",
      status = "reproduced",
      notes = "Training-window means and standard deviations used to standardize Example 3 climate indices."
    )
    save_table_csv(
      selection_table,
      filename = "ex3_lambda_selection.csv",
      output_id = "tab_ex3_lambda_selection",
      manuscript_label = "Example 3 transfer training-selection output",
      status = "reproduced",
      notes = sprintf(
        "Example 3 transfer-function training diagnostic grid; selected lambda=%0.3f and transfer psi discount=%0.3f by training %s.",
        lambda_star,
        psi_df_star,
        ex3_models$selection_metric
      )
    )
    save_table_csv(
      diagnostics_summary,
      filename = "ex3_diagnostics_summary.csv",
      output_id = "tab_ex3_diagnostics",
      manuscript_label = "tab:ex3",
      status = "reproduced",
      notes = "Example 3 final-training package diagnostics from diagnostics() for the no-covariate, direct-regression, and transfer-function models."
    )
    save_table_csv(
      forecast_metrics,
      filename = "ex3_forecast_metrics.csv",
      output_id = "tab_ex3_forecast_metrics",
      manuscript_label = "tab:ex3forecastmetrics",
      status = "reproduced",
      notes = "Example 3 final 18-month holdout forecast check loss and CRPS from diagnostics() for the no-covariate, direct-regression, and transfer-function models."
    )
    save_table_csv(
      sensitivity_metrics,
      filename = "ex3_sensitivity_forecast_metrics.csv",
      output_id = "tab_ex3_sensitivity_forecast_metrics",
      manuscript_label = "Example 3 sensitivity forecast metrics",
      status = "reproduced",
      notes = "Backward-compatible copy of the Example 3 final 18-month holdout forecast check loss and CRPS from diagnostics()."
    )

    xlim_mid <- as.numeric(ex3_cfg$focus_window %||% c(2016, 2020))
    if (length(xlim_mid) != 2L || any(!is.finite(xlim_mid)) || xlim_mid[[1L]] >= xlim_mid[[2L]]) {
      stop("Example 3 focus_window must contain two increasing finite years.", call. = FALSE)
    }
    tx_full <- grDevices::xy.coords(y_log_ts)$x
    tx_train <- grDevices::xy.coords(y_train_ts)$x
    forecast_plot_start <- as.numeric(ex3_cfg$forecast_plot_start %||% (tx_train[length(tx_train)] - 4))
    if (!is.finite(forecast_plot_start)) {
      stop("Example 3 forecast_plot_start must be finite.", call. = FALSE)
    }
    xlim_fore <- c(max(min(tx_full), forecast_plot_start), max(tx_full))

    if (need_ex3quantcomps) {
      q0 <- plot(M0, plot = FALSE)
      qreg <- plot(MREG, plot = FALSE)
      qtf <- plot(MTF, plot = FALSE)
      c0_seas <- plot(M0, type = "component", index = seasonal_idx, plot = FALSE)
      creg_seas <- plot(MREG, type = "component", index = seasonal_idx, plot = FALSE)
      ctf_seas <- plot(MTF, type = "component", index = seasonal_idx, plot = FALSE)
      creg_direct <- plot(MREG, type = "component", index = direct_reg_idx, plot = FALSE)
      ctf_transfer <- plot(MTF, type = "component", index = transfer_zeta_idx, plot = FALSE)

      save_png_plot("ex3quantcomps.png", {
        old_par <- graphics::par(mfrow = c(3, 1), mar = c(2.8, 4.4, 1.0, 0.9), oma = c(1.8, 0, 0, 0))
        on.exit(graphics::par(old_par), add = TRUE)

        graphics::plot(
          tx_full, y_log, type = "l", col = "grey70",
          ylim = padded_range(y_log, q0$lb.quant, q0$ub.quant, qreg$lb.quant, qreg$ub.quant, qtf$lb.quant, qtf$ub.quant),
          xlim = xlim_mid, xlab = "", ylab = "log flow / quantile"
        )
        graphics::grid(col = "grey90")
        plot(M0, add = TRUE, col = ex3_cols$m0)
        plot(MREG, add = TRUE, col = ex3_cols$mreg)
        plot(MTF, add = TRUE, col = ex3_cols$mtf)
        graphics::legend(
          "topleft", legend = c("M0 no covariates", "MREG direct regression", "MTF transfer function"),
          col = c(ex3_cols$m0, ex3_cols$mreg, ex3_cols$mtf), lty = 1, lwd = 1.5, bty = "n"
        )

        graphics::plot(
          NA, ylim = padded_range(c0_seas$lb.comp, c0_seas$ub.comp, creg_seas$lb.comp, creg_seas$ub.comp, ctf_seas$lb.comp, ctf_seas$ub.comp),
          xlim = xlim_mid, ylab = "seasonal contribution", xlab = ""
        )
        graphics::grid(col = "grey90")
        plot(M0, type = "component", index = seasonal_idx, add = TRUE, col = ex3_cols$m0)
        plot(MREG, type = "component", index = seasonal_idx, add = TRUE, col = ex3_cols$mreg)
        plot(MTF, type = "component", index = seasonal_idx, add = TRUE, col = ex3_cols$mtf)
        graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 1.4)

        graphics::plot(
          NA, ylim = padded_range(creg_direct$lb.comp, creg_direct$ub.comp, ctf_transfer$lb.comp, ctf_transfer$ub.comp, 0),
          xlim = xlim_mid, ylab = "covariate contribution", xlab = ""
        )
        graphics::grid(col = "grey90")
        plot(MREG, type = "component", index = direct_reg_idx, add = TRUE, col = ex3_cols$mreg)
        plot(MTF, type = "component", index = transfer_zeta_idx, add = TRUE, col = ex3_cols$mtf)
        graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 1.4)
        graphics::legend(
          "topleft", legend = c("MREG direct", "MTF transfer"),
          col = c(ex3_cols$mreg, ex3_cols$mtf), lty = 1, lwd = 1.5, bty = "n"
        )
        graphics::mtext("time", side = 1, outer = TRUE, line = 0.5)
      }, width = 8.2, height = 7.2, pointsize = 12.5)
    }

    if (need_ex3zetapsi) {
      save_png_plot("ex3zetapsi.png", {
        old_par <- graphics::par(no.readonly = TRUE)
        on.exit(graphics::par(old_par), add = TRUE)

        if (k_cov == 2L) {
          graphics::layout(matrix(c(1, 1, 2, 3), nrow = 2, byrow = TRUE), heights = c(1.05, 1))
        } else {
          graphics::par(mfrow = c(1, k_cov + 1L))
        }
        graphics::par(mar = c(3.0, 4.2, 2.1, 0.8), oma = c(0, 0, 0, 0))
        zeta <- plot(MTF, type = "state", index = transfer_zeta_idx, plot = FALSE)
        graphics::plot(
          zeta$x, zeta$map.comp, type = "n", xlab = "",
          ylab = "component CrIs",
          ylim = padded_range(zeta$lb.comp, zeta$ub.comp, 0)
        )
        graphics::grid(col = "grey90")
        plot(MTF, type = "state", index = transfer_zeta_idx, add = TRUE, col = ex3_cols$mtf)
        graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 1.4)
        graphics::title(expression(zeta[t]))

        graphics::par(mar = c(3.8, 4.2, 2.1, 0.8))
        for (j in seq_len(k_cov)) {
          psi <- plot(MTF, type = "state", index = transfer_psi_idx[[j]], plot = FALSE)
          psi_ylim <- padded_range(psi$lb.comp, psi$ub.comp, 0)
          graphics::plot(
            psi$x, psi$map.comp, type = "n", xlab = "time",
            ylab = "component CrIs", ylim = psi_ylim
          )
          graphics::grid(col = "grey90")
          plot(MTF, type = "state", index = transfer_psi_idx[[j]], add = TRUE, col = index_cols[[j]])
          graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 1.4)
          graphics::title(climate_psi_title(selected_labels[[j]]))
        }
      }, width = 8.8, height = 5.8, pointsize = 12.5)
    }

    if (need_ex3forecast) {
      save_png_plot("ex3forecast.png", {
        stats::plot.ts(
          y_log_ts, col = "grey70",
          ylim = padded_range(y_log, fc_M0$ff, fc_MREG$ff, fc_MTF$ff),
          xlim = xlim_fore,
          ylab = "log flow / forecast quantile",
          xlab = "time"
        )
        graphics::grid(col = "grey90")
        plot(fc_M0, add = TRUE, cols = c(ex3_cols$m0, ex3_cols$m0_aux))
        plot(fc_MREG, add = TRUE, cols = c(ex3_cols$mreg, ex3_cols$mreg_aux))
        plot(fc_MTF, add = TRUE, cols = c(ex3_cols$mtf, ex3_cols$mtf_aux))
        graphics::lines(tx_full[holdout_idx], y_log[holdout_idx], col = ex3_cols$holdout, lwd = 1.4)
        graphics::points(tx_full[holdout_idx], y_log[holdout_idx], col = ex3_cols$holdout, pch = 1, cex = 0.8)
        graphics::abline(v = tx_full[holdout_idx[[1L]]], col = ex3_cols$ref, lty = 5, lwd = 1.2)
        graphics::legend(
          "topleft", legend = c("M0 no covariates", "MREG direct regression", "MTF transfer", "held-out observations"),
          col = c(ex3_cols$m0, ex3_cols$mreg, ex3_cols$mtf, ex3_cols$holdout),
          lty = c(1, 1, 1, 1), pch = c(NA, NA, NA, 1), lwd = c(1.4, 1.4, 1.4, 1.2), bty = "n"
        )
      }, width = 8.4, height = 5.5, pointsize = 12.5)
    }
  }

  log_msg("Example 3 (Big Tree): complete")
  if (is.null(old_exdqlm_max_iter)) {
    options(exdqlm.max_iter = NULL)
  } else {
    options(exdqlm.max_iter = old_exdqlm_max_iter)
  }
}

# ---- ex4_static ----
need_ex4 <- TRUE
if (!need_ex4) {
  log_msg("Example 4 (static Nishimura-Suchard RHS sparse simulation): skipped")
} else {
  log_msg("Example 4 (static Nishimura-Suchard RHS sparse simulation): start")


need_ex4figure <- TRUE
need_ex4table <- TRUE

  cfg_ex4 <- cfg_run$ex4
  train_n <- as.integer(cfg_ex4$n_train)
  holdout_n <- as.integer(cfg_ex4$holdout_n)
  predictor_n <- as.integer(cfg_ex4$n_predictors)
  cov_rho <- as.numeric(cfg_ex4$cov_rho)
  sigma_eps <- as.numeric(cfg_ex4$sigma_eps)
  beta_slopes <- as.numeric(cfg_ex4$true_beta)
  p_levels <- as.numeric(cfg_ex4$p_levels)
  ldvb_max_iter <- as.integer(cfg_ex4$ldvb_max_iter)
  ldvb_max_iter_tail <- as.integer(cfg_ex4$ldvb_max_iter_tail)
  ldvb_tol <- as.numeric(cfg_ex4$ldvb_tol)
  n_samp <- as.integer(cfg_ex4$n_samp %||% 200L)
  n_burn <- as.integer(cfg_ex4$n_burn)
  n_mcmc <- as.integer(cfg_ex4$n_mcmc)
  thin <- as.integer(cfg_ex4$thin %||% 1L)
  ex4_seed_info <- ex4_resolve_dataset_seed(cfg_ex4)
  ex4_seed <- as.integer(ex4_seed_info$seed)
  rhs_ctrl <- ex4_build_rhs_ctrl(cfg_ex4)
  step_id <- sprintf(
    "ex4_static_rhsns_sparse_seed_%d_ns%d_b%d_k%d_tau%03d_zeta%03d_tol%s_iter%d_%d_v5",
    ex4_seed,
    n_samp,
    n_burn,
    n_mcmc,
    round(1000 * rhs_ctrl$tau0),
    round(1000 * rhs_ctrl$zeta2_fixed),
    gsub("[^0-9A-Za-z]+", "_", format(ldvb_tol)),
    ldvb_max_iter,
    ldvb_max_iter_tail
  )
  ex4_obj <- ex4_run_step(
    step_id,
    ex4_fit_seed(ex4_seed, cfg_ex4, stop_on_failure = TRUE),
    note = step_id
  )
  capture_output_file("ex4_run_summary.txt", {
    cat(sprintf("settings=%s\n", selected_run))
    cat(sprintf("seed=%d\n", ex4_obj$seed))
    cat(sprintf("seed_source=%s\n", ex4_seed_info$source))
    if (!is.na(ex4_seed_info$selection_file)) {
      cat(sprintf("seed_selection_file=%s\n", ex4_seed_info$selection_file))
      cat(sprintf("seed_selection_target_p0=%0.2f\n", ex4_seed_info$target_p0))
    }
    cat(sprintf("train_n=%d, holdout_n=%d, predictors=%d\n", train_n, holdout_n, predictor_n))
    cat(sprintf("ldvb_n.samp=%d, n.burn=%d, n.mcmc=%d\n", n_samp, n_burn, n_mcmc))
    cat(sprintf("cov_rho=%0.2f, sigma_eps=%0.2f\n", cov_rho, sigma_eps))
    cat(sprintf("beta_slopes=%s\n", paste(format(ex4_obj$beta_slopes, trim = TRUE), collapse = ", ")))
    cat(sprintf(
      "rhs_ctrl: tau0=%0.3f, zeta2_fixed=%0.3f, shrink_intercept=%s\n",
      rhs_ctrl$tau0, rhs_ctrl$zeta2_fixed, rhs_ctrl$shrink_intercept
    ))
    cat(sprintf("p_levels=%s\n\n", paste(format(p_levels, digits = 2), collapse = ", ")))
    for (nm in names(ex4_obj$fits)) {
      res <- ex4_obj$fits[[nm]]
      cat(sprintf("p0=%0.2f\n", res$p0))
      cat(sprintf(
        "  LDVB: converged=%s, iter=%d, runtime=%0.3f, active_rmse=%0.4f, inactive_mae=%0.4f, holdout_rmse=%0.4f\n",
        if (isTRUE(res$ldvb$converged)) "TRUE" else "FALSE",
        res$ldvb$iter,
        res$ldvb$runtime,
        res$ldvb$active_rmse,
        res$ldvb$inactive_mae,
        res$ldvb$holdout_ref_rmse
      ))
      cat(sprintf(
        "  MCMC: kernel=%s, runtime=%0.3f, active_rmse=%0.4f, inactive_mae=%0.4f, holdout_rmse=%0.4f\n\n",
        res$mcmc$kernel,
        res$mcmc$runtime,
        res$mcmc$active_rmse,
        res$mcmc$inactive_mae,
        res$mcmc$holdout_ref_rmse
      ))
    }
  })

  summary_rows <- ex4_summary_rows(ex4_obj, cfg_ex4 = cfg_ex4)

  if (need_ex4table) {
    save_table_csv(
      summary_rows,
      filename = "ex4static_summary.csv",
      output_id = "tab_ex4static_summary",
      manuscript_label = "tab:ex4static",
      status = "reproduced",
      notes = "Runtime and sparse-signal recovery metrics for LDVB and MCMC under the rhs_ns prior."
    )
  }

  if (need_ex4figure) {
    y_lim <- range(
      c(
        ex4_obj$beta_slopes,
        unlist(lapply(ex4_obj$fits, function(res) {
          c(
            res$diag_holdout$m1.beta.lb[-1],
            res$diag_holdout$m1.beta.ub[-1],
            res$diag_holdout$m2.beta.lb[-1],
            res$diag_holdout$m2.beta.ub[-1]
          )
        }))
      ),
      finite = TRUE
    )
    y_pad <- 0.08 * diff(y_lim)
    if (!is.finite(y_pad) || y_pad <= 0) y_pad <- 0.5
    y_lim <- c(y_lim[1] - y_pad, y_lim[2] + y_pad)

    save_png_plot("ex4static.png", {
      graphics::par(mfrow = c(1, 3), mar = c(5.2, 4, 2.6, 1), xpd = NA)
      for (i in seq_along(p_levels)) {
        res <- ex4_obj$fits[[ex4_p_key(p_levels[i])]]
        plot(
          res$diag_holdout,
          type = "coefficients",
          beta.ref = c(0, ex4_obj$beta_slopes),
          include.intercept = FALSE,
          coef.names = c("(Intercept)", ex4_obj$coef_names),
          cols = c(ldvb_cols$m1, ldvb_cols$m2),
          legend.labels = c("LDVB 95% interval", "MCMC 95% interval"),
          beta.ref.label = "truth",
          ylim = y_lim,
          ylab = if (i == 1L) "coefficient value" else "",
          main = sprintf("p0 = %.2f", res$p0),
          legend = i == 1L
        )
      }
    }, width = 9.2, height = 4.8, pointsize = 12.5)

  }

  if (identical(ex4_seed_info$source, "screen_selection")) {
  }

  log_msg("Example 4 (static Nishimura-Suchard RHS sparse simulation): complete")
}

# ---- stable batch-visible outputs ----
print_jss_heading <- function(label) {
  cat("\n")
  cat(strrep("=", 72), "\n", sep = "")
  cat(label, "\n", sep = "")
  cat(strrep("=", 72), "\n", sep = "")
}

print_csv_table <- function(label, relative_path) {
  print_jss_heading(label)
  path <- file.path(repo_root, relative_path)
  if (!file.exists(path)) stop(sprintf("Required table is missing: %s", relative_path), call. = FALSE)
  print(utils::read.csv(path, stringsAsFactors = FALSE), row.names = FALSE)
}

write_printed_output <- function(filename, expr) {
  path <- file.path(logs_dir, filename)
  txt <- utils::capture.output(eval.parent(substitute(expr)))
  writeLines(txt, con = path)
  invisible(path)
}

save_table_csv(benchmark_environment_table(), "benchmark_environment.csv")
save_table_csv(benchmark_settings_table(), "benchmark_backend_settings.csv")
write_session_info()

print_jss_heading("M95")
print(M95)
write_printed_output("M95-print.txt", print(M95))
print_jss_heading("summary(M95)")
print(summary(M95))
write_printed_output("M95-summary.txt", print(summary(M95)))
print_jss_heading("MTF$median.kt")
print(MTF$median.kt)
write_printed_output("MTF-median-kt.txt", print(MTF$median.kt))
print_csv_table("Table 7 / tab:ex2bench", "tables/ex2_dynamic_benchmark.csv")
print_csv_table("Table 8 / tab:ex3", "tables/ex3_diagnostics_summary.csv")
print_csv_table("Table 9 / tab:ex3forecastmetrics", "tables/ex3_forecast_metrics.csv")
print_csv_table("Table 10 / tab:ex4static", "tables/ex4static_summary.csv")
print_jss_heading("sessionInfo()")
print(utils::sessionInfo())
cat(sprintf("\nTotal elapsed seconds: %.3f\n", proc.time()[[3L]] - jss_start_time))
if (isTRUE(getOption("exdqlm.jss_rplots_active", FALSE))) {
  grDevices::dev.off()
  options(exdqlm.jss_rplots_active = FALSE)
}
cat("\nReplication complete. Primary batch outputs: code.Rout and Rplots.pdf.\n")
