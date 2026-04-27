# Manuscript Reproduction Stage

This stage reproduces the main manuscript example artifacts (figures, key tables,
and compact console-output equivalents) using the current `exdqlm` package API,
without modifying `article4.tex`.

For a reader-facing index of the publication artifacts, support-only outputs,
and recommended rerun entry points, see
`/home/jaguir26/local/src/exdqlm---Article/SUPPLEMENTARY_INDEX.md`.

## Canonical Example Workflow

The scripts under `analysis/manuscript/examples/` are the canonical source for
the paper examples. They are the only maintained executable workflow for
regenerating the manuscript-facing figures, support tables, logs, and
reproducibility tracker.

Each example has an isolated folder:

- `examples/ex1_lake_huron/`
- `examples/ex2_sunspots/`
- `examples/ex3_big_tree/`
- `examples/ex4_static/`

Each folder contains a `run.R`, a short `README.md`, a collaborator-facing
`config.yml`, and an `artifacts.yml` manifest. Shared setup and helper
infrastructure lives in `analysis/lib/manuscript_setup.R`.

Standalone collaborator scripts, including temporary `examples.R` files, should
be treated as review input rather than as a second maintained source. When a
standalone script contains a useful correction or improvement, merge that logic
into the appropriate canonical example folder here, rerun the affected target,
and commit the script/output/article changes together. This keeps the manuscript text,
displayed code, generated figures, generated tables, and reproducibility logs
from drifting apart.

The intended update cycle is:

1. Edit the relevant script in `analysis/manuscript/examples/`.
2. Run the narrowest useful target with `analysis/run_all.R --stage manuscript`.
3. Update any inline manuscript table/text in `article4.tex` from the generated
   CSV/log output.
4. Run the manuscript tests or a focused validation pass.
5. Commit the script, regenerated artifacts, manuscript text, and tracker updates
   together.

Collaborators who prefer to work through Overleaf can edit these canonical
example folders there. Those edits should then be pulled locally, validated
through this workflow, and pushed back to keep the article repository and
Overleaf in sync.

## Scope

- Rebuilds Example 1 (Lake Huron) figures.
- Rebuilds Example 1 predictive-synthesis figure from the tracked 0.05, 0.50, and 0.95 fits.
- Rebuilds Example 2 (Sunspots) primary figures from the LDVB workflow, with optional support-only LDVB diagnostics available when requested.
- Rebuilds a representative dynamic Example 2 runtime-and-quality benchmark table (`tab:ex2bench`) pairing runtime with KL, CRPS, and pplc under the disclosed backend profile.
- Rebuilds Example 3 (Big Tree) primary figures + diagnostics table from the LDVB workflow.
- Rebuilds Example 4 sparse static exAL simulation figure + summary table under the regularized horseshoe (RHS) prior.
- Adds LDVB-focused support artifacts for Example 2 and Example 3 (figures + diagnostics/scan tables).
- Adds an optional support-only Example 1 kernel comparison (`ex1kernel`) that benchmarks `slice` versus `laplace_rw` for the free-`sigma` median Lake Huron fit.
- Adds an optional support-only Example 4 seed screen (`ex4screen`) that benchmarks a fixed candidate set of simulation seeds and selects the tracked dataset seed using the \(p_0 = 0.50\) MCMC full-coverage criterion for the plotted slope coefficients.
- Writes a reproducibility tracker with per-artifact status notes.
- Writes support tables describing the disclosed benchmark backend profiles and tracked benchmark environment.

## Run

From repository root:

```bash
Rscript analysis/run_all.R --stage manuscript
```

For the staged overnight relaunch sequence against the current package checkout,
you can also run:

```bash
bash analysis/manuscript/run_overnight_relaunch.sh
```

Useful variants:

```bash
Rscript analysis/run_all.R --stage manuscript --profile quick
Rscript analysis/run_all.R --stage manuscript --profile standard
Rscript analysis/run_all.R --stage manuscript --skip-tests
Rscript analysis/run_all.R --stage manuscript --promote
Rscript analysis/run_all.R --stage manuscript --pkg-path /path/to/exdqlm
Rscript analysis/run_all.R --stage manuscript --targets ex2quant --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2quant,ex2checks --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2bench --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2quant_ldvb,ex2checks_ldvb --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2_ldvb_diagnostics --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3data,ex3quantcomps,ex3zetapsi,ex3forecast,ex3tables --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3quantcomps,ex3forecast --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex4screen --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex4figure,ex4table --force-refit --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1mcmc --force-refit --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1synth --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex1kernel --force-refit --skip-tests
```

By default, this stage loads local `exdqlm` source from
`/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile`. Override that with
`--pkg-path /path/to/exdqlm` or `EXDQLM_PKG_PATH=/path/to/exdqlm`.
If both are set, `--pkg-path` takes precedence over `EXDQLM_PKG_PATH`.
For constrained environments where rebuilding local source is not feasible,
set `EXDQLM_LOAD_MODE=installed` and optionally
`EXDQLM_INSTALLED_LIB=/path/to/R/library` to use an installed `exdqlm`
package instead. Source mode remains the default.

## Outputs

- `analysis/manuscript/outputs/figures/`: generated figure files.
- `analysis/manuscript/outputs/tables/`: diagnostics summaries + reproducibility tracker, including the Example 4 \(p_0 = 0.50\) seed-screen selection table.
- `analysis/manuscript/outputs/logs/`: compact textual outputs and session metadata.
- `analysis/manuscript/outputs/cache/`: cached fitted objects to support fast targeted reruns.

Figures cited by `article4.tex` are resolved from
`analysis/manuscript/outputs/figures/` through the manuscript `\graphicspath`.
Top-level `Figures/` files are optional local export copies created by
`--promote`; they are ignored by git and are not searched by the manuscript
build. Tables in `article4.tex` are inline LaTeX, so their displayed values
must be updated from the generated CSV/log files whenever a model is rerun.

Main tracker files:

- `manuscript_repro_tracker.csv`
- `manuscript_repro_tracker.md`
- `manuscript_api_migration_map.csv`
- `benchmark_backend_profiles.csv`
- `benchmark_environment.csv`

For the staged overnight relaunch sequence against the current package checkout,
see `analysis/manuscript/OVERNIGHT_RELAUNCH_CHECKLIST.md`.

For merge provenance and issue-by-issue integration notes tied to Raquel's
example review pass, see
`analysis/manuscript/RAQUEL_EXAMPLES_MERGE_AUDIT.md`.
