"""Focused API-shape tests for the rules_rs Cargo adapter."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(":rust/cargo.bzl", "cargo_aliases", "cargo_all_crate_deps", "cargo_package")

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
        package_name = "workspace/member",
    )

    asserts.equals(env, {"package": "workspace/member"}, cargo_aliases(cargo = cargo))
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

def cargo_api_tests():
    unittest.suite(
        "cargo_api_tests",
        cargo_generated_api_test,
    )
