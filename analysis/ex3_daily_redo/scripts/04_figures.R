prep <- cache_read("ex3_daily_prep.rds")
fit_results <- NULL
forecast_objects <- NULL

p_levels <- as.numeric(config$model$p_levels)
tau_levels <- vapply(p_levels, format_p0_label, character(1))
model_levels <- c("Direct regression", "Transfer function")
periods <- period_definitions()
ci_level <- uncertainty_level()
ci_pct <- sprintf("%d%%", round(100 * ci_level))
quant_cols <- quantile_palette(p_levels)
forecast_h <- as.integer(config$data$forecast_horizon)
forecast_context_start <- max(c(prep$fit_start, prep$forecast_start - forecast_context_days()))
trim_iter <- convergence_trim_start_iter()

obsolete_figures <- c(
  "ex3_daily_fit_recent.png",
  "ex3_daily_forecast_30d.png",
  "ex3_daily_transfer_components_p05.png",
  "ex3_daily_transfer_components_p50.png",
  "ex3_daily_transfer_zeta_periods.png"
)
unlink(file.path(figure_dir, obsolete_figures))

obsolete_tables <- c("ex3_daily_transfer_zeta_summary.csv")
unlink(file.path(table_dir, obsolete_tables))

read_cached_table <- function(filename, date_cols = NULL) {
  path <- file.path(table_dir, filename)
  if (!file.exists(path)) {
    return(NULL)
  }
  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  for (col in intersect(date_cols %||% character(), names(df))) {
    df[[col]] <- as.Date(df[[col]])
  }
  df
}

get_fit_results <- function() {
  if (is.null(fit_results)) {
    fit_results <<- cache_read("ex3_daily_fits_ldvb.rds")
  }
  fit_results
}

get_forecast_objects <- function() {
  if (is.null(forecast_objects)) {
    fc_status <- forecast_cache_status()
    if (!isTRUE(fc_status$valid)) {
      stop(
        "Forecast cache is not valid for the current config (",
        fc_status$reason,
        "). Rerun the forecast step before regenerating figures."
      )
    }
    forecast_objects <<- cache_read("ex3_daily_forecasts_ldvb.rds")
  }
  forecast_objects
}

replicate_obs_by_model <- function(df) {
  do.call(rbind, lapply(model_levels, function(model_label_i) {
    out <- df
    out$model_label <- model_label_i
    out
  }))
}

build_fit_period_obs <- function() {
  obs_rows <- list()
  obs_id <- 0L

  for (ii in seq_len(nrow(periods))) {
    period_i <- periods[ii, ]
    idx <- subset_idx(prep$fit_df$date, period_i$start, period_i$end)
    if (!length(idx)) next

    obs_id <- obs_id + 1L
    obs_rows[[obs_id]] <- replicate_obs_by_model(data.frame(
      date = prep$fit_df$date[idx],
      y = prep$y_train[idx],
      period_label = period_i$period_label,
      stringsAsFactors = FALSE
    ))
  }

  obs_df <- do.call(rbind, obs_rows)
  obs_df$period_label <- factor(obs_df$period_label, levels = periods$period_label)
  obs_df$model_label <- factor(obs_df$model_label, levels = model_levels)
  obs_df
}

