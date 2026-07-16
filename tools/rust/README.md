# Hermetic Rust developer tools

- `//tools/rust:cargo` forwards arguments to the Cargo distributed by the
  registered `rules_rs` toolchain.
- `//tools/rust:rust_analyzer_setup` configures VS Code, Neovim, Helix, or an
  editor-agnostic JSON client using Bazel-provisioned binaries.
- `//tools/rust:cargo_audit` selects the official checksum-pinned cargo-audit
  0.22.1 binary for the execution platform.

Consumers invoke these labels through `@rules_monorepo`, for example:

```bash
bazel run @rules_monorepo//tools/rust:cargo -- fmt
bazel run @rules_monorepo//tools/rust:rust_analyzer_setup -- --per-package-workspaces vscode
bazel run @rules_monorepo//tools/rust:cargo_audit -- --version
```
