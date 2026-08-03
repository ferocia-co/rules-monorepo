#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/rules-monorepo-zkvm-consumers.XXXXXX")"
trap 'rm -rf -- "${test_root}"' EXIT

inert_workspace="${repo_root}/tests/zkvm_consumers/inert"
opted_workspace="${repo_root}/tests/zkvm_consumers/opted_in"
output_user_root="${test_root}/bazel"

inert_bazel() {
    (
        cd "${inert_workspace}"
        bazelisk --output_user_root="${output_user_root}" "$@" --lockfile_mode=off
    )
}

opted_bazel() {
    (
        cd "${opted_workspace}"
        bazelisk --output_user_root="${output_user_root}" "$@" --lockfile_mode=off
    )
}

inert_bazel query //...
inert_bazel build //:normal_target

inert_output_base="$(inert_bazel info output_base)"
if find "${inert_output_base}/external" -maxdepth 1 -type d \
    \( -name '*risc0_zkvm*' -o -name '*sp1_zkvm*' -o -name '*zkvm_toolchains*' \) \
    -print -quit | grep -q .; then
    echo "zkVM repositories were activated without consumer opt-in" >&2
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
