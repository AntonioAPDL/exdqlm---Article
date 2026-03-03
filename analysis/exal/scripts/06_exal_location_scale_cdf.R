cases <- cfg_params$location_scale_cases
rows <- list()

for (i in seq_along(cases)) {
  case <- cases[[i]]
  label <- as.character(case$label %||% paste0("case_", i))
  p0 <- as.numeric(case$p0)
  mu <- as.numeric(case$mu)
  sigma <- as.numeric(case$sigma)
  gamma <- resolve_case_gamma(case)

  x <- seq(mu - 8 * sigma, mu + 8 * sigma, length.out = cfg_params$grid$x_n)
  cdf <- exdqlm::pexal(x, p0 = p0, mu = mu, sigma = sigma, gamma = gamma)

  rows[[i]] <- data.frame(
    x = x,
    cdf = cdf,
    case_label = label,
    p0 = p0,
    gamma = gamma,
    mu = mu,
    sigma = sigma,
    stringsAsFactors = FALSE
  )
}

df <- do.call(rbind, rows)

df$facet <- sprintf(
  "%s\np0=%.2f, gamma=%.3f, mu=%.2f, sigma=%.2f",
  df$case_label, df$p0, df$gamma, df$mu, df$sigma
)

plot_obj <- ggplot(df, aes(x = x, y = cdf, color = case_label)) +
  geom_line(linewidth = 0.9, show.legend = FALSE) +
  scale_color_manual(values = palette_vals[seq_along(unique(df$case_label))]) +
  labs(
    title = "exAL CDF Under Location-Scale Transformation",
    subtitle = "Each panel uses a distinct (p0, gamma, mu, sigma) configuration",
    x = cfg_style$labels$x,
    y = cfg_style$labels$cdf
  ) +
  facet_wrap(~facet, scales = "free_x", ncol = 1) +
  exal_theme()

save_plot_file(
  plot_obj,
  filename = "exal_fig_06_exal_location_scale_cdf.png",
  description = "exAL CDF under multiple location-scale parameterizations",
  main_text_candidate = FALSE
)

save_table_file(
  df,
  filename = "exal_data_06_exal_location_scale_cdf.csv",
  description = "Underlying data for location-scale CDF figure"
)
