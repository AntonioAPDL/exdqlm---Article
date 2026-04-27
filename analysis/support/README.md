# Support and Exploratory Workflows

This directory preserves non-canonical exploratory workflows and long-running
support analyses. These folders are intentionally **not** the manuscript source
of truth.

Canonical manuscript examples live under:

```text
analysis/manuscript/examples/
```

The support workflows remain available because they document alternative
analysis paths, sensitivity checks, and long-running experiments that may still
be useful.

Current support workflows:

- `ex3_daily_redo/`: daily Big Tree prototype using precipitation/soil moisture
  style inputs from the earlier exploration.
- `ex3_monthly_nino34_redo/`: monthly Big Tree climate-index screening and
  reduced-index experiments.
- `ex3_monthly_outputlag_redo/`: monthly Big Tree output-lag exploration.

If support logic becomes manuscript-facing, merge the relevant pieces into the
appropriate folder under `analysis/manuscript/examples/` and rerun the canonical
workflow.
