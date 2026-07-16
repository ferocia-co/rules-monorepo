"""Configuration shared by the language-agnostic OCI macros and tests."""

_DEFAULT_BASES = {
    "amd64": Label("@distroless_cc_linux_amd64//:distroless_cc_linux_amd64"),
    "arm64": Label("@distroless_cc_linux_arm64//:distroless_cc_linux_arm64"),
}

_FORMATS = ["docker", "oci"]

def binary_oci_target_names(name):
    """Returns the stable public labels emitted by binary_oci_image."""
    return struct(
        digest = name + "_image.digest",
        image = name + "_image",
        load_target = name + "_load",
        push = name + "_push",
        tarball = name + "_tarball",
    )

def resolve_binary_oci_config(
        architecture = "amd64",
        base = None,
        entrypoint = None,
        binary_name = None,
        package_dir = "/app",
        workdir = "/app",
        user = "65532:65532",
        load_format = "oci",
        tarball_format = None):
    """Validates and resolves stable defaults for a single-platform image."""
    if architecture not in _DEFAULT_BASES:
        fail("architecture must be one of {}, got {!r}".format(sorted(_DEFAULT_BASES.keys()), architecture))
    if load_format not in _FORMATS:
        fail("load_format must be one of {}, got {!r}".format(_FORMATS, load_format))
    if tarball_format == None:
        tarball_format = load_format
    if tarball_format not in _FORMATS:
        fail("tarball_format must be one of {}, got {!r}".format(_FORMATS, tarball_format))
    if base == None:
        base = _DEFAULT_BASES[architecture]
    if entrypoint == None:
        if binary_name == None:
            fail("binary_name is required when entrypoint is not provided")
        clean_package_dir = package_dir.rstrip("/")
        if clean_package_dir == "":
            clean_package_dir = "/"
        entrypoint = [clean_package_dir + "/" + binary_name]

    return struct(
        architecture = architecture,
        base = base,
        entrypoint = entrypoint,
        load_format = load_format,
        package_dir = package_dir,
        tarball_format = tarball_format,
        user = user,
        workdir = workdir,
    )
