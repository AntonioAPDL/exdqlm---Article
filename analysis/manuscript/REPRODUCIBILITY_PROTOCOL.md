# Manuscript Reproducibility Protocol

This protocol describes the public replication contract for the JSS submission
and the author-side checks used to maintain it.

## Public replication path

The submitted replication archive should be runnable without Git metadata,
local package paths, or author-side fit files. Install the submitted package
source tarball first:

```sh
R CMD INSTALL exdqlm_1.1.1.tar.gz
```

Then run the full manuscript replication:

```sh
OMP_NUM_THREADS=1 \
OMP_THREAD_LIMIT=1 \
OPENBLAS_NUM_THREADS=1 \
MKL_NUM_THREADS=1 \
BLIS_NUM_THREADS=1 \
VECLIB_MAXIMUM_THREADS=1 \
R CMD BATCH --vanilla code.R code.Rout
```

The full script refits the examples, regenerates figures and tables, prints the
manuscript tables and selected fitted-object output, writes `Rplots.pdf`, and
prints `sessionInfo()`. This is the only public R script in the JSS replication
archive.

## Randomness and backend policy

The public script sets:

```r
RNGversion("4.6.0")
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
```

The script also requires `exdqlm` version 1.1.1 at load time. The package patch
for 1.1.1 makes compiled stochastic helper paths use serial R-controlled RNG
streams, avoiding OpenMP worker RNG calls and wall-clock/thread-indexed seeds.
The same patch uses the stabilized exAL scale-skewness defaults exercised by
the manuscript rerun: an exact scale-collapsed gamma update for MCMC and a
structured `q(gamma) q(sigma | gamma)` factor for LDVB.

The thread environment variables are set before R starts so BLAS/OpenMP
configuration is visible to the full R session. Runtime values are expected to
depend on the machine; the manuscript reports the reference environment used for
the generated tables.

## Generated outputs

The full script writes:

- `code.Rout`
- `Rplots.pdf`
- `figures/*.png`
- `tables/*.csv`
- `logs/*.txt`

The batch output includes `M95`, `summary(M95)`, `MTF$median.kt`, Tables 7--10,
and `sessionInfo()`.

## Author-side maintenance

The repository keeps modular source files under `analysis/` and the generator
`tools/build-jss-replication-scripts.R` to make `code.R` maintainable. These
development files are not the public execution interface.

Before resubmission, the required author checks are:

- package test suite and `R CMD check` for `exdqlm_1.1.1.tar.gz`;
- `R CMD BATCH --vanilla code.R code.Rout`;
- manuscript and response compilation;
- archive extraction in a directory without Git metadata, followed by the
  README command or a parse-and-output check when a full second run is
  impractical.
