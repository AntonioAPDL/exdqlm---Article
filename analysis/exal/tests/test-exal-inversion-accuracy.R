test_that("qexal->pexal inversion meets configured accuracy threshold", {
  inv <- utils::read.csv(file.path(tables_dir, "exal_data_08_qexal_pexal_inversion.csv"))
  thr <- as.numeric(cfg_params$thresholds$inversion_max_abs_error)

  expect_true(all(is.finite(inv$abs_error)))
  expect_lte(max(inv$abs_error), thr)

  by_case <- aggregate(abs_error ~ case_label, data = inv, FUN = max)
  expect_true(all(by_case$abs_error <= thr))
})

test_that("summary inversion table exists and is internally consistent", {
  tab <- utils::read.csv(file.path(tables_dir, "exal_tab_01_inversion_error_summary.csv"))
  expect_true(nrow(tab) >= 1)
  expect_true(all(is.finite(tab$max_abs_error)))
  expect_true(all(tab$max_abs_error >= 0))
  expect_true(all(is.finite(tab$rmse)))
})

test_that("qexal(p0) identity check is within configured threshold", {
  idn <- utils::read.csv(file.path(tables_dir, "exal_data_09_qexal_p0_identity.csv"))
  thr <- as.numeric(cfg_params$thresholds$identity_abs_error)

  expect_true(all(is.finite(idn$abs_error)))
  expect_lte(max(idn$abs_error), thr)
})
