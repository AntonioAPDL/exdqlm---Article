# Supplement Theory Audit and Construction Plan

Local working document. Do not treat this as manuscript text yet.

Purpose: prepare a high-quality supplementary document that gives the main
model expressions and algorithms underlying the current `exdqlm` package.
Comparison with Barata et al. (2022) is deferred to a later document pass.

Current package source checked against this plan:

- Package repo: `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile`
- Package branch: `cransub/0.4.0`
- Article repo: `/home/jaguir26/local/src/exdqlm---Article`

## 1. Target Scope

The supplement should cover the models actually implemented in the package:

1. Dynamic DQLM:
   - AL likelihood.
   - Gaussian linear latent dynamic state.
   - Conjugate priors for non-state parameters.
   - MCMC by Gibbs/FFBS.
   - VB by CAVI.

2. Dynamic exDQLM:
   - exAL likelihood.
   - Gaussian linear latent dynamic state.
   - Conjugate priors where available.
   - MCMC by Gibbs/FFBS plus a one-dimensional update for `gamma`.
   - VB by LDVB, using a Laplace-Delta approximation for the nonconjugate
     `(sigma, gamma)` block.

3. Static AL regression:
   - AL likelihood.
   - Ridge/Gaussian coefficient prior.
   - RHS-NS sparse coefficient prior.
   - MCMC and VB.

4. Static exAL regression:
   - exAL likelihood.
   - Ridge/Gaussian coefficient prior.
   - RHS-NS sparse coefficient prior.
   - MCMC plus a one-dimensional update for `gamma`.
   - LDVB with a Laplace-Delta approximation for the nonconjugate
     `(sigma, gamma)` block.

## 2. Recommended Supplement Structure

The supplement should be normalized across models. Each model section should
use the same internal order:

1. Model hierarchy.
2. Augmented likelihood representation.
3. Prior specification.
4. Full joint density, up to normalizing constants.
5. Full conditional distributions or conditional kernels.
6. MCMC algorithm.
7. Mean-field factorization.
8. VB/CAVI or LDVB updates.
9. ELBO expression used for convergence monitoring.
10. Implementation notes, including which parts are exact and which are
    approximate.

Recommended top-level supplement outline:

```text
S1. Notation and Distributional Building Blocks
S2. Dynamic DQLM under the AL Likelihood
S3. Dynamic exDQLM under the exAL Likelihood
S4. Static AL and exAL Regression with Ridge Priors
S5. Static AL and exAL Regression with the RHS-NS Prior
S6. Slice and Laplace-Delta Updates for Nonconjugate Blocks
S7. Package-to-Algorithm Map
```

The article should stay compact. The supplement can be precise, but it should
avoid implementation trivia that does not change the statistical target.

## 3. Source Map

### 3.1 Dynamic DQLM and Static AL Regression

Primary source:

- `/home/jaguir26/local/src/DQLM-and-BQR---Theory/main.tex`

Useful locations:

- Static AL regression hierarchy: line 68.
- Static AL full posterior joint: line 99.
- Static AL Gibbs conditionals and sampler: lines 137-222.
- Static AL VB/CAVI updates: lines 235-337.
- Static AL ELBO: lines 349-530.
- Dynamic DQLM hierarchy: line 746.
- Dynamic DQLM full posterior joint: line 784.
- Dynamic DQLM Gibbs/FFBS conditionals and sampler: lines 840-911.
- Dynamic DQLM VB/CAVI updates: lines 927-1048.
- Dynamic DQLM ELBO: lines 1061-1191.

Coverage assessment:

- Complete for dynamic DQLM with AL likelihood.
- Complete for static AL regression with Gaussian/ridge coefficient prior.
- Ready to transcribe into the supplement after notation normalization.

### 3.2 Dynamic exDQLM

Primary source:

- `/home/jaguir26/local/src/univ-exDQLM---Ensemble/main.tex`

Useful locations:

