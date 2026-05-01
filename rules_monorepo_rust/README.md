# rules_monorepo_rust

Rust-specific layer for `rules_monorepo`.

It provides:

- Linux cross-platform transitions (`amd64`, `arm64`)
- Cargo-inferred wrappers that stay close to `rules_rust`
- `rust_binary` -> OCI image helper macro
- integration with `k8s_oci_deploy`

## Public API

Load from:

```starlark
load("@rules_monorepo//rules_monorepo_rust:defs.bzl", "rust_binary_oci_image", "transitioned_binary_arm64")
load("@rules_monorepo//rules_monorepo_rust:cargo_defs.bzl", "cargo_audit_test", "cargo_package", "cargo_rust_binary", "cargo_rust_library", "cargo_rust_proc_macro", "cargo_rust_test", "cargo_rust_test_suite")
```

Symbols:

- `rust_binary_oci_image` (alias: `monorepo_rust_binary_oci_image`)
- `transitioned_binary`
- `transitioned_binary_arm64`
- `linux_amd64_transition`
- `linux_arm64_transition`
- `cargo_package` / `cargo_aliases` / `cargo_all_crate_deps` / `cargo_proc_macro_deps`
- `cargo_rust_library` (Cargo.toml-inferred deps via `cargo_package(...)` or direct `all_crate_deps_fn`)
- `cargo_rust_binary` (Cargo.toml-inferred deps via `cargo_package(...)` or direct `all_crate_deps_fn`)
- `cargo_rust_proc_macro` (Cargo.toml-inferred deps via `cargo_package(...)` or direct `all_crate_deps_fn`)
- `cargo_rust_test` (Cargo.toml-inferred deps via `cargo_package(...)` or direct `all_crate_deps_fn`)
- `cargo_rust_test_suite` (Cargo-inferred integration-test suite wrapper)
- `cargo_audit_test` hermetic `cargo-audit audit` test using a pinned RustSec advisory DB

Configure the crate-universe extension from the rules_monorepo label:

```starlark
crate = use_extension("@rules_monorepo//rules_monorepo_rust:extensions.bzl", "crate")
```

## Required MODULE Setup (Rust Cross-Compile)

`rules_monorepo_rust` transitions target Linux platforms. Configure direct GitHub source override (no BCR required), Rust toolchains, and Linux cross C/C++ toolchains:

```starlark
bazel_dep(name = "rules_monorepo", version = "0.1.0")
bazel_dep(name = "rules_rust", version = "0.63.0")
bazel_dep(name = "toolchains_llvm", version = "1.6.0")

archive_override(
    module_name = "rules_monorepo",
    urls = ["https://github.com/ferocia-co/rules-monorepo/archive/REPLACE_WITH_COMMIT_SHA.tar.gz"],
    strip_prefix = "rules-monorepo-REPLACE_WITH_COMMIT_SHA",
    integrity = "sha256-REPLACE_WITH_BASE64_SHA256",
)

rust = use_extension("@rules_rust//rust:extensions.bzl", "rust")
rust.toolchain(
    extra_target_triples = [
        "aarch64-unknown-linux-gnu",
        "x86_64-unknown-linux-gnu",
    ],
    versions = ["1.91.0"],
)
use_repo(rust, "rust_toolchains")

llvm = use_extension("@toolchains_llvm//toolchain/extensions:llvm.bzl", "llvm")
llvm.toolchain(
    name = "llvm_toolchain",
    llvm_versions = {"": "latest:>=17.0.0,<20"},
)
llvm.sysroot(
    name = "llvm_toolchain",
    label = "@org_chromium_sysroot_linux_x64//sysroot",
    targets = ["linux-x86_64"],
)
llvm.sysroot(
    name = "llvm_toolchain",
    label = "@org_chromium_sysroot_linux_arm64//sysroot",
    targets = ["linux-aarch64"],
)
use_repo(llvm, "llvm_toolchain", "llvm_toolchain_llvm")
register_toolchains(
    "@llvm_toolchain//:cc-toolchain-x86_64-linux",
    "@llvm_toolchain//:cc-toolchain-aarch64-linux",
)

sysroot = use_repo_rule("@toolchains_llvm//toolchain:sysroot.bzl", "sysroot")
sysroot(
    name = "org_chromium_sysroot_linux_x64",
    sha256 = "93761371443acf55f429cab6628d5b423bf9a07a3445d2376b4ba52cb35a6d99",
    urls = ["https://commondatastorage.googleapis.com/chrome-linux-sysroot/toolchain/812a1cdc57400e9e0b3def67d41403b8bb764d2d/debian_sid_amd64_sysroot.tar.xz"],
)
sysroot(
    name = "org_chromium_sysroot_linux_arm64",
    sha256 = "38b11a17004bf9f5245f1de1c20d45b389b9dab18ce564ad73b44b6655c61850",
    urls = ["https://commondatastorage.googleapis.com/chrome-linux-sysroot/toolchain/f421bdbada4278feede4bae1ec8be91299e8938b/debian_sid_arm64_sysroot.tar.xz"],
)
```

