# Example 2: Sunspots

This folder contains the canonical script for the Sunspots example in Section
`sec:ex2` of `article4.tex`.

Edit `run.R` when changing the Example 2 model specifications, diagnostics, or
benchmark table. The numerical settings are read from the `ex2` section of
`analysis/config/params_manuscript.yml`.

## Run

```bash
Rscript analysis/run_all.R --stage manuscript --targets ex2 --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2quant,ex2checks --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2bench --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2tables --profile standard --skip-tests
```

After rerunning, validate with:

```bash
Rscript analysis/run_all.R --stage manuscript --tests-only
```

The article currently uses `ex2quant.png`, `ex2checks.png`, and the values in
`ex2_dynamic_benchmark.csv`.
