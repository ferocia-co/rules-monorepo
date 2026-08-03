"""Rust-specific rules layered on top of rules_monorepo."""

load("//rules_monorepo_rust/zkvm:defs.bzl", _ZkvmGuestInfo = "ZkvmGuestInfo", _risc0_guest = "risc0_guest", _sp1_guest = "sp1_guest")
load(":rust/oci.bzl", _rust_binary_oci_image = "rust_binary_oci_image")
load(":rust/transitions.bzl", _transitioned_binary = "transitioned_binary", _transitioned_binary_arm64 = "transitioned_binary_arm64")

rust_binary_oci_image = _rust_binary_oci_image
transitioned_binary = _transitioned_binary
transitioned_binary_arm64 = _transitioned_binary_arm64
ZkvmGuestInfo = _ZkvmGuestInfo
risc0_guest = _risc0_guest
sp1_guest = _sp1_guest
