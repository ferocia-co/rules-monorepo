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
grep -Fx -- "+ ${fake_bazel} build --compilation_mode=opt --jobs=2 //services/alpha:alpha_image" <<<"${build_output}"

debug_build_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" build \
    --bazel "${fake_bazel}" \
    --image alpha_image \
    --compilation-mode dbg \
    --dry-run
)"
grep -Fx -- "+ ${fake_bazel} build --compilation_mode=dbg --jobs=4 //services/alpha:alpha_image" <<<"${debug_build_output}"

conventional_name_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" build \
    --bazel "${fake_bazel}" \
    --image price-crank \
    --dry-run
)"
grep -Fx -- "+ ${fake_bazel} build --compilation_mode=opt --jobs=4 //services/price-crank:price-crank_oci_image" <<<"${conventional_name_output}"

exact_label_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" build \
    --bazel "${fake_bazel}" \
    --image //services/price-crank:price-crank_oci_image \
    --dry-run
)"
grep -Fx -- "+ ${fake_bazel} build --compilation_mode=opt --jobs=4 //services/price-crank:price-crank_oci_image" <<<"${exact_label_output}"

tarball_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" tarball \
    --bazel "${fake_bazel}" \
    --image beta_tarball \
    --dry-run
)"
grep -Fx -- "+ ${fake_bazel} build --compilation_mode=opt --jobs=4 //services/beta:beta_tarball" <<<"${tarball_output}"

single_push_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" push \
    --bazel "${fake_bazel}" \
    --image alpha \
    --repository registry.example.com/team/alpha \
    --dry-run
)"
grep -Fx -- "+ ${fake_bazel} run --compilation_mode=opt //services/alpha:alpha_push -- --repository registry.example.com/team/alpha" <<<"${single_push_output}"

push_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" push \
    --bazel "${fake_bazel}" \
    --all \
    --repository registry.example.com/team/images \
    --tag release-sha \
    --tag release-sha \
    --tag -candidate \
    --tag -candidate \
    --tag latest \
    --jobs 2 \
    --dry-run
)"
grep -Fx -- "+ ${fake_bazel} run --compilation_mode=opt //services/alpha:alpha_push -- --repository registry.example.com/team/images --tag release-sha --tag -candidate --tag latest" <<<"${push_output}"
grep -Fx -- "+ ${fake_bazel} run --compilation_mode=opt //services/beta:beta_push -- --repository registry.example.com/team/images --tag release-sha --tag -candidate --tag latest" <<<"${push_output}"
grep -Fx -- "+ ${fake_bazel} run --compilation_mode=opt //services/price-crank:price-crank_oci_push -- --repository registry.example.com/team/images --tag release-sha --tag -candidate --tag latest" <<<"${push_output}"

if BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" build \
  --bazel "${fake_bazel}" --image missing --dry-run >/dev/null 2>&1; then
  echo "missing image unexpectedly succeeded" >&2
  exit 1
fi

if BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" build \
  --bazel "${fake_bazel}" --image price --dry-run >/dev/null 2>&1; then
  echo "partial conventional image name unexpectedly succeeded" >&2
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
assert_fails_with "oci: --compilation-mode must be one of fastbuild, dbg, or opt" \
  build --bazel "${fake_bazel}" --all --compilation-mode release

"${oci}" --help >/dev/null
