# rules_monorepo

Language-agnostic Bazel rules for:

- OCI image packaging
- image push/load/tarball workflows
- Kubernetes apply/delete deploy flows with rollout checks

## Public API

Load from:

```starlark
load("@rules_monorepo//rules_monorepo:defs.bzl", "binary_oci_image", "k8s_apply", "k8s_oci_deploy")
```

Rules/macros:

- `binary_oci_image` (alias: `monorepo_binary_oci_image`)
- `k8s_apply` (alias: `monorepo_k8s_apply`)
- `k8s_oci_deploy` (alias: `monorepo_k8s_oci_deploy`)

## Required MODULE Setup

Install from GitHub (no BCR required) and pin a commit. `archive_override` is recommended for consumers/CI:

```starlark
bazel_dep(name = "rules_monorepo", version = "0.1.0")

archive_override(
    module_name = "rules_monorepo",
    urls = ["https://github.com/ferocia-co/rules-monorepo/archive/REPLACE_WITH_COMMIT_SHA.tar.gz"],
    strip_prefix = "rules-monorepo-REPLACE_WITH_COMMIT_SHA",
    integrity = "sha256-REPLACE_WITH_BASE64_SHA256",
)

monorepo_tools = use_extension(
    "@rules_monorepo//rules_monorepo:extensions.bzl",
    "monorepo_tools",
)

# Optional: configure which k8s tool repos to create.
# Defaults are kubectl=True, kustomize=True.
# monorepo_tools.k8s(
#     kubectl = False,
#     kustomize = True,
# )

use_repo(monorepo_tools, "kubectl_bin", "kustomize_bin")

# If using binary_oci_image defaults.
oci = use_extension("@rules_oci//oci:extensions.bzl", "oci")
oci.pull(
    name = "distroless_cc_linux_amd64",
    image = "gcr.io/distroless/cc-debian12",
    tag = "latest-amd64",
    reproducible = False,
)
oci.pull(
    name = "distroless_cc_linux_arm64",
    image = "gcr.io/distroless/cc-debian12",
    tag = "latest-arm64",
    reproducible = False,
)
use_repo(oci, "distroless_cc_linux_amd64", "distroless_cc_linux_arm64")
```

For `git_override` and `local_path_override` variants, see the root `README.md`.

## binary_oci_image

Creates an OCI pipeline from a Linux binary target.

Inputs:

- `name`: base target name
- `binary`: Bazel target for the Linux binary
- `base`: base image label (default `@distroless_cc_linux_amd64`)
- `entrypoint`: entrypoint list (defaults to `<package_dir>/<binary_name>`)
- `package_dir`: path inside image where binary is copied (default `/app`)
- `repo_tags`: local tags used by `oci_load`
- `repository`: remote repo for `oci_push`
- `remote_tags`: tags for `oci_push`

Generated targets:

- `<name>_image`
- `<name>_image.digest`
- `<name>_load`
- `<name>_tarball`
- `<name>_push`

Example:

```starlark
binary_oci_image(
    name = "gateway",
    binary = ":gateway_linux",
    repository = "registry.example.com/trading/gateway",
    repo_tags = ["gateway:local"],
)
```

## k8s_apply

Executable rule that:

- optionally pushes images before deploy
- templates manifest vars (namespace + git short sha + extra vars)
- runs `kubectl apply` or `kubectl delete`
- optionally waits for rollout status

Template vars:

- `{{NAMESPACE}}`
- `{{GIT_COMMIT_SHORT}}`
- keys from `extra_vars`

## k8s_oci_deploy

Convenience macro that generates:

- `<name>` rendered manifest target
- `<name>.apply`
- `<name>.delete`

Example:

```starlark
filegroup(
    name = "gateway_manifests",
    srcs = glob(["k8s/*.yaml"]),
)

k8s_oci_deploy(
    name = "gateway",
    namespace = "trading",
    manifests = [":gateway_manifests"],
    images = [{"push": ":gateway_push"}],
    rollout_selector = "app.kubernetes.io/name=gateway",
    rollout_kinds = ["deployment"],
    rollout_timeout = "5m",
)
```

Run:

```bash
bazel run //path/to:gateway.apply
bazel run //path/to:gateway.delete
```
