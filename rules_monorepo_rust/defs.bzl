"""Public API for rules_monorepo_rust."""

load(":rust/defs.bzl", _linux_amd64_transition = "linux_amd64_transition", _linux_arm64_transition = "linux_arm64_transition", _rust_binary_oci_image = "rust_binary_oci_image", _transitioned_binary = "transitioned_binary", _transitioned_binary_arm64 = "transitioned_binary_arm64")

rust_binary_oci_image = _rust_binary_oci_image
linux_amd64_transition = _linux_amd64_transition
linux_arm64_transition = _linux_arm64_transition
transitioned_binary = _transitioned_binary
transitioned_binary_arm64 = _transitioned_binary_arm64

monorepo_rust_binary_oci_image = _rust_binary_oci_image
