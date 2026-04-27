extract_includegraphics <- function(tex_path) {
  tex <- readLines(tex_path, warn = FALSE)
  pattern <- "\\\\includegraphics(?:\\[[^]]*\\])?\\{([^}]*)\\}"
  matches <- gregexpr(pattern, tex, perl = TRUE)
  raw <- regmatches(tex, matches)
  refs <- unlist(lapply(raw, function(x) {
    sub(pattern, "\\1", x, perl = TRUE)
  }), use.names = FALSE)
  unique(refs[nzchar(refs)])
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

example_root <- file.path(repo_root, "analysis", "manuscript", "examples")
shared_lib_root <- file.path(repo_root, "analysis", "lib")

canonical_examples <- c(
  "ex1_lake_huron",
  "ex2_sunspots",
  "ex3_big_tree",
  "ex4_static",
  "_manifest"
)

testthat::test_that("canonical manuscript example folders have the expected structure", {
  testthat::expect_true(file.exists(file.path(shared_lib_root, "README.md")))
  testthat::expect_true(file.exists(file.path(shared_lib_root, "manuscript_setup.R")))
  testthat::expect_true(dir.exists(example_root))

  for (example in canonical_examples) {
    example_dir <- file.path(example_root, example)
    testthat::expect_true(dir.exists(example_dir), info = example)
    testthat::expect_true(file.exists(file.path(example_dir, "README.md")), info = example)
    testthat::expect_true(file.exists(file.path(example_dir, "config.yml")), info = example)
    testthat::expect_true(file.exists(file.path(example_dir, "artifacts.yml")), info = example)
    testthat::expect_true(file.exists(file.path(example_dir, "run.R")), info = example)
  }

  testthat::expect_true(file.exists(file.path(example_root, "ex4_static", "helpers.R")))
  testthat::expect_true(file.exists(file.path(example_root, "ex4_static", "seed_screen.R")))
})

testthat::test_that("canonical manuscript example manifests parse cleanly", {
  testthat::skip_if_not_installed("yaml")

  for (example in canonical_examples) {
    example_dir <- file.path(example_root, example)
    cfg <- yaml::read_yaml(file.path(example_dir, "config.yml"))
    artifacts <- yaml::read_yaml(file.path(example_dir, "artifacts.yml"))

    testthat::expect_equal(cfg$example_id, example, info = example)
    testthat::expect_equal(artifacts$example_id, example, info = example)
    testthat::expect_type(artifacts$article_figures %||% character(0), "character")
    testthat::expect_type(artifacts$tables %||% character(0), "character")
    testthat::expect_type(artifacts$logs %||% character(0), "character")
  }
})

testthat::test_that("article figures are declared by the canonical example manifests", {
  testthat::skip_if_not_installed("yaml")

  tex_figures <- extract_includegraphics(file.path(repo_root, "article4.tex"))
  testthat::expect_gt(length(tex_figures), 0)

  manifest_figures <- unlist(lapply(canonical_examples, function(example) {
    artifacts <- yaml::read_yaml(file.path(example_root, example, "artifacts.yml"))
    stats::setNames(artifacts$article_figures %||% character(0), rep(example, length(artifacts$article_figures %||% character(0))))
  }), use.names = TRUE)

  missing_from_manifests <- setdiff(tex_figures, unname(manifest_figures))
  testthat::expect_equal(
    missing_from_manifests,
    character(0),
    info = paste("Figures in article4.tex missing from example artifacts.yml files:", paste(missing_from_manifests, collapse = ", "))
  )

  duplicated_manifest_figures <- names(which(table(manifest_figures) > 1L))
  testthat::expect_equal(
    duplicated_manifest_figures,
    character(0),
    info = paste("Figures declared by more than one example artifacts.yml:", paste(duplicated_manifest_figures, collapse = ", "))
  )
})

testthat::test_that("preserved support workflows remain available outside the canonical examples", {
  support_root <- file.path(repo_root, "analysis", "support")
  support_workflows <- c(
    "ex3_daily_redo",
    "ex3_monthly_nino34_redo",
    "ex3_monthly_outputlag_redo"
  )

  testthat::expect_true(dir.exists(support_root))
  testthat::expect_true(file.exists(file.path(support_root, "README.md")))

  for (workflow in support_workflows) {
    workflow_dir <- file.path(support_root, workflow)
    testthat::expect_true(dir.exists(workflow_dir), info = workflow)
    testthat::expect_true(file.exists(file.path(workflow_dir, "README.md")), info = workflow)
    testthat::expect_true(file.exists(file.path(workflow_dir, "run_all.R")), info = workflow)

    run_all <- readLines(file.path(workflow_dir, "run_all.R"), warn = FALSE)
    testthat::expect_true(
      any(grepl("file.path\\(redo_root, \"\\.\\.\", \"\\.\\.\", \"\\.\\.\"\\)", run_all)),
      info = sprintf("%s/run_all.R should resolve the article root from analysis/support/<workflow>.", workflow)
    )
  }

  daily_shell <- list.files(
    file.path(support_root, "ex3_daily_redo"),
    pattern = "^run_.*\\.sh$",
    full.names = TRUE
  )
  for (script in daily_shell) {
    lines <- readLines(script, warn = FALSE)
    testthat::expect_true(
      any(grepl("\\$\\{script_dir\\}/\\.\\./\\.\\./\\.\\.", lines)),
      info = sprintf("%s should resolve the article root from analysis/support/ex3_daily_redo.", basename(script))
    )
  }
})
