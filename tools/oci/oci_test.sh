#!/usr/bin/env bash
set -euo pipefail

workspace="${TEST_TMPDIR}/workspace"
mkdir -p "${workspace}"
oci="${RUNFILES_DIR}/${TEST_WORKSPACE}/tools/oci/oci"
oci_script="${RUNFILES_DIR}/${TEST_WORKSPACE}/tools/oci/oci.sh"
fake_bazel="${RUNFILES_DIR}/${TEST_WORKSPACE}/tools/oci/fake_bazel"
fake_execution_root="${workspace}/fake-execroot"
export FAKE_BAZEL_EXECUTION_ROOT="${fake_execution_root}"

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
expected_single_push_output="+ ${fake_bazel} build --compilation_mode=opt --jobs=4 --remote_download_outputs=all //services/alpha:alpha_push
# direct push //services/alpha:alpha_push
+ ${fake_execution_root}/bazel-out/fake/bin/services/alpha/alpha_push --repository registry.example.com/team/alpha"
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
expected_push_output="+ ${fake_bazel} build --compilation_mode=opt --jobs=2 --remote_download_outputs=all //services/alpha:alpha_push //services/beta:beta_push //services/gamma:gamma_push //services/price-crank:price-crank_oci_push
# direct push //services/alpha:alpha_push
+ ${fake_execution_root}/bazel-out/fake/bin/services/alpha/alpha_push --repository registry.example.com/team/images --tag release-sha --tag -candidate --tag latest
# direct push //services/beta:beta_push
+ ${fake_execution_root}/bazel-out/fake/bin/services/beta/beta_push --repository registry.example.com/team/images --tag release-sha --tag -candidate --tag latest
# direct push //services/gamma:gamma_push
+ ${fake_execution_root}/bazel-out/fake/bin/services/gamma/gamma_push --repository registry.example.com/team/images --tag release-sha --tag -candidate --tag latest
# direct push //services/price-crank:price-crank_oci_push
+ ${fake_execution_root}/bazel-out/fake/bin/services/price-crank/price-crank_oci_push --repository registry.example.com/team/images --tag release-sha --tag -candidate --tag latest"
if [[ "${push_output}" != "${expected_push_output}" ]]; then
  echo "push-all dry run did not preserve grouped-build and push ordering:" >&2
  printf '%s\n' "${push_output}" >&2
  exit 1
fi

fallback_push_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" "${oci}" push \
    --bazel "${fake_bazel}" \
    --image //services/alpha:alpha_push \
    --repository registry.example.com/team/alpha \
    --tag release-sha \
    --push-execution bazel-run \
    --compilation-mode fastbuild \
    --dry-run
)"
expected_fallback_push_output="+ ${fake_bazel} build --compilation_mode=fastbuild --jobs=4 //services/alpha:alpha_push
+ ${fake_bazel} run --compilation_mode=fastbuild //services/alpha:alpha_push -- --repository registry.example.com/team/alpha --tag release-sha"
if [[ "${fallback_push_output}" != "${expected_fallback_push_output}" ]]; then
  echo "bazel-run fallback dry run changed its build/run contract:" >&2
  printf '%s\n' "${fallback_push_output}" >&2
  exit 1
fi

