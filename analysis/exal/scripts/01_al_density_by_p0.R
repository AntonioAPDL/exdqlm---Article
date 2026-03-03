x <- seq(cfg_params$grid$x_min, cfg_params$grid$x_max, length.out = cfg_params$grid$x_n)
p0_vals <- as.numeric(unlist(cfg_params$baseline$p0))
mu <- as.numeric(cfg_params$baseline$mu)
sigma <- as.numeric(cfg_params$baseline$sigma)
gamma <- as.numeric(cfg_params$baseline$gamma)

rows <- vector("list", length(p0_vals))
for (i in seq_along(p0_vals)) {
  p0 <- p0_vals[[i]]
  d <- exdqlm::dexal(x, p0 = p0, mu = mu, sigma = sigma, gamma = gamma)
  rows[[i]] <- data.frame(
    x = x,
    density = d,
    p0 = p0,
    p0_label = sprintf("p0 = %.2f", p0),
    stringsAsFactors = FALSE
  )
}

df <- do.call(rbind, rows)

plot_obj <- ggplot(df, aes(x = x, y = density, color = p0_label)) +
  geom_line(linewidth = 1) +
  scale_color_manual(values = palette_vals[seq_along(p0_vals)]) +
  labs(
    title = "AL Special Case Density by Quantile Level",
    subtitle = "exAL with gamma = 0",
    x = cfg_style$labels$x,
    y = cfg_style$labels$density,
    color = "Quantile level"
  ) +
  exal_theme()

save_plot_file(
  plot_obj,
  filename = "exal_fig_01_al_density_by_p0.png",
  description = "AL special-case density curves for multiple p0 values",
  main_text_candidate = FALSE
)

save_table_file(
  df,
  filename = "exal_data_01_al_density_by_p0.csv",
  description = "Underlying data for AL density by p0 figure"
)
