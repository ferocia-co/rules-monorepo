# rules_monorepo

`rules_monorepo` is a Bazel-first deployment toolkit for monorepos.

It provides:

- `rules_monorepo`: language-agnostic rules for OCI image packaging and Kubernetes deployment
- `rules_monorepo_rust`: Rust-specific rules for cross-platform builds layered on top of `rules_monorepo`

The design goal is composability: keep deploy primitives generic, then add language-specific layers without coupling the core to one language ecosystem.

## What It Solves

- Build OCI images from Bazel binaries
- Generate tarballs, local image loads, image digests, and registry pushes
- Render/apply/delete Kubernetes manifests from Bazel targets
- Run pre-deploy image pushes and rollout checks from Bazel
- Build Rust binaries for Linux AMD64/ARM64 from non-Linux hosts using transitions

## Repository Layout

- `rules_monorepo/`: generic OCI + Kubernetes rules and tool bootstrap extension
- `rules_monorepo_rust/`: Rust cross-platform transitions + Rust-to-OCI helper macros
- `examples/`: copy-pasteable sample targets

## Install (Bzlmod Without BCR)

`rules_monorepo` is not in the Bazel Central Registry yet, so install it directly from GitHub.

### Option A: `archive_override` (recommended for consumers/CI)

Use this for reproducible pins without requiring `git` on the runner.

```starlark
bazel_dep(name = "rules_monorepo", version = "0.1.0")

archive_override(
    module_name = "rules_monorepo",
    urls = ["https://github.com/ferocia-co/rules-monorepo/archive/REPLACE_WITH_COMMIT_SHA.tar.gz"],
    strip_prefix = "rules-monorepo-REPLACE_WITH_COMMIT_SHA",
    integrity = "sha256-REPLACE_WITH_BASE64_SHA256",
)
```

Notes:
- `strip_prefix` must match the extracted top-level folder in the archive (`rules-monorepo-<commit>`).
- `integrity` should be computed from the exact URL above.

### Option B: `git_override` (convenient during fast iteration)

Use this while commit history is being rewritten frequently and you do not want to recalculate archive integrity every time.

```starlark
bazel_dep(name = "rules_monorepo", version = "0.1.0")

git_override(
    module_name = "rules_monorepo",
    remote = "https://github.com/ferocia-co/rules-monorepo.git",
    commit = "REPLACE_WITH_COMMIT_SHA",
)
```

Notes:
- This still pulls directly from GitHub (no registry needed).
- CI may need credentials if the repo is private or your network policy blocks anonymous GitHub access.

### Option C: `local_path_override` (local development only)

```starlark
bazel_dep(name = "rules_monorepo", version = "0.1.0")
local_path_override(module_name = "rules_monorepo", path = "../rules-monorepo")
```

Then configure required repos/extensions:

```starlark
# Required for k8s_apply / k8s_oci_deploy.
monorepo_tools = use_extension(
    "@rules_monorepo//rules_monorepo:extensions.bzl",
    "monorepo_tools",
)
use_repo(monorepo_tools, "kubectl_bin", "kustomize_bin")

# Optional if you rely on default image base labels used by binary_oci_image.
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

## Load Paths

```starlark
load("@rules_monorepo//rules_monorepo:defs.bzl", "binary_oci_image", "k8s_apply", "k8s_oci_deploy")
load("@rules_monorepo//rules_monorepo_rust:defs.bzl", "rust_binary_oci_image", "transitioned_binary_arm64")
```

## Quick Usage

### Generic binary to OCI image

```starlark
binary_oci_image(
    name = "gateway",
    binary = ":gateway_linux",
    repository = "registry.example.com/trading/gateway",
    repo_tags = ["gateway:local"],
)
```

### Kubernetes deploy

```starlark
k8s_oci_deploy(
    name = "gateway_deploy",
    namespace = "trading",
    manifests = [":gateway_manifests"],
    images = [{"push": ":gateway_push"}],
    rollout_selector = "app.kubernetes.io/name=gateway",
    rollout_kinds = ["deployment"],
)
```

### Rust binary to OCI image

```starlark
rust_binary_oci_image(
    name = "strategy_runner",
    binary = ":strategy_runner",
    repository = "registry.example.com/trading/strategy-runner",
)
```

## Rust Cross-Platform Setup

If you use `rules_monorepo_rust` transitions (`linux_amd64` / `linux_arm64`), configure Rust and C/C++ cross-toolchains in your `MODULE.bazel`.

See `rules_monorepo_rust/README.md` for a full copy-paste snippet.

## Examples

- `examples/rust_service`: Rust binary -> OCI image -> Kubernetes apply/delete targets

## Documentation

- `rules_monorepo/README.md`
- `rules_monorepo_rust/README.md`
- `examples/README.md`

## CI

GitHub Actions workflow `.github/workflows/ci.yml` runs on every push and pull request.

Checks performed:

- helper script syntax check (`bash -n rules_monorepo/k8s/k8s_apply_helper.sh`)
- full target graph query (`bazelisk --ignore_all_rc_files query //...`)
- analysis build for the end-to-end example (`bazelisk --ignore_all_rc_files build --nobuild //examples/rust_service:app_deploy.apply`)

## License

MIT. See `LICENSE`.