dry_run_root="${TEST_TMPDIR}/dry-run-execroot"
dry_run_output="$(
  BUILD_WORKSPACE_DIRECTORY="${workspace}" \
    FAKE_BAZEL_EXECUTION_ROOT="${dry_run_root}" \
    "${oci}" push --bazel "${fake_bazel}" --image alpha --dry-run
)"
grep -Fx -- "+ ${fake_bazel} build --compilation_mode=opt --jobs=4 --remote_download_outputs=all //services/alpha:alpha_push" <<<"${dry_run_output}"
grep -Fx -- "# direct push //services/alpha:alpha_push" <<<"${dry_run_output}"
grep -Fx -- "+ ${dry_run_root}/bazel-out/fake/bin/services/alpha/alpha_push" <<<"${dry_run_output}"
if [[ -e "${dry_run_root}" ]]; then
  echo "direct dry run materialized build outputs" >&2
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

  local expected_build="build --compilation_mode=opt --jobs=${expected_bazel_jobs} --remote_download_outputs=all //services/alpha:alpha_push //services/beta:beta_push //services/gamma:gamma_push //services/price-crank:price-crank_oci_push"
  if ! grep -Fxq -- "${expected_build}" "${log}"; then
    echo "${name}: grouped build did not use --jobs=${expected_bazel_jobs}" >&2
    cat "${log}" >&2
    exit 1
  fi
  if grep -q '^run ' "${log}"; then
    echo "${name}: direct mode started a Bazel run client" >&2
    cat "${log}" >&2
    exit 1
  fi
  if [[ "$(grep -c '^cquery ' "${log}")" -ne 1 ]]; then
    echo "${name}: direct mode did not use exactly one cquery" >&2
    cat "${log}" >&2
    exit 1
  fi
  if [[ "$(grep -c '^info execution_root$' "${log}")" -ne 1 ]]; then
    echo "${name}: direct mode did not resolve execution_root exactly once" >&2
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
grep -Fxq -- "build --compilation_mode=opt --jobs=4 --remote_download_outputs=all //services/alpha:alpha_push" "${prebuild_failure_log}"
if grep -Eq '^(run|cquery|info|launcher) ' "${prebuild_failure_log}"; then
  echo "push ran after grouped build failure" >&2
  exit 1
fi

direct_log="${TEST_TMPDIR}/direct.log"
BUILD_WORKSPACE_DIRECTORY="${workspace}" \
  FAKE_BAZEL_LOG="${direct_log}" \
  "${oci}" push \
    --bazel "${fake_bazel}" \
    --image //services/alpha:alpha_push \
    --repository registry.example.com/team/alpha \
    --tag release-sha \
    --tag latest \
    --bazel-jobs 9 \
    --push-jobs 1
grep -Fxq -- "build --compilation_mode=opt --jobs=9 --remote_download_outputs=all //services/alpha:alpha_push" "${direct_log}"
grep -Fq -- "cquery --compilation_mode=opt --remote_download_outputs=all set(//services/alpha:alpha_push )" "${direct_log}"
grep -Fxq -- "info execution_root" "${direct_log}"
grep -Fxq -- "launcher //services/alpha:alpha_push --repository registry.example.com/team/alpha --tag release-sha --tag latest" "${direct_log}"
if grep -q '^run ' "${direct_log}"; then
  echo "default direct push used bazel run" >&2
  cat "${direct_log}" >&2
  exit 1
fi

debug_direct_log="${TEST_TMPDIR}/debug-direct.log"
BUILD_WORKSPACE_DIRECTORY="${workspace}" \
  FAKE_BAZEL_LOG="${debug_direct_log}" \
  "${oci}" push \
    --bazel "${fake_bazel}" \
    --image beta \
    --compilation-mode dbg
grep -Fxq -- "build --compilation_mode=dbg --jobs=4 --remote_download_outputs=all //services/beta:beta_push" "${debug_direct_log}"
grep -Fq -- "cquery --compilation_mode=dbg --remote_download_outputs=all set(//services/beta:beta_push )" "${debug_direct_log}"
grep -Fq -- "launcher //services/beta:beta_push" "${debug_direct_log}"

fallback_log="${TEST_TMPDIR}/fallback.log"
BUILD_WORKSPACE_DIRECTORY="${workspace}" \
  FAKE_BAZEL_LOG="${fallback_log}" \
  "${oci}" push \
    --bazel "${fake_bazel}" \
    --image alpha \
    --repository registry.example.com/team/fallback \
    --tag fallback-tag \
    --push-execution bazel-run \
    --compilation-mode fastbuild
grep -Fxq -- "build --compilation_mode=fastbuild --jobs=4 //services/alpha:alpha_push" "${fallback_log}"
grep -Fxq -- "run --compilation_mode=fastbuild //services/alpha:alpha_push -- --repository registry.example.com/team/fallback --tag fallback-tag" "${fallback_log}"
if grep -Eq '^(cquery|info|launcher) ' "${fallback_log}"; then
  echo "bazel-run fallback unexpectedly used direct launcher resolution" >&2
  cat "${fallback_log}" >&2
  exit 1