build_fit_period_data <- function() {
  cached_fit <- read_cached_table("ex3_daily_fit_periods_summary.csv", date_cols = "date")
  if (!is.null(cached_fit)) {
    cached_fit$period_label <- factor(cached_fit$period_label, levels = periods$period_label)
    cached_fit$model_label <- factor(cached_fit$model_label, levels = model_levels)
    cached_fit$tau_label <- factor(cached_fit$tau_label, levels = tau_levels)
    return(list(fit = cached_fit, obs = build_fit_period_obs()))
  }

  fit_results <- get_fit_results()
  fit_rows <- list()
  row_id <- 0L

  for (ii in seq_len(nrow(periods))) {
    period_i <- periods[ii, ]
    idx <- subset_idx(prep$fit_df$date, period_i$start, period_i$end)
    if (!length(idx)) next

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
  obs_df <- build_fit_period_obs()

  fit_df$period_label <- factor(fit_df$period_label, levels = periods$period_label)
  fit_df$model_label <- factor(fit_df$model_label, levels = model_levels)
  fit_df$tau_label <- factor(fit_df$tau_label, levels = tau_levels)

  list(fit = fit_df, obs = obs_df)
}

build_forecast_plot_data <- function() {
  cached_fc <- read_cached_table("ex3_daily_forecast_plot_summary.csv", date_cols = "date")
  tail_idx <- which(prep$fit_df$date >= forecast_context_start)

  obs_hist <- replicate_obs_by_model(data.frame(
    date = prep$fit_df$date[tail_idx],
    y = prep$y_train[tail_idx],
    obs_phase = "history",
    stringsAsFactors = FALSE
  ))
  obs_future <- replicate_obs_by_model(data.frame(
    date = prep$future_df$date,
    y = prep$y_future,
    obs_phase = "future",
    stringsAsFactors = FALSE
  ))
  obs_hist$model_label <- factor(obs_hist$model_label, levels = model_levels)
  obs_future$model_label <- factor(obs_future$model_label, levels = model_levels)

  if (!is.null(cached_fc)) {
    cached_fc$model_label <- factor(cached_fc$model_label, levels = model_levels)
    cached_fc$tau_label <- factor(cached_fc$tau_label, levels = tau_levels)
    return(list(forecast = cached_fc, obs_hist = obs_hist, obs_future = obs_future))
  }

  fit_results <- get_fit_results()
  forecast_objects <- get_forecast_objects()
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

  list(forecast = fc_df, obs_hist = obs_hist, obs_future = obs_future)
}

build_transfer_state_data <- function() {
  cached_df <- read_cached_table("ex3_daily_transfer_states_summary.csv", date_cols = "date")
  if (!is.null(cached_df)) {
    cached_df$period_label <- factor(cached_df$period_label, levels = periods$period_label)
    cached_df$tau_label <- factor(cached_df$tau_label, levels = tau_levels)
    cached_df$state_label <- factor(
      cached_df$state_label,
      levels = c("Transfer state zeta", state_label_map(colnames(prep$X_train_scaled)))
    )
    return(cached_df)
  }

  fit_results <- get_fit_results()
  out <- list()
  row_id <- 0L

  for (ii in seq_len(nrow(periods))) {
    period_i <- periods[ii, ]
    idx <- subset_idx(prep$fit_df$date, period_i$start, period_i$end)
    if (!length(idx)) next

    for (p0 in p_levels) {
      key <- sprintf("p%03d", round(100 * p0))
      res <- fit_results[[key]]
      if (!fit_ok(res$transfer)) next

      idx_map <- transfer_state_indices(res, prep)
      row_id <- row_id + 1L
      out[[row_id]] <- state_series_summary(
        fit = res$transfer,
        state_index = idx_map$zeta,
        state_name = "zeta",
        state_label = "Transfer state zeta",
        dates = prep$fit_df$date,
        idx = idx,
        p0 = p0,
        period_label = period_i$period_label,
        level = ci_level
      )

      for (jj in seq_along(idx_map$psi)) {
        row_id <- row_id + 1L
        out[[row_id]] <- state_series_summary(
          fit = res$transfer,
          state_index = idx_map$psi[jj],
          state_name = idx_map$psi_names[jj],
          state_label = state_label_map(idx_map$psi_names[jj]),
          dates = prep$fit_df$date,
          idx = idx,
          p0 = p0,
          period_label = period_i$period_label,
          level = ci_level
        )
      }
    }
  }

  df <- do.call(rbind, out)
  df$period_label <- factor(df$period_label, levels = periods$period_label)
  df$tau_label <- factor(df$tau_label, levels = tau_levels)
  df$state_label <- factor(
    df$state_label,
    levels = c("Transfer state zeta", state_label_map(colnames(prep$X_train_scaled)))
  )
  df
}

build_direct_state_data <- function() {
  cached_df <- read_cached_table("ex3_daily_direct_states_summary.csv", date_cols = "date")
  if (!is.null(cached_df)) {
    cached_df$period_label <- factor(cached_df$period_label, levels = periods$period_label)
    cached_df$tau_label <- factor(cached_df$tau_label, levels = tau_levels)
    cached_df$state_label <- factor(cached_df$state_label, levels = state_label_map(colnames(prep$X_train_scaled)))
    return(cached_df)
  }

  fit_results <- get_fit_results()
  out <- list()
  row_id <- 0L

  for (ii in seq_len(nrow(periods))) {
    period_i <- periods[ii, ]
    idx <- subset_idx(prep$fit_df$date, period_i$start, period_i$end)
    if (!length(idx)) next

    for (p0 in p_levels) {
      key <- sprintf("p%03d", round(100 * p0))
      res <- fit_results[[key]]
      if (!fit_ok(res$direct)) next

      idx_map <- direct_state_indices(res, prep)
      for (jj in seq_along(idx_map$beta)) {
        row_id <- row_id + 1L
        out[[row_id]] <- state_series_summary(
          fit = res$direct,
          state_index = idx_map$beta[jj],
          state_name = idx_map$beta_names[jj],
          state_label = state_label_map(idx_map$beta_names[jj]),
          dates = prep$fit_df$date,
          idx = idx,
          p0 = p0,
          period_label = period_i$period_label,
          level = ci_level
        )
      }
    }
  }

  df <- do.call(rbind, out)
  df$period_label <- factor(df$period_label, levels = periods$period_label)
  df$tau_label <- factor(df$tau_label, levels = tau_levels)
  df$state_label <- factor(df$state_label, levels = state_label_map(colnames(prep$X_train_scaled)))
  df
}

build_convergence_plot_data <- function() {
  conv_df <- read_cached_table("ex3_daily_convergence_traces.csv")
  if (is.null(conv_df)) {
    fit_results <- get_fit_results()
    conv_df <- trim_convergence_trace_df(build_convergence_trace_df(fit_results), trim_start = trim_iter)
  }
  conv_df$model_label <- factor(conv_df$model_label, levels = model_levels)
  conv_df$tau_label <- factor(conv_df$tau_label, levels = tau_levels)
  conv_df
}

save_csv_if_rows <- function(df, filename) {
  if (!is.null(df) && nrow(df) > 0) write_csv(df, filename)
}

state_panel_plot <- function(df, panel_title, show_legend = FALSE) {
  ggplot2::ggplot(df, ggplot2::aes(x = date, y = estimate, color = tau_label, fill = tau_label)) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = lower, ymax = upper),
      alpha = quantile_ribbon_alpha(),
      color = NA,
      show.legend = FALSE
    ) +
    ggplot2::geom_line(
      linewidth = 0.55,
      alpha = quantile_line_alpha()
    ) +
    ggplot2::scale_color_manual(values = quant_cols, name = "Quantile level") +
    ggplot2::scale_fill_manual(values = quant_cols) +
    ggplot2::labs(title = panel_title, x = NULL, y = NULL) +
    theme_ex3(base_size = 10) +
    ggplot2::theme(
      legend.position = if (show_legend) "bottom" else "none",
      plot.title = ggplot2::element_text(size = 10.5, face = "bold"),
      axis.text.x = ggplot2::element_text(size = 8),
      axis.text.y = ggplot2::element_text(size = 8)
    )
}

