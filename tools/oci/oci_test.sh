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

bazel_jobs_build_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" build \
    --bazel "${fake_bazel}" \
    --image alpha \
    --bazel-jobs 6 \
    --dry-run
)"
grep -Fx -- "+ ${fake_bazel} build --compilation_mode=opt --jobs=6 //services/alpha:alpha_image" <<<"${bazel_jobs_build_output}"

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

precedence_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" build \
    --bazel "${fake_bazel}" \
    --image foo \
    --dry-run
)"
grep -Fx -- "+ ${fake_bazel} build --compilation_mode=opt --jobs=4 //services/foo:foo_image" <<<"${precedence_output}"

generated_name_precedence_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" build \
    --bazel "${fake_bazel}" \
    --image foo_image \
    --dry-run
)"
grep -Fx -- "+ ${fake_bazel} build --compilation_mode=opt --jobs=4 //services/foo:foo_image" <<<"${generated_name_precedence_output}"

collision_exact_label_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" build \
    --bazel "${fake_bazel}" \
    --image //services/shared-a:shared_oci_image \
    --dry-run
)"
grep -Fx -- "+ ${fake_bazel} build --compilation_mode=opt --jobs=4 //services/shared-a:shared_oci_image" <<<"${collision_exact_label_output}"

tarball_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" tarball \
    --bazel "${fake_bazel}" \
    --image beta_tarball \
    --dry-run
)"
grep -Fx -- "+ ${fake_bazel} build --compilation_mode=opt --jobs=4 //services/beta:beta_tarball" <<<"${tarball_output}"

bazel_jobs_tarball_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" tarball \
    --bazel "${fake_bazel}" \
    --image beta_tarball \
    --bazel-jobs 7 \
    --dry-run
)"
grep -Fx -- "+ ${fake_bazel} build --compilation_mode=opt --jobs=7 //services/beta:beta_tarball" <<<"${bazel_jobs_tarball_output}"

single_push_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" push \
    --bazel "${fake_bazel}" \
    --image alpha \
    --repository registry.example.com/team/alpha \
    --dry-run
)"
expected_single_push_output="+ ${fake_bazel} build --compilation_mode=opt --jobs=4 //services/alpha:alpha_push
+ ${fake_bazel} run --compilation_mode=opt //services/alpha:alpha_push -- --repository registry.example.com/team/alpha"
if [[ "${single_push_output}" != "${expected_single_push_output}" ]]; then
  echo "single push did not group-build before running:" >&2
  printf '%s\n' "${single_push_output}" >&2
  exit 1
fi

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
expected_push_output="+ ${fake_bazel} build --compilation_mode=opt --jobs=2 //services/alpha:alpha_push //services/beta:beta_push //services/gamma:gamma_push //services/price-crank:price-crank_oci_push
+ ${fake_bazel} run --compilation_mode=opt //services/alpha:alpha_push -- --repository registry.example.com/team/images --tag release-sha --tag -candidate --tag latest
+ ${fake_bazel} run --compilation_mode=opt //services/beta:beta_push -- --repository registry.example.com/team/images --tag release-sha --tag -candidate --tag latest
+ ${fake_bazel} run --compilation_mode=opt //services/gamma:gamma_push -- --repository registry.example.com/team/images --tag release-sha --tag -candidate --tag latest
+ ${fake_bazel} run --compilation_mode=opt //services/price-crank:price-crank_oci_push -- --repository registry.example.com/team/images --tag release-sha --tag -candidate --tag latest"
if [[ "${push_output}" != "${expected_push_output}" ]]; then
  echo "push-all dry run did not preserve grouped-build and push ordering:" >&2
  printf '%s\n' "${push_output}" >&2
  exit 1
fi

probe_pid=""
probe_dir=""
cleanup_probe() {
  if [[ -n "${probe_dir}" ]]; then
    : > "${probe_dir}/release" 2>/dev/null || true
  fi
  if [[ -n "${probe_pid}" ]] && kill -0 "${probe_pid}" 2>/dev/null; then
    kill "${probe_pid}" 2>/dev/null || true
    wait "${probe_pid}" 2>/dev/null || true
  fi
}
trap cleanup_probe EXIT

