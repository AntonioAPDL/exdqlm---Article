log_g_ref <- function(gamma) {
  log(2) + stats::pnorm(-abs(gamma), log.p = TRUE) + 0.5 * gamma^2
}

p0_grid <- seq(
  as.numeric(cfg_params$grid$bounds_p0_min),
  as.numeric(cfg_params$grid$bounds_p0_max),
  length.out = as.integer(cfg_params$grid$bounds_p0_n)
)

b <- t(vapply(p0_grid, function(p0) {
  v <- exdqlm::get_gamma_bounds(p0)
  c(L = as.numeric(v[["L"]]), U = as.numeric(v[["U"]]))
}, numeric(2)))

df_all <- data.frame(
  p0 = p0_grid,
  L = b[, "L"],
  U = b[, "U"],
  log_resid_L = log_g_ref(b[, "L"]) - log1p(-p0_grid),
  log_resid_U = log_g_ref(b[, "U"]) - log(p0_grid),
  stringsAsFactors = FALSE
)

cap_val <- max(abs(c(df_all$L, df_all$U)))
resid_tol <- as.numeric(cfg_params$grid$bounds_log_resid_tol %||% 1e-8)
clip_tol <- as.numeric(cfg_params$grid$bounds_clip_tol %||% 1e-10)

df_all$tail_clipped <- (abs(abs(df_all$L) - cap_val) <= clip_tol) | (abs(abs(df_all$U) - cap_val) <= clip_tol)
df_all$resid_ok <- abs(df_all$log_resid_L) <= resid_tol & abs(df_all$log_resid_U) <= resid_tol
df_all$used_in_plot <- df_all$resid_ok & (!df_all$tail_clipped)

df <- df_all[df_all$used_in_plot, , drop = FALSE]
if (nrow(df) < 50L) {
  stop("Insufficient interior points after gamma-bound filtering; check bounds tolerances.", call. = FALSE)
}
if (!all(diff(df$L) < 0) || !all(diff(df$U) < 0)) {
  stop("Filtered gamma bounds are not strictly monotone; check filtering logic.", call. = FALSE)
}

plot_obj <- ggplot(df, aes(x = p0)) +
  geom_ribbon(aes(ymin = L, ymax = U), fill = "#9ecae1", alpha = 0.35) +
  geom_line(aes(y = L, color = "L(p0)"), linewidth = 1.0) +
  geom_line(aes(y = U, color = "U(p0)"), linewidth = 1.0) +
  scale_color_manual(values = c("L(p0)" = palette_vals[[1]], "U(p0)" = palette_vals[[2]])) +
  labs(
    title = "Admissible Gamma Region Across Quantile Levels",
    subtitle = sprintf(
      "Strictly monotone interior region (p0 in [%.3f, %.3f]); tail-clipped endpoints excluded",
      min(df$p0), max(df$p0)
    ),
    x = "p0",
    y = "Gamma bounds",
    color = "Boundary"
  ) +
  exal_theme()

save_plot_file(
  plot_obj,
  filename = "exal_fig_07_gamma_bounds_region.png",
  description = "Admissible gamma interval [L(p0), U(p0)] across p0",
  main_text_candidate = TRUE
)

save_table_file(
  df_all,
  filename = "exal_tab_02_gamma_bounds_reference_grid.csv",
  description = "Reference gamma bounds on p0 grid with residual diagnostics and plot-domain flags"
)
