# Example 3 Monthly Nino34 Contrast

This directory contains a separate, self-contained monthly contrast analysis
for Example 3. It is intentionally distinct from:

- the current manuscript-facing monthly Big Tree workflow under
  `analysis/manuscript/`
- the daily redesign prototype under `analysis/ex3_daily_redo/`

This track uses:

- the staged daily San Lorenzo / Big Trees CSV stored outside the repos
- monthly means aggregated from that daily flow series
- the package `nino34` dataset loaded from the `0.4.0` package checkout

It is designed to compare:

1. a direct dynamic quantile regression, and
2. a multivariate transfer-function exDQLM,

across all seven quantile levels, without a forecast stage.

## Data

The monthly response is built by averaging the daily `usgs_cfs` values within
each calendar month. The covariate series comes from the package `nino34`
dataset.

By default the workflow expects:

- daily CSV:
  `/home/jaguir26/data/exdqlm_experiments/ex3_daily/big_trees_daily_usgs_ppt_soil.csv`
- package checkout:
  `/home/jaguir26/local/src/exdqlm__wt__0p4p0_article_main`

The overlapping monthly window between the aggregated daily flow and package
`nino34` is:

- `1987-01-01` through `2021-04-01`

Because the prepared feature recipe includes 3 monthly lags, the effective
modeled window begins after the initial lag burn-in.

## Model setup

The prepared feature recipe uses:

- `nino34`
- `nino34_sq`
- `nino34_lag1`
- `nino34_lag2`
- `nino34_lag3`

The direct-regression model uses those 5 standardized features in `regMod(X)`.
The transfer-function model uses the same 5 standardized features in the
multivariate transfer wrapper from the `0.4.0` package branch.

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
  - trend `1.0`
  - harmonics `0.9`, `0.9`, `0.9`
  - covariate block `0.95`
- transfer settings:
  - `lam = 0.85`
  - `tf.df = c(0.95, 0.95)`

These are manuscript-consistent starting values for a monthly Nino34-based
contrast, and they can be changed later in the YAML configs if needed.

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
Rscript analysis/ex3_monthly_nino34_redo/run_all.R
```

Useful variants:

```bash
Rscript analysis/ex3_monthly_nino34_redo/run_all.R --targets prep,fit
Rscript analysis/ex3_monthly_nino34_redo/run_all.R --targets figures,manifest
Rscript analysis/ex3_monthly_nino34_redo/run_all.R --config analysis/ex3_monthly_nino34_redo/config_launchcheck.yml
Rscript analysis/ex3_monthly_nino34_redo/run_all.R --config analysis/ex3_monthly_nino34_redo/config_q7_full.yml
EX3_MONTHLY_DAILY_INPUT_PATH=/path/to/big_trees_daily_usgs_ppt_soil.csv \
  Rscript analysis/ex3_monthly_nino34_redo/run_all.R
EX3_MONTHLY_PKG_PATH=/path/to/exdqlm \
  Rscript analysis/ex3_monthly_nino34_redo/run_all.R
```

The default `config.yml` mirrors the launchcheck profile.

## Launchcheck vs full run

Two tracked configs are prepared:

- `config_launchcheck.yml`
  - same monthly overlap window
  - two quantiles
  - shallow LDVB budget
  - used to validate wiring cheaply
- `config_q7_full.yml`
  - same monthly overlap window
  - all seven quantiles
  - prepared full run settings

## Prepared launcher

When you are ready to launch the full 7-quantile monthly run, use:

```bash
bash analysis/ex3_monthly_nino34_redo/run_full_q7.sh
```

That helper is intentionally manual. It will:

- clear cached `.rds`, `.rda`, and `.RData` files under this workflow's output
  tree
- clear stale runtime files under the full-run output tag
- launch the run under `setsid`
- write a PID file, console log, and progress log

## Outputs

The workflow writes:

- a generated monthly merged dataset
- fit summaries
- convergence tables
- in-sample diagnostics tables
- review figures for the data, fit windows, state paths, and convergence traces
- a manifest summarizing the run
