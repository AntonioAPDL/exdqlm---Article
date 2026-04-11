# Manuscript Reproducibility Tracker

Generated: 2026-04-11 00:26:48
Profile: standard
Seed: 20260302

## Artifact Status

- [reproduced] `ex1_model_output` -> `analysis/manuscript/outputs/logs/ex1_model_output.txt` (Example 1 model block). polytrend model object output.
- [reproduced] `ex1_run_summary` -> `analysis/manuscript/outputs/logs/ex1_run_summary.txt` (Example 1 textual outputs). Includes backend metadata and high-iteration trace diagnostics.
- [reproduced] `fig_ex1mcmc` -> `analysis/manuscript/outputs/figures/ex1mcmc.png` (fig:ex1mcmc). Trace and density plots for sigma and gamma from a dedicated higher-iteration free-sigma median MCMC run with thinning=10.
- [reproduced] `fig_ex1quants` -> `analysis/manuscript/outputs/figures/ex1quants.png` (fig:ex1quants). Four-panel Lake Huron figure with quantile estimates/forecasts on the top row and predictive synthesis over the observed and forecast windows on the bottom row.
- [approximate] `tab_ex1_runtime` -> `analysis/manuscript/outputs/tables/ex1_runtime_summary.csv` (Example 1 runtime statements). Runtimes vary by hardware/profile; trace run intentionally uses higher iterations.
- [reproduced] `ex2_model_output` -> `analysis/manuscript/outputs/logs/ex2_model_output.txt` (Example 2 model matrix output). Combined trend/seasonal state-space matrix.
- [reproduced] `ex2_run_summary` -> `analysis/manuscript/outputs/logs/ex2_run_summary.txt` (Example 2 textual outputs). Includes sigma summary and ISVB/LDVB runtime diagnostics.
- [reproduced] `log_ex2_benchmark_run_summary` -> `analysis/manuscript/outputs/logs/ex2_benchmark_run_summary.txt` (support: Example 2 dynamic benchmark summary). Runtime and diagnostics summary for the dynamic VB versus MCMC benchmark under the disclosed backend profile.
- [reproduced] `tab_ex2_dynamic_benchmark` -> `analysis/manuscript/outputs/tables/ex2_dynamic_benchmark.csv` (tab:ex2bench). Representative dynamic VB versus MCMC benchmark for Example 2 under backend Profile B.
- [reproduced] `fig_ex2quant` -> `analysis/manuscript/outputs/figures/ex2quant.png` (fig:ex2quant). Three-panel LDVB figure for original p0=0.85 comparing DQLM and exDQLM.
- [not_reproduced] `fig_ex2quant_ldvb` -> `analysis/manuscript/outputs/figures/ex2quant_ldvb.png` (new: fig ex2quant LDVB counterpart). Missing LDVB DQLM/exDQLM fits required for p0=0.85 quantile panel.
- [reproduced] `fig_ex2checks` -> `analysis/manuscript/outputs/figures/ex2checks.png` (fig:ex2checks). Primary Example 2 diagnostics figure generated from the LDVB fits.
- [reproduced] `tab_ex2_df_scan` -> `analysis/manuscript/outputs/tables/ex2_df_scan_kl.csv` (Example 2 discount-factor CRPS/KL selection). Best pair by CRPS in this run: (0.90, 0.85). Best pair by KL: (0.9, 0.85).
- [reproduced] `tab_ex2_diagnostics` -> `analysis/manuscript/outputs/tables/ex2_diagnostics_summary.csv` (Example 2 diagnostic narrative). Primary Example 2 diagnostics summary computed from the LDVB fits.
- [reproduced] `fig_ex3data` -> `analysis/manuscript/outputs/figures/ex3data.png` (fig:ex3data). Top: log BTflow. Bottom: nino34.
- [reproduced] `ex3_run_summary` -> `analysis/manuscript/outputs/logs/ex3_run_summary.txt` (Example 3 textual outputs). Includes lambda optimization table and median.kt.
- [reproduced] `ex3_run_summary_ldvb` -> `analysis/manuscript/outputs/logs/ex3_run_summary_ldvb.txt` (new: Example 3 LDVB textual outputs). LDVB counterpart including lambda scan and runtime summaries.
- [reproduced] `fig_ex3quantcomps` -> `analysis/manuscript/outputs/figures/ex3quantcomps.png` (fig:ex3quant). Primary Example 3 three-panel LDVB quantile/components figure with index-window fix.
- [reproduced] `fig_ex3zetapsi` -> `analysis/manuscript/outputs/figures/ex3zetapsi.png` (fig:ex3tftheta). Primary Example 3 LDVB transfer-function theta component plots.
- [reproduced] `fig_ex3forecast` -> `analysis/manuscript/outputs/figures/ex3forecast.png` (fig:ex3forecast). Primary Example 3 LDVB 18-step ahead forecast comparison.
- [reproduced] `tab_ex3_diagnostics` -> `analysis/manuscript/outputs/tables/ex3_diagnostics_summary.csv` (tab:ex3). Primary Example 3 LDVB diagnostics table generated with manuscript diagnostics helper.
- [reproduced] `tab_ex3_lambda_scan` -> `analysis/manuscript/outputs/tables/ex3_lambda_scan_kl.csv` (Example 3 lambda selection output). Primary LDVB lambda scan; best lambda in this run=0.850
- [reproduced] `log_ex4_run_summary` -> `analysis/manuscript/outputs/logs/ex4_run_summary.txt` (Example 4 textual outputs). Sparse RHS static simulation settings and recovery metrics for Example 4.
- [reproduced] `tab_ex4static_summary` -> `analysis/manuscript/outputs/tables/ex4static_summary.csv` (new: Example 4 static simulation summary). Runtime and sparse-signal recovery metrics for LDVB and MCMC under the RHS prior.
- [reproduced] `fig_ex4static` -> `analysis/manuscript/outputs/figures/ex4static.png` (fig:ex4static). Sparse RHS static simulation coefficient-recovery comparison for p0 = 0.05, 0.25, 0.50.
- [reproduced] `tab_api_migration_map` -> `analysis/manuscript/outputs/tables/manuscript_api_migration_map.csv` (global code migration). Maps deprecated manuscript calls to current package API.
- [reproduced] `tab_benchmark_backend_profiles` -> `analysis/manuscript/outputs/tables/benchmark_backend_profiles.csv` (support: benchmark backend profiles). Defines Profile A (pure-R baseline) and Profile B (manuscript-matched backend).
- [reproduced] `tab_benchmark_environment` -> `analysis/manuscript/outputs/tables/benchmark_environment.csv` (support: benchmark environment details). CPU, R version, package/article state, backend options, seeds, and dataset sizes for the tracked benchmark run.

