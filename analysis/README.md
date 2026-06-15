# Analysis Workflow

This folder contains the executable analysis support for the article. For JSS
or reader-facing replication, start from the repository root:

```sh
Rscript code.R
Rscript code.R --quick
Rscript code.R --example 3
```

The scripts in this directory are internal maintenance tools used by `code.R`
and by the authors for targeted reruns, preflight checks, and final reference
syncs.

## Structure

- `config/`: manuscript parameters, seeds, backend profile, and expected package
  version.
- `exal/`: exAL distribution utilities and support artifacts.
- `lib/`: shared analysis helpers.
- `manuscript/`: canonical manuscript example scripts, manifests, tests, and
  outputs.

## Internal commands

The internal runner can regenerate a full stage:

```sh
Rscript analysis/run_all.R --stage manuscript --profile standard
```

Useful targeted maintenance commands:

```sh
Rscript analysis/run_all.R --stage manuscript --profile quick
Rscript analysis/run_all.R --stage manuscript --tests-only
Rscript analysis/run_all.R --stage manuscript --targets ex1 --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex2 --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex3 --profile standard --skip-tests
Rscript analysis/run_all.R --stage manuscript --targets ex4 --profile standard --skip-tests
```

The preflight utility is for final reference-machine checks:

```sh
Rscript analysis/check_reproducibility.R --stage manuscript --profile standard --require-r-version 4.6.0
```

By default, the internal analysis workflow loads local `exdqlm` source when
source mode is requested. Public replication should normally use the submitted
package source tarball installed into R.

## Notes

- Deterministic seeds are recorded in `config/params_manuscript.yml`.
- Output filenames are stable for manuscript linkage.
- `Figures/` is an ignored local export mirror created only by explicit
  promotion; the manuscript reads generated figures from
  `analysis/manuscript/outputs/figures/`.
- Exploratory scripts should stay outside the submitted archive unless they
  become part of the maintained manuscript pipeline.
