"""pnpm-oriented frontend macros.

These macros keep package.json and pnpm-lock.yaml as the dependency source of
truth. Callers still load generated package bin wrappers from @npm because
Bazel loads .bzl files statically.
"""

load("@aspect_bazel_lib//lib:directory_path.bzl", "directory_path")
load("@aspect_rules_js//js:defs.bzl", "js_binary", "js_run_devserver", "js_test")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_load", "oci_push")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

DEFAULT_SOURCE_INCLUDES = [
    "*.cjs",
    "*.cts",
    "*.html",
    "*.js",
    "*.json",
    "*.mjs",
    "*.mts",
    "*.svelte",
    "*.ts",
    ".storybook/**",
    "cypress/**",
    "public/**",
    "src/**",
    "static/**",
    "stories/**",
    "tests/**",
]

DEFAULT_SOURCE_EXCLUDES = [
    ".svelte-kit/**",
    "build/**",
    "coverage/**",
    "cypress/downloads/**",
    "cypress/screenshots/**",
    "cypress/videos/**",
    "dist/**",
    "node_modules/**",
    "storybook-static/**",
    "test-results/**",
    "tmp/**",
]

def _as_list(value):
    if value == None:
        return []
    if type(value) == "string":
        return [value]
    return list(value)

def _dedupe(values):
    out = []
    for value in values or []:
        if value not in out:
            out.append(value)
    return out

def _default_chdir(chdir):
    return native.package_name() if chdir == None else chdir

def _with_node_modules(srcs, node_modules):
    out = _as_list(srcs)
    if node_modules != None:
        out.append(node_modules)
    return out

def _merge_env(defaults, env):
    out = {}
    for key, value in (defaults or {}).items():
        out[key] = value
    for key, value in (env or {}).items():
        out[key] = value
    return out

def _default_env(defaults, env):
    if env == None:
        return defaults
    return env

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

def _strip_trailing_slash(value):
    if len(value) > 1 and value[len(value) - 1:] == "/":
        return value[:-1]
    return value

def frontend_sources(
        name = "sources",
        include = DEFAULT_SOURCE_INCLUDES,
        exclude = DEFAULT_SOURCE_EXCLUDES,
        extra_srcs = None,
        tags = None,
        visibility = None):
    """Creates a standard frontend source filegroup."""
    native.filegroup(
        name = name,
        srcs = native.glob(
            _as_list(include),
            exclude = _as_list(exclude),
            allow_empty = True,
        ) + _as_list(extra_srcs),
        tags = _dedupe(tags),
        visibility = visibility,
    )

def pnpm_vite_build(
        name,
        vite,
        srcs,
        node_modules = ":node_modules",
        args = None,
        chdir = None,
        out_dir = "dist",
        out_dirs = None,
        tags = None,
        **kwargs):
    """Runs a package-local Vite build using an @npm generated vite macro."""
    if out_dirs == None:
        out_dirs = [out_dir]

    vite(
        name = name,
        srcs = _with_node_modules(srcs, node_modules),
        args = args or ["build"],
        chdir = _default_chdir(chdir),
        out_dirs = out_dirs,
        tags = _dedupe(tags),
        **kwargs
    )

def pnpm_vite_dev_server(
        name,
        vite,
        srcs,
        node_modules = ":node_modules",
        args = None,
        chdir = None,
        env = None,
        tags = None,
        **kwargs):
    """Runs a package-local Vite dev server through Bazel."""
    tool = name + "_vite_tool"

    vite(
        name = tool,
        tags = ["manual"],
    )

    js_run_devserver(
        name = name,
        tool = ":" + tool,
        data = _with_node_modules(srcs, node_modules),
        args = args or [
            "--host",
            "0.0.0.0",
        ],
        chdir = _default_chdir(chdir),
        env = env or {},
        grant_sandbox_write_permissions = True,
        tags = _dedupe(tags),
        **kwargs
    )

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
    pnpm_vite_build(
        name = name,
        vite = vite,
        srcs = srcs,
        node_modules = node_modules,
        args = args,
        chdir = chdir,
        out_dir = out_dir,
        tags = tags,
        **kwargs
    )

