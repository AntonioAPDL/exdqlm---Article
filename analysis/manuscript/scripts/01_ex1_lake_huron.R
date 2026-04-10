need_ex1 <- target_enabled("ex1", c("ex1mcmc", "ex1quants", "ex1kernel"))
if (!need_ex1) {
  log_msg("Example 1 (Lake Huron): skipped (target filter)")
} else {
  log_msg("Example 1 (Lake Huron): start")

  need_ex1mcmc <- target_enabled("ex1mcmc", "ex1")
  need_ex1quants <- target_enabled("ex1quants", "ex1")
  need_ex1kernel <- isTRUE(targeted_run) && target_enabled("ex1kernel")
  need_ex1_runtime <- need_ex1mcmc || need_ex1quants
  need_ex1_quants_models <- need_ex1quants || need_ex1_runtime
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

  if (!is.finite(n_chains_kernel) || n_chains_kernel < 2L) {
    stop("Example 1 kernel comparison requires n_chains_kernel >= 2.", call. = FALSE)
  }

  M95 <- NULL
  M50_dqlm <- NULL
  M5 <- NULL
  M50_trace <- NULL
  sigma_trace <- NULL
  gamma_trace <- NULL
  thin_idx <- integer(0)
  sigma_trace_thin <- NULL
  gamma_trace_thin <- NULL

  if (need_ex1_quants_models) {
    ex1_quants <- load_or_fit_cache("ex1_quants_models_v2_longer", {
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
    }, note = "ex1_quants_models_v2_longer")

    M95 <- ex1_quants$M95
    M50_dqlm <- ex1_quants$M50_dqlm
    M5 <- ex1_quants$M5
  }

  if (need_ex1_trace_model) {
    ex1_trace <- load_or_fit_cache("ex1_trace_model_v4_free_sigma_longer", {
      M50_trace <- exdqlm::exdqlmMCMC(
        y = y, p0 = 0.50, model = model,
        df = 0.9, dim.df = 2,
        PriorGamma = list(m_gam = 0, s_gam = 0.1, df_gam = 1),
        n.burn = nburn_trace, n.mcmc = nmcmc_trace,
        verbose = FALSE
      )
      list(M50_trace = M50_trace)
    }, note = "ex1_trace_model_v4_free_sigma_longer")

    M50_trace <- ex1_trace$M50_trace
    sigma_trace <- as.numeric(M50_trace$samp.sigma)
    gamma_trace <- as.numeric(M50_trace$samp.gamma)
    thin_idx <- seq.int(1L, length(sigma_trace), by = thin_trace)
    sigma_trace_thin <- coda::mcmc(sigma_trace[thin_idx], thin = thin_trace)
    gamma_trace_thin <- coda::mcmc(gamma_trace[thin_idx], thin = thin_trace)
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

    register_note("ex1", "Lake Huron uses cached fits; ex1mcmc uses a dedicated high-iteration median MCMC chain.")
  }

  log_msg("Example 1 (Lake Huron): complete")
}
