# Manuscript Reproducibility Protocol

This protocol defines the reference workflow for regenerating the article
figures, tables, diagnostics, and benchmark metadata.

The manuscript is intended to be reproducible from two checkouts:

- Article repository: `AntonioAPDL/exdqlm---Article`
- Package repository: `AntonioAPDL/exdqlm`

For the current article pass, the package checkout must track
`origin/feature/1.0.0-jss` and report package version `1.0.0`.

## Required Preflight

Run this before regenerating any manuscript artifacts:

```sh
EXDQLM_PKG_PATH=../exdqlm \
  /path/to/R-4.6.0/bin/Rscript \
  analysis/check_reproducibility.R --stage manuscript --profile standard --fetch --require-r-version 4.6.0
```

For final reference runs, use `--strict`. Strict mode must pass before a final
manuscript sync is committed.

The preflight checks:

- article remote, branch, commit, dirty state, and ahead/behind status;
- package remote, branch, commit, dirty state, and ahead/behind status;
- R version and actual running R/Rscript binaries;
- required R packages for the manuscript stage;
- Example 3 model data window, including the `1987-01-01` start date;
- tracked output paths in the artifact manifest;
- stale stochastic/FNN KL code or prose in canonical manuscript files;
- article-local redefinitions of held-out forecast check loss, CRPS, or
  interval-score helpers in Example 3;
- remaining Raquel Prado review markers.

## Reproducibility Modes

The article workflow has two reproducibility modes.

Portable mode is for fresh clones, Overleaf-source downloads, collaborators,
and JSS/readers on non-reference machines. It verifies that the pipeline runs,
required artifacts are generated, manifests and figure/table wiring are
coherent, package provenance is recorded, and numeric outputs are finite and
sensible. It does not require exact agreement with the manuscript's printed
runtime values or simulation-based diagnostics, because those can vary by
hardware, R runtime, compiled libraries, and backend profile.

Reference mode is the final acceptance gate on the documented benchmark
platform. It performs the portable checks and additionally requires exact
agreement between generated rounded values and the values printed in the
manuscript. Use this mode only before committing synchronized manuscript
figures, tables, and benchmark metadata.

Portable collaborator/reviewer run:

```sh
EXDQLM_PKG_PATH=../exdqlm \
  /path/to/R-4.6.0/bin/Rscript \
  code.R --profile standard --mode portable
```

Final reference-machine run:

```sh
EXDQLM_PKG_PATH=../exdqlm \
  /path/to/R-4.6.0/bin/Rscript \
  code.R --profile standard --mode reference --strict
```

## JSS HTML Replication Log

JSS encourages an output file from the standalone replication script. For R
submissions this should be `code.html` generated with `knitr::spin("code.R")`.
The safe command below uses quick portable tests-only mode, so the HTML log
checks the replication wiring without replacing publication artifacts:

```r
Sys.setenv(EXDQLM_PKG_PATH = "../exdqlm")
Sys.setenv(EXDQLM_REPRO_PROFILE = "quick")
Sys.setenv(EXDQLM_REPRO_MODE = "portable")
Sys.setenv(EXDQLM_REPRO_TESTS_ONLY = "true")
Sys.setenv(EXDQLM_SKIP_PREFLIGHT = "true")
Sys.setenv(EXDQLM_BUILDING_CODE_HTML = "true")
knitr::spin("code.R", knit = TRUE)
```

Before final submission, run the standard portable or reference command
directly, then refresh `code.html` so the reviewer-facing log reflects the
current `code.R` interface and session information.

## Manuscript Code Policy

The main article should show the package-facing code needed to understand each
workflow: model builders, fitting calls, diagnostics, forecasts, synthesis, and
the table/figure-producing package calls. Generic preprocessing should be
described in prose when doing so improves readability, with the guarded,
fully executable implementation kept in `analysis/` and reachable through
`code.R`. When preprocessing is abbreviated in the manuscript, the text should
state the data window, train/holdout split, and the generated artifact that
records the aligned data.

The source of truth for full reproduction is `code.R`, which calls
`analysis/run_all.R` and the canonical example scripts under
`analysis/manuscript/examples/`. The `CodeInput` chunks in `exdqlm-jss.tex` are
curated article excerpts. They must be readable and faithful to the canonical
workflow, but they do not need to include every cache, graphics-device,
manifest, or output-writing line from the scripts.

The traceability file `analysis/manuscript/code_chunk_map.csv` records, for
each displayed article chunk:

- the example and workflow role;
- whether the chunk is an exact snippet or a compact excerpt;
- the canonical source file(s) in `analysis/`;
- required manuscript and source-code terms;
- any figure/table target to which the chunk contributes.

The manuscript test suite parses all displayed chunks, checks the map coverage,
checks required source terms, and verifies that mapped figure/table labels are
registered in the example `artifacts.yml` files.

## Package Test Gate

Before using package outputs as article reference values, run the package tests
under the same R version used for the article:

```sh
/path/to/R-4.6.0/bin/Rscript -e \
  'testthat::test_local("../exdqlm", reporter = "summary")'
```

Before a release-candidate article sync, also run a package check:

