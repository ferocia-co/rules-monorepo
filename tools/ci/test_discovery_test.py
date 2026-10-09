"""Guard automatic inclusion, environment routing, and explicit exclusions."""

from __future__ import annotations

from contextlib import redirect_stderr, redirect_stdout
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from rules_monorepo_ci import test_discovery as discovery


def rules_xml(tests: dict[str, set[str]]) -> str:
    return "<query>" + "".join(
        f'<rule name="{label}" class="rust_test"><list name="tags">'
        + "".join(f'<string value="{tag}"/>' for tag in sorted(tags))
        + "</list></rule>"
        for label, tags in tests.items()
    ) + "</query>"


class TestDiscoveryTest(unittest.TestCase):
    def test_new_tests_and_manual_tests_are_run_in_their_environment(self) -> None:
        tests = {
            "//new/package:fresh_test": set(),
            "//new/package:manual_test": {"manual"},
            "//new/package:docker_test": {"manual", "requires-docker", *discovery.DOCKER_TAGS},
            "//new/package:live_test": {"manual", "live"},
        }
        with patch.object(discovery, "load_exclusions", return_value={"//new/package:live_test": "Uses production."}), patch.object(
            discovery.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, stdout=rules_xml(tests))
        ) as run:
            result = discovery.discover(Path("/workspace"), "/bazel")
        self.assertEqual(result["ordinary"], ["//new/package:fresh_test", "//new/package:manual_test"])
        self.assertEqual(result["docker"], ["//new/package:docker_test"])
        self.assertEqual(run.call_args.args[0][-1], discovery.ALL_TESTS)
        self.assertEqual(run.call_args.kwargs["cwd"], Path("/workspace"))

    def test_invalid_policy_and_unclassified_tests_fail_actionably(self) -> None:
        for tests, exclusions, message in (
            ({"//pkg:test": set()}, {"//pkg:missing": "Needs a live node."}, "exclusion does not name"),
            ({"//pkg:test": {"live"}}, {}, "add a reason"),
            ({"//pkg:test": {"requires-credentials"}}, {}, "add a reason"),
            ({"//pkg:test": {"requires-docker"}}, {}, "Docker tests need no-remote-exec, no-sandbox"),
            ({}, {}, "no test targets"),
        ):
            with self.subTest(message=message), self.assertRaisesRegex(ValueError, message):
                discovery.validate(tests, exclusions)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "exclusions.json"
            policies = [
                {"//pkg:test": ""}, {"//pkg:test": "  "}, {"//pkg:test": None}, [],
                *({label: "Too broad."} for label in ("//pkg:*", "//...:test", "//pkg/...:test", "//pkg:all", "//pkg:all-targets")),
            ]
            for policy in policies:
                with self.subTest(policy=policy):
                    path.write_text(json.dumps(policy))
                    with self.assertRaises(ValueError):
                        discovery.load_exclusions(path)

    def test_discovery_failure_stops_execution_with_a_short_error(self) -> None:
        for error, message in (
            (ValueError("//pkg:live_test: add a reason"), "//pkg:live_test: add a reason"),
            (subprocess.TimeoutExpired(["bazel", "query"], 600), "Bazel query timed out; check for another running Bazel command and retry"),
        ):
            with self.subTest(error=error):
                output = io.StringIO()
                with patch.object(discovery, "discover", side_effect=error), patch.object(
                    discovery.subprocess, "run"
                ) as run, redirect_stderr(output):
                    self.assertEqual(discovery.main(["ordinary"]), 1)
                run.assert_not_called()
                self.assertEqual(output.getvalue(), f"test discovery failed: {message}\n")

    def test_run_passes_every_discovered_target_and_bazel_flags(self) -> None:
        targets = {"ordinary": ["//new:test"], "docker": ["//new:docker_test"]}
        for group, labels in (("ordinary", targets["ordinary"]), ("docker", targets["docker"])):
            with self.subTest(group=group), patch.object(discovery, "discover", return_value=targets), patch.object(
                discovery.subprocess, "run", return_value=subprocess.CompletedProcess([], 4)
            ) as run:
                self.assertEqual(discovery.main([group, "--workspace", "/workspace", "--bazel", "./tools/bazel", "--", "--test_output=errors"]), 4)
                self.assertEqual(run.call_args.args[0], ["/workspace/tools/bazel", "test", *labels, "--test_output=errors"])
                self.assertEqual(run.call_args.kwargs["cwd"], Path("/workspace"))

    def test_empty_group_does_not_invoke_bazel_test(self) -> None:
        targets = {"ordinary": [], "docker": []}
        for group in targets:
            with self.subTest(group=group), patch.object(discovery, "discover", return_value=targets), patch.object(
                discovery.subprocess, "run"
            ) as run, redirect_stdout(io.StringIO()) as output:
                self.assertEqual(discovery.main([group]), 0)
                run.assert_not_called()
                self.assertEqual(output.getvalue(), f"no {group} tests to run\n")

    def test_consumer_workspace_and_policy_override_tool_location(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory).resolve()
            (workspace / "ci").mkdir()
            policy = workspace / "ci/excluded.json"
            policy.write_text('{"//pkg:live_test": "Uses a live service."}')
            xml = rules_xml({"//pkg:unit_test": {"manual"}, "//pkg:live_test": {"live"}})
            with patch.object(discovery.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, stdout=xml)) as run:
                output = io.StringIO()
                with redirect_stdout(output):
                    self.assertEqual(discovery.main([
                        "check", "--workspace", str(workspace), "--bazel", "bazelisk", "--exclusions", "ci/excluded.json",
                    ]), 0)
                self.assertEqual(run.call_args.args[0][0], "bazelisk")
                self.assertEqual(run.call_args.kwargs["cwd"], workspace)
                self.assertEqual(output.getvalue(), "test discovery passed: 1 ordinary, 0 Docker tests\n")
            with self.assertRaisesRegex(ValueError, str(policy)):
                discovery.validate({"//pkg:new_live_test": {"live"}}, {}, policy)


if __name__ == "__main__":
    unittest.main()
