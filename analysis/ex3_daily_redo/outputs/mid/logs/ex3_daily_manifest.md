# Example 3 Daily Redo Manifest

- config path: `/home/jaguir26/local/src/exdqlm---Article/analysis/ex3_daily_redo/config_mid.yml`
- output tag: `mid`
- article repo: `fda47b6`
- package repo: `668685f`
- staged data path: `/home/jaguir26/data/exdqlm_experiments/ex3_daily/big_trees_daily_usgs_ppt_soil.csv`
- staged data sha256: `1ee2854398a8ed93fb171fa04e2a81c824dc7ab933e37bb80068a25cdbc4a69a`
- fit window: `2017-01-01` to `2022-12-25` (2185 rows)
- forecast window: `2022-12-26` to `2023-01-24` (30 rows)
- response transform: `log_log1p`
- quantiles: `0.05, 0.5, 0.95`
- LDVB settings: tol=0.1, n.samp=80, max_iter=40, gam.init=0, sig.init=0.2
- transfer settings: lam=0.97, tf.df=0.9999999, 0.99999

## Output files

- figures: ex3_daily_data_overview.png, ex3_daily_fit_recent.png, ex3_daily_forecast_30d.png, ex3_daily_transfer_components_p05.png, ex3_daily_transfer_components_p50.png
- tables: ex3_daily_covariate_scaling.csv, ex3_daily_data_window_summary.csv, ex3_daily_fit_diagnostics.csv, ex3_daily_fit_summary.csv, ex3_daily_forecast_summary.csv

## Fit status snapshot

- p0=0.05 | direct_regression | status=ok | iter=40 | converged=FALSE | hit_iter_cap=TRUE | runtime=169.544 | median.kt=NA
- p0=0.05 | transfer_function | status=ok | iter=40 | converged=FALSE | hit_iter_cap=TRUE | runtime=185.465 | median.kt=50.57570
- p0=0.50 | direct_regression | status=ok | iter=40 | converged=FALSE | hit_iter_cap=TRUE | runtime=168.877 | median.kt=NA
- p0=0.50 | transfer_function | status=ok | iter=40 | converged=FALSE | hit_iter_cap=TRUE | runtime=183.686 | median.kt=53.32786
- p0=0.95 | direct_regression | status=ok | iter=40 | converged=FALSE | hit_iter_cap=TRUE | runtime=166.831 | median.kt=NA
- p0=0.95 | transfer_function | status=ok | iter=40 | converged=FALSE | hit_iter_cap=TRUE | runtime=181.068 | median.kt=57.70738

## Diagnostics snapshot

- p0=0.05 | direct_regression | KL=0.24758623 | CRPS=   1.435878 | pplc=   6340.870 | runtime=169.544
- p0=0.05 | transfer_function | KL=0.31702512 | CRPS=   1.469349 | pplc=   6478.962 | runtime=185.465
- p0=0.50 | direct_regression | KL=0.02281759 | CRPS=   8.589902 | pplc=  34415.019 | runtime=168.877
- p0=0.50 | transfer_function | KL=0.05019527 | CRPS=   9.368377 | pplc=  37583.101 | runtime=183.686
- p0=0.95 | direct_regression | KL=0.57451009 | CRPS=1818.870474 | pplc=6111241.774 | runtime=166.831
- p0=0.95 | transfer_function | KL=0.52629544 | CRPS=1485.746784 | pplc=4849315.636 | runtime=181.068

## Forecast snapshot

- p0=0.05 | direct_regression | mean_check_loss=0.02259341 | mean_abs_error=0.4518683
- p0=0.05 | transfer_function | mean_check_loss=0.03951295 | mean_abs_error=0.1815251
- p0=0.50 | direct_regression | mean_check_loss=0.16303820 | mean_abs_error=0.3260764
- p0=0.50 | transfer_function | mean_check_loss=0.10350631 | mean_abs_error=0.2070126
- p0=0.95 | direct_regression | mean_check_loss=0.10408954 | mean_abs_error=0.1342799
- p0=0.95 | transfer_function | mean_check_loss=0.04236261 | mean_abs_error=0.3226725
