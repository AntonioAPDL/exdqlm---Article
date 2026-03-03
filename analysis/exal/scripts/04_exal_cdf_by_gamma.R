x <- seq(cfg_params$grid$x_min, cfg_params$grid$x_max, length.out = cfg_params$grid$x_n)
p0 <- as.numeric(cfg_params$exal_gamma_sweep$p0)
frac_neg <- as.numeric(cfg_params$exal_gamma_sweep$fractions$negative)
frac_pos <- as.numeric(cfg_params$exal_gamma_sweep$fractions$positive)
trip <- gamma_triplet(p0, frac_neg = frac_neg, frac_pos = frac_pos)

mu <- as.numeric(cfg_params$baseline$mu)
sigma <- as.numeric(cfg_params$baseline$sigma)

labels <- c(
  sprintf("gamma = %.3f", trip[["g_neg"]]),
  "gamma = 0.000",
  sprintf("gamma = %.3f", trip[["g_pos"]])
)

gamma_vals <- unname(c(trip[["g_neg"]], trip[["g_zero"]], trip[["g_pos"]]))

rows <- vector("list", length(gamma_vals))
for (i in seq_along(gamma_vals)) {
  g <- gamma_vals[[i]]
  cdf <- exdqlm::pexal(x, p0 = p0, mu = mu, sigma = sigma, gamma = g)
  rows[[i]] <- data.frame(
    x = x,
    cdf = cdf,
    gamma = g,
    gamma_label = labels[[i]],
    p0 = p0,
    stringsAsFactors = FALSE
  )
}

df <- do.call(rbind, rows)

plot_obj <- ggplot(df, aes(x = x, y = cdf, color = gamma_label, linetype = gamma_label)) +
  geom_line(linewidth = 1) +
  scale_color_manual(values = palette_vals[1:3]) +
  scale_linetype_manual(values = c("solid", "dashed", "dotdash")) +
  labs(
    title = "exAL CDF Under Gamma Variation",
    subtitle = sprintf("Fixed p0 = %.2f", p0),
    x = cfg_style$labels$x,
    y = cfg_style$labels$cdf,
    color = "Gamma",
    linetype = "Gamma"
  ) +
  exal_theme()

save_plot_file(
  plot_obj,
  filename = "exal_fig_04_exal_cdf_gamma_sweep.png",
  description = "exAL CDF curves under negative, zero, and positive gamma",
  main_text_candidate = FALSE
)

save_table_file(
  df,
  filename = "exal_data_04_exal_cdf_gamma_sweep.csv",
  description = "Underlying data for exAL CDF gamma sweep"
)
