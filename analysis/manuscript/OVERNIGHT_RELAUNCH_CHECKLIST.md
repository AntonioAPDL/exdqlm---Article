# Overnight Relaunch Checklist

This checklist is the reproducible relaunch plan for the manuscript examples
and the alternative monthly Example 3 sandbox against the current article-facing
`0.4.0` package checkout.

## Package + repo state

- Article repo: `/home/jaguir26/local/src/exdqlm---Article`
- Package repo: `/home/jaguir26/local/src/exdqlm__wt__0p4p0_article_main`
- Required package commit before launch: `d10ab93`
- Load package source through `--pkg-path` for manuscript runs.
- Use `--force-refit` for manuscript reruns so cached fits from older package
  snapshots are not reused.

## Policy decisions baked into this relaunch

- Example 1: rerun as-is.
- Example 2: manuscript workflow uses LDVB and MCMC only.
- Example 2: no ISVB figures, tables, or comparison artifacts in the article
  workflow.
- Example 3: use monthly USGS flow aggregated from the staged daily USGS file.
- Example 3: use package `nino34`.
- Example 4: run the support-only seed screen first, then rerun the tracked example using the screen-selected dataset seed.
- Alternative Example 3: rerun the reduced-6 monthly sandbox separately after
  the main manuscript Example 3 rerun.

## Pre-launch checks

Run from the article repo root:

```bash
git status --short
git rev-parse HEAD
Rscript -e "pkg <- '/home/jaguir26/local/src/exdqlm__wt__0p4p0_article_main'; cat(normalizePath(pkg), '\n')"
Rscript -e "pkgload::load_all('/home/jaguir26/local/src/exdqlm__wt__0p4p0_article_main', quiet = TRUE); cat(formals(exdqlm::exdqlmLDVB)$fix.sigma, '\n')"
```

Expected:

- article repo is clean or intentionally staged
- package repo is clean
- `fix.sigma` defaults to `FALSE`

## Launch order

Run in this order so we surface the highest-risk package changes first.

### 1. Example 4 seed screen + tracked rerun

```bash
ARTICLE=/home/jaguir26/local/src/exdqlm---Article
PKG=/home/jaguir26/local/src/exdqlm__wt__0p4p0_article_main

Rscript $ARTICLE/analysis/run_all.R \
  --stage manuscript \
  --pkg-path "$PKG" \
  --targets ex4screen \
  --force-refit \
  --skip-tests

Rscript $ARTICLE/analysis/run_all.R \
  --stage manuscript \
  --pkg-path "$PKG" \
  --targets ex4figure,ex4table \
  --force-refit \
  --skip-tests
```

### 2. Example 1

```bash
Rscript $ARTICLE/analysis/run_all.R \
  --stage manuscript \
  --pkg-path "$PKG" \
  --targets ex1mcmc,ex1quants,ex1synth \
  --force-refit \
  --skip-tests
```

### 3. Example 3 manuscript

```bash
Rscript $ARTICLE/analysis/run_all.R \
  --stage manuscript \
  --pkg-path "$PKG" \
  --targets ex3data,ex3quantcomps,ex3quantcomps_ldvb,ex3zetapsi,ex3zetapsi_ldvb,ex3forecast,ex3forecast_ldvb,ex3tables,ex3tables_ldvb \
  --force-refit \
  --skip-tests
```

### 4. Alternative Example 3 sandbox

```bash
EX3_MONTHLY_PKG_PATH="$PKG" \
Rscript $ARTICLE/analysis/ex3_monthly_nino34_redo/run_all.R \
  --config $ARTICLE/analysis/ex3_monthly_nino34_redo/config_reduced6_crps_dense.yml \
  --targets prep,fit,figures,manifest
```

### 5. Example 2

```bash
Rscript $ARTICLE/analysis/run_all.R \
  --stage manuscript \
  --pkg-path "$PKG" \
  --targets ex2quant,ex2quant_ldvb,ex2checks,ex2checks_ldvb,ex2_ldvb_diagnostics,ex2tables,ex2tables_ldvb,ex2bench \
  --force-refit \
  --skip-tests
```

### 6. Full manuscript validation pass

```bash
Rscript $ARTICLE/analysis/run_all.R \
  --stage manuscript \
  --pkg-path "$PKG"
```

This last pass intentionally reuses the freshly written caches from the
targeted reruns instead of forcing every heavy model to refit again.

## Morning review checklist

- Example 4:
  - compare convergence, runtime, coefficient recovery, and summary table
- Example 1:
  - compare posterior quantile overlays and synthesis figure
- Example 3 manuscript:
  - compare lambda choice, diagnostics table, quantile panels, and forecast
- Alternative Example 3:
  - compare winning lambda, CRPS/KL/pplc, coefficient paths, and forecast
- Example 2:
  - confirm no ISVB artifacts were regenerated
  - compare LDVB and MCMC diagnostics/benchmark values only

## Overwrite rule

- If outputs are close: overwrite tracked analysis outputs and update article
  figures/tables/text to match the rerun.
- If outputs move moderately: update article figure references and numeric
  summaries after a targeted review.
- If outputs move materially: pause before promoting anything into the article.
