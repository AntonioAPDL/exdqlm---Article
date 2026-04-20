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
  need_ex3forecast <- target_enabled("ex3forecast", "ex3")
  need_ex3forecast_ldvb <- target_enabled("ex3forecast_ldvb", "ex3")
  need_ex3quantcomps <- target_enabled("ex3quantcomps", "ex3")
  need_ex3quantcomps_ldvb <- target_enabled("ex3quantcomps_ldvb", "ex3")
  need_ex3zetapsi <- target_enabled("ex3zetapsi", "ex3")
  need_ex3zetapsi_ldvb <- target_enabled("ex3zetapsi_ldvb", "ex3")
  need_ex3tables <- target_enabled("ex3tables", "ex3")
  need_ex3tables_ldvb <- target_enabled("ex3tables_ldvb", "ex3")
  need_ex3_models <- any(c(
    need_ex3forecast, need_ex3quantcomps, need_ex3zetapsi, need_ex3tables,
    need_ex3forecast_ldvb, need_ex3quantcomps_ldvb, need_ex3zetapsi_ldvb, need_ex3tables_ldvb
  ))

  ex3_daily_path <- Sys.getenv(
    "EX3_DAILY_DATA_PATH",
    unset = "/home/jaguir26/data/exdqlm_experiments/ex3_daily/big_trees_daily_usgs_ppt_soil.csv"
  )
  if (!file.exists(ex3_daily_path)) {
    stop(
      sprintf(
        "Required daily Big Tree input file not found: %s",
        ex3_daily_path
      ),
      call. = FALSE
    )
  }
  ex3_daily_df <- utils::read.csv(ex3_daily_path, stringsAsFactors = FALSE)
  required_cols <- c("date", "usgs_cfs")
  missing_cols <- setdiff(required_cols, names(ex3_daily_df))
  if (length(missing_cols) > 0L) {
    stop(
      sprintf(
        "Daily Big Tree input is missing required columns: %s",
        paste(missing_cols, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  utils::data("nino34", package = "exdqlm", envir = environment())
  if (!exists("nino34")) {
    stop("Required dataset nino34 not available from exdqlm package.", call. = FALSE)
  }

  ex3_daily_df$date <- as.Date(ex3_daily_df$date)
  ex3_daily_df <- ex3_daily_df[order(ex3_daily_df$date), required_cols, drop = FALSE]
  ex3_month_id <- format(ex3_daily_df$date, "%Y-%m")
  ex3_monthly_df <- aggregate(
    ex3_daily_df["usgs_cfs"],
    by = list(month = ex3_month_id),
    FUN = mean
  )
  ex3_monthly_df$date <- as.Date(paste0(ex3_monthly_df$month, "-01"))
  ex3_monthly_df <- ex3_monthly_df[order(ex3_monthly_df$date), , drop = FALSE]

  ex3_start_year <- as.integer(format(ex3_monthly_df$date[1], "%Y"))
  ex3_start_month <- as.integer(format(ex3_monthly_df$date[1], "%m"))
  btflow_ts_full <- stats::ts(
    ex3_monthly_df$usgs_cfs,
    start = c(ex3_start_year, ex3_start_month),
    frequency = 12
  )
  flow_monthly <- stats::window(btflow_ts_full, end = c(2021, 4))
  nino_ts <- stats::window(nino34, start = stats::start(flow_monthly), end = stats::end(flow_monthly))
  if (length(flow_monthly) != length(nino_ts)) {
    stop("Monthly USGS flow and nino34 overlap lengths do not match.", call. = FALSE)
  }

  y_log_ts <- log(flow_monthly)
  y_log <- as.numeric(y_log_ts)
  ex3_cols <- list(
    m1 = "#8A46B2",
    m1_aux = "#C48AE0",
    m2 = "#2E7D5B",
    m2_aux = "#85B89A",
    nino = "#2D6F95",
    ref = "#C47A2C"
  )
  ldvb_cols <- ex3_cols

  if (need_ex3data) {
    save_png_plot("ex3data.png", {
      graphics::par(mfrow = c(2, 1))
      stats::plot.ts(log(flow_monthly), col = "grey40", ylab = "log(flow)")
      stats::plot.ts(nino_ts, col = ex3_cols$nino, ylab = "nino34")
    })
    register_artifact(
      artifact_id = "fig_ex3data",
      artifact_type = "figure",
      relative_path = "analysis/manuscript/outputs/figures/ex3data.png",
      manuscript_target = "fig:ex3data",
      status = "reproduced",
      notes = paste(
        "Top: log monthly Big Tree flow aggregated from the staged daily file.",
        "Bottom: nino34 over the overlapping 1987-01 to 2021-04 window."
      )
    )
  }

  if (need_ex3_models) {
    trend_comp <- exdqlm::polytrendMod(1, m0 = 3, C0 = 0.1)
    seas_comp <- exdqlm::seasMod(p = 12, h = c(1, 2, 0.1469118636), C0 = diag(1, 6))
    model <- trend_comp + seas_comp

    reg_comp <- exdqlm::regMod(as.numeric(nino_ts), m0 = 1, C0 = 1)
    model_w_reg <- model + reg_comp

    n_samp <- as.integer(cfg_profile$ex3$n_samp)
    tol <- as.numeric(cfg_profile$ex3$tol)
    lambda_grid <- as.numeric(cfg_profile$ex3$lambda_grid)
    diag_ref_samp <- seeded_rnorm(length(y_log), seed_value + 301L)

    ex3_models <- load_or_fit_cache("ex3_models_ldvb_v5_monthly_usgs_nino_df099", {
      KLs_ldvb <- rep(NA_real_, length(lambda_grid))
      for (i in seq_along(lambda_grid)) {
        temp_M2_ldvb <- tryCatch(
          exdqlm::exdqlmTransferLDVB(
            y = y_log, p0 = 0.15, model = model,
            df = c(0.99, 0.99), dim.df = c(1, 6),
            X = as.numeric(nino_ts), tf.df = c(0.99), lam = lambda_grid[i],
            tf.m0 = c(0, 0),
            tf.C0 = diag(c(0.1, 0.005), 2),
            sig.init = 0.1, gam.init = -0.1,
            tol = tol, n.samp = n_samp,
            verbose = FALSE
          ),
          error = function(e) e
        )
        if (!inherits(temp_M2_ldvb, "error")) {
          temp_check_ldvb <- diagnostics_from_fit(temp_M2_ldvb, plot = FALSE, ref = diag_ref_samp, y_data = y_log)
          KLs_ldvb[i] <- temp_check_ldvb$m1.KL
        }
      }
      lambda_star_ldvb <- if (any(is.finite(KLs_ldvb))) lambda_grid[which.min(KLs_ldvb)] else NA_real_

      M1_ldvb <- tryCatch(
        exdqlm::exdqlmLDVB(
          y = y_log, p0 = 0.15, model = model_w_reg,
          df = c(0.99, 0.99, 0.99), dim.df = c(1, 6, 1),
          sig.init = 0.1, gam.init = -0.1,
          tol = tol, n.samp = n_samp,
          verbose = FALSE
        ),
        error = function(e) e
      )

      M2_ldvb <- if (is.finite(lambda_star_ldvb)) {
        tryCatch(
          exdqlm::exdqlmTransferLDVB(
            y = y_log, p0 = 0.15, model = model,
            df = c(0.99, 0.99), dim.df = c(1, 6),
            X = as.numeric(nino_ts), tf.df = c(0.99), lam = lambda_star_ldvb,
            tf.m0 = c(0, 0),
            tf.C0 = diag(c(0.1, 0.005), 2),
            sig.init = 0.1, gam.init = -0.1,
            tol = tol, n.samp = n_samp,
            verbose = FALSE
          ),
          error = function(e) e
        )
      } else {
        simpleError("No finite LDVB lambda-grid KL values; transfer-function LDVB fit skipped.")
      }

      list(
        M1 = M1_ldvb, M2 = M2_ldvb, M1_ldvb = M1_ldvb, M2_ldvb = M2_ldvb,
        model = model, model_w_reg = model_w_reg,
        lambda_grid = lambda_grid, KLs = KLs_ldvb, KLs_ldvb = KLs_ldvb,
        lambda_star = lambda_star_ldvb, lambda_star_ldvb = lambda_star_ldvb,
        n_samp = n_samp, tol = tol
      )
    }, note = "ex3_models_ldvb_v5_monthly_usgs_nino_df099")

    fit_ok <- function(x) !is.null(x) && !inherits(x, "error")
    M1 <- ex3_models$M1
    M2 <- ex3_models$M2
    M1_ldvb <- ex3_models$M1_ldvb
    M2_ldvb <- ex3_models$M2_ldvb
    lambda_grid <- ex3_models$lambda_grid
    KLs <- ex3_models$KLs
    KLs_ldvb <- ex3_models$KLs_ldvb
    lambda_star <- ex3_models$lambda_star
    lambda_star_ldvb <- ex3_models$lambda_star_ldvb
    ex3_ldvb_pair_ok <- fit_ok(M1_ldvb) && fit_ok(M2_ldvb)

    capture_output_file("ex3_run_summary.txt", {
      cat(sprintf("profile=%s\n", selected_profile))
      cat(sprintf("n.samp=%d, tol=%s\n", ex3_models$n_samp, format(ex3_models$tol)))
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
        notes = "Monthly USGS/nino34 Example 3 summary including lambda optimization table and median.kt."
      )

    capture_output_file("ex3_run_summary_ldvb.txt", {
      cat(sprintf("profile=%s\n", selected_profile))
      cat(sprintf("n.samp=%d, tol=%s\n", ex3_models$n_samp, format(ex3_models$tol)))
      cat(sprintf("lambda_star_ldvb=%s\n\n", format(lambda_star_ldvb, digits = 4)))
      cat("LDVB KL grid:\n")
      print(data.frame(lambda = lambda_grid, KL = KLs_ldvb))
      if (fit_ok(M2_ldvb)) {
        cat("\nM2_ldvb$median.kt:\n")
        print(M2_ldvb$median.kt)
      } else {
        cat("\nM2_ldvb status: failed\n")
        cat(M2_ldvb$message, "\n")
      }
      cat("\nRun times (seconds):\n")
      rt <- c()
      if (fit_ok(M1_ldvb)) rt <- c(rt, M1_ldvb = M1_ldvb$run.time)
      if (fit_ok(M2_ldvb)) rt <- c(rt, M2_ldvb = M2_ldvb$run.time)
      print(rt)
    })
      register_artifact(
        artifact_id = "ex3_run_summary_ldvb",
        artifact_type = "log",
        relative_path = "analysis/manuscript/outputs/logs/ex3_run_summary_ldvb.txt",
        manuscript_target = "new: Example 3 LDVB textual outputs",
        status = if (ex3_ldvb_pair_ok) "reproduced" else "approximate",
        notes = "LDVB monthly USGS/nino34 counterpart including lambda scan and runtime summaries."
      )

    xlim_mid <- c(1995, 2015)
    xlim_fore <- c(2017, 2021.4)

    # Preserve the monthly ts index so exdqlmPlot()/compPlot() use calendar time.
    M1$y <- y_log_ts
    M2$y <- y_log_ts
    if (fit_ok(M1_ldvb)) M1_ldvb$y <- y_log_ts
    if (fit_ok(M2_ldvb)) M2_ldvb$y <- y_log_ts

    if (need_ex3quantcomps) {
      save_png_plot("ex3quantcomps.png", {
        graphics::par(mfrow = c(3, 1))

        stats::plot.ts(y_log_ts, col = "grey70", ylim = c(1, 8), xlim = xlim_mid, ylab = "quantile 95% CrIs")
        exdqlm::exdqlmPlot(M1, add = TRUE, col = ex3_cols$m1)
        exdqlm::exdqlmPlot(M2, add = TRUE, col = ex3_cols$m2)
        graphics::legend("topleft", legend = c("M1 regression", "M2 transfer fn"), col = c(ex3_cols$m1, ex3_cols$m2), lty = 1, bty = "n")

        graphics::plot(NA, ylim = c(-2.0, 2.0), xlim = xlim_mid, ylab = "seasonal components", xlab = "time")
        exdqlm::compPlot(M1, index = 2:7, add = TRUE, col = ex3_cols$m1)
        exdqlm::compPlot(M2, index = 2:7, add = TRUE, col = ex3_cols$m2)

        graphics::plot(NA, ylim = c(-1.5, 1.5), xlim = xlim_mid, ylab = "Nino 3.4 components", xlab = "time")
        exdqlm::compPlot(M1, index = 8, add = TRUE, col = ex3_cols$m1)
        exdqlm::compPlot(M2, index = 8:9, add = TRUE, col = ex3_cols$m2)
        graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 2)
      })
      register_artifact(
        artifact_id = "fig_ex3quantcomps",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex3quantcomps.png",
        manuscript_target = "fig:ex3quant",
        status = "reproduced",
        notes = "Primary Example 3 three-panel LDVB quantile/components figure with index-window fix."
      )
    }

    if (need_ex3quantcomps_ldvb) {
      if (ex3_ldvb_pair_ok) {
        save_png_plot("ex3quantcomps_ldvb.png", {
          graphics::par(mfrow = c(3, 1))

          stats::plot.ts(y_log_ts, col = "grey70", ylim = c(1, 8), xlim = xlim_mid, ylab = "quantile 95% CrIs")
          q1_ld <- quantile_summary_from_fit(M1_ldvb, cr.percent = 0.95)
          q2_ld <- quantile_summary_from_fit(M2_ldvb, cr.percent = 0.95)
          plot_quantile_summary(q1_ld, col = ldvb_cols$m1, add = TRUE)
          plot_quantile_summary(q2_ld, col = ldvb_cols$m2, add = TRUE)
          graphics::legend("topleft", legend = c("M1 regression LD", "M2 transfer fn LD"), col = c(ldvb_cols$m1, ldvb_cols$m2), lty = 1, bty = "n")

          graphics::plot(NA, ylim = c(-2.0, 2.0), xlim = xlim_mid, ylab = "seasonal components", xlab = "time")
          c1_seas <- component_summary_from_fit(M1_ldvb, index = 2:7)
          c2_seas <- component_summary_from_fit(M2_ldvb, index = 2:7)
          plot_component_summary(c1_seas, add = TRUE, col = ldvb_cols$m1)
          plot_component_summary(c2_seas, add = TRUE, col = ldvb_cols$m2)

          graphics::plot(NA, ylim = c(-1.5, 1.5), xlim = xlim_mid, ylab = "Nino 3.4 components", xlab = "time")
          c1_cov <- component_summary_from_fit(M1_ldvb, index = 8)
          c2_cov <- component_summary_from_fit(M2_ldvb, index = 8:9)
          plot_component_summary(c1_cov, add = TRUE, col = ldvb_cols$m1)
          plot_component_summary(c2_cov, add = TRUE, col = ldvb_cols$m2)
          graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 2)
        })
        register_artifact(
          artifact_id = "fig_ex3quantcomps_ldvb",
          artifact_type = "figure",
          relative_path = "analysis/manuscript/outputs/figures/ex3quantcomps_ldvb.png",
          manuscript_target = "new: fig ex3quant LDVB counterpart",
          status = "reproduced",
          notes = "LDVB counterpart for Example 3 quantile/components plot."
        )
      } else {
        register_artifact(
          artifact_id = "fig_ex3quantcomps_ldvb",
          artifact_type = "figure",
          relative_path = "analysis/manuscript/outputs/figures/ex3quantcomps_ldvb.png",
          manuscript_target = "new: fig ex3quant LDVB counterpart",
          status = "not_reproduced",
          notes = "Missing LDVB M1/M2 fits for Example 3 quant/components."
        )
      }
    }

    if (need_ex3zetapsi) {
      save_png_plot("ex3zetapsi.png", {
        graphics::par(mfrow = c(1, 2))
        exdqlm::compPlot(M2, index = 8, col = ex3_cols$m2, add = FALSE, just.theta = TRUE)
        graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 2)
        graphics::title(expression(zeta[t]))
        exdqlm::compPlot(M2, index = 9, col = ex3_cols$m2, add = FALSE, just.theta = TRUE)
        graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 2)
        graphics::title(expression(psi[t]))
      })
      register_artifact(
        artifact_id = "fig_ex3zetapsi",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex3zetapsi.png",
        manuscript_target = "fig:ex3tftheta",
        status = "reproduced",
        notes = "Primary Example 3 LDVB transfer-function theta component plots."
      )
    }

    if (need_ex3zetapsi_ldvb) {
      if (fit_ok(M2_ldvb)) {
        save_png_plot("ex3zetapsi_ldvb.png", {
          graphics::par(mfrow = c(1, 2))
          zeta_ld <- component_summary_from_fit(M2_ldvb, index = 8, just.theta = TRUE)
          plot_component_summary(zeta_ld, col = ldvb_cols$m2, add = FALSE)
          graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 2)
          graphics::title(expression(zeta[t]))
          psi_ld <- component_summary_from_fit(M2_ldvb, index = 9, just.theta = TRUE)
          plot_component_summary(psi_ld, col = ldvb_cols$m2, add = FALSE)
          graphics::abline(h = 0, col = ex3_cols$ref, lty = 3, lwd = 2)
          graphics::title(expression(psi[t]))
        })
        register_artifact(
          artifact_id = "fig_ex3zetapsi_ldvb",
          artifact_type = "figure",
          relative_path = "analysis/manuscript/outputs/figures/ex3zetapsi_ldvb.png",
          manuscript_target = "new: fig ex3tftheta LDVB counterpart",
          status = "reproduced",
          notes = "LDVB transfer-function theta component plots."
        )
      } else {
        register_artifact(
          artifact_id = "fig_ex3zetapsi_ldvb",
          artifact_type = "figure",
          relative_path = "analysis/manuscript/outputs/figures/ex3zetapsi_ldvb.png",
          manuscript_target = "new: fig ex3tftheta LDVB counterpart",
          status = "not_reproduced",
          notes = "Missing LDVB transfer-function fit for zeta/psi plot."
        )
      }
    }

    if (need_ex3forecast) {
      save_png_plot("ex3forecast.png", {
        stats::plot.ts(y_log_ts, col = "grey70", ylim = c(1, 8), xlim = xlim_fore)
        fc1 <- exdqlm::exdqlmForecast(start.t = length(y_log) - 18, k = 18, m1 = M1, plot = FALSE)
        plot(fc1, add = TRUE, cols = c(ex3_cols$m1, ex3_cols$m1_aux))
        fc2 <- exdqlm::exdqlmForecast(start.t = length(y_log) - 18, k = 18, m1 = M2, plot = FALSE)
        plot(fc2, add = TRUE, cols = c(ex3_cols$m2, ex3_cols$m2_aux))
        vline_x <- grDevices::xy.coords(y_log_ts)$x[length(y_log_ts) - 18]
        graphics::abline(v = vline_x, col = ex3_cols$ref, lty = 5)
      })
      register_artifact(
        artifact_id = "fig_ex3forecast",
        artifact_type = "figure",
        relative_path = "analysis/manuscript/outputs/figures/ex3forecast.png",
        manuscript_target = "fig:ex3forecast",
        status = "reproduced",
        notes = "Primary Example 3 LDVB 18-step ahead forecast comparison."
      )
    }

    if (need_ex3forecast_ldvb) {
      if (ex3_ldvb_pair_ok) {
        save_png_plot("ex3forecast_ldvb.png", {
          stats::plot.ts(y_log_ts, col = "grey70", ylim = c(1, 8), xlim = xlim_fore)
          fc1_ld <- forecast_from_fit(start.t = length(y_log) - 18, k = 18, m1 = M1_ldvb, y_data = y_log, plot = FALSE)
          plot(fc1_ld, add = TRUE, cols = c(ldvb_cols$m1, ldvb_cols$m1_aux))
          fc2_ld <- forecast_from_fit(start.t = length(y_log) - 18, k = 18, m1 = M2_ldvb, y_data = y_log, plot = FALSE)
          plot(fc2_ld, add = TRUE, cols = c(ldvb_cols$m2, ldvb_cols$m2_aux))
          vline_x <- grDevices::xy.coords(y_log_ts)$x[length(y_log_ts) - 18]
          graphics::abline(v = vline_x, col = ex3_cols$ref, lty = 5)
        })
        register_artifact(
          artifact_id = "fig_ex3forecast_ldvb",
          artifact_type = "figure",
          relative_path = "analysis/manuscript/outputs/figures/ex3forecast_ldvb.png",
          manuscript_target = "new: fig ex3forecast LDVB counterpart",
          status = "reproduced",
          notes = "LDVB counterpart for the 18-step forecast figure."
        )
      } else {
        register_artifact(
          artifact_id = "fig_ex3forecast_ldvb",
          artifact_type = "figure",
          relative_path = "analysis/manuscript/outputs/figures/ex3forecast_ldvb.png",
          manuscript_target = "new: fig ex3forecast LDVB counterpart",
          status = "not_reproduced",
          notes = "Missing LDVB M1/M2 fits for Example 3 forecast."
        )
      }
    }

    if (need_ex3tables) {
      diag_3 <- diagnostics_from_fit(M1, M2, plot = FALSE, ref = diag_ref_samp, y_data = y_log)
      diag_table <- data.frame(
        model = c("M1_regression", "M2_transfer_function"),
        KL = c(diag_3$m1.KL, diag_3$m2.KL),
        CRPS = c(diag_3$m1.CRPS, diag_3$m2.CRPS),
        pplc = c(diag_3$m1.pplc, diag_3$m2.pplc),
        run_time_seconds = c(diag_3$m1.rt, diag_3$m2.rt)
      )
      save_table_csv(
        diag_table,
        filename = "ex3_diagnostics_summary.csv",
        artifact_id = "tab_ex3_diagnostics",
        manuscript_target = "tab:ex3",
        status = "reproduced",
        notes = "Primary Example 3 LDVB diagnostics table generated with manuscript diagnostics helper."
      )

      lambda_table <- data.frame(lambda = lambda_grid, KL = KLs)
      save_table_csv(
        lambda_table,
        filename = "ex3_lambda_scan_kl.csv",
        artifact_id = "tab_ex3_lambda_scan",
        manuscript_target = "Example 3 lambda selection output",
        status = "reproduced",
        notes = sprintf("Primary LDVB lambda scan; best lambda in this run=%0.3f", lambda_star)
      )

      register_note("ex3", sprintf("Best LDVB lambda by KL in this run profile: %0.3f.", lambda_star))
    }

    if (need_ex3tables_ldvb) {
      lambda_table_ldvb <- data.frame(lambda = lambda_grid, KL = KLs_ldvb)
      save_table_csv(
        lambda_table_ldvb,
        filename = "ex3_lambda_scan_kl_ldvb.csv",
        artifact_id = "tab_ex3_lambda_scan_ldvb",
        manuscript_target = "new: Example 3 lambda selection output (LDVB)",
        status = if (any(is.finite(KLs_ldvb))) "reproduced" else "not_reproduced",
        notes = if (any(is.finite(KLs_ldvb))) {
          sprintf("Best LDVB lambda in this run=%0.3f", lambda_star_ldvb)
        } else {
          "No finite LDVB KL values from lambda scan."
        }
      )

      if (ex3_ldvb_pair_ok) {
        diag_3_m1_ldvb <- diagnostics_from_fit(M1_ldvb, plot = FALSE, ref = diag_ref_samp, y_data = y_log)
        diag_3_m2_ldvb <- diagnostics_from_fit(M2_ldvb, plot = FALSE, ref = diag_ref_samp, y_data = y_log)
        diag_table_ldvb <- data.frame(
          model = c("M1_regression_ldvb", "M2_transfer_function_ldvb"),
          KL = c(diag_3_m1_ldvb$m1.KL, diag_3_m2_ldvb$m1.KL),
          CRPS = c(diag_3_m1_ldvb$m1.CRPS, diag_3_m2_ldvb$m1.CRPS),
          pplc = c(diag_3_m1_ldvb$m1.pplc, diag_3_m2_ldvb$m1.pplc),
          run_time_seconds = c(diag_3_m1_ldvb$m1.rt, diag_3_m2_ldvb$m1.rt)
        )
        save_table_csv(
          diag_table_ldvb,
          filename = "ex3_diagnostics_summary_ldvb.csv",
          artifact_id = "tab_ex3_diagnostics_ldvb",
          manuscript_target = "new: tab ex3 LDVB counterpart",
          status = "reproduced",
          notes = "LDVB counterpart diagnostics table generated with manuscript diagnostics helper."
        )
      } else {
        register_artifact(
          artifact_id = "tab_ex3_diagnostics_ldvb",
          artifact_type = "table",
          relative_path = "analysis/manuscript/outputs/tables/ex3_diagnostics_summary_ldvb.csv",
          manuscript_target = "new: tab ex3 LDVB counterpart",
          status = "not_reproduced",
          notes = "Missing LDVB M1/M2 fits for diagnostics summary."
        )
      }

      if (any(is.finite(KLs_ldvb))) {
        register_note("ex3_ldvb", sprintf("Best lambda by KL for LDVB support run: %0.3f.", lambda_star_ldvb))
      }
    }
  }

  log_msg("Example 3 (Big Tree): complete")
}
