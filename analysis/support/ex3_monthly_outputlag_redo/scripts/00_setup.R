suppressWarnings(suppressMessages({
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' is required for analysis/support/ex3_monthly_outputlag_redo.")
  }
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("Package 'pkgload' is required for analysis/support/ex3_monthly_outputlag_redo.")
  }
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for analysis/support/ex3_monthly_outputlag_redo.")
  }
  if (!requireNamespace("gridExtra", quietly = TRUE)) {
    stop("Package 'gridExtra' is required for analysis/support/ex3_monthly_outputlag_redo.")
  }
}))

if (!exists("redo_root", inherits = FALSE)) {
  stop("redo_root not defined. Run this workflow through analysis/support/ex3_monthly_outputlag_redo/run_all.R")
}
if (!exists("config_path", inherits = FALSE)) {
  config_path <- file.path(redo_root, "config.yml")
}

config <- yaml::read_yaml(config_path)
`%||%` <- function(x, y) if (is.null(x)) y else x

config_tag <- config$runtime$output_tag %||%
  tools::file_path_sans_ext(basename(config_path))
config_tag <- gsub("[^A-Za-z0-9_-]+", "_", config_tag)

output_root <- file.path(redo_root, "outputs", config_tag)
figure_dir <- file.path(output_root, "figures")
table_dir <- file.path(output_root, "tables")
log_dir <- file.path(output_root, "logs")
cache_dir <- file.path(output_root, "cache")
progress_log_path <- file.path(log_dir, "ex3_monthly_progress.log")

ensure_runtime_dir <- function(dir_path, keep_local = FALSE) {
  dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
  if (isTRUE(keep_local)) {
    gitignore_path <- file.path(dir_path, ".gitignore")
    if (!file.exists(gitignore_path)) {
      writeLines(c("*", "!.gitignore"), con = gitignore_path)
    }
  }
}

ensure_runtime_dir(output_root)
ensure_runtime_dir(figure_dir, keep_local = TRUE)
ensure_runtime_dir(table_dir, keep_local = TRUE)
ensure_runtime_dir(log_dir, keep_local = TRUE)
ensure_runtime_dir(cache_dir, keep_local = TRUE)

pkg_path <- Sys.getenv("EX3_MONTHLY_PKG_PATH", unset = config$runtime$pkg_path)
daily_input_path <- Sys.getenv(
  "EX3_MONTHLY_DAILY_INPUT_PATH",
  unset = config$data$daily_input_path
)

if (!file.exists(file.path(pkg_path, "DESCRIPTION"))) {
  stop("Could not locate exdqlm source at: ", pkg_path)
}
if (!file.exists(daily_input_path)) {
  stop("Could not locate staged daily dataset at: ", daily_input_path)
}

pkgload::load_all(pkg_path, quiet = TRUE, export_all = FALSE)

options(
  exdqlm.use_cpp_kf = TRUE,
  exdqlm.use_cpp_builders = FALSE,
  exdqlm.use_cpp_samplers = FALSE,
  exdqlm.use_cpp_postpred = FALSE,
  exdqlm.max_iter = as.integer(config$model$ldvb$max_iter %||% 50L)
)

seed_base <- as.integer(config$runtime$seed)
set.seed(seed_base)

validate_ldvb_gamma_init <- function() {
  gam_init <- config$model$ldvb$gam_init
  if (is.null(gam_init) || is.na(gam_init)) {
    return(invisible(NULL))
  }
  p_levels <- as.numeric(config$model$p_levels)
  bad_rows <- lapply(p_levels, function(p0) {
    bounds <- exdqlm::get_gamma_bounds(p0)
    if (gam_init < bounds[["L"]] || gam_init > bounds[["U"]]) {
      data.frame(
        p0 = p0,
        lower = as.numeric(bounds[["L"]]),
        upper = as.numeric(bounds[["U"]]),
        stringsAsFactors = FALSE
      )
    } else {
      NULL
    }
  })
  bad_rows <- Filter(Negate(is.null), bad_rows)
  if (!length(bad_rows)) {
    return(invisible(NULL))
  }
  bad <- do.call(rbind, bad_rows)
  msg <- paste(
    sprintf(
      "  p0=%.2f requires gam.init in [%.6f, %.6f]",
      bad$p0, bad$lower, bad$upper
    ),
    collapse = "\n"
  )
  stop(
    sprintf(
      "Configured gam.init=%.6f is incompatible with the requested quantile grid.\n%s",
      as.numeric(gam_init),
      msg
    ),
    call. = FALSE
  )
}

