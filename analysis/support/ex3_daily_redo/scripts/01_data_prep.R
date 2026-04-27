raw_df <- read.csv(data_path, stringsAsFactors = FALSE)
raw_df$date <- as.Date(raw_df$date)

fit_start <- as.Date(config$data$fit_start)
fit_end <- as.Date(config$data$fit_end)
forecast_start <- as.Date(config$data$forecast_start)
forecast_h <- as.integer(config$data$forecast_horizon)
forecast_end <- forecast_start + (forecast_h - 1L)

fit_idx <- raw_df$date >= fit_start & raw_df$date <= fit_end
future_idx <- raw_df$date >= forecast_start & raw_df$date <= forecast_end

if (!all(c(config$data$response_col, config$data$ppt_col, config$data$soil_col) %in% names(raw_df))) {
  stop("Daily redo dataset is missing one or more required columns.")
}
if (!any(fit_idx) || !any(future_idx)) {
  stop("Requested fit/forecast windows are not present in the staged dataset.")
}

fit_df <- raw_df[fit_idx, , drop = FALSE]
future_df <- raw_df[future_idx, , drop = FALSE]
y_all <- transform_response(raw_df[[config$data$response_col]])
y_train <- y_all[fit_idx]
y_future <- y_all[future_idx]

X_all_raw <- compute_feature_matrix(raw_df)
X_train_raw <- X_all_raw[fit_idx, , drop = FALSE]
X_future_raw <- X_all_raw[future_idx, , drop = FALSE]
if (anyNA(X_train_raw) || anyNA(X_future_raw)) {
  max_lag <- max(c(0L, feature_lag_days()))
  stop(
    "Lagged feature construction produced missing values inside the fit/forecast windows. ",
    "Choose a later fit_start or reduce the configured feature lag depth (current max lag = ",
    max_lag, ")."
  )
}
scaled_features <- scale_feature_matrix(X_train_raw, X_future_raw)
ref_sample <- stats::rnorm(length(y_train))

prep <- list(
  raw_df = raw_df,
  fit_df = fit_df,
  future_df = future_df,
  y_all = y_all,
  y_train = y_train,
  y_future = y_future,
  X_train_raw = X_train_raw,
  X_future_raw = X_future_raw,
  X_train_scaled = scaled_features$X_train,
  X_future_scaled = scaled_features$X_future,
  X_center = scaled_features$center,
  X_scale = scaled_features$scale,
  ref_sample = ref_sample,
  fit_start = fit_start,
  fit_end = fit_end,
  forecast_start = forecast_start,
  forecast_end = forecast_end
)

cache_write(prep, "ex3_daily_prep.rds")
log_progress(sprintf(
  "prep_summary | fit_n=%d | forecast_n=%d | fit_window=%s:%s | forecast_window=%s:%s",
  nrow(fit_df), nrow(future_df), fit_start, fit_end, forecast_start, forecast_end
))

write_csv(
  data.frame(
    fit_start = as.character(fit_start),
    fit_end = as.character(fit_end),
    fit_n = nrow(fit_df),
    forecast_start = as.character(forecast_start),
    forecast_end = as.character(forecast_end),
    forecast_n = nrow(future_df),
    data_start = as.character(min(raw_df$date)),
    data_end = as.character(max(raw_df$date)),
    data_n = nrow(raw_df),
    n_features = ncol(X_train_raw),
    base_feature_terms = paste(feature_base_terms(), collapse = ","),
    feature_lag_days = paste(feature_lag_days(), collapse = ","),
    response_transform = config$data$response_transform,
    stringsAsFactors = FALSE
  ),
  "ex3_daily_data_window_summary.csv"
)

feature_names <- colnames(prep$X_train_scaled)
feature_base <- sub("_lag[0-9]+$", "", feature_names)
feature_lag <- rep.int(0L, length(feature_names))
lag_mask <- grepl("_lag[0-9]+$", feature_names)
feature_lag[lag_mask] <- as.integer(sub("^.*_lag", "", feature_names[lag_mask]))

write_csv(
  data.frame(
    covariate = feature_names,
    base_term = feature_base,
    lag = feature_lag,
    center = as.numeric(prep$X_center),
    scale = as.numeric(prep$X_scale),
    stringsAsFactors = FALSE
  ),
  "ex3_daily_covariate_scaling.csv"
)
