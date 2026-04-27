need_ex4screen <- target_enabled("ex4screen")
if (!need_ex4screen) {
  log_msg("Example 4 seed screen: skipped (target filter)")
} else {
  log_msg("Example 4 seed screen: start")

  source(file.path(repo_root, "analysis", "manuscript", "examples", "ex4_static", "helpers.R"), local = TRUE)

  cfg_ex4 <- cfg_profile$ex4
  target_p0 <- ex4_screen_target_p0(cfg_ex4)
  target_key <- ex4_p_key(target_p0)
  n_samp <- as.integer(cfg_ex4$n_samp %||% 200L)
  n_burn <- as.integer(cfg_ex4$n_burn)
  n_mcmc <- as.integer(cfg_ex4$n_mcmc)
  screen_stem <- ex4_screen_file_stem(cfg_ex4)
  screen_batches <- ex4_screen_candidate_batches(cfg_ex4, seed_value)

  evaluate_seed <- function(dataset_seed) {
    cache_key <- ex4_seed_screen_cache_key(dataset_seed, cfg_ex4)
    ex4_load_or_fit_cache_safe(
      cache_key,
      ex4_fit_seed(dataset_seed, cfg_ex4, stop_on_failure = FALSE),
      note = cache_key
    )
  }

  build_detail_rows <- function(seed_results) {
    do.call(
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
              ldvb_truth_cover_n = NA_integer_,
              ldvb_truth_cover_total = NA_integer_,
              ldvb_truth_cover_all = NA,
              mcmc_truth_cover_n = NA_integer_,
              mcmc_truth_cover_total = NA_integer_,
              mcmc_truth_cover_all = NA,
              stringsAsFactors = FALSE
            )
          )
        }

        do.call(
          rbind,
          lapply(names(res$fits), function(nm) {
            fit <- res$fits[[nm]]
            ldvb_cov <- ex4_resolve_slope_coverage(fit$ldvb, res$beta_slopes)
            mcmc_cov <- ex4_resolve_slope_coverage(fit$mcmc, res$beta_slopes)
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
              ldvb_truth_cover_n = ldvb_cov$n_contains,
              ldvb_truth_cover_total = ldvb_cov$n_total,
              ldvb_truth_cover_all = ldvb_cov$all_contains,
              mcmc_truth_cover_n = mcmc_cov$n_contains,
              mcmc_truth_cover_total = mcmc_cov$n_total,
              mcmc_truth_cover_all = mcmc_cov$all_contains,
              stringsAsFactors = FALSE
            )
          })
        )
      })
    )
  }

  build_seed_rows <- function(detail_rows) {
    seeds <- sort(unique(detail_rows$seed))
    do.call(
      rbind,
      lapply(seeds, function(dataset_seed) {
        seed_detail <- detail_rows[detail_rows$seed == dataset_seed, , drop = FALSE]
        if (!all(seed_detail$status == "ok")) {
          return(
            data.frame(
              seed = as.integer(dataset_seed),
              pass = FALSE,
              fail_reason = unique(seed_detail$error[seed_detail$status != "ok"])[1],
              target_p0 = target_p0,
              target_mcmc_truth_cover_n = NA_integer_,
              target_mcmc_truth_cover_total = NA_integer_,
              target_mcmc_truth_cover_all = NA,
              target_mcmc_active_rmse = NA_real_,
              target_mcmc_holdout_rmse = NA_real_,
              target_mcmc_runtime_sec = NA_real_,
              target_mcmc_topk_support_ok = NA,
              target_mcmc_sign_support_ok = NA,
              stringsAsFactors = FALSE
            )
          )
        }

        target_detail <- seed_detail[abs(seed_detail$p0 - target_p0) < 1e-8, , drop = FALSE]
        if (nrow(target_detail) != 1L) {
          return(
            data.frame(
              seed = as.integer(dataset_seed),
              pass = FALSE,
              fail_reason = sprintf("missing_target_p0_%0.2f", target_p0),
              target_p0 = target_p0,
              target_mcmc_truth_cover_n = NA_integer_,
              target_mcmc_truth_cover_total = NA_integer_,
              target_mcmc_truth_cover_all = NA,
              target_mcmc_active_rmse = NA_real_,
              target_mcmc_holdout_rmse = NA_real_,
              target_mcmc_runtime_sec = NA_real_,
              target_mcmc_topk_support_ok = NA,
              target_mcmc_sign_support_ok = NA,
              stringsAsFactors = FALSE
            )
          )
        }

        cover_ok <- isTRUE(target_detail$mcmc_truth_cover_all[[1L]])
        data.frame(
          seed = as.integer(dataset_seed),
          pass = cover_ok,
          fail_reason = if (cover_ok) "" else sprintf(
            "mcmc_truth_coverage_%d_of_%d_at_p0_%0.2f",
            as.integer(target_detail$mcmc_truth_cover_n[[1L]]),
            as.integer(target_detail$mcmc_truth_cover_total[[1L]]),
            target_p0
          ),
          target_p0 = target_p0,
          target_mcmc_truth_cover_n = as.integer(target_detail$mcmc_truth_cover_n[[1L]]),
          target_mcmc_truth_cover_total = as.integer(target_detail$mcmc_truth_cover_total[[1L]]),
          target_mcmc_truth_cover_all = as.logical(target_detail$mcmc_truth_cover_all[[1L]]),
          target_mcmc_active_rmse = as.numeric(target_detail$mcmc_active_rmse[[1L]]),
          target_mcmc_holdout_rmse = as.numeric(target_detail$mcmc_holdout_rmse[[1L]]),
          target_mcmc_runtime_sec = as.numeric(target_detail$mcmc_runtime_sec[[1L]]),
          target_mcmc_topk_support_ok = as.logical(target_detail$mcmc_topk_support_ok[[1L]]),
          target_mcmc_sign_support_ok = as.logical(target_detail$mcmc_sign_support_ok[[1L]]),
          stringsAsFactors = FALSE
        )
      })
    )
  }

  select_passing_seed <- function(seed_rows) {
    passing_rows <- seed_rows[seed_rows$pass, , drop = FALSE]
    if (nrow(passing_rows) == 0L) {
      return(NULL)
    }
    passing_rows <- passing_rows[order(
      passing_rows$target_mcmc_active_rmse,
      passing_rows$target_mcmc_holdout_rmse,
      passing_rows$target_mcmc_runtime_sec,
      passing_rows$seed
    ), , drop = FALSE]
    as.integer(passing_rows$seed[[1L]])
  }

  seed_results <- list()
  selected_seed <- NA_integer_
  evaluated_batches <- 0L

  for (batch_idx in seq_along(screen_batches)) {
    batch_seeds <- as.integer(screen_batches[[batch_idx]])
    batch_results <- lapply(batch_seeds, evaluate_seed)
    names(batch_results) <- as.character(batch_seeds)
    seed_results <- c(seed_results, batch_results)
    evaluated_batches <- batch_idx

    detail_rows <- build_detail_rows(seed_results)
    seed_rows <- build_seed_rows(detail_rows)
    selected_seed <- select_passing_seed(seed_rows)
    if (!is.na(selected_seed)) break
  }

  detail_rows <- build_detail_rows(seed_results)
  seed_rows <- build_seed_rows(detail_rows)

  if (is.na(selected_seed)) {
    best_partial <- seed_rows[order(
      -seed_rows$target_mcmc_truth_cover_n,
      seed_rows$target_mcmc_active_rmse,
      seed_rows$target_mcmc_holdout_rmse,
      seed_rows$seed
    ), , drop = FALSE]
    stop(
      sprintf(
        paste(
          "No Example 4 seed satisfied the p0=%0.2f MCMC full-coverage criterion.",
          "Evaluated %d seed(s) across %d batch(es).",
          "Best observed coverage was %d/%d at seed %d."
        ),
        target_p0,
        nrow(seed_rows),
        evaluated_batches,
        as.integer(best_partial$target_mcmc_truth_cover_n[[1L]]),
        as.integer(best_partial$target_mcmc_truth_cover_total[[1L]]),
        as.integer(best_partial$seed[[1L]])
      ),
      call. = FALSE
    )
  }

  seed_rows$selected <- seed_rows$seed == selected_seed

  save_table_csv(
    detail_rows,
    filename = sprintf("%s_summary.csv", screen_stem),
    artifact_id = sprintf("tab_%s_summary", screen_stem),
    manuscript_target = "support: Example 4 seed screen metrics",
    status = "reproduced",
    notes = sprintf(
      "Per-seed, per-quantile comparison of the Example 4 static fits. Seed selection targets p0 = %0.2f and requires full MCMC 95%% slope-interval coverage.",
      target_p0
    )
  )

  save_table_csv(
    seed_rows,
    filename = sprintf("%s_selection.csv", screen_stem),
    artifact_id = sprintf("tab_%s_selection", screen_stem),
    manuscript_target = "support: Example 4 seed screen selection",
    status = "reproduced",
    notes = sprintf(
      "Seed-level selection summary for the Example 4 screen. The selected seed is the first full-coverage p0 = %0.2f candidate after sorting by MCMC active RMSE, holdout RMSE, runtime, and seed.",
      target_p0
    )
  )

  capture_output_file(sprintf("%s_summary.txt", screen_stem), {
    evaluated_seeds <- sort(unique(vapply(seed_results, function(x) x$seed, integer(1))))
    cat(sprintf("profile=%s\n", selected_profile))
    cat(sprintf("target_p0=%0.2f\n", target_p0))
    cat(sprintf("candidate_batches=%s\n", paste(
      vapply(screen_batches, function(x) paste(x, collapse = ","), character(1)),
      collapse = " | "
    )))
    cat(sprintf("evaluated_seeds=%s\n", paste(evaluated_seeds, collapse = ", ")))
    cat(sprintf("n.samp=%d, n.burn=%d, n.mcmc=%d\n", n_samp, n_burn, n_mcmc))
    cat(sprintf(
      paste(
        "selection criteria:",
        "all Example 4 fits must run successfully;",
        "the selected seed must have MCMC 95%% intervals covering all plotted slope coefficients at p0 = %0.2f;",
        "ties are broken by smaller target-p0 MCMC active RMSE, then smaller holdout RMSE, then smaller runtime, then seed.\n"
      ),
      target_p0
    ))
    cat(sprintf("selected_seed=%d\n\n", selected_seed))
    print(seed_rows, row.names = FALSE)
  })

  register_artifact(
    artifact_id = sprintf("log_%s_summary", screen_stem),
    artifact_type = "log",
    relative_path = sprintf("analysis/manuscript/outputs/logs/%s_summary.txt", screen_stem),
    manuscript_target = "support: Example 4 seed screen summary",
    status = "reproduced",
    notes = sprintf(
      "Selection criteria and chosen Example 4 dataset seed based on the p0 = %0.2f MCMC coverage screen.",
      target_p0
    )
  )

  log_msg(sprintf("Example 4 seed screen: selected seed %d for p0=%0.2f", selected_seed, target_p0))
  log_msg("Example 4 seed screen: complete")
}
