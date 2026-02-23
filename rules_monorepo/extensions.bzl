"""Bzlmod extension helpers for host tooling used by rules_monorepo."""

load(":repositories.bzl", "download_kubectl", "download_kustomize")

def _tools_impl(module_ctx):
    _ = module_ctx

    download_kubectl(name = "kubectl_bin")
    download_kustomize(name = "kustomize_bin")

monorepo_tools = module_extension(
    implementation = _tools_impl,
)
