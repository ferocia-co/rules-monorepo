# rules_monorepo

`rules_monorepo` is a Bazel-first deployment toolkit for monorepos.

It provides:

- `rules_monorepo`: language-agnostic rules for OCI image packaging and Kubernetes deployment
- `rules_monorepo_rust`: Rust-specific rules for cross-platform builds layered on top of `rules_monorepo`
- `rules_monorepo_frontend`: pnpm/Svelte/Vite checks, tests, and static frontend image packaging
- `rules_monorepo_docs`: mdBook documentation builds from Bazel-managed sources

The design goal is composability: keep deploy primitives generic, then add language-specific layers without coupling the core to one language ecosystem.

## What It Solves

- Build OCI images from Bazel binaries
- Generate tarballs, local image loads, image digests, and registry pushes
- Render/apply/delete Kubernetes manifests from Bazel targets
- Run pre-deploy image pushes and rollout checks from Bazel
- Build Rust binaries for Linux AMD64/ARM64 from non-Linux hosts using transitions
- Infer external and first-party Rust dependencies directly from Cargo workspaces and `Cargo.lock`
- Provide Cargo, rustfmt, Clippy, rust-analyzer, and rust-src through Bazel
- Run Cargo dependency audits against a pinned RustSec advisory DB
- Build pnpm/Svelte/Vite static frontends and package them as nginx OCI images
- Build mdBook documentation sites without committing generated HTML/CSS

## Repository Layout

- `rules_monorepo/`: generic OCI + Kubernetes rules and tool bootstrap extension
- `rules_monorepo_rust/`: Rust cross-platform transitions + Rust-to-OCI helper macros
- `rules_monorepo_frontend/`: frontend build/check/test/image macros for pnpm apps
- `rules_monorepo_docs/`: mdBook repository rule and documentation build rule
- `examples/`: copy-pasteable sample targets

## Install (Bzlmod Without BCR)

`rules_monorepo` is not in the Bazel Central Registry yet, so install it directly from GitHub.

### Option A: `archive_override` (recommended for consumers/CI)

Use this for reproducible pins without requiring `git` on the runner.

```starlark
bazel_dep(name = "rules_monorepo", version = "2026.07.21.1")

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
bazel_dep(name = "rules_monorepo", version = "2026.07.21.1")

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
bazel_dep(name = "rules_monorepo", version = "2026.07.21.1")
local_path_override(module_name = "rules_monorepo", path = "../rules-monorepo")
```

Then configure required repos/extensions:

```starlark
# Required for k8s_apply / k8s_oci_deploy.
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

# Optional: required when using mdbook_docs.
download_mdbook = use_repo_rule(
    "@rules_monorepo//rules_monorepo_docs:repositories.bzl",
    "download_mdbook",
)
download_mdbook(name = "mdbook_bin")
```

## Load Paths

```starlark
load("@rules_monorepo//rules_monorepo:defs.bzl", "binary_oci_image", "k8s_apply", "k8s_oci_deploy", "oci_archive")
load("@rules_monorepo//rules_monorepo_rust:defs.bzl", "rust_binary_oci_image", "transitioned_binary_arm64")
load("@rules_monorepo//rules_monorepo_rust:cargo_defs.bzl", "cargo_audit_test", "cargo_package", "cargo_rust_binary", "cargo_rust_library", "cargo_rust_proc_macro", "cargo_rust_test", "cargo_rust_test_suite")
load("@rules_monorepo//rules_monorepo_frontend:defs.bzl", "frontend_static_site_oci_image", "pnpm_frontend_checks", "pnpm_playwright_test", "pnpm_svelte_vite_app")
load("@rules_monorepo//rules_monorepo_docs:defs.bzl", "mdbook_docs")
```

## Quick Usage

### Generic binary to OCI image

```starlark
binary_oci_image(
    name = "gateway",
    architecture = "arm64",
    binary = ":gateway_linux",
    repository = "registry.example.com/trading/gateway",
    repo_tags = ["gateway:local"],
)
```

### Existing image to local archive

```starlark
oci_archive(
    name = "gateway_component_oci",
    image = ":gateway_image",
    format = "docker",
    repo_tags = ["gateway:local"],
)
```

