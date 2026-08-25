# Analysis Workflow

This folder contains the executable analysis support for the article. For JSS
or reader-facing replication, start from the repository root:

```sh
R CMD BATCH --vanilla code.R code.Rout
R CMD BATCH --vanilla code-fast.R code-fast.Rout
```

The full `code.R` command refits the manuscript examples, prints the numerical
tables and selected fitted-object output to `code.Rout`, and writes the graphics
stream to `Rplots.pdf`. The optional `code-fast.R` command uses reduced
computation settings for code checking and is not authoritative for manuscript
values.

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

The internal runner and preflight utilities remain available for author-side
maintenance, targeted reruns, and reference-machine checks. They are not part
of the JSS reviewer-facing execution contract and are excluded from the final
replication archive.

The preflight utility can be run by authors before rebuilding the public
scripts and archive:

```sh
Rscript analysis/check_reproducibility.R --stage manuscript --profile standard --require-r-version 4.6.0
```

For targeted reruns, authors should inspect the runner's help and use the
smallest manuscript target needed for the intended update. Public replication
should use the submitted package source tarball installed into R, not a local
source-package resolver.

## Notes

- Deterministic seeds are recorded in `config/params_manuscript.yml`.
- Output filenames are stable for manuscript linkage.
- Large `.rds` fit caches are local accelerators and should be excluded from
  the final submission archive; full/example `code.R` runs recreate them when
  absent.
- `Figures/` is an ignored local export mirror created only by explicit
  promotion; the manuscript reads generated figures from
  `analysis/manuscript/outputs/figures/`.
- Exploratory scripts should stay outside the submitted archive unless they
  become part of the maintained manuscript pipeline.
