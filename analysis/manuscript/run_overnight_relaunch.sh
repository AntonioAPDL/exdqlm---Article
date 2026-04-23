#!/usr/bin/env bash
set -euo pipefail

ARTICLE_ROOT="/home/jaguir26/local/src/exdqlm---Article"
PKG_ROOT="${EXDQLM_PKG_PATH:-/home/jaguir26/local/src/exdqlm__wt__0p4p0_article_main}"
STAMP="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="$ARTICLE_ROOT/analysis/manuscript/outputs/logs/overnight_relaunch_$STAMP"
MASTER_LOG="$RUN_DIR/master.log"
STATUS_TSV="$RUN_DIR/status.tsv"

mkdir -p "$RUN_DIR"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$MASTER_LOG"
}

run_step() {
  local step_name="$1"
  shift
  local step_log="$RUN_DIR/${step_name}.log"
  local start_ts end_ts elapsed status

  start_ts="$(date +%s)"
  log "START $step_name"
  log "CMD   $*"

  if "$@" >"$step_log" 2>&1; then
    status="ok"
    end_ts="$(date +%s)"
    elapsed="$((end_ts - start_ts))"
    log "DONE  $step_name (${elapsed}s)"
  else
    status="failed"
    end_ts="$(date +%s)"
    elapsed="$((end_ts - start_ts))"
    log "FAIL  $step_name (${elapsed}s) -- see $step_log"
    printf '%s\t%s\t%s\t%s\t%s\n' "$step_name" "$status" "$start_ts" "$end_ts" "$step_log" >> "$STATUS_TSV"
    exit 1
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' "$step_name" "$status" "$start_ts" "$end_ts" "$step_log" >> "$STATUS_TSV"
}

printf 'step\tstatus\tstart_epoch\tend_epoch\tlog_path\n' > "$STATUS_TSV"

log "Article root: $ARTICLE_ROOT"
log "Package root: $PKG_ROOT"
log "Package commit: $(git -C "$PKG_ROOT" rev-parse --short HEAD)"
log "Run dir: $RUN_DIR"

run_step "ex4screen" \
  Rscript "$ARTICLE_ROOT/analysis/run_all.R" \
    --stage manuscript \
    --pkg-path "$PKG_ROOT" \
    --targets ex4screen \
    --force-refit \
    --skip-tests

run_step "ex4" \
  Rscript "$ARTICLE_ROOT/analysis/run_all.R" \
    --stage manuscript \
    --pkg-path "$PKG_ROOT" \
    --targets ex4figure,ex4table \
    --force-refit \
    --skip-tests

run_step "ex1" \
  Rscript "$ARTICLE_ROOT/analysis/run_all.R" \
    --stage manuscript \
    --pkg-path "$PKG_ROOT" \
    --targets ex1mcmc,ex1quants,ex1synth \
    --force-refit \
    --skip-tests

run_step "ex3_manuscript" \
  Rscript "$ARTICLE_ROOT/analysis/run_all.R" \
    --stage manuscript \
    --pkg-path "$PKG_ROOT" \
    --targets ex3data,ex3quantcomps,ex3quantcomps_ldvb,ex3zetapsi,ex3zetapsi_ldvb,ex3forecast,ex3forecast_ldvb,ex3tables,ex3tables_ldvb \
    --force-refit \
    --skip-tests

run_step "ex3_alt_monthly" \
  env EX3_MONTHLY_PKG_PATH="$PKG_ROOT" \
  Rscript "$ARTICLE_ROOT/analysis/ex3_monthly_nino34_redo/run_all.R" \
    --config "$ARTICLE_ROOT/analysis/ex3_monthly_nino34_redo/config_reduced6_crps_dense.yml" \
    --targets prep,fit,figures,manifest

run_step "ex2" \
  Rscript "$ARTICLE_ROOT/analysis/run_all.R" \
    --stage manuscript \
    --pkg-path "$PKG_ROOT" \
    --targets ex2quant,ex2quant_ldvb,ex2checks,ex2checks_ldvb,ex2_ldvb_diagnostics,ex2tables,ex2tables_ldvb,ex2bench \
    --force-refit \
    --skip-tests

# Final manuscript pass reuses the freshly written caches instead of refitting
# every heavy model a second time. This keeps the overnight plan efficient while
# still exercising the full stage and test suite end to end.
run_step "manuscript_full_validate" \
  Rscript "$ARTICLE_ROOT/analysis/run_all.R" \
    --stage manuscript \
    --pkg-path "$PKG_ROOT"

log "All overnight relaunch steps completed successfully."
log "Status table: $STATUS_TSV"
