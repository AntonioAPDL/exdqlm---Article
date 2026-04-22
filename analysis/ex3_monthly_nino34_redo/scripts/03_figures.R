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

build_forecast_objects <- function() {
  if (length(p_levels) != 1L) return(NULL)
  fit_results <- get_fit_results()
  key <- sprintf("p%03d", round(100 * p_levels[1]))
  res <- fit_results[[key]]
  if (is.null(res) || !fit_ok(res$direct) || !fit_ok(res$transfer)) return(NULL)

  start_year <- as.integer(format(prep$fit_df$date[1], "%Y"))
  start_month <- as.integer(format(prep$fit_df$date[1], "%m"))
  y_ts <- stats::ts(prep$y_train, start = c(start_year, start_month), frequency = 12)
  start_t <- length(prep$y_train) - 18L
  if (!is.finite(start_t) || start_t < 1L) return(NULL)

  fc_direct <- forecast_from_fit(start.t = start_t, k = 18, m1 = res$direct, y_data = y_ts, plot = FALSE)
  fc_transfer <- forecast_from_fit(start.t = start_t, k = 18, m1 = res$transfer, y_data = y_ts, plot = FALSE)
  fc_direct$ff <- fc_direct$ff[seq_len(fc_direct$k)]
  fc_direct$fQ <- fc_direct$fQ[seq_len(fc_direct$k)]
  fc_transfer$ff <- fc_transfer$ff[seq_len(fc_transfer$k)]
  fc_transfer$fQ <- fc_transfer$fQ[seq_len(fc_transfer$k)]

  list(
    y_ts = y_ts,
    start_t = start_t,
    direct = fc_direct,
    transfer = fc_transfer
  )
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

build_transfer_state_data_full <- function() {
  cached_df <- read_cached_table("ex3_monthly_transfer_states_full_summary.csv", date_cols = "date")
  if (!is.null(cached_df)) {
    cached_df$tau_label <- factor(cached_df$tau_label, levels = tau_levels)
    return(cached_df)
  }

  fit_results <- get_fit_results()
  out <- list()
  row_id <- 0L
  idx <- seq_along(prep$fit_df$date)

  for (p0 in p_levels) {
    key <- sprintf("p%03d", round(100 * p0))
    res <- fit_results[[key]]
    if (!fit_ok(res$transfer)) next

    idx_map <- transfer_state_indices(res, prep)
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
        period_label = "Full modeled window",
        level = ci_level
      )
    }
  }

  df <- do.call(rbind, out)
  df$tau_label <- factor(df$tau_label, levels = tau_levels)
  df
}

build_transfer_zeta_data_full <- function() {
  cached_df <- read_cached_table("ex3_monthly_transfer_zeta_full_summary.csv", date_cols = "date")
  if (!is.null(cached_df)) {
    cached_df$tau_label <- factor(cached_df$tau_label, levels = tau_levels)
    return(cached_df)
  }

  fit_results <- get_fit_results()
  out <- list()
  row_id <- 0L
  idx <- seq_along(prep$fit_df$date)

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
      period_label = "Full modeled window",
      level = ci_level
    )
  }

  df <- do.call(rbind, out)
  df$tau_label <- factor(df$tau_label, levels = tau_levels)
  df
}

build_direct_state_data_full <- function() {
  cached_df <- read_cached_table("ex3_monthly_direct_states_full_summary.csv", date_cols = "date")
  if (!is.null(cached_df)) {
    cached_df$tau_label <- factor(cached_df$tau_label, levels = tau_levels)
    return(cached_df)
  }

  fit_results <- get_fit_results()
  out <- list()
  row_id <- 0L
  idx <- seq_along(prep$fit_df$date)

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
        period_label = "Full modeled window",
        level = ci_level
      )
    }
  }

  df <- do.call(rbind, out)
  df$tau_label <- factor(df$tau_label, levels = tau_levels)
  df
}

