"""Rustfmt check for explicitly listed Rust targets without dependency traversal.

The upstream rustfmt_test collector walks deps, proc_macro_deps, and crate even
when transitive=False. Its direct markers can instead be requested from the
upstream rustfmt_aspect on each listed target. Build this rule to check them.
"""

load("@rules_rust//rust:defs.bzl", "rust_common", "rustfmt_aspect")

def _rustfmt_direct_impl(ctx):
    checks = []
    for target in ctx.attr.targets:
        if OutputGroupInfo in target and hasattr(target[OutputGroupInfo], "rustfmt_checks"):
            checks.append(target[OutputGroupInfo].rustfmt_checks)
    return [DefaultInfo(files = depset(transitive = checks))]

rustfmt_direct = rule(
    implementation = _rustfmt_direct_impl,
    attrs = {
        "targets": attr.label_list(
            aspects = [rustfmt_aspect],
            providers = [
                [rust_common.crate_info],
                [rust_common.test_crate_info],
            ],
        ),
    },
    doc = "Checks direct Rust sources with the pinned rustfmt toolchain.",
)
