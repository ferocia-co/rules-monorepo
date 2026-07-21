"""Focused tests for single-platform OCI configuration."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(":oci/config.bzl", "binary_oci_target_names", "oci_archive_target_names", "resolve_binary_oci_config", "resolve_oci_archive_config")

def _amd64_defaults_impl(ctx):
    env = unittest.begin(ctx)
    config = resolve_binary_oci_config(binary_name = "worker")
    asserts.equals(env, "amd64", config.architecture)
    asserts.equals(env, "/app", config.package_dir)
    asserts.equals(env, "/app", config.workdir)
    asserts.equals(env, "65532:65532", config.user)
    asserts.equals(env, ["/app/worker"], config.entrypoint)
    asserts.equals(env, "oci", config.load_format)
    asserts.equals(env, "oci", config.tarball_format)
    asserts.equals(env, Label("@distroless_cc_linux_amd64//:distroless_cc_linux_amd64"), config.base)
    return unittest.end(env)

amd64_defaults_test = unittest.make(_amd64_defaults_impl)

def _arm64_formats_impl(ctx):
    env = unittest.begin(ctx)
    config = resolve_binary_oci_config(
        architecture = "arm64",
        binary_name = "worker",
        load_format = "oci",
        tarball_format = "docker",
    )
    asserts.equals(env, "arm64", config.architecture)
    asserts.equals(env, "oci", config.load_format)
    asserts.equals(env, "docker", config.tarball_format)
    asserts.equals(env, Label("@distroless_cc_linux_arm64//:distroless_cc_linux_arm64"), config.base)
    return unittest.end(env)

arm64_formats_test = unittest.make(_arm64_formats_impl)

def _public_names_impl(ctx):
    env = unittest.begin(ctx)
    names = binary_oci_target_names("worker")
    asserts.equals(env, "worker_image", names.image)
    asserts.equals(env, "worker_image.digest", names.digest)
    asserts.equals(env, "worker_load", names.load_target)
    asserts.equals(env, "worker_tarball", names.tarball)
    asserts.equals(env, "worker_push", names.push)
    return unittest.end(env)

public_names_test = unittest.make(_public_names_impl)

def _archive_config_impl(ctx):
    env = unittest.begin(ctx)
    defaults = resolve_oci_archive_config(name = "worker_oci")
    asserts.equals(env, "oci", defaults.format)
    asserts.equals(env, "oci", defaults.tarball_format)
    asserts.equals(env, "worker_oci.tar", defaults.output)

    docker = resolve_oci_archive_config(
        name = "worker_component_oci",
        format = "docker",
        output = "worker-component.tar",
    )
    asserts.equals(env, "docker", docker.format)
    asserts.equals(env, "docker", docker.tarball_format)
    asserts.equals(env, "worker-component.tar", docker.output)
    return unittest.end(env)

archive_config_test = unittest.make(_archive_config_impl)

def _archive_names_impl(ctx):
    env = unittest.begin(ctx)
    names = oci_archive_target_names("worker_component_oci")
    asserts.equals(env, "worker_component_oci_load", names.load_target)
    asserts.equals(env, "worker_component_oci_tarball", names.tarball)
    return unittest.end(env)

archive_names_test = unittest.make(_archive_names_impl)

def oci_config_tests():
    unittest.suite(
        "oci_config_tests",
        amd64_defaults_test,
        archive_config_test,
        archive_names_test,
        arm64_formats_test,
        public_names_test,
    )
