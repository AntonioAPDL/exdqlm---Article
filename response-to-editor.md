# Response to the Editorial Return

Thank you for the careful second prescreening review. We understand the return
as a reproducibility-interface and output-provenance problem: the previous
archive still made it too hard to run the article computations in batch mode and
compare the resulting output directly with the manuscript. We have restructured
the replication materials accordingly and are resubmitting as a new submission
with a point-by-point response.

Submitted files:

- `exdqlm-jss.pdf`
- `exdqlm_1.1.1.tar.gz`
- `exdqlm-jss-replication.tar.gz`
- `response-to-editor.pdf`

The package source is version 1.1.1 of `exdqlm`. This is a narrow
reproducibility patch. It does not change the statistical model, exported API,
or manuscript claims. It corrects compiled stochastic helper paths so they use
serial R-controlled random-number streams and adds repeated-seed tests.

## Summary

- `code.R` is now the authoritative flat batch script.
- The primary command is `R CMD BATCH --vanilla code.R code.Rout`.
- `code.R` produces `code.Rout` and `Rplots.pdf` at the archive root.
- `code-fast.R` is a reduced code-checking script and is not authoritative for
  manuscript numerical values.
- `code.Rout` prints `M95`, `summary(M95)`, `MTF$median.kt`, Tables 7--10, and
  `sessionInfo()`.
- The manuscript and README now state the reference environment, RNG settings,
  package version, backend/thread settings, and output locations.

## Point-by-point response

1. **Single script and batch-mode output.** The revised archive centers on
   `code.R`, a flat, commented R file ordered by manuscript examples. Running
   `R CMD BATCH --vanilla code.R code.Rout` performs the full replication.

2. **Exact reproducibility and computing environment.** The public scripts set
   `RNGversion("4.6.0")` and
   `RNGkind("Mersenne-Twister", "Inversion", "Rejection")`, require
   `exdqlm` 1.1.1, and are run with thread variables set before R starts.
   Version 1.1.1 corrects compiled stochastic RNG/thread behavior found while
   investigating the editorial discrepancies.

3. **More visible output.** The full batch output now includes fitted-object
   output, selected summaries, Tables 7--10, `MTF$median.kt`, and
   `sessionInfo()`.

4. **Figure differences.** The full script regenerates the manuscript figures
   in order and uses the same plotting expressions for `Rplots.pdf` and the PNG
   files used by the manuscript.

5. **`MTF$median.kt`.** The manuscript value is taken from the full `code.R`
   reference run and is printed directly in `code.Rout`.

6. **Missing Figure 3 top panel and Figure 5.** The full script now regenerates
   the complete Sunspots figure and the Big Tree data/covariate figure.

7. **Missing Tables 7 and 10.** Both tables are generated and printed by the
   full script, and saved as CSV files.

8. **`tab.ex3` and `tab.ex3.fc`.** These are printed as Tables 8 and 9 in
   `code.Rout` and saved as generated CSV files.

9. **Fitted-object output.** The full script prints `M95` and `summary(M95)`,
   and the manuscript discusses representative fitted-object output.

## Validation

Before resubmission we ran the package repeatability tests, package test suite,
`R CMD build`, `R CMD check --no-manual --run-donttest`,
`R CMD BATCH --vanilla code-fast.R code-fast.Rout`,
`R CMD BATCH --vanilla code.R code.Rout`, manuscript/response compilation, and
archive extraction checks using R 4.6.0.
