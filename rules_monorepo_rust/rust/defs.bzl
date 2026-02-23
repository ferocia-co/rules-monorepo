"""Rust-specific rules layered on top of rules_monorepo."""

load(":rust/oci.bzl", _rust_binary_oci_image = "rust_binary_oci_image")
load(":rust/transitions.bzl", _linux_amd64_transition = "linux_amd64_transition", _linux_arm64_transition = "linux_arm64_transition", _transitioned_binary = "transitioned_binary", _transitioned_binary_arm64 = "transitioned_binary_arm64")

rust_binary_oci_image = _rust_binary_oci_image
linux_amd64_transition = _linux_amd64_transition
linux_arm64_transition = _linux_arm64_transition
transitioned_binary = _transitioned_binary
transitioned_binary_arm64 = _transitioned_binary_arm64