fi

assert_build_profiling_scope() {
  local name="$1"
  local mode="$2"
  local image="$3"
  local expected_target="$4"
  local execution="$5"
  local log="${TEST_TMPDIR}/${name}-profiling.log"
  local profile_path="${TEST_TMPDIR}/${name}.profile.gz"
  local execution_log_path="${TEST_TMPDIR}/${name}.execution.log"
  local build_event_json_path="${TEST_TMPDIR}/${name}.bep.json"
  local compilation_mode="opt"
  local -a extra_args=()

  case "${execution}" in
    direct) ;;
    fallback)
      compilation_mode="fastbuild"
      extra_args+=(--push-execution bazel-run --compilation-mode fastbuild)
      ;;
    none) ;;
    *)
      echo "unknown profiling test execution mode: ${execution}" >&2
      exit 1
      ;;
  esac

  BUILD_WORKSPACE_DIRECTORY="${workspace}" \
    FAKE_BAZEL_LOG="${log}" \
    "${oci}" "${mode}" \
      --bazel "${fake_bazel}" \
      --image "${image}" \
      --profile "${profile_path}" \
      --execution-log "${execution_log_path}" \
      --build-event-json "${build_event_json_path}" \
      "${extra_args[@]}"

  local expected_build="build --compilation_mode=${compilation_mode} --jobs=4"
  if [[ "${execution}" == "direct" ]]; then
    expected_build+=" --remote_download_outputs=all"
  fi
  expected_build+=" --profile=${profile_path}"
  expected_build+=" --execution_log_compact_file=${execution_log_path}"
  expected_build+=" --build_event_json_file=${build_event_json_path}"
  expected_build+=" ${expected_target}"

  if ! grep -Fxq -- "${expected_build}" "${log}"; then
    echo "${name}: profiling flags changed the grouped build contract" >&2
    cat "${log}" >&2
    exit 1
  fi
  if [[ "$(grep -c '^build ' "${log}")" -ne 1 ]]; then
    echo "${name}: expected exactly one grouped build" >&2
    cat "${log}" >&2
    exit 1
  fi
  if ! grep -q '^query ' "${log}"; then
    echo "${name}: fake Bazel did not observe target discovery" >&2
    cat "${log}" >&2
    exit 1
  fi

  local build_flag
  for build_flag in \
    "--profile=${profile_path}" \
    "--execution_log_compact_file=${execution_log_path}" \
    "--build_event_json_file=${build_event_json_path}"; do
    if [[ "$(grep -F -c -- "${build_flag}" "${log}")" -ne 1 ]]; then
      echo "${name}: ${build_flag} did not occur exactly once" >&2
      cat "${log}" >&2
      exit 1
    fi
    if grep -v '^build ' "${log}" | grep -Fq -- "${build_flag}"; then
      echo "${name}: ${build_flag} escaped the grouped build" >&2
      cat "${log}" >&2
      exit 1
    fi
  done
}

assert_build_profiling_scope \
  build build alpha //services/alpha:alpha_image none
assert_build_profiling_scope \
  tarball tarball beta //services/beta:beta_tarball none
assert_build_profiling_scope \
  direct-push push alpha //services/alpha:alpha_push direct
assert_build_profiling_scope \
  fallback-push push alpha //services/alpha:alpha_push fallback

assert_no_registry_mutation() {
  local name="$1"
  local log="$2"
  if grep -Eq '^(run|launcher) ' "${log}"; then
    echo "${name}: registry mutation began before the launcher plan was valid" >&2
    cat "${log}" >&2
    exit 1
  fi
}

cquery_failure_log="${TEST_TMPDIR}/cquery-failure.log"
if BUILD_WORKSPACE_DIRECTORY="${workspace}" \
  FAKE_BAZEL_LOG="${cquery_failure_log}" \
  FAKE_BAZEL_FAIL_CQUERY=1 \
  "${oci}" push --bazel "${fake_bazel}" --image alpha >/dev/null 2>&1; then
  echo "push unexpectedly succeeded after cquery failure" >&2
  exit 1
