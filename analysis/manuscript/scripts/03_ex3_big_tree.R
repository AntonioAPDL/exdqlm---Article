need_ex3 <- target_enabled("ex3", c("ex3data", "ex3forecast", "ex3quantcomps", "ex3zetapsi", "ex3tables"))
if (!need_ex3) {
  log_msg("Example 3 (Big Tree): skipped (target filter)")
} else {
  log_msg("Example 3 (Big Tree): start")

  need_ex3data <- target_enabled("ex3data", "ex3")
  need_ex3forecast <- target_enabled("ex3forecast", "ex3")
  need_ex3quantcomps <- target_enabled("ex3quantcomps", "ex3")
  need_ex3zetapsi <- target_enabled("ex3zetapsi", "ex3")
  need_ex3tables <- target_enabled("ex3tables", "ex3")
  need_ex3_models <- any(c(need_ex3forecast, need_ex3quantcomps, need_ex3zetapsi, need_ex3tables))

  utils::data("BTflow", package = "exdqlm", envir = environment())
  utils::data("nino34", package = "exdqlm", envir = environment())

  if (!exists("BTflow") || !exists("nino34")) {
    stop("Required datasets BTflow/nino34 not available from exdqlm package.", call. = FALSE)
  }

  btflow_ts <- BTflow
  nino_ts <- nino34
  y_log <- log(as.numeric(btflow_ts))

  if (need_ex3data) {
    save_png_plot("ex3data.png", {
      graphics::par(mfrow = c(2, 1))
      stats::plot.ts(log(btflow_ts), col = "grey40", ylab = "log(BTflow)")
      stats::plot.ts(nino_ts, col = "steelblue4", ylab = "nino34")
    })
    register_artifact(
      artifact_id = "fig_ex3data",
      artifact_type = "figure",
      relative_path = "analysis/manuscript/outputs/figures/ex3data.png",
      manuscript_target = "fig:ex3data",
      status = "reproduced",
      notes = "Top: log BTflow. Bottom: nino34."
    )
  }

  if (need_ex3_models) {
    trend_comp <- exdqlm::polytrendMod(1, m0 = 3, C0 = 0.1)
    seas_comp <- exdqlm::seasMod(p = 12, h = 1, C0 = diag(1, 2))
    model <- trend_comp + seas_comp

    reg_comp <- exdqlm::as.exdqlm(list(
      m0 = 0,
      C0 = 1,
      FF = matrix(as.numeric(nino_ts), nrow = 1),
      GG = 1
    ))
    model_w_reg <- model + reg_comp

    n_is <- as.integer(cfg_profile$ex3$n_is)
    n_samp <- as.integer(cfg_profile$ex3$n_samp)
    tol <- as.numeric(cfg_profile$ex3$tol)
    lambda_grid <- as.numeric(cfg_profile$ex3$lambda_grid)

    ex3_models <- load_or_fit_cache("ex3_models", {
      ref_samp <- stats::rnorm(length(y_log))
      KLs <- numeric(length(lambda_grid))
      for (i in seq_along(lambda_grid)) {
        temp_M2 <- exdqlm::transfn_exdqlmISVB(
          y = y_log, p0 = 0.15, model = model,
          df = c(1, 0.9), dim.df = c(1, 2),
          X = as.numeric(nino_ts), tf.df = c(0.95), lam = lambda_grid[i],
          tf.m0 = c(0, 0), tf.C0 = diag(c(0.1, 0.005), 2),
          sig.init = 0.1, gam.init = -0.1,
          tol = tol, n.IS = n_is, n.samp = n_samp,
          verbose = FALSE
        )
        temp_check <- exdqlm::exdqlmDiagnostics(temp_M2, plot = FALSE, ref = ref_samp)
        KLs[i] <- temp_check$m1.KL
      }
      lambda_star <- lambda_grid[which.min(KLs)]

      M1 <- exdqlm::exdqlmISVB(
        y = y_log, p0 = 0.15, model = model_w_reg,
        df = c(1, 0.9, 0.95), dim.df = c(1, 2, 1),
        sig.init = 0.1, gam.init = -0.1,
        tol = tol, n.IS = n_is, n.samp = n_samp,
        verbose = FALSE
      )

      M2 <- exdqlm::transfn_exdqlmISVB(
        y = y_log, p0 = 0.15, model = model,
        df = c(1, 0.9), dim.df = c(1, 2),
        X = as.numeric(nino_ts), tf.df = c(0.95), lam = lambda_star,
        tf.m0 = c(0, 0), tf.C0 = diag(c(0.1, 0.005), 2),
        sig.init = 0.1, gam.init = -0.1,
        tol = tol, n.IS = n_is, n.samp = n_samp,
        verbose = FALSE
      )

      list(
        M1 = M1, M2 = M2, model = model, model_w_reg = model_w_reg,
        lambda_grid = lambda_grid, KLs = KLs, lambda_star = lambda_star,
        n_is = n_is, n_samp = n_samp, tol = tol
      )
    }, note = "ex3_models")

    M1 <- ex3_models$M1
    M2 <- ex3_models$M2
    lambda_grid <- ex3_models$lambda_grid
    KLs <- ex3_models$KLs
    lambda_star <- ex3_models$lambda_star

    capture_output_file("ex3_run_summary.txt", {
      cat(sprintf("profile=%s\n", selected_profile))
      cat(sprintf("n.IS=%d, n.samp=%d, tol=%s\n", ex3_models$n_is, ex3_models$n_samp, format(ex3_models$tol)))
      cat(sprintf("lambda_star=%0.3f\n\n", lambda_star))
      cat("KL grid:\n")
      print(data.frame(lambda = lambda_grid, KL = KLs))
      cat("\nM2$median.kt:\n")
      print(M2$median.kt)
      cat("\nRun times (seconds):\n")
      print(c(M1 = M1$run.time, M2 = M2$run.time))
    })
    register_artifact(
      artifact_id = "ex3_run_summary",
      artifact_type = "log",
      relative_path = "analysis/manuscript/outputs/logs/ex3_run_summary.txt",
      manuscript_target = "Example 3 textual outputs",
      status = "reproduced",
      notes = "Includes lambda optimization table and median.kt."
    )

    xlim_idx_1970 <- time_window_to_index(btflow_ts, 1970, 1990)
    xlim_idx_fore <- time_window_to_index(btflow_ts, 2017, 2021.4)

    if (need_ex3quantcomps) {
      save_png_plot("ex3quantcomps.png", {
        graphics::par(mfrow = c(3, 1))

        stats::plot.ts(y_log, col = "grey70", ylim = c(1, 8), xlim = xlim_idx_1970, ylab = "quantile 95% CrIs")
        exdqlm::exdqlmPlot(M1, add = TRUE, col = "purple")
        exdqlm::exdqlmPlot(M2, add = TRUE, col = "forestgreen")
        graphics::legend("topleft", legend = c("M1 regression", "M2 transfer fn"), col = c("purple", "forestgreen"), lty = 1, bty = "n")

        graphics::plot(NA, ylim = c(-1.5, 1.5), xlim = xlim_idx_1970, ylab = "seasonal components", xlab = "Index")
        exdqlm::compPlot(M1, index = c(2, 3), add = TRUE, col = "purple")
        exdqlm::compPlot(M2, index = c(2, 3), add = TRUE, col = "forestgreen")

        graphics::plot(NA, ylim = c(-0.5, 1.5), xlim = xlim_idx_1970, ylab = "Nino 3.4 components", xlab = "Index")
        exdqlm::compPlot(M1, index = c(4), add = TRUE, col = "purple")
        exdqlm::compPlot(M2, index = c(4, 5), add = TRUE, col = "forestgreen")
        graphics::abline(h = 0, col = "orange", lty = 3, lwd = 2)
      })
      register_artifact(
        artifact_id = "fig_ex3quantcomps",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex3quantcomps.png",
        manuscript_target = "fig:ex3quant",
        status = "reproduced",
        notes = "Three-panel quantile/components figure with index-window fix."
      )
    }

    if (need_ex3zetapsi) {
      save_png_plot("ex3zetapsi.png", {
        graphics::par(mfrow = c(1, 2))
        exdqlm::compPlot(M2, index = 4, col = "forestgreen", add = FALSE, just.theta = TRUE)
        graphics::abline(h = 0, col = "orange", lty = 3, lwd = 2)
        graphics::title(expression(zeta[t]))
        exdqlm::compPlot(M2, index = 5, col = "forestgreen", add = FALSE, just.theta = TRUE)
        graphics::abline(h = 0, col = "orange", lty = 3, lwd = 2)
        graphics::title(expression(psi[t]))
      })
      register_artifact(
        artifact_id = "fig_ex3zetapsi",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex3zetapsi.png",
        manuscript_target = "fig:ex3tftheta",
        status = "reproduced",
        notes = "Transfer-function theta component plots."
      )
    }

    if (need_ex3forecast) {
      save_png_plot("ex3forecast.png", {
        stats::plot.ts(y_log, col = "grey70", ylim = c(1, 8), xlim = xlim_idx_fore)
        fc1 <- exdqlm::exdqlmForecast(start.t = length(y_log) - 18, k = 18, m1 = M1, plot = FALSE)
        plot(fc1, add = TRUE, cols = c("purple", "magenta"))
        fc2 <- exdqlm::exdqlmForecast(start.t = length(y_log) - 18, k = 18, m1 = M2, plot = FALSE)
        plot(fc2, add = TRUE, cols = c("forestgreen", "green"))
        vline_x <- grDevices::xy.coords(y_log)$x[length(y_log) - 18]
        graphics::abline(v = vline_x, col = "orange", lty = 5)
      })
      register_artifact(
        artifact_id = "fig_ex3forecast",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex3forecast.png",
        manuscript_target = "fig:ex3forecast",
        status = "reproduced",
        notes = "18-step ahead forecast comparison."
      )
    }

    if (need_ex3tables) {
      diag_3 <- exdqlm::exdqlmDiagnostics(M1, M2, plot = FALSE)
      diag_table <- data.frame(
        model = c("M1_regression", "M2_transfer_function"),
        KL = c(diag_3$m1.KL, diag_3$m2.KL),
        pplc = c(diag_3$m1.pplc, diag_3$m2.pplc),
        run_time_seconds = c(diag_3$m1.rt, diag_3$m2.rt)
      )
      save_table_csv(
        diag_table,
        filename = "ex3_diagnostics_summary.csv",
        artifact_id = "tab_ex3_diagnostics",
        manuscript_target = "tab:ex3",
        status = "reproduced",
        notes = "Diagnostics table generated with exdqlmDiagnostics."
      )

      lambda_table <- data.frame(lambda = lambda_grid, KL = KLs)
      save_table_csv(
        lambda_table,
        filename = "ex3_lambda_scan_kl.csv",
        artifact_id = "tab_ex3_lambda_scan",
        manuscript_target = "Example 3 lambda selection output",
        status = "reproduced",
        notes = sprintf("Best lambda in this run=%0.3f", lambda_star)
      )

      register_note("ex3", sprintf("Best lambda by KL in this run profile: %0.3f.", lambda_star))
    }
  }

  log_msg("Example 3 (Big Tree): complete")
}
