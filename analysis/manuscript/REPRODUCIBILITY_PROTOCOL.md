# Manuscript Reproducibility Protocol

This protocol defines the reference workflow for regenerating the article
figures, tables, diagnostics, and benchmark metadata.

The manuscript is intended to be reproducible from two checkouts:

- Article repository: `AntonioAPDL/exdqlm---Article`
- Package repository: `AntonioAPDL/exdqlm`

For the current article pass, the package checkout must track
`origin/feature/0.5.0-crps-iqs` and report package version `0.5.0.9000`.

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
- remaining Raquel Prado review markers.

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
In exdqlm 0.5.0, KL diagnostics are deterministic for fixed fitted objects by
default. The article should not use stochastic `FNN::KL.divergence()` calls or
random standard-normal reference samples in canonical examples.

CRPS is the primary predictive scoring rule for discount-factor selection in
the examples. KL is reported as a calibration/normality diagnostic for the MAP
standardized one-step-ahead forecast errors.

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

## Final Acceptance Criteria

A final reproducibility sync should have:

- package tests passing under R 4.6.0 or newer;
- article manuscript tests passing under the same R;
- strict preflight with zero errors and no unresolved warnings;
- no `From RP` or `\color{magenta}` markers;
- no stale stochastic/FNN KL wiring in canonical manuscript files;
- all tracked artifact paths present or explicitly marked obsolete with a clear
  manifest update;
- all manuscript figures/tables traceable to scripts and generated outputs;
- benchmark/runtime captions consistent with the runtime policy above.
