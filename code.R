#!/usr/bin/env Rscript

#' # exdqlm Article Replication Script
#'
#' This file is the standalone replication entrypoint for the `exdqlm`
#' article. It wraps the manuscript pipeline in `analysis/` and is the file to
#' run from a fresh clone, an Overleaf source download, or a final reference
#' checkout.
#'
#' The script can load `exdqlm` in two ways. Source mode is the default and
#' uses a companion package checkout, usually supplied by
#' `EXDQLM_PKG_PATH=../exdqlm` or `--pkg-path ../exdqlm`. Installed-package mode
#' is useful for reviewer and Overleaf-source checks:
#'
#' ```sh
#' EXDQLM_LOAD_MODE=installed Rscript code.R --profile quick --mode portable --tests-only --skip-preflight
#' ```
#'
#' ## Reproducibility profiles and modes
#'
#' The `quick` profile is a smoke-test profile. The `standard` profile is the
#' manuscript replication profile used for the reported examples. Two
#' reproducibility modes are available:
#'
#' - `portable` verifies that the pipeline runs and produces coherent figures,
#'   tables, manifests, diagnostics, package provenance, and finite numerical
#'   summaries on the current machine. It does not require exact equality with
#'   reference-machine runtimes or simulation-based diagnostics.
#' - `reference` additionally requires exact agreement between generated values
#'   and values printed in the manuscript. Use it only on the documented
#'   reference machine before synchronizing manuscript tables and runtimes.
#'
#' All manuscript runs set the random-number generator explicitly to
#' `Mersenne-Twister / Inversion / Rejection` before the configured seed is
#' applied. The manuscript benchmark profile uses one C++ thread and keeps the
#' C++ sampler backend disabled. Runtime values are therefore reference-profile
#' elapsed fitting times, not machine-independent constants.
#'
#' ## Main commands
#'
#' ```sh
#' EXDQLM_PKG_PATH=../exdqlm Rscript code.R --profile quick --mode portable --tests-only
#' EXDQLM_PKG_PATH=../exdqlm Rscript code.R --profile standard --mode portable
#' EXDQLM_PKG_PATH=../exdqlm Rscript code.R --profile standard --mode reference --strict
#' ```
#'
#' The first command is a cheap smoke test. The second command regenerates the
#' manuscript artifacts in portable mode. The third command is the final
#' reference-machine acceptance gate.
#'
#' ## Manuscript output map
#'
#' The manuscript pipeline regenerates artifacts under
#' `analysis/manuscript/outputs/`:
#'
#' - Example 1, Lake Huron: dynamic quantile fits, forecasts, trace diagnostics,
#'   and posterior-predictive synthesis artifacts.
#' - Example 2, Sunspots: AL/exAL dynamic diagnostics, discount-factor scans,
#'   runtime/diagnostic benchmark tables, and LDVB diagnostic plots.
#' - Example 3, Big Tree water flow: no-covariate, direct-regression, and
#'   transfer-function fits; component plots; held-out forecast diagnostics.
#' - Example 4, static simulation: quantile-specific sparse exAL LDVB/MCMC
#'   comparison figure and table.
#'
#' The tracker files in `analysis/manuscript/outputs/tables/` map generated
#' files back to manuscript figures and tables.
#'
#' ## Creating the JSS HTML replication log
#'
#' JSS encourages an output file created from this script. The safe portable
#' HTML check uses the quick tests-only profile, which validates the wiring
#' without overwriting manuscript artifacts:
#'
#' ```r
#' Sys.setenv(EXDQLM_PKG_PATH = "../exdqlm")
#' Sys.setenv(EXDQLM_REPRO_PROFILE = "quick")
#' Sys.setenv(EXDQLM_REPRO_MODE = "portable")
#' Sys.setenv(EXDQLM_REPRO_TESTS_ONLY = "true")
#' Sys.setenv(EXDQLM_SKIP_PREFLIGHT = "true")
#' Sys.setenv(EXDQLM_BUILDING_CODE_HTML = "true")
#' knitr::spin("code.R", knit = TRUE)
#' ```
#'
#' For the final article bundle, run the standard portable or reference command
#' directly before creating or refreshing `code.html`.

