#!/usr/bin/env Rscript

#' # exdqlm article replication script
#'
#' This is the standalone replication script for the JSS article
#' "exdqlm: An R Package for Estimation and Analysis of Flexible Dynamic
#' Quantile Linear Models".
#'
#' Run this file from the extracted replication-materials directory:
#'
#' ```sh
#' Rscript code.R
#' ```
#'
#' The default command regenerates the manuscript figures, tables, logs, and
#' reproducibility manifests using the standard manuscript profile. Two shorter
#' commands are provided for checking the materials without running the full
#' replication:
#'
#' ```sh
#' Rscript code.R --quick
#' Rscript code.R --example 3
#' ```
#'
#' `--quick` checks package loading, the manuscript wiring, the existing
#' generated outputs, and the test suite without refitting every example.
#' `--example 3` reruns only the Big Tree water-flow example and its manifest
#' checks. The same pattern works for examples 1, 2, and 4.
#'
#' The script uses an installed `exdqlm` package by default. To reproduce with a
#' local package source tree during development, set `EXDQLM_LOAD_MODE=source`
#' and `EXDQLM_PKG_PATH=/path/to/exdqlm` before running this script.
#'
#' All manuscript runs initialize the random-number generator to
#' `Mersenne-Twister / Inversion / Rejection` through the manuscript setup file.
#' Runtime values are elapsed fitting times on the machine used for the run, so
#' small differences across platforms are expected.
#'
#' The replication writes outputs under `analysis/manuscript/outputs/`:
#'
#' - `figures/`: manuscript figures.
#' - `tables/`: generated tables, manifests, and provenance files.
#' - `logs/`: text logs and `sessionInfo()`.
#' - `cache/`: cached model fits used to avoid unnecessary refits.
#'
#' The code printed in the manuscript is a compact excerpt of the same
#' workflows. The full executable example scripts live in
#' `analysis/manuscript/examples/` and are sourced below in manuscript order.
#'
#' JSS encourages an execution log generated from the replication script. For R
#' submissions this can be refreshed with:
#'
#' ```r
#' Sys.setenv(EXDQLM_REPLICATION_QUICK = "true")
#' knitr::spin("code.R", knit = TRUE)
#' ```
#'
#' The quick flag keeps the HTML refresh inexpensive. For final reference
#' regeneration, run `Rscript code.R` before refreshing the archive.

env_flag <- function(name, default = FALSE) {
  value <- Sys.getenv(name, unset = if (isTRUE(default)) "true" else "false")
  tolower(trimws(value)) %in% c("true", "1", "yes", "y")
}

find_article_root <- function(start = getwd()) {
  cur <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(cur, "exdqlm-jss.tex")) &&
        dir.exists(file.path(cur, "analysis", "manuscript", "examples"))) {
      return(cur)
    }
    parent <- dirname(cur)
    if (identical(parent, cur)) {
      stop("Could not locate the replication-materials root containing exdqlm-jss.tex.", call. = FALSE)
    }
    cur <- parent
  }
}

example_targets <- function(example) {
  example <- tolower(trimws(as.character(example)))
  switch(
    example,
    "1" = "ex1",
    "ex1" = "ex1",
    "lake_huron" = "ex1",
    "lake-huron" = "ex1",
    "2" = "ex2",
    "ex2" = "ex2",
    "sunspots" = "ex2",
    "3" = "ex3",
    "ex3" = "ex3",
    "big_tree" = "ex3",
    "big-tree" = "ex3",
    "4" = "ex4",
    "ex4" = "ex4",
    "static" = "ex4",
    stop("`--example` must be one of 1, 2, 3, or 4.", call. = FALSE)
  )
}

parse_replication_args <- function(args) {
  out <- list(
    profile = "standard",
    quick = env_flag("EXDQLM_REPLICATION_QUICK") || env_flag("EXDQLM_BUILDING_CODE_HTML"),
    example = Sys.getenv("EXDQLM_REPLICATION_EXAMPLE", unset = ""),
    show_help = FALSE
  )

  i <- 1L
  while (i <= length(args)) {
    arg <- args[[i]]
    if (arg == "--quick") {
      out$quick <- TRUE
    } else if (arg == "--example") {
      i <- i + 1L
      if (i > length(args)) stop("`--example` requires a value.", call. = FALSE)
      out$example <- args[[i]]
    } else if (arg %in% c("--help", "-h")) {
      out$show_help <- TRUE
    } else {
      stop(sprintf("Unknown argument: %s. Run `Rscript code.R --help` for usage.", arg), call. = FALSE)
    }
    i <- i + 1L
  }

  if (isTRUE(out$quick)) {
    out$profile <- "quick"
  }
  out$targets <- if (nzchar(out$example)) example_targets(out$example) else character(0)
  out
}

