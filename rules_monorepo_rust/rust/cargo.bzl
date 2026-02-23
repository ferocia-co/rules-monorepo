"""Cargo-inferred wrappers for rules_rust targets.

This file expects crate_universe repositories to be exposed as:

    use_repo(crates, "cargo_dep")
"""

load("@cargo_dep//:defs.bzl", "all_crate_deps")
load("@rules_rust//rust:defs.bzl", "rust_binary", "rust_library", "rust_test")

def _resolved_package_name(package_name):
    return package_name if package_name else native.package_name()

def _merged(explicit, inferred):
    deps = list(explicit or [])
    deps.extend(inferred)
    return deps

def cargo_all_crate_deps(
        package_name = "",
        normal = True,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False):
    """Returns crate_universe deps for a package.

    Args:
        package_name: crate_universe package name. Defaults to native.package_name().
        normal: include normal deps.
        normal_dev: include dev deps.
        proc_macro: include proc-macro deps.
        proc_macro_dev: include proc-macro dev deps.
    """
    return all_crate_deps(
        package_name = _resolved_package_name(package_name),
        normal = normal,
        normal_dev = normal_dev,
        proc_macro = proc_macro,
        proc_macro_dev = proc_macro_dev,
    )

def cargo_proc_macro_deps(
        package_name = "",
        include_dev_deps = False):
    """Convenience wrapper for proc-macro deps."""
    return cargo_all_crate_deps(
        package_name = package_name,
        normal = False,
        normal_dev = False,
        proc_macro = True,
        proc_macro_dev = include_dev_deps,
    )

def cargo_rust_library(
        name,
        deps = None,
        proc_macro_deps = None,
        package_name = "",
        include_dev_deps = False,
        include_dev_proc_macro_deps = False,
        **kwargs):
    """rust_library wrapper that infers Cargo deps from crate_universe."""
    rust_library(
        name = name,
        deps = _merged(
            deps,
            cargo_all_crate_deps(
                package_name = package_name,
                normal = True,
                normal_dev = include_dev_deps,
                proc_macro = False,
                proc_macro_dev = False,
            ),
        ),
        proc_macro_deps = _merged(
            proc_macro_deps,
            cargo_proc_macro_deps(
                package_name = package_name,
                include_dev_deps = include_dev_proc_macro_deps,
            ),
        ),
        **kwargs
    )

def cargo_rust_binary(
        name,
        deps = None,
        package_name = "",
        include_dev_deps = False,
        **kwargs):
    """rust_binary wrapper that infers Cargo deps from crate_universe."""
    rust_binary(
        name = name,
        deps = _merged(
            deps,
            cargo_all_crate_deps(
                package_name = package_name,
                normal = True,
                normal_dev = include_dev_deps,
                proc_macro = False,
                proc_macro_dev = False,
            ),
        ),
        **kwargs
    )

def cargo_rust_test(
        name,
        deps = None,
        package_name = "",
        include_dev_deps = True,
        **kwargs):
    """rust_test wrapper that infers Cargo deps from crate_universe."""
    rust_test(
        name = name,
        deps = _merged(
            deps,
            cargo_all_crate_deps(
                package_name = package_name,
                normal = True,
                normal_dev = include_dev_deps,
                proc_macro = False,
                proc_macro_dev = False,
            ),
        ),
        **kwargs
    )
