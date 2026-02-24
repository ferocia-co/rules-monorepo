"""Bzlmod extension helpers for host tooling used by rules_monorepo."""

load(":repositories.bzl", "download_kubectl", "download_kustomize")

def _resolve_k8s_tool_repos(module_ctx):
    include_kubectl = True
    include_kustomize = True

    # Prefer root-module configuration when available. Fall back to
    # iterating all tags for compatibility with older Bazel module objects.
    tags = []
    for mod in module_ctx.modules:
        if hasattr(mod, "is_root") and mod.is_root:
            tags.extend(mod.tags.k8s)
    if not tags:
        for mod in module_ctx.modules:
            tags.extend(mod.tags.k8s)

    # Default is backward-compatible: both repos enabled.
    # If configured, the last tag wins.
    for cfg in tags:
        include_kubectl = cfg.kubectl
        include_kustomize = cfg.kustomize

    return include_kubectl, include_kustomize

def _tools_impl(module_ctx):
    include_kubectl, include_kustomize = _resolve_k8s_tool_repos(module_ctx)

    if include_kubectl:
        download_kubectl(name = "kubectl_bin")
    if include_kustomize:
        download_kustomize(name = "kustomize_bin")

monorepo_tools = module_extension(
    implementation = _tools_impl,
    tag_classes = {
        "k8s": tag_class(
            attrs = {
                "kubectl": attr.bool(default = True),
                "kustomize": attr.bool(default = True),
            },
        ),
    },
)
