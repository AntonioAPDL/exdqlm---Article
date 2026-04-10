# Manuscript Reproducibility Tracker

Generated: 2026-04-09 20:46:25
Profile: standard
Seed: 20260302

## Artifact Status

- [reproduced] `ex1_model_output` -> `analysis/manuscript/outputs/logs/ex1_model_output.txt` (Example 1 model block). polytrend model object output.
- [reproduced] `ex1_run_summary` -> `analysis/manuscript/outputs/logs/ex1_run_summary.txt` (Example 1 textual outputs). Includes backend metadata and high-iteration trace diagnostics.
- [reproduced] `fig_ex1mcmc` -> `analysis/manuscript/outputs/figures/ex1mcmc.png` (fig:ex1mcmc). Trace and density plots for sigma and gamma from a dedicated higher-iteration free-sigma median MCMC run with thinning=5.
- [reproduced] `fig_ex1quants` -> `analysis/manuscript/outputs/figures/ex1quants.png` (fig:ex1quants). Two-panel quantile and forecast figure with index-window fix.
- [reproduced] `log_ex1_kernel_compare` -> `analysis/manuscript/outputs/logs/ex1_kernel_compare_summary.txt` (support: Example 1 kernel comparison summary). Four-chain Lake Huron median comparison of slice and laplace_rw.
- [reproduced] `tab_ex1_kernel_summary` -> `analysis/manuscript/outputs/tables/ex1_kernel_summary.csv` (support: Example 1 kernel summary). Pooled sigma/gamma posterior, runtime, Rhat, and ESS summaries for free-sigma slice and laplace_rw fits.
- [reproduced] `tab_ex1_kernel_chain_stability` -> `analysis/manuscript/outputs/tables/ex1_kernel_chain_stability.csv` (support: Example 1 kernel chain stability). Per-chain sigma/gamma posterior summaries, runtimes, and acceptance diagnostics.
- [reproduced] `fig_ex1_kernel_compare` -> `analysis/manuscript/outputs/figures/ex1_kernel_compare.png` (support: Example 1 slice vs laplace_rw kernel comparison). Four-chain Lake Huron median comparison with sigma and gamma trace overlays under free sigma.
- [approximate] `tab_ex1_runtime` -> `analysis/manuscript/outputs/tables/ex1_runtime_summary.csv` (Example 1 runtime statements). Runtimes vary by hardware/profile; trace run intentionally uses higher iterations.
- [reproduced] `tab_api_migration_map` -> `analysis/manuscript/outputs/tables/manuscript_api_migration_map.csv` (global code migration). Maps deprecated manuscript calls to current package API.

## Notes

- api_update: Deprecated exdqlmChecks replaced with exdqlmDiagnostics.
- api_update: Deprecated y= usage removed from exdqlmPlot/compPlot/exdqlmForecast calls.
- ldvb_note: Added ISVB vs LDVB comparison figure for dynamic Sunspots example.
- backend: MCMC runs use C++ backend options exdqlm.use_cpp_mcmc=TRUE and exdqlm.cpp_mcmc_mode='fast'.
- ex1_kernel: Lake Huron median kernel comparison: slice vs laplace_rw. Mean runtime ratio (laplace_rw / slice) = 0.758. sigma Rhat: slice=1.004, laplace_rw=1.156. gamma Rhat: slice=1.044, laplace_rw=1.332. sigma ESS: slice=505.8, laplace_rw=132.5. gamma ESS: slice=77.8, laplace_rw=25.4.
- ex1: Lake Huron uses cached fits; ex1mcmc uses a dedicated high-iteration median MCMC chain.
- coverage: Targeted run; requested targets: ex1mcmc, ex1quants, ex1kernel.
- timing: Exact runtime printouts in manuscript are historical and expected to differ.
- timing: Runtime values depend on hardware and backend settings; the Example 4 table reflects the standard-profile reproduction run recorded here.
- scope: Automated reproduction outputs are isolated under analysis/manuscript; manuscript text updates are tracked separately in article4.tex.
