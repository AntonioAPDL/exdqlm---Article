# Example 3 Daily Redo Manifest

- config path: `/home/jaguir26/local/src/exdqlm---Article/analysis/ex3_daily_redo/config_mid_stable.yml`
- output tag: `mid_stable`
- article repo snapshot at rerun: `6dd47cd`
- package repo snapshot at rerun: `668685f`
- staged data path: `/home/jaguir26/data/exdqlm_experiments/ex3_daily/big_trees_daily_usgs_ppt_soil.csv`
- staged data sha256: `1ee2854398a8ed93fb171fa04e2a81c824dc7ab933e37bb80068a25cdbc4a69a`
- fit window: `2017-01-01` to `2022-12-25` (2185 rows)
- forecast window: `2022-12-26` to `2023-01-24` (30 rows)
- response transform: `log_log1p`
- quantiles: `0.05, 0.5, 0.95`
- LDVB settings: tol=0.1, n.samp=100, max_iter=400, gam.init=0, sig.init=0.2
- transfer settings: lam=0.97, tf.df=0.9999999, 0.99999

## Output files

- figures: ex3_daily_data_overview.png, ex3_daily_fit_recent.png, ex3_daily_forecast_30d.png, ex3_daily_transfer_components_p05.png, ex3_daily_transfer_components_p50.png
- tables: ex3_daily_covariate_scaling.csv, ex3_daily_data_window_summary.csv, ex3_daily_fit_diagnostics.csv, ex3_daily_fit_summary.csv, ex3_daily_forecast_summary.csv, ex3_daily_ldvb_convergence.csv

## Fit status snapshot

- p0=0.05 | direct_regression | status=ok | iter=400 | converged=FALSE | hit_iter_cap=TRUE | runtime=1660.837 | median.kt=NA
- p0=0.05 | transfer_function | status=ok | iter=400 | converged=FALSE | hit_iter_cap=TRUE | runtime=1870.127 | median.kt=47.53547
- p0=0.50 | direct_regression | status=ok | iter=400 | converged=FALSE | hit_iter_cap=TRUE | runtime=1689.089 | median.kt=NA
- p0=0.50 | transfer_function | status=ok | iter=400 | converged=FALSE | hit_iter_cap=TRUE | runtime=1885.018 | median.kt=53.26515
- p0=0.95 | direct_regression | status=ok | iter=400 | converged=FALSE | hit_iter_cap=TRUE | runtime=1665.169 | median.kt=NA
- p0=0.95 | transfer_function | status=ok | iter=400 | converged=FALSE | hit_iter_cap=TRUE | runtime=1907.625 | median.kt=58.46990

## Diagnostics snapshot

- p0=0.05 | direct_regression | KL=0.21773341 | CRPS=   0.7478406 | pplc=    3353.257 | runtime=1660.837
- p0=0.05 | transfer_function | KL=0.34539974 | CRPS=   0.5842016 | pplc=    2618.802 | runtime=1870.127
- p0=0.50 | direct_regression | KL=0.03628635 | CRPS=   8.4780451 | pplc=   34209.275 | runtime=1689.089
- p0=0.50 | transfer_function | KL=0.04578689 | CRPS=   9.2766586 | pplc=   37346.935 | runtime=1885.018
- p0=0.95 | direct_regression | KL=0.63850480 | CRPS=4374.3395837 | pplc=15678055.466 | runtime=1665.169
- p0=0.95 | transfer_function | KL=0.40702836 | CRPS=2519.6816811 | pplc= 8673709.381 | runtime=1907.625

## Forecast snapshot

- p0=0.05 | direct_regression | mean_check_loss=0.02384933 | mean_abs_error=0.4769867
- p0=0.05 | transfer_function | mean_check_loss=0.02688746 | mean_abs_error=0.1935300
- p0=0.50 | direct_regression | mean_check_loss=0.16358913 | mean_abs_error=0.3271783
- p0=0.50 | transfer_function | mean_check_loss=0.10274327 | mean_abs_error=0.2054865
- p0=0.95 | direct_regression | mean_check_loss=0.08677115 | mean_abs_error=0.1203047
- p0=0.95 | transfer_function | mean_check_loss=0.04252356 | mean_abs_error=0.3300302
