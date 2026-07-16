# OCI orchestration

`@rules_monorepo//tools/oci` discovers the public targets produced by the OCI
macros through their `oci_image`, `oci_tarball`, and `oci_push` tags. It always
runs from `BUILD_WORKSPACE_DIRECTORY` and calls the consumer's Bazel wrapper.

```bash
bazel run @rules_monorepo//tools/oci -- build --bazel ./tools/bazel --all
bazel run @rules_monorepo//tools/oci -- tarball --bazel ./tools/bazel --image worker
bazel run @rules_monorepo//tools/oci -- push --bazel ./tools/bazel \
  --image worker --repository registry.example.com/team/worker \
  --tag "$GIT_SHA" --tag latest --jobs 4
```

`--scope` limits discovery to a query scope. `--image` accepts a logical name,
the generated target name, or a full label and may be repeated. In push mode,
`--repository` overrides the repository for every selected target, while
`--tag` may be repeated. Pushes use at most `--jobs` concurrent Bazel processes.
Use `--dry-run` to validate selection and command construction without loading
or pushing images.
