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
    "fig_ex2checks",
    "fig_ex3data",
    "fig_ex3quantcomps",
    "fig_ex3zetapsi",
    "fig_ex3forecast",
    "tab_ex3_diagnostics"
  )

  for (id in core) {
    row <- tr[tr$artifact_id == id, , drop = FALSE]
    testthat::expect_true(nrow(row) > 0, info = sprintf("Missing tracker row for %s", id))
    testthat::expect_true(
      all(row$status %in% c("reproduced", "approximate")),
      info = sprintf("Unexpected status for %s: %s", id, paste(unique(row$status), collapse = ", "))
    )
  }
})
