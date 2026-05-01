"""pnpm-oriented frontend macros.

These macros keep package.json and pnpm-lock.yaml as the dependency source of
truth. Callers still load generated package bin wrappers from @npm because
Bazel loads .bzl files statically.
"""

load("@aspect_rules_js//js:defs.bzl", "js_test")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_load", "oci_push")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

def _dedupe(values):
    out = []
    for value in values or []:
        if value not in out:
            out.append(value)
    return out

def _default_chdir(chdir):
    return native.package_name() if chdir == None else chdir

def _with_node_modules(srcs, node_modules):
    out = list(srcs or [])
    if node_modules != None:
        out.append(node_modules)
    return out

def _target_name(label):
    if type(label) != "string":
        return None
    if label.startswith(":"):
        return label[1:]
    if ":" in label:
        return label.rsplit(":", 1)[1]
    return label.rsplit("/", 1)[-1]

def _image_name_from_repo_tags(repo_tags):
    if type(repo_tags) != "list" or len(repo_tags) == 0:
        return None
    tag = repo_tags[0]
    if type(tag) != "string":
        return None
    if ":" in tag:
        return tag.rsplit(":", 1)[0]
    return tag

def _default_repo_name(name):
    return name.replace("_", "-")

def pnpm_svelte_vite_app(
        name,
        vite,
        srcs,
        node_modules = ":node_modules",
        args = None,
        chdir = None,
        out_dir = "dist",
        tags = None,
        **kwargs):
    """Runs a package-local Vite build using an @npm generated vite macro."""
    vite(
        name = name,
        srcs = _with_node_modules(srcs, node_modules),
        args = args or ["build"],
        chdir = _default_chdir(chdir),
        out_dirs = [out_dir],
        tags = _dedupe(tags),
        **kwargs
    )

def pnpm_svelte_check_test(
        name,
        svelte_check,
        srcs,
        node_modules = ":node_modules",
        tsconfig = "tsconfig.json",
        chdir = None,
        tags = None,
        **kwargs):
    """Runs svelte-check as a buildable lint target."""
    svelte_check(
        name = name,
        srcs = _with_node_modules(srcs, node_modules),
        args = [
            "--tsconfig",
            "./{}".format(tsconfig),
        ],
        chdir = _default_chdir(chdir),
        stderr = name + ".stderr",
        stdout = name + ".stdout",
        tags = _dedupe(list(tags or []) + ["lint"]),
        **kwargs
    )

def pnpm_tsc_noemit_test(
        name,
        tsc,
        srcs,
        node_modules = ":node_modules",
        project = "tsconfig.json",
        chdir = None,
        tags = None,
        **kwargs):
    """Runs TypeScript in no-emit mode as a buildable lint target."""
    tsc(
        name = name,
        srcs = _with_node_modules(srcs, node_modules),
        args = [
            "--noEmit",
            "--pretty",
            "false",
            "-p",
            project,
        ],
        chdir = _default_chdir(chdir),
        stderr = name + ".stderr",
        stdout = name + ".stdout",
        tags = _dedupe(list(tags or []) + ["lint"]),
        **kwargs
    )

def pnpm_prettier_test(
        name,
        prettier,
        srcs,
        node_modules = ":node_modules",
        patterns = None,
        chdir = None,
        tags = None,
        **kwargs):
    """Runs prettier --check as a buildable lint target."""
    prettier(
        name = name,
        srcs = _with_node_modules(srcs, node_modules),
        args = ["--check"] + (patterns or [
            "*.{html,json,mjs,ts}",
            "src/**/*.{css,svelte,ts}",
            "tests/**/*.mjs",
        ]),
        chdir = _default_chdir(chdir),
        stderr = name + ".stderr",
        stdout = name + ".stdout",
        tags = _dedupe(list(tags or []) + ["lint"]),
        **kwargs
    )

def pnpm_eslint_test(
        name,
        eslint,
        srcs,
        node_modules = ":node_modules",
        patterns = None,
        chdir = None,
        tags = None,
        **kwargs):
    """Runs eslint with zero-warning policy as a buildable lint target."""
    eslint(
        name = name,
        srcs = _with_node_modules(srcs, node_modules),
        args = [
            "--max-warnings",
            "0",
        ] + (patterns or [
            "*.{config.mjs,config.ts}",
            "src/**/*.{svelte,ts}",
            "tests/**/*.mjs",
        ]),
        chdir = _default_chdir(chdir),
        stderr = name + ".stderr",
        stdout = name + ".stdout",
        tags = _dedupe(list(tags or []) + ["lint"]),
        **kwargs
    )

def pnpm_frontend_checks(
        name,
        srcs,
        svelte_check = None,
        tsc = None,
        prettier = None,
        eslint = None,
        node_modules = ":node_modules",
        chdir = None,
        tags = None):
    """Defines common frontend checks and a filegroup aggregating them."""
    targets = []
    base_tags = _dedupe(list(tags or []) + ["lint"])

    if svelte_check != None:
        target = name + "_svelte_check"
        pnpm_svelte_check_test(
            name = target,
            svelte_check = svelte_check,
            srcs = srcs,
            node_modules = node_modules,
            chdir = chdir,
            tags = base_tags,
        )
        targets.append(":" + target)

    if tsc != None:
        target = name + "_tsc_noemit"
        pnpm_tsc_noemit_test(
            name = target,
            tsc = tsc,
            srcs = srcs,
            node_modules = node_modules,
            chdir = chdir,
            tags = base_tags,
        )
        targets.append(":" + target)

    if prettier != None:
        target = name + "_prettier_check"
        pnpm_prettier_test(
            name = target,
            prettier = prettier,
            srcs = srcs,
            node_modules = node_modules,
            chdir = chdir,
            tags = base_tags,
        )
        targets.append(":" + target)

    if eslint != None:
        target = name + "_eslint_check"
        pnpm_eslint_test(
            name = target,
            eslint = eslint,
            srcs = srcs,
            node_modules = node_modules,
            chdir = chdir,
            tags = base_tags,
        )
        targets.append(":" + target)

    native.filegroup(
        name = name,
        srcs = targets,
        tags = base_tags,
    )

