# Example 3: Big Tree

This folder contains the canonical script for the Big Tree example in Section
`sec:ex3` of `article4.tex`.

Edit `run.R` when changing the manuscript-facing Big Tree workflow. This script
uses the observed USGS monthly-average `BTflow` response and the standardized
`NOI` and `AMO` columns from the package `climateIndices` data frame. It does
not use precipitation, soil moisture, hidden daily files, or the older
reconstructed Big Tree flow series.

The current script is intentionally separated from the older support/sandbox
workflows under `analysis/support/`. Those workflows are preserved as screening
or historical analysis inputs only; they are not the manuscript source of truth.

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
`ex3_diagnostics_summary.csv`. The lambda screen is stored in
`ex3_lambda_scan.csv` and selects the transfer-function rate by finite CRPS.
The lambda table records fit failures and package convergence flags separately:
`status == "ok"` means the fit completed and produced finite diagnostics, while
`converged` reports the LDVB joint stopping rule from the package.
