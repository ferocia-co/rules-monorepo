"""Public frontend API for rules_monorepo."""

load(
    ":pnpm_defs.bzl",
    _frontend_node_server_oci_image = "frontend_node_server_oci_image",
    _frontend_sources = "frontend_sources",
    _frontend_static_site_oci_image = "frontend_static_site_oci_image",
    _pnpm_biome_check = "pnpm_biome_check",
    _pnpm_cypress_test = "pnpm_cypress_test",
    _pnpm_eslint_test = "pnpm_eslint_test",
    _pnpm_frontend_checks = "pnpm_frontend_checks",
    _pnpm_playwright_cli = "pnpm_playwright_cli",
    _pnpm_playwright_test = "pnpm_playwright_test",
    _pnpm_prettier_test = "pnpm_prettier_test",
    _pnpm_storybook_dev_server = "pnpm_storybook_dev_server",
    _pnpm_storybook_static_build = "pnpm_storybook_static_build",
    _pnpm_svelte_check_test = "pnpm_svelte_check_test",
    _pnpm_svelte_vite_app = "pnpm_svelte_vite_app",
    _pnpm_sveltekit_node_server = "pnpm_sveltekit_node_server",
    _pnpm_sveltekit_sync = "pnpm_sveltekit_sync",
    _pnpm_tsc_noemit_test = "pnpm_tsc_noemit_test",
    _pnpm_vite_build = "pnpm_vite_build",
    _pnpm_vite_dev_server = "pnpm_vite_dev_server",
    _pnpm_vitest_test = "pnpm_vitest_test",
)

frontend_node_server_oci_image = _frontend_node_server_oci_image
frontend_sources = _frontend_sources
frontend_static_site_oci_image = _frontend_static_site_oci_image
pnpm_biome_check = _pnpm_biome_check
pnpm_cypress_test = _pnpm_cypress_test
pnpm_eslint_test = _pnpm_eslint_test
pnpm_frontend_checks = _pnpm_frontend_checks
pnpm_playwright_cli = _pnpm_playwright_cli
pnpm_playwright_test = _pnpm_playwright_test
pnpm_prettier_test = _pnpm_prettier_test
pnpm_storybook_dev_server = _pnpm_storybook_dev_server
pnpm_storybook_static_build = _pnpm_storybook_static_build
pnpm_svelte_check_test = _pnpm_svelte_check_test
pnpm_svelte_vite_app = _pnpm_svelte_vite_app
pnpm_sveltekit_node_server = _pnpm_sveltekit_node_server
pnpm_sveltekit_sync = _pnpm_sveltekit_sync
pnpm_tsc_noemit_test = _pnpm_tsc_noemit_test
pnpm_vite_build = _pnpm_vite_build
pnpm_vite_dev_server = _pnpm_vite_dev_server
pnpm_vitest_test = _pnpm_vitest_test

monorepo_frontend_node_server_oci_image = _frontend_node_server_oci_image
monorepo_frontend_sources = _frontend_sources
monorepo_frontend_static_site_oci_image = _frontend_static_site_oci_image
monorepo_pnpm_biome_check = _pnpm_biome_check
monorepo_pnpm_cypress_test = _pnpm_cypress_test
monorepo_pnpm_eslint_test = _pnpm_eslint_test
monorepo_pnpm_frontend_checks = _pnpm_frontend_checks
monorepo_pnpm_playwright_cli = _pnpm_playwright_cli
monorepo_pnpm_playwright_test = _pnpm_playwright_test
monorepo_pnpm_prettier_test = _pnpm_prettier_test
monorepo_pnpm_storybook_dev_server = _pnpm_storybook_dev_server
monorepo_pnpm_storybook_static_build = _pnpm_storybook_static_build
monorepo_pnpm_svelte_check_test = _pnpm_svelte_check_test
monorepo_pnpm_svelte_vite_app = _pnpm_svelte_vite_app
monorepo_pnpm_sveltekit_node_server = _pnpm_sveltekit_node_server
monorepo_pnpm_sveltekit_sync = _pnpm_sveltekit_sync
monorepo_pnpm_tsc_noemit_test = _pnpm_tsc_noemit_test
monorepo_pnpm_vite_build = _pnpm_vite_build
monorepo_pnpm_vite_dev_server = _pnpm_vite_dev_server
monorepo_pnpm_vitest_test = _pnpm_vitest_test
