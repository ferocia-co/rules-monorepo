"""Guard the PR selector's graph scope and full-suite fallbacks."""

from __future__ import annotations

from pathlib import Path
import subprocess
import tempfile
import unittest

from rules_monorepo_ci import selection as selector

CONFIG = {
    "clippy_root": "//:all_clippy",
    "oci_root": "//:all_oci_images",
    "always_test_targets": ["//:all_javascript_bundles", "//:all_javascript_checks", "//:all_javascript_tests"],
    "full_check_paths": ["tools/ci", "tools/bazel", "tools/component_tests"],
}
ROOTS = selector.selection_roots(CONFIG, {})


def select_targets(root, paths, **kwargs):
    return selector.select_targets(root, paths, roots=ROOTS,
        always_checked_roots=CONFIG["always_test_targets"], full_check_paths=CONFIG["full_check_paths"], **kwargs)


class SelectPrTargetsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "BUILD.bazel").write_text("")
        package = self.root / "apps/service"
        package.mkdir(parents=True)
        (package / "BUILD.bazel").write_text("")
        source = package / "src/types/info_request.rs"
        source.parent.mkdir(parents=True)
        source.write_text("pub struct InfoRequest;\n")
        self.rust_path = "apps/service/src/types/info_request.rs"

    def test_batched_queries_select_direct_checks_and_rustfmt_scope(self) -> None:
        seen = []

        def query(expression: str) -> list[str]:
            seen.append(expression)
            if expression.startswith("set("):
                return ["//apps/service:src/types/info_request.rs"]
            if ROOTS["ordinary_tests"][1] in expression:
                return ["//apps/service:lib_test"]
            if ROOTS["docker_tests"][1] in expression:
                return ["//integration/scenarios:scenario_test"]
            if "labels(deps, //:all_clippy)" in expression:
                return ["//apps/service:lib", "//apps/service:service"]
            if "labels(srcs, //:all_oci_images)" in expression:
                return ["//apps/service:service_oci_tarball"]
            self.fail(f"unexpected query: {expression}")

        result = select_targets(self.root, [self.rust_path, self.rust_path], query=query)
        self.assertFalse(result["full"])
        self.assertEqual(result["rust_files"], [self.rust_path])
        self.assertEqual(result["rustfmt_packages"], ["//apps/service:all"])
        self.assertEqual(result["ordinary_tests"], ["//apps/service:lib_test"])
        self.assertEqual(result["oci_tarballs"], ["//apps/service:service_oci_tarball"])
        self.assertEqual(result["oci_images"], ["//apps/service:service_oci_image"])
        self.assertEqual(len(seen), 5)
        source_label = "//apps/service:src/types/info_request.rs"
        self.assertTrue(all(source_label in expr for expr in seen))
        self.assertTrue(all(f"set({source_label})" in expr for expr in seen))
        self.assertIn("intersect labels(deps, //:all_clippy)", seen[2])
        self.assertIn("intersect labels(srcs, //:all_oci_images)", seen[3])

    def test_test_only_rust_source_keeps_formatting_scope(self) -> None:
        source = self.root / "apps/service/tests/feature.rs"
        source.parent.mkdir(parents=True)
        source.write_text("#[test] fn feature() {}\n")

        def query(expression: str) -> list[str]:
            if expression.startswith("set("):
                return ["//apps/service:tests/feature.rs"]
            if ROOTS["ordinary_tests"][1] in expression:
                return ["//apps/service:feature_test"]
            return []

        result = select_targets(
            self.root, ["apps/service/tests/feature.rs"], query=query
        )
        self.assertFalse(result["full"])
        self.assertEqual(result["rustfmt_packages"], ["//apps/service:all"])
        self.assertEqual(result["clippy_targets"], [])

    def test_unmapped_rust_file_runs_full_suite(self) -> None:
        result = select_targets(self.root, [self.rust_path], query=lambda _: [])
        self.assertTrue(result["full"])
        self.assertEqual(result["rust_files"], [])

    def test_unmapped_nonrust_source_runs_full_suite(self) -> None:
        source = self.root / "apps/service/config.json"
        source.write_text("{}\n")
        result = select_targets(
            self.root, ["apps/service/config.json"], query=lambda _: []
        )
        self.assertTrue(result["full"])

    def test_undeclared_root_documentation_skips_heavy_queries(self) -> None:
        for path in ("README.md", "docs/runbooks/recovery.md"):
            doc = self.root / path
            doc.parent.mkdir(parents=True, exist_ok=True)
            doc.write_text("# Documentation\n")
        seen = []

        def query(expression: str) -> list[str]:
            seen.append(expression)
            if expression == "kind('source file', //:all-targets)":
                return []
            self.fail(f"unexpected query: {expression}")

        result = select_targets(
            self.root,
            ["README.md", "docs/runbooks/recovery.md"],
            query=query,
        )
        self.assertFalse(result["full"])
        self.assertTrue(result["docs_only"])
        self.assertEqual(result["ordinary_tests"], [])
        self.assertEqual(result["oci_images"], [])
        self.assertEqual(seen, ["kind('source file', //:all-targets)"])

    def test_root_documentation_does_not_expand_mixed_source_selection(self) -> None:
        (self.root / "README.md").write_text("# Documentation\n")
        seen = []

        def query(expression: str) -> list[str]:
            seen.append(expression)
            if expression.startswith("kind('source file', "):
                return []
            if expression.startswith("set("):
                return ["//apps/service:src/types/info_request.rs"]
            if ROOTS["ordinary_tests"][1] in expression:
                return ["//apps/service:lib_test"]
            return []

        result = select_targets(
            self.root, ["README.md", self.rust_path], query=query
        )
        self.assertFalse(result["full"])
        self.assertFalse(result["docs_only"])
        self.assertEqual(result["ordinary_tests"], ["//apps/service:lib_test"])
        self.assertTrue(all("//:README.md" not in expression for expression in seen[1:]))

    def test_undeclared_package_documentation_skips_heavy_queries(self) -> None:
        for path in (
            "apps/service/README.md",
            "apps/node/docs/CHAIN_HISTORY.md",
            "apps/api/docs/public/reference.md",
        ):
            with self.subTest(path=path):
                doc = self.root / path
                doc.parent.mkdir(parents=True, exist_ok=True)
                package = self.root.joinpath(*Path(path).parts[:2])
                (package / "BUILD.bazel").touch()
                doc.write_text("# Documentation\n")
                def query(expression: str) -> list[str]:
                    self.assertTrue(expression.startswith("kind('source file', "))
                    return []

                result = select_targets(self.root, [path], query=query)
                self.assertFalse(result["full"])
                self.assertTrue(result["docs_only"])

    def test_declared_documentation_keeps_dependency_selection(self) -> None:
        doc = self.root / "apps/service/docs/guide.md"
        doc.parent.mkdir(parents=True)
        doc.write_text("# Guide\n")
        label = "//apps/service:docs/guide.md"

        def query(expression: str) -> list[str]:
            if expression.startswith("kind('source file', "):
                return [label]
            if expression.startswith("set("):
                return [label]
            if ROOTS["ordinary_tests"][1] in expression:
                return ["//apps/service:docs_test"]
            return []

        result = select_targets(
            self.root, ["apps/service/docs/guide.md"], query=query
        )
        self.assertFalse(result["full"])
        self.assertFalse(result["docs_only"])
        self.assertEqual(result["ordinary_tests"], ["//apps/service:docs_test"])

    def test_declared_documentation_outside_ci_graph_runs_full_suite(self) -> None:
        doc = self.root / "README.md"
        doc.write_text("# Guide\n")

        def query(expression: str) -> list[str]:
            if expression.startswith("kind('source file', "):
                return ["//:README.md"]
            return []

        result = select_targets(self.root, ["README.md"], query=query)
        self.assertTrue(result["full"])

    def test_undeclared_env_example_does_not_expand_rust_selection(self) -> None:
        env = self.root / "apps/service/.env.example"
        env.write_text("EXAMPLE=1\n")
        source_label = "//apps/service:src/types/info_request.rs"

        def query(expression: str) -> list[str]:
            if expression.startswith("kind('source file', "):
                return []
            if expression.startswith("set("):
                return [source_label]
            if ROOTS["ordinary_tests"][1] in expression:
                return ["//apps/service:lib_test"]
            return []

        result = select_targets(
            self.root, [self.rust_path, "apps/service/.env.example"], query=query
        )
        self.assertFalse(result["full"])
        self.assertEqual(result["ordinary_tests"], ["//apps/service:lib_test"])

    def test_documentation_preflight_failure_runs_full_suite(self) -> None:
        doc = self.root / "README.md"
        doc.write_text("# Guide\n")

        def fail(_: str) -> list[str]:
            raise subprocess.CalledProcessError(7, "bazel query")

        result = select_targets(self.root, ["README.md"], query=fail)
        self.assertTrue(result["full"])
        self.assertEqual(result["reason"], "Bazel query failed")

    def test_selected_oci_targets_require_tarball_naming(self) -> None:
        def query(expression: str) -> list[str]:
            if expression.startswith("set("):
                return ["//apps/service:src/types/info_request.rs"]
            if "labels(srcs, //:all_oci_images)" in expression:
                return ["//apps/service:unexpected_name"]
            return []

        result = select_targets(self.root, [self.rust_path], query=query)
        self.assertTrue(result["full"])
        self.assertEqual(result["reason"], "Bazel query failed")

    def test_one_unmapped_rust_file_among_mapped_files_runs_full_suite(self) -> None:
        second = self.root / "apps/service/src/types/new_file.rs"
        second.write_text("pub struct NewFile;\n")

        def query(expression: str) -> list[str]:
            if expression.startswith("set("):
                return ["//apps/service:src/types/info_request.rs"]
            if ROOTS["ordinary_tests"][1] in expression:
                return ["//apps/service:lib_test"]
            return []

        result = select_targets(
            self.root,
            [self.rust_path, "apps/service/src/types/new_file.rs"],
            query=query,
        )
        self.assertTrue(result["full"])

    def test_query_failure_runs_full_suite(self) -> None:
        def fail(_: str) -> list[str]:
            raise subprocess.CalledProcessError(7, "bazel query")

        result = select_targets(self.root, [self.rust_path], query=fail)
        self.assertTrue(result["full"])
        self.assertEqual(result["reason"], "Bazel query failed")

    def test_build_and_tooling_changes_do_not_query(self) -> None:
        for path in (
            "apps/service/BUILD.bazel", "MODULE.bazel", "Cargo.lock",
            ".github/workflows/ci.yml", "tools/ci/select_pr_targets.py",
            "tools/bazel/rust_deps.bzl", "Justfile", ".bazelignore",
            ".bazelrc.ci", "apps/service/rustfmt.toml",
        ):
            with self.subTest(path=path):
                changed = self.root / path
                changed.parent.mkdir(parents=True, exist_ok=True)
                changed.touch()
                result = select_targets(
                    self.root, [path], query=lambda _: self.fail("query should not run")
                )
                self.assertTrue(result["full"])

    def test_missing_outside_and_rename_status_run_full_suite(self) -> None:
        for path in ("apps/service/src/deleted.rs", "../outside.rs", "/tmp/outside.rs"):
            with self.subTest(path=path):
                result = select_targets(self.root, [path], query=lambda _: [])
                self.assertTrue(result["full"])
        result = select_targets(
            self.root, [self.rust_path], deleted_or_renamed=True, query=lambda _: []
        )
        self.assertTrue(result["full"])

if __name__ == "__main__":
    unittest.main()
