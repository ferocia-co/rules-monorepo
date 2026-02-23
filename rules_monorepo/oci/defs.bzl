"""Language-agnostic OCI image helpers."""

load("@rules_oci//oci:defs.bzl", "oci_image", "oci_load", "oci_push")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

def _dedupe_tags(tags):
    deduped = []
    for tag in list(tags or []) + ["manual", "oci"]:
        if tag not in deduped:
            deduped.append(tag)
    return deduped

def _default_repo_name(name):
    return name.replace("_", "-")

def _image_name_from_repo_tags(repo_tags):
    if type(repo_tags) != "list" or len(repo_tags) == 0:
        return None
    tag = repo_tags[0]
    if type(tag) != "string":
        return None
    if ":" in tag:
        return tag.rsplit(":", 1)[0]
    return tag

def _target_name(label):
    if type(label) != "string":
        return None
    if label.startswith(":"):
        return label[1:]
    if ":" in label:
        return label.rsplit(":", 1)[1]
    return label.rsplit("/", 1)[-1]

def binary_oci_image(
        name,
        binary,
        base = "@distroless_cc_linux_amd64",
        entrypoint = None,
        package_dir = "/app",
        repo_tags = None,
        repository = None,
        remote_tags = None,
        tags = None):
    """Generate an OCI image pipeline from a pre-built Linux binary target.

    Generated targets:
      - <name>_image
      - <name>_image.digest
      - <name>_load
      - <name>_tarball
      - <name>_push
    """

    base_tags = _dedupe_tags(tags)

    layer_amd64 = name + "_layer_amd64"
    image_amd64 = name + "_image_amd64"
    image = name + "_image"
    load_target = name + "_load"
    push_target = name + "_push"

    if entrypoint == None:
        binary_name = _target_name(binary)
        if binary_name == None:
            fail("binary must be a label string")
        clean_package_dir = package_dir.rstrip("/")
        if clean_package_dir == "":
            clean_package_dir = "/"
        entrypoint = [clean_package_dir + "/" + binary_name]

    pkg_tar(
        name = layer_amd64,
        srcs = [binary],
        package_dir = package_dir,
        tags = base_tags,
    )

    oci_image(
        name = image_amd64,
        base = base,
        entrypoint = entrypoint,
        tars = [":" + layer_amd64],
        tags = base_tags + ["oci_image_internal"],
    )

    native.alias(
        name = image,
        actual = ":" + image_amd64,
        tags = base_tags + ["oci_image"],
    )

    native.filegroup(
        name = image + ".digest",
        srcs = [":" + image_amd64 + ".digest"],
        tags = base_tags + ["oci_image"],
    )

    if repo_tags == None:
        repo_tags = ["{}:local".format(_default_repo_name(name))]

    tarball_files = name + "_tarball_files"
    tarball_target = name + "_tarball"

    oci_load(
        name = load_target,
        image = ":" + image,
        format = "oci",
        repo_tags = repo_tags,
        tags = base_tags + ["oci_load"],
    )

    native.filegroup(
        name = tarball_files,
        srcs = [":" + load_target],
        output_group = "tarball",
        tags = base_tags + ["oci_tarball"],
    )

    native.genrule(
        name = tarball_target,
        srcs = [":" + tarball_files],
        outs = [name + ".tar"],
        cmd = "cp $(location :{}) $@".format(tarball_files),
        tags = base_tags + ["oci_tarball"],
    )

    if repository == None:
        image_name = _image_name_from_repo_tags(repo_tags) or _default_repo_name(name)
        repository = "registry.invalid/{}".format(image_name)

    if remote_tags == None:
        remote_tags = []

    oci_push(
        name = push_target,
        image = ":" + image,
        repository = repository,
        remote_tags = remote_tags,
        tags = base_tags + ["oci_push"],
    )