build_base_state_data_full <- function(model_type = c("direct", "transfer")) {
  model_type <- match.arg(model_type)
  filename <- if (identical(model_type, "direct")) {
    "ex3_monthly_direct_base_states_full_summary.csv"
  } else {
    "ex3_monthly_transfer_base_states_full_summary.csv"
  }
  cached_df <- read_cached_table(filename, date_cols = "date")
  if (!is.null(cached_df)) {
    cached_df$tau_label <- factor(cached_df$tau_label, levels = tau_levels)
    return(cached_df)
  }

  fit_results <- get_fit_results()
  out <- list()
  row_id <- 0L
  idx <- seq_along(prep$fit_df$date)

  for (p0 in p_levels) {
    key <- sprintf("p%03d", round(100 * p0))
    res <- fit_results[[key]]
    fit_obj <- if (identical(model_type, "direct")) res$direct else res$transfer
    if (!fit_ok(fit_obj)) next

    idx_map <- base_state_indices(fit_obj, prep, model = model_type)
    for (jj in seq_along(idx_map$indices)) {
      row_id <- row_id + 1L
      out[[row_id]] <- state_series_summary(
        fit = fit_obj,
        state_index = idx_map$indices[jj],
        state_name = idx_map$names[jj],
        state_label = idx_map$labels[jj],
        dates = prep$fit_df$date,
        idx = idx,
        p0 = p0,
        period_label = "Full modeled window",
        level = ci_level
      )
    }
  }

  df <- do.call(rbind, out)
  df$tau_label <- factor(df$tau_label, levels = tau_levels)
  df
}