fi
assert_no_registry_mutation cquery-failure "${cquery_failure_log}"

info_failure_log="${TEST_TMPDIR}/info-failure.log"
if BUILD_WORKSPACE_DIRECTORY="${workspace}" \
  FAKE_BAZEL_LOG="${info_failure_log}" \
  FAKE_BAZEL_FAIL_INFO=1 \
  "${oci}" push --bazel "${fake_bazel}" --image alpha >/dev/null 2>&1; then
  echo "push unexpectedly succeeded after execution_root resolution failure" >&2
  exit 1
fi
assert_no_registry_mutation info-failure "${info_failure_log}"

incomplete_plan_log="${TEST_TMPDIR}/incomplete-plan.log"
if BUILD_WORKSPACE_DIRECTORY="${workspace}" \
  FAKE_BAZEL_LOG="${incomplete_plan_log}" \
  FAKE_BAZEL_OMIT_CQUERY_TARGET=//services/beta:beta_push \
  "${oci}" push --bazel "${fake_bazel}" --image alpha --image beta >/dev/null 2>&1; then
  echo "push unexpectedly succeeded with an incomplete direct-launch plan" >&2
  exit 1
fi
assert_no_registry_mutation incomplete-plan "${incomplete_plan_log}"

duplicate_plan_log="${TEST_TMPDIR}/duplicate-plan.log"
if BUILD_WORKSPACE_DIRECTORY="${workspace}" \
  FAKE_BAZEL_LOG="${duplicate_plan_log}" \
  FAKE_BAZEL_DUPLICATE_CQUERY_TARGET=//services/alpha:alpha_push \
  "${oci}" push --bazel "${fake_bazel}" --image alpha >/dev/null 2>&1; then
  echo "push unexpectedly succeeded with a duplicate direct-launch plan" >&2
  exit 1
fi
assert_no_registry_mutation duplicate-plan "${duplicate_plan_log}"

missing_launcher_root="${TEST_TMPDIR}/missing-launcher-execroot"
missing_launcher_log="${TEST_TMPDIR}/missing-launcher.log"
if BUILD_WORKSPACE_DIRECTORY="${workspace}" \
  FAKE_BAZEL_EXECUTION_ROOT="${missing_launcher_root}" \
  FAKE_BAZEL_LOG="${missing_launcher_log}" \
  FAKE_BAZEL_SKIP_BUILD_LAUNCHER_TARGET=//services/alpha:alpha_push \
  "${oci}" push --bazel "${fake_bazel}" --image alpha >/dev/null 2>&1; then
  echo "push unexpectedly succeeded without a materialized launcher" >&2
  exit 1
fi
assert_no_registry_mutation missing-launcher "${missing_launcher_log}"

child_failure_log="${TEST_TMPDIR}/child-failure.log"
if BUILD_WORKSPACE_DIRECTORY="${workspace}" \
  FAKE_BAZEL_LOG="${child_failure_log}" \
  FAKE_BAZEL_FAIL_LAUNCH_TARGET=//services/alpha:alpha_push \
  "${oci}" push \
    --bazel "${fake_bazel}" \
    --image alpha \
    --image beta \
    --push-jobs 2 >/dev/null 2>&1; then
  echo "push unexpectedly succeeded after a direct launcher failed" >&2
  exit 1
fi
grep -Fq -- "launcher //services/alpha:alpha_push" "${child_failure_log}"
grep -Fq -- "launcher //services/beta:beta_push" "${child_failure_log}"
if grep -q '^run ' "${child_failure_log}"; then
  echo "failed direct launcher caused a bazel-run fallback" >&2
  exit 1
fi

probe_dir="${TEST_TMPDIR}/signal-barrier"
signal_log="${TEST_TMPDIR}/signal.log"
mkdir -p "${probe_dir}"
BUILD_WORKSPACE_DIRECTORY="${workspace}" \
  FAKE_BAZEL_LOG="${signal_log}" \
  FAKE_BAZEL_RUN_BARRIER_DIR="${probe_dir}" \
  FAKE_BAZEL_SIGNAL_DIR="${probe_dir}" \
  "${oci_script}" push --bazel "${fake_bazel}" --all --push-jobs 2 >/dev/null 2>&1 &