- Dynamic exAL augmentation: line 108.
- Conditionally Gaussian pseudo-observation form: line 143.
- Complete augmented joint model: line 160.
- MCMC full conditional blocks: line 195.
- Latent `v_t` update: line 210.
- Latent `s_t` update: line 230.
- State path FFBS update: line 256.
- `sigma` update: line 296.
- `gamma` nonconjugate update target: line 328.
- Gibbs/MH algorithm: line 371.
- VB factorization and CAVI schedule: line 384.
- State, `v_t`, `s_t`, and `(sigma, gamma)` VB factors: lines 416-501.
- Laplace-Delta approximation for `(sigma, gamma)`: line 549.
- ELBO decomposition: line 658.

Secondary source:

- `/home/jaguir26/local/src/exDQLM---Ensemble/main.tex`

Useful secondary locations:

- exAL augmentation: line 241.
- Full conditionals: line 314.
- Gibbs/MH and CAVI algorithms: line 533.
- Laplace-Delta and full ELBO details: lines 1033-1581.

Coverage assessment:

- Complete for hierarchy, full joint, conditional kernels, FFBS, LDVB, and ELBO.
- Needs one supplement-level adjustment: the TeX notes usually describe the
  `gamma` update as MH or MH/slice, while the current package default is a
  bounded univariate slice update for `gamma` with exact `sigma` update given
  `gamma`. The supplement draft now includes the generic bounded-slice
  algorithm; it still needs a final line-by-line check against `utils.R`.

### 3.3 Static exAL Regression with Ridge Prior

Primary source:

- `/home/jaguir26/local/src/exAL---Regression/main.tex`

Useful locations:

- Static exAL model and gamma reparameterization: line 53.
- Latent-variable representation: line 109.
- Prior specification: line 162.
- Full joint distribution: line 198.
- Gibbs full conditionals: line 230.
- `beta` conditional: line 247.
- `s_i` conditional: line 279.
- `v_i` conditional: line 321.
- `sigma` conditional: line 348.
- `gamma` nonconjugate conditional kernel: line 398.
- Static exAL MCMC algorithm: line 438.
- Static exAL VB factorization and CAVI: line 573.
- `q_beta`, `q_s`, `q_v`, and `q_{sigma,gamma}` updates:
  lines 597, 686, 785, and 910.
- Laplace-Delta approximation: line 1019.
- ELBO: line 1412.

Secondary focused sources:

- `/home/jaguir26/local/src/Static-exAL-Regression---MCMC/main.tex`
- `/home/jaguir26/local/src/Static-exAL-Regression---VB/main.tex`

Coverage assessment:

- Complete for static exAL regression with Gaussian/ridge coefficient prior.
- Ready to transcribe after notation normalization.
- The supplement should explicitly state that the AL static model is obtained
  by setting `gamma = 0`, matching the package flags `dqlm.ind = TRUE` and
  `al.ind = TRUE`.

### 3.4 Static AL/exAL Regression with the RHS-NS Prior

Primary sources:

- `/home/jaguir26/local/src/RHS---Implementations/main.tex`
- `/home/jaguir26/local/src/Q-DESN---Theory-for-implementation/main.tex`
- `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/R/static_beta_prior.R`

Do not use the older direct-RHS log-scale derivations as the supplement target.
Those are useful historical/context files, but the package-paper sparse-prior
derivation should focus on the conjugate `rhs_ns` path.

Useful locations in `RHS---Implementations/main.tex`:

- Regularized horseshoe prior discussion: line 202.
- Nishimura-Suchard reformulation: line 305.
- Fictitious-data augmentation: line 374.
- Which conditionals stay the same and which change: line 395.
- Fixed versus random slab scale `zeta`: line 440.
- Side-by-side mathematical comparison: line 638.
- Gibbs-friendly RHS-NS algorithm: line 762.

Useful locations in `Q-DESN---Theory-for-implementation/main.tex`:

- RHS-NS conditional law and effective coefficient variance: lines 91-123.
- Pseudo-data interpretation: lines 128-133.
- RHS-NS posterior factorization and IG auxiliary representation: lines
  160-183.
- Full conditionals for `lambda_j^2`, `nu_j`, `tau^2`, `xi`, and `zeta^2`:
  lines 240-284.
