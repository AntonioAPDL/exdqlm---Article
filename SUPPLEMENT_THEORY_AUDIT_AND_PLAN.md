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
  `/home/jaguir26/local/src/exdqlm---Article/supplement-theory.tex`
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
