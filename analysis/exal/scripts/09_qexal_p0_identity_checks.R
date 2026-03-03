cases <- cfg_params$identity_cases
rows <- list()

for (i in seq_along(cases)) {
  case <- cases[[i]]
  p0 <- as.numeric(case$p0)
  mu <- as.numeric(case$mu)
  sigma <- as.numeric(case$sigma)
  gamma <- resolve_case_gamma(case)

  qhat <- exdqlm::qexal(p0, p0 = p0, mu = mu, sigma = sigma, gamma = gamma)

  rows[[i]] <- data.frame(
    case_id = sprintf("id_%02d", i),
    p0 = p0,
    gamma = gamma,
    mu = mu,
    sigma = sigma,
    qhat = as.numeric(qhat),
    abs_error = abs(as.numeric(qhat) - mu),
    stringsAsFactors = FALSE
  )
}

df <- do.call(rbind, rows)
floor_eps <- .Machine$double.eps
df$abs_error_display <- pmax(df$abs_error, floor_eps)
df$neglog10_abs_error <- -log10(df$abs_error_display)

df$case_label <- sprintf(
  "%s | p0=%.2f, gamma=%+.4f, mu=%.2f",
  df$case_id, df$p0, df$gamma, df$mu
)

df$case_label <- factor(df$case_label, levels = unique(df$case_label))
thr <- as.numeric(cfg_params$thresholds$identity_abs_error)
thr_score <- -log10(max(thr, floor_eps))

plot_obj <- ggplot(df, aes(x = case_label, y = neglog10_abs_error)) +
  geom_col(fill = palette_vals[[2]], alpha = 0.9, width = 0.72) +
  geom_hline(yintercept = thr_score, linetype = "dashed", color = cfg_style$palette$neutral, linewidth = 0.7) +
  labs(
    title = "Identity Check: qexal(p0) = mu",
    subtitle = "Accuracy score -log10(abs error); dashed line is configured threshold",
    x = "Case",
    y = "-log10(abs error)"
  ) +
  exal_theme() +
  theme(axis.text.x = element_text(angle = 35, hjust = 1))

save_plot_file(
  plot_obj,
  filename = "exal_fig_09_qexal_p0_identity.png",
  description = "Absolute error for qexal(p0)=mu identity check",
  main_text_candidate = FALSE
)

save_table_file(
  df,
  filename = "exal_data_09_qexal_p0_identity.csv",
  description = "Underlying identity-check data"
)
