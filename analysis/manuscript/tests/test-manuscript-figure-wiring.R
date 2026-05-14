`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

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

extract_table_labels <- function(tex_path) {
  tex <- readLines(tex_path, warn = FALSE)
  pattern <- "\\\\label\\{(tab:[^}]*)\\}"
  matches <- gregexpr(pattern, tex, perl = TRUE)
  raw <- regmatches(tex, matches)
  refs <- unlist(lapply(raw, function(x) {
    sub(pattern, "\\1", x, perl = TRUE)
  }), use.names = FALSE)
  unique(refs[nzchar(refs)])
}

testthat::test_that("manuscript figures resolve from canonical generated outputs", {
  tex_path <- file.path(repo_root, "exdqlm-jss.tex")
  testthat::expect_true(file.exists(tex_path))

  tex <- readLines(tex_path, warn = FALSE)
  graphicspath <- grep("\\\\graphicspath", tex, value = TRUE)
  testthat::expect_true(length(graphicspath) > 0)
  testthat::expect_true(any(grepl("analysis/manuscript/outputs/figures", graphicspath, fixed = TRUE)))
  testthat::expect_false(any(grepl("Figures/", graphicspath, fixed = TRUE)))

  included <- extract_includegraphics(tex_path)
  testthat::expect_gt(length(included), 0)

  generated_paths <- file.path(repo_root, "analysis", "manuscript", "outputs", "figures", included)
  missing_generated <- included[!file.exists(generated_paths)]
  testthat::expect_equal(
    length(missing_generated),
    0L,
    info = paste("These manuscript figures are not in analysis/manuscript/outputs/figures:", paste(missing_generated, collapse = ", "))
  )

})

testthat::test_that("included manuscript figures are recorded in the reproducibility tracker", {
  tex_path <- file.path(repo_root, "exdqlm-jss.tex")
  included <- extract_includegraphics(tex_path)
  tracker <- utils::read.csv(tracker_csv, stringsAsFactors = FALSE)

  expected_relpaths <- file.path("analysis", "manuscript", "outputs", "figures", included)
  missing_tracker <- setdiff(expected_relpaths, tracker$relative_path)
  testthat::expect_equal(
    length(missing_tracker),
    0L,
    info = paste("Included figures missing from manuscript_repro_tracker.csv:", paste(missing_tracker, collapse = ", "))
  )

  included_rows <- tracker[tracker$relative_path %in% expected_relpaths, , drop = FALSE]
  testthat::expect_true(
    all(included_rows$status == "reproduced"),
    info = "All included manuscript figures should have status 'reproduced' in the tracker."
  )
})

testthat::test_that("main manuscript tables are recorded in manifests and tracker", {
  testthat::skip_if_not_installed("yaml")

  tex_path <- file.path(repo_root, "exdqlm-jss.tex")
  table_labels <- extract_table_labels(tex_path)
  testthat::expect_gt(length(table_labels), 0)

  example_dirs <- list.dirs(file.path(repo_root, "analysis", "manuscript", "examples"), recursive = FALSE, full.names = TRUE)
  target_maps <- lapply(file.path(example_dirs, "artifacts.yml"), function(path) {
    if (!file.exists(path)) return(character(0))
    artifacts <- yaml::read_yaml(path)
    unlist(artifacts$article_targets %||% character(0), use.names = TRUE)
  })
  manifest_targets <- unlist(target_maps, use.names = TRUE)
  manifest_table_labels <- names(manifest_targets)[grepl("^tab:", names(manifest_targets))]

  missing_from_manifests <- setdiff(table_labels, manifest_table_labels)
  testthat::expect_equal(
    missing_from_manifests,
    character(0),
    info = paste("Table labels in exdqlm-jss.tex missing from example artifacts.yml:", paste(missing_from_manifests, collapse = ", "))
  )

  tracker <- utils::read.csv(tracker_csv, stringsAsFactors = FALSE)
  missing_from_tracker <- setdiff(table_labels, tracker$manuscript_target)
  testthat::expect_equal(
    missing_from_tracker,
    character(0),
    info = paste("Table labels in exdqlm-jss.tex missing from manuscript_repro_tracker.csv:", paste(missing_from_tracker, collapse = ", "))
  )

  table_rows <- tracker[tracker$manuscript_target %in% table_labels, , drop = FALSE]
  testthat::expect_true(
    all(table_rows$status == "reproduced"),
    info = "All main manuscript tables should have status 'reproduced' in the tracker."
  )
})

testthat::test_that("main manuscript artifacts have registered generating scripts", {
  testthat::skip_if_not_installed("yaml")

  tex_path <- file.path(repo_root, "exdqlm-jss.tex")
  included_figures <- extract_includegraphics(tex_path)
  table_labels <- extract_table_labels(tex_path)
  manuscript_targets <- c(paste0("fig:", tools::file_path_sans_ext(included_figures)), table_labels)

  example_dirs <- list.dirs(file.path(repo_root, "analysis", "manuscript", "examples"), recursive = FALSE, full.names = TRUE)
  example_dirs <- example_dirs[basename(example_dirs) != "_manifest"]

  missing_generators <- character()
  for (example_dir in example_dirs) {
    artifacts_path <- file.path(example_dir, "artifacts.yml")
    run_path <- file.path(example_dir, "run.R")
    if (!file.exists(artifacts_path) || !file.exists(run_path)) next

    artifacts <- yaml::read_yaml(artifacts_path)
    targets <- artifacts$article_targets %||% list()
    if (!length(targets)) next

    run_text <- readLines(run_path, warn = FALSE)
    for (target_name in intersect(names(targets), manuscript_targets)) {
      output_file <- as.character(targets[[target_name]])
      if (!any(grepl(output_file, run_text, fixed = TRUE))) {
        missing_generators <- c(missing_generators, sprintf("%s -> %s", target_name, output_file))
      }
    }
  }

  testthat::expect_equal(
    missing_generators,
    character(0),
    info = paste("Main manuscript artifacts missing explicit generation references in run.R:", paste(missing_generators, collapse = ", "))
  )
})