assert_push_concurrency() {
  local name="$1"
  local expected_push_jobs="$2"
  local expected_bazel_jobs="$3"
  shift 3

  probe_dir="${TEST_TMPDIR}/${name}-barrier"
  local log="${TEST_TMPDIR}/${name}.log"
  mkdir -p "${probe_dir}"

  BUILD_WORKSPACE_DIRECTORY="${workspace}" \
    FAKE_BAZEL_LOG="${log}" \
    FAKE_BAZEL_RUN_BARRIER_DIR="${probe_dir}" \
    "${oci}" push --bazel "${fake_bazel}" --all "$@" >/dev/null 2>&1 &
  probe_pid=$!

  local started=0
  local attempt
  for ((attempt = 0; attempt < 200; attempt += 1)); do
    started="$(find "${probe_dir}" -type f -name '*.started' | wc -l | tr -d '[:space:]')"
    if ((started >= expected_push_jobs)); then
      break
    fi
    if ! kill -0 "${probe_pid}" 2>/dev/null; then
      break
    fi
    sleep 0.05
  done

  # Give an incorrectly over-wide scheduler time to launch extra pushes while
  # every process already admitted by the scheduler remains blocked.
  sleep 0.2
  started="$(find "${probe_dir}" -type f -name '*.started' | wc -l | tr -d '[:space:]')"
  : > "${probe_dir}/release"

  local child_status=0
  wait "${probe_pid}" || child_status=$?
  probe_pid=""
  if ((child_status != 0)); then
    echo "${name}: push probe exited with status ${child_status}" >&2
    cat "${log}" >&2
    exit 1
  fi
  if ((started != expected_push_jobs)); then
    echo "${name}: expected ${expected_push_jobs} concurrent pushes, observed ${started}" >&2
    cat "${log}" >&2
    exit 1
  fi

  local expected_build="build --compilation_mode=opt --jobs=${expected_bazel_jobs} //services/alpha:alpha_push //services/beta:beta_push //services/gamma:gamma_push //services/price-crank:price-crank_oci_push"
  if ! grep -Fxq -- "${expected_build}" "${log}"; then
    echo "${name}: grouped build did not use --jobs=${expected_bazel_jobs}" >&2
    cat "${log}" >&2
    exit 1
  fi
  probe_dir=""
}

assert_push_concurrency default-jobs 4 4
assert_push_concurrency legacy-jobs 2 2 --jobs 2
assert_push_concurrency split-before-alias 1 7 \
  --bazel-jobs 7 --push-jobs 1 --jobs 3
assert_push_concurrency split-after-alias 1 7 \
  --jobs 3 --bazel-jobs 7 --push-jobs 1

prebuild_failure_log="${TEST_TMPDIR}/prebuild-failure.log"
if BUILD_WORKSPACE_DIRECTORY="${workspace}" \
  FAKE_BAZEL_FAIL_BUILD=1 \
  FAKE_BAZEL_LOG="${prebuild_failure_log}" \
  "${oci}" push \
    --bazel "${fake_bazel}" \
    --image alpha >/dev/null 2>&1; then
  echo "push unexpectedly succeeded after grouped build failure" >&2
  exit 1
fi
grep -Fxq -- "build --compilation_mode=opt --jobs=4 //services/alpha:alpha_push" "${prebuild_failure_log}"
if grep -q '^run ' "${prebuild_failure_log}"; then
  echo "push ran after grouped build failure" >&2
  exit 1
fi

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
assert_fails_with "oci: --push-jobs is only valid in push mode" \
  build --bazel "${fake_bazel}" --all --push-jobs 2
assert_fails_with "oci: --push-jobs is only valid in push mode" \
  tarball --bazel "${fake_bazel}" --all --push-jobs 2
assert_fails_with "oci: --compilation-mode must be one of fastbuild, dbg, or opt" \
  build --bazel "${fake_bazel}" --all --compilation-mode release
assert_fails_with "oci: ambiguous image selection for build: shared_oci_image matches multiple targets at generated target-name tier" \
  build --bazel "${fake_bazel}" --image shared_oci_image --dry-run
assert_fails_with "oci: ambiguous image selection for build: shared_oci matches multiple targets at logical-name tier" \
  build --bazel "${fake_bazel}" --image shared_oci --dry-run
assert_fails_with "oci: ambiguous image selection for build: shared matches multiple targets at conventional shorthand tier" \
  build --bazel "${fake_bazel}" --image shared --dry-run

for jobs_option in --jobs --bazel-jobs --push-jobs; do
  assert_fails_with "oci: ${jobs_option} requires a positive integer" \
    push --bazel "${fake_bazel}" --all "${jobs_option}"
  for invalid_jobs in 0 invalid -1; do
    assert_fails_with "oci: ${jobs_option} requires a positive integer" \
      push --bazel "${fake_bazel}" --all "${jobs_option}" "${invalid_jobs}"
  done
done

help_output="$("${oci}" --help)"
grep -F -- "--jobs N" <<<"${help_output}"
grep -F -- "--bazel-jobs N" <<<"${help_output}"
grep -F -- "--push-jobs N" <<<"${help_output}"
