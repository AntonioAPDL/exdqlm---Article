#!/usr/bin/env Rscript

#' # exdqlm Article Replication Script
#'
#' This script is the top-level reproducibility entrypoint for the article.
#' It assumes that the article repository and the companion `exdqlm` package
#' repository have been cloned next to each other, with the package checkout on
#' the article branch described in `README.md`.
#'
#' The default `quick` profile is intended as a smoke test for a fresh clone.
#' The `standard` profile is the reference profile used before synchronizing
#' manuscript figures, tables, and runtime metadata.
#'
#' Example:
#'
#' ```sh
#' EXDQLM_PKG_PATH=../exdqlm Rscript code.R --profile quick
#' EXDQLM_PKG_PATH=../exdqlm Rscript code.R --profile standard --strict
#' ```

find_repo_root <- function(start = getwd()) {
  cur <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(cur, "exdqlm-jss.tex"))) return(cur)
    parent <- dirname(cur)
    if (identical(parent, cur)) {
      stop("Could not locate repository root (exdqlm-jss.tex not found).", call. = FALSE)
    }
    cur <- parent
  }
}

parse_args <- function(args) {
  out <- list(
    profile = Sys.getenv("EXDQLM_REPRO_PROFILE", unset = "quick"),
    pkg_path = Sys.getenv("EXDQLM_PKG_PATH", unset = "../exdqlm"),
    require_r_version = Sys.getenv("EXDQLM_REQUIRED_R_VERSION", unset = "4.6.0"),
    targets = "",
    tests_only = FALSE,
    skip_preflight = FALSE,
    strict = FALSE,
    fetch = FALSE,
    force_refit = FALSE
  )

  i <- 1L
  while (i <= length(args)) {
    a <- args[[i]]
    if (a == "--profile") {
      i <- i + 1L
      out$profile <- args[[i]]
    } else if (a == "--pkg-path") {
      i <- i + 1L
      out$pkg_path <- args[[i]]
    } else if (a == "--require-r-version") {
      i <- i + 1L
      out$require_r_version <- args[[i]]
    } else if (a == "--targets") {
      i <- i + 1L
      out$targets <- args[[i]]
    } else if (a == "--tests-only") {
      out$tests_only <- TRUE
    } else if (a == "--skip-preflight") {
      out$skip_preflight <- TRUE
    } else if (a == "--strict") {
      out$strict <- TRUE
    } else if (a == "--fetch") {
      out$fetch <- TRUE
    } else if (a == "--force-refit") {
      out$force_refit <- TRUE
    } else if (a %in% c("--help", "-h")) {
      cat(
        "Usage: Rscript code.R [options]\n\n",
        "Options:\n",
        "  --profile NAME             Manuscript profile: quick, standard, or full\n",
        "  --pkg-path PATH            exdqlm source checkout. Default: EXDQLM_PKG_PATH or ../exdqlm\n",
        "  --require-r-version X.Y.Z  Minimum R version for preflight. Default: 4.6.0\n",
        "  --targets LIST             Optional comma-separated manuscript targets\n",
        "  --tests-only               Run manuscript tests without regenerating artifacts\n",
        "  --force-refit              Force recomputation for selected targets\n",
        "  --fetch                    Fetch remotes during preflight\n",
        "  --strict                   Treat preflight warnings as failures\n",
        "  --skip-preflight           Run the manuscript pipeline without preflight\n",
        "  --help                     Show this message\n",
        sep = ""
      )
      quit(status = 0)
    } else {
      stop(sprintf("Unknown argument: %s", a), call. = FALSE)
    }
    i <- i + 1L
  }
  out
}

run_step <- function(label, script, args) {
  cat(sprintf("\n== %s ==\n", label))
  cmd <- normalizePath(file.path(R.home("bin"), "Rscript"), mustWork = TRUE)
  status <- system2(cmd, c(script, args))
  if (!identical(status, 0L)) {
    stop(sprintf("%s failed with exit status %s.", label, status), call. = FALSE)
  }
  invisible(TRUE)
}

main <- function() {
  args <- parse_args(commandArgs(trailingOnly = TRUE))
  repo_root <- find_repo_root()
  setwd(repo_root)

  Sys.setenv(EXDQLM_PKG_PATH = args$pkg_path)

  if (!isTRUE(args$skip_preflight)) {
    preflight_args <- c(
      "analysis/check_reproducibility.R",
      "--stage", "manuscript",
      "--profile", args$profile,
      "--pkg-path", args$pkg_path,
      "--require-r-version", args$require_r_version
    )
    if (isTRUE(args$strict)) preflight_args <- c(preflight_args, "--strict")
    if (isTRUE(args$fetch)) preflight_args <- c(preflight_args, "--fetch")
    run_step("Preflight", preflight_args[[1]], preflight_args[-1])
  }

  run_args <- c(
    "analysis/run_all.R",
    "--stage", "manuscript",
    "--profile", args$profile,
    "--pkg-path", args$pkg_path
  )
  if (nzchar(args$targets)) run_args <- c(run_args, "--targets", args$targets)
  if (isTRUE(args$tests_only)) run_args <- c(run_args, "--tests-only")
  if (isTRUE(args$force_refit)) run_args <- c(run_args, "--force-refit")
  run_step("Manuscript pipeline", run_args[[1]], run_args[-1])

  cat("\n== Session Info ==\n")
  print(utils::sessionInfo())
}

main()
