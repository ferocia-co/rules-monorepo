"""Repository rules for documentation tooling."""

_MDBOOK_VERSION = "0.5.3"

_MDBOOK_ARCHIVES = {
    "darwin_amd64": (
        "x86_64-apple-darwin",
        "9b74591168f8dbf19fcdf2386b68031fecc4b847b2e81e2de2d23ed502618875",
    ),
    "darwin_arm64": (
        "aarch64-apple-darwin",
        "2aaa197d85eb8c44903f0aa9f571612662e2d5314471697f3adb353e9e2a0007",
    ),
    "linux_amd64": (
        "x86_64-unknown-linux-gnu",
        "e2fd508a4fac06cbaa9f88b97d27bdc3b55a08946304ca845879fe26a3699e11",
    ),
    "linux_arm64": (
        "aarch64-unknown-linux-musl",
        "428c91cf73fec7494cbefe6e170e12508c9d45d9d096104b7c62d47ff43911c2",
    ),
}

def _host_platform(ctx):
    if ctx.os.name == "linux":
        arch = ctx.execute(["uname", "-m"]).stdout.strip()
        if arch == "aarch64":
            return "linux_arm64"
        return "linux_amd64"

    if ctx.os.name == "mac os x":
        arch = ctx.execute(["uname", "-m"]).stdout.strip()
        if arch == "arm64":
            return "darwin_arm64"
        return "darwin_amd64"

    fail("Platform {} is not supported".format(ctx.os.name))

def _download_mdbook_impl(ctx):
    platform = _host_platform(ctx)
    triple, sha256 = _MDBOOK_ARCHIVES[platform]
    url = "https://github.com/rust-lang/mdBook/releases/download/v{version}/mdbook-v{version}-{triple}.tar.gz".format(
        triple = triple,
        version = _MDBOOK_VERSION,
    )

    ctx.file("BUILD.bazel", """\
package(default_visibility = ["//visibility:public"])

genrule(
    name = "mdbook",
    srcs = ["bin/mdbook"],
    outs = ["mdbook_bin"],
    cmd = "cp $(location bin/mdbook) $@ && chmod +x $@",
    executable = True,
)
""")

    ctx.download_and_extract(
        url = url,
        output = "bin",
        sha256 = sha256,
    )

download_mdbook = repository_rule(
    doc = "Downloads a pinned mdBook v{} release binary for the host platform.".format(_MDBOOK_VERSION),
    implementation = _download_mdbook_impl,
)
