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

testthat::test_that("manuscript figures resolve from canonical generated outputs", {
  tex_path <- file.path(repo_root, "article4.tex")
  testthat::expect_true(file.exists(tex_path))

  tex <- readLines(tex_path, warn = FALSE)
  graphicspath <- grep("\\\\graphicspath", tex, value = TRUE)
  testthat::expect_true(length(graphicspath) > 0)
  testthat::expect_true(any(grepl("analysis/manuscript/outputs/figures", graphicspath, fixed = TRUE)))

  included <- extract_includegraphics(tex_path)
  testthat::expect_gt(length(included), 0)

  generated_paths <- file.path(repo_root, "analysis", "manuscript", "outputs", "figures", included)
  fallback_paths <- file.path(repo_root, "Figures", included)

  missing_generated <- included[!file.exists(generated_paths)]
  testthat::expect_equal(
    length(missing_generated),
    0L,
    info = paste("These manuscript figures are not in analysis/manuscript/outputs/figures:", paste(missing_generated, collapse = ", "))
  )

  fallback_only <- included[!file.exists(generated_paths) & file.exists(fallback_paths)]
  testthat::expect_equal(
    length(fallback_only),
    0L,
    info = paste("These manuscript figures would fall back to stale Figures/ copies:", paste(fallback_only, collapse = ", "))
  )
})

testthat::test_that("included manuscript figures are recorded in the reproducibility tracker", {
  tex_path <- file.path(repo_root, "article4.tex")
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
