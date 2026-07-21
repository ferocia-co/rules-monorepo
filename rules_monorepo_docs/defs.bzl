"""Public documentation API for rules_monorepo."""

load(":mdbook.bzl", _mdbook_docs = "mdbook_docs")

mdbook_docs = _mdbook_docs

monorepo_mdbook_docs = _mdbook_docs
