"""Focused API-shape tests for the rules_rs Cargo adapter."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(":rust/cargo.bzl", "cargo_alias_specs_for_testing", "cargo_aliases", "cargo_all_crate_deps", "cargo_package", "cargo_target_kwargs_for_testing")

_FAKE_DEP_DATA = {
    "workspace/build-proc-macro": {
        "aliases": {
            "//libs:build_proc_macro": "build_proc_macro_alias",
        },
        "build_deps": ["//libs:build_proc_macro"],
        "build_deps_by_platform": {},
        "deps": [],
        "deps_by_platform": {},
        "dev_deps": [],
        "dev_deps_by_platform": {},
    },
    "workspace/member": {
        "aliases": {
            "//libs:build": "build_alias",
            "//libs:build_linux": "build_linux_alias",
            "//libs:dev_reverse": "dev_reverse_alias",
            "//libs:dev_linux": "dev_linux_alias",
            "//libs:normal": "normal_alias",
            "//libs:normal_linux": "normal_linux_alias",
            "//libs:shared_across_kinds": "shared_across_kinds_alias",
            "//libs:stale_aggregate_only": "stale_aggregate_only_alias",
        },
        "build_deps": ["//libs:build"],
        "build_deps_by_platform": {
            "//cfg:linux": ["//libs:build_linux"],
        },
        "deps": [
            "//libs:normal",
            "//libs:shared_across_kinds",
        ],
        "deps_by_platform": {
            "//cfg:linux": ["//libs:normal_linux"],
        },
        "dev_deps": ["//libs:dev_reverse"],
        "dev_deps_by_platform": {
            "//cfg:linux": [
                "//libs:dev_linux",
                "//libs:shared_across_kinds",
            ],
        },
    },
}

def _fake_aliases(package_name = None):
    return {"package": package_name}

def _fake_all_crate_deps(
        normal = False,
        normal_dev = False,
        build = False,
        package_name = None,
        cargo_only = False):
    return [normal, normal_dev, build, package_name, cargo_only]

def _cargo_generated_api_impl(ctx):
    env = unittest.begin(ctx)
    cargo = cargo_package(
        aliases_fn = _fake_aliases,
        all_crate_deps_fn = _fake_all_crate_deps,
        dep_data = _FAKE_DEP_DATA,
        package_name = "workspace/member",
    )

    asserts.equals(
        env,
        {
            "//libs:normal": "normal_alias",
            "//libs:shared_across_kinds": "shared_across_kinds_alias",
        },
        cargo_alias_specs_for_testing(
            dep_data = cargo.dep_data,
            package_name = cargo.package_name,
        ).common,
    )
    asserts.equals(
        env,
        [True, True, False, "workspace/member", True],
        cargo_all_crate_deps(
            cargo = cargo,
            normal_dev = True,
            cargo_only = True,
        ),
    )
    return unittest.end(env)

cargo_generated_api_test = unittest.make(_cargo_generated_api_impl)

def _normal_aliases_exclude_dev_reverse_edge_impl(ctx):
    env = unittest.begin(ctx)

    specs = cargo_alias_specs_for_testing(
        dep_data = _FAKE_DEP_DATA,
        package_name = "workspace/member",
    )

    asserts.equals(env, {
        "//libs:normal": "normal_alias",
        "//libs:shared_across_kinds": "shared_across_kinds_alias",
    }, specs.common)
    asserts.equals(env, {
        "//cfg:linux": {"//libs:normal_linux": "normal_linux_alias"},
    }, specs.by_platform)
    asserts.equals(env, None, specs.common.get("//libs:dev_reverse"))
    asserts.equals(env, None, specs.common.get("//libs:stale_aggregate_only"))
    asserts.equals(env, None, specs.by_platform["//cfg:linux"].get("//libs:dev_linux"))

    return unittest.end(env)

normal_aliases_exclude_dev_reverse_edge_test = unittest.make(_normal_aliases_exclude_dev_reverse_edge_impl)

def _test_aliases_include_dev_edges_impl(ctx):
    env = unittest.begin(ctx)

    specs = cargo_alias_specs_for_testing(
        dep_data = _FAKE_DEP_DATA,
        package_name = "workspace/member",
        normal_dev = True,
    )

    asserts.equals(env, {
        "//libs:dev_reverse": "dev_reverse_alias",
        "//libs:normal": "normal_alias",
        "//libs:shared_across_kinds": "shared_across_kinds_alias",
    }, specs.common)
    asserts.equals(env, {
        "//cfg:linux": {
            "//libs:dev_linux": "dev_linux_alias",
            "//libs:normal_linux": "normal_linux_alias",
        },
    }, specs.by_platform)

    return unittest.end(env)

test_aliases_include_dev_edges_test = unittest.make(_test_aliases_include_dev_edges_impl)

def _build_aliases_select_only_build_edges_impl(ctx):
    env = unittest.begin(ctx)

    specs = cargo_alias_specs_for_testing(
        dep_data = _FAKE_DEP_DATA,
        package_name = "workspace/member",
        normal = False,
        build = True,
    )

    asserts.equals(env, {"//libs:build": "build_alias"}, specs.common)
    asserts.equals(env, {
        "//cfg:linux": {"//libs:build_linux": "build_linux_alias"},
    }, specs.by_platform)

    return unittest.end(env)

build_aliases_select_only_build_edges_test = unittest.make(_build_aliases_select_only_build_edges_impl)

def _build_proc_macro_aliases_fold_into_build_edges_impl(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        {"//libs:build_proc_macro": "build_proc_macro_alias"},
        cargo_aliases(
            dep_data = _FAKE_DEP_DATA,
            package_name = "workspace/build-proc-macro",
            normal = False,
            build_proc_macro = True,
        ),
    )

    return unittest.end(env)

build_proc_macro_aliases_fold_into_build_edges_test = unittest.make(_build_proc_macro_aliases_fold_into_build_edges_impl)

def _explicit_empty_aliases_remain_authoritative_impl(ctx):
    env = unittest.begin(ctx)

    cargo = cargo_package(
        dep_data = _FAKE_DEP_DATA,
        package_name = "workspace/member",
    )
    kwargs = cargo_target_kwargs_for_testing(
        kwargs = {"aliases": {}},
        aliases_fn = None,
        cargo = cargo,
        package_name = "",
        include_dev_deps = True,
        include_dev_proc_macro_deps = True,
    )

    asserts.equals(env, {"aliases": {}}, kwargs)

    return unittest.end(env)

explicit_empty_aliases_remain_authoritative_test = unittest.make(_explicit_empty_aliases_remain_authoritative_impl)

def _legacy_alias_function_still_works_impl(ctx):
    env = unittest.begin(ctx)

    cargo = cargo_package(
        aliases_fn = _fake_aliases,
        package_name = "workspace/member",
    )

    asserts.equals(env, {"package": "workspace/member"}, cargo_aliases(cargo = cargo))

    return unittest.end(env)

legacy_alias_function_still_works_test = unittest.make(_legacy_alias_function_still_works_impl)

def cargo_api_tests():
    unittest.suite(
        "cargo_api_tests",
        build_aliases_select_only_build_edges_test,
        build_proc_macro_aliases_fold_into_build_edges_test,
        cargo_generated_api_test,
        explicit_empty_aliases_remain_authoritative_test,
        legacy_alias_function_still_works_test,
        normal_aliases_exclude_dev_reverse_edge_test,
        test_aliases_include_dev_edges_test,
    )