def pnpm_playwright_cli(
        name,
        playwright,
        node_modules = ":node_modules",
        chdir = None,
        data = None,
        tags = None,
        **kwargs):
    """Defines a package-local Playwright CLI target."""
    playwright(
        name = name,
        chdir = _default_chdir(chdir),
        data = _with_node_modules(data or [], node_modules),
        tags = _dedupe(list(tags or []) + ["manual"]),
        **kwargs
    )

def pnpm_playwright_test(
        name,
        entry_point,
        srcs,
        node_modules = ":node_modules",
        chromium_headless_shell = "@playwright_chromium_headless_shell_linux_x64//:chrome_headless_shell",
        chromium_headless_shell_files = "@playwright_chromium_headless_shell_linux_x64//:chrome_headless_shell_files",
        chromium_env = "FEROCIA_PLAYWRIGHT_CHROMIUM_HEADLESS_SHELL",
        chdir = None,
        tags = None,
        **kwargs):
    """Defines a js_test with Linux Chromium headless-shell runfiles."""
    linux_config = name + "_linux_x86_64"
    native.config_setting(
        name = linux_config,
        constraint_values = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
    )

    linux_label = ":" + linux_config
    js_test(
        name = name,
        entry_point = entry_point,
        data = _with_node_modules(srcs, node_modules) + select({
            linux_label: [
                chromium_headless_shell,
                chromium_headless_shell_files,
            ],
            "//conditions:default": [],
        }),
        no_copy_to_bin = select({
            linux_label: [chromium_headless_shell_files],
            "//conditions:default": [],
        }),
        chdir = _default_chdir(chdir),
        env = select({
            linux_label: {
                "CI": "1",
                chromium_env: "$(rootpath {})".format(chromium_headless_shell),
            },
            "//conditions:default": {
                "CI": "1",
            },
        }),
        tags = _dedupe(list(tags or []) + ["exclusive"]),
        **kwargs
    )

def frontend_static_site_oci_image(
        name,
        assets,
        nginx_conf,
        base = "@nginx_unprivileged_linux_amd64",
        entrypoint = None,
        html_dir = "/usr/share/nginx/html",
        nginx_conf_dir = "/etc/nginx",
        repo_tags = None,
        repository = None,
        remote_tags = None,
        tags = None):
    """Builds an nginx-based OCI image for static frontend assets."""
    base_tags = _dedupe(list(tags or []) + ["manual", "oci"])

    assets_layer = name + "_assets_layer"
    nginx_config_layer = name + "_nginx_config_layer"
    image_amd64 = name + "_image_amd64"
    image = name + "_image"
    load_target = name + "_load"
    tarball_files = name + "_tarball_files"
    tarball_target = name + "_tarball"
    push_target = name + "_push"

    if entrypoint == None:
        entrypoint = [
            "/usr/sbin/nginx",
            "-g",
            "daemon off;",
        ]

    pkg_tar(
        name = assets_layer,
        srcs = [assets],
        package_dir = html_dir,
        tags = base_tags,
    )

    pkg_tar(
        name = nginx_config_layer,
        srcs = [nginx_conf],
        package_dir = nginx_conf_dir,
        tags = base_tags,
    )

    oci_image(
        name = image_amd64,
        base = base,
        entrypoint = entrypoint,
        tars = [
            ":" + assets_layer,
            ":" + nginx_config_layer,
        ],
        tags = base_tags + ["oci_image_internal"],
    )

    native.alias(
        name = image,
        actual = ":" + image_amd64,
        tags = base_tags + ["oci_image"],
    )

    native.filegroup(
        name = image + ".digest",
        srcs = [":" + image_amd64 + ".digest"],
        tags = base_tags + ["oci_image"],
    )

    if repo_tags == None:
        repo_tags = ["{}:local".format(_default_repo_name(name))]

    oci_load(
        name = load_target,
        image = ":" + image,
        repo_tags = repo_tags,
        tags = base_tags + ["oci_load"],
    )

    native.filegroup(
        name = tarball_files,
        srcs = [":" + load_target],
        output_group = "tarball",
        tags = base_tags + ["oci_tarball"],
    )

    native.genrule(
        name = tarball_target,
        srcs = [":" + tarball_files],
        outs = [name + ".tar"],
        cmd = "cp $(location :{}) $@".format(tarball_files),
        tags = base_tags + ["oci_tarball"],
    )

    if repository == None:
        image_name = _image_name_from_repo_tags(repo_tags) or _target_name(assets) or _default_repo_name(name)
        repository = "registry.invalid/{}".format(image_name)

    oci_push(
        name = push_target,
        image = ":" + image,
        repository = repository,
        remote_tags = remote_tags or [],
        tags = base_tags + ["oci_push"],
    )
