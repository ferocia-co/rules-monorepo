"""Cargo audit integration for Bazel tests."""

def _to_rlocation_path(ctx, file):
    if file.short_path.startswith("../"):
        return file.short_path[3:]
    return ctx.workspace_name + "/" + file.short_path

def _shell_quote(value):
    return "'" + value.replace("'", "'\"'\"'") + "'"

def _cargo_audit_test_impl(ctx):
    audit_config = ctx.file.audit_config
    audit_config_path = _to_rlocation_path(ctx, audit_config) if audit_config else ""
    audit_args = " \\\n  " + " \\\n  ".join(
        [_shell_quote(arg) for arg in ctx.attr.audit_args] + ['"$@"'],
    )

    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        output = executable,
        is_executable = True,
        content = """#!/usr/bin/env bash
set -euo pipefail

runfiles_lib="bazel_tools/tools/bash/runfiles/runfiles.bash"
# shellcheck source=/dev/null
source "${{RUNFILES_DIR:-/dev/null}}/${{runfiles_lib}}" 2>/dev/null || \\
  source "$(grep -sm1 "^${{runfiles_lib}} " "${{RUNFILES_MANIFEST_FILE:-/dev/null}}" | cut -f2- -d' ')" 2>/dev/null || \\
  source "$0.runfiles/${{runfiles_lib}}" 2>/dev/null || \\
  source "$(grep -sm1 "^${{runfiles_lib}} " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || {{
    echo "ERROR: cannot find ${{runfiles_lib}}" >&2
    exit 1
  }}

runfiles_export_envvars

exec "$(rlocation {runner})" \\
  {cargo_audit} \\
  {cargo_lock} \\
  {advisory_db_marker} \\
  {audit_config} \\
  --{audit_args}
""".format(
            advisory_db_marker = _shell_quote(_to_rlocation_path(ctx, ctx.file.advisory_db_marker)),
            audit_args = audit_args,
            audit_config = _shell_quote(audit_config_path),
            cargo_audit = _shell_quote(_to_rlocation_path(ctx, ctx.executable.cargo_audit)),
            cargo_lock = _shell_quote(_to_rlocation_path(ctx, ctx.file.cargo_lock)),
            runner = _shell_quote(_to_rlocation_path(ctx, ctx.file._runner)),
        ),
    )

    runfiles = ctx.runfiles(
        files = [
            ctx.file._runner,
            ctx.executable.cargo_audit,
            ctx.file.cargo_lock,
            ctx.file.advisory_db_marker,
        ] + ctx.files.advisory_db + ctx.files.data + ([audit_config] if audit_config else []),
    )
    runfiles = runfiles.merge(ctx.attr._runfiles[DefaultInfo].default_runfiles)
    runfiles = runfiles.merge(ctx.attr.cargo_audit[DefaultInfo].default_runfiles)
    for target in ctx.attr.data:
        runfiles = runfiles.merge(target[DefaultInfo].default_runfiles)

    return [DefaultInfo(
        executable = executable,
        runfiles = runfiles,
    )]

_cargo_audit_test = rule(
    doc = "Runs cargo-audit against a Cargo.lock file using a pinned RustSec advisory DB.",
    implementation = _cargo_audit_test_impl,
    test = True,
    attrs = {
        "advisory_db": attr.label(
            doc = "Filegroup containing the pinned RustSec advisory DB.",
            allow_files = True,
        ),
        "advisory_db_marker": attr.label(
            doc = "File at the advisory DB root; README.md is provided by rustsec_advisory_db.",
            allow_single_file = True,
        ),
        "audit_args": attr.string_list(
            doc = "Additional arguments passed after `cargo-audit audit`.",
        ),
        "audit_config": attr.label(
            doc = "Optional .cargo/audit.toml file.",
            allow_single_file = True,
        ),
        "cargo_audit": attr.label(
            doc = "Executable cargo-audit target.",
            executable = True,
            cfg = "target",
        ),
        "cargo_lock": attr.label(
            doc = "Cargo.lock file to audit.",
            allow_single_file = True,
        ),
        "data": attr.label_list(
            doc = "Additional runtime data.",
            allow_files = True,
        ),
        "_runner": attr.label(
            allow_single_file = True,
            default = Label("@rules_monorepo//rules_monorepo_rust/private:cargo_audit_test.sh"),
        ),
        "_runfiles": attr.label(
            default = Label("@bazel_tools//tools/bash/runfiles"),
        ),
    },
)

def cargo_audit_test(
        name,
        cargo_lock = "//:Cargo.lock",
        cargo_audit = "@cargo_audit_tools//:audit",
        advisory_db = "@rustsec_advisory_db//:all",
        advisory_db_marker = "@rustsec_advisory_db//:README.md",
        **kwargs):
    """Defines a Bazel test that runs cargo-audit against a Cargo.lock file."""
    _cargo_audit_test(
        name = name,
        advisory_db = advisory_db,
        advisory_db_marker = advisory_db_marker,
        cargo_audit = cargo_audit,
        cargo_lock = cargo_lock,
        **kwargs
    )
