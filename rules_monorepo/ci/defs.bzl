"""Configure a shared CI runner with consumer-owned Bazel targets."""

load("@rules_python//python:py_binary.bzl", "py_binary")

def _config_impl(ctx):
    config = json.decode(ctx.attr.settings)
    config["exclusions"] = ctx.file.exclusions.short_path if ctx.file.exclusions else None
    ctx.actions.write(ctx.outputs.out, json.encode(config))
    return [DefaultInfo(
        files = depset([ctx.outputs.out]),
        runfiles = ctx.runfiles(files = [ctx.file.exclusions] if ctx.file.exclusions else []),
    )]

_ci_config = rule(
    implementation = _config_impl,
    attrs = {
        "exclusions": attr.label(allow_single_file = [".json"]),
        "out": attr.output(mandatory = True),
        "settings": attr.string(mandatory = True),
    },
)

def ci_runner(
        name,
        exclusions = None,
        build_targets = [],
        always_test_targets = [],
        check_targets = [],
        lockfile_targets = [],
        clippy_root = "",
        oci_root = "",
        oci_scope = "//...",
        full_check_paths = [],
        test_args = [],
        full_check_args = [],
        docker_jobs = 2,
        oci_jobs = 16,
        **kwargs):
    """Discover tests and select PR checks from the consumer's dependency graph.

    check_targets are executables run before checks with BAZEL_REAL set.
    lockfile_targets are built with --nobuild --lockfile_mode=error.
    clippy_root lists direct lint dependencies; oci_root lists standard OCI tarballs.
    """
    if docker_jobs < 1 or oci_jobs < 1:
        fail("CI concurrency must be positive")
    config = dict(
        build_targets = build_targets,
        always_test_targets = always_test_targets,
        check_targets = check_targets,
        lockfile_targets = lockfile_targets,
        clippy_root = clippy_root,
        oci_root = oci_root,
        oci_scope = oci_scope,
        full_check_paths = full_check_paths,
        test_args = test_args,
        full_check_args = full_check_args,
        docker_jobs = docker_jobs,
        oci_jobs = oci_jobs,
    )
    for key in ("build_targets", "always_test_targets", "check_targets", "lockfile_targets"):
        for target in config[key]:
            if not target.startswith("//") and not target.startswith("@"):
                fail("{} requires absolute Bazel labels: {}".format(key, target))
    _ci_config(
        name = name + "_config",
        exclusions = exclusions,
        out = name + ".config.json",
        settings = json.encode(config),
    )
    py_binary(
        name = name,
        main_module = "rules_monorepo_ci.runner",
        args = ["--config", "$(rootpath :" + name + "_config)"],
        data = [":" + name + "_config"],
        deps = [Label("//tools/ci:runner")],
        env = {"PYTHONDONTWRITEBYTECODE": "1"},
        **kwargs
    )
