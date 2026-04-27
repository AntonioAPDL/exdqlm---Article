testthat::test_that("Example 1 synthesis forecast starts at the next Lake Huron time step", {
  bridge_path <- file.path(
    repo_root,
    "analysis", "manuscript", "outputs", "tables",
    "ex1_synthesis_bridge_check.csv"
  )
  testthat::expect_true(file.exists(bridge_path))

  bridge <- utils::read.csv(bridge_path, stringsAsFactors = FALSE)
  testthat::expect_equal(nrow(bridge), 1L)
  testthat::expect_true(all(is.finite(unlist(bridge, use.names = FALSE))))
  testthat::expect_equal(bridge$time_gap, bridge$data_time_step, tolerance = 1e-10)
  testthat::expect_gt(bridge$first_forecast_time, bridge$observed_end_time)
})
