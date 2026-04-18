#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
config_path="${script_dir}/config_full_history_q7_refresh_lag3_150.yml"

output_root="${script_dir}/outputs/full_history_q7_discount_refresh_lag3_150"
log_dir="${output_root}/logs"
pid_path="${log_dir}/full_history_q7_discount_refresh_lag3_150.pid"

cleanup_runtime_dir() {
  local target_dir="$1"
  if [[ ! -d "${target_dir}" ]]; then
    return 0
  fi
  find "${target_dir}" -mindepth 1 -type f ! -name ".gitignore" -delete
}

cleanup_heavy_cache_files() {
  local outputs_root="${script_dir}/outputs"
  if [[ ! -d "${outputs_root}" ]]; then
    return 0
  fi
  find "${outputs_root}" -type f \( -name "*.rds" -o -name "*.rda" -o -name "*.RData" \) -delete
}

mkdir -p "${log_dir}"

if [[ -f "${pid_path}" ]]; then
  old_pid="$(cat "${pid_path}" 2>/dev/null || true)"
  if [[ -n "${old_pid}" ]] && ps -p "${old_pid}" > /dev/null 2>&1; then
    echo "A lagged refresh run is already active with pid ${old_pid}."
    exit 1
  fi
fi

cleanup_heavy_cache_files
cleanup_runtime_dir "${output_root}/cache"
cleanup_runtime_dir "${output_root}/figures"
cleanup_runtime_dir "${output_root}/tables"
cleanup_runtime_dir "${output_root}/logs"

mkdir -p "${output_root}/figures" "${output_root}/tables" "${output_root}/logs" "${output_root}/cache"
for keep_dir in "${output_root}/figures" "${output_root}/tables" "${output_root}/logs" "${output_root}/cache"; do
  if [[ ! -f "${keep_dir}/.gitignore" ]]; then
    printf '*\n!.gitignore\n' > "${keep_dir}/.gitignore"
  fi
done

timestamp="$(date +%Y%m%d_%H%M%S)"
log_path="${log_dir}/console_${timestamp}.log"

cd "${repo_root}"
setsid bash -lc "cd '${repo_root}' && exec Rscript analysis/ex3_daily_redo/run_all.R --config analysis/ex3_daily_redo/config_full_history_q7_refresh_lag3_150.yml" \
  > "${log_path}" 2>&1 < /dev/null &
pid=$!
echo "${pid}" > "${pid_path}"
sleep 3

if ! ps -p "${pid}" > /dev/null 2>&1; then
  echo "Launch failed. Check log: ${log_path}"
  exit 2
fi

cat <<EOF
Started full-history q7 lagged refresh run.
pid: ${pid}
config: ${config_path}
console log: ${log_path}
progress log: ${log_dir}/ex3_daily_progress.log
pid file: ${pid_path}

Cleanup performed before launch:
- removed all cached .rds/.rda/.RData files under ${script_dir}/outputs
- cleared stale runtime files under ${output_root}
EOF
