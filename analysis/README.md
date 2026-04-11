# Analysis Workflow

This folder contains reproducible analysis stages for the article.

- `exal`: exAL distribution utilities/reproducibility assets.
- `manuscript`: end-to-end regeneration of main manuscript example artifacts.
  This includes the sparse `rhs_ns` static benchmark used in Example 4.

For a reader-facing map of the manuscript artifacts, support-only outputs, and
rerun entry points, see
`/home/jaguir26/local/src/exdqlm---Article/SUPPLEMENTARY_INDEX.md`.

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
Rscript analysis/run_all.R --stage manuscript --targets ex2quant_ldvb,ex2checks_ldvb --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2_gamma_posteriors --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2_ldvb_diagnostics --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3quantcomps_ldvb,ex3forecast_ldvb,ex3tables_ldvb --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1mcmc --force-refit --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1synth --skip-tests
```

By default, the analysis workflow loads local `exdqlm` source from
`/home/jaguir26/local/src/exdqlm__wt__0p4p0_article_main`. Override that with
`--pkg-path /path/to/exdqlm` or `EXDQLM_PKG_PATH=/path/to/exdqlm`.
If both are set, `--pkg-path` takes precedence over `EXDQLM_PKG_PATH`.
For constrained environments where rebuilding local source is not feasible,
set `EXDQLM_LOAD_MODE=installed` and optionally
`EXDQLM_INSTALLED_LIB=/path/to/R/library` to use an installed `exdqlm`
package instead. Source mode remains the default.

## Structure

- `config/`: stage parameter and plotting configuration.
- `exal/`: exAL-focused scripts/tests/outputs.
- `manuscript/`: manuscript examples scripts/tests/outputs.

## Notes

- Deterministic seeds are stage-specific (`config/params_*.yml`).
- Output filenames are stable for repeatable manuscript linkage.
- Promotion copies selected figures into top-level `Figures/`.
