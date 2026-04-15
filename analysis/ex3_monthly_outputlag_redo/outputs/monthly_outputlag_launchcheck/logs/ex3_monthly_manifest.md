# Example 3 Monthly Output-Lag Contrast Manifest

- config path: `/home/jaguir26/local/src/exdqlm---Article/analysis/ex3_monthly_outputlag_redo/config_launchcheck.yml`
- output tag: `monthly_outputlag_launchcheck`
- article repo snapshot at rerun: `1862548`
- package repo snapshot at rerun: `668685f`
- staged daily data path: `/home/jaguir26/data/exdqlm_experiments/ex3_daily/big_trees_daily_usgs_ppt_soil.csv`
- staged daily data sha256: `1ee2854398a8ed93fb171fa04e2a81c824dc7ab933e37bb80068a25cdbc4a69a`
- response aggregation: `monthly_mean`
- overlap window: `1987-01-01` to `2021-04-01` (412 monthly rows)
- modeled fit window: `1987-07-01` to `2026-03-01` (465 rows)
- response transform: `log`
- quantiles: `0.15, 0.5`
- feature base terms: ``
- feature lag terms: `flow, flow_sq`
- feature lag months: `1, 2, 3, 4, 5, 6`
- LDVB settings: tol=0.1, n.samp=40, max_iter=6, gam.init=0, sig.init=0.1
- transfer settings: lam=0.85, tf.df=0.99, 0.99
- BTflow comparison: corr_raw=0.999999877684395, corr_log=0.999993164962299, max_abs_diff=1.92

## Output files

- figures: ex3_monthly_convergence_elbo.png, ex3_monthly_convergence_gamma.png, ex3_monthly_convergence_sigma.png, ex3_monthly_data_overview.png, ex3_monthly_direct_states_drought.png, ex3_monthly_direct_states_enso.png, ex3_monthly_fit_periods.png, ex3_monthly_transfer_states_drought.png, ex3_monthly_transfer_states_enso.png
- tables: ex3_monthly_btflow_comparison.csv, ex3_monthly_convergence_traces.csv, ex3_monthly_covariate_scaling.csv, ex3_monthly_data_window_summary.csv, ex3_monthly_direct_states_summary.csv, ex3_monthly_fit_diagnostics.csv, ex3_monthly_fit_periods_summary.csv, ex3_monthly_fit_summary.csv, ex3_monthly_ldvb_convergence.csv, ex3_monthly_model_dataset.csv, ex3_monthly_transfer_states_summary.csv

## Fit status snapshot

- p0=0.15 | direct_regression | status=ok | iter=6 | converged=FALSE | hit_iter_cap=TRUE | runtime=12.019 | median.kt=NA
- p0=0.15 | transfer_function | status=ok | iter=6 | converged=FALSE | hit_iter_cap=TRUE | runtime=13.259 | median.kt=27.63251
- p0=0.50 | direct_regression | status=ok | iter=6 | converged=FALSE | hit_iter_cap=TRUE | runtime=12.186 | median.kt=NA
- p0=0.50 | transfer_function | status=ok | iter=6 | converged=FALSE | hit_iter_cap=TRUE | runtime=13.371 | median.kt=27.81882

## Diagnostics snapshot

- p0=0.15 | direct_regression | KL=0.23935640 | CRPS=0.3686590 | pplc=  95.10828 | runtime=12.019
- p0=0.15 | transfer_function | KL=0.20363050 | CRPS=0.3713092 | pplc=  97.72482 | runtime=13.259
- p0=0.50 | direct_regression | KL=0.08663709 | CRPS=1.3440723 | pplc=1082.96671 | runtime=12.186
- p0=0.50 | transfer_function | KL=0.07005799 | CRPS=1.3723621 | pplc=1121.07452 | runtime=13.371
