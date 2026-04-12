prep <- cache_read("ex3_daily_prep.rds")
fit_results <- cache_read("ex3_daily_fits_ldvb.rds")

diagnostic_rows <- list()
forecast_rows <- list()
forecast_objects <- list()

for (nm in names(fit_results)) {
  res <- fit_results[[nm]]
  p0 <- res$p0

  if (fit_ok(res$direct)) {
    direct_diag <- diagnostics_summary(res$direct, ref = prep$ref_sample)
    diagnostic_rows[[length(diagnostic_rows) + 1L]] <- data.frame(
      p0 = p0,
      model = "direct_regression",
      KL = direct_diag$KL,
      CRPS = direct_diag$CRPS,
      pplc = direct_diag$pplc,
      runtime = direct_diag$runtime,
      stringsAsFactors = FALSE
    )

    direct_forecast_mats <- build_direct_forecast_mats(
      base_model = res$direct_spec$base_model,
      X_future_scaled = prep$X_future_scaled
    )
    direct_fc <- exdqlm::exdqlmForecast(
      start.t = length(prep$y_train),
      k = nrow(prep$X_future_scaled),
      m1 = res$direct,
      fFF = direct_forecast_mats$fFF,
      fGG = direct_forecast_mats$fGG,
      plot = FALSE
    )
    forecast_objects[[sprintf("%s_direct", nm)]] <- direct_fc
    forecast_rows[[length(forecast_rows) + 1L]] <- forecast_summary_row(
      p0 = p0,
      label = "direct_regression",
      forecast_obj = direct_fc,
      y_future = prep$y_future
    )
  }

  if (fit_ok(res$transfer)) {
    transfer_diag <- diagnostics_summary(res$transfer, ref = prep$ref_sample)
    diagnostic_rows[[length(diagnostic_rows) + 1L]] <- data.frame(
      p0 = p0,
      model = "transfer_function",
      KL = transfer_diag$KL,
      CRPS = transfer_diag$CRPS,
      pplc = transfer_diag$pplc,
      runtime = transfer_diag$runtime,
      stringsAsFactors = FALSE
    )

    transfer_forecast_mats <- build_transfer_forecast_mats(
      base_model = res$transfer_spec$base_model,
      X_future_scaled = prep$X_future_scaled,
      lam = res$transfer_spec$lam
    )
    transfer_fc <- exdqlm::exdqlmForecast(
      start.t = length(prep$y_train),
      k = nrow(prep$X_future_scaled),
      m1 = res$transfer,
      fFF = transfer_forecast_mats$fFF,
      fGG = transfer_forecast_mats$fGG,
      plot = FALSE
    )
    forecast_objects[[sprintf("%s_transfer", nm)]] <- transfer_fc
    forecast_rows[[length(forecast_rows) + 1L]] <- forecast_summary_row(
      p0 = p0,
      label = "transfer_function",
      forecast_obj = transfer_fc,
      y_future = prep$y_future
    )
  }
}

diagnostic_df <- do.call(rbind, diagnostic_rows)
forecast_df <- do.call(rbind, forecast_rows)

write_csv(diagnostic_df, "ex3_daily_fit_diagnostics.csv")
write_csv(forecast_df, "ex3_daily_forecast_summary.csv")
cache_write(forecast_objects, "ex3_daily_forecasts_ldvb.rds")
