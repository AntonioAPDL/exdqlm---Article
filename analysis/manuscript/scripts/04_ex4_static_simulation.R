need_ex4 <- target_enabled("ex4", c("ex4figure", "ex4table"))
if (!need_ex4) {
  log_msg("Example 4 (static rhs_ns sparse simulation): skipped (target filter)")
} else {
  log_msg("Example 4 (static rhs_ns sparse simulation): start")

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
  ldvb_n_samp_xi <- as.integer(cfg_ex4$ldvb_n_samp_xi)
  n_burn <- as.integer(cfg_ex4$n_burn)
  n_mcmc <- as.integer(cfg_ex4$n_mcmc)
  thin <- as.integer(cfg_ex4$thin %||% 1L)
  ex4_seed <- as.integer(seed_value + 404L)

  if (length(beta_slopes) != predictor_n) {
    stop("Example 4 config mismatch: length(true_beta) must equal n_predictors.", call. = FALSE)
  }

  rhs_ctrl <- list(
    tau0 = as.numeric(cfg_ex4$rhs_tau0),
    a_zeta = as.numeric(cfg_ex4$rhs_a_zeta),
    b_zeta = as.numeric(cfg_ex4$rhs_b_zeta),
    zeta2_fixed = as.numeric(cfg_ex4$rhs_zeta2_fixed),
    shrink_intercept = FALSE
  )

  true_beta_full <- c(0, beta_slopes)
  coef_names <- paste0("x", seq_len(predictor_n))
  active_mask <- beta_slopes != 0
  cov_mat <- cov_rho ^ as.matrix(stats::dist(seq_len(predictor_n)))

  simulate_target_quantile_sample <- function(X_raw, p0, z = NULL) {
    if (is.null(z)) z <- stats::rnorm(nrow(X_raw))
    as.numeric(X_raw %*% beta_slopes) + sigma_eps * (z - stats::qnorm(p0))
  }

  p_key <- function(p0) sprintf("p%03d", round(100 * p0))

  load_or_fit_cache_safe <- function(key, expr, note = NULL) {
    path <- cache_file(key)
    if (file.exists(path) && !force_refit) {
      if (!is.null(note)) log_msg(sprintf("Loading cache for %s", key))
      cache_info <- file.info(path)
      if (!isTRUE(cache_info$size > 0)) {
        log_msg(sprintf("Ignoring empty cache file for %s; refitting.", key))
        unlink(path, force = TRUE)
      } else {
        cached <- tryCatch(
          readRDS(path),
          error = function(e) {
            log_msg(sprintf("Ignoring unreadable cache for %s: %s", key, conditionMessage(e)))
            unlink(path, force = TRUE)
            NULL
          }
        )
        if (!is.null(cached)) return(cached)
      }
    }
    if (!is.null(note)) log_msg(sprintf("Fitting cache for %s", key))
    val <- eval.parent(substitute(expr))
    tryCatch(
      saveRDS(val, path),
      error = function(e) {
        if (file.exists(path) && !isTRUE(file.info(path)$size > 0)) {
          unlink(path, force = TRUE)
        }
        log_msg(sprintf("Cache write skipped for %s: %s", key, conditionMessage(e)))
        invisible(NULL)
      }
    )
    val
  }

  ex4_obj <- load_or_fit_cache_safe("ex4_static_rhsns_sparse_v1", {
    set.seed(ex4_seed)

    X_train_raw <- MASS::mvrnorm(train_n, mu = rep(0, predictor_n), Sigma = cov_mat)
    X_train <- cbind(1, X_train_raw)
    X_holdout_raw <- MASS::mvrnorm(holdout_n, mu = rep(0, predictor_n), Sigma = cov_mat)
    X_holdout <- cbind(1, X_holdout_raw)
    ref_holdout <- as.numeric(X_holdout %*% true_beta_full)

    fits <- vector("list", length(p_levels))
    names(fits) <- vapply(p_levels, p_key, character(1))

    for (p0 in p_levels) {
      ldvb_budget <- if (isTRUE(all.equal(p0, 0.05))) ldvb_max_iter_tail else ldvb_max_iter
      y_train <- simulate_target_quantile_sample(X_train_raw, p0)
      y_holdout <- simulate_target_quantile_sample(X_holdout_raw, p0)

      warn_ldvb <- msg_ldvb <- character()
      fit_ldvb <- withCallingHandlers(
        exdqlm::exal_static_LDVB(
          y = y_train,
          X = X_train,
          p0 = p0,
          beta_prior = "rhs_ns",
          beta_prior_controls = rhs_ctrl,
          max_iter = ldvb_budget,
          tol = ldvb_tol,
          n_samp_xi = ldvb_n_samp_xi,
          verbose = FALSE
        ),
        warning = function(w) {
          warn_ldvb <<- c(warn_ldvb, conditionMessage(w))
          invokeRestart("muffleWarning")
        },
        message = function(m) {
          msg_ldvb <<- c(msg_ldvb, conditionMessage(m))
          invokeRestart("muffleMessage")
        }
      )
      if (length(unique(warn_ldvb)) > 0L || length(unique(msg_ldvb)) > 0L) {
        stop(
          sprintf(
            "Example 4 LDVB was not silent at p0=%0.2f. warnings=%s messages=%s",
            p0,
            paste(unique(warn_ldvb), collapse = " | "),
            paste(unique(msg_ldvb), collapse = " | ")
          ),
          call. = FALSE
        )
      }
      if (!isTRUE(fit_ldvb$converged)) {
        stop(
          sprintf(
            "Example 4 LDVB did not converge at p0=%0.2f (iter=%d, stop=%s).",
            p0,
            as.integer(fit_ldvb$iter),
            fit_ldvb$diagnostics$convergence$stop_reason
          ),
          call. = FALSE
        )
      }

      warn_mcmc <- msg_mcmc <- character()
      fit_mcmc <- withCallingHandlers(
        exdqlm::exal_static_mcmc(
          y = y_train,
          X = X_train,
          p0 = p0,
          beta_prior = "rhs_ns",
          beta_prior_controls = rhs_ctrl,
          n.burn = n_burn,
          n.mcmc = n_mcmc,
          thin = thin,
          init.from.vb = TRUE,
          verbose = FALSE
        ),
        warning = function(w) {
          warn_mcmc <<- c(warn_mcmc, conditionMessage(w))
          invokeRestart("muffleWarning")
        },
        message = function(m) {
          msg_mcmc <<- c(msg_mcmc, conditionMessage(m))
          invokeRestart("muffleMessage")
        }
      )
      if (length(unique(warn_mcmc)) > 0L || length(unique(msg_mcmc)) > 0L) {
        stop(
          sprintf(
            "Example 4 MCMC was not silent at p0=%0.2f. warnings=%s messages=%s",
            p0,
            paste(unique(warn_mcmc), collapse = " | "),
            paste(unique(msg_mcmc), collapse = " | ")
          ),
          call. = FALSE
        )
      }
      if (!identical(fit_mcmc$mh.diagnostics$proposal, "slice")) {
        stop(
          sprintf("Example 4 expected slice default for static MCMC at p0=%0.2f.", p0),
          call. = FALSE
        )
      }
      if (!all(is.finite(as.numeric(fit_mcmc$samp.beta))) ||
          !all(is.finite(as.numeric(fit_mcmc$samp.sigma))) ||
          !all(is.finite(as.numeric(fit_mcmc$samp.gamma)))) {
        stop(
          sprintf("Example 4 MCMC returned non-finite draws at p0=%0.2f.", p0),
          call. = FALSE
        )
      }

      diag_holdout <- exdqlm::exalDiagnostics(
        fit_ldvb, fit_mcmc,
        X = X_holdout,
        y = y_holdout,
        ref = ref_holdout,
        plot = FALSE
      )

      z_crit <- stats::qnorm(0.975)
      ldvb_beta_full <- as.numeric(fit_ldvb$qbeta$m)
      ldvb_sd_full <- sqrt(pmax(diag(as.matrix(fit_ldvb$qbeta$V)), 0))
      ldvb_lb_full <- ldvb_beta_full - z_crit * ldvb_sd_full
      ldvb_ub_full <- ldvb_beta_full + z_crit * ldvb_sd_full

      mcmc_draws <- as.matrix(fit_mcmc$samp.beta)
      mcmc_beta_full <- as.numeric(colMeans(mcmc_draws))
      mcmc_lb_full <- as.numeric(apply(mcmc_draws, 2, stats::quantile, probs = 0.025))
      mcmc_ub_full <- as.numeric(apply(mcmc_draws, 2, stats::quantile, probs = 0.975))

      slope_idx <- seq_len(predictor_n) + 1L
      ldvb_beta_slopes <- ldvb_beta_full[slope_idx]
      mcmc_beta_slopes <- mcmc_beta_full[slope_idx]

      fits[[p_key(p0)]] <- list(
        p0 = p0,
        y_train = y_train,
        ldvb = list(
          converged = TRUE,
          iter = as.integer(fit_ldvb$iter),
          stop = fit_ldvb$diagnostics$convergence$stop_reason,
          runtime = as.numeric(fit_ldvb$run.time),
          beta_full = ldvb_beta_full,
          beta_slopes = ldvb_beta_slopes,
          beta_lb_slopes = ldvb_lb_full[slope_idx],
          beta_ub_slopes = ldvb_ub_full[slope_idx],
          active_rmse = sqrt(mean((ldvb_beta_slopes[active_mask] - beta_slopes[active_mask])^2)),
          inactive_mae = mean(abs(ldvb_beta_slopes[!active_mask])),
          holdout_ref_rmse = as.numeric(diag_holdout$m1.ref_rmse),
          holdout_check_loss = as.numeric(diag_holdout$m1.check_loss),
          tau = as.numeric(fit_ldvb$beta_prior$summary$tau),
          zeta2 = as.numeric(fit_ldvb$beta_prior$summary$zeta2)
        ),
        mcmc = list(
          kernel = fit_mcmc$mh.diagnostics$proposal,
          runtime = as.numeric(fit_mcmc$run.time),
          beta_full = mcmc_beta_full,
          beta_slopes = mcmc_beta_slopes,
          beta_lb_slopes = mcmc_lb_full[slope_idx],
          beta_ub_slopes = mcmc_ub_full[slope_idx],
          active_rmse = sqrt(mean((mcmc_beta_slopes[active_mask] - beta_slopes[active_mask])^2)),
          inactive_mae = mean(abs(mcmc_beta_slopes[!active_mask])),
          holdout_ref_rmse = as.numeric(diag_holdout$m2.ref_rmse),
          holdout_check_loss = as.numeric(diag_holdout$m2.check_loss),
          tau = as.numeric(fit_mcmc$beta_prior$summary$tau),
          zeta2 = as.numeric(fit_mcmc$beta_prior$summary$zeta2)
        )
      )
    }

    list(
      seed = ex4_seed,
      train_n = train_n,
      holdout_n = holdout_n,
      predictor_n = predictor_n,
      cov_mat = cov_mat,
      cov_rho = cov_rho,
      sigma_eps = sigma_eps,
      beta_slopes = beta_slopes,
      coef_names = coef_names,
      rhs_ctrl = rhs_ctrl,
      p_levels = p_levels,
      fits = fits
    )
  }, note = "ex4_static_rhsns_sparse_v1")

  capture_output_file("ex4_run_summary.txt", {
    cat(sprintf("profile=%s\n", selected_profile))
    cat(sprintf("seed=%d\n", ex4_obj$seed))
    cat(sprintf("train_n=%d, holdout_n=%d, predictors=%d\n", train_n, holdout_n, predictor_n))
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
    notes = "Sparse rhs_ns static simulation settings and recovery metrics for Example 4."
  )

  summary_rows <- do.call(
    rbind,
    lapply(names(ex4_obj$fits), function(nm) {
      res <- ex4_obj$fits[[nm]]
      data.frame(
        p0 = rep(res$p0, 2L),
        method = c("LDVB", "MCMC"),
        runtime_sec = c(res$ldvb$runtime, res$mcmc$runtime),
        active_signal_rmse = c(res$ldvb$active_rmse, res$mcmc$active_rmse),
        inactive_signal_mae = c(res$ldvb$inactive_mae, res$mcmc$inactive_mae),
        holdout_quantile_rmse = c(res$ldvb$holdout_ref_rmse, res$mcmc$holdout_ref_rmse),
        holdout_check_loss = c(res$ldvb$holdout_check_loss, res$mcmc$holdout_check_loss),
        rhs_tau = c(res$ldvb$tau, res$mcmc$tau),
        rhs_zeta2 = c(res$ldvb$zeta2, res$mcmc$zeta2),
        ldvb_iter = c(res$ldvb$iter, NA_integer_),
        ldvb_stop = c(res$ldvb$stop, NA_character_),
        stringsAsFactors = FALSE
      )
    })
  )

  if (need_ex4table) {
    save_table_csv(
      summary_rows,
      filename = "ex4static_summary.csv",
      artifact_id = "tab_ex4static_summary",
      manuscript_target = "new: Example 4 static simulation summary",
      status = "reproduced",
      notes = "Runtime and sparse-signal recovery metrics for LDVB and MCMC under the rhs_ns prior."
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
        res <- ex4_obj$fits[[p_key(p_levels[i])]]
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
            legend = c("truth", "LDVB 95% interval", "MCMC 95% interval"),
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
      notes = "Sparse rhs_ns static simulation coefficient-recovery comparison for p0 = 0.05, 0.25, 0.50."
    )
  }

  register_note(
    "ex4",
    "Example 4 uses a sparse correlated-Gaussian regression benchmark with a target-quantile-centered Gaussian response model, so the true p0-quantile equals X beta at each fitted p0."
  )
  register_note(
    "ex4",
    "The static sparse benchmark uses the rhs_ns prior with tau0 = 0.15, zeta2_fixed = 9, and an unshrunk intercept."
  )
  register_note(
    "ex4",
    "The p0=0.05 LDVB fit uses an expanded iteration budget; p0=0.25 and p0=0.50 use the standard Example 4 LDVB budget."
  )
  register_note(
    "ex4",
    "Example 4 focuses on the general static exAL model; the AL special case remains available via dqlm.ind = TRUE."
  )

  log_msg("Example 4 (static rhs_ns sparse simulation): complete")
}
