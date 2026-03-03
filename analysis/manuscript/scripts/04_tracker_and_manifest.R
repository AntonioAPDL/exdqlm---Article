log_msg("Manuscript tracker: start")

expected_targets <- data.frame(
  artifact_id = c(
    "fig_ex1mcmc",
    "fig_ex1quants",
    "fig_ex2quant",
    "fig_ex2checks",
    "fig_ex2_isvb_ldvb_compare",
    "fig_ex3data",
    "fig_ex3quantcomps",
    "fig_ex3zetapsi",
    "fig_ex3forecast",
    "tab_ex3_diagnostics"
  ),
  manuscript_target = c(
    "fig:ex1mcmc",
    "fig:ex1quants",
    "fig:ex2quant",
    "fig:ex2checks",
    "new: ISVB vs LDVB dynamic comparison",
    "fig:ex3data",
    "fig:ex3quant",
    "fig:ex3tftheta",
    "fig:ex3forecast",
    "tab:ex3"
  ),
  stringsAsFactors = FALSE
)

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

register_note("coverage", "All main manuscript example figures were targeted in this pipeline.")
register_note("timing", "Exact runtime printouts in manuscript are historical and expected to differ.")
register_note("scope", "Main manuscript .tex was not modified; all updates are isolated under analysis/manuscript.")

write_tracker()

log_msg("Manuscript tracker: complete")
