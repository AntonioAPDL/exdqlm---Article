# Manuscript Reproducibility Tracker

Generated: 2026-03-03 00:30:55
Profile: quick
Seed: 20260302

## Artifact Status

- [reproduced] `ex2_model_output` -> `analysis/manuscript/outputs/logs/ex2_model_output.txt` (Example 2 model matrix output). Combined trend/seasonal state-space matrix.
- [reproduced] `ex2_run_summary` -> `analysis/manuscript/outputs/logs/ex2_run_summary.txt` (Example 2 textual outputs). Includes sigma summary and ISVB/LDVB runtime diagnostics.
- [reproduced] `fig_ex2quant_ldvb` -> `analysis/manuscript/outputs/figures/ex2quant_ldvb.png` (new: fig ex2quant LDVB counterpart). LDVB counterpart of ex2quant with DQLM/exDQLM overlays and gamma histogram.
- [reproduced] `fig_ex2checks_ldvb` -> `analysis/manuscript/outputs/figures/ex2checks_ldvb.png` (new: fig ex2checks LDVB counterpart). LDVB counterpart of ex2checks using exdqlmDiagnostics.
- [reproduced] `tab_ex2_df_scan_ldvb` -> `analysis/manuscript/outputs/tables/ex2_df_scan_kl_ldvb.csv` (new: Example 2 discount-factor KL selection (LDVB)). Best pair in this run: (0.90, 0.85)
- [reproduced] `tab_ex2_diagnostics_ldvb` -> `analysis/manuscript/outputs/tables/ex2_diagnostics_summary_ldvb.csv` (new: Example 2 diagnostic narrative (LDVB)). LDVB counterpart computed with exdqlmDiagnostics.
- [reproduced] `ex3_run_summary` -> `analysis/manuscript/outputs/logs/ex3_run_summary.txt` (Example 3 textual outputs). Includes lambda optimization table and median.kt.
- [reproduced] `ex3_run_summary_ldvb` -> `analysis/manuscript/outputs/logs/ex3_run_summary_ldvb.txt` (new: Example 3 LDVB textual outputs). LDVB counterpart including lambda scan and runtime summaries.
- [reproduced] `fig_ex3quantcomps_ldvb` -> `analysis/manuscript/outputs/figures/ex3quantcomps_ldvb.png` (new: fig ex3quant LDVB counterpart). LDVB counterpart for Example 3 quantile/components plot.
- [reproduced] `fig_ex3zetapsi_ldvb` -> `analysis/manuscript/outputs/figures/ex3zetapsi_ldvb.png` (new: fig ex3tftheta LDVB counterpart). LDVB transfer-function theta component plots.
- [reproduced] `fig_ex3forecast_ldvb` -> `analysis/manuscript/outputs/figures/ex3forecast_ldvb.png` (new: fig ex3forecast LDVB counterpart). LDVB counterpart for the 18-step forecast figure.
- [reproduced] `tab_ex3_lambda_scan_ldvb` -> `analysis/manuscript/outputs/tables/ex3_lambda_scan_kl_ldvb.csv` (new: Example 3 lambda selection output (LDVB)). Best LDVB lambda in this run=0.850
- [reproduced] `tab_ex3_diagnostics_ldvb` -> `analysis/manuscript/outputs/tables/ex3_diagnostics_summary_ldvb.csv` (new: tab ex3 LDVB counterpart). LDVB counterpart diagnostics table generated with exdqlmDiagnostics.
- [reproduced] `tab_api_migration_map` -> `analysis/manuscript/outputs/tables/manuscript_api_migration_map.csv` (global code migration). Maps deprecated manuscript calls to current package API.

## Notes

- api_update: Deprecated exdqlmChecks replaced with exdqlmDiagnostics.
- api_update: Deprecated y= usage removed from exdqlmPlot/compPlot/exdqlmForecast calls.
- ldvb_note: Added ISVB vs LDVB comparison figure for dynamic Sunspots example.
- backend: MCMC runs use C++ backend options exdqlm.use_cpp_mcmc=TRUE and exdqlm.cpp_mcmc_mode='fast'.
- ex2: Used explicit dlm->exdqlm conversion because as.exdqlm(dlm) errors in current package.
- ex2_ldvb: Sunspots LDVB KL search best seasonal discount factor=0.85 for this run profile.
- ex3_ldvb: Best lambda by KL for LDVB in this run profile: 0.850.
- coverage: Targeted run; requested targets: ex2quant_ldvb, ex2checks_ldvb, ex2tables_ldvb, ex3quantcomps_ldvb, ex3zetapsi_ldvb, ex3forecast_ldvb, ex3tables_ldvb.
- timing: Exact runtime printouts in manuscript are historical and expected to differ.
- scope: Main manuscript .tex was not modified; all updates are isolated under analysis/manuscript.