render_state_figure <- function(df, period_label, model_type, filename, title) {
  period_df <- df[df$period_label == period_label, , drop = FALSE]
  if (!nrow(period_df)) return(invisible(NULL))

  if (identical(model_type, "transfer")) {
    state_order <- c("Transfer state zeta", state_label_map(colnames(prep$X_train_scaled)))
  } else {
    state_order <- state_label_map(colnames(prep$X_train_scaled))
  }

  state_labels <- intersect(state_order, unique(as.character(period_df$state_label)))
  period_df$state_label <- factor(period_df$state_label, levels = state_labels)

  dummy_label <- state_labels[1]
  legend_plot <- state_panel_plot(
    df = period_df[period_df$state_label == dummy_label, , drop = FALSE],
    panel_title = dummy_label,
    show_legend = TRUE
  )
  leg <- legend_grob(legend_plot)

  if (identical(model_type, "transfer")) {
    zeta_df <- period_df[period_df$state_label == "Transfer state zeta", , drop = FALSE]
    psi_df <- period_df[period_df$state_label != "Transfer state zeta", , drop = FALSE]

    zeta_plot <- state_panel_plot(
      df = zeta_df,
      panel_title = "Transfer state zeta",
      show_legend = FALSE
    ) +
      ggplot2::theme(
        plot.margin = ggplot2::margin(5.5, 5.5, 0, 5.5),
        axis.title.y = ggplot2::element_text(face = "bold")
      ) +
      ggplot2::labs(y = NULL)

    psi_plot <- ggplot2::ggplot(
      psi_df,
      ggplot2::aes(x = date, y = estimate, color = tau_label, fill = tau_label)
    ) +
      ggplot2::geom_hline(
        yintercept = 0,
        color = state_zero_line_color(),
        linewidth = state_zero_line_linewidth(),
        linetype = "solid"
      ) +
      ggplot2::geom_ribbon(
        ggplot2::aes(ymin = lower, ymax = upper),
        alpha = quantile_ribbon_alpha(),
        color = NA,
        show.legend = FALSE
      ) +
      ggplot2::geom_line(
        linewidth = 0.5,
        alpha = quantile_line_alpha()
      ) +
      ggplot2::facet_wrap(~ state_label, scales = "free_y", ncol = 4) +
      ggplot2::scale_color_manual(values = quant_cols, name = "Quantile level") +
      ggplot2::scale_fill_manual(values = quant_cols) +
      ggplot2::labs(x = NULL, y = NULL) +
      theme_ex3(base_size = 10) +
      ggplot2::theme(
        legend.position = "none",
        strip.text = ggplot2::element_text(size = 9.5, face = "bold"),
        axis.text.x = ggplot2::element_text(size = 7.5),
        axis.text.y = ggplot2::element_text(size = 7.5),
        plot.margin = ggplot2::margin(0, 5.5, 5.5, 5.5)
      )

    full_grob <- gridExtra::arrangeGrob(
      ggplot2::ggplotGrob(zeta_plot),
      ggplot2::ggplotGrob(psi_plot),
      leg,
      ncol = 1,
      heights = c(2.2, max(4, ceiling(length(state_labels[-1]) / 4)) * 1.6, 0.8),
      top = grid::textGrob(
        title,
        gp = grid::gpar(fontsize = 14, fontface = "bold")
      )
    )
    fig_height <- 12 + 0.8 * max(0, ceiling(length(state_labels[-1]) / 4) - 5)
  } else {
    beta_plot <- ggplot2::ggplot(
      period_df,
      ggplot2::aes(x = date, y = estimate, color = tau_label, fill = tau_label)
    ) +
      ggplot2::geom_hline(
        yintercept = 0,
        color = state_zero_line_color(),
        linewidth = state_zero_line_linewidth(),
        linetype = "solid"
      ) +
      ggplot2::geom_ribbon(
        ggplot2::aes(ymin = lower, ymax = upper),
        alpha = quantile_ribbon_alpha(),
        color = NA,
        show.legend = FALSE
      ) +
      ggplot2::geom_line(
        linewidth = 0.5,
        alpha = quantile_line_alpha()
      ) +
      ggplot2::facet_wrap(~ state_label, scales = "free_y", ncol = 4) +
      ggplot2::scale_color_manual(values = quant_cols, name = "Quantile level") +
      ggplot2::scale_fill_manual(values = quant_cols) +
      ggplot2::labs(x = NULL, y = NULL) +
      theme_ex3(base_size = 10) +
      ggplot2::theme(
        legend.position = "none",
        strip.text = ggplot2::element_text(size = 9.5, face = "bold"),
        axis.text.x = ggplot2::element_text(size = 7.5),
        axis.text.y = ggplot2::element_text(size = 7.5)
      )

    full_grob <- gridExtra::arrangeGrob(
      ggplot2::ggplotGrob(beta_plot),
      leg,
      ncol = 1,
      heights = c(max(4, ceiling(length(state_labels) / 4)) * 1.8, 0.8),
      top = grid::textGrob(
        title,
        gp = grid::gpar(fontsize = 14, fontface = "bold")
      )
    )
    fig_height <- 10 + 0.8 * max(0, ceiling(length(state_labels) / 4) - 5)
  }

  save_png_plot(
    filename,
    {
      grid::grid.newpage()
      grid::grid.draw(full_grob)
    },
    width = 13,
    height = fig_height
  )
}

