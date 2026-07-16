"""Turns a prebuilt source file into a Bazel executable target."""

def _executable_file_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(
        output = output,
        target_file = ctx.file.src,
        is_executable = True,
    )
    return [DefaultInfo(
        executable = output,
        files = depset([output]),
        runfiles = ctx.runfiles(files = [output]),
    )]

executable_file = rule(
    implementation = _executable_file_impl,
    executable = True,
    attrs = {
        "src": attr.label(
            allow_single_file = True,
            cfg = "exec",
            mandatory = True,
        ),
    },
)
