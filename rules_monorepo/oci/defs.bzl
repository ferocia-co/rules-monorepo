"""Language-agnostic OCI image helpers."""

load("@rules_oci//oci:defs.bzl", "oci_image", "oci_image_index", "oci_load", "oci_push")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")
load(":oci/config.bzl", "binary_oci_target_names", "resolve_binary_oci_config")

def _executable_file_impl(ctx):
    executable = ctx.attr.binary[DefaultInfo].files_to_run.executable
    if executable == None:
        fail("binary must provide an executable", attr = "binary")

    # platform_transition_binary intentionally forwards both the original
    # executable and its renamed symlink in DefaultInfo.files. pkg_tar's
    # label-to-path map accepts exactly one file, so expose only the executable
    # selected by FilesToRunProvider at this packaging boundary.
    return [DefaultInfo(files = depset([executable]))]

_executable_file = rule(
    implementation = _executable_file_impl,
    attrs = {
        "binary": attr.label(
            cfg = "target",
            executable = True,
            mandatory = True,
        ),
    },
)

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
        architecture = "amd64",
        base = None,
        binary_name = None,
        annotations = None,
        cmd = None,
        created = None,
        entrypoint = None,
        env = None,
        exposed_ports = None,
        labels = None,
        load_format = "oci",
        package_dir = "/app",
        repo_tags = None,
        repository = None,
        remote_tags = None,
        tags = None,
        tarball_format = None,
        tars = None,
        user = "65532:65532",
        volumes = None,
        workdir = "/app"):
    """Generate an OCI image pipeline from a pre-built Linux binary target.

    Generated targets:
      - <name>_image
      - <name>_image.digest
      - <name>_load
      - <name>_tarball
      - <name>_push
    """

    base_tags = _dedupe_tags(tags)

    if binary_name == None:
        binary_name = _target_name(binary)
    if binary_name == None:
        fail("binary must be a label string")

    config = resolve_binary_oci_config(
        architecture = architecture,
        base = base,
        binary_name = binary_name,
        entrypoint = entrypoint,
        load_format = load_format,
        package_dir = package_dir,
        tarball_format = tarball_format,
        user = user,
        workdir = workdir,
    )

    layer_arch = name + "_layer_" + architecture
    image_arch = name + "_image_" + architecture
    binary_file = name + "_binary_file_" + architecture
    public = binary_oci_target_names(name)
    image = public.image
    load_target = public.load_target
    push_target = public.push

    _executable_file(
        name = binary_file,
        binary = binary,
        tags = base_tags + ["oci_binary_internal"],
    )

    pkg_tar(
        name = layer_arch,
        files = {":" + binary_file: binary_name},
        package_dir = config.package_dir,
        tags = base_tags,
    )

    oci_image(
        name = image_arch,
        annotations = annotations,
        base = config.base,
        cmd = cmd,
        created = created,
        entrypoint = config.entrypoint,
        env = env,
        exposed_ports = exposed_ports,
        labels = labels,
        tars = list(tars or []) + [":" + layer_arch],
        user = config.user,
        volumes = volumes,
        workdir = config.workdir,
        tags = base_tags + ["oci_image_internal"],
    )

    native.alias(
        name = image,
        actual = ":" + image_arch,
        tags = base_tags + ["oci_image"],
    )

    native.filegroup(
        name = image + ".digest",
        srcs = [":" + image_arch + ".digest"],
        tags = base_tags + ["oci_image"],
    )

    if repo_tags == None:
        repo_tags = ["{}:local".format(_default_repo_name(name))]

    tarball_files = name + "_tarball_files"
    tarball_target = public.tarball

    # rules_oci requires an image-index input when emitting an OCI archive.
    # This is a single-entry transport wrapper only; the public image and push
    # targets remain the architecture-specific image manifest above.
    oci_transport_image = None
    if config.load_format == "oci" or config.tarball_format == "oci":
        oci_transport_image = name + "_transport_{}_oci_index".format(architecture)
        oci_image_index(
            name = oci_transport_image,
            images = [":" + image_arch],
            tags = base_tags + ["oci_transport_internal"],
        )

    load_image = ":" + image
    if config.load_format == "oci":
        load_image = ":" + oci_transport_image

    oci_load(
        name = load_target,
        image = load_image,
        format = config.load_format,
        repo_tags = repo_tags,
        tags = base_tags + ["oci_load"],
    )

    tarball_load_target = load_target
    if config.tarball_format != config.load_format:
        tarball_load_target = name + "_tarball_{}_{}_load".format(architecture, config.tarball_format)
        tarball_image = ":" + image
        if config.tarball_format == "oci":
            tarball_image = ":" + oci_transport_image
        oci_load(
            name = tarball_load_target,
            image = tarball_image,
            format = config.tarball_format,
            repo_tags = repo_tags,
            tags = base_tags + ["oci_tarball_internal"],
        )

    native.filegroup(
        name = tarball_files,
        srcs = [":" + tarball_load_target],
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
