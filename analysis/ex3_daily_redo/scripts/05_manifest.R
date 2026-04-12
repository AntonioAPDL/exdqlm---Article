prep <- cache_read("ex3_daily_prep.rds")
fit_summary <- utils::read.csv(file.path(table_dir, "ex3_daily_fit_summary.csv"), stringsAsFactors = FALSE)
diag_summary <- utils::read.csv(file.path(table_dir, "ex3_daily_fit_diagnostics.csv"), stringsAsFactors = FALSE)
forecast_summary <- utils::read.csv(file.path(table_dir, "ex3_daily_forecast_summary.csv"), stringsAsFactors = FALSE)

manifest_lines <- c(
  "# Example 3 Daily Redo Manifest",
  "",
  sprintf("- config path: `%s`", config_path),
  sprintf("- output tag: `%s`", config_tag),
  sprintf("- article repo: `%s`", git_ref(repo_root)),
  sprintf("- package repo: `%s`", git_ref(pkg_path)),
  sprintf("- staged data path: `%s`", data_path),
  sprintf("- staged data sha256: `%s`", sha256_file(data_path)),
  sprintf("- fit window: `%s` to `%s` (%d rows)", prep$fit_start, prep$fit_end, nrow(prep$fit_df)),
  sprintf("- forecast window: `%s` to `%s` (%d rows)", prep$forecast_start, prep$forecast_end, nrow(prep$future_df)),
  sprintf("- response transform: `%s`", config$data$response_transform),
  sprintf("- quantiles: `%s`", paste(config$model$p_levels, collapse = ", ")),
  sprintf("- LDVB settings: tol=%s, n.samp=%s, max_iter=%s, gam.init=%s, sig.init=%s",
          config$model$ldvb$tol, config$model$ldvb$n_samp,
          config$model$ldvb$max_iter,
          config$model$ldvb$gam_init, config$model$ldvb$sig_init),
  sprintf("- transfer settings: lam=%s, tf.df=%s",
          config$model$transfer$lam, paste(config$model$transfer$tf_df, collapse = ", ")),
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

forecast_lines <- c("", "## Forecast snapshot", "")
forecast_lines <- c(
  forecast_lines,
  apply(forecast_summary, 1, function(row) {
    sprintf("- p0=%s | %s | mean_check_loss=%s | mean_abs_error=%s",
            row[["p0"]], row[["model"]], row[["mean_check_loss"]], row[["mean_abs_error"]])
  })
)

write_text(c(manifest_lines, status_lines, diagnostic_lines, forecast_lines), "ex3_daily_manifest.md")
