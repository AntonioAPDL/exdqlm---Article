# Manuscript Reproducibility Tracker

Generated: 2026-05-18 03:23:24
Profile: standard
Seed: 20260501

## Artifact Status

- [reproduced] `ex1_model_output` -> `analysis/manuscript/outputs/logs/ex1_model_output.txt` (Example 1 model block). polytrend model object output.
- [reproduced] `ex1_run_summary` -> `analysis/manuscript/outputs/logs/ex1_run_summary.txt` (Example 1 textual outputs). Includes backend metadata and high-iteration trace diagnostics.
- [reproduced] `fig_ex1mcmc` -> `analysis/manuscript/outputs/figures/ex1mcmc.png` (fig:ex1mcmc). Trace and density plots for sigma and gamma from a dedicated higher-iteration free-sigma median MCMC run with thinning=10.
- [reproduced] `tab_ex1_synthesis_bridge` -> `analysis/manuscript/outputs/tables/ex1_synthesis_bridge_check.csv` (support: Example 1 synthesis forecast-origin check). Checks that the forecast synthesis begins one Lake Huron time step after the observed-period synthesis endpoint; Figure 2(d) uses these endpoints for the visual interval bridge.
- [reproduced] `fig_ex1quants` -> `analysis/manuscript/outputs/figures/ex1quants.png` (fig:ex1quants). Four-panel Lake Huron figure with quantile estimates/forecasts on the top row and predictive synthesis over the observed and forecast windows on the bottom row. Panel (d) uses a darker related forecast synthesis band and bridges the observed synthesis endpoint to the first forecast synthesis endpoint for visual continuity on the annual time scale.
- [reproduced] `log_ex1_synthesis_summary` -> `analysis/manuscript/outputs/logs/ex1_synthesis_summary.txt` (support: Example 1 synthesis summary). Synthesis settings and compact summaries for the Lake Huron predictive synthesis figure.
- [reproduced] `fig_ex1synth` -> `analysis/manuscript/outputs/figures/ex1synth.png` (support: Example 1 standalone synthesis figure). Standalone support figure for Lake Huron predictive synthesis combining the 0.05, 0.50, and 0.95 fitted models over the observed period and the eight-step forecast horizon, with a darker forecast synthesis band and one-step visual bridge at the forecast origin.
- [approximate] `tab_ex1_runtime` -> `analysis/manuscript/outputs/tables/ex1_runtime_summary.csv` (Example 1 runtime statements). Runtimes vary by hardware/profile; trace run intentionally uses higher iterations.
- [reproduced] `ex2_model_output` -> `analysis/manuscript/outputs/logs/ex2_model_output.txt` (Example 2 model matrix output). Combined trend/seasonal state-space matrix.
- [reproduced] `ex2_run_summary` -> `analysis/manuscript/outputs/logs/ex2_run_summary.txt` (Example 2 textual outputs). Includes sigma summary and LDVB runtime diagnostics for the manuscript Example 2 workflow.
- [reproduced] `log_ex2_benchmark_run_summary` -> `analysis/manuscript/outputs/logs/ex2_benchmark_run_summary.txt` (support: Example 2 dynamic benchmark summary). Runtime and diagnostics summary for the dynamic LDVB versus MCMC benchmark under the disclosed backend profile.
- [reproduced] `tab_ex2_dynamic_benchmark` -> `analysis/manuscript/outputs/tables/ex2_dynamic_benchmark.csv` (tab:ex2bench). Representative dynamic LDVB versus MCMC benchmark for Example 2 under backend Profile B.
- [reproduced] `fig_ex2quant` -> `analysis/manuscript/outputs/figures/ex2quant.png` (fig:ex2quant). Composite Sunspots figure with full-series panel, quantile-comparison panel, and gamma histogram.
- [reproduced] `fig_ex2quant_ldvb` -> `analysis/manuscript/outputs/figures/ex2quant_ldvb.png` (new: fig ex2quant LDVB counterpart). Composite Sunspots figure with full-series panel, quantile-comparison panel, and gamma histogram.
- [reproduced] `fig_ex2quant_ldvb_p099` -> `analysis/manuscript/outputs/figures/ex2quant_ldvb_p099.png` (new: fig ex2quant LDVB upper-tail (p0=0.99)). Three-panel LDVB figure for p0=0.99 comparing DQLM and exDQLM.
- [reproduced] `fig_ex2quant_ldvb_p005` -> `analysis/manuscript/outputs/figures/ex2quant_ldvb_p005.png` (new: fig ex2quant LDVB lower-tail (p0=0.05)). Three-panel LDVB figure for p0=0.05 comparing DQLM and exDQLM.
- [reproduced] `fig_ex2checks` -> `analysis/manuscript/outputs/figures/ex2checks.png` (fig:ex2checks). Primary Example 2 diagnostics figure generated from the LDVB fits.
- [reproduced] `fig_ex2checks_ldvb` -> `analysis/manuscript/outputs/figures/ex2checks_ldvb.png` (new: fig ex2checks LDVB counterpart). LDVB counterpart of ex2checks using exdqlmDiagnostics.
- [reproduced] `fig_ex2_ldvb_diagnostics` -> `analysis/manuscript/outputs/figures/ex2_ldvb_diagnostics.png` (new: LDVB convergence diagnostics). LDVB diagnostics with stricter tolerance (tol=0.01, n.samp=3000); includes DQLM/exDQLM LDVB fit overlay, seq.gamma, seq.sigma, and ELBO trace.
- [reproduced] `ex2_ldvb_diagnostics_summary` -> `analysis/manuscript/outputs/logs/ex2_ldvb_diagnostics_summary.txt` (new: LDVB convergence diagnostics summary). Text summary for LDVB convergence diagnostics.
- [reproduced] `tab_ex2_df_scan` -> `analysis/manuscript/outputs/tables/ex2_df_scan_kl.csv` (Example 2 discount-factor CRPS/KL selection). Best pair by CRPS in this run: (0.90, 0.85). Best pair by KL: (0.9, 0.85).
- [reproduced] `tab_ex2_diagnostics` -> `analysis/manuscript/outputs/tables/ex2_diagnostics_summary.csv` (Example 2 diagnostic narrative). Primary Example 2 diagnostics summary computed from the LDVB fits.
- [reproduced] `tab_ex2_df_scan_ldvb` -> `analysis/manuscript/outputs/tables/ex2_df_scan_kl_ldvb.csv` (new: Example 2 discount-factor CRPS/KL selection (LDVB)). Best pair by CRPS in this run: (0.90, 0.85). Best pair by KL: (0.9, 0.85).
- [reproduced] `tab_ex2_diagnostics_ldvb` -> `analysis/manuscript/outputs/tables/ex2_diagnostics_summary_ldvb.csv` (new: Example 2 diagnostic narrative (LDVB)). LDVB counterpart computed with exdqlmDiagnostics.
- [reproduced] `fig_ex3data` -> `analysis/manuscript/outputs/figures/ex3data.png` (fig:ex3data). Top: log observed monthly package BTflow. Bottom: standardized NOI and AMO over 1987-01 to 2022-12; vertical line marks the 18-month forecast holdout.
- [reproduced] `ex3_run_summary` -> `analysis/manuscript/outputs/logs/ex3_run_summary.txt` (Example 3 textual outputs). Observed BTflow plus NOI/AMO Example 3 summary with training-selected transfer settings, package diagnostics, and held-out forecast metrics.
- [reproduced] `tab_ex3_model_dataset` -> `analysis/manuscript/outputs/tables/ex3_model_dataset.csv` (Example 3 modeling dataset). Aligned Big Tree flow and climate-index data used by Example 3, with training and forecast-holdout phase labels.
- [reproduced] `tab_ex3_covariate_scaling` -> `analysis/manuscript/outputs/tables/ex3_covariate_scaling.csv` (Example 3 covariate scaling). Training-window means and standard deviations used to standardize Example 3 climate indices.
- [reproduced] `tab_ex3_lambda_selection` -> `analysis/manuscript/outputs/tables/ex3_lambda_selection.csv` (Example 3 transfer training-selection output). Example 3 transfer-function training diagnostic grid; selected lambda=0.850 and transfer psi discount=1.000 by training PPLC.
- [reproduced] `tab_ex3_diagnostics` -> `analysis/manuscript/outputs/tables/ex3_diagnostics_summary.csv` (tab:ex3). Example 3 final-training package diagnostics from exdqlmDiagnostics for the no-covariate, direct-regression, and transfer-function models.
- [reproduced] `tab_ex3_forecast_metrics` -> `analysis/manuscript/outputs/tables/ex3_forecast_metrics.csv` (tab:ex3forecastmetrics). Example 3 final 18-month holdout forecast check loss and CRPS from exdqlmForecastDiagnostics for the no-covariate, direct-regression, and transfer-function models.
- [reproduced] `tab_ex3_sensitivity_forecast_metrics` -> `analysis/manuscript/outputs/tables/ex3_sensitivity_forecast_metrics.csv` (Example 3 sensitivity forecast metrics). Backward-compatible copy of the Example 3 final 18-month holdout forecast check loss and CRPS from exdqlmForecastDiagnostics.
- [reproduced] `fig_ex3quantcomps` -> `analysis/manuscript/outputs/figures/ex3quantcomps.png` (fig:ex3quant). Example 3 quantile, seasonal, and covariate-contribution comparison for M0, MREG, and MTF.
- [reproduced] `fig_ex3zetapsi` -> `analysis/manuscript/outputs/figures/ex3zetapsi.png` (fig:ex3tftheta). Transfer-function zeta state and NOI/AMO psi states for the final Example 3 fit.
- [reproduced] `fig_ex3forecast` -> `analysis/manuscript/outputs/figures/ex3forecast.png` (fig:ex3forecast). Example 3 18-step holdout forecast over 2021-07 to 2022-12.
- [reproduced] `log_ex4_run_summary` -> `analysis/manuscript/outputs/logs/ex4_run_summary.txt` (Example 4 textual outputs). Sparse Nishimura-Suchard RHS static simulation settings and recovery metrics for Example 4.
- [reproduced] `tab_ex4static_summary` -> `analysis/manuscript/outputs/tables/ex4static_summary.csv` (tab:ex4static). Runtime and sparse-signal recovery metrics for LDVB and MCMC under the rhs_ns prior.
- [reproduced] `fig_ex4static` -> `analysis/manuscript/outputs/figures/ex4static.png` (fig:ex4static). Sparse Nishimura-Suchard RHS static simulation coefficient-recovery comparison for p0 = 0.05, 0.25, 0.50.
- [reproduced] `tab_api_migration_map` -> `analysis/manuscript/outputs/tables/manuscript_api_migration_map.csv` (global code migration). Maps deprecated manuscript calls to current package API.
- [reproduced] `tab_benchmark_backend_profiles` -> `analysis/manuscript/outputs/tables/benchmark_backend_profiles.csv` (support: benchmark backend profiles). Defines Profile A (pure-R baseline) and Profile B (manuscript-matched backend).
- [reproduced] `tab_benchmark_environment` -> `analysis/manuscript/outputs/tables/benchmark_environment.csv` (support: benchmark environment details). CPU, R version, package/article state, backend options, seeds, and dataset sizes for the tracked benchmark run.

