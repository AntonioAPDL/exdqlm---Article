#!/usr/bin/env Rscript

find_repo_root <- function(start = getwd()) {
  cur <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(cur, "exdqlm-jss.tex")) &&
        dir.exists(file.path(cur, "analysis", "manuscript", "examples"))) {
      return(cur)
    }
    parent <- dirname(cur)
    if (identical(parent, cur)) {
      stop("Could not locate the exdqlm article repository root.", call. = FALSE)
    }
    cur <- parent
  }
}

read_file <- function(path) {
  readLines(path, warn = FALSE)
}

write_file <- function(path, lines) {
  lines <- sub("[[:space:]]+$", "", lines)
  writeLines(lines, con = path, useBytes = TRUE)
}

braces_delta <- function(x) {
  stripped <- sub("#.*$", "", x)
  open_match <- gregexpr("{", stripped, fixed = TRUE)[[1L]]
  close_match <- gregexpr("}", stripped, fixed = TRUE)[[1L]]
  open <- if (open_match[[1L]] == -1L) 0L else length(open_match)
  close <- if (close_match[[1L]] == -1L) 0L else length(close_match)
  open - close
}

function_extent <- function(lines, name) {
  start <- grep(sprintf("^%s\\s*<-\\s*function\\b", name), lines)
  if (length(start) != 1L) {
    stop(sprintf("Expected exactly one function named %s, found %d.", name, length(start)), call. = FALSE)
  }
  depth <- 0L
  for (i in seq.int(start, length(lines))) {
    depth <- depth + braces_delta(lines[[i]])
    if (i > start && depth <= 0L) {
      return(c(start, i))
    }
  }
  stop(sprintf("Could not find end of function %s.", name), call. = FALSE)
}

replace_range <- function(lines, first, last, replacement) {
  c(
    if (first > 1L) lines[seq_len(first - 1L)] else character(),
    replacement,
    if (last < length(lines)) lines[seq.int(last + 1L, length(lines))] else character()
  )
}

replace_function <- function(lines, name, replacement) {
  idx <- function_extent(lines, name)
  replace_range(lines, idx[[1L]], idx[[2L]], replacement)
}

remove_matching_lines <- function(lines, pattern, fixed = FALSE) {
  lines[!grepl(pattern, lines, fixed = fixed)]
}

replace_line <- function(lines, pattern, replacement, fixed = FALSE) {
  idx <- grep(pattern, lines, fixed = fixed)
  if (length(idx) != 1L) {
    stop(sprintf("Expected exactly one line matching %s, found %d.", pattern, length(idx)), call. = FALSE)
  }
  replace_range(lines, idx, idx, replacement)
}

replace_between <- function(lines, start_pattern, end_pattern, replacement, fixed = FALSE) {
  first <- grep(start_pattern, lines, fixed = fixed)
  last <- grep(end_pattern, lines, fixed = fixed)
  if (length(first) != 1L || length(last) != 1L || first >= last) {
    stop(
      sprintf(
        "Could not replace block from %s to %s (starts=%d, ends=%d).",
        start_pattern, end_pattern, length(first), length(last)
      ),
      call. = FALSE
    )
  }
  replace_range(lines, first, last - 1L, replacement)
}

dput_lines <- function(object, name) {
  c(
    sprintf("%s <-", name),
    paste0("  ", utils::capture.output(dput(object)))
  )
}

