test_that("expected exAL figure outputs exist", {
  expected <- c(
    "exal_fig_01_al_density_by_p0.png",
    "exal_fig_02_al_cdf_by_p0.png",
    "exal_fig_03_exal_density_gamma_sweep.png",
    "exal_fig_04_exal_cdf_gamma_sweep.png",
    "exal_fig_05_exal_location_scale_density.png",
    "exal_fig_06_exal_location_scale_cdf.png",
    "exal_fig_07_gamma_bounds_region.png",
    "exal_fig_08_qexal_pexal_inversion_panels.png",
    "exal_fig_09_qexal_p0_identity.png",
    "exal_fig_10_rexal_density_overlay_3cases.png"
  )
  missing <- expected[!file.exists(file.path(figures_dir, expected))]
  expect_length(missing, 0)
})

test_that("density and cdf data are finite and valid", {
  d1 <- utils::read.csv(file.path(tables_dir, "exal_data_01_al_density_by_p0.csv"))
  d3 <- utils::read.csv(file.path(tables_dir, "exal_data_03_exal_density_gamma_sweep.csv"))
  d5 <- utils::read.csv(file.path(tables_dir, "exal_data_05_exal_location_scale_density.csv"))
  d10 <- utils::read.csv(file.path(tables_dir, "exal_data_10_rexal_density_grid.csv"))

  for (d in list(d1$density, d3$density, d5$density, d10$density_true)) {
    expect_true(all(is.finite(d)))
    expect_true(all(d >= 0))
  }

  c2 <- utils::read.csv(file.path(tables_dir, "exal_data_02_al_cdf_by_p0.csv"))
  c4 <- utils::read.csv(file.path(tables_dir, "exal_data_04_exal_cdf_gamma_sweep.csv"))
  c6 <- utils::read.csv(file.path(tables_dir, "exal_data_06_exal_location_scale_cdf.csv"))

  for (d in list(c2$cdf, c4$cdf, c6$cdf)) {
    expect_true(all(is.finite(d)))
    expect_true(all(d >= -1e-12))
    expect_true(all(d <= 1 + 1e-12))
  }
})

test_that("CDF is nondecreasing in x for grouped curves", {
  check_group_monotone <- function(df, group_cols, y_col = "cdf") {
    key <- do.call(interaction, c(df[group_cols], list(drop = TRUE)))
    spl <- split(df, key)
    for (g in spl) {
      g <- g[order(g$x), , drop = FALSE]
      dy <- diff(g[[y_col]])
      expect_true(all(dy >= -as.numeric(cfg_params$thresholds$cdf_monotonic_tol)))
    }
  }

  c2 <- utils::read.csv(file.path(tables_dir, "exal_data_02_al_cdf_by_p0.csv"))
  c4 <- utils::read.csv(file.path(tables_dir, "exal_data_04_exal_cdf_gamma_sweep.csv"))
  c6 <- utils::read.csv(file.path(tables_dir, "exal_data_06_exal_location_scale_cdf.csv"))

  check_group_monotone(c2, c("p0_label"))
  check_group_monotone(c4, c("gamma_label"))
  check_group_monotone(c6, c("case_label"))
})
