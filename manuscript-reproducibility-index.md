# Replication Materials Index

This note maps the JSS replication archive to the manuscript figures, tables,
and supporting output. The public entry point is the flat batch script `code.R`.

## Required package

The manuscript and replication materials target `exdqlm` version 1.1.1. Install
the submitted source tarball before running the script. This version uses
R-controlled random-number streams for manuscript stochastic computations.

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

## Supporting Files

The full run records supporting information in `logs/M95-print.txt`,
`logs/M95-summary.txt`, `logs/MTF-median-kt.txt`, and `logs/sessionInfo.txt`.

Runtime values are elapsed fitting times on the recorded platform and should not
be treated as machine-independent constants.

## Development Files

The repository keeps modular scripts under `analysis/` for author-side
maintenance. These files are useful for development but are not the public
replication interface for JSS and are not needed to run the submitted archive.
