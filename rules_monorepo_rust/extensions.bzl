"""Rust module extensions re-exported from rules_rs."""

load("@rules_rs//rs:extensions.bzl", _crate = "crate")
load("@rules_rs//rs:rules_rust_wasm_bindgen.bzl", _rust_wasm_bindgen = "rules_rust_wasm_bindgen")
load("//rules_monorepo_rust/zkvm:extensions.bzl", _zkvm_toolchains = "zkvm_toolchains")

crate = _crate
rust_wasm_bindgen = _rust_wasm_bindgen
zkvm_toolchains = _zkvm_toolchains