make_convergence_plot <- function(df, value_col, title, filename) {
  plot_df <- df[!is.na(df[[value_col]]), , drop = FALSE]
  subtitle <- sprintf(
    "Curves are shown from iteration %d onward to suppress early start-up scale distortion; the x-axis still spans the full iteration range.",
    trim_iter
  )
  if (!nrow(plot_df)) {
    placeholder <- ggplot2::ggplot() +
      ggplot2::annotate(
        "text",
        x = 0.5,
        y = 0.5,
        label = sprintf(
          "No %s trace values remain after trimming iterations before %d.",
          value_col,
          trim_iter
        ),
        size = 4.4,
        color = "grey25"
      ) +
      ggplot2::xlim(0, 1) +
      ggplot2::ylim(0, 1) +
      ggplot2::labs(
        title = title,
        subtitle = subtitle,
        x = NULL,
        y = NULL
      ) +
      theme_ex3() +
      ggplot2::theme(
        axis.text = ggplot2::element_blank(),
        axis.ticks = ggplot2::element_blank(),
        panel.grid = ggplot2::element_blank()
      )
    save_gg_plot(filename, placeholder, width = 11.5, height = 8.0)
    return(invisible(NULL))
  }

  plot_df$value <- plot_df[[value_col]]
  max_iter <- max(df$iter, na.rm = TRUE)
  plot_obj <- ggplot2::ggplot(plot_df, ggplot2::aes(x = iter, y = value, color = tau_label)) +
    ggplot2::geom_vline(xintercept = trim_iter, color = "grey55", linetype = 3, linewidth = 0.5) +
    ggplot2::geom_line(linewidth = 0.55, alpha = 0.9) +
    ggplot2::facet_wrap(~ model_label, ncol = 1, scales = "free_y") +
    ggplot2::scale_color_manual(values = quant_cols, name = "Quantile level") +
    ggplot2::scale_x_continuous(limits = c(0, max_iter), expand = c(0.01, 0.01)) +
    ggplot2::labs(
      title = title,
      subtitle = subtitle,
      x = "LDVB iteration",
      y = NULL
    ) +
    theme_ex3()
  save_gg_plot(filename, plot_obj, width = 11.5, height = 8.0)
}

