# Replication Materials Index

This note maps the files in the article archive to the manuscript figures,
tables, and supporting outputs. The public replication entrypoint is the
top-level script `code.R`; the `analysis/` tree contains the executable example
scripts, manifests, tests, and generated artifacts used by that script.

The revised submission targets the `exdqlm` package version recorded in
`analysis/config/params_manuscript.yml`. Install the submitted package source
tarball before running a full replication. The generated environment table
records the exact package version, commit, R version, random-number generator,
backend profile, and platform used for the reference run.

## Public replication entrypoints

From the extracted archive:

```sh
Rscript code.R
```

This is the full manuscript replication command. It refits the manuscript
examples, regenerates the figures, generated tables, logs, and artifact
manifests, then runs the manuscript checks and prints `sessionInfo()`.

For a faster installation and wiring check:

```sh
Rscript code.R --quick
```

For a targeted example rerun and refit:

```sh
Rscript code.R --example 3
```

Valid example numbers are `1`, `2`, `3`, and `4`. The included `code.html` file
is generated from `code.R` with `knitr::spin("code.R", knit = TRUE)`.

## Publication artifacts

| Manuscript target | Tracked output | Notes |
| --- | --- | --- |
| `fig:ex1mcmc` | `analysis/manuscript/outputs/figures/ex1mcmc.png` | Lake Huron MCMC diagnostics. |
| `fig:ex1quants` | `analysis/manuscript/outputs/figures/ex1quants.png` | Lake Huron quantile fits, forecasts, and synthesis. |
| `fig:ex2quant` | `analysis/manuscript/outputs/figures/ex2quant.png` | Sunspots fitted upper quantile. |
| `fig:ex2checks` | `analysis/manuscript/outputs/figures/ex2checks.png` | Sunspots fitted diagnostic plots. |
| `tab:ex2bench` | `analysis/manuscript/outputs/tables/ex2_dynamic_benchmark.csv` | Sunspots benchmark source table. |
| `fig:ex3data` | `analysis/manuscript/outputs/figures/ex3data.png` | Big Tree data and covariates. |
| `fig:ex3quant` | `analysis/manuscript/outputs/figures/ex3quantcomps.png` | Big Tree fitted quantiles and components. |
| `fig:ex3tftheta` | `analysis/manuscript/outputs/figures/ex3zetapsi.png` | Big Tree transfer-function states. |
| `fig:ex3forecast` | `analysis/manuscript/outputs/figures/ex3forecast.png` | Big Tree held-out forecasts. |
| `tab:ex3` | `analysis/manuscript/outputs/tables/ex3_diagnostics_summary.csv` | Big Tree fitted diagnostics. |
| `fig:ex4static` | `analysis/manuscript/outputs/figures/ex4static.png` | Static sparse exAL coefficient summaries. |
| `tab:ex4static` | `analysis/manuscript/outputs/tables/ex4static_summary.csv` | Static sparse exAL simulation summaries. |

## Core replication files

- `README.md`: short archive-level instructions.
- `code.R`: public standalone replication script.
- `code.html`: execution log generated from `code.R`.
- `exdqlm-jss.tex`: manuscript source.
- `exdqlm-supplement.tex`: appendix source input included by
  `exdqlm-jss.tex`.
- `analysis/config/params_manuscript.yml`: seeds, profile settings, expected
  package version, and backend profile.
- `analysis/manuscript/examples/`: canonical scripts for Examples 1--4.
- `analysis/manuscript/outputs/`: generated figures, tables, local caches, and logs.

Large `.rds` fit caches are local conveniences. They are recreated by the full
replication command when absent and should not be treated as required
submission artifacts.

The code printed in the manuscript is a reader-facing excerpt of the same
workflows. The file `analysis/manuscript/code_chunk_map.csv` records how each
displayed code chunk maps to the canonical executable scripts.

## Generated provenance

The main generated provenance files are:

- `analysis/manuscript/outputs/tables/manuscript_repro_tracker.csv`
- `analysis/manuscript/outputs/tables/manuscript_repro_tracker.md`
- `analysis/manuscript/outputs/tables/manuscript_repro_notes.csv`
- `analysis/manuscript/outputs/tables/manuscript_api_migration_map.csv`
- `analysis/manuscript/outputs/tables/benchmark_backend_profiles.csv`
- `analysis/manuscript/outputs/tables/benchmark_environment.csv`

Runtime values are elapsed fitting times for the recorded reference platform
and backend profile. They are not intended to be machine-independent constants.

## Internal maintenance tools

The files `analysis/run_all.R` and `analysis/check_reproducibility.R` remain in
the archive because they are useful for targeted developer reruns and final
reference checks. They are not the primary public entrypoint; use `code.R`
first.

Examples of internal targeted reruns:

```sh
Rscript analysis/run_all.R --stage manuscript --targets ex1 --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2 --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3 --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex4 --profile standard --skip-tests
```

The preflight utility is intended for final reference-machine maintenance:

```sh
Rscript analysis/check_reproducibility.R --stage manuscript --profile standard --require-r-version 4.6.0
```

## Auxiliary artifacts

The standard manuscript run includes the publication artifacts above. Optional
developer targets can also regenerate support artifacts such as the Example 1
kernel comparison and the Example 4 seed screen. These are documented in the
example folders under `analysis/manuscript/examples/` and are not required for
ordinary reader replication.
