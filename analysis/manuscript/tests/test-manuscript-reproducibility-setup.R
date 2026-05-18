repro_mode <- tolower(Sys.getenv("EXDQLM_REPRO_MODE", unset = "portable"))
if (!repro_mode %in% c("portable", "reference")) repro_mode <- "portable"

reference_sync_enabled <- function() {
  flag <- tolower(Sys.getenv(
    "EXDQLM_REFERENCE_SYNC",
    unset = if (identical(repro_mode, "reference")) "true" else "false"
  ))
  flag %in% c("true", "1", "yes")
}

read_required_csv <- function(rel, ...) {
  path <- file.path(repo_root, rel)
  testthat::expect_true(file.exists(path), info = sprintf("Missing generated table: %s", rel))
  utils::read.csv(path, stringsAsFactors = FALSE, ...)
}

expect_columns <- function(x, cols, label) {
  testthat::expect_true(
    all(cols %in% names(x)),
    info = sprintf("%s missing expected columns: %s", label, paste(setdiff(cols, names(x)), collapse = ", "))
  )
}

expect_finite_columns <- function(x, cols, label) {
  for (col in cols) {
    testthat::expect_true(
      all(is.finite(as.numeric(x[[col]]))),
      info = sprintf("%s column %s must contain finite numeric values", label, col)
    )
  }
}

testthat::test_that("clone-grade reproducibility entrypoints exist", {
  testthat::expect_true(file.exists(file.path(repo_root, "README.md")))
  testthat::expect_true(file.exists(file.path(repo_root, "code.R")))
  testthat::expect_true(file.exists(file.path(repo_root, "analysis", "check_reproducibility.R")))
  testthat::expect_true(file.exists(file.path(repo_root, "analysis", "lib", "exdqlm_package_resolver.R")))
})

