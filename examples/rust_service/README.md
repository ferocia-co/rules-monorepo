# rust_service Example

This example shows the full pipeline:

1. compile a Rust binary
2. package it as an OCI image
3. push image tags
4. render/apply/delete Kubernetes manifests

## Targets

- `:app` - Rust binary
- `:app_image` - OCI image
- `:app_push` - registry push target
- `:app_deploy` - rendered manifest
- `:app_deploy.apply` - apply flow
- `:app_deploy.delete` - delete flow

## Run

```bash
bazel run //examples/rust_service:app_deploy.apply
bazel run //examples/rust_service:app_deploy.delete
```

## Notes

- Manifest template uses `{{GIT_COMMIT_SHORT}}` for image tags.
- `k8s_oci_deploy` auto-wires `:app_push` before apply.
