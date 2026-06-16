# exdqlm JSS Resubmission: Coauthor Review Summary

Date: 2026-06-16

Article repository: this Overleaf/Git repository.

Package repository: the companion `exdqlm` R package repository.

Article commit before adding these coauthor-review files:
`556e79fb7b3d8b10a5ced07c41ec098df96e8b9a`

Package commit used for the revised `1.1.0` software source:
`1b2bc3583be3b1c6fe8eae4b60a375b5762e764e`

Package version: `1.1.0`

## Executive Summary

The revised submission addresses the JSS editorial return at the manuscript,
package, and replication-material levels. The main changes are:

- the manuscript now states the software contribution more explicitly relative
  to the prior methodology;
- the article contains a new package design and implementation section;
- the package has a clearer S3 class/method layer for fitted objects,
  diagnostics, forecasts, synthesis, and static diagnostics;
- the replication materials are standalone and centered on `code.R`;
- the previous supplement has been merged into the main manuscript as
  appendices;
- the response-to-editor document gives a point-by-point reply; and
- the final submission bundle contains the manuscript PDF, package source tarball,
  replication archive, and response PDF.

For coauthor review, a separate marked manuscript was created:

- `exdqlm-jss-coauthor-review.tex`
- `exdqlm-jss-coauthor-review.pdf`

The blue boxes in that PDF identify the main regions revised after the JSS
return. The clean submission manuscript remains:

- `exdqlm-jss.tex`
- `exdqlm-jss.pdf`

The coauthor-review file is only for internal review and should not be uploaded
to JSS.

## Baseline Used for This Summary

The rejection comments do not record an exact article commit hash for the first
submitted version. The comments clearly refer to the first JSS submission that
used package version `1.0.0`, the old `code.R --profile ... --mode ...`
interface, a Git-dependent preflight check, and a separate supplementary PDF.
This summary therefore treats that first JSS submission state as the baseline,
and the current article/package state as the revised resubmission state.

## JSS Comment-by-Comment Summary

| ID | JSS/editor issue | Current resolution | Coauthor review focus |
| --- | --- | --- | --- |
| G1 | Contribution relative to prior methodology was unclear. | Introduction and conclusion now separate prior methodology from the JSS software contribution. | Check whether the contribution framing is scientifically accurate and not overstated. |
| G2 | Replication materials were hard to use. | Public workflow is now centered on `Rscript code.R`, with `--quick` and `--example N` options. | Check whether the README/code.R workflow is clear enough for a reader. |
| D1 | README referred to GitHub; JSS wanted standalone materials. | Replication archive is no-Git, standalone, and installable from the package tarball. | Check whether the replication README is concise and clear. |
| D2 | `code.R` launched another master script. | `code.R` now directly orchestrates the manuscript examples. | Mostly resolved mechanically. |
| D3 | Too many unclear modes, especially portable/reference. | Public options were simplified; internal reference checks are not part of the reader workflow. | Check whether the distinction between public replication and internal checks is clear. |
| D4 | `main()` made intermediate analysis hard to inspect. | `code.R` is now a commented replication script with direct sourcing of example scripts. | Check whether this is readable enough for JSS. |
| D5 | Public command failed outside a Git checkout. | Public replication no longer requires Git metadata; no-Git archive tests pass. | No substantive scientific review needed. |
| D6 | Manuscript lacked package design and implementation section. | Added Section 4 on package design, object families, methods, backends, and workflow table. | Important: review Section 4 and Table 2 carefully. |
| D7 | Print/summary methods should be more informative. | Package now has richer `print()`/`summary()` methods and tests. | Check whether manuscript description is adequate. |
| D8 | Class inheritance was unclear. | Dynamic fits inherit from `exdqlmFit`; static fits inherit from `exalStaticFit`. | Check whether this design explanation is understandable. |
| D9 | Post-processing should use methods where natural. | Added/clarified `plot()` and `predict()` workflows; constructors remain named when extra inputs are needed. | Check whether this compromise is well explained. |
| D10 | Diagnostics should visibly return objects and use `plot()`. | Diagnostic and forecast diagnostic functions return visible objects with methods. | Check Examples 2--4 for clarity. |
| D11 | Single PDF; supplement should be appendices. | Former supplement is now `exdqlm-appendix.tex`, included in the main PDF as Appendices A--J. | Check appendix integration and whether appendix length/content is acceptable. |
| S1 | Software/source/license/submission bundle alignment. | Package source is `exdqlm_1.1.0.tar.gz`, MIT licensed, and the replication archive is below the upload limit. | No scientific review needed. |

## Main Article Changes

Major revised areas:

1. **Introduction and software comparison**
   - Clarified that the exAL family and exDQLM model come from prior work.
   - Positioned this article as a software paper: implementation, API, object
     design, diagnostics, examples, and reproducibility.
   - Expanded the software comparison table to distinguish static quantile
     regression, time-as-predictor regression, Gaussian state-space models, and
     quantile latent-state workflows.

