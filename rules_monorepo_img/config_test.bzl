"""Focused analysis tests for the isolated rules_img pilot."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(":config.bzl", "resolve_rust_binary_img_pilot_config", "rust_binary_img_pilot_target_names")

def _arm64_defaults_impl(ctx):
    env = unittest.begin(ctx)
    config = resolve_rust_binary_img_pilot_config(binary = "//examples/rust_service:app")
    asserts.equals(env, Label("@rules_img_distroless_cc_linux_arm64//:image"), config.base)
    asserts.equals(env, "/app/app", config.binary_path)
    asserts.equals(env, Label("@rules_rs//rs/platforms:aarch64-unknown-linux-gnu"), config.platform)
    asserts.equals(env, "65532:65532", config.user)
    asserts.equals(env, "/app", config.workdir)
    return unittest.end(env)

arm64_defaults_test = unittest.make(_arm64_defaults_impl)

def _target_names_impl(ctx):
    env = unittest.begin(ctx)
    names = rust_binary_img_pilot_target_names("worker")
    asserts.equals(env, "worker_img_layer", names.layer)
    asserts.equals(env, "worker_img_image", names.image)
    asserts.equals(env, "worker_img_digest", names.digest)
    return unittest.end(env)

target_names_test = unittest.make(_target_names_impl)

def rules_img_pilot_config_tests():
    unittest.suite(
        "rules_img_pilot_config_tests",
        arm64_defaults_test,
        target_names_test,
    )
