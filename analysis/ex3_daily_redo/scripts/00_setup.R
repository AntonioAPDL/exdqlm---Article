suppressWarnings(suppressMessages({
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' is required for analysis/ex3_daily_redo.")
  }
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("Package 'pkgload' is required for analysis/ex3_daily_redo.")
  }
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for analysis/ex3_daily_redo.")
  }
  if (!requireNamespace("gridExtra", quietly = TRUE)) {
    stop("Package 'gridExtra' is required for analysis/ex3_daily_redo.")
  }
  if (!requireNamespace("scales", quietly = TRUE)) {
    stop("Package 'scales' is required for analysis/ex3_daily_redo.")
  }
}))

if (!exists("redo_root", inherits = FALSE)) {
  stop("redo_root not defined. Run this workflow through analysis/ex3_daily_redo/run_all.R")
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
progress_log_path <- file.path(log_dir, "ex3_daily_progress.log")

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

pkg_path <- Sys.getenv("EX3_DAILY_PKG_PATH", unset = config$runtime$pkg_path)
data_path <- Sys.getenv("EX3_DAILY_DATA_PATH", unset = config$data$input_path)
if (!file.exists(file.path(pkg_path, "DESCRIPTION"))) {
  stop("Could not locate exdqlm source at: ", pkg_path)
}
if (!file.exists(data_path)) {
  stop("Could not locate staged daily dataset at: ", data_path)
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
  if (is.null(x)) {
    return(NULL)
  }
  if (is.list(x)) {
    return(lapply(x, normalize_signature_object))
  }
  if (is.integer(x) || is.numeric(x)) {
    return(unname(as.numeric(x)))
  }
  if (is.logical(x)) {
    return(unname(as.logical(x)))
  }
  if (inherits(x, "Date")) {
    return(as.character(x))
  }
  if (is.character(x)) {
    return(unname(as.character(x)))
  }
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
  if (!file.exists(path)) {
    return(NULL)
  }
  txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
  if (!nzchar(trimws(txt))) {
    return(NULL)
  }
  yaml::yaml.load(txt)
}

fit_signature_object <- function() {
  normalize_signature_object(list(
    pkg_ref = git_ref(pkg_path),
    fit_start = as.character(config$data$fit_start),
    fit_end = as.character(config$data$fit_end),
    response_transform = config$data$response_transform,
    response_col = config$data$response_col,
    ppt_col = config$data$ppt_col,
    soil_col = config$data$soil_col,
    p_levels = as.numeric(config$model$p_levels),
    trend_order = as.integer(config$model$trend_order),
    seasonal_period = as.numeric(config$model$seasonal_period),
    seasonal_harmonics = as.numeric(config$model$seasonal_harmonics),
    features = list(
      base_terms = feature_base_terms(),
      lag_days = feature_lag_days()
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
      transfer_c0 = as.numeric(config$model$priors$transfer_c0)
    )
  ))
}

fit_signature_string <- function() {
  sig_obj <- fit_signature_object()
  paste(yaml::as.yaml(sig_obj), collapse = "")
}

fit_signature_path <- function() {
  file.path(cache_dir, "ex3_daily_fit_signature.txt")
}

write_fit_signature <- function(signature = fit_signature_string()) {
  writeLines(signature, con = fit_signature_path())
}

fit_cache_status <- function() {
  if (!isTRUE(config$runtime$reuse_fit_cache %||% TRUE)) {
    return(list(can_reuse = FALSE, reason = "reuse_disabled"))
  }
  if (!cache_exists("ex3_daily_fits_ldvb.rds")) {
    return(list(can_reuse = FALSE, reason = "cache_missing"))
  }
  sig_path <- fit_signature_path()
  if (!file.exists(sig_path)) {
    return(list(can_reuse = TRUE, reason = "signature_missing_assumed_match"))
  }
  cached_sig_obj <- signature_file_read(sig_path)
  if (is.null(cached_sig_obj)) {
    return(list(can_reuse = TRUE, reason = "signature_missing_assumed_match"))
  }
  if (signature_objects_equal(fit_signature_object(), cached_sig_obj)) {
    return(list(can_reuse = TRUE, reason = "signature_match"))
  }
  list(can_reuse = FALSE, reason = "signature_mismatch")
}

fit_cache_path <- function() file.path(cache_dir, "ex3_daily_fits_ldvb.rds")
forecast_cache_path <- function() file.path(cache_dir, "ex3_daily_forecasts_ldvb.rds")
synthesis_cache_path <- function() file.path(cache_dir, "ex3_daily_predictive_synthesis.rds")

forecast_signature_object <- function() {
  normalize_signature_object(list(
    fit_signature = fit_signature_object(),
    forecast_start = as.character(config$data$forecast_start),
    forecast_horizon = as.integer(config$data$forecast_horizon),
    uncertainty_level = as.numeric(config$plots$uncertainty_level %||% 0.95)
  ))
}

forecast_signature_string <- function() {
  sig_obj <- forecast_signature_object()
  paste(yaml::as.yaml(sig_obj), collapse = "")
}

forecast_signature_path <- function() {
  file.path(cache_dir, "ex3_daily_forecast_signature.txt")
}

write_forecast_signature <- function(signature = forecast_signature_string()) {
  writeLines(signature, con = forecast_signature_path())
}

forecast_cache_status <- function() {
  if (!cache_exists("ex3_daily_forecasts_ldvb.rds")) {
    return(list(valid = FALSE, reason = "cache_missing"))
  }
  sig_path <- forecast_signature_path()
  if (!file.exists(sig_path)) {
    return(list(valid = FALSE, reason = "signature_missing"))
  }
  cached_sig_obj <- signature_file_read(sig_path)
  if (!is.null(cached_sig_obj) &&
      signature_objects_equal(forecast_signature_object(), cached_sig_obj)) {
    return(list(valid = TRUE, reason = "signature_match"))
  }
  list(valid = FALSE, reason = "signature_mismatch")
}

synthesis_signature_object <- function() {
  normalize_signature_object(list(
    method = "calibrated_quantile_grid_synthesis_v2",
    forecast_signature = forecast_signature_object(),
    forecast_context_days = forecast_context_days(),
    source_draws = synthesis_source_draws(),
    n_samp = synthesis_n_samp(),
    uncertainty_level = as.numeric(config$plots$uncertainty_level %||% 0.95)
  ))
}

synthesis_signature_string <- function() {
  sig_obj <- synthesis_signature_object()
  paste(yaml::as.yaml(sig_obj), collapse = "")
}

synthesis_signature_path <- function() {
  file.path(cache_dir, "ex3_daily_synthesis_signature.txt")
}

write_synthesis_signature <- function(signature = synthesis_signature_string()) {
  writeLines(signature, con = synthesis_signature_path())
}

synthesis_cache_status <- function() {
  if (!cache_exists("ex3_daily_predictive_synthesis.rds")) {
    return(list(valid = FALSE, reason = "cache_missing"))
  }
  sig_path <- synthesis_signature_path()
  if (!file.exists(sig_path)) {
    return(list(valid = FALSE, reason = "signature_missing"))
  }
  cached_sig_obj <- signature_file_read(sig_path)
  if (!is.null(cached_sig_obj) &&
      signature_objects_equal(synthesis_signature_object(), cached_sig_obj)) {
    return(list(valid = TRUE, reason = "signature_match"))
  }
  list(valid = FALSE, reason = "signature_mismatch")
}

transform_response <- function(x) {
  transform_name <- config$data$response_transform %||% "log_log1p"
  if (identical(transform_name, "log_log1p")) {
    return(log(log(x + 1)))
  }
  stop("Unsupported response transform: ", transform_name)
}

feature_base_terms <- function() {
  base_terms <- config$model$features$base_terms %||%
    c("ppt", "soil", "ppt_soil", "ppt2", "soil2")
  base_terms <- as.character(base_terms)
  if (!length(base_terms)) {
    stop("At least one base feature term must be specified.")
  }
  unique(base_terms)
}

feature_lag_days <- function() {
  lag_days <- config$model$features$lag_days %||% integer()
  lag_days <- sort(unique(as.integer(lag_days)))
  lag_days[is.finite(lag_days) & lag_days > 0L]
}

feature_term_vector <- function(df, term) {
  switch(
    term,
    ppt = as.numeric(df$ppt_mm),
    soil = as.numeric(df$soil_moisture),
    ppt_soil = as.numeric(df$ppt_mm) * as.numeric(df$soil_moisture),
    ppt2 = as.numeric(df$ppt_mm)^2,
    soil2 = as.numeric(df$soil_moisture)^2,
    stop("Unsupported feature term: ", term)
  )
}

compute_feature_matrix <- function(df) {
  base_terms <- feature_base_terms()
  base_df <- setNames(
    data.frame(
      lapply(base_terms, function(term) feature_term_vector(df, term)),
      check.names = FALSE,
      stringsAsFactors = FALSE
    ),
    base_terms
  )

  lag_days <- feature_lag_days()
  if (!length(lag_days)) {
    return(as.matrix(base_df))
  }

  lagged_list <- lapply(lag_days, function(lag_i) {
    lagged_df <- data.frame(
      lapply(base_df, function(x) c(rep(NA_real_, lag_i), head(as.numeric(x), -lag_i))),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
    names(lagged_df) <- sprintf("%s_lag%d", names(base_df), lag_i)
    lagged_df
  })

  as.matrix(do.call(cbind, c(list(base_df), lagged_list)))
}

scale_feature_matrix <- function(X_train, X_future) {
  center <- colMeans(X_train)
  scale <- apply(X_train, 2, stats::sd)
  if (any(!is.finite(scale) | scale <= 0)) {
    stop("Training-window feature scaling produced a non-positive standard deviation.")
  }

  list(
    X_train = scale(X_train, center = center, scale = scale),
    X_future = scale(X_future, center = center, scale = scale),
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
  tf_dim <- ncol(X_train_scaled) + 1L

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
    tf.C0 = diag(as.numeric(config$model$priors$transfer_c0), tf_dim),
    base_model = base_model
  )
}

build_direct_forecast_mats <- function(base_model, X_future_scaled) {
  reg_future <- exdqlm::regMod(
    X_future_scaled,
    m0 = rep(0, ncol(X_future_scaled)),
    C0 = diag(1, ncol(X_future_scaled))
  )
  future_model <- base_model + reg_future
  list(fFF = future_model$FF, fGG = future_model$GG)
}

build_transfer_forecast_mats <- function(base_model, X_future_scaled, lam) {
  X_future_scaled <- as.matrix(X_future_scaled)
  TT <- nrow(X_future_scaled)
  temp.p <- length(base_model$m0)
  k <- ncol(X_future_scaled)
  zeta_idx <- temp.p + 1L
  psi_idx <- seq.int(temp.p + 2L, temp.p + k + 1L)
  p_aug <- temp.p + k + 1L

  fFF <- matrix(0, p_aug, TT)
  fFF[seq_len(temp.p), ] <- matrix(base_model$FF, nrow = temp.p, ncol = TT)
  fFF[zeta_idx, ] <- 1

  fGG <- array(0, c(p_aug, p_aug, TT))
  fGG[seq_len(temp.p), seq_len(temp.p), ] <- array(base_model$GG, c(temp.p, temp.p, TT))
  fGG[zeta_idx, zeta_idx, ] <- lam
  for (j in seq_len(k)) {
    fGG[zeta_idx, psi_idx[j], ] <- X_future_scaled[, j]
    fGG[psi_idx[j], psi_idx[j], ] <- 1
  }

  list(fFF = fFF, fGG = fGG, zeta_idx = zeta_idx, psi_idx = psi_idx)
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
    do.call(exdqlm::transfn_exdqlmLDVB, c(list(
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

extract_map_quantile <- function(fit) {
  p <- dim(fit$samp.theta)[1]
  TT <- dim(fit$samp.theta)[2]
  n_samp <- dim(fit$samp.theta)[3]
  big_FF <- array(fit$model$FF, c(p, TT, n_samp))
  quant_samps <- colSums(big_FF * fit$samp.theta)
  rowMeans(quant_samps)
}

check_loss_fn <- function(p0, diff) {
  diff * p0 - diff * as.numeric(diff < 0)
}

forecast_summary_row <- function(p0, label, forecast_obj, y_future) {
  qhat <- as.numeric(forecast_obj$ff[seq_len(length(y_future))])
  data.frame(
    p0 = p0,
    model = label,
    horizon = length(y_future),
    mean_check_loss = mean(check_loss_fn(p0, y_future - qhat)),
    mean_abs_error = mean(abs(y_future - qhat)),
    stringsAsFactors = FALSE
  )
}

format_p0_label <- function(p0) {
  sprintf("tau = %.2f", p0)
}

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
    dry = list(label = "Dry / drought (2012-2016)", start = "2012-01-01", end = "2016-12-31"),
    rainy = list(label = "Rainy period (2017-2019)", start = "2017-01-01", end = "2019-12-31")
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

forecast_context_days <- function() {
  as.integer(config$plots$forecast_context_days %||% 30L)
}

convergence_trim_start_iter <- function() {
  as.integer(config$plots$convergence_trim_start_iter %||% 20L)
}

synthesis_source_draws <- function() {
  synth_cfg <- config$plots$synthesis %||% list()
  as.integer(synth_cfg$source_draws %||% config$model$ldvb$n_samp %||% 1000L)
}

synthesis_n_samp <- function() {
  synth_cfg <- config$plots$synthesis %||% list()
  as.integer(synth_cfg$n_samp %||% 1000L)
}

synthesis_line_color <- function() {
  synth_cfg <- config$plots$synthesis %||% list()
  as.character(synth_cfg$line_color %||% "#1f2733")
}

synthesis_linewidth <- function() {
  synth_cfg <- config$plots$synthesis %||% list()
  as.numeric(synth_cfg$line_width %||% 0.85)
}

synthesis_ribbon_fill <- function() {
  synth_cfg <- config$plots$synthesis %||% list()
  as.character(synth_cfg$ribbon_fill %||% "#9fb7d5")
}

synthesis_ribbon_alpha <- function() {
  synth_cfg <- config$plots$synthesis %||% list()
  as.numeric(synth_cfg$ribbon_alpha %||% 0.28)
}

historical_obs_color <- function() {
  as.character(config$plots$historical_obs_color %||% "grey60")
}

historical_obs_point_size <- function() {
  as.numeric(config$plots$historical_obs_point_size %||% 0.65)
}

future_obs_color <- function() {
  as.character(config$plots$future_obs_color %||% "#c76f1d")
}

future_obs_point_size <- function() {
  as.numeric(config$plots$future_obs_point_size %||% 1.8)
}

state_zero_line_color <- function() {
  as.character(config$plots$state_zero_line_color %||% "#8c6d1f")
}

state_zero_line_linewidth <- function() {
  as.numeric(config$plots$state_zero_line_linewidth %||% 0.55)
}

quantile_line_alpha <- function() {
  as.numeric(config$plots$quantile_line_alpha %||% 0.72)
}

quantile_ribbon_alpha <- function() {
  as.numeric(config$plots$quantile_ribbon_alpha %||% 0.07)
}

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

evenly_spaced_idx <- function(n, target_n) {
  target_n <- min(as.integer(target_n), as.integer(n))
  unique(pmax(1L, pmin(as.integer(n), round(seq.int(1L, n, length.out = target_n)))))
}

subset_draw_matrix <- function(M, target_n) {
  M <- as.matrix(M)
  idx <- evenly_spaced_idx(ncol(M), target_n)
  M[, idx, drop = FALSE]
}

subset_draw_vector <- function(x, target_n, fill = 0) {
  x <- as.numeric(x)
  if (!length(x)) return(rep(fill, target_n))
  idx <- evenly_spaced_idx(length(x), target_n)
  x[idx]
}

row_quantile_prob <- function(M, prob) {
  M <- as.matrix(M)
  if (requireNamespace("matrixStats", quietly = TRUE)) {
    as.numeric(matrixStats::rowQuantiles(M, probs = prob, na.rm = TRUE))
  } else {
    apply(M, 1L, stats::quantile, probs = prob, na.rm = TRUE, names = FALSE)
  }
}

calibrate_draw_matrix_to_quantile <- function(draws, p0, target_quantile) {
  draws <- as.matrix(draws)
  target_quantile <- as.numeric(target_quantile)
  if (nrow(draws) != length(target_quantile)) {
    stop("Target quantile vector length does not match the draw matrix row count.")
  }
  empirical_q <- row_quantile_prob(draws, prob = p0)
  sweep(draws, 1L, target_quantile - empirical_q, `+`)
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

summarize_draw_matrix <- function(draws, level = uncertainty_level()) {
  probs <- posterior_ci_probs(level)
  data.frame(
    estimate = rowMeans(draws),
    lower = apply(draws, 1, stats::quantile, probs = probs[1], names = FALSE),
    upper = apply(draws, 1, stats::quantile, probs = probs[2], names = FALSE),
    stringsAsFactors = FALSE
  )
}

synthesis_anchor_from_draws <- function(draws_list, p,
                                        enforce_isotonic = TRUE,
                                        T_expected = NULL) {
  stopifnot(is.list(draws_list), is.numeric(p), length(draws_list) == length(p))
  L <- length(p)
  if (L < 2L) stop("Need at least two quantile levels to build synthesis anchors.")

  dims_r <- vapply(draws_list, function(M) nrow(as.matrix(M)), 1L)
  dims_c <- vapply(draws_list, function(M) ncol(as.matrix(M)), 1L)
  if (is.null(T_expected)) {
    cand_tab <- sort(table(c(dims_r, dims_c)), decreasing = TRUE)
    Tt <- as.integer(names(cand_tab)[1])
  } else {
    Tt <- as.integer(T_expected)
  }

  mats <- lapply(draws_list, function(M) {
    M <- as.matrix(M)
    if (nrow(M) == Tt) {
      M
    } else if (ncol(M) == Tt) {
      t(M)
    } else {
      stop(
        sprintf(
          "A draw matrix has shape %dx%d; neither dimension matches T=%d.",
          nrow(M), ncol(M), Tt
        )
      )
    }
  })

  ord <- order(p)
  taus <- as.numeric(p[ord])
  mats <- mats[ord]

  if (any(!is.finite(taus)) || any(taus <= 0 | taus >= 1)) {
    stop("All synthesis quantile levels must lie in (0,1).")
  }
  if (any(diff(taus) <= 0)) {
    stop("Synthesis quantile levels must be strictly increasing.")
  }

  v_mat <- do.call(cbind, lapply(seq_len(L), function(i) {
    row_quantile_prob(mats[[i]], prob = taus[i])
  }))

  if (isTRUE(enforce_isotonic)) {
    m_adj <- t(apply(v_mat, 1L, function(vrow) stats::isoreg(x = taus, y = vrow)$yf))
  } else {
    m_adj <- v_mat
  }

  list(
    levels = taus,
    quantiles = m_adj
  )
}

eval_quantile_grid_row <- function(q_row, u, p_levels) {
  p_levels <- as.numeric(p_levels)
  q_row <- as.numeric(q_row)
  u <- as.numeric(u)

  out <- stats::approx(
    x = p_levels,
    y = q_row,
    xout = pmin(pmax(u, min(p_levels)), max(p_levels)),
    rule = 2,
    ties = "ordered"
  )$y

  left_mask <- u < p_levels[1L]
  if (any(left_mask)) {
    slope_left <- (q_row[2L] - q_row[1L]) / (p_levels[2L] - p_levels[1L])
    out[left_mask] <- q_row[1L] + slope_left * (u[left_mask] - p_levels[1L])
  }

  right_mask <- u > p_levels[length(p_levels)]
  if (any(right_mask)) {
    L <- length(p_levels)
    slope_right <- (q_row[L] - q_row[L - 1L]) / (p_levels[L] - p_levels[L - 1L])
    out[right_mask] <- q_row[L] + slope_right * (u[right_mask] - p_levels[L])
  }

  out
}

sample_from_quantile_grid <- function(anchor_obj, n_samp = synthesis_n_samp(), seed = NULL) {
  levels <- as.numeric(anchor_obj$levels)
  q_mat <- as.matrix(anchor_obj$quantiles)
  TT <- nrow(q_mat)
  n_samp <- as.integer(n_samp)

  sampler <- function() {
    U <- matrix(stats::runif(TT * n_samp), nrow = TT, ncol = n_samp)
    draws <- matrix(NA_real_, nrow = TT, ncol = n_samp)
    for (tt in seq_len(TT)) {
      draws[tt, ] <- eval_quantile_grid_row(q_mat[tt, ], U[tt, ], levels)
    }
    draws
  }

  draws <- if (is.null(seed)) sampler() else with_local_seed(seed, sampler())

  list(
    levels = levels,
    quantiles = q_mat,
    draws = draws,
    summary = list(
      mean = rowMeans(draws),
      q025 = row_quantile_prob(draws, 0.025),
      q250 = row_quantile_prob(draws, 0.250),
      q500 = row_quantile_prob(draws, 0.500),
      q750 = row_quantile_prob(draws, 0.750),
      q975 = row_quantile_prob(draws, 0.975)
    ),
    method = list(
      name = "calibrated-quantile-grid",
      n_samp = n_samp
    )
  )
}

synthesis_summary_df <- function(syn_obj, dates, model, phase) {
  data.frame(
    date = as.Date(dates),
    model = model,
    model_label = model_label(model),
    phase = phase,
    mean = as.numeric(syn_obj$summary$mean),
    q025 = as.numeric(syn_obj$summary$q025),
    q250 = as.numeric(syn_obj$summary$q250),
    q500 = as.numeric(syn_obj$summary$q500),
    q750 = as.numeric(syn_obj$summary$q750),
    q975 = as.numeric(syn_obj$summary$q975),
    estimate = as.numeric(syn_obj$summary$q500),
    lower = as.numeric(syn_obj$summary$q025),
    upper = as.numeric(syn_obj$summary$q975),
    stringsAsFactors = FALSE
  )
}

sample_forecast_predictive_draws <- function(mfit, fc, target_n, seed) {
  target_n <- min(as.integer(target_n), max(1L, ncol(as.matrix(mfit$samp.post.pred))))
  sigma_draws <- subset_draw_vector(mfit$samp.sigma, target_n)
  gamma_draws <- if (length(mfit$samp.gamma)) subset_draw_vector(mfit$samp.gamma, target_n) else rep(0, target_n)
  qdraw <- with_local_seed(seed, {
    Z <- matrix(stats::rnorm(length(fc$ff) * target_n), nrow = length(fc$ff), ncol = target_n)
    sweep(Z, 1L, sqrt(pmax(fc$fQ, 0)), `*`) + fc$ff
  })
  ydraw <- matrix(NA_real_, nrow = nrow(qdraw), ncol = ncol(qdraw))
  for (j in seq_len(ncol(qdraw))) {
    ydraw[, j] <- with_local_seed(seed + j, {
      exdqlm::rexal(
        nrow(qdraw),
        p0 = mfit$p0,
        mu = qdraw[, j],
        sigma = sigma_draws[j],
        gamma = gamma_draws[j]
      )
    })
  }
  list(qdraw = qdraw, ydraw = ydraw, sigma = sigma_draws, gamma = gamma_draws)
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

forecast_path_summary <- function(fit, forecast_obj, tail_dates, tail_idx,
                                  future_dates, p0, model,
                                  level = uncertainty_level()) {
  fit_df <- fitted_path_summary(
    fit = fit,
    dates = tail_dates,
    idx = tail_idx,
    p0 = p0,
    model = model,
    period_label = "Forecast context",
    level = level
  )
  fit_df$period_label <- NULL

  zcrit <- stats::qnorm((1 + level) / 2)
  fc_mean <- as.numeric(forecast_obj$ff[seq_along(future_dates)])
  fc_sd <- sqrt(pmax(as.numeric(forecast_obj$fQ[seq_along(future_dates)]), 0))
  fc_df <- data.frame(
    date = future_dates,
    model = model,
    model_label = model_label(model),
    p0 = p0,
    tau_label = format_p0_label(p0),
    phase = "forecast",
    estimate = fc_mean,
    lower = fc_mean - zcrit * fc_sd,
    upper = fc_mean + zcrit * fc_sd,
    stringsAsFactors = FALSE
  )

  rbind(fit_df, fc_df)
}

zeta_state_summary <- function(fit, res, prep, dates, idx, p0, period_label,
                               level = uncertainty_level()) {
  base_p <- length(res$transfer_spec$base_model$m0)
  zeta_idx <- base_p + 1L
  z_mean <- as.numeric(fit$theta.out$sm[zeta_idx, idx])
  z_sd <- state_sd_from_sC(fit$theta.out$sC, zeta_idx, idx)
  zcrit <- stats::qnorm((1 + level) / 2)
  data.frame(
    date = dates[idx],
    period_label = period_label,
    state = "zeta",
    state_label = "Transfer state zeta",
    p0 = p0,
    tau_label = format_p0_label(p0),
    estimate = z_mean,
    lower = z_mean - zcrit * z_sd,
    upper = z_mean + zcrit * z_sd,
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
    lag_days <- sub("^.*_lag", "", name)
    return(sprintf("%s (lag %s)", state_label_map(base_name), lag_days))
  }
  switch(
    name,
    ppt = "ppt",
    soil = "soil",
    ppt_soil = "ppt × soil",
    ppt2 = "ppt²",
    soil2 = "soil²",
    zeta = "Transfer state zeta",
    name
  )
}

convergence_trace_for_fit <- function(fit, p0, model) {
  elbo <- as.numeric(fit$diagnostics$elbo %||% fit$misc$elbo %||% numeric())
  sigma <- as.numeric(fit$seq.sigma %||% numeric())
  gamma <- as.numeric(fit$seq.gamma %||% rep(NA_real_, length(sigma)))
  n_iter <- max(length(elbo), length(sigma), length(gamma), 0L)
  if (n_iter < 1L) {
    return(data.frame())
  }

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

  if (!length(traces)) {
    return(data.frame())
  }
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
