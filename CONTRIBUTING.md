# Contributing

## Development Prerequisites

- Bazel or Bazelisk
- Python 3 (required at runtime by `rules_monorepo:k8s_apply_helper`)
- `kubectl` and `kustomize` are fetched via module extension by default (configurable via `monorepo_tools.k8s(...)`), no manual install required
- Rust, Cargo, rustfmt, Clippy, and rust-analyzer are fetched by `rules_rs`; do not install host Rust for repository validation

## Local Validation

Use analysis-only validation to catch rule wiring regressions without full builds:

```bash
env -u BAZEL_OPTS bazelisk --ignore_all_rc_files --output_user_root=/tmp/rules-monorepo-bazel-root build --nobuild //examples/rust_service:app_deploy.apply
```

## CI Expectations

Every push and pull request runs `.github/workflows/ci.yml`. Keep local checks aligned with:

```bash
bazelisk query //...
bazelisk build --nobuild //examples/rust_service:app_deploy.apply
bazelisk test //rules_monorepo_rust:cargo_api_tests //rules_monorepo:oci_config_tests //tools/oci:oci_test
bazelisk build //examples/cargo_workspace/app //tools/rust:cargo //tools/rust:rust_analyzer_setup
bazelisk build //examples/rust_service:app_tarball //examples/rust_service:app_arm64_tarball //examples/rust_service:app_component_oci_tarball
```

CI intentionally reads the checked-in `.bazelrc` so Aspect telemetry remains
disabled and the canonical rustfmt configuration is exercised. The
`--ignore_all_rc_files` local analysis command above is an additional portability
check, not the CI policy path.

## Documentation Expectations

Any public API/macro change should update:

- `README.md`
- `rules_monorepo/README.md`
- `rules_monorepo_rust/README.md`
- `examples/README.md`

## Release Checklist

- Update `module(... version = "...")` in `MODULE.bazel`
- Verify example target analysis succeeds
- Confirm `LICENSE` remains present and correct
