# Manuscript Reproduction Stage

This stage reproduces the main manuscript example artifacts (figures, key tables,
and compact console-output equivalents) using the current `exdqlm` package API,
without modifying `article4.tex`.

## Scope

- Rebuilds Example 1 (Lake Huron) figures.
- Rebuilds Example 1 predictive-synthesis figure from the tracked 0.05, 0.50, and 0.95 fits.
- Rebuilds Example 2 (Sunspots) primary figures from the LDVB workflow, with support-only ISVB/LDVB comparison artifacts available when requested.
- Rebuilds Example 3 (Big Tree) primary figures + diagnostics table from the LDVB workflow.
- Rebuilds Example 4 sparse static exAL simulation figure + summary table under the regularized horseshoe (RHS) prior.
- Adds one extra dynamic comparison figure: ISVB vs LDVB (`ex2_isvb_ldvb_compare.png`).
- Adds side-by-side gamma posterior comparison for Example 2 with 95% CrIs (`ex2_gamma_posteriors.png` + `ex2_gamma_credible_intervals.csv`).
- Adds LDVB-only counterparts for ISVB artifacts in Example 2 and Example 3 (figures + diagnostics/scan tables).
- Adds an optional support-only Example 1 kernel comparison (`ex1kernel`) that benchmarks `slice` versus `laplace_rw` for the free-`sigma` median Lake Huron fit.
- Adds an optional support-only Example 4 seed screen (`ex4screen`) that benchmarks a fixed candidate set of simulation seeds before promoting one seed into the tracked static example.
- Writes a reproducibility tracker with per-artifact status notes.

## Run

From repository root:

```bash
Rscript analysis/run_all.R --stage manuscript
```

Useful variants:

```bash
Rscript analysis/run_all.R --stage manuscript --profile quick
Rscript analysis/run_all.R --stage manuscript --profile standard
Rscript analysis/run_all.R --stage manuscript --skip-tests
Rscript analysis/run_all.R --stage manuscript --promote
Rscript analysis/run_all.R --stage manuscript --pkg-path /path/to/exdqlm
Rscript analysis/run_all.R --stage manuscript --targets ex2quant --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2quant,ex2checks --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2quant_ldvb,ex2checks_ldvb --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2_gamma_posteriors --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2_ldvb_diagnostics --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3data,ex3quantcomps,ex3zetapsi,ex3forecast,ex3tables --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3quantcomps_ldvb,ex3forecast_ldvb,ex3tables_ldvb --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3quantcomps,ex3forecast --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex4screen --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex4figure,ex4table --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1mcmc --force-refit --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1synth --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1kernel --force-refit --skip-tests
```

By default, this stage loads local `exdqlm` source from
`/home/jaguir26/local/src/exdqlm__wt__0p4p0_article_main`. Override that with
`--pkg-path /path/to/exdqlm` or `EXDQLM_PKG_PATH=/path/to/exdqlm`.
If both are set, `--pkg-path` takes precedence over `EXDQLM_PKG_PATH`.
For constrained environments where rebuilding local source is not feasible,
set `EXDQLM_LOAD_MODE=installed` and optionally
`EXDQLM_INSTALLED_LIB=/path/to/R/library` to use an installed `exdqlm`
package instead. Source mode remains the default.

## Outputs

- `analysis/manuscript/outputs/figures/`: generated figure files.
- `analysis/manuscript/outputs/tables/`: diagnostics summaries + reproducibility tracker.
- `analysis/manuscript/outputs/logs/`: compact textual outputs and session metadata.
- `analysis/manuscript/outputs/cache/`: cached fitted objects to support fast targeted reruns.

Main tracker files:

- `manuscript_repro_tracker.csv`
- `manuscript_repro_tracker.md`
- `manuscript_api_migration_map.csv`
