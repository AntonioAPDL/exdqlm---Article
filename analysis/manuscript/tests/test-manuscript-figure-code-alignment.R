if (!exists("repo_root", inherits = TRUE)) {
  repo_root <- normalizePath(Sys.getenv("EXDQLM_ARTICLE_REPO", unset = getwd()), mustWork = TRUE)
}

source(file.path(repo_root, "analysis", "lib", "manuscript_code_policy.R"), local = TRUE)

tex_path <- file.path(repo_root, "exdqlm-jss.tex")

codeinput_by_id <- function() {
  chunks <- extract_codeinput_chunks(tex_path)
  names(chunks) <- vapply(chunks, `[[`, character(1), "chunk_id")
  chunks
}

code_text <- function(chunks, id) paste(chunks[[id]]$code, collapse = "\n")

count_fixed <- function(pattern, text) {
  loc <- gregexpr(pattern, text, fixed = TRUE)[[1L]]
  if (identical(loc[[1L]], -1L)) 0L else length(loc)
}

testthat::test_that("displayed figure chunks retain canonical visual markers", {
  chunks <- codeinput_by_id()

  fig1 <- code_text(chunks, "chunk_004")
  testthat::expect_true(grepl("mfcol = c(2, 2)", fig1, fixed = TRUE))
  testthat::expect_false(grepl("mfrow = c(2, 2)", fig1, fixed = TRUE))
  testthat::expect_true(grepl("\"sigma trace\"", fig1, fixed = TRUE))
  testthat::expect_true(grepl("\"gamma density\"", fig1, fixed = TRUE))

  fig2_synthesis <- code_text(chunks, "chunk_011")
  testthat::expect_gte(count_fixed("legend(", fig2_synthesis), 2L)
  testthat::expect_true(grepl("Observed-period synthesis (95%)", fig2_synthesis, fixed = TRUE))
  testthat::expect_true(grepl("Forecast synthesis (95%)", fig2_synthesis, fixed = TRUE))

  fig6_top <- code_text(chunks, "chunk_027")
  fig6_seasonal <- code_text(chunks, "chunk_028")
  fig6_covariate <- code_text(chunks, "chunk_029")
  fig6 <- paste(fig6_top, fig6_seasonal, fig6_covariate, sep = "\n")
  testthat::expect_true(grepl("padded.range", fig6, fixed = TRUE))
  testthat::expect_true(grepl("M0 no covariates", fig6, fixed = TRUE))
  testthat::expect_true(grepl("MREG direct", fig6, fixed = TRUE))
  testthat::expect_true(grepl("MTF transfer", fig6, fixed = TRUE))
  testthat::expect_false(grepl("ylim = c(1, 8)", fig6, fixed = TRUE))
  testthat::expect_false(grepl("ylim = c(-2, 2)", fig6, fixed = TRUE))

  fig7 <- code_text(chunks, "chunk_030")
  testthat::expect_true(grepl("heights = c(1.05, 1)", fig7, fixed = TRUE))
  testthat::expect_true(grepl("padded.range", fig7, fixed = TRUE))
  testthat::expect_true(grepl("psi[list(NOI, t)]", fig7, fixed = TRUE))
  testthat::expect_true(grepl("psi[list(AMO, t)]", fig7, fixed = TRUE))
  testthat::expect_false(grepl("ylim = c(-0.3, 0.1)", fig7, fixed = TRUE))
  testthat::expect_false(grepl("ylim = c(-0.1, 0.3)", fig7, fixed = TRUE))

  fig8 <- code_text(chunks, "chunk_032")
  testthat::expect_gte(count_fixed("plot = FALSE", fig8), 3L)
  testthat::expect_true(grepl("plot(fc.M0", fig8, fixed = TRUE))
  testthat::expect_true(grepl("plot(fc.MREG", fig8, fixed = TRUE))
  testthat::expect_true(grepl("plot(fc.MTF", fig8, fixed = TRUE))
  testthat::expect_true(grepl("held-out observations", fig8, fixed = TRUE))

  fig9 <- code_text(chunks, "chunk_036")
  testthat::expect_true(grepl("beta.summary", fig9, fixed = TRUE))
  testthat::expect_true(grepl("segments(", fig9, fixed = TRUE))
  testthat::expect_true(grepl("LDVB 95% interval", fig9, fixed = TRUE))
  testthat::expect_true(grepl("MCMC 95% interval", fig9, fixed = TRUE))
})
