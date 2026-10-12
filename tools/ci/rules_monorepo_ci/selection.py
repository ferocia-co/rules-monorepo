#!/usr/bin/env python3
"""Select affected Bazel targets, falling back to the full gate on uncertainty."""

from __future__ import annotations

from pathlib import Path
import re
import subprocess
from typing import Callable

from rules_monorepo_ci.test_discovery import test_queries


LABEL_PART = re.compile(r"^[A-Za-z0-9_./+\-]+$")
RESULT_LABEL = re.compile(r"^//[^\s:]*:[^\s:]+$")
GROUPS = ("ordinary_tests", "docker_tests", "clippy_targets", "oci_tarballs")


def selection_roots(config: dict, exclusions: dict[str, str]) -> dict[str, tuple[str, str]]:
    tests = test_queries(exclusions)
    roots = {key: (tests[group], tests[group]) for key, group in (("ordinary_tests", "ordinary"), ("docker_tests", "docker"))}
    if root := config.get("clippy_root"):
        roots["clippy_targets"] = (root, f"labels(deps, {root})")
    if root := config.get("oci_root"):
        roots["oci_tarballs"] = (root, f"labels(srcs, {root})")
    return roots


def full_result(reason: str) -> dict[str, object]:
    return {
        "full": True,
        "docs_only": False,
        "reason": reason,
        **{key: [] for key in GROUPS},
        "oci_images": [],
        "rust_files": [],
        "rustfmt_packages": [],
    }


def _requires_full(path: str, full_check_paths: list[str]) -> bool:
    parts = Path(path).parts
    name = parts[-1]
    return (
        name in {
            "BUILD", "BUILD.bazel", "MODULE.bazel", "MODULE.bazel.lock",
            "WORKSPACE", "WORKSPACE.bazel", "Cargo.toml", "Cargo.lock",
            "pnpm-lock.yaml", "pnpm-workspace.yaml", "package.json",
            "Justfile", "justfile", ".bazelrc", ".bazelversion",
            ".npmrc", ".nvmrc", "rust-toolchain", "rust-toolchain.toml",
            "Dockerfile", "Containerfile", ".dockerignore",
            ".bazelignore", ".bazeliskrc", "rustfmt.toml",
            ".rustfmt.toml", "clippy.toml", ".clippy.toml",
        }
        or name.startswith(".bazelrc")
        or name.endswith((".lock", ".lockb"))
        or name.endswith((".bzl", ".bazel"))
        or parts[:1] in {(".github",), (".cargo",), (".flox",)}
        or any(path == prefix.rstrip("/") or path.startswith(prefix.rstrip("/") + "/") for prefix in full_check_paths)
    )


def _source_label(repo_root: Path, relative: str) -> tuple[str, str]:
    path = Path(relative)
    if path.is_absolute() or not path.parts or any(part in {".", ".."} for part in path.parts):
        raise ValueError("invalid changed path")
    if any(not LABEL_PART.fullmatch(part) for part in path.parts):
        raise ValueError("changed path cannot be represented safely in a Bazel query")

    file_path = repo_root / path
    if not file_path.is_file() or not file_path.resolve().is_relative_to(repo_root.resolve()):
        raise ValueError("changed path is missing or outside the workspace")

    package_dir = file_path.parent
    while package_dir.is_relative_to(repo_root):
        if (package_dir / "BUILD.bazel").is_file() or (package_dir / "BUILD").is_file():
            package = package_dir.relative_to(repo_root).as_posix()
            package_prefix = "//" + package if package != "." else "//"
            source_name = file_path.relative_to(package_dir).as_posix()
            return f"{package_prefix}:{source_name}", f"{package_prefix}:all"
        if package_dir == repo_root:
            break
        package_dir = package_dir.parent
    raise ValueError("changed path has no Bazel package")


def _query_expression(root: str, selected: str, source_labels: list[str]) -> str:
    changed = "set(" + " ".join(source_labels) + ")"
    return f"rdeps(deps({root}), {changed}) intersect {selected}"


def _source_coverage_expression(source_labels: list[str], roots: dict, always_checked_roots: list[str]) -> str:
    changed = "set(" + " ".join(source_labels) + ")"
    roots = " union ".join(
        f"deps({root})" for root in [*(root for root, _ in roots.values()), *always_checked_roots]
    )
    return f"{changed} intersect ({roots})"


def _oci_images(tarballs: list[str]) -> list[str]:
    images = []
    for label in tarballs:
        if not label.endswith("_tarball"):
            raise ValueError("selected OCI target is not a tarball")
        images.append(label[: -len("_tarball")] + "_image")
    return images


def _run_query(bazel: Path, repo_root: Path, expression: str) -> list[str]:
    completed = subprocess.run(
        [str(bazel), "query", "--noshow_progress", "--output=label", expression],
        cwd=repo_root,
        text=True,
        capture_output=True,
        timeout=60,
        check=True,
    )
    labels = completed.stdout.splitlines()
    if any(not RESULT_LABEL.fullmatch(label) for label in labels):
        raise ValueError("Bazel query returned an unexpected label")
    return sorted(set(labels))


def select_targets(
    repo_root: Path,
    changed_files: list[str],
    *,
    roots: dict[str, tuple[str, str]],
    always_checked_roots: list[str] = (),
    full_check_paths: list[str] = (),
    deleted_or_renamed: bool = False,
    query: Callable[[str], list[str]],
) -> dict[str, object]:
    if deleted_or_renamed:
        return full_result("deleted or renamed path")
    if not changed_files:
        return full_result("no changed paths supplied")

    source_labels: set[str] = set()
    optional_source_labels: dict[str, str] = {}
    rust_files: set[str] = set()
    rustfmt_packages: set[str] = set()
    for relative in changed_files:
        if not relative or _requires_full(relative, full_check_paths):
            return full_result("build, dependency, workflow, or CI tooling changed")
        try:
            label, package = _source_label(repo_root, relative)
        except (OSError, ValueError):
            return full_result("changed path cannot be resolved to a Bazel source")
        # Bazel does not create file targets for documentation or example env
        # files unless a rule declares them. Undeclared files cannot change a
        # Bazel action, while declared ones need the normal dependency query.
        if relative.endswith(".md") or Path(relative).name == ".env.example":
            optional_source_labels[label] = package
            continue
        source_labels.add(label)
        if relative.endswith(".rs"):
            rust_files.add(relative)
            rustfmt_packages.add(package)

    try:
        if optional_source_labels:
            packages = sorted({
                package[:-3] + "all-targets"
                for package in optional_source_labels.values()
            })
            declared = set(query("kind('source file', " + " + ".join(packages) + ")"))
            source_labels.update(optional_source_labels.keys() & declared)
    except (OSError, ValueError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return full_result("Bazel query failed")

    results: dict[str, object] = {
        "full": False,
        "docs_only": not source_labels,
        "reason": "",
        **{key: [] for key in GROUPS},
        "rust_files": sorted(rust_files),
        "rustfmt_packages": sorted(rustfmt_packages),
    }
    if not source_labels:
        return {
            **results,
            **{key: [] for key in GROUPS},
            "oci_images": [],
        }
    labels = sorted(source_labels)
    try:
        for key, (root, selected) in roots.items():
            results[key] = query(_query_expression(root, selected, labels))
        results["oci_images"] = _oci_images(results["oci_tarballs"])
        covered = set(query(_source_coverage_expression(labels, roots, always_checked_roots)))
        if covered != source_labels:
            return full_result("changed source is outside the selected CI graph")
    except (OSError, ValueError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return full_result("Bazel query failed")

    return results
