# Example 1 MCMC Seed Screen

This support workflow screens random seeds for the dedicated Example 1 median
exDQLM MCMC trace fit used in `ex1mcmc.png`. It is intentionally outside the
canonical manuscript pipeline so that trace aesthetics can be checked without
rerunning every Example 1 figure, table, and synthesis artifact.

Run from the article repository root, for example:

```sh
Rscript analysis/support/ex1_mcmc_seed_screen/run.R --profile standard --seeds 20260601:20260616 --cores 4
```

Outputs are written to `analysis/support/ex1_mcmc_seed_screen/outputs/`:

- `seed_screen_summary.csv`: simple chain diagnostics and ranking score.
- `contact_sheet_top*.png`: compact visual review of the best-ranked seeds.
- `seed_<seed>_trace.png`: trace and density panels for each candidate seed.

After choosing a seed visually, copy only that seed to
`analysis/config/params_manuscript.yml` and rerun the canonical Example 1 target.
