#!/usr/bin/env Rscript

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
  out <- list(stage = "manuscript", profile = "quick", pkg_path = NULL, strict = FALSE)
  i <- 1L
  while (i <= length(args)) {
    a <- args[[i]]
    if (a %in% c("--stage", "-s")) {
      i <- i + 1L
      out$stage <- args[[i]]
    } else if (a == "--profile") {
      i <- i + 1L
      out$profile <- args[[i]]
    } else if (a == "--pkg-path") {
      i <- i + 1L
      out$pkg_path <- args[[i]]
    } else if (a == "--strict") {
      out$strict <- TRUE
    } else if (a %in% c("--help", "-h")) {
      cat(
        "Usage: Rscript analysis/check_reproducibility.R [options]\n\n",
        "Options:\n",
        "  --stage exal|manuscript   Stage to check. Default: manuscript\n",
        "  --profile NAME            Manuscript profile to validate. Default: quick\n",
        "  --pkg-path PATH           exdqlm source checkout to use/check\n",
        "  --strict                  Treat warnings as failures\n",
        "  --help                    Show this message\n",
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

section <- function(title) cat(sprintf("\n== %s ==\n", title))
line <- function(label, value) cat(sprintf("%-28s %s\n", paste0(label, ":"), value))

problems <- new.env(parent = emptyenv())
problems$errors <- character()
problems$warnings <- character()

add_error <- function(...) {
  problems$errors <- c(problems$errors, sprintf(...))
}

add_warning <- function(...) {
  problems$warnings <- c(problems$warnings, sprintf(...))
}

ok <- function(msg) cat(sprintf("[OK]   %s\n", msg))
warn <- function(msg) {
  cat(sprintf("[WARN] %s\n", msg))
  problems$warnings <- c(problems$warnings, msg)
}
fail <- function(msg) {
  cat(sprintf("[FAIL] %s\n", msg))
  problems$errors <- c(problems$errors, msg)
}

check_packages <- function(pkgs, label) {
  section(sprintf("R Packages: %s", label))
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  for (p in setdiff(pkgs, missing)) ok(sprintf("%s available", p))
  for (p in missing) fail(sprintf("%s missing", p))
  invisible(missing)
}

read_csv_safely <- function(path) {
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL)
}

main <- function() {
  args <- parse_args(commandArgs(trailingOnly = TRUE))
  repo_root <- find_repo_root(getwd())
  analysis_root <- file.path(repo_root, "analysis")
  source(file.path(analysis_root, "lib", "exdqlm_package_resolver.R"), local = TRUE)

  section("Article Repository")
  line("path", repo_root)
  article_git <- exdqlm_git_info(repo_root)
  line("branch", article_git$branch)
  line("upstream", article_git$upstream)
  line("commit", article_git$commit)
  line("remote", article_git$remote)
  line("dirty tracked files", article_git$dirty)
  if (!grepl("exdqlm---Article", article_git$remote, fixed = TRUE)) {
    fail("Article remote does not look like AntonioAPDL/exdqlm---Article.")
  } else {
    ok("article remote is exdqlm---Article")
  }

  section("exdqlm Package Source")
  load_spec <- exdqlm_resolve_load_spec()
  line("load mode", load_spec$mode)
  if (identical(load_spec$mode, "source")) {
    pkg_spec <- exdqlm_resolve_source_spec(repo_root, pkg_path = args$pkg_path, fail_if_missing = FALSE)
    if (!isTRUE(pkg_spec$is_package)) {
      fail("No valid local exdqlm source checkout found.")
      cat("Candidate sibling paths checked:\n")
      cat(paste0("  - ", pkg_spec$candidates, "\n"), sep = "")
    } else {
      line("path", pkg_spec$path)
      line("source", pkg_spec$source)
      line("version", pkg_spec$version)
      line("branch", pkg_spec$git$branch)
      line("upstream", pkg_spec$git$upstream)
      line("commit", pkg_spec$git$commit)
      line("remote", pkg_spec$git$remote)
      line("dirty tracked files", pkg_spec$git$dirty)
      if (!grepl("AntonioAPDL/exdqlm", pkg_spec$git$remote, fixed = TRUE)) {
        warn("Package remote does not look like AntonioAPDL/exdqlm.")
      } else {
        ok("package remote is AntonioAPDL/exdqlm")
      }
      if (!grepl("^0\\.5\\.0", pkg_spec$version)) {
        warn(sprintf("Package source version is %s, not 0.5.0/0.5.0.9000.", pkg_spec$version))
      }
      if (!identical(pkg_spec$git$upstream, "origin/feature/0.5.0-crps-iqs")) {
        warn(sprintf("Package upstream is %s; expected origin/feature/0.5.0-crps-iqs for current paper work.", pkg_spec$git$upstream))
      }
    }
  } else {
    if (!is.null(load_spec$installed_lib)) line("installed lib", load_spec$installed_lib)
    if (requireNamespace("exdqlm", quietly = TRUE)) {
      line("installed version", as.character(utils::packageVersion("exdqlm")))
      ok("installed exdqlm is available")
    } else {
      fail("EXDQLM_LOAD_MODE=installed but installed exdqlm is unavailable.")
    }
  }

  common_pkgs <- c("yaml", "testthat")
  manuscript_pkgs <- c("matrixStats", "coda", "dlm", "FNN", "pkgload", "png")
  exal_pkgs <- c("ggplot2", "pkgload")
  if (args$stage == "manuscript") {
    check_packages(unique(c(common_pkgs, manuscript_pkgs)), "manuscript")
  } else if (args$stage == "exal") {
    check_packages(unique(c(common_pkgs, exal_pkgs)), "exal")
  } else {
    fail(sprintf("Unknown stage '%s'. Use exal or manuscript.", args$stage))
  }

  section("Analysis Configuration")
  cfg_path <- file.path(analysis_root, "config", "params_manuscript.yml")
  if (file.exists(cfg_path) && requireNamespace("yaml", quietly = TRUE)) {
    cfg <- yaml::read_yaml(cfg_path)
    profiles <- names(cfg$profiles)
    line("profiles", paste(profiles, collapse = ", "))
    if (!args$profile %in% profiles) {
      fail(sprintf("Profile '%s' not found in params_manuscript.yml.", args$profile))
    } else {
      ok(sprintf("profile '%s' is configured", args$profile))
    }
    ex3 <- cfg$profiles[[args$profile]]$ex3
    if (!is.null(ex3)) {
      line("ex3 fit_start", ex3$fit_start)
      line("ex3 fit_end", ex3$fit_end)
      line("ex3 forecast_horizon", ex3$forecast_horizon)
      if (!identical(as.character(ex3$fit_start), "1987-01-01")) {
        warn("Example 3 fit_start is not 1987-01-01.")
      }
    }
  } else {
    fail("Could not read analysis/config/params_manuscript.yml.")
  }

  section("Tracked Output Consistency")
  tracker_path <- file.path(repo_root, "analysis", "manuscript", "outputs", "tables", "manuscript_repro_tracker.csv")
  tracker <- read_csv_safely(tracker_path)
  if (is.null(tracker)) {
    warn("manuscript_repro_tracker.csv is absent or unreadable; run manuscript targets before final sync.")
  } else {
    required_cols <- c("artifact_id", "artifact_type", "relative_path", "manuscript_target", "status", "notes")
    missing_cols <- setdiff(required_cols, names(tracker))
    if (length(missing_cols)) {
      fail(sprintf("Tracker missing columns: %s", paste(missing_cols, collapse = ", ")))
    } else {
      rel <- tracker$relative_path[nzchar(tracker$relative_path)]
      missing_outputs <- rel[!file.exists(file.path(repo_root, rel))]
      if (length(missing_outputs)) {
        warn(sprintf("Tracker lists %d missing output file(s): %s", length(missing_outputs), paste(head(missing_outputs, 5), collapse = ", ")))
      } else {
        ok("all tracker relative paths exist on disk")
      }
      not_reproduced <- tracker$artifact_id[tracker$status == "not_reproduced"]
      if (length(not_reproduced)) {
        warn(sprintf("Tracker has not_reproduced artifact(s): %s", paste(not_reproduced, collapse = ", ")))
      }
    }
  }

  section("Example 3 Data Window")
  ex3_data_path <- file.path(repo_root, "analysis", "manuscript", "outputs", "tables", "ex3_model_dataset.csv")
  ex3_data <- read_csv_safely(ex3_data_path)
  if (is.null(ex3_data) || !"date" %in% names(ex3_data)) {
    warn("Example 3 model dataset output is absent or lacks a date column.")
  } else {
    dates <- as.Date(ex3_data$date)
    train_dates <- dates[ex3_data$model_train %in% c(TRUE, "TRUE", "True", "true", 1, "1")]
    holdout_dates <- dates[ex3_data$model_holdout %in% c(TRUE, "TRUE", "True", "true", 1, "1")]
    line("model first date", as.character(min(dates, na.rm = TRUE)))
    line("model last date", as.character(max(dates, na.rm = TRUE)))
    line("training last date", as.character(max(train_dates, na.rm = TRUE)))
    line("holdout first date", as.character(min(holdout_dates, na.rm = TRUE)))
    line("holdout months", length(holdout_dates))
    if (!identical(as.character(min(dates, na.rm = TRUE)), "1987-01-01")) {
      warn("Example 3 model dataset does not begin on 1987-01-01.")
    } else {
      ok("Example 3 model dataset begins on 1987-01-01")
    }
  }

  section("Manuscript Review Markers")
  tex_path <- file.path(repo_root, "exdqlm-jss.tex")
  if (file.exists(tex_path)) {
    tex <- readLines(tex_path, warn = FALSE)
    rp_count <- sum(grepl("From RP|color\\{magenta\\}", tex))
    line("RP/magenta markers", rp_count)
    if (rp_count > 0L) {
      warn("Manuscript still contains Raquel Prado/magenta review markers.")
    }
  }

  section("Summary")
  line("errors", length(problems$errors))
  line("warnings", length(problems$warnings))
  if (length(problems$errors)) {
    cat("\nErrors:\n")
    cat(paste0("  - ", problems$errors, "\n"), sep = "")
  }
  if (length(problems$warnings)) {
    cat("\nWarnings:\n")
    cat(paste0("  - ", problems$warnings, "\n"), sep = "")
  }

  if (length(problems$errors) || (isTRUE(args$strict) && length(problems$warnings))) {
    quit(status = 1)
  }
  quit(status = 0)
}

main()
