#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

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
    stage = "manuscript",
    profile = "quick",
    pkg_path = NULL,
    strict = FALSE,
    fetch = FALSE,
    require_r_version = Sys.getenv("EXDQLM_REQUIRED_R_VERSION", unset = "")
  )
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
    } else if (a == "--fetch") {
      out$fetch <- TRUE
    } else if (a == "--require-r-version") {
      i <- i + 1L
      out$require_r_version <- args[[i]]
    } else if (a %in% c("--help", "-h")) {
      cat(
        "Usage: Rscript analysis/check_reproducibility.R [options]\n\n",
        "Options:\n",
        "  --stage exal|manuscript   Stage to check. Default: manuscript\n",
        "  --profile NAME            Manuscript profile to validate. Default: quick\n",
        "  --pkg-path PATH           exdqlm source checkout to use/check\n",
        "  --fetch                   Fetch article/package remotes before freshness checks\n",
        "  --require-r-version X.Y.Z Require at least this R version\n",
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
  out$require_r_version <- trimws(out$require_r_version)
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

fetch_git_remote <- function(path, label) {
  if (is.null(path) || !dir.exists(path) || !file.exists(file.path(path, ".git"))) {
    warn(sprintf("Cannot fetch %s remote because path is not a git checkout: %s", label, path %||% "<null>"))
    return(invisible(FALSE))
  }
  status <- system2("git", c("-C", path, "fetch", "--all", "--prune"), stdout = TRUE, stderr = TRUE)
  fetch_status <- attr(status, "status") %||% 0L
  if (!identical(as.integer(fetch_status), 0L)) {
    fail(sprintf("git fetch failed for %s checkout: %s", label, path))
    if (length(status)) cat(paste0("  ", status, "\n"), sep = "")
    return(invisible(FALSE))
  }
  ok(sprintf("fetched %s remote refs", label))
  invisible(TRUE)
}

report_git_freshness <- function(info, label, fail_when_behind = FALSE) {
  if (is.na(info$ahead) || is.na(info$behind)) {
    warn(sprintf("%s upstream freshness could not be determined.", label))
    return(invisible(FALSE))
  }

  line("ahead/behind", sprintf("%s/%s relative to upstream", info$ahead, info$behind))
  if (info$behind > 0L) {
    msg <- sprintf("%s checkout is behind upstream by %d commit(s). Pull/update before relaunching examples.", label, info$behind)
    if (fail_when_behind) fail(msg) else warn(msg)
  } else if (info$ahead > 0L) {
    warn(sprintf("%s checkout is ahead of upstream by %d commit(s); generated artifacts may not match the remote branch.", label, info$ahead))
  } else {
    ok(sprintf("%s checkout is up to date with upstream", label))
  }
  invisible(TRUE)
}

check_r_version <- function(required = "") {
  section("R Runtime")
  current <- as.character(getRversion())
  line("R.version.string", R.version.string)
  line("R.home", R.home())
  line("R binary", normalizePath(file.path(R.home("bin"), "R"), mustWork = FALSE))
  line("Rscript binary", normalizePath(file.path(R.home("bin"), "Rscript"), mustWork = FALSE))
  line("PATH R", Sys.which("R") %||% NA_character_)
  if (!nzchar(required)) {
    warn("No required R version was supplied. Use --require-r-version before final example relaunches.")
    return(invisible(FALSE))
  }

  line("required minimum", required)
  current_v <- numeric_version(current)
  required_v <- numeric_version(required)
  if (current_v < required_v) {
    fail(sprintf(
      "R %s is older than required R %s. Update R before relaunching final examples.",
      current,
      required
    ))
  } else {
    ok(sprintf("R %s satisfies required minimum R %s", current, required))
  }
  invisible(TRUE)
}

read_csv_safely <- function(path) {
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL)
}

main <- function() {
  args <- parse_args(commandArgs(trailingOnly = TRUE))
  repo_root <- find_repo_root(getwd())
  analysis_root <- file.path(repo_root, "analysis")
  source(file.path(analysis_root, "lib", "exdqlm_package_resolver.R"), local = TRUE)

  load_spec <- exdqlm_resolve_load_spec()
  pkg_spec <- NULL
  if (identical(load_spec$mode, "source")) {
    pkg_spec <- exdqlm_resolve_source_spec(repo_root, pkg_path = args$pkg_path, fail_if_missing = FALSE)
  }

  if (isTRUE(args$fetch)) {
    section("Remote Freshness Fetch")
    fetch_git_remote(repo_root, "article")
    if (identical(load_spec$mode, "source") && isTRUE(pkg_spec$is_package)) {
      fetch_git_remote(pkg_spec$path, "package")
    } else if (identical(load_spec$mode, "source")) {
      warn("Package source checkout is unresolved, so package remote refs were not fetched.")
    } else {
      warn("EXDQLM_LOAD_MODE=installed: package source remote freshness cannot be fetched.")
    }
  }

  check_r_version(args$require_r_version)

  section("Article Repository")
  line("path", repo_root)
  article_git <- exdqlm_git_info(repo_root)
  line("branch", article_git$branch)
  line("upstream", article_git$upstream)
  line("commit", article_git$commit)
  line("remote", article_git$remote)
  line("dirty tracked files", article_git$dirty)
  if (isTRUE(article_git$dirty)) {
    warn("Article checkout has dirty tracked files. Commit or intentionally discard regenerated artifacts before the final reproducibility gate.")
  }
  report_git_freshness(article_git, "article", fail_when_behind = FALSE)
  if (!grepl("exdqlm---Article", article_git$remote, fixed = TRUE)) {
    fail("Article remote does not look like AntonioAPDL/exdqlm---Article.")
  } else {
    ok("article remote is exdqlm---Article")
  }

  section("exdqlm Package Source")
  line("load mode", load_spec$mode)
  if (identical(load_spec$mode, "source")) {
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
      if (isTRUE(pkg_spec$git$dirty)) {
        warn("Package checkout has dirty tracked files. Final article reruns should use a committed package state.")
      }
      report_git_freshness(pkg_spec$git, "package", fail_when_behind = TRUE)
      if (!grepl("AntonioAPDL/exdqlm", pkg_spec$git$remote, fixed = TRUE)) {
        warn("Package remote does not look like AntonioAPDL/exdqlm.")
      } else {
        ok("package remote is AntonioAPDL/exdqlm")
      }
      if (!identical(pkg_spec$version, "1.0.0")) {
        warn(sprintf("Package source version is %s, not 1.0.0.", pkg_spec$version))
      }
      if (!identical(pkg_spec$git$upstream, "origin/feature/1.0.0-jss")) {
        warn(sprintf("Package upstream is %s; expected origin/feature/1.0.0-jss for current paper work.", pkg_spec$git$upstream))
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
  manuscript_pkgs <- c("matrixStats", "coda", "dlm", "pkgload", "png")
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

  section("Canonical KL Diagnostics Wiring")
  kl_files <- file.path(repo_root, c(
    "analysis/lib/manuscript_setup.R",
    "analysis/manuscript/examples/ex2_sunspots/run.R",
    "analysis/manuscript/examples/ex3_big_tree/run.R",
    "exdqlm-jss.tex",
    "exdqlm-supplement.tex"
  ))
  kl_patterns <- c("FNN::KL", "KL\\.divergence", "ref\\.samp", "reference sample used in the KL", "nearest-neighbor estimates")
  stale_hits <- character()
  for (path in kl_files[file.exists(kl_files)]) {
    lines <- readLines(path, warn = FALSE)
    hits <- which(vapply(kl_patterns, function(pat) any(grepl(pat, lines)), logical(1)))
    if (length(hits)) {
      stale_hits <- c(stale_hits, sprintf("%s [%s]", basename(path), paste(kl_patterns[hits], collapse = ", ")))
    }
  }
  line("stale KL markers", length(stale_hits))
  if (length(stale_hits)) {
    fail(sprintf("Canonical article files still contain stale stochastic/FNN KL wording or code: %s", paste(stale_hits, collapse = "; ")))
  } else {
    ok("canonical article files use the deterministic exdqlm 1.0.0 KL diagnostics wording/code")
  }

  section("Canonical Forecast Scoring Wiring")
  scoring_files <- file.path(repo_root, c(
    "analysis/manuscript/examples/ex3_big_tree/run.R",
    "exdqlm-jss.tex"
  ))
  scoring_patterns <- c(
    "check\\.loss\\.fn",
    "crps\\.iqs",
    "check_loss_vec",
    "iqs_crps_vec",
    "interval_score_vec"
  )
  scoring_hits <- character()
  for (path in scoring_files[file.exists(scoring_files)]) {
    lines <- readLines(path, warn = FALSE)
    hits <- which(vapply(scoring_patterns, function(pat) any(grepl(pat, lines)), logical(1)))
    if (length(hits)) {
      scoring_hits <- c(scoring_hits, sprintf("%s [%s]", basename(path), paste(scoring_patterns[hits], collapse = ", ")))
    }
    if (!any(grepl("exdqlmForecastDiagnostics", lines, fixed = TRUE))) {
      scoring_hits <- c(scoring_hits, sprintf("%s [missing exdqlmForecastDiagnostics]", basename(path)))
    }
  }
  line("stale forecast scoring markers", length(scoring_hits))
  if (length(scoring_hits)) {
    fail(sprintf("Canonical Example 3 files must use package-level forecast diagnostics: %s", paste(scoring_hits, collapse = "; ")))
  } else {
    ok("Example 3 held-out forecast scores use exdqlmForecastDiagnostics")
  }

  ex3_fc_path <- file.path(repo_root, "analysis", "manuscript", "outputs", "tables", "ex3_forecast_metrics.csv")
  ex3_fc <- read_csv_safely(ex3_fc_path)
  if (!is.null(ex3_fc)) {
    stale_cols <- intersect(names(ex3_fc), c("quantile_coverage", "n_exceedances", "interval_score", "coverage", "mean_interval_width"))
    if (length(stale_cols)) {
      fail(sprintf("ex3_forecast_metrics.csv still contains non-manuscript forecast columns: %s", paste(stale_cols, collapse = ", ")))
    } else {
      ok("ex3_forecast_metrics.csv is limited to package forecast diagnostics")
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
