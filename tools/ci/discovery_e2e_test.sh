#!/usr/bin/env bash
set -euo pipefail

rules_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
consumer="$(mktemp -d "${TMPDIR:-/tmp}/test-discovery-consumer.XXXXXXXX")"
cleanup() {
  (cd "${consumer}" && bazelisk shutdown >/dev/null 2>&1) || true
  rm -rf "${consumer}"
}
trap cleanup EXIT
version="$(sed -n 's/^    version = "\([^"]*\)",$/\1/p' "${rules_root}/MODULE.bazel" | head -n 1)"
cat > "${consumer}/MODULE.bazel" <<EOF
module(name = "discovery_consumer")
bazel_dep(name = "rules_monorepo", version = "${version}")
bazel_dep(name = "rules_shell", version = "0.8.0")
local_path_override(module_name = "rules_monorepo", path = "${rules_root}")
EOF
cp "${rules_root}/.bazelversion" "${consumer}/.bazelversion"
cat > "${consumer}/BUILD.bazel" <<'EOF'
load("@rules_shell//shell:sh_test.bzl", "sh_test")
sh_test(name = "manual_test", srcs = ["ordinary.sh"], tags = ["manual"])
sh_test(name = "docker_test", srcs = ["docker.sh"], tags = ["requires-docker", "no-sandbox", "no-remote-exec"])
sh_test(name = "live_test", srcs = ["live.sh"], tags = ["live"])
EOF
printf '#!/bin/sh\necho TEST_RAN_ORDINARY\n' > "${consumer}/ordinary.sh"
printf '#!/bin/sh\necho TEST_RAN_DOCKER\n' > "${consumer}/docker.sh"
printf '#!/bin/sh\nexit 1\n' > "${consumer}/live.sh"
chmod +x "${consumer}"/*.sh
mkdir "${consumer}/ci"
printf '{"//:live_test": "Contacts a deployed service."}\n' > "${consumer}/ci/excluded.json"
cd "${consumer}"

run_discovery() {
  bazelisk run @rules_monorepo//tools/ci:test_targets -- "$1" --exclusions ci/excluded.json "${@:2}"
}
check="$(run_discovery check)"
grep -F 'test discovery passed: 1 ordinary, 1 Docker tests' <<< "${check}"
ordinary="$(run_discovery ordinary -- --test_output=all 2>&1)"
grep -F TEST_RAN_ORDINARY <<< "${ordinary}"
if grep -Fq TEST_RAN_DOCKER <<< "${ordinary}"; then
  echo 'ordinary test selection included a Docker test' >&2
  exit 1
fi

cat >> BUILD.bazel <<'EOF'
sh_test(name = "fresh_test", srcs = ["fresh.sh"])
EOF
printf '#!/bin/sh\necho TEST_RAN_FRESH\n' > fresh.sh
chmod +x fresh.sh
fresh="$(run_discovery ordinary -- --test_output=all 2>&1)"
grep -F TEST_RAN_FRESH <<< "${fresh}"
docker="$(run_discovery docker -- --test_output=all 2>&1)"
grep -F TEST_RAN_DOCKER <<< "${docker}"
if grep -Eq 'TEST_RAN_(ORDINARY|FRESH)' <<< "${docker}"; then
  echo 'Docker test selection included an ordinary test' >&2
  exit 1
fi

printf '{}\n' > ci/excluded.json
if failure="$(run_discovery check 2>&1)"; then
  echo 'an unexplained live-test exclusion passed validation' >&2
  exit 1
fi
grep -F '//:live_test: add a reason in' <<< "${failure}"
