"""Macro-level analysis tests for OCI discovery and binary naming."""

load(":oci/defs.bzl", "binary_oci_image")

def _fixture_executable_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(output, "fixture", is_executable = True)
    return [DefaultInfo(executable = output)]

_fixture_executable = rule(
    implementation = _fixture_executable_impl,
    executable = True,
)

def _macro_contract_test_impl(ctx):
    if ctx.attr.expected:
        if ctx.attr.discovery_tag not in ctx.attr.actual_tags:
            fail("expected discovery tag {} in {}".format(ctx.attr.discovery_tag, ctx.attr.actual_tags))
    elif ctx.attr.discovery_tag in ctx.attr.actual_tags:
        fail("unexpected discovery tag {} in {}".format(ctx.attr.discovery_tag, ctx.attr.actual_tags))
    for base_tag in ["manual", "oci"]:
        if base_tag not in ctx.attr.actual_tags:
            fail("expected base tag {} in {}".format(base_tag, ctx.attr.actual_tags))
    if ctx.attr.expected_binary_name and ctx.attr.actual_binary_names != [ctx.attr.expected_binary_name]:
        fail("expected binary name {}, got {}".format(ctx.attr.expected_binary_name, ctx.attr.actual_binary_names))
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(executable, "#!/bin/sh\nexit 0\n", is_executable = True)
    return [DefaultInfo(executable = executable)]

macro_contract_test = rule(
    implementation = _macro_contract_test_impl,
    attrs = {
        "actual_binary_names": attr.string_list(),
        "actual_tags": attr.string_list(),
        "discovery_tag": attr.string(mandatory = True),
        "expected": attr.bool(mandatory = True),
        "expected_binary_name": attr.string(),
    },
    test = True,
)

def oci_macro_tests():
    _fixture_executable(name = "oci_macro_fixture_binary")
    binary_oci_image(
        name = "oci_macro_default",
        binary = ":oci_macro_fixture_binary",
        repository = "registry.invalid/default",
    )
    binary_oci_image(
        name = "oci_macro_private",
        binary = ":oci_macro_fixture_binary",
        binary_name = "soak-test",
        discoverable = False,
        repository = "registry.invalid/private",
    )

    tests = []
    for fixture, expected in [("oci_macro_default", True), ("oci_macro_private", False)]:
        for target_suffix, discovery_tag in [
            ("_image", "oci_image"),
            ("_push", "oci_push"),
            ("_tarball", "oci_tarball"),
        ]:
            test_name = fixture + target_suffix + "_discovery_tag_test"
            generated = native.existing_rule(fixture + target_suffix)
            macro_contract_test(
                name = test_name,
                actual_tags = generated["tags"],
                discovery_tag = discovery_tag,
                expected = expected,
            )
            tests.append(":" + test_name)

    layer = native.existing_rule("oci_macro_private_layer_amd64")
    macro_contract_test(
        name = "oci_macro_binary_name_test",
        actual_binary_names = layer["files"].values(),
        actual_tags = layer["tags"],
        discovery_tag = "oci_image",
        expected = False,
        expected_binary_name = "soak-test",
    )
    tests.append(":oci_macro_binary_name_test")
    native.test_suite(name = "oci_macro_tests", tests = tests)
