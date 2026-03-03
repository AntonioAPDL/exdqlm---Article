# Analysis Workflow

This folder contains a reproducible exAL analysis pipeline for the article,
implemented with `exdqlm` package functions (no direct `sourceCpp` usage).

## Run

From repository root:

```bash
Rscript analysis/run_all.R --stage exal
```

Optional flags:

```bash
Rscript analysis/run_all.R --stage exal --tests-only
Rscript analysis/run_all.R --stage exal --skip-tests
Rscript analysis/run_all.R --stage exal --promote
Rscript analysis/run_all.R --stage exal --pkg-path /path/to/exdqlm
```

## Structure

- `config/`: parameter and plotting style configuration.
- `exal/scripts/`: staged script pipeline (`00` setup, `01-11` outputs).
- `exal/tests/`: `testthat` validation suite.
- `exal/outputs/figures/`: generated figures.
- `exal/outputs/tables/`: generated tables/manifests.
- `exal/outputs/logs/`: runtime session metadata (ignored except `.gitkeep`).

## Notes

- Deterministic seed is controlled in `config/params_exal.yml`.
- Output filenames are fixed and intended for stable manuscript references.
- Promotion copies selected figures into top-level `Figures/`.
