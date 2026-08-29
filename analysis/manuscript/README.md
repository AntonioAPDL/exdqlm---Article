# Manuscript Reproduction Stage

This stage contains the maintained scripts used to regenerate the article's
manuscript-facing figures, tables, logs, and run manifests. For public JSS
replication, use the root script first:

```sh
R CMD BATCH --vanilla code.R code.Rout
```

The root `code.R` command refits the manuscript examples, prints the numerical
tables and selected fitted-object output to `code.Rout`, and writes the graphics
stream to `Rplots.pdf`.

The commands below are internal maintenance commands for focused reruns and
final reference checks.

## Maintained example workflow

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
3. Inspect generated figures, tables, and logs.
4. Update any inline manuscript table or text from generated outputs.
5. Run manuscript tests or a focused validation pass.
6. Commit the script, regenerated outputs, manuscript text, and tracker updates
   together.

## Scope

- Rebuilds Example 1 Lake Huron figures and synthesis outputs.
- Rebuilds Example 2 Sunspots figures, diagnostics, benchmark table, and
  discount-factor scan outputs.
- Rebuilds Example 3 Big Tree figures, package diagnostic table, and held-out
  forecast-score table.
- Rebuilds Example 4 sparse static exAL simulation figure and summary table.
- Writes run notes, benchmark-setting information, and benchmark-environment
  information.

Optional developer targets can regenerate support outputs such as the Example 1
kernel comparison.

Large saved fit files are local accelerators. They are recreated by full or
focused runs and should be excluded from the submitted archive if needed to
satisfy upload-size limits.

## Internal run commands

The author-side runner supports full-stage regeneration, focused example
reruns, and tests-only checks. These commands are intended for repository
maintenance, not for JSS reviewers. The generated root script `code.R` is the
public batch interface submitted with the article.

For internal maintenance, inspect the runner's help from the repository root and
choose the narrowest target that matches the intended update. Source-package
maintenance is also author-only; the submitted replication archive expects the
matching package source tarball to be installed before execution.

## Outputs

- `outputs/figures/`: generated manuscript figure files tracked for manuscript
  compilation.
- `outputs/tables/`: diagnostics summaries, generated tables, tracker files,
  benchmark settings, and benchmark environment.
- `outputs/logs/`: compact textual outputs and session metadata.
- `outputs/cache/`: local saved fit files supporting focused author-side reruns.

Figures cited by `exdqlm-jss.tex` are resolved from the root `figures/` folder
when the public script has just been run, with
`analysis/manuscript/outputs/figures/` retained as the tracked manuscript-source
fallback.

Internal development checklists and review-audit notes are intentionally not
part of the submission archive. The maintained reader-facing provenance is the
root `README.md`, the flat batch script `code.R`, this protocol family,
generated tracker files, and example manifests.
