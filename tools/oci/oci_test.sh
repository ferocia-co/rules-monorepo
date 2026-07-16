#!/usr/bin/env bash
set -euo pipefail

workspace="${TEST_TMPDIR}/workspace"
mkdir -p "${workspace}"
oci="${RUNFILES_DIR}/${TEST_WORKSPACE}/tools/oci/oci"
fake_bazel="${RUNFILES_DIR}/${TEST_WORKSPACE}/tools/oci/fake_bazel"

build_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" build \
    --bazel "${fake_bazel}" \
    --scope //services/... \
    --image alpha \
    --jobs 2 \
    --dry-run
)"
grep -F -- "+ ${fake_bazel} build --jobs=2 //services/alpha:alpha_image" <<<"${build_output}"

tarball_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" tarball \
    --bazel "${fake_bazel}" \
    --image beta_tarball \
    --dry-run
)"
grep -F -- "+ ${fake_bazel} build --jobs=4 //services/beta:beta_tarball" <<<"${tarball_output}"

single_push_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" push \
    --bazel "${fake_bazel}" \
    --image alpha \
    --repository registry.example.com/team/alpha \
    --dry-run
)"
grep -F -- "+ ${fake_bazel} run //services/alpha:alpha_push -- --repository registry.example.com/team/alpha" <<<"${single_push_output}"

push_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" push \
    --bazel "${fake_bazel}" \
    --all \
    --repository registry.example.com/team/images \
    --tag release-sha \
    --tag latest \
    --jobs 2 \
    --dry-run
)"
grep -F -- "+ ${fake_bazel} run //services/alpha:alpha_push -- --repository registry.example.com/team/images --tag release-sha --tag latest" <<<"${push_output}"
grep -F -- "+ ${fake_bazel} run //services/beta:beta_push -- --repository registry.example.com/team/images --tag release-sha --tag latest" <<<"${push_output}"

if BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" build \
  --bazel "${fake_bazel}" --image missing --dry-run >/dev/null 2>&1; then
  echo "missing image unexpectedly succeeded" >&2
  exit 1
fi

assert_fails_with() {
  expected="$1"
  shift
  if output="$(BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" "$@" 2>&1)"; then
    echo "command unexpectedly succeeded: $*" >&2
    exit 1
  fi
  grep -F -- "${expected}" <<<"${output}"
}

assert_fails_with "oci: --repository requires a value" \
  push --bazel "${fake_bazel}" --all --repository
assert_fails_with "oci: --repository requires a value" \
  push --bazel "${fake_bazel}" --all --repository ""
assert_fails_with "oci: --repository is only valid in push mode" \
  build --bazel "${fake_bazel}" --all --repository registry.example.com/team/images

"${oci}" --help >/dev/null
