# Analysis Workflow

This folder contains reproducible analysis stages for the article.

- `exal`: exAL distribution utilities/reproducibility assets.
- `manuscript`: end-to-end regeneration of main manuscript example artifacts.
  Canonical per-example scripts live under `analysis/manuscript/examples/`.
  This includes the sparse `rhs_ns` static benchmark used in Example 4.
- `support`: preserved exploratory and alternative workflows that are useful for
  audit/history but are not the manuscript source of truth.

For a reader-facing map of the manuscript artifacts, support-only outputs, and
rerun entry points, see
`/home/jaguir26/local/src/exdqlm---Article/SUPPLEMENTARY_INDEX.md`.

The canonical source for the paper examples is
`analysis/manuscript/examples/`, executed through `analysis/run_all.R --stage
manuscript`. Standalone example scripts should be merged into that stage rather
than maintained separately, so manuscript text, displayed code, figures, tables,
and reproducibility logs stay synchronized.

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
Rscript analysis/run_all.R --stage manuscript --targets ex2_ldvb_diagnostics --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3data,ex3quantcomps,ex3zetapsi,ex3forecast,ex3tables --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1mcmc --force-refit --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1synth --skip-tests
```

By default, the analysis workflow loads local `exdqlm` source from
`/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile`. Override that with
`--pkg-path /path/to/exdqlm` or `EXDQLM_PKG_PATH=/path/to/exdqlm`.
If both are set, `--pkg-path` takes precedence over `EXDQLM_PKG_PATH`.
For constrained environments where rebuilding local source is not feasible,
set `EXDQLM_LOAD_MODE=installed` and optionally
`EXDQLM_INSTALLED_LIB=/path/to/R/library` to use an installed `exdqlm`
package instead. Source mode remains the default.

## Structure

- `config/`: stage parameter and plotting configuration.
- `exal/`: exAL-focused scripts/tests/outputs.
- `lib/`: shared analysis helpers used by the manuscript stage.
- `manuscript/`: canonical manuscript example scripts/tests/outputs.
- `support/`: non-canonical exploratory workflows retained for reference.

## Notes

- Deterministic seeds are stage-specific (`config/params_*.yml`).
- Output filenames are stable for repeatable manuscript linkage.
- The optional `--promote` flag copies selected figures into top-level
  `Figures/` as a local export mirror. That directory is ignored by git and is
  not used by `article4.tex`.
- The staged overnight manuscript relaunch plan is documented in
  `analysis/manuscript/OVERNIGHT_RELAUNCH_CHECKLIST.md`.
