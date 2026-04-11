log_msg("Manuscript tracker: start")

expected_targets <- data.frame(
  artifact_id = c(
    "fig_ex1mcmc",
    "fig_ex1quants",
    "fig_ex2quant",
    "fig_ex2checks",
    "tab_ex2_dynamic_benchmark",
    "fig_ex3data",
    "fig_ex3quantcomps",
    "fig_ex3zetapsi",
    "fig_ex3forecast",
    "tab_ex3_diagnostics",
    "fig_ex4static",
    "tab_ex4static_summary"
  ),
  manuscript_target = c(
    "fig:ex1mcmc",
    "fig:ex1quants",
    "fig:ex2quant",
    "fig:ex2checks",
    "tab:ex2bench",
    "fig:ex3data",
    "fig:ex3quant",
    "fig:ex3tftheta",
    "fig:ex3forecast",
    "tab:ex3",
    "fig:ex4static",
    "new: Example 4 static simulation summary"
  ),
  stringsAsFactors = FALSE
)

if (targeted_run) {
  target_map <- list(
    ex1 = c("fig_ex1mcmc", "fig_ex1quants", "tab_ex1_runtime"),
    ex1mcmc = c("fig_ex1mcmc"),
    ex1quants = c("fig_ex1quants"),
    ex1synth = c("fig_ex1synth", "log_ex1_synthesis_summary"),
    ex1kernel = c("fig_ex1_kernel_compare", "tab_ex1_kernel_summary", "tab_ex1_kernel_chain_stability", "log_ex1_kernel_compare"),
    ex2 = c(
      "fig_ex2quant", "fig_ex2quant_ldvb",
      "fig_ex2checks", "fig_ex2checks_ldvb",
      "tab_ex2_dynamic_benchmark",
      "fig_ex2_isvb_ldvb_compare", "fig_ex2_gamma_posteriors", "fig_ex2_ldvb_diagnostics",
      "tab_ex2_gamma_credible_intervals", "tab_ex2_diagnostics", "tab_ex2_diagnostics_ldvb",
      "tab_ex2_df_scan", "tab_ex2_df_scan_ldvb"
    ),
    ex2quant = c("fig_ex2quant"),
    ex2quant_ldvb = c("fig_ex2quant_ldvb"),
    ex2checks = c("fig_ex2checks", "tab_ex2_dynamic_benchmark"),
    ex2checks_ldvb = c("fig_ex2checks_ldvb"),
    ex2bench = c("tab_ex2_dynamic_benchmark"),
    ex2_isvb_ldvb_compare = c("fig_ex2_isvb_ldvb_compare"),
    ex2_gamma_posteriors = c("fig_ex2_gamma_posteriors", "tab_ex2_gamma_credible_intervals"),
    ex2_ldvb_diagnostics = c("fig_ex2_ldvb_diagnostics"),
    ex2tables = c("tab_ex2_diagnostics", "tab_ex2_df_scan"),
    ex2tables_ldvb = c("tab_ex2_diagnostics_ldvb", "tab_ex2_df_scan_ldvb"),
    ex3 = c(
      "fig_ex3data",
      "fig_ex3quantcomps", "fig_ex3quantcomps_ldvb",
      "fig_ex3zetapsi", "fig_ex3zetapsi_ldvb",
      "fig_ex3forecast", "fig_ex3forecast_ldvb",
      "tab_ex3_diagnostics", "tab_ex3_diagnostics_ldvb",
      "tab_ex3_lambda_scan", "tab_ex3_lambda_scan_ldvb"
    ),
    ex3data = c("fig_ex3data"),
    ex3quantcomps = c("fig_ex3quantcomps"),
    ex3quantcomps_ldvb = c("fig_ex3quantcomps_ldvb"),
    ex3zetapsi = c("fig_ex3zetapsi"),
    ex3zetapsi_ldvb = c("fig_ex3zetapsi_ldvb"),
    ex3forecast = c("fig_ex3forecast"),
    ex3forecast_ldvb = c("fig_ex3forecast_ldvb"),
    ex3tables = c("tab_ex3_diagnostics", "tab_ex3_lambda_scan"),
    ex3tables_ldvb = c("tab_ex3_diagnostics_ldvb", "tab_ex3_lambda_scan_ldvb"),
    ex4screen = c("tab_ex4_seed_screen_summary", "tab_ex4_seed_screen_selection", "log_ex4_seed_screen_summary"),
    ex4 = c("fig_ex4static", "tab_ex4static_summary"),
    ex4figure = c("fig_ex4static"),
    ex4table = c("tab_ex4static_summary")
  )
  exp_ids <- unique(unlist(target_map[intersect(names(target_map), targets)], use.names = FALSE))
  if (length(exp_ids) > 0L) {
    expected_targets <- expected_targets[expected_targets$artifact_id %in% exp_ids, , drop = FALSE]
  } else {
    expected_targets <- expected_targets[0, , drop = FALSE]
  }

  if ("ex1kernel" %in% targets) {
    expected_targets <- rbind(
      expected_targets,
      data.frame(
        artifact_id = c(
          "fig_ex1_kernel_compare",
          "tab_ex1_kernel_summary",
          "tab_ex1_kernel_chain_stability",
          "log_ex1_kernel_compare"
        ),
        manuscript_target = c(
          "support: Example 1 slice vs laplace_rw kernel comparison",
          "support: Example 1 kernel summary",
          "support: Example 1 kernel chain stability",
          "support: Example 1 kernel comparison summary"
        ),
        stringsAsFactors = FALSE
      )
    )
  }

  if ("ex4screen" %in% targets) {
    expected_targets <- rbind(
      expected_targets,
      data.frame(
        artifact_id = c(
          "tab_ex4_seed_screen_summary",
          "tab_ex4_seed_screen_selection",
          "log_ex4_seed_screen_summary"
        ),
        manuscript_target = c(
          "support: Example 4 seed screen metrics",
          "support: Example 4 seed screen selection",
          "support: Example 4 seed screen summary"
        ),
        stringsAsFactors = FALSE
      )
    )
  }
}

