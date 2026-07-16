"""Rust helpers for OCI image pipelines."""

load("//rules_monorepo:defs.bzl", "binary_oci_image")
load(":rust/transitions.bzl", "transitioned_binary", "transitioned_binary_arm64")

def _target_name(label):
    if type(label) != "string":
        return None
    if label.startswith(":"):
        return label[1:]
    if ":" in label:
        return label.rsplit(":", 1)[1]
    return label.rsplit("/", 1)[-1]

def rust_binary_oci_image(
        name,
        binary,
        architecture = "amd64",
        base = None,
        entrypoint = None,
        load_format = "oci",
        package_dir = "/app",
        repo_tags = None,
        repository = None,
        remote_tags = None,
        tags = None,
        tarball_format = None,
        tars = None,
        user = "65532:65532",
        workdir = "/app",
        **kwargs):
    """Generate a Linux OCI image pipeline for a Rust binary target."""

    base_tags = list(tags or [])
    base_tags.extend(["manual", "oci"])

    binary_name = _target_name(binary)
    if binary_name == None:
        fail("binary must be a label string")

    if architecture == "amd64":
        transition_rule = transitioned_binary
    elif architecture == "arm64":
        transition_rule = transitioned_binary_arm64
    else:
        fail("architecture must be one of ['amd64', 'arm64'], got {!r}".format(architecture))

    linux_binary = name + "_linux_" + architecture

    transition_rule(
        name = linux_binary,
        binary = binary,
        tags = base_tags,
    )

    binary_oci_image(
        name = name,
        architecture = architecture,
        binary = ":" + linux_binary,
        binary_name = binary_name,
        base = base,
        entrypoint = entrypoint,
        load_format = load_format,
        package_dir = package_dir,
        repo_tags = repo_tags,
        repository = repository,
        remote_tags = remote_tags,
        tags = base_tags,
        tarball_format = tarball_format,
        tars = tars,
        user = user,
        workdir = workdir,
        **kwargs
    )
