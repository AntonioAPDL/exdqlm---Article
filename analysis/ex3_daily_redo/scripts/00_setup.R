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

for (dir_path in c(output_root, figure_dir, table_dir, log_dir, cache_dir)) {
  dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
}
cache_gitignore <- file.path(cache_dir, ".gitignore")
if (!file.exists(cache_gitignore)) {
  writeLines(c("*", "!.gitignore"), con = cache_gitignore)
}

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

fit_signature_string <- function() {
  sig_obj <- list(
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
  )
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
  current_sig <- fit_signature_string()
  if (!file.exists(sig_path)) {
    return(list(can_reuse = TRUE, reason = "signature_missing_assumed_match"))
  }
  cached_sig <- paste(readLines(sig_path, warn = FALSE), collapse = "")
  if (identical(cached_sig, current_sig)) {
    return(list(can_reuse = TRUE, reason = "signature_match"))
  }
  list(can_reuse = FALSE, reason = "signature_mismatch")
}

fit_cache_path <- function() file.path(cache_dir, "ex3_daily_fits_ldvb.rds")
forecast_cache_path <- function() file.path(cache_dir, "ex3_daily_forecasts_ldvb.rds")

transform_response <- function(x) {
  transform_name <- config$data$response_transform %||% "log_log1p"
  if (identical(transform_name, "log_log1p")) {
    return(log(log(x + 1)))
  }
  stop("Unsupported response transform: ", transform_name)
}

compute_feature_matrix <- function(df) {
  X <- with(df, cbind(
    ppt = ppt_mm,
    soil = soil_moisture,
    ppt_soil = ppt_mm * soil_moisture,
    ppt2 = ppt_mm^2,
    soil2 = soil_moisture^2
  ))
  as.matrix(X)
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
  as.integer(config$plots$forecast_context_days %||% 60L)
}

quantile_palette <- function(p_levels = as.numeric(config$model$p_levels)) {
  labels <- vapply(p_levels, format_p0_label, character(1))
  cols <- grDevices::hcl.colors(length(labels), palette = "Viridis")
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
    p0 = p0,
    tau_label = format_p0_label(p0),
    estimate = z_mean,
    lower = z_mean - zcrit * z_sd,
    upper = z_mean + zcrit * z_sd,
    stringsAsFactors = FALSE
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
