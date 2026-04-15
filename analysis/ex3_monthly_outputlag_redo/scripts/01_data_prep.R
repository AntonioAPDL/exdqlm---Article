utils::data("BTflow", package = "exdqlm", envir = environment())

if (!exists("BTflow")) {
  stop("Required dataset BTflow is not available from the 0.4.0 package checkout.")
}

daily_df <- read.csv(daily_input_path, stringsAsFactors = FALSE)
daily_df$date <- as.Date(daily_df$date)
daily_df <- daily_df[order(daily_df$date), , drop = FALSE]

if (!config$data$response_col %in% names(daily_df)) {
  stop("Daily input is missing response column: ", config$data$response_col)
}

month_id <- format(daily_df$date, "%Y-%m")
monthly_flow <- aggregate(
  daily_df[[config$data$response_col]],
  by = list(month = month_id),
  FUN = mean
)
names(monthly_flow)[2] <- "usgs_cfs_monthly_mean"
monthly_flow$date <- as.Date(paste0(monthly_flow$month, "-01"))
monthly_flow$month <- NULL

bt_time <- time(BTflow)
bt_year <- floor(bt_time)
bt_month <- round((bt_time - bt_year) * 12 + 1)
bt_df <- data.frame(
  date = as.Date(sprintf("%04d-%02d-01", bt_year, bt_month)),
  BTflow = as.numeric(BTflow),
  stringsAsFactors = FALSE
)

monthly_df <- merge(monthly_flow, bt_df, by = "date", all.x = TRUE)
monthly_df <- monthly_df[order(monthly_df$date), , drop = FALSE]

fit_start <- as.Date(config$data$fit_start)
fit_end <- as.Date(config$data$fit_end)
fit_df0 <- monthly_df[monthly_df$date >= fit_start & monthly_df$date <= fit_end, , drop = FALSE]

if (!nrow(fit_df0)) {
  stop("Requested monthly fit window has no overlap with the aggregated San Lorenzo flow series.")
}

X_raw0 <- compute_feature_matrix(fit_df0)
keep_idx <- stats::complete.cases(X_raw0)
fit_df <- fit_df0[keep_idx, , drop = FALSE]
X_train_raw <- X_raw0[keep_idx, , drop = FALSE]

if (!nrow(fit_df)) {
  stop("No complete monthly rows remain after applying lagged output feature construction.")
}

scaled_features <- scale_feature_matrix(X_train_raw)
y_train <- transform_response(fit_df$usgs_cfs_monthly_mean)
ref_sample <- stats::rnorm(length(y_train))

bt_overlap <- monthly_df[stats::complete.cases(monthly_df$BTflow), c("date", "usgs_cfs_monthly_mean", "BTflow"), drop = FALSE]
bt_overlap$diff <- bt_overlap$BTflow - bt_overlap$usgs_cfs_monthly_mean
bt_overlap$log_diff <- log(bt_overlap$BTflow) - log(bt_overlap$usgs_cfs_monthly_mean)

bt_summary <- data.frame(
  overlap_start = as.character(min(bt_overlap$date)),
  overlap_end = as.character(max(bt_overlap$date)),
  overlap_n = nrow(bt_overlap),
  fit_start_requested = as.character(fit_start),
  fit_end_requested = as.character(fit_end),
  fit_start_modeled = as.character(min(fit_df$date)),
  fit_end_modeled = as.character(max(fit_df$date)),
  fit_n_modeled = nrow(fit_df),
  corr_raw = cor(bt_overlap$BTflow, bt_overlap$usgs_cfs_monthly_mean),
  corr_log = cor(log(bt_overlap$BTflow), log(bt_overlap$usgs_cfs_monthly_mean)),
  max_abs_diff = max(abs(bt_overlap$diff)),
  median_abs_diff = stats::median(abs(bt_overlap$diff)),
  stringsAsFactors = FALSE
)

prep <- list(
  daily_df = daily_df,
  monthly_df = monthly_df,
  fit_df = fit_df,
  y_train = y_train,
  X_train_raw = X_train_raw,
  X_train_scaled = scaled_features$X_train,
  X_center = scaled_features$center,
  X_scale = scaled_features$scale,
  ref_sample = ref_sample,
  fit_start_requested = fit_start,
  fit_end_requested = fit_end,
  fit_start_modeled = min(fit_df$date),
  fit_end_modeled = max(fit_df$date),
  btflow_summary = bt_summary
)

cache_write(prep, "ex3_monthly_prep.rds")
log_progress(sprintf(
  "prep_summary | monthly_n=%d | fit_n=%d | monthly_window=%s:%s | modeled_window=%s:%s",
  nrow(monthly_df), nrow(fit_df),
  min(monthly_df$date), max(monthly_df$date),
  min(fit_df$date), max(fit_df$date)
))

feature_names <- colnames(prep$X_train_scaled)
feature_base <- sub("_lag[0-9]+$", "", feature_names)
feature_lag <- rep.int(0L, length(feature_names))
lag_mask <- grepl("_lag[0-9]+$", feature_names)
feature_lag[lag_mask] <- as.integer(sub("^.*_lag", "", feature_names[lag_mask]))

write_csv(
  data.frame(
    monthly_start = as.character(min(monthly_df$date)),
    monthly_end = as.character(max(monthly_df$date)),
    monthly_n = nrow(monthly_df),
    fit_start_requested = as.character(fit_start),
    fit_end_requested = as.character(fit_end),
    fit_start_modeled = as.character(min(fit_df$date)),
    fit_end_modeled = as.character(max(fit_df$date)),
    fit_n_modeled = nrow(fit_df),
    dropped_for_lags = nrow(fit_df0) - nrow(fit_df),
    n_features = ncol(X_train_raw),
    base_feature_terms = paste(feature_base_terms(), collapse = ","),
    lag_feature_terms = paste(feature_lag_terms(), collapse = ","),
    feature_lag_months = paste(feature_lag_months(), collapse = ","),
    response_transform = config$data$response_transform,
    stringsAsFactors = FALSE
  ),
  "ex3_monthly_data_window_summary.csv"
)

write_csv(
  data.frame(
    covariate = feature_names,
    base_term = feature_base,
    lag = feature_lag,
    center = as.numeric(prep$X_center),
    scale = as.numeric(prep$X_scale),
    stringsAsFactors = FALSE
  ),
  "ex3_monthly_covariate_scaling.csv"
)

model_dataset <- data.frame(
  date = fit_df$date,
  usgs_cfs_monthly_mean = fit_df$usgs_cfs_monthly_mean,
  BTflow = fit_df$BTflow,
  y_train = y_train,
  X_train_raw,
  check.names = FALSE,
  stringsAsFactors = FALSE
)

write_csv(model_dataset, "ex3_monthly_model_dataset.csv")
write_csv(bt_summary, "ex3_monthly_btflow_comparison.csv")
