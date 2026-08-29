# Replication Materials Index

This note maps the JSS replication archive to the manuscript figures, tables,
and supporting output. The public entry point is the flat batch script `code.R`.

## Required package

The manuscript and replication materials target `exdqlm` version 1.1.1. Install
the submitted source tarball before running the script. This version uses serial
R-controlled RNG streams in manuscript stochastic helpers and the stabilized
default exAL scale-skewness updates for MCMC and LDVB.

## Public command

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

## Manuscript outputs

| Manuscript target | Generated output |
| --- | --- |
| `fig:ex1mcmc` | `figures/ex1mcmc.png` |
| `fig:ex1quants` | `figures/ex1quants.png` |
| `fig:ex2quant` | `figures/ex2quant.png` |
| `fig:ex2checks` | `figures/ex2checks.png` |
| `tab:ex2bench` | `tables/ex2_dynamic_benchmark.csv` |
| `fig:ex3data` | `figures/ex3data.png` |
| `fig:ex3quant` | `figures/ex3quantcomps.png` |
| `fig:ex3tftheta` | `figures/ex3zetapsi.png` |
| `fig:ex3forecast` | `figures/ex3forecast.png` |
| `tab:ex3` | `tables/ex3_diagnostics_summary.csv` |
| `tab:ex3forecastmetrics` | `tables/ex3_forecast_metrics.csv` |
| `fig:ex4static` | `figures/ex4static.png` |
| `tab:ex4static` | `tables/ex4static_summary.csv` |

The full script also prints the fitted object `M95`, `summary(M95)`,
`MTF$median.kt`, Tables 7--10, and `sessionInfo()` to `code.Rout`.

## Supporting files

The full run records supporting information in:

- `tables/benchmark_environment.csv`
- `tables/benchmark_backend_settings.csv`
- `logs/M95-print.txt`
- `logs/M95-summary.txt`
- `logs/MTF-median-kt.txt`
- `logs/sessionInfo.txt`

Runtime values are elapsed fitting times on the recorded platform and should not
be treated as machine-independent constants.

## Development files

The repository keeps modular scripts under `analysis/` for author-side
maintenance and for generating the flat public script. These files are useful
for development but are not the public replication interface for JSS.
