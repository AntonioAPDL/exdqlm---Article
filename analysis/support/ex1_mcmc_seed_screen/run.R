#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

get_arg <- function(flag, default = NULL) {
  idx <- match(flag, args)
  if (is.na(idx) || idx == length(args)) default else args[[idx + 1L]]
}

parse_seeds <- function(x) {
  if (is.null(x) || !nzchar(x)) {
    return(20260601:20260616)
  }
  parts <- unlist(strsplit(x, ",", fixed = TRUE), use.names = FALSE)
  out <- integer(0)
  for (part in parts) {
    part <- trimws(part)
    if (grepl("^[0-9]+:[0-9]+$", part)) {
      ends <- as.integer(strsplit(part, ":", fixed = TRUE)[[1L]])
      out <- c(out, seq.int(ends[[1L]], ends[[2L]]))
    } else {
      out <- c(out, as.integer(part))
    }
  }
  unique(out[is.finite(out)])
}

cmd_args <- commandArgs(FALSE)
file_arg <- cmd_args[grep("^--file=", cmd_args)[1L]]
script_path <- normalizePath(sub("^--file=", "", file_arg %||% ""), mustWork = FALSE)
if (!file.exists(script_path)) {
  script_path <- normalizePath("analysis/support/ex1_mcmc_seed_screen/run.R", mustWork = TRUE)
}
support_dir <- dirname(script_path)
repo_root <- normalizePath(file.path(support_dir, "..", "..", ".."), mustWork = TRUE)

profile <- get_arg("--profile", "standard")
pkg_path <- get_arg("--pkg-path", NULL)
seed_override <- NULL
targets <- character(0)
force_refit <- FALSE

source(file.path(repo_root, "analysis", "lib", "manuscript_setup.R"))

seeds <- parse_seeds(get_arg("--seeds", NULL))
if (!length(seeds)) stop("No valid seeds supplied.", call. = FALSE)

cores <- as.integer(get_arg("--cores", min(4L, length(seeds), parallel::detectCores(logical = FALSE) %||% 1L)))
if (!is.finite(cores) || cores < 1L) cores <- 1L
cores <- min(cores, length(seeds))

out_dir <- file.path(support_dir, "outputs")
fig_dir <- file.path(out_dir, "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

nburn <- as.integer(cfg_profile$ex1$n_burn_trace %||% cfg_profile$ex1$n_burn)
nmcmc <- as.integer(cfg_profile$ex1$n_mcmc_trace %||% cfg_profile$ex1$n_mcmc)
thin <- max(1L, as.integer(cfg_profile$ex1$thin_trace %||% 1L))

trace_indices <- function(n, thin) seq.int(1L, n, by = thin)

lag1_acf <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) < 3L || stats::sd(x) == 0) return(NA_real_)
  as.numeric(stats::acf(x, plot = FALSE, lag.max = 1)$acf[2L])
}

third_drift <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) < 9L || stats::sd(x) == 0) return(NA_real_)
  n <- length(x)
  k <- floor(n / 3)
  abs(mean(utils::head(x, k)) - mean(utils::tail(x, k))) / stats::sd(x)
}

plot_seed_trace <- function(seed, sigma_trace, gamma_trace, file) {
  grDevices::png(file, width = 1800, height = 1300, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par), add = TRUE)
  graphics::par(mfrow = c(2, 2), mar = c(4.1, 4.1, 3, 1.2))
  graphics::plot(sigma_trace, type = "l", col = "#2F5D7C", lwd = 0.8,
                 xlab = "retained draw (thinned)", ylab = expression(sigma),
                 main = sprintf("seed %d: sigma trace", seed))
  graphics::grid(col = "grey90")
  graphics::plot(gamma_trace, type = "l", col = "#8A4F2A", lwd = 0.8,
                 xlab = "retained draw (thinned)", ylab = expression(gamma),
                 main = sprintf("seed %d: gamma trace", seed))
  graphics::grid(col = "grey90")
  graphics::plot(stats::density(sigma_trace), col = "#2F5D7C", lwd = 1.5,
                 xlab = expression(sigma), main = "sigma density")
  graphics::rug(sigma_trace, col = grDevices::adjustcolor("#2F5D7C", 0.35))
  graphics::plot(stats::density(gamma_trace), col = "#8A4F2A", lwd = 1.5,
                 xlab = expression(gamma), main = "gamma density")
  graphics::rug(gamma_trace, col = grDevices::adjustcolor("#8A4F2A", 0.35))
}