This creates `gateway_component_oci_load` and
`gateway_component_oci_tarball` without rebuilding the existing image. The
`image` label must provide one OCI image manifest (such as an `oci_image`), not
a multi-platform `oci_image_index`.

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

## Cargo-Inferred Rust Dependencies

To avoid duplicating Rust crate deps in both `Cargo.toml` and BUILD targets, use the Cargo-inferred API in `rules_monorepo_rust:cargo_defs.bzl`.

1. Configure the canonical `rules_rs` Cargo extension in `MODULE.bazel`:

```starlark
crate = use_extension("@rules_rs//rs:extensions.bzl", "crate")
crate.from_cargo(
    name = "crates",
    cargo_lock = "//:Cargo.lock",
    cargo_toml = "//:Cargo.toml",
    platform_triples = [
        "aarch64-apple-darwin",
        "aarch64-unknown-linux-gnu",
        "x86_64-apple-darwin",
        "x86_64-unknown-linux-gnu",
    ],
)
use_repo(crate, "crates")
```

2. Use Cargo-inferred wrappers in BUILD files:

```starlark
load("@crates//:data.bzl", "DEP_DATA")
load("@crates//:defs.bzl", "aliases", "all_crate_deps")
load("@rules_monorepo//rules_monorepo_rust:cargo_defs.bzl", "cargo_package", "cargo_rust_binary", "rust_binary_oci_image")

CARGO = cargo_package(
    aliases_fn = aliases,
    all_crate_deps_fn = all_crate_deps,
    dep_data = DEP_DATA,
)

cargo_rust_binary(
    name = "strategy_runner",
    srcs = ["src/main.rs"],
    edition = "2024",
    cargo = CARGO,
)

rust_binary_oci_image(
    name = "strategy_runner",
    binary = ":strategy_runner",
    repository = "registry.example.com/trading/strategy-runner",
)
```

By default, wrappers infer deps for `native.package_name()`. If a manifest path
differs from the Bazel package, pass `package_name` explicitly. First-party path
dependencies are inferred too; their Bazel package must expose a default target
named after the directory. Existing callers may continue passing
`all_crate_deps_fn` directly.

Passing `DEP_DATA` keeps renamed normal, dev, build, and target-specific crates
on the same selectors as their dependency edges. Normal library/binary targets
exclude dev-only aliases, while tests include them.

Supported inferred wrappers:

- `cargo_rust_library`
- `cargo_rust_binary`
- `cargo_rust_proc_macro`
- `cargo_rust_test`
- `cargo_rust_test_suite`

Lint/doc/format integration:

- use `rust_clippy`, `rustfmt_test`, `rust_doc`, and `rust_doc_test` against targets created by `cargo_rust_*`
- dedicated cargo-aware lint/doc wrappers are not yet provided

Use `bazel_deps` only for dependencies that do not exist in Cargo metadata.

## Cargo Audit

`cargo_audit_test` runs `cargo-audit audit --no-fetch` with a pinned RustSec
advisory DB and isolated `CARGO_HOME`. The shared hermetic cargo-audit 0.22.1
tool supports macOS and Linux on AMD64/ARM64. Pass `cargo_lock` for one test or
`cargo_locks` for a stable suite over multiple independent workspaces. The
obsolete `crate.spec`/`crate.from_specs` host-tool flow is not used.

## OCI orchestration

The default Rust/generic binary images use checksum-pinned Debian 12
distroless `cc:nonroot`, `/app`, and `65532:65532`. Choose `architecture` as
`amd64` or `arm64`; override `base` only for an intentional exception.

```bash
bazel run @rules_monorepo//tools/oci -- build --bazel ./tools/bazel --all
bazel run @rules_monorepo//tools/oci -- push --bazel ./tools/bazel \
  --image gateway --repository registry.example.com/team/gateway \
  --tag "$GIT_SHA" --jobs 4
```

The command discovers standard OCI tags, supports selected/all images and
bounded push concurrency, and offers `--dry-run` for non-mutating validation.
Build, tarball, and push operations use optimized binaries by default. A
conventional trailing `_oci` is optional during selection. Resolution prefers
an exact full label, generated target name, logical name, then the stripped
`_oci` shorthand; ambiguity at the first matching tier is an error. Repeated
runtime tags are deduplicated. In push mode, `--repository` overrides the
repository for every selected image.

