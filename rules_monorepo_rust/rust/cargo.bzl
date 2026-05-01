"""Cargo-inferred wrappers for rules_rust targets.

This file does not load a crate_universe repository directly. Consumers pass
crate_universe helpers via `cargo_package(...)` or the lower-level `*_fn`
parameters.
"""

load("@rules_rust//rust:defs.bzl", "rust_binary", "rust_library", "rust_proc_macro", "rust_test")

def cargo_package(
        aliases_fn = None,
        all_crate_deps_fn = None,
        package_name = ""):
    """Returns package-scoped Cargo inference helpers for cargo_rust_* macros."""
    return struct(
        aliases_fn = aliases_fn,
        all_crate_deps_fn = all_crate_deps_fn,
        package_name = package_name,
    )

def _resolved_package_name(package_name, cargo = None):
    if package_name:
        return package_name
    if cargo != None and getattr(cargo, "package_name", ""):
        return cargo.package_name
    return native.package_name()

def _resolved_aliases_fn(aliases_fn, cargo):
    if aliases_fn != None:
        return aliases_fn
    if cargo != None and hasattr(cargo, "aliases_fn"):
        return cargo.aliases_fn
    return None

def _resolved_all_crate_deps_fn(all_crate_deps_fn, cargo):
    if all_crate_deps_fn != None:
        return all_crate_deps_fn
    if cargo != None and hasattr(cargo, "all_crate_deps_fn"):
        return cargo.all_crate_deps_fn
    return None

def _merged(explicit, inferred):
    deps = list(explicit or [])
    deps.extend(inferred or [])
    return deps

def _with_manifest_compile_data(kwargs, include_manifest_compile_data):
    out = dict(kwargs)
    if not include_manifest_compile_data:
        return out

    manifest = native.glob(["Cargo.toml"])
    compile_data = list(out.pop("compile_data", []))
    compile_data.extend(manifest)
    out["compile_data"] = compile_data
    return out

def _sanitize_target_name(value):
    sanitized = value
    for ch in ["/", "\\", ".", "-", ":", "@"]:
        sanitized = sanitized.replace(ch, "_")
    return sanitized

def _generated_test_target_name(suite_name, src):
    if type(src) != "string":
        fail("cargo_rust_test_suite only supports string labels in srcs, got {}".format(src))
    return "{}__{}".format(suite_name, _sanitize_target_name(src))

def cargo_aliases(
        aliases_fn = None,
        package_name = "",
        cargo = None,
        normal = True,
        normal_dev = False,
        proc_macro = True,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False):
    """Returns crate_universe aliases for a package."""
    resolved_aliases_fn = _resolved_aliases_fn(aliases_fn, cargo)
    if resolved_aliases_fn == None:
        return None

    return resolved_aliases_fn(
        package_name = _resolved_package_name(package_name, cargo = cargo),
        normal = normal,
        normal_dev = normal_dev,
        proc_macro = proc_macro,
        proc_macro_dev = proc_macro_dev,
        build = build,
        build_proc_macro = build_proc_macro,
    )

def cargo_all_crate_deps(
        all_crate_deps_fn = None,
        package_name = "",
        cargo = None,
        normal = True,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False):
    """Returns package-scoped direct crate_universe deps from Cargo.toml.

    Args:
        all_crate_deps_fn: optional function loaded from @cargo_dep//:defs.bzl.
        package_name: Cargo package/Bazel package name. Defaults to native.package_name().
        cargo: optional `cargo_package(...)` context.
        normal: include normal deps.
        normal_dev: include dev deps.
        proc_macro: include proc-macro deps.
        proc_macro_dev: include proc-macro dev deps.
    """
    resolved_all_crate_deps_fn = _resolved_all_crate_deps_fn(all_crate_deps_fn, cargo)
    if resolved_all_crate_deps_fn == None:
        return []

    return resolved_all_crate_deps_fn(
        package_name = _resolved_package_name(package_name, cargo = cargo),
        normal = normal,
        normal_dev = normal_dev,
        proc_macro = proc_macro,
        proc_macro_dev = proc_macro_dev,
    )

def cargo_proc_macro_deps(
        all_crate_deps_fn = None,
        package_name = "",
        cargo = None,
        include_dev_deps = False):
    """Convenience wrapper for proc-macro deps."""
    return cargo_all_crate_deps(
        all_crate_deps_fn = all_crate_deps_fn,
        package_name = package_name,
        cargo = cargo,
        normal = False,
        normal_dev = False,
        proc_macro = True,
        proc_macro_dev = include_dev_deps,
    )

