log_g_ref <- function(gamma) {
  log(2) + stats::pnorm(-abs(gamma), log.p = TRUE) + 0.5 * gamma^2
}

test_that("get_gamma_bounds returns finite ordered intervals", {
  p0s <- c(0.001, 0.01, 0.1, 0.5, 0.9, 0.99, 0.999)
  for (p0 in p0s) {
    b <- exdqlm::get_gamma_bounds(p0)
    L <- as.numeric(b[["L"]])
    U <- as.numeric(b[["U"]])

    expect_true(is.finite(L) && is.finite(U))
    expect_lt(L, U)
    expect_lte(L, 0)
    expect_gte(U, 0)

    # Equation residual checks are strict only in moderate p0 regions.
    if (p0 >= 0.1 && p0 <= 0.9) {
      expect_lt(abs(log_g_ref(L) - log1p(-p0)), 1e-3)
      expect_lt(abs(log_g_ref(U) - log(p0)), 1e-3)
    }
  }
})

test_that("gamma bounds table exists and is sane on full grid", {
  tab <- utils::read.csv(file.path(tables_dir, "exal_tab_02_gamma_bounds_reference_grid.csv"))
  expect_true(nrow(tab) >= 50)
  expect_true(all(is.finite(tab$L)))
  expect_true(all(is.finite(tab$U)))
  expect_true(all(tab$L < tab$U))
  expect_true(all(tab$L <= 0))
  expect_true(all(tab$U >= 0))
})