probe_pid=$!
for ((attempt = 0; attempt < 200; attempt += 1)); do
  started="$(find "${probe_dir}" -type f -name '*.started' | wc -l | tr -d '[:space:]')"
  if ((started == 2)); then
    break
  fi
  if ! kill -0 "${probe_pid}" 2>/dev/null; then
    break
  fi
  sleep 0.05
done
if [[ "${started:-0}" -ne 2 ]]; then
  echo "signal cleanup probe did not start two direct launchers" >&2
  cat "${signal_log}" >&2
  exit 1
fi
kill -TERM "${probe_pid}"
signal_status=0
wait "${probe_pid}" || signal_status=$?
probe_pid=""
if [[ "${signal_status}" -ne 143 ]]; then
  echo "signal cleanup probe exited ${signal_status}, expected 143" >&2
  cat "${signal_log}" >&2
  exit 1
fi
for started_file in "${probe_dir}"/*.started; do
  child_pid="${started_file##*/}"
  child_pid="${child_pid%.started}"
  if kill -0 "${child_pid}" 2>/dev/null; then
    echo "signal cleanup left direct launcher ${child_pid} running" >&2
    ps -o pid,ppid,pgid,command -p "${child_pid}" >&2 || true
    cat "${signal_log}" >&2
    exit 1
  fi
done
probe_dir=""

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
assert_fails_with "oci: --push-execution is only valid in push mode" \
  build --bazel "${fake_bazel}" --all --push-execution direct
assert_fails_with "oci: --push-execution is only valid in push mode" \
  tarball --bazel "${fake_bazel}" --all --push-execution bazel-run
assert_fails_with "oci: --push-execution requires a value" \
  push --bazel "${fake_bazel}" --all --push-execution
assert_fails_with "oci: --push-execution must be one of direct or bazel-run" \
  push --bazel "${fake_bazel}" --all --push-execution invalid
assert_fails_with "oci: --compilation-mode must be one of fastbuild, dbg, or opt" \
  build --bazel "${fake_bazel}" --all --compilation-mode release
for output_option in --profile --execution-log --build-event-json; do
  assert_fails_with "oci: ${output_option} requires a path" \
    build --bazel "${fake_bazel}" --all "${output_option}"
  assert_fails_with "oci: ${output_option} requires a path" \
    build --bazel "${fake_bazel}" --all "${output_option}" ""
  assert_fails_with "oci: ${output_option} requires a path" \
    build --bazel "${fake_bazel}" --all "${output_option}" --dry-run
  assert_fails_with "oci: ${output_option} may only be specified once" \
    build --bazel "${fake_bazel}" --all \
      "${output_option}" "${TEST_TMPDIR}/first-output" \
      "${output_option}" "${TEST_TMPDIR}/second-output"
done
assert_fails_with "oci: profiling output paths must be distinct" \
  build --bazel "${fake_bazel}" --all \
    --profile "${TEST_TMPDIR}/shared-output" \
    --execution-log "${TEST_TMPDIR}/shared-output"
assert_fails_with "oci: profiling output paths must be distinct" \
  build --bazel "${fake_bazel}" --all \
    --profile "${TEST_TMPDIR}/shared-output" \
    --build-event-json "${TEST_TMPDIR}/shared-output"
assert_fails_with "oci: profiling output paths must be distinct" \
  build --bazel "${fake_bazel}" --all \
    --execution-log "${TEST_TMPDIR}/shared-output" \
    --build-event-json "${TEST_TMPDIR}/shared-output"
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
grep -F -- "--push-execution MODE" <<<"${help_output}"
grep -F -- "--profile PATH" <<<"${help_output}"
grep -F -- "--execution-log PATH" <<<"${help_output}"
grep -F -- "--build-event-json PATH" <<<"${help_output}"
