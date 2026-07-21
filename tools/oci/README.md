# OCI orchestration

`@rules_monorepo//tools/oci` discovers the public targets produced by the OCI
macros through their `oci_image`, `oci_tarball`, and `oci_push` tags. It always
runs from `BUILD_WORKSPACE_DIRECTORY` and calls the consumer's Bazel wrapper.

```bash
bazel run @rules_monorepo//tools/oci -- build --bazel ./tools/bazel --all
bazel run @rules_monorepo//tools/oci -- tarball --bazel ./tools/bazel --image worker
bazel run @rules_monorepo//tools/oci -- push --bazel ./tools/bazel \
  --image worker --repository registry.example.com/team/worker \
  --tag "$GIT_SHA" --tag latest --bazel-jobs 16 --push-jobs 4

# Temporary rollback path if direct launcher execution is incompatible.
bazel run @rules_monorepo//tools/oci -- push --bazel ./tools/bazel \
  --image worker --push-execution bazel-run
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
together and stops if that build fails. `--bazel-jobs` bounds that batch build,
while `--push-jobs` independently bounds concurrent push processes. Both
default to 4. The legacy `--jobs` option sets both values for backwards
compatibility; an explicit split option wins regardless of argument order.

Push execution defaults to `--push-execution direct`. The grouped build uses
`--remote_download_outputs=all`, then one same-configuration `cquery` resolves
every selected target's `DefaultInfo.files_to_run.executable`. The tool resolves
the Bazel execution root, validates the complete set of materialized executable
launchers, and only then runs them with the existing repository and tag
arguments. This avoids one competing `bazel run` client and output-base lock per
image. Launcher failures are aggregated, concurrency remains bounded by
`--push-jobs`, and termination signals stop and reap outstanding launchers.

`--push-execution bazel-run` retains the previous per-image Bazel invocation as
an explicit rollback mode. It deliberately does not force all remote outputs or
perform launcher resolution.

Use `--dry-run` to validate selection and print a deterministic direct-launch
plan without building, loading, or pushing images. Direct dry runs still run
the discovery query, one analysis-only `cquery`, and `bazel info execution_root`
so the printed launcher paths are real for the selected configuration. Because
no build occurs, dry run validates plan completeness but not executable presence;
the non-dry path performs that check after its grouped build and before the
first registry mutation.
