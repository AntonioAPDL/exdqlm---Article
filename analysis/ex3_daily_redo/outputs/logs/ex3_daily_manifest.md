# Example 3 Daily Redo Manifest

- article repo: `8e65111`
- package repo: `668685f`
- staged data path: `/home/jaguir26/data/exdqlm_experiments/ex3_daily/big_trees_daily_usgs_ppt_soil.csv`
- staged data sha256: `1ee2854398a8ed93fb171fa04e2a81c824dc7ab933e37bb80068a25cdbc4a69a`
- fit window: `2020-01-01` to `2022-12-25` (1090 rows)
- forecast window: `2022-12-26` to `2023-01-24` (30 rows)
- response transform: `log_log1p`
- quantiles: `0.05, 0.5`
- LDVB settings: tol=0.1, n.samp=60, gam.init=0, sig.init=0.2
- transfer settings: lam=0.97, tf.df=0.9999999, 0.99999

## Output files

- figures: ex3_daily_data_overview.png, ex3_daily_fit_recent.png, ex3_daily_forecast_30d.png, ex3_daily_transfer_components_p05.png, ex3_daily_transfer_components_p50.png
- tables: ex3_daily_covariate_scaling.csv, ex3_daily_data_window_summary.csv, ex3_daily_fit_diagnostics.csv, ex3_daily_fit_summary.csv, ex3_daily_forecast_summary.csv

## Fit status snapshot

- p0=0.05 | direct_regression | status=ok | runtime=56.535 | median.kt=NA
- p0=0.05 | transfer_function | status=ok | runtime=61.447 | median.kt=45.33101
- p0=0.50 | direct_regression | status=ok | runtime=53.704 | median.kt=NA
- p0=0.50 | transfer_function | status=ok | runtime=60.236 | median.kt=34.67451

## Diagnostics snapshot

- p0=0.05 | direct_regression | KL=0.72155469 | CRPS= 1.973548 | pplc= 4307.832 | runtime=56.535
- p0=0.05 | transfer_function | KL=0.86303942 | CRPS= 1.896041 | pplc= 4142.036 | runtime=61.447
- p0=0.50 | direct_regression | KL=0.05502216 | CRPS=11.817926 | pplc=23322.652 | runtime=53.704
- p0=0.50 | transfer_function | KL=0.12937493 | CRPS=10.300445 | pplc=20340.099 | runtime=60.236

## Forecast snapshot

- p0=0.05 | direct_regression | mean_check_loss=0.02173926 | mean_abs_error=0.4347852
- p0=0.05 | transfer_function | mean_check_loss=0.09004635 | mean_abs_error=0.2217388
- p0=0.50 | direct_regression | mean_check_loss=0.16977669 | mean_abs_error=0.3395534
- p0=0.50 | transfer_function | mean_check_loss=0.11093125 | mean_abs_error=0.2218625
