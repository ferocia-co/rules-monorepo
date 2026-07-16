"""Rust-specific rules layered on top of rules_monorepo."""

load(":rust/oci.bzl", _rust_binary_oci_image = "rust_binary_oci_image")
load(":rust/transitions.bzl", _transitioned_binary = "transitioned_binary", _transitioned_binary_arm64 = "transitioned_binary_arm64")

rust_binary_oci_image = _rust_binary_oci_image
transitioned_binary = _transitioned_binary
transitioned_binary_arm64 = _transitioned_binary_arm64
