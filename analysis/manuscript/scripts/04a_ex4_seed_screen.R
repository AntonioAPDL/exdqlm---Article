need_ex4screen <- target_enabled("ex4screen")
if (!need_ex4screen) {
  log_msg("Example 4 seed screen: skipped (target filter)")
} else {
  log_msg("Example 4 seed screen: start")

  source(file.path(repo_root, "analysis", "manuscript", "scripts", "04_ex4_helpers.R"), local = TRUE)

  cfg_ex4 <- cfg_profile$ex4
  screen_seeds <- as.integer(unlist(cfg_ex4$screen_seeds %||% (seed_value + 500L + seq_len(8L))))
  n_samp <- as.integer(cfg_ex4$n_samp %||% 200L)
  n_burn <- as.integer(cfg_ex4$n_burn)
  n_mcmc <- as.integer(cfg_ex4$n_mcmc)
  holdout_ratio_max <- as.numeric(cfg_ex4$screen_holdout_ratio_max %||% 1.25)
  active_ratio_max <- as.numeric(cfg_ex4$screen_active_ratio_max %||% 1.35)
  check_ratio_max <- as.numeric(cfg_ex4$screen_check_ratio_max %||% 1.05)

  if (length(screen_seeds) < 2L) {
    stop("Example 4 seed screen requires at least two candidate seeds.", call. = FALSE)
  }

  seed_results <- lapply(screen_seeds, function(dataset_seed) {
    cache_key <- sprintf(
      "ex4_seed_screen_seed_%d_ns%d_b%d_k%d_v2",
      as.integer(dataset_seed),
      n_samp,
      n_burn,
      n_mcmc
    )
    ex4_load_or_fit_cache_safe(
      cache_key,
      ex4_fit_seed(dataset_seed, cfg_ex4, stop_on_failure = FALSE),
      note = cache_key
    )
  })

  detail_rows <- do.call(
    rbind,
    lapply(seed_results, function(res) {
      if (!isTRUE(res$ok)) {
        return(
          data.frame(
            seed = res$seed,
            p0 = NA_real_,
            status = "error",
            error = res$error,
            ldvb_runtime_sec = NA_real_,
            mcmc_runtime_sec = NA_real_,
            runtime_ratio = NA_real_,
            ldvb_active_rmse = NA_real_,
            mcmc_active_rmse = NA_real_,
            active_ratio = NA_real_,
            ldvb_holdout_rmse = NA_real_,
            mcmc_holdout_rmse = NA_real_,
            holdout_ratio = NA_real_,
            ldvb_check_loss = NA_real_,
            mcmc_check_loss = NA_real_,
            check_ratio = NA_real_,
            ldvb_topk_support_ok = NA,
            ldvb_sign_support_ok = NA,
            mcmc_topk_support_ok = NA,
            mcmc_sign_support_ok = NA,
            stringsAsFactors = FALSE
          )
        )
      }

      do.call(
        rbind,
        lapply(names(res$fits), function(nm) {
          fit <- res$fits[[nm]]
          data.frame(
            seed = res$seed,
            p0 = fit$p0,
            status = "ok",
            error = "",
            ldvb_runtime_sec = fit$ldvb$runtime,
            mcmc_runtime_sec = fit$mcmc$runtime,
            runtime_ratio = fit$ldvb$runtime / fit$mcmc$runtime,
            ldvb_active_rmse = fit$ldvb$active_rmse,
            mcmc_active_rmse = fit$mcmc$active_rmse,
            active_ratio = fit$ldvb$active_rmse / fit$mcmc$active_rmse,
            ldvb_holdout_rmse = fit$ldvb$holdout_ref_rmse,
            mcmc_holdout_rmse = fit$mcmc$holdout_ref_rmse,
            holdout_ratio = fit$ldvb$holdout_ref_rmse / fit$mcmc$holdout_ref_rmse,
            ldvb_check_loss = fit$ldvb$holdout_check_loss,
            mcmc_check_loss = fit$mcmc$holdout_check_loss,
            check_ratio = fit$ldvb$holdout_check_loss / fit$mcmc$holdout_check_loss,
            ldvb_topk_support_ok = fit$ldvb$support$topk_support_ok,
            ldvb_sign_support_ok = fit$ldvb$support$sign_support_ok,
            mcmc_topk_support_ok = fit$mcmc$support$topk_support_ok,
            mcmc_sign_support_ok = fit$mcmc$support$sign_support_ok,
            stringsAsFactors = FALSE
          )
        })
      )
    })
  )

  seed_rows <- do.call(
    rbind,
    lapply(screen_seeds, function(dataset_seed) {
      seed_detail <- detail_rows[detail_rows$seed == dataset_seed, , drop = FALSE]
      if (!all(seed_detail$status == "ok")) {
        return(
          data.frame(
            seed = as.integer(dataset_seed),
            pass = FALSE,
            fail_reason = unique(seed_detail$error[seed_detail$status != "ok"])[1],
            mean_runtime_ratio = NA_real_,
            max_holdout_ratio = NA_real_,
            max_active_ratio = NA_real_,
            max_check_ratio = NA_real_,
            stringsAsFactors = FALSE
          )
        )
      }

      support_ok <- all(
        seed_detail$ldvb_topk_support_ok &
          seed_detail$ldvb_sign_support_ok &
          seed_detail$mcmc_topk_support_ok &
          seed_detail$mcmc_sign_support_ok
      )
      runtime_ok <- all(seed_detail$ldvb_runtime_sec < seed_detail$mcmc_runtime_sec)
      holdout_ok <- all(seed_detail$holdout_ratio <= holdout_ratio_max)
      active_ok <- all(seed_detail$active_ratio <= active_ratio_max)
      check_ok <- all(seed_detail$check_ratio <= check_ratio_max)

      fail_reason <- c()
      if (!support_ok) fail_reason <- c(fail_reason, "support")
      if (!runtime_ok) fail_reason <- c(fail_reason, "runtime")
      if (!holdout_ok) fail_reason <- c(fail_reason, "holdout")
      if (!active_ok) fail_reason <- c(fail_reason, "active")
      if (!check_ok) fail_reason <- c(fail_reason, "check")

      data.frame(
        seed = as.integer(dataset_seed),
        pass = length(fail_reason) == 0L,
        fail_reason = if (length(fail_reason) == 0L) "" else paste(fail_reason, collapse = ";"),
        mean_runtime_ratio = mean(seed_detail$runtime_ratio),
        max_holdout_ratio = max(seed_detail$holdout_ratio),
        max_active_ratio = max(seed_detail$active_ratio),
        max_check_ratio = max(seed_detail$check_ratio),
        stringsAsFactors = FALSE
      )
    })
  )

  passing_rows <- seed_rows[seed_rows$pass, , drop = FALSE]
  if (nrow(passing_rows) == 0L) {
    stop(
      sprintf(
        paste(
          "No Example 4 screening seed satisfied the current criteria.",
          "Checked %d seeds with thresholds holdout<=%.2f, active<=%.2f, check<=%.2f,",
          "plus support recovery and LDVB<MCMC runtime at every fitted p0."
        ),
        length(screen_seeds),
        holdout_ratio_max,
        active_ratio_max,
        check_ratio_max
      ),
      call. = FALSE
    )
  }

  passing_rows <- passing_rows[order(
    passing_rows$max_holdout_ratio,
    passing_rows$max_active_ratio,
    passing_rows$max_check_ratio,
    passing_rows$mean_runtime_ratio,
    passing_rows$seed
  ), , drop = FALSE]
  selected_seed <- as.integer(passing_rows$seed[[1L]])
  seed_rows$selected <- seed_rows$seed == selected_seed

  save_table_csv(
    detail_rows,
    filename = "ex4_seed_screen_summary.csv",
    artifact_id = "tab_ex4_seed_screen_summary",
    manuscript_target = "support: Example 4 seed screen metrics",
    status = "reproduced",
    notes = "Per-seed, per-quantile comparison of LDVB and MCMC for the Example 4 screening run."
  )

  save_table_csv(
    seed_rows,
    filename = "ex4_seed_screen_selection.csv",
    artifact_id = "tab_ex4_seed_screen_selection",
    manuscript_target = "support: Example 4 seed screen selection",
    status = "reproduced",
    notes = "Seed-level pass/fail summary for the Example 4 screening run."
  )

  capture_output_file("ex4_seed_screen_summary.txt", {
    cat(sprintf("profile=%s\n", selected_profile))
    cat(sprintf("candidate_seeds=%s\n", paste(screen_seeds, collapse = ", ")))
    cat(sprintf("n.samp=%d, n.burn=%d, n.mcmc=%d\n", n_samp, n_burn, n_mcmc))
    cat(sprintf(
      paste(
        "selection criteria:",
        "support recovery for both methods;",
        "LDVB runtime < MCMC runtime at each p0;",
        "holdout ratio <= %.2f;",
        "active ratio <= %.2f;",
        "check ratio <= %.2f.\n"
      ),
      holdout_ratio_max, active_ratio_max, check_ratio_max
    ))
    cat(sprintf("selected_seed=%d\n\n", selected_seed))
    print(seed_rows, row.names = FALSE)
  })

  register_artifact(
    artifact_id = "log_ex4_seed_screen_summary",
    artifact_type = "log",
    relative_path = "analysis/manuscript/outputs/logs/ex4_seed_screen_summary.txt",
    manuscript_target = "support: Example 4 seed screen summary",
    status = "reproduced",
    notes = "Selection criteria and final recommended seed for the Example 4 benchmark."
  )

  log_msg(sprintf("Example 4 seed screen: selected seed %d", selected_seed))
  log_msg("Example 4 seed screen: complete")
}
