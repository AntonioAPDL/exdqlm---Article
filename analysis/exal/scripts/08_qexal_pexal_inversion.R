cases <- cfg_params$inversion_cases
rows <- list()

for (i in seq_along(cases)) {
  case <- cases[[i]]
  label <- as.character(case$label %||% paste0("inv_", i))
  p0 <- as.numeric(case$p0)
  mu <- as.numeric(case$mu)
  sigma <- as.numeric(case$sigma)
  gamma <- resolve_case_gamma(case)

  p_lo <- max(as.numeric(cfg_params$grid$p_min), p0 - 0.15)
  p_hi <- min(as.numeric(cfg_params$grid$p_max), p0 + 0.15)
  p_grid <- seq(p_lo, p_hi, length.out = as.integer(cfg_params$grid$p_n))

  q <- suppressWarnings(exdqlm::qexal(p_grid, p0 = p0, mu = mu, sigma = sigma, gamma = gamma))
  p_back <- exdqlm::pexal(q, p0 = p0, mu = mu, sigma = sigma, gamma = gamma)

  rows[[i]] <- data.frame(
    case_label = label,
    p = p_grid,
    q = q,
    p_recovered = p_back,
    abs_error = abs(p_back - p_grid),
    p0 = p0,
    gamma = gamma,
    mu = mu,
    sigma = sigma,
    stringsAsFactors = FALSE
  )
}

df <- do.call(rbind, rows)
df <- df[is.finite(df$q) & is.finite(df$p_recovered) & is.finite(df$abs_error), , drop = FALSE]
df$facet <- sprintf(
  "%s\np0=%.2f, gamma=%.3f, mu=%.2f, sigma=%.2f",
  df$case_label, df$p0, df$gamma, df$mu, df$sigma
)

plot_obj <- ggplot(df, aes(x = p, y = p_recovered)) +
  geom_line(color = palette_vals[[1]], linewidth = 1) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = cfg_style$palette$neutral) +
  labs(
    title = "Quantile Inversion Check: qexal Followed by pexal",
    subtitle = "Recovered probabilities should match input probabilities",
    x = "Input probability",
    y = "Recovered probability"
  ) +
  facet_wrap(~facet, ncol = 1) +
  exal_theme()

save_plot_file(
  plot_obj,
  filename = "exal_fig_08_qexal_pexal_inversion_panels.png",
  description = "qexal->pexal inversion validation panels across parameter cases",
  main_text_candidate = TRUE
)

save_table_file(
  df,
  filename = "exal_data_08_qexal_pexal_inversion.csv",
  description = "Underlying inversion-check data"
)