env_flag <- function(name, default = FALSE) {
  value <- tolower(trimws(Sys.getenv(name, unset = if (isTRUE(default)) "true" else "false")))
  value %in% c("true", "1", "yes", "y")
}

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
    mode = Sys.getenv("EXDQLM_REPRO_MODE", unset = "portable"),
    pkg_path = Sys.getenv("EXDQLM_PKG_PATH", unset = "../exdqlm"),
    require_r_version = Sys.getenv("EXDQLM_REQUIRED_R_VERSION", unset = "4.6.0"),
    targets = "",
    tests_only = env_flag("EXDQLM_REPRO_TESTS_ONLY"),
    skip_preflight = env_flag("EXDQLM_SKIP_PREFLIGHT"),
    strict = env_flag("EXDQLM_REPRO_STRICT"),
    fetch = env_flag("EXDQLM_REPRO_FETCH"),
    force_refit = env_flag("EXDQLM_FORCE_REFIT")
  )

  i <- 1L
  while (i <= length(args)) {
    a <- args[[i]]
    if (a == "--profile") {
      i <- i + 1L
      out$profile <- args[[i]]
    } else if (a == "--mode") {
      i <- i + 1L
      out$mode <- args[[i]]
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
        "  --mode MODE                Reproducibility mode: portable or reference\n",
        "  --pkg-path PATH            exdqlm source checkout. Default: EXDQLM_PKG_PATH or ../exdqlm\n",
        "  --require-r-version X.Y.Z  Minimum R version for preflight. Default: 4.6.0\n",
        "  --targets LIST             Optional comma-separated manuscript targets\n",
        "  --tests-only               Run manuscript tests without regenerating artifacts\n",
        "  --force-refit              Force recomputation for selected targets\n",
        "  --fetch                    Fetch remotes during preflight\n",
        "  --strict                   Treat preflight warnings as failures\n",
        "  --skip-preflight           Run the manuscript pipeline without preflight\n",
        "  --help                     Show this message\n",
        "\nEnvironment defaults:\n",
        "  EXDQLM_REPRO_PROFILE       Default profile when --profile is omitted\n",
        "  EXDQLM_REPRO_MODE          Default mode when --mode is omitted\n",
        "  EXDQLM_REPRO_TESTS_ONLY    If true, run tests without regenerating artifacts\n",
        "  EXDQLM_SKIP_PREFLIGHT      If true, skip preflight\n",
        "  EXDQLM_LOAD_MODE           source or installed package loading\n",
        sep = ""
      )
      quit(status = 0)
    } else {
      stop(sprintf("Unknown argument: %s", a), call. = FALSE)
    }
    i <- i + 1L
  }
  out$mode <- tolower(trimws(out$mode))
  if (!out$mode %in% c("portable", "reference")) {
    stop("--mode must be either 'portable' or 'reference'.", call. = FALSE)
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

  if (identical(args$mode, "reference")) {
    args$strict <- TRUE
  }

  Sys.setenv(
    EXDQLM_PKG_PATH = args$pkg_path,
    EXDQLM_REPRO_MODE = args$mode,
    EXDQLM_REFERENCE_SYNC = if (identical(args$mode, "reference")) "true" else "false"
  )

  cat(sprintf("== Reproducibility Mode ==\n%s\n", args$mode))

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
    "--mode", args$mode,
    "--pkg-path", args$pkg_path
  )
  if (nzchar(args$targets)) run_args <- c(run_args, "--targets", args$targets)
  if (isTRUE(args$tests_only)) run_args <- c(run_args, "--tests-only")
  if (isTRUE(args$force_refit)) run_args <- c(run_args, "--force-refit")
  run_step("Manuscript pipeline", run_args[[1]], run_args[-1])

  cat("\n== Session Info ==\n")
  if (!nzchar(Sys.getenv("TZ", unset = ""))) {
    Sys.setenv(TZ = "America/New_York")
  }
  print(utils::sessionInfo())
}

main()
