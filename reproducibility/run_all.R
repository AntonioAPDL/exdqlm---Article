#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- normalizePath(if (length(args) >= 1) args[[1]] else ".", mustWork = TRUE)

scripts_dir <- file.path(repo_root, "reproducibility", "scripts")
fig_dir <- file.path(repo_root, "Figures")
out_dir <- file.path(repo_root, "reproducibility", "outputs")
log_dir <- file.path(out_dir, "logs")

dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

script_files <- c(
  "00_helpers.R",
  "10_exal_distribution.R",
  "20_dynamic_ldvb.R",
  "30_static_regression.R",
  "40_synthesis.R",
  "50_diagnostics_forecast.R"
)

ctx <- new.env(parent = globalenv())
ctx$repo_root <- repo_root
ctx$scripts_dir <- scripts_dir
ctx$fig_dir <- fig_dir
ctx$out_dir <- out_dir
ctx$log_dir <- log_dir

for (s in script_files) {
  path <- file.path(scripts_dir, s)
  if (!file.exists(path)) {
    stop(sprintf("Missing script: %s", path), call. = FALSE)
  }
  message(sprintf("Running %s", s))
  tryCatch(
    source(path, local = ctx),
    error = function(e) {
      stop(sprintf("Script failed (%s): %s", s, conditionMessage(e)), call. = FALSE)
    }
  )
}

writeLines(capture.output(sessionInfo()), con = file.path(out_dir, "sessionInfo.txt"))
message("Reproducibility run complete.")
