test_that("rexal sampling quantile diagnostics are within threshold", {
  sam <- utils::read.csv(file.path(tables_dir, "exal_data_10_sampling_quantiles.csv"))
  thr <- as.numeric(cfg_params$thresholds$sampling_q_error)

  expect_true(nrow(sam) > 0)
  expect_true(all(is.finite(sam$sample_q)))
  expect_true(all(is.finite(sam$theory_q)))
  expect_true(all(is.finite(sam$abs_error)))
  expect_lte(max(sam$abs_error), thr)
})

test_that("sampling summary table exists and has expected columns", {
  tab <- utils::read.csv(file.path(tables_dir, "exal_tab_03_sampling_fit_summary.csv"))
  needed <- c("case_label", "max_abs_error", "mean_abs_error")
  expect_true(all(needed %in% names(tab)))
  expect_true(all(is.finite(tab$max_abs_error)))
})
