need_ex2 <- target_enabled("ex2", c("ex2quant", "ex2checks", "ex2_isvb_ldvb_compare", "ex2_ldvb_diagnostics", "ex2_gamma_posteriors", "ex2tables"))
if (!need_ex2) {
  log_msg("Example 2 (Sunspots): skipped (target filter)")
} else {
  log_msg("Example 2 (Sunspots): start")

  need_ex2quant <- target_enabled("ex2quant", "ex2")
  need_ex2checks <- target_enabled("ex2checks", "ex2")
  need_ex2_ldvb <- target_enabled("ex2_isvb_ldvb_compare", "ex2")
  need_ex2_ldvb_diag <- target_enabled("ex2_ldvb_diagnostics", "ex2")
  need_ex2_gamma <- target_enabled("ex2_gamma_posteriors", "ex2")
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
  ldvb_diag_tol <- as.numeric(cfg_profile$ex2$ldvb_diag_tol %||% tol)
  ldvb_diag_n_samp <- as.integer(cfg_profile$ex2$ldvb_diag_n_samp %||% n_samp)
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

  if (need_ex2_gamma) {
    if (!inherits(M2_ldvb, "error")) {
      gamma_is <- as.numeric(M2$samp.gamma)
      gamma_ld <- as.numeric(M2_ldvb$samp.gamma)
      gamma_is <- gamma_is[is.finite(gamma_is)]
      gamma_ld <- gamma_ld[is.finite(gamma_ld)]

      ci_is <- stats::quantile(gamma_is, probs = c(0.025, 0.5, 0.975), na.rm = TRUE, names = FALSE)
      ci_ld <- stats::quantile(gamma_ld, probs = c(0.025, 0.5, 0.975), na.rm = TRUE, names = FALSE)

      draw_gamma_panel <- function(draws, ci, col, main_txt) {
        s <- stats::sd(draws)
        if (is.finite(s) && s >= 1e-8) {
          d <- stats::density(draws)
          graphics::plot(d, col = col, lwd = 2, main = main_txt, xlab = expression(gamma), ylab = "Density")
          y_max <- max(d$y, na.rm = TRUE)
          graphics::segments(ci[1], 0, ci[1], y_max, col = col, lty = 2, lwd = 1.5)
          graphics::segments(ci[2], 0, ci[2], y_max, col = col, lty = 1, lwd = 1.5)
          graphics::segments(ci[3], 0, ci[3], y_max, col = col, lty = 2, lwd = 1.5)
          graphics::legend("topright", legend = c("Median", "95% CrI"), col = col, lty = c(1, 2), bty = "n")
        } else {
          x0 <- ci[2]
          x_pad <- max(5e-4, abs(x0) * 0.05)
          graphics::plot(NA, xlim = c(x0 - x_pad, x0 + x_pad), ylim = c(0, 1), main = main_txt, xlab = expression(gamma), ylab = "Density")
          graphics::segments(x0 = ci[2], y0 = 0, x1 = ci[2], y1 = 1, col = col, lwd = 3)
          graphics::segments(x0 = ci[1], y0 = 0, x1 = ci[1], y1 = 1, col = col, lwd = 1.5, lty = 2)
          graphics::segments(x0 = ci[3], y0 = 0, x1 = ci[3], y1 = 1, col = col, lwd = 1.5, lty = 2)
          graphics::legend("topright", legend = c("Point mass", "95% CrI"), col = col, lty = c(1, 2), bty = "n")
        }
        graphics::mtext(
          sprintf("95%% CrI: [%.4f, %.4f]", ci[1], ci[3]),
          side = 3, line = 0.2, cex = 0.8
        )
      }

      save_png_plot("ex2_gamma_posteriors.png", {
        graphics::par(mfrow = c(1, 2))
        draw_gamma_panel(gamma_is, ci_is, col = "blue", main_txt = "ISVB: gamma posterior")
        draw_gamma_panel(gamma_ld, ci_ld, col = "darkorange", main_txt = "LDVB: gamma posterior")
      })
      register_artifact(
        artifact_id = "fig_ex2_gamma_posteriors",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex2_gamma_posteriors.png",
        manuscript_target = "new: ISVB and LDVB gamma posteriors (side-by-side)",
        status = "reproduced",
        notes = "Separate gamma posterior densities with median and 95% credible intervals for each method."
      )

      gamma_ci_tbl <- data.frame(
        method = c("ISVB", "LDVB"),
        lower_95 = c(ci_is[1], ci_ld[1]),
        median = c(ci_is[2], ci_ld[2]),
        upper_95 = c(ci_is[3], ci_ld[3]),
        mean = c(mean(gamma_is), mean(gamma_ld)),
        sd = c(stats::sd(gamma_is), stats::sd(gamma_ld)),
        n_draws = c(length(gamma_is), length(gamma_ld))
      )
      save_table_csv(
        gamma_ci_tbl,
        filename = "ex2_gamma_credible_intervals.csv",
        artifact_id = "tab_ex2_gamma_credible_intervals",
        manuscript_target = "new: Example 2 gamma 95% credible intervals",
        status = "reproduced",
        notes = "Summaries from posterior samples of gamma for ISVB and LDVB."
      )
    } else {
      register_artifact(
        artifact_id = "fig_ex2_gamma_posteriors",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex2_gamma_posteriors.png",
        manuscript_target = "new: ISVB and LDVB gamma posteriors (side-by-side)",
        status = "not_reproduced",
        notes = sprintf("LDVB fit failed: %s", M2_ldvb$message)
      )
      register_artifact(
        artifact_id = "tab_ex2_gamma_credible_intervals",
        artifact_type = "table",
        relative_path = "analysis/manuscript/outputs/tables/ex2_gamma_credible_intervals.csv",
        manuscript_target = "new: Example 2 gamma 95% credible intervals",
        status = "not_reproduced",
        notes = sprintf("LDVB fit failed: %s", M2_ldvb$message)
      )
    }
  }

  if (need_ex2_ldvb_diag) {
    ldvb_diag <- load_or_fit_cache("ex2_ldvb_diagnostics_fit", {
      exdqlm::exdqlmLDVB(
        y = y_ts, p0 = 0.85, model = model,
        df = c(0.9, 0.85), dim.df = c(1, 8),
        sig.init = 2, n.samp = ldvb_diag_n_samp, tol = ldvb_diag_tol,
        verbose = FALSE
      )
    }, note = "ex2_ldvb_diagnostics_fit")
    seq_g <- as.numeric(ldvb_diag$seq.gamma)
    seq_s <- as.numeric(ldvb_diag$seq.sigma)
    el <- as.numeric(ldvb_diag$diagnostics$elbo)

    save_png_plot("ex2_ldvb_diagnostics.png", {
      graphics::par(mfrow = c(2, 2))

      # Fit comparison in the manuscript's focused time window.
      stats::plot.ts(y, xlim = xlim_idx, col = "grey70", ylab = "quantile 95% CrIs")
      exdqlm::exdqlmPlot(M2, add = TRUE, col = "blue")
      q_ld <- quantile_summary_from_fit(ldvb_diag, cr.percent = 0.95)
      plot_quantile_summary(q_ld, col = "darkorange", add = TRUE)
      graphics::legend("topleft", legend = c("ISVB fit", "LDVB fit"), col = c("blue", "darkorange"), lty = 1, bty = "n")

      # LDVB parameter paths by iteration.
      graphics::plot(seq_along(seq_g), seq_g, type = "o", pch = 16, cex = 0.45, col = "darkorange", xlab = "Iteration", ylab = expression(seq(gamma)))
      graphics::plot(seq_along(seq_s), seq_s, type = "o", pch = 16, cex = 0.45, col = "darkorange", xlab = "Iteration", ylab = expression(seq(sigma)))

      # ELBO and delta-ELBO traces.
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
        "LDVB diagnostics with stricter tolerance (tol=%s, n.samp=%d); includes fit overlay, seq.gamma, seq.sigma, ELBO trace.",
        format(ldvb_diag_tol), ldvb_diag_n_samp
      )
    )

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
