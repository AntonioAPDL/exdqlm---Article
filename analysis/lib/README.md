# Shared Analysis Helpers

This directory contains shared setup code used by analysis stages that are not
owned by a single example.

- `manuscript_setup.R` loads the current `exdqlm` package source or installed
  package, reads manuscript configuration, defines output directories, and
  provides helper functions used by the canonical manuscript examples.

Example-specific code should live under `analysis/manuscript/examples/`.
Only move logic here when it is genuinely shared across examples.
