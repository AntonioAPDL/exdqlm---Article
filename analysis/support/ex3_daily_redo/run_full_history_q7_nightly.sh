#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
config_path="${script_dir}/config_full_history_q7_nightly_1000.yml"
output_root="${script_dir}/outputs/full_history_q7_nightly_1000"
log_dir="${output_root}/logs"
pid_path="${log_dir}/full_history_q7_nightly_1000.pid"

mkdir -p "${log_dir}" "${output_root}/cache"

if [[ -f "${pid_path}" ]]; then
  old_pid="$(cat "${pid_path}" 2>/dev/null || true)"
  if [[ -n "${old_pid}" ]] && ps -p "${old_pid}" > /dev/null 2>&1; then
    echo "A full-history nightly run is already active with pid ${old_pid}."
    exit 1
  fi
fi

timestamp="$(date +%Y%m%d_%H%M%S)"
log_path="${log_dir}/console_${timestamp}.log"

cd "${repo_root}"
setsid bash -lc "cd '${repo_root}' && exec Rscript analysis/support/ex3_daily_redo/run_all.R --config analysis/support/ex3_daily_redo/config_full_history_q7_nightly_1000.yml" \
  > "${log_path}" 2>&1 < /dev/null &
pid=$!
echo "${pid}" > "${pid_path}"
sleep 3

if ! ps -p "${pid}" > /dev/null 2>&1; then
  echo "Launch failed. Check log: ${log_path}"
  exit 2
fi

cat <<EOF
Started full-history q7 overnight run.
pid: ${pid}
config: ${config_path}
console log: ${log_path}
progress log: ${log_dir}/ex3_daily_progress.log
pid file: ${pid_path}
EOF
