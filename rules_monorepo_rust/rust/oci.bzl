"""Rust helpers for OCI image pipelines."""

load("//rules_monorepo:defs.bzl", "binary_oci_image")
load(":rust/transitions.bzl", "transitioned_binary")

def rust_binary_oci_image(
        name,
        binary,
        base = "@distroless_cc_linux_amd64",
        repo_tags = None,
        repository = None,
        remote_tags = None,
        tags = None):
    """Generate a Linux OCI image pipeline for a Rust binary target."""

    base_tags = list(tags or [])
    base_tags.extend(["manual", "oci"])

    linux_bin_amd64 = name + "_linux"

    transitioned_binary(
        name = linux_bin_amd64,
        binary = binary,
        tags = base_tags,
    )

    binary_oci_image(
        name = name,
        binary = ":" + linux_bin_amd64,
        base = base,
        repo_tags = repo_tags,
        repository = repository,
        remote_tags = remote_tags,
        tags = base_tags,
    )
