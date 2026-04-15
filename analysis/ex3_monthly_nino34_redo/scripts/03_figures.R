prep <- cache_read("ex3_monthly_prep.rds")
fit_results <- NULL

p_levels <- as.numeric(config$model$p_levels)
tau_levels <- vapply(p_levels, format_p0_label, character(1))
model_levels <- c("Direct regression", "Transfer function")
periods <- period_definitions()
ci_level <- uncertainty_level()
ci_pct <- sprintf("%d%%", round(100 * ci_level))
quant_cols <- quantile_palette(p_levels)
trim_iter <- convergence_trim_start_iter()

read_cached_table <- function(filename, date_cols = NULL) {
  path <- file.path(table_dir, filename)
  if (!file.exists(path)) return(NULL)
  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  for (col in intersect(date_cols %||% character(), names(df))) {
    df[[col]] <- as.Date(df[[col]])
  }
  df
}

get_fit_results <- function() {
  if (is.null(fit_results)) {
    fit_results <<- cache_read("ex3_monthly_fits_ldvb.rds")
  }
  fit_results
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
  cached_fit <- read_cached_table("ex3_monthly_fit_periods_summary.csv", date_cols = "date")
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

build_transfer_state_data <- function() {
  cached_df <- read_cached_table("ex3_monthly_transfer_states_summary.csv", date_cols = "date")
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
  cached_df <- read_cached_table("ex3_monthly_direct_states_summary.csv", date_cols = "date")
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
  conv_df <- read_cached_table("ex3_monthly_convergence_traces.csv")
  if (is.null(conv_df)) {
    fit_results <- get_fit_results()
    conv_df <- trim_convergence_trace_df(build_convergence_trace_df(fit_results), trim_start = trim_iter)
  }
  conv_df$model_label <- factor(conv_df$model_label, levels = model_levels)
  conv_df$tau_label <- factor(conv_df$tau_label, levels = tau_levels)
  conv_df
}

state_panel_plot <- function(df, panel_title, show_legend = FALSE) {
  ggplot2::ggplot(df, ggplot2::aes(x = date, y = estimate, color = tau_label, fill = tau_label)) +
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
    ggplot2::geom_line(linewidth = 0.55, alpha = quantile_line_alpha()) +
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

  legend_plot <- state_panel_plot(
    period_df[period_df$state_label == state_labels[1], , drop = FALSE],
    panel_title = state_labels[1],
    show_legend = TRUE
  )
  leg <- legend_grob(legend_plot)

  ncol_facets <- 3L

  if (identical(model_type, "transfer")) {
    zeta_df <- period_df[period_df$state_label == "Transfer state zeta", , drop = FALSE]
    psi_df <- period_df[period_df$state_label != "Transfer state zeta", , drop = FALSE]

    zeta_plot <- state_panel_plot(
      df = zeta_df,
      panel_title = "Transfer state zeta",
      show_legend = FALSE
    ) +
      ggplot2::theme(plot.margin = ggplot2::margin(5.5, 5.5, 0, 5.5))

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
      ggplot2::geom_line(linewidth = 0.5, alpha = quantile_line_alpha()) +
      ggplot2::facet_wrap(~ state_label, scales = "free_y", ncol = ncol_facets) +
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
      ggplot2::ggplotGrob(zeta_plot),
      ggplot2::ggplotGrob(psi_plot),
      leg,
      ncol = 1,
      heights = c(2.2, max(3, ceiling(length(state_labels[-1]) / ncol_facets)) * 1.8, 0.8),
      top = grid::textGrob(title, gp = grid::gpar(fontsize = 14, fontface = "bold"))
    )
    fig_height <- 11 + 0.7 * max(0, ceiling(length(state_labels[-1]) / ncol_facets) - 2)
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
      ggplot2::geom_line(linewidth = 0.5, alpha = quantile_line_alpha()) +
      ggplot2::facet_wrap(~ state_label, scales = "free_y", ncol = ncol_facets) +
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
      heights = c(max(3, ceiling(length(state_labels) / ncol_facets)) * 1.9, 0.8),
      top = grid::textGrob(title, gp = grid::gpar(fontsize = 14, fontface = "bold"))
    )
    fig_height <- 9 + 0.7 * max(0, ceiling(length(state_labels) / ncol_facets) - 2)
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
        "text", x = 0.5, y = 0.5,
        label = sprintf(
          "No %s trace values remain after trimming iterations before %d.",
          value_col, trim_iter
        ),
        size = 4.4, color = "grey25"
      ) +
      ggplot2::xlim(0, 1) +
      ggplot2::ylim(0, 1) +
      ggplot2::labs(title = title, subtitle = subtitle, x = NULL, y = NULL) +
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
transfer_state_data <- build_transfer_state_data()
direct_state_data <- build_direct_state_data()
convergence_df <- build_convergence_plot_data()

