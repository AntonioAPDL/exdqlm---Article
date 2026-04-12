prep <- cache_read("ex3_daily_prep.rds")
p_levels <- as.numeric(config$model$p_levels)
parallel_ok <- isTRUE(config$runtime$parallel) && .Platform$OS.type != "windows"
workers <- max(1L, as.integer(config$runtime$workers %||% 1L))

fit_fun <- function(i) {
  p0 <- p_levels[i]
  fit_model_pair(p0 = p0, prep = prep, fit_seed = seed_base + i)
}

fit_results <- if (parallel_ok) {
  parallel::mclapply(seq_along(p_levels), fit_fun, mc.cores = workers)
} else {
  lapply(seq_along(p_levels), fit_fun)
}
names(fit_results) <- sprintf("p%03d", round(100 * p_levels))
cache_write(fit_results, "ex3_daily_fits_ldvb.rds")

fit_rows <- do.call(rbind, lapply(fit_results, function(res) {
  direct_row <- data.frame(
    p0 = res$p0,
    model = "direct_regression",
    status = if (fit_ok(res$direct)) "ok" else "error",
    runtime = if (fit_ok(res$direct)) as.numeric(res$direct$run.time) else NA_real_,
    median_kt = NA_real_,
    stringsAsFactors = FALSE
  )
  transfer_row <- data.frame(
    p0 = res$p0,
    model = "transfer_function",
    status = if (fit_ok(res$transfer)) "ok" else "error",
    runtime = if (fit_ok(res$transfer)) as.numeric(res$transfer$run.time) else NA_real_,
    median_kt = if (fit_ok(res$transfer)) as.numeric(res$transfer$median.kt) else NA_real_,
    stringsAsFactors = FALSE
  )
  rbind(direct_row, transfer_row)
}))

write_csv(fit_rows, "ex3_daily_fit_summary.csv")

fit_notes <- unlist(lapply(fit_results, function(res) {
  lines <- sprintf("p0 = %.2f", res$p0)
  if (!fit_ok(res$direct)) {
    lines <- c(lines, sprintf("  direct_regression failed: %s", res$direct$message))
  }
  if (!fit_ok(res$transfer)) {
    lines <- c(lines, sprintf("  transfer_function failed: %s", res$transfer$message))
  }
  c(lines, "")
}))
write_text(fit_notes, "ex3_daily_fit_notes.txt")
