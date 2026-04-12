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
  direct_row <- fit_status_row(
    p0 = res$p0,
    label = "direct_regression",
    fit = res$direct,
    median_kt = NA_real_
  )
  transfer_row <- fit_status_row(
    p0 = res$p0,
    label = "transfer_function",
    fit = res$transfer,
    median_kt = if (fit_ok(res$transfer)) res$transfer$median.kt else NA_real_
  )
  rbind(direct_row, transfer_row)
}))

write_csv(fit_rows, "ex3_daily_fit_summary.csv")

fit_notes <- unlist(lapply(fit_results, function(res) {
  lines <- sprintf("p0 = %.2f", res$p0)
  if (fit_ok(res$direct)) {
    lines <- c(
      lines,
      sprintf(
        "  direct_regression | iter=%s | converged=%s | hit_iter_cap=%s | runtime=%.3f",
        res$direct$iter %||% NA_integer_,
        isTRUE(res$direct$converged),
        fit_hit_iter_cap(res$direct),
        as.numeric(res$direct$run.time)
      )
    )
  } else {
    lines <- c(lines, sprintf("  direct_regression failed: %s", conditionMessage(res$direct)))
  }
  if (fit_ok(res$transfer)) {
    lines <- c(
      lines,
      sprintf(
        "  transfer_function | iter=%s | converged=%s | hit_iter_cap=%s | runtime=%.3f | median.kt=%.5f",
        res$transfer$iter %||% NA_integer_,
        isTRUE(res$transfer$converged),
        fit_hit_iter_cap(res$transfer),
        as.numeric(res$transfer$run.time),
        as.numeric(res$transfer$median.kt)
      )
    )
  } else {
    lines <- c(lines, sprintf("  transfer_function failed: %s", conditionMessage(res$transfer)))
  }
  c(lines, "")
}))
write_text(fit_notes, "ex3_daily_fit_notes.txt")
