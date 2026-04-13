prep <- cache_read("ex3_daily_prep.rds")
fit_results <- cache_read("ex3_daily_fits_ldvb.rds")
forecast_objects <- cache_read("ex3_daily_forecasts_ldvb.rds")

p_levels <- as.numeric(config$model$p_levels)
tau_levels <- vapply(p_levels, format_p0_label, character(1))
model_levels <- c("Direct regression", "Transfer function")
periods <- period_definitions()
ci_level <- uncertainty_level()
ci_pct <- sprintf("%d%%", round(100 * ci_level))
quant_cols <- quantile_palette(p_levels)
forecast_h <- as.integer(config$data$forecast_horizon)
forecast_context_start <- max(c(prep$fit_start, prep$forecast_start - forecast_context_days()))

obsolete_figures <- c(
  "ex3_daily_fit_recent.png",
  "ex3_daily_forecast_30d.png",
  "ex3_daily_transfer_components_p05.png",
  "ex3_daily_transfer_components_p50.png"
)
unlink(file.path(figure_dir, obsolete_figures))

replicate_obs_by_model <- function(df) {
  do.call(rbind, lapply(model_levels, function(model_label_i) {
    out <- df
    out$model_label <- model_label_i
    out
  }))
}

build_fit_period_data <- function() {
  fit_rows <- list()
  obs_rows <- list()
  row_id <- 0L
  obs_id <- 0L

  for (ii in seq_len(nrow(periods))) {
    period_i <- periods[ii, ]
    idx <- subset_idx(prep$fit_df$date, period_i$start, period_i$end)
    if (!length(idx)) {
      next
    }

    obs_id <- obs_id + 1L
    obs_rows[[obs_id]] <- replicate_obs_by_model(data.frame(
      date = prep$fit_df$date[idx],
      y = prep$y_train[idx],
      period_label = period_i$period_label,
      stringsAsFactors = FALSE
    ))

    for (p0 in p_levels) {
      key <- sprintf("p%03d", round(100 * p0))
      res <- fit_results[[key]]

      if (fit_ok(res$direct)) {
        row_id <- row_id + 1L
        fit_rows[[row_id]] <- fitted_path_summary(
          fit = res$direct,
          dates = prep$fit_df$date,
          idx = idx,
          p0 = p0,
          model = "direct_regression",
          period_label = period_i$period_label,
          level = ci_level
        )
      }

      if (fit_ok(res$transfer)) {
        row_id <- row_id + 1L
        fit_rows[[row_id]] <- fitted_path_summary(
          fit = res$transfer,
          dates = prep$fit_df$date,
          idx = idx,
          p0 = p0,
          model = "transfer_function",
          period_label = period_i$period_label,
          level = ci_level
        )
      }
    }
  }

  fit_df <- do.call(rbind, fit_rows)
  obs_df <- do.call(rbind, obs_rows)

  fit_df$period_label <- factor(fit_df$period_label, levels = periods$period_label)
  fit_df$model_label <- factor(fit_df$model_label, levels = model_levels)
  fit_df$tau_label <- factor(fit_df$tau_label, levels = tau_levels)

  obs_df$period_label <- factor(obs_df$period_label, levels = periods$period_label)
  obs_df$model_label <- factor(obs_df$model_label, levels = model_levels)

  list(fit = fit_df, obs = obs_df)
}

build_forecast_plot_data <- function() {
  tail_idx <- which(prep$fit_df$date >= forecast_context_start)
  obs_df <- replicate_obs_by_model(data.frame(
    date = c(prep$fit_df$date[tail_idx], prep$future_df$date),
    y = c(prep$y_train[tail_idx], prep$y_future),
    phase = c(rep("fit", length(tail_idx)), rep("forecast", nrow(prep$future_df))),
    stringsAsFactors = FALSE
  ))

  fc_rows <- list()
  row_id <- 0L
  for (p0 in p_levels) {
    key <- sprintf("p%03d", round(100 * p0))
    res <- fit_results[[key]]

    direct_fc <- forecast_objects[[sprintf("%s_direct", key)]]
    if (fit_ok(res$direct) && !is.null(direct_fc)) {
      row_id <- row_id + 1L
      fc_rows[[row_id]] <- forecast_path_summary(
        fit = res$direct,
        forecast_obj = direct_fc,
        tail_dates = prep$fit_df$date,
        tail_idx = tail_idx,
        future_dates = prep$future_df$date,
        p0 = p0,
        model = "direct_regression",
        level = ci_level
      )
    }

    transfer_fc <- forecast_objects[[sprintf("%s_transfer", key)]]
    if (fit_ok(res$transfer) && !is.null(transfer_fc)) {
      row_id <- row_id + 1L
      fc_rows[[row_id]] <- forecast_path_summary(
        fit = res$transfer,
        forecast_obj = transfer_fc,
        tail_dates = prep$fit_df$date,
        tail_idx = tail_idx,
        future_dates = prep$future_df$date,
        p0 = p0,
        model = "transfer_function",
        level = ci_level
      )
    }
  }

  fc_df <- do.call(rbind, fc_rows)
  fc_df$model_label <- factor(fc_df$model_label, levels = model_levels)
  fc_df$tau_label <- factor(fc_df$tau_label, levels = tau_levels)
  obs_df$model_label <- factor(obs_df$model_label, levels = model_levels)

  list(forecast = fc_df, obs = obs_df)
}

