# Example 4: Static exAL

This folder contains the canonical scripts for the static exAL simulation
example in Section `sec:ex4static` of `article4.tex`.

- `run.R` regenerates the manuscript-facing figure/table.
- `seed_screen.R` runs the optional support-only seed screen.
- `helpers.R` contains Example 4 helper functions shared by both scripts.

The numerical settings are read from the `ex4` section of
`analysis/config/params_manuscript.yml`.

## Run

```bash
Rscript analysis/run_all.R --stage manuscript --targets ex4 --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex4figure,ex4table --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex4screen --profile standard --skip-tests
```

After rerunning, validate with:

```bash
Rscript analysis/run_all.R --stage manuscript --tests-only
```

The article currently uses `ex4static.png` and the values in
`ex4static_summary.csv`.