for (i in seq_len(nrow(expected_targets))) {
  id <- expected_targets$artifact_id[i]
  if (!any(artifact_registry$artifact_id == id)) {
    artifact_registry <<- rbind(
      artifact_registry,
      data.frame(
        artifact_id = id,
        artifact_type = "unknown",
        relative_path = "",
        manuscript_target = expected_targets$manuscript_target[i],
        status = "not_reproduced",
        notes = "Artifact was expected but not registered by example scripts.",
        stringsAsFactors = FALSE
      )
    )
  }
}

if (nrow(artifact_registry) > 0L) {
  for (i in seq_len(nrow(artifact_registry))) {
    rel <- artifact_registry$relative_path[i]
    if (nzchar(rel)) {
      abs_path <- file.path(repo_root, rel)
      if (!file.exists(abs_path)) {
        artifact_registry$status[i] <- "not_reproduced"
        old_note <- artifact_registry$notes[i]
        artifact_registry$notes[i] <- paste(
          trimws(old_note),
          "Output file missing on disk at tracker time.",
          sep = if (nzchar(trimws(old_note))) " " else ""
        )
      }
    }
  }
}

api_map <- data.frame(
  manuscript_call = c(
    "exdqlmChecks(y = ..., M1, M2, ...)",
    "exdqlmPlot(y = ..., M1, ...)",
    "compPlot(y = ..., M1, ...)",
    "exdqlmForecast(y = ..., start.t, k, M1, ...)"
  ),
  reproduced_call = c(
    "exdqlmDiagnostics(M1, M2, ...)",
    "exdqlmPlot(M1, ...)",
    "compPlot(M1, ...)",
    "exdqlmForecast(start.t = ..., k = ..., m1 = M1, ...)"
  ),
  status = c("replaced", "replaced", "replaced", "replaced"),
  stringsAsFactors = FALSE
)
save_table_csv(
  api_map,
  filename = "manuscript_api_migration_map.csv",
  artifact_id = "tab_api_migration_map",
  manuscript_target = "global code migration",
  status = "reproduced",
  notes = "Maps deprecated manuscript calls to current package API."
)

save_table_csv(
  benchmark_profiles_table(),
  filename = "benchmark_backend_profiles.csv",
  artifact_id = "tab_benchmark_backend_profiles",
  manuscript_target = "support: benchmark backend profiles",
  status = "reproduced",
  notes = "Defines Profile A (pure-R baseline) and Profile B (manuscript-matched backend)."
)

save_table_csv(
  benchmark_environment_table(),
  filename = "benchmark_environment.csv",
  artifact_id = "tab_benchmark_environment",
  manuscript_target = "support: benchmark environment details",
  status = "reproduced",
  notes = "CPU, R version, package/article state, backend options, seeds, and dataset sizes for the tracked benchmark run."
)

if (targeted_run) {
  register_note("coverage", sprintf("Targeted run; requested targets: %s.", paste(targets, collapse = ", ")))
} else {
  register_note("coverage", "All publication-set manuscript artifacts were targeted in this pipeline.")
}
register_note("timing", "Exact runtime printouts in manuscript are historical and expected to differ.")
register_note("timing", "Runtime values depend on hardware and backend settings; the Example 4 table reflects the standard-profile reproduction run recorded here.")
register_note("benchmark", sprintf("Benchmark tables reported in the manuscript use backend Profile %s; benchmark_backend_profiles.csv defines both disclosed benchmark profiles.", selected_benchmark_profile))
register_note("benchmark", "benchmark_environment.csv records CPU, R version, package/article state, backend options, seeds, and dataset sizes for the tracked benchmark run.")
register_note("scope", "Automated reproduction outputs are isolated under analysis/manuscript; manuscript text updates are tracked separately in article4.tex.")

write_tracker()

log_msg("Manuscript tracker: complete")
