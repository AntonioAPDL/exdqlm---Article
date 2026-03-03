suppressPackageStartupMessages(library(testthat))

infer_repo_root <- function(start = getwd()) {
  cur <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(cur, "article4.tex"))) return(cur)
    parent <- dirname(cur)
    if (identical(parent, cur)) stop("Could not infer repo root for tests.", call. = FALSE)
    cur <- parent
  }
}

repo_root <- Sys.getenv("EXDQLM_ARTICLE_REPO", unset = "")
if (!nzchar(repo_root)) repo_root <- infer_repo_root()
repo_root <- normalizePath(repo_root, mustWork = TRUE)

project_stage <- "exal"
profile <- "standard"
seed_override <- NULL

pkg_path_env <- Sys.getenv("EXDQLM_PKG_PATH", unset = "")
pkg_path <- if (nzchar(pkg_path_env)) pkg_path_env else NULL

source(file.path(repo_root, "analysis", "exal", "scripts", "00_setup.R"), local = TRUE)
