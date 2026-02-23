"""Kubernetes deployment rules and macros for rules_monorepo."""

def _json_escape(value):
    return value.replace("\\", "\\\\").replace("\"", "\\\"")

def _json_string(value):
    return "\"" + _json_escape(value) + "\""

def _json_list(values):
    return "[" + ", ".join([_json_string(v) for v in values]) + "]"

def _json_dict(values):
    items = []
    for k in sorted(values.keys()):
        items.append(_json_string(k) + ": " + _json_string(values[k]))
    return "{ " + ", ".join(items) + " }"

def _runfile_path(ctx, file):
    workspace = ctx.workspace_name or "_main"
    return "{}/{}".format(workspace, file.short_path)

def _shell_quote(value):
    return "'" + value.replace("'", "'\"'\"'") + "'"

def _yaml_quote(value):
    escaped = value.replace("\\", "\\\\").replace("\"", "\\\"")
    return "\"{}\"".format(escaped)

def _pad3(i):
    s = str(i)
    if i < 10:
        return "00" + s
    if i < 100:
        return "0" + s
    return s

def _kustomize_manifest_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".yaml")

    manifest_files = sorted(ctx.files.manifests, key = lambda f: f.path)
    if len(manifest_files) == 0:
        ctx.actions.write(out, "")
        return [DefaultInfo(files = depset([out]))]

    kustomize_bin = ctx.executable.kustomize

    yaml_lines = [
        "apiVersion: kustomize.config.k8s.io/v1beta1",
        "kind: Kustomization",
        "resources:",
    ]

    for i in range(len(manifest_files)):
        yaml_lines.append("- manifest_{}.yaml".format(_pad3(i)))

    if ctx.attr.namespace:
        yaml_lines.append("namespace: {}".format(_yaml_quote(ctx.attr.namespace)))

    if ctx.attr.common_annotations:
        yaml_lines.append("commonAnnotations:")
        for key in sorted(ctx.attr.common_annotations.keys()):
            yaml_lines.append("  {}: {}".format(key, _yaml_quote(ctx.attr.common_annotations[key])))

    cmd_lines = [
        "set -euo pipefail",
        "tmp=\"$(mktemp -d)\"",
        "trap 'rm -rf \"$tmp\"' EXIT",
        "cat > \"$tmp/kustomization.yaml\" <<'EOF_KUSTOMIZATION'",
    ]
    cmd_lines.extend(yaml_lines)
    cmd_lines.append("EOF_KUSTOMIZATION")

    for i, f in enumerate(manifest_files):
        cmd_lines.append(
            "cp {} \"$tmp/manifest_{}.yaml\"".format(
                _shell_quote(f.path),
                _pad3(i),
            ),
        )

    cmd_lines.append(
        "{} build \"$tmp\" > {}".format(
            _shell_quote(kustomize_bin.path),
            _shell_quote(out.path),
        ),
    )

    ctx.actions.run_shell(
        inputs = manifest_files,
        tools = [kustomize_bin],
        outputs = [out],
        command = "\n".join(cmd_lines),
        mnemonic = "MonorepoKustomize",
        progress_message = "Rendering kustomize manifest {}".format(ctx.label),
    )

    return [DefaultInfo(files = depset([out]))]

kustomize_manifest = rule(
    implementation = _kustomize_manifest_impl,
    attrs = {
        "manifests": attr.label_list(allow_files = True, default = []),
        "namespace": attr.string(mandatory = True),
        "common_annotations": attr.string_dict(default = {}),
        "kustomize": attr.label(
            default = Label("@kustomize_bin//:kustomize"),
            executable = True,
            cfg = "exec",
        ),
    },
)