screen_state_paths <- function(df) {
  if (is.null(df) || !nrow(df)) return(data.frame())

  split_df <- split(df, interaction(df$p0, df$state, drop = TRUE))
  rows <- lapply(split_df, function(x) {
    ci_cross_zero <- x$lower <= 0 & x$upper >= 0
    data.frame(
      p0 = x$p0[1],
      tau_label = x$tau_label[1],
      state = x$state[1],
      state_label = x$state_label[1],
      n_time = nrow(x),
      prop_ci_crosses_zero = mean(ci_cross_zero),
      prop_ci_excludes_zero = mean(!ci_cross_zero),
      mean_abs_estimate = mean(abs(x$estimate)),
      max_abs_estimate = max(abs(x$estimate)),
      mean_ci_width = mean(x$upper - x$lower),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

render_full_state_batches <- function(df, filename_prefix, title_prefix, model_type) {
  if (is.null(df) || !nrow(df)) return(invisible(NULL))

  state_labels <- unique(as.character(df$state_label))
  batch_size <- max(1L, full_state_batch_size())
  batches <- split(state_labels, ceiling(seq_along(state_labels) / batch_size))
  y_lim <- full_state_ylim()
  line_col <- model_line_color(model_type)
  fill_col <- model_fill_color(model_type)

  for (ii in seq_along(batches)) {
    labels_i <- batches[[ii]]
    batch_df <- df[df$state_label %in% labels_i, , drop = FALSE]
    batch_df$state_label <- factor(batch_df$state_label, levels = labels_i)

    plot_obj <- ggplot2::ggplot(
      batch_df,
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
      ggplot2::facet_wrap(~ state_label, scales = if (is.null(y_lim)) "free_y" else "fixed", ncol = 3) +
      ggplot2::scale_color_manual(values = setNames(line_col, tau_levels), name = "Quantile level") +
      ggplot2::scale_fill_manual(values = setNames(fill_col, tau_levels)) +
      ggplot2::labs(
        title = sprintf("%s (batch %02d)", title_prefix, ii),
        subtitle = sprintf("Shaded bands show %s posterior intervals.", ci_pct),
        x = NULL,
        y = NULL
      ) +
      theme_ex3(base_size = 10) +
      ggplot2::theme(
        strip.text = ggplot2::element_text(size = 9.5, face = "bold"),
        axis.text.x = ggplot2::element_text(size = 7.5),
        axis.text.y = ggplot2::element_text(size = 7.5)
      )

    if (!is.null(y_lim)) {
      plot_obj <- plot_obj + ggplot2::coord_cartesian(ylim = y_lim)
    }

    save_gg_plot(
      sprintf("%s_batch%02d.png", filename_prefix, ii),
      plot_obj,
      width = 13,
      height = 8 + 0.45 * max(0, length(labels_i) - 3)
    )
  }
}

render_full_zeta_plot <- function(df) {
  if (is.null(df) || !nrow(df)) return(invisible(NULL))
  pal <- ex3_palette()

  plot_obj <- ggplot2::ggplot(
    df,
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
    ggplot2::geom_line(linewidth = 0.55, alpha = quantile_line_alpha()) +
    ggplot2::scale_color_manual(values = setNames(pal$m2, tau_levels), name = "Quantile level") +
    ggplot2::scale_fill_manual(values = setNames(pal$m2_aux, tau_levels)) +
    ggplot2::labs(
      title = "Transfer-state zeta over the full modeled window",
      subtitle = sprintf("Shaded bands show %s posterior intervals.", ci_pct),
      x = NULL,
      y = NULL
    ) +
    theme_ex3(base_size = 10)

  save_gg_plot("ex3_monthly_transfer_zeta_full.png", plot_obj, width = 13, height = 6)
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

state_panel_plot <- function(df, panel_title, show_legend = FALSE, model_type = c("direct", "transfer")) {
  model_type <- match.arg(model_type)
  line_col <- model_line_color(model_type)
  fill_col <- model_fill_color(model_type)
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
    ggplot2::scale_color_manual(values = setNames(line_col, tau_levels), name = "Quantile level") +
    ggplot2::scale_fill_manual(values = setNames(fill_col, tau_levels)) +
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
    show_legend = TRUE,
    model_type = model_type
  )
  leg <- legend_grob(legend_plot)

  ncol_facets <- 3L
  line_col <- model_line_color(model_type)
  fill_col <- model_fill_color(model_type)

  if (identical(model_type, "transfer")) {
    zeta_df <- period_df[period_df$state_label == "Transfer state zeta", , drop = FALSE]
    psi_df <- period_df[period_df$state_label != "Transfer state zeta", , drop = FALSE]

    zeta_plot <- state_panel_plot(
      df = zeta_df,
      panel_title = "Transfer state zeta",
      show_legend = FALSE,
      model_type = model_type
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
      ggplot2::scale_color_manual(values = setNames(line_col, tau_levels), name = "Quantile level") +
      ggplot2::scale_fill_manual(values = setNames(fill_col, tau_levels)) +
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
      ggplot2::scale_color_manual(values = setNames(line_col, tau_levels), name = "Quantile level") +
      ggplot2::scale_fill_manual(values = setNames(fill_col, tau_levels)) +
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

render_base_state_full_plot <- function(df, model_type, filename, title) {
  if (is.null(df) || !nrow(df)) return(invisible(NULL))
  line_col <- model_line_color(model_type)
  fill_col <- model_fill_color(model_type)

  plot_obj <- ggplot2::ggplot(
    df,
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
    ggplot2::facet_wrap(~ state_label, scales = "free_y", ncol = 3) +
    ggplot2::scale_color_manual(values = setNames(line_col, tau_levels), name = "Quantile level") +
    ggplot2::scale_fill_manual(values = setNames(fill_col, tau_levels)) +
    ggplot2::labs(
      title = title,
      subtitle = sprintf("Shaded bands show %s posterior intervals.", ci_pct),
      x = NULL,
      y = NULL
    ) +
    theme_ex3(base_size = 10) +
    ggplot2::theme(
      strip.text = ggplot2::element_text(size = 9.5, face = "bold"),
      axis.text.x = ggplot2::element_text(size = 7.5),
      axis.text.y = ggplot2::element_text(size = 7.5)
    )

  save_gg_plot(filename, plot_obj, width = 13, height = 8.5)
}

render_article_like_quantcomps_plot <- function() {
  if (!single_quantile_run()) return(invisible(NULL))
  fit_results <- get_fit_results()
  key <- sprintf("p%03d", round(100 * p_levels[1]))
  res <- fit_results[[key]]
  if (is.null(res) || !fit_ok(res$direct) || !fit_ok(res$transfer)) {
    return(invisible(NULL))
  }

  pal <- ex3_palette()
  start_year <- as.integer(format(prep$fit_df$date[1], "%Y"))
  start_month <- as.integer(format(prep$fit_df$date[1], "%m"))
  y_ts <- stats::ts(prep$y_train, start = c(start_year, start_month), frequency = 12)
  direct_fit <- res$direct
  transfer_fit <- res$transfer
  direct_fit$y <- y_ts
  transfer_fit$y <- y_ts

  direct_q <- quantile_summary_from_fit(direct_fit, cr.percent = ci_level)
  transfer_q <- quantile_summary_from_fit(transfer_fit, cr.percent = ci_level)
  direct_base <- base_state_indices(direct_fit, prep, model = "direct")
  transfer_base <- base_state_indices(transfer_fit, prep, model = "transfer")
  direct_reg <- direct_state_indices(res, prep)
  transfer_tf <- transfer_state_indices(res, prep)

  direct_seas <- component_summary_from_fit(direct_fit, index = direct_base$indices[-1], cr.percent = ci_level)
  transfer_seas <- component_summary_from_fit(transfer_fit, index = transfer_base$indices[-1], cr.percent = ci_level)
  direct_cov <- component_summary_from_fit(direct_fit, index = direct_reg$beta, cr.percent = ci_level)
  transfer_cov <- component_summary_from_fit(transfer_fit, index = transfer_tf$zeta, cr.percent = ci_level)

  xlim_mid <- c(1995, 2015)
  q_ylim <- range(c(prep$y_train, direct_q$lb, direct_q$ub, transfer_q$lb, transfer_q$ub), na.rm = TRUE)
  seas_ylim <- range(c(direct_seas$lb, direct_seas$ub, transfer_seas$lb, transfer_seas$ub), na.rm = TRUE)
  cov_ylim <- range(c(direct_cov$lb, direct_cov$ub, transfer_cov$lb, transfer_cov$ub), na.rm = TRUE)

  save_png_plot("ex3_monthly_quantcomps.png", {
    graphics::par(mfrow = c(3, 1), mar = c(3, 4, 2, 1))

    stats::plot.ts(
      y_ts,
      col = grDevices::adjustcolor(pal$obs, alpha.f = 0.9),
      ylim = q_ylim,
      xlim = xlim_mid,
      ylab = sprintf("quantile %s CrIs", ci_pct)
    )
    plot_quantile_summary(direct_q, col = pal$m1, add = TRUE)
    plot_quantile_summary(transfer_q, col = pal$m2, add = TRUE)
    graphics::legend(
      "topleft",
      legend = c("M1 regression", "M2 transfer fn"),
      col = c(pal$m1, pal$m2),
      lty = 1,
      lwd = 1.5,
      bty = "n"
    )

    graphics::plot(
      NA,
      ylim = seas_ylim,
      xlim = xlim_mid,
      ylab = "seasonal components",
      xlab = "time"
    )
    plot_component_summary(direct_seas, add = TRUE, col = pal$m1)
    plot_component_summary(transfer_seas, add = TRUE, col = pal$m2)

    graphics::plot(
      NA,
      ylim = cov_ylim,
      xlim = xlim_mid,
      ylab = "climate contribution",
      xlab = "time"
    )
    plot_component_summary(direct_cov, add = TRUE, col = pal$m1)
    plot_component_summary(transfer_cov, add = TRUE, col = pal$m2)
    graphics::abline(h = 0, col = pal$ref, lty = 3, lwd = 2)
  }, width = 11.5, height = 10.0)
}

render_article_like_zetapsi_plot <- function(zeta_df, psi_df) {
  if (!single_quantile_run() || is.null(zeta_df) || !nrow(zeta_df) || is.null(psi_df) || !nrow(psi_df)) {
    return(invisible(NULL))
  }
  pal <- ex3_palette()

  zeta_plot <- ggplot2::ggplot(
    zeta_df,
    ggplot2::aes(x = date, y = estimate)
  ) +
    ggplot2::geom_hline(yintercept = 0, color = pal$ref, linetype = 3, linewidth = 0.7) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = lower, ymax = upper),
      fill = pal$m2_aux,
      alpha = 0.35
    ) +
    ggplot2::geom_line(color = pal$m2, linewidth = 0.6) +
    ggplot2::labs(title = expression(zeta[t]), x = NULL, y = NULL) +
    theme_ex3(base_size = 10) +
    ggplot2::theme(plot.title = ggplot2::element_text(hjust = 0.5))

  psi_plot <- ggplot2::ggplot(
    psi_df,
    ggplot2::aes(x = date, y = estimate)
  ) +
    ggplot2::geom_hline(yintercept = 0, color = pal$ref, linetype = 3, linewidth = 0.6) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = lower, ymax = upper),
      fill = pal$m2_aux,
      alpha = 0.25
    ) +
    ggplot2::geom_line(color = pal$m2, linewidth = 0.45) +
    ggplot2::facet_wrap(~ state_label, scales = "free_y", ncol = 3) +
    ggplot2::labs(title = expression(psi[t]), x = NULL, y = NULL) +
    theme_ex3(base_size = 10) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5),
      strip.text = ggplot2::element_text(size = 9, face = "bold")
    )

  full_grob <- gridExtra::arrangeGrob(
    ggplot2::ggplotGrob(zeta_plot),
    ggplot2::ggplotGrob(psi_plot),
    ncol = 1,
    heights = c(1.2, 2.7),
    top = grid::textGrob(
      "Transfer-state zeta and psi paths over the full modeled window",
      gp = grid::gpar(fontsize = 14, fontface = "bold")
    )
  )

  save_png_plot(
    "ex3_monthly_zetapsi.png",
    {
      grid::grid.newpage()
      grid::grid.draw(full_grob)
    },
    width = 13,
    height = 10
  )
}

make_convergence_plot <- function(df, value_col, title, filename) {
  plot_df <- df[!is.na(df[[value_col]]), , drop = FALSE]
  subtitle <- sprintf(
    "Traces come from fit$diagnostics$vb_trace and are shown from iteration %d onward to suppress early start-up scale distortion.",
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
  if (single_quantile_run()) {
    plot_obj <- ggplot2::ggplot(plot_df, ggplot2::aes(x = iter, y = value, color = model_label)) +
      ggplot2::geom_vline(xintercept = trim_iter, color = "grey55", linetype = 3, linewidth = 0.5) +
      ggplot2::geom_line(linewidth = 0.6, alpha = 0.95) +
      ggplot2::scale_color_manual(
        values = c(
          "Direct regression" = model_line_color("direct"),
          "Transfer function" = model_line_color("transfer")
        ),
        name = "Model"
      ) +
      ggplot2::scale_x_continuous(limits = c(0, max_iter), expand = c(0.01, 0.01)) +
      ggplot2::labs(
        title = title,
        subtitle = subtitle,
        x = "LDVB iteration",
        y = NULL
      ) +
      theme_ex3()
  } else {
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
  }

  save_gg_plot(filename, plot_obj, width = 11.5, height = 8.0)
}

fit_plot_data <- build_fit_period_data()
transfer_state_data <- build_transfer_state_data()
direct_state_data <- build_direct_state_data()
transfer_state_data_full <- build_transfer_state_data_full()
transfer_zeta_data_full <- build_transfer_zeta_data_full()
direct_state_data_full <- build_direct_state_data_full()
direct_base_state_data_full <- build_base_state_data_full("direct")
transfer_base_state_data_full <- build_base_state_data_full("transfer")
convergence_df <- build_convergence_plot_data()
direct_screening <- screen_state_paths(direct_state_data_full)
transfer_screening <- screen_state_paths(transfer_state_data_full)

save_csv_if_rows(fit_plot_data$fit, "ex3_monthly_fit_periods_summary.csv")
save_csv_if_rows(transfer_state_data, "ex3_monthly_transfer_states_summary.csv")
save_csv_if_rows(direct_state_data, "ex3_monthly_direct_states_summary.csv")
save_csv_if_rows(transfer_state_data_full, "ex3_monthly_transfer_states_full_summary.csv")
save_csv_if_rows(transfer_zeta_data_full, "ex3_monthly_transfer_zeta_full_summary.csv")
save_csv_if_rows(direct_state_data_full, "ex3_monthly_direct_states_full_summary.csv")
save_csv_if_rows(direct_base_state_data_full, "ex3_monthly_direct_base_states_full_summary.csv")
save_csv_if_rows(transfer_base_state_data_full, "ex3_monthly_transfer_base_states_full_summary.csv")
save_csv_if_rows(direct_screening, "ex3_monthly_direct_states_full_screening.csv")
save_csv_if_rows(transfer_screening, "ex3_monthly_transfer_states_full_screening.csv")
save_csv_if_rows(convergence_df, "ex3_monthly_convergence_traces.csv")

save_png_plot("ex3_monthly_data_overview.png", {
  pal <- ex3_palette()
  graphics::par(mfrow = c(2, 1), mar = c(3, 4, 2, 1))
  graphics::plot(
    prep$fit_df$date, prep$y_train, type = "l", col = pal$obs,
    xlab = "", ylab = "log(monthly mean flow)",
    main = "Monthly San Lorenzo flow (aggregated from daily data)"
  )
  graphics::points(
    prep$fit_df$date, prep$y_train,
    pch = 16, cex = 0.25,
    col = grDevices::adjustcolor(pal$obs, alpha.f = 0.7)
  )
  preview_terms <- prep$preview_terms %||% character()
  preview_labels <- state_label_map(preview_terms)
  preview_mat <- as.matrix(prep$fit_df[, preview_terms, drop = FALSE])
  preview_scaled <- scale(preview_mat)
  preview_cols <- c("#0b6e99", "#2d728f", "#457b9d")[seq_len(max(1, ncol(preview_scaled)))]
  if (ncol(preview_scaled) <= 1L) {
    graphics::plot(
      prep$fit_df$date, as.numeric(preview_scaled[, 1]), type = "l", col = preview_cols[1],
      xlab = "date", ylab = preview_labels[1],
      main = sprintf("Monthly %s over the common overlap window", preview_labels[1])
    )
    graphics::points(
      prep$fit_df$date, as.numeric(preview_scaled[, 1]),
      pch = 16, cex = 0.25,
      col = grDevices::adjustcolor(preview_cols[1], alpha.f = 0.7)
    )
  } else {
    graphics::matplot(
      prep$fit_df$date,
      preview_scaled,
      type = "l",
      lty = 1,
      lwd = 1.1,
      col = preview_cols,
      xlab = "date",
      ylab = "scaled covariates",
      main = "Representative monthly covariates over the common overlap window"
    )
    graphics::legend(
      "topright",
      legend = preview_labels,
      col = preview_cols,
      lty = 1,
      lwd = 1.1,
      bty = "n",
      cex = 0.8
    )
  }
})

if (single_quantile_run()) {
  fit_period_plot <- ggplot2::ggplot() +
    ggplot2::geom_ribbon(
      data = fit_plot_data$fit,
      ggplot2::aes(x = date, ymin = lower, ymax = upper, fill = model_label, group = model_label),
      alpha = quantile_ribbon_alpha(),
      color = NA,
      show.legend = FALSE
    ) +
    ggplot2::geom_line(
      data = fit_plot_data$obs,
      ggplot2::aes(x = date, y = y),
      color = ex3_palette()$obs,
      linewidth = 0.45
    ) +
    ggplot2::geom_point(
      data = fit_plot_data$obs,
      ggplot2::aes(x = date, y = y),
      color = ex3_palette()$obs,
      size = historical_obs_point_size(),
      shape = 16,
      stroke = 0,
      alpha = 0.9
    ) +
    ggplot2::geom_line(
      data = fit_plot_data$fit,
      ggplot2::aes(x = date, y = estimate, color = model_label),
      linewidth = 0.55,
      alpha = 0.85
    ) +
    ggplot2::facet_grid(model_label ~ period_label, scales = "free_x") +
    ggplot2::scale_color_manual(
      values = c(
        "Direct regression" = model_line_color("direct"),
        "Transfer function" = model_line_color("transfer")
      ),
      name = "Model"
    ) +
    ggplot2::scale_fill_manual(
      values = c(
        "Direct regression" = model_fill_color("direct"),
        "Transfer function" = model_fill_color("transfer")
      )
    ) +
    ggplot2::labs(
      title = "Monthly Example 3 sandbox fits across the selected windows",
      subtitle = sprintf(
        "Rows compare the direct and transfer models; shaded bands show %s posterior intervals.",
        ci_pct
      ),
      x = NULL,
      y = "log(monthly mean flow)"
    ) +
    theme_ex3()
} else {
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
      title = "Monthly Example 3 sandbox fits across the selected windows",
      subtitle = sprintf(
        "Rows compare the direct and transfer models; shaded bands show %s posterior intervals.",
        ci_pct
      ),
      x = NULL,
      y = "log(monthly mean flow)"
    ) +
    theme_ex3()
}

save_gg_plot("ex3_monthly_fit_periods.png", fit_period_plot, width = 13, height = 10)

forecast_obj <- build_forecast_objects()
if (!is.null(forecast_obj)) {
  direct_cols <- c("#8A46B2", "#C48AE0")
  transfer_cols <- c("#2E7D5B", "#85B89A")
  ref_col <- "#C47A2C"
  y_range <- range(as.numeric(forecast_obj$y_ts), na.rm = TRUE)
  y_pad <- 0.25 * diff(y_range)
  if (!is.finite(y_pad) || y_pad <= 0) y_pad <- 0.5
  save_png_plot("ex3_monthly_forecast.png", {
    stats::plot.ts(
      forecast_obj$y_ts,
      col = "grey70",
      ylim = c(y_range[1] - y_pad, y_range[2] + y_pad),
      xlim = c(2017, 2021.4),
      ylab = "log(monthly mean flow)",
      xlab = "",
      main = "Monthly Example 3 sandbox: 18-step forecast comparison"
    )
    plot(forecast_obj$direct, add = TRUE, cols = direct_cols)
    plot(forecast_obj$transfer, add = TRUE, cols = transfer_cols)
    vline_x <- grDevices::xy.coords(forecast_obj$y_ts)$x[forecast_obj$start_t]
    graphics::abline(v = vline_x, col = ref_col, lty = 5)
    graphics::legend(
      "topleft",
      legend = c("Direct regression", "Transfer function"),
      col = c(direct_cols[1], transfer_cols[1]),
      lwd = 2,
      bty = "n",
      cex = 0.9
    )
  }, width = 11.5, height = 7.0)
}

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
  title = "Monthly Example 3 sandbox: ELBO traces",
  filename = "ex3_monthly_convergence_elbo.png"
)
make_convergence_plot(
  df = convergence_df,
  value_col = "sigma",
  title = "Monthly Example 3 sandbox: sigma traces",
  filename = "ex3_monthly_convergence_sigma.png"
)
make_convergence_plot(
  df = convergence_df,
  value_col = "gamma",
  title = "Monthly Example 3 sandbox: gamma traces",
  filename = "ex3_monthly_convergence_gamma.png"
)

render_full_state_batches(
  df = direct_state_data_full,
  filename_prefix = "ex3_monthly_direct_states_full",
  title_prefix = "Direct-model coefficient paths over the full modeled window",
  model_type = "direct"
)
render_full_state_batches(
  df = transfer_state_data_full,
  filename_prefix = "ex3_monthly_transfer_coefficients_full",
  title_prefix = "Transfer-model coefficient paths over the full modeled window",
  model_type = "transfer"
)
render_full_zeta_plot(transfer_zeta_data_full)
render_base_state_full_plot(
  df = direct_base_state_data_full,
  model_type = "direct",
  filename = "ex3_monthly_direct_base_states_full.png",
  title = "Direct-model trend and harmonic state paths over the full modeled window"
)
render_base_state_full_plot(
  df = transfer_base_state_data_full,
  model_type = "transfer",
  filename = "ex3_monthly_transfer_base_states_full.png",
  title = "Transfer-model trend and harmonic state paths over the full modeled window"
)
render_article_like_quantcomps_plot()
render_article_like_zetapsi_plot(
  zeta_df = transfer_zeta_data_full,
  psi_df = transfer_state_data_full
)

log_progress("figures_written | monthly data, fit, forecast, article-style, state, screening, and convergence figures completed")
