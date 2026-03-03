# Manuscript Reproduction Stage

This stage reproduces the main manuscript example artifacts (figures, key tables,
and compact console-output equivalents) using the current `exdqlm` package API,
without modifying `article4.tex`.

## Scope

- Rebuilds Example 1 (Lake Huron) figures.
- Rebuilds Example 2 (Sunspots) figures + diagnostics with `exdqlmDiagnostics`.
- Rebuilds Example 3 (Big Tree) figures + diagnostics table.
- Adds one extra dynamic comparison figure: ISVB vs LDVB (`ex2_isvb_ldvb_compare.png`).
- Adds side-by-side gamma posterior comparison for Example 2 with 95% CrIs (`ex2_gamma_posteriors.png` + `ex2_gamma_credible_intervals.csv`).
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
Rscript analysis/run_all.R --stage manuscript --targets ex2_gamma_posteriors --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2_ldvb_diagnostics --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3quantcomps,ex3forecast --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1mcmc --force-refit --skip-tests
```

## Outputs

- `analysis/manuscript/outputs/figures/`: generated figure files.
- `analysis/manuscript/outputs/tables/`: diagnostics summaries + reproducibility tracker.
- `analysis/manuscript/outputs/logs/`: compact textual outputs and session metadata.
- `analysis/manuscript/outputs/cache/`: cached fitted objects to support fast targeted reruns.

Main tracker files:

- `manuscript_repro_tracker.csv`
- `manuscript_repro_tracker.md`
- `manuscript_api_migration_map.csv`
