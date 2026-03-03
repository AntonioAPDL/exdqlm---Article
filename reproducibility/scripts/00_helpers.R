# Shared helpers for manuscript reproducibility scripts.

stopifnot(exists("repo_root"), exists("fig_dir"), exists("out_dir"), exists("log_dir"))

dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

log_step <- function(msg) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), msg))
}

save_png <- function(filename, width = 7, height = 5, res = 300) {
  path <- file.path(fig_dir, filename)
  png(path, width = width, height = height, units = "in", res = res)
  path
}

close_device <- function() {
  if (!is.null(dev.list())) {
    dev.off()
  }
}

log_step("Loaded reproducibility helpers.")