- Mean-field RHS-NS factorization and VB updates: lines 369-463.
- ELBO decomposition: lines 501-540.

Historical/non-target location:

- `/home/jaguir26/local/src/VB-for-Horseshoe-Regression/main.tex` contains
  older direct-RHS expressions, including nonconjugate log-scale blocks. Do not
  use those formulas as the package-paper `rhs_ns` derivation.

Useful locations in current package code:

- Prior dispatch and controls:
  `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/R/static_beta_prior.R`,
  line 9.
- RHS-NS initialization:
  `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/R/static_beta_prior.R`,
  line 989.
- RHS-NS VB update:
  `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/R/static_beta_prior.R`,
  line 1194.
- RHS-NS ELBO contribution:
  `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/R/static_beta_prior.R`,
  line 1295.
- RHS-NS MCMC update:
  `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/R/static_beta_prior.R`,
  line 1399.

Coverage assessment:

- The RHS-NS hierarchy, conditionals, VB updates, and term-level ELBO pieces do
  exist locally. The most useful TeX source is
  `Q-DESN---Theory-for-implementation/main.tex`, and the implementation source
  of truth is `static_beta_prior.R`.
- The remaining work is not a new derivation from scratch; it is a careful
  reconciliation pass to ensure the supplement formulas match the current
  package code exactly, including fixed-versus-random `zeta2` behavior and
  intercept-shrinkage behavior.

## 4. Current Package Implementation Map

Dynamic functions:

- `exdqlmMCMC()`:
  `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/R/exdqlmMCMC.R`,
  function definition near line 246.
- `exdqlmLDVB()`:
  `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/R/exdqlmLDVB.R`,
  function definition near line 148.
Static functions:

- `exalStaticMCMC()`:
  `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/R/exalStaticMCMC.R`,
  function definition near line 198.
- `exalStaticLDVB()`:
  `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/R/exalStaticLDVB.R`,
  function definition near line 1041.
- Static coefficient-prior machinery:
  `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/R/static_beta_prior.R`.

Shared implementation:

- Bounded univariate slice sampler:
  `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/R/utils.R`,
  line 239.
- Static AL alias `al.ind` for `dqlm.ind`:
  `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/R/utils.R`,
  line 613.
- Global inference controls and warmup configuration:
  `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/R/exal_inference_config.R`.

## 5. What We Can Draft Immediately

The following sections can be drafted now with high confidence:

1. S1 notation and AL/exAL mixture representations.
2. S2 dynamic DQLM hierarchy, full joint, Gibbs/FFBS, CAVI, and ELBO.
3. S3 dynamic exDQLM hierarchy, full joint, conditionals, LDVB, and ELBO.
4. S4 static AL/exAL regression with ridge prior.
5. S6 generic bounded-slice and Laplace-Delta description.
6. S7 package-to-algorithm map.

At this point, the supplement draft has no intentional large mathematical
placeholders. The remaining work is verification and polishing, not new
derivation from scratch.

## 6. Missing or Incomplete Items

### Item A: RHS-NS package-exact reconciliation

Status: mostly available and now drafted in the supplement.

The following pieces are available:

- Full `rhs_ns` hierarchy and coefficient precision contribution.
- Full conditionals for `lambda_j^2`, `nu_j`, `tau^2`, `xi`, and `zeta^2`.
- VB updates for the conjugate IG scale block.
- Term-by-term RHS-NS ELBO contribution matching the structure of
  `static_beta_prior.R:1295`.

Remaining work:

- Do a line-by-line verification pass against `static_beta_prior.R`, especially
  the fixed-`zeta2` branch and the unshrunk-intercept contribution.
- Confirm notation in the static ridge/exAL section feeds cleanly into the
  RHS-NS section.

### Item B: Bounded slice sampler algorithm

Status: drafted in the supplement.

Why this matters:

- The code has the sampler.
- The TeX theory notes mostly say MH or MH/slice.
- The supplement should match the package default.
- Remaining work is to verify the algorithm statement against the current
  implementation in `R/utils.R`.

## 7. Proposed Writing Plan

