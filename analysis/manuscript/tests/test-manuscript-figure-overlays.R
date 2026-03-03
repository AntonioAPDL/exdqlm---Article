testthat::test_that("key figure overlays are present (color checks)", {
  testthat::skip_if_not_installed("png")

  read_img <- function(rel) {
    p <- file.path(repo_root, rel)
    if (!file.exists(p)) return(NULL)
    png::readPNG(p)
  }

  count_near_color <- function(img, rgb, tol = 0.20) {
    if (is.null(img) || length(dim(img)) < 3L) return(0L)
    r <- img[, , 1]
    g <- img[, , 2]
    b <- img[, , 3]
    sum(abs(r - rgb[1]) <= tol & abs(g - rgb[2]) <= tol & abs(b - rgb[3]) <= tol)
  }

  blue <- c(0, 0, 1)
  red <- c(1, 0, 0)
  purple <- c(160/255, 32/255, 240/255)
  forestgreen <- c(34/255, 139/255, 34/255)
  darkorange <- c(1, 140/255, 0)
  ldvb_m1 <- c(230/255, 159/255, 0)
  ldvb_m2 <- c(0, 114/255, 178/255)

  ex1q <- read_img("analysis/manuscript/outputs/figures/ex1quants.png")
  if (!is.null(ex1q)) {
    testthat::expect_gt(count_near_color(ex1q, purple), 60)
    testthat::expect_gt(count_near_color(ex1q, blue), 60)
    testthat::expect_gt(count_near_color(ex1q, forestgreen), 60)
  }

  ex2q <- read_img("analysis/manuscript/outputs/figures/ex2quant.png")
  if (!is.null(ex2q)) {
    testthat::expect_gt(count_near_color(ex2q, red), 40)
    testthat::expect_gt(count_near_color(ex2q, blue), 40)
  }

  ex2v <- read_img("analysis/manuscript/outputs/figures/ex2_isvb_ldvb_compare.png")
  if (!is.null(ex2v)) {
    testthat::expect_gt(count_near_color(ex2v, blue), 40)
    testthat::expect_gt(count_near_color(ex2v, darkorange), 20)
  }

  ex2d <- read_img("analysis/manuscript/outputs/figures/ex2_ldvb_diagnostics.png")
  if (!is.null(ex2d)) {
    testthat::expect_gt(count_near_color(ex2d, blue), 20)
    testthat::expect_gt(count_near_color(ex2d, darkorange), 40)
  }

  ex2g <- read_img("analysis/manuscript/outputs/figures/ex2_gamma_posteriors.png")
  if (!is.null(ex2g)) {
    testthat::expect_gt(count_near_color(ex2g, blue), 20)
    testthat::expect_gt(count_near_color(ex2g, darkorange), 20)
  }

  ex2q_ld <- read_img("analysis/manuscript/outputs/figures/ex2quant_ldvb.png")
  if (!is.null(ex2q_ld)) {
    testthat::expect_gt(count_near_color(ex2q_ld, ldvb_m1), 30)
    testthat::expect_gt(count_near_color(ex2q_ld, ldvb_m2), 20)
  }

  ex2c_ld <- read_img("analysis/manuscript/outputs/figures/ex2checks_ldvb.png")
  if (!is.null(ex2c_ld)) {
    testthat::expect_gt(count_near_color(ex2c_ld, ldvb_m1), 20)
    testthat::expect_gt(count_near_color(ex2c_ld, ldvb_m2), 20)
  }

  ex3q <- read_img("analysis/manuscript/outputs/figures/ex3quantcomps.png")
  if (!is.null(ex3q)) {
    testthat::expect_gt(count_near_color(ex3q, purple), 40)
    testthat::expect_gt(count_near_color(ex3q, forestgreen), 40)
  }

  ex3f <- read_img("analysis/manuscript/outputs/figures/ex3forecast.png")
  if (!is.null(ex3f)) {
    testthat::expect_gt(count_near_color(ex3f, purple), 40)
    testthat::expect_gt(count_near_color(ex3f, forestgreen), 40)
  }

  ex3q_ld <- read_img("analysis/manuscript/outputs/figures/ex3quantcomps_ldvb.png")
  if (!is.null(ex3q_ld)) {
    testthat::expect_gt(count_near_color(ex3q_ld, ldvb_m1), 30)
    testthat::expect_gt(count_near_color(ex3q_ld, ldvb_m2), 20)
  }

  ex3z_ld <- read_img("analysis/manuscript/outputs/figures/ex3zetapsi_ldvb.png")
  if (!is.null(ex3z_ld)) {
    testthat::expect_gt(count_near_color(ex3z_ld, ldvb_m2), 20)
  }

  ex3f_ld <- read_img("analysis/manuscript/outputs/figures/ex3forecast_ldvb.png")
  if (!is.null(ex3f_ld)) {
    testthat::expect_gt(count_near_color(ex3f_ld, ldvb_m1), 30)
    testthat::expect_gt(count_near_color(ex3f_ld, ldvb_m2), 20)
  }
})
