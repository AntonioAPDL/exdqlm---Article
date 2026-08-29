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

paren_delta <- function(x) {
  stripped <- sub("#.*$", "", x)
  open_match <- gregexpr("(", stripped, fixed = TRUE)[[1L]]
  close_match <- gregexpr(")", stripped, fixed = TRUE)[[1L]]
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

remove_call_blocks <- function(lines, call_name) {
  out <- character()
  i <- 1L
  pattern <- sprintf("\\b%s\\s*\\(", call_name)
  while (i <= length(lines)) {
    if (!grepl(pattern, lines[[i]])) {
      out <- c(out, lines[[i]])
      i <- i + 1L
      next
    }

    depth <- 0L
    repeat {
      depth <- depth + paren_delta(lines[[i]])
      i <- i + 1L
      if (i > length(lines) || depth <= 0L) break
    }
  }
  out
}

replace_assignment_call <- function(lines, name, replacement) {
  idx <- grep(sprintf("^\\s*%s\\s*<-", name), lines)
  if (length(idx) == 0L) return(lines)
  if (length(idx) > 1L) {
    stop(sprintf("Expected at most one assignment to %s, found %d.", name, length(idx)), call. = FALSE)
  }
  first <- idx[[1L]]
  depth <- 0L
  last <- first
  for (i in seq.int(first, length(lines))) {
    depth <- depth + paren_delta(lines[[i]])
    last <- i
    if (i > first && depth <= 0L) break
    if (i == first && depth <= 0L) break
  }
  replace_range(lines, first, last, replacement)
}

rename_public_terms <- function(lines) {
  replacements <- c(
    selected_profile = "selected_run",
    cfg_profile = "cfg_run",
    cfg_benchmark_profiles = "cfg_benchmark_settings",
    selected_benchmark_profile = "selected_benchmark_setting",
    benchmark_profiles_table = "benchmark_settings_table",
    apply_backend_profile = "apply_backend_settings",
    with_backend_profile = "with_backend_settings",
    load_or_fit_cache = "run_step",
    ex4_load_or_fit_cache_safe = "ex4_run_step",
    trace_cache_key = "trace_step_id",
    cache_key = "step_id",
    artifact_id = "output_id",
    artifact_type = "output_type",
    artifact_registry = "output_registry",
    register_artifact = "record_output",
    register_note = "record_note",
    manuscript_target = "manuscript_label",
    benchmark_profiles = "benchmark_settings",
    manuscript_benchmark_profile = "manuscript_benchmark_setting",
    profiles = "run_settings"
  )
  for (from in names(replacements)) {
    lines <- gsub(from, replacements[[from]], lines, fixed = TRUE)
  }
  lines <- gsub("Profile", "Settings", lines, fixed = TRUE)
  lines <- gsub("profile", "settings", lines, fixed = TRUE)
  lines <- gsub("cached", "stored", lines, fixed = TRUE)
  lines <- gsub("cache", "stored result", lines, fixed = TRUE)
  lines <- gsub("authoritative", "full", lines, fixed = TRUE)
  lines <- gsub("artifacts", "outputs", lines, fixed = TRUE)
  lines <- gsub("artifact", "output", lines, fixed = TRUE)
  lines
}

dput_lines <- function(object, name) {
  c(
    sprintf("%s <-", name),
    paste0("  ", utils::capture.output(dput(object)))
  )
}

sanitize_setup <- function(lines, cfg_params) {
  lines <- gsub('"yaml",\\s*', "", lines)
  lines <- replace_between(
    lines,
    "analysis_root <- file.path(repo_root, \"analysis\")",
    "for (d in c(figures_dir, tables_dir, logs_dir, cache_dir)) ensure_dir(d)",
    c(
      "analysis_root <- file.path(repo_root, \"analysis\")",
      "figures_dir <- file.path(repo_root, \"figures\")",
      "tables_dir <- file.path(repo_root, \"tables\")",
      "logs_dir <- file.path(repo_root, \"logs\")",
      "",
      "for (d in c(figures_dir, tables_dir, logs_dir)) ensure_dir(d)"
    ),
    fixed = TRUE
  )
  lines <- remove_matching_lines(
    lines,
    "for (d in c(figures_dir, tables_dir, logs_dir, cache_dir)) ensure_dir(d)",
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
    if (fn == "safe_system_output") next
    lines <- replace_function(lines, fn, character())
  }
  lines <- replace_function(
    lines,
    "git_state_snapshot",
    c(
      "source_state_snapshot <- function(path) {",
      "  list(path = NA_character_, identifier = \"CRAN package\")",
      "}"
    )
  )
  lines <- replace_function(
    lines,
    "cache_file",
    c(
      "step_output_file <- function(step_id) {",
      "  file.path(logs_dir, sprintf(\"%s.txt\", step_id))",
      "}"
    )
  )
  lines <- replace_function(
    lines,
    "load_or_fit_cache",
    c(
      "run_step <- function(step_id, expr, note = NULL) {",
      "  eval.parent(substitute(expr))",
      "}"
    )
  )
  lines <- replace_between(
    lines,
    "targets <- if (exists(\"targets\")) as.character(targets) else character(0)",
    "force_refit <- isTRUE(force_refit)",
    character(),
    fixed = TRUE
  )
  lines <- remove_matching_lines(lines, "force_refit <- isTRUE(force_refit)", fixed = TRUE)
  lines <- replace_between(
    lines,
    "artifact_registry <- data.frame(",
    "save_png_plot <- function",
    character(),
    fixed = TRUE
  )
  lines <- replace_function(
    lines,
    "save_table_csv",
    c(
      "save_table_csv <- function(df, filename, ...) {",
      "  path <- file.path(tables_dir, filename)",
      "  utils::write.csv(df, file = path, row.names = FALSE)",
      "  invisible(path)",
      "}"
    )
  )
  lines <- replace_function(
    lines,
    "write_tracker",
    c(
      "write_replication_index <- function() {",
      "  invisible(TRUE)",
      "}"
    )
  )
  lines <- replace_function(
    lines,
    "write_session_info",
    c(
      "write_session_info <- function() {",
      "  path <- file.path(logs_dir, \"sessionInfo.txt\")",
      "  txt <- utils::capture.output({",
      "    cat(sprintf(\"Seed: %s\\n\", seed_value))",
      "    cat(sprintf(\"RNGkind: %s\\n\", paste(RNGkind(), collapse = \" | \")))",
      "    cat(sprintf(\"Date: %s\\n\\n\", as.character(Sys.time())))",
      "    print(sessionInfo())",
      "  })",
      "  txt <- sanitize_reference_paths(txt)",
      "  write_log_lines(txt, path)",
      "}"
    )
  )
  lines <- replace_function(
    lines,
    "resolve_ex4_dataset_seed_for_reporting",
    c(
      "resolve_ex4_dataset_seed_for_reporting <- function(cfg_ex4 = cfg_run$ex4) {",
      "  as.integer(cfg_ex4$dataset_seed %||% NA_integer_)",
      "}"
    )
  )
  lines <- replace_function(lines, "promote_publication_figures", character())
  lines <- replace_function(lines, "target_enabled", character())
  lines <- remove_call_blocks(lines, "register_note")
  lines <- gsub("article_git_at_setup", "article_state_at_setup", lines, fixed = TRUE)
  lines <- gsub("pkg_git_at_setup", "pkg_state_at_setup", lines, fixed = TRUE)
  lines <- gsub("git_state_snapshot", "source_state_snapshot", lines, fixed = TRUE)
  lines <- gsub("pkg_state_at_setup$commit", "pkg_state_at_setup$identifier", lines, fixed = TRUE)
  lines <- gsub("\"exdqlm_commit\"", "\"exdqlm_source\"", lines, fixed = TRUE)
  lines <- replace_line(
    lines,
    "log_msg(sprintf(\"00_setup complete (profile=%s)\", selected_profile))",
    "log_msg(\"Setup complete\")",
    fixed = TRUE
  )
  lines <- gsub(
    "repo_root is not defined. Run via code.R or the internal analysis runner.",
    "repo_root is not defined. Run code.R from the extracted replication directory.",
    lines,
    fixed = TRUE
  )
  lines <- rename_public_terms(lines)
  lines <- replace_line(lines, "selected_run <- settings %||% \"standard\"", "selected_run <- \"standard\"", fixed = TRUE)
  lines
}

sanitize_ex4_helpers <- function(lines) {
  lines <- replace_function(
    lines,
    "ex4_resolve_dataset_seed",
    c(
      "ex4_resolve_dataset_seed <- function(cfg_ex4) {",
      "  configured_seed <- as.integer(cfg_ex4$dataset_seed %||% (seed_value + 404L))",
      "  if (!is.finite(configured_seed)) stop(\"Example 4 dataset_seed must be finite.\", call. = FALSE)",
      "  configured_seed",
      "}"
    )
  )
  lines <- replace_function(
    lines,
    "ex4_load_or_fit_cache_safe",
    c(
      "ex4_run_step <- function(step_id, expr, note = NULL) {",
      "  eval.parent(substitute(expr))",
      "}"
    )
  )
  lines
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
  lines <- gsub("trace_cache_key", "trace_step_id", lines, fixed = TRUE)
  lines <- gsub("cache_key", "step_id", lines, fixed = TRUE)
  lines <- gsub(
    "Lake Huron public replication refits the manuscript models; ex1mcmc uses a dedicated high-iteration median MCMC chain, and runtime statements depend on the reference computer (see ex1_run_summary).",
    "Lake Huron refits the manuscript models; ex1mcmc uses a dedicated high-iteration median MCMC chain, and runtime statements depend on the reference computer (see ex1_run_summary).",
    lines,
    fixed = TRUE
  )
  lines <- gsub("skipped (target filter)", "skipped", lines, fixed = TRUE)
  need_assignments <- c(
    "need_ex1", "need_ex1mcmc", "need_ex1quants", "need_ex1synth",
    "need_ex2", "need_ex2quant", "need_ex2quant_ldvb", "need_ex2checks",
    "need_ex2checks_ldvb", "need_ex2benchmark", "need_ex2_ldvb_diag",
    "need_ex2_tables", "need_ex2_tables_ldvb",
    "need_ex3", "need_ex3data", "need_ex3forecast", "need_ex3quantcomps",
    "need_ex3zetapsi", "need_ex3tables",
    "need_ex4", "need_ex4figure", "need_ex4table"
  )
  for (name in need_assignments) {
    lines <- replace_assignment_call(lines, name, sprintf("%s <- TRUE", name))
  }
  lines <- replace_assignment_call(lines, "need_ex1kernel", "need_ex1kernel <- FALSE")
  lines <- remove_call_blocks(lines, "register_artifact")
  lines <- remove_call_blocks(lines, "register_note")
  lines <- rename_public_terms(lines)
  lines
}

script_header <- function() {
  c(
    "#!/usr/bin/env Rscript",
    "",
    "#' # exdqlm JSS replication script",
    "#'",
    "#' This file is the full manuscript replication script for the JSS article",
    "#' \"exdqlm: An R Package for Estimation and Analysis of Flexible Dynamic",
    "#' Quantile Linear Models\".",
    "#'",
    "#' Run from the extracted replication-materials directory with:",
    "#'",
    "#' ```sh",
    "#' R CMD BATCH --vanilla code.R code.Rout",
    "#' ```",
    "#'",
    "#' This script refits the four examples, regenerates the manuscript figures,",
    "#' prints the numerical tables and selected fitted-object output, and records",
    "#' the computational environment.",
    "#'",
    "#' The script is intentionally flat: it contains the setup code, helper code,",
    "#' and example code in manuscript order.",
    "",
    "jss_start_time <- proc.time()[[3L]]",
    "repo_root <- normalizePath(getwd(), winslash = \"/\", mustWork = TRUE)",
    "seed_override <- NULL",
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
    "cat(\"Run: full manuscript replication\\n\")",
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
  "  manuscript_figures <- as.character(cfg_params$manuscript_output$figures %||% character())",
  "  if (isTRUE(getOption(\"exdqlm.jss_rplots_active\", FALSE)) && filename %in% manuscript_figures) {",
  "    eval.parent(plot_expr)",
  "  }",
  "  invisible(path)",
  "}"
)

final_output_block <- function() c(
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
  "write_printed_output <- function(filename, expr) {",
  "  path <- file.path(logs_dir, filename)",
  "  txt <- utils::capture.output(eval.parent(substitute(expr)))",
  "  writeLines(txt, con = path)",
  "  invisible(path)",
  "}",
  "",
  "save_table_csv(benchmark_environment_table(), \"benchmark_environment.csv\")",
  "save_table_csv(benchmark_settings_table(), \"benchmark_backend_settings.csv\")",
  "write_session_info()",
  "",
  "print_jss_heading(\"M95\")",
  "print(M95)",
  "write_printed_output(\"M95-print.txt\", print(M95))",
  "print_jss_heading(\"summary(M95)\")",
  "print(summary(M95))",
  "write_printed_output(\"M95-summary.txt\", print(summary(M95)))",
  "print_jss_heading(\"MTF$median.kt\")",
  "print(MTF$median.kt)",
  "write_printed_output(\"MTF-median-kt.txt\", print(MTF$median.kt))",
  "print_csv_table(\"Table 7 / tab:ex2bench\", \"tables/ex2_dynamic_benchmark.csv\")",
  "print_csv_table(\"Table 8 / tab:ex3\", \"tables/ex3_diagnostics_summary.csv\")",
  "print_csv_table(\"Table 9 / tab:ex3forecastmetrics\", \"tables/ex3_forecast_metrics.csv\")",
  "print_csv_table(\"Table 10 / tab:ex4static\", \"tables/ex4static_summary.csv\")",
  "print_jss_heading(\"sessionInfo()\")",
  "print(utils::sessionInfo())",
  "cat(sprintf(\"\\nTotal elapsed seconds: %.3f\\n\", proc.time()[[3L]] - jss_start_time))",
  "if (isTRUE(getOption(\"exdqlm.jss_rplots_active\", FALSE))) {",
  "  grDevices::dev.off()",
  "  options(exdqlm.jss_rplots_active = FALSE)",
  "}",
  "cat(\"\\nReplication complete. Primary batch outputs: code.Rout and Rplots.pdf.\\n\")"
)

validate_generated <- function(path) {
  txt <- paste(read_file(path), collapse = "\n")
  forbidden <- c(
    "source(",
    "readRDS(",
    "saveRDS(",
    "code-fast.R",
    "examples.R",
    "EXDQLM_LOAD_MODE",
    "EXDQLM_PKG_PATH",
    "run_all.R",
    "--quick",
    "--example",
    "parse_replication_args",
    "target_enabled",
    "targeted_run",
    "promotion",
    "artifact_registry",
    "register_artifact",
    "register_note",
    "cache_dir",
    "cache_file",
    "load_or_fit_cache"
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

build_script <- function(repo_root, out_file) {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("The yaml package is required to build the generated scripts.", call. = FALSE)
  }
  cfg_params <- yaml::read_yaml(file.path(repo_root, "analysis", "config", "params_manuscript.yml"))
  cfg_params$run_name <- "standard"
  cfg_params$run_settings <- cfg_params$profiles["standard"]
  cfg_params$profiles <- NULL
  cfg_params$manuscript_benchmark_setting <- cfg_params$manuscript_benchmark_profile
  cfg_params$manuscript_benchmark_profile <- NULL
  cfg_params$benchmark_settings <- cfg_params$benchmark_profiles
  cfg_params$benchmark_profiles <- NULL
  cfg_params$manuscript_output <- cfg_params$promotion
  cfg_params$promotion <- NULL
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
        "ex4_static/run.R"
      )
    ),
    function(path) c(sprintf("\n# ---- %s ----", basename(dirname(path))), sanitize_example(read_file(path)))
  )

  lines <- c(
    script_header(),
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
    final_output_block()
  )

  lines <- rename_public_terms(lines)
  write_file(out_file, lines)
  Sys.chmod(out_file, mode = "0755")
  validate_generated(out_file)
  invisible(out_file)
}

repo_root <- find_repo_root()
build_script(repo_root, file.path(repo_root, "code.R"))
old_fast <- file.path(repo_root, "code-fast.R")
if (file.exists(old_fast)) unlink(old_fast, force = TRUE)
cat("Generated code.R\n")
