inversion_path <- file.path(tables_dir, "exal_data_08_qexal_pexal_inversion.csv")
identity_path <- file.path(tables_dir, "exal_data_09_qexal_p0_identity.csv")
sampling_path <- file.path(tables_dir, "exal_data_10_sampling_quantiles.csv")

if (!file.exists(inversion_path) || !file.exists(identity_path) || !file.exists(sampling_path)) {
  stop("Required intermediate tables are missing before summary table generation.", call. = FALSE)
}

inv <- utils::read.csv(inversion_path, stringsAsFactors = FALSE)
idn <- utils::read.csv(identity_path, stringsAsFactors = FALSE)
sam <- utils::read.csv(sampling_path, stringsAsFactors = FALSE)

inv_summary <- do.call(rbind, lapply(split(inv, inv$case_label), function(d) {
  data.frame(
    case_label = d$case_label[[1]],
    p0 = d$p0[[1]],
    gamma = d$gamma[[1]],
    mu = d$mu[[1]],
    sigma = d$sigma[[1]],
    max_abs_error = max(abs(d$abs_error), na.rm = TRUE),
    mean_abs_error = mean(abs(d$abs_error), na.rm = TRUE),
    rmse = sqrt(mean((d$p_recovered - d$p)^2, na.rm = TRUE)),
    stringsAsFactors = FALSE
  )
}))

sam_summary <- do.call(rbind, lapply(split(sam, sam$case_label), function(d) {
  data.frame(
    case_label = d$case_label[[1]],
    p0 = d$p0[[1]],
    gamma = d$gamma[[1]],
    mu = d$mu[[1]],
    sigma = d$sigma[[1]],
    max_abs_error = max(abs(d$abs_error), na.rm = TRUE),
    mean_abs_error = mean(abs(d$abs_error), na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))

identity_summary <- data.frame(
  max_abs_error = max(idn$abs_error, na.rm = TRUE),
  mean_abs_error = mean(idn$abs_error, na.rm = TRUE),
  threshold = as.numeric(cfg_params$thresholds$identity_abs_error),
  stringsAsFactors = FALSE
)

save_table_file(
  inv_summary,
  filename = "exal_tab_01_inversion_error_summary.csv",
  description = "Case-wise inversion error summary for qexal->pexal checks"
)

save_table_file(
  sam_summary,
  filename = "exal_tab_03_sampling_fit_summary.csv",
  description = "Case-wise sampling quantile fit summary"
)

save_table_file(
  identity_summary,
  filename = "exal_data_11_identity_summary.csv",
  description = "Identity-check summary metrics"
)

fig_files <- list.files(figures_dir, pattern = "^exal_fig_.*\\.png$", full.names = TRUE)
if (nrow(figure_registry) == 0L) {
  figure_registry <- data.frame(
    file = basename(fig_files),
    description = "",
    section = "exAL",
    main_text_candidate = FALSE,
    stringsAsFactors = FALSE
  )
}

manifest <- merge(
  figure_registry,
  data.frame(
    file = basename(fig_files),
    bytes = as.integer(file.info(fig_files)$size),
    md5 = unname(tools::md5sum(fig_files)),
    stringsAsFactors = FALSE
  ),
  by = "file",
  all.x = TRUE,
  sort = FALSE
)

save_table_file(
  manifest,
  filename = "exal_figure_manifest.csv",
  description = "Figure manifest with metadata, size, and hash"
)

save_table_file(
  table_registry,
  filename = "exal_table_manifest.csv",
  description = "Table manifest for generated exAL outputs"
)
