#!/bin/sh
set -eu

if [ "${1:-}" != "query" ]; then
  printf 'fake_bazel only permits query, got: %s\n' "$*" >&2
  exit 1
fi

cat <<'EOF'
//services/alpha:alpha_image
//services/alpha:alpha_image.digest
//services/alpha:alpha_tarball
//services/alpha:alpha_push
//services/beta:beta_image
//services/beta:beta_tarball
//services/beta:beta_push
EOF
