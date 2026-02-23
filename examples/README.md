# Examples

This directory contains copy-pasteable examples for `rules_monorepo`.

## Use From GitHub

In a consumer repo `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_monorepo", version = "0.1.0")

archive_override(
    module_name = "rules_monorepo",
    urls = ["https://github.com/ferocia-co/rules-monorepo/archive/REPLACE_WITH_COMMIT_SHA.tar.gz"],
    strip_prefix = "rules-monorepo-REPLACE_WITH_COMMIT_SHA",
    integrity = "sha256-REPLACE_WITH_BASE64_SHA256",
)
```

See root `README.md` for `git_override` and `local_path_override` alternatives.
See `rules_monorepo_rust/README.md` for Cargo-inferred Rust wrappers (`cargo_defs.bzl`) that avoid duplicated crate deps in BUILD files.

## rust_service

Path: `examples/rust_service`

Demonstrates:

- `rust_binary` build
- `rust_binary_oci_image` packaging
- `k8s_oci_deploy` apply/delete targets

Note:

- this example uses plain `rust_binary` for minimal setup
- for Cargo-inferred dependency workflows, see `rules_monorepo_rust/README.md` and use `cargo_defs.bzl`

Key targets:

- `//examples/rust_service:app_push`
- `//examples/rust_service:app_deploy.apply`
- `//examples/rust_service:app_deploy.delete`

Analysis-only validation command:

```bash
env -u BAZEL_OPTS bazelisk --ignore_all_rc_files --output_user_root=/tmp/rules-monorepo-bazel-root build --nobuild //examples/rust_service:app_deploy.apply
```
