need_ex2 <- target_enabled("ex2", c("ex2quant", "ex2checks", "ex2_isvb_ldvb_compare", "ex2tables"))
if (!need_ex2) {
  log_msg("Example 2 (Sunspots): skipped (target filter)")
} else {
  log_msg("Example 2 (Sunspots): start")

  need_ex2quant <- target_enabled("ex2quant", "ex2")
  need_ex2checks <- target_enabled("ex2checks", "ex2")
  need_ex2_ldvb <- target_enabled("ex2_isvb_ldvb_compare", "ex2")
  need_ex2_tables <- target_enabled("ex2tables", "ex2")

  y_ts <- datasets::sunspot.year
  y <- as.numeric(y_ts)

  dlm_trend_comp <- dlm::dlmModPoly(1, m0 = mean(y), C0 = 10)
  # Explicit conversion avoids a known as.exdqlm(dlm) bug in current package state.
  trend_comp <- exdqlm::as.exdqlm(list(
    m0 = as.numeric(dlm_trend_comp$m0),
    C0 = as.matrix(dlm_trend_comp$C0),
    FF = t(as.matrix(dlm_trend_comp$FF)),
    GG = as.matrix(dlm_trend_comp$GG)
  ))
  seas_comp <- exdqlm::seasMod(p = 11, h = 1:4, C0 = 10 * diag(8))
  model <- trend_comp + seas_comp
  register_note("ex2", "Used explicit dlm->exdqlm conversion because as.exdqlm(dlm) errors in current package.")

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

  n_is <- as.integer(cfg_profile$ex2$n_is)
  n_samp <- as.integer(cfg_profile$ex2$n_samp)
  tol <- as.numeric(cfg_profile$ex2$tol)
  df_grid <- as.numeric(cfg_profile$ex2$df_grid)

  ex2_core <- load_or_fit_cache("ex2_core_models", {
    M_sigma <- exdqlm::exdqlmISVB(
      y = y_ts, p0 = 0.85, model = model,
      df = c(0.9, 0.85), dim.df = c(1, 8),
      dqlm.ind = TRUE, fix.sigma = FALSE,
      n.IS = n_is, n.samp = n_samp, tol = tol,
      verbose = FALSE
    )

    M1 <- exdqlm::exdqlmISVB(
      y = y_ts, p0 = 0.85, model = model,
      df = c(0.9, 0.85), dim.df = c(1, 8),
      dqlm.ind = TRUE, sig.init = 2,
      n.IS = n_is, n.samp = n_samp, tol = tol,
      verbose = FALSE
    )

    M2 <- exdqlm::exdqlmISVB(
      y = y_ts, p0 = 0.85, model = model,
      df = c(0.9, 0.85), dim.df = c(1, 8),
      sig.init = 2,
      n.IS = n_is, n.samp = n_samp, tol = tol,
      verbose = FALSE
    )

    M2_ldvb <- tryCatch(
      exdqlm::exdqlmLDVB(
        y = y_ts, p0 = 0.85, model = model,
        df = c(0.9, 0.85), dim.df = c(1, 8),
        sig.init = 2, n.samp = n_samp, tol = tol,
        verbose = FALSE
      ),
      error = function(e) e
    )

    list(M_sigma = M_sigma, M1 = M1, M2 = M2, M2_ldvb = M2_ldvb, model = model)
  }, note = "ex2_core_models")

  M_sigma <- ex2_core$M_sigma
  M1 <- ex2_core$M1
  M2 <- ex2_core$M2
  M2_ldvb <- ex2_core$M2_ldvb

  capture_output_file("ex2_run_summary.txt", {
    cat(sprintf("profile=%s\n", selected_profile))
    cat(sprintf("n.IS=%d, n.samp=%d, tol=%s\n\n", n_is, n_samp, format(tol)))
    cat("Summary(M_sigma$samp.sigma):\n")
    print(summary(M_sigma$samp.sigma))
    cat("\nRuntime seconds:\n")
    rt <- c(M_sigma = M_sigma$run.time, M1_isvb = M1$run.time, M2_isvb = M2$run.time)
    if (!inherits(M2_ldvb, "error")) rt <- c(rt, M2_ldvb = M2_ldvb$run.time)
    print(rt)
    if (inherits(M2_ldvb, "error")) {
      cat("\nLDVB status: failed\n")
      cat(M2_ldvb$message, "\n")
    } else {
      cat("\nLDVB status: success\n")
      cat("Summary(M2_ldvb$samp.gamma):\n")
      print(summary(M2_ldvb$samp.gamma))
    }
  })
  register_artifact(
    artifact_id = "ex2_run_summary",
    artifact_type = "log",
    relative_path = "analysis/manuscript/outputs/logs/ex2_run_summary.txt",
    manuscript_target = "Example 2 textual outputs",
    status = if (inherits(M2_ldvb, "error")) "approximate" else "reproduced",
    notes = "Includes sigma summary and ISVB/LDVB runtime diagnostics."
  )

  xlim_idx <- time_window_to_index(y_ts, 1750, 1850)

  if (need_ex2quant) {
    save_png_plot("ex2quant.png", {
      graphics::par(mfrow = c(1, 3))
      stats::plot.ts(y_ts, col = "darkgrey", ylab = "sunspot count")

      stats::plot.ts(y, xlim = xlim_idx, col = "darkgrey", ylab = "quantile 95% CrIs")
      exdqlm::exdqlmPlot(M1, add = TRUE, col = "red")
      exdqlm::exdqlmPlot(M2, add = TRUE, col = "blue")
      graphics::legend("topleft", legend = c("DQLM (ISVB)", "exDQLM (ISVB)"), col = c("red", "blue"), lty = 1, bty = "n")

      graphics::hist(M2$samp.gamma, xlab = expression(gamma), main = "")
    })
    register_artifact(
      artifact_id = "fig_ex2quant",
      artifact_type = "figure",
      relative_path = "analysis/manuscript/outputs/figures/ex2quant.png",
      manuscript_target = "fig:ex2quant",
      status = "reproduced",
      notes = "Three-panel Sunspots figure (data, quantiles, gamma histogram)."
    )
  }

  if (need_ex2checks) {
    save_png_plot("ex2checks.png", {
      graphics::par(mfrow = c(2, 3))
      exdqlm::exdqlmDiagnostics(M1, M2, plot = TRUE, cols = c("red", "blue"))
    })
    register_artifact(
      artifact_id = "fig_ex2checks",
      artifact_type = "figure",
      relative_path = "analysis/manuscript/outputs/figures/ex2checks.png",
      manuscript_target = "fig:ex2checks",
      status = "reproduced",
      notes = "Generated via exdqlmDiagnostics replacement for legacy exdqlmChecks."
    )
  }

  if (need_ex2_ldvb) {
    if (!inherits(M2_ldvb, "error")) {
      save_png_plot("ex2_isvb_ldvb_compare.png", {
        graphics::par(mfrow = c(1, 2))

        stats::plot.ts(y, xlim = xlim_idx, col = "grey70", ylab = "quantile 95% CrIs")
        exdqlm::exdqlmPlot(M2, add = TRUE, col = "blue")
        q_ld <- quantile_summary_from_fit(M2_ldvb, cr.percent = 0.95)
        plot_quantile_summary(q_ld, col = "darkorange", add = TRUE)
        graphics::legend(
          "topleft",
          legend = c("ISVB exDQLM", "LDVB exDQLM"),
          col = c("blue", "darkorange"),
          lty = 1,
          bty = "n"
        )

        gamma_is <- as.numeric(M2$samp.gamma)
        gamma_ld <- as.numeric(M2_ldvb$samp.gamma)
        d_is <- stats::density(gamma_is)
        r_all <- range(c(gamma_is, gamma_ld), na.rm = TRUE)
        span <- max(1e-4, diff(r_all))
        xlim_gamma <- c(r_all[1] - 0.15 * span, r_all[2] + 0.15 * span)

        graphics::plot(d_is, col = "blue", lwd = 2, main = "", xlab = expression(gamma), ylab = "Density", xlim = xlim_gamma)
        if (stats::sd(gamma_ld) < 1e-4) {
          x0 <- as.numeric(stats::median(gamma_ld))
          ymax <- max(d_is$y, na.rm = TRUE)
          graphics::segments(x0 = x0, y0 = 0, x1 = x0, y1 = ymax * 0.95, col = "darkorange", lwd = 3, lty = 2)
          graphics::legend("topright", legend = c("ISVB", "LDVB (point mass)"), col = c("blue", "darkorange"), lty = c(1, 2), lwd = 2, bty = "n")
        } else {
          d_ld <- stats::density(gamma_ld)
          graphics::lines(d_ld, col = "darkorange", lwd = 2)
          graphics::legend("topright", legend = c("ISVB", "LDVB"), col = c("blue", "darkorange"), lty = 1, lwd = 2, bty = "n")
        }
      })
      register_artifact(
        artifact_id = "fig_ex2_isvb_ldvb_compare",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex2_isvb_ldvb_compare.png",
        manuscript_target = "new: ISVB vs LDVB dynamic comparison",
        status = "reproduced",
        notes = "Includes robust LDVB display when gamma posterior is near-degenerate."
      )
    } else {
      register_artifact(
        artifact_id = "fig_ex2_isvb_ldvb_compare",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex2_isvb_ldvb_compare.png",
        manuscript_target = "new: ISVB vs LDVB dynamic comparison",
        status = "not_reproduced",
        notes = sprintf("LDVB fit failed: %s", M2_ldvb$message)
      )
    }
  }

  if (need_ex2_tables) {
    ex2_df_scan <- load_or_fit_cache("ex2_df_scan", {
      possible_dfs <- cbind(0.9, df_grid)
      ref_samp <- stats::rnorm(length(y_ts))
      KLs <- numeric(nrow(possible_dfs))
      for (i in seq_len(nrow(possible_dfs))) {
        temp_M <- exdqlm::exdqlmISVB(
          y = y_ts, p0 = 0.85, model = model,
          df = possible_dfs[i, ], dim.df = c(1, 8),
          sig.init = 2,
          n.IS = n_is, n.samp = n_samp, tol = tol,
          verbose = FALSE
        )
        temp_check <- exdqlm::exdqlmDiagnostics(temp_M, plot = FALSE, ref = ref_samp)
        KLs[i] <- temp_check$m1.KL
      }
      list(possible_dfs = possible_dfs, KLs = KLs)
    }, note = "ex2_df_scan")

    possible_dfs <- ex2_df_scan$possible_dfs
    KLs <- ex2_df_scan$KLs
    best_df <- possible_dfs[which.min(KLs), ]
    df_scan <- data.frame(
      trend_df = possible_dfs[, 1],
      seasonal_df = possible_dfs[, 2],
      KL = KLs
    )
    save_table_csv(
      df_scan,
      filename = "ex2_df_scan_kl.csv",
      artifact_id = "tab_ex2_df_scan",
      manuscript_target = "Example 2 discount-factor KL selection",
      status = "reproduced",
      notes = sprintf("Best pair in this run: (%0.2f, %0.2f)", best_df[1], best_df[2])
    )

    diag_2 <- exdqlm::exdqlmDiagnostics(M1, M2, plot = FALSE)
    diag_table <- data.frame(
      model = c("M1_dqlm_isvb", "M2_exdqlm_isvb"),
      KL = c(diag_2$m1.KL, diag_2$m2.KL),
      pplc = c(diag_2$m1.pplc, diag_2$m2.pplc),
      run_time_seconds = c(diag_2$m1.rt, diag_2$m2.rt)
    )
    save_table_csv(
      diag_table,
      filename = "ex2_diagnostics_summary.csv",
      artifact_id = "tab_ex2_diagnostics",
      manuscript_target = "Example 2 diagnostic narrative",
      status = "reproduced",
      notes = "Computed with exdqlmDiagnostics."
    )

    register_note(
      "ex2",
      sprintf("Sunspots KL search best seasonal discount factor=%0.2f for this run profile.", best_df[2])
    )
  }

  log_msg("Example 2 (Sunspots): complete")
}
