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

testthat::test_that("Example 4 publication seed is configured, not output-dependent", {
  testthat::skip_if_not_installed("yaml")

  params <- yaml::read_yaml(file.path(repo_root, "analysis", "config", "params_manuscript.yml"))
  for (profile_name in c("quick", "standard", "full")) {
    ex4 <- params$profiles[[profile_name]]$ex4
    testthat::expect_equal(as.integer(ex4$dataset_seed), 20260712L, info = profile_name)
    testthat::expect_null(ex4$dataset_seed_mode, info = profile_name)
  }
})

testthat::test_that("Example 3 manuscript preprocessing is reader-facing", {
  tex <- readLines(file.path(repo_root, "exdqlm-jss.tex"), warn = FALSE)

  testthat::expect_true(any(grepl("first 414", tex, fixed = TRUE)))
  testthat::expect_true(any(grepl("final 18", tex, fixed = TRUE)))
  testthat::expect_true(any(grepl("ex3\\\\_model\\\\_dataset.csv", tex)))
  testthat::expect_true(any(grepl("window\\(y\\.fit, end = c\\(2021, 6\\)\\)", tex)))
  testthat::expect_true(any(grepl("X\\.train = scale\\(X\\.raw\\[1:414, \\]\\)", tex)))
  testthat::expect_false(any(grepl("date >= as\\.Date|date <= as\\.Date|train\\.ind|holdout\\.ind", tex)))
})

testthat::test_that("article figures are declared by the canonical example manifests", {
  testthat::skip_if_not_installed("yaml")

  tex_figures <- extract_includegraphics(file.path(repo_root, "exdqlm-jss.tex"))
  testthat::expect_gt(length(tex_figures), 0)

  manifest_figures <- unlist(lapply(canonical_examples, function(example) {
    artifacts <- yaml::read_yaml(file.path(example_root, example, "artifacts.yml"))
    stats::setNames(artifacts$article_figures %||% character(0), rep(example, length(artifacts$article_figures %||% character(0))))
  }), use.names = TRUE)

  missing_from_manifests <- setdiff(tex_figures, unname(manifest_figures))
  testthat::expect_equal(
    missing_from_manifests,
    character(0),
    info = paste("Figures in exdqlm-jss.tex missing from example artifacts.yml files:", paste(missing_from_manifests, collapse = ", "))
  )

  duplicated_manifest_figures <- names(which(table(manifest_figures) > 1L))
  testthat::expect_equal(
    duplicated_manifest_figures,
    character(0),
    info = paste("Figures declared by more than one example artifacts.yml:", paste(duplicated_manifest_figures, collapse = ", "))
  )
})

testthat::test_that("submission tree excludes non-canonical exploratory workflows", {
  testthat::expect_false(dir.exists(file.path(repo_root, "analysis", "support")))
})
