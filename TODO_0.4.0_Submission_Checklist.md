# exdqlm Article TODO/Checklist for 0.4.0 Submission

This is a checklist that tracks the minimum manuscript updates required so the article matches the current package scope (`exdqlm` 0.4.0) and is submission-ready.

## Gap Summary (Current article vs package 0.4.0)

### Major missing features in article text/examples
- Not covered at all in `article4.tex`:
  - `exdqlmLDVB`
  - `exdqlm_synthesize_from_draws`
  - `regMod`
  - `exal_static_LDVB`
  - `exal_static_mcmc`
  - exAL distribution helpers: `dexal`, `pexal`, `qexal`, `rexal`
  - `get_gamma_bounds`

### Outdated API usage in article examples
- Uses `exdqlmChecks(...)` instead of `exdqlmDiagnostics(...)`.
- Uses old signatures with explicit `y = ...` in plotting/forecasting helpers:
  - `exdqlmPlot(y = ..., ...)`
  - `compPlot(y = ..., ...)`
  - `exdqlmForecast(y = ..., ...)`
- These should be updated to current interfaces.

### Computational story mismatch
- Article currently emphasizes MCMC + ISVB only.
- Package 0.4.0 now includes dynamic LDVB + static exAL workflows + synthesis helper.
- C++ acceleration exists for selected paths (Kalman/builder/sampler/postpred toggles), but **no C++ MCMC implementation**; this should be stated explicitly.

---

## P0: Must Complete Before Submission

### A) Core narrative and positioning
- [ ] Update Introduction to describe 0.4.0 scope (MCMC, ISVB, LDVB, static regression, synthesis).
- [ ] Update Conclusion to reflect new functionality and current boundaries (including no C++ MCMC).

### B) Function/API correctness pass
- [ ] Replace all `exdqlmChecks` references with `exdqlmDiagnostics`.
- [ ] Update all old calls using `y =` in helper functions to current signatures.
- [ ] Verify every function call shown in the manuscript runs with the current package API.

### C) New methods sections (short, focused)
- [ ] Add subsection: dynamic LDVB (`exdqlmLDVB`) and when to use it vs ISVB/MCMC.
- [ ] Add subsection: static regression builder (`regMod`) and static exAL inference (`exal_static_LDVB`, `exal_static_mcmc`).
- [ ] Add subsection: posterior predictive synthesis (`exdqlm_synthesize_from_draws`) with constraints (quantile grid monotonicity/anchors).
- [ ] Add short reference subsection for exAL distribution helpers (`dexal`, `pexal`, `qexal`, `rexal`, `get_gamma_bounds`).

### D) New examples (required)
- [ ] Add one minimal dynamic LDVB example (small, fast, reproducible).
- [ ] Add one minimal static regression example using `regMod` + at least one static inference routine.
- [ ] Add one synthesis example showing input draws -> synthesized output + basic diagnostic summary.
- [ ] Add one short exAL helper example block (density/CDF/quantile/random generation sanity).

### E) Reproducibility and consistency gates
- [ ] Ensure all printed code chunks are executable as-is (no stale arguments/functions).
- [ ] Update figures/tables impacted by API or algorithm additions.
- [ ] Confirm notation and terminology are consistent across dynamic/static/synthesis sections.

---

## P1: Strongly Recommended (High Value)

### F) Performance/computation section refresh
- [ ] Add a compact runtime table comparing representative workloads:
  - ISVB vs LDVB (dynamic)
  - static LDVB vs static MCMC
- [ ] Add a clear note on optional C++ toggles and defaults:
  - `exdqlm.use_cpp_kf`
  - `exdqlm.use_cpp_builders`
  - `exdqlm.use_cpp_samplers`
  - `exdqlm.use_cpp_postpred`
- [ ] Explicitly state that MCMC remains R-path (no C++ MCMC backend).

### G) Example modernization
- [ ] Keep examples short enough for editorial/reviewer reproducibility.
- [ ] Prefer deterministic seeds and compact windows in demonstration code.
- [ ] Cross-reference examples to package help pages for exact argument contracts.

---

## P2: Nice-to-Have (If Time Allows)

- [ ] Add a one-page appendix table mapping "function -> purpose -> key inputs -> key outputs".
- [ ] Add a small migration note from older API names/signatures to current ones.
- [ ] Add supplementary script list for end-to-end reproduction of all article figures.

---

## Example Coverage Matrix (Target)

- [ ] `exdqlmISVB` (existing, update calls)
- [ ] `exdqlmMCMC` (existing)
- [ ] `exdqlmLDVB` (new)
- [ ] `transfn_exdqlmISVB` (existing)
- [ ] `regMod` (new)
- [ ] `exal_static_LDVB` (new)
- [ ] `exal_static_mcmc` (new)
- [ ] `exdqlm_synthesize_from_draws` (new)
- [ ] `exdqlmForecast` (existing, update calls)
- [ ] `exdqlmDiagnostics` (replace old `exdqlmChecks` references)
- [ ] `exdqlmPlot`, `compPlot` (existing, update calls)
- [ ] `dexal`, `pexal`, `qexal`, `rexal`, `get_gamma_bounds` (newly documented usage)

---

## Submission-Readiness Checklist

- [ ] All manuscript code blocks compile/run with current package version.
- [ ] All figures/tables regenerate without manual patching.
- [ ] No references to deprecated names/signatures remain.
- [ ] New 0.4.0 functionality is represented with at least one concrete example each.
- [ ] Computational claims match actual implementation status (including backend limits).
- [ ] Final proofreading pass for notation consistency and concise language.

