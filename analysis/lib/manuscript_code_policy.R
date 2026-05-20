split_policy_field <- function(x) {
  x <- trimws(x %||% "")
  if (!nzchar(x) || identical(tolower(x), "none")) return(character())
  trimws(strsplit(x, ";", fixed = TRUE)[[1L]])
}

extract_codeinput_chunks <- function(tex_path) {
  if (!file.exists(tex_path)) {
    stop(sprintf("Missing LaTeX file: %s", tex_path), call. = FALSE)
  }

  tex <- readLines(tex_path, warn = FALSE)
  chunks <- list()
  in_chunk <- FALSE
  chunk_start <- NA_integer_
  chunk_lines <- character()

  strip_prompt <- function(line) {
    line <- sub("^R> ?", "", line)
    line <- sub("^\\+ ?", "", line)
    line
  }

  for (i in seq_along(tex)) {
    line <- tex[[i]]
    if (grepl("^\\\\begin\\{CodeInput\\}", line)) {
      if (in_chunk) {
        stop(sprintf("Nested CodeInput block starts at line %d.", i), call. = FALSE)
      }
      in_chunk <- TRUE
      chunk_start <- i
      chunk_lines <- character()
      next
    }

    if (grepl("^\\\\end\\{CodeInput\\}", line)) {
      if (!in_chunk) {
        stop(sprintf("Unexpected CodeInput end at line %d.", i), call. = FALSE)
      }
      chunks[[length(chunks) + 1L]] <- list(
        chunk_id = sprintf("chunk_%03d", length(chunks) + 1L),
        tex_start = chunk_start,
        tex_end = i,
        code = chunk_lines
      )
      in_chunk <- FALSE
      chunk_start <- NA_integer_
      chunk_lines <- character()
      next
    }

    if (in_chunk) chunk_lines <- c(chunk_lines, strip_prompt(line))
  }

  if (in_chunk) stop("Unclosed CodeInput block in LaTeX file.", call. = FALSE)
  chunks
}

parse_codeinput_chunks <- function(chunks) {
  lapply(chunks, function(chunk) {
    expr <- try(parse(text = chunk$code), silent = TRUE)
    if (inherits(expr, "try-error")) {
      stop(
        sprintf(
          "CodeInput %s at tex lines %d-%d does not parse: %s",
          chunk$chunk_id,
          chunk$tex_start,
          chunk$tex_end,
          as.character(expr)
        ),
        call. = FALSE
      )
    }
    invisible(expr)
  })
  invisible(TRUE)
}

read_code_chunk_map <- function(map_path) {
  required <- c(
    "chunk_id", "example", "role", "display_scope", "source_files",
    "manuscript_terms", "source_terms", "artifact_targets", "notes"
  )
  if (!file.exists(map_path)) {
    stop(sprintf("Missing code chunk map: %s", map_path), call. = FALSE)
  }
  map <- utils::read.csv(map_path, stringsAsFactors = FALSE, na.strings = "")
  missing <- setdiff(required, names(map))
  if (length(missing)) {
    stop(sprintf("Code chunk map missing columns: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  if (anyDuplicated(map$chunk_id)) {
    stop("Code chunk map contains duplicated chunk_id values.", call. = FALSE)
  }
  map
}

read_repo_text <- function(repo_root, rel_paths) {
  rel_paths <- split_policy_field(rel_paths)
  if (!length(rel_paths)) return(character())
  paths <- file.path(repo_root, rel_paths)
  missing <- rel_paths[!file.exists(paths)]
  if (length(missing)) {
    stop(sprintf("Mapped source files are missing: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  unlist(lapply(paths, readLines, warn = FALSE), use.names = FALSE)
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L || all(is.na(x))) y else x
