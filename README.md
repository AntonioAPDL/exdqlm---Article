# exdqlm article replication materials

This directory contains the manuscript source and replication materials for
the JSS article:

> exdqlm: An R Package for Estimation and Analysis of Flexible Dynamic Quantile
> Linear Models

The replication materials are intended to be run from this extracted directory.
They do not require a version-control checkout.

## Contents

- `exdqlm-jss.tex`, `exdqlm-jss.pdf`: manuscript source and compiled PDF. The
  compiled manuscript PDF includes the technical appendices.
- `exdqlm-appendix.tex`: appendix source input used by `exdqlm-jss.tex`.
  It is not a separate submitted manuscript PDF.
- `code.R`: standalone replication script for the manuscript results.
- `code.html`: HTML log generated from `code.R` with `knitr::spin()`.
- `analysis/`: scripts, configuration, generated figures/tables/logs, tests,
  and small helper files used by `code.R`.
- `analysis/manuscript/outputs/`: generated manuscript artifacts.

The source code for the `exdqlm` R package is submitted separately as the
package source tarball. The package is also available from CRAN when the CRAN
version matches the submitted manuscript version.

## Install the package

Install `exdqlm` before running the replication script. If the submitted source
tarball is available in the current directory, install it with:

```sh
R CMD INSTALL exdqlm_*.tar.gz
```

If the matching version is already on CRAN, this is also sufficient:

```sh
Rscript -e 'install.packages("exdqlm", repos = "https://cloud.r-project.org")'
```

You can confirm the installed version with:

```sh
Rscript -e 'packageVersion("exdqlm")'
```

## Reproduce the article

From this directory, run:

```sh
Rscript code.R
```

This is the full manuscript replication command. It refits the manuscript
examples, regenerates the figures, generated tables, logs, and reproducibility
manifests under `analysis/manuscript/outputs/`, then runs the manuscript checks
and prints `sessionInfo()`.

The full run can take substantial time because several examples fit Bayesian
models. For a faster setup check, run:

```sh
Rscript code.R --quick
```

The quick command checks package loading, manuscript wiring, existing generated
outputs, and the test suite without refitting all examples.

To rerun and refit a single example, use:

```sh
Rscript code.R --example 3
```

Valid example numbers are `1`, `2`, `3`, and `4`.

## Output locations

The main generated files are written to:

- `analysis/manuscript/outputs/figures/`
- `analysis/manuscript/outputs/tables/`
- `analysis/manuscript/outputs/logs/`
- `analysis/manuscript/outputs/cache/` (local fit caches recreated by full runs)

The manuscript reads figures from `analysis/manuscript/outputs/figures/`.
Generated CSV files and logs provide the numerical source for the tables and
reported values in the manuscript.

Large `.rds` fit caches are local conveniences and are not required in the
submitted archive. If they are absent, `Rscript code.R` recreates the needed
fits from the scripts and data.

Runtime values are machine dependent. They are recorded as elapsed fitting
times for the stated backend profile and should be interpreted together with
the generated environment/provenance files.

## HTML replication log

The included `code.html` file is produced from `code.R`. To refresh a quick
HTML log, run:

```r
Sys.setenv(EXDQLM_REPLICATION_QUICK = "true")
knitr::spin("code.R", knit = TRUE)
```

For a final full refresh, run `Rscript code.R` first and then regenerate
`code.html` from the same `code.R`.

## Notes for development runs

The public replication path uses the installed `exdqlm` package. During
development only, a local package source tree can be used by setting:

```sh
EXDQLM_LOAD_MODE=source EXDQLM_PKG_PATH=/path/to/exdqlm Rscript code.R --quick
```

This is not required for reproducing the submitted materials.
