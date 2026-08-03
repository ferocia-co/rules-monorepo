"""Configuration shared by the language-agnostic OCI macros and tests."""

_DEFAULT_BASES = {
    "amd64": Label("@distroless_cc_linux_amd64//:distroless_cc_linux_amd64"),
    "arm64": Label("@distroless_cc_linux_arm64//:distroless_cc_linux_arm64"),
}

_FORMATS = ["docker", "oci"]

def oci_archive_target_names(name):
    """Returns the stable public labels emitted by oci_archive."""
    return struct(
        load_target = name + "_load",
        tarball = name + "_tarball",
    )

def binary_oci_target_names(name):
    """Returns the stable public labels emitted by binary_oci_image."""
    archive = oci_archive_target_names(name)
    return struct(
        digest = name + "_image.digest",
        image = name + "_image",
        load_target = archive.load_target,
        push = name + "_push",
        tarball = archive.tarball,
    )

def resolve_oci_archive_config(
        name,
        format = "oci",
        output = None,
        tarball_format = None):
    """Validates and resolves stable defaults for OCI load/tarball targets."""
    if format not in _FORMATS:
        fail("format must be one of {}, got {!r}".format(_FORMATS, format))
    if tarball_format == None:
        tarball_format = format
    if tarball_format not in _FORMATS:
        fail("tarball_format must be one of {}, got {!r}".format(_FORMATS, tarball_format))
    if output == None:
        output = name + ".tar"
    if type(output) != "string" or output == "":
        fail("output must be a non-empty string")

    return struct(
        format = format,
        output = output,
        tarball_format = tarball_format,
    )

def resolve_binary_oci_config(
        architecture = "amd64",
        base = None,
        discoverable = True,
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
    if type(discoverable) != "bool":
        fail("discoverable must be a bool, got {!r}".format(discoverable))
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
        discoverable = discoverable,
        entrypoint = entrypoint,
        load_format = load_format,
        package_dir = package_dir,
        tarball_format = tarball_format,
        user = user,
        workdir = workdir,
    )
