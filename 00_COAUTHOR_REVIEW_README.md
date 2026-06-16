# Coauthor Review Guide

This repository contains two manuscript versions:

- `exdqlm-jss.pdf` / `exdqlm-jss.tex`: clean JSS submission version.
- `exdqlm-jss-coauthor-review.pdf` / `exdqlm-jss-coauthor-review.tex`:
  internal coauthor-review version with blue boxes marking the main revised
  regions after the JSS editorial return.

Overleaf may open or compile `exdqlm-jss.tex` by default. That is expected:
the clean version does not show colored review notes. To see the marked
version, open `exdqlm-jss-coauthor-review.pdf`, or compile
`exdqlm-jss-coauthor-review.tex`.

The blue boxes are meant to guide review; they are not intended for the final
JSS upload.

## Main Places To Check

1. **Introduction / software contribution**
   - Check that the article clearly separates prior methodology from the
     software contribution of this JSS paper.

2. **Model diagnostics and forecasting**
   - Check the KL, CRPS, PPLC, forecast, and held-out diagnostic descriptions.

3. **Package design and implementation**
   - Check the new JSS-facing description of classes, returned objects,
     standard methods, and workflow tables.

4. **Examples and code chunks**
   - Check that the displayed code is clear, reader-facing, and aligned with
     `code.R`.

5. **Example 3**
   - Check the no-covariate, direct-regression, and transfer-function
     comparison.
   - Check the use of `predict()` and `exdqlmForecastDiagnostics()`.

6. **Example 4**
   - Check the static workflow and the coefficient-interval plot generated via
     `exalStaticDiagnostics()` and `plot(..., type = "coefficients")`.

7. **Conclusion**
   - Check that the final scope, limitations, and future work are accurate.

8. **Appendices**
   - Check that the former supplement now reads naturally as appendices in the
     main manuscript PDF.

9. **Response to JSS**
   - Check `response-to-editor.pdf` for the point-by-point response.

## Supporting Files

- `docs/coauthor_resubmission_summary_2026-06-16.md`: detailed summary of
  what changed.
- `docs/coauthor_email_draft_es_2026-06-16.md`: draft Spanish email with the
  same high-level summary.

