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

  forecast_metrics_row <- function(model, label, forecast_obj, y_future,
                                   crps_probs, crps_weights = NULL) {
    dx <- exdqlm::exdqlmForecastDiagnostics(
      forecast_obj,
      y = y_future,
      crps_probs = crps_probs,
      crps_weights = crps_weights
    )
    data.frame(
      model = model,
      label = label,
      horizon = dx$horizon,
      mean_check_loss = as.numeric(dx$m1.check_loss),
      CRPS = as.numeric(dx$m1.CRPS),
      stringsAsFactors = FALSE
    )
  }

  scale_with_training <- function(X_raw, train_idx) {
    center <- colMeans(X_raw[train_idx, , drop = FALSE])
    scale <- apply(X_raw[train_idx, , drop = FALSE], 2, stats::sd)
    if (any(!is.finite(scale)) || any(scale <= 0)) {
      stop("Training-window climate-index scaling produced non-positive standard deviations.", call. = FALSE)
    }
    X_scaled <- sweep(sweep(X_raw, 2, center, "-"), 2, scale, "/")
    colnames(X_scaled) <- colnames(X_raw)
    list(X_scaled = X_scaled, center = center, scale = scale)
  }

  build_base_forecast_mats <- function(base_model, k) {
    p <- length(base_model$m0)
    list(
      fFF = matrix(base_model$FF, nrow = p, ncol = k),
      fGG = array(base_model$GG, c(p, p, k))
    )
  }

  build_direct_forecast_mats <- function(base_model, X_future_scaled, coef_c0 = 1) {
    X_future_scaled <- as.matrix(X_future_scaled)
    reg_future <- exdqlm::regMod(
      X_future_scaled,
      m0 = rep(0, ncol(X_future_scaled)),
      C0 = diag(coef_c0, ncol(X_future_scaled))
    )
    future_model <- base_model + reg_future
    p <- length(future_model$m0)
    k <- nrow(X_future_scaled)
    list(
      fFF = matrix(future_model$FF, nrow = p, ncol = k),
      fGG = array(future_model$GG, c(p, p, k))
    )
  }

  build_transfer_forecast_mats <- function(base_model, X_future_scaled, lambda) {
    X_future_scaled <- as.matrix(X_future_scaled)
    TT <- nrow(X_future_scaled)
    temp_p <- length(base_model$m0)
    k <- ncol(X_future_scaled)
    zeta_idx <- temp_p + 1L
    psi_idx <- seq.int(temp_p + 2L, temp_p + k + 1L)
    p_aug <- temp_p + k + 1L

    base_FF <- matrix(base_model$FF, nrow = temp_p, ncol = TT)
    base_GG <- array(base_model$GG, c(temp_p, temp_p, TT))

    fFF <- matrix(0, p_aug, TT)
    fFF[seq_len(temp_p), ] <- base_FF
    fFF[zeta_idx, ] <- 1

    fGG <- array(0, c(p_aug, p_aug, TT))
    fGG[seq_len(temp_p), seq_len(temp_p), ] <- base_GG
    fGG[zeta_idx, zeta_idx, ] <- lambda
    for (j in seq_len(k)) {
      fGG[zeta_idx, psi_idx[[j]], ] <- X_future_scaled[, j]
      fGG[psi_idx[[j]], psi_idx[[j]], ] <- 1
    }

    list(fFF = fFF, fGG = fGG, zeta_idx = zeta_idx, psi_idx = psi_idx)
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

  if (nrow(model_df) < 60L) {
    stop("Example 3 aligned data window has fewer than 60 complete monthly observations.", call. = FALSE)
  }
  if (any(!is.finite(model_df$flow_cfs)) || any(model_df$flow_cfs <= 0)) {
    stop("BTflow values used in Example 3 must be positive and finite before log transform.", call. = FALSE)
  }

  X_raw <- as.matrix(model_df[, selected_indices, drop = FALSE])
  storage.mode(X_raw) <- "double"

  flow_ts <- make_monthly_ts(model_df$flow_cfs, model_df$date)
  y_log_ts <- log(flow_ts)
  y_log <- as.numeric(y_log_ts)
  k_cov <- ncol(X_raw)

  forecast_horizon <- as.integer(ex3_cfg$forecast_horizon %||% 18L)
  if (!is.finite(forecast_horizon) || forecast_horizon < 1L || forecast_horizon >= nrow(model_df)) {
    stop("Example 3 forecast_horizon must be positive and smaller than the analysis sample.", call. = FALSE)
  }
  final_train_n <- nrow(model_df) - forecast_horizon
  final_train_idx <- seq_len(final_train_n)
  holdout_idx <- seq.int(final_train_n + 1L, nrow(model_df))

  final_scaling <- scale_with_training(X_raw, final_train_idx)
  X_final_scaled <- final_scaling$X_scaled

  y_train_ts <- make_monthly_ts(y_log[final_train_idx], model_df$date[final_train_idx])
  y_holdout <- y_log[holdout_idx]
  X_train <- X_final_scaled[final_train_idx, , drop = FALSE]
  X_holdout <- X_final_scaled[holdout_idx, , drop = FALSE]

  ex3_cols <- list(
    m0 = "#7A4BA0",
    m0_aux = "#B991CC",
    mtf = "#2E7D5B",
    mtf_aux = "#85B89A",
    mreg = "#4C72B0",
    mreg_aux = "#9EB8D9",
    idx1 = "#2D6F95",
    idx2 = "#B85C38",
    holdout = "#C47A2C",
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
  transfer_psi_df_grid <- as.numeric(ex3_cfg$transfer_psi_df_grid %||% transfer_psi_df)
  transfer_psi_df_grid <- sort(unique(transfer_psi_df_grid[is.finite(transfer_psi_df_grid) &
                                                             transfer_psi_df_grid > 0 &
                                                             transfer_psi_df_grid <= 1]))
  if (!length(transfer_psi_df_grid)) transfer_psi_df_grid <- transfer_psi_df
  selection_metric <- toupper(as.character(ex3_cfg$selection_metric %||% "PPLC"))
  if (!selection_metric %in% c("PPLC", "CRPS", "KL")) {
    stop("Example 3 selection_metric must be one of PPLC, CRPS, or KL.", call. = FALSE)
  }
  crps_probs <- as.numeric(ex3_cfg$crps_probs %||% seq(0.01, 0.99, by = 0.01))
  crps_probs <- sort(unique(crps_probs[is.finite(crps_probs) & crps_probs > 0 & crps_probs < 1]))
  if (!length(crps_probs)) {
    stop("Example 3 crps_probs must contain values strictly between 0 and 1.", call. = FALSE)
  }
  trend_c0 <- as.numeric(ex3_cfg$trend_c0 %||% 0.1)
  trend_m0 <- as.numeric(ex3_cfg$trend_m0 %||% log(50))
  seasonal_c0 <- as.numeric(ex3_cfg$seasonal_c0 %||% 1)
  climate_coef_c0 <- as.numeric(ex3_cfg$climate_coef_c0 %||% 1)
  reg_c0 <- as.numeric(ex3_cfg$reg_c0 %||% climate_coef_c0)
  transfer_zeta_c0 <- as.numeric(ex3_cfg$transfer_zeta_c0 %||% 0.1)
  transfer_psi_c0 <- as.numeric(ex3_cfg$transfer_psi_c0 %||% climate_coef_c0)
  gam_init <- as.numeric(ex3_cfg$gam_init %||% -0.1)
  sig_init <- as.numeric(ex3_cfg$sig_init %||% 0.1)
  n_samp <- as.integer(ex3_cfg$n_samp)
  forecast_n_samp <- as.integer(ex3_cfg$forecast_n_samp %||% n_samp)
  if (!is.finite(forecast_n_samp) || forecast_n_samp < 1L) forecast_n_samp <- n_samp
  tol <- as.numeric(ex3_cfg$tol)
  max_iter <- as.integer(ex3_cfg$max_iter %||% getOption("exdqlm.max_iter", 200L))
  lambda_grid <- as.numeric(ex3_cfg$lambda_grid)
  lambda_grid <- sort(unique(lambda_grid[is.finite(lambda_grid) & lambda_grid > 0 & lambda_grid < 1]))
  if (!length(lambda_grid)) stop("Example 3 lambda_grid must contain values in (0, 1).", call. = FALSE)

  make_base_model <- function(y_train) {
    trend_comp <- exdqlm::polytrendMod(
      order = trend_order,
      m0 = trend_m0,
      C0 = trend_c0
    )
    seas_comp <- exdqlm::seasMod(
      p = seasonal_period,
      h = harmonics,
      C0 = diag(seasonal_c0, 2L * length(harmonics))
    )
    trend_comp + seas_comp
  }

  base_model_template <- make_base_model(y_train_ts)
  base_state_dim <- length(base_model_template$m0)
  seasonal_idx <- seq.int(trend_order + 1L, base_state_dim)
  direct_reg_idx <- seq.int(base_state_dim + 1L, base_state_dim + k_cov)
  transfer_zeta_idx <- base_state_dim + 1L
  transfer_psi_idx <- seq.int(base_state_dim + 2L, base_state_dim + k_cov + 1L)

  df_base <- c(trend_df, seasonal_df)
  dim_df_base <- c(trend_order, 2L * length(harmonics))
  df_direct <- c(trend_df, seasonal_df, covariate_df)
  dim_df_direct <- c(trend_order, 2L * length(harmonics), k_cov)
  tf_m0 <- rep(0, k_cov + 1L)
  tf_C0 <- diag(c(transfer_zeta_c0, rep(transfer_psi_c0, k_cov)), k_cov + 1L)

  fit_base_model <- function(y_train) {
    base_model <- make_base_model(y_train)
    fit <- exdqlm::exdqlmLDVB(
      y = y_train, p0 = p0, model = base_model,
      df = df_base, dim.df = dim_df_base,
      sig.init = sig_init, gam.init = gam_init,
      fix.sigma = FALSE,
      tol = tol, n.samp = n_samp,
      verbose = FALSE
    )
    attr(fit, "ex3_base_model") <- base_model
    fit
  }

  fit_direct_model <- function(y_train, X_train_scaled) {
    base_model <- make_base_model(y_train)
    reg_comp <- exdqlm::regMod(
      X_train_scaled,
      m0 = rep(0, ncol(X_train_scaled)),
      C0 = diag(reg_c0, ncol(X_train_scaled))
    )
    fit <- exdqlm::exdqlmLDVB(
      y = y_train, p0 = p0, model = base_model + reg_comp,
      df = df_direct, dim.df = dim_df_direct,
      sig.init = sig_init, gam.init = gam_init,
      fix.sigma = FALSE,
      tol = tol, n.samp = n_samp,
      verbose = FALSE
    )
    attr(fit, "ex3_base_model") <- base_model
    fit
  }

  fit_transfer_model <- function(y_train, X_train_scaled, lambda, psi_df) {
    base_model <- make_base_model(y_train)
    tf_df <- c(transfer_zeta_df, psi_df)
    fit <- exdqlm::exdqlmTransferLDVB(
      y = y_train, p0 = p0, model = base_model,
      df = df_base, dim.df = dim_df_base,
      X = X_train_scaled, tf.df = tf_df, lam = lambda,
      tf.m0 = tf_m0, tf.C0 = tf_C0,
      sig.init = sig_init, gam.init = gam_init,
      fix.sigma = FALSE,
      tol = tol, n.samp = n_samp,
      verbose = FALSE
    )
    attr(fit, "ex3_base_model") <- base_model
    fit
  }

  forecast_with_mats <- function(fit, k, mats, seed) {
    exdqlm::exdqlmForecast(
      start.t = length(fit$y),
      k = k,
      m1 = fit,
      fFF = mats$fFF,
      fGG = mats$fGG,
      plot = FALSE,
      return.draws = TRUE,
      n.samp = forecast_n_samp,
      seed = seed
    )
  }

  with_ex3_max_iter <- function(expr) {
    old <- options(exdqlm.max_iter = max_iter)
    on.exit(options(old), add = TRUE)
    eval.parent(substitute(expr))
  }

  ex3_diagnostics <- function(...) {
    args <- list(...)
    args$plot <- FALSE
    if ("crps_probs" %in% names(formals(exdqlm::exdqlmDiagnostics))) {
      args$crps_probs <- crps_probs
    }
    do.call(exdqlm::exdqlmDiagnostics, args)
  }

  if (need_ex3data) {
    save_png_plot("ex3data.png", {
      old_par <- graphics::par(mfrow = c(2, 1), mar = c(3.0, 4.2, 1.0, 0.8), oma = c(1.6, 0, 0, 0))
      on.exit(graphics::par(old_par), add = TRUE)

      stats::plot.ts(y_log_ts, col = "grey35", ylab = "log flow", xlab = "", lwd = 1.1)
      graphics::grid(col = "grey88")
      graphics::abline(v = grDevices::xy.coords(y_log_ts)$x[holdout_idx[[1L]]], col = ex3_cols$holdout, lty = 5, lwd = 1.2)

      tx <- as.numeric(stats::time(y_log_ts))
      graphics::plot(
        tx, X_final_scaled[, 1L], type = "l", lty = 1, lwd = 1.6,
        col = index_cols[[1L]], xlab = "", ylab = "standardized index",
        ylim = padded_range(X_final_scaled)
      )
      if (k_cov > 1L) {
        for (j in 2L:k_cov) {
          graphics::lines(tx, X_final_scaled[, j], col = index_cols[[j]], lwd = 1.6, lty = j)
        }
      }
      graphics::abline(h = 0, col = "grey65", lty = 3)
      graphics::abline(v = tx[holdout_idx[[1L]]], col = ex3_cols$holdout, lty = 5, lwd = 1.2)
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
        "Top: log observed monthly package BTflow. Bottom: standardized %s over %s to %s; vertical line marks the 18-month forecast holdout.",
        paste(selected_labels, collapse = " and "),
        fmt_month(min(model_df$date)),
        fmt_month(max(model_df$date))
      )
    )
  }

  if (need_ex3_models) {
    pkg_commit <- git_short_head(resolve_pkg_path()$path)
    grid_tag <- paste(sprintf("%03d", round(100 * lambda_grid)), collapse = "_")
    psi_tag <- paste(sprintf("%03d", round(100 * transfer_psi_df_grid)), collapse = "_")
    window_tag <- paste(fmt_month(range(model_df$date)), collapse = "_")
    metric_tag <- gsub("[^0-9A-Za-z]+", "_", selection_metric)
    p0_tag <- sprintf("p%03d", round(100 * p0))
    prior_tag <- sprintf("m0%04d_c0%04d", round(1000 * trend_m0), round(1000 * trend_c0))
    coef_tag <- sprintf(
      "coefc0%04d_regdf%03d_zetadf%03d_psidf%s",
      round(1000 * climate_coef_c0),
      round(100 * covariate_df),
      round(100 * transfer_zeta_df),
      psi_tag
    )
    cache_key <- sprintf(
      "ex3_models_trainselect_v6_threemodel_%s_%s_%s_%s_%s_%s_grid%s_%s_nsamp%d_tol%s_h%d",
      paste(selected_indices, collapse = "_"),
      pkg_commit %||% "unknown",
      window_tag,
      p0_tag,
      prior_tag,
      coef_tag,
      grid_tag,
      metric_tag,
      n_samp,
      gsub("[^0-9A-Za-z]+", "_", format(tol)),
      forecast_horizon
    )

    ex3_models <- load_or_fit_cache(cache_key, {
      selection_rows <- list()
      row_id <- 0L
      for (psi_df in transfer_psi_df_grid) {
        for (i in seq_along(lambda_grid)) {
          row_id <- row_id + 1L
          lambda <- lambda_grid[[i]]
          selection_seed <- seed_value + 3500L + row_id
          log_msg(sprintf(
            "Example 3 training-selection fit %d/%d: lambda = %.3f, transfer psi df = %.3f",
            row_id, length(lambda_grid) * length(transfer_psi_df_grid), lambda, psi_df
          ))
          fit <- tryCatch(
            with_ex3_max_iter(with_local_seed(
              selection_seed,
              fit_transfer_model(y_train_ts, X_train, lambda = lambda, psi_df = psi_df)
            )),
            error = function(e) e
          )

          row <- data.frame(
            lambda = lambda,
            transfer_zeta_df = transfer_zeta_df,
            transfer_psi_df = psi_df,
            selection_metric = selection_metric,
            selection_value = NA_real_,
            KL = NA_real_,
            KL_flipped = NA_real_,
            CRPS = NA_real_,
            PPLC = NA_real_,
            runtime = NA_real_,
            iter = NA_integer_,
            converged = NA,
            status = "ok",
            error_message = "",
            seed = selection_seed,
            stringsAsFactors = FALSE
          )

          if (!fit_ok(fit)) {
            row$status <- "fit_error"
            row$error_message <- conditionMessage(fit)
            selection_rows[[row_id]] <- row
            next
          }

          row$runtime <- as.numeric(fit$run.time %||% NA_real_)
          row$iter <- as.integer(fit$iter %||% NA_integer_)
          row$converged <- isTRUE(fit$converged)

          diag_fit <- tryCatch(
            ex3_diagnostics(fit),
            error = function(e) e
          )
          if (!fit_ok(diag_fit)) {
            row$status <- "diagnostics_error"
            row$error_message <- conditionMessage(diag_fit)
            selection_rows[[row_id]] <- row
            next
          }

          row$KL <- as.numeric(diag_fit$m1.KL %||% NA_real_)
          row$KL_flipped <- as.numeric(diag_fit$m1.KL.flip %||% NA_real_)
          row$CRPS <- as.numeric(diag_fit$m1.CRPS %||% NA_real_)
          row$PPLC <- as.numeric(diag_fit$m1.pplc %||% NA_real_)
          row$selection_value <- as.numeric(row[[selection_metric]])
          if (!is.finite(row$selection_value)) {
            row$status <- "nonfinite_metrics"
          }
          selection_rows[[row_id]] <- row
        }
      }

      selection_table <- do.call(rbind, selection_rows)
      ok <- selection_table$status == "ok" & is.finite(selection_table$selection_value)
      if (!any(ok)) {
        stop("No finite training-selection diagnostics were produced by the Example 3 transfer grid.", call. = FALSE)
      }
      eligible_idx <- which(ok)
      order_key <- order(
        selection_table$selection_value[eligible_idx],
        -selection_table$transfer_psi_df[eligible_idx],
        selection_table$CRPS[eligible_idx],
        selection_table$KL[eligible_idx],
        selection_table$lambda[eligible_idx]
      )
      selected_idx <- eligible_idx[order_key[[1L]]]
      selection_table$selected <- seq_len(nrow(selection_table)) == selected_idx
      lambda_star <- selection_table$lambda[[selected_idx]]
      psi_df_star <- selection_table$transfer_psi_df[[selected_idx]]
      log_msg(sprintf(
        "Example 3 selected transfer settings: lambda = %.3f, transfer psi df = %.3f by training %s",
        lambda_star, psi_df_star, selection_metric
      ))

      log_msg("Example 3 final fit: M0 no-transfer baseline")
      M0 <- tryCatch(
        with_ex3_max_iter(with_local_seed(seed_value + 3600L, fit_base_model(y_train_ts))),
        error = function(e) e
      )
      log_msg("Example 3 final fit: MTF transfer-function model")
      MTF <- tryCatch(
        with_ex3_max_iter(with_local_seed(
          seed_value + 3700L,
          fit_transfer_model(y_train_ts, X_train, lambda = lambda_star, psi_df = psi_df_star)
        )),
        error = function(e) e
      )
      log_msg("Example 3 final fit: MREG direct-regression model")
      MREG <- tryCatch(
        with_ex3_max_iter(with_local_seed(seed_value + 3800L, fit_direct_model(y_train_ts, X_train))),
        error = function(e) e
      )

      if (!fit_ok(M0) || !fit_ok(MREG) || !fit_ok(MTF)) {
        stop("Example 3 final no-transfer, direct-regression, or transfer-function LDVB fit failed.", call. = FALSE)
      }

      base_final <- attr(M0, "ex3_base_model")
      log_msg("Example 3 forecasting and scoring final 18-month holdout")
      fc_M0 <- forecast_with_mats(
        M0,
        k = forecast_horizon,
        mats = build_base_forecast_mats(base_final, forecast_horizon),
        seed = seed_value + 4600L
      )
      fc_MTF <- forecast_with_mats(
        MTF,
        k = forecast_horizon,
        mats = build_transfer_forecast_mats(attr(MTF, "ex3_base_model"), X_holdout, lambda = lambda_star),
        seed = seed_value + 4700L
      )
      fc_MREG <- forecast_with_mats(
        MREG,
        k = forecast_horizon,
        mats = build_direct_forecast_mats(attr(MREG, "ex3_base_model"), X_holdout, coef_c0 = reg_c0),
        seed = seed_value + 4800L
      )

      forecast_metrics <- rbind(
        forecast_metrics_row("M0_no_transfer", "M0 no transfer", fc_M0, y_holdout,
                             crps_probs = crps_probs),
        forecast_metrics_row("MREG_direct_regression", "MREG direct regression", fc_MREG, y_holdout,
                             crps_probs = crps_probs),
        forecast_metrics_row("MTF_transfer_function", "MTF transfer function", fc_MTF, y_holdout,
                             crps_probs = crps_probs)
      )
      sensitivity_metrics <- forecast_metrics

      list(
        M0 = M0,
        MTF = MTF,
        MREG = MREG,
        fc_M0 = fc_M0,
        fc_MTF = fc_MTF,
        fc_MREG = fc_MREG,
        selection_table = selection_table,
        forecast_metrics = forecast_metrics,
        sensitivity_metrics = sensitivity_metrics,
        lambda_star = lambda_star,
        psi_df_star = psi_df_star,
        selected_indices = selected_indices,
        selected_labels = selected_labels,
        X_center = final_scaling$center,
        X_scale = final_scaling$scale,
        selection_metric = selection_metric,
        crps_probs = crps_probs,
        n_samp = n_samp,
        forecast_n_samp = forecast_n_samp,
        tol = tol,
        max_iter = max_iter
      )
    }, note = cache_key)

    M0 <- ex3_models$M0
    MTF <- ex3_models$MTF
    MREG <- ex3_models$MREG
    fc_M0 <- ex3_models$fc_M0
    fc_MTF <- ex3_models$fc_MTF
    fc_MREG <- ex3_models$fc_MREG
    if (!fit_ok(M0) || !fit_ok(MREG) || !fit_ok(MTF)) {
      stop("Example 3 final LDVB fits failed; cannot regenerate manuscript artifacts.", call. = FALSE)
    }

    M0$y <- y_train_ts
    MTF$y <- y_train_ts
    MREG$y <- y_train_ts

    lambda_star <- ex3_models$lambda_star
    psi_df_star <- ex3_models$psi_df_star
    selected_labels <- ex3_models$selected_labels
    selected_indices <- ex3_models$selected_indices
    selection_table <- ex3_models$selection_table
    forecast_metrics <- rbind(
      forecast_metrics_row("M0_no_transfer", "M0 no transfer", fc_M0, y_holdout,
                           crps_probs = crps_probs),
      forecast_metrics_row("MREG_direct_regression", "MREG direct regression", fc_MREG, y_holdout,
                           crps_probs = crps_probs),
      forecast_metrics_row("MTF_transfer_function", "MTF transfer function", fc_MTF, y_holdout,
                           crps_probs = crps_probs)
    )
    sensitivity_metrics <- forecast_metrics
    diagnostic_row <- function(model, label, fit) {
      dx <- ex3_diagnostics(fit)
      data.frame(
        model = model,
        label = label,
        KL = as.numeric(dx$m1.KL),
        KL_flipped = as.numeric(dx$m1.KL.flip),
        CRPS = as.numeric(dx$m1.CRPS),
        PPLC = as.numeric(dx$m1.pplc),
        stringsAsFactors = FALSE
      )
    }
    diagnostics_summary <- rbind(
      diagnostic_row("M0_no_transfer", "M0 no transfer", M0),
      diagnostic_row("MREG_direct_regression", "MREG direct regression", MREG),
      diagnostic_row("MTF_transfer_function", "MTF transfer function", MTF)
    )
    capture_output_file("ex3_run_summary.txt", {
      cat(sprintf("profile=%s\n", selected_profile))
      cat(sprintf("package_commit=%s\n", git_short_head(resolve_pkg_path()$path)))
      cat(sprintf("p0=%0.2f\n", p0))
      cat(sprintf("trend_prior_m0=%0.6f, trend_prior_C0=%0.3f\n", trend_m0, trend_c0))
      cat(sprintf("climate_coef_prior_C0=%0.3f\n", climate_coef_c0))
      cat(sprintf(
        "discount_factors=trend:%0.3f, seasonal:%0.3f, direct_coef:%0.3f, transfer_zeta:%0.3f, transfer_psi:%0.3f\n",
        trend_df, seasonal_df, covariate_df, transfer_zeta_df, psi_df_star
      ))
      cat(sprintf("data_window=%s to %s\n", fmt_month(min(model_df$date)), fmt_month(max(model_df$date))))
      cat(sprintf("final_training_window=%s to %s\n", fmt_month(model_df$date[min(final_train_idx)]), fmt_month(model_df$date[max(final_train_idx)])))
      cat(sprintf("forecast_holdout_window=%s to %s\n", fmt_month(model_df$date[min(holdout_idx)]), fmt_month(model_df$date[max(holdout_idx)])))
      cat(sprintf("n_observations=%d, n_train=%d, n_holdout=%d\n", nrow(model_df), length(final_train_idx), length(holdout_idx)))
      cat(sprintf("selected_indices=%s\n", paste(selected_labels, collapse = ", ")))
      cat(sprintf("n.samp=%d, forecast_n.samp=%d, tol=%s, max_iter=%d\n", ex3_models$n_samp, ex3_models$forecast_n_samp, format(ex3_models$tol), ex3_models$max_iter))
      cat(sprintf("lambda_star_by_training_%s=%0.3f\n", tolower(ex3_models$selection_metric), lambda_star))
      cat(sprintf("transfer_psi_df_star=%0.3f\n\n", psi_df_star))
      cat("Training transfer grid diagnostics:\n")
      print(selection_table)
      cat("\nFinal-training covariate scaling:\n")
      print(data.frame(index = selected_indices, label = selected_labels, center = ex3_models$X_center, scale = ex3_models$X_scale))
      cat("\nMTF$median.kt:\n")
      print(MTF$median.kt)
      cat("\nRun times:\n")
      print(c(M0 = M0$run.time, MTF = MTF$run.time, MREG = if (fit_ok(MREG)) MREG$run.time else NA_real_))
      cat("\nConvergence:\n")
      print(data.frame(
        model = c("M0", "MTF", "MREG"),
        iter = c(M0$iter %||% NA_integer_, MTF$iter %||% NA_integer_, if (fit_ok(MREG)) MREG$iter %||% NA_integer_ else NA_integer_),
        converged = c(isTRUE(M0$converged), isTRUE(MTF$converged), if (fit_ok(MREG)) isTRUE(MREG$converged) else NA)
      ))
      cat("\nFinal-training package diagnostics from exdqlmDiagnostics():\n")
      print(diagnostics_summary)
      cat("\nFinal holdout forecast metrics from exdqlmForecastDiagnostics():\n")
      print(forecast_metrics)
      cat("\nSensitivity forecast metrics:\n")
      print(sensitivity_metrics)
    })
    register_artifact(
      artifact_id = "ex3_run_summary",
      artifact_type = "log",
      relative_path = "analysis/manuscript/outputs/logs/ex3_run_summary.txt",
      manuscript_target = "Example 3 textual outputs",
      status = "reproduced",
      notes = "Observed BTflow plus NOI/AMO Example 3 summary with training-selected transfer settings, package diagnostics, and held-out forecast metrics."
    )

    model_dataset <- data.frame(
      date = model_df$date,
      flow_cfs = model_df$flow_cfs,
      log_flow = y_log,
      phase = ifelse(seq_len(nrow(model_df)) %in% holdout_idx, "forecast_holdout", "training"),
      model_train = seq_len(nrow(model_df)) %in% final_train_idx,
      model_holdout = seq_len(nrow(model_df)) %in% holdout_idx,
      X_final_scaled,
      check.names = FALSE
    )
    save_table_csv(
      model_dataset,
      filename = "ex3_model_dataset.csv",
      artifact_id = "tab_ex3_model_dataset",
      manuscript_target = "Example 3 modeling dataset",
      status = "reproduced",
      notes = "Aligned Big Tree flow and climate-index data used by Example 3, with training and forecast-holdout phase labels."
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
      manuscript_target = "Example 3 covariate scaling",
      status = "reproduced",
      notes = "Training-window means and standard deviations used to standardize Example 3 climate indices."
    )
    save_table_csv(
      selection_table,
      filename = "ex3_lambda_selection.csv",
      artifact_id = "tab_ex3_lambda_selection",
      manuscript_target = "Example 3 transfer training-selection output",
      status = "reproduced",
      notes = sprintf(
        "Example 3 transfer-function training diagnostic grid; selected lambda=%0.3f and transfer psi discount=%0.3f by training %s.",
        lambda_star,
        psi_df_star,
        ex3_models$selection_metric
      )
    )
    save_table_csv(
      diagnostics_summary,
      filename = "ex3_diagnostics_summary.csv",
      artifact_id = "tab_ex3_diagnostics",
      manuscript_target = "tab:ex3",
      status = "reproduced",
      notes = "Example 3 final-training package diagnostics from exdqlmDiagnostics for the no-covariate, direct-regression, and transfer-function models."
    )
    save_table_csv(
      forecast_metrics,
      filename = "ex3_forecast_metrics.csv",
      artifact_id = "tab_ex3_forecast_metrics",
      manuscript_target = "tab:ex3forecastmetrics",
      status = "reproduced",
      notes = "Example 3 final 18-month holdout forecast check loss and CRPS from exdqlmForecastDiagnostics for the no-covariate, direct-regression, and transfer-function models."
    )
    save_table_csv(
      sensitivity_metrics,
      filename = "ex3_sensitivity_forecast_metrics.csv",
      artifact_id = "tab_ex3_sensitivity_forecast_metrics",
      manuscript_target = "Example 3 sensitivity forecast metrics",
      status = "reproduced",
      notes = "Backward-compatible copy of the Example 3 final 18-month holdout forecast check loss and CRPS from exdqlmForecastDiagnostics."
    )
    register_note("ex3", sprintf(
      "Example 3 selected lambda=%0.3f using training-data %s with static transfer psi coefficients (discount fixed at %0.3f).",
      lambda_star,
      ex3_models$selection_metric,
      psi_df_star
    ))
    register_note("ex3", sprintf(
      "Example 3 final forecast metrics are computed only on the %d-month holdout window from %s to %s.",
      forecast_horizon,
      fmt_month(model_df$date[min(holdout_idx)]),
      fmt_month(model_df$date[max(holdout_idx)])
    ))

    xlim_mid <- as.numeric(ex3_cfg$focus_window %||% c(2016, 2020))
    if (length(xlim_mid) != 2L || any(!is.finite(xlim_mid)) || xlim_mid[[1L]] >= xlim_mid[[2L]]) {
      stop("Example 3 focus_window must contain two increasing finite years.", call. = FALSE)
    }
    tx_full <- grDevices::xy.coords(y_log_ts)$x
    tx_train <- grDevices::xy.coords(y_train_ts)$x
    forecast_plot_start <- as.numeric(ex3_cfg$forecast_plot_start %||% (tx_train[length(tx_train)] - 4))
    if (!is.finite(forecast_plot_start)) {
      stop("Example 3 forecast_plot_start must be finite.", call. = FALSE)
    }
    xlim_fore <- c(max(min(tx_full), forecast_plot_start), max(tx_full))

    if (need_ex3quantcomps) {
      q0 <- quantile_summary_from_fit(M0, cr.percent = 0.95)
      qreg <- quantile_summary_from_fit(MREG, cr.percent = 0.95)
      qtf <- quantile_summary_from_fit(MTF, cr.percent = 0.95)
      c0_seas <- component_summary_from_fit(M0, index = seasonal_idx)
      creg_seas <- component_summary_from_fit(MREG, index = seasonal_idx)
      ctf_seas <- component_summary_from_fit(MTF, index = seasonal_idx)
      creg_direct <- component_summary_from_fit(MREG, index = direct_reg_idx)
      ctf_transfer <- component_summary_from_fit(MTF, index = transfer_zeta_idx)

      save_png_plot("ex3quantcomps.png", {
        old_par <- graphics::par(mfrow = c(3, 1), mar = c(2.8, 4.4, 1.0, 0.9), oma = c(1.8, 0, 0, 0))
        on.exit(graphics::par(old_par), add = TRUE)

        graphics::plot(
          tx_full, y_log, type = "l", col = "grey70",
          ylim = padded_range(y_log, q0$lb, q0$ub, qreg$lb, qreg$ub, qtf$lb, qtf$ub),
          xlim = xlim_mid, xlab = "", ylab = "log flow / quantile"
        )
        graphics::grid(col = "grey90")
        plot_quantile_summary(q0, col = ex3_cols$m0, add = TRUE)
        plot_quantile_summary(qreg, col = ex3_cols$mreg, add = TRUE)
        plot_quantile_summary(qtf, col = ex3_cols$mtf, add = TRUE)
        graphics::legend(
          "topleft", legend = c("M0 no covariates", "MREG direct regression", "MTF transfer function"),
          col = c(ex3_cols$m0, ex3_cols$mreg, ex3_cols$mtf), lty = 1, lwd = 1.5, bty = "n"
        )

        graphics::plot(
          NA, ylim = padded_range(c0_seas$lb, c0_seas$ub, creg_seas$lb, creg_seas$ub, ctf_seas$lb, ctf_seas$ub),
          xlim = xlim_mid, ylab = "seasonal contribution", xlab = ""
        )
        graphics::grid(col = "grey90")
        plot_component_with_band(c0_seas, col = ex3_cols$m0)
        plot_component_with_band(creg_seas, col = ex3_cols$mreg)
        plot_component_with_band(ctf_seas, col = ex3_cols$mtf)
        graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 1.4)

        graphics::plot(
          NA, ylim = padded_range(creg_direct$lb, creg_direct$ub, ctf_transfer$lb, ctf_transfer$ub, 0),
          xlim = xlim_mid, ylab = "covariate contribution", xlab = ""
        )
        graphics::grid(col = "grey90")
        plot_component_with_band(creg_direct, col = ex3_cols$mreg)
        plot_component_with_band(ctf_transfer, col = ex3_cols$mtf)
        graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 1.4)
        graphics::legend(
          "topleft", legend = c("MREG direct", "MTF transfer"),
          col = c(ex3_cols$mreg, ex3_cols$mtf), lty = 1, lwd = 1.5, bty = "n"
        )
        graphics::mtext("time", side = 1, outer = TRUE, line = 0.5)
      }, width = 8.2, height = 7.2, pointsize = 12.5)
      register_artifact(
        artifact_id = "fig_ex3quantcomps",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex3quantcomps.png",
        manuscript_target = "fig:ex3quant",
        status = "reproduced",
        notes = "Example 3 quantile, seasonal, and covariate-contribution comparison for M0, MREG, and MTF."
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
        graphics::par(mar = c(3.0, 4.2, 2.1, 0.8), oma = c(0, 0, 0, 0))
        zeta <- component_summary_from_fit(MTF, index = transfer_zeta_idx, just.theta = TRUE)
        plot_component_summary(zeta, col = ex3_cols$mtf, add = FALSE, xlab = "")
        graphics::grid(col = "grey90")
        graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 1.4)
        graphics::title(expression(zeta[t]))

        graphics::par(mar = c(3.8, 4.2, 2.1, 0.8))
        for (j in seq_len(k_cov)) {
          psi <- component_summary_from_fit(MTF, index = transfer_psi_idx[[j]], just.theta = TRUE)
          psi_ylim <- padded_range(psi$lb, psi$ub, 0)
          plot_component_summary(psi, col = index_cols[[j]], add = FALSE, ylim = psi_ylim)
          graphics::grid(col = "grey90")
          graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 1.4)
          graphics::title(climate_psi_title(selected_labels[[j]]))
        }
      }, width = 8.8, height = 5.8, pointsize = 12.5)
      register_artifact(
        artifact_id = "fig_ex3zetapsi",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex3zetapsi.png",
        manuscript_target = "fig:ex3tftheta",
        status = "reproduced",
        notes = "Transfer-function zeta state and NOI/AMO psi states for the final Example 3 fit."
      )
    }

    if (need_ex3forecast) {
      save_png_plot("ex3forecast.png", {
        stats::plot.ts(
          y_log_ts, col = "grey70",
          ylim = padded_range(y_log, fc_M0$ff, fc_MREG$ff, fc_MTF$ff),
          xlim = xlim_fore,
          ylab = "log flow / forecast quantile",
          xlab = "time"
        )
        graphics::grid(col = "grey90")
        plot(fc_M0, add = TRUE, cols = c(ex3_cols$m0, ex3_cols$m0_aux))
        plot(fc_MREG, add = TRUE, cols = c(ex3_cols$mreg, ex3_cols$mreg_aux))
        plot(fc_MTF, add = TRUE, cols = c(ex3_cols$mtf, ex3_cols$mtf_aux))
        graphics::lines(tx_full[holdout_idx], y_log[holdout_idx], col = ex3_cols$holdout, lwd = 1.4)
        graphics::points(tx_full[holdout_idx], y_log[holdout_idx], col = ex3_cols$holdout, pch = 1, cex = 0.8)
        graphics::abline(v = tx_full[holdout_idx[[1L]]], col = ex3_cols$ref, lty = 5, lwd = 1.2)
        graphics::legend(
          "topleft", legend = c("M0 no covariates", "MREG direct regression", "MTF transfer", "held-out observations"),
          col = c(ex3_cols$m0, ex3_cols$mreg, ex3_cols$mtf, ex3_cols$holdout),
          lty = c(1, 1, 1, 1), pch = c(NA, NA, NA, 1), lwd = c(1.4, 1.4, 1.4, 1.2), bty = "n"
        )
      }, width = 8.4, height = 5.5, pointsize = 12.5)
      register_artifact(
        artifact_id = "fig_ex3forecast",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex3forecast.png",
        manuscript_target = "fig:ex3forecast",
        status = "reproduced",
        notes = sprintf(
          "Example 3 %d-step holdout forecast over %s to %s.",
          forecast_horizon,
          fmt_month(model_df$date[min(holdout_idx)]),
          fmt_month(model_df$date[max(holdout_idx)])
        )
      )
    }
  }

  log_msg("Example 3 (Big Tree): complete")
}
