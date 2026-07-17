# rules_monorepo

Language-agnostic Bazel rules for:

- OCI image packaging
- image push/load/tarball workflows
- Kubernetes apply/delete deploy flows with rollout checks

## Public API

Load from:

```starlark
load("@rules_monorepo//rules_monorepo:defs.bzl", "binary_oci_image", "k8s_apply", "k8s_oci_deploy", "oci_archive")
```

Rules/macros:

- `binary_oci_image` (alias: `monorepo_binary_oci_image`)
- `k8s_apply` (alias: `monorepo_k8s_apply`)
- `k8s_oci_deploy` (alias: `monorepo_k8s_oci_deploy`)
- `oci_archive` (alias: `monorepo_oci_archive`)

## Required MODULE Setup

Install from GitHub (no BCR required) and pin a commit. `archive_override` is recommended for consumers/CI:

```starlark
bazel_dep(name = "rules_monorepo", version = "2026.07.17.2")

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

```

For `git_override` and `local_path_override` variants, see the root `README.md`.

## binary_oci_image

Creates an OCI pipeline from a Linux binary target.

Inputs:

- `name`: base target name
- `binary`: Bazel target for the Linux binary
- `architecture`: `amd64` (default) or `arm64`
- `base`: optional override; otherwise uses the matching shared, digest-pinned
  Debian 12 distroless `cc:nonroot` image
- `entrypoint`: entrypoint list (defaults to `<package_dir>/<binary_name>`)
- `package_dir`: path inside image where binary is copied (default `/app`)
- `workdir`: default `/app`
- `user`: default `65532:65532`
- `load_format`: `oci` (default) or `docker`
- `tarball_format`: defaults to `load_format`, but may differ for component
  compatibility
- `tars`, `env`, `labels`, and other OCI configuration inputs remain
  overridable
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
    architecture = "arm64",
    binary = ":gateway_linux",
    repository = "registry.example.com/trading/gateway",
    repo_tags = ["gateway:local"],
)
```

## oci_archive

Adds local-load and tarball targets around one existing OCI image manifest
without rebuilding or changing that image:

```starlark
oci_archive(
    name = "gateway_component_oci",
    image = ":gateway_image",
    format = "docker",
    repo_tags = ["gateway:local"],
)
```

The generated targets are `<name>_load` and `<name>_tarball`. `format` accepts
`oci` (default) or `docker`; `tarball_format` may differ when needed. Pass
`output` to choose the tar filename and `tags` to add tags alongside the
standard `manual`, `oci`, `oci_load`, and `oci_tarball` tags. `image` must label
a single manifest target such as `oci_image`; multi-platform `oci_image_index`
targets are not supported.

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
