#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
config_path="${script_dir}/config_long_nightly_1000.yml"
output_root="${script_dir}/outputs/long_nightly_1000"
log_dir="${output_root}/logs"

mkdir -p "${log_dir}" "${output_root}/cache"

timestamp="$(date +%Y%m%d_%H%M%S)"
log_path="${log_dir}/console_${timestamp}.log"
pid_path="${log_dir}/long_nightly_1000.pid"

cd "${repo_root}"
nohup Rscript analysis/ex3_daily_redo/run_all.R --config "${config_path}" \
  > "${log_path}" 2>&1 < /dev/null &
pid=$!
echo "${pid}" > "${pid_path}"

cat <<EOF
Started long overnight run.
pid: ${pid}
config: ${config_path}
log: ${log_path}
pid file: ${pid_path}
EOF
