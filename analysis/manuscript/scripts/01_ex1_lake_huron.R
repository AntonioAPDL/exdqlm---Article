need_ex1 <- target_enabled("ex1", c("ex1mcmc", "ex1quants"))
if (!need_ex1) {
  log_msg("Example 1 (Lake Huron): skipped (target filter)")
} else {
  log_msg("Example 1 (Lake Huron): start")

  need_ex1mcmc <- target_enabled("ex1mcmc", "ex1")
  need_ex1quants <- target_enabled("ex1quants", "ex1")

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

  ex1_quants <- load_or_fit_cache("ex1_quants_models", {
    M95 <- exdqlm::exdqlmMCMC(
      y = y, p0 = 0.95, model = model,
      df = 0.9, dim.df = 2,
      fix.sigma = TRUE, sig.init = 0.07,
      PriorGamma = list(m_gam = -1, s_gam = 0.1, df_gam = 1),
      n.burn = nburn, n.mcmc = nmcmc,
      verbose = FALSE
    )
    M5 <- exdqlm::exdqlmMCMC(
      y = y, p0 = 0.05, model = model,
      df = 0.9, dim.df = 2,
      fix.sigma = TRUE, sig.init = 0.07,
      PriorGamma = list(m_gam = 1, s_gam = 0.1, df_gam = 1),
      n.burn = nburn, n.mcmc = nmcmc,
      verbose = FALSE
    )
    M50_dqlm <- exdqlm::exdqlmMCMC(
      y = y, p0 = 0.50, model = model,
      df = 0.9, dim.df = 2,
      fix.sigma = TRUE, sig.init = 0.4,
      gam.init = 0, fix.gamma = TRUE,
      n.burn = nburn, n.mcmc = nmcmc,
      verbose = FALSE
    )
    list(model = model, M95 = M95, M50_dqlm = M50_dqlm, M5 = M5)
  }, note = "ex1_quants_models")

  ex1_trace <- load_or_fit_cache("ex1_trace_model_v2", {
    M50_trace <- exdqlm::exdqlmMCMC(
      y = y, p0 = 0.50, model = model,
      df = 0.9, dim.df = 2,
      fix.sigma = TRUE, sig.init = 0.4,
      PriorGamma = list(m_gam = 0, s_gam = 0.1, df_gam = 1),
      n.burn = nburn_trace, n.mcmc = nmcmc_trace,
      verbose = FALSE
    )
    list(M50_trace = M50_trace)
  }, note = "ex1_trace_model_v2")

  M95 <- ex1_quants$M95
  M50_dqlm <- ex1_quants$M50_dqlm
  M5 <- ex1_quants$M5
  M50_trace <- ex1_trace$M50_trace

  gamma_trace <- as.numeric(M50_trace$samp.gamma)
  thin_idx <- seq.int(1L, length(gamma_trace), by = thin_trace)
  gamma_trace_thin <- coda::mcmc(gamma_trace[thin_idx], thin = thin_trace)

  capture_output_file("ex1_run_summary.txt", {
    cat(sprintf("profile=%s\n", selected_profile))
    cat(sprintf("quantile run settings: n.burn=%d, n.mcmc=%d\n", nburn, nmcmc))
    cat(sprintf("trace run settings: n.burn=%d, n.mcmc=%d, thin=%d, saved_for_plot=%d\n\n", nburn_trace, nmcmc_trace, thin_trace, length(thin_idx)))
    cat("M50_trace gamma summary:\n")
    print(summary(gamma_trace))
    cat("\nM50_trace gamma summary (thinned chain used in ex1mcmc.png):\n")
    print(summary(as.numeric(gamma_trace_thin)))
    cat("\nM50_dqlm gamma fixed:\n")
    print(unique(as.numeric(M50_dqlm$samp.gamma)))
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

  if (need_ex1mcmc) {
    save_png_plot("ex1mcmc.png", {
      graphics::par(mfcol = c(1, 2))
      coda::traceplot(gamma_trace_thin, main = "")
      coda::densplot(gamma_trace_thin, main = "")
    })
    register_artifact(
      artifact_id = "fig_ex1mcmc",
      artifact_type = "figure",
      relative_path = "analysis/manuscript/outputs/figures/ex1mcmc.png",
      manuscript_target = "fig:ex1mcmc",
      status = "reproduced",
      notes = sprintf("Trace and density plot using dedicated higher-iteration median MCMC run with thinning=%d.", thin_trace)
    )
  }

  if (need_ex1quants) {
    save_png_plot("ex1quants.png", {
      graphics::par(mfcol = c(1, 2))

      # Use time-aware copies so x-axis is labeled in years (not raw index).
      M95_plot <- M95
      M50_dqlm_plot <- M50_dqlm
      M5_plot <- M5
      M95_plot$y <- y_ts
      M50_dqlm_plot$y <- y_ts
      M5_plot$y <- y_ts

      exdqlm::exdqlmPlot(M95_plot)
      exdqlm::exdqlmPlot(M50_dqlm_plot, add = TRUE, col = "blue")
      exdqlm::exdqlmPlot(M5_plot, add = TRUE, col = "forestgreen")
      graphics::legend(
        "topright",
        lty = 1, col = c("purple", "blue", "forestgreen"),
        legend = c(expression("p"[0] == 0.95), expression("p"[0] == 0.50), expression("p"[0] == 0.05))
      )

      fFF <- model$FF
      fGG <- model$GG
      k_fore <- 8L
      t_end <- tail(grDevices::xy.coords(y_ts)$x, 1L)
      dt <- 1 / stats::frequency(y_ts)
      xlim_fore <- c(1952, t_end + k_fore * dt)
      stats::plot.ts(y_ts, xlim = xlim_fore, ylim = c(575, 581), col = "dark grey", ylab = "quantile forecast")

      fc95 <- exdqlm::exdqlmForecast(start.t = length(y), k = k_fore, m1 = M95_plot, fFF = fFF, fGG = fGG, plot = FALSE)
      plot(fc95, add = TRUE, cols = c("purple", "magenta"))
      fc50 <- exdqlm::exdqlmForecast(start.t = length(y), k = k_fore, m1 = M50_dqlm_plot, fFF = fFF, fGG = fGG, plot = FALSE)
      plot(fc50, add = TRUE, cols = c("blue", "lightblue"))
      fc05 <- exdqlm::exdqlmForecast(start.t = length(y), k = k_fore, m1 = M5_plot, fFF = fFF, fGG = fGG, plot = FALSE)
      plot(fc05, add = TRUE, cols = c("forestgreen", "green"))
    })
    register_artifact(
      artifact_id = "fig_ex1quants",
      artifact_type = "figure",
      relative_path = "analysis/manuscript/outputs/figures/ex1quants.png",
      manuscript_target = "fig:ex1quants",
      status = "reproduced",
      notes = "Two-panel quantile and forecast figure with index-window fix."
    )
  }

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

  register_note("ex1", "Lake Huron uses cached fits; ex1mcmc uses a dedicated high-iteration median MCMC chain.")

  log_msg("Example 1 (Lake Huron): complete")
}
