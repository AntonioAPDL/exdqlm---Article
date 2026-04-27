need_ex1 <- target_enabled("ex1", c("ex1mcmc", "ex1quants", "ex1synth", "ex1kernel"))
if (!need_ex1) {
  log_msg("Example 1 (Lake Huron): skipped (target filter)")
} else {
  log_msg("Example 1 (Lake Huron): start")

  need_ex1mcmc <- target_enabled("ex1mcmc", "ex1")
  need_ex1quants <- target_enabled("ex1quants", "ex1")
  need_ex1synth <- target_enabled("ex1synth", "ex1")
  need_ex1kernel <- isTRUE(targeted_run) && target_enabled("ex1kernel")
  need_ex1_runtime <- need_ex1mcmc || need_ex1quants
  need_ex1_quants_models <- need_ex1quants || need_ex1_runtime || need_ex1synth
  need_ex1_synthesis <- need_ex1quants || need_ex1synth
  need_ex1_trace_model <- need_ex1mcmc || need_ex1_runtime

  y_ts <- datasets::LakeHuron
  y <- as.numeric(y_ts)
  model <- exdqlm::polytrendMod(order = 2, m0 = c(mean(y), 0), C0 = 10 * diag(2))

  capture_output_file("ex1_model_output.txt", {
    print(model)
  })
  register_artifact(
    artifact_id = "ex1_model_output",
    artifact_type = "log",
    relative_path = "analysis/manuscript/outputs/logs/ex1_model_output.txt",
    manuscript_target = "Example 1 model block",
    status = "reproduced",
    notes = "polytrend model object output."
  )

  nburn <- as.integer(cfg_profile$ex1$n_burn)
  nmcmc <- as.integer(cfg_profile$ex1$n_mcmc)
  nburn_trace <- as.integer(cfg_profile$ex1$n_burn_trace %||% nburn)
  nmcmc_trace <- as.integer(cfg_profile$ex1$n_mcmc_trace %||% nmcmc)
  thin_trace <- max(1L, as.integer(cfg_profile$ex1$thin_trace %||% 1L))
  n_chains_kernel <- as.integer(cfg_profile$ex1$n_chains_kernel %||% 4L)
  nburn_kernel <- as.integer(cfg_profile$ex1$n_burn_kernel %||% nburn)
  nmcmc_kernel <- as.integer(cfg_profile$ex1$n_mcmc_kernel %||% nmcmc)
  thin_kernel_plot <- max(1L, as.integer(cfg_profile$ex1$thin_kernel_plot %||% 1L))
  synth_source_draws <- max(50L, as.integer(cfg_profile$ex1$synth_source_draws %||% 1000L))
  synth_n_samp <- max(100L, as.integer(cfg_profile$ex1$synth_n_samp %||% 1000L))
  forecast_window_start <- as.numeric(cfg_profile$ex1$forecast_window_start %||% 1952)
  synth_window_start <- as.numeric(cfg_profile$ex1$synth_window_start %||% 1952)

  if (!is.finite(n_chains_kernel) || n_chains_kernel < 2L) {
    stop("Example 1 kernel comparison requires n_chains_kernel >= 2.", call. = FALSE)
  }

  M95 <- NULL
  M50_dqlm <- NULL
  M5 <- NULL
  M50_trace <- NULL
  M95_plot <- NULL
  M50_dqlm_plot <- NULL
  M5_plot <- NULL
  fc95 <- NULL
  fc50 <- NULL
  fc05 <- NULL
  ex1_synthesis <- NULL
  ex1_synthesis_bridge_check <- NULL
  sigma_trace <- NULL
  gamma_trace <- NULL
  thin_idx <- integer(0)
  sigma_trace_thin <- NULL
  gamma_trace_thin <- NULL

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

  summarize_smoothed_quantile <- function(mfit, cr.percent = 0.95) {
    y_ref <- mfit$y
    half.alpha <- (1 - cr.percent) / 2
    p_state <- dim(mfit$samp.theta)[1]
    n_samp <- dim(mfit$samp.theta)[3]
    TT_local <- length(y_ref)
    big_FF <- array(mfit$model$FF, c(p_state, TT_local, n_samp))
    quant_samps <- colSums(big_FF * mfit$samp.theta)
    list(
      x = grDevices::xy.coords(y_ref)$x,
      qmap = rowMeans(quant_samps),
      qlb = matrixStats::rowQuantiles(quant_samps, probs = half.alpha),
      qub = matrixStats::rowQuantiles(quant_samps, probs = cr.percent + half.alpha)
    )
  }

  add_forecast_overlay <- function(fc, cols = c("purple", "magenta"), lwd_main = 1.8, lwd_ci = 1,
                                   halo_col = "white", halo_main = 3.8, halo_ci = 2.2,
                                   observed_mode = c("filtered", "smoothed")) {
    observed_mode <- match.arg(observed_mode)
    y_ref <- fc$m1$y
    ts_xy <- grDevices::xy.coords(y_ref)
    half.alpha <- (1 - fc$cr.percent) / 2

    if (identical(observed_mode, "smoothed")) {
      smooth_quant <- summarize_smoothed_quantile(fc$m1, cr.percent = fc$cr.percent)
      qmap <- smooth_quant$qmap[seq_len(fc$start.t)]
      qlb <- smooth_quant$qlb[seq_len(fc$start.t)]
      qub <- smooth_quant$qub[seq_len(fc$start.t)]
    } else {
      p <- dim(fc$m1$model$GG)[1]
      FF.start.t <- matrix(fc$m1$model$FF[, 1:fc$start.t], p, fc$start.t)
      fm.start.t <- matrix(fc$m1$theta.out$fm[, 1:fc$start.t], p, fc$start.t)
      qmap <- colSums(matrix(FF.start.t * fm.start.t, p, fc$start.t))
      fC.start.t <- array(fc$m1$theta.out$fC[, , 1:fc$start.t], c(p, p, fc$start.t))
      temp.var <- matrix(NA_real_, p, fc$start.t)
      for (t in seq_len(fc$start.t)) {
        temp.var[, t] <- fC.start.t[, , t] %*% FF.start.t[, t]
      }
      qvar <- colSums(FF.start.t * temp.var)
      qsd <- sqrt(pmax(qvar, 0))
      zlb <- stats::qnorm(half.alpha)
      zub <- stats::qnorm(fc$cr.percent + half.alpha)
      qlb <- qmap + zlb * qsd
      qub <- qmap + zub * qsd
    }
    zlb <- stats::qnorm(half.alpha)
    zub <- stats::qnorm(fc$cr.percent + half.alpha)
    fqlb <- fc$ff + zlb * sqrt(pmax(fc$fQ, 0))
    fqub <- fc$ff + zub * sqrt(pmax(fc$fQ, 0))
    x_future <- seq(from = ts_xy$x[fc$start.t], by = diff(ts_xy$x)[1], length.out = fc$k + 1L)

    graphics::lines(ts_xy$x[1:fc$start.t], qlb, col = halo_col, lty = 3, lwd = halo_ci)
    graphics::lines(ts_xy$x[1:fc$start.t], qub, col = halo_col, lty = 3, lwd = halo_ci)
    graphics::lines(ts_xy$x[1:fc$start.t], qmap, col = halo_col, lwd = halo_main)
    graphics::lines(x_future, c(qmap[fc$start.t], fc$ff), col = halo_col, lwd = halo_main)
    graphics::lines(x_future, c(qub[fc$start.t], fqub), col = halo_col, lty = 3, lwd = halo_ci)
    graphics::lines(x_future, c(qlb[fc$start.t], fqlb), col = halo_col, lty = 3, lwd = halo_ci)

    graphics::lines(ts_xy$x[1:fc$start.t], qlb, col = cols[1], lty = 3, lwd = lwd_ci)
    graphics::lines(ts_xy$x[1:fc$start.t], qub, col = cols[1], lty = 3, lwd = lwd_ci)
    graphics::lines(ts_xy$x[1:fc$start.t], qmap, col = cols[1], lwd = lwd_main)
    graphics::lines(x_future, c(qmap[fc$start.t], fc$ff), col = cols[2], lwd = lwd_main)
    graphics::lines(x_future, c(qub[fc$start.t], fqub), col = cols[2], lty = 3, lwd = lwd_ci)
    graphics::lines(x_future, c(qlb[fc$start.t], fqlb), col = cols[2], lty = 3, lwd = lwd_ci)
  }

  synthesis_forecast_origin_check <- function(syn_obs, syn_future, y_ts) {
    ts_xy <- grDevices::xy.coords(y_ts)
    dt_local <- 1 / stats::frequency(y_ts)
    observed_end_time <- tail(ts_xy$x, 1L)
    first_forecast_time <- observed_end_time + dt_local

    data.frame(
      observed_end_time = observed_end_time,
      first_forecast_time = first_forecast_time,
      data_time_step = dt_local,
      time_gap = first_forecast_time - observed_end_time,
      observed_q025 = tail(as.numeric(syn_obs$summary$q025), 1L),
      forecast_q025 = as.numeric(syn_future$summary$q025[1L]),
      q025_jump = as.numeric(syn_future$summary$q025[1L]) - tail(as.numeric(syn_obs$summary$q025), 1L),
      observed_q500 = tail(as.numeric(syn_obs$summary$q500), 1L),
      forecast_q500 = as.numeric(syn_future$summary$q500[1L]),
      q500_jump = as.numeric(syn_future$summary$q500[1L]) - tail(as.numeric(syn_obs$summary$q500), 1L),
      observed_q975 = tail(as.numeric(syn_obs$summary$q975), 1L),
      forecast_q975 = as.numeric(syn_future$summary$q975[1L]),
      q975_jump = as.numeric(syn_future$summary$q975[1L]) - tail(as.numeric(syn_obs$summary$q975), 1L),
      stringsAsFactors = FALSE
    )
  }

  add_synthesis_forecast_bridge <- function(check, band.col, border = NA) {
    graphics::polygon(
      x = c(
        check$observed_end_time,
        check$first_forecast_time,
        check$first_forecast_time,
        check$observed_end_time
      ),
      y = c(
        check$observed_q025,
        check$forecast_q025,
        check$forecast_q975,
        check$observed_q975
      ),
      col = band.col,
      border = border
    )
  }

  ex1_quant_cols <- list(
    q95 = "#8A46B2",
    q95_future = "#C48AE0",
    q50 = "#2F6FA8",
    q50_future = "#8DBFDE",
    q05 = "#2E7D5B",
    q05_future = "#85B89A"
  )

  synth_obs_col <- grDevices::adjustcolor("#F7D6DE", alpha.f = 0.40)
  synth_fore_col <- grDevices::adjustcolor("#C96F83", alpha.f = 0.48)

  if (need_ex1_quants_models) {
    ex1_quants <- load_or_fit_cache(sprintf("ex1_quants_models_v3_main_2000_3000_seed%s", seed_value), {
      M95 <- exdqlm::exdqlmMCMC(
        y = y, p0 = 0.95, model = model,
        df = 0.9, dim.df = 2,
        PriorGamma = list(m_gam = -1, s_gam = 0.1, df_gam = 1),
        n.burn = nburn, n.mcmc = nmcmc,
        verbose = FALSE
      )
      M5 <- exdqlm::exdqlmMCMC(
        y = y, p0 = 0.05, model = model,
        df = 0.9, dim.df = 2,
        PriorGamma = list(m_gam = 1, s_gam = 0.1, df_gam = 1),
        n.burn = nburn, n.mcmc = nmcmc,
        verbose = FALSE
      )
      M50_dqlm <- exdqlm::exdqlmMCMC(
        y = y, p0 = 0.50, model = model,
        df = 0.9, dim.df = 2,
        gam.init = 0, fix.gamma = TRUE,
        n.burn = nburn, n.mcmc = nmcmc,
        verbose = FALSE
      )
      list(model = model, M95 = M95, M50_dqlm = M50_dqlm, M5 = M5)
    }, note = sprintf("ex1_quants_models_v3_main_2000_3000_seed%s", seed_value))

    M95 <- ex1_quants$M95
    M50_dqlm <- ex1_quants$M50_dqlm
    M5 <- ex1_quants$M5

    M95_plot <- M95
    M50_dqlm_plot <- M50_dqlm
    M5_plot <- M5
    M95_plot$y <- y_ts
    M50_dqlm_plot$y <- y_ts
    M5_plot$y <- y_ts
  }

  if (need_ex1_trace_model) {
    ex1_trace <- load_or_fit_cache(sprintf("ex1_trace_model_v5_slice_2000_3000_seed%s", seed_value), {
      M50_trace <- exdqlm::exdqlmMCMC(
        y = y, p0 = 0.50, model = model,
        df = 0.9, dim.df = 2,
        PriorGamma = list(m_gam = 0, s_gam = 0.1, df_gam = 1),
        n.burn = nburn_trace, n.mcmc = nmcmc_trace,
        verbose = FALSE
      )
      list(M50_trace = M50_trace)
    }, note = sprintf("ex1_trace_model_v5_slice_2000_3000_seed%s", seed_value))

    M50_trace <- ex1_trace$M50_trace
    sigma_trace <- as.numeric(M50_trace$samp.sigma)
    gamma_trace <- as.numeric(M50_trace$samp.gamma)
    thin_idx <- seq.int(1L, length(sigma_trace), by = thin_trace)
    sigma_trace_thin <- coda::mcmc(sigma_trace[thin_idx], thin = thin_trace)
    gamma_trace_thin <- coda::mcmc(gamma_trace[thin_idx], thin = thin_trace)
  }

  fFF <- model$FF
  fGG <- model$GG
  k_fore <- 8L
  t_end <- tail(grDevices::xy.coords(y_ts)$x, 1L)
  dt <- 1 / stats::frequency(y_ts)
  xlim_fore <- c(forecast_window_start, t_end + k_fore * dt)
  xlim_synth_obs <- c(synth_window_start, t_end)

  if (need_ex1_quants_models) {
    fc95 <- forecast_from_fit(
      start.t = length(y), k = k_fore, m1 = M95_plot,
      fFF = fFF, fGG = fGG, plot = FALSE, y_data = y_ts,
      return.draws = TRUE, n.samp = synth_source_draws, seed = seed_value + 195L
    )
    fc50 <- forecast_from_fit(
      start.t = length(y), k = k_fore, m1 = M50_dqlm_plot,
      fFF = fFF, fGG = fGG, plot = FALSE, y_data = y_ts,
      return.draws = TRUE, n.samp = synth_source_draws, seed = seed_value + 250L
    )
    fc05 <- forecast_from_fit(
      start.t = length(y), k = k_fore, m1 = M5_plot,
      fFF = fFF, fGG = fGG, plot = FALSE, y_data = y_ts,
      return.draws = TRUE, n.samp = synth_source_draws, seed = seed_value + 305L
    )
  }

  if (need_ex1_runtime) {
    capture_output_file("ex1_run_summary.txt", {
      cat(sprintf("profile=%s\n", selected_profile))
      cat(sprintf("quantile run settings: n.burn=%d, n.mcmc=%d\n", nburn, nmcmc))
      cat(sprintf("trace run settings: n.burn=%d, n.mcmc=%d, thin=%d, saved_for_plot=%d\n\n", nburn_trace, nmcmc_trace, thin_trace, length(thin_idx)))
      cat("M50_trace sigma summary:\n")
      print(summary(sigma_trace))
      cat("\nM50_trace sigma summary (thinned chain used in ex1mcmc.png):\n")
      print(summary(as.numeric(sigma_trace_thin)))
      cat("\nM50_trace gamma summary:\n")
      print(summary(gamma_trace))
      cat("\nM50_trace gamma summary (thinned chain used in ex1mcmc.png):\n")
      print(summary(as.numeric(gamma_trace_thin)))
      cat("\nM50_trace joint posterior summary:\n")
      print(data.frame(
        parameter = c("sigma", "gamma"),
        mean = c(mean(sigma_trace), mean(gamma_trace)),
        q025 = c(as.numeric(stats::quantile(sigma_trace, 0.025)),
                 as.numeric(stats::quantile(gamma_trace, 0.025))),
        median = c(stats::median(sigma_trace), stats::median(gamma_trace)),
        q975 = c(as.numeric(stats::quantile(sigma_trace, 0.975)),
                 as.numeric(stats::quantile(gamma_trace, 0.975)))
      ))
      cat("\nM50_dqlm gamma fixed:\n")
      print(if (length(M50_dqlm$samp.gamma)) unique(as.numeric(M50_dqlm$samp.gamma)) else 0)
      cat("\nBackend metadata (trace model):\n")
      print(M50_trace$backend)
      cat("\nRun times (seconds):\n")
      print(c(M95 = M95$run.time, M50_trace = M50_trace$run.time, M5 = M5$run.time, M50_dqlm = M50_dqlm$run.time))
    })
    register_artifact(
      artifact_id = "ex1_run_summary",
      artifact_type = "log",
      relative_path = "analysis/manuscript/outputs/logs/ex1_run_summary.txt",
      manuscript_target = "Example 1 textual outputs",
      status = "reproduced",
      notes = "Includes backend metadata and high-iteration trace diagnostics."
    )
  }

  if (need_ex1mcmc) {
    save_png_plot("ex1mcmc.png", {
      graphics::par(mfcol = c(2, 2))
      coda::traceplot(sigma_trace_thin, main = "sigma trace")
      coda::densplot(sigma_trace_thin, main = "sigma density")
      coda::traceplot(gamma_trace_thin, main = "gamma trace")
      coda::densplot(gamma_trace_thin, main = "gamma density")
    })
    register_artifact(
      artifact_id = "fig_ex1mcmc",
      artifact_type = "figure",
      relative_path = "analysis/manuscript/outputs/figures/ex1mcmc.png",
      manuscript_target = "fig:ex1mcmc",
      status = "reproduced",
      notes = sprintf("Trace and density plots for sigma and gamma from a dedicated higher-iteration free-sigma median MCMC run with thinning=%d.", thin_trace)
    )
  }

  if (need_ex1_synthesis) {
    ex1_synthesis <- load_or_fit_cache(sprintf("ex1_synthesis_v5_s3_plot_seed%s", seed_value), {
      syn_obs <- with_local_seed(seed_value + 111L, {
        exdqlm::quantileSynthesis(
          draws_list = list(M5, M50_dqlm, M95),
          p = c(0.05, 0.50, 0.95),
          T_expected = length(y),
          n_samp = synth_n_samp,
          seed = seed_value + 111L
        )
      })

      syn_future <- with_local_seed(seed_value + 333L, {
        exdqlm::quantileSynthesis(
          draws_list = list(fc05, fc50, fc95),
          p = c(0.05, 0.50, 0.95),
          T_expected = k_fore,
          n_samp = synth_n_samp,
          seed = seed_value + 333L
        )
      })

      list(
        syn_obs = syn_obs,
        syn_future = syn_future
      )
    }, note = sprintf("ex1_synthesis_v5_s3_plot_seed%s", seed_value))

    ex1_synthesis_bridge_check <- synthesis_forecast_origin_check(
      ex1_synthesis$syn_obs,
      ex1_synthesis$syn_future,
      y_ts
    )
    save_table_csv(
      ex1_synthesis_bridge_check,
      filename = "ex1_synthesis_bridge_check.csv",
      artifact_id = "tab_ex1_synthesis_bridge",
      manuscript_target = "support: Example 1 synthesis forecast-origin check",
      notes = "Checks that the forecast synthesis begins one Lake Huron time step after the observed-period synthesis endpoint; Figure 2(d) uses these endpoints for the visual interval bridge."
    )
  }

  if (need_ex1quants) {
    save_png_plot("ex1quants.png", {
      ts_xy <- grDevices::xy.coords(y_ts)
      idx_obs_synth <- time_window_to_index(y_ts, synth_window_start, t_end)
      idx_obs <- idx_obs_synth[1]:idx_obs_synth[2]
      x_obs_full <- ts_xy$x
      x_future <- seq(from = t_end, by = dt, length.out = k_fore + 1L)
      x_future_fore <- x_future[-1L]

      obs_q025_full <- ex1_synthesis$syn_obs$summary$q025
      obs_q975_full <- ex1_synthesis$syn_obs$summary$q975
      fut_q025 <- ex1_synthesis$syn_future$summary$q025
      fut_q975 <- ex1_synthesis$syn_future$summary$q975

      y_lim_obs_synth <- range(
        y[idx_obs],
        obs_q025_full[idx_obs], obs_q975_full[idx_obs],
        na.rm = TRUE
      )
      y_lim_zoom_synth <- range(
        y[time_window_to_index(y_ts, forecast_window_start, t_end)[1]:length(y)],
        obs_q025_full[time_window_to_index(y_ts, forecast_window_start, t_end)[1]:length(y)],
        obs_q975_full[time_window_to_index(y_ts, forecast_window_start, t_end)[1]:length(y)],
        fut_q025, fut_q975,
        na.rm = TRUE
      )

      graphics::par(mfrow = c(2, 2), mar = c(3.6, 4.1, 2.2, 1.2), oma = c(0, 0, 0.8, 0))

      exdqlm::exdqlmPlot(M95_plot, col = ex1_quant_cols$q95)
      exdqlm::exdqlmPlot(M50_dqlm_plot, add = TRUE, col = ex1_quant_cols$q50)
      exdqlm::exdqlmPlot(M5_plot, add = TRUE, col = ex1_quant_cols$q05)
      graphics::legend(
        "topright",
        lty = 1, col = c(ex1_quant_cols$q95, ex1_quant_cols$q50, ex1_quant_cols$q05),
        legend = c(expression("p"[0] == 0.95), expression("p"[0] == 0.50), expression("p"[0] == 0.05))
      )
      graphics::title(main = "(a) Dynamic quantiles", cex.main = 0.95)

      stats::plot.ts(y_ts, xlim = xlim_fore, ylim = c(575, 581), col = "dark grey", ylab = "quantile forecast")
      add_forecast_overlay(fc95, cols = c(ex1_quant_cols$q95, ex1_quant_cols$q95_future))
      add_forecast_overlay(fc50, cols = c(ex1_quant_cols$q50, ex1_quant_cols$q50_future))
      add_forecast_overlay(fc05, cols = c(ex1_quant_cols$q05, ex1_quant_cols$q05_future))
      graphics::title(main = "(b) Forecasted quantiles", cex.main = 0.95)

      plot(
        ex1_synthesis$syn_obs,
        y = y_ts,
        time = x_obs_full,
        xlim = xlim_synth_obs,
        ylim = y_lim_obs_synth,
        show.median = FALSE,
        band.col = synth_obs_col,
        y.col = grDevices::adjustcolor("grey30", alpha.f = 0.62),
        ylab = "predictive synthesis",
        main = "(c) Observed-period synthesis"
      )
      graphics::legend(
        "bottomleft",
        legend = c("Synthesized posterior predictive interval (95%)"),
        fill = c(synth_obs_col),
        border = c(NA),
        lty = c(NA),
        lwd = c(NA),
        col = c(NA),
        bty = "n",
        bg = grDevices::adjustcolor("white", alpha.f = 0.82),
        cex = 0.68,
        y.intersp = 0.82,
        x.intersp = 0.9,
        inset = c(0.015, 0.015)
      )

      plot(
        ex1_synthesis$syn_obs,
        y = y_ts,
        time = x_obs_full,
        xlim = xlim_fore,
        ylim = y_lim_zoom_synth,
        show.median = FALSE,
        band.col = synth_obs_col,
        y.col = grDevices::adjustcolor("grey30", alpha.f = 0.62),
        ylab = "predictive synthesis",
        main = "(d) Forecast synthesis"
      )
      add_synthesis_forecast_bridge(
        ex1_synthesis_bridge_check,
        band.col = synth_fore_col
      )
      plot(
        ex1_synthesis$syn_future,
        time = x_future_fore,
        add = TRUE,
        show.median = FALSE,
        band.col = synth_fore_col
      )
      graphics::abline(v = t_end, lty = 3, col = "grey45")
      graphics::legend(
        "topright",
        legend = c("Observed-period synthesis (95%)", "Forecast synthesis (95%)"),
        fill = c(synth_obs_col, synth_fore_col),
        border = c(NA, NA),
        lty = c(NA, NA),
        lwd = c(NA, NA),
        col = c(NA, NA),
        bty = "o",
        bg = grDevices::adjustcolor("white", alpha.f = 0.86),
        box.lty = 0,
        cex = 0.66,
        y.intersp = 0.82,
        x.intersp = 0.9,
        inset = c(0.015, 0.025)
      )
    })
    register_artifact(
      artifact_id = "fig_ex1quants",
      artifact_type = "figure",
      relative_path = "analysis/manuscript/outputs/figures/ex1quants.png",
      manuscript_target = "fig:ex1quants",
      status = "reproduced",
      notes = "Four-panel Lake Huron figure with quantile estimates/forecasts on the top row and predictive synthesis over the observed and forecast windows on the bottom row. Panel (d) uses a darker forecast synthesis band and bridges the observed synthesis endpoint to the first forecast synthesis endpoint for visual continuity on the annual time scale."
    )
  }

  if (need_ex1synth) {
    capture_output_file("ex1_synthesis_summary.txt", {
      cat(sprintf("profile=%s\n", selected_profile))
      cat(sprintf("source_draws=%d | synthesized_draws=%d\n", synth_source_draws, synth_n_samp))
      cat(sprintf("window_start=%s | forecast_horizon=%d\n\n", format(synth_window_start), k_fore))
      cat("Forecast-origin synthesis alignment:\n")
      print(ex1_synthesis_bridge_check)
      cat("\n")
      cat("Observed-period synthesis summary:\n")
      print(summary(ex1_synthesis$syn_obs$summary$q500))
      cat("\nForecast-period synthesis summary:\n")
      print(summary(ex1_synthesis$syn_future$summary$q500))
    })
    register_artifact(
      artifact_id = "log_ex1_synthesis_summary",
      artifact_type = "log",
      relative_path = "analysis/manuscript/outputs/logs/ex1_synthesis_summary.txt",
      manuscript_target = "support: Example 1 synthesis summary",
      status = "reproduced",
      notes = "Synthesis settings and compact summaries for the Lake Huron predictive synthesis figure."
    )

    save_png_plot("ex1synth.png", {
      ts_xy <- grDevices::xy.coords(y_ts)
      idx_window <- time_window_to_index(y_ts, synth_window_start, t_end)
      idx_obs <- idx_window[1]:idx_window[2]
      x_obs_full <- ts_xy$x
      x_future <- seq(from = t_end, by = dt, length.out = k_fore + 1L)
      x_future_fore <- x_future[-1L]

      obs_q025_full <- ex1_synthesis$syn_obs$summary$q025
      obs_q975_full <- ex1_synthesis$syn_obs$summary$q975

      fut_q025 <- ex1_synthesis$syn_future$summary$q025
      fut_q975 <- ex1_synthesis$syn_future$summary$q975

      y_lim <- range(
        y[idx_obs],
        obs_q025_full[idx_obs], obs_q975_full[idx_obs],
        fut_q025, fut_q975,
        na.rm = TRUE
      )

      plot(
        ex1_synthesis$syn_obs,
        y = y_ts,
        time = x_obs_full,
        xlim = xlim_fore,
        ylim = y_lim,
        show.median = FALSE,
        band.col = synth_obs_col,
        y.col = grDevices::adjustcolor("grey30", alpha.f = 0.62),
        ylab = "predictive synthesis"
      )
      add_synthesis_forecast_bridge(
        ex1_synthesis_bridge_check,
        band.col = synth_fore_col
      )
      plot(
        ex1_synthesis$syn_future,
        time = x_future_fore,
        add = TRUE,
        show.median = FALSE,
        band.col = synth_fore_col
      )
      graphics::abline(v = t_end, lty = 3, col = "grey45")

      graphics::legend(
        "topright",
        legend = c("Observed-period synthesis (95%)", "Forecast synthesis (95%)"),
        fill = c(synth_obs_col, synth_fore_col),
        border = c(NA, NA),
        lty = c(NA, NA),
        lwd = c(NA, NA),
        col = c(NA, NA),
        bty = "o",
        bg = grDevices::adjustcolor("white", alpha.f = 0.86),
        box.lty = 0,
        cex = 0.66,
        y.intersp = 0.82,
        x.intersp = 0.9,
        inset = c(0.015, 0.025)
      )
    })
    register_artifact(
      artifact_id = "fig_ex1synth",
      artifact_type = "figure",
      relative_path = "analysis/manuscript/outputs/figures/ex1synth.png",
      manuscript_target = "support: Example 1 standalone synthesis figure",
      status = "reproduced",
      notes = "Standalone support figure for Lake Huron predictive synthesis combining the 0.05, 0.50, and 0.95 fitted models over the observed period and the eight-step forecast horizon, with a darker forecast synthesis band and one-step visual bridge at the forecast origin."
    )
  }

  if (need_ex1kernel) {
    compact_kernel_fit <- function(fit, kernel, seed) {
      list(
        kernel = kernel,
        seed = as.integer(seed),
        run_time = as.numeric(fit$run.time),
        sigma = as.numeric(fit$samp.sigma),
        gamma = as.numeric(fit$samp.gamma),
        accept_total = as.numeric(fit$accept.rate),
        accept_burn = as.numeric(fit$accept.rate.burn),
        accept_keep = as.numeric(fit$accept.rate.keep),
        vb_init_method = fit$vb.init.method %||% NA_character_,
        backend = fit$backend,
        mh = list(
          proposal = fit$mh.diagnostics$proposal,
          scale_final = fit$mh.diagnostics$scale_final,
          slice_width = fit$mh.diagnostics$slice_width,
          slice_max_steps = fit$mh.diagnostics$slice_max_steps,
          laplace_refresh = fit$mh.diagnostics$laplace_refresh
        )
      )
    }

    safe_rhat <- function(x) {
      out <- tryCatch(
        coda::gelman.diag(x, autoburnin = FALSE)$psrf[1, "Point est."],
        error = function(e) NA_real_
      )
      as.numeric(out)
    }

    safe_ess <- function(x) {
      out <- tryCatch(coda::effectiveSize(x), error = function(e) NA_real_)
      out <- as.numeric(out)
      if (!length(out)) return(NA_real_)
      out[[1L]]
    }

    build_kernel_diag <- function(compact_fits) {
      sigma_list <- coda::mcmc.list(lapply(compact_fits, function(f) coda::as.mcmc(f$sigma)))
      gamma_list <- coda::mcmc.list(lapply(compact_fits, function(f) coda::as.mcmc(f$gamma)))

      chain_rows <- do.call(rbind, lapply(seq_along(compact_fits), function(i) {
        fit_i <- compact_fits[[i]]
        data.frame(
          kernel = fit_i$kernel,
          chain = i,
          seed = fit_i$seed,
          runtime_sec = fit_i$run_time,
          sigma_mean = mean(fit_i$sigma),
          sigma_q025 = as.numeric(stats::quantile(fit_i$sigma, 0.025)),
          sigma_q975 = as.numeric(stats::quantile(fit_i$sigma, 0.975)),
          gamma_mean = mean(fit_i$gamma),
          gamma_q025 = as.numeric(stats::quantile(fit_i$gamma, 0.025)),
          gamma_q975 = as.numeric(stats::quantile(fit_i$gamma, 0.975)),
          accept_total = fit_i$accept_total,
          accept_burn = fit_i$accept_burn,
          accept_keep = fit_i$accept_keep,
          vb_init_method = fit_i$vb_init_method,
          stringsAsFactors = FALSE
        )
      }))

      pooled_sigma <- unlist(lapply(compact_fits, `[[`, "sigma"), use.names = FALSE)
      pooled_gamma <- unlist(lapply(compact_fits, `[[`, "gamma"), use.names = FALSE)
      summary_row <- data.frame(
        kernel = compact_fits[[1L]]$kernel,
        n_chains = length(compact_fits),
        n_burn = nburn_kernel,
        n_mcmc = nmcmc_kernel,
        runtime_total_sec = sum(chain_rows$runtime_sec),
        runtime_mean_sec = mean(chain_rows$runtime_sec),
        sigma_mean = mean(pooled_sigma),
        sigma_q025 = as.numeric(stats::quantile(pooled_sigma, 0.025)),
        sigma_q975 = as.numeric(stats::quantile(pooled_sigma, 0.975)),
        gamma_mean = mean(pooled_gamma),
        gamma_q025 = as.numeric(stats::quantile(pooled_gamma, 0.025)),
        gamma_q975 = as.numeric(stats::quantile(pooled_gamma, 0.975)),
        sigma_rhat = safe_rhat(sigma_list),
        gamma_rhat = safe_rhat(gamma_list),
        sigma_ess = safe_ess(sigma_list),
        gamma_ess = safe_ess(gamma_list),
        chain_mean_sigma_sd = stats::sd(chain_rows$sigma_mean),
        chain_mean_gamma_sd = stats::sd(chain_rows$gamma_mean),
        accept_total_mean = mean(chain_rows$accept_total, na.rm = TRUE),
        accept_total_min = suppressWarnings(min(chain_rows$accept_total, na.rm = TRUE)),
        accept_total_max = suppressWarnings(max(chain_rows$accept_total, na.rm = TRUE)),
        vb_init_method = compact_fits[[1L]]$vb_init_method,
        stringsAsFactors = FALSE
      )
      if (!all(is.finite(chain_rows$accept_total))) {
        summary_row$accept_total_mean <- NA_real_
        summary_row$accept_total_min <- NA_real_
        summary_row$accept_total_max <- NA_real_
      }

      list(
        fits = compact_fits,
        sigma_list = sigma_list,
        gamma_list = gamma_list,
        chain_rows = chain_rows,
        summary_row = summary_row
      )
    }

    run_kernel_multichain <- function(kernel, seeds) {
      fits <- vector("list", length(seeds))
      for (i in seq_along(seeds)) {
        set.seed(seeds[[i]])
        fit_i <- exdqlm::exdqlmMCMC(
          y = y, p0 = 0.50, model = model,
          df = 0.9, dim.df = 2,
          PriorGamma = list(m_gam = 0, s_gam = 0.1, df_gam = 1),
          n.burn = nburn_kernel, n.mcmc = nmcmc_kernel,
          init.from.vb = TRUE,
          vb_init_controls = list(method = "ldvb", verbose = FALSE),
          mh.proposal = kernel,
          trace.diagnostics = FALSE,
          verbose = FALSE
        )
        fits[[i]] <- compact_kernel_fit(fit_i, kernel = kernel, seed = seeds[[i]])
      }
      build_kernel_diag(fits)
    }

    ex1_kernel <- load_or_fit_cache("ex1_kernel_compare_v3_free_sigma_longer", {
      slice_seeds <- seed_value + 1100L + seq_len(n_chains_kernel)
      laplace_seeds <- seed_value + 1200L + seq_len(n_chains_kernel)
      list(
        slice = run_kernel_multichain("slice", slice_seeds),
        laplace_rw = run_kernel_multichain("laplace_rw", laplace_seeds)
      )
    }, note = "ex1_kernel_compare_v3_free_sigma_longer")

    kernel_summary <- do.call(
      rbind,
      list(ex1_kernel$slice$summary_row, ex1_kernel$laplace_rw$summary_row)
    )
    kernel_chain_stability <- do.call(
      rbind,
      list(ex1_kernel$slice$chain_rows, ex1_kernel$laplace_rw$chain_rows)
    )

    speed_row <- merge(
      subset(kernel_summary, kernel == "slice")[, c("runtime_mean_sec", "runtime_total_sec")],
      subset(kernel_summary, kernel == "laplace_rw")[, c("runtime_mean_sec", "runtime_total_sec")],
      by = NULL,
      suffixes = c(".slice", ".laplace_rw")
    )
    kernel_compare_note <- sprintf(
      paste(
        "Lake Huron median kernel comparison: slice vs laplace_rw.",
        "Mean runtime ratio (laplace_rw / slice) = %0.3f.",
        "sigma Rhat: slice=%0.3f, laplace_rw=%0.3f.",
        "gamma Rhat: slice=%0.3f, laplace_rw=%0.3f.",
        "sigma ESS: slice=%0.1f, laplace_rw=%0.1f.",
        "gamma ESS: slice=%0.1f, laplace_rw=%0.1f."
      ),
      speed_row$runtime_mean_sec.laplace_rw / speed_row$runtime_mean_sec.slice,
      kernel_summary$sigma_rhat[kernel_summary$kernel == "slice"],
      kernel_summary$sigma_rhat[kernel_summary$kernel == "laplace_rw"],
      kernel_summary$gamma_rhat[kernel_summary$kernel == "slice"],
      kernel_summary$gamma_rhat[kernel_summary$kernel == "laplace_rw"],
      kernel_summary$sigma_ess[kernel_summary$kernel == "slice"],
      kernel_summary$sigma_ess[kernel_summary$kernel == "laplace_rw"],
      kernel_summary$gamma_ess[kernel_summary$kernel == "slice"],
      kernel_summary$gamma_ess[kernel_summary$kernel == "laplace_rw"]
    )

    capture_output_file("ex1_kernel_compare_summary.txt", {
      cat(sprintf("profile=%s\n", selected_profile))
      cat(sprintf("n.chains=%d, n.burn=%d, n.mcmc=%d, thin.plot=%d\n\n", n_chains_kernel, nburn_kernel, nmcmc_kernel, thin_kernel_plot))
      cat("Kernel summary:\n")
      print(kernel_summary)
      cat("\nPer-chain posterior stability summary:\n")
      print(kernel_chain_stability)
      cat("\nGelman diagnostics (sigma):\n")
      print(coda::gelman.diag(ex1_kernel$slice$sigma_list, autoburnin = FALSE))
      print(coda::gelman.diag(ex1_kernel$laplace_rw$sigma_list, autoburnin = FALSE))
      cat("\nGelman diagnostics (gamma):\n")
      print(coda::gelman.diag(ex1_kernel$slice$gamma_list, autoburnin = FALSE))
      print(coda::gelman.diag(ex1_kernel$laplace_rw$gamma_list, autoburnin = FALSE))
      cat("\nEffective sample sizes:\n")
      cat(sprintf("slice sigma=%0.2f gamma=%0.2f\n", ex1_kernel$slice$summary_row$sigma_ess, ex1_kernel$slice$summary_row$gamma_ess))
      cat(sprintf("laplace_rw sigma=%0.2f gamma=%0.2f\n", ex1_kernel$laplace_rw$summary_row$sigma_ess, ex1_kernel$laplace_rw$summary_row$gamma_ess))
      cat("\nNarrative note:\n")
      cat(kernel_compare_note, "\n")
    })
    register_artifact(
      artifact_id = "log_ex1_kernel_compare",
      artifact_type = "log",
      relative_path = "analysis/manuscript/outputs/logs/ex1_kernel_compare_summary.txt",
      manuscript_target = "support: Example 1 kernel comparison summary",
      status = "reproduced",
      notes = "Four-chain Lake Huron median comparison of slice and laplace_rw."
    )

    save_table_csv(
      kernel_summary,
      filename = "ex1_kernel_summary.csv",
      artifact_id = "tab_ex1_kernel_summary",
      manuscript_target = "support: Example 1 kernel summary",
      status = "reproduced",
      notes = "Pooled sigma/gamma posterior, runtime, Rhat, and ESS summaries for free-sigma slice and laplace_rw fits."
    )

    save_table_csv(
      kernel_chain_stability,
      filename = "ex1_kernel_chain_stability.csv",
      artifact_id = "tab_ex1_kernel_chain_stability",
      manuscript_target = "support: Example 1 kernel chain stability",
      status = "reproduced",
      notes = "Per-chain sigma/gamma posterior summaries, runtimes, and acceptance diagnostics."
    )

    save_png_plot("ex1_kernel_compare.png", {
      chain_cols <- c("#0072B2", "#D55E00", "#009E73", "#CC79A7")
      sigma_range <- range(
        unlist(lapply(c(ex1_kernel$slice$fits, ex1_kernel$laplace_rw$fits), `[[`, "sigma"), use.names = FALSE),
        finite = TRUE
      )
      gamma_range <- range(
        unlist(lapply(c(ex1_kernel$slice$fits, ex1_kernel$laplace_rw$fits), `[[`, "gamma"), use.names = FALSE),
        finite = TRUE
      )

      plot_kernel_traces <- function(diag_obj, param, ylab, ylim, main, subtitle = NULL) {
        iter <- seq_len(length(diag_obj$fits[[1L]][[param]]))
        trace_mat <- do.call(cbind, lapply(diag_obj$fits, `[[`, param))
        graphics::matplot(
          iter,
          trace_mat,
          type = "l",
          lty = 1,
          lwd = 1,
          col = chain_cols[seq_len(ncol(trace_mat))],
          xlab = "kept iteration",
          ylab = ylab,
          ylim = ylim,
          main = main,
          sub = subtitle
        )
        graphics::legend(
          "topright",
          legend = sprintf("chain %d", seq_len(ncol(trace_mat))),
          col = chain_cols[seq_len(ncol(trace_mat))],
          lty = 1,
          bty = "n", cex = 0.8
        )
      }

      graphics::par(mfrow = c(2, 2))
      plot_kernel_traces(
        ex1_kernel$slice,
        param = "sigma",
        ylab = expression(sigma),
        ylim = sigma_range,
        main = "slice: sigma traces",
        subtitle = sprintf("mean runtime %.2fs, Rhat %.3f, ESS %.1f",
                           ex1_kernel$slice$summary_row$runtime_mean_sec,
                           ex1_kernel$slice$summary_row$sigma_rhat,
                           ex1_kernel$slice$summary_row$sigma_ess)
      )
      plot_kernel_traces(
        ex1_kernel$laplace_rw,
        param = "sigma",
        ylab = expression(sigma),
        ylim = sigma_range,
        main = "laplace_rw: sigma traces",
        subtitle = sprintf("mean runtime %.2fs, Rhat %.3f, ESS %.1f, accept %.3f",
                           ex1_kernel$laplace_rw$summary_row$runtime_mean_sec,
                           ex1_kernel$laplace_rw$summary_row$sigma_rhat,
                           ex1_kernel$laplace_rw$summary_row$sigma_ess,
                           ex1_kernel$laplace_rw$summary_row$accept_total_mean)
      )
      plot_kernel_traces(
        ex1_kernel$slice,
        param = "gamma",
        ylab = expression(gamma),
        ylim = gamma_range,
        main = "slice: gamma traces",
        subtitle = sprintf("Rhat %.3f, ESS %.1f",
                           ex1_kernel$slice$summary_row$gamma_rhat,
                           ex1_kernel$slice$summary_row$gamma_ess)
      )
      plot_kernel_traces(
        ex1_kernel$laplace_rw,
        param = "gamma",
        ylab = expression(gamma),
        ylim = gamma_range,
        main = "laplace_rw: gamma traces",
        subtitle = sprintf("Rhat %.3f, ESS %.1f, accept %.3f",
                           ex1_kernel$laplace_rw$summary_row$gamma_rhat,
                           ex1_kernel$laplace_rw$summary_row$gamma_ess,
                           ex1_kernel$laplace_rw$summary_row$accept_total_mean)
      )
    })
    register_artifact(
      artifact_id = "fig_ex1_kernel_compare",
      artifact_type = "figure",
      relative_path = "analysis/manuscript/outputs/figures/ex1_kernel_compare.png",
      manuscript_target = "support: Example 1 slice vs laplace_rw kernel comparison",
      status = "reproduced",
      notes = "Four-chain Lake Huron median comparison with sigma and gamma trace overlays under free sigma."
    )

    register_note("ex1_kernel", kernel_compare_note)
  }

  if (need_ex1_runtime) {
    ex1_runtime <- data.frame(
      model = c("M95", "M50_trace", "M5", "M50_dqlm"),
      run_time_seconds = c(M95$run.time, M50_trace$run.time, M5$run.time, M50_dqlm$run.time)
    )
    save_table_csv(
      ex1_runtime,
      filename = "ex1_runtime_summary.csv",
      artifact_id = "tab_ex1_runtime",
      manuscript_target = "Example 1 runtime statements",
      status = "approximate",
      notes = "Runtimes vary by hardware/profile; trace run intentionally uses higher iterations."
    )

    register_note("ex1", "Lake Huron uses cached fits; ex1mcmc uses a dedicated high-iteration median MCMC chain, and runtime statements are profile-dependent (see ex1_run_summary).")
  }

  log_msg("Example 1 (Lake Huron): complete")
}
