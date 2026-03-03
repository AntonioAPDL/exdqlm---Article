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

df <- data.frame(
  p0 = p0_grid,
  L = b[, "L"],
  U = b[, "U"],
  log_resid_L = log_g_ref(b[, "L"]) - log1p(-p0_grid),
  log_resid_U = log_g_ref(b[, "U"]) - log(p0_grid),
  stringsAsFactors = FALSE
)

plot_obj <- ggplot(df, aes(x = p0)) +
  geom_ribbon(aes(ymin = L, ymax = U), fill = "#9ecae1", alpha = 0.35) +
  geom_line(aes(y = L, color = "L(p0)"), linewidth = 0.9) +
  geom_line(aes(y = U, color = "U(p0)"), linewidth = 0.9) +
  scale_color_manual(values = c("L(p0)" = palette_vals[[1]], "U(p0)" = palette_vals[[2]])) +
  labs(
    title = "Admissible Gamma Region Across Quantile Levels",
    subtitle = "Bounds from get_gamma_bounds(p0)",
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
  df,
  filename = "exal_tab_02_gamma_bounds_reference_grid.csv",
  description = "Reference gamma bounds on p0 grid with log residual diagnostics"
)
