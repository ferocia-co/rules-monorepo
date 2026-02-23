"""Cargo-inferred wrappers for rules_rust targets.

This file does not load @cargo_dep directly. Consumers provide their own
`all_crate_deps` function from crate_universe.
"""

load("@rules_rust//rust:defs.bzl", "rust_binary", "rust_library", "rust_test")

def _resolved_package_name(package_name):
    return package_name if package_name else native.package_name()

def _merged(explicit, inferred):
    deps = list(explicit or [])
    deps.extend(inferred or [])
    return deps

def cargo_all_crate_deps(
        all_crate_deps_fn,
        package_name = "",
        normal = True,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False):
    """Returns crate_universe deps for a package.

    Args:
        all_crate_deps_fn: function loaded from @cargo_dep//:defs.bzl.
        package_name: crate_universe package name. Defaults to native.package_name().
        normal: include normal deps.
        normal_dev: include dev deps.
        proc_macro: include proc-macro deps.
        proc_macro_dev: include proc-macro dev deps.
    """
    return all_crate_deps_fn(
        package_name = _resolved_package_name(package_name),
        normal = normal,
        normal_dev = normal_dev,
        proc_macro = proc_macro,
        proc_macro_dev = proc_macro_dev,
    )

def cargo_proc_macro_deps(
        all_crate_deps_fn,
        package_name = "",
        include_dev_deps = False):
    """Convenience wrapper for proc-macro deps."""
    return cargo_all_crate_deps(
        all_crate_deps_fn = all_crate_deps_fn,
        package_name = package_name,
        normal = False,
        normal_dev = False,
        proc_macro = True,
        proc_macro_dev = include_dev_deps,
    )

def _inferred_binary_or_library_deps(
        all_crate_deps_fn,
        package_name,
        include_dev_deps):
    if all_crate_deps_fn == None:
        return []
    return cargo_all_crate_deps(
        all_crate_deps_fn = all_crate_deps_fn,
        package_name = package_name,
        normal = True,
        normal_dev = include_dev_deps,
    )

def cargo_rust_library(
        name,
        deps = None,
        proc_macro_deps = None,
        package_name = "",
        include_dev_deps = False,
        include_dev_proc_macro_deps = False,
        all_crate_deps_fn = None,
        cargo_deps = None,
        cargo_macro_deps = None,
        **kwargs):
    """rust_library wrapper that merges inferred Cargo deps with explicit deps.

    Args:
        all_crate_deps_fn: optional function loaded from @cargo_dep//:defs.bzl.
        cargo_deps: optional precomputed normal deps.
        cargo_macro_deps: optional precomputed proc-macro deps.
    """
    inferred_deps = _merged(
        _inferred_binary_or_library_deps(
            all_crate_deps_fn = all_crate_deps_fn,
            package_name = package_name,
            include_dev_deps = include_dev_deps,
        ),
        cargo_deps,
    )
    inferred_proc_macro_deps = _merged(
        cargo_proc_macro_deps(
            all_crate_deps_fn = all_crate_deps_fn,
            package_name = package_name,
            include_dev_deps = include_dev_proc_macro_deps,
        ) if all_crate_deps_fn != None else [],
        cargo_macro_deps,
    )
    rust_library(
        name = name,
        deps = _merged(deps, inferred_deps),
        proc_macro_deps = _merged(proc_macro_deps, inferred_proc_macro_deps),
        **kwargs
    )

def cargo_rust_binary(
        name,
        deps = None,
        package_name = "",
        include_dev_deps = False,
        all_crate_deps_fn = None,
        cargo_deps = None,
        **kwargs):
    """rust_binary wrapper that merges inferred Cargo deps with explicit deps."""
    inferred_deps = _merged(
        _inferred_binary_or_library_deps(
            all_crate_deps_fn = all_crate_deps_fn,
            package_name = package_name,
            include_dev_deps = include_dev_deps,
        ),
        cargo_deps,
    )
    rust_binary(
        name = name,
        deps = _merged(deps, inferred_deps),
        **kwargs
    )

def cargo_rust_test(
        name,
        deps = None,
        package_name = "",
        include_dev_deps = True,
        all_crate_deps_fn = None,
        cargo_deps = None,
        **kwargs):
    """rust_test wrapper that merges inferred Cargo deps with explicit deps."""
    inferred_deps = _merged(
        _inferred_binary_or_library_deps(
            all_crate_deps_fn = all_crate_deps_fn,
            package_name = package_name,
            include_dev_deps = include_dev_deps,
        ),
        cargo_deps,
    )
    rust_test(
        name = name,
        deps = _merged(deps, inferred_deps),
        **kwargs
    )
