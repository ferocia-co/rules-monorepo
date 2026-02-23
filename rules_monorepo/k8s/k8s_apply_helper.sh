#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


def runfiles_locations():
    runfiles_dir = os.getenv("RUNFILES_DIR")
    runfiles_manifest = os.getenv("RUNFILES_MANIFEST_FILE")

    if runfiles_dir or runfiles_manifest:
        return (
            Path(runfiles_dir) if runfiles_dir else None,
            Path(runfiles_manifest) if runfiles_manifest else None,
        )

    argv0 = sys.argv[0] if sys.argv else ""
    if argv0:
        runfiles_dir_candidate = Path(f"{argv0}.runfiles")
        if runfiles_dir_candidate.exists():
            return runfiles_dir_candidate, None

        runfiles_manifest_candidate = Path(f"{argv0}.runfiles_manifest")
        if runfiles_manifest_candidate.exists():
            return None, runfiles_manifest_candidate

    return None, None


def resolve_runfile(path: str) -> Path:
    runfiles_dir, runfiles_manifest = runfiles_locations()

    if runfiles_dir is not None:
        candidate = runfiles_dir / path
        if candidate.exists():
            return candidate

    if runfiles_manifest is not None:
        with runfiles_manifest.open("r", encoding="utf-8") as handle:
            for line in handle:
                line = line.rstrip("\n")
                key, sep, value = line.partition(" ")
                if sep and key == path:
                    return Path(value)

    raise RuntimeError(f"runfile not found: {path}")


def load_stable_status(path: Path):
    status = {}
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            key, sep, value = line.partition(" ")
            if sep:
                status[key] = value
    return status


def run_cmd(cmd):
    process = subprocess.run(cmd)
    if process.returncode != 0:
        raise RuntimeError(f"command failed ({process.returncode}): {' '.join(cmd)}")


def has_manifest_objects(contents: str) -> bool:
    for raw_line in contents.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or line == "---":
            continue
        return True
    return False


def main() -> int:
    config_runfile = os.getenv("K8S_DEPLOY_CONFIG")
    if not config_runfile:
        raise RuntimeError("K8S_DEPLOY_CONFIG is not set")

    config_path = resolve_runfile(config_runfile)
    with config_path.open("r", encoding="utf-8") as handle:
        config = json.load(handle)

    action = config.get("action", "apply")
    if action not in ("apply", "delete"):
        raise RuntimeError(f"unsupported action: {action}")

    vars_map = dict(config.get("extra_vars", {}))
    vars_map["NAMESPACE"] = config["namespace"]

    git_commit_short = os.getenv("GIT_COMMIT_SHORT")
    if not git_commit_short:
        stable_status = config.get("stable_status")
        if stable_status:
            stable_status_path = resolve_runfile(stable_status)
            status = load_stable_status(stable_status_path)
            git_commit_short = status.get("STABLE_GIT_COMMIT_SHORT")

    if git_commit_short:
        vars_map["GIT_COMMIT_SHORT"] = git_commit_short
    else:
        if action == "apply":
            raise RuntimeError("GIT_COMMIT_SHORT is not available")
        git_commit_short = "unknown"
        vars_map["GIT_COMMIT_SHORT"] = git_commit_short

    kubectl = "kubectl"
    if config.get("kubectl"):
        kubectl = str(resolve_runfile(config["kubectl"]))

    cluster = (config.get("cluster") or "").strip()
    user = (config.get("user") or "").strip()

    kubeconfig = (config.get("kubeconfig") or "").strip()
    if not kubeconfig:
        kubeconfig = (os.getenv("KUBECONFIG") or "").strip()

    for push in config.get("pushes", []):
        push_path = str(resolve_runfile(push))
        run_cmd([push_path, "--tag", vars_map["GIT_COMMIT_SHORT"]])

    manifest_path = resolve_runfile(config["manifest"])
    manifest_contents = manifest_path.read_text(encoding="utf-8")

    rendered = manifest_contents
    for key, value in vars_map.items():
        rendered = rendered.replace("{{" + key + "}}", str(value))

    if not has_manifest_objects(rendered):
        print(
            f"No Kubernetes resources found in rendered manifest; skipping {action} for namespace {config['namespace']}.",
        )
        return 0

    rendered_path = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", delete=False, encoding="utf-8") as tmp:
            tmp.write(rendered)
            rendered_path = tmp.name

        common = [kubectl]
        if kubeconfig:
            common.extend(["--kubeconfig", kubeconfig])
        if cluster:
            common.extend(["--cluster", cluster])
        if user:
            common.extend(["--user", user])
        common.extend(["--namespace", config["namespace"]])

        if action == "delete":
            run_cmd(common + ["delete", "--ignore-not-found", "-f", rendered_path])
            return 0

        if config.get("validate", True):
            run_cmd(common + ["apply", "--dry-run=server", "-f", rendered_path])

        run_cmd(common + ["apply", "-f", rendered_path])

        rollout_selector = config.get("rollout_selector")
        if rollout_selector:
            rollout_timeout = config.get("rollout_timeout", "5m")
            for kind in config.get("rollout_kinds", []):
                run_cmd(
                    common
                    + [
                        "rollout",
                        "status",
                        kind,
                        "-l",
                        rollout_selector,
                        "--timeout",
                        rollout_timeout,
                    ],
                )
    finally:
        if rendered_path and os.path.exists(rendered_path):
            os.unlink(rendered_path)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pylint: disable=broad-except
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
PY
