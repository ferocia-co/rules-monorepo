"""Discover, select, and execute a consumer's Bazel CI targets."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

from rules_monorepo_ci import selection, test_discovery


def changed_paths(workspace: Path) -> tuple[list[str], bool]:
    def git(*args: str) -> bytes:
        return subprocess.check_output(["git", *args], cwd=workspace, stderr=subprocess.PIPE)

    try:
        if git("rev-parse", "HEAD").decode().strip() != os.environ.get("GITHUB_SHA"):
            return [], False
        git("cat-file", "-e", "HEAD^2^{commit}")
        paths = git("diff", "--name-only", "-z", "--no-renames", "HEAD^1", "HEAD")
        if paths and not paths.endswith(b"\0"):
            return [], False
        deleted = git("diff", "--name-only", "-z", "--no-renames", "--diff-filter=D", "HEAD^1", "HEAD")
        return [os.fsdecode(path) for path in paths.split(b"\0") if path], bool(deleted)
    except (OSError, subprocess.CalledProcessError):
        return [], False


class Runner:
    def __init__(self, workspace: Path, bazel: str, config: dict):
        self.workspace = workspace
        self.bazel = test_discovery.bazel_command(bazel, workspace)
        self.config = config
        self.exclusions = workspace / config["exclusions"] if config["exclusions"] else None

    def run(self, *args: str) -> None:
        subprocess.run([self.bazel, *args], cwd=self.workspace, check=True,
            env={**os.environ, "BAZEL_REAL": self.bazel})

    def discover(self) -> dict[str, list[str]]:
        return test_discovery.discover(self.workspace, self.bazel, self.exclusions)

    def select(self, paths: list[str], deleted: bool = False) -> dict:
        roots = selection.selection_roots(self.config, test_discovery.load_exclusions(self.exclusions))
        return selection.select_targets(self.workspace, paths, roots=roots,
            always_checked_roots=self.config["always_test_targets"],
            full_check_paths=self.config["full_check_paths"], deleted_or_renamed=deleted,
            query=lambda expression: selection._run_query(Path(self.bazel), self.workspace, expression))

    def plan(self, paths: list[str], deleted: bool = False) -> None:
        self.discover()
        result = self.select(paths, deleted)
        encoded = json.dumps(result, sort_keys=True)
        for variable, entry in (
            ("GITHUB_OUTPUT", f"docs_only={str(result['docs_only']).lower()}\n"),
            ("GITHUB_ENV", f"PLAN_JSON={encoded}\n"),
        ):
            if path := os.environ.get(variable):
                with Path(path).open("a") as output:
                    output.write(entry)
        print(encoded)

    def checks(self, plan: dict, flags: list[str]) -> None:
        tests = self.discover()
        if targets := self.config["lockfile_targets"]:
            self.run("build", *targets, "--nobuild", "--lockfile_mode=error")
        for target in self.config["check_targets"]:
            self.run("run", target)
        if plan["full"]:
            self.run("test", *tests["ordinary"], *self.config["build_targets"],
                *self.config["always_test_targets"], *self.config["test_args"],
                *self.config["full_check_args"], *flags)
            return
        if self.config["clippy_root"] and (packages := plan["rustfmt_packages"]):
            self.run("run", "@rules_rust//tools/rustfmt:target_aware_rustfmt", "--", *packages, "--", "--check")
        if targets := plan["clippy_targets"]:
            self.run("build", *targets, "--aspects=@rules_rust//rust:defs.bzl%rust_clippy_aspect",
                "--output_groups=clippy_checks", *self.config["test_args"], *flags)
        if targets := [*self.config["always_test_targets"], *plan["ordinary_tests"]]:
            self.run("test", *targets, *self.config["test_args"], *flags)

    def components(self, plan: dict, flags: list[str]) -> None:
        tests = self.discover()["docker"] if plan["full"] else plan["docker_tests"]
        if not tests:
            print("No Docker tests selected.")
            return
        runtime = subprocess.check_output(
            ["docker", "info", "--format", "{{.ServerVersion}}/{{.OSType}}/{{.Architecture}}"],
            cwd=self.workspace, text=True).strip()
        self.run("test", *tests, *self.config["test_args"],
            f"--local_test_jobs={self.config['docker_jobs']}", "--test_output=errors",
            f"--test_env=COMPONENT_TEST_DOCKER_RUNTIME={runtime}", *flags)

    def images(self, plan: dict, flags: list[str]) -> None:
        if not self.config["oci_root"] or (not plan["full"] and not plan["oci_images"]):
            print("No OCI images selected.")
            return
        targets = ["--all"] if plan["full"] else [arg for image in plan["oci_images"] for arg in ("--image", image)]
        self.run("run", "--compilation_mode=opt", "@rules_monorepo//tools/oci:oci", "--",
            "build", "--bazel", self.bazel, *targets, "--scope", self.config["oci_scope"],
            "--bazel-jobs", os.environ.get("OCI_BAZEL_CONCURRENCY", str(self.config["oci_jobs"])), *flags)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--workspace", type=Path, default=os.environ.get("BUILD_WORKSPACE_DIRECTORY", "."))
    parser.add_argument("--bazel", default="bazelisk")
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--changed-file", action="append", default=[])
    parser.add_argument("--changed-files0", type=Path)
    parser.add_argument("--deleted-or-renamed", action="store_true")
    parser.add_argument("stage", choices=("plan", "checks", "components", "images"))
    argv = list(sys.argv[1:] if argv is None else argv)
    separator = argv.index("--") if "--" in argv else len(argv)
    flags = argv[separator + 1:]
    args = parser.parse_args(argv[:separator])
    try:
        runner = Runner(args.workspace.resolve(), args.bazel, json.loads(args.config.read_text()))
        if args.stage == "plan":
            paths, deleted = (args.changed_file, args.deleted_or_renamed) if args.changed_file or args.changed_files0 else changed_paths(runner.workspace)
            if args.changed_files0:
                try:
                    data = args.changed_files0.read_bytes()
                    if data and not data.endswith(b"\0"):
                        raise ValueError("changed-files0 must end in NUL")
                    paths = [*paths, *(os.fsdecode(path) for path in data.split(b"\0") if path)]
                except (OSError, ValueError):
                    paths = []
            runner.plan(paths, deleted)
        else:
            plan = json.loads(os.environ["PLAN_JSON"]) if "PLAN_JSON" in os.environ and not args.full else selection.full_result("full gate requested")
            if not plan["docs_only"]:
                {"checks": runner.checks, "components": runner.components, "images": runner.images}[args.stage](plan, flags)
    except subprocess.CalledProcessError as error:
        if error.stderr:
            print(error.stderr.strip().splitlines()[-1], file=sys.stderr)
        return error.returncode
    except subprocess.TimeoutExpired:
        print("CI failed: Bazel query timed out; wait for other Bazel commands and retry", file=sys.stderr)
        return 1
    except (OSError, ValueError, KeyError, TypeError, ET.ParseError) as error:
        print(f"CI failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
