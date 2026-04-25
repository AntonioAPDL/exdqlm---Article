# Reduced-6 CRPS Dense Relaunch

This note documents the remaining alternative Example 3 work after the main
manuscript relaunch. The goal is to regenerate the support-only reduced-6
monthly sandbox with the current CRAN-target package branch, without changing
the manuscript-facing Example 3.

## Scope

- Analysis directory:
  `analysis/ex3_monthly_nino34_redo`
- Config:
  `config_reduced6_crps_dense.yml`
- Output tag:
  `monthly_reduced6_crps_dense_p015_df099_iter200`
- Package branch:
  `cransub/0.4.0`
- Package worktree:
  `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile`
- Required package commit at relaunch:
  `ac245f1`

## Model Definition

- Response: monthly mean USGS flow built from the staged daily USGS file.
- Fit window: `1987-01-01` through `2021-04-01`.
- Response transform: `log`.
- Quantile: `p0 = 0.15`.
- Covariates: the reduced set `NOI`, `SOI`, `ESPI`, `PNA`, `WHWP`, and `AMO`
  from the monthly climate-index panel.
- Standardization: covariates are centered and scaled inside the workflow
  before fitting.
- Discounts: all trend, harmonic, covariate, and transfer blocks use `0.99`.
- LDVB budget: `tol = 0.02`, `n.samp = 500`, `max_iter = 200`.
- Transfer decay selection: select the best lambda by `CRPS`.
- Lambda grid: `0.01`, then `0.05` through `0.95` by `0.05`, plus `0.99`.

## Relaunch Command

Run from the article repository root:

```bash
bash analysis/ex3_monthly_nino34_redo/run_reduced6_crps_dense_background.sh
```

The launcher records the package branch and commit, starts the run with
`nohup`, and writes runtime logs under the ignored output tree:

```text
analysis/ex3_monthly_nino34_redo/outputs/monthly_reduced6_crps_dense_p015_df099_iter200/logs/
```

## Monitoring Command

```bash
bash analysis/ex3_monthly_nino34_redo/check_reduced6_crps_dense_status.sh
```

This reports whether the background process is still alive, tails the workflow
progress log, prints the launcher metadata, and shows the selected lambda once
the lambda-screen table exists.

## Completion Criteria

The relaunch is considered complete when the output tree contains:

- `tables/ex3_monthly_fit_summary.csv`
- `tables/ex3_monthly_lambda_screen.csv`
- `tables/ex3_monthly_fit_diagnostics.csv`
- `tables/ex3_monthly_ldvb_convergence.csv`
- `figures/ex3_monthly_convergence_elbo.png`
- `figures/ex3_monthly_convergence_sigma.png`
- `figures/ex3_monthly_convergence_gamma.png`
- `figures/ex3_monthly_fit_periods.png`
- `figures/ex3_monthly_direct_states_full_batch01.png`
- `figures/ex3_monthly_transfer_coefficients_full_batch01.png`
- `figures/ex3_monthly_transfer_zeta_full.png`
- `logs/ex3_monthly_manifest.md`

The manifest records the article snapshot, package snapshot, data hashes, model
settings, selected lambda, diagnostics, and generated files.

## Notes

The previous dense reduced-6 attempt was started from an older package snapshot
and stopped before figures, diagnostics, and manifest were produced. The current
relaunch is explicitly tied to `cransub/0.4.0` so that the alternative Example 3
support run matches the package branch used for the article and CRAN submission.
