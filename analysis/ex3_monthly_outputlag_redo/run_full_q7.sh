#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_path="${script_dir}/config_q7_full.yml"
output_root="${script_dir}/outputs/monthly_outputlag_q7_full"
log_dir="${output_root}/logs"

mkdir -p "${log_dir}"
find "${output_root}" -type f \( -name '*.rds' -o -name '*.rda' -o -name '*.RData' \) -delete
find "${output_root}" -mindepth 1 -type f ! -name '.gitignore' -delete || true
find "${output_root}" -mindepth 1 -type d -empty -delete || true
mkdir -p "${log_dir}"

stamp="$(date +%Y%m%d_%H%M%S)"
console_log="${log_dir}/console_${stamp}.log"
pid_file="${log_dir}/monthly_outputlag_q7_full.pid"

nohup bash -lc "exec Rscript \"${script_dir}/run_all.R\" --config \"${config_path}\"" \
  > "${console_log}" 2>&1 < /dev/null &

run_pid=$!
echo "${run_pid}" > "${pid_file}"

echo "pid=${run_pid}"
echo "console_log=${console_log}"
echo "pid_file=${pid_file}"
