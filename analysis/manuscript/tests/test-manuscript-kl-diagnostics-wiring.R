testthat::test_that("canonical manuscript KL diagnostics use deterministic package wiring", {
  canonical <- file.path(repo_root, c(
    "analysis/lib/manuscript_setup.R",
    "analysis/manuscript/examples/ex2_sunspots/run.R",
    "analysis/manuscript/examples/ex3_big_tree/run.R",
    "analysis/manuscript/REPRODUCIBILITY_PROTOCOL.md",
    "exdqlm-jss.tex"
  ))

  text <- unlist(lapply(canonical, readLines, warn = FALSE), use.names = FALSE)

  testthat::expect_false(any(grepl("FNN::KL|KL\\.divergence|ref\\.samp", text)))
  testthat::expect_true(any(grepl("exdqlm::diagnostics", text, fixed = TRUE)))
  testthat::expect_false(any(grepl("m[12]\\.KL\\.(by_k|gaussian)\\s*=", text)))
  testthat::expect_true(any(grepl("kl\\.details", text)))
})

testthat::test_that("manuscript diagnostics helper preserves deterministic KL outputs", {
  setup_path <- file.path(repo_root, "analysis", "lib", "manuscript_setup.R")
  setup_lines <- readLines(setup_path, warn = FALSE)
  testthat::expect_false(any(grepl("stats::rnorm\\(TT\\)|seeded_rnorm", setup_lines)))
  testthat::expect_true(any(grepl("exdqlm::diagnostics", setup_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("kl_k", setup_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("crps_probs", setup_lines, fixed = TRUE)))
})

testthat::test_that("Example 3 forecast scores use package-level diagnostics", {
  canonical <- file.path(repo_root, c(
    "analysis/manuscript/examples/ex3_big_tree/run.R",
    "exdqlm-jss.tex"
  ))
  text <- unlist(lapply(canonical, readLines, warn = FALSE), use.names = FALSE)

  testthat::expect_true(any(grepl("diagnostics(fc.", text, fixed = TRUE)))
  testthat::expect_false(any(grepl("check\\.loss\\.fn|crps\\.iqs|check_loss_vec|iqs_crps_vec|interval_score_vec", text)))
  testthat::expect_false(any(grepl("95\\\\% coverage", text)))
})
