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

  rgb_hex <- function(x) as.numeric(grDevices::col2rgb(x)) / 255

  ex1_cols <- list(
    q95 = rgb_hex("#8A46B2"),
    q50 = rgb_hex("#2F6FA8"),
    q05 = rgb_hex("#2E7D5B")
  )
  ex2_cols <- list(
    dqlm = rgb_hex("#C44E52"),
    exdqlm = rgb_hex("#4C72B0")
  )
  ex3_cols <- list(
    m1 = rgb_hex("#8A46B2"),
    mreg = rgb_hex("#4C72B0"),
    m2 = rgb_hex("#2E7D5B")
  )
  ldvb_cols <- list(
    m1 = rgb_hex("#E69F00"),
    m2 = rgb_hex("#0072B2")
  )
  darkorange <- rgb_hex("darkorange")
  steelblue <- rgb_hex("steelblue")

  ex1q <- read_img("analysis/manuscript/outputs/figures/ex1quants.png")
  if (!is.null(ex1q)) {
    testthat::expect_gt(count_near_color(ex1q, ex1_cols$q95), 60)
    testthat::expect_gt(count_near_color(ex1q, ex1_cols$q50), 60)
    testthat::expect_gt(count_near_color(ex1q, ex1_cols$q05), 60)
  }

  ex2q <- read_img("analysis/manuscript/outputs/figures/ex2quant.png")
  if (!is.null(ex2q)) {
    testthat::expect_gt(count_near_color(ex2q, ex2_cols$dqlm), 40)
    testthat::expect_gt(count_near_color(ex2q, ex2_cols$exdqlm), 40)
  }

  ex2d <- read_img("analysis/manuscript/outputs/figures/ex2_ldvb_diagnostics.png")
  if (!is.null(ex2d)) {
    testthat::expect_gt(count_near_color(ex2d, steelblue), 20)
    testthat::expect_gt(count_near_color(ex2d, darkorange), 40)
  }

  ex2q_ld <- read_img("analysis/manuscript/outputs/figures/ex2quant_ldvb.png")
  if (!is.null(ex2q_ld)) {
    testthat::expect_gt(count_near_color(ex2q_ld, ex2_cols$dqlm), 30)
    testthat::expect_gt(count_near_color(ex2q_ld, ex2_cols$exdqlm), 20)
  }

  ex2c_ld <- read_img("analysis/manuscript/outputs/figures/ex2checks_ldvb.png")
  if (!is.null(ex2c_ld)) {
    testthat::expect_gt(count_near_color(ex2c_ld, ldvb_cols$m1), 20)
    testthat::expect_gt(count_near_color(ex2c_ld, ldvb_cols$m2), 20)
  }

  ex3q <- read_img("analysis/manuscript/outputs/figures/ex3quantcomps.png")
  if (!is.null(ex3q)) {
    testthat::expect_gt(count_near_color(ex3q, ex3_cols$m1), 40)
    testthat::expect_gt(count_near_color(ex3q, ex3_cols$mreg), 40)
    testthat::expect_gt(count_near_color(ex3q, ex3_cols$m2), 40)
  }

  ex3f <- read_img("analysis/manuscript/outputs/figures/ex3forecast.png")
  if (!is.null(ex3f)) {
    testthat::expect_gt(count_near_color(ex3f, ex3_cols$m1), 40)
    testthat::expect_gt(count_near_color(ex3f, ex3_cols$mreg), 40)
    testthat::expect_gt(count_near_color(ex3f, ex3_cols$m2), 40)
  }

})
