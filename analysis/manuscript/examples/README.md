# Canonical Manuscript Examples

This directory is the canonical, collaborator-facing source for the four
examples shown in `article4.tex`.

Each example has its own folder with:

- `run.R`: the executable workflow for that example.
- `config.yml`: a compact map of editable settings and useful run commands.
- `artifacts.yml`: the figures, tables, and logs that the example produces.
- `README.md`: short guidance for editing and validating the example.

The generated manuscript-facing artifacts are intentionally still written to the
shared output folders:

- `analysis/manuscript/outputs/figures/`
- `analysis/manuscript/outputs/tables/`
- `analysis/manuscript/outputs/logs/`
- `analysis/manuscript/outputs/cache/`

Keeping output filenames stable lets `article4.tex` remain simple:
`\graphicspath` points to `analysis/manuscript/outputs/figures/`, and the
article includes figures by filename only.

## Editing Rules

1. Edit only the relevant example folder when changing an example.
2. Keep manuscript-facing output filenames stable unless `article4.tex` is
   updated in the same commit.
3. Update the example's `artifacts.yml` if a figure, table, or log is added,
   removed, or renamed.
4. Rerun the narrowest useful target before committing.

## Common Commands

From the article repository root:

```bash
Rscript analysis/run_all.R --stage manuscript --targets ex1 --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2 --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3 --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex4 --skip-tests
Rscript analysis/run_all.R --stage manuscript --tests-only
```

Use `--profile quick` for smoke checks and `--profile standard` for
manuscript-facing regeneration.