def pnpm_sveltekit_sync(
        name,
        svelte_kit,
        srcs,
        node_modules = ":node_modules",
        args = None,
        chdir = None,
        out_dir = ".svelte-kit",
        out_dirs = None,
        tags = None,
        **kwargs):
    """Runs svelte-kit sync and exposes generated SvelteKit types."""
    if out_dirs == None:
        out_dirs = [out_dir]

    svelte_kit(
        name = name,
        srcs = _with_node_modules(srcs, node_modules),
        args = args or ["sync"],
        chdir = _default_chdir(chdir),
        out_dirs = out_dirs,
        tags = _dedupe(tags),
        **kwargs
    )

def pnpm_sveltekit_node_server(
        name,
        bundle = ":bundle",
        node_modules = ":node_modules",
        package_json = "package.json",
        entry_point_path = "index.js",
        chdir = None,
        data = None,
        env = None,
        tags = None,
        **kwargs):
    """Runs a SvelteKit adapter-node bundle through Bazel."""
    entry_point = name + "_entry_point"

    directory_path(
        name = entry_point,
        directory = bundle,
        path = entry_point_path,
        tags = ["manual"],
    )

    server_data = _as_list(data) + [bundle]
    if package_json != None:
        server_data.append(package_json)

    js_binary(
        name = name,
        entry_point = ":" + entry_point,
        data = _with_node_modules(server_data, node_modules),
        chdir = _default_chdir(chdir),
        env = _merge_env({"NODE_ENV": "production"}, env),
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

def pnpm_biome_check(
        name,
        biome,
        srcs,
        node_modules = ":node_modules",
        args = None,
        chdir = None,
        stderr = None,
        stdout = None,
        tags = None,
        **kwargs):
    """Runs biome ci as a buildable lint target."""
    biome(
        name = name,
        srcs = _with_node_modules(srcs, node_modules),
        args = args or [
            "ci",
            ".",
        ],
        chdir = _default_chdir(chdir),
        stderr = stderr or (name + ".stderr"),
        stdout = stdout or (name + ".stdout"),
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
        biome = None,
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

    if biome != None:
        target = name + "_biome_check"
        pnpm_biome_check(
            name = target,
            biome = biome,
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

def pnpm_vitest_test(
        name,
        vitest,
        srcs,
        node_modules = ":node_modules",
        args = None,
        chdir = None,
        env = None,
        tags = None,
        **kwargs):
    """Runs Vitest as a Bazel test target."""
    vitest(
        name = name,
        data = _with_node_modules(srcs, node_modules),
        args = args or ["run"],
        chdir = _default_chdir(chdir),
        env = _default_env({
            "CI": "1",
            "FORCE_COLOR": "0",
            "NO_COLOR": "1",
            "TERM": "dumb",
        }, env),
        tags = _dedupe(tags),
        **kwargs
    )

def pnpm_cypress_test(
        name,
        cypress,
        srcs,
        node_modules = ":node_modules",
        args = None,
        chdir = None,
        env = None,
        tags = None,
        **kwargs):
    """Runs Cypress as an exclusive Bazel test target."""
    cypress(
        name = name,
        data = _with_node_modules(srcs, node_modules),
        args = args or ["run"],
        chdir = _default_chdir(chdir),
        env = _default_env({
            "CI": "1",
            "FORCE_COLOR": "0",
            "NO_COLOR": "1",
            "TERM": "dumb",
        }, env),
        tags = _dedupe(list(tags or []) + ["e2e", "exclusive"]),
        **kwargs
    )

def pnpm_storybook_static_build(
        name,
        storybook,
        srcs,
        node_modules = ":node_modules",
        args = None,
        chdir = None,
        env = None,
        out_dir = "storybook-static",
        out_dirs = None,
        tags = None,
        **kwargs):
    """Runs a caller-provided Storybook bin and exposes its static output."""
    if out_dirs == None:
        out_dirs = [out_dir]

    storybook(
        name = name,
        srcs = _with_node_modules(srcs, node_modules),
        args = args or [
            "build",
            "--output-dir",
            out_dirs[0],
        ],
        chdir = _default_chdir(chdir),
        env = _merge_env({"STORYBOOK_DISABLE_TELEMETRY": "1"}, env),
        out_dirs = out_dirs,
        tags = _dedupe(tags),
        **kwargs
    )

def pnpm_storybook_dev_server(
        name,
        storybook,
        srcs,
        node_modules = ":node_modules",
        args = None,
        chdir = None,
        env = None,
        tags = None,
        **kwargs):
    """Runs a caller-provided Storybook dev server through Bazel."""
    tool = name + "_storybook_tool"

    storybook(
        name = tool,
        tags = ["manual"],
    )

    js_run_devserver(
        name = name,
        tool = ":" + tool,
        data = _with_node_modules(srcs, node_modules),
        args = args or [
            "dev",
            "--host",
            "0.0.0.0",
            "--port",
            "6006",
        ],
        chdir = _default_chdir(chdir),
        env = _merge_env({"STORYBOOK_DISABLE_TELEMETRY": "1"}, env),
        grant_sandbox_write_permissions = True,
        tags = _dedupe(tags),
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
                "FORCE_COLOR": "0",
                chromium_env: "$(rootpath {})".format(chromium_headless_shell),
                "NO_COLOR": "1",
                "TERM": "dumb",
            },
            "//conditions:default": {
                "CI": "1",
                "FORCE_COLOR": "0",
                "NO_COLOR": "1",
                "TERM": "dumb",
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

def frontend_node_server_oci_image(
        name,
        bundle = ":bundle",
        node_modules = None,
        package_json = "package.json",
        extra_srcs = None,
        base = None,
        app_dir = "/app",
        entry_point_path = "build/index.js",
        entrypoint = None,
        cmd = None,
        env = None,
        exposed_ports = None,
        workdir = "/app",
        user = None,
        repo_tags = None,
        repository = None,
        remote_tags = None,
        tags = None):
    """Builds an OCI image for a frontend Node server bundle."""
    if base == None:
        fail("frontend_node_server_oci_image requires base; callers own Node base image repositories")

    base_tags = _dedupe(list(tags or []) + ["manual", "oci"])

    package_layer = name + "_package_layer"
    app_layer = name + "_app_layer"
    node_modules_layer = name + "_node_modules_layer"
    extra_layer = name + "_extra_layer"
    image_amd64 = name + "_image_amd64"
    image = name + "_image"
    load_target = name + "_load"
    tarball_files = name + "_tarball_files"
    tarball_target = name + "_tarball"
    push_target = name + "_push"

    if entrypoint == None:
        entrypoint = [
            "/nodejs/bin/node",
            "{}/{}".format(_strip_trailing_slash(app_dir), entry_point_path),
        ]

    if exposed_ports == None:
        exposed_ports = ["3000/tcp"]

    pkg_tar(
        name = package_layer,
        srcs = [package_json],
        package_dir = app_dir,
        tags = base_tags,
    )

    pkg_tar(
        name = app_layer,
        srcs = _as_list(bundle),
        package_dir = app_dir,
        tags = base_tags,
    )

    image_tars = [
        ":" + package_layer,
        ":" + app_layer,
    ]

    if node_modules != None:
        pkg_tar(
            name = node_modules_layer,
            srcs = [node_modules],
            package_dir = app_dir,
            tags = base_tags,
        )
        image_tars.append(":" + node_modules_layer)

    if extra_srcs != None:
        pkg_tar(
            name = extra_layer,
            srcs = _as_list(extra_srcs),
            package_dir = app_dir,
            tags = base_tags,
        )
        image_tars.append(":" + extra_layer)

    image_kwargs = {
        "name": image_amd64,
        "base": base,
        "entrypoint": entrypoint,
        "env": _merge_env({
            "HOST": "0.0.0.0",
            "NODE_ENV": "production",
            "PORT": "3000",
        }, env),
        "exposed_ports": exposed_ports,
        "tars": image_tars,
        "tags": base_tags + ["oci_image_internal"],
    }
    if cmd != None:
        image_kwargs["cmd"] = cmd
    if workdir != None:
        image_kwargs["workdir"] = workdir
    if user != None:
        image_kwargs["user"] = user

    oci_image(**image_kwargs)

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
        image_name = _image_name_from_repo_tags(repo_tags) or _target_name(bundle) or _default_repo_name(name)
        repository = "registry.invalid/{}".format(image_name)

    oci_push(
        name = push_target,
        image = ":" + image,
        repository = repository,
        remote_tags = remote_tags or [],
        tags = base_tags + ["oci_push"],
    )