2. **Model diagnostics and forecasting**
   - Clarified deterministic KL diagnostics.
   - CRPS is now described as the package-level integrated quantile-score
     approximation from posterior predictive draws.
   - PPLC remains part of fitted diagnostics.
   - Removed article-local scoring helpers from the examples.

3. **Package design and implementation**
   - Added a new JSS-facing section.
   - Explains `exdqlmFit` and `exalStaticFit` shared class families.
   - Explains visible diagnostic/forecast/synthesis/static diagnostic objects.
   - Explains standard methods: `print()`, `summary()`, `plot()`, and
     `predict()`.
   - Adds a workflow table mapping functions/methods to returned objects.

4. **Examples**
   - The displayed code chunks now follow the revised package API and are
     aligned with `code.R`/`analysis/`.
   - Example 3 now compares no-covariate, direct-regression, and
     transfer-function models.
   - Example 3 forecasts are created using `predict()` on fitted dynamic
     objects.
   - Example 3 held-out forecast metrics use
     `exdqlmForecastDiagnostics()`.
   - Example 4 uses `exalStaticDiagnostics()` and
     `plot(..., type = "coefficients")` for the coefficient interval figure.

5. **Conclusion**
   - Rewritten to match the revised software scope.
   - States limitations and future directions without overclaiming.

## Appendix / Former Supplement

The previous supplement is now included in the main manuscript as appendices:

- source file: `exdqlm-appendix.tex`
- included from: `exdqlm-jss.tex`
- PDF output: a single `exdqlm-jss.pdf`

Appendix numbering now uses A--J rather than "S" supplement numbering. Appendix
equations, tables, and algorithms are numbered by appendix section.

This directly addresses the editor's request that there be one manuscript PDF
with appendices, rather than a separate supplementary PDF.

## Package/API Changes

Package version `1.1.0` contains the resubmission API improvements:

- shared class families:
  - `exdqlmFit`
  - `exalStaticFit`
- richer `print()` and `summary()` methods;
- `plot()` methods for fitted dynamic objects, diagnostics, forecasts,
  synthesis objects, and static diagnostics;
- `predict()` method for dynamic fitted objects, returning `exdqlmForecast`
  objects;
- visible diagnostic and forecast diagnostic objects:
  - `exdqlmDiagnostic`
  - `exdqlmForecastDiagnostic`
  - `exalStaticDiagnostic`
- `exdqlmForecastDiagnostics()` for held-out forecast check loss and CRPS;
- coefficient interval plotting from `exalStaticDiagnostics()` through
  `plot(..., type = "coefficients")`;
- updated documentation, NEWS, README, and tests.

## Reproducibility Materials

The public replication workflow is now:

```sh
Rscript code.R
Rscript code.R --quick
Rscript code.R --example 3
```

The archive no longer requires Git metadata. The submitted replication archive
contains:

- `README.md`
- `code.R`
- `code.html`
- manuscript source and PDF
- appendix source
- `analysis/` scripts, configs, tests, and generated outputs

The archive excludes:

- `.git` / `.github` / `.gitignore`
- ignored audit documents
- local `.rds` caches
- scratch LaTeX files
- nested archives
- response-to-editor files
- old supplement files

## Submission Artifacts

Recommended upload files:

- `exdqlm-jss.pdf`
- `exdqlm_1.1.0.tar.gz`
- `exdqlm-jss-replication.tar.gz`
- `response-to-editor.pdf`

The `.zip` replication archive is available as a backup if the JSS interface has
trouble with `.tar.gz`, but only one replication archive should be uploaded
unless requested.

## Files Coauthors Should Review

Primary:

- `exdqlm-jss-coauthor-review.pdf`
- `response-to-editor.pdf`

Optional/source-level:

- `exdqlm-jss-coauthor-review.tex`
- `exdqlm-jss.tex`
- `exdqlm-appendix.tex`
- `README.md`
- `code.R`
- `code.html`

Suggested focus:

1. Is the contribution framing accurate?
2. Is the package design section clear?
3. Do Examples 3 and 4 read naturally?
4. Is the appendix integration acceptable?
5. Does the response-to-editor answer the JSS comments directly?

## Remaining Risks / Coauthor Judgment

- The manuscript is long because the appendix is now included in the main PDF.
  This follows the editor's instruction and JSS has no page limit, but
  coauthors should confirm the appendix content is appropriate.
- The response letter says package version `1.1.0` is prepared for CRAN
  submission, not already published. This is intentional unless/until CRAN
  publication is confirmed.
- The examples are now more API-oriented. Coauthors should check that the
  scientific interpretation did not become too compressed.

## Verification Already Run

Using R 4.6.0 and installed `exdqlm` 1.1.0 from the staging library:

- clean manuscript compiled successfully;
- coauthor-review manuscript compiled successfully;
- `Rscript code.R --quick` passed;
- strict reproducibility preflight passed with `0 errors / 0 warnings`;
- fresh extracted no-Git replication archive quick test passed;
- final archive audit found no Git metadata, ignored audit documents, RDS
  caches, response files, old supplement files, or nested archives.
