"""Cargo-inferred public API for rules_monorepo_rust.

Load `aliases` and `all_crate_deps` from your crate_universe repository in
BUILD files, wrap them once with `cargo_package(...)`, and pass that `cargo`
context to the `cargo_rust_*` macros. Direct `all_crate_deps_fn` usage remains
supported for existing callers.
"""

load(":rust/audit.bzl", _cargo_audit_test = "cargo_audit_test")
load(":rust/cargo.bzl", _cargo_aliases = "cargo_aliases", _cargo_all_crate_deps = "cargo_all_crate_deps", _cargo_package = "cargo_package", _cargo_proc_macro_deps = "cargo_proc_macro_deps", _cargo_rust_binary = "cargo_rust_binary", _cargo_rust_library = "cargo_rust_library", _cargo_rust_proc_macro = "cargo_rust_proc_macro", _cargo_rust_test = "cargo_rust_test", _cargo_rust_test_suite = "cargo_rust_test_suite")
load(":rust/defs.bzl", _linux_amd64_transition = "linux_amd64_transition", _linux_arm64_transition = "linux_arm64_transition", _rust_binary_oci_image = "rust_binary_oci_image", _transitioned_binary = "transitioned_binary", _transitioned_binary_arm64 = "transitioned_binary_arm64")

cargo_audit_test = _cargo_audit_test
cargo_aliases = _cargo_aliases
cargo_all_crate_deps = _cargo_all_crate_deps
cargo_package = _cargo_package
cargo_proc_macro_deps = _cargo_proc_macro_deps
cargo_rust_library = _cargo_rust_library
cargo_rust_binary = _cargo_rust_binary
cargo_rust_proc_macro = _cargo_rust_proc_macro
cargo_rust_test = _cargo_rust_test
cargo_rust_test_suite = _cargo_rust_test_suite

rust_binary_oci_image = _rust_binary_oci_image
linux_amd64_transition = _linux_amd64_transition
linux_arm64_transition = _linux_arm64_transition
transitioned_binary = _transitioned_binary
transitioned_binary_arm64 = _transitioned_binary_arm64

monorepo_cargo_audit_test = _cargo_audit_test
monorepo_cargo_aliases = _cargo_aliases
monorepo_cargo_all_crate_deps = _cargo_all_crate_deps
monorepo_cargo_package = _cargo_package
monorepo_cargo_proc_macro_deps = _cargo_proc_macro_deps
monorepo_cargo_rust_library = _cargo_rust_library
monorepo_cargo_rust_binary = _cargo_rust_binary
monorepo_cargo_rust_proc_macro = _cargo_rust_proc_macro
monorepo_cargo_rust_test = _cargo_rust_test
monorepo_cargo_rust_test_suite = _cargo_rust_test_suite
monorepo_rust_binary_oci_image = _rust_binary_oci_image
