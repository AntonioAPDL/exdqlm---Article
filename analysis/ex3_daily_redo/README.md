# Example 3 Daily Redo Prototype

This directory contains an experimental, self-contained redesign of Example 3
using the daily Big Trees / San Lorenzo dataset staged outside the repository.

This workflow is intentionally separate from the tracked manuscript stage:

- it does not modify `article4.tex`
- it does not replace the current monthly Big Trees example
- it is used to prototype the daily redesign and inspect figures, tables, and
  fit objects before deciding whether the manuscript should change

## Data

By default the workflow expects the staged CSV at:

`/home/jaguir26/data/exdqlm_experiments/ex3_daily/big_trees_daily_usgs_ppt_soil.csv`

Override that path with:

```bash
EX3_DAILY_DATA_PATH=/path/to/big_trees_daily_usgs_ppt_soil.csv \
Rscript analysis/ex3_daily_redo/run_all.R
```

The current default file has:

- `date`
- `usgs_cfs`
- `ppt_mm`
- `soil_moisture`

with daily coverage from `1987-01-01` through `2026-03-31`.

## Model scope

The prototype fits, for each quantile level,

1. a no-transfer dynamic quantile regression using `regMod(X)`, and
2. a transfer-function dynamic quantile model using the multivariate
   `transfn_exdqlmLDVB()` wrapper.

The current config is intentionally a **wiring-first prototype**:

- fit window starts in `2020-01-01` rather than in 1987
- quantiles are limited to `0.05` and `0.50`
- LDVB is run with a capped iteration budget (`max_iter = 25`, `n.samp = 60`)
- parallel launches are capped at `2` workers

This keeps the first launches fast enough to validate the data path, the
multivariate transfer wrapper, and the forecast wiring before moving to the
full seven-quantile / long-history run. Once the workflow is behaving well,
the config can be widened back out to the longer 2010-to-2022 window or the
full 1987-to-2022 history.

Three tracked config tiers are available:

- `config_smoke.yml`
  - shortest validation run
  - outputs written to `outputs/smoke/`
- `config_mid.yml`
  - widened validation run with 3 quantiles
  - outputs written to `outputs/mid/`
- `config_long.yml`
  - longer validation config for the 2010-to-2022 window
  - outputs written to `outputs/long/`

Additional stabilization configs are available for the short and mid windows:

- `config_smoke_stable.yml`
  - same short validation window as smoke
  - completed short-window stabilization pass with `max_iter = 300`
  - outputs written to `outputs/smoke_stable/`
- `config_smoke_stable_400.yml`
  - deeper short-window follow-up stabilization pass
  - outputs written to `outputs/smoke_stable_400/`
- `config_mid_stable.yml`
  - same widened validation window as mid
  - first serious widened-window stabilization pass
  - outputs written to `outputs/mid_stable/`
- `config_long_nightly_1000.yml`
  - dedicated overnight long-window run
  - keeps the 2010-to-2022 window and the three-quantile grid
  - raises the LDVB budget to `max_iter = 1000`
  - outputs written to `outputs/long_nightly_1000/`

The default `config.yml` currently mirrors the smoke profile.

Both models share:

- transformed response `log(log(usgs_cfs + 1))`
- trend `polytrendMod(1)`
- seasonal structure `seasMod(p = 363.5854, h = c(1, 2, 0.1469118636))`
- the 5 standardized covariates:
  - `ppt`
  - `soil`
  - `ppt_soil`
  - `ppt2`
  - `soil2`

The current prototype uses the full exAL / exDQLM path only. It does not
include a separate `dqlm.ind = TRUE` sweep yet.

## Run

From the article repository root:

```bash
Rscript analysis/ex3_daily_redo/run_all.R
```

Useful variants:

```bash
Rscript analysis/ex3_daily_redo/run_all.R --targets prep,fit
Rscript analysis/ex3_daily_redo/run_all.R --targets forecast,figures,manifest
Rscript analysis/ex3_daily_redo/run_all.R --config analysis/ex3_daily_redo/config_smoke.yml
Rscript analysis/ex3_daily_redo/run_all.R --config analysis/ex3_daily_redo/config_mid.yml
Rscript analysis/ex3_daily_redo/run_all.R --config analysis/ex3_daily_redo/config_smoke_stable.yml
Rscript analysis/ex3_daily_redo/run_all.R --config analysis/ex3_daily_redo/config_smoke_stable_400.yml
Rscript analysis/ex3_daily_redo/run_all.R --config analysis/ex3_daily_redo/config_mid_stable.yml
Rscript analysis/ex3_daily_redo/run_all.R --config analysis/ex3_daily_redo/config_long_nightly_1000.yml
./analysis/ex3_daily_redo/run_long_nightly.sh
Rscript analysis/ex3_daily_redo/run_all.R --config /path/to/config.yml
EX3_DAILY_PKG_PATH=/path/to/exdqlm Rscript analysis/ex3_daily_redo/run_all.R
EX3_DAILY_DATA_PATH=/path/to/big_trees_daily_usgs_ppt_soil.csv \
  Rscript analysis/ex3_daily_redo/run_all.R
EX3_DAILY_CONFIG_PATH=/path/to/config.yml \
  Rscript analysis/ex3_daily_redo/run_all.R
```

By default the workflow loads package source from:

`/home/jaguir26/local/src/exdqlm__wt__0p4p0_article_main`

Override that with `EX3_DAILY_PKG_PATH=/path/to/exdqlm`.

## Outputs

- `outputs/<profile>/figures/`
  - `ex3_daily_data_overview.png`
  - `ex3_daily_fit_recent.png`
  - `ex3_daily_forecast_30d.png`
  - `ex3_daily_transfer_components_p05.png`
  - `ex3_daily_transfer_components_p50.png`
- `outputs/<profile>/tables/`
  - `ex3_daily_data_window_summary.csv`
  - `ex3_daily_covariate_scaling.csv`
  - `ex3_daily_fit_summary.csv`
  - `ex3_daily_ldvb_convergence.csv`
  - `ex3_daily_fit_diagnostics.csv`
  - `ex3_daily_forecast_summary.csv`
- `outputs/<profile>/logs/`
  - `ex3_daily_manifest.md`
  - `ex3_daily_fit_notes.txt`
- `outputs/<profile>/cache/`
  - cached `.rds` objects used to speed up repeated tuning runs

Each profile keeps its own cache directory, and those cache directories are
intentionally ignored by git.

For the overnight long-window run, the helper launcher writes:

- a PID file to `outputs/long_nightly_1000/logs/long_nightly_1000.pid`
- a timestamped console log to `outputs/long_nightly_1000/logs/console_<timestamp>.log`

so the background run can be checked without reopening the workflow manually.
