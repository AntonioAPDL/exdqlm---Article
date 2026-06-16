# Manuscript Reproducibility Protocol

This protocol describes how to regenerate and validate the article figures,
tables, diagnostics, and benchmark provenance. The public replication interface
is the top-level `code.R` script. Internal scripts in `analysis/` remain
available for targeted reruns and author-side exact-value checks.

The manuscript targets the `exdqlm` version configured in
`analysis/config/params_manuscript.yml`. For the revised submission, install the
submitted package source tarball before running the full replication.

## Public replication path

From the extracted archive:

```sh
Rscript code.R
```

This full run refits the manuscript examples, regenerates publication figures,
generated tables, logs, local caches, and manifests under
`analysis/manuscript/outputs/`, runs the manuscript tests, and prints
`sessionInfo()`.

For a shorter reviewer or collaborator check:

```sh
Rscript code.R --quick
```

The quick run checks package loading, manuscript wiring, existing generated
outputs, and the test suite without refitting all examples.

For a targeted example rerun and refit:

```sh
Rscript code.R --example 3
```

The same pattern works for examples `1`, `2`, `3`, and `4`.

Large `.rds` fit caches are author-side accelerators. They are recreated by the
full replication command when absent and should be excluded from the submitted
archive if needed to stay within upload limits.

## HTML replication log

JSS encourages an output file from the standalone replication script. For R
submissions this should be `code.html` generated with `knitr::spin("code.R")`.
A quick refresh is:

```r
Sys.setenv(EXDQLM_REPLICATION_QUICK = "true")
knitr::spin("code.R", knit = TRUE)
```

For final submission, run the full `Rscript code.R` replication first,
then refresh `code.html` from the same script.

## Randomness and backend policy

Manuscript runs set the random-number generator from
`analysis/config/params_manuscript.yml` before the configured seed is applied:

```yaml
rng:
  kind: Mersenne-Twister
  normal_kind: Inversion
  sample_kind: Rejection
```

The benchmark profile used for printed runtime values is also configured in
`params_manuscript.yml`. The current author benchmark profile records one C++ thread,
enables the C++ MCMC backend in `"fast"` mode, and keeps C++ samplers disabled.
This keeps the benchmark run auditable while still using the backend reported
in the manuscript.

Runtime values are elapsed fitting times stored in returned fit objects as
`run.time`, unless a caption explicitly says otherwise. They exclude diagnostic
calculations, plotting, table construction, manuscript rendering, and post-run
inspection.

## Manuscript code policy

The main text should show the package-facing code needed to understand each
workflow: model builders, fitting calls, diagnostics, forecasts, synthesis, and
the table/figure-producing package calls. Generic preprocessing should be
described in prose when that improves readability, with the guarded executable
implementation kept in `analysis/` and reached through `code.R`.

The displayed `CodeInput` chunks in `exdqlm-jss.tex` are curated article
excerpts. They must be readable and faithful to the canonical workflow, but
they do not need to include every cache, graphics-device, manifest, or
output-writing line from the scripts.

The traceability file `analysis/manuscript/code_chunk_map.csv` records, for
each displayed article chunk:

- the example and workflow role;
- whether the chunk is an exact snippet or a compact excerpt;
- the canonical source file(s) in `analysis/`;
- required manuscript and source-code terms;
- any figure/table target to which the chunk contributes.

The manuscript test suite parses all displayed chunks, checks map coverage,
checks required source terms, and verifies that mapped figure/table labels are
registered in the example `artifacts.yml` files.

## Author maintenance tools

Use this section when maintaining the article repository, not as the main JSS
reader path.

Before a final exact-value regeneration, run the author maintenance check with the current
R release used for the manuscript:

```sh
Rscript analysis/check_reproducibility.R --stage manuscript --profile standard --require-r-version 4.6.0
```

If using a local package checkout instead of an installed package:

```sh
EXDQLM_LOAD_MODE=source EXDQLM_PKG_PATH=/path/to/exdqlm \
  Rscript analysis/check_reproducibility.R --stage manuscript --profile standard --require-r-version 4.6.0
```

This check verifies R version, package version, git/provenance state when
available, required packages, RNG/backend policy, artifact manifests, code-chunk
traceability, diagnostic wiring, and known stale-code markers.

For targeted internal reruns, use:

```sh
Rscript analysis/run_all.R --stage manuscript --targets TARGETS --profile standard --force-refit --skip-tests
```

The final author-side full run is:

```sh
Rscript analysis/run_all.R --stage manuscript --profile standard
```

The public `Rscript code.R` command sources the same canonical example scripts
in manuscript order.

## Package test gate

Before using package outputs as article reference values, run the package tests
under the same R version used for the article:

```sh
Rscript -e 'testthat::test_local("/path/to/exdqlm", reporter = "summary")'
```

Before a release-candidate article sync, also run a package check:

```sh
cd /path/to/exdqlm
R CMD check --no-manual --run-donttest .
```

Record the R version, package commit, test/check command, and result in the
final correction notes.

## Artifact generation order

Do not run the full manuscript regeneration first when a targeted scientific or
implementation issue is known. Use this order:

1. Fix the relevant package, analysis, manuscript, or documentation source.
2. Run the narrowest affected example target.
3. Inspect generated figures/tables/logs.
4. Sync inline manuscript tables and prose from generated outputs.
5. Run manuscript tests.
6. Run the author maintenance checks.
7. Run full manuscript regeneration only after targeted checks are clean.

The optional Example 4 seed screen is explicit-only. A full standard manuscript
run regenerates the Example 4 figure/table from the configured `dataset_seed`,
but it does not redo the seed screen unless the `ex4screen` target is supplied.

## Diagnostic policy

Canonical diagnostics must use the package implementation. The article should
not use stochastic `FNN::KL.divergence()` calls or random standard-normal
reference samples in canonical examples.

CRPS is the primary predictive scoring rule for discount-factor selection in
the examples. KL is reported as a calibration/normality diagnostic for the MAP
standardized one-step-ahead forecast errors. The top-level value `KL` is the
primary quantity to report; `KL.flip` is a secondary sensitivity diagnostic,
and by-`k`/Gaussian plug-in details belong under `kl.details` rather than as
competing table columns.

Held-out forecast tables must use `exdqlmForecastDiagnostics()` on
`exdqlmForecast` objects, typically returned by `predict(..., return.draws = TRUE)`
from a fitted dynamic model. The article should not define local check-loss or
CRPS functions for manuscript forecast comparisons.

## Final acceptance criteria

A final reproducibility sync should have:

- package tests passing under R 4.6.0 or newer;
- package check passing with 0 errors, 0 warnings, and 0 notes;
- article manuscript tests passing under the same R;
- author maintenance checks with no unresolved warnings relevant to submission;
- no `From RP`, `TODO`, or `\color{magenta}` markers;
- no stale stochastic/FNN KL wiring in canonical manuscript files;
- no article-local CRPS/check-loss redefinitions for Example 3 forecast scores;
- explicit RNG and benchmark-backend provenance recorded in
  `benchmark_environment.csv`;
- manuscript figures/tables synchronized with generated outputs;
- `code.html` refreshed from the final `code.R`;
- an extracted no-git archive able to run `Rscript code.R --quick`.
