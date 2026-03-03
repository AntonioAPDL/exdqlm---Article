# exdqlm Manuscript Master Checklist (Current Package State)

ToDos before submission:

## Current Implementation Status (Package)
- Dynamic MCMC FFBS now has a C++ implementation integrated in `exdqlm`.
- Backend controls are available via `exdqlm.use_cpp_mcmc` and `exdqlm.cpp_mcmc_mode` (`strict|fast`).
- Current package default is C++ MCMC enabled in `fast` mode.
- Backend parity/validation is covered by package tests; manuscript benchmarks must still disclose backend profile.

## An editorial Policy
- Write the paper as a description of the **current package**.
- Avoid release-tag framing (e.g., "v0.x.y") in the main narrative unless needed in a short reproducibility note.
- Keep claims evidence-based and reproducible from code, figures, and tables included in the manuscript workflow.
- Ensure method descriptions, API usage, and examples match the package exactly at submission time.

---

## Critical Gap Summary (Current manuscript vs current package)

### Missing core functionality in manuscript
- Dynamic LDVB estimation (`exdqlmLDVB`) is not currently presented.
- Static regression workflow is not currently presented:
  - `regMod`
  - `exal_static_LDVB`
  - `exal_static_mcmc`
- Posterior predictive synthesis is not currently presented:
  - `exdqlm_synthesize_from_draws`
- exAL utility functions are not currently presented:
  - `dexal`, `pexal`, `qexal`, `rexal`, `get_gamma_bounds`

### Missing provenance and related-software positioning
- exAL utility functions should be explicitly tied to the distribution introduced in:
  - Yan, Y., Zheng, X., and Kottas, A. (2025). *A new family of error distributions for Bayesian quantile regression*. Bayesian Analysis. DOI: `10.1214/25-BA1507`.
- Add a brief related-software note for:
  - `https://github.com/xzheng42/bqrgal-examples/tree/main`
- Clarify manuscript positioning:
  - `bqrgal-examples` provides result-reproduction scripts for regression/prediction workflows.
  - `exdqlm` provides a packaged R interface with distribution-level utilities (`d/p/q/r`), diagnostics/forecast workflows, and robust C++-backed implementations where available.

### Outdated API usage in manuscript code
- `exdqlmChecks(...)` appears in manuscript code; should be `exdqlmDiagnostics(...)`.
- Old helper signatures still appear (explicit `y =` where current API no longer expects it):
  - `exdqlmPlot(y = ..., ...)`
  - `compPlot(y = ..., ...)`
  - `exdqlmForecast(y = ..., ...)`

### Inference narrative mismatch
- Manuscript is currently ISVB-centric in method exposition and examples.
- Updated target: make LDVB the primary approximate-inference method in the manuscript for VB.
- Keep MCMC as exact posterior reference/baseline.
- Dynamic MCMC now includes a C++ FFBS backend path; manuscript/runtime comparisons must explicitly state backend mode/profile.

---

## P0: Must Complete Before Submission

### A) Reframe core methodology around current inference strategy
- [ ] Replace ISVB-first exposition in Methods with LDVB-first exposition.
- [ ] Update algorithm descriptions/equations/pseudocode to match LDVB implementation.
- [ ] Reframe comparative text: LDVB (fast approximate) vs MCMC (exact baseline).
- [ ] Decide final ISVB policy for paper:
  - remove from main text entirely, or
  - keep only brief legacy note (not central method).

### B) API and code-block correctness pass (full manuscript)
- [ ] Replace all `exdqlmChecks` references with `exdqlmDiagnostics`.
- [ ] Update outdated helper calls (`exdqlmPlot`, `compPlot`, `exdqlmForecast`) to current signatures.
- [ ] Execute every manuscript code block and verify no stale arguments/functions remain.

### C) Add missing methods coverage
- [ ] Add concise subsection for dynamic LDVB (`exdqlmLDVB`).
- [ ] Add concise subsection for static regression/exAL workflows:
  - `regMod`, `exal_static_LDVB`, `exal_static_mcmc`.
- [ ] Add concise subsection for synthesis:
  - `exdqlm_synthesize_from_draws` (inputs, assumptions, outputs, constraints).
- [ ] Add concise subsection for exAL distribution helpers:
  - `dexal`, `pexal`, `qexal`, `rexal`, `get_gamma_bounds`.
