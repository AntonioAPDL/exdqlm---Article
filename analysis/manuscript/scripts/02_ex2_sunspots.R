log_msg("Example 2 (Sunspots): start")

y <- as.numeric(datasets::sunspot.year)
y_ts <- datasets::sunspot.year

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

save_png_plot("ex2quant.png", {
  graphics::par(mfrow = c(1, 3))
  stats::plot.ts(y_ts, col = "darkgrey", ylab = "sunspot count")

  stats::plot.ts(y_ts, xlim = c(1750, 1850), col = "darkgrey", ylab = "quantile 95% CrIs")
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

save_png_plot("ex2checks.png", {
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

if (!inherits(M2_ldvb, "error")) {
  save_png_plot("ex2_isvb_ldvb_compare.png", {
    graphics::par(mfrow = c(1, 2))

    stats::plot.ts(y_ts, xlim = c(1750, 1850), col = "grey70", ylab = "quantile 95% CrIs")
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

    d_isvb <- stats::density(as.numeric(M2$samp.gamma))
    d_ldvb <- stats::density(as.numeric(M2_ldvb$samp.gamma))
    graphics::plot(d_isvb, col = "blue", lwd = 2, main = "", xlab = expression(gamma), ylab = "Density")
    graphics::lines(d_ldvb, col = "darkorange", lwd = 2)
    graphics::legend("topright", legend = c("ISVB", "LDVB"), col = c("blue", "darkorange"), lty = 1, lwd = 2, bty = "n")
  })
  register_artifact(
    artifact_id = "fig_ex2_isvb_ldvb_compare",
    artifact_type = "figure",
    relative_path = "analysis/manuscript/outputs/figures/ex2_isvb_ldvb_compare.png",
    manuscript_target = "new: ISVB vs LDVB dynamic comparison",
    status = "reproduced",
    notes = "Requested additional dynamic comparison using LDVB counterpart."
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

log_msg("Example 2 (Sunspots): complete")
