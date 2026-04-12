# Example 3 Daily Redo Manifest

- config path: `/home/jaguir26/local/src/exdqlm---Article/analysis/ex3_daily_redo/config_smoke_stable_400.yml`
- output tag: `smoke_stable_400`
- article repo snapshot at rerun: `6dd47cd`
- package repo snapshot at rerun: `668685f`
- staged data path: `/home/jaguir26/data/exdqlm_experiments/ex3_daily/big_trees_daily_usgs_ppt_soil.csv`
- staged data sha256: `1ee2854398a8ed93fb171fa04e2a81c824dc7ab933e37bb80068a25cdbc4a69a`
- fit window: `2020-01-01` to `2022-12-25` (1090 rows)
- forecast window: `2022-12-26` to `2023-01-24` (30 rows)
- response transform: `log_log1p`
- quantiles: `0.05, 0.5`
- LDVB settings: tol=0.1, n.samp=80, max_iter=400, gam.init=0, sig.init=0.2
- transfer settings: lam=0.97, tf.df=0.9999999, 0.99999

## Output files

- figures: ex3_daily_data_overview.png, ex3_daily_fit_recent.png, ex3_daily_forecast_30d.png, ex3_daily_transfer_components_p05.png, ex3_daily_transfer_components_p50.png
- tables: ex3_daily_covariate_scaling.csv, ex3_daily_data_window_summary.csv, ex3_daily_fit_diagnostics.csv, ex3_daily_fit_summary.csv, ex3_daily_forecast_summary.csv, ex3_daily_ldvb_convergence.csv

## Fit status snapshot

- p0=0.05 | direct_regression | status=ok | iter=400 | converged=FALSE | hit_iter_cap=TRUE | runtime= 845.382 | median.kt=NA
- p0=0.05 | transfer_function | status=ok | iter=400 | converged=FALSE | hit_iter_cap=TRUE | runtime= 936.551 | median.kt=50.09151
- p0=0.50 | direct_regression | status=ok | iter=257 | converged=TRUE | hit_iter_cap=FALSE | runtime= 589.836 | median.kt=NA
- p0=0.50 | transfer_function | status=ok | iter=400 | converged=FALSE | hit_iter_cap=TRUE | runtime=1014.222 | median.kt=34.06448

## Diagnostics snapshot

- p0=0.05 | direct_regression | KL=0.22963214 | CRPS= 0.8761088 | pplc= 1923.261 | runtime= 845.382
- p0=0.05 | transfer_function | KL=0.34957895 | CRPS= 0.7924823 | pplc= 1738.158 | runtime= 936.551
- p0=0.50 | direct_regression | KL=0.05993617 | CRPS=12.7536201 | pplc=25487.354 | runtime= 589.836
- p0=0.50 | transfer_function | KL=0.08987894 | CRPS=10.6872402 | pplc=21249.200 | runtime=1014.222

## Forecast snapshot

- p0=0.05 | direct_regression | mean_check_loss=0.02116978 | mean_abs_error=0.4233957
- p0=0.05 | transfer_function | mean_check_loss=0.06963999 | mean_abs_error=0.2122720
- p0=0.50 | direct_regression | mean_check_loss=0.17862516 | mean_abs_error=0.3572503
- p0=0.50 | transfer_function | mean_check_loss=0.10915269 | mean_abs_error=0.2183054
