# Manuscript Reproducibility Tracker

Generated: 2026-03-03 12:40:22
Profile: standard
Seed: 20260302

## Artifact Status

- [reproduced] `ex2_model_output` -> `analysis/manuscript/outputs/logs/ex2_model_output.txt` (Example 2 model matrix output). Combined trend/seasonal state-space matrix.
- [reproduced] `ex2_run_summary` -> `analysis/manuscript/outputs/logs/ex2_run_summary.txt` (Example 2 textual outputs). Includes sigma summary and ISVB/LDVB runtime diagnostics.
- [reproduced] `fig_ex2quant` -> `analysis/manuscript/outputs/figures/ex2quant.png` (fig:ex2quant). Two-panel ISVB extreme-quantile figure (p0=0.05 and p0=0.95) with fit and forecast views.
- [reproduced] `tab_api_migration_map` -> `analysis/manuscript/outputs/tables/manuscript_api_migration_map.csv` (global code migration). Maps deprecated manuscript calls to current package API.

## Notes

- api_update: Deprecated exdqlmChecks replaced with exdqlmDiagnostics.
- api_update: Deprecated y= usage removed from exdqlmPlot/compPlot/exdqlmForecast calls.
- ldvb_note: Added ISVB vs LDVB comparison figure for dynamic Sunspots example.
- backend: MCMC runs use C++ backend options exdqlm.use_cpp_mcmc=TRUE and exdqlm.cpp_mcmc_mode='fast'.
- ex2: Used explicit dlm->exdqlm conversion because as.exdqlm(dlm) errors in current package.
- coverage: Targeted run; requested targets: ex2quant.
- timing: Exact runtime printouts in manuscript are historical and expected to differ.
- scope: Main manuscript .tex was not modified; all updates are isolated under analysis/manuscript.
