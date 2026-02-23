"""Platform transition rules for building Linux binaries on any host."""

_LINUX_AMD64_PLATFORM = str(Label(":linux_amd64"))
_LINUX_ARM64_PLATFORM = str(Label(":linux_arm64"))

def _linux_amd64_transition_impl(settings, attr):
    _ = settings, attr
    return {"//command_line_option:platforms": _LINUX_AMD64_PLATFORM}

linux_amd64_transition = transition(
    implementation = _linux_amd64_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _linux_arm64_transition_impl(settings, attr):
    _ = settings, attr
    return {"//command_line_option:platforms": _LINUX_ARM64_PLATFORM}

linux_arm64_transition = transition(
    implementation = _linux_arm64_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _transitioned_binary_impl(ctx):
    src = ctx.attr.binary[0][DefaultInfo].files_to_run.executable
    out = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(output = out, target_file = src)
    return [
        DefaultInfo(
            files = depset([out]),
            executable = out,
            runfiles = ctx.runfiles(files = [out]),
        ),
    ]

transitioned_binary = rule(
    implementation = _transitioned_binary_impl,
    attrs = {
        "binary": attr.label(
            mandatory = True,
            cfg = linux_amd64_transition,
            executable = True,
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    executable = True,
)

transitioned_binary_arm64 = rule(
    implementation = _transitioned_binary_impl,
    attrs = {
        "binary": attr.label(
            mandatory = True,
            cfg = linux_arm64_transition,
            executable = True,
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    executable = True,
)
