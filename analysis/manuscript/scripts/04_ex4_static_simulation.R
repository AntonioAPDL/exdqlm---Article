need_ex4 <- target_enabled("ex4", c("ex4figure", "ex4table"))
if (!need_ex4) {
  log_msg("Example 4 (static exAL simulation): skipped (target filter)")
} else {
  log_msg("Example 4 (static exAL simulation): start")

  need_ex4figure <- target_enabled("ex4figure", "ex4")
  need_ex4table <- target_enabled("ex4table", "ex4")

  cfg_ex4 <- cfg_profile$ex4
  train_n <- as.integer(cfg_ex4$n_train)
  grid_n <- as.integer(cfg_ex4$grid_n)
  holdout_n <- as.integer(cfg_ex4$holdout_n)
  p_levels <- as.numeric(cfg_ex4$p_levels)
  ldvb_max_iter <- as.integer(cfg_ex4$ldvb_max_iter)
  ldvb_max_iter_tail <- as.integer(cfg_ex4$ldvb_max_iter_tail)
  ldvb_tol <- as.numeric(cfg_ex4$ldvb_tol)
  ldvb_n_samp_xi <- as.integer(cfg_ex4$ldvb_n_samp_xi)
  n_burn <- as.integer(cfg_ex4$n_burn)
  n_mcmc <- as.integer(cfg_ex4$n_mcmc)
  thin <- as.integer(cfg_ex4$thin %||% 1L)
  ex4_seed <- as.integer(seed_value + 404L)

  sim_par <- list(
    alpha0 = 0,
    alpha1 = 0.5,
    delta0 = 1.2,
    delta1 = 0.35
  )

  true_quantile <- function(x, p0) {
    (sim_par$alpha0 + sim_par$alpha1 * x) +
      (sim_par$delta0 + sim_par$delta1 * x) * stats::qnorm(p0)
  }

  simulate_y <- function(x) {
    mu <- sim_par$alpha0 + sim_par$alpha1 * x
    sigma <- sim_par$delta0 + sim_par$delta1 * x
    mu + sigma * stats::rnorm(length(x))
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

  ex4_obj <- load_or_fit_cache_safe("ex4_static_sim_v1", {
    set.seed(ex4_seed)

    x_train <- seq(-2, 2, length.out = train_n)
    X_train <- cbind(1, x_train)
    y_train <- simulate_y(x_train)

    x_grid <- seq(-2, 2, length.out = grid_n)
    X_grid <- cbind(1, x_grid)

    x_holdout <- sort(stats::runif(holdout_n, min = -2, max = 2))
    X_holdout <- cbind(1, x_holdout)
    y_holdout <- simulate_y(x_holdout)

    fits <- vector("list", length(p_levels))
    names(fits) <- vapply(p_levels, p_key, character(1))

    for (p0 in p_levels) {
      ldvb_budget <- if (isTRUE(all.equal(p0, 0.05))) ldvb_max_iter_tail else ldvb_max_iter

      fit_ldvb <- exdqlm::exal_static_LDVB(
        y = y_train,
        X = X_train,
        p0 = p0,
        max_iter = ldvb_budget,
        tol = ldvb_tol,
        n_samp_xi = ldvb_n_samp_xi,
        verbose = FALSE
      )
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

      fit_mcmc <- exdqlm::exal_static_mcmc(
        y = y_train,
        X = X_train,
        p0 = p0,
        n.burn = n_burn,
        n.mcmc = n_mcmc,
        thin = thin,
        init.from.vb = TRUE,
        verbose = FALSE
      )
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

      diag_grid <- exdqlm::exalDiagnostics(
        fit_ldvb, fit_mcmc,
        X = X_grid,
        ref = true_quantile(x_grid, p0),
        plot = FALSE
      )
      diag_holdout <- exdqlm::exalDiagnostics(
        fit_ldvb, fit_mcmc,
        X = X_holdout,
        y = y_holdout,
        ref = true_quantile(x_holdout, p0),
        plot = FALSE
      )

      fits[[p_key(p0)]] <- list(
        p0 = p0,
        ldvb = list(
          converged = isTRUE(fit_ldvb$converged),
          iter = as.integer(fit_ldvb$iter),
          stop = fit_ldvb$diagnostics$convergence$stop_reason,
          runtime = as.numeric(fit_ldvb$run.time),
          beta = as.numeric(diag_grid$m1.beta.mean),
          grid_rmse = as.numeric(diag_grid$m1.ref_rmse),
          grid_mae = as.numeric(diag_grid$m1.ref_mae),
          holdout_check_loss = as.numeric(diag_holdout$m1.check_loss)
        ),
        mcmc = list(
          kernel = fit_mcmc$mh.diagnostics$proposal,
          runtime = as.numeric(fit_mcmc$run.time),
          beta = as.numeric(diag_grid$m2.beta.mean),
          grid_rmse = as.numeric(diag_grid$m2.ref_rmse),
          grid_mae = as.numeric(diag_grid$m2.ref_mae),
          holdout_check_loss = as.numeric(diag_holdout$m2.check_loss)
        ),
        grid = list(
          x = diag_grid$x,
          ref = diag_grid$ref,
          ldvb_map = diag_grid$m1.map.quant,
          mcmc_map = diag_grid$m2.map.quant
        )
      )
    }

    list(
      sim_par = sim_par,
      seed = ex4_seed,
      train = list(x = x_train, X = X_train, y = y_train),
      grid = list(x = x_grid, X = X_grid),
      holdout = list(x = x_holdout, X = X_holdout, y = y_holdout),
      fits = fits
    )
  }, note = "ex4_static_sim_v1")

  capture_output_file("ex4_run_summary.txt", {
    cat(sprintf("profile=%s\n", selected_profile))
    cat(sprintf("seed=%d\n", ex4_obj$seed))
    cat(sprintf("train_n=%d, grid_n=%d, holdout_n=%d\n", train_n, grid_n, holdout_n))
    cat(sprintf("p_levels=%s\n\n", paste(format(p_levels, digits = 2), collapse = ", ")))
    for (nm in names(ex4_obj$fits)) {
      res <- ex4_obj$fits[[nm]]
      cat(sprintf("p0=%0.2f\n", res$p0))
      cat(sprintf(
        "  LDVB: converged=%s, iter=%d, stop=%s, runtime=%0.3f\n",
        if (isTRUE(res$ldvb$converged)) "TRUE" else "FALSE",
        res$ldvb$iter,
        res$ldvb$stop,
        res$ldvb$runtime
      ))
      cat(sprintf(
        "  MCMC: kernel=%s, runtime=%0.3f\n",
        res$mcmc$kernel,
        res$mcmc$runtime
      ))
      cat(sprintf(
        "  Grid RMSE: LDVB=%0.4f, MCMC=%0.4f\n",
        res$ldvb$grid_rmse,
        res$mcmc$grid_rmse
      ))
      cat(sprintf(
        "  Holdout check loss: LDVB=%0.4f, MCMC=%0.4f\n\n",
        res$ldvb$holdout_check_loss,
        res$mcmc$holdout_check_loss
      ))
    }
  })
  register_artifact(
    artifact_id = "log_ex4_run_summary",
    artifact_type = "log",
    relative_path = "analysis/manuscript/outputs/logs/ex4_run_summary.txt",
    manuscript_target = "Example 4 textual outputs",
    status = "reproduced",
    notes = "Simulation settings, convergence summary, and recovery metrics for Example 4."
  )

  summary_rows <- do.call(
    rbind,
    lapply(names(ex4_obj$fits), function(nm) {
      res <- ex4_obj$fits[[nm]]
      p0 <- res$p0
      beta_true <- c(
        sim_par$alpha0 + sim_par$delta0 * stats::qnorm(p0),
        sim_par$alpha1 + sim_par$delta1 * stats::qnorm(p0)
      )
      data.frame(
        p0 = rep(p0, 2L),
        method = c("LDVB", "MCMC"),
        beta0_true = rep(beta_true[1], 2L),
        beta1_true = rep(beta_true[2], 2L),
        beta0_hat = c(res$ldvb$beta[1], res$mcmc$beta[1]),
        beta1_hat = c(res$ldvb$beta[2], res$mcmc$beta[2]),
        grid_rmse = c(res$ldvb$grid_rmse, res$mcmc$grid_rmse),
        grid_mae = c(res$ldvb$grid_mae, res$mcmc$grid_mae),
        holdout_check_loss = c(res$ldvb$holdout_check_loss, res$mcmc$holdout_check_loss),
        runtime_sec = c(res$ldvb$runtime, res$mcmc$runtime),
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
      notes = "Runtime and recovery metrics for LDVB and MCMC across p0 = 0.05, 0.25, 0.50."
    )
  }

  if (need_ex4figure) {
    y_lim <- range(
      c(
        ex4_obj$train$y,
        unlist(lapply(ex4_obj$fits, function(res) {
          c(
            res$grid$ref,
            res$grid$ldvb_map,
            res$grid$mcmc_map
          )
        }))
      ),
      finite = TRUE
    )

    save_png_plot("ex4static.png", {
      graphics::par(mfrow = c(1, 3), mar = c(4, 4, 3, 1))
      for (i in seq_along(p_levels)) {
        res <- ex4_obj$fits[[p_key(p_levels[i])]]
        graphics::plot(
          ex4_obj$train$x,
          ex4_obj$train$y,
          pch = 16,
          cex = 0.55,
          col = grDevices::adjustcolor("grey55", alpha.f = 0.35),
          xlab = "x",
          ylab = if (i == 1L) "y / fitted quantile" else "",
          main = sprintf("p0 = %.2f", res$p0),
          ylim = y_lim
        )
        graphics::lines(ex4_obj$grid$x, res$grid$ref, lwd = 2, lty = 2, col = "black")
        graphics::lines(ex4_obj$grid$x, res$grid$ldvb_map, lwd = 2, col = ldvb_cols$m1)
        graphics::lines(ex4_obj$grid$x, res$grid$mcmc_map, lwd = 2, col = ldvb_cols$m2)
        if (i == 1L) {
          graphics::legend(
            "topleft",
            legend = c("truth", "LDVB", "MCMC"),
            col = c("black", ldvb_cols$m1, ldvb_cols$m2),
            lty = c(2, 1, 1),
            lwd = c(2, 2, 2),
            bty = "n"
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
      notes = "Static exAL simulation with truth, LDVB, and MCMC quantile curves for p0 = 0.05, 0.25, 0.50."
    )
  }

  register_note(
    "ex4",
    "Example 4 uses a heteroskedastic normal location-scale simulation with known linear conditional quantiles."
  )
  register_note(
    "ex4",
    "The p0=0.05 LDVB fit uses an expanded iteration budget; p0=0.25 and p0=0.50 use the default Example 4 LDVB budget."
  )
  register_note(
    "ex4",
    "Example 4 focuses on the general static exAL model; the AL special case remains available via dqlm.ind = TRUE."
  )

  log_msg("Example 4 (static exAL simulation): complete")
}
