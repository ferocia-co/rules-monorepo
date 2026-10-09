#!/usr/bin/env python3
"""Discover Bazel tests, require explained exclusions, and route Docker tests."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET


ALL_TESTS = 'kind(".*_test rule", //...)'
DOCKER_TAGS = {"no-sandbox", "no-remote-exec"}


def load_exclusions(path: Path | None = None) -> dict[str, str]:
    if path is None:
        return {}
    policy = json.loads(path.read_text())
    if not isinstance(policy, dict):
        raise ValueError(f"{path.name}: expected target-to-reason entries")
    for label, reason in policy.items():
        match = re.fullmatch(r"//([A-Za-z0-9_./+\-]*):([A-Za-z0-9_./+\-]+)", label)
        if not match or set(match[1].split("/")) & {".", "..", "..."} or match[2] in {"all", "all-targets"}:
            raise ValueError(f"{path.name}: invalid test label {label!r}")
        if not isinstance(reason, str) or not reason.strip():
            raise ValueError(f"{label}: add a plain reason in {path.name}")
    return policy


def test_queries(exclusions: dict[str, str]) -> dict[str, str]:
    labels = " ".join(f'"{label}"' for label in sorted(exclusions))
    eligible = f"({ALL_TESTS} except set({labels}))"
    tag = r"(^|[ ,]|\[)requires-docker($|[ ,]|\])"
    docker = f'attr(tags, "{tag}", {eligible})'
    return {
        "ordinary": f"({eligible} except {docker})",
        "docker": docker,
    }


def parse_tests(xml: str) -> dict[str, set[str]]:
    return {
        rule.attrib["name"]: {
            tag.attrib["value"] for tag in rule.findall("list[@name='tags']/string")
        }
        for rule in ET.fromstring(xml).findall("rule")
    }


def validate(
    tests: dict[str, set[str]], exclusions: dict[str, str], exclusions_path: Path | None = None,
) -> None:
    policy = str(exclusions_path) if exclusions_path else "an exclusions file (--exclusions)"
    failures = [
        f"{label}: exclusion does not name a discovered test"
        for label in sorted(exclusions.keys() - tests.keys())
    ]
    for label, tags in sorted(tests.items()):
        if tags & {"live", "requires-credentials"} and label not in exclusions:
            failures.append(f"{label}: add a reason in {policy}")
        if label not in exclusions and "requires-docker" in tags and DOCKER_TAGS - tags:
            failures.append(f"{label}: Docker tests need {', '.join(sorted(DOCKER_TAGS - tags))}")
    if not tests:
        failures.append("no test targets discovered")
    if failures:
        raise ValueError("\n".join(failures))


def partition_tests(tests: dict[str, set[str]], exclusions: dict[str, str]) -> dict[str, list[str]]:
    return {
        group: sorted(
            label for label, tags in tests.items()
            if label not in exclusions and ("requires-docker" in tags) == docker
        )
        for group, docker in (("ordinary", False), ("docker", True))
    }


def bazel_command(bazel: str, workspace: Path) -> str:
    return str((workspace / bazel).resolve()) if "/" in bazel else bazel


def discover(
    workspace: Path, bazel: str, exclusions_path: Path | None = None,
) -> dict[str, list[str]]:
    exclusions = load_exclusions(exclusions_path)
    result = subprocess.run(
        [bazel_command(bazel, workspace), "query", "--noshow_progress", "--output=xml", ALL_TESTS],
        cwd=workspace, text=True, capture_output=True, timeout=600, check=True,
    )
    tests = parse_tests(result.stdout)
    validate(tests, exclusions, exclusions_path)
    return partition_tests(tests, exclusions)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("group", choices=("check", "ordinary", "docker"))
    parser.add_argument("--workspace", type=Path, default=os.environ.get("BUILD_WORKSPACE_DIRECTORY", "."))
    parser.add_argument("--bazel", default="bazelisk")
    parser.add_argument("--exclusions", type=Path)
    args, flags = parser.parse_known_args(argv)
    workspace = args.workspace.resolve()
    exclusions_path = workspace / args.exclusions if args.exclusions else None
    try:
        targets = discover(workspace, args.bazel, exclusions_path)
    except (OSError, ValueError, ET.ParseError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        if isinstance(error, subprocess.TimeoutExpired):
            message = "Bazel query timed out; check for another running Bazel command and retry"
        elif isinstance(error, subprocess.CalledProcessError):
            message = error.stderr.strip().splitlines()[-1] if error.stderr.strip() else "Bazel query failed"
        else:
            message = str(error)
        print(f"test discovery failed: {message}", file=sys.stderr)
        return 1
    if args.group == "check":
        print(f"test discovery passed: {len(targets['ordinary'])} ordinary, {len(targets['docker'])} Docker tests")
        return 0
    labels = targets[args.group]
    if not labels:
        print(f"no {args.group} tests to run")
        return 0
    if flags[:1] == ["--"]:
        flags = flags[1:]
    return subprocess.run([bazel_command(args.bazel, workspace), "test", *labels, *flags], cwd=workspace).returncode


if __name__ == "__main__":
    sys.exit(main())
