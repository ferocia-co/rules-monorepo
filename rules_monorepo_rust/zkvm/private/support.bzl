"""Internal support toolchain used by the public RISC0 guest rule."""

Risc0SupportInfo = provider(
    fields = {
        "program_binary": "Host FilesToRunProvider for the ProgramBinary encoder.",
        "v1compat": "Pinned v1compat kernel ELF File.",
    },
)

def _risc0_support_toolchain_impl(ctx):
    return [
        platform_common.ToolchainInfo(
            risc0 = Risc0SupportInfo(
                program_binary = ctx.attr.program_binary[DefaultInfo].files_to_run,
                v1compat = ctx.file.v1compat,
            ),
        ),
    ]

risc0_support_toolchain = rule(
    implementation = _risc0_support_toolchain_impl,
    attrs = {
        "program_binary": attr.label(
            cfg = "exec",
            executable = True,
            mandatory = True,
        ),
        "v1compat": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
    },
)