## Frontend Rules

`rules_monorepo_frontend` keeps `package.json` and `pnpm-lock.yaml` as the
frontend dependency source of truth. Consumers configure `aspect_rules_js` and
load generated package bin callables from `@npm`, then pass those callables to
the macros.

Common targets:

- `frontend_sources`: standard frontend source filegroup
- `pnpm_vite_build` / `pnpm_vite_dev_server`: Vite build and dev-server targets
- `pnpm_svelte_vite_app`: Vite bundle target
- `pnpm_sveltekit_sync` / `pnpm_sveltekit_node_server`: SvelteKit sync and adapter-node runner
- `pnpm_frontend_checks`: aggregate Svelte, TypeScript, Prettier, and ESLint checks
- `pnpm_biome_check`, `pnpm_vitest_test`, `pnpm_cypress_test`: Biome, Vitest, and Cypress targets
- `pnpm_storybook_static_build` / `pnpm_storybook_dev_server`: Storybook build and dev-server targets
- `pnpm_playwright_test`: `js_test` with optional Linux Chromium headless-shell runfiles
- `frontend_static_site_oci_image`: nginx static-site image pipeline
- `frontend_node_server_oci_image`: Node server image pipeline

The frontend OCI image helpers create
`frontend_image`, `frontend_image.digest`, `frontend_load`, `frontend_tarball`,
and `frontend_push`. See `rules_monorepo_frontend/README.md` and
`examples/svelte_vite_app`.

## Documentation Rules

`rules_monorepo_docs` downloads a pinned mdBook release binary and builds docs
from source files staged in their Bazel package-relative layout.

Configure the tool repository in `MODULE.bazel`:

```starlark
download_mdbook = use_repo_rule(
    "@rules_monorepo//rules_monorepo_docs:repositories.bzl",
    "download_mdbook",
)
download_mdbook(name = "mdbook_bin")
```

Use the rule next to a standard mdBook `book.toml`:

```starlark
load("@rules_monorepo//rules_monorepo_docs:defs.bzl", "mdbook_docs")

mdbook_docs(
    name = "docs",
    book = "book.toml",
    mdbook = "@mdbook_bin//:mdbook",
    srcs = glob(["src/**"]),
)
```

The default mdBook destination directory is `book`, and the declared Bazel
directory output also defaults to `book`. Set `build_dir` when mdBook should
write to another destination, and `out_dir` when the Bazel output directory
should use another name. Pass `postbuild_script` for deterministic
post-processing that should run from the staged book root after `mdbook build`.

## Examples

- `examples/rust_service`: Rust binary -> OCI image -> Kubernetes apply/delete targets
- `examples/svelte_vite_app`: pnpm/Svelte/Vite -> checks -> Playwright smoke test -> nginx OCI image

## Documentation

- `rules_monorepo/README.md`
- `rules_monorepo_rust/README.md`
- `rules_monorepo_frontend/README.md`
- `rules_monorepo_docs/README.md`
- `examples/README.md`

## Release Notes

Bazel Central Registry metadata belongs in a separate `bazel-central-registry`
workflow/repository. This repository currently documents direct
`archive_override`, `git_override`, and `local_path_override` consumption.

## CI

GitHub Actions workflow `.github/workflows/ci.yml` runs on every push and pull request.

Checks performed:

- helper script syntax checks for Kubernetes, cargo-audit, and OCI tooling
- full target graph query (`bazelisk --ignore_all_rc_files query //...`)
- OCI configuration/CLI tests and hermetic multi-lock cargo-audit tests
- representative AMD64/ARM64 distroless image and archive builds
- analysis build for the end-to-end example (`bazelisk --ignore_all_rc_files build --nobuild //examples/rust_service:app_deploy.apply`)
- analysis build for the frontend example (`bazelisk --ignore_all_rc_files build --nobuild //examples/svelte_vite_app:bundle //examples/svelte_vite_app:checks //examples/svelte_vite_app:frontend_image`)

## License

MIT. See `LICENSE`.
