# exdqlm article replication materials

This directory contains the manuscript source and replication materials for the
JSS article

> exdqlm: An R Package for Estimation and Analysis of Flexible Dynamic Quantile
> Linear Models.

This README is for the JSS article archive, not for general package use. Package
users should consult the CRAN page, package README, and reference manual.

## Files for JSS upload

The JSS resubmission should contain these files:

- `exdqlm-jss.pdf`: manuscript PDF, including appendices.
- `response-to-editor.pdf`: point-by-point response to the prescreening
  comments.
- `exdqlm_1.1.1.tar.gz`: `exdqlm` package source tarball.
- `exdqlm-jss-replication.tar.gz`: article source and replication materials.

The replication archive is built from this repository after excluding local
scratch files, audit notes, interrupted runs, and development-only artifacts.

## Replication scripts

The public replication interface is deliberately simple:

- `code.R`: authoritative full replication script. It refits the manuscript
  examples, regenerates figures and tables, prints selected fitted-object output
  and all manuscript tables to `code.Rout`, and writes the full graphics stream
  to `Rplots.pdf`.
- `code-fast.R`: reduced code-checking script with the same structure and
  smaller computation settings. It is not authoritative for manuscript numbers.

Both scripts are flat, commented R scripts. They do not call `source()`, read or
write saved fit objects, inspect Git metadata, or require local paths.

## Install the package

Install the submitted package source tarball before running the replication:

```sh
R CMD INSTALL exdqlm_1.1.1.tar.gz
```

Confirm the installed version:

```sh
Rscript -e 'stopifnot(as.character(packageVersion("exdqlm")) == "1.1.1")'
```

## Run the full replication

From the extracted replication directory, run:

```sh
OMP_NUM_THREADS=1 \
OMP_THREAD_LIMIT=1 \
OPENBLAS_NUM_THREADS=1 \
MKL_NUM_THREADS=1 \
BLIS_NUM_THREADS=1 \
VECLIB_MAXIMUM_THREADS=1 \
R CMD BATCH --vanilla code.R code.Rout
```

The full run can take substantial time because it refits Bayesian dynamic and
static quantile models. The primary reviewer-facing outputs are `code.Rout` and
`Rplots.pdf`, together with generated files under
`analysis/manuscript/outputs/`.

For a shorter code-path check, run:

```sh
OMP_NUM_THREADS=1 \
OMP_THREAD_LIMIT=1 \
OPENBLAS_NUM_THREADS=1 \
MKL_NUM_THREADS=1 \
BLIS_NUM_THREADS=1 \
VECLIB_MAXIMUM_THREADS=1 \
R CMD BATCH --vanilla code-fast.R code-fast.Rout
```

`code-fast.Rout` should be used only to check that the workflow executes and
prints the expected objects, tables, and session information.

## Output locations

The main generated files are:

- `code.Rout`: batch console output from the full script.
- `Rplots.pdf`: graphics stream from the full script, with manuscript figures in
  manuscript order.
- `analysis/manuscript/outputs/figures/`: PNG figures used by the manuscript.
- `analysis/manuscript/outputs/tables/`: CSV sources for manuscript tables.
- `analysis/manuscript/outputs/logs/`: printed summaries and provenance logs.

Runtime values are platform dependent. The replication output records the R
version, package version, RNG settings, backend profile, and platform used for
the author reference run.
