# Example 3 Monthly Specification Sandbox

This directory is a small monthly experimentation sandbox for Example 3. It is
deliberately separate from the manuscript-facing workflow under
`analysis/manuscript/`, so we can try alternative monthly covariate
specifications without overwriting the paper each time.

The design goal is simple:

- keep the response and model structure close to the current paper Example 3
- use the monthly USGS flow series built by averaging the staged daily flow
  data within each calendar month
- swap only the monthly covariate specification and a few tuning settings
- generate diagnostics, convergence traces, and coefficient-path plots that are
  useful for screening before deciding whether to change the manuscript

## Two intended modes

The sandbox now supports two explicit monthly modes.

1. Paper-like `nino34`
   - monthly mean USGS flow from the staged daily file
   - package `nino34` as the covariate
   - same direct-regression versus transfer-function contrast used in the paper

2. Monthly all-index alternative
   - the same monthly USGS response
   - the 17 monthly climate indices from
     `/home/jaguir26/muscat_data_backup/jaguir26/project1_ucsc_phd/climate_indices/combined_indices.csv`
   - covariates standardized inside the workflow before fitting
   - the same Example 3 logic: one direct model, one transfer-function model,
     lambda screening, and diagnostic/plot review

## Data

The default staged daily input is:

- `/home/jaguir26/data/exdqlm_experiments/ex3_daily/big_trees_daily_usgs_ppt_soil.csv`

The monthly response is always built by averaging daily `usgs_cfs` values
within each calendar month.

By default, the fit window is:

- `1987-01-01` through `2021-04-01`

That is the overlap used in the current monthly USGS plus `nino34` Example 3
setup.

## Configs

Tracked configs:

- [config.yml](/home/jaguir26/local/src/exdqlm---Article/analysis/ex3_monthly_nino34_redo/config.yml)
  - default paper-like launchcheck
  - `p0 = 0.15`
  - `nino34`, no lagged covariates
- [config_launchcheck.yml](/home/jaguir26/local/src/exdqlm---Article/analysis/ex3_monthly_nino34_redo/config_launchcheck.yml)
  - explicit copy of the default paper-like launchcheck
- [config_q7_full.yml](/home/jaguir26/local/src/exdqlm---Article/analysis/ex3_monthly_nino34_redo/config_q7_full.yml)
  - paper-like q7 run
- [config_allidx_launchcheck.yml](/home/jaguir26/local/src/exdqlm---Article/analysis/ex3_monthly_nino34_redo/config_allidx_launchcheck.yml)
  - monthly all-index launchcheck
  - one quantile at `0.15`
  - all 17 monthly indices at once
  - no lags, transforms, or interactions
  - all discount factors set to `0.99`
- [config_allidx_intermediate.yml](/home/jaguir26/local/src/exdqlm---Article/analysis/ex3_monthly_nino34_redo/config_allidx_intermediate.yml)
  - the first serious screening run
  - same all-index monthly structure as above
  - deeper VB budget: `tol = 0.05`, `n.samp = 300`, `max_iter = 50`
- [config_allidx_fullconv.yml](/home/jaguir26/local/src/exdqlm---Article/analysis/ex3_monthly_nino34_redo/config_allidx_fullconv.yml)
  - pruning-grade all-index screening run
  - same all-index monthly structure as above
  - large VB budget intended for convergence-sensitive pruning:
    `tol = 0.02`, `n.samp = 500`, `max_iter = 300`
- [config_reduced6_refined.yml](/home/jaguir26/local/src/exdqlm---Article/analysis/ex3_monthly_nino34_redo/config_reduced6_refined.yml)
  - reduced 6-index rerun after full-model screening
  - uses `NOI`, `SOI`, `ESPI`, `PNA`, `WHWP`, and `AMO`
  - keeps the same monthly Example 3 structure
  - refined transfer-decay grid around the previously selected `lambda = 0.30`
  - `tol = 0.02`, `n.samp = 500`, `max_iter = 200`
- [config_reduced6_crps_dense.yml](/home/jaguir26/local/src/exdqlm---Article/analysis/ex3_monthly_nino34_redo/config_reduced6_crps_dense.yml)
  - reduced 6-index rerun using the same covariate set
  - selects the transfer decay by `CRPS`, not `KL`
  - dense lambda grid from `0.01` through `0.99`
  - `tol = 0.02`, `n.samp = 500`, `max_iter = 200`

## Current API

The intended interface remains the existing one:

```bash
Rscript analysis/ex3_monthly_nino34_redo/run_all.R
```

Useful variants:

```bash
Rscript analysis/ex3_monthly_nino34_redo/run_all.R --targets prep,fit
Rscript analysis/ex3_monthly_nino34_redo/run_all.R --targets figures,manifest
Rscript analysis/ex3_monthly_nino34_redo/run_all.R --config analysis/ex3_monthly_nino34_redo/config_launchcheck.yml
Rscript analysis/ex3_monthly_nino34_redo/run_all.R --config analysis/ex3_monthly_nino34_redo/config_q7_full.yml
Rscript analysis/ex3_monthly_nino34_redo/run_all.R --config analysis/ex3_monthly_nino34_redo/config_allidx_launchcheck.yml
Rscript analysis/ex3_monthly_nino34_redo/run_all.R --config analysis/ex3_monthly_nino34_redo/config_allidx_intermediate.yml
Rscript analysis/ex3_monthly_nino34_redo/run_all.R --config analysis/ex3_monthly_nino34_redo/config_reduced6_crps_dense.yml
```

The q7 launcher remains available for the paper-like profile:

```bash
bash analysis/ex3_monthly_nino34_redo/run_full_q7.sh
```

## Outputs

Each config writes its own output tree under `outputs/<output_tag>/`, including:

- a merged monthly modeling dataset
- covariate mapping and scaling tables
- fit summaries and diagnostics
- lambda-screen summaries
- LDVB convergence tables and ELBO / sigma / gamma traces
- selected-window fitted-quantile plots
- forecast comparison plots
- selected-window state plots
- full-window coefficient-path plots
- simple full-window screening tables
- a manifest summarizing the run

The root `outputs/` folder is ignored by git so we can regenerate these freely
without cluttering repo status.

## Intended workflow

The practical order is:

1. run the paper-like launchcheck to confirm the baseline monthly sandbox
2. run the all-index launchcheck to confirm the 17-index monthly wiring
3. run the all-index intermediate spec for a faster first look
4. run the all-index full-convergence spec before any pruning decision
5. inspect the full-window coefficient paths and screening tables
6. prune to smaller index subsets before trying anything more complicated

That keeps the sandbox close to the current paper Example 3 while still making
room for careful monthly covariate experiments.