validate_ldvb_gamma_init()

save_png_plot <- function(filename, expr, width = config$plots$width,
                          height = config$plots$height, res = config$plots$res,
                          pointsize = config$plots$pointsize) {
  path <- file.path(figure_dir, filename)
  grDevices::png(path, width = width, height = height, units = "in",
                 res = res, pointsize = pointsize)
  on.exit(grDevices::dev.off(), add = TRUE)
  force(expr)
  invisible(path)
}

save_gg_plot <- function(filename, plot_obj, width = config$plots$width,
                         height = config$plots$height, res = config$plots$res,
                         bg = "white") {
  path <- file.path(figure_dir, filename)
  ggplot2::ggsave(
    filename = path,
    plot = plot_obj,
    width = width,
    height = height,
    units = "in",
    dpi = res,
    bg = bg
  )
  invisible(path)
}

write_csv <- function(x, filename, row.names = FALSE) {
  utils::write.csv(x, file.path(table_dir, filename), row.names = row.names)
}

write_text <- function(lines, filename) {
  writeLines(lines, con = file.path(log_dir, filename))
}

reset_progress_log <- function() {
  writeLines(character(), con = progress_log_path)
}

log_progress <- function(msg, console = TRUE) {
  stamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  line <- sprintf("[%s] pid=%s | %s", stamp, Sys.getpid(), msg)
  cat(line, "\n", file = progress_log_path, append = TRUE, sep = "")
  if (isTRUE(console)) {
    cat(line, "\n", sep = "")
    flush(stdout())
  }
  invisible(line)
}

sha256_file <- function(path) {
  out <- system2("sha256sum", shQuote(path), stdout = TRUE, stderr = FALSE)
  sub("\\s+.*$", "", out[1])
}

