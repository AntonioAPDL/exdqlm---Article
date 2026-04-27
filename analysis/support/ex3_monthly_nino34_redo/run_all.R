#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
arg_get <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) {
    return(sub(paste0("^--", name, "="), "", hit[1]))
  }
  hit_idx <- match(paste0("--", name), args)
  if (!is.na(hit_idx) && hit_idx < length(args)) {
    return(args[hit_idx + 1L])
  }
  default
}

file_arg <- grep("^--file=", commandArgs(), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", file_arg[1]), mustWork = TRUE)
redo_root <- dirname(script_path)
repo_root <- normalizePath(file.path(redo_root, "..", "..", ".."), mustWork = TRUE)

targets <- strsplit(arg_get("targets", "prep,fit,figures,manifest"), ",", fixed = TRUE)[[1]]
targets <- trimws(targets)
targets <- targets[nzchar(targets)]
config_path <- arg_get(
  "config",
  Sys.getenv("EX3_MONTHLY_CONFIG_PATH", unset = file.path(redo_root, "config.yml"))
)
config_path <- normalizePath(config_path, mustWork = TRUE)

source(file.path(redo_root, "scripts", "00_setup.R"))

clean_runtime_dir_files <- function(dir_path) {
  existing <- list.files(dir_path, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  existing <- existing[basename(existing) != ".gitignore"]
  if (length(existing)) {
    unlink(existing, recursive = TRUE, force = TRUE)
  }
}

clean_runtime_dir_files(figure_dir)
clean_runtime_dir_files(table_dir)
clean_runtime_dir_files(log_dir)
reset_progress_log()
log_progress(sprintf(
  "run_start | config=%s | output_tag=%s | targets=%s",
  config_path, config_tag, paste(targets, collapse = ",")
))

step_map <- c(
  prep = "01_data_prep.R",
  fit = "02_fit_ldvb.R",
  figures = "03_figures.R",
  manifest = "04_manifest.R"
)

for (step in names(step_map)) {
  if (step %in% targets) {
    message(sprintf("[ex3_monthly_nino34_redo] running step: %s", step))
    log_progress(sprintf("step_start | step=%s", step))
    source(file.path(redo_root, "scripts", step_map[[step]]), local = FALSE)
    log_progress(sprintf("step_done | step=%s", step))
  }
}

log_progress("run_done | all requested steps completed")
