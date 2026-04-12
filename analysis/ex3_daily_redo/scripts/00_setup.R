suppressWarnings(suppressMessages({
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' is required for analysis/ex3_daily_redo.")
  }
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("Package 'pkgload' is required for analysis/ex3_daily_redo.")
  }
}))

if (!exists("redo_root", inherits = FALSE)) {
  stop("redo_root not defined. Run this workflow through analysis/ex3_daily_redo/run_all.R")
}
if (!exists("config_path", inherits = FALSE)) {
  config_path <- file.path(redo_root, "config.yml")
}

config <- yaml::read_yaml(config_path)
output_root <- file.path(redo_root, "outputs")
figure_dir <- file.path(output_root, "figures")
table_dir <- file.path(output_root, "tables")
log_dir <- file.path(output_root, "logs")
cache_dir <- file.path(output_root, "cache")

for (dir_path in c(output_root, figure_dir, table_dir, log_dir, cache_dir)) {
  dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
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

`%||%` <- function(x, y) if (is.null(x)) y else x

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

write_csv <- function(x, filename, row.names = FALSE) {
  utils::write.csv(x, file.path(table_dir, filename), row.names = row.names)
}

write_text <- function(lines, filename) {
  writeLines(lines, con = file.path(log_dir, filename))
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

  ldvb_args <- list(
    fix.gamma = FALSE,
    gam.init = as.numeric(config$model$ldvb$gam_init),
    fix.sigma = FALSE,
    sig.init = as.numeric(config$model$ldvb$sig_init),
    tol = as.numeric(config$model$ldvb$tol),
    n.samp = as.integer(config$model$ldvb$n_samp),
    verbose = FALSE
  )

  direct_fit <- tryCatch(
    do.call(exdqlm::exdqlmLDVB, c(list(
      y = prep$y_train, p0 = p0,
      model = direct_spec$model,
      df = direct_spec$df, dim.df = direct_spec$dim.df
    ), ldvb_args)),
    error = function(e) e
  )

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

  list(
    p0 = p0,
    direct = direct_fit,
    transfer = transfer_fit,
    direct_spec = direct_spec,
    transfer_spec = transfer_spec
  )
}

fit_ok <- function(x) !inherits(x, "error")

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