testthat::test_that("code.R is a JSS-facing spin-ready replication script", {
  code_lines <- readLines(file.path(repo_root, "code.R"), warn = FALSE)

  testthat::expect_true(any(grepl("# exdqlm Article Replication Script", code_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("knitr::spin(\"code.R\", knit = TRUE)", code_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("sessionInfo()", code_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("EXDQLM_REPRO_TESTS_ONLY", code_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("Manuscript output map", code_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("Sys.setenv(TZ = \"America/New_York\")", code_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("Mersenne-Twister / Inversion / Rejection", code_lines, fixed = TRUE)))

  testthat::skip_if_not_installed("knitr")
  spun <- knitr::spin(text = code_lines, knit = FALSE)
  testthat::expect_true(any(grepl("exdqlm Article Replication Script", spun, fixed = TRUE)))
  testthat::expect_true(any(grepl("Creating the JSS HTML replication log", spun, fixed = TRUE)))
  testthat::expect_true(any(grepl("sessionInfo", spun, fixed = TRUE)))
})

testthat::test_that("code.html records the JSS replication log when generated", {
  testthat::skip_if(
    isTRUE(getOption("knitr.in.progress")) ||
      tolower(Sys.getenv("EXDQLM_BUILDING_CODE_HTML", unset = "false")) %in% c("true", "1", "yes"),
    "code.html is written after the knitr::spin() run completes."
  )

  html_path <- file.path(repo_root, "code.html")
  testthat::expect_true(file.exists(html_path), info = "Run knitr::spin(\"code.R\", knit = TRUE) to refresh code.html.")

  html <- readLines(html_path, warn = FALSE)
  testthat::expect_true(any(grepl("exdqlm Article Replication Script", html, fixed = TRUE)))
  testthat::expect_true(any(grepl("EXDQLM_REPRO_TESTS_ONLY", html, fixed = TRUE)))
  testthat::expect_true(any(grepl("Session Info", html, fixed = TRUE)))
  testthat::expect_true(any(grepl("R version", html, fixed = TRUE)))
})

testthat::test_that("portable and reference reproducibility modes are wired", {
  code_lines <- readLines(file.path(repo_root, "code.R"), warn = FALSE)
  run_lines <- readLines(file.path(repo_root, "analysis", "run_all.R"), warn = FALSE)

  testthat::expect_true(any(grepl("--mode", code_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("portable", code_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("reference", code_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("EXDQLM_REPRO_MODE", code_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("EXDQLM_REFERENCE_SYNC", code_lines, fixed = TRUE)))

  testthat::expect_true(any(grepl("--mode", run_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("EXDQLM_REPRO_MODE", run_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("EXDQLM_REFERENCE_SYNC", run_lines, fixed = TRUE)))
})

testthat::test_that("package resolver includes current and generic source checkout names", {
  source(file.path(repo_root, "analysis", "lib", "exdqlm_package_resolver.R"), local = TRUE)
  candidates <- basename(exdqlm_source_candidate_paths(repo_root))

  testthat::expect_true("exdqlm" %in% candidates)
  testthat::expect_true("exdqlm__wt__1p0p0_exdqlm_article" %in% candidates)
  testthat::expect_true("exdqlm__wt__1.0.0-jss" %in% candidates)
  testthat::expect_true("exdqlm__wt__0p5p0_exdqlm_article" %in% candidates)
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

  testthat::expect_true(any(grepl("set_manuscript_rng", setup_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("RNGkind(kind = kind, normal.kind = normal_kind, sample.kind = sample_kind)", setup_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("selected_rng_kind <- set_manuscript_rng()", setup_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("rng_kind", setup_lines, fixed = TRUE)))
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

testthat::test_that("RNG and benchmark backend reproducibility policy is explicit", {
  testthat::skip_if_not_installed("yaml")
  cfg <- yaml::read_yaml(file.path(repo_root, "analysis", "config", "params_manuscript.yml"))

  testthat::expect_identical(as.character(cfg$rng$kind), "Mersenne-Twister")
  testthat::expect_identical(as.character(cfg$rng$normal_kind), "Inversion")
  testthat::expect_identical(as.character(cfg$rng$sample_kind), "Rejection")
  testthat::expect_identical(as.character(cfg$manuscript_benchmark_profile), "B")
  testthat::expect_identical(as.integer(cfg$benchmark_profiles$B$cpp_threads), 1L)
  testthat::expect_false(isTRUE(cfg$benchmark_profiles$B$use_cpp_samplers))

  check_lines <- readLines(file.path(repo_root, "analysis", "check_reproducibility.R"), warn = FALSE)
  testthat::expect_true(any(grepl("manuscript RNG kind is explicit and stable", check_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("benchmark profile keeps C++ samplers disabled", check_lines, fixed = TRUE)))
})

testthat::test_that("preflight enforces the manuscript code policy", {
  check_lines <- readLines(file.path(repo_root, "analysis", "check_reproducibility.R"), warn = FALSE)

  testthat::expect_true(any(grepl("Manuscript Code Policy", check_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("low-level Example 3 markers", check_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("first 414", check_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("final 18", check_lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("ex3\\\\_model\\\\_dataset.csv", check_lines, fixed = TRUE)))
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

testthat::test_that("portable generated manuscript tables are coherent", {
  ex2 <- read_required_csv("analysis/manuscript/outputs/tables/ex2_dynamic_benchmark.csv")
  expect_columns(
    ex2,
    c("model", "method", "runtime_sec", "KL", "CRPS", "pplc", "backend_profile"),
    "Example 2 benchmark table"
  )
  testthat::expect_true(all(c("DQLM", "exDQLM") %in% ex2$model))
  testthat::expect_true(all(c("LDVB", "MCMC") %in% ex2$method))
  expect_finite_columns(ex2, c("runtime_sec", "KL", "CRPS", "pplc"), "Example 2 benchmark table")
  testthat::expect_true(all(ex2$runtime_sec > 0))
  testthat::expect_true(all(ex2$CRPS >= 0))
  testthat::expect_true(all(ex2$pplc >= 0))

  expected_models <- c(
    "M0_no_transfer",
    "MREG_direct_regression",
    "MTF_transfer_function"
  )

  ex3 <- read_required_csv("analysis/manuscript/outputs/tables/ex3_diagnostics_summary.csv")
  expect_columns(ex3, c("model", "label", "KL", "KL_flipped", "CRPS", "PPLC"), "Example 3 diagnostics table")
  testthat::expect_true(all(expected_models %in% ex3$model))
  expect_finite_columns(ex3, c("KL", "KL_flipped", "CRPS", "PPLC"), "Example 3 diagnostics table")
  testthat::expect_true(all(ex3$CRPS >= 0))
  testthat::expect_true(all(ex3$PPLC >= 0))

  ex3_fc <- read_required_csv("analysis/manuscript/outputs/tables/ex3_forecast_metrics.csv")
  expect_columns(ex3_fc, c("model", "label", "horizon", "mean_check_loss", "CRPS"), "Example 3 forecast table")
  testthat::expect_true(all(expected_models %in% ex3_fc$model))
  expect_finite_columns(ex3_fc, c("horizon", "mean_check_loss", "CRPS"), "Example 3 forecast table")
  testthat::expect_true(all(ex3_fc$horizon > 0))
  testthat::expect_true(all(ex3_fc$mean_check_loss >= 0))
  testthat::expect_true(all(ex3_fc$CRPS >= 0))

  ex4 <- read_required_csv("analysis/manuscript/outputs/tables/ex4static_summary.csv")
  expect_columns(
    ex4,
    c("p0", "method", "runtime_sec", "active_signal_rmse", "inactive_signal_mae", "holdout_quantile_rmse"),
    "Example 4 static summary table"
  )
  testthat::expect_true(all(c("LDVB", "MCMC") %in% ex4$method))
  expect_finite_columns(
    ex4,
    c("p0", "runtime_sec", "active_signal_rmse", "inactive_signal_mae", "holdout_quantile_rmse"),
    "Example 4 static summary table"
  )
  testthat::expect_true(all(ex4$p0 > 0 & ex4$p0 < 1))
  testthat::expect_true(all(ex4$runtime_sec > 0))

  env <- read_required_csv(
    "analysis/manuscript/outputs/tables/benchmark_environment.csv",
    header = FALSE
  )
  fields <- stats::setNames(env$V2, env$V1)
  testthat::expect_identical(fields[["exdqlm_version"]], "1.0.0")
  testthat::expect_true(nzchar(fields[["exdqlm_commit"]]))
  testthat::expect_true(nzchar(fields[["r_version"]]))
  testthat::expect_true(nzchar(fields[["runtime_definition"]]))
  testthat::expect_true("diagnostics_runtime_included" %in% names(fields))
  testthat::expect_true("exdqlm.cpp_threads" %in% names(fields))
  testthat::expect_identical(fields[["rng_kind"]], "Mersenne-Twister")
  testthat::expect_identical(fields[["rng_normal_kind"]], "Inversion")
  testthat::expect_identical(fields[["rng_sample_kind"]], "Rejection")
  testthat::expect_identical(fields[["exdqlm.cpp_threads"]], "1")
  testthat::expect_identical(fields[["exdqlm.use_cpp_samplers"]], "FALSE")
})

testthat::test_that("main manuscript inline table values match generated outputs", {
  testthat::skip_if_not(
    reference_sync_enabled(),
    "Exact manuscript-value matching is a reference-mode check."
  )

  tex <- paste(readLines(file.path(repo_root, "exdqlm-jss.tex"), warn = FALSE), collapse = "\n")
  expect_value <- function(value, digits) {
    rendered <- sprintf(paste0("%0.", digits, "f"), as.numeric(value))
    testthat::expect_true(
      grepl(rendered, tex, fixed = TRUE),
      info = sprintf("Rendered table value %s is missing from exdqlm-jss.tex.", rendered)
    )
  }

  ex2 <- utils::read.csv(
    file.path(repo_root, "analysis", "manuscript", "outputs", "tables", "ex2_dynamic_benchmark.csv"),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(ex2))) {
    expect_value(ex2$runtime_sec[[i]], 2)
    expect_value(ex2$KL[[i]], 3)
    expect_value(ex2$CRPS[[i]], 3)
    expect_value(ex2$pplc[[i]], 1)
  }

  ex3 <- utils::read.csv(
    file.path(repo_root, "analysis", "manuscript", "outputs", "tables", "ex3_diagnostics_summary.csv"),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(ex3))) {
    expect_value(ex3$KL[[i]], 3)
    expect_value(ex3$CRPS[[i]], 3)
    expect_value(ex3$PPLC[[i]], 3)
  }

  ex3_fc <- utils::read.csv(
    file.path(repo_root, "analysis", "manuscript", "outputs", "tables", "ex3_forecast_metrics.csv"),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(ex3_fc))) {
    expect_value(ex3_fc$mean_check_loss[[i]], 3)
    expect_value(ex3_fc$CRPS[[i]], 3)
  }

  ex4 <- utils::read.csv(
    file.path(repo_root, "analysis", "manuscript", "outputs", "tables", "ex4static_summary.csv"),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(ex4))) {
    expect_value(ex4$runtime_sec[[i]], 2)
    expect_value(ex4$active_signal_rmse[[i]], 3)
    expect_value(ex4$inactive_signal_mae[[i]], 3)
    expect_value(ex4$holdout_quantile_rmse[[i]], 3)
  }

  env <- utils::read.csv(
    file.path(repo_root, "analysis", "manuscript", "outputs", "tables", "benchmark_environment.csv"),
    header = FALSE,
    stringsAsFactors = FALSE
  )
  exdqlm_commit <- env$V2[env$V1 == "exdqlm_commit"][[1]]
  testthat::expect_true(grepl(exdqlm_commit, tex, fixed = TRUE))
})
