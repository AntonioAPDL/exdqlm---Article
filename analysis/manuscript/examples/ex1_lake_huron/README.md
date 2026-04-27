# Example 1: Lake Huron

This folder contains the canonical script for the Lake Huron example in
Section `sec:ex1` of `article4.tex`.

Edit `run.R` when changing the Example 1 code shown or described in the paper.
The numerical settings are read from the `ex1` section of
`analysis/config/params_manuscript.yml`.

## Run

```bash
Rscript analysis/run_all.R --stage manuscript --targets ex1 --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1mcmc --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1quants --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1synth --profile standard --skip-tests
```

After rerunning, validate with:

```bash
Rscript analysis/run_all.R --stage manuscript --tests-only
```

The article currently uses `ex1mcmc.png` and `ex1quants.png`; `ex1synth.png`
is a support figure.

`ex1_synthesis_bridge_check.csv` records the observed-period synthesis endpoint
and the first forecast synthesis time. This is a lightweight audit for the
visual bridge used at the forecast origin in Figure 2(d).
