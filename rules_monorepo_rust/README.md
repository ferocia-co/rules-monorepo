# rules_monorepo_rust

The Rust layer uses [`hermeticbuild/rules_rs`](https://github.com/hermeticbuild/rules_rs)
as the single source of Rust toolchains and Cargo dependency metadata. Consumers
keep normal Cargo workspaces and committed `Cargo.lock` files; BUILD targets do
not repeat Cargo dependencies.

It provides:

- Rust 1.97.0, Cargo, rustfmt, Clippy, rust-src, and rust-analyzer from Bazel
- Cargo-inferred library, binary, proc-macro, and test macros
- Linux AMD64/ARM64 transitions
- Rust binary-to-OCI helpers
- pinned RustSec audit integration

## Configure a Cargo workspace

`rules_monorepo` registers the Rust and LLVM toolchains. A consumer only
declares each independent Cargo workspace:

```starlark
bazel_dep(name = "rules_monorepo", version = "0.2.0")

crate = use_extension(
    "@rules_monorepo//rules_monorepo_rust:extensions.bzl",
    "crate",
)
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

Declare a second `from_cargo` repository for a nested workspace with its own
lockfile. Do not list member manifests: `rules_rs` discovers them through Cargo
metadata and consumes the lock directly.

## Bind the generated dependencies once

Create one small adapter per Cargo workspace:

```starlark
# //tools/rust:deps.bzl
load("@crates//:defs.bzl", "aliases", "all_crate_deps")
load("@rules_monorepo//rules_monorepo_rust:cargo_defs.bzl", "cargo_package")

CARGO = cargo_package(
    aliases_fn = aliases,
    all_crate_deps_fn = all_crate_deps,
)
```

BUILD packages load that value and declare only source/configuration details:

```starlark
load("//tools/rust:deps.bzl", "CARGO")
load(
    "@rules_monorepo//rules_monorepo_rust:cargo_defs.bzl",
    "cargo_rust_binary",
    "cargo_rust_test",
)

cargo_rust_binary(
    name = "worker",
    srcs = ["src/main.rs"],
    cargo = CARGO,
    edition = "2024",
)

cargo_rust_test(
    name = "worker_test",
    srcs = ["tests/worker.rs"],
    cargo = CARGO,
    bazel_deps = [":worker_lib"],
    edition = "2024",
)
```

The macros infer normal, target-specific, development, proc-macro, and
first-party path dependencies. `cargo_rust_test` includes Cargo dev dependencies
by default. Use `bazel_deps` only for generated files or other non-Cargo Bazel
edges. Existing `deps`, `cargo_deps`, `cargo_macro_deps`, and direct
`all_crate_deps_fn` arguments remain accepted for source compatibility.

First-party path dependencies resolve to their Bazel package default label.
Therefore a depended-on Cargo library at `//libs/orderbook` must expose its
canonical target as `//libs/orderbook:orderbook`.

Public macros are:

- `cargo_rust_library`
- `cargo_rust_binary`
- `cargo_rust_proc_macro`
- `cargo_rust_test`
- `cargo_rust_test_suite`

They are exported from `@rules_monorepo//rules_monorepo_rust:cargo_defs.bzl`.

Common upstream Rust rules are re-exported by the public `defs.bzl` and
`cargo_defs.bzl` facades, so consumer BUILD files do not load `@rules_rust`
directly. This includes the native Rust rules, Clippy/doc/rustfmt rules,
`cargo_build_script`, and `rust_wasm_bindgen`.

## Hermetic Cargo and rust-analyzer

Run the Bazel-provisioned Cargo from the workspace directory:

```bash
bazel run @rules_monorepo//tools/rust:cargo -- fmt
bazel run @rules_monorepo//tools/rust:cargo -- metadata --locked
```

Configure rust-analyzer without installing Rust locally:

```bash
bazel run @rules_monorepo//tools/rust:rust_analyzer_setup -- --per-package-workspaces vscode
bazel run @rules_monorepo//tools/rust:rust_analyzer_setup -- --per-package-workspaces neovim
bazel run @rules_monorepo//tools/rust:rust_analyzer_setup -- --per-package-workspaces helix
bazel run @rules_monorepo//tools/rust:rust_analyzer_setup -- --per-package-workspaces print
```

Omit `--per-package-workspaces` for full-workspace indexing. Package splitting
keeps very large workspaces responsive, but rust-analyzer reloads when moving
between packages and reverse dependents are not indexed. Flycheck uses Bazel
`rustc`, not Clippy; repository `just lint` commands remain the authoritative
lint entry point.

The setup command writes editor configuration and a local
`.rules_rust_analyzer` launcher/cache tree. Consumers should ignore those
generated files and wrap this target with an editor-explicit `just dev-setup`
recipe rather than installing editors or extensions.

## Formatting and telemetry

Consumers should commit a stable-only root `rustfmt.toml` and configure:

```text
build --@rules_rust//rust/settings:rustfmt.toml=//:rustfmt.toml
```

This makes Bazel formatting and `cargo fmt` share the same configuration.
Disable Aspect repository telemetry explicitly in every root `.bazelrc`
because `.bazelrc` policy is not inherited through module dependencies:

```text
common --repo_env=ASPECT_TOOLS_TELEMETRY=
```

## Cargo audit

`cargo_audit_test` defaults to the official checksum-pinned cargo-audit 0.22.1
binary for the execution platform and a shared pinned RustSec database. The
prebuilt matrix covers macOS and Linux on AMD64/ARM64, with no host Cargo.

```starlark
cargo_audit_test(
    name = "audit",
    cargo_locks = ["//:Cargo.lock", "//bins/etl:Cargo.lock"],
)
```

`cargo_lock` retains the original single-test behavior. `cargo_locks` creates
one isolated test per lock and a stable suite at the requested `name`.
`cargo_audit`, `advisory_db`, and `advisory_db_marker` remain overridable.

## Rust binary to OCI image

```starlark
load("@rules_monorepo//rules_monorepo_rust:defs.bzl", "rust_binary_oci_image")

rust_binary_oci_image(
    name = "worker",
    architecture = "arm64",
    binary = ":worker",
    repository = "registry.example.com/example/worker",
    tarball_format = "docker",
)
```

Generated public targets are `:worker_image`, `:worker_image.digest`,
`:worker_load`, `:worker_tarball`, and `:worker_push`.

Each invocation creates exactly one platform image. Defaults are AMD64, OCI
load/tarball output, `/app`, UID/GID `65532:65532`, and the shared pinned
Debian 12 distroless `cc:nonroot` base. Use `load_format = "docker"` for `fw`;
use a distinct `tarball_format` when only a component tarball must be Docker.
