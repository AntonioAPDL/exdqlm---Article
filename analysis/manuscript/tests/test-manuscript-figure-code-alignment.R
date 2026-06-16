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

  fig6_top <- code_text(chunks, "chunk_028")
  fig6_seasonal <- code_text(chunks, "chunk_029")
  fig6_covariate <- code_text(chunks, "chunk_030")
  fig6 <- paste(fig6_top, fig6_seasonal, fig6_covariate, sep = "\n")
  testthat::expect_true(grepl("plot(M0", fig6_top, fixed = TRUE))
  testthat::expect_true(grepl("plot(MREG", fig6_top, fixed = TRUE))
  testthat::expect_true(grepl("plot(MTF", fig6_top, fixed = TRUE))
  testthat::expect_true(grepl("add = TRUE", fig6_top, fixed = TRUE))
  testthat::expect_true(grepl("type = \"component\"", fig6_seasonal, fixed = TRUE))
  testthat::expect_true(grepl("type = \"component\"", fig6_covariate, fixed = TRUE))
  testthat::expect_true(grepl("M0 no covariates", fig6, fixed = TRUE))
  testthat::expect_true(grepl("MREG direct", fig6, fixed = TRUE))
  testthat::expect_true(grepl("MTF transfer", fig6, fixed = TRUE))
  testthat::expect_false(grepl("q.summary", fig6, fixed = TRUE))
  testthat::expect_false(grepl("c.summary", fig6, fixed = TRUE))
  testthat::expect_false(grepl("add.band", fig6, fixed = TRUE))
  testthat::expect_true(grepl("ylim = c(1, 8)", fig6_top, fixed = TRUE))
  testthat::expect_true(grepl("ylim = c(-2, 2)", fig6_seasonal, fixed = TRUE))
  testthat::expect_true(grepl("ylim = c(-1.5, 1.5)", fig6_covariate, fixed = TRUE))

  fig7 <- code_text(chunks, "chunk_031")
  testthat::expect_true(grepl("type = \"state\"", fig7, fixed = TRUE))
  testthat::expect_true(grepl("add = TRUE", fig7, fixed = TRUE))
  testthat::expect_true(grepl("psi[list(NOI, t)]", fig7, fixed = TRUE))
  testthat::expect_true(grepl("psi[list(AMO, t)]", fig7, fixed = TRUE))
  testthat::expect_false(grepl("c.summary", fig7, fixed = TRUE))
  testthat::expect_false(grepl("add.band", fig7, fixed = TRUE))
  testthat::expect_true(grepl("ylim = c(-0.11, 0.01)", fig7, fixed = TRUE))
  testthat::expect_true(grepl("ylim = c(-0.005, 0.06)", fig7, fixed = TRUE))

  fig8_forecasts <- paste(
    code_text(chunks, "chunk_033"),
    code_text(chunks, "chunk_034"),
    code_text(chunks, "chunk_035"),
    sep = "\n"
  )
  fig8_plot <- code_text(chunks, "chunk_036")
  testthat::expect_gte(count_fixed("predict(", fig8_forecasts), 3L)
  testthat::expect_false(grepl("exdqlmForecast(", fig8_forecasts, fixed = TRUE))
  testthat::expect_gte(count_fixed("return.draws = TRUE", fig8_forecasts), 3L)
  testthat::expect_false(grepl("plot = FALSE", fig8_forecasts, fixed = TRUE))
  testthat::expect_true(grepl("plot(fc.M0", fig8_plot, fixed = TRUE))
  testthat::expect_true(grepl("plot(fc.MREG", fig8_plot, fixed = TRUE))
  testthat::expect_true(grepl("plot(fc.MTF", fig8_plot, fixed = TRUE))
  testthat::expect_true(grepl("held-out observations", fig8_plot, fixed = TRUE))

  fig9 <- code_text(chunks, "chunk_041")
  testthat::expect_true(grepl("exalStaticDiagnostics", fig9, fixed = TRUE))
  testthat::expect_true(grepl("type = \"coefficients\"", fig9, fixed = TRUE))
  testthat::expect_true(grepl("beta.ref = c(0, beta.true)", fig9, fixed = TRUE))
  testthat::expect_true(grepl("include.intercept = FALSE", fig9, fixed = TRUE))
  testthat::expect_true(grepl("ylim = y.lim", fig9, fixed = TRUE))
  testthat::expect_true(grepl("legend = i == 1", fig9, fixed = TRUE))
  testthat::expect_true(grepl("legend.labels = c(\"LDVB 95% interval\", \"MCMC 95% interval\")", fig9, fixed = TRUE))
  testthat::expect_true(grepl("beta.ref.label = \"truth\"", fig9, fixed = TRUE))
  testthat::expect_true(grepl("cols = c(\"orange\", \"steelblue\")", fig9, fixed = TRUE))
  testthat::expect_false(grepl("beta.summary", fig9, fixed = TRUE))
  testthat::expect_false(grepl("segments(", fig9, fixed = TRUE))
})
