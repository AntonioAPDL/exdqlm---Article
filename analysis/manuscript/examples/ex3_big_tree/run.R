need_ex3 <- target_enabled(
  "ex3",
  c(
    "ex3data",
    "ex3forecast", "ex3forecast_ldvb",
    "ex3quantcomps", "ex3quantcomps_ldvb",
    "ex3zetapsi", "ex3zetapsi_ldvb",
    "ex3tables", "ex3tables_ldvb"
  )
)

if (!need_ex3) {
  log_msg("Example 3 (Big Tree): skipped (target filter)")
} else {
  log_msg("Example 3 (Big Tree): start")

  need_ex3data <- target_enabled("ex3data", "ex3")
  need_ex3forecast <- target_enabled("ex3forecast", c("ex3", "ex3forecast_ldvb"))
  need_ex3quantcomps <- target_enabled("ex3quantcomps", c("ex3", "ex3quantcomps_ldvb"))
  need_ex3zetapsi <- target_enabled("ex3zetapsi", c("ex3", "ex3zetapsi_ldvb"))
  need_ex3tables <- target_enabled("ex3tables", c("ex3", "ex3tables_ldvb"))
  need_ex3_models <- any(c(need_ex3forecast, need_ex3quantcomps, need_ex3zetapsi, need_ex3tables))

  fit_ok <- function(x) !is.null(x) && !inherits(x, "error")

  with_local_seed <- function(seed, expr) {
    has_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    old_seed <- if (has_seed) get(".Random.seed", envir = .GlobalEnv, inherits = FALSE) else NULL
    on.exit({
      if (has_seed) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }, add = TRUE)
    set.seed(as.integer(seed))
    eval.parent(substitute(expr))
  }

  month_sequence_from_ts <- function(x) {
    st <- stats::start(x)
    start_date <- as.Date(sprintf("%04d-%02d-01", as.integer(st[1]), as.integer(st[2])))
    seq.Date(start_date, by = "month", length.out = length(x))
  }

  make_monthly_ts <- function(values, dates) {
    if (!length(values)) stop("Cannot create a monthly ts from zero observations.", call. = FALSE)
    start_date <- as.Date(dates[[1]])
    stats::ts(
      values,
      start = c(as.integer(format(start_date, "%Y")), as.integer(format(start_date, "%m"))),
      frequency = 12
    )
  }

  fmt_month <- function(x) format(as.Date(x), "%Y-%m")

  padded_range <- function(..., pad = 0.08) {
    vals <- unlist(list(...), use.names = FALSE)
    vals <- vals[is.finite(vals)]
    if (!length(vals)) return(c(-1, 1))
    r <- range(vals)
    if (diff(r) == 0) return(r + c(-1, 1) * max(1, abs(r[1]) * pad))
    r + c(-1, 1) * diff(r) * pad
  }

  plot_component_with_band <- function(csum, col, lwd = 1.6, lty = 1) {
    graphics::lines(csum$x, csum$map, col = col, lwd = lwd, lty = lty)
    graphics::lines(csum$x, csum$lb, col = col, lwd = 0.8, lty = 2)
    graphics::lines(csum$x, csum$ub, col = col, lwd = 0.8, lty = 2)
  }

  climate_psi_title <- function(label) {
    as.expression(substitute(psi[list(LABEL, t)], list(LABEL = label)))
  }

  utils::data("BTflow", package = "exdqlm", envir = environment())
  utils::data("climateIndices", package = "exdqlm", envir = environment())
  if (!exists("BTflow") || !stats::is.ts(BTflow)) {
    stop("Required package dataset BTflow is not available as a monthly ts.", call. = FALSE)
  }
  if (!exists("climateIndices") || !is.data.frame(climateIndices)) {
    stop("Required package dataset climateIndices is not available as a data frame.", call. = FALSE)
  }

  ex3_cfg <- cfg_profile$ex3
  p0 <- as.numeric(ex3_cfg$p0 %||% 0.15)
  p0_label <- sprintf("%0.2f", p0)
  p0_tag <- gsub("\\.", "p", p0_label)
  selected_indices <- tolower(as.character(ex3_cfg$selected_indices %||% c("noi", "amo")))
  selected_indices <- selected_indices[nzchar(selected_indices)]
  if (!length(selected_indices)) {
    stop("Example 3 requires at least one selected climate index.", call. = FALSE)
  }
  missing_indices <- setdiff(selected_indices, names(climateIndices))
  if (length(missing_indices)) {
    stop(
      sprintf("climateIndices is missing selected columns: %s", paste(missing_indices, collapse = ", ")),
      call. = FALSE
    )
  }
  required_cols <- c("date", selected_indices)
  if (!"date" %in% names(climateIndices)) {
    stop("climateIndices must contain a date column.", call. = FALSE)
  }

  index_labels <- c(
    nino3 = "Nino 3",
    nao = "NAO",
    nino12 = "Nino 1+2",
    whwp = "WHWP",
    gmt = "GMT",
    oni = "ONI",
    pna = "PNA",
    noi = "NOI",
    wp = "WP",
    nino34 = "Nino 3.4",
    solar_flux = "Solar Flux",
    amo = "AMO",
    espi = "ESPI",
    tsa = "TSA",
    nino4 = "Nino 4",
    tna = "TNA",
    soi = "SOI"
  )
  selected_labels <- unname(index_labels[selected_indices])
  missing_labels <- is.na(selected_labels) | !nzchar(selected_labels)
  selected_labels[missing_labels] <- toupper(selected_indices[missing_labels])

  bt_dates <- month_sequence_from_ts(BTflow)
  flow_df <- data.frame(date = bt_dates, flow_cfs = as.numeric(BTflow))
  climate_df <- climateIndices[, required_cols, drop = FALSE]
  climate_df$date <- as.Date(climate_df$date)

  model_df <- merge(flow_df, climate_df, by = "date", all = FALSE)
  model_df <- model_df[order(model_df$date), , drop = FALSE]

  fit_start <- as.Date(ex3_cfg$fit_start %||% min(model_df$date))
  fit_end <- as.Date(ex3_cfg$fit_end %||% max(model_df$date))
  model_df <- model_df[model_df$date >= fit_start & model_df$date <= fit_end, , drop = FALSE]
  model_df <- model_df[stats::complete.cases(model_df[, c("flow_cfs", selected_indices), drop = FALSE]), , drop = FALSE]

  if (nrow(model_df) < 36L) {
    stop("Example 3 aligned data window has fewer than 36 complete monthly observations.", call. = FALSE)
  }
  if (any(!is.finite(model_df$flow_cfs)) || any(model_df$flow_cfs <= 0)) {
    stop("BTflow values used in Example 3 must be positive and finite before log transform.", call. = FALSE)
  }

  X_raw <- as.matrix(model_df[, selected_indices, drop = FALSE])
  storage.mode(X_raw) <- "double"
  x_center <- colMeans(X_raw)
  x_scale <- apply(X_raw, 2, stats::sd)
  if (any(!is.finite(x_scale)) || any(x_scale <= 0)) {
    stop("Selected climate-index columns must have positive finite standard deviations.", call. = FALSE)
  }
  X_scaled <- sweep(sweep(X_raw, 2, x_center, "-"), 2, x_scale, "/")
  colnames(X_scaled) <- selected_indices

  flow_ts <- make_monthly_ts(model_df$flow_cfs, model_df$date)
  y_log_ts <- log(flow_ts)
  y_log <- as.numeric(y_log_ts)
  k_cov <- ncol(X_scaled)

  ex3_cols <- list(
    m1 = "#8A46B2",
    m1_aux = "#C48AE0",
    m2 = "#2E7D5B",
    m2_aux = "#85B89A",
    idx1 = "#2D6F95",
    idx2 = "#B85C38",
    ref = "#C47A2C"
  )
  index_cols <- c(ex3_cols$idx1, ex3_cols$idx2, "#6B8E23", "#5F4B8B")
  index_cols <- rep(index_cols, length.out = k_cov)

  harmonics <- as.numeric(ex3_cfg$harmonics %||% c(1, 2, 0.1469118636))
  trend_order <- as.integer(ex3_cfg$trend_order %||% 1L)
  seasonal_period <- as.numeric(ex3_cfg$seasonal_period %||% 12)
  trend_df <- as.numeric(ex3_cfg$trend_df %||% 0.99)
  seasonal_df <- as.numeric(ex3_cfg$seasonal_df %||% 0.99)
  covariate_df <- as.numeric(ex3_cfg$covariate_df %||% 0.99)
  transfer_zeta_df <- as.numeric(ex3_cfg$transfer_zeta_df %||% 0.99)
  transfer_psi_df <- as.numeric(ex3_cfg$transfer_psi_df %||% 0.99)
  trend_c0 <- as.numeric(ex3_cfg$trend_c0 %||% 0.1)
  seasonal_c0 <- as.numeric(ex3_cfg$seasonal_c0 %||% 1)
  reg_c0 <- as.numeric(ex3_cfg$reg_c0 %||% 1)
  transfer_zeta_c0 <- as.numeric(ex3_cfg$transfer_zeta_c0 %||% 0.1)
  transfer_psi_c0 <- as.numeric(ex3_cfg$transfer_psi_c0 %||% 0.005)
  gam_init <- as.numeric(ex3_cfg$gam_init %||% -0.1)
  sig_init <- as.numeric(ex3_cfg$sig_init %||% 0.1)
  n_samp <- as.integer(ex3_cfg$n_samp)
  tol <- as.numeric(ex3_cfg$tol)
  max_iter <- as.integer(ex3_cfg$max_iter %||% getOption("exdqlm.max_iter", 200L))
  lambda_grid <- as.numeric(ex3_cfg$lambda_grid)
  lambda_grid <- sort(unique(lambda_grid[is.finite(lambda_grid) & lambda_grid > 0 & lambda_grid < 1]))
  if (!length(lambda_grid)) stop("Example 3 lambda_grid must contain values in (0, 1).", call. = FALSE)

  trend_comp <- exdqlm::polytrendMod(
    order = trend_order,
    m0 = as.numeric(stats::quantile(y_log, probs = p0)),
    C0 = trend_c0
  )
  seas_comp <- exdqlm::seasMod(
    p = seasonal_period,
    h = harmonics,
    C0 = diag(seasonal_c0, 2L * length(harmonics))
  )
  model <- trend_comp + seas_comp
  reg_comp <- exdqlm::regMod(X_scaled, m0 = rep(0, k_cov), C0 = diag(reg_c0, k_cov))
  model_w_reg <- model + reg_comp

  base_state_dim <- length(model$m0)
  seasonal_idx <- seq.int(trend_order + 1L, base_state_dim)
  direct_cov_idx <- seq.int(base_state_dim + 1L, base_state_dim + k_cov)
  transfer_zeta_idx <- base_state_dim + 1L
  transfer_psi_idx <- seq.int(base_state_dim + 2L, base_state_dim + k_cov + 1L)

  df_base <- c(trend_df, seasonal_df)
  dim_df_base <- c(trend_order, 2L * length(harmonics))
  df_direct <- c(trend_df, seasonal_df, covariate_df)
  dim_df_direct <- c(trend_order, 2L * length(harmonics), k_cov)
  tf_df <- c(transfer_zeta_df, transfer_psi_df)
  tf_m0 <- rep(0, k_cov + 1L)
  tf_C0 <- diag(c(transfer_zeta_c0, rep(transfer_psi_c0, k_cov)), k_cov + 1L)

  fit_direct_model <- function() {
    exdqlm::exdqlmLDVB(
      y = y_log_ts, p0 = p0, model = model_w_reg,
      df = df_direct, dim.df = dim_df_direct,
      sig.init = sig_init, gam.init = gam_init,
      fix.sigma = FALSE,
      tol = tol, n.samp = n_samp,
      verbose = FALSE
    )
  }

  fit_transfer_model <- function(lambda) {
    exdqlm::exdqlmTransferLDVB(
      y = y_log_ts, p0 = p0, model = model,
      df = df_base, dim.df = dim_df_base,
      X = X_scaled, tf.df = tf_df, lam = lambda,
      tf.m0 = tf_m0, tf.C0 = tf_C0,
      sig.init = sig_init, gam.init = gam_init,
      fix.sigma = FALSE,
      tol = tol, n.samp = n_samp,
      verbose = FALSE
    )
  }

  with_ex3_max_iter <- function(expr) {
    old <- options(exdqlm.max_iter = max_iter)
    on.exit(options(old), add = TRUE)
    eval.parent(substitute(expr))
  }

  diag_ref_samp <- seeded_rnorm(length(y_log), seed_value + 301L)

  if (need_ex3data) {
    save_png_plot("ex3data.png", {
      old_par <- graphics::par(mfrow = c(2, 1), mar = c(3.0, 4.2, 1.0, 0.8), oma = c(1.6, 0, 0, 0))
      on.exit(graphics::par(old_par), add = TRUE)

      stats::plot.ts(y_log_ts, col = "grey35", ylab = "log flow", xlab = "", lwd = 1.1)
      graphics::grid(col = "grey88")

      tx <- as.numeric(stats::time(y_log_ts))
      graphics::plot(
        tx, X_scaled[, 1L], type = "l", lty = 1, lwd = 1.6,
        col = index_cols[[1L]], xlab = "", ylab = "standardized index",
        ylim = padded_range(X_scaled)
      )
      if (k_cov > 1L) {
        for (j in 2L:k_cov) {
          graphics::lines(tx, X_scaled[, j], col = index_cols[[j]], lwd = 1.6, lty = j)
        }
      }
      graphics::abline(h = 0, col = "grey65", lty = 3)
      graphics::grid(col = "grey88")
      graphics::legend(
        "topleft", legend = selected_labels, col = index_cols,
        lty = seq_len(k_cov), lwd = 1.6, bty = "n", ncol = min(2L, k_cov)
      )
      graphics::mtext("time", side = 1, outer = TRUE, line = 0.4)
    })
    register_artifact(
      artifact_id = "fig_ex3data",
      artifact_type = "figure",
      relative_path = "analysis/manuscript/outputs/figures/ex3data.png",
      manuscript_target = "fig:ex3data",
      status = "reproduced",
      notes = sprintf(
        "Top: log observed monthly package BTflow. Bottom: standardized %s over %s to %s.",
        paste(selected_labels, collapse = " and "),
        fmt_month(min(model_df$date)),
        fmt_month(max(model_df$date))
      )
    )
  }

  if (need_ex3_models) {
    pkg_commit <- git_short_head(resolve_pkg_path()$path)
    grid_tag <- paste(sprintf("%03d", round(100 * lambda_grid)), collapse = "_")
    window_tag <- paste(fmt_month(range(model_df$date)), collapse = "_")
    cache_key <- sprintf(
      "ex3_models_ldvb_v13_p%s_iter%d_%s_%s_%s_grid%s_nsamp%d_tol%s",
      p0_tag,
      max_iter,
      paste(selected_indices, collapse = "_"),
      pkg_commit %||% "unknown",
      window_tag,
      grid_tag,
      n_samp,
      gsub("[^0-9A-Za-z]+", "_", format(tol))
    )

    ex3_models <- load_or_fit_cache(cache_key, {
      lambda_rows <- vector("list", length(lambda_grid))
      lambda_fits <- vector("list", length(lambda_grid))

      for (i in seq_along(lambda_grid)) {
        lambda_seed <- seed_value + 3300L + i
        temp_M2 <- tryCatch(
          with_ex3_max_iter(with_local_seed(lambda_seed, fit_transfer_model(lambda_grid[[i]]))),
          error = function(e) e
        )
        status <- "ok"
        error_message <- ""
        KL <- CRPS <- pplc <- runtime <- NA_real_
        iter <- NA_integer_
        converged <- NA

        if (inherits(temp_M2, "error")) {
          status <- "error"
          error_message <- conditionMessage(temp_M2)
        } else {
          lambda_fits[[i]] <- temp_M2
          runtime <- as.numeric(temp_M2$run.time %||% NA_real_)
          iter <- as.integer(temp_M2$iter %||% NA_integer_)
          converged <- isTRUE(temp_M2$converged)
          temp_check <- tryCatch(
            diagnostics_from_fit(temp_M2, plot = FALSE, ref = diag_ref_samp, y_data = y_log),
            error = function(e) e
          )
          if (inherits(temp_check, "error")) {
            status <- "diagnostics_error"
            error_message <- conditionMessage(temp_check)
          } else {
            KL <- temp_check$m1.KL
            CRPS <- temp_check$m1.CRPS
            pplc <- temp_check$m1.pplc
            if (!all(is.finite(c(KL, CRPS, pplc)))) {
              status <- "nonfinite_diagnostics"
            }
          }
        }

        lambda_rows[[i]] <- data.frame(
          lambda = lambda_grid[[i]],
          KL = KL,
          CRPS = CRPS,
          pplc = pplc,
          runtime = runtime,
          iter = iter,
          converged = converged,
          status = status,
          error_message = error_message,
          seed = lambda_seed,
          stringsAsFactors = FALSE
        )
      }

      lambda_table <- do.call(rbind, lambda_rows)
      finite_crps <- is.finite(lambda_table$CRPS) & lambda_table$status == "ok"
      if (!any(finite_crps)) {
        stop("No finite CRPS values were produced by the Example 3 lambda scan.", call. = FALSE)
      }
      selected_idx <- which(finite_crps)[which.min(lambda_table$CRPS[finite_crps])]
      lambda_star <- lambda_table$lambda[[selected_idx]]
      lambda_table$selected_by_CRPS <- seq_len(nrow(lambda_table)) == selected_idx

      M1_ldvb <- tryCatch(
        with_ex3_max_iter(with_local_seed(seed_value + 3200L, fit_direct_model())),
        error = function(e) e
      )
      M2_ldvb <- lambda_fits[[selected_idx]]
      if (!fit_ok(M2_ldvb)) {
        M2_ldvb <- tryCatch(
          with_ex3_max_iter(with_local_seed(lambda_table$seed[[selected_idx]], fit_transfer_model(lambda_star))),
          error = function(e) e
        )
      }

      list(
        M1 = M1_ldvb,
        M2 = M2_ldvb,
        model = model,
        model_w_reg = model_w_reg,
        lambda_grid = lambda_grid,
        lambda_table = lambda_table,
        lambda_star = lambda_star,
        selected_indices = selected_indices,
        selected_labels = selected_labels,
        X_center = x_center,
        X_scale = x_scale,
        n_samp = n_samp,
        tol = tol,
        max_iter = max_iter
      )
    }, note = cache_key)

    M1 <- ex3_models$M1
    M2 <- ex3_models$M2
    if (!fit_ok(M1) || !fit_ok(M2)) {
      stop("Example 3 final LDVB fits failed; cannot regenerate manuscript artifacts.", call. = FALSE)
    }
    M1$y <- y_log_ts
    M2$y <- y_log_ts

    lambda_star <- ex3_models$lambda_star
    lambda_table <- ex3_models$lambda_table
    selected_labels <- ex3_models$selected_labels
    selected_indices <- ex3_models$selected_indices

    capture_output_file("ex3_run_summary.txt", {
      cat(sprintf("profile=%s\n", selected_profile))
      cat(sprintf("package_commit=%s\n", git_short_head(resolve_pkg_path()$path)))
      cat(sprintf("p0=%0.2f\n", p0))
      cat(sprintf("data_window=%s to %s\n", fmt_month(min(model_df$date)), fmt_month(max(model_df$date))))
      cat(sprintf("n_observations=%d\n", nrow(model_df)))
      cat(sprintf("selected_indices=%s\n", paste(selected_labels, collapse = ", ")))
      cat(sprintf("n.samp=%d, tol=%s, max_iter=%d\n", ex3_models$n_samp, format(ex3_models$tol), ex3_models$max_iter))
      cat(sprintf("lambda_star_by_CRPS=%0.3f\n\n", lambda_star))
      cat("Lambda scan:\n")
      print(lambda_table)
      cat("\nCovariate scaling:\n")
      print(data.frame(index = selected_indices, label = selected_labels, center = ex3_models$X_center, scale = ex3_models$X_scale))
      cat("\nM2$median.kt:\n")
      print(M2$median.kt)
      cat("\nRun times (seconds):\n")
      print(c(M1 = M1$run.time, M2 = M2$run.time))
      cat("\nConvergence status:\n")
      print(data.frame(
        model = c("M1", "M2"),
        iter = c(M1$iter %||% NA_integer_, M2$iter %||% NA_integer_),
        converged = c(isTRUE(M1$converged), isTRUE(M2$converged))
      ))
    })
    register_artifact(
      artifact_id = "ex3_run_summary",
      artifact_type = "log",
      relative_path = "analysis/manuscript/outputs/logs/ex3_run_summary.txt",
      manuscript_target = "Example 3 textual outputs",
      status = "reproduced",
      notes = "Observed BTflow plus NOI/AMO Example 3 summary including CRPS lambda scan and transfer persistence."
    )

    save_png_plot("ex3_vb_convergence.png", {
      plot_vb_convergence_grid(
        fits = list(M1_dynamic_regression = M1, M2_transfer_function = M2),
        labels = c("M1 dynamic regression", "M2 transfer function")
      )
    }, width = 10, height = 5.8)
    register_artifact(
      artifact_id = "fig_ex3_vb_convergence",
      artifact_type = "figure",
      relative_path = "analysis/manuscript/outputs/figures/ex3_vb_convergence.png",
      manuscript_target = "support: Example 3 LDVB convergence traces",
      status = "reproduced",
      notes = sprintf("Support-only LDVB convergence traces for the Example 3 final fits (p0=%s, n.samp=%d, max_iter=%d).", p0_label, n_samp, max_iter)
    )

    model_dataset <- data.frame(
      date = model_df$date,
      flow_cfs = model_df$flow_cfs,
      log_flow = y_log,
      X_scaled,
      check.names = FALSE
    )
    save_table_csv(
      model_dataset,
      filename = "ex3_model_dataset.csv",
      artifact_id = "tab_ex3_model_dataset",
      manuscript_target = "support: Example 3 aligned model dataset",
      status = "reproduced",
      notes = "Aligned package BTflow and standardized climate-index inputs used by the canonical Example 3 fits."
    )

    covariate_scaling <- data.frame(
      index = selected_indices,
      label = selected_labels,
      center = as.numeric(ex3_models$X_center),
      scale = as.numeric(ex3_models$X_scale),
      stringsAsFactors = FALSE
    )
    save_table_csv(
      covariate_scaling,
      filename = "ex3_covariate_scaling.csv",
      artifact_id = "tab_ex3_covariate_scaling",
      manuscript_target = "support: Example 3 covariate standardization",
      status = "reproduced",
      notes = "Centers and scales used to standardize the selected climate indices."
    )

    save_table_csv(
      lambda_table,
      filename = "ex3_lambda_scan.csv",
      artifact_id = "tab_ex3_lambda_scan",
      manuscript_target = "Example 3 lambda selection output",
      status = "reproduced",
      notes = sprintf("Example 3 transfer-function lambda scan; best finite CRPS lambda=%0.3f.", lambda_star)
    )
    register_note("ex3", sprintf("Example 3 selected lambda=%0.3f by finite CRPS over the documented grid.", lambda_star))
    register_note("ex3", sprintf(
      "Example 3 uses observed package BTflow and standardized %s from climateIndices over %s to %s.",
      paste(selected_labels, collapse = " and "),
      fmt_month(min(model_df$date)),
      fmt_month(max(model_df$date))
    ))

    xlim_mid <- as.numeric(ex3_cfg$focus_window %||% c(2016, 2020))
    if (length(xlim_mid) != 2L || any(!is.finite(xlim_mid)) || xlim_mid[[1L]] >= xlim_mid[[2L]]) {
      stop("Example 3 focus_window must contain two increasing finite years.", call. = FALSE)
    }
    forecast_horizon <- as.integer(ex3_cfg$forecast_horizon %||% 18L)
    if (!is.finite(forecast_horizon) || forecast_horizon < 1L || forecast_horizon >= length(y_log)) {
      stop("Example 3 forecast_horizon must be positive and smaller than the analysis sample.", call. = FALSE)
    }
    forecast_start_t <- length(y_log) - forecast_horizon
    tx <- grDevices::xy.coords(y_log_ts)$x
    forecast_plot_start <- as.numeric(ex3_cfg$forecast_plot_start %||% (tx[forecast_start_t] - 4))
    if (!is.finite(forecast_plot_start)) {
      stop("Example 3 forecast_plot_start must be finite.", call. = FALSE)
    }
    xlim_fore <- c(max(min(tx), forecast_plot_start), max(tx))

    if (need_ex3quantcomps) {
      q1 <- quantile_summary_from_fit(M1, cr.percent = 0.95)
      q2 <- quantile_summary_from_fit(M2, cr.percent = 0.95)
      c1_seas <- component_summary_from_fit(M1, index = seasonal_idx)
      c2_seas <- component_summary_from_fit(M2, index = seasonal_idx)
      c1_cov <- component_summary_from_fit(M1, index = direct_cov_idx)
      c2_transfer <- component_summary_from_fit(M2, index = transfer_zeta_idx)

      save_png_plot("ex3quantcomps.png", {
        old_par <- graphics::par(mfrow = c(3, 1), mar = c(2.8, 4.4, 1.0, 0.9), oma = c(1.8, 0, 0, 0))
        on.exit(graphics::par(old_par), add = TRUE)

        graphics::plot(
          tx, y_log, type = "l", col = "grey70",
          ylim = padded_range(y_log, q1$lb, q1$ub, q2$lb, q2$ub),
          xlim = xlim_mid, xlab = "", ylab = "log flow / quantile"
        )
        graphics::grid(col = "grey90")
        plot_quantile_summary(q1, col = ex3_cols$m1, add = TRUE)
        plot_quantile_summary(q2, col = ex3_cols$m2, add = TRUE)
        graphics::legend(
          "topleft", legend = c("M1 dynamic regression", "M2 transfer function"),
          col = c(ex3_cols$m1, ex3_cols$m2), lty = 1, lwd = 1.5, bty = "n"
        )

        graphics::plot(
          NA, ylim = padded_range(c1_seas$lb, c1_seas$ub, c2_seas$lb, c2_seas$ub),
          xlim = xlim_mid, ylab = "seasonal contribution", xlab = ""
        )
        graphics::grid(col = "grey90")
        plot_component_with_band(c1_seas, col = ex3_cols$m1)
        plot_component_with_band(c2_seas, col = ex3_cols$m2)
        graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 1.4)

        graphics::plot(
          NA, ylim = padded_range(c1_cov$lb, c1_cov$ub, c2_transfer$lb, c2_transfer$ub),
          xlim = xlim_mid, ylab = "climate contribution", xlab = ""
        )
        graphics::grid(col = "grey90")
        plot_component_with_band(c1_cov, col = ex3_cols$m1)
        plot_component_with_band(c2_transfer, col = ex3_cols$m2)
        graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 1.4)
        graphics::mtext("time", side = 1, outer = TRUE, line = 0.5)
      })
      register_artifact(
        artifact_id = "fig_ex3quantcomps",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex3quantcomps.png",
        manuscript_target = "fig:ex3quant",
        status = "reproduced",
        notes = "Example 3 quantile, seasonal, and combined NOI/AMO climate-contribution comparison."
      )
    }

    if (need_ex3zetapsi) {
      save_png_plot("ex3zetapsi.png", {
        old_par <- graphics::par(no.readonly = TRUE)
        on.exit(graphics::par(old_par), add = TRUE)

        if (k_cov == 2L) {
          graphics::layout(matrix(c(1, 1, 2, 3), nrow = 2, byrow = TRUE), heights = c(1.05, 1))
        } else {
          graphics::par(mfrow = c(1, k_cov + 1L))
        }
        psi_ylim_by_index <- list(noi = c(-0.3, 0), amo = c(0, 0.3))

        graphics::par(mar = c(3.0, 4.2, 2.1, 0.8), oma = c(0, 0, 0, 0))
        zeta <- component_summary_from_fit(M2, index = transfer_zeta_idx, just.theta = TRUE)
        plot_component_summary(zeta, col = ex3_cols$m2, add = FALSE, xlab = "")
        graphics::grid(col = "grey90")
        graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 1.4)
        graphics::title(expression(zeta[t]))

        graphics::par(mar = c(3.8, 4.2, 2.1, 0.8))
        for (j in seq_len(k_cov)) {
          psi <- component_summary_from_fit(M2, index = transfer_psi_idx[[j]], just.theta = TRUE)
          psi_ylim <- psi_ylim_by_index[[selected_indices[[j]]]]
          plot_component_summary(psi, col = index_cols[[j]], add = FALSE, ylim = psi_ylim)
          graphics::grid(col = "grey90")
          graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 1.4)
          graphics::title(climate_psi_title(selected_labels[[j]]))
        }
      })
      register_artifact(
        artifact_id = "fig_ex3zetapsi",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex3zetapsi.png",
        manuscript_target = "fig:ex3tftheta",
        status = "reproduced",
        notes = "Transfer-function zeta state and NOI/AMO psi states for the canonical Example 3 fit."
      )
    }

    if (need_ex3forecast) {
      save_png_plot("ex3forecast.png", {
        stats::plot.ts(
          y_log_ts, col = "grey70",
          ylim = padded_range(y_log),
          xlim = xlim_fore,
          ylab = "log flow / forecast quantile",
          xlab = "time"
        )
        graphics::grid(col = "grey90")
        fc1 <- forecast_from_fit(
          start.t = forecast_start_t, k = forecast_horizon, m1 = M1,
          plot = FALSE, y_data = y_log_ts
        )
        fc1$ff <- fc1$ff[seq_len(fc1$k)]
        fc1$fQ <- fc1$fQ[seq_len(fc1$k)]
        plot(fc1, add = TRUE, cols = c(ex3_cols$m1, ex3_cols$m1_aux))

        fc2 <- forecast_from_fit(
          start.t = forecast_start_t, k = forecast_horizon, m1 = M2,
          plot = FALSE, y_data = y_log_ts
        )
        fc2$ff <- fc2$ff[seq_len(fc2$k)]
        fc2$fQ <- fc2$fQ[seq_len(fc2$k)]
        plot(fc2, add = TRUE, cols = c(ex3_cols$m2, ex3_cols$m2_aux))

        graphics::abline(v = tx[[forecast_start_t]], col = ex3_cols$ref, lty = 5, lwd = 1.2)
        graphics::legend(
          "topleft", legend = c("M1 regression", "M2 transfer"),
          col = c(ex3_cols$m1, ex3_cols$m2), lty = 1, lwd = 1.4, bty = "n"
        )
      }, width = 8, height = 5.5)
      register_artifact(
        artifact_id = "fig_ex3forecast",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex3forecast.png",
        manuscript_target = "fig:ex3forecast",
        status = "reproduced",
        notes = sprintf(
          "Example 3 %d-step forecast over the final observed overlap window ending %s.",
          forecast_horizon,
          fmt_month(max(model_df$date))
        )
      )
    }

    if (need_ex3tables) {
      diag_3 <- diagnostics_from_fit(M1, M2, plot = FALSE, ref = diag_ref_samp, y_data = y_log)
      diag_table <- data.frame(
        model = c("M1_dynamic_regression", "M2_transfer_function"),
        KL = c(diag_3$m1.KL, diag_3$m2.KL),
        CRPS = c(diag_3$m1.CRPS, diag_3$m2.CRPS),
        pplc = c(diag_3$m1.pplc, diag_3$m2.pplc),
        run_time_seconds = c(diag_3$m1.rt, diag_3$m2.rt),
        stringsAsFactors = FALSE
      )
      save_table_csv(
        diag_table,
        filename = "ex3_diagnostics_summary.csv",
        artifact_id = "tab_ex3_diagnostics",
        manuscript_target = "tab:ex3",
        status = "reproduced",
        notes = "Example 3 diagnostics table generated from the canonical NOI/AMO manuscript workflow."
      )
    }
  }

  log_msg("Example 3 (Big Tree): complete")
}
