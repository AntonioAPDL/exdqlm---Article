# Manuscript Reproducibility Tracker

Generated: 2026-04-28 22:14:48
Profile: standard
Seed: 20260519

## Artifact Status

- [reproduced] `ex1_model_output` -> `analysis/manuscript/outputs/logs/ex1_model_output.txt` (Example 1 model block). polytrend model object output.
- [reproduced] `ex1_run_summary` -> `analysis/manuscript/outputs/logs/ex1_run_summary.txt` (Example 1 textual outputs). Includes backend metadata and high-iteration trace diagnostics.
- [reproduced] `fig_ex1mcmc` -> `analysis/manuscript/outputs/figures/ex1mcmc.png` (fig:ex1mcmc). Trace and density plots for sigma and gamma from a dedicated higher-iteration free-sigma median MCMC run with thinning=10.
- [reproduced] `fig_ex1_mcmc_traces_all` -> `analysis/manuscript/outputs/figures/ex1_mcmc_traces_all.png` (support: Example 1 MCMC traces for fitted quantile models). Support-only MCMC sigma/gamma trace plots for the Example 1 fitted quantile models, thinned by 10.
- [reproduced] `tab_ex1_synthesis_bridge` -> `analysis/manuscript/outputs/tables/ex1_synthesis_bridge_check.csv` (support: Example 1 synthesis forecast-origin check). Checks that the forecast synthesis begins one Lake Huron time step after the observed-period synthesis endpoint; Figure 2(d) uses these endpoints for the visual interval bridge.
- [reproduced] `fig_ex1quants` -> `analysis/manuscript/outputs/figures/ex1quants.png` (fig:ex1quants). Four-panel Lake Huron figure with quantile estimates/forecasts on the top row and predictive synthesis over the observed and forecast windows on the bottom row. Panel (d) uses a darker related forecast synthesis band and bridges the observed synthesis endpoint to the first forecast synthesis endpoint for visual continuity on the annual time scale.
- [reproduced] `log_ex1_synthesis_summary` -> `analysis/manuscript/outputs/logs/ex1_synthesis_summary.txt` (support: Example 1 synthesis summary). Synthesis settings and compact summaries for the Lake Huron predictive synthesis figure.
- [reproduced] `fig_ex1synth` -> `analysis/manuscript/outputs/figures/ex1synth.png` (support: Example 1 standalone synthesis figure). Standalone support figure for Lake Huron predictive synthesis combining the 0.05, 0.50, and 0.95 fitted models over the observed period and the eight-step forecast horizon, with a darker forecast synthesis band and one-step visual bridge at the forecast origin.
- [approximate] `tab_ex1_runtime` -> `analysis/manuscript/outputs/tables/ex1_runtime_summary.csv` (Example 1 runtime statements). Runtimes vary by hardware/profile; trace run intentionally uses higher iterations.
- [reproduced] `ex2_model_output` -> `analysis/manuscript/outputs/logs/ex2_model_output.txt` (Example 2 model matrix output). Combined trend/seasonal state-space matrix.
- [reproduced] `ex2_run_summary` -> `analysis/manuscript/outputs/logs/ex2_run_summary.txt` (Example 2 textual outputs). Includes sigma summary and LDVB runtime diagnostics for the manuscript Example 2 workflow.
- [reproduced] `fig_ex2_vb_convergence` -> `analysis/manuscript/outputs/figures/ex2_vb_convergence.png` (support: Example 2 LDVB convergence traces). Support-only LDVB convergence traces for the primary Example 2 fits (p0=0.95, n.samp=3000, max_iter=500).
- [reproduced] `log_ex2_benchmark_run_summary` -> `analysis/manuscript/outputs/logs/ex2_benchmark_run_summary.txt` (support: Example 2 dynamic benchmark summary). Runtime and diagnostics summary for the dynamic VB versus MCMC benchmark under the disclosed backend profile.
- [reproduced] `tab_ex2_dynamic_benchmark` -> `analysis/manuscript/outputs/tables/ex2_dynamic_benchmark.csv` (tab:ex2bench). Representative dynamic VB versus MCMC benchmark for Example 2 under backend Profile B.
- [reproduced] `fig_ex2_mcmc_traces` -> `analysis/manuscript/outputs/figures/ex2_mcmc_traces.png` (support: Example 2 benchmark MCMC traces). Support-only MCMC sigma/gamma trace plots for the Example 2 benchmark fits (p0=0.95, n.mcmc=3000).
- [reproduced] `fig_ex2quant` -> `analysis/manuscript/outputs/figures/ex2quant.png` (fig:ex2quant). Composite Sunspots figure with full-series panel, quantile-comparison panel, and gamma histogram.
- [reproduced] `fig_ex2checks` -> `analysis/manuscript/outputs/figures/ex2checks.png` (fig:ex2checks). Primary Example 2 diagnostics figure generated from the LDVB fits.
- [reproduced] `fig_ex2_ldvb_diagnostics` -> `analysis/manuscript/outputs/figures/ex2_ldvb_diagnostics.png` (new: LDVB convergence diagnostics). LDVB diagnostics with stricter tolerance (p0=0.95, tol=0.01, n.samp=3000, max_iter=500); includes DQLM/exDQLM LDVB fit overlay, seq.gamma, seq.sigma, and ELBO trace.
- [reproduced] `ex2_ldvb_diagnostics_summary` -> `analysis/manuscript/outputs/logs/ex2_ldvb_diagnostics_summary.txt` (new: LDVB convergence diagnostics summary). Text summary for LDVB convergence diagnostics.
- [reproduced] `tab_ex2_df_scan` -> `analysis/manuscript/outputs/tables/ex2_df_scan_kl.csv` (Example 2 discount-factor CRPS/KL selection). Best pair by CRPS in this run: (0.90, 0.95). Best pair by KL: (0.9, 0.9).
- [reproduced] `tab_ex2_diagnostics` -> `analysis/manuscript/outputs/tables/ex2_diagnostics_summary.csv` (Example 2 diagnostic narrative). Primary Example 2 diagnostics summary computed from the LDVB fits.
- [reproduced] `fig_ex3data` -> `analysis/manuscript/outputs/figures/ex3data.png` (fig:ex3data). Top: log observed monthly package BTflow. Bottom: standardized NOI and AMO over 1987-01 to 2022-12.
- [reproduced] `ex3_run_summary` -> `analysis/manuscript/outputs/logs/ex3_run_summary.txt` (Example 3 textual outputs). Observed BTflow plus NOI/AMO Example 3 summary including CRPS lambda scan and transfer persistence.
- [reproduced] `fig_ex3_vb_convergence` -> `analysis/manuscript/outputs/figures/ex3_vb_convergence.png` (support: Example 3 LDVB convergence traces). Support-only LDVB convergence traces for the Example 3 final fits (p0=0.05, n.samp=3000, max_iter=500).
- [reproduced] `tab_ex3_model_dataset` -> `analysis/manuscript/outputs/tables/ex3_model_dataset.csv` (support: Example 3 aligned model dataset). Aligned package BTflow and standardized climate-index inputs used by the canonical Example 3 fits.
- [reproduced] `tab_ex3_covariate_scaling` -> `analysis/manuscript/outputs/tables/ex3_covariate_scaling.csv` (support: Example 3 covariate standardization). Centers and scales used to standardize the selected climate indices.
- [reproduced] `tab_ex3_lambda_scan` -> `analysis/manuscript/outputs/tables/ex3_lambda_scan.csv` (Example 3 lambda selection output). Example 3 transfer-function lambda scan; best finite CRPS lambda=0.400.
- [reproduced] `fig_ex3quantcomps` -> `analysis/manuscript/outputs/figures/ex3quantcomps.png` (fig:ex3quant). Example 3 quantile, seasonal, and combined NOI/AMO climate-contribution comparison.
- [reproduced] `fig_ex3zetapsi` -> `analysis/manuscript/outputs/figures/ex3zetapsi.png` (fig:ex3tftheta). Transfer-function zeta state and NOI/AMO psi states for the canonical Example 3 fit.
- [reproduced] `fig_ex3forecast` -> `analysis/manuscript/outputs/figures/ex3forecast.png` (fig:ex3forecast). Example 3 18-step forecast over the final observed overlap window ending 2022-12.
- [reproduced] `tab_ex3_diagnostics` -> `analysis/manuscript/outputs/tables/ex3_diagnostics_summary.csv` (tab:ex3). Example 3 diagnostics table generated from the canonical NOI/AMO manuscript workflow.
- [reproduced] `tab_ex4_seed_screen_p050_summary` -> `analysis/manuscript/outputs/tables/ex4_seed_screen_p050_summary.csv` (support: Example 4 seed screen metrics). Per-seed, per-quantile comparison of the Example 4 static fits. Seed selection targets p0 = 0.50 and requires full MCMC 95% slope-interval coverage.
- [reproduced] `tab_ex4_seed_screen_p050_selection` -> `analysis/manuscript/outputs/tables/ex4_seed_screen_p050_selection.csv` (support: Example 4 seed screen selection). Seed-level selection summary for the Example 4 screen. The selected seed is the first full-coverage p0 = 0.50 candidate after sorting by MCMC active RMSE, holdout RMSE, runtime, and seed.
- [reproduced] `log_ex4_seed_screen_p050_summary` -> `analysis/manuscript/outputs/logs/ex4_seed_screen_p050_summary.txt` (support: Example 4 seed screen summary). Selection criteria and chosen Example 4 dataset seed based on the p0 = 0.50 MCMC coverage screen.
- [reproduced] `log_ex4_run_summary` -> `analysis/manuscript/outputs/logs/ex4_run_summary.txt` (Example 4 textual outputs). Sparse RHS static simulation settings and recovery metrics for Example 4.
- [reproduced] `tab_ex4static_summary` -> `analysis/manuscript/outputs/tables/ex4static_summary.csv` (new: Example 4 static simulation summary). Runtime and sparse-signal recovery metrics for LDVB and MCMC under the RHS prior.
- [reproduced] `fig_ex4static` -> `analysis/manuscript/outputs/figures/ex4static.png` (fig:ex4static). Sparse RHS static simulation coefficient-recovery comparison for p0 = 0.05, 0.25, 0.50.
- [reproduced] `tab_api_migration_map` -> `analysis/manuscript/outputs/tables/manuscript_api_migration_map.csv` (global code migration). Maps deprecated manuscript calls to current package API.
- [reproduced] `tab_benchmark_backend_profiles` -> `analysis/manuscript/outputs/tables/benchmark_backend_profiles.csv` (support: benchmark backend profiles). Defines Profile A (pure-R baseline) and Profile B (manuscript-matched backend).
- [reproduced] `tab_benchmark_environment` -> `analysis/manuscript/outputs/tables/benchmark_environment.csv` (support: benchmark environment details). CPU, R version, package/article state, backend options, seeds, and dataset sizes for the tracked benchmark run.

