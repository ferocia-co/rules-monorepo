"""Cargo-inferred public API backed by rules_rs Cargo workspaces."""

load(":rust/audit.bzl", _cargo_audit_test = "cargo_audit_test")
load(":rust/cargo.bzl", _cargo_aliases = "cargo_aliases", _cargo_all_crate_deps = "cargo_all_crate_deps", _cargo_package = "cargo_package", _cargo_proc_macro_deps = "cargo_proc_macro_deps", _cargo_rust_binary = "cargo_rust_binary", _cargo_rust_library = "cargo_rust_library", _cargo_rust_proc_macro = "cargo_rust_proc_macro", _cargo_rust_test = "cargo_rust_test", _cargo_rust_test_suite = "cargo_rust_test_suite")
load(":rust/defs.bzl", _linux_amd64_transition = "linux_amd64_transition", _linux_arm64_transition = "linux_arm64_transition", _rust_binary_oci_image = "rust_binary_oci_image", _transitioned_binary = "transitioned_binary", _transitioned_binary_arm64 = "transitioned_binary_arm64")
load(":rust/upstream.bzl", _RustWasmBindgenInfo = "RustWasmBindgenInfo", _cargo_build_script = "cargo_build_script", _rust_binary = "rust_binary", _rust_clippy = "rust_clippy", _rust_doc = "rust_doc", _rust_doc_test = "rust_doc_test", _rust_library = "rust_library", _rust_proc_macro = "rust_proc_macro", _rust_test = "rust_test", _rust_test_suite = "rust_test_suite", _rust_wasm_bindgen = "rust_wasm_bindgen", _rust_wasm_bindgen_test = "rust_wasm_bindgen_test", _rust_wasm_bindgen_toolchain = "rust_wasm_bindgen_toolchain", _rustfmt_test = "rustfmt_test")

RustWasmBindgenInfo = _RustWasmBindgenInfo
cargo_build_script = _cargo_build_script
rust_binary = _rust_binary
rust_clippy = _rust_clippy
rust_doc = _rust_doc
rust_doc_test = _rust_doc_test
rust_library = _rust_library
rust_proc_macro = _rust_proc_macro
rust_test = _rust_test
rust_test_suite = _rust_test_suite
rust_wasm_bindgen = _rust_wasm_bindgen
rust_wasm_bindgen_test = _rust_wasm_bindgen_test
rust_wasm_bindgen_toolchain = _rust_wasm_bindgen_toolchain
rustfmt_test = _rustfmt_test

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