build_zeta_period_data <- function() {
  zeta_rows <- list()
  row_id <- 0L

  for (ii in seq_len(nrow(periods))) {
    period_i <- periods[ii, ]
    idx <- subset_idx(prep$fit_df$date, period_i$start, period_i$end)
    if (!length(idx)) {
      next
    }

    for (p0 in p_levels) {
      key <- sprintf("p%03d", round(100 * p0))
      res <- fit_results[[key]]
      if (!fit_ok(res$transfer)) {
        next
      }

      row_id <- row_id + 1L
      zeta_rows[[row_id]] <- zeta_state_summary(
        fit = res$transfer,
        res = res,
        prep = prep,
        dates = prep$fit_df$date,
        idx = idx,
        p0 = p0,
        period_label = period_i$period_label,
        level = ci_level
      )
    }
  }

  zeta_df <- do.call(rbind, zeta_rows)
  zeta_df$period_label <- factor(zeta_df$period_label, levels = periods$period_label)
  zeta_df$tau_label <- factor(zeta_df$tau_label, levels = tau_levels)
  zeta_df
}

build_convergence_plot_data <- function() {
  conv_df <- build_convergence_trace_df(fit_results)
  conv_df$model_label <- factor(conv_df$model_label, levels = model_levels)
  conv_df$tau_label <- factor(conv_df$tau_label, levels = tau_levels)
  conv_df
}

save_csv_if_rows <- function(df, filename) {
  if (!is.null(df) && nrow(df) > 0) {
    write_csv(df, filename)
  }
}

fit_plot_data <- build_fit_period_data()
forecast_plot_data <- build_forecast_plot_data()
zeta_plot_data <- build_zeta_period_data()
convergence_df <- build_convergence_plot_data()

save_csv_if_rows(fit_plot_data$fit, "ex3_daily_fit_periods_summary.csv")
save_csv_if_rows(forecast_plot_data$forecast, "ex3_daily_forecast_plot_summary.csv")
save_csv_if_rows(zeta_plot_data, "ex3_daily_transfer_zeta_summary.csv")
save_csv_if_rows(convergence_df, "ex3_daily_convergence_traces.csv")

save_png_plot("ex3_daily_data_overview.png", {
  graphics::par(mfrow = c(3, 1), mar = c(3, 4, 2, 1))
  graphics::plot(
    prep$raw_df$date, prep$y_all, type = "l", col = "grey35",
    xlab = "", ylab = "log(log(usgs+1))",
    main = "Daily Big Trees prototype data"
  )
  graphics::abline(v = prep$forecast_start, col = "firebrick", lty = 2)
  graphics::plot(
    prep$raw_df$date, prep$raw_df$ppt_mm, type = "l", col = "#0b6e99",
    xlab = "", ylab = "ppt_mm"
  )
  graphics::abline(v = prep$forecast_start, col = "firebrick", lty = 2)
  graphics::plot(
    prep$raw_df$date, prep$raw_df$soil_moisture, type = "l", col = "#4b7f52",
    xlab = "date", ylab = "soil_moisture"
  )
  graphics::abline(v = prep$forecast_start, col = "firebrick", lty = 2)
})

fit_period_plot <- ggplot2::ggplot() +
  ggplot2::geom_line(
    data = fit_plot_data$obs,
    ggplot2::aes(x = date, y = y),
    color = "grey70",
    linewidth = 0.35
  ) +
  ggplot2::geom_ribbon(
    data = fit_plot_data$fit,
    ggplot2::aes(x = date, ymin = lower, ymax = upper, fill = tau_label, group = tau_label),
    alpha = 0.10,
    color = NA,
    show.legend = FALSE
  ) +
  ggplot2::geom_line(
    data = fit_plot_data$fit,
    ggplot2::aes(x = date, y = estimate, color = tau_label),
    linewidth = 0.55
  ) +
  ggplot2::facet_grid(period_label ~ model_label, scales = "free_x") +
  ggplot2::scale_color_manual(values = quant_cols, name = "Quantile level") +
  ggplot2::scale_fill_manual(values = quant_cols) +
  ggplot2::labs(
    title = "Dry and rainy period fits across all seven quantiles",
    subtitle = sprintf(
      "Rows compare a dry/drought window (2012-2016) and a rainy window (2017-2019); shaded bands show %s posterior intervals.",
      ci_pct
    ),
    x = NULL,
    y = "Transformed streamflow"
  ) +
  theme_ex3()