fit_plot_data <- build_fit_period_data()
forecast_plot_data <- build_forecast_plot_data()
transfer_state_data <- build_transfer_state_data()
direct_state_data <- build_direct_state_data()
convergence_df <- build_convergence_plot_data()

save_csv_if_rows(fit_plot_data$fit, "ex3_daily_fit_periods_summary.csv")
save_csv_if_rows(forecast_plot_data$forecast, "ex3_daily_forecast_plot_summary.csv")
save_csv_if_rows(transfer_state_data, "ex3_daily_transfer_states_summary.csv")
save_csv_if_rows(direct_state_data, "ex3_daily_direct_states_summary.csv")
save_csv_if_rows(convergence_df, "ex3_daily_convergence_traces.csv")

save_png_plot("ex3_daily_data_overview.png", {
  graphics::par(mfrow = c(3, 1), mar = c(3, 4, 2, 1))
  graphics::plot(
    prep$raw_df$date, prep$y_all, type = "l", col = "grey35",
    xlab = "", ylab = "log(log(usgs+1))",
    main = "Daily Big Trees prototype data"
  )
  graphics::points(
    prep$raw_df$date, prep$y_all,
    pch = 16, cex = 0.18, col = grDevices::adjustcolor("grey35", alpha.f = 0.7)
  )
  graphics::abline(v = prep$forecast_start, col = "firebrick", lty = 2)
  graphics::plot(
    prep$raw_df$date, prep$raw_df$ppt_mm, type = "l", col = "#0b6e99",
    xlab = "", ylab = "ppt_mm"
  )
  graphics::points(
    prep$raw_df$date, prep$raw_df$ppt_mm,
    pch = 16, cex = 0.18, col = grDevices::adjustcolor("#0b6e99", alpha.f = 0.7)
  )
  graphics::abline(v = prep$forecast_start, col = "firebrick", lty = 2)
  graphics::plot(
    prep$raw_df$date, prep$raw_df$soil_moisture, type = "l", col = "#4b7f52",
    xlab = "date", ylab = "soil_moisture"
  )
  graphics::points(
    prep$raw_df$date, prep$raw_df$soil_moisture,
    pch = 16, cex = 0.18, col = grDevices::adjustcolor("#4b7f52", alpha.f = 0.7)
  )
  graphics::abline(v = prep$forecast_start, col = "firebrick", lty = 2)
})

