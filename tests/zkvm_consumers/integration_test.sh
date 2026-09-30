#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/rules-monorepo-zkvm-consumers.XXXXXX")"

inert_workspace="${repo_root}/tests/zkvm_consumers/inert"
opted_workspace="${repo_root}/tests/zkvm_consumers/opted_in"
output_user_root="${test_root}/bazel"
inert_output_base="${test_root}/inert-output-base"
opted_output_base="${test_root}/opted-output-base"

cleanup() {
    local status=$?
    local cleanup_status=0
    trap - EXIT
    for output_base in "${inert_output_base}" "${opted_output_base}"; do
        (
            cd "${repo_root}"
            bazelisk --output_user_root="${output_user_root}" --output_base="${output_base}" shutdown
        ) >/dev/null 2>&1 || cleanup_status=$?
    done
    # Bazel tree artifacts can contain read-only directories. Restore only our
    # scratch directories; find does not follow external repository symlinks.
    find "${test_root}" -type d -exec chmod u+w {} + || cleanup_status=$?
    rm -rf -- "${test_root}" || cleanup_status=$?
    if [[ "${status}" -ne 0 ]]; then
        exit "${status}"
    fi
    exit "${cleanup_status}"
}
trap cleanup EXIT

inert_bazel() {
    (
        cd "${inert_workspace}"
        bazelisk --output_user_root="${output_user_root}" --output_base="${inert_output_base}" "$@" --lockfile_mode=off
    )
}

opted_bazel() {
    (
        cd "${opted_workspace}"
        bazelisk --output_user_root="${output_user_root}" --output_base="${opted_output_base}" "$@" --lockfile_mode=off
    )
}

inert_bazel query //...
inert_bazel mod graph | grep -F 'rules_rs@0.0.112'
inert_bazel build //:normal_target @rules_monorepo//tools/rust:rust_analyzer_setup
inert_bazel run //:native_rust

inert_output_base="$(inert_bazel info output_base)"
if find "${inert_output_base}/external" -maxdepth 1 \
    \( -type d -o -type l \) \
    \( -name '*risc0_zkvm*' -o -name '*sp1_zkvm*' -o -name '*zkvm_toolchains*' -o -name '*zkvm_guest_crates*' \) \
    -print -quit | grep -q .; then
    echo "zkVM repositories were activated without consumer opt-in" >&2
    exit 1
fi

# The shared compatibility patches must apply transitively; fixture-only
# platform aliases must not, despite using the same canonical extension.
inert_facades=("${inert_output_base}"/external/*rules_rust*/rust/platform/BUILD.bazel)
if [[ ! -f "${inert_facades[0]}" ]]; then
    echo "inert Rust consumer did not instantiate the shared facade" >&2
    exit 1
fi
if grep -Eq 'riscv32im-(risc0|succinct)-zkvm' "${inert_facades[@]}"; then
    echo "fixture-only Rust platform patch leaked into a consumer" >&2
    exit 1
fi

if inert_bazel query @zkvm_toolchains//:all >/dev/null 2>&1; then
    echo "zkVM hub unexpectedly exists in the inert consumer" >&2
    exit 1
fi

opted_bazel query @zkvm_toolchains//:all
opted_bazel build \
    --nobuild \
    --extra_execution_platforms=@rules_monorepo//rules_monorepo_rust/zkvm:linux_x86_64_exec_platform \
    //:risc0_guest \
    //:sp1_guest
