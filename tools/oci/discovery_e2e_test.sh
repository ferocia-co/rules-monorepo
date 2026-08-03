#!/usr/bin/env bash
set -euo pipefail

discovered="$(
  bazelisk query \
    "attr(tags, '\\boci_image\\b', //rules_monorepo/...)" \
    --output=label
)"

grep -Fx -- "//rules_monorepo:oci_macro_default_image" <<<"${discovered}"
if grep -Eq -- "oci_macro_private|_image_amd64" <<<"${discovered}"; then
  echo "private or internal OCI target was returned by public tag discovery" >&2
  printf '%s\n' "${discovered}" >&2
  exit 1
fi

output="$(
  bazelisk run //tools/oci:oci -- \
    build \
    --scope //rules_monorepo/... \
    --all \
    --dry-run
)"

grep -F -- "//rules_monorepo:oci_macro_default_image" <<<"${output}"
if grep -Fq -- "oci_macro_private" <<<"${output}"; then
  echo "private OCI pipeline was returned by public discovery" >&2
  printf '%s\n' "${output}" >&2
  exit 1
fi
