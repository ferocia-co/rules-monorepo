#!/bin/sh
set -eu

log_line() {
  [ -z "${FAKE_BAZEL_LOG:-}" ] || printf '%s\n' "$*" >> "$FAKE_BAZEL_LOG"
}

launcher_path() {
  target_without_repo=${1#*//}
  package=${target_without_repo%%:*}
  name=${target_without_repo#*:}
  if [ -n "$package" ]; then
    printf 'bazel-out/fake/bin/%s/%s' "$package" "$name"
  else
    printf 'bazel-out/fake/bin/%s' "$name"
  fi
}

signal_launcher() {
  signal_name="$1"
  signal_status="$2"
  log_line "launcher-signal ${launcher_target} ${signal_name}"
  if [ -n "${FAKE_BAZEL_SIGNAL_DIR:-}" ]; then
    : > "${FAKE_BAZEL_SIGNAL_DIR}/$$.terminated"
  fi
  exit "$signal_status"
}

run_fake_push() {
  launcher_target="$1"
  shift
  trap 'signal_launcher HUP 129' HUP
  trap 'signal_launcher INT 130' INT
  trap 'signal_launcher TERM 143' TERM
  log_line "launcher ${launcher_target} $*"
  if [ -n "${FAKE_BAZEL_RUN_BARRIER_DIR:-}" ]; then
    : > "${FAKE_BAZEL_RUN_BARRIER_DIR}/$$.started"
    while [ ! -e "${FAKE_BAZEL_RUN_BARRIER_DIR}/release" ]; do
      sleep 0.05
    done
  fi
  if [ "${FAKE_BAZEL_FAIL_LAUNCH_TARGET:-}" = "$launcher_target" ]; then
    exit 43
  fi
}

# A direct push launcher is a copy of this script with an adjacent target-label
# sidecar. Detect it before interpreting the first push argument as a Bazel
# command.
if [ -f "$0.label" ]; then
  launcher_target=$(cat "$0.label")
  run_fake_push "$launcher_target" "$@"
  exit 0
fi

execution_root=${FAKE_BAZEL_EXECUTION_ROOT:-${PWD}/fake-execroot}

case "${1:-}" in
  query)
    log_line "$*"
    cat <<'EOF'
//services/alpha:alpha_image
//services/alpha:alpha_image.digest
//services/alpha:alpha_tarball
//services/alpha:alpha_push
//services/beta:beta_image
//services/beta:beta_tarball
//services/beta:beta_push
//services/gamma:gamma_push
//services/foo:foo_image
//services/foo:foo_image_image
//services/foo:foo_oci_image
//services/price-crank:price-crank_oci_image
//services/price-crank:price-crank_oci_tarball
//services/price-crank:price-crank_oci_push
//services/shared-a:shared_oci_image
//services/shared-b:shared_oci_image
EOF
    ;;
  build)
    if [ -z "${FAKE_BAZEL_LOG:-}" ]; then
      printf 'fake_bazel only permits build with FAKE_BAZEL_LOG, got: %s\n' "$*" >&2
      exit 1
    fi
    log_line "$*"
    if [ "${FAKE_BAZEL_FAIL_BUILD:-0}" = "1" ]; then
      exit 42
    fi
    for argument in "$@"; do
      case "$argument" in
        //*:*_push|@*//*:*_push)
          if [ "${FAKE_BAZEL_SKIP_BUILD_LAUNCHER_TARGET:-}" = "$argument" ]; then
            continue
          fi
          relative_launcher=$(launcher_path "$argument")
          launcher="${execution_root}/${relative_launcher}"
          mkdir -p "${launcher%/*}"
          cp "$0" "$launcher"
          chmod +x "$launcher"
          printf '%s\n' "$argument" > "$launcher.label"
          ;;
      esac
    done
    ;;
  cquery)
    log_line "$*"
    if [ "${FAKE_BAZEL_FAIL_CQUERY:-0}" = "1" ]; then
      exit 44
    fi
    targets=""
    for argument in "$@"; do
      case "$argument" in
        'set('*')') targets=${argument#set(}; targets=${targets%)} ;;
      esac
    done
    [ -n "$targets" ] || exit 0
    for target in $targets; do
      [ "${FAKE_BAZEL_OMIT_CQUERY_TARGET:-}" != "$target" ] || continue
      relative_launcher=$(launcher_path "$target")
      printf '%s\t%s\n' "$target" "$relative_launcher"
      if [ "${FAKE_BAZEL_DUPLICATE_CQUERY_TARGET:-}" = "$target" ]; then
        printf '%s\t%s\n' "$target" "$relative_launcher"
      fi
    done
    ;;
  info)
    log_line "$*"
    [ "${2:-}" = "execution_root" ] || {
      printf 'fake_bazel only supports info execution_root, got: %s\n' "$*" >&2
      exit 1
    }
    if [ "${FAKE_BAZEL_FAIL_INFO:-0}" = "1" ]; then
      exit 45
    fi
    printf '%s\n' "$execution_root"
    ;;
  run)
    if [ -z "${FAKE_BAZEL_LOG:-}" ]; then
      printf 'fake_bazel only permits run with FAKE_BAZEL_LOG, got: %s\n' "$*" >&2
      exit 1
    fi
    log_line "$*"
    run_target=""
    for argument in "$@"; do
      case "$argument" in
        //*:*_push|@*//*:*_push) run_target=$argument; break ;;
      esac
    done
    [ -n "$run_target" ] || exit 1
    if [ -n "${FAKE_BAZEL_RUN_BARRIER_DIR:-}" ]; then
      : > "${FAKE_BAZEL_RUN_BARRIER_DIR}/$$.started"
      while [ ! -e "${FAKE_BAZEL_RUN_BARRIER_DIR}/release" ]; do
        sleep 0.05
      done
    fi
    if [ "${FAKE_BAZEL_FAIL_RUN_TARGET:-}" = "$run_target" ]; then
      exit 46
    fi
    ;;
  *)
    printf 'fake_bazel does not support command: %s\n' "$*" >&2
    exit 1
    ;;
esac
