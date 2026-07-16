"""Compatibility macros for building Linux binaries on any host."""

load("@aspect_bazel_lib//lib:transitions.bzl", "platform_transition_binary")

_LINUX_AMD64_PLATFORM = "@rules_rs//rs/platforms:x86_64-unknown-linux-gnu"
_LINUX_ARM64_PLATFORM = "@rules_rs//rs/platforms:aarch64-unknown-linux-gnu"

def _transitioned_binary(name, binary, target_platform, basename, **kwargs):
    # The previous local rule named its executable after the transitioned
    # target. Preserve that contract: consumers use the basename as the path
    # inside OCI images, while Aspect's rule otherwise defaults to the source
    # binary's basename.
    if basename == None:
        basename = name

    platform_transition_binary(
        name = name,
        basename = basename,
        binary = binary,
        target_platform = target_platform,
        **kwargs
    )

def transitioned_binary(name, binary, basename = None, **kwargs):
    """Build `binary` for rules_rs's canonical Linux AMD64 platform."""
    _transitioned_binary(
        name = name,
        basename = basename,
        binary = binary,
        target_platform = _LINUX_AMD64_PLATFORM,
        **kwargs
    )

def transitioned_binary_arm64(name, binary, basename = None, **kwargs):
    """Build `binary` for rules_rs's canonical Linux ARM64 platform."""
    _transitioned_binary(
        name = name,
        basename = basename,
        binary = binary,
        target_platform = _LINUX_ARM64_PLATFORM,
        **kwargs
    )
