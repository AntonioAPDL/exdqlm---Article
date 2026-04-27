# Example 3 Monthly Output-Lag Contrast

This directory contains a separate, self-contained monthly contrast analysis
for Example 3. It is intentionally distinct from:

- the manuscript-facing monthly Big Tree workflow under `analysis/manuscript/`
- the monthly Nino34 contrast under `analysis/support/ex3_monthly_nino34_redo/`
- the daily redesign prototype under `analysis/support/ex3_daily_redo/`

This track uses:

- the staged daily San Lorenzo / Big Trees CSV stored outside the repos
- monthly means aggregated from that daily flow series
- autoregressive monthly flow features built from the response itself

It is designed to compare:

1. a direct dynamic quantile regression, and
2. a multivariate transfer-function exDQLM,

across all seven quantile levels, without a forecast stage.

## Data

The monthly response is built by averaging the daily `usgs_cfs` values within
each calendar month. Because this workflow no longer uses `nino34`, the full
available monthly window from the staged daily data can be used.

By default the workflow expects:

- daily CSV:
  `/home/jaguir26/data/exdqlm_experiments/ex3_daily/big_trees_daily_usgs_ppt_soil.csv`
- package checkout:
  `/home/jaguir26/local/src/exdqlm__wt__0p4p0_article_main`

The aggregated monthly flow currently spans:

- `1987-01-01` through `2026-03-01`

Because the prepared feature recipe includes 6 monthly lags, the effective
modeled window begins after the initial lag burn-in.

For validation only, the workflow still compares the aggregated monthly flow
against the package `BTflow` series over their shared overlap.

## Model setup

The prepared feature recipe uses only lagged output terms:

- `flow_lag1` through `flow_lag6`
- `flow_sq_lag1` through `flow_sq_lag6`

That gives:

- `12` standardized features in the direct-regression model
- `1` transfer state `zeta_t` plus `12` transfer coefficient states in the
  transfer-function model

The prepared full run currently uses:

- quantiles:
  `0.05, 0.20, 0.35, 0.50, 0.65, 0.80, 0.95`
- trend order:
  `1`
- seasonal period:
  `12`
- seasonal harmonics:
  `1`, `2`, `0.1469118636`
- direct discounts:
  - trend `0.95`
  - harmonics `0.95`, `0.95`, `0.95`
  - covariate block `0.95`
- transfer settings:
  - `lam = 0.85`
  - `tf.df = c(0.95, 0.95)`
- LDVB settings:
  - `tol = 0.10`
  - `n.samp = 1000`
  - `max_iter = 300`
  - `gam.init = 0`
  - `sig.init = 0.10`

The seasonal harmonics are chosen to match the daily redesign's annualized
structure after changing the time base from daily to monthly:

- `h = 1` gives a 12-month cycle
- `h = 2` gives a 6-month cycle
- `h = 0.1469118636` gives an `12 / 0.1469118636 ≈ 81.68` month cycle,
  or about `6.81` years

Because `seasMod()` parameterizes each harmonic through `w = h * 2 * pi / p`,
keeping the same `h` values while changing `p` from an annual daily period to
an annual monthly period preserves the same cycles-per-year interpretation.

## Run

From the article repository root:

```bash
Rscript analysis/support/ex3_monthly_outputlag_redo/run_all.R
```

Useful variants:

```bash
Rscript analysis/support/ex3_monthly_outputlag_redo/run_all.R --targets prep,fit
Rscript analysis/support/ex3_monthly_outputlag_redo/run_all.R --targets figures,manifest
Rscript analysis/support/ex3_monthly_outputlag_redo/run_all.R --config analysis/support/ex3_monthly_outputlag_redo/config_launchcheck.yml
Rscript analysis/support/ex3_monthly_outputlag_redo/run_all.R --config analysis/support/ex3_monthly_outputlag_redo/config_q7_full.yml
EX3_MONTHLY_DAILY_INPUT_PATH=/path/to/big_trees_daily_usgs_ppt_soil.csv \
  Rscript analysis/support/ex3_monthly_outputlag_redo/run_all.R
EX3_MONTHLY_PKG_PATH=/path/to/exdqlm \
  Rscript analysis/support/ex3_monthly_outputlag_redo/run_all.R
```

The default `config.yml` mirrors the launchcheck profile.

## Launchcheck vs full run

Two tracked configs are prepared:

- `config_launchcheck.yml`
  - full monthly flow window
  - two quantiles
  - shallow LDVB budget
  - used to validate wiring cheaply
- `config_q7_full.yml`
  - full monthly flow window
  - all seven quantiles
  - prepared full run settings

## Prepared launcher

When you are ready to launch the full 7-quantile monthly run, use:

```bash
bash analysis/support/ex3_monthly_outputlag_redo/run_full_q7.sh
```

That helper is intentionally manual. It will:

- clear cached `.rds`, `.rda`, and `.RData` files under this workflow's output
  tree
- clear stale runtime files under the full-run output tag
- launch the run under `nohup` from a login shell
- write a PID file, console log, and progress log

The workflow also validates `gam.init` against the full requested quantile grid
before any workers are launched, so incompatible starts fail fast at startup.

## Outputs

The workflow writes:

- a generated monthly modeling dataset
- fit summaries
- convergence tables
- in-sample diagnostics tables
- review figures for the data, fit windows, regression / transfer state paths,
  structural component paths, and convergence traces
- a manifest summarizing the run

The structural component figures are built from the cached posterior state draws,
not from a Gaussian approximation. For each model family and review window, the
workflow decomposes the latent structural block into:

- `1` trend contribution
- `3` seasonal contributions matching the configured harmonics

and then summarizes each component with empirical `2.5%`, `50%`, and `97.5%`
posterior behavior through the plotted mean and `95%` credible band.