sanitize_setup <- function(lines, cfg_params) {
  lines <- gsub('"yaml",\\s*', "", lines)
  lines <- replace_line(
    lines,
    "cache_dir <- file.path(output_root, \"cache\")",
    "# The generated JSS scripts refit all manuscript computations.",
    fixed = TRUE
  )
  lines <- replace_line(
    lines,
    "for (d in c(figures_dir, tables_dir, logs_dir, cache_dir)) ensure_dir(d)",
    "for (d in c(figures_dir, tables_dir, logs_dir)) ensure_dir(d)",
    fixed = TRUE
  )
  lines <- replace_line(
    lines,
    "cfg_params <- yaml::read_yaml(file.path(analysis_root, \"config\", \"params_manuscript.yml\"))",
    dput_lines(cfg_params, "cfg_params"),
    fixed = TRUE
  )
  lines <- remove_matching_lines(
    lines,
    "source(file.path(analysis_root, \"lib\", \"exdqlm_package_resolver.R\"), local = TRUE)",
    fixed = TRUE
  )
  lines <- replace_function(
    lines,
    "resolve_pkg_path",
    c(
      "resolve_pkg_path <- function(fail_if_missing = FALSE) {",
      "  list(path = NA_character_, candidate = \"installed\")",
      "}"
    )
  )
  lines <- replace_function(
    lines,
    "load_exdqlm",
    c(
      "load_exdqlm <- function() {",
      "  suppressPackageStartupMessages(library(\"exdqlm\"))",
      "  found_version <- as.character(utils::packageVersion(\"exdqlm\"))",
      "  expected_version <- as.character(cfg_params$expected_exdqlm_version)",
      "  log_msg(sprintf(\"Loaded installed exdqlm version %s\", found_version))",
      "  if (!identical(found_version, expected_version)) {",
      "    stop(sprintf(\"This replication script requires exdqlm %s; found %s\", expected_version, found_version), call. = FALSE)",
      "  }",
      "  invisible(TRUE)",
      "}"
    )
  )
  for (fn in c("safe_system_output", "git_short_head", "git_branch", "git_upstream", "git_dirty_state")) {
    lines <- replace_function(lines, fn, c(sprintf("%s <- function(...) NA_character_", fn)))
  }
  lines <- replace_function(
    lines,
    "cache_file",
    c(
      "jss_step_file <- function(step_id) {",
      "  file.path(logs_dir, sprintf(\"%s_%s.txt\", step_id, selected_profile))",
      "}"
    )
  )
  lines <- replace_function(
    lines,
    "git_state_snapshot",
    c(
      "git_state_snapshot <- function(path) {",
      "  list(path = NA_character_, identifier = \"installed package\")",
      "}"
    )
  )
  replacements <- c(
    git_short_head = "source_identifier",
    git_branch = "source_branch_placeholder",
    git_upstream = "source_remote_placeholder",
    git_dirty_state = "source_state_placeholder",
    git_state_snapshot = "source_state_snapshot",
    article_git_at_setup = "article_state_at_setup",
    pkg_git_at_setup = "pkg_state_at_setup",
    exdqlm_commit = "exdqlm_source"
  )
  for (from in names(replacements)) {
    lines <- gsub(from, replacements[[from]], lines, fixed = TRUE)
  }
  lines <- gsub("pkg_state_at_setup$commit", "pkg_state_at_setup$identifier", lines, fixed = TRUE)
  lines <- replace_function(
    lines,
    "load_or_fit_cache",
    c(
      "run_step <- function(step_id, expr, note = NULL) {",
      "  eval.parent(substitute(expr))",
      "}"
    )
  )
  lines
}

sanitize_ex4_helpers <- function(lines) {
  lines <- replace_function(
    lines,
    "ex4_load_or_fit_cache_safe",
    c(
      "ex4_run_step <- function(step_id, expr, note = NULL) {",
      "  eval.parent(substitute(expr))",
      "}"
    )
  )
  gsub("ex4_seed_screen_cache_key", "ex4_seed_screen_step_id", lines, fixed = TRUE)
}