Step 1: Create a new supplement TeX file.

- Suggested path:
  `/home/jaguir26/local/src/exdqlm---Article/exdqlm-supplement.tex`
- Keep it separate from the main article at first.
- Add only after we decide whether the supplement is included in the submission
  bundle or maintained as an online appendix.

Step 2: Build the supplement skeleton.

- Add S1-S8 sections from this plan.
- Use a small set of shared notation macros.
- Avoid mixing local code variable names with mathematical symbols unless the
  link is useful for users.

Step 3: Transcribe complete sections.

- Dynamic DQLM from `DQLM-and-BQR---Theory/main.tex`.
- Dynamic exDQLM from `univ-exDQLM---Ensemble/main.tex`.
- Static AL/exAL ridge from `exAL---Regression/main.tex`.

Step 4: Write implementation-exact slice sampler section.

- Derive no new target kernel unless needed.
- Use the already-derived gamma kernels.
- Add algorithm pseudocode for bounded slice sampling.

Step 5: Consolidate static RHS-NS.

- Start with the package code in `static_beta_prior.R`.
- Use `Q-DESN---Theory-for-implementation/main.tex` for the conjugate `rhs_ns`
  formulas.
- Use `RHS---Implementations/main.tex` only for conceptual Nishimura-Suchard
  context.
- Ignore direct-RHS nonconjugate expressions for this supplement pass.
- Verify the drafted formulas against the current package code.

Step 6: Add package-to-algorithm map.

- One compact table mapping package functions to model, likelihood, coefficient
  prior, inference method, nonconjugate update, and diagnostics.

Step 7: Final audit.

- For every expression in the supplement, verify whether it is:
  exact implementation target, approximation used by LDVB, monitoring ELBO, or
  conceptual prior explanation.
- Mark approximation status explicitly.
- Avoid claims that depend on local run settings, seeds, examples, or branch
  history.

## 8. Quality Criteria for the Supplement

The final supplement should:

- Use neutral, factual academic writing.
- Match the current package implementation, not an older derivation.
- Clearly distinguish exact Gibbs/CAVI updates from approximate LDVB steps.
- Keep notation consistent across dynamic and static models.
- Use compact algorithms rather than long prose where possible.
- Avoid idiosyncratic code history or local audit details.
- Be readable to a statistically trained reader who has not seen the code.

## 9. Current Sparse-prior Decision

Treat ridge as the default/static baseline and `rhs_ns` as the sparse-prior
implementation to document. The direct `rhs` path is intentionally excluded
from the current supplement because its log-scale block is nonconjugate and is
not the target derivation for the package paper.

## 10. Remote jerez Check

Checked `jerez.be.ucsc.edu` for local source repositories under the usual user
locations. No matching `exdqlm`, `RHS`, `Q-DESN`, or horseshoe source repos
were found under `/home/jaguir26/local/src`, `/home/jaguir26/src`, or nearby
home-directory source locations. The relevant theory sources for this pass are
therefore the muscat local repositories listed above.

## 11. Normalization and Polish Pass

Date: 2026-04-30.

The supplement was normalized using the following contract:

- Use `p_gamma` only for the exAL internal quantile map.
- Use `pi_gamma(gamma)` for the prior density of `gamma`.
- Reserve `xi` for the RHS-NS half-Cauchy auxiliary variable.
- Use `z_gamma` for the transformed `gamma` coordinate in Laplace-Delta
  calculations.
- Treat `IG(a,b)` as inverse-gamma with rate `b`.
- Treat `GIG(lambda, chi, psi)` as the package parameterization with kernel
  `x^(lambda-1) exp{-(chi/x + psi x)/2}`.
- Treat all unsubscripted expectations in VB sections as expectations under
  the current mean-field distribution `q`.

Corrections made in this pass:

- Removed the notation collision between the exAL map `p(gamma)` and the
  prior density for `gamma` by renaming the map to `p_gamma` and the prior to
  `pi_gamma(gamma)`.
- Removed the notation collision between the Laplace-Delta transform `xi` and
  the RHS-NS auxiliary variable `xi` by using `z_gamma` for the transformed
  `gamma` coordinate.
