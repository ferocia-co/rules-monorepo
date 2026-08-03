"""Checksum-pinned repositories for supported zkVM vendor toolchains."""

_RISC0_RUST_URLS = [
    "https://github.com/risc0/rust/releases/download/r0.1.88.0/rust-toolchain-x86_64-unknown-linux-gnu.tar.gz",
]
_RISC0_C_URLS = [
    "https://github.com/risc0/toolchain/releases/download/2024.01.05/riscv32im-linux-x86_64.tar.xz",
]
_SP1_RUST_URLS = [
    "https://github.com/succinctlabs/rust/releases/download/succinct-1.91.1/rust-toolchain-x86_64-unknown-linux-gnu.tar.gz",
]
_RISC0_V1COMPAT_URLS = [
    "https://static.crates.io/crates/risc0-zkos-v1compat/risc0-zkos-v1compat-2.2.3.crate",
]

_RUST_BUILD = """\
load("@rules_rust//rust:toolchain.bzl", "rust_stdlib_filegroup")

package(default_visibility = ["//visibility:public"])

exports_files([
    "bin/rustc",
    "lib/rustlib/x86_64-unknown-linux-gnu/bin/rust-lld",
] + glob(["bin/rustdoc_tool_binary"], allow_empty = True))

rust_stdlib_filegroup(
    name = "rust_std",
    srcs = glob(["lib/rustlib/{target_triple}/lib/**"]),
)

filegroup(
    name = "rustc_lib",
    srcs = glob([
        "lib/*.so",
        "lib/rustlib/x86_64-unknown-linux-gnu/lib/**",
    ]),
)
"""

_C_BUILD = """\
load("@rules_cc//cc:defs.bzl", "cc_toolchain")
load(":cc_toolchain_config.bzl", "risc0_cc_toolchain_config")

package(default_visibility = ["//visibility:public"])

exports_files([
    "bin/riscv32-unknown-elf-gcc",
    "cc_toolchain_config.bzl",
])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

filegroup(
    name = "empty",
    srcs = [],
)

risc0_cc_toolchain_config(name = "risc0_cc_toolchain_config")

cc_toolchain(
    name = "risc0_cc_toolchain_impl",
    all_files = ":all_files",
    ar_files = ":all_files",
    as_files = ":all_files",
    compiler_files = ":all_files",
    dwp_files = ":empty",
    linker_files = ":all_files",
    objcopy_files = ":all_files",
    strip_files = ":all_files",
    supports_param_files = 0,
    toolchain_config = ":risc0_cc_toolchain_config",
)

"""

def _rust_toolchain_repository_impl(ctx):
    ctx.download_and_extract(
        url = ctx.attr.urls,
        sha256 = ctx.attr.sha256,
    )
    ctx.file("WORKSPACE.bazel", "workspace(name = \"{}\")\n".format(ctx.name))
    ctx.file("BUILD.bazel", _RUST_BUILD.format(target_triple = ctx.attr.target_triple))

rust_toolchain_repository = repository_rule(
    implementation = _rust_toolchain_repository_impl,
    attrs = {
        "sha256": attr.string(mandatory = True),
        "target_triple": attr.string(mandatory = True),
        "urls": attr.string_list(mandatory = True),
    },
)

def _c_toolchain_repository_impl(ctx):
    ctx.download_and_extract(
        url = ctx.attr.urls,
        sha256 = ctx.attr.sha256,
        stripPrefix = "riscv32im-linux-x86_64",
    )
    ctx.file("WORKSPACE.bazel", "workspace(name = \"{}\")\n".format(ctx.name))
    ctx.template(
        "cc_toolchain_config.bzl",
        ctx.path(ctx.attr._toolchain_config),
    )
    ctx.file("BUILD.bazel", _C_BUILD)

c_toolchain_repository = repository_rule(
    implementation = _c_toolchain_repository_impl,
    attrs = {
        "_toolchain_config": attr.label(
            allow_single_file = True,
            default = Label("//rules_monorepo_rust/zkvm:private/risc0_cc_toolchain_config.bzl"),
        ),
        "sha256": attr.string(mandatory = True),
        "urls": attr.string_list(mandatory = True),
    },
)

def risc0_rust_repository(name):
    rust_toolchain_repository(
        name = name,
        sha256 = "222651797ba58f0bafd959191a48d23b35b3266d9e082fc49fb4d84733064fce",
        target_triple = "riscv32im-risc0-zkvm-elf",
        urls = _RISC0_RUST_URLS,
    )

def risc0_c_repository(name):
    c_toolchain_repository(
        name = name,
        sha256 = "cc19497db5fd1ccd92fa3d315a33cacd4ba480f8d21b3c84dfb5493cfd68da0d",
        urls = _RISC0_C_URLS,
    )

def sp1_rust_repository(name):
    rust_toolchain_repository(
        name = name,
        sha256 = "9fe2fee01908fccf32ea1837379ce836a24f3dac3a80ca24e33c87a6599c36ec",
        target_triple = "riscv32im-succinct-zkvm-elf",
        urls = _SP1_RUST_URLS,
    )

def _v1compat_repository_impl(ctx):
    ctx.download_and_extract(
        url = ctx.attr.urls,
        sha256 = ctx.attr.sha256,
        stripPrefix = "risc0-zkos-v1compat-2.2.3",
        type = "tar.gz",
    )
    ctx.file("WORKSPACE.bazel", "workspace(name = \"{}\")\n".format(ctx.name))
    ctx.file("BUILD.bazel", """\
package(default_visibility = ["//visibility:public"])

exports_files(["elfs/v1compat.elf"])
""")

risc0_v1compat_repository = repository_rule(
    implementation = _v1compat_repository_impl,
    attrs = {
        "sha256": attr.string(mandatory = True),
        "urls": attr.string_list(mandatory = True),
    },
)

def risc0_v1compat_elf_repository(name):
    # risc0-binfmt 3.0.5's ProgramBinary format uses the v1compat kernel from
    # the RISC0 3.0.5 release stack. The published kernel crate is versioned
    # independently as 2.2.3.
    risc0_v1compat_repository(
        name = name,
        sha256 = "b8b0b598ba7946354b10ca5c56e382de801e6c7fce9fccad0396ec436bc5072b",
        urls = _RISC0_V1COMPAT_URLS,
    )

def _zkvm_hub_repository_impl(ctx):
    ctx.file("WORKSPACE.bazel", "workspace(name = \"{}\")\n".format(ctx.name))
    ctx.template(
        "BUILD.bazel",
        ctx.path(ctx.attr._build_template),
    )

zkvm_hub_repository = repository_rule(
    implementation = _zkvm_hub_repository_impl,
    attrs = {
        "_build_template": attr.label(
            allow_single_file = True,
            default = Label("//rules_monorepo_rust/zkvm:private/zkvm_hub.BUILD.tpl"),
        ),
    },
)

def zkvm_toolchain_hub_repository(name):
    zkvm_hub_repository(name = name)
