# Example 3: Big Tree

This folder contains the canonical script for the Big Tree example in Section
`sec:ex3` of `exdqlm-jss.tex`.

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
`ex3_forecast_metrics.csv`. The transfer-function validation screen is stored in
`ex3_validation_selection.csv` and selects the transfer-function rate and
instantaneous-coefficient discount factor by forecast check loss on the internal
validation window. The final manuscript metrics are computed only on the
18-month holdout forecast window. The validation table records fit/forecast
failures and package convergence flags separately: `status == "ok"` means the
fit completed and produced finite forecast metrics, while `converged` reports
the LDVB joint stopping rule from the package.
