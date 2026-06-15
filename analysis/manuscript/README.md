# Manuscript Reproduction Stage

This stage contains the canonical scripts used to regenerate the article's
manuscript-facing figures, generated tables, logs, caches, and artifact
manifests. For public JSS replication, use the root script first:

```sh
Rscript code.R
Rscript code.R --quick
Rscript code.R --example 3
```

The commands below are internal maintenance commands for targeted reruns and
final reference checks.

## Canonical example workflow

The maintained example scripts live under:

- `examples/ex1_lake_huron/`
- `examples/ex2_sunspots/`
- `examples/ex3_big_tree/`
- `examples/ex4_static/`

Each folder contains a `run.R`, short documentation, configuration notes, and
an `artifacts.yml` manifest. Shared setup and helper infrastructure lives in
`analysis/lib/manuscript_setup.R`.

When updating an example:

1. Edit the relevant script in `analysis/manuscript/examples/`.
2. Run the narrowest useful target with `analysis/run_all.R`.
3. Inspect generated figures/tables/logs.
4. Update any inline manuscript table/text from generated outputs.
5. Run manuscript tests or a focused validation pass.
6. Commit the script, regenerated artifacts, manuscript text, and tracker
   updates together.

## Scope

- Rebuilds Example 1 Lake Huron figures and synthesis outputs.
- Rebuilds Example 2 Sunspots figures, diagnostics, benchmark table, and
  discount-factor scan outputs.
- Rebuilds Example 3 Big Tree figures, package diagnostic table, and held-out
  forecast-score table.
- Rebuilds Example 4 sparse static exAL simulation figure and summary table.
- Writes the reproducibility tracker, run notes, backend-profile table, and
  benchmark-environment table.

Optional developer targets can regenerate support artifacts such as the
Example 1 kernel comparison or the Example 4 seed screen.

## Internal run commands

From the repository root:

```sh
Rscript analysis/run_all.R --stage manuscript --profile standard
```

Useful targeted variants:

```sh
Rscript analysis/run_all.R --stage manuscript --profile quick
Rscript analysis/run_all.R --stage manuscript --tests-only
Rscript analysis/run_all.R --stage manuscript --targets ex1 --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2 --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3 --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex4 --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex4screen --profile standard --force-refit --skip-tests
```

For local source-package maintenance:

```sh
EXDQLM_LOAD_MODE=source EXDQLM_PKG_PATH=/path/to/exdqlm \
  Rscript analysis/run_all.R --stage manuscript --tests-only
```

The optional Example 4 seed screen is intentionally explicit-only. A full
standard manuscript run regenerates the Example 4 figure/table from the
configured `dataset_seed`, but does not redo the seed screen unless the
`ex4screen` target is supplied.

## Outputs

- `outputs/figures/`: generated manuscript figure files.
- `outputs/tables/`: diagnostics summaries, generated tables, tracker files,
  backend profile, and benchmark environment.
- `outputs/logs/`: compact textual outputs and session metadata.
- `outputs/cache/`: cached fitted objects supporting fast targeted reruns.

Figures cited by `exdqlm-jss.tex` are resolved from
`analysis/manuscript/outputs/figures/` through the manuscript `\graphicspath`.
Tables in `exdqlm-jss.tex` are inline LaTeX, so displayed values must be
updated from generated CSV/log files whenever a model is rerun.

Internal development checklists and review-audit notes are intentionally not
part of the submission archive. The maintained reader-facing provenance is the
root `README.md`, `code.R`, `code.html`, this protocol family, the code chunk
map, generated tracker files, and example manifests.
