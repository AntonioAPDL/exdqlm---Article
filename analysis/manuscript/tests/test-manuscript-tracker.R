testthat::test_that("manuscript tracker exists and has required schema", {
  testthat::expect_true(file.exists(tracker_csv))
  tr <- utils::read.csv(tracker_csv, stringsAsFactors = FALSE)
  testthat::expect_true(all(c(
    "artifact_id", "artifact_type", "relative_path",
    "manuscript_target", "status", "notes"
  ) %in% names(tr)))
  testthat::expect_gt(nrow(tr), 0)
})

testthat::test_that("core manuscript figure targets are reproduced", {
  tr <- utils::read.csv(tracker_csv, stringsAsFactors = FALSE)
  core <- c(
    "fig_ex1mcmc",
    "fig_ex1quants",
    "fig_ex2quant",
    "fig_ex2quant_ldvb",
    "fig_ex2checks",
    "fig_ex2checks_ldvb",
    "fig_ex2_gamma_posteriors",
    "fig_ex2_ldvb_diagnostics",
    "tab_ex2_diagnostics",
    "tab_ex2_diagnostics_ldvb",
    "fig_ex3data",
    "fig_ex3quantcomps",
    "fig_ex3quantcomps_ldvb",
    "fig_ex3zetapsi",
    "fig_ex3zetapsi_ldvb",
    "fig_ex3forecast",
    "fig_ex3forecast_ldvb",
    "tab_ex3_diagnostics",
    "tab_ex3_diagnostics_ldvb",
    "fig_ex4static",
    "tab_ex4static_summary"
  )

  if (!all(core %in% tr$artifact_id)) {
    testthat::skip("Tracker appears to come from a targeted run; full-core coverage check skipped.")
  }

  for (id in core) {
    row <- tr[tr$artifact_id == id, , drop = FALSE]
    testthat::expect_true(nrow(row) > 0, info = sprintf("Missing tracker row for %s", id))
    testthat::expect_true(
      all(row$status %in% c("reproduced", "approximate")),
      info = sprintf("Unexpected status for %s: %s", id, paste(unique(row$status), collapse = ", "))
    )
  }
})

testthat::test_that("optional Example 1 kernel comparison artifacts are coherent when present", {
  tr <- utils::read.csv(tracker_csv, stringsAsFactors = FALSE)
  ids <- c(
    "fig_ex1_kernel_compare",
    "tab_ex1_kernel_summary",
    "tab_ex1_kernel_chain_stability",
    "log_ex1_kernel_compare"
  )

  if (!all(ids %in% tr$artifact_id)) {
    testthat::skip("Example 1 kernel-comparison artifacts not present in this tracker run.")
  }

  for (id in ids) {
    row <- tr[tr$artifact_id == id, , drop = FALSE]
    testthat::expect_true(nrow(row) > 0, info = sprintf("Missing tracker row for %s", id))
    testthat::expect_true(
      all(row$status %in% c("reproduced", "approximate")),
      info = sprintf("Unexpected status for %s: %s", id, paste(unique(row$status), collapse = ", "))
    )
  }
})
