#!/usr/bin/env Rscript

find_repo_root <- function(start = getwd()) {
  cur <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(cur, "article4.tex"))) {
      return(cur)
    }
    parent <- dirname(cur)
    if (identical(parent, cur)) {
      stop("Could not locate repository root (article4.tex not found).", call. = FALSE)
    }
    cur <- parent
  }
}

parse_args <- function(args) {
  out <- list(
    stage = "exal",
    tests_only = FALSE,
    skip_tests = FALSE,
    promote = FALSE,
    profile = "standard",
    pkg_path = NULL,
    seed = NULL
  )

  i <- 1L
  while (i <= length(args)) {
    a <- args[[i]]
    if (a %in% c("--stage", "-s")) {
      i <- i + 1L
      out$stage <- args[[i]]
    } else if (a == "--tests-only") {
      out$tests_only <- TRUE
    } else if (a == "--skip-tests") {
      out$skip_tests <- TRUE
    } else if (a == "--promote") {
      out$promote <- TRUE
    } else if (a == "--profile") {
      i <- i + 1L
      out$profile <- args[[i]]
    } else if (a == "--pkg-path") {
      i <- i + 1L
      out$pkg_path <- args[[i]]
    } else if (a == "--seed") {
      i <- i + 1L
      out$seed <- as.integer(args[[i]])
    } else {
      stop(sprintf("Unknown argument: %s", a), call. = FALSE)
    }
    i <- i + 1L
  }
  out
}

clear_stage_outputs <- function(stage_root) {
  figs <- file.path(stage_root, "outputs", "figures")
  tabs <- file.path(stage_root, "outputs", "tables")
  logs <- file.path(stage_root, "outputs", "logs")

  for (d in c(figs, tabs)) {
    if (dir.exists(d)) {
      files <- list.files(d, full.names = TRUE, recursive = TRUE)
      if (length(files) > 0L) unlink(files, recursive = TRUE, force = TRUE)
    }
  }
  if (dir.exists(logs)) {
    files <- list.files(logs, full.names = TRUE, recursive = TRUE)
    if (length(files) > 0L) unlink(files, recursive = TRUE, force = TRUE)
  }
}

main <- function() {
  args <- parse_args(commandArgs(trailingOnly = TRUE))
  repo_root <- find_repo_root(getwd())

  ctx <- new.env(parent = globalenv())
  ctx$repo_root <- repo_root
  ctx$project_stage <- args$stage
  ctx$profile <- args$profile
  ctx$pkg_path <- args$pkg_path
  ctx$seed_override <- args$seed

  valid_stages <- c("exal", "manuscript")
  if (!args$stage %in% valid_stages) {
    stop(sprintf("Unknown stage '%s'. Valid stages: %s", args$stage, paste(valid_stages, collapse = ", ")), call. = FALSE)
  }

  stage_scripts <- file.path(repo_root, "analysis", args$stage, "scripts")
  stage_tests <- file.path(repo_root, "analysis", args$stage, "tests")
  if (!dir.exists(stage_scripts)) {
    stop(sprintf("Stage scripts directory not found: %s", stage_scripts), call. = FALSE)
  }

  source(file.path(stage_scripts, "00_setup.R"), local = ctx)

  if (!args$tests_only) {
    ctx$log_msg(sprintf("Clearing previous %s outputs", args$stage))
    clear_stage_outputs(file.path(repo_root, "analysis", args$stage))

    run_order <- switch(
      args$stage,
      exal = c(
        "01_al_density_by_p0.R",
        "02_al_cdf_by_p0.R",
        "03_exal_density_by_gamma.R",
        "04_exal_cdf_by_gamma.R",
        "05_exal_location_scale_density.R",
        "06_exal_location_scale_cdf.R",
        "07_gamma_bounds_region.R",
        "08_qexal_pexal_inversion.R",
        "09_qexal_p0_identity_checks.R",
        "10_rexal_density_overlay.R",
        "11_summary_tables.R"
      ),
      manuscript = c(
        "01_ex1_lake_huron.R",
        "02_ex2_sunspots.R",
        "03_ex3_big_tree.R",
        "04_tracker_and_manifest.R"
      )
    )

    for (s in run_order) {
      ctx$log_msg(sprintf("Running script: %s", s))
      source(file.path(stage_scripts, s), local = ctx)
    }
  }

  if (!args$skip_tests) {
    ctx$log_msg(sprintf("Running %s tests", args$stage))
    if (!requireNamespace("testthat", quietly = TRUE)) {
      stop("testthat is required to run tests.", call. = FALSE)
    }
    Sys.setenv(EXDQLM_ARTICLE_REPO = repo_root)
    if (!is.null(args$pkg_path)) Sys.setenv(EXDQLM_PKG_PATH = args$pkg_path)

    testthat::test_dir(stage_tests, reporter = "summary")
  }

  if (args$promote) {
    ctx$log_msg("Promoting approved figures to Figures/")
    ctx$promote_publication_figures()
  }

  ctx$write_session_info()
  ctx$log_msg("Run complete")
}

main()
