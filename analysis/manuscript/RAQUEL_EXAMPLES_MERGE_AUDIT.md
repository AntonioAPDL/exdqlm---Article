# Raquel Example Merge Audit

This document records how Raquel's review-driven example updates were merged into
the canonical manuscript workflow under `analysis/manuscript/scripts/`.

## Scope

- Keep a single source of truth for reproducible manuscript examples.
- Preserve Raquel-reviewed example intent while aligning with the current
  `exdqlm` 0.4.0 API and article wording.
- Verify that all manuscript examples and the alternative Example 3 sandbox can
  be rerun end-to-end from local source.

## Canonical Repositories

- Article repo:
  `/home/jaguir26/local/src/exdqlm---Article`
- Package repo:
  `/home/jaguir26/local/src/exdqlm__wt__0p4p0_article_main`

## Merge Provenance

- Reviewer base commit in article history:
  `aa60e6c` (`Raquels Review`)
- Follow-up issue-resolution commits integrated on top of that base:
  `e81a304`, `68b1e5c`, `ba6230d`, `38960b9`, `0537871`, `b7dde88`, `3249a61`, `e93bd9f`
- Canonical scripts that carry the merged example behavior:
  - `analysis/manuscript/scripts/00_setup.R`
  - `analysis/manuscript/scripts/01_ex1_lake_huron.R`
  - `analysis/manuscript/scripts/02_ex2_sunspots.R`
  - `analysis/manuscript/scripts/03_ex3_big_tree.R`
  - `analysis/manuscript/scripts/04a_ex4_seed_screen.R`
  - `analysis/manuscript/scripts/04_ex4_static_simulation.R`
  - `analysis/manuscript/scripts/05_tracker_and_manifest.R`

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
- Keep monthly USGS-from-daily response + package `nino34`.
- Keep manuscript Example 3 workflow isolated from alternative sandbox.

4. Example 4 (static exAL)
- Keep screen-first seed policy targeting `p0=0.50` MCMC full slope-coverage.
- Refit tracked seed outputs under current package source.

5. Alternative Example 3 sandbox
- Keep under `analysis/ex3_monthly_nino34_redo/` and rerun separately from
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
- Package source path:
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
  - Example 3 manuscript targets (`ex3data`, `ex3quantcomps`,
    `ex3quantcomps_ldvb`, `ex3zetapsi`, `ex3zetapsi_ldvb`, `ex3forecast`,
    `ex3forecast_ldvb`, `ex3tables`, `ex3tables_ldvb`)
  - Example 4 (`ex4figure`, `ex4table`)
- Completed manuscript validation pass:
  - `Rscript analysis/run_all.R --stage manuscript --pkg-path <package-path>`
- Alternative Example 3 dense sweep:
  - Initiated and partially executed, then intentionally stopped because the
    dense support-only CRPS lambda sweep is long-running and not required to
    regenerate manuscript-facing artifacts.
- Package post-rerun console-output hardening commit:
  - `ac245f1` on `work/0.4.0-article-main` (pushed).