- [ ] In the exAL subsection, cite Yan et al. (2025; DOI `10.1214/25-BA1507`) and add a brief, neutral comparison to `bqrgal-examples` (scope and interface differences).

### D) Replace and regenerate examples/figures tied to old approach
- [ ] Identify all figures/tables generated from ISVB-centered analyses.
- [ ] Replace those analyses with LDVB-centered workflows where appropriate.
- [ ] Regenerate all affected figures/tables and update captions/discussion text.
- [ ] Ensure examples are small, deterministic, and reviewer-runnable.

### E) Submission-quality writing and structure
- [ ] Tighten Introduction to state problem, contribution, and package scope clearly.
- [ ] Ensure method-order is logical: model -> inference -> diagnostics -> examples.
- [ ] Tighten Conclusion to reflect delivered functionality and realistic limitations.

---

## P1: Other things to do.

### F) Computational evidence section
- [ ] Add runtime and quality comparison tables for representative tasks:
  - LDVB vs MCMC (dynamic)
  - static LDVB vs static MCMC
- [ ] Define and report benchmark backend profiles explicitly for fair comparisons:
  - Profile A: pure R baseline (`use_cpp_kf=FALSE`, `use_cpp_mcmc=FALSE`, samplers/postpred OFF).
  - Profile B: matched core C++ (`use_cpp_kf=TRUE`, `use_cpp_mcmc=TRUE`, `cpp_mcmc_mode="fast"`, samplers/postpred OFF).
- [ ] Report environment details for reproducibility (CPU, R version, seeds, dataset sizes).
- [ ] Include uncertainty/accuracy metrics alongside runtime (not runtime alone).

### G) Backend implementation clarity
- [ ] Add a short implementation note on optional C++ acceleration paths and defaults.
- [ ] State explicitly that dynamic MCMC now has a C++ FFBS backend (`exdqlm.use_cpp_mcmc`, mode `strict|fast`; current default `fast`).
- [ ] Clarify strict-vs-fast semantics in text:
  - `strict` preserves legacy R-kernel parity behavior.
  - `fast` enables C++ FFBS acceleration.
- [ ] Avoid overstating backend acceleration as universal across all inference routines.

### H) Software-paper quality controls
- [ ] Add a compact function map table: function, purpose, key inputs, key outputs.
- [ ] Add reproducibility paragraph: how to rerun all manuscript figures/tables end-to-end.
- [ ] Ensure notation is consistent across dynamic, static, and synthesis sections.

---

## P2: Nice-to-Haves

- [ ] Add sensitivity checks for at least one key example (prior/tuning robustness).
- [ ] Add supplementary material index for scripts and data artifacts.

---

## Required Example Coverage Matrix

### Dynamic modeling
- [ ] `exdqlmMCMC` (exact posterior baseline; disclose backend mode/profile used in each result)
- [ ] `exdqlmLDVB` (primary approximate inference in manuscript)
- [ ] `transfn_exdqlmISVB` only if retained with explicit legacy/limited framing

### Static modeling
- [ ] `regMod`
- [ ] `exal_static_LDVB`
- [ ] `exal_static_mcmc`

### Synthesis and utilities
- [ ] `exdqlm_synthesize_from_draws`
- [ ] `dexal`, `pexal`, `qexal`, `rexal`, `get_gamma_bounds`

### Diagnostics/forecast/visualization
- [ ] `exdqlmDiagnostics`
- [ ] `exdqlmForecast`
- [ ] `exdqlmPlot`
- [ ] `compPlot`

---

## Final Submission Gates
- [ ] All manuscript code blocks execute successfully with the current package.
- [ ] All figures/tables are regenerated from tracked scripts (no manual edits).
- [ ] No deprecated function names or outdated signatures remain.
- [ ] Main narrative reflects current package capabilities (version-agnostic framing).
- [ ] Inference narrative is coherent and aligned with LDVB-first positioning.
- [ ] Runtime comparison sections disclose backend profile/mode so VB-vs-MCMC timing is backend-fair.
- [ ] Any claim of MCMC/VB speed advantage is tied to one disclosed backend profile and one disclosed dataset/task setting.
- [ ] Claims are supported by reproducible empirical evidence in manuscript artifacts.
- [ ] exAL provenance and related-software positioning are accurate and appropriately cited.