```sh
cd ../exdqlm
/path/to/R-4.6.0/bin/Rscript -e \
  'if (!requireNamespace("rcmdcheck", quietly = TRUE)) install.packages("rcmdcheck", repos = "https://cloud.r-project.org"); rcmdcheck::rcmdcheck(args = c("--no-manual"), error_on = "warning")'
```

Record the R version, package commit, test/check command, and result in the
final correction notes.

## Artifact Generation Order

Do not run the full manuscript regeneration first when a targeted scientific or
implementation issue is known. Use this order:

1. Fix the relevant source code, manuscript prose, and documentation.
2. Run targeted example regeneration for the affected artifacts.
3. Inspect generated figures/tables/logs.
4. Sync inline manuscript tables and prose from generated outputs.
5. Run manuscript tests.
6. Run strict preflight.
7. Run full manuscript regeneration only after targeted checks are clean.

Targeted reruns use:

```sh
EXDQLM_PKG_PATH=../exdqlm \
  /path/to/R-4.6.0/bin/Rscript \
  analysis/run_all.R --stage manuscript --targets TARGETS --profile standard --force-refit --skip-tests
```

The final full run is:

```sh
EXDQLM_PKG_PATH=../exdqlm \
  /path/to/R-4.6.0/bin/Rscript \
  analysis/run_all.R --stage manuscript --profile standard
```

The top-level reader-facing wrapper is:

```sh
EXDQLM_PKG_PATH=../exdqlm \
  /path/to/R-4.6.0/bin/Rscript \
  code.R --profile standard --mode portable
```

The full run regenerates the publication-facing Example 4 simulation figure and
table from the committed `dataset_seed` in `analysis/config/params_manuscript.yml`.
It does not rerun the expensive support-only seed screen by default. To reselect
the Example 4 simulation seed, run the explicit support target:

```sh
EXDQLM_PKG_PATH=../exdqlm \
  /path/to/R-4.6.0/bin/Rscript \
  analysis/run_all.R --stage manuscript --targets ex4screen --profile standard --force-refit --skip-tests
```

After running `ex4screen`, update the configured `dataset_seed` if a different
seed is selected, then rerun `--targets ex4figure,ex4table` so the selected seed
and displayed Example 4 artifacts are synchronized.

## Diagnostic Policy

The canonical article diagnostics must use the current package implementation.
In exdqlm 1.0.0, KL diagnostics are deterministic for fixed fitted objects by
default. The article should not use stochastic `FNN::KL.divergence()` calls or
random standard-normal reference samples in canonical examples.

CRPS is the primary predictive scoring rule for discount-factor selection in
the examples. KL is reported as a calibration/normality diagnostic for the MAP
standardized one-step-ahead forecast errors. The top-level value `KL` is the
primary quantity to report; `KL.flip` is a secondary sensitivity diagnostic,
and by-`k`/Gaussian plug-in details belong under `kl.details` rather than as
competing table columns.

Held-out forecast tables must use `exdqlmForecastDiagnostics()` on
`exdqlmForecast(..., return.draws = TRUE)` objects. The article should not
define local check-loss or CRPS functions for manuscript forecast comparisons.

## Runtime Policy

Unless a caption explicitly says otherwise, runtime means model-fitting elapsed
time stored in returned fit objects as `run.time`.

Reported runtime excludes:

- diagnostic calculations;
- plotting;
- table construction;
- manuscript rendering;
- post-run inspection.

Runtime values are reference timings for the recorded machine/profile, not
machine-independent constants. The file
`analysis/manuscript/outputs/tables/benchmark_environment.csv` records CPU, OS,
R binary, package/article commits, backend options, seeds, and dataset sizes for
the run.

## Randomness and Backend Policy

Manuscript runs set the random-number generator from
`analysis/config/params_manuscript.yml` before the configured seed is applied:

```yaml
rng:
  kind: Mersenne-Twister
  normal_kind: Inversion
  sample_kind: Rejection
```

The benchmark profile used for printed runtime values is Profile B. It records
`exdqlm.cpp_threads = 1L`, enables the C++ MCMC backend in `"fast"` mode, and
keeps C++ samplers disabled. This profile is intended to make the reference
run stable and auditable while still reflecting the backend used for the
manuscript timings.

Portable runs should reproduce the workflow and coherent numerical summaries.
Exact trace paths, elapsed runtimes, and some simulation-based summaries may
differ across operating systems, compilers, BLAS/LAPACK builds, and hardware.
The reference run is the only run expected to match the printed rounded
manuscript values exactly.

## Final Acceptance Criteria

A final reproducibility sync should have:

- package tests passing under R 4.6.0 or newer;
- article manuscript tests passing under the same R;
- strict preflight with zero errors and no unresolved warnings;
- no `From RP` or `\color{magenta}` markers;
- no stale stochastic/FNN KL wiring in canonical manuscript files;
- no article-local CRPS/check-loss redefinitions for Example 3 forecast scores;
- explicit RNG and benchmark-backend provenance recorded in
  `benchmark_environment.csv`;
- all tracked artifact paths present or explicitly marked obsolete with a clear
  manifest update;
- all manuscript figures/tables traceable to scripts and generated outputs;
- benchmark/runtime captions consistent with the runtime policy above.
