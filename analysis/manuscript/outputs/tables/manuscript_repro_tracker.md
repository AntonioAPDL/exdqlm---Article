# Manuscript Reproducibility Tracker

Generated: 2026-04-10 02:41:06
Profile: standard
Seed: 20260302

## Artifact Status

- [reproduced] `tab_ex4_seed_screen_summary` -> `analysis/manuscript/outputs/tables/ex4_seed_screen_summary.csv` (support: Example 4 seed screen metrics). Per-seed, per-quantile comparison of LDVB and MCMC for the Example 4 screening run.
- [reproduced] `tab_ex4_seed_screen_selection` -> `analysis/manuscript/outputs/tables/ex4_seed_screen_selection.csv` (support: Example 4 seed screen selection). Seed-level pass/fail summary for the Example 4 screening run.
- [reproduced] `log_ex4_seed_screen_summary` -> `analysis/manuscript/outputs/logs/ex4_seed_screen_summary.txt` (support: Example 4 seed screen summary). Selection criteria and final recommended seed for the Example 4 benchmark.
- [reproduced] `log_ex4_run_summary` -> `analysis/manuscript/outputs/logs/ex4_run_summary.txt` (Example 4 textual outputs). Sparse rhs_ns static simulation settings and recovery metrics for Example 4.
- [reproduced] `tab_ex4static_summary` -> `analysis/manuscript/outputs/tables/ex4static_summary.csv` (new: Example 4 static simulation summary). Runtime and sparse-signal recovery metrics for LDVB and MCMC under the rhs_ns prior.
- [reproduced] `fig_ex4static` -> `analysis/manuscript/outputs/figures/ex4static.png` (fig:ex4static). Sparse rhs_ns static simulation coefficient-recovery comparison for p0 = 0.05, 0.25, 0.50.
- [reproduced] `tab_api_migration_map` -> `analysis/manuscript/outputs/tables/manuscript_api_migration_map.csv` (global code migration). Maps deprecated manuscript calls to current package API.

## Notes

- api_update: Deprecated exdqlmChecks replaced with exdqlmDiagnostics.
- api_update: Deprecated y= usage removed from exdqlmPlot/compPlot/exdqlmForecast calls.
- ldvb_note: Added ISVB vs LDVB comparison figure for dynamic Sunspots example.
- backend: MCMC runs use C++ backend options exdqlm.use_cpp_mcmc=TRUE and exdqlm.cpp_mcmc_mode='fast'.
- ex4: Example 4 uses a sparse correlated-Gaussian regression benchmark with a target-quantile-centered Gaussian response model, so the true p0-quantile equals X beta at each fitted p0.
- ex4: The static sparse benchmark uses the rhs_ns prior with tau0 = 0.15, zeta2_fixed = 9, and an unshrunk intercept.
- ex4: The p0=0.05 LDVB fit uses an expanded iteration budget; p0=0.25 and p0=0.50 use the standard Example 4 LDVB budget.
- ex4: Example 4 focuses on the general static exAL model; the AL special case remains available via dqlm.ind = TRUE.
- coverage: Targeted run; requested targets: ex4screen, ex4figure, ex4table.
- timing: Exact runtime printouts in manuscript are historical and expected to differ.
- timing: Runtime values depend on hardware and backend settings; the Example 4 table reflects the standard-profile reproduction run recorded here.
- scope: Automated reproduction outputs are isolated under analysis/manuscript; manuscript text updates are tracked separately in article4.tex.
