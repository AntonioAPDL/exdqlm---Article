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
cfg_benchmark_profiles <- cfg_params$benchmark_profiles %||% list()
selected_benchmark_profile <- cfg_params$manuscript_benchmark_profile %||% "B"
if (!selected_benchmark_profile %in% names(cfg_benchmark_profiles)) {
  stop(
    sprintf(
      "Unknown benchmark backend profile '%s'. Valid: %s",
      selected_benchmark_profile,
      paste(names(cfg_benchmark_profiles), collapse = ", ")
    ),
    call. = FALSE
  )
}

seed_value <- seed_override %||% cfg_params$seed
set.seed(seed_value)

targets <- if (exists("targets")) as.character(targets) else character(0)
targets <- targets[nzchar(targets)]
targeted_run <- length(targets) > 0L
force_refit <- isTRUE(force_refit)

resolve_pkg_path <- function() {
  env_pkg_path <- Sys.getenv("EXDQLM_PKG_PATH", unset = "")
  env_pkg_path <- if (nzchar(env_pkg_path)) env_pkg_path else NULL
  default_pkg_path <- "/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile"

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

required_fns <- c(
  "polytrendMod", "seasMod", "as.exdqlm",
  "exdqlmMCMC", "exdqlmLDVB", "exdqlmDiagnostics",
  "exdqlmPlot", "compPlot", "exdqlmForecast",
  "exalStaticLDVB", "exalStaticMCMC", "exalStaticDiagnostics",
  "quantileSynthesis"
)
missing_fns <- required_fns[!vapply(required_fns, function(f) {
  exists(f, where = asNamespace("exdqlm"), mode = "function", inherits = FALSE)
}, logical(1))]
if (length(missing_fns) > 0L) {
  stop(sprintf("Missing required exdqlm functions: %s", paste(missing_fns, collapse = ", ")), call. = FALSE)
}

apply_backend_profile <- function(profile_name = selected_benchmark_profile) {
  prof <- cfg_benchmark_profiles[[profile_name]]
  if (is.null(prof)) {
    stop(sprintf("Unknown benchmark backend profile '%s'.", profile_name), call. = FALSE)
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

with_backend_profile <- function(profile_name, expr) {
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
  apply_backend_profile(profile_name)
  eval.parent(substitute(expr))
}

safe_system_output <- function(cmd, args = character()) {
  out <- tryCatch(
    system2(cmd, args = args, stdout = TRUE, stderr = FALSE),
    error = function(e) character()
  )
  trimws(out[nzchar(trimws(out))])
}

git_short_head <- function(path) {
  out <- safe_system_output("git", c("-C", path, "rev-parse", "--short", "HEAD"))
  if (length(out)) out[[1]] else NA_character_
}

git_dirty_state <- function(path) {
  nzchar(paste(
    safe_system_output("git", c("-C", path, "status", "--porcelain", "--untracked-files=no")),
    collapse = ""
  ))
}

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

seeded_rnorm <- function(n, seed) {
  old_exists <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (old_exists) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }
  on.exit({
    if (old_exists) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  set.seed(as.integer(seed))
  stats::rnorm(n)
}

benchmark_profiles_table <- function() {
  rows <- lapply(names(cfg_benchmark_profiles), function(name) {
    prof <- cfg_benchmark_profiles[[name]]
    data.frame(
      profile = name,
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

resolve_ex4_dataset_seed_for_reporting <- function(cfg_ex4 = cfg_profile$ex4) {
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
      "selected_profile",
      "benchmark_profile",
      "seed",
      "cpu_model",
      "os",
      "r_version",
      "exdqlm_version",
      "exdqlm_commit",
      "exdqlm_dirty",
      "article_commit",
      "article_dirty",
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
      selected_profile,
      selected_benchmark_profile,
      as.character(seed_value),
      cpu_model,
      paste(Sys.info()[c("sysname", "release", "machine")], collapse = " | "),
      paste(R.version$major, R.version$minor, sep = "."),
      pkg_version,
      git_short_head(resolve_pkg_path()$path),
      as.character(git_dirty_state(resolve_pkg_path()$path)),
      git_short_head(repo_root),
      as.character(git_dirty_state(repo_root)),
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
      as.character(cfg_profile$ex4$n_train %||% NA_integer_),
      as.character(cfg_profile$ex4$holdout_n %||% NA_integer_),
      as.character(resolve_ex4_dataset_seed_for_reporting(cfg_profile$ex4))
    ),
    stringsAsFactors = FALSE
  )
}

apply_backend_profile(selected_benchmark_profile)

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

diagnostics_from_fit <- function(m1, m2 = NULL, plot = TRUE, cols = c("red", "blue"), ref = NULL, y_data = NULL) {
  safe_metric_mean <- function(x) {
    x <- as.numeric(x)
    x <- x[is.finite(x)]
    if (!length(x)) NA_real_ else mean(x)
  }
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
  m1.KL.flip <- mean(FNN::KL.divergence(m1_msfe, ref))
  if (has_y) {
    m1.loss <- matrix(NA_real_, TT, dim(m1_post_pred)[2])
    for (t in seq_len(TT)) {
      m1.loss[t, ] <- exdqlm:::CheckLossFn(m1$p0, y[t] - m1_post_pred[t, ])
    }
    m1.pplc <- sum(rowMeans(m1.loss))
    m1.CRPS <- safe_metric_mean(exdqlm:::.exdqlm_crps_vec(y, m1_post_pred))
  } else {
    m1.pplc <- NA_real_
    m1.CRPS <- NA_real_
  }
  m1.qq <- stats::qqnorm(m1_msfe, plot = FALSE)
  m1.acf <- stats::acf(m1.uts, plot = FALSE)

  retlist <- list(
    m1.uts = m1.uts, m1.KL = m1.KL, m1.KL.flip = m1.KL.flip, m1.CRPS = m1.CRPS, m1.pplc = m1.pplc,
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
    retlist$m2.KL.flip <- mean(FNN::KL.divergence(m2_msfe, ref))
    retlist$m2.pplc <- m2.pplc
    retlist$m2.CRPS <- if (has_y) safe_metric_mean(exdqlm:::.exdqlm_crps_vec(y, m2_post_pred)) else NA_real_
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

  copy_binary_file <- function(src, dst) {
    if (file.exists(dst)) unlink(dst, force = TRUE)
    in_con <- file(src, open = "rb")
    out_con <- file(dst, open = "wb")
    on.exit(try(close(out_con), silent = TRUE), add = TRUE)
    on.exit(try(close(in_con), silent = TRUE), add = TRUE)

    repeat {
      buf <- readBin(in_con, what = "raw", n = 1024L * 1024L)
      if (length(buf) == 0L) break
      writeBin(buf, out_con)
    }
    invisible(dst)
  }

  for (f in promote) {
    src <- file.path(figures_dir, f)
    dst <- file.path(target_dir, f)
    if (!file.exists(src)) {
      stop(sprintf("Promotion source figure missing: %s", src), call. = FALSE)
    }
    copy_binary_file(src, dst)
  }

  log_msg(sprintf("Promoted %d manuscript figure(s) to ignored local Figures/ export mirror", length(promote)))
}

register_note("api_update", "Deprecated exdqlmChecks replaced with exdqlmDiagnostics.")
register_note("api_update", "Deprecated y= usage removed from exdqlmPlot/compPlot/exdqlmForecast calls.")
register_note("ex2_policy", "Example 2 manuscript workflow now uses LDVB and MCMC only; ISVB support artifacts were retired.")
register_note(
  "backend",
  sprintf(
    "Benchmark Profile %s (%s) is active for manuscript runs; current MCMC backend options are exdqlm.use_cpp_mcmc=%s and exdqlm.cpp_mcmc_mode='%s'.",
    selected_benchmark_profile,
    cfg_benchmark_profiles[[selected_benchmark_profile]]$label %||% "backend profile",
    as.character(isTRUE(getOption("exdqlm.use_cpp_mcmc"))),
    as.character(getOption("exdqlm.cpp_mcmc_mode"))
  )
)

log_msg(sprintf("00_setup complete (profile=%s)", selected_profile))
