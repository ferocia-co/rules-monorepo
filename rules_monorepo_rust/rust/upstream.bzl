"""Stable facade over common rules from the rules_rs-provided rules_rust."""

load(
    "@rules_rust//cargo:defs.bzl",
    _cargo_build_script = "cargo_build_script",
)
load(
    "@rules_rust//extensions/wasm_bindgen:defs.bzl",
    _RustWasmBindgenInfo = "RustWasmBindgenInfo",
    _rust_wasm_bindgen = "rust_wasm_bindgen",
    _rust_wasm_bindgen_test = "rust_wasm_bindgen_test",
    _rust_wasm_bindgen_toolchain = "rust_wasm_bindgen_toolchain",
)
load(
    "@rules_rust//rust:defs.bzl",
    _rust_binary = "rust_binary",
    _rust_clippy = "rust_clippy",
    _rust_doc = "rust_doc",
    _rust_doc_test = "rust_doc_test",
    _rust_library = "rust_library",
    _rust_proc_macro = "rust_proc_macro",
    _rust_test = "rust_test",
    _rust_test_suite = "rust_test_suite",
    _rustfmt_test = "rustfmt_test",
)

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
