# Replication Materials Index

This note maps the JSS replication archive to the manuscript figures, tables,
and supporting outputs. The public entry point is the flat batch script
`code.R`. The optional `code-fast.R` script uses smaller computation settings
for code-path checks only.

## Required package

The manuscript and replication materials target `exdqlm` version 1.1.1. Install
the submitted source tarball before running either script.

## Public commands

Full manuscript replication:

```sh
OMP_NUM_THREADS=1 \
OMP_THREAD_LIMIT=1 \
OPENBLAS_NUM_THREADS=1 \
MKL_NUM_THREADS=1 \
BLIS_NUM_THREADS=1 \
VECLIB_MAXIMUM_THREADS=1 \
R CMD BATCH --vanilla code.R code.Rout
```

Reduced code-path check:

```sh
OMP_NUM_THREADS=1 \
OMP_THREAD_LIMIT=1 \
OPENBLAS_NUM_THREADS=1 \
MKL_NUM_THREADS=1 \
BLIS_NUM_THREADS=1 \
VECLIB_MAXIMUM_THREADS=1 \
R CMD BATCH --vanilla code-fast.R code-fast.Rout
```

## Publication artifacts

| Manuscript target | Generated output |
| --- | --- |
| `fig:ex1mcmc` | `analysis/manuscript/outputs/figures/ex1mcmc.png` |
| `fig:ex1quants` | `analysis/manuscript/outputs/figures/ex1quants.png` |
| `fig:ex2quant` | `analysis/manuscript/outputs/figures/ex2quant.png` |
| `fig:ex2checks` | `analysis/manuscript/outputs/figures/ex2checks.png` |
| `tab:ex2bench` | `analysis/manuscript/outputs/tables/ex2_dynamic_benchmark.csv` |
| `fig:ex3data` | `analysis/manuscript/outputs/figures/ex3data.png` |
| `fig:ex3quant` | `analysis/manuscript/outputs/figures/ex3quantcomps.png` |
| `fig:ex3tftheta` | `analysis/manuscript/outputs/figures/ex3zetapsi.png` |
| `fig:ex3forecast` | `analysis/manuscript/outputs/figures/ex3forecast.png` |
| `tab:ex3` | `analysis/manuscript/outputs/tables/ex3_diagnostics_summary.csv` |
| `tab:ex3forecastmetrics` | `analysis/manuscript/outputs/tables/ex3_forecast_metrics.csv` |
| `fig:ex4static` | `analysis/manuscript/outputs/figures/ex4static.png` |
| `tab:ex4static` | `analysis/manuscript/outputs/tables/ex4static_summary.csv` |

The full script also prints the fitted object `M95`, `summary(M95)`,
`MTF$median.kt`, Tables 7--10, and `sessionInfo()` to `code.Rout`.

## Provenance files

The full run records supporting provenance in:

- `analysis/manuscript/outputs/tables/benchmark_environment.csv`
- `analysis/manuscript/outputs/tables/benchmark_backend_profiles.csv`
- `analysis/manuscript/outputs/tables/manuscript_repro_tracker.csv`
- `analysis/manuscript/outputs/tables/manuscript_repro_notes.csv`

Runtime values are elapsed fitting times on the recorded platform and should not
be treated as machine-independent constants.

## Development files

The repository keeps modular scripts under `analysis/` for author-side
maintenance and for generating the flat public scripts. These files are useful
for development but are not the public replication interface for JSS.
