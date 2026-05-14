testthat::test_that("clone-grade reproducibility entrypoints exist", {
  testthat::expect_true(file.exists(file.path(repo_root, "README.md")))
  testthat::expect_true(file.exists(file.path(repo_root, "code.R")))
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

testthat::test_that("manuscript setup records run-start provenance and headless PNG output", {
  setup_lines <- readLines(file.path(repo_root, "analysis", "lib", "manuscript_setup.R"), warn = FALSE)

  testthat::expect_true(any(grepl("article_git_at_setup <- git_state_snapshot\\(repo_root\\)", setup_lines)))
  testthat::expect_true(any(grepl("pkg_git_at_setup <- git_state_snapshot\\(pkg_source_at_setup\\$path\\)", setup_lines)))
  testthat::expect_true(any(grepl("article_git_at_setup$dirty", setup_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("pkg_git_at_setup$dirty", setup_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("capabilities\\(\"cairo\"\\)", setup_lines)))
  testthat::expect_true(any(grepl("type = png_type", setup_lines, fixed = TRUE)))
})

testthat::test_that("preflight warns about dirty tracked checkouts for final reruns", {
  check_lines <- readLines(file.path(repo_root, "analysis", "check_reproducibility.R"), warn = FALSE)

  testthat::expect_true(any(grepl("Article checkout has dirty tracked files", check_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("Package checkout has dirty tracked files", check_lines, fixed = TRUE)))
})

testthat::test_that("manuscript examples avoid data-centered prior means", {
  canonical_files <- file.path(repo_root, c(
    "exdqlm-jss.tex",
    "analysis/manuscript/examples/ex2_sunspots/run.R",
    "analysis/manuscript/examples/ex3_big_tree/run.R"
  ))
  text <- unlist(lapply(canonical_files, readLines, warn = FALSE), use.names = FALSE)

  stale_patterns <- c(
    "m0 = mean\\(",
    "m0 = stats::mean\\(",
    "m0 = quantile\\(",
    "m0 = stats::quantile\\(",
    "m0 = as.numeric\\(stats::quantile"
  )
  for (pattern in stale_patterns) {
    testthat::expect_false(
      any(grepl(pattern, text)),
      info = sprintf("data-centered prior marker still present: %s", pattern)
    )
  }
})

testthat::test_that("backend options table lives in the supplement", {
  main_text <- readLines(file.path(repo_root, "exdqlm-jss.tex"), warn = FALSE)
  supp_text <- readLines(file.path(repo_root, "exdqlm-supplement.tex"), warn = FALSE)

  testthat::expect_false(any(grepl("\\\\label\\{tab:backendopts\\}", main_text)))
  testthat::expect_false(any(grepl("\\\\section\\{Global backend options\\}", main_text)))
  testthat::expect_true(any(grepl("\\\\label\\{tab:supp_backendopts\\}", supp_text)))
  testthat::expect_true(any(grepl("\\\\section\\{Global backend options\\}", supp_text)))
})

testthat::test_that("Example 3 uses static climate coefficients in the three-model comparison", {
  testthat::skip_if_not_installed("yaml")

  cfg <- yaml::read_yaml(file.path(repo_root, "analysis", "config", "params_manuscript.yml"))
  for (profile in c("quick", "standard", "full")) {
    ex3 <- cfg$profiles[[profile]]$ex3
    testthat::expect_equal(as.numeric(ex3$covariate_df), 1)
    testthat::expect_equal(as.numeric(ex3$transfer_psi_df), 1)
    testthat::expect_equal(as.numeric(unlist(ex3$transfer_psi_df_grid)), 1)
    testthat::expect_equal(as.numeric(ex3$reg_c0), as.numeric(ex3$transfer_psi_c0))
    testthat::expect_true(all(as.numeric(unlist(ex3$lambda_grid)) >= 0.70))
    testthat::expect_true(all(as.numeric(unlist(ex3$lambda_grid)) < 1))
  }
})

testthat::test_that("Example 3 canonical output tables include all three models", {
  expected_models <- c(
    "M0_no_transfer",
    "MREG_direct_regression",
    "MTF_transfer_function"
  )
  table_paths <- file.path(repo_root, c(
    "analysis/manuscript/outputs/tables/ex3_diagnostics_summary.csv",
    "analysis/manuscript/outputs/tables/ex3_forecast_metrics.csv"
  ))
  if (!all(file.exists(table_paths))) {
    testthat::skip("Example 3 generated output tables are not present in this targeted test run.")
  }

  for (path in table_paths) {
    tab <- utils::read.csv(path, stringsAsFactors = FALSE)
    testthat::expect_true(
      all(expected_models %in% tab$model),
      info = sprintf("%s does not include all canonical Example 3 models", basename(path))
    )
  }
})

testthat::test_that("Example 3 forecast metrics are registered and package-scored", {
  artifacts <- readLines(file.path(repo_root, "analysis", "manuscript", "examples", "ex3_big_tree", "artifacts.yml"), warn = FALSE)
  manifest <- readLines(file.path(repo_root, "analysis", "manuscript", "examples", "_manifest", "run.R"), warn = FALSE)
  run_lines <- readLines(file.path(repo_root, "analysis", "manuscript", "examples", "ex3_big_tree", "run.R"), warn = FALSE)

  testthat::expect_true(any(grepl("tab:ex3forecastmetrics: ex3_forecast_metrics.csv", artifacts, fixed = TRUE)))
  testthat::expect_true(any(grepl("\"tab_ex3_forecast_metrics\"", manifest, fixed = TRUE)))
  testthat::expect_true(any(grepl("exdqlmForecastDiagnostics", run_lines, fixed = TRUE)))

  fc_path <- file.path(repo_root, "analysis", "manuscript", "outputs", "tables", "ex3_forecast_metrics.csv")
  if (!file.exists(fc_path)) {
    testthat::skip("Example 3 forecast metric output table is not present in this targeted test run.")
  }

  fc <- utils::read.csv(fc_path, stringsAsFactors = FALSE)
  testthat::expect_true(all(c("model", "label", "horizon", "mean_check_loss", "CRPS") %in% names(fc)))
  testthat::expect_false(any(c(
    "quantile_coverage", "n_exceedances", "interval_score",
    "coverage", "mean_interval_width"
  ) %in% names(fc)))
})
