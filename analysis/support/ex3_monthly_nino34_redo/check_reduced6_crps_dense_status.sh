#!/usr/bin/env bash
set -euo pipefail

ARTICLE_ROOT="${ARTICLE_ROOT:-/home/jaguir26/local/src/exdqlm---Article}"
OUTPUT_DIR="$ARTICLE_ROOT/analysis/support/ex3_monthly_nino34_redo/outputs/monthly_reduced6_crps_dense_p015_df099_iter200"
LOG_DIR="$OUTPUT_DIR/logs"
STATE_DIR="$OUTPUT_DIR/.run_state"
PID_FILE="$STATE_DIR/reduced6_crps_dense.pid"
RUN_LOG="$STATE_DIR/reduced6_crps_dense_background.log"
LAUNCH_INFO="$STATE_DIR/reduced6_crps_dense_launch_info.txt"
PROGRESS_LOG="$LOG_DIR/ex3_monthly_progress.log"
FIT_SUMMARY="$OUTPUT_DIR/tables/ex3_monthly_fit_summary.csv"
LAMBDA_SCREEN="$OUTPUT_DIR/tables/ex3_monthly_lambda_screen.csv"
MANIFEST="$LOG_DIR/ex3_monthly_manifest.md"

status_printed=0
if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE")"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "status=running pid=$pid"
  else
    echo "status=not-running last_pid=$pid"
  fi
  status_printed=1
elif [[ -f "$PROGRESS_LOG" ]]; then
  pid="$(sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p' "$PROGRESS_LOG" | tail -n 1)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "status=running pid=$pid source=progress-log"
    status_printed=1
  fi
fi

if [[ "$status_printed" -eq 0 ]]; then
  echo "status=not-launched"
fi

if [[ -f "$LAUNCH_INFO" ]]; then
  echo
  echo "launch_info:"
  sed -n '1,40p' "$LAUNCH_INFO"
else
  echo
  echo "launch_info: unavailable"
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
