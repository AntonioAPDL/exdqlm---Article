# Changes After The JSS Editorial Return

This file is a coauthor-review checklist. The clean manuscript for submission
is `exdqlm-jss.pdf`; the marked review manuscript is
`00_COMPILE_THIS_COAUTHOR_REVIEW.pdf`.

The marked PDF uses blue boxes to identify the main revised regions. It is not
a word-by-word diff. Its purpose is to make the scientific and editorial changes
easy to review without putting review markup into the final JSS manuscript.

## Main Files To Open

1. `00_COMPILE_THIS_COAUTHOR_REVIEW.pdf`
   Marked coauthor-review copy with blue boxes and a review roadmap.
2. `response-to-editor.pdf`
   Point-by-point response to the JSS editorial comments.
3. `exdqlm-jss.pdf`
   Clean final manuscript PDF for submission.
4. `code.R` and `code.html`
   Standalone replication script and rendered code listing.

## High-Level Revision Map

| Area | What changed | Why it matters for review |
| --- | --- | --- |
| Introduction and software positioning | The opening now separates the prior exDQLM methodology from the software contribution of the JSS paper. | Addresses the editor's concern that the paper must read as a software article rather than only as a methods article. |
| Software comparison table | The package comparison was rewritten around modeling scope, temporal/state-space handling, computation, and multiple-quantile handling. | Clarifies the software gap and avoids vague or inconsistent feature labels. |
| Diagnostics | KL, CRPS, PPLC, and held-out forecast diagnostics are now presented as package-level diagnostic outputs with a clearer object lifecycle. | Addresses the request for clearer package functionality and reproducible diagnostics. |
| Package design section | A new implementation section describes classes, returned objects, S3 methods, backend behavior, and workflow tables. | Gives JSS readers a clearer software architecture view. |
| Code chunks | The displayed manuscript code was revised to use the current package API and to match the reader-facing workflow in `code.R`. | Makes the article examples easier to run and understand without copying internal preprocessing. |
| Example 3 | Forecasting now uses the standard `predict()` workflow and held-out metrics use `exdqlmForecastDiagnostics()`. | Demonstrates the new forecast-diagnostics API directly in the paper. |
| Example 4 | Static diagnostics now return coefficient summaries and the figure uses `plot(..., type = "coefficients")`. | Replaces manual plotting code with package functionality. |
| Appendices | The former separate supplement is now integrated as appendices in the main manuscript PDF. | Matches the revised submission format and makes algorithms/derivations available in one PDF. |
| Replication materials | `code.R`, `code.html`, README files, and archive contents were cleaned and tested outside a Git checkout. | Aligns the submission with JSS replication expectations. |
| Response letter | A point-by-point response document was added and polished for resubmission. | Gives editors a direct map from comments to revisions. |

## Coauthor Review Focus

Please focus on whether the revised manuscript now:

- clearly states the package contribution relative to the earlier methodology;
- presents the new package API and S3 workflow accurately;
- explains the diagnostics and forecast diagnostics without overclaiming;
- uses the right level of code in the article while leaving full reproduction to
  `code.R`;
- makes Examples 3 and 4 read naturally after the API changes;
- has appendices that read like part of the main manuscript, not a leftover
  supplement;
- responds completely and fairly to the JSS comments.

## What Not To Review As Final Submission Content

The files with `COAUTHOR_REVIEW`, this checklist, and the blue review boxes are
only for internal review. They should not be uploaded to JSS. The final upload
uses the clean manuscript, package source tarball, replication archive, and
response-to-editor document.