def _inferred_binary_or_library_deps(
        all_crate_deps_fn,
        cargo,
        package_name,
        include_dev_deps):
    resolved_all_crate_deps_fn = _resolved_all_crate_deps_fn(all_crate_deps_fn, cargo)
    if resolved_all_crate_deps_fn == None:
        return []
    return cargo_all_crate_deps(
        all_crate_deps_fn = resolved_all_crate_deps_fn,
        package_name = package_name,
        cargo = cargo,
        normal = True,
        normal_dev = include_dev_deps,
    )

def _with_inferred_aliases(
        kwargs,
        aliases_fn,
        cargo,
        package_name,
        include_dev_deps,
        include_dev_proc_macro_deps):
    out = dict(kwargs)
    if out.get("aliases") != None:
        return out

    inferred_aliases = cargo_aliases(
        aliases_fn = aliases_fn,
        package_name = package_name,
        cargo = cargo,
        normal = True,
        normal_dev = include_dev_deps,
        proc_macro = True,
        proc_macro_dev = include_dev_proc_macro_deps,
    )
    if inferred_aliases != None:
        out["aliases"] = inferred_aliases
    return out

def cargo_rust_library(
        name,
        deps = None,
        proc_macro_deps = None,
        cargo = None,
        aliases_fn = None,
        package_name = "",
        include_dev_deps = False,
        include_dev_proc_macro_deps = False,
        include_manifest_compile_data = True,
        all_crate_deps_fn = None,
        cargo_deps = None,
        cargo_macro_deps = None,
        **kwargs):
    """rust_library wrapper that merges Cargo.toml deps with explicit deps.

    Args:
        cargo: optional `cargo_package(...)` context.
        aliases_fn: optional function loaded from @cargo_dep//:defs.bzl.
        all_crate_deps_fn: optional direct-deps function loaded from @cargo_dep//:defs.bzl.
        cargo_deps: optional precomputed normal deps.
        cargo_macro_deps: optional precomputed proc-macro deps.
    """
    inferred_deps = _merged(
        _inferred_binary_or_library_deps(
            all_crate_deps_fn = all_crate_deps_fn,
            cargo = cargo,
            package_name = package_name,
            include_dev_deps = include_dev_deps,
        ),
        cargo_deps,
    )
    inferred_proc_macro_deps = _merged(
        cargo_proc_macro_deps(
            all_crate_deps_fn = all_crate_deps_fn,
            package_name = package_name,
            cargo = cargo,
            include_dev_deps = include_dev_proc_macro_deps,
        ),
        cargo_macro_deps,
    )
    rust_library(
        name = name,
        deps = _merged(deps, inferred_deps),
        proc_macro_deps = _merged(proc_macro_deps, inferred_proc_macro_deps),
        **_with_inferred_aliases(
            kwargs = _with_manifest_compile_data(kwargs, include_manifest_compile_data),
            aliases_fn = aliases_fn,
            cargo = cargo,
            package_name = package_name,
            include_dev_deps = include_dev_deps,
            include_dev_proc_macro_deps = include_dev_proc_macro_deps,
        )
    )

def cargo_rust_binary(
        name,
        deps = None,
        proc_macro_deps = None,
        cargo = None,
        aliases_fn = None,
        package_name = "",
        include_dev_deps = False,
        include_dev_proc_macro_deps = False,
        include_manifest_compile_data = True,
        all_crate_deps_fn = None,
        cargo_deps = None,
        cargo_macro_deps = None,
        **kwargs):
    """rust_binary wrapper that merges Cargo.toml deps with explicit deps."""
    inferred_deps = _merged(
        _inferred_binary_or_library_deps(
            all_crate_deps_fn = all_crate_deps_fn,
            cargo = cargo,
            package_name = package_name,
            include_dev_deps = include_dev_deps,
        ),
        cargo_deps,
    )
    inferred_proc_macro_deps = _merged(
        cargo_proc_macro_deps(
            all_crate_deps_fn = all_crate_deps_fn,
            package_name = package_name,
            cargo = cargo,
            include_dev_deps = include_dev_proc_macro_deps,
        ),
        cargo_macro_deps,
    )
    rust_binary(
        name = name,
        deps = _merged(deps, inferred_deps),
        proc_macro_deps = _merged(proc_macro_deps, inferred_proc_macro_deps),
        **_with_inferred_aliases(
            kwargs = _with_manifest_compile_data(kwargs, include_manifest_compile_data),
            aliases_fn = aliases_fn,
            cargo = cargo,
            package_name = package_name,
            include_dev_deps = include_dev_deps,
            include_dev_proc_macro_deps = include_dev_proc_macro_deps,
        )
    )

