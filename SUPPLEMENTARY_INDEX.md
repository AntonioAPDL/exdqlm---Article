# Supplementary Materials Index

This note is the reader-facing map to the reproducible materials that accompany
the `exdqlm` software article. It is intended to complement the manuscript by
identifying the publication artifacts, the main support-only artifacts, and the
tracked rerun paths used to regenerate them from the current `0.4.0` package.

Current snapshot references are recorded in the generated reproducibility
tracker and rerun logs. When regenerating artifacts, use the checked-out article
commit together with the current CRAN-facing package branch
`cransub/0.4.0`, or override the package path explicitly with `--pkg-path`.

## 1. Publication Artifacts

These are the figures and tables cited directly in the manuscript.

| Manuscript target | Tracked output | Optional local export |
| --- | --- | --- |
| `fig:ex1mcmc` | `analysis/manuscript/outputs/figures/ex1mcmc.png` | `Figures/ex1mcmc.png` |
| `fig:ex1quants` | `analysis/manuscript/outputs/figures/ex1quants.png` | `Figures/ex1quants.png` |
| `fig:ex2quant` | `analysis/manuscript/outputs/figures/ex2quant.png` | `Figures/ex2quant.png` |
| `fig:ex2checks` | `analysis/manuscript/outputs/figures/ex2checks.png` | `Figures/ex2checks.png` |
| `tab:ex2bench` | `analysis/manuscript/outputs/tables/ex2_dynamic_benchmark.csv` | tracked table only |
| `fig:ex3data` | `analysis/manuscript/outputs/figures/ex3data.png` | `Figures/ex3data.png` |
| `fig:ex3quant` | `analysis/manuscript/outputs/figures/ex3quantcomps.png` | `Figures/ex3quantcomps.png` |
| `fig:ex3tftheta` | `analysis/manuscript/outputs/figures/ex3zetapsi.png` | `Figures/ex3zetapsi.png` |
| `fig:ex3forecast` | `analysis/manuscript/outputs/figures/ex3forecast.png` | `Figures/ex3forecast.png` |
| `tab:ex3` | `analysis/manuscript/outputs/tables/ex3_diagnostics_summary.csv` | tracked table only |
| `fig:ex4static` | `analysis/manuscript/outputs/figures/ex4static.png` | `Figures/ex4static.png` |
| `tab:ex4static` | `analysis/manuscript/outputs/tables/ex4static_summary.csv` | tracked table only |

## 2. Core Reproduction Files

The manuscript-facing workflow is organized under the article repository:

- [analysis/README.md](/home/jaguir26/local/src/exdqlm---Article/analysis/README.md)
- [analysis/manuscript/README.md](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/README.md)
- [analysis/run_all.R](/home/jaguir26/local/src/exdqlm---Article/analysis/run_all.R)
- [article4.tex](/home/jaguir26/local/src/exdqlm---Article/article4.tex)

The canonical executable scripts for the paper examples are under
`analysis/manuscript/examples/`. Manuscript figures are generated into
`analysis/manuscript/outputs/figures/`, which is the first path searched by
`article4.tex`. Top-level `Figures/` files are optional local export copies
created by `--promote`; they are ignored by git and are not used by the
manuscript build. Inline LaTeX tables in `article4.tex` should be synchronized
with the corresponding generated CSV/log outputs whenever a model is rerun.

The main reproducibility outputs written by the manuscript stage are:

- [manuscript_repro_tracker.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/manuscript_repro_tracker.csv)
- [manuscript_repro_tracker.md](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/manuscript_repro_tracker.md)
- [manuscript_repro_notes.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/manuscript_repro_notes.csv)
- [manuscript_api_migration_map.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/manuscript_api_migration_map.csv)
- [benchmark_backend_profiles.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/benchmark_backend_profiles.csv)
- [benchmark_environment.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/benchmark_environment.csv)

## 3. Main Rerun Entry Points

From the repository root:

```bash
Rscript analysis/run_all.R --stage manuscript
Rscript analysis/run_all.R --stage manuscript --profile standard --promote
```

Useful targeted reruns:

```bash
Rscript analysis/run_all.R --stage manuscript --targets ex1mcmc,ex1quants,ex1synth --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2quant,ex2checks,ex2bench --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3data,ex3quantcomps,ex3zetapsi,ex3forecast,ex3tables --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex4screen --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex4figure,ex4table --profile standard --force-refit --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1kernel --profile standard --force-refit --skip-tests
```

