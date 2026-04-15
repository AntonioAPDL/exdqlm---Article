prep <- cache_read("ex3_monthly_prep.rds")
fit_summary <- utils::read.csv(file.path(table_dir, "ex3_monthly_fit_summary.csv"), stringsAsFactors = FALSE)
diag_summary <- utils::read.csv(file.path(table_dir, "ex3_monthly_fit_diagnostics.csv"), stringsAsFactors = FALSE)
bt_summary <- utils::read.csv(file.path(table_dir, "ex3_monthly_btflow_comparison.csv"), stringsAsFactors = FALSE)

manifest_lines <- c(
  "# Example 3 Monthly Nino34 Contrast Manifest",
  "",
  sprintf("- config path: `%s`", config_path),
  sprintf("- output tag: `%s`", config_tag),
  sprintf("- article repo snapshot at rerun: `%s`", git_ref(repo_root)),
  sprintf("- package repo snapshot at rerun: `%s`", git_ref(pkg_path)),
  sprintf("- staged daily data path: `%s`", daily_input_path),
  sprintf("- staged daily data sha256: `%s`", sha256_file(daily_input_path)),
  sprintf("- response aggregation: `%s`", config$data$aggregation),
  sprintf("- overlap window: `%s` to `%s` (%s monthly rows)", bt_summary$overlap_start, bt_summary$overlap_end, bt_summary$overlap_n),
  sprintf("- modeled fit window: `%s` to `%s` (%s rows)", bt_summary$fit_start_modeled, bt_summary$fit_end_modeled, bt_summary$fit_n_modeled),
  sprintf("- response transform: `%s`", config$data$response_transform),
  sprintf("- quantiles: `%s`", paste(config$model$p_levels, collapse = ", ")),
  sprintf("- feature base terms: `%s`", paste(feature_base_terms(), collapse = ", ")),
  sprintf("- feature lag terms: `%s`", paste(feature_lag_terms(), collapse = ", ")),
  sprintf("- feature lag months: `%s`", paste(feature_lag_months(), collapse = ", ")),
  sprintf("- LDVB settings: tol=%s, n.samp=%s, max_iter=%s, gam.init=%s, sig.init=%s",
          config$model$ldvb$tol, config$model$ldvb$n_samp,
          config$model$ldvb$max_iter,
          config$model$ldvb$gam_init, config$model$ldvb$sig_init),
  sprintf("- transfer settings: lam=%s, tf.df=%s",
          config$model$transfer$lam, paste(config$model$transfer$tf_df, collapse = ", ")),
  sprintf("- BTflow comparison: corr_raw=%s, corr_log=%s, max_abs_diff=%s",
          bt_summary$corr_raw, bt_summary$corr_log, bt_summary$max_abs_diff),
  "",
  "## Output files",
  "",
  paste0("- figures: ", paste(sort(list.files(figure_dir)), collapse = ", ")),
  paste0("- tables: ", paste(sort(list.files(table_dir)), collapse = ", ")),
  "",
  "## Fit status snapshot",
  ""
)

status_lines <- apply(fit_summary, 1, function(row) {
  sprintf("- p0=%s | %s | status=%s | iter=%s | converged=%s | hit_iter_cap=%s | runtime=%s | median.kt=%s",
          row[["p0"]], row[["model"]], row[["status"]], row[["iter"]],
          row[["converged"]], row[["hit_iter_cap"]], row[["runtime"]], row[["median_kt"]])
})

diagnostic_lines <- c("", "## Diagnostics snapshot", "")
diagnostic_lines <- c(
  diagnostic_lines,
  apply(diag_summary, 1, function(row) {
    sprintf("- p0=%s | %s | KL=%s | CRPS=%s | pplc=%s | runtime=%s",
            row[["p0"]], row[["model"]], row[["KL"]], row[["CRPS"]], row[["pplc"]], row[["runtime"]])
  })
)

write_text(c(manifest_lines, status_lines, diagnostic_lines), "ex3_monthly_manifest.md")
log_progress("manifest_written | ex3_monthly_manifest.md")