def cargo_rust_proc_macro(
        name,
        deps = None,
        proc_macro_deps = None,
        cargo = None,
        aliases_fn = None,
        package_name = "",
        include_dev_deps = False,
        include_dev_proc_macro_deps = False,
        include_manifest_compile_data = True,
        all_crate_deps_fn = None,
        cargo_deps = None,
        cargo_macro_deps = None,
        **kwargs):
    """rust_proc_macro wrapper that merges Cargo.toml deps with explicit deps."""
    inferred_deps = _merged(
        _inferred_binary_or_library_deps(
            all_crate_deps_fn = all_crate_deps_fn,
            cargo = cargo,
            package_name = package_name,
            include_dev_deps = include_dev_deps,
        ),
        cargo_deps,
    )
    inferred_proc_macro_deps = _merged(
        cargo_proc_macro_deps(
            all_crate_deps_fn = all_crate_deps_fn,
            package_name = package_name,
            cargo = cargo,
            include_dev_deps = include_dev_proc_macro_deps,
        ),
        cargo_macro_deps,
    )
    rust_proc_macro(
        name = name,
        deps = _merged(deps, inferred_deps),
        proc_macro_deps = _merged(proc_macro_deps, inferred_proc_macro_deps),
        **_with_inferred_aliases(
            kwargs = _with_manifest_compile_data(kwargs, include_manifest_compile_data),
            aliases_fn = aliases_fn,
            cargo = cargo,
            package_name = package_name,
            include_dev_deps = include_dev_deps,
            include_dev_proc_macro_deps = include_dev_proc_macro_deps,
        )
    )

def cargo_rust_test(
        name,
        deps = None,
        proc_macro_deps = None,
        cargo = None,
        aliases_fn = None,
        package_name = "",
        include_dev_deps = True,
        include_dev_proc_macro_deps = True,
        include_manifest_compile_data = True,
        all_crate_deps_fn = None,
        cargo_deps = None,
        cargo_macro_deps = None,
        **kwargs):
    """rust_test wrapper that merges Cargo.toml deps with explicit deps."""
    inferred_deps = _merged(
        _inferred_binary_or_library_deps(
            all_crate_deps_fn = all_crate_deps_fn,
            cargo = cargo,
            package_name = package_name,
            include_dev_deps = include_dev_deps,
        ),
        cargo_deps,
    )
    inferred_proc_macro_deps = _merged(
        cargo_proc_macro_deps(
            all_crate_deps_fn = all_crate_deps_fn,
            package_name = package_name,
            cargo = cargo,
            include_dev_deps = include_dev_proc_macro_deps,
        ),
        cargo_macro_deps,
    )
    rust_test(
        name = name,
        deps = _merged(deps, inferred_deps),
        proc_macro_deps = _merged(proc_macro_deps, inferred_proc_macro_deps),
        **_with_inferred_aliases(
            kwargs = _with_manifest_compile_data(kwargs, include_manifest_compile_data),
            aliases_fn = aliases_fn,
            cargo = cargo,
            package_name = package_name,
            include_dev_deps = include_dev_deps,
            include_dev_proc_macro_deps = include_dev_proc_macro_deps,
        )
    )

def cargo_rust_test_suite(
        name,
        srcs,
        shared_srcs = None,
        tags = None,
        visibility = None,
        testonly = None,
        **kwargs):
    """cargo_rust_test wrapper mirroring rules_rust's rust_test_suite macro.

    Each `.rs` file in `srcs` becomes its own `cargo_rust_test` target, while
    `shared_srcs` are included in every generated test crate. All other kwargs
    are forwarded to the generated `cargo_rust_test` targets.
    """
    shared_srcs = list(shared_srcs or [])
    shared_srcs_set = {src: True for src in shared_srcs}
    test_tags = list(tags or [])
    generated_tests = []

    for src in srcs:
        if type(src) != "string":
            fail("cargo_rust_test_suite only supports string labels in srcs, got {}".format(src))
        if src in shared_srcs_set or not src.endswith(".rs"):
            continue

        test_name = _generated_test_target_name(name, src)
        cargo_rust_test(
            name = test_name,
            srcs = [src] + shared_srcs,
            tags = test_tags,
            **kwargs
        )
        generated_tests.append(":" + test_name)

    if not generated_tests:
        fail("cargo_rust_test_suite({}, ...) did not find any Rust test sources".format(name))

    suite_kwargs = {
        "name": name,
        "tests": generated_tests,
        "tags": test_tags,
    }
    if visibility != None:
        suite_kwargs["visibility"] = visibility
    if testonly != None:
        suite_kwargs["testonly"] = testonly

    native.test_suite(**suite_kwargs)
