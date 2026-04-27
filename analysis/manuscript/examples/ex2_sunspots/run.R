need_ex2 <- target_enabled(
  "ex2",
  c(
    "ex2bench",
    "ex2quant", "ex2quant_ldvb",
    "ex2checks", "ex2checks_ldvb",
    "ex2_ldvb_diagnostics",
    "ex2tables", "ex2tables_ldvb"
  )
)
if (!need_ex2) {
  log_msg("Example 2 (Sunspots): skipped (target filter)")
} else {
  log_msg("Example 2 (Sunspots): start")

  need_ex2quant <- target_enabled("ex2quant", "ex2")
  need_ex2quant_ldvb <- target_enabled("ex2quant_ldvb", "ex2")
  need_ex2checks <- target_enabled("ex2checks", "ex2")
  need_ex2checks_ldvb <- target_enabled("ex2checks_ldvb", "ex2")
  need_ex2benchmark <- target_enabled("ex2bench", "ex2") || need_ex2checks
  need_ex2_ldvb_diag <- target_enabled("ex2_ldvb_diagnostics", "ex2")
  need_ex2_tables <- target_enabled("ex2tables", "ex2")
  need_ex2_tables_ldvb <- target_enabled("ex2tables_ldvb", "ex2")
  need_ex2_ldvb_core <- any(c(
    need_ex2quant, need_ex2quant_ldvb,
    need_ex2checks, need_ex2checks_ldvb,
    need_ex2_ldvb_diag, need_ex2_tables_ldvb
  ))

  y_ts <- datasets::sunspot.year
  y <- as.numeric(y_ts)
  diag_ref_samp <- seeded_rnorm(length(y_ts), seed_value + 201L)

  dlm_trend_comp <- dlm::dlmModPoly(1, m0 = mean(y), C0 = 10)
  trend_comp <- exdqlm::as.exdqlm(dlm_trend_comp)
  seas_comp <- exdqlm::seasMod(p = 11, h = 1:4, C0 = 10 * diag(8))
  model <- trend_comp + seas_comp

  capture_output_file("ex2_model_output.txt", {
    cat("Combined GG matrix:\n")
    print(model$GG)
  })
  register_artifact(
    artifact_id = "ex2_model_output",
    artifact_type = "log",
    relative_path = "analysis/manuscript/outputs/logs/ex2_model_output.txt",
    manuscript_target = "Example 2 model matrix output",
    status = "reproduced",
    notes = "Combined trend/seasonal state-space matrix."
  )

  n_samp <- as.integer(cfg_profile$ex2$n_samp)
  tol <- as.numeric(cfg_profile$ex2$tol)
  ldvb_diag_tol <- as.numeric(cfg_profile$ex2$ldvb_diag_tol %||% tol)
  ldvb_diag_n_samp <- as.integer(cfg_profile$ex2$ldvb_diag_n_samp %||% n_samp)
  benchmark_n_burn <- as.integer(cfg_profile$ex2$benchmark_n_burn %||% 1000L)
  benchmark_n_mcmc <- as.integer(cfg_profile$ex2$benchmark_n_mcmc %||% 300L)
  df_grid <- as.numeric(cfg_profile$ex2$df_grid)

  fit_ok <- function(x) !is.null(x) && !inherits(x, "error")
  M_sigma_ldvb <- M1_ldvb <- M2_ldvb <- NULL

  if (need_ex2_ldvb_core) {
    ex2_core_ldvb <- load_or_fit_cache(
      sprintf("ex2_core_models_ldvb_nsamp%d_tol%s_v3", n_samp, format(tol)),
      {
      M_sigma_ldvb <- tryCatch(
        exdqlm::exdqlmLDVB(
          y = y_ts, p0 = 0.85, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          dqlm.ind = TRUE, fix.sigma = FALSE,
          n.samp = n_samp, tol = tol,
          verbose = FALSE
        ),
        error = function(e) e
      )

      M1_ldvb <- tryCatch(
        exdqlm::exdqlmLDVB(
          y = y_ts, p0 = 0.85, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          dqlm.ind = TRUE, sig.init = 2, fix.sigma = FALSE,
          n.samp = n_samp, tol = tol,
          verbose = FALSE
        ),
        error = function(e) e
      )

      M2_ldvb <- tryCatch(
        exdqlm::exdqlmLDVB(
          y = y_ts, p0 = 0.85, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          sig.init = 2, fix.sigma = FALSE,
          n.samp = n_samp, tol = tol,
          verbose = FALSE
        ),
        error = function(e) e
      )

      list(M_sigma_ldvb = M_sigma_ldvb, M1_ldvb = M1_ldvb, M2_ldvb = M2_ldvb)
    }, note = sprintf("ex2_core_models_ldvb_nsamp%d_tol%s_v3", n_samp, format(tol)))
    M_sigma_ldvb <- ex2_core_ldvb$M_sigma_ldvb
    M1_ldvb <- ex2_core_ldvb$M1_ldvb
    M2_ldvb <- ex2_core_ldvb$M2_ldvb
  }

  ex2_ldvb_pair_ok <- fit_ok(M1_ldvb) && fit_ok(M2_ldvb)

  capture_output_file("ex2_run_summary.txt", {
    cat(sprintf("profile=%s\n", selected_profile))
    cat(sprintf("n.samp=%d, tol=%s\n\n", n_samp, format(tol)))
    if (fit_ok(M_sigma_ldvb)) {
      cat("Summary(M_sigma_ldvb$samp.sigma):\n")
      print(summary(M_sigma_ldvb$samp.sigma))
    }
    cat("\nRuntime seconds:\n")
    rt <- c()
    if (fit_ok(M_sigma_ldvb)) rt <- c(rt, M_sigma_ldvb = M_sigma_ldvb$run.time)
    if (fit_ok(M1_ldvb)) rt <- c(rt, M1_ldvb = M1_ldvb$run.time)
    if (fit_ok(M2_ldvb)) rt <- c(rt, M2_ldvb = M2_ldvb$run.time)
    print(rt)
    if (!fit_ok(M_sigma_ldvb)) {
      cat("\nLDVB status M_sigma: failed\n")
      cat(M_sigma_ldvb$message, "\n")
    }
    if (!fit_ok(M1_ldvb)) {
      cat("\nLDVB status M1: failed\n")
      cat(M1_ldvb$message, "\n")
    }
    if (fit_ok(M2_ldvb)) {
      cat("\nLDVB status: success\n")
      cat("Summary(M2_ldvb$samp.gamma):\n")
      print(summary(M2_ldvb$samp.gamma))
    } else {
      cat("\nLDVB status M2: failed\n")
      cat(M2_ldvb$message, "\n")
    }
  })
  register_artifact(
    artifact_id = "ex2_run_summary",
    artifact_type = "log",
    relative_path = "analysis/manuscript/outputs/logs/ex2_run_summary.txt",
    manuscript_target = "Example 2 textual outputs",
    status = if (fit_ok(M_sigma_ldvb) && fit_ok(M1_ldvb) && fit_ok(M2_ldvb)) "reproduced" else "approximate",
    notes = "Includes sigma summary and LDVB runtime diagnostics for the manuscript Example 2 workflow."
  )

  if (need_ex2benchmark && ex2_ldvb_pair_ok) {
    benchmark_cache_key <- sprintf(
      "ex2_dynamic_benchmark_%s_nsamp%d_b%d_k%d_v3",
      selected_benchmark_profile,
      n_samp,
      benchmark_n_burn,
      benchmark_n_mcmc
    )
    ex2_benchmark <- load_or_fit_cache(benchmark_cache_key, {
      M1_mcmc <- with_backend_profile(selected_benchmark_profile, {
        exdqlm::exdqlmMCMC(
          y = y_ts, p0 = 0.85, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          dqlm.ind = TRUE, fix.sigma = FALSE,
          n.burn = benchmark_n_burn, n.mcmc = benchmark_n_mcmc,
          verbose = FALSE
        )
      })

      M2_mcmc <- with_backend_profile(selected_benchmark_profile, {
        exdqlm::exdqlmMCMC(
          y = y_ts, p0 = 0.85, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          fix.sigma = FALSE,
          n.burn = benchmark_n_burn, n.mcmc = benchmark_n_mcmc,
          verbose = FALSE
        )
      })

      diag_vb <- diagnostics_from_fit(M1_ldvb, M2_ldvb, plot = FALSE, ref = diag_ref_samp, y_data = y)
      diag_mcmc <- diagnostics_from_fit(M1_mcmc, M2_mcmc, plot = FALSE, ref = diag_ref_samp, y_data = y)

      list(
        M1_mcmc = M1_mcmc,
        M2_mcmc = M2_mcmc,
        diag_vb = diag_vb,
        diag_mcmc = diag_mcmc
      )
    }, note = benchmark_cache_key)

    capture_output_file("ex2_benchmark_run_summary.txt", {
      cat(sprintf("profile=%s\n", selected_profile))
      cat(sprintf("backend_profile=%s\n", selected_benchmark_profile))
      cat(sprintf("vb_n.samp=%d, benchmark_n.burn=%d, benchmark_n.mcmc=%d\n\n", n_samp, benchmark_n_burn, benchmark_n_mcmc))
      cat("VB benchmark diagnostics:\n")
      print(data.frame(
        model = c("DQLM", "exDQLM"),
        runtime_sec = c(ex2_benchmark$diag_vb$m1.rt, ex2_benchmark$diag_vb$m2.rt),
        KL = c(ex2_benchmark$diag_vb$m1.KL, ex2_benchmark$diag_vb$m2.KL),
        CRPS = c(ex2_benchmark$diag_vb$m1.CRPS, ex2_benchmark$diag_vb$m2.CRPS),
        pplc = c(ex2_benchmark$diag_vb$m1.pplc, ex2_benchmark$diag_vb$m2.pplc)
      ))
      cat("\nMCMC benchmark diagnostics:\n")
      print(data.frame(
        model = c("DQLM", "exDQLM"),
        runtime_sec = c(ex2_benchmark$diag_mcmc$m1.rt, ex2_benchmark$diag_mcmc$m2.rt),
        KL = c(ex2_benchmark$diag_mcmc$m1.KL, ex2_benchmark$diag_mcmc$m2.KL),
        CRPS = c(ex2_benchmark$diag_mcmc$m1.CRPS, ex2_benchmark$diag_mcmc$m2.CRPS),
        pplc = c(ex2_benchmark$diag_mcmc$m1.pplc, ex2_benchmark$diag_mcmc$m2.pplc)
      ))
      cat("\nMCMC backend metadata:\n")
      print(ex2_benchmark$M2_mcmc$backend)
    })
    register_artifact(
      artifact_id = "log_ex2_benchmark_run_summary",
      artifact_type = "log",
      relative_path = "analysis/manuscript/outputs/logs/ex2_benchmark_run_summary.txt",
      manuscript_target = "support: Example 2 dynamic benchmark summary",
      status = "reproduced",
      notes = "Runtime and diagnostics summary for the dynamic VB versus MCMC benchmark under the disclosed backend profile."
    )

    ex2_benchmark_table <- data.frame(
      model = c("DQLM", "exDQLM", "DQLM", "exDQLM"),
      method = c("VB", "VB", "MCMC", "MCMC"),
      runtime_sec = c(
        ex2_benchmark$diag_vb$m1.rt,
        ex2_benchmark$diag_vb$m2.rt,
        ex2_benchmark$diag_mcmc$m1.rt,
        ex2_benchmark$diag_mcmc$m2.rt
      ),
      KL = c(
        ex2_benchmark$diag_vb$m1.KL,
        ex2_benchmark$diag_vb$m2.KL,
        ex2_benchmark$diag_mcmc$m1.KL,
        ex2_benchmark$diag_mcmc$m2.KL
      ),
      CRPS = c(
        ex2_benchmark$diag_vb$m1.CRPS,
        ex2_benchmark$diag_vb$m2.CRPS,
        ex2_benchmark$diag_mcmc$m1.CRPS,
        ex2_benchmark$diag_mcmc$m2.CRPS
      ),
      pplc = c(
        ex2_benchmark$diag_vb$m1.pplc,
        ex2_benchmark$diag_vb$m2.pplc,
        ex2_benchmark$diag_mcmc$m1.pplc,
        ex2_benchmark$diag_mcmc$m2.pplc
      ),
      backend_profile = rep(selected_benchmark_profile, 4),
      posterior_draws = rep(n_samp, 4),
      burn_in = c(NA_integer_, NA_integer_, benchmark_n_burn, benchmark_n_burn),
      n_burn = rep(benchmark_n_burn, 4),
      n_mcmc = rep(benchmark_n_mcmc, 4),
      stringsAsFactors = FALSE
    )
    save_table_csv(
      ex2_benchmark_table,
      filename = "ex2_dynamic_benchmark.csv",
      artifact_id = "tab_ex2_dynamic_benchmark",
      manuscript_target = "tab:ex2bench",
      status = "reproduced",
      notes = sprintf(
        "Representative dynamic VB versus MCMC benchmark for Example 2 under backend Profile %s.",
        selected_benchmark_profile
      )
    )
  } else if (need_ex2benchmark) {
    register_artifact(
      artifact_id = "tab_ex2_dynamic_benchmark",
      artifact_type = "table",
      relative_path = "analysis/manuscript/outputs/tables/ex2_dynamic_benchmark.csv",
      manuscript_target = "tab:ex2bench",
      status = "not_reproduced",
      notes = "Missing LDVB fits required to seed the Example 2 dynamic benchmark."
    )
  }

  xlim_idx <- time_window_to_index(y_ts, 1750, 1850)
  xlim_time <- c(1750, 1850)
  ex2_cols <- list(
    dqlm = "#C44E52",
    exdqlm = "#4C72B0",
    obs = "#6F6F6F",
    hist_fill = grDevices::adjustcolor("#4C72B0", alpha.f = 0.22),
    hist_border = "#4C72B0"
  )

  if (need_ex2quant || need_ex2quant_ldvb) {
    plot_quant_triplet_ldvb <- function(filename, m_dqlm, m_exdqlm, p0_label) {
      m_dqlm_plot <- m_dqlm
      m_exdqlm_plot <- m_exdqlm
      m_dqlm_plot$y <- y_ts
      m_exdqlm_plot$y <- y_ts
      save_png_plot(filename, {
        graphics::layout(matrix(c(1, 1, 2, 3), nrow = 2, byrow = TRUE), heights = c(0.9, 1.1))
        graphics::par(mar = c(3.1, 4.1, 2.6, 1.2) + 0.1)
        stats::plot.ts(y_ts, col = ex2_cols$obs, ylab = "sunspot count", xlab = "year")
        graphics::title(main = "Sunspot time series")

        graphics::par(mar = c(3.6, 4.1, 2.6, 1.2) + 0.1)
        stats::plot.ts(y_ts, xlim = xlim_time, col = ex2_cols$obs, ylab = "quantile and 95% CrI", xlab = "year")
        q_d <- quantile_summary_from_fit(m_dqlm_plot, cr.percent = 0.95)
        q_e <- quantile_summary_from_fit(m_exdqlm_plot, cr.percent = 0.95)
        plot_quantile_summary(q_d, col = ex2_cols$dqlm, add = TRUE)
        plot_quantile_summary(q_e, col = ex2_cols$exdqlm, add = TRUE)
        graphics::legend(
          "topleft",
          legend = c("DQLM", "exDQLM"),
          col = c(ex2_cols$dqlm, ex2_cols$exdqlm),
          lty = 1,
          lwd = c(1.5, 1.5),
          bty = "n"
        )
        graphics::title(main = sprintf("LDVB fit for p0 = %s", p0_label))

        graphics::par(mar = c(3.6, 4.1, 2.6, 1.2) + 0.1)
        graphics::hist(
          as.numeric(m_exdqlm_plot$samp.gamma),
          xlab = expression(gamma),
          main = sprintf("exDQLM posterior draws of gamma (p0 = %s)", p0_label),
          col = ex2_cols$hist_fill,
          border = ex2_cols$hist_border
        )
        graphics::abline(v = stats::median(as.numeric(m_exdqlm_plot$samp.gamma), na.rm = TRUE), col = ex2_cols$exdqlm, lwd = 2)
      }, height = 7)
    }

    if (ex2_ldvb_pair_ok && need_ex2quant) {
      plot_quant_triplet_ldvb("ex2quant.png", M1_ldvb, M2_ldvb, "0.85")
      register_artifact(
        artifact_id = "fig_ex2quant",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex2quant.png",
        manuscript_target = "fig:ex2quant",
        status = "reproduced",
        notes = "Composite Sunspots figure with full-series panel, quantile-comparison panel, and gamma histogram."
      )
    } else if (need_ex2quant) {
      register_artifact(
        artifact_id = "fig_ex2quant",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex2quant.png",
        manuscript_target = "fig:ex2quant",
        status = "not_reproduced",
        notes = "Missing LDVB DQLM/exDQLM fits required for the primary Example 2 quantile panel."
      )
    }

    if (ex2_ldvb_pair_ok && need_ex2quant_ldvb) {
      plot_quant_triplet_ldvb("ex2quant_ldvb.png", M1_ldvb, M2_ldvb, "0.85")
      register_artifact(
        artifact_id = "fig_ex2quant_ldvb",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex2quant_ldvb.png",
        manuscript_target = "new: fig ex2quant LDVB counterpart",
        status = "reproduced",
        notes = "Composite Sunspots figure with full-series panel, quantile-comparison panel, and gamma histogram."
      )
    } else {
      register_artifact(
        artifact_id = "fig_ex2quant_ldvb",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex2quant_ldvb.png",
        manuscript_target = "new: fig ex2quant LDVB counterpart",
        status = "not_reproduced",
        notes = "Missing LDVB DQLM/exDQLM fits required for p0=0.85 quantile panel."
      )
    }

    if (need_ex2quant_ldvb) {
      ex2_extreme_ldvb <- load_or_fit_cache(
        sprintf("ex2_quant_grid_ldvb_nsamp%d_tol%s_v3", n_samp, format(tol)),
        {
        M99_dqlm_ldvb <- tryCatch(
          exdqlm::exdqlmLDVB(
            y = y_ts, p0 = 0.99, model = model,
            df = c(0.9, 0.85), dim.df = c(1, 8),
            # Stabilize extreme upper-tail DQLM fit under LDVB.
            dqlm.ind = TRUE, sig.init = 10, fix.sigma = FALSE,
            n.samp = n_samp, tol = tol,
            verbose = FALSE
          ),
          error = function(e) e
        )
        M99_exdqlm_ldvb <- tryCatch(
        exdqlm::exdqlmLDVB(
          y = y_ts, p0 = 0.99, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          sig.init = 2, fix.sigma = FALSE,
          n.samp = n_samp, tol = tol,
          verbose = FALSE
        ),
          error = function(e) e
        )
        M05_dqlm_ldvb <- tryCatch(
        exdqlm::exdqlmLDVB(
          y = y_ts, p0 = 0.05, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          dqlm.ind = TRUE, sig.init = 2, fix.sigma = FALSE,
          n.samp = n_samp, tol = tol,
          verbose = FALSE
        ),
          error = function(e) e
        )
        M05_exdqlm_ldvb <- tryCatch(
        exdqlm::exdqlmLDVB(
          y = y_ts, p0 = 0.05, model = model,
          df = c(0.9, 0.85), dim.df = c(1, 8),
          sig.init = 2, fix.sigma = FALSE,
          n.samp = n_samp, tol = tol,
          verbose = FALSE
        ),
          error = function(e) e
        )
        list(
          M99_dqlm_ldvb = M99_dqlm_ldvb, M99_exdqlm_ldvb = M99_exdqlm_ldvb,
          M05_dqlm_ldvb = M05_dqlm_ldvb, M05_exdqlm_ldvb = M05_exdqlm_ldvb
        )
      }, note = sprintf("ex2_quant_grid_ldvb_nsamp%d_tol%s_v3", n_samp, format(tol)))

      ldvb_p099_ok <- fit_ok(ex2_extreme_ldvb$M99_dqlm_ldvb) && fit_ok(ex2_extreme_ldvb$M99_exdqlm_ldvb)
      ldvb_p005_ok <- fit_ok(ex2_extreme_ldvb$M05_dqlm_ldvb) && fit_ok(ex2_extreme_ldvb$M05_exdqlm_ldvb)

      if (ldvb_p099_ok) {
        plot_quant_triplet_ldvb("ex2quant_ldvb_p099.png", ex2_extreme_ldvb$M99_dqlm_ldvb, ex2_extreme_ldvb$M99_exdqlm_ldvb, "0.99")
        register_artifact(
          artifact_id = "fig_ex2quant_ldvb_p099",
          artifact_type = "figure",
          relative_path = "analysis/manuscript/outputs/figures/ex2quant_ldvb_p099.png",
          manuscript_target = "new: fig ex2quant LDVB upper-tail (p0=0.99)",
          status = "reproduced",
          notes = "Three-panel LDVB figure for p0=0.99 comparing DQLM and exDQLM."
        )
      } else {
        register_artifact(
          artifact_id = "fig_ex2quant_ldvb_p099",
          artifact_type = "figure",
          relative_path = "analysis/manuscript/outputs/figures/ex2quant_ldvb_p099.png",
          manuscript_target = "new: fig ex2quant LDVB upper-tail (p0=0.99)",
          status = "not_reproduced",
          notes = "Missing LDVB DQLM/exDQLM fits required for p0=0.99 quantile panel."
        )
      }

      if (ldvb_p005_ok) {
        plot_quant_triplet_ldvb("ex2quant_ldvb_p005.png", ex2_extreme_ldvb$M05_dqlm_ldvb, ex2_extreme_ldvb$M05_exdqlm_ldvb, "0.05")
        register_artifact(
          artifact_id = "fig_ex2quant_ldvb_p005",
          artifact_type = "figure",
          relative_path = "analysis/manuscript/outputs/figures/ex2quant_ldvb_p005.png",
          manuscript_target = "new: fig ex2quant LDVB lower-tail (p0=0.05)",
          status = "reproduced",
          notes = "Three-panel LDVB figure for p0=0.05 comparing DQLM and exDQLM."
        )
      } else {
        register_artifact(
          artifact_id = "fig_ex2quant_ldvb_p005",
          artifact_type = "figure",
          relative_path = "analysis/manuscript/outputs/figures/ex2quant_ldvb_p005.png",
          manuscript_target = "new: fig ex2quant LDVB lower-tail (p0=0.05)",
          status = "not_reproduced",
          notes = "Missing LDVB DQLM/exDQLM fits required for p0=0.05 quantile panel."
        )
      }
    }
  }

  if (need_ex2checks) {
    if (ex2_ldvb_pair_ok) {
      save_png_plot("ex2checks.png", {
        graphics::par(mfrow = c(2, 3))
        diagnostics_from_fit(M1_ldvb, M2_ldvb, plot = TRUE, cols = c(ex2_cols$dqlm, ex2_cols$exdqlm), ref = diag_ref_samp, y_data = y)
      })
      register_artifact(
        artifact_id = "fig_ex2checks",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex2checks.png",
        manuscript_target = "fig:ex2checks",
        status = "reproduced",
        notes = "Primary Example 2 diagnostics figure generated from the LDVB fits."
      )
    } else {
      register_artifact(
        artifact_id = "fig_ex2checks",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex2checks.png",
        manuscript_target = "fig:ex2checks",
        status = "not_reproduced",
        notes = "Missing LDVB DQLM/exDQLM fits required for the primary diagnostics panel."
      )
    }
  }

  if (need_ex2checks_ldvb) {
    if (ex2_ldvb_pair_ok) {
      save_png_plot("ex2checks_ldvb.png", {
        graphics::par(mfrow = c(2, 3))
        diagnostics_from_fit(M1_ldvb, plot = TRUE, cols = c(ldvb_cols$m1, ldvb_cols$m1), ref = diag_ref_samp, y_data = y)
        diagnostics_from_fit(M2_ldvb, plot = TRUE, cols = c(ldvb_cols$m2, ldvb_cols$m2), ref = diag_ref_samp, y_data = y)
      })
      register_artifact(
        artifact_id = "fig_ex2checks_ldvb",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex2checks_ldvb.png",
        manuscript_target = "new: fig ex2checks LDVB counterpart",
        status = "reproduced",
        notes = "LDVB counterpart of ex2checks using exdqlmDiagnostics."
      )
    } else {
      register_artifact(
        artifact_id = "fig_ex2checks_ldvb",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex2checks_ldvb.png",
        manuscript_target = "new: fig ex2checks LDVB counterpart",
        status = "not_reproduced",
        notes = "Missing LDVB DQLM/exDQLM fits required for diagnostics panel."
      )
    }
  }

  if (need_ex2_ldvb_diag) {
    ldvb_diag <- load_or_fit_cache(
      sprintf("ex2_ldvb_diagnostics_fit_nsamp%d_tol%s_v3", ldvb_diag_n_samp, format(ldvb_diag_tol)),
      {
      exdqlm::exdqlmLDVB(
        y = y_ts, p0 = 0.85, model = model,
        df = c(0.9, 0.85), dim.df = c(1, 8),
        sig.init = 2, fix.sigma = FALSE,
        n.samp = ldvb_diag_n_samp, tol = ldvb_diag_tol,
        verbose = FALSE
      )
    }, note = sprintf("ex2_ldvb_diagnostics_fit_nsamp%d_tol%s_v3", ldvb_diag_n_samp, format(ldvb_diag_tol)))
    seq_g <- as.numeric(ldvb_diag$seq.gamma)
    seq_s <- as.numeric(ldvb_diag$seq.sigma)
    el <- as.numeric(ldvb_diag$diagnostics$elbo)

    if (fit_ok(M1_ldvb)) {
      save_png_plot("ex2_ldvb_diagnostics.png", {
        graphics::par(mfrow = c(2, 2))

        stats::plot.ts(y, xlim = xlim_idx, col = "grey70", ylab = "quantile 95% CrIs")
        q_dqlm_ld <- quantile_summary_from_fit(M1_ldvb, cr.percent = 0.95)
        q_exdqlm_ld <- quantile_summary_from_fit(ldvb_diag, cr.percent = 0.95)
        plot_quantile_summary(q_dqlm_ld, col = ex2_cols$dqlm, add = TRUE)
        plot_quantile_summary(q_exdqlm_ld, col = ex2_cols$exdqlm, add = TRUE)
        graphics::legend(
          "topleft",
          legend = c("DQLM LDVB", "exDQLM LDVB"),
          col = c(ex2_cols$dqlm, ex2_cols$exdqlm),
          lty = 1,
          bty = "n"
        )

        graphics::plot(seq_along(seq_g), seq_g, type = "o", pch = 16, cex = 0.45, col = "darkorange", xlab = "Iteration", ylab = expression(seq(gamma)))
        graphics::plot(seq_along(seq_s), seq_s, type = "o", pch = 16, cex = 0.45, col = "darkorange", xlab = "Iteration", ylab = expression(seq(sigma)))

        if (length(el) > 1L && all(is.finite(el))) {
          de <- c(NA_real_, diff(el))
          de_rng <- range(de, na.rm = TRUE)
          el_rng <- range(el, na.rm = TRUE)
          if (is.finite(diff(de_rng)) && diff(de_rng) > 0) {
            de_scaled <- el_rng[1] + (de - de_rng[1]) * diff(el_rng) / diff(de_rng)
          } else {
            de_scaled <- rep(mean(el_rng), length(de))
          }
          graphics::plot(seq_along(el), el, type = "l", lwd = 2, col = "darkorange", xlab = "Iteration", ylab = "ELBO")
          graphics::lines(seq_along(el), de_scaled, col = "steelblue", lty = 2)
          graphics::legend("bottomright", legend = c("ELBO", "scaled delta ELBO"), col = c("darkorange", "steelblue"), lty = c(1, 2), bty = "n")
        } else {
          graphics::plot.new()
          graphics::title("ELBO trace unavailable")
        }
      })
      register_artifact(
        artifact_id = "fig_ex2_ldvb_diagnostics",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex2_ldvb_diagnostics.png",
        manuscript_target = "new: LDVB convergence diagnostics",
        status = "reproduced",
        notes = sprintf(
          "LDVB diagnostics with stricter tolerance (tol=%s, n.samp=%d); includes DQLM/exDQLM LDVB fit overlay, seq.gamma, seq.sigma, and ELBO trace.",
          format(ldvb_diag_tol), ldvb_diag_n_samp
        )
      )
    } else {
      register_artifact(
        artifact_id = "fig_ex2_ldvb_diagnostics",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex2_ldvb_diagnostics.png",
        manuscript_target = "new: LDVB convergence diagnostics",
        status = "not_reproduced",
        notes = sprintf("LDVB DQLM reference fit failed: %s", M1_ldvb$message)
      )
    }

    capture_output_file("ex2_ldvb_diagnostics_summary.txt", {
      cat(sprintf("tol=%s, n.samp=%d, iter=%d\n\n", format(ldvb_diag_tol), ldvb_diag_n_samp, ldvb_diag$iter))
      cat("seq.gamma summary:\n")
      print(summary(seq_g))
      cat("\nseq.sigma summary:\n")
      print(summary(seq_s))
      if (length(el) > 0L) {
        cat("\nELBO summary:\n")
        print(summary(el))
        if (length(el) > 1L) {
          cat("\nLast 5 delta ELBO values:\n")
          print(tail(diff(el), 5))
        }
      }
      cat("\nPosterior sample summaries:\n")
      cat("gamma: "); print(summary(as.numeric(ldvb_diag$samp.gamma)))
      cat("sigma: "); print(summary(as.numeric(ldvb_diag$samp.sigma)))
    })
    register_artifact(
      artifact_id = "ex2_ldvb_diagnostics_summary",
      artifact_type = "log",
      relative_path = "analysis/manuscript/outputs/logs/ex2_ldvb_diagnostics_summary.txt",
      manuscript_target = "new: LDVB convergence diagnostics summary",
      status = "reproduced",
      notes = "Text summary for LDVB convergence diagnostics."
    )

    register_note(
      "ex2_ldvb_diag",
      sprintf("Added LDVB diagnostic refit for convergence checks (tol=%s, n.samp=%d, iter=%d).",
              format(ldvb_diag_tol), ldvb_diag_n_samp, ldvb_diag$iter)
    )
  }

  if (need_ex2_tables) {
    ex2_df_scan <- load_or_fit_cache(
      sprintf("ex2_df_scan_ldvb_primary_nsamp%d_tol%s_v3", n_samp, format(tol)),
      {
      possible_dfs <- cbind(0.9, df_grid)
      KLs <- rep(NA_real_, nrow(possible_dfs))
      CRPSs <- rep(NA_real_, nrow(possible_dfs))
      for (i in seq_len(nrow(possible_dfs))) {
        temp_M <- tryCatch(
          exdqlm::exdqlmLDVB(
            y = y_ts, p0 = 0.85, model = model,
            df = possible_dfs[i, ], dim.df = c(1, 8),
            sig.init = 2, fix.sigma = FALSE,
            n.samp = n_samp, tol = tol,
            verbose = FALSE
          ),
          error = function(e) e
        )
        if (!inherits(temp_M, "error")) {
          temp_check <- diagnostics_from_fit(temp_M, plot = FALSE, ref = diag_ref_samp, y_data = y)
          KLs[i] <- temp_check$m1.KL
          CRPSs[i] <- temp_check$m1.CRPS
        }
      }
      list(possible_dfs = possible_dfs, KLs = KLs, CRPSs = CRPSs)
    }, note = sprintf("ex2_df_scan_ldvb_primary_nsamp%d_tol%s_v3", n_samp, format(tol)))

    possible_dfs <- ex2_df_scan$possible_dfs
    KLs <- ex2_df_scan$KLs
    CRPSs <- ex2_df_scan$CRPSs
    finite_crps <- is.finite(CRPSs)
    finite_kl <- is.finite(KLs)
    df_scan <- data.frame(
      trend_df = possible_dfs[, 1],
      seasonal_df = possible_dfs[, 2],
      CRPS = CRPSs,
      KL = KLs,
      rank_CRPS = rank(CRPSs, ties.method = "min", na.last = "keep"),
      rank_KL = rank(KLs, ties.method = "min", na.last = "keep")
    )
    if (any(finite_crps)) {
      best_df <- possible_dfs[which.min(CRPSs), ]
      best_df_kl <- if (any(finite_kl)) possible_dfs[which.min(KLs), ] else c(NA_real_, NA_real_)
        save_table_csv(
        df_scan,
        filename = "ex2_df_scan_kl.csv",
        artifact_id = "tab_ex2_df_scan",
        manuscript_target = "Example 2 discount-factor CRPS/KL selection",
        status = "reproduced",
        notes = sprintf(
          "Best pair by CRPS in this run: (%0.2f, %0.2f). Best pair by KL: (%s, %s).",
          best_df[1], best_df[2],
          format(best_df_kl[1], trim = TRUE, digits = 2),
          format(best_df_kl[2], trim = TRUE, digits = 2)
        )
      )

      register_note(
        "ex2",
        sprintf(
          "Sunspots LDVB discount-factor screen selects seasonal discount factor=%0.2f by CRPS for this run profile; KL is reported alongside it.",
          best_df[2]
        )
      )
    } else {
      save_table_csv(
        df_scan,
        filename = "ex2_df_scan_kl.csv",
        artifact_id = "tab_ex2_df_scan",
        manuscript_target = "Example 2 discount-factor CRPS/KL selection",
        status = "not_reproduced",
        notes = "No finite CRPS values were obtained in the primary LDVB discount-factor scan."
      )
    }

    if (ex2_ldvb_pair_ok) {
      diag_2 <- diagnostics_from_fit(M1_ldvb, M2_ldvb, plot = FALSE, ref = diag_ref_samp, y_data = y)
      diag_table <- data.frame(
        model = c("M1_dqlm_ldvb", "M2_exdqlm_ldvb"),
        KL = c(diag_2$m1.KL, diag_2$m2.KL),
        CRPS = c(diag_2$m1.CRPS, diag_2$m2.CRPS),
        pplc = c(diag_2$m1.pplc, diag_2$m2.pplc),
        run_time_seconds = c(diag_2$m1.rt, diag_2$m2.rt)
      )
      save_table_csv(
        diag_table,
        filename = "ex2_diagnostics_summary.csv",
        artifact_id = "tab_ex2_diagnostics",
        manuscript_target = "Example 2 diagnostic narrative",
        status = "reproduced",
        notes = "Primary Example 2 diagnostics summary computed from the LDVB fits."
      )
    } else {
      register_artifact(
        artifact_id = "tab_ex2_diagnostics",
        artifact_type = "table",
        relative_path = "analysis/manuscript/outputs/tables/ex2_diagnostics_summary.csv",
        manuscript_target = "Example 2 diagnostic narrative",
        status = "not_reproduced",
        notes = "Missing LDVB DQLM/exDQLM fits required for the primary diagnostics summary."
      )
    }
  }

  if (need_ex2_tables_ldvb) {
    ex2_df_scan_ldvb <- load_or_fit_cache(
      sprintf("ex2_df_scan_ldvb_support_nsamp%d_tol%s_v3", n_samp, format(tol)),
      {
      possible_dfs <- cbind(0.9, df_grid)
      KLs <- rep(NA_real_, nrow(possible_dfs))
      CRPSs <- rep(NA_real_, nrow(possible_dfs))
      for (i in seq_len(nrow(possible_dfs))) {
        temp_M <- tryCatch(
          exdqlm::exdqlmLDVB(
            y = y_ts, p0 = 0.85, model = model,
            df = possible_dfs[i, ], dim.df = c(1, 8),
            sig.init = 2, fix.sigma = FALSE,
            n.samp = n_samp, tol = tol,
            verbose = FALSE
          ),
          error = function(e) e
        )
        if (!inherits(temp_M, "error")) {
          temp_check <- diagnostics_from_fit(temp_M, plot = FALSE, ref = diag_ref_samp, y_data = y)
          KLs[i] <- temp_check$m1.KL
          CRPSs[i] <- temp_check$m1.CRPS
        }
      }
      list(possible_dfs = possible_dfs, KLs = KLs, CRPSs = CRPSs)
    }, note = sprintf("ex2_df_scan_ldvb_support_nsamp%d_tol%s_v3", n_samp, format(tol)))

    possible_dfs_ld <- ex2_df_scan_ldvb$possible_dfs
    KLs_ld <- ex2_df_scan_ldvb$KLs
    CRPSs_ld <- ex2_df_scan_ldvb$CRPSs
    df_scan_ld <- data.frame(
      trend_df = possible_dfs_ld[, 1],
      seasonal_df = possible_dfs_ld[, 2],
      CRPS = CRPSs_ld,
      KL = KLs_ld,
      rank_CRPS = rank(CRPSs_ld, ties.method = "min", na.last = "keep"),
      rank_KL = rank(KLs_ld, ties.method = "min", na.last = "keep")
    )
    finite_crps_ld <- is.finite(CRPSs_ld)
    finite_kl_ld <- is.finite(KLs_ld)
    if (any(finite_crps_ld)) {
      best_df_ld <- possible_dfs_ld[which.min(CRPSs_ld), ]
      best_df_kl_ld <- if (any(finite_kl_ld)) possible_dfs_ld[which.min(KLs_ld), ] else c(NA_real_, NA_real_)
      save_table_csv(
        df_scan_ld,
        filename = "ex2_df_scan_kl_ldvb.csv",
        artifact_id = "tab_ex2_df_scan_ldvb",
        manuscript_target = "new: Example 2 discount-factor CRPS/KL selection (LDVB)",
        status = "reproduced",
        notes = sprintf(
          "Best pair by CRPS in this run: (%0.2f, %0.2f). Best pair by KL: (%s, %s).",
          best_df_ld[1], best_df_ld[2],
          format(best_df_kl_ld[1], trim = TRUE, digits = 2),
          format(best_df_kl_ld[2], trim = TRUE, digits = 2)
        )
      )
      register_note(
        "ex2_ldvb",
        sprintf(
          "Sunspots LDVB discount-factor screen selects seasonal discount factor=%0.2f by CRPS for this run profile; KL is reported alongside it.",
          best_df_ld[2]
        )
      )
    } else {
      save_table_csv(
        df_scan_ld,
        filename = "ex2_df_scan_kl_ldvb.csv",
        artifact_id = "tab_ex2_df_scan_ldvb",
        manuscript_target = "new: Example 2 discount-factor CRPS/KL selection (LDVB)",
        status = "not_reproduced",
        notes = "No finite CRPS values were obtained in LDVB discount-factor scan."
      )
    }

    if (ex2_ldvb_pair_ok) {
      diag_m1_ld <- diagnostics_from_fit(M1_ldvb, plot = FALSE, ref = diag_ref_samp, y_data = y)
      diag_m2_ld <- diagnostics_from_fit(M2_ldvb, plot = FALSE, ref = diag_ref_samp, y_data = y)
      diag_table_ld <- data.frame(
        model = c("M1_dqlm_ldvb", "M2_exdqlm_ldvb"),
        KL = c(diag_m1_ld$m1.KL, diag_m2_ld$m1.KL),
        CRPS = c(diag_m1_ld$m1.CRPS, diag_m2_ld$m1.CRPS),
        pplc = c(diag_m1_ld$m1.pplc, diag_m2_ld$m1.pplc),
        run_time_seconds = c(diag_m1_ld$m1.rt, diag_m2_ld$m1.rt)
      )
      save_table_csv(
        diag_table_ld,
        filename = "ex2_diagnostics_summary_ldvb.csv",
        artifact_id = "tab_ex2_diagnostics_ldvb",
        manuscript_target = "new: Example 2 diagnostic narrative (LDVB)",
        status = "reproduced",
        notes = "LDVB counterpart computed with exdqlmDiagnostics."
      )
    } else {
      register_artifact(
        artifact_id = "tab_ex2_diagnostics_ldvb",
        artifact_type = "table",
        relative_path = "analysis/manuscript/outputs/tables/ex2_diagnostics_summary_ldvb.csv",
        manuscript_target = "new: Example 2 diagnostic narrative (LDVB)",
        status = "not_reproduced",
        notes = "Missing LDVB DQLM/exDQLM fits required for diagnostics summary."
      )
    }
  }

  log_msg("Example 2 (Sunspots): complete")
}
