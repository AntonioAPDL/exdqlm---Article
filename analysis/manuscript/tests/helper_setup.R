repo_root <- Sys.getenv("EXDQLM_ARTICLE_REPO", unset = "")
if (!nzchar(repo_root)) {
  stop("EXDQLM_ARTICLE_REPO is not set for manuscript tests.", call. = FALSE)
}

tracker_csv <- file.path(repo_root, "analysis", "manuscript", "outputs", "tables", "manuscript_repro_tracker.csv")
