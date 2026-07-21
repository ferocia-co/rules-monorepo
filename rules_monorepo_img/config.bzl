"""Configuration for the isolated rules_img Rust-binary pilot."""

_ARM64_PLATFORM = Label("@rules_rs//rs/platforms:aarch64-unknown-linux-gnu")
_DEFAULT_BASE = Label("@rules_img_distroless_cc_linux_arm64//:image")

def _target_name(label):
    if type(label) != "string":
        return None
    if label.startswith(":"):
        return label[1:]
    if ":" in label:
        return label.rsplit(":", 1)[1]
    return label.rsplit("/", 1)[-1]

def rust_binary_img_pilot_target_names(name):
    """Returns the targets emitted by rust_binary_img_pilot."""
    return struct(
        digest = name + "_img_digest",
        image = name + "_img_image",
        layer = name + "_img_layer",
    )

def resolve_rust_binary_img_pilot_config(
        binary,
        base = None):
    """Validates and resolves the deliberately narrow ARM64 pilot config."""
    binary_name = _target_name(binary)
    if binary_name == None or binary_name == "":
        fail("binary must be a non-empty label string")
    if base == None:
        base = _DEFAULT_BASE

    return struct(
        base = base,
        binary_path = "/app/" + binary_name,
        platform = _ARM64_PLATFORM,
        user = "65532:65532",
        workdir = "/app",
    )
