# Manuscript Plot Polish Checklist

This checklist tracks the final figure/table polish pass requested after the
main Example 1--4 workflow was made canonical and reproducible. The goal is to
improve readability without changing the statistical specifications unless a
plot review reveals a genuine mismatch between the manuscript, script, and
generated artifact.

## Working Rules

- Edit the canonical scripts under `analysis/manuscript/examples/`; do not
  manually edit generated figures.
- Keep each plot change scoped to one figure or one tightly related figure set.
- Regenerate the narrowest useful target first, inspect the figure, then run the
  full manuscript workflow before committing.
- If a figure caption or displayed code chunk changes, update `article4.tex` in
  the same commit.
- If a generated artifact note needs to change, update the corresponding
  `register_artifact()` call in the example script and regenerate the tracker.
- Keep article-side review notes out of submission-facing text once the
  corresponding edits are accepted.
- Apply the manuscript prose rules in `WRITING_STYLE_CHECKLIST.md` whenever a
  plot/table edit also changes article text, captions, or displayed code.
- Commit scripts, regenerated figures/tables, PDF/log, and tracker updates
  together so the repo remains reproducible at every pushed commit.

## Review Criteria

- Captions accurately describe the figure content, model specification, plotted
  time window, colors, line types, and interval type.
- Axis labels and legends are readable at manuscript scale.
- Panels use consistent typography, margins, and label placement.
- Colors distinguish model objects clearly while staying visually restrained.
- Figure windows do not contain avoidable white space or clipped content.
- Legends avoid covering the main scientific signal.
- Tables use consistent rounding, labels, and row/column descriptions.
- The article text, displayed code, generated artifact, and reproducibility
  tracker all agree.

## Figure Queue

### Example 1: Lake Huron

- [x] `fig:ex1mcmc` / `ex1mcmc.png`
  - Current status: regenerated from the dedicated median MCMC trace run.
  - Polish focus: trace readability, density labels, and caption consistency.
- [x] `fig:ex1quants` / `ex1quants.png`
  - Current status: forecast synthesis band darkened and synthesis legend moved
    to the bottom-left.
  - Polish focus: keep the observed and forecast synthesis bands visually
    distinct without distracting from the data.
- [x] support `ex1synth.png`
  - Current status: same synthesis color/legend treatment as the manuscript
    panel.

### Example 2: Sunspots

- [ ] `fig:ex2quant` / `ex2quant.png`
  - Polish focus: panel balance, labels, gamma histogram readability, and
    color/legend consistency between DQLM and exDQLM.
- [ ] `fig:ex2checks` / `ex2checks.png`
  - Polish focus: diagnostic panel labels, ACF/QQ readability, and consistent
    ordering for DQLM versus exDQLM.
- [ ] Support LDVB figures
  - Polish focus: make support-only artifacts readable enough for review while
    keeping manuscript-facing figures primary.

### Example 3: Big Tree

- [ ] `fig:ex3data` / `ex3data.png`
  - Polish focus: log-flow and climate-index labels, date axis readability, and
    color clarity for NOI/AMO.
- [ ] `fig:ex3quant` / `ex3quantcomps.png`
  - Polish focus: align caption with the three displayed panels, reduce clutter,
    and make model colors/intervals easy to distinguish.
- [ ] `fig:ex3tftheta` / `ex3zetapsi.png`
  - Current status: transfer-state layout uses the 2x2 structure requested for
    zeta, NOI, and AMO.
  - Polish focus: confirm y-limits, labels, zero-reference lines, and spacing.
- [ ] `fig:ex3forecast` / `ex3forecast.png`
  - Polish focus: forecast-origin clarity, model distinction, and caption
    agreement with the forecast horizon and plotted window.

### Example 4: Static exAL

- [ ] `fig:ex4static` / `ex4static.png`
  - Polish focus: coefficient labels, interval readability, and whether the
    three quantile panels are visually balanced.

## Table Queue

- [x] Introductory software-positioning table
  - Current status: Table 1 was rewritten and re-audited cell-by-cell against
    package documentation and CRAN metadata for the representative
    quantile/state-space packages, with columns aligned to the manuscript's
    positioning argument.
  - Polish focus: placement, acronym clarity, and readable contrast between
    general quantile-regression software, state-space software, and
    `exdqlm`.
- [ ] Example 2 benchmark/diagnostic tables
  - Confirm rounding, labels, and manuscript text match generated CSV files.
- [ ] Example 3 diagnostics/lambda tables
  - Confirm lambda selection and diagnostic values match generated CSV files.
- [ ] Example 4 static summary table
  - Confirm runtime/recovery metrics and seed-screen explanation match generated
    outputs.
- [ ] Backend/profile appendix table
  - Confirm placement, labels, and references remain correct after final figure
    edits.

## Suggested Order

1. Example 1 final visual confirmation.
2. Example 3 figures, because they changed most recently and carry the highest
   reviewer/context risk.
3. Example 2 figures and tables.
4. Example 4 figure and table.
5. Global caption and prose-style pass using `WRITING_STYLE_CHECKLIST.md`.
6. Full manuscript workflow and `pdflatex` validation.

## Validation Commands

Targeted figure rerun:

```bash
Rscript analysis/run_all.R --stage manuscript --targets <target> --profile standard --skip-tests
```

Full manuscript validation:

```bash
Rscript analysis/run_all.R --stage manuscript --profile standard
pdflatex -interaction=nonstopmode article4.tex
pdflatex -interaction=nonstopmode article4.tex
pdflatex -interaction=nonstopmode article4.tex
```
