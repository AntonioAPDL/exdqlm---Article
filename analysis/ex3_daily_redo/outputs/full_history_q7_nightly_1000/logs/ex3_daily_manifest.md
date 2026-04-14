# Example 3 Daily Redo Manifest

- config path: `/home/jaguir26/local/src/exdqlm---Article/analysis/ex3_daily_redo/config_full_history_q7_nightly_1000.yml`
- output tag: `full_history_q7_nightly_1000`
- article repo snapshot at rerun: `5fc7f0a`
- package repo snapshot at rerun: `668685f`
- staged data path: `/home/jaguir26/data/exdqlm_experiments/ex3_daily/big_trees_daily_usgs_ppt_soil.csv`
- staged data sha256: `1ee2854398a8ed93fb171fa04e2a81c824dc7ab933e37bb80068a25cdbc4a69a`
- fit window: `1987-05-29` to `2022-12-25` (12995 rows)
- forecast window: `2022-12-26` to `2023-01-24` (30 rows)
- response transform: `log_log1p`
- quantiles: `0.05, 0.2, 0.35, 0.5, 0.65, 0.8, 0.95`
- LDVB settings: tol=0.1, n.samp=1000, max_iter=1000, gam.init=0, sig.init=0.2
- transfer settings: lam=0.97, tf.df=0.9999999, 0.99999

## Output files

- figures: ex3_daily_convergence_elbo.png, ex3_daily_convergence_gamma.png, ex3_daily_convergence_sigma.png, ex3_daily_data_overview.png, ex3_daily_direct_states_dry.png, ex3_daily_direct_states_rainy.png, ex3_daily_fit_periods.png, ex3_daily_forecast_quantiles.png, ex3_daily_transfer_states_dry.png, ex3_daily_transfer_states_rainy.png
- tables: ex3_daily_convergence_traces.csv, ex3_daily_covariate_scaling.csv, ex3_daily_data_window_summary.csv, ex3_daily_direct_states_summary.csv, ex3_daily_fit_diagnostics.csv, ex3_daily_fit_periods_summary.csv, ex3_daily_fit_summary.csv, ex3_daily_forecast_plot_summary.csv, ex3_daily_forecast_summary.csv, ex3_daily_ldvb_convergence.csv, ex3_daily_transfer_states_summary.csv

## Fit status snapshot

- p0=0.05 | direct_regression | status=ok | iter=1000 | converged=FALSE | hit_iter_cap=TRUE | runtime=25188.49 | median.kt=NA
- p0=0.05 | transfer_function | status=ok | iter=1000 | converged=FALSE | hit_iter_cap=TRUE | runtime=27210.71 | median.kt=65.77138
- p0=0.20 | direct_regression | status=ok | iter=1000 | converged=FALSE | hit_iter_cap=TRUE | runtime=25074.03 | median.kt=NA
- p0=0.20 | transfer_function | status=ok | iter=1000 | converged=FALSE | hit_iter_cap=TRUE | runtime=26924.49 | median.kt=65.72021
- p0=0.35 | direct_regression | status=ok | iter=1000 | converged=FALSE | hit_iter_cap=TRUE | runtime=24812.51 | median.kt=NA
- p0=0.35 | transfer_function | status=ok | iter=1000 | converged=FALSE | hit_iter_cap=TRUE | runtime=27257.24 | median.kt=64.83573
- p0=0.50 | direct_regression | status=ok | iter=1000 | converged=FALSE | hit_iter_cap=TRUE | runtime=24790.36 | median.kt=NA
- p0=0.50 | transfer_function | status=ok | iter=1000 | converged=FALSE | hit_iter_cap=TRUE | runtime=27039.51 | median.kt=64.80278
- p0=0.65 | direct_regression | status=ok | iter=1000 | converged=FALSE | hit_iter_cap=TRUE | runtime=24389.44 | median.kt=NA
- p0=0.65 | transfer_function | status=ok | iter=1000 | converged=FALSE | hit_iter_cap=TRUE | runtime=27235.45 | median.kt=65.36282
- p0=0.80 | direct_regression | status=ok | iter=1000 | converged=FALSE | hit_iter_cap=TRUE | runtime=24296.21 | median.kt=NA
- p0=0.80 | transfer_function | status=ok | iter=1000 | converged=FALSE | hit_iter_cap=TRUE | runtime=27483.13 | median.kt=64.90444
- p0=0.95 | direct_regression | status=ok | iter=1000 | converged=FALSE | hit_iter_cap=TRUE | runtime=24087.99 | median.kt=NA
- p0=0.95 | transfer_function | status=ok | iter=1000 | converged=FALSE | hit_iter_cap=TRUE | runtime=27987.76 | median.kt=66.10271