- Corrected the generic Delta approximation from a product form to the usual
  additive second-order approximation.
- Added an explicit distribution-parameterization contract to the supplement.
- Expanded the package-to-algorithm map to distinguish exact Gibbs/CAVI blocks
  from Laplace-Delta and bounded-slice blocks.
- Recompiled `exdqlm-supplement.tex` after the normalization pass; the final
  compile completed without LaTeX warnings about undefined references,
  reruns, overfull boxes, or underfull boxes.

Equation-family verification matrix:

| Supplement block | Source checked | Status | Notes |
| --- | --- | --- | --- |
| AL mixture and dynamic DQLM MCMC/VB | `DQLM-and-BQR---Theory/main.tex` lines 840-1048 | Checked | Uses the same AL constants, IG scale update, GIG latent update, and variational pseudo-observation. |
| Dynamic exDQLM hierarchy and MCMC conditionals | `univ-exDQLM---Ensemble/main.tex` lines 108-341 | Checked | Supplement uses the same exAL augmentation and conditional kernels; sampler wording reflects current package slice default rather than older MH-only notes. |
| Dynamic exDQLM LDVB moments | `univ-exDQLM---Ensemble/main.tex` lines 404-690 and `R/exdqlmLDVB.R` LD block | Checked with approximation note | Kappa moment definitions and Laplace-Delta role are aligned. Stored diagnostic names are implementation metadata rather than theory targets. |
| Static exAL ridge MCMC/VB | `exAL---Regression/main.tex` lines 247-398, 573-710, 910-1088, and 1412-1455 | Checked | Static beta, latent `s`, latent `v`, sigma, gamma, and LDVB factorization are aligned with source notes. |
| RHS-NS MCMC/VB/ELBO | `Q-DESN---Theory-for-implementation/main.tex` lines 91-183, 240-284, 369-463, 501-540 and `R/static_beta_prior.R` lines 822-1398 | Checked | Term-by-term ELBO matches the package structure. Fixed `zeta2`, unshrunk intercept behavior, and warmup/freeze scheduling were reconciled in the 2026-04-30 safety pass. |
| Bounded slice sampler | `R/utils.R` lines 239-330 | Checked | Algorithm matches stepping-out, truncation to bounds, shrinkage, and acceptance logic. |

2026-04-30 safety pass:

- Rechecked the AL dynamic DQLM MCMC/VB/ELBO block against
  `DQLM-and-BQR---Theory/main.tex` lines 840-1191.
- Rechecked the exAL dynamic hierarchy, MCMC conditionals, LDVB moment block,
  and Laplace-Delta role against `univ-exDQLM---Ensemble/main.tex` lines
  108-341 and 404-690, plus the current dynamic LDVB implementation.
- Rechecked the static exAL ridge MCMC/VB/ELBO block against
  `exAL---Regression/main.tex` lines 247-398, 573-710, 910-1088, and
  1412-1455.
- Rechecked the RHS-NS hierarchy, MCMC/VB scale updates, fixed-versus-random
  `zeta2` behavior, unshrunk-intercept contribution, and term-level ELBO
  against `Q-DESN---Theory-for-implementation/main.tex` lines 240-284,
  422-463, and 501-540, plus `R/static_beta_prior.R`.
- Added explicit prose clarifying that RHS-NS tau warmup/freeze controls in the
  package are update-scheduling devices and do not change the conditional or
  coordinate targets printed in the supplement.
- Rechecked bounded slice-sampler prose against the current implementation in
  `R/utils.R` lines 239-330.

## 12. JSS-facing Supplement Polish Pass

Date: 2026-04-30.

The supplement was converted from an internal working derivation note into a
submission-facing document:

- Switched `exdqlm-supplement.tex` to the local `jss` class with `nojss` and
  `noheadings`, retaining JSS markup for package names, code, authors,
  abstract, keywords, and address information.
- Removed the public "Working draft" metadata, internal source-path comments,
  and the public second-pass verification checklist from the TeX file. The
  derivation trace remains in this audit document.
