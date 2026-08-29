#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L || !nzchar(x)) y else x

script_arg <- commandArgs(trailingOnly = FALSE)
script_file <- sub("^--file=", "", script_arg[grepl("^--file=", script_arg)][1L])
if (!is.na(script_file) && nzchar(script_file)) {
  repo_root <- normalizePath(file.path(dirname(script_file), ".."),
                             winslash = "/", mustWork = TRUE)
} else {
  repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}
if (!file.exists(file.path(repo_root, "exdqlm-jss.tex"))) {
  stop("Run this script from the article repository or through tools/build-jss-submission-archive.R.",
       call. = FALSE)
}

stop_missing <- function(paths, label) {
  missing <- paths[!file.exists(paths)]
  if (length(missing)) {
    stop(sprintf(
      "%s missing:\n%s",
      label,
      paste(sprintf("  - %s", missing), collapse = "\n")
    ), call. = FALSE)
  }
}

copy_one <- function(from, to) {
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  ok <- file.copy(from, to, overwrite = TRUE, copy.date = TRUE)
  if (!ok) stop(sprintf("Could not copy %s to %s", from, to), call. = FALSE)
  invisible(to)
}

copy_tree <- function(from, to, pattern = NULL) {
  stop_missing(from, "Source directory")
  files <- list.files(from, recursive = TRUE, all.files = TRUE, no.. = TRUE,
                      full.names = TRUE, pattern = pattern)
  for (src in files) {
    if (dir.exists(src)) next
    rel <- substring(src, nchar(normalizePath(from, winslash = "/", mustWork = TRUE)) + 2L)
    copy_one(src, file.path(to, rel))
  }
  invisible(to)
}

repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
out_parent <- normalizePath(file.path(repo_root, ".."), winslash = "/", mustWork = TRUE)
submission_dir <- file.path(out_parent, sprintf("exdqlm-jss-submission-%s", stamp))
replication_dir <- file.path(submission_dir, "exdqlm-jss-replication")

dir.create(replication_dir, recursive = TRUE, showWarnings = FALSE)

required_root <- file.path(repo_root, c(
  "README.md",
  "code.R",
  "code.Rout",
  "Rplots.pdf",
  "exdqlm-jss.pdf",
  "response-to-editor.pdf",
  "exdqlm-jss.tex",
  "exdqlm-jss.bbl",
  "references.bib",
  "jss.cls",
  "jss.bst",
  "Sweave.sty",
  "jsslogo.jpg"
))
stop_missing(required_root, "Required submission file")
stop_missing(file.path(repo_root, c("figures", "tables", "logs")), "Required output directory")

copy_one(file.path(repo_root, "README.md"), file.path(replication_dir, "README.md"))
copy_one(file.path(repo_root, "manuscript-reproducibility-index.md"),
         file.path(replication_dir, "MANIFEST.txt"))
copy_one(file.path(repo_root, "code.R"), file.path(replication_dir, "code.R"))
copy_one(file.path(repo_root, "code.Rout"), file.path(replication_dir, "code.Rout"))
copy_one(file.path(repo_root, "Rplots.pdf"), file.path(replication_dir, "Rplots.pdf"))
copy_tree(file.path(repo_root, "figures"), file.path(replication_dir, "figures"))
copy_tree(file.path(repo_root, "tables"), file.path(replication_dir, "tables"))
copy_tree(file.path(repo_root, "logs"), file.path(replication_dir, "logs"))

manuscript_dir <- file.path(replication_dir, "manuscript-source")
for (file in c("exdqlm-jss.tex", "exdqlm-jss.bbl", "references.bib",
               "jss.cls", "jss.bst", "Sweave.sty", "jsslogo.jpg")) {
  copy_one(file.path(repo_root, file), file.path(manuscript_dir, file))
}
copy_tree(file.path(repo_root, "figures"), file.path(manuscript_dir, "figures"))

old_wd <- setwd(replication_dir)
on.exit(setwd(old_wd), add = TRUE)
all_files <- list.files(".", recursive = TRUE, all.files = TRUE, no.. = TRUE)
all_files <- all_files[file.info(all_files)$isdir %in% FALSE]
if (nzchar(Sys.which("sha256sum"))) {
  checksums <- system2("sha256sum", all_files, stdout = TRUE)
} else {
  checksums <- sprintf("%s  %s", tools::md5sum(all_files), all_files)
}
writeLines(checksums, "SHA256SUMS")
setwd(old_wd)

replication_tar <- file.path(submission_dir, "exdqlm-jss-replication.tar.gz")
old_wd <- setwd(submission_dir)
on.exit(setwd(old_wd), add = TRUE)
utils::tar(replication_tar, files = "exdqlm-jss-replication",
           compression = "gzip", tar = "tar")
setwd(old_wd)

copy_one(file.path(repo_root, "exdqlm-jss.pdf"),
         file.path(submission_dir, "exdqlm-jss.pdf"))
copy_one(file.path(repo_root, "response-to-editor.pdf"),
         file.path(submission_dir, "response-to-editor.pdf"))

pkg_tarball <- Sys.getenv("EXDQLM_PACKAGE_TARBALL", unset = "")
if (nzchar(pkg_tarball)) {
  pkg_tarball <- normalizePath(pkg_tarball, winslash = "/", mustWork = TRUE)
  copy_one(pkg_tarball, file.path(submission_dir, basename(pkg_tarball)))
} else {
  pkg_dest <- file.path(submission_dir, "exdqlm_1.1.1.tar.gz")
  utils::download.file(
    "https://cran.r-project.org/src/contrib/exdqlm_1.1.1.tar.gz",
    destfile = pkg_dest,
    mode = "wb",
    quiet = TRUE
  )
}

cat("Built JSS submission directory:\n")
cat(sprintf("%s\n", submission_dir))
cat("Upload these four files to JSS:\n")
cat(sprintf("- %s\n", file.path(submission_dir, "exdqlm-jss.pdf")))
cat(sprintf("- %s\n", file.path(submission_dir, "response-to-editor.pdf")))
cat(sprintf("- %s\n", file.path(submission_dir, "exdqlm_1.1.1.tar.gz")))
cat(sprintf("- %s\n", replication_tar))
