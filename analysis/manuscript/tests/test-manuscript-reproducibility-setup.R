testthat::test_that("clone-grade reproducibility entrypoints exist", {
  testthat::expect_true(file.exists(file.path(repo_root, "README.md")))
  testthat::expect_true(file.exists(file.path(repo_root, "analysis", "check_reproducibility.R")))
  testthat::expect_true(file.exists(file.path(repo_root, "analysis", "lib", "exdqlm_package_resolver.R")))
})

testthat::test_that("package resolver includes current and generic source checkout names", {
  source(file.path(repo_root, "analysis", "lib", "exdqlm_package_resolver.R"), local = TRUE)
  candidates <- basename(exdqlm_source_candidate_paths(repo_root))

  testthat::expect_true("exdqlm" %in% candidates)
  testthat::expect_true("exdqlm__wt__0p5p0_exdqlm_article" %in% candidates)
  testthat::expect_true("exdqlm__wt__0.5.0-crps-iqs" %in% candidates)
})

testthat::test_that("reader-facing analysis docs avoid stale machine-specific paths", {
  docs <- c(
    "README.md",
    "analysis/README.md",
    "analysis/manuscript/README.md",
    "analysis/manuscript/RAQUEL_EXAMPLES_MERGE_AUDIT.md",
    "manuscript-reproducibility-index.md"
  )

  for (doc in docs) {
    lines <- readLines(file.path(repo_root, doc), warn = FALSE)
    testthat::expect_false(
      any(grepl("/data/muscat_data|/data/jaguir26/local", lines)),
      info = doc
    )
  }
})
