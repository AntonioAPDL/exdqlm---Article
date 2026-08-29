# Analysis Workflow

This folder contains the author-side analysis support for the article. For JSS
or reader-facing replication, start from the repository root:

```sh
R CMD BATCH --vanilla code.R code.Rout
```

The `code.R` command refits the manuscript examples, prints the numerical
tables and selected fitted-object output to `code.Rout`, and writes the graphics
stream to `Rplots.pdf`.

The scripts in this directory are maintenance files used to rebuild `code.R`,
run focused checks, and update the manuscript outputs. They are not the public
JSS execution path and are excluded from the final replication archive.

## Structure

- `config/`: manuscript parameters, seeds, benchmark settings, and expected
  package version.
- `exal/`: exAL distribution utilities and support outputs.
- `lib/`: shared analysis helpers.
- `manuscript/`: manuscript example scripts, manifests, tests, and outputs.

## Internal commands

The internal runner and preflight utilities remain available for author-side
maintenance, focused reruns, and reference-machine checks. They are not part of
the JSS reviewer-facing execution contract.

The preflight utility can be run by authors before rebuilding the public script
and archive:

```sh
Rscript analysis/check_reproducibility.R --stage manuscript --profile standard --require-r-version 4.6.0
```

For focused reruns, authors should inspect the runner's help and use the
smallest manuscript target needed for the intended update. Public replication
should use the submitted package source tarball installed into R, not a local
source-package resolver.

## Notes

- Deterministic seeds are recorded in `config/params_manuscript.yml`.
- Output filenames are stable for manuscript linkage.
- Large saved fit files are local accelerators and should be excluded from the
  final submission archive; the public `code.R` run refits the examples.
- Exploratory scripts should stay outside the submitted archive unless they
  become part of the maintained manuscript examples.