- Added a short scope-and-organization section so readers understand how to use
  the supplement before entering the model-specific mathematics.
- Normalized section and subsection headings to sentence style and changed the
  notation and package-map displays into captioned tables.
- Prefixed supplement tables and displayed equations with `S` numbering to
  avoid ambiguity with the main article.
- Reduced unnecessary packages and resolved JSS-width line breaks in the
  mathematical prose and displayed equations.
- Recompiled the supplement after the JSS-facing polish pass. The final log has
  no undefined references, rerun warnings, overfull boxes, or underfull boxes.
  The only remaining warning is the standard `hyperindex` warning emitted by
  the bundled `jss.cls` under this TeX Live/hyperref combination.

Remaining verification work before submission:

- Do one final visual PDF read for page breaks and equation readability.
- Decide whether the official submitted supplement should include a short
  reference list, or rely on the main article for citations.

## 13. Implementation-match audit against `cransub/0.4.0`

Date: 2026-04-30.

Source of truth for this pass:

- Article repo: `/home/jaguir26/local/src/exdqlm---Article`
- Article commit at start of pass: `8e81e019380acdf8e4930a918946fe78c21e1e3e`
- Package repo: `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile`
- Package branch: `cransub/0.4.0`
- Package commit: `33adab3ad545ba3ceb013d8e3682be2bdbfa3118`

Audit rule:

- Treat the package implementation as fixed for this pass.
- Correct `exdqlm-supplement.tex` only when the document is inaccurate,
  incomplete in a submission-relevant way, or likely to mislead a reader about
  the current implementation.
- Do not patch the package from this audit.

Findings:

- Dynamic AL/DQLM MCMC: the state FFBS pseudo-observation, inverse-gamma
  `sigma` update, and GIG `v_t` update in `exdqlmMCMC.R` match the supplement.
  The implementation includes optional warmup scheduling for state, latent, and
  `sigma` blocks. This is a scheduling detail, not a formula mismatch.
- Dynamic AL/DQLM VB: the reduced CAVI core in `utils.R` matches the supplement
  pseudo-response, GIG latent update, inverse-gamma `sigma` factor, and ELBO
  decomposition.
- Dynamic exAL/exDQLM MCMC: the GIG `v_t`, truncated-normal `s_t`, FFBS state
  update, exact conditional `sigma` GIG update, and default bounded-slice
  `gamma` kernel in `exdqlmMCMC.R` match the supplement. The implementation
  also exposes transformed random-walk alternatives, so the package map was
  clarified to say bounded slice is the default rather than the only path.
- Dynamic exAL/exDQLM VB: the kappa-moment definitions, `q(v_t)`, `q(s_t)`,
  state pseudo-response, Laplace-Delta `(sigma, gamma)` block, and ELBO block
  structure in `exdqlmLDVB.R` match the supplement. The implementation may
  temporarily hold the `s_t` and `(sigma, gamma)` blocks during warmup; this is
  a numerical schedule and does not alter the displayed targets. A later ELBO
  pass found one narrow diagnostic discrepancy: the closed-form entropy of a
  positive truncated-normal factor should contain `0.5 * (1 - alpha * Lambda)`
  when `alpha = mu / tau`, whereas the current exAL LDVB code uses the opposite
  sign in this entropy term. This affects the monitored ELBO value for exAL
  LDVB, not the coordinate update for `q(s_t)`.
- Static AL regression MCMC/VB: the reduced static path in `exalStaticMCMC.R`
  and `utils.R` matches the supplement's AL special-case updates after replacing
  state moments by static regression moments.
- Static exAL regression MCMC: the Gaussian coefficient update, GIG `v_i`,
  truncated-normal `s_i`, exact conditional `sigma` GIG update, and default
  bounded-slice `gamma` kernel in `exalStaticMCMC.R` match the supplement. As
  with the dynamic case, the package also exposes transformed random-walk
  alternatives.