For `git_override` and `local_path_override` variants, see the root `README.md`.

## Optional MODULE Setup (Cargo-Inferred Deps)

To infer crate deps from `Cargo.toml`/`Cargo.lock`, configure crate_universe and expose it as `@cargo_dep`.
The `rules_monorepo_rust` extension currently re-exports the standard `rules_rust` crate_universe extension from a stable rules_monorepo load path:

```starlark
crate = use_extension("@rules_monorepo//rules_monorepo_rust:extensions.bzl", "crate")
crate.from_cargo(
    name = "cargo_dep",
    cargo_lockfile = "//:Cargo.lock",
    manifests = [
        "//path/to/crate:Cargo.toml",
    ],
)
use_repo(crate, "cargo_dep")
```

If you use a different repository name, load `aliases` and `all_crate_deps` from that repo label and wrap them with `cargo_package(...)`.

## Optional MODULE Setup (Cargo Audit)

To run `cargo-audit` hermetically under Bazel, configure a dedicated
crate_universe repository for the `cargo-audit` binary and pin the RustSec
advisory database:

```starlark
crate.spec(
    package = "cargo-audit",
    repositories = ["cargo_audit_tools"],
    version = "0.22.1",
)
crate.annotation(
    crate = "cargo-audit",
    extra_aliased_targets = {
        "audit": "cargo-audit__bin",
    },
    gen_binaries = ["cargo-audit"],
    repositories = ["cargo_audit_tools"],
)
crate.from_specs(
    name = "cargo_audit_tools",
    cargo_lockfile = "//:cargo-audit-Cargo.lock",
    lockfile = "//:cargo-audit-bazel-lock.json",
)
use_repo(crate, "cargo_audit_tools")

rustsec_advisory_db = use_repo_rule(
    "@rules_monorepo//rules_monorepo_rust:repositories.bzl",
    "rustsec_advisory_db",
)
rustsec_advisory_db(
    name = "rustsec_advisory_db",
    commit = "REPLACE_WITH_RUSTSEC_ADVISORY_DB_COMMIT",
    sha256 = "REPLACE_WITH_ARCHIVE_SHA256",
)
```

Then add a test target:

```starlark
load("@rules_monorepo//rules_monorepo_rust:cargo_defs.bzl", "cargo_audit_test")

cargo_audit_test(
    name = "cargo_audit",
    cargo_lock = "//:Cargo.lock",
    audit_config = "//:.cargo/audit.toml",
)
```

`cargo_audit_test` runs:

```text
cargo-audit audit --no-fetch --db <pinned advisory-db> --file <Cargo.lock>
```

The generated test uses an isolated `CARGO_HOME` and, when no `audit_config` is
provided, writes a minimal `.cargo/audit.toml` that disables database fetching,
staleness checks, and yanked-crate checks.

## Cargo-Inferred Macro Behavior

`cargo_defs.bzl` wrappers merge package-scoped Cargo.toml deps with explicit Bazel deps.

Recommended pattern:

```starlark
load("@cargo_dep//:defs.bzl", "aliases", "all_crate_deps")
load("@rules_monorepo//rules_monorepo_rust:cargo_defs.bzl", "cargo_package")

CARGO = cargo_package(
    aliases_fn = aliases,
    all_crate_deps_fn = all_crate_deps,
)
```

`aliases()` is the crate_universe alias map for the current Cargo package. The
wrappers derive it automatically from `cargo = CARGO`, so BUILD targets do not
need to spell `aliases = aliases()` themselves.

Existing callers may continue to pass `all_crate_deps_fn = all_crate_deps`
directly.

### `cargo_rust_library`

- infers normal deps from the package's declared Cargo.toml dependencies
- `include_dev_deps` default: `False`
- supports `cargo_deps` (extra normal deps) and `cargo_macro_deps` (extra proc-macro deps)
- supports `include_dev_proc_macro_deps` for proc-macro dev deps

### `cargo_rust_binary`

- infers normal deps from the package's declared Cargo.toml dependencies
- infers proc-macro deps from the same package-scoped Cargo metadata
- `include_dev_deps` default: `False`
- `include_dev_proc_macro_deps` default: `False`
- supports `cargo_deps` and `cargo_macro_deps` for manual additions

### `cargo_rust_proc_macro`

- infers normal deps from the package's declared Cargo.toml dependencies
- infers proc-macro deps from the same package-scoped Cargo metadata
- `include_dev_deps` default: `False`
- `include_dev_proc_macro_deps` default: `False`
- supports `cargo_deps` and `cargo_macro_deps` for manual additions

