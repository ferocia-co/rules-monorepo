# rules_monorepo_frontend

Frontend layer for `rules_monorepo`.

These macros standardize Bazel target shapes for pnpm frontend packages. They
do not own dependency setup: consuming repos still own `package.json`,
`pnpm-lock.yaml`, `npm_translate_lock`, package-local `@npm` bin wrapper loads,
Node/pnpm toolchains, browser archives, and OCI base image repositories.

## Dependency Model

Configure `aspect_rules_js` in the consuming repo and load package-local bin
wrappers from `@npm`.

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
    pnpm_lock = "//:pnpm-lock.yaml",
    bins = {
        "@biomejs/biome": ["biome=bin/biome"],
        "@sveltejs/kit": ["svelte-kit=svelte-kit.js"],
        "cypress": ["cypress=bin/cypress"],
        "eslint": ["eslint=bin/eslint.js"],
        "playwright": ["playwright=cli.js"],
        "prettier": ["prettier=bin/prettier.cjs"],
        "storybook": ["storybook=bin/index.cjs"],
        "svelte-check": ["svelte-check=bin/svelte-check"],
        "typescript": ["tsc=bin/tsc"],
        "vite": ["vite=bin/vite.js"],
        "vitest": ["vitest=vitest.mjs"],
    },
)
use_repo(npm, "npm")
```

Only declare the bins a package actually uses. If a tool requires extra linked
workspace packages, pass those labels in that target's `srcs` or `data`.

## Static Vite App

```starlark
load("@npm//path/to/app:eslint/package_json.bzl", eslint_bin = "bin")
load("@npm//path/to/app:playwright/package_json.bzl", playwright_bin = "bin")
load("@npm//path/to/app:prettier/package_json.bzl", prettier_bin = "bin")
load("@npm//path/to/app:svelte-check/package_json.bzl", svelte_check_bin = "bin")
load("@npm//path/to/app:typescript/package_json.bzl", tsc_bin = "bin")
load("@npm//path/to/app:vite/package_json.bzl", vite_bin = "bin")
load(
    "@rules_monorepo//rules_monorepo_frontend:defs.bzl",
    "frontend_sources",
    "frontend_static_site_oci_image",
    "pnpm_frontend_checks",
    "pnpm_playwright_cli",
    "pnpm_playwright_test",
    "pnpm_vite_build",
)

frontend_sources(name = "sources")

pnpm_vite_build(
    name = "bundle",
    vite = vite_bin.vite,
    srcs = [":sources"],
)

pnpm_frontend_checks(
    name = "checks",
    srcs = [":sources"],
    eslint = eslint_bin.eslint,
    prettier = prettier_bin.prettier,
    svelte_check = svelte_check_bin.svelte_check,
    tsc = tsc_bin.tsc,
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
    base = "@nginx_unprivileged_linux_amd64",
    nginx_conf = "nginx.conf",
    repository = "registry.example.com/frontend",
)
```

`pnpm_svelte_vite_app` remains available for fw-compatible callers and delegates
to `pnpm_vite_build`.

## SvelteKit Node App

```starlark
load("@npm//apps/web:@biomejs/biome/package_json.bzl", biome_bin = "bin")
load("@npm//apps/web:@sveltejs/kit/package_json.bzl", svelte_kit_bin = "bin")
load("@npm//apps/web:cypress/package_json.bzl", cypress_bin = "bin")
load("@npm//apps/web:storybook/package_json.bzl", storybook_bin = "bin")
load("@npm//apps/web:svelte-check/package_json.bzl", svelte_check_bin = "bin")
load("@npm//apps/web:typescript/package_json.bzl", tsc_bin = "bin")
load("@npm//apps/web:vite/package_json.bzl", vite_bin = "bin")
load("@npm//apps/web:vitest/package_json.bzl", vitest_bin = "bin")
load(
    "@rules_monorepo//rules_monorepo_frontend:defs.bzl",
    "frontend_node_server_oci_image",
    "frontend_sources",
    "pnpm_biome_check",
    "pnpm_cypress_test",
    "pnpm_storybook_dev_server",
    "pnpm_storybook_static_build",
    "pnpm_svelte_check_test",
    "pnpm_sveltekit_node_server",
    "pnpm_sveltekit_sync",
    "pnpm_tsc_noemit_test",
    "pnpm_vite_build",
    "pnpm_vite_dev_server",
    "pnpm_vitest_test",
)

