# Manuscript Reproducibility Tracker

Generated: 2026-04-20 04:00:18
Profile: standard
Seed: 20260302

## Artifact Status

- [reproduced] `fig_ex3data` -> `analysis/manuscript/outputs/figures/ex3data.png` (fig:ex3data). Top: log monthly Big Tree flow aggregated from the staged daily file. Bottom: nino34 over the overlapping 1987-01 to 2021-04 window.
- [reproduced] `ex3_run_summary` -> `analysis/manuscript/outputs/logs/ex3_run_summary.txt` (Example 3 textual outputs). Monthly USGS/nino34 Example 3 summary including lambda optimization table and median.kt.
- [reproduced] `ex3_run_summary_ldvb` -> `analysis/manuscript/outputs/logs/ex3_run_summary_ldvb.txt` (new: Example 3 LDVB textual outputs). LDVB monthly USGS/nino34 counterpart including lambda scan and runtime summaries.
- [reproduced] `fig_ex3quantcomps` -> `analysis/manuscript/outputs/figures/ex3quantcomps.png` (fig:ex3quant). Primary Example 3 three-panel LDVB quantile/components figure with index-window fix.
- [reproduced] `fig_ex3zetapsi` -> `analysis/manuscript/outputs/figures/ex3zetapsi.png` (fig:ex3tftheta). Primary Example 3 LDVB transfer-function theta component plots.
- [reproduced] `fig_ex3forecast` -> `analysis/manuscript/outputs/figures/ex3forecast.png` (fig:ex3forecast). Primary Example 3 LDVB 18-step ahead forecast comparison.
- [reproduced] `tab_ex3_diagnostics` -> `analysis/manuscript/outputs/tables/ex3_diagnostics_summary.csv` (tab:ex3). Primary Example 3 LDVB diagnostics table generated with manuscript diagnostics helper.
- [reproduced] `tab_ex3_lambda_scan` -> `analysis/manuscript/outputs/tables/ex3_lambda_scan_kl.csv` (Example 3 lambda selection output). Primary LDVB lambda scan; best lambda in this run=0.300
- [reproduced] `tab_api_migration_map` -> `analysis/manuscript/outputs/tables/manuscript_api_migration_map.csv` (global code migration). Maps deprecated manuscript calls to current package API.
- [reproduced] `tab_benchmark_backend_profiles` -> `analysis/manuscript/outputs/tables/benchmark_backend_profiles.csv` (support: benchmark backend profiles). Defines Profile A (pure-R baseline) and Profile B (manuscript-matched backend).
- [reproduced] `tab_benchmark_environment` -> `analysis/manuscript/outputs/tables/benchmark_environment.csv` (support: benchmark environment details). CPU, R version, package/article state, backend options, seeds, and dataset sizes for the tracked benchmark run.

## Notes

- api_update: Deprecated exdqlmChecks replaced with exdqlmDiagnostics.
- api_update: Deprecated y= usage removed from exdqlmPlot/compPlot/exdqlmForecast calls.
- ldvb_note: Added ISVB vs LDVB comparison figure for dynamic Sunspots example.
- backend: Benchmark Profile B (manuscript-matched backend) is active for manuscript runs; current MCMC backend options are exdqlm.use_cpp_mcmc=TRUE and exdqlm.cpp_mcmc_mode='fast'.
- ex3: Best LDVB lambda by KL in this run profile: 0.300.
- coverage: Targeted run; requested targets: ex3data, ex3quantcomps, ex3zetapsi, ex3forecast, ex3tables.
- timing: Exact runtime printouts in manuscript are historical and expected to differ.
- timing: Runtime values depend on hardware and backend settings; the Example 4 table reflects the standard-profile reproduction run recorded here.
- benchmark: Benchmark tables reported in the manuscript use backend Profile B; benchmark_backend_profiles.csv defines both disclosed benchmark profiles.
- benchmark: benchmark_environment.csv records CPU, R version, package/article state, backend options, seeds, and dataset sizes for the tracked benchmark run.
- scope: Automated reproduction outputs are isolated under analysis/manuscript; manuscript text updates are tracked separately in article4.tex.
