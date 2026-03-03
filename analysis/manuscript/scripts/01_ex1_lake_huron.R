log_msg("Example 1 (Lake Huron): start")

y <- as.numeric(datasets::LakeHuron)
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

M95 <- exdqlm::exdqlmMCMC(
  y = y, p0 = 0.95, model = model,
  df = 0.9, dim.df = 2,
  fix.sigma = TRUE, sig.init = 0.07,
  PriorGamma = list(m_gam = -1, s_gam = 0.1, df_gam = 1),
  n.burn = nburn, n.mcmc = nmcmc,
  verbose = FALSE
)

M50 <- exdqlm::exdqlmMCMC(
  y = y, p0 = 0.50, model = model,
  df = 0.9, dim.df = 2,
  fix.sigma = TRUE, sig.init = 0.4,
  PriorGamma = list(m_gam = 0, s_gam = 0.1, df_gam = 1),
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

# Refit median as DQLM equivalent (gamma fixed at zero) per manuscript flow.
M50_dqlm <- exdqlm::exdqlmMCMC(
  y = y, p0 = 0.50, model = model,
  df = 0.9, dim.df = 2,
  fix.sigma = TRUE, sig.init = 0.4,
  gam.init = 0, fix.gamma = TRUE,
  n.burn = nburn, n.mcmc = nmcmc,
  verbose = FALSE
)

capture_output_file("ex1_run_summary.txt", {
  cat(sprintf("profile=%s\n", selected_profile))
  cat(sprintf("n.burn=%d, n.mcmc=%d\n\n", nburn, nmcmc))
  cat("M50 gamma summary (free gamma):\n")
  print(summary(M50$samp.gamma))
  cat("\nM50_dqlm gamma fixed:\n")
  print(unique(as.numeric(M50_dqlm$samp.gamma)))
  cat("\nRun times (seconds):\n")
  print(c(M95 = M95$run.time, M50 = M50$run.time, M5 = M5$run.time, M50_dqlm = M50_dqlm$run.time))
})
register_artifact(
  artifact_id = "ex1_run_summary",
  artifact_type = "log",
  relative_path = "analysis/manuscript/outputs/logs/ex1_run_summary.txt",
  manuscript_target = "Example 1 textual outputs",
  status = "reproduced",
  notes = "Compact output equivalents of console summaries."
)

save_png_plot("ex1mcmc.png", {
  graphics::par(mfcol = c(1, 2))
  coda::traceplot(M50$samp.gamma, main = "")
  coda::densplot(M50$samp.gamma, main = "")
})
register_artifact(
  artifact_id = "fig_ex1mcmc",
  artifact_type = "figure",
  relative_path = "analysis/manuscript/outputs/figures/ex1mcmc.png",
  manuscript_target = "fig:ex1mcmc",
  status = "reproduced",
  notes = "Trace and density plot from MCMC median model."
)

save_png_plot("ex1quants.png", {
  graphics::par(mfcol = c(1, 2))

  exdqlm::exdqlmPlot(M95)
  exdqlm::exdqlmPlot(M50_dqlm, add = TRUE, col = "blue")
  exdqlm::exdqlmPlot(M5, add = TRUE, col = "forestgreen")
  graphics::legend(
    "topright",
    lty = 1, col = c("purple", "blue", "forestgreen"),
    legend = c(expression("p"[0] == 0.95), expression("p"[0] == 0.50), expression("p"[0] == 0.05))
  )

  fFF <- model$FF
  fGG <- model$GG
  stats::plot.ts(y, xlim = c(1952, 1980), ylim = c(575, 581), col = "dark grey")
  exdqlm::exdqlmForecast(start.t = length(y), k = 8, m1 = M95, fFF = fFF, fGG = fGG, plot = TRUE, add = TRUE)
  exdqlm::exdqlmForecast(start.t = length(y), k = 8, m1 = M50_dqlm, fFF = fFF, fGG = fGG, plot = TRUE, add = TRUE, cols = c("blue", "lightblue"))
  exdqlm::exdqlmForecast(start.t = length(y), k = 8, m1 = M5, fFF = fFF, fGG = fGG, plot = TRUE, add = TRUE, cols = c("forestgreen", "green"))
})
register_artifact(
  artifact_id = "fig_ex1quants",
  artifact_type = "figure",
  relative_path = "analysis/manuscript/outputs/figures/ex1quants.png",
  manuscript_target = "fig:ex1quants",
  status = "reproduced",
  notes = "Two-panel quantile and forecast figure with updated helper signatures."
)

ex1_runtime <- data.frame(
  model = c("M95", "M50", "M5", "M50_dqlm"),
  run_time_seconds = c(M95$run.time, M50$run.time, M5$run.time, M50_dqlm$run.time)
)
save_table_csv(
  ex1_runtime,
  filename = "ex1_runtime_summary.csv",
  artifact_id = "tab_ex1_runtime",
  manuscript_target = "Example 1 runtime statements",
  status = "approximate",
  notes = "Runtimes vary by hardware/profile; values are reproducible for the configured profile."
)

register_note("ex1", "Lake Huron figures reproduced with updated APIs; exact run-times not expected to match manuscript timestamps.")

log_msg("Example 1 (Lake Huron): complete")
