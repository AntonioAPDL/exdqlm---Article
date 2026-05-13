# exdqlm Article Reproducibility

This repository contains the reproducible manuscript materials for the
`exdqlm` article: LaTeX source, figures, tables, analysis scripts, tests, and
supporting audit material.

The article is intended to be run against the companion package repository:

- Article repo: `AntonioAPDL/exdqlm---Article`
- Package repo: `AntonioAPDL/exdqlm`
- Current package branch for this article work: `feature/0.5.0-crps-iqs`

## Quick Start

Clone the article and package repositories next to each other:

```sh
git clone https://github.com/AntonioAPDL/exdqlm---Article.git
git clone --branch feature/0.5.0-crps-iqs https://github.com/AntonioAPDL/exdqlm.git
cd exdqlm---Article
```

Run the read-only preflight check:

```sh
EXDQLM_PKG_PATH=../exdqlm Rscript analysis/check_reproducibility.R
```

Before regenerating any examples, refresh remote refs and require both the local
package checkout and R runtime to be current. As of 2026-05-13, the current
official R release is R 4.6.0, so final reference runs should use at least that
version:

```sh
EXDQLM_PKG_PATH=../exdqlm Rscript analysis/check_reproducibility.R --fetch --strict --require-r-version 4.6.0
```

Run the cheap manuscript structure/tests pass:

```sh
EXDQLM_PKG_PATH=../exdqlm Rscript analysis/run_all.R --stage manuscript --tests-only
```

## Package Loading Modes

Source mode is the default. The article workflow tries, in order:

1. `--pkg-path /path/to/exdqlm`
2. `EXDQLM_PKG_PATH=/path/to/exdqlm`
3. common sibling checkout names such as `../exdqlm`

Example:

```sh
Rscript analysis/run_all.R --stage manuscript --pkg-path ../exdqlm --tests-only
```

Installed-package mode is also supported:

```sh
EXDQLM_LOAD_MODE=installed Rscript analysis/check_reproducibility.R
EXDQLM_LOAD_MODE=installed Rscript analysis/run_all.R --stage manuscript --tests-only
```

Use `EXDQLM_INSTALLED_LIB=/path/to/R/library` if the installed package lives in
a non-default R library.

## Main Workflows

The manuscript-facing analysis lives under `analysis/manuscript/examples/` and
is orchestrated by `analysis/run_all.R`.

Cheap checks:

```sh
Rscript analysis/check_reproducibility.R
Rscript analysis/run_all.R --stage manuscript --tests-only
```

Targeted regeneration:

```sh
EXDQLM_PKG_PATH=../exdqlm Rscript analysis/run_all.R --stage manuscript --targets ex2checks --profile standard --skip-tests
```

Full manuscript regeneration can be expensive:

```sh
EXDQLM_PKG_PATH=../exdqlm Rscript analysis/run_all.R --stage manuscript --profile standard
```

## Outputs

Generated manuscript artifacts are written under:

- `analysis/manuscript/outputs/figures/`
- `analysis/manuscript/outputs/tables/`
- `analysis/manuscript/outputs/logs/`
- `analysis/manuscript/outputs/cache/`

The article LaTeX file reads figures from
`analysis/manuscript/outputs/figures/`. Tables in `exdqlm-jss.tex` are inline
LaTeX and must be synchronized from generated CSV/log outputs after reruns.

## Reproducibility Notes

- `analysis/check_reproducibility.R` is read-only unless `--fetch` is supplied
  and should be the first command run in a fresh clone. Use `--fetch --strict`
  with `--require-r-version` before regenerating examples so stale package
  checkouts or stale R runtimes are caught before expensive relaunches.
- `analysis/manuscript/outputs/tables/manuscript_repro_tracker.csv` maps tracked
  artifacts to manuscript targets.
- Runtime values are hardware-, R-version-, backend-, and profile-dependent.
  Benchmark provenance is recorded in
  `analysis/manuscript/outputs/tables/benchmark_environment.csv`.
- Support workflows under `analysis/support/` are retained for audit/history;
  they are not the canonical source of manuscript figures and tables.
