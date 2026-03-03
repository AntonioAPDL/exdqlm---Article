# Manuscript Reproducibility Tracker

Generated: 2026-03-02 22:45:52
Profile: standard
Seed: 20260302

## Artifact Status

- [reproduced] `ex1_model_output` -> `analysis/manuscript/outputs/logs/ex1_model_output.txt` (Example 1 model block). polytrend model object output.
- [reproduced] `ex1_run_summary` -> `analysis/manuscript/outputs/logs/ex1_run_summary.txt` (Example 1 textual outputs). Includes backend metadata and high-iteration trace diagnostics.
- [reproduced] `fig_ex1mcmc` -> `analysis/manuscript/outputs/figures/ex1mcmc.png` (fig:ex1mcmc). Trace and density plot using dedicated higher-iteration median MCMC run.
- [reproduced] `fig_ex1quants` -> `analysis/manuscript/outputs/figures/ex1quants.png` (fig:ex1quants). Two-panel quantile and forecast figure with index-window fix.
- [approximate] `tab_ex1_runtime` -> `analysis/manuscript/outputs/tables/ex1_runtime_summary.csv` (Example 1 runtime statements). Runtimes vary by hardware/profile; trace run intentionally uses higher iterations.
- [reproduced] `ex2_model_output` -> `analysis/manuscript/outputs/logs/ex2_model_output.txt` (Example 2 model matrix output). Combined trend/seasonal state-space matrix.
- [reproduced] `ex2_run_summary` -> `analysis/manuscript/outputs/logs/ex2_run_summary.txt` (Example 2 textual outputs). Includes sigma summary and ISVB/LDVB runtime diagnostics.
- [reproduced] `fig_ex2quant` -> `analysis/manuscript/outputs/figures/ex2quant.png` (fig:ex2quant). Three-panel Sunspots figure (data, quantiles, gamma histogram).
- [reproduced] `fig_ex2checks` -> `analysis/manuscript/outputs/figures/ex2checks.png` (fig:ex2checks). Generated via exdqlmDiagnostics replacement for legacy exdqlmChecks.
- [reproduced] `fig_ex2_isvb_ldvb_compare` -> `analysis/manuscript/outputs/figures/ex2_isvb_ldvb_compare.png` (new: ISVB vs LDVB dynamic comparison). Includes robust LDVB display when gamma posterior is near-degenerate.
- [reproduced] `tab_ex2_df_scan` -> `analysis/manuscript/outputs/tables/ex2_df_scan_kl.csv` (Example 2 discount-factor KL selection). Best pair in this run: (0.90, 0.85)
- [reproduced] `tab_ex2_diagnostics` -> `analysis/manuscript/outputs/tables/ex2_diagnostics_summary.csv` (Example 2 diagnostic narrative). Computed with exdqlmDiagnostics.
- [reproduced] `fig_ex3data` -> `analysis/manuscript/outputs/figures/ex3data.png` (fig:ex3data). Top: log BTflow. Bottom: nino34.
- [reproduced] `ex3_run_summary` -> `analysis/manuscript/outputs/logs/ex3_run_summary.txt` (Example 3 textual outputs). Includes lambda optimization table and median.kt.
- [reproduced] `fig_ex3quantcomps` -> `analysis/manuscript/outputs/figures/ex3quantcomps.png` (fig:ex3quant). Three-panel quantile/components figure with index-window fix.
- [reproduced] `fig_ex3zetapsi` -> `analysis/manuscript/outputs/figures/ex3zetapsi.png` (fig:ex3tftheta). Transfer-function theta component plots.
- [reproduced] `fig_ex3forecast` -> `analysis/manuscript/outputs/figures/ex3forecast.png` (fig:ex3forecast). 18-step ahead forecast comparison.
- [reproduced] `tab_ex3_diagnostics` -> `analysis/manuscript/outputs/tables/ex3_diagnostics_summary.csv` (tab:ex3). Diagnostics table generated with exdqlmDiagnostics.
- [reproduced] `tab_ex3_lambda_scan` -> `analysis/manuscript/outputs/tables/ex3_lambda_scan_kl.csv` (Example 3 lambda selection output). Best lambda in this run=0.900
- [reproduced] `tab_api_migration_map` -> `analysis/manuscript/outputs/tables/manuscript_api_migration_map.csv` (global code migration). Maps deprecated manuscript calls to current package API.

## Notes

- api_update: Deprecated exdqlmChecks replaced with exdqlmDiagnostics.
- api_update: Deprecated y= usage removed from exdqlmPlot/compPlot/exdqlmForecast calls.
- ldvb_note: Added ISVB vs LDVB comparison figure for dynamic Sunspots example.
- backend: MCMC runs use C++ backend options exdqlm.use_cpp_mcmc=TRUE and exdqlm.cpp_mcmc_mode='fast'.
- ex1: Lake Huron uses cached fits; ex1mcmc uses a dedicated high-iteration median MCMC chain.
- ex2: Used explicit dlm->exdqlm conversion because as.exdqlm(dlm) errors in current package.
- ex2: Sunspots KL search best seasonal discount factor=0.85 for this run profile.
- ex3: Best lambda by KL in this run profile: 0.900.
- coverage: All main manuscript example figures were targeted in this pipeline.
- timing: Exact runtime printouts in manuscript are historical and expected to differ.
- scope: Main manuscript .tex was not modified; all updates are isolated under analysis/manuscript.
