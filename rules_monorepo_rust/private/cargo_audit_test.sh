#!/usr/bin/env bash
set -euo pipefail

runfiles_lib="bazel_tools/tools/bash/runfiles/runfiles.bash"
# shellcheck source=/dev/null
source "${RUNFILES_DIR:-/dev/null}/${runfiles_lib}" 2>/dev/null || \
  source "$(grep -sm1 "^${runfiles_lib} " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/${runfiles_lib}" 2>/dev/null || {
    echo "ERROR: cannot find ${runfiles_lib}" >&2
    exit 1
  }

usage() {
  echo "usage: $0 <cargo-audit> <Cargo.lock> <advisory-db-marker> <audit-config-or-empty> -- [cargo-audit args...]" >&2
}

resolve_runfile() {
  local path="$1"
  if [[ -z "${path}" ]]; then
    return 1
  fi
  if [[ "${path}" = /* ]]; then
    printf '%s\n' "${path}"
    return 0
  fi
  if [[ -e "${path}" ]]; then
    printf '%s\n' "${PWD}/${path}"
    return 0
  fi
  rlocation "${path}"
}

if [[ "$#" -lt 5 ]]; then
  usage
  exit 2
fi

cargo_audit="$(resolve_runfile "$1")"
cargo_lock="$(resolve_runfile "$2")"
advisory_db_marker="$(resolve_runfile "$3")"
audit_config_arg="$4"
shift 4

if [[ "${1:-}" != "--" ]]; then
  usage
  exit 2
fi
shift

advisory_db="$(dirname "${advisory_db_marker}")"
workdir="${TEST_TMPDIR:-$(mktemp -d)}/cargo-audit"
mkdir -p "${workdir}/.cargo" "${workdir}/cargo-home"

if [[ -n "${audit_config_arg}" ]]; then
  cp "$(resolve_runfile "${audit_config_arg}")" "${workdir}/.cargo/audit.toml"
else
  cat >"${workdir}/.cargo/audit.toml" <<'EOF'
[database]
fetch = false
stale = false

[yanked]
enabled = false
EOF
fi

export CARGO_HOME="${workdir}/cargo-home"
cd "${workdir}"

exec "${cargo_audit}" audit \
  --no-fetch \
  --db "${advisory_db}" \
  --file "${cargo_lock}" \
  --color never \
  "$@"
