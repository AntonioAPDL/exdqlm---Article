ex4_p_key <- function(p0) sprintf("p%03d", round(100 * p0))

ex4_build_rhs_ctrl <- function(cfg_ex4) {
  list(
    tau0 = as.numeric(cfg_ex4$rhs_tau0),
    a_zeta = as.numeric(cfg_ex4$rhs_a_zeta),
    b_zeta = as.numeric(cfg_ex4$rhs_b_zeta),
    zeta2_fixed = as.numeric(cfg_ex4$rhs_zeta2_fixed),
    shrink_intercept = FALSE
  )
}

ex4_interval_coverage <- function(lb, ub, truth) {
  contains <- as.logical(lb <= truth & truth <= ub)
  list(
    contains = contains,
    n_contains = sum(contains),
    n_total = length(contains),
    all_contains = all(contains)
  )
}

ex4_resolve_slope_coverage <- function(method_fit, beta_true) {
  if (!is.null(method_fit$slope_coverage)) {
    cov <- method_fit$slope_coverage
    if (!is.null(cov$contains) &&
        !is.null(cov$n_contains) &&
        !is.null(cov$n_total) &&
        !is.null(cov$all_contains)) {
      return(cov)
    }
  }
  ex4_interval_coverage(
    lb = as.numeric(method_fit$beta_lb_slopes),
    ub = as.numeric(method_fit$beta_ub_slopes),
    truth = as.numeric(beta_true)
  )
}

ex4_screen_target_p0 <- function(cfg_ex4) {
  as.numeric(cfg_ex4$screen_target_p0 %||% 0.50)
}

ex4_screen_file_stem <- function(cfg_ex4) {
  sprintf("ex4_seed_screen_p%03d", round(100 * ex4_screen_target_p0(cfg_ex4)))
}

ex4_screen_candidate_batches <- function(cfg_ex4, seed_value) {
  base_seeds <- as.integer(unlist(cfg_ex4$screen_seeds %||% (seed_value + 500L + seq_len(8L))))
  base_seeds <- sort(unique(base_seeds))
  if (length(base_seeds) < 2L) {
    stop("Example 4 seed screen requires at least two candidate seeds.", call. = FALSE)
  }

  extra_seed_count <- as.integer(cfg_ex4$screen_extra_seed_count %||% 0L)
  batch_size <- as.integer(cfg_ex4$screen_batch_size %||% length(base_seeds))
  if (!is.finite(batch_size) || batch_size < 1L) batch_size <- length(base_seeds)

  batches <- list(base_seeds)
  if (extra_seed_count > 0L) {
    extra_start <- max(base_seeds) + 1L
    extra_seeds <- seq.int(extra_start, length.out = extra_seed_count)
    extra_batches <- split(extra_seeds, ceiling(seq_along(extra_seeds) / batch_size))
    batches <- c(batches, extra_batches)
  }
  batches
}

ex4_seed_selection_path <- function(cfg_ex4) {
  file.path(tables_dir, sprintf("%s_selection.csv", ex4_screen_file_stem(cfg_ex4)))
}

ex4_seed_screen_cache_key <- function(dataset_seed, cfg_ex4) {
  sprintf(
    "ex4_seed_screen_seed_%d_ns%d_b%d_k%d_v2",
    as.integer(dataset_seed),
    as.integer(cfg_ex4$n_samp %||% 200L),
    as.integer(cfg_ex4$n_burn),
    as.integer(cfg_ex4$n_mcmc)
  )
}

ex4_resolve_dataset_seed <- function(cfg_ex4) {
  mode <- tolower(trimws(as.character(cfg_ex4$dataset_seed_mode %||% "configured")))
  configured_seed <- as.integer(cfg_ex4$dataset_seed %||% (seed_value + 404L))
  if (!mode %in% c("configured", "screen_selection")) {
    stop(sprintf("Unsupported Example 4 dataset_seed_mode '%s'.", mode), call. = FALSE)
  }
  if (identical(mode, "configured")) {
    return(list(
      seed = configured_seed,
      source = "configured",
      target_p0 = ex4_screen_target_p0(cfg_ex4),
      selection_file = NA_character_
    ))
  }

  selection_path <- ex4_seed_selection_path(cfg_ex4)
  if (!file.exists(selection_path)) {
    stop(
      sprintf(
        paste(
          "Example 4 is configured to use a screen-selected dataset seed, but the selection file was not found:",
          "%s",
          "Run the ex4screen target first."
        ),
        selection_path
      ),
      call. = FALSE
    )
  }

  selected_tab <- utils::read.csv(selection_path, stringsAsFactors = FALSE)
  if (!"selected" %in% names(selected_tab)) {
    stop(sprintf("Example 4 seed-selection file is missing the 'selected' column: %s", selection_path), call. = FALSE)
  }
  selected_rows <- selected_tab[isTRUE(selected_tab$selected) | selected_tab$selected %in% c(TRUE, "TRUE", "True", "true", 1, "1"), , drop = FALSE]
  if (nrow(selected_rows) != 1L) {
    stop(
      sprintf(
        "Expected exactly one selected Example 4 seed in %s, found %d.",
        selection_path,
        nrow(selected_rows)
      ),
      call. = FALSE
    )
  }

  list(
    seed = as.integer(selected_rows$seed[[1L]]),
    source = "screen_selection",
    target_p0 = ex4_screen_target_p0(cfg_ex4),
    selection_file = selection_path
  )
}

