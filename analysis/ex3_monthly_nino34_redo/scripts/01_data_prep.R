utils::data("nino34", package = "exdqlm", envir = environment())

if (!exists("nino34")) {
  stop("Required dataset nino34 is not available from the 0.4.0 package checkout.")
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
names(monthly_flow)[2] <- "response_monthly_mean"
monthly_flow$date <- as.Date(paste0(monthly_flow$month, "-01"))
monthly_flow$month <- NULL
monthly_flow <- monthly_flow[order(monthly_flow$date), , drop = FALSE]

covariate_source <- covariate_source_name()

if (identical(covariate_source, "package_nino34")) {
  nino_time <- time(nino34)
  nino_year <- floor(nino_time)
  nino_month <- round((nino_time - nino_year) * 12 + 1)
  covariate_df <- data.frame(
    date = as.Date(sprintf("%04d-%02d-01", nino_year, nino_month)),
    nino34 = as.numeric(nino34),
    stringsAsFactors = FALSE
  )
  covariate_mapping <- data.frame(
    source = "package_nino34",
    original_name = "nino34",
    clean_name = "nino34",
    stringsAsFactors = FALSE
  )
} else if (identical(covariate_source, "climate_panel_csv")) {
  climate_panel_path <- as.character(config$data$climate_panel_path %||% "")
  date_col <- as.character(config$data$climate_panel_date_col %||% "Date")
  if (!nzchar(climate_panel_path) || !file.exists(climate_panel_path)) {
    stop("Climate-panel CSV not found: ", climate_panel_path)
  }
  panel_df <- read.csv(climate_panel_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!date_col %in% names(panel_df)) {
    stop("Climate-panel CSV is missing the configured date column: ", date_col)
  }
  panel_df$date <- as.Date(panel_df[[date_col]])
  if (anyNA(panel_df$date)) {
    stop("Climate-panel date column could not be parsed as Date values.")
  }
  raw_names <- setdiff(names(panel_df), c(date_col, "date"))
  clean_names <- sanitize_feature_names_unique(raw_names)

  covariate_df <- panel_df[, c("date", raw_names), drop = FALSE]
  names(covariate_df) <- c("date", clean_names)
  covariate_df <- covariate_df[order(covariate_df$date), , drop = FALSE]

  covariate_mapping <- data.frame(
    source = "climate_panel_csv",
    original_name = raw_names,
    clean_name = clean_names,
    stringsAsFactors = FALSE
  )
} else {
  stop("Unsupported covariate_source: ", covariate_source)
}

available_covariates <- setdiff(names(covariate_df), "date")
covariate_label_lookup <- stats::setNames(
  covariate_mapping$original_name,
  covariate_mapping$clean_name
)

overlap_df <- merge(monthly_flow, covariate_df, by = "date")
overlap_df <- overlap_df[order(overlap_df$date), , drop = FALSE]

fit_start <- as.Date(config$data$fit_start)
fit_end <- as.Date(config$data$fit_end)
fit_df0 <- overlap_df[overlap_df$date >= fit_start & overlap_df$date <= fit_end, , drop = FALSE]

if (!nrow(fit_df0)) {
  stop("Requested monthly fit window has no overlap between the response and covariates.")
}

resolved_base <- resolved_base_terms(available_covariates)
resolved_lags <- resolved_lag_terms(resolved_base)
preview_terms <- head(resolved_base, min(3L, length(resolved_base)))

X_raw0 <- compute_feature_matrix(fit_df0, available_covariates)
keep_idx <- stats::complete.cases(X_raw0)
fit_df <- fit_df0[keep_idx, , drop = FALSE]
X_train_raw <- X_raw0[keep_idx, , drop = FALSE]

if (!nrow(fit_df)) {
  stop("No complete monthly rows remain after applying the configured feature recipe.")
}

scaled_features <- scale_feature_matrix(X_train_raw)
y_train <- transform_response(fit_df$response_monthly_mean)
ref_sample <- stats::rnorm(length(y_train))

response_summary <- data.frame(
  overlap_start = as.character(min(overlap_df$date)),
  overlap_end = as.character(max(overlap_df$date)),
  overlap_n = nrow(overlap_df),
  fit_start_requested = as.character(fit_start),
  fit_end_requested = as.character(fit_end),
  fit_start_modeled = as.character(min(fit_df$date)),
  fit_end_modeled = as.character(max(fit_df$date)),
  fit_n_modeled = nrow(fit_df),
  mean_flow = mean(fit_df$response_monthly_mean),
  sd_flow = stats::sd(fit_df$response_monthly_mean),
  min_flow = min(fit_df$response_monthly_mean),
  max_flow = max(fit_df$response_monthly_mean),
  stringsAsFactors = FALSE
)

prep <- list(
  daily_df = daily_df,
  monthly_df = overlap_df,
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
  response_summary = response_summary,
  covariate_source = covariate_source,
  available_covariates = available_covariates,
  resolved_base_terms = resolved_base,
  resolved_lag_terms = resolved_lags,
  preview_terms = preview_terms,
  covariate_mapping = covariate_mapping,
  covariate_label_lookup = covariate_label_lookup
)

cache_write(prep, "ex3_monthly_prep.rds")
log_progress(sprintf(
  "prep_summary | covariate_source=%s | overlap_n=%d | fit_n=%d | n_covariates=%d | n_features=%d | overlap_window=%s:%s | modeled_window=%s:%s",
  covariate_source,
  nrow(overlap_df), nrow(fit_df),
  length(available_covariates), ncol(X_train_raw),
  min(overlap_df$date), max(overlap_df$date),
  min(fit_df$date), max(fit_df$date)
))

feature_names <- colnames(prep$X_train_scaled)
feature_base <- sub("_lag[0-9]+$", "", feature_names)
feature_lag <- rep.int(0L, length(feature_names))
lag_mask <- grepl("_lag[0-9]+$", feature_names)
feature_lag[lag_mask] <- as.integer(sub("^.*_lag", "", feature_names[lag_mask]))

write_csv(
  data.frame(
    covariate_source = covariate_source,
    overlap_start = as.character(min(overlap_df$date)),
    overlap_end = as.character(max(overlap_df$date)),
    overlap_n = nrow(overlap_df),
    fit_start_requested = as.character(fit_start),
    fit_end_requested = as.character(fit_end),
    fit_start_modeled = as.character(min(fit_df$date)),
    fit_end_modeled = as.character(max(fit_df$date)),
    fit_n_modeled = nrow(fit_df),
    dropped_for_lags = nrow(fit_df0) - nrow(fit_df),
    n_available_covariates = length(available_covariates),
    available_covariates = paste(available_covariates, collapse = ","),
    base_feature_terms = paste(resolved_base, collapse = ","),
    lag_feature_terms = paste(resolved_lags, collapse = ","),
    feature_lag_months = paste(feature_lag_months(), collapse = ","),
    n_features = ncol(X_train_raw),
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

write_csv(covariate_mapping, "ex3_monthly_covariate_mapping.csv")

model_dataset <- data.frame(
  date = fit_df$date,
  response_monthly_mean = fit_df$response_monthly_mean,
  y_train = y_train,
  fit_df[, available_covariates, drop = FALSE],
  stats::setNames(
    as.data.frame(X_train_raw, check.names = FALSE, stringsAsFactors = FALSE),
    paste0("feature__", colnames(X_train_raw))
  ),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

write_csv(model_dataset, "ex3_monthly_model_dataset.csv")
write_csv(response_summary, "ex3_monthly_response_summary.csv")
