# Analysis Workflow

This folder contains reproducible analysis stages for the article.

- `exal`: exAL distribution utilities/reproducibility assets.
- `manuscript`: end-to-end regeneration of main manuscript example artifacts.

## Run

From repository root:

```bash
Rscript analysis/run_all.R --stage exal
Rscript analysis/run_all.R --stage manuscript
```

Optional flags:

```bash
Rscript analysis/run_all.R --stage manuscript --profile quick
Rscript analysis/run_all.R --stage manuscript --tests-only
Rscript analysis/run_all.R --stage manuscript --skip-tests
Rscript analysis/run_all.R --stage manuscript --promote
Rscript analysis/run_all.R --stage manuscript --pkg-path /path/to/exdqlm
Rscript analysis/run_all.R --stage manuscript --targets ex2quant --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1mcmc --force-refit --skip-tests
```

## Structure

- `config/`: stage parameter and plotting configuration.
- `exal/`: exAL-focused scripts/tests/outputs.
- `manuscript/`: manuscript examples scripts/tests/outputs.

## Notes

- Deterministic seeds are stage-specific (`config/params_*.yml`).
- Output filenames are stable for repeatable manuscript linkage.
- Promotion copies selected figures into top-level `Figures/`.