ex4_simulate_target_quantile_sample <- function(X_raw, beta_slopes, sigma_eps, p0, z = NULL) {
  if (is.null(z)) z <- stats::rnorm(nrow(X_raw))
  as.numeric(X_raw %*% beta_slopes) + sigma_eps * (z - stats::qnorm(p0))
}

ex4_load_or_fit_cache_safe <- function(key, expr, note = NULL) {
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

ex4_support_recovery <- function(beta_est, beta_true) {
  active_idx <- which(beta_true != 0)
  topk <- order(abs(beta_est), decreasing = TRUE)[seq_along(active_idx)]
  list(
    topk_support_ok = identical(sort(topk), active_idx),
    sign_support_ok = all(sign(beta_est[active_idx]) == sign(beta_true[active_idx])),
    min_active_abs = min(abs(beta_est[active_idx])),
    max_inactive_abs = max(abs(beta_est[-active_idx]))
  )
}

ex4_fit_seed <- function(dataset_seed, cfg_ex4, stop_on_failure = TRUE) {
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

  if (length(beta_slopes) != predictor_n) {
    stop("Example 4 config mismatch: length(true_beta) must equal n_predictors.", call. = FALSE)
  }

  rhs_ctrl <- ex4_build_rhs_ctrl(cfg_ex4)
  true_beta_full <- c(0, beta_slopes)
  coef_names <- paste0("x", seq_len(predictor_n))
  active_mask <- beta_slopes != 0
  cov_mat <- cov_rho ^ as.matrix(stats::dist(seq_len(predictor_n)))

  fit_one_seed <- function() {
    set.seed(dataset_seed)

    X_train_raw <- MASS::mvrnorm(train_n, mu = rep(0, predictor_n), Sigma = cov_mat)
    X_train <- cbind(1, X_train_raw)
    X_holdout_raw <- MASS::mvrnorm(holdout_n, mu = rep(0, predictor_n), Sigma = cov_mat)
    X_holdout <- cbind(1, X_holdout_raw)
    ref_holdout <- as.numeric(X_holdout %*% true_beta_full)

    fits <- vector("list", length(p_levels))
    names(fits) <- vapply(p_levels, ex4_p_key, character(1))

    for (p0 in p_levels) {
      ldvb_budget <- if (isTRUE(all.equal(p0, 0.05))) ldvb_max_iter_tail else ldvb_max_iter
      y_train <- ex4_simulate_target_quantile_sample(X_train_raw, beta_slopes, sigma_eps, p0)
      y_holdout <- ex4_simulate_target_quantile_sample(X_holdout_raw, beta_slopes, sigma_eps, p0)

      warn_ldvb <- msg_ldvb <- character()
      fit_ldvb <- withCallingHandlers(
        exdqlm::exalStaticLDVB(
          y = y_train,
          X = X_train,
          p0 = p0,
          beta_prior = "rhs_ns",
          beta_prior_controls = rhs_ctrl,
          max_iter = ldvb_budget,
          tol = ldvb_tol,
          n.samp = n_samp,
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
        exdqlm::exalStaticMCMC(
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

      diag_holdout <- exdqlm::exalStaticDiagnostics(
        fit_ldvb, fit_mcmc,
        X = X_holdout,
        y = y_holdout,
        ref = ref_holdout,
        plot = FALSE
      )

      z_crit <- stats::qnorm(0.975)
      if (!is.null(fit_ldvb$samp.beta)) {
        ldvb_draws <- as.matrix(fit_ldvb$samp.beta)
        ldvb_beta_full <- as.numeric(colMeans(ldvb_draws))
        ldvb_lb_full <- as.numeric(apply(ldvb_draws, 2, stats::quantile, probs = 0.025))
        ldvb_ub_full <- as.numeric(apply(ldvb_draws, 2, stats::quantile, probs = 0.975))
      } else {
        ldvb_beta_full <- as.numeric(fit_ldvb$qbeta$m)
        ldvb_sd_full <- sqrt(pmax(diag(as.matrix(fit_ldvb$qbeta$V)), 0))
        ldvb_lb_full <- ldvb_beta_full - z_crit * ldvb_sd_full
        ldvb_ub_full <- ldvb_beta_full + z_crit * ldvb_sd_full
      }

      mcmc_draws <- as.matrix(fit_mcmc$samp.beta)
      mcmc_beta_full <- as.numeric(colMeans(mcmc_draws))
      mcmc_lb_full <- as.numeric(apply(mcmc_draws, 2, stats::quantile, probs = 0.025))
      mcmc_ub_full <- as.numeric(apply(mcmc_draws, 2, stats::quantile, probs = 0.975))

      slope_idx <- seq_len(predictor_n) + 1L
      ldvb_beta_slopes <- ldvb_beta_full[slope_idx]
      mcmc_beta_slopes <- mcmc_beta_full[slope_idx]
      ldvb_support <- ex4_support_recovery(ldvb_beta_slopes, beta_slopes)
      mcmc_support <- ex4_support_recovery(mcmc_beta_slopes, beta_slopes)
      ldvb_slope_coverage <- ex4_interval_coverage(ldvb_lb_full[slope_idx], ldvb_ub_full[slope_idx], beta_slopes)
      mcmc_slope_coverage <- ex4_interval_coverage(mcmc_lb_full[slope_idx], mcmc_ub_full[slope_idx], beta_slopes)

      fits[[ex4_p_key(p0)]] <- list(
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
          zeta2 = as.numeric(fit_ldvb$beta_prior$summary$zeta2),
          support = ldvb_support,
          slope_coverage = ldvb_slope_coverage
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
          zeta2 = as.numeric(fit_mcmc$beta_prior$summary$zeta2),
          support = mcmc_support,
          slope_coverage = mcmc_slope_coverage
        )
      )
    }

    list(
      ok = TRUE,
      seed = as.integer(dataset_seed),
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
  }

  if (isTRUE(stop_on_failure)) {
    return(fit_one_seed())
  }

  tryCatch(
    fit_one_seed(),
    error = function(e) {
      list(
        ok = FALSE,
        seed = as.integer(dataset_seed),
        error = conditionMessage(e)
      )
    }
  )
}

ex4_summary_rows <- function(ex4_obj, cfg_ex4 = NULL) {
  vb_n_samp <- if (!is.null(cfg_ex4)) as.integer(cfg_ex4$n_samp %||% NA_integer_) else NA_integer_
  mcmc_n_burn <- if (!is.null(cfg_ex4)) as.integer(cfg_ex4$n_burn %||% NA_integer_) else NA_integer_
  mcmc_n_mcmc <- if (!is.null(cfg_ex4)) as.integer(cfg_ex4$n_mcmc %||% NA_integer_) else NA_integer_
  do.call(
    rbind,
    lapply(names(ex4_obj$fits), function(nm) {
      res <- ex4_obj$fits[[nm]]
      ldvb_cov <- ex4_resolve_slope_coverage(res$ldvb, ex4_obj$beta_slopes)
      mcmc_cov <- ex4_resolve_slope_coverage(res$mcmc, ex4_obj$beta_slopes)
      data.frame(
        p0 = rep(res$p0, 2L),
        method = c("VB", "MCMC"),
        runtime_sec = c(res$ldvb$runtime, res$mcmc$runtime),
        active_signal_rmse = c(res$ldvb$active_rmse, res$mcmc$active_rmse),
        inactive_signal_mae = c(res$ldvb$inactive_mae, res$mcmc$inactive_mae),
        holdout_quantile_rmse = c(res$ldvb$holdout_ref_rmse, res$mcmc$holdout_ref_rmse),
        holdout_check_loss = c(res$ldvb$holdout_check_loss, res$mcmc$holdout_check_loss),
        rhs_tau = c(res$ldvb$tau, res$mcmc$tau),
        rhs_zeta2 = c(res$ldvb$zeta2, res$mcmc$zeta2),
        posterior_draws = c(vb_n_samp, mcmc_n_mcmc),
        burn_in = c(NA_integer_, mcmc_n_burn),
        ldvb_iter = c(res$ldvb$iter, NA_integer_),
        ldvb_stop = c(res$ldvb$stop, NA_character_),
        truth_interval_cover_n = c(ldvb_cov$n_contains, mcmc_cov$n_contains),
        truth_interval_cover_total = c(ldvb_cov$n_total, mcmc_cov$n_total),
        truth_interval_cover_all = c(ldvb_cov$all_contains, mcmc_cov$all_contains),
        stringsAsFactors = FALSE
      )
    })
  )
}