## Notes

- api_update: Deprecated exdqlmChecks replaced with exdqlmDiagnostics.
- api_update: Deprecated y= usage removed from exdqlmPlot/compPlot/exdqlmForecast calls.
- ex2_policy: Example 2 manuscript workflow now uses LDVB and MCMC only; ISVB support artifacts were retired.
- backend: Benchmark Profile B (manuscript-matched backend) is active for manuscript runs; current MCMC backend options are exdqlm.use_cpp_mcmc=TRUE and exdqlm.cpp_mcmc_mode='fast'.
- ex1: Lake Huron uses cached fits; ex1mcmc uses a dedicated high-iteration median MCMC chain, and runtime statements are profile-dependent (see ex1_run_summary).
- ex2_ldvb_diag: Added LDVB diagnostic refit for convergence checks (p0=0.95, tol=0.01, n.samp=3000, max_iter=500, iter=359).
- ex2: Sunspots LDVB discount-factor screen selects seasonal discount factor=0.95 by CRPS for this run profile; KL is reported alongside it.
- ex3: Example 3 selected lambda=0.400 by finite CRPS over the documented grid.
- ex3: Example 3 uses observed package BTflow and standardized NOI and AMO from climateIndices over 1987-01 to 2022-12.
- ex4: Example 4 uses a sparse correlated-Gaussian regression benchmark with a target-quantile-centered Gaussian response model, so the true p0-quantile equals X beta at each fitted p0.
- ex4: The static sparse benchmark uses the regularized horseshoe (RHS) prior with tau0 = 0.15, zeta2_fixed = 9, and an unshrunk intercept.
- ex4: The p0=0.05 LDVB fit uses an expanded iteration budget; p0=0.25 and p0=0.50 use the standard Example 4 LDVB budget.
- ex4: The tracked Example 4 dataset seed (20260718) was selected by the support-only ex4screen workflow using the p0=0.50 MCMC full-coverage criterion for the plotted slope coefficients.
- ex4: Example 4 focuses on the general static exAL model; the AL special case remains available via al.ind = TRUE (static alias of dqlm.ind = TRUE).
- coverage: All publication-set manuscript artifacts were targeted in this pipeline.
- timing: Exact runtime printouts in manuscript are historical and expected to differ.
- timing: Runtime values depend on hardware and backend settings; the Example 4 table reflects the standard-profile reproduction run recorded here.
- benchmark: Benchmark tables reported in the manuscript use backend Profile B; benchmark_backend_profiles.csv defines both disclosed benchmark profiles.
- benchmark: benchmark_environment.csv records CPU, R version, package/article state, backend options, seeds, and dataset sizes for the tracked benchmark run.
- scope: Automated reproduction outputs are isolated under analysis/manuscript; manuscript text updates are tracked separately in article4.tex.