fit_period_plot <- ggplot2::ggplot() +
  ggplot2::geom_ribbon(
    data = fit_plot_data$fit,
    ggplot2::aes(x = date, ymin = lower, ymax = upper, fill = tau_label, group = tau_label),
    alpha = quantile_ribbon_alpha(),
    color = NA,
    show.legend = FALSE
  ) +
  ggplot2::geom_line(
    data = fit_plot_data$obs,
    ggplot2::aes(x = date, y = y),
    color = historical_obs_color(),
    linewidth = 0.45
  ) +
  ggplot2::geom_point(
    data = fit_plot_data$obs,
    ggplot2::aes(x = date, y = y),
    color = historical_obs_color(),
    size = historical_obs_point_size(),
    shape = 16,
    stroke = 0,
    alpha = 0.9
  ) +
  ggplot2::geom_line(
    data = fit_plot_data$fit,
    ggplot2::aes(x = date, y = estimate, color = tau_label),
    linewidth = 0.5,
    alpha = quantile_line_alpha()
  ) +
  ggplot2::facet_grid(model_label ~ period_label, scales = "free_x") +
  ggplot2::scale_color_manual(values = quant_cols, name = "Quantile level") +
  ggplot2::scale_fill_manual(values = quant_cols) +
  ggplot2::labs(
    title = "Dry and rainy fit windows across all seven quantiles",
    subtitle = sprintf(
      "Columns show the dry/drought (2012-2016) and rainy (2017-2019) windows; rows compare the direct and transfer models. Shaded bands show %s posterior intervals.",
      ci_pct
    ),
    x = NULL,
    y = "Transformed streamflow"
  ) +
  theme_ex3()

save_gg_plot("ex3_daily_fit_periods.png", fit_period_plot, width = 13, height = 10)