## Notes

- api_update: Deprecated exdqlmChecks replaced with exdqlmDiagnostics.
- api_update: Deprecated y= usage removed from exdqlmPlot/compPlot/exdqlmForecast calls.
- ldvb_note: Added ISVB vs LDVB comparison figure for dynamic Sunspots example.
- backend: Benchmark Profile B (manuscript-matched backend) is active for manuscript runs; current MCMC backend options are exdqlm.use_cpp_mcmc=TRUE and exdqlm.cpp_mcmc_mode='fast'.
- ex1: Lake Huron uses cached fits; ex1mcmc uses a dedicated high-iteration median MCMC chain.
- ex2: Used explicit dlm->exdqlm conversion because as.exdqlm(dlm) errors in current package.
- ex2: Sunspots LDVB discount-factor screen selects seasonal discount factor=0.85 by CRPS for this run profile; KL is reported alongside it.
- ex3: Best LDVB lambda by KL in this run profile: 0.850.
- ex4: Example 4 uses a sparse correlated-Gaussian regression benchmark with a target-quantile-centered Gaussian response model, so the true p0-quantile equals X beta at each fitted p0.
- ex4: The static sparse benchmark uses the regularized horseshoe (RHS) prior with tau0 = 0.15, zeta2_fixed = 9, and an unshrunk intercept.
- ex4: The p0=0.05 LDVB fit uses an expanded iteration budget; p0=0.25 and p0=0.50 use the standard Example 4 LDVB budget.
- ex4: Example 4 focuses on the general static exAL model; the AL special case remains available via dqlm.ind = TRUE.
- coverage: Targeted run; requested targets: ex1mcmc, ex1quants, ex2quant, ex2checks, ex2tables, ex3data, ex3quantcomps, ex3zetapsi, ex3forecast, ex3tables, ex4figure, ex4table.
- timing: Exact runtime printouts in manuscript are historical and expected to differ.
- timing: Runtime values depend on hardware and backend settings; the Example 4 table reflects the standard-profile reproduction run recorded here.
- benchmark: Benchmark tables reported in the manuscript use backend Profile B; benchmark_backend_profiles.csv defines both disclosed benchmark profiles.
- benchmark: benchmark_environment.csv records CPU, R version, package/article state, backend options, seeds, and dataset sizes for the tracked benchmark run.
- scope: Automated reproduction outputs are isolated under analysis/manuscript; manuscript text updates are tracked separately in article4.tex.