## Notes

- api_update: Deprecated exdqlmChecks replaced with exdqlmDiagnostics.
- api_update: Deprecated y= usage removed from exdqlmPlot/compPlot/exdqlmForecast calls.
- ex2_policy: Example 2 manuscript workflow now uses LDVB and MCMC only; ISVB support artifacts were retired.
- backend: Benchmark Profile B (manuscript-matched backend) is active for manuscript runs; current MCMC backend options are exdqlm.use_cpp_mcmc=TRUE and exdqlm.cpp_mcmc_mode='fast'.
- ex1: Lake Huron uses cached fits; ex1mcmc uses a dedicated high-iteration median MCMC chain, and runtime statements are profile-dependent (see ex1_run_summary).
- ex2_ldvb_diag: Added LDVB diagnostic refit for convergence checks (tol=0.01, n.samp=3000, iter=200).
- ex2: Sunspots LDVB discount-factor screen selects seasonal discount factor=0.85 by CRPS for this run profile; KL is reported alongside it.
- ex2_ldvb: Sunspots LDVB discount-factor screen selects seasonal discount factor=0.85 by CRPS for this run profile; KL is reported alongside it.
- ex3: Example 3 selected lambda=0.850 using training-data PPLC with static transfer psi coefficients (discount fixed at 1.000).
- ex3: Example 3 final forecast metrics are computed only on the 18-month holdout window from 2021-07 to 2022-12.
- ex4: Example 4 uses a sparse correlated-Gaussian regression benchmark with a target-quantile-centered Gaussian response model, so the true p0-quantile equals X beta at each fitted p0.
- ex4: The static sparse benchmark uses the Nishimura-Suchard regularized horseshoe (rhs_ns) prior with tau0 = 0.15, zeta2_fixed = 9, and an unshrunk intercept.
- ex4: The p0=0.05 LDVB fit uses an expanded iteration budget; p0=0.25 and p0=0.50 use the standard Example 4 LDVB budget.
- ex4: Example 4 focuses on the general static exAL model; the AL special case remains available via al.ind = TRUE (static alias of dqlm.ind = TRUE).
- coverage: All publication-set manuscript artifacts were targeted in this pipeline.
- timing: Exact runtime printouts in manuscript are historical and expected to differ.
- timing: Runtime values depend on hardware and backend settings; the Example 4 table reflects the standard-profile reproduction run recorded here.
- benchmark: Benchmark tables reported in the manuscript use backend Profile B; benchmark_backend_profiles.csv defines both disclosed benchmark profiles.
- benchmark: benchmark_environment.csv records CPU, R version, package/article state, backend options, seeds, and dataset sizes for the tracked benchmark run.
- scope: Automated reproduction outputs are isolated under analysis/manuscript; manuscript text updates are tracked separately in exdqlm-jss.tex.