## 4. Support Artifacts by Example

### Example 1: Lake Huron

Publication-facing:
- [ex1mcmc.png](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/figures/ex1mcmc.png)
- [ex1quants.png](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/figures/ex1quants.png)

Support-only:
- [ex1synth.png](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/figures/ex1synth.png)
- [ex1_synthesis_summary.txt](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/logs/ex1_synthesis_summary.txt)
- [ex1_kernel_summary.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/ex1_kernel_summary.csv)
- [ex1_kernel_chain_stability.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/ex1_kernel_chain_stability.csv)
- [ex1_kernel_compare_summary.txt](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/logs/ex1_kernel_compare_summary.txt)

### Example 2: Sunspots

Publication-facing:
- [ex2quant.png](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/figures/ex2quant.png)
- [ex2checks.png](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/figures/ex2checks.png)
- [ex2_dynamic_benchmark.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/ex2_dynamic_benchmark.csv)

Support-only:
- [ex2_df_scan_kl.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/ex2_df_scan_kl.csv)
- [ex2_ldvb_diagnostics.png](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/figures/ex2_ldvb_diagnostics.png)

### Example 3: Big Tree

Publication-facing:
- [ex3data.png](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/figures/ex3data.png)
- [ex3quantcomps.png](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/figures/ex3quantcomps.png)
- [ex3zetapsi.png](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/figures/ex3zetapsi.png)
- [ex3forecast.png](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/figures/ex3forecast.png)
- [ex3_diagnostics_summary.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/ex3_diagnostics_summary.csv)

Support-only:
- [ex3_lambda_scan.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/ex3_lambda_scan.csv)
- [ex3_model_dataset.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/ex3_model_dataset.csv)
- [ex3_covariate_scaling.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/ex3_covariate_scaling.csv)

### Example 4: Static exAL benchmark

Publication-facing:
- [ex4static.png](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/figures/ex4static.png)
- [ex4static_summary.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/ex4static_summary.csv)

Support-only:
- [ex4_seed_screen_p050_summary.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/ex4_seed_screen_p050_summary.csv)
- [ex4_seed_screen_p050_selection.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/ex4_seed_screen_p050_selection.csv)
- [ex4_seed_screen_p050_summary.txt](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/logs/ex4_seed_screen_p050_summary.txt)

## 5. Supplementary Robustness Note

The current manuscript does not add a new main-text sensitivity section. Instead,
the repository retains support-side robustness artifacts for the parts of the
workflow where this is most informative.

The most important of these is the Example 4 \(p_0 = 0.50\) seed screen:

- [ex4_seed_screen_p050_selection.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/ex4_seed_screen_p050_selection.csv)
- [ex4_seed_screen_p050_summary.txt](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/logs/ex4_seed_screen_p050_summary.txt)

In the tracked standard-profile run, a fixed seed grid is screened in
deterministic batches until at least one candidate satisfies the illustration
criterion:
- the full Example 4 fit must succeed for all tracked `p0` values,
- at `p0 = 0.50`, the MCMC 95% intervals for all plotted slope coefficients
  must contain the truth,
- among the full-coverage seeds, the promoted seed is chosen by smaller MCMC
  active-signal RMSE, then smaller holdout RMSE, then smaller runtime.

This confirms that the promoted Example 4 benchmark is not a casual seed
choice, while also making clear that the static benchmark is a curated
illustrative example rather than a claim of uniform performance across all
possible simulated datasets.

Two smaller support-side robustness checks are also retained:
- Example 1 kernel comparison:
  [ex1_kernel_summary.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/ex1_kernel_summary.csv)
- Example 2 discount-factor scan:
  [ex2_df_scan_kl.csv](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/outputs/tables/ex2_df_scan_kl.csv)

## 6. Practical Reading Order

For a reader who wants only the core article artifacts:
1. read the manuscript and inspect the publication figures/tables listed in Section 1
2. consult the reproducibility tracker files in Section 2

For a reader who wants the computational support layer:
1. read [analysis/manuscript/README.md](/home/jaguir26/local/src/exdqlm---Article/analysis/manuscript/README.md)
2. use the rerun commands in Section 3
3. inspect the example-specific support artifacts in Sections 4 and 5