sanitize_example <- function(lines) {
  lines <- remove_matching_lines(lines, "source(file.path(", fixed = TRUE)
  if (any(grepl("ex4_obj <- NULL", lines, fixed = TRUE))) {
    lines <- replace_between(
      lines,
      "  ex4_obj <- NULL",
      "  capture_output_file(\"ex4_run_summary.txt\", {",
      c(
        "  ex4_obj <- ex4_load_or_fit_cache_safe(",
        "    cache_key,",
        "    ex4_fit_seed(ex4_seed, cfg_ex4, stop_on_failure = TRUE),",
        "    note = cache_key",
        "  )"
      ),
      fixed = TRUE
    )
  }
  lines <- gsub("ex4_load_or_fit_cache_safe", "ex4_run_step", lines, fixed = TRUE)
  lines <- gsub("load_or_fit_cache", "run_step", lines, fixed = TRUE)
  lines <- gsub("ex4_seed_screen_cache_key", "ex4_seed_screen_step_id", lines, fixed = TRUE)
  lines <- gsub("trace_cache_key", "trace_step_id", lines, fixed = TRUE)
  lines <- gsub("screen_cache_key", "screen_step_id", lines, fixed = TRUE)
  lines <- gsub("cache_key", "step_id", lines, fixed = TRUE)
  lines <- gsub(
    "Lake Huron uses cached fits; ex1mcmc uses a dedicated high-iteration median MCMC chain, and runtime statements are profile-dependent (see ex1_run_summary).",
    "Lake Huron refits the manuscript models; ex1mcmc uses a dedicated high-iteration median MCMC chain, and runtime statements are profile-dependent (see ex1_run_summary).",
    lines,
    fixed = TRUE
  )
  lines
}

script_header <- function(profile, authoritative) {
  profile_label <- if (identical(profile, "standard")) "full manuscript replication" else "reduced code-checking run"
  c(
    "#!/usr/bin/env Rscript",
    "",
    "#' # exdqlm JSS replication script",
    "#'",
    sprintf("#' This file is the %s for the JSS article", profile_label),
    "#' \"exdqlm: An R Package for Estimation and Analysis of Flexible Dynamic",
    "#' Quantile Linear Models\".",
    "#'",
    "#' Run from the extracted replication-materials directory with:",
    "#'",
    if (authoritative) "#' ```sh\n#' R CMD BATCH --vanilla code.R code.Rout\n#' ```" else "#' ```sh\n#' R CMD BATCH --vanilla code-fast.R code-fast.Rout\n#' ```",
    "#'",
    if (authoritative) {
      "#' This is the authoritative script for the manuscript values. It refits the examples, regenerates the manuscript figures, prints the numerical tables and selected fitted-object output, and records the computational environment."
    } else {
      "#' This reduced script follows the same workflow with smaller Monte Carlo settings. It is for checking code paths and is not authoritative for manuscript numerical values."
    },
    "#'",
    "#' The script is intentionally flat: it contains the setup code, helper code, and example code in manuscript order.",
    "",
    "jss_start_time <- proc.time()[[3L]]",
    "repo_root <- normalizePath(getwd(), winslash = \"/\", mustWork = TRUE)",
    sprintf("profile <- \"%s\"", profile),
    "pkg_path <- \"\"",
    "seed_override <- NULL",
    "targets <- character(0)",
    "force_refit <- TRUE",
    "Sys.setenv(",
    "  TZ = \"America/New_York\",",
    "  OMP_NUM_THREADS = Sys.getenv(\"OMP_NUM_THREADS\", unset = \"1\"),",
    "  OMP_THREAD_LIMIT = Sys.getenv(\"OMP_THREAD_LIMIT\", unset = \"1\"),",
    "  OPENBLAS_NUM_THREADS = Sys.getenv(\"OPENBLAS_NUM_THREADS\", unset = \"1\"),",
    "  MKL_NUM_THREADS = Sys.getenv(\"MKL_NUM_THREADS\", unset = \"1\"),",
    "  BLIS_NUM_THREADS = Sys.getenv(\"BLIS_NUM_THREADS\", unset = \"1\"),",
    "  VECLIB_MAXIMUM_THREADS = Sys.getenv(\"VECLIB_MAXIMUM_THREADS\", unset = \"1\")",
    ")",
    "RNGversion(\"4.6.0\")",
    "RNGkind(\"Mersenne-Twister\", \"Inversion\", \"Rejection\")",
    "",
    "cat(\"== exdqlm JSS replication ==\\n\")",
    sprintf("cat(\"Profile: %s\\n\")", profile),
    sprintf("cat(\"Authoritative manuscript values: %s\\n\")", if (authoritative) "yes" else "no"),
    "cat(sprintf(\"R: %s\\n\", R.version.string))",
    "cat(sprintf(\"Working directory: %s\\n\", repo_root))",
    "cat(sprintf(\"RNGkind: %s\\n\", paste(RNGkind(), collapse = \" / \")))",
    "cat(\"Thread environment:\\n\")",
    "print(Sys.getenv(c(\"OMP_NUM_THREADS\", \"OMP_THREAD_LIMIT\", \"OPENBLAS_NUM_THREADS\", \"MKL_NUM_THREADS\", \"BLIS_NUM_THREADS\", \"VECLIB_MAXIMUM_THREADS\"), unset = NA_character_))",
    "",
    "if (file.exists(\"Rplots.pdf\")) unlink(\"Rplots.pdf\", force = TRUE)",
    "grDevices::pdf(\"Rplots.pdf\", onefile = TRUE)",
    "options(exdqlm.jss_rplots_active = TRUE)",
    "on.exit({",
    "  if (isTRUE(getOption(\"exdqlm.jss_rplots_active\", FALSE))) {",
    "    grDevices::dev.off()",
    "    options(exdqlm.jss_rplots_active = FALSE)",
    "  }",
    "}, add = TRUE)"
  )
}

