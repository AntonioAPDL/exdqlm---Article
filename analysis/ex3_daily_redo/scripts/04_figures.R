prep <- cache_read("ex3_daily_prep.rds")
fit_results <- cache_read("ex3_daily_fits_ldvb.rds")
forecast_objects <- cache_read("ex3_daily_forecasts_ldvb.rds")
p_levels <- as.numeric(config$model$p_levels)
recent_days <- as.integer(config$plots$recent_window_days)
n_fit_panels <- length(p_levels) + 1L
n_rows <- ceiling(n_fit_panels / 2)

date_all <- prep$fit_df$date
date_recent_start <- max(prep$fit_start, prep$fit_end - recent_days)
recent_idx <- prep$fit_df$date >= date_recent_start
tail_idx <- prep$fit_df$date >= (prep$forecast_start - recent_days)

save_png_plot("ex3_daily_data_overview.png", {
  graphics::par(mfrow = c(3, 1), mar = c(3, 4, 2, 1))
  graphics::plot(prep$raw_df$date, prep$y_all, type = "l", col = "grey35",
                 xlab = "", ylab = "log(log(usgs+1))",
                 main = "Daily Big Trees prototype data")
  graphics::abline(v = prep$forecast_start, col = "firebrick", lty = 2)
  graphics::plot(prep$raw_df$date, prep$raw_df$ppt_mm, type = "l", col = "#0b6e99",
                 xlab = "", ylab = "ppt_mm")
  graphics::abline(v = prep$forecast_start, col = "firebrick", lty = 2)
  graphics::plot(prep$raw_df$date, prep$raw_df$soil_moisture, type = "l", col = "#4b7f52",
                 xlab = "date", ylab = "soil_moisture")
  graphics::abline(v = prep$forecast_start, col = "firebrick", lty = 2)
})

save_png_plot("ex3_daily_fit_recent.png", {
  graphics::par(mfrow = c(n_rows, 2), mar = c(3, 4, 2, 1))
  for (i in seq_along(p_levels)) {
    res <- fit_results[[sprintf("p%03d", round(100 * p_levels[i]))]]
    graphics::plot(prep$fit_df$date[recent_idx], prep$y_train[recent_idx], type = "l",
                   col = "grey70", xlab = "", ylab = sprintf("p0 = %.2f", p_levels[i]),
                   main = sprintf("Recent fit window (p0 = %.2f)", p_levels[i]))
    if (fit_ok(res$direct)) {
      direct_path <- extract_map_quantile(res$direct)
      graphics::lines(prep$fit_df$date[recent_idx], direct_path[recent_idx], col = "#7a3db8", lwd = 1.4)
    }
    if (fit_ok(res$transfer)) {
      transfer_path <- extract_map_quantile(res$transfer)
      graphics::lines(prep$fit_df$date[recent_idx], transfer_path[recent_idx], col = "#1f7a4d", lwd = 1.4)
    }
    graphics::abline(v = prep$forecast_start, col = "firebrick", lty = 2)
  }
  graphics::plot.new()
  graphics::legend("center",
                   legend = c("data", "direct regression", "transfer function", "forecast start"),
                   col = c("grey70", "#7a3db8", "#1f7a4d", "firebrick"),
                   lty = c(1, 1, 1, 2), bty = "n")
})

save_png_plot("ex3_daily_forecast_30d.png", {
  graphics::par(mfrow = c(n_rows, 2), mar = c(3, 4, 2, 1))
  obs_dates <- c(prep$fit_df$date[tail_idx], prep$future_df$date)
  obs_values <- c(prep$y_train[tail_idx], prep$y_future)
  for (i in seq_along(p_levels)) {
    p0 <- p_levels[i]
    key <- sprintf("p%03d", round(100 * p0))
    graphics::plot(obs_dates, obs_values, type = "l", col = "grey70",
                   xlab = "", ylab = sprintf("p0 = %.2f", p0),
                   main = sprintf("30-day forecast (p0 = %.2f)", p0))
    direct_fc <- forecast_objects[[sprintf("%s_direct", key)]]
    transfer_fc <- forecast_objects[[sprintf("%s_transfer", key)]]
    if (!is.null(direct_fc)) {
      direct_vals <- c(extract_map_quantile(fit_results[[key]]$direct)[tail_idx],
                       as.numeric(direct_fc$ff[seq_len(length(prep$y_future))]))
      graphics::lines(obs_dates, direct_vals, col = "#7a3db8", lwd = 1.4)
    }
    if (!is.null(transfer_fc)) {
      transfer_vals <- c(extract_map_quantile(fit_results[[key]]$transfer)[tail_idx],
                         as.numeric(transfer_fc$ff[seq_len(length(prep$y_future))]))
      graphics::lines(obs_dates, transfer_vals, col = "#1f7a4d", lwd = 1.4)
    }
    graphics::abline(v = prep$forecast_start, col = "firebrick", lty = 2)
  }
  graphics::plot.new()
  graphics::legend("center",
                   legend = c("data", "direct regression", "transfer function", "forecast start"),
                   col = c("grey70", "#7a3db8", "#1f7a4d", "firebrick"),
                   lty = c(1, 1, 1, 2), bty = "n")
})

plot_transfer_components <- function(p0, filename) {
  key <- sprintf("p%03d", round(100 * p0))
  res <- fit_results[[key]]
  if (!fit_ok(res$transfer)) {
    return(invisible(NULL))
  }
  fit <- res$transfer
  base_p <- length(res$transfer_spec$base_model$m0)
  zeta_idx <- base_p + 1L
  psi_idx <- seq.int(base_p + 2L, base_p + ncol(prep$X_train_scaled) + 1L)

  save_png_plot(filename, {
    graphics::par(mfrow = c(3, 2), mar = c(3, 4, 2, 1))
    zeta_plot <- exdqlm::compPlot(fit, index = zeta_idx, just.theta = TRUE, add = FALSE, col = "#1f7a4d")
    graphics::title(main = sprintf("Transfer states, p0 = %.2f", p0))
    for (j in seq_along(psi_idx)) {
      exdqlm::compPlot(fit, index = psi_idx[j], just.theta = TRUE, add = FALSE, col = "#0b6e99")
      graphics::title(main = colnames(prep$X_train_scaled)[j])
    }
  }, width = 12, height = 9)
}

plot_transfer_components(0.05, "ex3_daily_transfer_components_p05.png")
plot_transfer_components(0.50, "ex3_daily_transfer_components_p50.png")
