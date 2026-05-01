"""Public frontend API for rules_monorepo."""

load(":pnpm_defs.bzl", _frontend_static_site_oci_image = "frontend_static_site_oci_image", _pnpm_eslint_test = "pnpm_eslint_test", _pnpm_frontend_checks = "pnpm_frontend_checks", _pnpm_playwright_cli = "pnpm_playwright_cli", _pnpm_playwright_test = "pnpm_playwright_test", _pnpm_prettier_test = "pnpm_prettier_test", _pnpm_svelte_check_test = "pnpm_svelte_check_test", _pnpm_svelte_vite_app = "pnpm_svelte_vite_app", _pnpm_tsc_noemit_test = "pnpm_tsc_noemit_test")

frontend_static_site_oci_image = _frontend_static_site_oci_image
pnpm_eslint_test = _pnpm_eslint_test
pnpm_frontend_checks = _pnpm_frontend_checks
pnpm_playwright_cli = _pnpm_playwright_cli
pnpm_playwright_test = _pnpm_playwright_test
pnpm_prettier_test = _pnpm_prettier_test
pnpm_svelte_check_test = _pnpm_svelte_check_test
pnpm_svelte_vite_app = _pnpm_svelte_vite_app
pnpm_tsc_noemit_test = _pnpm_tsc_noemit_test

monorepo_frontend_static_site_oci_image = _frontend_static_site_oci_image
monorepo_pnpm_eslint_test = _pnpm_eslint_test
monorepo_pnpm_frontend_checks = _pnpm_frontend_checks
monorepo_pnpm_playwright_cli = _pnpm_playwright_cli
monorepo_pnpm_playwright_test = _pnpm_playwright_test
monorepo_pnpm_prettier_test = _pnpm_prettier_test
monorepo_pnpm_svelte_check_test = _pnpm_svelte_check_test
monorepo_pnpm_svelte_vite_app = _pnpm_svelte_vite_app
monorepo_pnpm_tsc_noemit_test = _pnpm_tsc_noemit_test