fit_seed <- function(seed) {
  set.seed(seed)
  y_ts <- datasets::LakeHuron
  y <- as.numeric(y_ts)
  model <- exdqlm::polytrendMod(order = 2, m0 = c(mean(y), 0), C0 = 10 * diag(2))

  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    exdqlm::exdqlmMCMC(
      y = y, p0 = 0.50, model = model,
      df = 0.9, dim.df = 2,
      PriorGamma = list(m_gam = 0, s_gam = 0.1, df_gam = 1),
      n.burn = nburn, n.mcmc = nmcmc,
      verbose = FALSE,
      trace.diagnostics = FALSE
    ),
    error = function(e) e
  )
  runtime <- proc.time()[["elapsed"]] - t0

  if (inherits(fit, "error")) {
    return(list(
      row = data.frame(seed = seed, status = "fit_error", runtime_sec = runtime,
                       ess_sigma = NA_real_, ess_gamma = NA_real_,
                       acf1_sigma = NA_real_, acf1_gamma = NA_real_,
                       drift_sigma = NA_real_, drift_gamma = NA_real_,
                       score = -Inf, message = fit$message),
      sigma = numeric(0), gamma = numeric(0)
    ))
  }

  sigma <- as.numeric(fit$samp.sigma)
  gamma <- as.numeric(fit$samp.gamma)
  idx <- trace_indices(length(sigma), thin)
  sigma_t <- sigma[idx]
  gamma_t <- gamma[idx]

  fig_file <- file.path(fig_dir, sprintf("seed_%d_trace.png", seed))
  plot_seed_trace(seed, sigma_t, gamma_t, fig_file)

  ess_sigma <- tryCatch(as.numeric(coda::effectiveSize(coda::mcmc(sigma))), error = function(e) NA_real_)
  ess_gamma <- tryCatch(as.numeric(coda::effectiveSize(coda::mcmc(gamma))), error = function(e) NA_real_)
  acf1_sigma <- lag1_acf(sigma)
  acf1_gamma <- lag1_acf(gamma)
  drift_sigma <- third_drift(sigma)
  drift_gamma <- third_drift(gamma)
  score <- sum(log1p(c(ess_sigma, ess_gamma)), na.rm = TRUE) -
    3 * sum(abs(c(acf1_sigma, acf1_gamma)), na.rm = TRUE) -
    2 * sum(c(drift_sigma, drift_gamma), na.rm = TRUE)

  list(
    row = data.frame(
      seed = seed,
      status = "ok",
      runtime_sec = runtime,
      ess_sigma = ess_sigma,
      ess_gamma = ess_gamma,
      acf1_sigma = acf1_sigma,
      acf1_gamma = acf1_gamma,
      drift_sigma = drift_sigma,
      drift_gamma = drift_gamma,
      sigma_mean = mean(sigma),
      gamma_mean = mean(gamma),
      sigma_sd = stats::sd(sigma),
      gamma_sd = stats::sd(gamma),
      score = score,
      figure = fig_file,
      message = "",
      stringsAsFactors = FALSE
    ),
    sigma = sigma_t,
    gamma = gamma_t
  )
}

log_msg(sprintf(
  "Example 1 seed screen: %d seeds, profile=%s, n.burn=%d, n.mcmc=%d, thin=%d, cores=%d",
  length(seeds), profile, nburn, nmcmc, thin, cores
))

results <- if (cores > 1L && .Platform$OS.type != "windows") {
  parallel::mclapply(seeds, fit_seed, mc.cores = cores)
} else {
  lapply(seeds, fit_seed)
}

summary_df <- do.call(rbind, lapply(results, `[[`, "row"))
summary_df <- summary_df[order(-summary_df$score, summary_df$seed), , drop = FALSE]
utils::write.csv(summary_df, file.path(out_dir, "seed_screen_summary.csv"), row.names = FALSE)

top_n <- min(8L, sum(summary_df$status == "ok"))
if (top_n > 0L) {
  top_seeds <- summary_df$seed[seq_len(top_n)]
  top_results <- results[match(top_seeds, seeds)]
  contact_file <- file.path(out_dir, sprintf("contact_sheet_top%d.png", top_n))
  grDevices::png(contact_file, width = 1800, height = max(900, 300 * top_n), res = 150)
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par), add = TRUE)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(top_n, 2), mar = c(2.5, 4, 2, 0.8))
  for (i in seq_along(top_results)) {
    seed <- top_seeds[[i]]
    graphics::plot(top_results[[i]]$sigma, type = "l", col = "#2F5D7C", lwd = 0.8,
                   xlab = "", ylab = expression(sigma),
                   main = sprintf("seed %d: sigma", seed))
    graphics::grid(col = "grey90")
    graphics::plot(top_results[[i]]$gamma, type = "l", col = "#8A4F2A", lwd = 0.8,
                   xlab = "", ylab = expression(gamma),
                   main = sprintf("seed %d: gamma", seed))
    graphics::grid(col = "grey90")
  }
}

log_msg(sprintf("Example 1 seed screen complete. Summary: %s", file.path(out_dir, "seed_screen_summary.csv")))
