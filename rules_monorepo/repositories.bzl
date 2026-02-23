"""Repository rules for kubectl and kustomize host binaries."""

_KUBECTL_BINARIES = {
    "darwin_amd64": (
        "https://dl.k8s.io/release/v1.30.8/bin/darwin/amd64/kubectl",
        "46682e24c3aecfbe92f53b86fb15beb740c43a0fafe0a4e06a1c8bb3ce9e985b",
    ),
    "darwin_arm64": (
        "https://dl.k8s.io/release/v1.30.8/bin/darwin/arm64/kubectl",
        "52b11bb032f88e4718cd4e3c8374a6b1fad29772aa1ce701276cc4e17d37642f",
    ),
    "linux_amd64": (
        "https://dl.k8s.io/release/v1.30.8/bin/linux/amd64/kubectl",
        "7f39bdcf768ce4b8c1428894c70c49c8b4d2eee52f3606eb02f5f7d10f66d692",
    ),
    "linux_arm64": (
        "https://dl.k8s.io/release/v1.30.8/bin/linux/arm64/kubectl",
        "e51d6a76fade0871a9143b64dc62a5ff44f369aa6cb4b04967d93798bf39d15b",
    ),
}

_KUSTOMIZE_BINARIES = {
    "darwin_amd64": (
        "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.5.3/kustomize_v4.5.3_darwin_amd64.tar.gz",
        "b0a6b0568273d466abd7cd535c556e44aa9ff5f54c07e86ed9f3016b416de992",
    ),
    "darwin_arm64": (
        "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.5.3/kustomize_v4.5.3_darwin_arm64.tar.gz",
        "2fb58138c319d404e1604ae6665356e211b2ea45f17f174df1322de0100a55c4",
    ),
    "linux_amd64": (
        "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.5.3/kustomize_v4.5.3_linux_amd64.tar.gz",
        "e4dc2f795235b03a2e6b12c3863c44abe81338c5c0054b29baf27dcc734ae693",
    ),
    "linux_arm64": (
        "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.5.3/kustomize_v4.5.3_linux_arm64.tar.gz",
        "97cf7d53214388b1ff2177a56404445f02d8afacb9421339c878c5ac2c8bc2c8",
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

def _download_kubectl_impl(ctx):
    platform = _host_platform(ctx)

    ctx.file("BUILD", """
filegroup(
    name = "kubectl",
    srcs = ["bin/kubectl"],
    visibility = ["//visibility:public"],
)
""")

    url, sha256 = _KUBECTL_BINARIES[platform]
    ctx.download(
        url,
        output = "bin/kubectl",
        executable = True,
        sha256 = sha256,
    )


def _download_kustomize_impl(ctx):
    platform = _host_platform(ctx)

    ctx.file("BUILD", """
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

sh_binary(
    name = "kustomize",
    srcs = ["bin/kustomize"],
    visibility = ["//visibility:public"],
)
""")

    url, sha256 = _KUSTOMIZE_BINARIES[platform]
    ctx.download_and_extract(url, "bin/", sha256 = sha256)


download_kubectl = repository_rule(_download_kubectl_impl)
download_kustomize = repository_rule(_download_kustomize_impl)