## Diagnostics snapshot

- p0=0.05 | direct_regression | KL=0.49808130 | CRPS=   0.7474700 | pplc=   20967.72 | runtime=25188.49
- p0=0.05 | transfer_function | KL=0.41690844 | CRPS=   0.7958427 | pplc=   22042.31 | runtime=27210.71
- p0=0.20 | direct_regression | KL=0.16684081 | CRPS=   0.6561219 | pplc=   17501.31 | runtime=25074.03
- p0=0.20 | transfer_function | KL=0.13211251 | CRPS=   0.7213212 | pplc=   19143.57 | runtime=26924.49
- p0=0.35 | direct_regression | KL=0.12444930 | CRPS=   1.3286500 | pplc=   34130.46 | runtime=24812.51
- p0=0.35 | transfer_function | KL=0.09523624 | CRPS=   1.4852524 | pplc=   38158.66 | runtime=27257.24
- p0=0.50 | direct_regression | KL=0.12709696 | CRPS=   3.9665543 | pplc=   97557.31 | runtime=24790.36
- p0=0.50 | transfer_function | KL=0.09353672 | CRPS=   4.2429817 | pplc=  104302.75 | runtime=27039.51
- p0=0.65 | direct_regression | KL=0.18495511 | CRPS=  15.9695698 | pplc=  369188.73 | runtime=24389.44
- p0=0.65 | transfer_function | KL=0.14464329 | CRPS=  15.7252990 | pplc=  361126.69 | runtime=27235.45
- p0=0.80 | direct_regression | KL=0.34092226 | CRPS=  94.8411280 | pplc= 2098411.48 | runtime=24296.21
- p0=0.80 | transfer_function | KL=0.29282334 | CRPS=  81.2012051 | pplc= 1762685.81 | runtime=27483.13
- p0=0.95 | direct_regression | KL=0.88209443 | CRPS=2234.4424610 | pplc=47849308.21 | runtime=24087.99
- p0=0.95 | transfer_function | KL=0.81327670 | CRPS=1575.2798286 | pplc=32677946.63 | runtime=27987.76

## Forecast snapshot

- p0=0.05 | direct_regression | mean_check_loss=0.01970393 | mean_abs_error=0.3940785
- p0=0.05 | transfer_function | mean_check_loss=0.01400040 | mean_abs_error=0.2551078
- p0=0.20 | direct_regression | mean_check_loss=0.06074242 | mean_abs_error=0.2984925
- p0=0.20 | transfer_function | mean_check_loss=0.05577156 | mean_abs_error=0.2010270
- p0=0.35 | direct_regression | mean_check_loss=0.08642887 | mean_abs_error=0.2440430
- p0=0.35 | transfer_function | mean_check_loss=0.07818133 | mean_abs_error=0.1829181
- p0=0.50 | direct_regression | mean_check_loss=0.10384150 | mean_abs_error=0.2076830
- p0=0.50 | transfer_function | mean_check_loss=0.08883282 | mean_abs_error=0.1776656
- p0=0.65 | direct_regression | mean_check_loss=0.10896195 | mean_abs_error=0.1728767
- p0=0.65 | transfer_function | mean_check_loss=0.08765086 | mean_abs_error=0.1838020
- p0=0.80 | direct_regression | mean_check_loss=0.10105166 | mean_abs_error=0.1413911
- p0=0.80 | transfer_function | mean_check_loss=0.07318049 | mean_abs_error=0.2100387
- p0=0.95 | direct_regression | mean_check_loss=0.03873045 | mean_abs_error=0.0880834
- p0=0.95 | transfer_function | mean_check_loss=0.03359902 | mean_abs_error=0.2896190