### `cargo_rust_test`

- infers normal deps from the package's declared Cargo.toml dependencies
- infers proc-macro deps from the same package-scoped Cargo metadata
- `include_dev_deps` default: `True` (test-friendly default)
- `include_dev_proc_macro_deps` default: `True`
- supports `cargo_deps` and `cargo_macro_deps` for manual additions

### `cargo_rust_test_suite`

- mirrors `rules_rust`'s `rust_test_suite`
- creates one `cargo_rust_test` target per `.rs` file in `srcs`
- includes every file from `shared_srcs` in each generated test crate
- inherits Cargo-inferred deps for each generated test target

Common behavior:

- `package_name` defaults to `native.package_name()`
- if `cargo` / `all_crate_deps_fn` is omitted, wrappers behave like pass-through wrappers and only use explicitly supplied deps
- wrappers include local `Cargo.toml` in `compile_data` by default (`include_manifest_compile_data = True`) to preserve proc-macro behavior that reads crate manifests

## Lint / Format / Docs

There are currently no dedicated wrappers like `cargo_rust_clippy` or `cargo_rustfmt_test`.

Use standard `rules_rust` lint/doc/format rules against targets produced by `cargo_rust_*`:

- `rust_clippy`
- `rustfmt_test`
- `rust_doc`
- `rust_doc_test`

This still works with inferred deps because those dependencies are attached to the underlying `cargo_rust_*` targets.

## Optional / Feature-Gated Dependencies

Cargo inference follows what crate_universe resolves from your manifests and features.

- if an optional dependency is not active in the dependency graph for a target, add it explicitly with `cargo_deps`
- example: binaries importing `tracing` directly may need `cargo_deps = ["@cargo_dep//:tracing"]`

## Example: Rust Binary -> OCI Image

```starlark
load("@cargo_dep//:defs.bzl", "aliases", "all_crate_deps")
load("@rules_monorepo//rules_monorepo_rust:cargo_defs.bzl", "cargo_package", "cargo_rust_binary", "rust_binary_oci_image")

CARGO = cargo_package(
    aliases_fn = aliases,
    all_crate_deps_fn = all_crate_deps,
)

cargo_rust_binary(
    name = "market_maker",
    srcs = ["src/main.rs"],
    edition = "2024",
    cargo = CARGO,
    # deps are inferred from Cargo.toml via crate_universe.
)

rust_binary_oci_image(
    name = "market_maker",
    binary = ":market_maker",
    repository = "registry.example.com/trading/market-maker",
)
```

If `Cargo.toml` path and Bazel package path differ, set `package_name` explicitly:

```starlark
cargo_rust_binary(
    name = "market_maker",
    srcs = ["src/main.rs"],
    edition = "2024",
    cargo = CARGO,
    package_name = "apps/market-maker",
)
```

The older direct function style remains valid:

```starlark
load("@cargo_dep//:defs.bzl", "all_crate_deps")
load("@rules_monorepo//rules_monorepo_rust:cargo_defs.bzl", "cargo_rust_binary")

cargo_rust_binary(
    name = "market_maker",
    srcs = ["src/main.rs"],
    edition = "2024",
    all_crate_deps_fn = all_crate_deps,
)
```

Generated targets:

- `:market_maker_image`
- `:market_maker_image.digest`
- `:market_maker_load`
- `:market_maker_tarball`
- `:market_maker_push`

## Example: Explicit ARM64 Binary/Image

```starlark
load("@rules_monorepo//rules_monorepo:defs.bzl", "binary_oci_image")
load("@rules_monorepo//rules_monorepo_rust:defs.bzl", "transitioned_binary_arm64")

transitioned_binary_arm64(
    name = "market_maker_linux_arm64",
    binary = ":market_maker",
)

binary_oci_image(
    name = "market_maker_arm64",
    binary = ":market_maker_linux_arm64",
    base = "@distroless_cc_linux_arm64",
    repository = "registry.example.com/trading/market-maker-arm64",
)
```

## Example: Deploy With k8s_oci_deploy

```starlark
load("@rules_monorepo//rules_monorepo:defs.bzl", "k8s_oci_deploy")
load("@rules_monorepo//rules_monorepo_rust:defs.bzl", "rust_binary_oci_image")

rust_binary_oci_image(
    name = "strategy_runner",
    binary = ":strategy_runner",
    repository = "registry.example.com/trading/strategy-runner",
)

filegroup(
    name = "k8s_manifests",
    srcs = glob(["k8s/*.yaml"]),
)

k8s_oci_deploy(
    name = "strategy_runner_deploy",
    namespace = "strategies",
    manifests = [":k8s_manifests"],
    images = [{"push": ":strategy_runner_push"}],
    rollout_selector = "app.kubernetes.io/name=strategy-runner",
    rollout_kinds = ["deployment"],
)
```
