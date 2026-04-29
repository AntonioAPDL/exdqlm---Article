# Manuscript Writing Style Checklist

This checklist is the standing prose-quality standard for changes to
`article4.tex`, table captions, figure captions, displayed code explanations,
and manuscript-facing example text. It is intended to keep edits consistent with
a submission-ready JSS software article: neutral, factual, readable, and aligned
with the current package and reproducible analysis workflow.

## Target Voice

- Write for a statistically trained reader who may be new to `exdqlm`, not for
  the local development team.
- Use neutral, factual, precise language. Avoid hype, informal asides,
  reviewer-facing explanations, or subjective labels such as "boring",
  "interesting", or "better" unless the claim is defined by a reported metric.
- Prefer direct software-paper prose: introduce the data or task, state the
  model specification, name the package function or workflow being illustrated,
  and interpret the resulting figure or table.
- Keep interpretation restrained. The examples illustrate package workflows;
  they are not presented as standalone scientific studies.

## Claim Discipline

- Every software, methodological, or numerical claim must be true for the
  current package state and reproducible from the printed code, generated
  artifacts, tables, figures, or cited documentation.
- Do not overstate comparisons with other packages or methods. Prefer factual
  verbs such as "provides", "supports", "implements", "uses", and "reports".
- When comparing fitted models, state the metric and direction of preference
  explicitly. Avoid vague claims such as "performs well" unless the relevant
  table or figure defines what "well" means.
- Treat timing results as hardware- and profile-dependent. Put exact runtime
  values in generated tables or reproducibility artifacts; use rounded or
  qualitative runtime statements in prose only when they help the reader.

## Detail Level

- Keep submission-facing prose focused on reader-facing information. Move branch
  names, cache keys, seed-screen rationale, troubleshooting history, and local
  audit notes to analysis READMEs, trackers, or support artifacts.
- Use exact numerical values only when they are part of the model
  specification, displayed output, or necessary interpretation. Otherwise round
  to the precision needed for understanding.
- Explain why a modeling choice matters for the example workflow, not why it was
  chosen during local development.
- Avoid redundancy. If a function, metric, or diagnostic is defined once, later
  examples should refer back to it and add only example-specific information.

## Terminology and Notation

- Use function names with parentheses in prose, for example `exdqlmLDVB()`.
  Reserve class/object names without parentheses for returned objects.
- Use `VB` in reader-facing prose for the broad approximate-inference strategy.
  Use `LDVB` when referring to the specific Laplace-Delta routine or a literal
  function name.
- Keep notation aligned with the manuscript: use \(p_0\) for the target
  quantile, \(\boldsymbol{\theta}_t\) for dynamic states, and
  \(\sigma,\gamma\) for scale and skewness parameters.
- Define model labels once within each example and reuse them consistently in
  text, captions, figures, and tables.

## Example-Section Pattern

- Start each example by naming the dataset, modeling goal, target quantile(s),
  and package feature being illustrated.
- Present model construction before inference controls. Present diagnostics and
  interpretation only after the fitted objects and comparisons are defined.
- Make captions self-contained: describe what is plotted, the model labels or
  colors, the interval type, and any displayed time window or holdout period.
- Keep displayed code pedagogical. It should show how a reader would use the
  package, not expose local scaffolding that only exists to manage the article
  repository.

## Final Prose Gate

Before committing a manuscript-facing prose change, confirm that:

- The text can be understood without knowing our email thread, branch history,
  local cache names, or debugging process.
- The prose, displayed code, captions, generated artifacts, and tables describe
  the same model specification.
- No unresolved review notes, internal comments, or local-audit language remain
  in submission-facing text.
- The change is polished enough that it could be submitted as-is if the rest of
  the manuscript were ready.