forecast_plot <- ggplot2::ggplot() +
  ggplot2::geom_ribbon(
    data = forecast_plot_data$forecast,
    ggplot2::aes(x = date, ymin = lower, ymax = upper, fill = tau_label, group = tau_label),
    alpha = quantile_ribbon_alpha(),
    color = NA,
    show.legend = FALSE
  ) +
  ggplot2::geom_line(
    data = forecast_plot_data$obs_hist,
    ggplot2::aes(x = date, y = y),
    color = historical_obs_color(),
    linewidth = 0.5
  ) +
  ggplot2::geom_point(
    data = forecast_plot_data$obs_hist,
    ggplot2::aes(x = date, y = y),
    color = historical_obs_color(),
    size = historical_obs_point_size(),
    shape = 16,
    stroke = 0,
    alpha = 0.9
  ) +
  ggplot2::geom_line(
    data = forecast_plot_data$obs_future,
    ggplot2::aes(x = date, y = y),
    color = future_obs_color(),
    linewidth = 0.75,
    linetype = "solid"
  ) +
  ggplot2::geom_point(
    data = forecast_plot_data$obs_future,
    ggplot2::aes(x = date, y = y),
    color = future_obs_color(),
    size = future_obs_point_size(),
    shape = 1,
    stroke = 0.85,
    alpha = 0.95
  ) +
  ggplot2::geom_line(
    data = forecast_plot_data$forecast,
    ggplot2::aes(x = date, y = estimate, color = tau_label),
    linewidth = 0.58,
    alpha = quantile_line_alpha()
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
  ggplot2::labs(
    title = sprintf("Thirty observed days plus the %d-step-ahead forecast", forecast_h),
    subtitle = sprintf(
      "Historical observations are shown in gray with solid lines and small filled markers; holdout observations are shown in orange with solid lines and open circles. Shaded bands show %s uncertainty.",
      ci_pct
    ),
    x = NULL,
    y = "Transformed streamflow"
  ) +
  theme_ex3()

save_gg_plot("ex3_daily_forecast_quantiles.png", forecast_plot, width = 13, height = 6.8)

render_state_figure(
  df = transfer_state_data,
  period_label = periods$period_label[periods$period == "dry"],
  model_type = "transfer",
  filename = "ex3_daily_transfer_states_dry.png",
  title = "Transfer-model state paths during the dry / drought period (2012-2016)"
)
render_state_figure(
  df = transfer_state_data,
  period_label = periods$period_label[periods$period == "rainy"],
  model_type = "transfer",
  filename = "ex3_daily_transfer_states_rainy.png",
  title = "Transfer-model state paths during the rainy period (2017-2019)"
)
render_state_figure(
  df = direct_state_data,
  period_label = periods$period_label[periods$period == "dry"],
  model_type = "direct",
  filename = "ex3_daily_direct_states_dry.png",
  title = "Direct-model regression state paths during the dry / drought period (2012-2016)"
)
render_state_figure(
  df = direct_state_data,
  period_label = periods$period_label[periods$period == "rainy"],
  model_type = "direct",
  filename = "ex3_daily_direct_states_rainy.png",
  title = "Direct-model regression state paths during the rainy period (2017-2019)"
)

make_convergence_plot(
  convergence_df,
  value_col = "elbo",
  title = "ELBO traces from the cached full-history LDVB fits",
  filename = "ex3_daily_convergence_elbo.png"
)
make_convergence_plot(
  convergence_df,
  value_col = "sigma",
  title = "Sigma trajectories from the cached full-history LDVB fits",
  filename = "ex3_daily_convergence_sigma.png"
)
make_convergence_plot(
  convergence_df,
  value_col = "gamma",
  title = "Gamma trajectories from the cached full-history LDVB fits",
  filename = "ex3_daily_convergence_gamma.png"
)

log_progress("figures_written | redesigned fit, forecast, state, and convergence figures completed")
