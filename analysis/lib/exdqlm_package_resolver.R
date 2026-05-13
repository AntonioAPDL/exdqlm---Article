`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

exdqlm_trim_env <- function(name) {
  value <- trimws(Sys.getenv(name, unset = ""))
  if (nzchar(value)) value else NULL
}

exdqlm_safe_system_output <- function(cmd, args = character()) {
  out <- tryCatch(
    system2(cmd, args = args, stdout = TRUE, stderr = TRUE),
    error = function(e) character()
  )
  trimws(out[nzchar(trimws(out))])
}

exdqlm_source_candidate_paths <- function(repo_root) {
  unique(normalizePath(
    file.path(
      repo_root,
      "..",
      c(
        "exdqlm",
        "exdqlm__wt__0p5p0_exdqlm_article",
        "exdqlm__wt__0p5p0_article",
        "exdqlm__wt__0p5p0",
        "exdqlm__wt__0.5.0-crps-iqs",
        "exdqlm__wt__0.5.0"
      )
    ),
    winslash = "/",
    mustWork = FALSE
  ))
}

exdqlm_read_description_field <- function(path, field) {
  desc <- file.path(path, "DESCRIPTION")
  if (!file.exists(desc)) return(NA_character_)
  dcf <- tryCatch(read.dcf(desc), error = function(e) NULL)
  if (is.null(dcf) || !field %in% colnames(dcf)) return(NA_character_)
  as.character(dcf[1, field])
}

exdqlm_is_source_checkout <- function(path) {
  dir.exists(path) &&
    file.exists(file.path(path, "DESCRIPTION")) &&
    identical(exdqlm_read_description_field(path, "Package"), "exdqlm")
}

exdqlm_git_ahead_behind <- function(path) {
  counts <- exdqlm_safe_system_output(
    "git",
    c("-C", path, "rev-list", "--left-right", "--count", "HEAD...@{u}")
  )
  counts <- counts[grepl("^[0-9]+[[:space:]]+[0-9]+$", counts)]
  if (!length(counts)) {
    return(c(ahead = NA_integer_, behind = NA_integer_))
  }

  values <- as.integer(strsplit(counts[[1]], "[[:space:]]+")[[1]])
  c(ahead = values[[1]], behind = values[[2]])
}

exdqlm_git_info <- function(path) {
  if (is.null(path) || !dir.exists(path)) {
    return(list(branch = NA_character_, upstream = NA_character_, commit = NA_character_,
                dirty = NA, remote = NA_character_, ahead = NA_integer_,
                behind = NA_integer_))
  }

  branch <- exdqlm_safe_system_output("git", c("-C", path, "branch", "--show-current"))
  upstream <- exdqlm_safe_system_output("git", c("-C", path, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"))
  commit <- exdqlm_safe_system_output("git", c("-C", path, "rev-parse", "HEAD"))
  status <- exdqlm_safe_system_output("git", c("-C", path, "status", "--porcelain", "--untracked-files=no"))
  remote <- exdqlm_safe_system_output("git", c("-C", path, "remote", "get-url", "origin"))
  counts <- exdqlm_git_ahead_behind(path)

  list(
    branch = branch[[1]] %||% NA_character_,
    upstream = upstream[[1]] %||% NA_character_,
    commit = commit[[1]] %||% NA_character_,
    dirty = length(status) > 0L,
    remote = remote[[1]] %||% NA_character_,
    ahead = counts[["ahead"]],
    behind = counts[["behind"]]
  )
}

exdqlm_resolve_source_spec <- function(repo_root,
                                       pkg_path = NULL,
                                       env_pkg_path = exdqlm_trim_env("EXDQLM_PKG_PATH"),
                                       fail_if_missing = FALSE) {
  cli_path <- if (!is.null(pkg_path) && nzchar(pkg_path)) pkg_path else NULL
  candidates <- exdqlm_source_candidate_paths(repo_root)

  explicit_path <- cli_path %||% env_pkg_path
  if (!is.null(explicit_path)) {
    source <- if (!is.null(cli_path)) "--pkg-path" else "EXDQLM_PKG_PATH"
    path <- normalizePath(explicit_path, winslash = "/", mustWork = FALSE)
    is_pkg <- exdqlm_is_source_checkout(path)
    if (fail_if_missing && !is_pkg) {
      stop(
        sprintf(
          paste(
            "The exdqlm source path from %s is not a valid exdqlm checkout: %s",
            "Point --pkg-path or EXDQLM_PKG_PATH to a checkout of AntonioAPDL/exdqlm,",
            "or set EXDQLM_LOAD_MODE=installed to use an installed package.",
            sep = "\n"
          ),
          source,
          path
        ),
        call. = FALSE
      )
    }
  } else {
    hits <- candidates[vapply(candidates, exdqlm_is_source_checkout, logical(1))]
    path <- hits[[1]] %||% NULL
    source <- if (!is.null(path)) "auto sibling search" else "unresolved"
    is_pkg <- !is.null(path)
    if (fail_if_missing && !is_pkg) {
      stop(
        paste(
          "Could not find a local exdqlm source checkout.",
          "Use --pkg-path /path/to/exdqlm, set EXDQLM_PKG_PATH=/path/to/exdqlm,",
          "clone git@github.com:AntonioAPDL/exdqlm.git next to this article repo,",
          "or set EXDQLM_LOAD_MODE=installed to use an installed package.",
          sep = "\n"
        ),
        call. = FALSE
      )
    }
  }

  list(
    path = path,
    source = source,
    is_package = is_pkg,
    version = if (!is.null(path) && is_pkg) exdqlm_read_description_field(path, "Version") else NA_character_,
    candidates = candidates,
    git = exdqlm_git_info(path)
  )
}

exdqlm_resolve_load_spec <- function() {
  load_mode <- tolower(trimws(Sys.getenv("EXDQLM_LOAD_MODE", unset = "source")))
  load_mode <- if (nzchar(load_mode)) load_mode else "source"
  if (!load_mode %in% c("source", "installed")) {
    stop(
      sprintf("Unsupported EXDQLM_LOAD_MODE '%s'. Use 'source' or 'installed'.", load_mode),
      call. = FALSE
    )
  }

  installed_lib <- exdqlm_trim_env("EXDQLM_INSTALLED_LIB")
  installed_lib <- if (!is.null(installed_lib)) {
    normalizePath(installed_lib, winslash = "/", mustWork = FALSE)
  } else {
    NULL
  }

  list(mode = load_mode, installed_lib = installed_lib)
}

exdqlm_load_package <- function(repo_root, pkg_path = NULL, log_msg = message) {
  load_spec <- exdqlm_resolve_load_spec()

  if (identical(load_spec$mode, "installed")) {
    if (!is.null(pkg_path) || nzchar(Sys.getenv("EXDQLM_PKG_PATH", unset = ""))) {
      log_msg("EXDQLM_LOAD_MODE=installed: ignoring source-path overrides and loading installed exdqlm.")
    }
    if (!is.null(load_spec$installed_lib)) {
      if (!dir.exists(load_spec$installed_lib)) {
        stop(sprintf("EXDQLM_INSTALLED_LIB does not exist: %s", load_spec$installed_lib), call. = FALSE)
      }
      .libPaths(unique(c(load_spec$installed_lib, .libPaths())))
    }
    if (!requireNamespace("exdqlm", quietly = TRUE)) {
      stop(
        paste(
          "Installed exdqlm package not found.",
          "Set EXDQLM_INSTALLED_LIB to the library containing exdqlm, install exdqlm,",
          "or switch to source mode with EXDQLM_LOAD_MODE=source.",
          sep = "\n"
        ),
        call. = FALSE
      )
    }
    pkg_loc <- tryCatch(find.package("exdqlm"), error = function(e) NA_character_)
    version <- as.character(utils::packageVersion("exdqlm"))
    log_msg(sprintf(
      "Loaded installed exdqlm (EXDQLM_LOAD_MODE=installed): %s [version %s]",
      pkg_loc,
      version
    ))
    return(invisible(list(mode = "installed", path = pkg_loc, version = version)))
  }

  pkg_spec <- exdqlm_resolve_source_spec(repo_root, pkg_path = pkg_path, fail_if_missing = TRUE)

  loader_name <- if (requireNamespace("pkgload", quietly = TRUE)) {
    "pkgload::load_all"
  } else if (requireNamespace("devtools", quietly = TRUE)) {
    "devtools::load_all"
  } else {
    stop(
      paste(
        "pkgload (preferred) or devtools is required to load local exdqlm package source.",
        "Install pkgload, or set EXDQLM_LOAD_MODE=installed to use an installed exdqlm package.",
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  if (identical(loader_name, "pkgload::load_all")) {
    pkgload::load_all(path = pkg_spec$path, quiet = TRUE, export_all = FALSE, helpers = FALSE)
  } else {
    devtools::load_all(path = pkg_spec$path, quiet = TRUE, export_all = FALSE, helpers = FALSE)
  }

  version <- as.character(utils::packageVersion("exdqlm"))
  log_msg(sprintf(
    "Loaded local exdqlm from source (%s via %s): %s [version %s]",
    pkg_spec$source,
    loader_name,
    pkg_spec$path,
    version
  ))
  invisible(list(mode = "source", path = pkg_spec$path, version = version, git = pkg_spec$git))
}
