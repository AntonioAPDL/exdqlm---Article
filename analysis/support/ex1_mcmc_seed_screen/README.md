# Example 1 MCMC Trace Seed Screen

This folder records the local seed-screening outputs used to choose the
dedicated MCMC trace seed for Example 1. The manuscript workflow now uses
`trace_seed: 20260616` for the Lake Huron median trace fit while leaving the
main Example 1 quantile and synthesis seeds unchanged.

The screening summary is in `outputs/seed_screen_summary.csv`. Higher scores
indicate better empirical trace behavior based on effective sample size,
lag-one autocorrelation, and drift diagnostics for the `sigma` and `gamma`
chains. The file `outputs/contact_sheet_top8.png` provides the visual
comparison for the top-ranked candidates.

The selected seed was `20260616`, which ranked first in the screen and had the
best overall balance of quantitative diagnostics and visual trace behavior.
