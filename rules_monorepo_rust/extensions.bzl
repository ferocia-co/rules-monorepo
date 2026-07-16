"""Rust module extensions re-exported from rules_rs."""

load("@rules_rs//rs:extensions.bzl", _crate = "crate")
load("@rules_rust//extensions/wasm_bindgen:extensions.bzl", _rust_wasm_bindgen = "rust_ext")

crate = _crate
rust_wasm_bindgen = _rust_wasm_bindgen
