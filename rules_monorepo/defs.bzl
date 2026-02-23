"""Public API for rules_monorepo."""

load(":k8s/defs.bzl", _k8s_apply = "k8s_apply", _k8s_oci_deploy = "k8s_oci_deploy")
load(":oci/defs.bzl", _binary_oci_image = "binary_oci_image")

binary_oci_image = _binary_oci_image
k8s_apply = _k8s_apply
k8s_oci_deploy = _k8s_oci_deploy

monorepo_binary_oci_image = _binary_oci_image
monorepo_k8s_apply = _k8s_apply
monorepo_k8s_oci_deploy = _k8s_oci_deploy
