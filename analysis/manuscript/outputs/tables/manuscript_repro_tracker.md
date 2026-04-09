# Manuscript Reproducibility Tracker

Generated: 2026-04-09 19:48:27
Profile: standard
Seed: 20260302

## Artifact Status

- [reproduced] `ex1_model_output` -> `analysis/manuscript/outputs/logs/ex1_model_output.txt` (Example 1 model block). polytrend model object output.
- [reproduced] `log_ex1_kernel_compare` -> `analysis/manuscript/outputs/logs/ex1_kernel_compare_summary.txt` (support: Example 1 kernel comparison summary). Four-chain Lake Huron median comparison of slice and laplace_rw.
- [reproduced] `tab_ex1_kernel_summary` -> `analysis/manuscript/outputs/tables/ex1_kernel_summary.csv` (support: Example 1 kernel summary). Gamma-only pooled posterior, runtime, Rhat, and ESS summaries for slice and laplace_rw with sigma fixed.
- [reproduced] `tab_ex1_kernel_chain_stability` -> `analysis/manuscript/outputs/tables/ex1_kernel_chain_stability.csv` (support: Example 1 kernel chain stability). Per-chain gamma posterior summaries, runtimes, and acceptance diagnostics.
- [reproduced] `fig_ex1_kernel_compare` -> `analysis/manuscript/outputs/figures/ex1_kernel_compare.png` (support: Example 1 slice vs laplace_rw kernel comparison). Four-chain Lake Huron median comparison with gamma trace and density overlays under fixed sigma.
- [reproduced] `tab_api_migration_map` -> `analysis/manuscript/outputs/tables/manuscript_api_migration_map.csv` (global code migration). Maps deprecated manuscript calls to current package API.

## Notes

- api_update: Deprecated exdqlmChecks replaced with exdqlmDiagnostics.
- api_update: Deprecated y= usage removed from exdqlmPlot/compPlot/exdqlmForecast calls.
- ldvb_note: Added ISVB vs LDVB comparison figure for dynamic Sunspots example.
- backend: MCMC runs use C++ backend options exdqlm.use_cpp_mcmc=TRUE and exdqlm.cpp_mcmc_mode='fast'.
- ex1_kernel: Lake Huron median kernel comparison: slice vs laplace_rw. Sigma is fixed at 0.4, so the comparison targets gamma mixing only. Mean runtime ratio (laplace_rw / slice) = 0.781. gamma Rhat: slice=1.036, laplace_rw=1.040. gamma ESS: slice=214.0, laplace_rw=77.3.
- coverage: Targeted run; requested targets: ex1kernel.
- timing: Exact runtime printouts in manuscript are historical and expected to differ.
- timing: Runtime values depend on hardware and backend settings; the Example 4 table reflects the standard-profile reproduction run recorded here.
- scope: Automated reproduction outputs are isolated under analysis/manuscript; manuscript text updates are tracked separately in article4.tex.
