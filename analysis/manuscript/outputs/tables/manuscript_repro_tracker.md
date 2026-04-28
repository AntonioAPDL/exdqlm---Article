# Manuscript Reproducibility Tracker

Generated: 2026-04-28 19:16:36
Profile: standard
Seed: 20260519

## Artifact Status

- [reproduced] `ex1_model_output` -> `analysis/manuscript/outputs/logs/ex1_model_output.txt` (Example 1 model block). polytrend model object output.
- [reproduced] `ex1_run_summary` -> `analysis/manuscript/outputs/logs/ex1_run_summary.txt` (Example 1 textual outputs). Includes backend metadata and high-iteration trace diagnostics.
- [reproduced] `fig_ex1_mcmc_traces_all` -> `analysis/manuscript/outputs/figures/ex1_mcmc_traces_all.png` (support: Example 1 MCMC traces for fitted quantile models). Support-only MCMC sigma/gamma trace plots for the Example 1 fitted quantile models, thinned by 10.
- [reproduced] `tab_ex1_synthesis_bridge` -> `analysis/manuscript/outputs/tables/ex1_synthesis_bridge_check.csv` (support: Example 1 synthesis forecast-origin check). Checks that the forecast synthesis begins one Lake Huron time step after the observed-period synthesis endpoint; Figure 2(d) uses these endpoints for the visual interval bridge.
- [reproduced] `fig_ex1quants` -> `analysis/manuscript/outputs/figures/ex1quants.png` (fig:ex1quants). Four-panel Lake Huron figure with quantile estimates/forecasts on the top row and predictive synthesis over the observed and forecast windows on the bottom row. Panel (d) uses a darker related forecast synthesis band and bridges the observed synthesis endpoint to the first forecast synthesis endpoint for visual continuity on the annual time scale.
- [reproduced] `log_ex1_synthesis_summary` -> `analysis/manuscript/outputs/logs/ex1_synthesis_summary.txt` (support: Example 1 synthesis summary). Synthesis settings and compact summaries for the Lake Huron predictive synthesis figure.
- [reproduced] `fig_ex1synth` -> `analysis/manuscript/outputs/figures/ex1synth.png` (support: Example 1 standalone synthesis figure). Standalone support figure for Lake Huron predictive synthesis combining the 0.05, 0.50, and 0.95 fitted models over the observed period and the eight-step forecast horizon, with a darker forecast synthesis band and one-step visual bridge at the forecast origin.
- [approximate] `tab_ex1_runtime` -> `analysis/manuscript/outputs/tables/ex1_runtime_summary.csv` (Example 1 runtime statements). Runtimes vary by hardware/profile; trace run intentionally uses higher iterations.
- [reproduced] `tab_api_migration_map` -> `analysis/manuscript/outputs/tables/manuscript_api_migration_map.csv` (global code migration). Maps deprecated manuscript calls to current package API.
- [reproduced] `tab_benchmark_backend_profiles` -> `analysis/manuscript/outputs/tables/benchmark_backend_profiles.csv` (support: benchmark backend profiles). Defines Profile A (pure-R baseline) and Profile B (manuscript-matched backend).
- [reproduced] `tab_benchmark_environment` -> `analysis/manuscript/outputs/tables/benchmark_environment.csv` (support: benchmark environment details). CPU, R version, package/article state, backend options, seeds, and dataset sizes for the tracked benchmark run.

## Notes

- api_update: Deprecated exdqlmChecks replaced with exdqlmDiagnostics.
- api_update: Deprecated y= usage removed from exdqlmPlot/compPlot/exdqlmForecast calls.
- ex2_policy: Example 2 manuscript workflow now uses LDVB and MCMC only; ISVB support artifacts were retired.
- backend: Benchmark Profile B (manuscript-matched backend) is active for manuscript runs; current MCMC backend options are exdqlm.use_cpp_mcmc=TRUE and exdqlm.cpp_mcmc_mode='fast'.
- ex1: Lake Huron uses cached fits; ex1mcmc uses a dedicated high-iteration median MCMC chain, and runtime statements are profile-dependent (see ex1_run_summary).
- coverage: Targeted run; requested targets: ex1quants, ex1synth.
- timing: Exact runtime printouts in manuscript are historical and expected to differ.
- timing: Runtime values depend on hardware and backend settings; the Example 4 table reflects the standard-profile reproduction run recorded here.
- benchmark: Benchmark tables reported in the manuscript use backend Profile B; benchmark_backend_profiles.csv defines both disclosed benchmark profiles.
- benchmark: benchmark_environment.csv records CPU, R version, package/article state, backend options, seeds, and dataset sizes for the tracked benchmark run.
- scope: Automated reproduction outputs are isolated under analysis/manuscript; manuscript text updates are tracked separately in article4.tex.