save_png_override <- c(
  "save_png_plot <- function(filename, expr,",
  "                          width = cfg_params$figures$width,",
  "                          height = cfg_params$figures$height,",
  "                          res = cfg_params$figures$res,",
  "                          pointsize = cfg_params$figures$pointsize) {",
  "  plot_expr <- substitute(expr)",
  "  path <- file.path(figures_dir, filename)",
  "  png_type <- if (isTRUE(capabilities(\"cairo\"))) \"cairo\" else getOption(\"bitmapType\", \"Xlib\")",
  "  grDevices::png(filename = path, width = width, height = height, units = \"in\", res = res, pointsize = pointsize, type = png_type)",
  "  tryCatch(",
  "    eval.parent(plot_expr),",
  "    finally = grDevices::dev.off()",
  "  )",
  "  manuscript_figures <- as.character(cfg_params$promotion$figures %||% character())",
  "  if (isTRUE(getOption(\"exdqlm.jss_rplots_active\", FALSE)) && filename %in% manuscript_figures) {",
  "    eval.parent(plot_expr)",
  "  }",
  "  invisible(path)",
  "}"
)

final_output_block <- function(batch_output) c(
  "print_jss_heading <- function(label) {",
  "  cat(\"\\n\")",
  "  cat(strrep(\"=\", 72), \"\\n\", sep = \"\")",
  "  cat(label, \"\\n\", sep = \"\")",
  "  cat(strrep(\"=\", 72), \"\\n\", sep = \"\")",
  "}",
  "",
  "print_csv_table <- function(label, relative_path) {",
  "  print_jss_heading(label)",
  "  path <- file.path(repo_root, relative_path)",
  "  if (!file.exists(path)) stop(sprintf(\"Required table is missing: %s\", relative_path), call. = FALSE)",
  "  print(utils::read.csv(path, stringsAsFactors = FALSE), row.names = FALSE)",
  "}",
  "",
  "print_jss_heading(\"M95\")",
  "print(M95)",
  "print_jss_heading(\"summary(M95)\")",
  "print(summary(M95))",
  "print_jss_heading(\"MTF$median.kt\")",
  "print(MTF$median.kt)",
  "print_csv_table(\"Table 7 / tab:ex2bench\", \"analysis/manuscript/outputs/tables/ex2_dynamic_benchmark.csv\")",
  "print_csv_table(\"Table 8 / tab:ex3\", \"analysis/manuscript/outputs/tables/ex3_diagnostics_summary.csv\")",
  "print_csv_table(\"Table 9 / tab:ex3forecastmetrics\", \"analysis/manuscript/outputs/tables/ex3_forecast_metrics.csv\")",
  "print_csv_table(\"Table 10 / tab:ex4static\", \"analysis/manuscript/outputs/tables/ex4static_summary.csv\")",
  "print_jss_heading(\"sessionInfo()\")",
  "print(utils::sessionInfo())",
  "cat(sprintf(\"\\nTotal elapsed seconds: %.3f\\n\", proc.time()[[3L]] - jss_start_time))",
  "if (isTRUE(getOption(\"exdqlm.jss_rplots_active\", FALSE))) {",
  "  grDevices::dev.off()",
  "  options(exdqlm.jss_rplots_active = FALSE)",
  "}",
  sprintf("cat(\"\\nReplication complete. Primary batch artifacts: %s and Rplots.pdf.\\n\")", batch_output)
)

