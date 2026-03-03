cases <- cfg_params$location_scale_cases
rows <- list()
meta <- list()

for (i in seq_along(cases)) {
  case <- cases[[i]]
  label <- as.character(case$label %||% paste0("case_", i))
  p0 <- as.numeric(case$p0)
  mu <- as.numeric(case$mu)
  sigma <- as.numeric(case$sigma)
  gamma <- resolve_case_gamma(case)

  x <- seq(mu - 8 * sigma, mu + 8 * sigma, length.out = cfg_params$grid$x_n)
  d <- exdqlm::dexal(x, p0 = p0, mu = mu, sigma = sigma, gamma = gamma)

  rows[[i]] <- data.frame(
    x = x,
    density = d,
    case_label = label,
    p0 = p0,
    gamma = gamma,
    mu = mu,
    sigma = sigma,
    stringsAsFactors = FALSE
  )

  meta[[i]] <- data.frame(
    case_label = label,
    p0 = p0,
    gamma = gamma,
    mu = mu,
    sigma = sigma,
    stringsAsFactors = FALSE
  )
}

df <- do.call(rbind, rows)
df_meta <- do.call(rbind, meta)

df$facet <- sprintf(
  "%s\np0=%.2f, gamma=%.3f, mu=%.2f, sigma=%.2f",
  df$case_label, df$p0, df$gamma, df$mu, df$sigma
)

plot_obj <- ggplot(df, aes(x = x, y = density, color = case_label)) +
  geom_line(linewidth = 0.9, show.legend = FALSE) +
  scale_color_manual(values = palette_vals[seq_along(unique(df$case_label))]) +
  labs(
    title = "exAL Density Under Location-Scale Transformation",
    subtitle = "Each panel uses a distinct (p0, gamma, mu, sigma) configuration",
    x = cfg_style$labels$x,
    y = cfg_style$labels$density
  ) +
  facet_wrap(~facet, scales = "free_x", ncol = 1) +
  exal_theme()

save_plot_file(
  plot_obj,
  filename = "exal_fig_05_exal_location_scale_density.png",
  description = "exAL density under multiple location-scale parameterizations",
  main_text_candidate = FALSE
)

save_table_file(
  df,
  filename = "exal_data_05_exal_location_scale_density.csv",
  description = "Underlying data for location-scale density figure"
)

save_table_file(
  df_meta,
  filename = "exal_data_05_location_scale_cases.csv",
  description = "Case metadata for location-scale density/cdf scripts"
)
