# Example 3: Big Tree

This folder contains the canonical script for the Big Tree example in Section
`sec:ex3` of `article4.tex`.

Edit `run.R` when changing the manuscript-facing Big Tree workflow. The current
script is intentionally separated from the older support/sandbox workflows under
`analysis/support/`.

The numerical settings are read from the `ex3` section of
`analysis/config/params_manuscript.yml`.

## Run

```bash
Rscript analysis/run_all.R --stage manuscript --targets ex3 --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3data --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3quantcomps,ex3zetapsi,ex3forecast --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3tables --profile standard --skip-tests
```

After rerunning, validate with:

```bash
Rscript analysis/run_all.R --stage manuscript --tests-only
```

The article currently uses `ex3data.png`, `ex3quantcomps.png`,
`ex3zetapsi.png`, `ex3forecast.png`, and the values in
`ex3_diagnostics_summary.csv`.
