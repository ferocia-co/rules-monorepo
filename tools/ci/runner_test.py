"""Preserve full, selective, and docs-only gates through direct Bazel calls."""

from contextlib import redirect_stderr, redirect_stdout
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from rules_monorepo_ci import runner, selection


CONFIG = {
    "exclusions": None,
    "build_targets": ["//:checks"],
    "always_test_targets": ["//:frontend", "//:audit"],
    "check_targets": ["//:validate"],
    "lockfile_targets": ["@dependencies//:lints"],
    "clippy_root": "//:lint",
    "oci_root": "//:images",
    "oci_scope": "//... except //integration/...",
    "full_check_paths": ["ci"],
    "test_args": ["--remote_download_outputs=minimal"],
    "full_check_args": ["--nobuild_runfile_links"],
    "docker_jobs": 2,
    "oci_jobs": 16,
}


def plan(**updates):
    return {**selection.full_result(""), "full": False, **updates}


class RunnerTest(unittest.TestCase):
    def setUp(self):
        self.subject = runner.Runner(Path("/workspace"), "./bazel", CONFIG)

    def test_diff_requires_expected_merge_and_preserves_nul_paths(self):
        for head, parent, paths, deleted, expected in (
            (b"expected\n", b"", b"src/a.rs\0docs/a\nb.md\0", b"", (["src/a.rs", "docs/a\nb.md"], False)),
            (b"expected\n", b"", b"src/a.rs\0", b"src/old.rs\0", (["src/a.rs"], True)),
            (b"other\n", b"", b"src/a.rs\0", b"", ([], False)),
            (b"expected\n", subprocess.CalledProcessError(1, "git"), b"", b"", ([], False)),
            (b"expected\n", b"", subprocess.CalledProcessError(1, "git"), b"", ([], False)),
            (b"expected\n", b"", b"src/truncated.rs", b"", ([], False)),
        ):
            with self.subTest(expected=expected), patch.dict(os.environ, GITHUB_SHA="expected"), patch.object(
                runner.subprocess, "check_output", side_effect=[head, parent, paths, deleted]
            ):
                self.assertEqual(runner.changed_paths(Path("/workspace")), expected)

    def test_plan_exports_docs_only_and_full_fallback_after_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "BUILD.bazel").touch()
            (root / "README.md").write_text("# Docs\n")
            subject = runner.Runner(root, "bazel", CONFIG)
            for paths, docs_only in ((["README.md"], True), ([], False)):
                with self.subTest(paths=paths), patch.object(subject, "discover") as discover, patch.object(
                    selection, "_run_query", return_value=[]
                ), patch.dict(os.environ, GITHUB_ENV=str(root / "env"), GITHUB_OUTPUT=str(root / "output")), redirect_stdout(io.StringIO()) as output:
                    subject.plan(paths)
                discover.assert_called_once()
                result = json.loads(output.getvalue())
                self.assertEqual(result["docs_only"], docs_only)
                self.assertEqual(result["full"], not docs_only)
                self.assertEqual((root / "env").read_text().splitlines()[-1], f"PLAN_JSON={json.dumps(result, sort_keys=True)}")
                self.assertEqual((root / "output").read_text().splitlines()[-1], f"docs_only={str(docs_only).lower()}")

    def test_checks_discover_full_inventory_and_keep_selective_invariants(self):
        for full, ordinary in ((True, []), (False, []), (False, ["//fresh:test"])):
            with self.subTest(full=full, tests=ordinary), patch.object(self.subject, "run") as run, patch.object(
                self.subject, "discover", return_value={"ordinary": ["//fresh:manual_test"], "docker": []}
            ):
                self.subject.checks(plan(full=full, ordinary_tests=ordinary,
                    rustfmt_packages=["//fresh:all"], clippy_targets=["//fresh:lib"]), ["--jobs=3"])
            commands = [call.args for call in run.call_args_list]
            self.assertEqual(commands[:2], [("build", "@dependencies//:lints", "--nobuild", "--lockfile_mode=error"), ("run", "//:validate")])
            for label in ("//:frontend", "//:audit", *( ["//fresh:manual_test", "//:checks"] if full else ordinary)):
                self.assertIn(label, commands[-1])
            self.assertEqual(commands[-1][-1], "--jobs=3")
            if not full:
                self.assertIn(("run", "@rules_rust//tools/rustfmt:target_aware_rustfmt", "--", "//fresh:all", "--", "--check"), commands)
                self.assertTrue(any("//fresh:lib" in command and "--output_groups=clippy_checks" in command for command in commands))

    def test_direct_execution_uses_consumer_wrapper_and_propagates_failure(self):
        with patch.object(runner.subprocess, "run", side_effect=subprocess.CalledProcessError(7, "bazel")) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                self.subject.run("test", "//fresh:test")
        self.assertEqual(run.call_args.args[0], ["/workspace/bazel", "test", "//fresh:test"])
        self.assertEqual(run.call_args.kwargs["env"]["BAZEL_REAL"], "/workspace/bazel")
        self.assertEqual(run.call_args.kwargs["cwd"], Path("/workspace"))
        with patch.object(self.subject, "run", side_effect=subprocess.CalledProcessError(7, "bazel")) as run, patch.object(
            self.subject, "discover", return_value={"ordinary": [], "docker": []}
        ), self.assertRaises(subprocess.CalledProcessError):
            self.subject.checks(plan(), [])
        self.assertEqual(run.call_count, 1)

    def test_docker_routing_skips_empty_groups_and_keys_results_by_runtime(self):
        for full, tests in ((False, []), (False, ["//fresh:docker_test"]), (True, [])):
            with self.subTest(full=full, tests=tests), patch.object(self.subject, "run") as run, patch.object(
                self.subject, "discover", return_value={"docker": ["//other:docker_test"]}
            ), patch.object(runner.subprocess, "check_output", return_value="28/linux/x86_64\n") as docker, redirect_stdout(io.StringIO()):
                self.subject.components(plan(full=full, docker_tests=tests), ["--local_test_jobs=1"])
            if not full and not tests:
                docker.assert_not_called()
                run.assert_not_called()
            else:
                args = run.call_args.args
                self.assertEqual(args[:2], ("test", "//other:docker_test" if full else tests[0]))
                self.assertIn("--test_env=COMPONENT_TEST_DOCKER_RUNTIME=28/linux/x86_64", args)
                self.assertIn("--local_test_jobs=2", args)
                self.assertEqual(args[-1], "--local_test_jobs=1")

    def test_oci_selection_keeps_scope_concurrency_and_does_not_push(self):
        for full, images in ((False, []), (False, ["//fresh:app_oci_image"]), (True, [])):
            with self.subTest(full=full, images=images), patch.object(self.subject, "run") as run, patch.dict(
                os.environ, OCI_BAZEL_CONCURRENCY="8"
            ), redirect_stdout(io.StringIO()):
                self.subject.images(plan(full=full, oci_images=images), [])
            if not full and not images:
                run.assert_not_called()
            else:
                args = run.call_args.args
                self.assertEqual(args[:5], ("run", "--compilation_mode=opt", "@rules_monorepo//tools/oci:oci", "--", "build"))
                self.assertIn("//... except //integration/...", args)
                self.assertEqual(args[-2:], ("--bazel-jobs", "8"))
                self.assertIn("--all" if full else "--image", args)
                for image in images:
                    self.assertIn(image, args)

    def test_cli_handles_docs_only_bad_input_and_explicit_full_override(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "config.json"
            config.write_text(json.dumps(CONFIG))
            args = ["--config", str(config)]
            for stage in ("checks", "components", "images"):
                with self.subTest(stage=stage), patch.dict(os.environ, PLAN_JSON=json.dumps(plan(docs_only=True))), patch.object(runner.Runner, stage) as execute:
                    self.assertEqual(runner.main([*args, stage]), 0)
                    execute.assert_not_called()
            with patch.dict(os.environ, PLAN_JSON=json.dumps(plan(docs_only=True))), patch.object(runner.Runner, "checks") as execute:
                self.assertEqual(runner.main([*args, "checks", "--full", "--", "--jobs=3"]), 0)
                self.assertTrue(execute.call_args.args[0]["full"])
                self.assertEqual(execute.call_args.args[1], ["--jobs=3"])
            with patch.dict(os.environ, PLAN_JSON="invalid"), redirect_stderr(io.StringIO()) as output:
                self.assertEqual(runner.main([*args, "checks"]), 1)
            self.assertTrue(output.getvalue().startswith("CI failed:"))
            paths = Path(directory) / "paths"
            paths.write_bytes(b"unterminated")
            with patch.object(runner.Runner, "plan") as execute:
                self.assertEqual(runner.main([*args, "plan", "--changed-files0", str(paths)]), 0)
                self.assertEqual(execute.call_args.args[0], [])
            with patch.object(runner.Runner, "checks", side_effect=subprocess.CalledProcessError(7, "bazel")):
                self.assertEqual(runner.main([*args, "checks", "--full"]), 7)


if __name__ == "__main__":
    unittest.main()
