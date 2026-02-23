"""Cargo-inferred public API for rules_monorepo_rust.

Load `all_crate_deps` from your crate_universe repository in BUILD files and
pass it via `all_crate_deps_fn` to cargo_rust_* macros.
"""

load(":rust/cargo.bzl", _cargo_all_crate_deps = "cargo_all_crate_deps", _cargo_proc_macro_deps = "cargo_proc_macro_deps", _cargo_rust_binary = "cargo_rust_binary", _cargo_rust_library = "cargo_rust_library", _cargo_rust_proc_macro = "cargo_rust_proc_macro", _cargo_rust_test = "cargo_rust_test")
load(":rust/defs.bzl", _linux_amd64_transition = "linux_amd64_transition", _linux_arm64_transition = "linux_arm64_transition", _rust_binary_oci_image = "rust_binary_oci_image", _transitioned_binary = "transitioned_binary", _transitioned_binary_arm64 = "transitioned_binary_arm64")

cargo_all_crate_deps = _cargo_all_crate_deps
cargo_proc_macro_deps = _cargo_proc_macro_deps
cargo_rust_library = _cargo_rust_library
cargo_rust_binary = _cargo_rust_binary
cargo_rust_proc_macro = _cargo_rust_proc_macro
cargo_rust_test = _cargo_rust_test

rust_binary_oci_image = _rust_binary_oci_image
linux_amd64_transition = _linux_amd64_transition
linux_arm64_transition = _linux_arm64_transition
transitioned_binary = _transitioned_binary
transitioned_binary_arm64 = _transitioned_binary_arm64

monorepo_cargo_all_crate_deps = _cargo_all_crate_deps
monorepo_cargo_proc_macro_deps = _cargo_proc_macro_deps
monorepo_cargo_rust_library = _cargo_rust_library
monorepo_cargo_rust_binary = _cargo_rust_binary
monorepo_cargo_rust_proc_macro = _cargo_rust_proc_macro
monorepo_cargo_rust_test = _cargo_rust_test
monorepo_rust_binary_oci_image = _rust_binary_oci_image
