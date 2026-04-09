# Manuscript Reproducibility Tracker

Generated: 2026-04-09 04:46:53
Profile: standard
Seed: 20260302

## Artifact Status

- [reproduced] `log_ex4_run_summary` -> `analysis/manuscript/outputs/logs/ex4_run_summary.txt` (Example 4 textual outputs). Simulation settings, convergence summary, and recovery metrics for Example 4.
- [reproduced] `tab_ex4static_summary` -> `analysis/manuscript/outputs/tables/ex4static_summary.csv` (new: Example 4 static simulation summary). Runtime and recovery metrics for LDVB and MCMC across p0 = 0.05, 0.25, 0.50.
- [reproduced] `fig_ex4static` -> `analysis/manuscript/outputs/figures/ex4static.png` (fig:ex4static). Static exAL simulation with truth, LDVB, and MCMC quantile curves for p0 = 0.05, 0.25, 0.50.
- [reproduced] `tab_api_migration_map` -> `analysis/manuscript/outputs/tables/manuscript_api_migration_map.csv` (global code migration). Maps deprecated manuscript calls to current package API.

## Notes

- api_update: Deprecated exdqlmChecks replaced with exdqlmDiagnostics.
- api_update: Deprecated y= usage removed from exdqlmPlot/compPlot/exdqlmForecast calls.
- ldvb_note: Added ISVB vs LDVB comparison figure for dynamic Sunspots example.
- backend: MCMC runs use C++ backend options exdqlm.use_cpp_mcmc=TRUE and exdqlm.cpp_mcmc_mode='fast'.
- ex4: Example 4 uses a heteroskedastic normal location-scale simulation with known linear conditional quantiles.
- ex4: The p0=0.05 LDVB fit uses an expanded iteration budget; p0=0.25 and p0=0.50 use the default Example 4 LDVB budget.
- ex4: Example 4 focuses on the general static exAL model; the AL special case remains available via dqlm.ind = TRUE.
- coverage: Targeted run; requested targets: ex4.
- timing: Runtime values depend on hardware and backend settings; the Example 4 table reflects the standard-profile reproduction run recorded here.
- scope: Automated reproduction outputs are isolated under analysis/manuscript; manuscript text updates are tracked separately in article4.tex.