frontend_sources(
    name = "sources",
    extra_srcs = [".gitignore"],
)

pnpm_sveltekit_sync(
    name = "sveltekit_sync",
    svelte_kit = svelte_kit_bin.svelte_kit,
    srcs = [":sources"],
)

pnpm_vite_build(
    name = "bundle",
    vite = vite_bin.vite,
    srcs = [
        ":sources",
        ":sveltekit_sync",
    ],
    out_dir = "build",
)

pnpm_vite_dev_server(
    name = "dev",
    vite = vite_bin.vite_binary,
    srcs = [
        ":sources",
        ":sveltekit_sync",
    ],
)

pnpm_sveltekit_node_server(
    name = "server",
    bundle = ":bundle",
)

pnpm_svelte_check_test(
    name = "svelte_check",
    svelte_check = svelte_check_bin.svelte_check,
    srcs = [
        ":sources",
        ":sveltekit_sync",
    ],
)

pnpm_tsc_noemit_test(
    name = "tsc_noemit",
    tsc = tsc_bin.tsc,
    srcs = [
        ":sources",
        ":sveltekit_sync",
    ],
)

pnpm_biome_check(
    name = "biome_check",
    biome = biome_bin.biome,
    srcs = [":sources"],
)

pnpm_vitest_test(
    name = "vitest_test",
    vitest = vitest_bin.vitest_test,
    srcs = [
        ":sources",
        ":sveltekit_sync",
    ],
)

pnpm_storybook_static_build(
    name = "storybook",
    storybook = storybook_bin.storybook,
    srcs = [
        ":sources",
        "//:node_modules/@storybook/sveltekit",
        "//:node_modules/react",
        "//:node_modules/react-dom",
    ],
)

pnpm_storybook_dev_server(
    name = "storybook_dev",
    storybook = storybook_bin.storybook_binary,
    srcs = [
        ":sources",
        ":sveltekit_sync",
        "//:node_modules/@storybook/sveltekit",
        "//:node_modules/react",
        "//:node_modules/react-dom",
    ],
)

pnpm_cypress_test(
    name = "cypress_e2e_test",
    cypress = cypress_bin.cypress_test,
    srcs = [
        ":sources",
        ":sveltekit_sync",
        ":bundle",
    ],
    tags = ["no-sandbox"],
)

frontend_node_server_oci_image(
    name = "frontend",
    bundle = ":bundle",
    base = "@nodejs_distroless_linux_amd64",
    repository = "registry.example.com/frontend",
)
```

Storybook support deliberately wraps only a caller-provided Storybook bin plus
caller-provided `srcs`. It does not create hard-coded package-store links.

## Generated OCI Targets

`frontend_static_site_oci_image(name = "frontend", ...)` and
`frontend_node_server_oci_image(name = "frontend", ...)` generate:

- `frontend_image`
- `frontend_image.digest`
- `frontend_load`
- `frontend_tarball`
- `frontend_push`

When `repository` is omitted, the push target uses the existing placeholder
`registry.invalid/...` default. Real consumers should pass their own registry.
The Node image helper defaults to `/nodejs/bin/node /app/build/index.js`,
`HOST=0.0.0.0`, `PORT=3000`, and `3000/tcp`, all of which callers may override.

## Playwright Browser Archive

`pnpm_playwright_test` can use Linux x86_64 Chromium headless-shell runfiles.
If you keep the default browser labels, the consuming repo must define the
`@playwright_chromium_headless_shell_linux_x64` repository itself.
