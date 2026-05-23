if (!exists("repo_root", inherits = TRUE)) {
  repo_root <- normalizePath(Sys.getenv("EXDQLM_ARTICLE_REPO", unset = getwd()), mustWork = TRUE)
}

source(file.path(repo_root, "analysis", "lib", "manuscript_code_policy.R"), local = TRUE)

tex_path <- file.path(repo_root, "exdqlm-jss.tex")
map_path <- file.path(repo_root, "analysis", "manuscript", "code_chunk_map.csv")

testthat::test_that("displayed manuscript code chunks parse as R excerpts", {
  chunks <- extract_codeinput_chunks(tex_path)
  testthat::expect_gte(length(chunks), 30L)
  testthat::expect_silent(parse_codeinput_chunks(chunks))
})

testthat::test_that("manuscript code chunk map covers every displayed chunk", {
  chunks <- extract_codeinput_chunks(tex_path)
  map <- read_code_chunk_map(map_path)

  chunk_ids <- vapply(chunks, `[[`, character(1), "chunk_id")
  testthat::expect_setequal(map$chunk_id, chunk_ids)
  testthat::expect_true(all(map$display_scope %in% c("exact", "excerpt", "exact_with_analysis_helpers")))
  testthat::expect_false(any(!nzchar(map$example)))
  testthat::expect_false(any(!nzchar(map$role)))
  testthat::expect_false(any(!nzchar(map$notes)))
})

testthat::test_that("displayed code chunks are traceable to canonical analysis sources", {
  chunks <- extract_codeinput_chunks(tex_path)
  map <- read_code_chunk_map(map_path)
  names(chunks) <- vapply(chunks, `[[`, character(1), "chunk_id")

  for (i in seq_len(nrow(map))) {
    row <- map[i, ]
    chunk <- chunks[[row$chunk_id]]
    code_text <- paste(chunk$code, collapse = "\n")

    for (term in split_policy_field(row$manuscript_terms)) {
      testthat::expect_true(
        grepl(term, code_text, fixed = TRUE),
        info = sprintf("%s is missing manuscript term: %s", row$chunk_id, term)
      )
    }

    source_text <- paste(read_repo_text(repo_root, row$source_files), collapse = "\n")
    for (term in split_policy_field(row$source_terms)) {
      testthat::expect_true(
        grepl(term, source_text, fixed = TRUE),
        info = sprintf("%s mapped source files are missing source term: %s", row$chunk_id, term)
      )
    }
  }
})

testthat::test_that("mapped manuscript figures and tables are registered in artifact manifests", {
  map <- read_code_chunk_map(map_path)
  tex <- paste(readLines(tex_path, warn = FALSE), collapse = "\n")
  artifact_files <- list.files(
    file.path(repo_root, "analysis", "manuscript", "examples"),
    pattern = "^artifacts\\.yml$",
    recursive = TRUE,
    full.names = TRUE
  )
  artifacts <- paste(unlist(lapply(artifact_files, readLines, warn = FALSE), use.names = FALSE), collapse = "\n")

  targets <- unique(unlist(lapply(map$artifact_targets, split_policy_field), use.names = FALSE))
  targets <- targets[nzchar(targets)]
  testthat::expect_true(length(targets) > 0L)

  for (target in targets) {
    testthat::expect_true(
      grepl(sprintf("\\label{%s}", target), tex, fixed = TRUE),
      info = sprintf("Mapped manuscript target is not a LaTeX label: %s", target)
    )
    testthat::expect_true(
      grepl(sprintf("%s:", target), artifacts, fixed = TRUE),
      info = sprintf("Mapped manuscript target is not registered in artifacts.yml: %s", target)
    )
  }
})

testthat::test_that("displayed manuscript code avoids stale local scoring implementations", {
  chunks <- extract_codeinput_chunks(tex_path)
  code_text <- paste(unlist(lapply(chunks, `[[`, "code"), use.names = FALSE), collapse = "\n")
  stale_patterns <- c(
    "FNN::KL",
    "KL.divergence",
    "ref.samp",
    "check.loss.fn",
    "crps.iqs",
    "check_loss_vec",
    "iqs_crps_vec",
    "interval_score_vec"
  )

  for (pattern in stale_patterns) {
    testthat::expect_false(
      grepl(pattern, code_text, fixed = TRUE),
      info = sprintf("Displayed manuscript code contains stale local scoring marker: %s", pattern)
    )
  }

  testthat::expect_true(grepl("exdqlmDiagnostics", code_text, fixed = TRUE))
  testthat::expect_true(grepl("exdqlmForecastDiagnostics", code_text, fixed = TRUE))
})
