cases <- cfg_params$sampling_cases
sample_rows <- list()
density_rows <- list()
quantile_rows <- list()

for (i in seq_along(cases)) {
  case <- cases[[i]]
  label <- as.character(case$label %||% paste0("samp_", i))
  p0 <- as.numeric(case$p0)
  mu <- as.numeric(case$mu)
  sigma <- as.numeric(case$sigma)
  gamma <- resolve_case_gamma(case)
  n <- as.integer(case$sample_n %||% NA)
  if (length(n) != 1L || is.na(n) || n <= 0L) {
    stop(sprintf("Invalid sample_n for case '%s'", label), call. = FALSE)
  }

  set.seed(seed_value + i)
  s <- exdqlm::rexal(n = n, p0 = p0, mu = mu, sigma = sigma, gamma = gamma)

  x_grid <- seq(stats::quantile(s, 0.001), stats::quantile(s, 0.999), length.out = 1400)
  d_true <- exdqlm::dexal(x_grid, p0 = p0, mu = mu, sigma = sigma, gamma = gamma)

  sample_rows[[i]] <- data.frame(
    x = as.numeric(s),
    case_label = label,
    facet = sprintf("%s\np0=%.2f, gamma=%.3f, mu=%.2f, sigma=%.2f", label, p0, gamma, mu, sigma),
    stringsAsFactors = FALSE
  )

  density_rows[[i]] <- data.frame(
    x = x_grid,
    density_true = d_true,
    case_label = label,
    facet = sprintf("%s\np0=%.2f, gamma=%.3f, mu=%.2f, sigma=%.2f", label, p0, gamma, mu, sigma),
    stringsAsFactors = FALSE
  )

  probs <- sort(unique(pmax(0.05, pmin(0.95, c(p0 - 0.12, p0 - 0.06, p0, p0 + 0.06, p0 + 0.12)))))
  sample_q <- as.numeric(stats::quantile(s, probs = probs, names = FALSE))
  theory_q <- as.numeric(suppressWarnings(exdqlm::qexal(probs, p0 = p0, mu = mu, sigma = sigma, gamma = gamma)))
  keep <- is.finite(theory_q)

  quantile_rows[[i]] <- data.frame(
    case_label = label,
    p0 = p0,
    gamma = gamma,
    mu = mu,
    sigma = sigma,
    prob = probs[keep],
    sample_q = sample_q[keep],
    theory_q = theory_q[keep],
    abs_error = abs(sample_q[keep] - theory_q[keep]),
    stringsAsFactors = FALSE
  )
}

df_samples <- do.call(rbind, sample_rows)
df_density <- do.call(rbind, density_rows)
df_q <- do.call(rbind, quantile_rows)
df_density <- df_density[is.finite(df_density$density_true), , drop = FALSE]

bins <- as.integer(cfg_params$sampling_cases[[1]]$bins %||% 80L)

plot_obj <- ggplot(df_samples, aes(x = x)) +
  geom_histogram(aes(y = after_stat(density)), bins = bins, fill = "grey85", color = "grey35", alpha = 0.9) +
  geom_line(
    data = df_density,
    aes(x = x, y = density_true, color = "Theoretical density"),
    linewidth = 0.9,
    inherit.aes = FALSE
  ) +
  scale_color_manual(values = c("Theoretical density" = palette_vals[[4]])) +
  labs(
    title = "rexal Sampling Diagnostics Against Theoretical Density",
    subtitle = "Histogram of samples with exAL theoretical density overlay",
    x = cfg_style$labels$x,
    y = cfg_style$labels$density,
    color = "Curve"
  ) +
  facet_wrap(~facet, scales = "free", ncol = 1) +
  exal_theme()

save_plot_file(
  plot_obj,
  filename = "exal_fig_10_rexal_density_overlay_3cases.png",
  description = "rexal sample histograms with theoretical exAL density overlays",
  main_text_candidate = TRUE
)

save_table_file(
  df_density,
  filename = "exal_data_10_rexal_density_grid.csv",
  description = "Density grid data for rexal overlay figure"
)

save_table_file(
  df_q,
  filename = "exal_data_10_sampling_quantiles.csv",
  description = "Sample-vs-theoretical quantile diagnostics for rexal cases"
)
