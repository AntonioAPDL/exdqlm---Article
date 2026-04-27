# Raquel Example Merge Audit

This document records how Raquel's review-driven example updates were merged into
the canonical manuscript workflow under `analysis/manuscript/examples/`.

## Scope

- Keep a single source of truth for reproducible manuscript examples.
- Preserve Raquel-reviewed example intent while aligning with the current
  `exdqlm` 0.4.0 API and article wording.
- Verify that all manuscript examples and the alternative Example 3 sandbox can
  be rerun end-to-end from local source.

## Canonical Workflow Decision

As of the April 26 review pass, the canonical paper-example workflow is the
article repository's `analysis/manuscript/examples/` stage, run through
`analysis/run_all.R --stage manuscript`. Separate collaborator scripts, such as
temporary `examples.R` files, are not maintained as parallel sources of truth.
They should be used as review input and merged into the canonical scripts before
the corresponding figures, tables, logs, and manuscript text are regenerated.

This decision is intended to keep the article text, displayed code chunks,
tracked figures, inline tables, generated CSV/log outputs, and reproducibility
tracker synchronized. Small machine-to-machine numerical differences can still
occur because of runtime, backend, and random-number differences, but those
differences should be handled by rerunning the same canonical scripts rather than
by maintaining separate example workflows.

## Canonical Repositories

- Article repo:
  `/home/jaguir26/local/src/exdqlm---Article`
- Package repo for the current CRAN-facing branch:
  `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile`
- Package branch:
  `cransub/0.4.0`

## Merge Provenance

- Reviewer base commit in article history:
  `aa60e6c` (`Raquels Review`)
- Follow-up issue-resolution commits integrated on top of that base:
  `e81a304`, `68b1e5c`, `ba6230d`, `38960b9`, `0537871`, `b7dde88`, `3249a61`, `e93bd9f`
- Canonical scripts that carry the merged example behavior:
  - `analysis/lib/manuscript_setup.R`
  - `analysis/manuscript/examples/ex1_lake_huron/run.R`
  - `analysis/manuscript/examples/ex2_sunspots/run.R`
  - `analysis/manuscript/examples/ex3_big_tree/run.R`
  - `analysis/manuscript/examples/ex4_static/seed_screen.R`
  - `analysis/manuscript/examples/ex4_static/run.R`
  - `analysis/manuscript/examples/_manifest/run.R`

## Merge Decisions by Example

1. Example 1 (Lake Huron)
- Keep manuscript figure flow and update calls to object-based synthesis /
  forecast draws (`quantileSynthesis()` + `exdqlmForecast(..., return.draws=TRUE)`).
- Keep dedicated median trace run for Figure `fig:ex1mcmc` and align narrative to
  tracked reproducibility logs.

2. Example 2 (Sunspots)
- Keep LDVB and MCMC support only.
- Exclude ISVB comparison artifacts from manuscript workflow.

3. Example 3 (manuscript)
- Keep observed monthly USGS Big Tree flow and replace the weak `nino34`-only
  manuscript example with a small climate-index specification chosen from the
  broader screened index set.
- Keep precipitation and soil moisture out of the manuscript-facing example to
  avoid overlap with the separate river-dynamics analysis.
- Keep manuscript Example 3 workflow isolated from alternative sandbox.

4. Example 4 (static exAL)
- Keep screen-first seed policy targeting `p0=0.50` MCMC full slope-coverage.
- Refit tracked seed outputs under current package source.

5. Alternative Example 3 sandbox
- Keep under `analysis/support/ex3_monthly_nino34_redo/` and rerun separately from
  manuscript examples.

## Verification Checklist

- Package pre-test baseline executed before integration.
- Package post-change regression tests executed after integration, including
  console-progress contract tests.
- Manuscript stage relaunch executed through
  `analysis/manuscript/run_overnight_relaunch.sh`.
- Tracker consistency test executed:
  `analysis/manuscript/tests/test-manuscript-tracker.R`.

## Live Relaunch Record (Current Pass)

- Run directory:
  `analysis/manuscript/outputs/logs/overnight_relaunch_20260425_042122`
- Historical package source path used in that launch:
  `/home/jaguir26/local/src/exdqlm__wt__0p4p0_article_main`
- Package HEAD at launch:
  `fe7f1ed`
- Status:
  `completed` for manuscript examples (Ex1, Ex2, Ex3, Ex4) and manuscript
  validation.

## Relaunch Outcome Summary (2026-04-25)

- Completed and regenerated locally (main manuscript):
  - Example 1 (`ex1mcmc`, `ex1quants`, `ex1synth`)
  - Example 2 (`ex2quant`, `ex2quant_ldvb`, `ex2checks`, `ex2checks_ldvb`,
    `ex2_ldvb_diagnostics`, `ex2tables`, `ex2tables_ldvb`, `ex2bench`)
  - Example 3 manuscript targets (`ex3data`, `ex3quantcomps`, `ex3zetapsi`,
    `ex3forecast`, `ex3tables`). Legacy `_ldvb` target aliases now route to
    these canonical LDVB artifacts rather than producing duplicate files.
  - Example 4 (`ex4figure`, `ex4table`)
- Completed manuscript validation pass:
  - `Rscript analysis/run_all.R --stage manuscript --pkg-path <package-path>`
- Alternative Example 3 dense sweep:
  - Initiated and partially executed, then intentionally stopped because the
    dense support-only CRPS lambda sweep is long-running and not required to
    regenerate manuscript-facing artifacts.
- Package post-rerun console-output hardening commit:
  - `ac245f1` on `work/0.4.0-article-main` (pushed).