save_gg_plot("ex3_daily_fit_periods.png", fit_period_plot, width = 13, height = 10)

forecast_plot <- ggplot2::ggplot() +
  ggplot2::geom_line(
    data = forecast_plot_data$obs,
    ggplot2::aes(x = date, y = y),
    color = "grey70",
    linewidth = 0.4
  ) +
  ggplot2::geom_ribbon(
    data = forecast_plot_data$forecast,
    ggplot2::aes(x = date, ymin = lower, ymax = upper, fill = tau_label, group = tau_label),
    alpha = 0.11,
    color = NA,
    show.legend = FALSE
  ) +
  ggplot2::geom_line(
    data = forecast_plot_data$forecast,
    ggplot2::aes(x = date, y = estimate, color = tau_label, linetype = phase),
    linewidth = 0.65
  ) +
  ggplot2::annotate(
    "segment",
    x = prep$forecast_start,
    xend = prep$forecast_start,
    y = -Inf,
    yend = Inf,
    color = "firebrick",
    linetype = 2,
    linewidth = 0.6
  ) +
  ggplot2::facet_wrap(~ model_label, nrow = 1) +
  ggplot2::scale_color_manual(values = quant_cols, name = "Quantile level") +
  ggplot2::scale_fill_manual(values = quant_cols) +
  ggplot2::scale_linetype_manual(values = c(fit = "solid", forecast = "solid"), guide = "none") +
  ggplot2::labs(
    title = sprintf("Fixed-horizon %d-day forecast across all seven quantiles", forecast_h),
    subtitle = sprintf(
      "Each panel shows the last %d fit days plus the %d-day holdout; shaded bands show %s uncertainty for the estimated quantile path.",
      as.integer(as.numeric(prep$forecast_start - forecast_context_start)),
      forecast_h,
      ci_pct
    ),
    x = NULL,
    y = "Transformed streamflow"
  ) +
  theme_ex3()

save_gg_plot("ex3_daily_forecast_quantiles.png", forecast_plot, width = 13, height = 6.8)

zeta_plot <- ggplot2::ggplot(zeta_plot_data, ggplot2::aes(x = date, y = estimate, color = tau_label, fill = tau_label)) +
  ggplot2::geom_ribbon(
    ggplot2::aes(ymin = lower, ymax = upper),
    alpha = 0.12,
    color = NA,
    show.legend = FALSE
  ) +
  ggplot2::geom_line(linewidth = 0.65) +
  ggplot2::facet_wrap(~ period_label, nrow = 1, scales = "free_x") +
  ggplot2::scale_color_manual(values = quant_cols, name = "Quantile level") +
  ggplot2::scale_fill_manual(values = quant_cols) +
  ggplot2::labs(
    title = "Transfer-effect state across dry and rainy periods",
    subtitle = sprintf(
      "Panels show the smoothed zeta_t state for the transfer-function model across all seven quantiles; shaded bands show %s Gaussian state intervals.",
      ci_pct
    ),
    x = NULL,
    y = expression(zeta[t])
  ) +
  theme_ex3()

save_gg_plot("ex3_daily_transfer_zeta_periods.png", zeta_plot, width = 13, height = 6.4)

make_convergence_plot <- function(df, value_col, title, subtitle, filename) {
  plot_df <- df[!is.na(df[[value_col]]), , drop = FALSE]
  plot_df$value <- plot_df[[value_col]]
  plot_obj <- ggplot2::ggplot(plot_df, ggplot2::aes(x = iter, y = value, color = tau_label)) +
    ggplot2::geom_line(linewidth = 0.55, alpha = 0.95) +
    ggplot2::facet_wrap(~ model_label, ncol = 1, scales = "free_y") +
    ggplot2::scale_color_manual(values = quant_cols, name = "Quantile level") +
    ggplot2::labs(
      title = title,
      subtitle = subtitle,
      x = "LDVB iteration",
      y = NULL
    ) +
    theme_ex3()
  save_gg_plot(filename, plot_obj, width = 11.5, height = 8.0)
}

make_convergence_plot(
  convergence_df,
  value_col = "elbo",
  title = "ELBO traces from the cached full-history LDVB fits",
  subtitle = "Each curve tracks one quantile level; panels split the direct and transfer models.",
  filename = "ex3_daily_convergence_elbo.png"
)

make_convergence_plot(
  convergence_df,
  value_col = "sigma",
  title = "Sigma trajectories from the cached full-history LDVB fits",
  subtitle = "These traces show how the scale parameter stabilized across the seven quantile models.",
  filename = "ex3_daily_convergence_sigma.png"
)

make_convergence_plot(
  convergence_df,
  value_col = "gamma",
  title = "Gamma trajectories from the cached full-history LDVB fits",
  subtitle = "These traces show the skewness parameter path under the exAL formulation.",
  filename = "ex3_daily_convergence_gamma.png"
)

log_progress("figures_written | redesigned fit, forecast, transfer, and convergence figures completed")