git_ref <- function(path) {
  out <- tryCatch(
    system2("git", c("-C", path, "rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(e) character()
  )
  if (length(out)) out[1] else NA_character_
}

cache_read <- function(name) {
  path <- file.path(cache_dir, name)
  if (!file.exists(path)) {
    stop("Required cache file not found: ", path)
  }
  readRDS(path)
}

cache_write <- function(object, name) {
  saveRDS(object, file = file.path(cache_dir, name))
}

cache_exists <- function(name) {
  file.exists(file.path(cache_dir, name))
}

normalize_signature_object <- function(x) {
  if (is.null(x)) return(NULL)
  if (is.list(x)) return(lapply(x, normalize_signature_object))
  if (is.integer(x) || is.numeric(x)) return(unname(as.numeric(x)))
  if (is.logical(x)) return(unname(as.logical(x)))
  if (inherits(x, "Date")) return(as.character(x))
  if (is.character(x)) return(unname(as.character(x)))
  x
}

signature_objects_equal <- function(current_obj, cached_obj) {
  isTRUE(all.equal(
    normalize_signature_object(current_obj),
    normalize_signature_object(cached_obj),
    check.attributes = FALSE,
    tolerance = 1e-6
  ))
}

signature_file_read <- function(path) {
  if (!file.exists(path)) return(NULL)
  txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
  if (!nzchar(trimws(txt))) return(NULL)
  yaml::yaml.load(txt)
}

fit_cache_path <- function() {
  file.path(cache_dir, "ex3_monthly_fits_ldvb.rds")
}

fit_signature_path <- function() {
  file.path(cache_dir, "ex3_monthly_fit_signature.txt")
}

figure_data_signature_path <- function() {
  file.path(table_dir, "ex3_monthly_figure_data_signature.txt")
}

feature_base_terms <- function() {
  terms <- config$model$features$base_terms %||% character()
  unique(as.character(terms))
}

feature_lag_terms <- function() {
  terms <- config$model$features$lag_terms %||% c("flow", "flow_sq")
  unique(as.character(terms))
}

feature_lag_months <- function() {
  lag_months <- config$model$features$lag_months %||% integer()
  lag_months <- sort(unique(as.integer(lag_months)))
  lag_months[is.finite(lag_months) & lag_months > 0L]
}

fit_signature_object <- function() {
  normalize_signature_object(list(
    pkg_ref = git_ref(pkg_path),
    fit_start = as.character(config$data$fit_start),
    fit_end = as.character(config$data$fit_end),
    response_transform = config$data$response_transform,
    response_col = config$data$response_col,
    aggregation = config$data$aggregation,
    p_levels = as.numeric(config$model$p_levels),
    trend_order = as.integer(config$model$trend_order),
    seasonal_period = as.numeric(config$model$seasonal_period),
    seasonal_harmonics = as.numeric(config$model$seasonal_harmonics),
    features = list(
      base_terms = feature_base_terms(),
      lag_terms = feature_lag_terms(),
      lag_months = feature_lag_months()
    ),
    discounts = list(
      trend = as.numeric(config$model$discounts$trend),
      harmonics = as.numeric(config$model$discounts$harmonics),
      covariates = as.numeric(config$model$discounts$covariates)
    ),
    transfer = list(
      lam = as.numeric(config$model$transfer$lam),
      tf_df = as.numeric(config$model$transfer$tf_df)
    ),
    ldvb = list(
      tol = as.numeric(config$model$ldvb$tol),
      n_samp = as.integer(config$model$ldvb$n_samp),
      max_iter = as.integer(config$model$ldvb$max_iter),
      gam_init = as.numeric(config$model$ldvb$gam_init),
      sig_init = as.numeric(config$model$ldvb$sig_init)
    ),
    priors = list(
      trend_c0 = as.numeric(config$model$priors$trend_c0),
      seasonal_c0 = as.numeric(config$model$priors$seasonal_c0),
      reg_c0 = as.numeric(config$model$priors$reg_c0),
      transfer_zeta_c0 = as.numeric(config$model$priors$transfer_zeta_c0),
      transfer_psi_c0 = as.numeric(config$model$priors$transfer_psi_c0)
    )
  ))
}

write_fit_signature <- function() {
  writeLines(yaml::as.yaml(fit_signature_object()), con = fit_signature_path())
}

signature_file_text <- function(path) {
  if (!file.exists(path)) return(NULL)
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

fit_signature_text <- function() {
  signature_file_text(fit_signature_path())
}

figure_data_cache_ok <- function() {
  current_sig <- fit_signature_text()
  cached_sig <- signature_file_text(figure_data_signature_path())
  !is.null(current_sig) && identical(current_sig, cached_sig)
}

write_figure_data_signature <- function() {
  current_sig <- fit_signature_text()
  if (is.null(current_sig)) return(invisible(FALSE))
  writeLines(current_sig, con = figure_data_signature_path())
  invisible(TRUE)
}

fit_cache_status <- function() {
  if (!isTRUE(config$runtime$reuse_fit_cache %||% TRUE)) {
    return(list(can_reuse = FALSE, reason = "reuse_disabled"))
  }
  if (!cache_exists("ex3_monthly_fits_ldvb.rds")) {
    return(list(can_reuse = FALSE, reason = "cache_missing"))
  }
  cached_sig_obj <- signature_file_read(fit_signature_path())
  if (is.null(cached_sig_obj)) {
    return(list(can_reuse = FALSE, reason = "signature_missing"))
  }
  if (signature_objects_equal(fit_signature_object(), cached_sig_obj)) {
    return(list(can_reuse = TRUE, reason = "signature_match"))
  }
  list(can_reuse = FALSE, reason = "signature_mismatch")
}

transform_response <- function(x) {
  x <- as.numeric(x)
  transform_name <- as.character(config$data$response_transform %||% "log")
  if (identical(transform_name, "log")) {
    return(log(x))
  }
  stop("Unsupported response transform: ", transform_name)
}

feature_term_vector <- function(df, term) {
  switch(
    term,
    flow = as.numeric(df$usgs_cfs_monthly_mean),
    flow_sq = as.numeric(df$usgs_cfs_monthly_mean)^2,
    stop("Unsupported feature term: ", term)
  )
}

compute_feature_matrix <- function(df) {
  base_terms <- feature_base_terms()
  lag_terms <- feature_lag_terms()
  requested_terms <- unique(c(base_terms, lag_terms))
  term_df <- setNames(
    data.frame(
      lapply(requested_terms, function(term) feature_term_vector(df, term)),
      check.names = FALSE,
      stringsAsFactors = FALSE
    ),
    requested_terms
  )
  base_df <- term_df[base_terms]

  lag_months <- feature_lag_months()
  lag_terms <- intersect(lag_terms, names(term_df))
  if (!length(lag_months) || !length(lag_terms)) {
    return(as.matrix(term_df[base_terms]))
  }

  lagged_list <- lapply(lag_months, function(lag_i) {
    lagged_df <- data.frame(
      lapply(term_df[lag_terms], function(x) c(rep(NA_real_, lag_i), head(as.numeric(x), -lag_i))),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
    names(lagged_df) <- sprintf("%s_lag%d", names(lagged_df), lag_i)
    lagged_df
  })

  as.matrix(do.call(cbind, c(list(base_df), lagged_list)))
}

scale_feature_matrix <- function(X_train) {
  center <- colMeans(X_train)
  scale <- apply(X_train, 2, stats::sd)
  if (any(!is.finite(scale) | scale <= 0)) {
    stop("Feature scaling produced a non-positive standard deviation.")
  }
  list(
    X_train = scale(X_train, center = center, scale = scale),
    center = center,
    scale = scale
  )
}

make_base_model <- function(y_train, p0) {
  h <- as.numeric(config$model$seasonal_harmonics)
  trend_c0 <- diag(as.numeric(config$model$priors$trend_c0), as.integer(config$model$trend_order))
  seasonal_c0 <- diag(as.numeric(config$model$priors$seasonal_c0), 2L * length(h))

  trend_comp <- exdqlm::polytrendMod(
    order = as.integer(config$model$trend_order),
    m0 = as.numeric(stats::quantile(y_train, probs = p0)),
    C0 = trend_c0
  )
  seas_comp <- exdqlm::seasMod(
    p = as.numeric(config$model$seasonal_period),
    h = h,
    C0 = seasonal_c0
  )
  trend_comp + seas_comp
}

make_direct_spec <- function(y_train, p0, X_train_scaled) {
  base_model <- make_base_model(y_train, p0)
  reg_c0 <- diag(as.numeric(config$model$priors$reg_c0), ncol(X_train_scaled))
  reg_model <- exdqlm::regMod(X_train_scaled, m0 = rep(0, ncol(X_train_scaled)), C0 = reg_c0)

  list(
    model = base_model + reg_model,
    df = c(
      as.numeric(config$model$discounts$trend),
      as.numeric(config$model$discounts$harmonics),
      as.numeric(config$model$discounts$covariates)
    ),
    dim.df = c(
      as.integer(config$model$trend_order),
      rep(2L, length(config$model$seasonal_harmonics)),
      ncol(X_train_scaled)
    ),
    base_model = base_model
  )
}

make_transfer_spec <- function(y_train, p0, X_train_scaled) {
  base_model <- make_base_model(y_train, p0)
  k <- ncol(X_train_scaled)
  tf_dim <- k + 1L
  tf_diag <- c(
    as.numeric(config$model$priors$transfer_zeta_c0),
    rep(as.numeric(config$model$priors$transfer_psi_c0), k)
  )

  list(
    model = base_model,
    df = c(
      as.numeric(config$model$discounts$trend),
      as.numeric(config$model$discounts$harmonics)
    ),
    dim.df = c(
      as.integer(config$model$trend_order),
      rep(2L, length(config$model$seasonal_harmonics))
    ),
    lam = as.numeric(config$model$transfer$lam),
    tf.df = as.numeric(config$model$transfer$tf_df),
    tf.m0 = rep(0, tf_dim),
    tf.C0 = diag(tf_diag, tf_dim),
    base_model = base_model
  )
}

fit_model_pair <- function(p0, prep, fit_seed) {
  set.seed(fit_seed)
  direct_spec <- make_direct_spec(prep$y_train, p0, prep$X_train_scaled)
  transfer_spec <- make_transfer_spec(prep$y_train, p0, prep$X_train_scaled)
  fit_verbose <- isTRUE(config$model$ldvb$verbose %||% FALSE)

  ldvb_args <- list(
    fix.gamma = FALSE,
    gam.init = as.numeric(config$model$ldvb$gam_init),
    fix.sigma = FALSE,
    sig.init = as.numeric(config$model$ldvb$sig_init),
    tol = as.numeric(config$model$ldvb$tol),
    n.samp = as.integer(config$model$ldvb$n_samp),
    verbose = fit_verbose
  )

  log_progress(sprintf("fit_start | p0=%.2f | model=direct_regression | seed=%s", p0, fit_seed))
  direct_fit <- tryCatch(
    do.call(exdqlm::exdqlmLDVB, c(list(
      y = prep$y_train, p0 = p0,
      model = direct_spec$model,
      df = direct_spec$df, dim.df = direct_spec$dim.df
    ), ldvb_args)),
    error = function(e) e
  )
  if (fit_ok(direct_fit)) {
    log_progress(sprintf(
      "fit_done | p0=%.2f | model=direct_regression | iter=%s | converged=%s | runtime=%.3f",
      p0,
      direct_fit$iter %||% NA_integer_,
      isTRUE(direct_fit$converged),
      as.numeric(direct_fit$run.time)
    ))
  } else {
    log_progress(sprintf(
      "fit_error | p0=%.2f | model=direct_regression | message=%s",
      p0, conditionMessage(direct_fit)
    ))
  }

  log_progress(sprintf("fit_start | p0=%.2f | model=transfer_function | seed=%s", p0, fit_seed))
  transfer_fit <- tryCatch(
    do.call(exdqlm::exdqlmTransferLDVB, c(list(
      y = prep$y_train, p0 = p0,
      model = transfer_spec$model,
      X = prep$X_train_scaled,
      df = transfer_spec$df, dim.df = transfer_spec$dim.df,
      lam = transfer_spec$lam, tf.df = transfer_spec$tf.df,
      tf.m0 = transfer_spec$tf.m0, tf.C0 = transfer_spec$tf.C0
    ), ldvb_args)),
    error = function(e) e
  )
  if (fit_ok(transfer_fit)) {
    log_progress(sprintf(
      "fit_done | p0=%.2f | model=transfer_function | iter=%s | converged=%s | runtime=%.3f | median.kt=%.5f",
      p0,
      transfer_fit$iter %||% NA_integer_,
      isTRUE(transfer_fit$converged),
      as.numeric(transfer_fit$run.time),
      as.numeric(transfer_fit$median.kt)
    ))
  } else {
    log_progress(sprintf(
      "fit_error | p0=%.2f | model=transfer_function | message=%s",
      p0, conditionMessage(transfer_fit)
    ))
  }

  list(
    p0 = p0,
    direct = direct_fit,
    transfer = transfer_fit,
    direct_spec = direct_spec,
    transfer_spec = transfer_spec
  )
}

fit_ok <- function(x) !inherits(x, "error")

fit_hit_iter_cap <- function(fit) {
  max_iter <- as.integer(config$model$ldvb$max_iter %||% NA_integer_)
  if (!fit_ok(fit) || !is.finite(max_iter) || is.null(fit$iter)) {
    return(NA)
  }
  isFALSE(fit$converged) && as.integer(fit$iter) >= max_iter
}

fit_status_row <- function(p0, label, fit, median_kt = NA_real_) {
  if (!fit_ok(fit)) {
    return(data.frame(
      p0 = p0,
      model = label,
      status = "error",
      runtime = NA_real_,
      iter = NA_integer_,
      converged = NA,
      hit_iter_cap = NA,
      median_kt = median_kt,
      error_message = conditionMessage(fit),
      stringsAsFactors = FALSE
    ))
  }

  data.frame(
    p0 = p0,
    model = label,
    status = "ok",
    runtime = as.numeric(fit$run.time),
    iter = as.integer(fit$iter %||% NA_integer_),
    converged = isTRUE(fit$converged),
    hit_iter_cap = fit_hit_iter_cap(fit),
    median_kt = as.numeric(median_kt),
    error_message = "",
    stringsAsFactors = FALSE
  )
}

ldvb_convergence_row <- function(p0, label, fit) {
  if (!fit_ok(fit)) {
    return(data.frame(
      p0 = p0,
      model = label,
      iter = NA_integer_,
      converged = NA,
      stop_reason = "error",
      delta_state = NA_real_,
      delta_sigma = NA_real_,
      delta_gamma = NA_real_,
      delta_s = NA_real_,
      delta_elbo = NA_real_,
      committed_local_pass = NA,
      committed_grad_inf = NA_real_,
      committed_min_eig = NA_real_,
      candidate_local_pass = NA,
      candidate_grad_inf = NA_real_,
      candidate_min_eig = NA_real_,
      stringsAsFactors = FALSE
    ))
  }

  conv <- fit$diagnostics$convergence %||% list()
  final <- conv$final %||% list()
  mode_quality <- fit$diagnostics$ld_block$mode_quality %||% list()
  ld_final <- fit$diagnostics$ld_block$final %||% list()

  data.frame(
    p0 = p0,
    model = label,
    iter = as.integer(fit$iter %||% NA_integer_),
    converged = isTRUE(fit$converged),
    stop_reason = as.character(conv$stop_reason %||% NA_character_),
    delta_state = as.numeric(final$delta_state %||% NA_real_),
    delta_sigma = as.numeric(final$delta_sigma %||% NA_real_),
    delta_gamma = as.numeric(final$delta_gamma %||% NA_real_),
    delta_s = as.numeric(final$delta_s %||% NA_real_),
    delta_elbo = as.numeric(final$delta_elbo %||% NA_real_),
    committed_local_pass = as.logical(mode_quality$local_mode_pass %||% NA),
    committed_grad_inf = as.numeric(mode_quality$grad_inf_norm %||% NA_real_),
    committed_min_eig = as.numeric(mode_quality$neg_hess_min_eig %||% NA_real_),
    candidate_local_pass = as.logical(ld_final$ld_mode_local_pass_candidate %||% NA),
    candidate_grad_inf = as.numeric(ld_final$ld_mode_grad_inf_norm_candidate %||% NA_real_),
    candidate_min_eig = as.numeric(ld_final$ld_mode_neg_hess_min_eig_candidate %||% NA_real_),
    stringsAsFactors = FALSE
  )
}

diagnostics_summary <- function(fit, ref) {
  di <- exdqlm::exdqlmDiagnostics(fit, plot = FALSE, ref = ref)
  list(
    KL = as.numeric(di$m1.KL),
    CRPS = as.numeric(di$m1.CRPS),
    pplc = as.numeric(di$m1.pplc),
    runtime = as.numeric(fit$run.time)
  )
}

format_p0_label <- function(p0) sprintf("tau = %.2f", p0)

model_label <- function(label) {
  switch(
    label,
    direct_regression = "Direct regression",
    transfer_function = "Transfer function",
    label
  )
}

uncertainty_level <- function() {
  as.numeric(config$plots$uncertainty_level %||% 0.95)
}

posterior_ci_probs <- function(level = uncertainty_level()) {
  c((1 - level) / 2, 1 - (1 - level) / 2)
}

period_definitions <- function() {
  periods_cfg <- config$plots$periods %||% list(
    enso = list(label = "Strong El Nino (1997-1999)", start = "1997-01-01", end = "1999-12-01"),
    drought = list(label = "Dry / drought (2012-2016)", start = "2012-01-01", end = "2016-12-01")
  )
  rows <- lapply(names(periods_cfg), function(name) {
    period <- periods_cfg[[name]]
    data.frame(
      period = name,
      period_label = as.character(period$label %||% name),
      start = as.Date(period$start),
      end = as.Date(period$end),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

convergence_trim_start_iter <- function() {
  as.integer(config$plots$convergence_trim_start_iter %||% 20L)
}

historical_obs_color <- function() as.character(config$plots$historical_obs_color %||% "grey60")
historical_obs_point_size <- function() as.numeric(config$plots$historical_obs_point_size %||% 0.65)
historical_obs_linewidth <- function() as.numeric(config$plots$historical_obs_linewidth %||% 0.45)
historical_obs_shape <- function() as.integer(config$plots$historical_obs_shape %||% 1L)
historical_obs_stroke <- function() as.numeric(config$plots$historical_obs_stroke %||% 0.35)
state_zero_line_color <- function() as.character(config$plots$state_zero_line_color %||% "#8c6d1f")
state_zero_line_linewidth <- function() as.numeric(config$plots$state_zero_line_linewidth %||% 0.55)
quantile_line_alpha <- function() as.numeric(config$plots$quantile_line_alpha %||% 0.72)
quantile_ribbon_alpha <- function() as.numeric(config$plots$quantile_ribbon_alpha %||% 0.07)

quantile_palette <- function(p_levels = as.numeric(config$model$p_levels)) {
  labels <- vapply(p_levels, format_p0_label, character(1))
  cols <- config$plots$quantile_palette %||%
    c("#7f0000", "#b2182b", "#6b3f3f", "#111111", "#3e5f8a", "#2166ac", "#053061")
  cols <- as.character(cols)
  if (length(cols) != length(labels)) {
    cols <- grDevices::colorRampPalette(cols)(length(labels))
  }
  stats::setNames(cols, labels)
}

theme_ex3 <- function(base_size = config$plots$pointsize %||% 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 1),
      plot.subtitle = ggplot2::element_text(color = "grey25"),
      axis.title = ggplot2::element_text(face = "bold"),
      strip.text = ggplot2::element_text(face = "bold"),
      legend.position = "bottom",
      legend.title = ggplot2::element_text(face = "bold"),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_line(color = "grey88"),
      panel.grid.major.y = ggplot2::element_line(color = "grey90")
    )
}

subset_idx <- function(dates, start, end) {
  which(dates >= as.Date(start) & dates <= as.Date(end))
}

state_sd_from_sC <- function(sC, index, idx) {
  vals <- vapply(idx, function(tt) sC[index, index, tt], numeric(1))
  sqrt(pmax(vals, 0))
}

posterior_quantile_draw_matrix <- function(fit, idx) {
  idx <- as.integer(idx)
  FF <- as.matrix(fit$model$FF)[, idx, drop = FALSE]
  theta <- fit$samp.theta[, idx, , drop = FALSE]
  ns <- dim(theta)[3]
  draws <- vapply(seq_len(ns), function(s) {
    colSums(FF * theta[, , s])
  }, numeric(length(idx)))
  if (is.null(dim(draws))) {
    draws <- matrix(draws, nrow = length(idx), ncol = 1L)
  }
  draws
}

linear_component_draw_matrix <- function(fit, state_indices, weights, idx) {
  idx <- as.integer(idx)
  state_indices <- as.integer(state_indices)
  weights <- as.numeric(weights)
  theta <- fit$samp.theta[state_indices, idx, , drop = FALSE]
  ns <- dim(theta)[3]
  draws <- vapply(seq_len(ns), function(s) {
    theta_s <- matrix(
      theta[, , s, drop = TRUE],
      nrow = length(state_indices),
      ncol = length(idx)
    )
    as.numeric(crossprod(weights, theta_s))
  }, numeric(length(idx)))
  if (is.null(dim(draws))) {
    draws <- matrix(draws, nrow = length(idx), ncol = 1L)
  }
  draws
}

summarize_draw_matrix <- function(draws, level = uncertainty_level()) {
  probs <- posterior_ci_probs(level)
  data.frame(
    estimate = rowMeans(draws),
    lower = apply(draws, 1, stats::quantile, probs = probs[1], names = FALSE),
    upper = apply(draws, 1, stats::quantile, probs = probs[2], names = FALSE),
    stringsAsFactors = FALSE
  )
}

fitted_path_summary <- function(fit, dates, idx, p0, model, period_label,
                                level = uncertainty_level()) {
  draws <- posterior_quantile_draw_matrix(fit, idx)
  summary_df <- summarize_draw_matrix(draws, level = level)
  data.frame(
    date = dates[idx],
    period_label = period_label,
    model = model,
    model_label = model_label(model),
    p0 = p0,
    tau_label = format_p0_label(p0),
    phase = "fit",
    summary_df,
    stringsAsFactors = FALSE
  )
}

state_series_summary <- function(fit, state_index, state_name, state_label,
                                 dates, idx, p0, period_label,
                                 level = uncertainty_level()) {
  mu <- as.numeric(fit$theta.out$sm[state_index, idx])
  sd <- state_sd_from_sC(fit$theta.out$sC, state_index, idx)
  zcrit <- stats::qnorm((1 + level) / 2)
  data.frame(
    date = dates[idx],
    period_label = period_label,
    state = state_name,
    state_label = state_label,
    p0 = p0,
    tau_label = format_p0_label(p0),
    estimate = mu,
    lower = mu - zcrit * sd,
    upper = mu + zcrit * sd,
    stringsAsFactors = FALSE
  )
}

component_series_summary <- function(fit, state_indices, weights,
                                     component_name, component_label,
                                     dates, idx, p0, period_label,
                                     level = uncertainty_level()) {
  draws <- linear_component_draw_matrix(
    fit = fit,
    state_indices = state_indices,
    weights = weights,
    idx = idx
  )
  summary_df <- summarize_draw_matrix(draws, level = level)
  data.frame(
    date = dates[idx],
    period_label = period_label,
    component = component_name,
    component_label = component_label,
    p0 = p0,
    tau_label = format_p0_label(p0),
    summary_df,
    stringsAsFactors = FALSE
  )
}

transfer_state_indices <- function(res, prep) {
  base_p <- length(res$transfer_spec$base_model$m0)
  k <- ncol(prep$X_train_scaled)
  list(
    zeta = base_p + 1L,
    psi = seq.int(base_p + 2L, base_p + k + 1L),
    psi_names = colnames(prep$X_train_scaled)
  )
}

direct_state_indices <- function(res, prep) {
  base_p <- length(res$direct_spec$base_model$m0)
  k <- ncol(prep$X_train_scaled)
  list(
    beta = seq.int(base_p + 1L, base_p + k),
    beta_names = colnames(prep$X_train_scaled)
  )
}

state_label_map <- function(name) {
  if (length(name) != 1L) {
    return(vapply(name, state_label_map, character(1)))
  }
  if (grepl("_lag[0-9]+$", name)) {
    base_name <- sub("_lag[0-9]+$", "", name)
    lag_m <- sub("^.*_lag", "", name)
    return(sprintf("%s (lag %s)", state_label_map(base_name), lag_m))
  }
  switch(
    name,
    flow = "Monthly flow",
    flow_sq = "Monthly flow^2",
    zeta = "Transfer state zeta",
    name
  )
}

structural_component_labels <- function() {
  seasonal_period <- as.numeric(config$model$seasonal_period)
  harmonics <- as.numeric(config$model$seasonal_harmonics)
  c(
    "Trend component",
    vapply(seq_along(harmonics), function(jj) {
      cycle_months <- seasonal_period / harmonics[jj]
      cycle_label <- if (abs(cycle_months - round(cycle_months)) < 1e-6) {
        sprintf("%d-month cycle", as.integer(round(cycle_months)))
      } else {
        sprintf("%.2f-month cycle", cycle_months)
      }
      sprintf("Seasonal component %d (%s)", jj, cycle_label)
    }, character(1))
  )
}

structural_component_definitions <- function(res, model = c("direct", "transfer")) {
  model <- match.arg(model)
  base_model <- if (identical(model, "direct")) {
    res$direct_spec$base_model
  } else {
    res$transfer_spec$base_model
  }
  ff <- as.numeric(base_model$FF)
  trend_order <- as.integer(config$model$trend_order)
  labels <- structural_component_labels()
  defs <- list()

  if (trend_order > 0L) {
    idx <- seq_len(trend_order)
    defs[[length(defs) + 1L]] <- list(
      component = "trend",
      label = labels[1],
      indices = idx,
      weights = ff[idx]
    )
  }

  cursor <- trend_order
  seasonal_harmonics <- as.numeric(config$model$seasonal_harmonics)
  for (jj in seq_along(seasonal_harmonics)) {
    idx <- seq.int(cursor + 1L, cursor + 2L)
    defs[[length(defs) + 1L]] <- list(
      component = sprintf("seasonal_%d", jj),
      label = labels[jj + 1L],
      indices = idx,
      weights = ff[idx]
    )
    cursor <- cursor + 2L
  }

  defs
}

convergence_trace_for_fit <- function(fit, p0, model) {
  elbo <- as.numeric(fit$diagnostics$elbo %||% fit$misc$elbo %||% numeric())
  sigma <- as.numeric(fit$seq.sigma %||% numeric())
  gamma <- as.numeric(fit$seq.gamma %||% rep(NA_real_, length(sigma)))
  n_iter <- max(length(elbo), length(sigma), length(gamma), 0L)
  if (n_iter < 1L) return(data.frame())

  pad_to <- function(x, n) {
    x <- as.numeric(x)
    if (length(x) >= n) return(x[seq_len(n)])
    c(x, rep(NA_real_, n - length(x)))
  }

  data.frame(
    iter = seq_len(n_iter),
    p0 = p0,
    tau_label = format_p0_label(p0),
    model = model,
    model_label = model_label(model),
    elbo = pad_to(elbo, n_iter),
    sigma = pad_to(sigma, n_iter),
    gamma = pad_to(gamma, n_iter),
    stringsAsFactors = FALSE
  )
}

build_convergence_trace_df <- function(fit_results) {
  traces <- unlist(lapply(fit_results, function(res) {
    out <- list()
    if (fit_ok(res$direct)) {
      out[[length(out) + 1L]] <- convergence_trace_for_fit(res$direct, res$p0, "direct_regression")
    }
    if (fit_ok(res$transfer)) {
      out[[length(out) + 1L]] <- convergence_trace_for_fit(res$transfer, res$p0, "transfer_function")
    }
    out
  }), recursive = FALSE)
  if (!length(traces)) return(data.frame())
  do.call(rbind, traces)
}

trim_convergence_trace_df <- function(df, trim_start = convergence_trim_start_iter()) {
  out <- df
  mask <- out$iter < trim_start
  out$elbo[mask] <- NA_real_
  out$sigma[mask] <- NA_real_
  out$gamma[mask] <- NA_real_
  out
}

legend_grob <- function(plot_obj) {
  g <- ggplot2::ggplotGrob(plot_obj)
  idx <- which(vapply(g$grobs, function(x) x$name %||% "", character(1)) == "guide-box")
  if (length(idx)) g$grobs[[idx[1]]] else NULL
}

save_csv_if_rows <- function(df, filename) {
  if (!is.null(df) && nrow(df) > 0) write_csv(df, filename)
}
