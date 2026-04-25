need_ex4 <- target_enabled("ex4", c("ex4figure", "ex4table"))
if (!need_ex4) {
  log_msg("Example 4 (static RHS sparse simulation): skipped (target filter)")
} else {
  log_msg("Example 4 (static RHS sparse simulation): start")

  source(file.path(repo_root, "analysis", "manuscript", "scripts", "04_ex4_helpers.R"), local = TRUE)

  need_ex4figure <- target_enabled("ex4figure", "ex4")
  need_ex4table <- target_enabled("ex4table", "ex4")

  cfg_ex4 <- cfg_profile$ex4
  train_n <- as.integer(cfg_ex4$n_train)
  holdout_n <- as.integer(cfg_ex4$holdout_n)
  predictor_n <- as.integer(cfg_ex4$n_predictors)
  cov_rho <- as.numeric(cfg_ex4$cov_rho)
  sigma_eps <- as.numeric(cfg_ex4$sigma_eps)
  beta_slopes <- as.numeric(cfg_ex4$true_beta)
  p_levels <- as.numeric(cfg_ex4$p_levels)
  ldvb_max_iter <- as.integer(cfg_ex4$ldvb_max_iter)
  ldvb_max_iter_tail <- as.integer(cfg_ex4$ldvb_max_iter_tail)
  ldvb_tol <- as.numeric(cfg_ex4$ldvb_tol)
  n_samp <- as.integer(cfg_ex4$n_samp %||% 200L)
  ldvb_n_samp_xi <- as.integer(cfg_ex4$ldvb_n_samp_xi)
  n_burn <- as.integer(cfg_ex4$n_burn)
  n_mcmc <- as.integer(cfg_ex4$n_mcmc)
  thin <- as.integer(cfg_ex4$thin %||% 1L)
  ex4_seed_info <- ex4_resolve_dataset_seed(cfg_ex4)
  ex4_seed <- as.integer(ex4_seed_info$seed)
  rhs_ctrl <- ex4_build_rhs_ctrl(cfg_ex4)
  cache_key <- sprintf(
    "ex4_static_rhsns_sparse_seed_%d_ns%d_b%d_k%d_v3",
    ex4_seed,
    n_samp,
    n_burn,
    n_mcmc
  )
  ex4_obj <- NULL
  if (!force_refit && identical(ex4_seed_info$source, "screen_selection")) {
    screen_cache_key <- ex4_seed_screen_cache_key(ex4_seed, cfg_ex4)
    screen_cache_path <- cache_file(screen_cache_key)
    if (file.exists(screen_cache_path)) {
      log_msg(sprintf("Reusing Example 4 seed-screen cache for %s", screen_cache_key))
      ex4_obj <- readRDS(screen_cache_path)
      saveRDS(ex4_obj, cache_file(cache_key))
    }
  }
  if (is.null(ex4_obj)) {
    ex4_obj <- ex4_load_or_fit_cache_safe(
      cache_key,
      ex4_fit_seed(ex4_seed, cfg_ex4, stop_on_failure = TRUE),
      note = cache_key
    )
  }

  capture_output_file("ex4_run_summary.txt", {
    cat(sprintf("profile=%s\n", selected_profile))
    cat(sprintf("seed=%d\n", ex4_obj$seed))
    cat(sprintf("seed_source=%s\n", ex4_seed_info$source))
    if (!is.na(ex4_seed_info$selection_file)) {
      cat(sprintf("seed_selection_file=%s\n", ex4_seed_info$selection_file))
      cat(sprintf("seed_selection_target_p0=%0.2f\n", ex4_seed_info$target_p0))
    }
    cat(sprintf("train_n=%d, holdout_n=%d, predictors=%d\n", train_n, holdout_n, predictor_n))
    cat(sprintf("ldvb_n.samp=%d, n.burn=%d, n.mcmc=%d\n", n_samp, n_burn, n_mcmc))
    cat(sprintf("cov_rho=%0.2f, sigma_eps=%0.2f\n", cov_rho, sigma_eps))
    cat(sprintf("beta_slopes=%s\n", paste(format(ex4_obj$beta_slopes, trim = TRUE), collapse = ", ")))
    cat(sprintf(
      "rhs_ctrl: tau0=%0.3f, a_zeta=%0.3f, b_zeta=%0.3f, zeta2_fixed=%0.3f\n",
      rhs_ctrl$tau0, rhs_ctrl$a_zeta, rhs_ctrl$b_zeta, rhs_ctrl$zeta2_fixed
    ))
    cat(sprintf("p_levels=%s\n\n", paste(format(p_levels, digits = 2), collapse = ", ")))
    for (nm in names(ex4_obj$fits)) {
      res <- ex4_obj$fits[[nm]]
      cat(sprintf("p0=%0.2f\n", res$p0))
      cat(sprintf(
        "  LDVB: converged=%s, iter=%d, runtime=%0.3f, active_rmse=%0.4f, inactive_mae=%0.4f, holdout_rmse=%0.4f\n",
        if (isTRUE(res$ldvb$converged)) "TRUE" else "FALSE",
        res$ldvb$iter,
        res$ldvb$runtime,
        res$ldvb$active_rmse,
        res$ldvb$inactive_mae,
        res$ldvb$holdout_ref_rmse
      ))
      cat(sprintf(
        "  MCMC: kernel=%s, runtime=%0.3f, active_rmse=%0.4f, inactive_mae=%0.4f, holdout_rmse=%0.4f\n\n",
        res$mcmc$kernel,
        res$mcmc$runtime,
        res$mcmc$active_rmse,
        res$mcmc$inactive_mae,
        res$mcmc$holdout_ref_rmse
      ))
    }
  })
  register_artifact(
    artifact_id = "log_ex4_run_summary",
    artifact_type = "log",
    relative_path = "analysis/manuscript/outputs/logs/ex4_run_summary.txt",
    manuscript_target = "Example 4 textual outputs",
    status = "reproduced",
    notes = "Sparse RHS static simulation settings and recovery metrics for Example 4."
  )

  summary_rows <- ex4_summary_rows(ex4_obj, cfg_ex4 = cfg_ex4)

  if (need_ex4table) {
    save_table_csv(
      summary_rows,
      filename = "ex4static_summary.csv",
      artifact_id = "tab_ex4static_summary",
      manuscript_target = "new: Example 4 static simulation summary",
      status = "reproduced",
      notes = "Runtime and sparse-signal recovery metrics for LDVB and MCMC under the RHS prior."
    )
  }

  if (need_ex4figure) {
    y_lim <- range(
      c(
        ex4_obj$beta_slopes,
        unlist(lapply(ex4_obj$fits, function(res) {
          c(
            res$ldvb$beta_lb_slopes,
            res$ldvb$beta_ub_slopes,
            res$mcmc$beta_lb_slopes,
            res$mcmc$beta_ub_slopes
          )
        }))
      ),
      finite = TRUE
    )
    y_pad <- 0.08 * diff(y_lim)
    if (!is.finite(y_pad) || y_pad <= 0) y_pad <- 0.5
    y_lim <- c(y_lim[1] - y_pad, y_lim[2] + y_pad)

    save_png_plot("ex4static.png", {
      graphics::par(mfrow = c(1, 3), mar = c(6, 4, 3, 1), xpd = NA)
      x_pos <- seq_len(predictor_n)
      for (i in seq_along(p_levels)) {
        res <- ex4_obj$fits[[ex4_p_key(p_levels[i])]]
        graphics::plot(
          x_pos,
          ex4_obj$beta_slopes,
          type = "n",
          xaxt = "n",
          xlab = "",
          ylab = if (i == 1L) "coefficient value" else "",
          main = sprintf("p0 = %.2f", res$p0),
          ylim = y_lim
        )
        graphics::abline(h = 0, col = "grey85", lty = 2)
        graphics::axis(1, at = x_pos, labels = ex4_obj$coef_names, las = 2, cex.axis = 0.9)
        graphics::segments(
          x_pos - 0.12, res$ldvb$beta_lb_slopes,
          x_pos - 0.12, res$ldvb$beta_ub_slopes,
          col = ldvb_cols$m1, lwd = 2
        )
        graphics::points(x_pos - 0.12, res$ldvb$beta_slopes, pch = 16, col = ldvb_cols$m1)
        graphics::segments(
          x_pos + 0.12, res$mcmc$beta_lb_slopes,
          x_pos + 0.12, res$mcmc$beta_ub_slopes,
          col = ldvb_cols$m2, lwd = 2
        )
        graphics::points(x_pos + 0.12, res$mcmc$beta_slopes, pch = 16, col = ldvb_cols$m2)
        graphics::points(x_pos, ex4_obj$beta_slopes, pch = 18, cex = 1.1, col = "black")
        if (i == 1L) {
          graphics::legend(
            "topleft",
            legend = c("truth", "VB 95% interval", "MCMC 95% interval"),
            col = c("black", ldvb_cols$m1, ldvb_cols$m2),
            pch = c(18, 16, 16),
            lty = c(0, 1, 1),
            lwd = c(0, 2, 2),
            bty = "n",
            cex = 0.9
          )
        }
      }
    })

    register_artifact(
      artifact_id = "fig_ex4static",
      artifact_type = "figure",
      relative_path = "analysis/manuscript/outputs/figures/ex4static.png",
      manuscript_target = "fig:ex4static",
      status = "reproduced",
      notes = "Sparse RHS static simulation coefficient-recovery comparison for p0 = 0.05, 0.25, 0.50."
    )
  }

  register_note(
    "ex4",
    "Example 4 uses a sparse correlated-Gaussian regression benchmark with a target-quantile-centered Gaussian response model, so the true p0-quantile equals X beta at each fitted p0."
  )
  register_note(
    "ex4",
    "The static sparse benchmark uses the regularized horseshoe (RHS) prior with tau0 = 0.15, zeta2_fixed = 9, and an unshrunk intercept."
  )
  register_note(
    "ex4",
    "The p0=0.05 LDVB fit uses an expanded iteration budget; p0=0.25 and p0=0.50 use the standard Example 4 LDVB budget."
  )
  if (identical(ex4_seed_info$source, "screen_selection")) {
    register_note(
      "ex4",
      sprintf(
        "The tracked Example 4 dataset seed (%d) was selected by the support-only ex4screen workflow using the p0=%0.2f MCMC full-coverage criterion for the plotted slope coefficients.",
        ex4_seed,
        ex4_seed_info$target_p0
      )
    )
  }
  register_note(
    "ex4",
    "Example 4 focuses on the general static exAL model; the AL special case remains available via al.ind = TRUE (static alias of dqlm.ind = TRUE)."
  )

  log_msg("Example 4 (static RHS sparse simulation): complete")
}
