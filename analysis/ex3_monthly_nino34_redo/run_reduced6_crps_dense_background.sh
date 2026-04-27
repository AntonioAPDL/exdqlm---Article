#!/usr/bin/env bash
set -euo pipefail

ARTICLE_ROOT="${ARTICLE_ROOT:-/home/jaguir26/local/src/exdqlm---Article}"
PKG_ROOT="${EX3_MONTHLY_PKG_PATH:-/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile}"
CONFIG_PATH="$ARTICLE_ROOT/analysis/ex3_monthly_nino34_redo/config_reduced6_crps_dense.yml"
OUTPUT_DIR="$ARTICLE_ROOT/analysis/ex3_monthly_nino34_redo/outputs/monthly_reduced6_crps_dense_p015_df099_iter200"
LOG_DIR="$OUTPUT_DIR/logs"
STATE_DIR="$OUTPUT_DIR/.run_state"
PID_FILE="$STATE_DIR/reduced6_crps_dense.pid"
RUN_LOG="$STATE_DIR/reduced6_crps_dense_background.log"
LAUNCH_INFO="$STATE_DIR/reduced6_crps_dense_launch_info.txt"

mkdir -p "$LOG_DIR"
mkdir -p "$STATE_DIR"

if [[ ! -f "$PKG_ROOT/DESCRIPTION" ]]; then
  echo "Could not find exdqlm package source at $PKG_ROOT" >&2
  exit 1
fi

pkg_branch="$(git -C "$PKG_ROOT" rev-parse --abbrev-ref HEAD)"
pkg_commit="$(git -C "$PKG_ROOT" rev-parse --short HEAD)"
if [[ "$pkg_branch" != "cransub/0.4.0" ]]; then
  echo "Expected package branch cransub/0.4.0, found $pkg_branch at $PKG_ROOT" >&2
  exit 1
fi

if [[ -f "$PID_FILE" ]]; then
  old_pid="$(cat "$PID_FILE")"
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    echo "Reduced-6 dense relaunch already appears to be running with pid $old_pid"
    exit 0
  fi
fi

{
  echo "launch_time=$(date -Iseconds)"
  echo "article_root=$ARTICLE_ROOT"
  echo "package_root=$PKG_ROOT"
  echo "package_branch=$pkg_branch"
  echo "package_commit=$pkg_commit"
  echo "config_path=$CONFIG_PATH"
  echo "output_dir=$OUTPUT_DIR"
} > "$LAUNCH_INFO"

setsid env EX3_MONTHLY_PKG_PATH="$PKG_ROOT" \
  Rscript "$ARTICLE_ROOT/analysis/ex3_monthly_nino34_redo/run_all.R" \
  --config "$CONFIG_PATH" \
  --targets prep,fit,figures,manifest \
  > "$RUN_LOG" 2>&1 < /dev/null &

pid="$!"
echo "$pid" > "$PID_FILE"
echo "Started reduced-6 dense CRPS relaunch with pid $pid"
echo "Package: $pkg_branch@$pkg_commit"
echo "Log: $RUN_LOG"
