#!/bin/sh
set -eu

case "${1:-}" in
  query)
    cat <<'EOF'
//services/alpha:alpha_image
//services/alpha:alpha_image.digest
//services/alpha:alpha_tarball
//services/alpha:alpha_push
//services/beta:beta_image
//services/beta:beta_tarball
//services/beta:beta_push
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
  build|run)
    if [ -z "${FAKE_BAZEL_LOG:-}" ]; then
      printf 'fake_bazel only permits build/run with FAKE_BAZEL_LOG, got: %s\n' "$*" >&2
      exit 1
    fi
    printf '%s\n' "$*" >> "$FAKE_BAZEL_LOG"
    if [ "$1" = "build" ] && [ "${FAKE_BAZEL_FAIL_BUILD:-0}" = "1" ]; then
      exit 42
    fi
    ;;
  *)
    printf 'fake_bazel does not support command: %s\n' "$*" >&2
    exit 1
    ;;
esac
