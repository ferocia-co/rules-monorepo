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

`--scope` limits discovery to a query scope. `--image` may be repeated and
resolves, in order, an exact full label, generated target name, logical name,
then a conventional logical name with trailing `_oci` stripped. Resolution
stops at the first matching tier, and multiple targets at that tier are an
error; use a full label to disambiguate targets with the same name in different
packages. Build, tarball, and push operations use optimized (`opt`) binaries by
default; `--compilation-mode fastbuild|dbg|opt` provides an explicit override.
In push mode, `--repository` overrides the repository for every selected
target, while repeated `--tag` values are deduplicated in first-seen order.
Before any registry mutation, push mode builds all selected `oci_push` targets
together and stops if that build fails. Pushes then use at most `--jobs`
concurrent Bazel processes. Use `--dry-run` to validate selection and command
construction without loading or pushing images.
