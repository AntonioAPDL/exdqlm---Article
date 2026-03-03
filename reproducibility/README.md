# Reproducibility Workflow

This folder organizes manuscript code so all analyses are reproducible and easy
to maintain.

## Layout

- `run_all.R`: entrypoint to run scripts in a fixed order.
- `scripts/`: analysis scripts used to generate manuscript outputs.
- `outputs/`: non-figure artifacts (logs, tables, session info).

## Output Conventions

- Manuscript figures should be written to `../Figures/` (repo-level `Figures/`).
- Non-figure outputs should be written to `reproducibility/outputs/`.

## Run

From the repository root:

```bash
Rscript reproducibility/run_all.R
```

Optional explicit root:

```bash
Rscript reproducibility/run_all.R /data/muscat_data/jaguir26/exdqlm---Article
```

## Notes

- Keep scripts deterministic (set seeds where needed).
- Prefer stable filenames for figures so article references remain valid.
- Add code exactly as used for manuscript results; avoid ad-hoc manual steps.