print_help <- function() {
  cat(
    "Usage:\n",
    "  Rscript code.R\n",
    "  Rscript code.R --quick\n",
    "  Rscript code.R --example 3\n\n",
    "Options:\n",
    "  --quick       Run a fast wiring/test pass using the quick profile.\n",
    "  --example N   Rerun one manuscript example, where N is 1, 2, 3, or 4.\n",
    "  --help        Show this help message.\n\n",
    "Package loading:\n",
    "  By default the script loads the installed exdqlm package. For development\n",
    "  source runs, set EXDQLM_LOAD_MODE=source and EXDQLM_PKG_PATH=/path/to/exdqlm.\n",
    sep = ""
  )
}

clear_manuscript_outputs <- function(stage_root) {
  for (subdir in c("figures", "tables", "logs")) {
    path <- file.path(stage_root, "outputs", subdir)
    if (!dir.exists(path)) next
    files <- list.files(path, full.names = TRUE, recursive = TRUE)
    if (length(files)) unlink(files, recursive = TRUE, force = TRUE)
  }
}

source_manuscript_step <- function(env, path, label) {
  env$log_msg(sprintf("Running %s", label))
  source(path, local = env)
  invisible(TRUE)
}

run_manuscript_tests <- function(repo_root) {
  if (!requireNamespace("testthat", quietly = TRUE)) {
    stop("The testthat package is required to run the manuscript checks.", call. = FALSE)
  }
  Sys.setenv(EXDQLM_ARTICLE_REPO = repo_root)
  testthat::test_dir(file.path(repo_root, "analysis", "manuscript", "tests"), reporter = "summary")
  invisible(TRUE)
}

args <- parse_replication_args(commandArgs(trailingOnly = TRUE))
if (isTRUE(args$show_help)) {
  print_help()
  quit(status = 0)
}

repo_root <- find_article_root()
setwd(repo_root)

if (!nzchar(Sys.getenv("EXDQLM_LOAD_MODE", unset = ""))) {
  Sys.setenv(EXDQLM_LOAD_MODE = "installed")
}
Sys.setenv(EXDQLM_REFERENCE_SYNC = "false")
if (!nzchar(Sys.getenv("TZ", unset = ""))) {
  Sys.setenv(TZ = "America/New_York")
}

replication_env <- new.env(parent = globalenv())
replication_env$repo_root <- repo_root
replication_env$project_stage <- "manuscript"
replication_env$profile <- args$profile
replication_env$pkg_path <- Sys.getenv("EXDQLM_PKG_PATH", unset = "")
replication_env$seed_override <- NULL
replication_env$targets <- args$targets
replication_env$force_refit <- FALSE

cat("== exdqlm article replication ==\n")
cat(sprintf("Working directory: %s\n", repo_root))
cat(sprintf("Profile: %s\n", args$profile))
if (length(args$targets)) {
  cat(sprintf("Target: %s\n", paste(args$targets, collapse = ", ")))
} else if (isTRUE(args$quick)) {
  cat("Target: quick wiring/test pass; existing outputs are not regenerated.\n")
} else {
  cat("Target: full manuscript replication.\n")
}

source(file.path(repo_root, "analysis", "lib", "manuscript_setup.R"), local = replication_env)

manuscript_stage_root <- file.path(repo_root, "analysis", "manuscript")
example_scripts <- file.path(
  manuscript_stage_root,
  "examples",
  c(
    "ex1_lake_huron/run.R",
    "ex2_sunspots/run.R",
    "ex3_big_tree/run.R",
    "ex4_static/seed_screen.R",
    "ex4_static/run.R",
    "_manifest/run.R"
  )
)

if (isTRUE(args$quick)) {
  replication_env$log_msg("Quick pass: checking current manuscript outputs without clearing or refitting.")
} else {
  if (length(args$targets)) {
    replication_env$log_msg("Targeted run: keeping existing outputs and regenerating selected artifacts.")
  } else {
    replication_env$log_msg("Clearing previous manuscript figures, tables, and logs.")
    clear_manuscript_outputs(manuscript_stage_root)
  }

  labels <- c(
    "Example 1 (Lake Huron)",
    "Example 2 (Sunspots)",
    "Example 3 (Big Tree water flow)",
    "Example 4 seed-screen helper",
    "Example 4 (static simulation)",
    "manuscript manifest"
  )
  for (i in seq_along(example_scripts)) {
    source_manuscript_step(replication_env, example_scripts[[i]], labels[[i]])
  }
}

replication_env$log_msg("Running manuscript checks")
run_manuscript_tests(repo_root)

replication_env$write_session_info()

cat("\n== Session Info ==\n")
print(utils::sessionInfo())

cat("\nReplication complete.\n")
