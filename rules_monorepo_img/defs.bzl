"""Experimental rules_img helpers kept separate from production rules_oci APIs."""

load("@rules_img//img:image.bzl", "image_manifest")
load("@rules_img//img:layer.bzl", "file_metadata", "image_layer")
load(":config.bzl", "resolve_rust_binary_img_pilot_config", "rust_binary_img_pilot_target_names")

def _pilot_tags(tags):
    result = list(tags or [])
    for tag in ["manual", "rules_img_pilot"]:
        if tag not in result:
            result.append(tag)
    return result

def rust_binary_img_pilot(
        name,
        binary,
        base = None,
        tags = None,
        visibility = None):
    """Builds one experimental ARM64 rules_img manifest from a Rust binary.

    This macro intentionally emits no rules_oci tags and no load or push target.
    It exists only for side-by-side image-build evaluation.
    """
    config = resolve_rust_binary_img_pilot_config(
        binary = binary,
        base = base,
    )
    public = rust_binary_img_pilot_target_names(name)
    base_tags = _pilot_tags(tags)
    common_kwargs = {}
    if visibility != None:
        common_kwargs["visibility"] = visibility

    image_layer(
        name = public.layer,
        compress = "gzip",
        create_parent_directories = "enabled",
        estargz = "disabled",
        file_metadata = {
            config.binary_path: file_metadata(
                gid = 65532,
                mode = "0755",
                uid = 65532,
            ),
        },
        include_runfiles = False,
        srcs = {config.binary_path: binary},
        tags = base_tags,
        **common_kwargs
    )

    image_manifest(
        name = public.image,
        base = config.base,
        cmd = [],
        entrypoint = [config.binary_path],
        layers = [":" + public.layer],
        platform = config.platform,
        stamp = "disabled",
        tags = base_tags,
        user = config.user,
        working_dir = config.workdir,
        **common_kwargs
    )

    native.filegroup(
        name = public.digest,
        srcs = [":" + public.image],
        output_group = "digest",
        tags = base_tags,
        **common_kwargs
    )
