"""Rust module extensions for rules_monorepo.

This keeps the public extension label under rules_monorepo while preserving
standard rules_rust crate_universe behavior.
"""

load("@rules_rust//crate_universe:extension.bzl", _crate = "crate")

crate = _crate
