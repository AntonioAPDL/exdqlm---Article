prep <- cache_read("ex3_monthly_prep.rds")
fit_summary <- utils::read.csv(file.path(table_dir, "ex3_monthly_fit_summary.csv"), stringsAsFactors = FALSE)
diag_summary <- utils::read.csv(file.path(table_dir, "ex3_monthly_fit_diagnostics.csv"), stringsAsFactors = FALSE)
window_summary <- utils::read.csv(file.path(table_dir, "ex3_monthly_data_window_summary.csv"), stringsAsFactors = FALSE)
response_summary <- utils::read.csv(file.path(table_dir, "ex3_monthly_response_summary.csv"), stringsAsFactors = FALSE)
lambda_screen_path <- file.path(table_dir, "ex3_monthly_lambda_screen.csv")
lambda_summary <- if (file.exists(lambda_screen_path)) {
  utils::read.csv(lambda_screen_path, stringsAsFactors = FALSE)
} else {
  NULL
}

manifest_lines <- c(
  "# Example 3 Monthly Sandbox Manifest",
  "",
  sprintf("- config path: `%s`", config_path),
  sprintf("- output tag: `%s`", config_tag),
  sprintf("- article repo snapshot at rerun: `%s`", git_ref(repo_root)),
  sprintf("- package repo snapshot at rerun: `%s`", git_ref(pkg_path)),
  sprintf("- staged daily data path: `%s`", daily_input_path),
  sprintf("- staged daily data sha256: `%s`", sha256_file(daily_input_path)),
  sprintf("- response aggregation: `%s`", config$data$aggregation),
  sprintf("- covariate source: `%s`", prep$covariate_source),
  sprintf("- overlap window: `%s` to `%s` (%s monthly rows)",
          response_summary$overlap_start, response_summary$overlap_end, response_summary$overlap_n),
  sprintf("- modeled fit window: `%s` to `%s` (%s rows)",
          response_summary$fit_start_modeled, response_summary$fit_end_modeled, response_summary$fit_n_modeled),
  sprintf("- response transform: `%s`", config$data$response_transform),
  sprintf("- quantiles: `%s`", paste(config$model$p_levels, collapse = ", ")),
  sprintf("- available covariates (%s): `%s`",
          window_summary$n_available_covariates, window_summary$available_covariates),
  sprintf("- feature base terms: `%s`", window_summary$base_feature_terms),
  sprintf("- feature lag terms: `%s`", window_summary$lag_feature_terms),
  sprintf("- feature lag months: `%s`", window_summary$feature_lag_months),
  sprintf("- transfer lambda grid: `%s`", paste(transfer_lambda_grid(), collapse = ", ")),
  sprintf("- transfer lambda selection metric: `%s`", transfer_selection_metric()),
  sprintf("- LDVB settings: tol=%s, n.samp=%s, max_iter=%s, gam.init=%s, sig.init=%s",
          config$model$ldvb$tol, config$model$ldvb$n_samp,
          config$model$ldvb$max_iter,
          config$model$ldvb$gam_init, config$model$ldvb$sig_init),
  sprintf("- discounts: trend=%s | harmonics=%s | covariates=%s",
          config$model$discounts$trend,
          paste(config$model$discounts$harmonics, collapse = ", "),
          config$model$discounts$covariates),
  sprintf("- transfer settings: lam=%s | tf.df=%s",
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
  sprintf("- p0=%s | %s | status=%s | iter=%s | converged=%s | hit_iter_cap=%s | runtime=%s | selected_lambda=%s | median.kt=%s",
          row[["p0"]], row[["model"]], row[["status"]], row[["iter"]],
          row[["converged"]], row[["hit_iter_cap"]], row[["runtime"]],
          row[["selected_lambda"]], row[["median_kt"]])
})

diagnostic_lines <- c("", "## Diagnostics snapshot", "")
diagnostic_lines <- c(
  diagnostic_lines,
  apply(diag_summary, 1, function(row) {
    sprintf("- p0=%s | %s | KL=%s | CRPS=%s | pplc=%s | runtime=%s",
            row[["p0"]], row[["model"]], row[["KL"]], row[["CRPS"]], row[["pplc"]], row[["runtime"]])
  })
)

lambda_lines <- character()
if (!is.null(lambda_summary) && nrow(lambda_summary)) {
  lambda_lines <- c("", "## Lambda screen snapshot", "")
  lambda_lines <- c(
    lambda_lines,
    apply(lambda_summary, 1, function(row) {
      sprintf("- p0=%s | lambda=%s | KL=%s | CRPS=%s | pplc=%s | metric=%s | metric_value=%s | runtime=%s | status=%s",
              row[["p0"]], row[["lambda"]], row[["KL"]], row[["CRPS"]], row[["pplc"]],
              row[["selection_metric"]], row[["selection_value"]], row[["runtime"]], row[["status"]])
    })
  )
}

write_text(c(manifest_lines, status_lines, diagnostic_lines, lambda_lines), "ex3_monthly_manifest.md")
log_progress("manifest_written | ex3_monthly_manifest.md")
