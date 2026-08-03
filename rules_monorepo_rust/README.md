# rules_monorepo_rust

The Rust layer uses [`hermeticbuild/rules_rs`](https://github.com/hermeticbuild/rules_rs)
as the single source of Rust toolchains and Cargo dependency metadata. Consumers
keep normal Cargo workspaces and committed `Cargo.lock` files; BUILD targets do
not repeat Cargo dependencies.

It provides:

- Rust 1.97.0, Cargo, rustfmt, Clippy, rust-src, and rust-analyzer from Bazel
- Cargo-inferred library, binary, proc-macro, and test macros
- Linux AMD64/ARM64 compatibility macros using rules_rs's canonical platforms
- Rust binary-to-OCI helpers
- pinned RustSec audit integration
- transitioned RISC0 and SP1 guest compilation with checksum-pinned vendor
  toolchains

## Configure a Cargo workspace

Declare each independent Cargo workspace:

```starlark
bazel_dep(name = "rules_monorepo", version = "2026.08.03.1")

crate = use_extension(
    "@rules_rs//rs:extensions.bzl",
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
load("@crates//:data.bzl", "DEP_DATA")
load("@crates//:defs.bzl", "aliases", "all_crate_deps")
load("@rules_monorepo//rules_monorepo_rust:cargo_defs.bzl", "cargo_package")

CARGO = cargo_package(
    aliases_fn = aliases,
    all_crate_deps_fn = all_crate_deps,
    dep_data = DEP_DATA,
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
by default; libraries, binaries, and proc macros do not. Loading `DEP_DATA` once
also filters the generated aggregate aliases by those dependency kinds. Its
platform-specific aliases remain in matching `select()` branches, preserving
macOS/Linux cross-analysis without leaking platform-only or dev-only edges.
Use `bazel_deps` only for generated files or other non-Cargo Bazel edges.
Existing `deps`, `cargo_deps`, `cargo_macro_deps`, and direct
`all_crate_deps_fn` arguments remain accepted for source compatibility. An old
adapter without `DEP_DATA` still works, but retains rules_rs's aggregate alias
behavior until migrated.

For a direct build-script rule, select its Cargo aliases and dependencies with
`cargo_aliases(cargo = CARGO, normal = False, build = True)` and
`cargo_all_crate_deps(cargo = CARGO, normal = False, build = True)`.

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
directly. Binary, library, proc-macro, test, and build-script APIs come through
rules_rs's official facades. Clippy/doc/rustfmt, test-suite, and wasm-bindgen
rule APIs remain direct compatibility exports for rules_rs v0.0.96.

`transitioned_binary` and `transitioned_binary_arm64` are thin compatibility
macros over Aspect's `platform_transition_binary`. They target rules_rs's
`x86_64-unknown-linux-gnu` and `aarch64-unknown-linux-gnu` platforms and retain
the historical target-name executable basename by default. Pass `basename` to
override it.

The `rust_wasm_bindgen` module extension exported from `extensions.bzl` is the
rules_rs-provided extension. Consumers may instantiate and register it when its
CLI matches their crate version; projects that need another CLI keep an
explicit compatible toolchain. rules_monorepo does not globally select a
version because the wasm-bindgen protocol is version-sensitive.

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
    binary_name = "worker-service",
    discoverable = False,
    repository = "registry.example.com/example/worker",
    tarball_format = "docker",
)
```

Generated public targets are `:worker_image`, `:worker_image.digest`,
`:worker_load`, `:worker_tarball`, and `:worker_push`.

`binary_name` overrides the basename copied into `package_dir` and therefore
the default entrypoint. Set `discoverable = False` for an exact/manual pipeline:
all five targets remain directly usable, but the standard `oci_image`,
`oci_tarball`, and `oci_push` tags are omitted. Both options preserve their
existing defaults when unspecified.

For an additional Docker/OCI load and tarball pair around one already-built
image manifest, use the language-agnostic `oci_archive` macro from
`@rules_monorepo//rules_monorepo:defs.bzl`; it does not rebuild the Rust binary
or image. Its `image` input must be a single manifest, not an
`oci_image_index`.

Each invocation creates exactly one platform image. Defaults are AMD64, OCI
load/tarball output, `/app`, UID/GID `65532:65532`, and the shared pinned
Debian 12 distroless `cc:nonroot` base. Use `load_format = "docker"` for `fw`;
use a distinct `tarball_format` when only a component tarball must be Docker.

## RISC0 and SP1 guests

The public `defs.bzl` and `cargo_defs.bzl` facades export `risc0_guest`,
`sp1_guest`, and `ZkvmGuestInfo`. zkVM support is inert for transitive users.
A consumer root opts in by importing the generated hub and registering its
toolchains:

```starlark
zkvm = use_extension(
    "@rules_monorepo//rules_monorepo_rust:extensions.bzl",
    "zkvm_toolchains",
)
use_repo(zkvm, "zkvm_toolchains")

register_toolchains(
    "@zkvm_toolchains//:risc0_cc_toolchain",
    "@zkvm_toolchains//:risc0_rust_toolchain",
    "@zkvm_toolchains//:risc0_support_toolchain",
    "@zkvm_toolchains//:sp1_rust_toolchain",
)
```

The hub owns every asset-referencing toolchain target and resolves its pinned
compiler and v1compat repositories privately. Consumers import only the hub;
they do not need repository mappings for those implementation assets.

Wrap normal Rust binary targets rather than invoking Cargo from an action:

```starlark
load(
    "@rules_monorepo//rules_monorepo_rust:defs.bzl",
    "risc0_guest",
    "rust_binary",
    "sp1_guest",
)

rust_binary(
    name = "guest_program",
    srcs = ["src/main.rs"],
    edition = "2024",
)
risc0_guest(name = "guest_risc0", binary = ":guest_program")
sp1_guest(name = "guest_sp1", binary = ":guest_program")
```

Both wrappers transition atomically to `opt`, `riscv32`, `os:none`, and a
private proof-system constraint. `ZkvmGuestInfo` contains `elf`,
`proof_system`, and `target_triple`. SP1 returns its transitioned ELF. RISC0
combines the transitioned user ELF with the independently versioned v1compat
2.2.3 kernel using the exact `risc0-binfmt` 3.0.5 `ProgramBinary` encoding.

The compiler contract is RISC0 Rust `r0.1.88.0`, C toolchain `2024.01.05`, and
`riscv32im-risc0-zkvm-elf`. The registered standard C toolchain propagates its
checksum-pinned `riscv32-unknown-elf-gcc`, `ar`, `-march=rv32im`, and
`-mabi=ilp32` contract to native dependencies and Cargo build scripts. SP1
builder semantics are `5.2.4`, Rust
`succinct-1.91.1`, and `riscv32im-succinct-zkvm-elf`. These official compiler
executables run only on Linux x86_64. macOS supports package loading, unit
tests, and analysis with the explicit analysis-only execution platform; actual
guest builds run on Linux x86_64 CI/workers:

```bash
bazel build --nobuild \
  --extra_execution_platforms=@rules_monorepo//rules_monorepo_rust/zkvm:linux_x86_64_exec_platform \
  //examples/zkvm_guest:risc0_guest //examples/zkvm_guest:sp1_guest
```
