# rules_monorepo_frontend

Frontend layer for `rules_monorepo`.

The v1 API targets pnpm workspaces that use Svelte, Vite, TypeScript,
Prettier, ESLint, Playwright, and static nginx OCI images.

## Dependency Model

`package.json` and `pnpm-lock.yaml` stay the dependency source of truth.
Configure `aspect_rules_js` in `MODULE.bazel` and load package-local generated
bin wrappers from `@npm`.

For pnpm v10, declare packages that run lifecycle hooks in
`pnpm-workspace.yaml`:

```yaml
packages:
  - interfaces/experiments/orderbook/ui

onlyBuiltDependencies:
  - esbuild
  - playwright
```

```starlark
bazel_dep(name = "rules_nodejs", version = "6.7.4")
bazel_dep(name = "aspect_rules_js", version = "3.0.3")

node = use_extension("@rules_nodejs//nodejs:extensions.bzl", "node")
node.toolchain(node_version_from_nvmrc = "//:.nvmrc")
use_repo(node, "nodejs_toolchains")

pnpm = use_extension("@aspect_rules_js//npm:extensions.bzl", "pnpm")
pnpm.pnpm(pnpm_version = "10.33.0")
use_repo(pnpm, "pnpm")

npm = use_extension("@aspect_rules_js//npm:extensions.bzl", "npm")
npm.npm_translate_lock(
    name = "npm",
    npmrc = "//:.npmrc",
    pnpm_lock = "//:pnpm-lock.yaml",
    bins = {
        "eslint": ["eslint=bin/eslint.js"],
        "playwright": ["playwright=cli.js"],
        "prettier": ["prettier=bin/prettier.cjs"],
        "svelte-check": ["svelte-check=bin/svelte-check"],
        "typescript": ["tsc=bin/tsc"],
        "vite": ["vite=bin/vite.js"],
    },
)
use_repo(npm, "npm")
```

If you use `pnpm_playwright_test` with the default Linux browser labels, add the
same pinned headless-shell repository used by fw:

```starlark
http_archive = use_repo_rule("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "playwright_chromium_headless_shell_linux_x64",
    build_file_content = """
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "chrome_headless_shell_files",
    srcs = glob(["chrome-headless-shell-linux64/**"]),
)

filegroup(
    name = "chrome_headless_shell",
    srcs = ["chrome-headless-shell-linux64/chrome-headless-shell"],
)
""",
    sha256 = "a9a525cb3832d59a810f78f8ba6c5ed3592a6a488984627f5d827c2a365c8a5a",
    urls = [
        "https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/1200/chromium-headless-shell-linux.zip",
        "https://playwright.download.prss.microsoft.com/dbazure/download/playwright/builds/chromium/1200/chromium-headless-shell-linux.zip",
        "https://cdn.playwright.dev/builds/chromium/1200/chromium-headless-shell-linux.zip",
    ],
)
```

## BUILD Usage

```starlark
load("@npm//path/to/app:eslint/package_json.bzl", eslint_bin = "bin")
load("@npm//path/to/app:playwright/package_json.bzl", playwright_bin = "bin")
load("@npm//path/to/app:prettier/package_json.bzl", prettier_bin = "bin")
load("@npm//path/to/app:svelte-check/package_json.bzl", svelte_check_bin = "bin")
load("@npm//path/to/app:typescript/package_json.bzl", tsc_bin = "bin")
load("@npm//path/to/app:vite/package_json.bzl", vite_bin = "bin")
load("@rules_monorepo//rules_monorepo_frontend:defs.bzl", "frontend_static_site_oci_image", "pnpm_frontend_checks", "pnpm_playwright_cli", "pnpm_playwright_test", "pnpm_svelte_vite_app")

pnpm_svelte_vite_app(
    name = "bundle",
    vite = vite_bin.vite,
    srcs = [":sources"],
    out_dir = "dist",
)

pnpm_frontend_checks(
    name = "checks",
    srcs = [":sources"],
    svelte_check = svelte_check_bin.svelte_check,
    tsc = tsc_bin.tsc,
    prettier = prettier_bin.prettier,
    eslint = eslint_bin.eslint,
)

pnpm_playwright_cli(
    name = "playwright_cli",
    playwright = playwright_bin.playwright_binary,
)

pnpm_playwright_test(
    name = "playwright_test",
    entry_point = "tests/smoke.mjs",
    srcs = [":sources"],
)

frontend_static_site_oci_image(
    name = "frontend",
    assets = ":bundle",
    nginx_conf = "nginx.conf",
    repository = "registry.example.com/frontend",
)
```

Callers still load the generated bin wrappers explicitly because Bazel loads
`.bzl` files statically. The macros centralize the repeatable build, check,
test, and OCI target shapes.

`frontend_static_site_oci_image(name = "frontend", ...)` generates the same
target names as fw's current UI packaging:

- `frontend_image`
- `frontend_image.digest`
- `frontend_load`
- `frontend_tarball`
- `frontend_push`

`pnpm_playwright_test` adds the Linux x86_64 headless-shell runfiles when the
target platform matches Linux and sets
`FEROCIA_PLAYWRIGHT_CHROMIUM_HEADLESS_SHELL` to the shell binary rootpath.
