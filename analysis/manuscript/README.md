# Manuscript Reproduction Stage

This stage contains the canonical scripts used to regenerate the article's
manuscript-facing figures, generated tables, logs, caches, and artifact
manifests. For public JSS replication, use the root script first:

```sh
R CMD BATCH --vanilla code.R code.Rout
R CMD BATCH --vanilla code-fast.R code-fast.Rout
```

The full `code.R` command refits the manuscript examples, prints the numerical
tables and selected fitted-object output to `code.Rout`, and writes the graphics
stream to `Rplots.pdf`. The optional `code-fast.R` command uses reduced
computation settings for code checking and is not authoritative for manuscript
values.

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
2. Run the narrowest useful author-side target.
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

Large `.rds` fit caches are local accelerators. They are recreated by
full/example runs and should be excluded from the submitted archive if needed
to satisfy upload-size limits.

## Internal run commands

The author-side runner supports full-stage regeneration, targeted example
reruns, tests-only checks, and the optional Example 4 seed screen. These
commands are intended for repository maintenance, not for JSS reviewers. The
generated root scripts `code.R` and `code-fast.R` are the public batch
interfaces submitted with the article.

For internal maintenance, inspect the runner's help from the repository root
and choose the narrowest target that matches the intended update. Source-package
maintenance is also author-only; the submitted replication archive expects the
matching package source tarball to be installed before execution.

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
root `README.md`, the flat batch scripts `code.R` and `code-fast.R`, this
protocol family, generated tracker files, and example manifests.
