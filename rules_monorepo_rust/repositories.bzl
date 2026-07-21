"""Repository rules for Rust security audit support."""

_CARGO_AUDIT_RELEASE_URLS = [
    "https://github.com/rustsec/rustsec/releases/download/cargo-audit/v{version}/cargo-audit-{target}-v{version}.tgz",
]

def _cargo_audit_binary_impl(ctx):
    substitutions = {
        "target": ctx.attr.target,
        "version": ctx.attr.version,
    }
    ctx.download_and_extract(
        url = [url.format(**substitutions) for url in ctx.attr.urls],
        sha256 = ctx.attr.sha256,
        stripPrefix = "cargo-audit-{target}-v{version}".format(**substitutions),
    )
    ctx.file("WORKSPACE.bazel", """workspace(name = \"{}\")""".format(ctx.name))
    ctx.file("BUILD.bazel", """\
package(default_visibility = ["//visibility:public"])

exports_files(["cargo-audit"])
""")

cargo_audit_binary = repository_rule(
    doc = "Downloads one official checksum-pinned cargo-audit release binary.",
    implementation = _cargo_audit_binary_impl,
    attrs = {
        "sha256": attr.string(mandatory = True),
        "target": attr.string(mandatory = True),
        "urls": attr.string_list(default = _CARGO_AUDIT_RELEASE_URLS),
        "version": attr.string(default = "0.22.1"),
    },
)

_DEFAULT_ADVISORY_DB_URLS = [
    "https://github.com/RustSec/advisory-db/archive/{commit}.tar.gz",
]

def _rustsec_advisory_db_impl(ctx):
    strip_prefix = ctx.attr.strip_prefix
    if not strip_prefix:
        strip_prefix = "advisory-db-{}".format(ctx.attr.commit)

    ctx.download_and_extract(
        url = [url.format(commit = ctx.attr.commit) for url in ctx.attr.urls],
        sha256 = ctx.attr.sha256,
        stripPrefix = strip_prefix,
    )

    ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(ctx.name))
    ctx.file("BUILD.bazel", """\
package(default_visibility = ["//visibility:public"])

exports_files(["README.md"])

filegroup(
    name = "all",
    srcs = glob(["**"]),
)
""")

rustsec_advisory_db = repository_rule(
    doc = "Downloads a pinned RustSec advisory-db archive for hermetic cargo audit tests.",
    implementation = _rustsec_advisory_db_impl,
    attrs = {
        "commit": attr.string(
            doc = "RustSec/advisory-db commit SHA to download.",
            mandatory = True,
        ),
        "sha256": attr.string(
            doc = "SHA-256 of the downloaded archive.",
            mandatory = True,
        ),
        "strip_prefix": attr.string(
            doc = "Archive strip prefix. Defaults to advisory-db-{commit}.",
        ),
        "urls": attr.string_list(
            doc = "Archive URLs. Each URL may contain a {commit} placeholder.",
            default = _DEFAULT_ADVISORY_DB_URLS,
        ),
    },
)
