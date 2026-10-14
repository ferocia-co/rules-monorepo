"""Regression coverage for native data outside Cargo OUT_DIR."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _native_directory_impl(ctx):
    archive = [
        library.pic_static_library or library.static_library
        for linker_input in ctx.attr.archive[CcInfo].linking_context.linker_inputs.to_list()
        for library in linker_input.libraries
        if library.pic_static_library or library.static_library
    ][0]
    directory = ctx.actions.declare_directory(ctx.label.name)
    ctx.actions.run_shell(
        inputs = [archive],
        outputs = [directory],
        arguments = [archive.path, directory.path],
        command = "mkdir -p \"$2\"\ncp \"$1\" \"$2/libnative_fixture.a\"",
    )
    return [DefaultInfo(files = depset([directory]))]

native_directory = rule(
    implementation = _native_directory_impl,
    attrs = {"archive": attr.label(mandatory = True, providers = [CcInfo])},
)

def _native_link_input_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [action for action in analysistest.target_actions(env) if action.mnemonic == "Rustc"]
    asserts.equals(env, 1, len(actions))
    directory = ctx.attr.native_data[DefaultInfo].files.to_list()[0]
    asserts.true(
        env,
        directory in actions[0].inputs.to_list(),
        "Original native build-script data missing from final Rustc inputs",
    )
    return analysistest.end(env)

native_link_input_test = analysistest.make(
    _native_link_input_test_impl,
    attrs = {"native_data": attr.label(mandatory = True)},
)