- Static exAL regression VB: `exalStaticLDVB.R` matches the supplement's
  Gaussian `q(beta)`, GIG `q(v_i)`, truncated-normal `q(s_i)`,
  Laplace-Delta `q(sigma,gamma)`, and ELBO decomposition. The same
  positive-truncated-normal entropy sign discrepancy appears in the static
  exAL LDVB monitored ELBO.
- RHS-NS sparse prior: `static_beta_prior.R` matches the supplement's active
  coefficient precision, inverse-gamma MCMC updates, mean-field VB updates,
  fixed-versus-random `zeta2` branches, unshrunk-intercept contribution, and
  term-level ELBO. The direct nonconjugate `rhs` path remains intentionally
  excluded from the supplement.
- State evolution notation: the supplement used generic `W_t`; the package
  induces the evolution covariance through discount-factor filtering. The
  supplement was clarified to state that `W_t` denotes the covariance induced by
  the package's discount-factor construction.
- Warmup/scheduling notation: the supplement previously described the update
  targets but did not state that the package may schedule early updates for
  numerical stability. A concise package-map note was added. This keeps the
  supplement implementation-honest without turning it into a code manual.

Supplement corrections made in this pass:

- Clarified the discount-factor interpretation of the dynamic evolution
  covariance.
- Added a compact implementation note explaining that warmup/scheduling controls
  change update timing, not the statistical targets.
- Revised the package-to-algorithm table to say the bounded-slice `gamma` update
  is the default exAL MCMC path and that random-walk alternatives are exposed.

No package-code changes were made in this audit.

## 14. ELBO derivability and entropy-expression pass

Date: 2026-04-30.

Purpose:

- Convert the ELBO sections from high-level decompositions into computable
  formulas that a reader can map to the package diagnostics.
- Reuse exact entropy formulas when available and state explicitly when the
  package uses Laplace-Delta approximations.

Sources checked:

- Dynamic AL/DQLM ELBO: `DQLM-and-BQR---Theory/main.tex` lines 1061-1197 and
  the reduced CAVI implementation in `R/utils.R` lines 1082-1265.
- Static AL/BQR ELBO: `DQLM-and-BQR---Theory/main.tex` lines 349-532 and the
  reduced static CAVI implementation in `R/utils.R` lines 1420-1665.
- Dynamic exAL/exDQLM ELBO: `univ-exDQLM---Ensemble/main.tex` lines 658-789,
  `exDQLM---Ensemble/main.tex` lines 1524-1578, and `R/exdqlmLDVB.R`.
- Static exAL ELBO: `exAL---Regression/main.tex` lines 1412-1805 and
  `R/exalStaticLDVB.R` lines 2022-2097.

Supplement changes made:

- Added a reusable ELBO-building-block subsection with Gaussian,
  inverse-gamma, GIG, positive truncated-normal, and Laplace-Delta entropy
  formulas.
- Expanded the dynamic AL/DQLM ELBO into the state pseudo-model contribution,
  inverse-gamma scale prior, exponential latent prior, AL likelihood, and
  entropy terms.
- Expanded the dynamic exAL/exDQLM ELBO into likelihood, latent-prior,
  nonconjugate-prior, GIG entropy, truncated-normal entropy, state, and
  Laplace-Delta entropy blocks.
- Expanded the static exAL ridge/RHS ELBO into likelihood, latent-prior,
  coefficient-prior, nonconjugate-prior, and entropy blocks, with the AL special
  case stated explicitly.

Important implementation note:

- The positive truncated-normal entropy is analytically available. With
  `u = mu / tau` and `Lambda = phi(u) / Phi(u)`, the entropy is
  `0.5 * log(2*pi*tau^2) + log(Phi(u)) + 0.5 * (1 - u * Lambda)`.
- The current package code in `R/exdqlmLDVB.R` and `R/exalStaticLDVB.R` uses
  `0.5 * (1 + u * Lambda)` for this entropy term. The moments used to update
  the truncated-normal factors are correct; the discrepancy is isolated to the
  monitored ELBO entropy contribution.
- No package-code changes were made in this supplement pass. If we want the
  CRAN branch ELBO diagnostics to match the mathematical supplement exactly,
  this sign should be patched in the package and the affected LDVB examples
  should be rerun.
