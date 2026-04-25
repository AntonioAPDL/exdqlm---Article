#!/usr/bin/env bash
set -euo pipefail

ARTICLE_ROOT="${ARTICLE_ROOT:-/home/jaguir26/local/src/exdqlm---Article}"
OUTPUT_DIR="$ARTICLE_ROOT/analysis/ex3_monthly_nino34_redo/outputs/monthly_reduced6_crps_dense_p015_df099_iter200"
LOG_DIR="$OUTPUT_DIR/logs"
PID_FILE="$LOG_DIR/reduced6_crps_dense.pid"
RUN_LOG="$LOG_DIR/reduced6_crps_dense_background.log"
PROGRESS_LOG="$LOG_DIR/ex3_monthly_progress.log"
FIT_SUMMARY="$OUTPUT_DIR/tables/ex3_monthly_fit_summary.csv"
LAMBDA_SCREEN="$OUTPUT_DIR/tables/ex3_monthly_lambda_screen.csv"
MANIFEST="$LOG_DIR/ex3_monthly_manifest.md"

if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE")"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "status=running pid=$pid"
  else
    echo "status=not-running last_pid=$pid"
  fi
else
  echo "status=not-launched"
fi

if [[ -f "$LOG_DIR/reduced6_crps_dense_launch_info.txt" ]]; then
  echo
  echo "launch_info:"
  sed -n '1,40p' "$LOG_DIR/reduced6_crps_dense_launch_info.txt"
fi

if [[ -f "$PROGRESS_LOG" ]]; then
  echo
  echo "progress_tail:"
  tail -n 25 "$PROGRESS_LOG"
fi

if [[ -f "$RUN_LOG" ]]; then
  echo
  echo "run_log_tail:"
  tail -n 20 "$RUN_LOG"
fi

if [[ -f "$FIT_SUMMARY" ]]; then
  echo
  echo "fit_summary:"
  sed -n '1,20p' "$FIT_SUMMARY"
fi

if [[ -f "$LAMBDA_SCREEN" ]]; then
  echo
  echo "lambda_screen_best_by_crps:"
  Rscript -e 'x <- read.csv(commandArgs(TRUE)[1]); x <- x[is.finite(x$CRPS), ]; if (nrow(x)) print(x[which.min(x$CRPS), ], row.names = FALSE)' "$LAMBDA_SCREEN"
fi

if [[ -f "$MANIFEST" ]]; then
  echo
  echo "manifest_head:"
  sed -n '1,45p' "$MANIFEST"
fi