def _k8s_apply_impl(ctx):
    config_file = ctx.actions.declare_file(ctx.label.name + ".config.json")

    manifest_file = ctx.file.manifest
    info_file = ctx.info_file
    kubectl_files = ctx.attr.kubectl[DefaultInfo].files.to_list()
    if len(kubectl_files) != 1:
        fail("kubectl must provide exactly one file")
    kubectl_file = kubectl_files[0]

    pushes = []
    for push in ctx.attr.pushes:
        pushes.append(_runfile_path(ctx, push[DefaultInfo].files_to_run.executable))

    rollout_selector = "null"
    if ctx.attr.rollout_selector:
        rollout_selector = _json_string(ctx.attr.rollout_selector)

    config_json = """{{
  "manifest": {manifest},
  "namespace": {namespace},
  "cluster": {cluster},
  "user": {user},
  "kubeconfig": {kubeconfig},
  "kubectl": {kubectl},
  "pushes": {pushes},
  "rollout_selector": {rollout_selector},
  "rollout_kinds": {rollout_kinds},
  "rollout_timeout": {rollout_timeout},
  "stable_status": {stable_status},
  "validate": {validate},
  "action": {action},
  "extra_vars": {extra_vars}
}}
""".format(
        manifest = _json_string(_runfile_path(ctx, manifest_file)),
        namespace = _json_string(ctx.attr.namespace),
        cluster = _json_string(ctx.attr.cluster),
        user = _json_string(ctx.attr.user),
        kubeconfig = _json_string(ctx.attr.kubeconfig),
        kubectl = _json_string(_runfile_path(ctx, kubectl_file)),
        pushes = _json_list(pushes),
        rollout_selector = rollout_selector,
        rollout_kinds = _json_list(ctx.attr.rollout_kinds),
        rollout_timeout = _json_string(ctx.attr.rollout_timeout),
        stable_status = _json_string(_runfile_path(ctx, info_file)),
        validate = "true" if ctx.attr.validate else "false",
        action = _json_string(ctx.attr.action),
        extra_vars = _json_dict(ctx.attr.extra_vars),
    )

    ctx.actions.write(config_file, config_json)

    output = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(output = output, target_file = ctx.executable._helper)

    runfiles = ctx.runfiles(files = [
        config_file,
        manifest_file,
        info_file,
        kubectl_file,
        ctx.executable._helper,
    ])
    for push in ctx.attr.pushes:
        runfiles = runfiles.merge(push[DefaultInfo].default_runfiles)
    runfiles = runfiles.merge(ctx.attr.kubectl[DefaultInfo].default_runfiles)

    env = {
        "K8S_DEPLOY_CONFIG": _runfile_path(ctx, config_file),
    }

    return [
        DefaultInfo(executable = output, runfiles = runfiles),
        RunEnvironmentInfo(environment = env),
    ]

k8s_apply = rule(
    implementation = _k8s_apply_impl,
    attrs = {
        "manifest": attr.label(mandatory = True, allow_single_file = True),
        "pushes": attr.label_list(default = []),
        "namespace": attr.string(mandatory = True),
        "cluster": attr.string(default = ""),
        "user": attr.string(default = ""),
        "kubeconfig": attr.string(default = ""),
        "rollout_selector": attr.string(),
        "rollout_kinds": attr.string_list(default = ["deployment", "statefulset", "daemonset"]),
        "rollout_timeout": attr.string(default = "5m"),
        "validate": attr.bool(default = True),
        "action": attr.string(default = "apply"),
        "extra_vars": attr.string_dict(default = {}),
        "kubectl": attr.label(
            default = Label("@kubectl_bin//:kubectl"),
            allow_files = True,
            cfg = "exec",
        ),
        "_helper": attr.label(
            default = Label("//rules_monorepo:k8s_apply_helper"),
            executable = True,
            cfg = "exec",
        ),
    },
    executable = True,
)

def k8s_oci_deploy(
        name,
        namespace,
        manifests,
        images = None,
        cluster = "",
        user = "",
        kubeconfig = "",
        common_annotations = None,
        rollout_selector = None,
        rollout_kinds = None,
        rollout_timeout = "5m",
        validate = True,
        extra_vars = None):
    """Render manifests via kustomize and create apply/delete executable targets."""

    images = images or []
    rollout_kinds = rollout_kinds or ["deployment", "statefulset", "daemonset"]
    extra_vars = extra_vars or {}

    kustomize_manifest(
        name = name,
        namespace = namespace,
        manifests = manifests,
        common_annotations = common_annotations or {},
    )

    k8s_apply(
        name = name + ".apply",
        manifest = ":" + name,
        pushes = [image["push"] for image in images],
        namespace = namespace,
        cluster = cluster,
        user = user,
        kubeconfig = kubeconfig,
        rollout_selector = rollout_selector,
        rollout_kinds = rollout_kinds,
        rollout_timeout = rollout_timeout,
        validate = validate,
        extra_vars = extra_vars,
    )

    k8s_apply(
        name = name + ".delete",
        manifest = ":" + name,
        namespace = namespace,
        cluster = cluster,
        user = user,
        kubeconfig = kubeconfig,
        action = "delete",
        validate = False,
        extra_vars = extra_vars,
    )