save_csv_if_rows(fit_plot_data$fit, "ex3_monthly_fit_periods_summary.csv")
save_csv_if_rows(transfer_state_data, "ex3_monthly_transfer_states_summary.csv")
save_csv_if_rows(direct_state_data, "ex3_monthly_direct_states_summary.csv")
save_csv_if_rows(convergence_df, "ex3_monthly_convergence_traces.csv")

save_png_plot("ex3_monthly_data_overview.png", {
  graphics::par(mfrow = c(2, 1), mar = c(3, 4, 2, 1))
  graphics::plot(
    prep$fit_df$date, prep$y_train, type = "l", col = "grey35",
    xlab = "", ylab = "log(monthly mean flow)",
    main = "Monthly San Lorenzo flow (aggregated from daily data)"
  )
  graphics::points(
    prep$fit_df$date, prep$y_train,
    pch = 16, cex = 0.25,
    col = grDevices::adjustcolor("grey35", alpha.f = 0.7)
  )
  graphics::plot(
    prep$fit_df$date, prep$fit_df$nino34, type = "l", col = "#0b6e99",
    xlab = "date", ylab = "nino34",
    main = "Monthly nino34 over the common overlap window"
  )
  graphics::points(
    prep$fit_df$date, prep$fit_df$nino34,
    pch = 16, cex = 0.25,
    col = grDevices::adjustcolor("#0b6e99", alpha.f = 0.7)
  )
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
    title = "Monthly Nino34 contrast fits across the selected windows",
    subtitle = sprintf(
      "Rows compare the direct and transfer models; shaded bands show %s posterior intervals.",
      ci_pct
    ),
    x = NULL,
    y = "log(monthly mean flow)"
  ) +
  theme_ex3()

save_gg_plot("ex3_monthly_fit_periods.png", fit_period_plot, width = 13, height = 10)

render_state_figure(
  df = transfer_state_data,
  period_label = periods$period_label[periods$period == "enso"],
  model_type = "transfer",
  filename = "ex3_monthly_transfer_states_enso.png",
  title = "Transfer-model state paths during the strong El Nino window (1997-1999)"
)
render_state_figure(
  df = transfer_state_data,
  period_label = periods$period_label[periods$period == "drought"],
  model_type = "transfer",
  filename = "ex3_monthly_transfer_states_drought.png",
  title = "Transfer-model state paths during the dry / drought window (2012-2016)"
)
render_state_figure(
  df = direct_state_data,
  period_label = periods$period_label[periods$period == "enso"],
  model_type = "direct",
  filename = "ex3_monthly_direct_states_enso.png",
  title = "Direct-model regression state paths during the strong El Nino window (1997-1999)"
)
render_state_figure(
  df = direct_state_data,
  period_label = periods$period_label[periods$period == "drought"],
  model_type = "direct",
  filename = "ex3_monthly_direct_states_drought.png",
  title = "Direct-model regression state paths during the dry / drought window (2012-2016)"
)

make_convergence_plot(
  df = convergence_df,
  value_col = "elbo",
  title = "Monthly Nino34 contrast: ELBO traces",
  filename = "ex3_monthly_convergence_elbo.png"
)
make_convergence_plot(
  df = convergence_df,
  value_col = "sigma",
  title = "Monthly Nino34 contrast: sigma traces",
  filename = "ex3_monthly_convergence_sigma.png"
)
make_convergence_plot(
  df = convergence_df,
  value_col = "gamma",
  title = "Monthly Nino34 contrast: gamma traces",
  filename = "ex3_monthly_convergence_gamma.png"
)

log_progress("figures_written | monthly nino34 data, fit, state, and convergence figures completed")