validate_generated <- function(path) {
  txt <- paste(read_file(path), collapse = "\n")
  forbidden <- c(
    "source(",
    "readRDS(",
    "saveRDS(",
    "EXDQLM_LOAD_MODE",
    "EXDQLM_PKG_PATH",
    "run_all.R",
    "--quick",
    "--example",
    "parse_replication_args"
  )
  bad <- forbidden[vapply(forbidden, grepl, logical(1), x = txt, fixed = TRUE)]
  if (length(bad)) {
    stop(
      sprintf("Generated script %s contains forbidden public-archive token(s): %s", basename(path), paste(bad, collapse = ", ")),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

build_script <- function(repo_root, profile, out_file, authoritative = identical(profile, "standard")) {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("The yaml package is required to build the generated scripts.", call. = FALSE)
  }
  cfg_params <- yaml::read_yaml(file.path(repo_root, "analysis", "config", "params_manuscript.yml"))
  cfg_params$profile <- profile
  cfg_params$profiles <- cfg_params$profiles[profile]
  cfg_params$expected_exdqlm_version <- "1.1.1"

  setup <- sanitize_setup(read_file(file.path(repo_root, "analysis", "lib", "manuscript_setup.R")), cfg_params)
  ex4_helpers <- sanitize_ex4_helpers(read_file(file.path(repo_root, "analysis", "manuscript", "examples", "ex4_static", "helpers.R")))
  examples <- lapply(
    file.path(
      repo_root,
      "analysis",
      "manuscript",
      "examples",
      c(
        "ex1_lake_huron/run.R",
        "ex2_sunspots/run.R",
        "ex3_big_tree/run.R",
        "ex4_static/run.R",
        "_manifest/run.R"
      )
    ),
    function(path) c(sprintf("\n# ---- %s ----", basename(dirname(path))), sanitize_example(read_file(path)))
  )

  lines <- c(
    script_header(profile, authoritative),
    "",
    "# ---- inlined manuscript setup ----",
    setup,
    "",
    "# ---- JSS-facing plotting override ----",
    save_png_override,
    "",
    "# ---- inlined Example 4 helpers ----",
    ex4_helpers,
    "",
    unlist(examples, use.names = FALSE),
    "",
    "# ---- stable batch-visible outputs ----",
    final_output_block(if (authoritative) "code.Rout" else "code-fast.Rout")
  )

  write_file(out_file, lines)
  Sys.chmod(out_file, mode = "0755")
  validate_generated(out_file)
  invisible(out_file)
}

repo_root <- find_repo_root()
build_script(repo_root, "standard", file.path(repo_root, "code.R"), authoritative = TRUE)
build_script(repo_root, "quick", file.path(repo_root, "code-fast.R"), authoritative = FALSE)
cat("Generated code.R and code-fast.R\n")
