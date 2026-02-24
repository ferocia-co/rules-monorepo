# Contributing

## Development Prerequisites

- Bazel or Bazelisk
- Python 3 (required at runtime by `rules_monorepo:k8s_apply_helper`)
- `kubectl` and `kustomize` are fetched via module extension by default (configurable via `monorepo_tools.k8s(...)`), no manual install required

## Local Validation

Use analysis-only validation to catch rule wiring regressions without full builds:

```bash
env -u BAZEL_OPTS bazelisk --ignore_all_rc_files --output_user_root=/tmp/rules-monorepo-bazel-root build --nobuild //examples/rust_service:app_deploy.apply
```

## CI Expectations

Every push and pull request runs `.github/workflows/ci.yml`. Keep local checks aligned with:

```bash
bazelisk --ignore_all_rc_files query //...
bazelisk --ignore_all_rc_files build --nobuild //examples/rust_service:app_deploy.apply
```

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
