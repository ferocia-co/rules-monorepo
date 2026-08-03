load("@rules_monorepo//rules_monorepo_rust/zkvm:private/support.bzl", "risc0_support_toolchain")
load("@rules_rust//rust:toolchain.bzl", "rust_toolchain")

package(default_visibility = ["//visibility:public"])

rust_toolchain(
    name = "risc0_rust_toolchain_impl",
    binary_ext = "",
    default_edition = "2024",
    dylib_ext = ".so",
    exec_triple = "x86_64-unknown-linux-gnu",
    extra_exec_rustc_flags = [],
    extra_rustc_flags = [
        "-Cpasses=lower-atomic",
        "-Clink-arg=-Ttext=0x00200800",
        "-Clink-arg=--fatal-warnings",
        "-Cpanic=abort",
        "--cfg=getrandom_backend=\"custom\"",
    ],
    linker = "@risc0_zkvm_rust//:lib/rustlib/x86_64-unknown-linux-gnu/bin/rust-lld",
    linker_preference = "rust",
    process_wrapper = "@rules_rust//util/process_wrapper",
    rust_doc = "@risc0_zkvm_rust//:bin/rustdoc_tool_binary",
    rust_std = "@risc0_zkvm_rust//:rust_std",
    rustc = "@risc0_zkvm_rust//:bin/rustc",
    rustc_lib = "@risc0_zkvm_rust//:rustc_lib",
    staticlib_ext = ".a",
    stdlib_linkflags = [],
    target_triple = "riscv32im-risc0-zkvm-elf",
    version = "r0.1.88.0",
)

toolchain(
    name = "risc0_rust_toolchain",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
    target_compatible_with = [
        "@platforms//cpu:riscv32",
        "@platforms//os:none",
        "@rules_monorepo//rules_monorepo_rust/zkvm:risc0",
    ],
    toolchain = ":risc0_rust_toolchain_impl",
    toolchain_type = "@rules_rust//rust:toolchain_type",
)

rust_toolchain(
    name = "sp1_rust_toolchain_impl",
    binary_ext = "",
    default_edition = "2024",
    dylib_ext = ".so",
    exec_triple = "x86_64-unknown-linux-gnu",
    extra_exec_rustc_flags = [],
    extra_rustc_flags = [
        "-Cpasses=lower-atomic",
        "-Clink-arg=-Ttext=0x00201000",
        "-Clink-arg=--image-base=0x00200800",
        "-Cpanic=abort",
        "--cfg=getrandom_backend=\"custom\"",
        "-Cllvm-args=-misched-prera-direction=bottomup",
        "-Cllvm-args=-misched-postra-direction=bottomup",
    ],
    linker = "@sp1_zkvm_rust//:lib/rustlib/x86_64-unknown-linux-gnu/bin/rust-lld",
    linker_preference = "rust",
    process_wrapper = "@rules_rust//util/process_wrapper",
    # Succinct's published guest archive intentionally contains no rustdoc.
    # rust_toolchain requires one even though sp1_guest exposes compilation,
    # not documentation; use the real Linux-host RISC0 rustdoc executable.
    rust_doc = "@risc0_zkvm_rust//:bin/rustdoc_tool_binary",
    rust_std = "@sp1_zkvm_rust//:rust_std",
    rustc = "@sp1_zkvm_rust//:bin/rustc",
    rustc_lib = "@sp1_zkvm_rust//:rustc_lib",
    staticlib_ext = ".a",
    stdlib_linkflags = [],
    target_triple = "riscv32im-succinct-zkvm-elf",
    version = "succinct-1.91.1",
)

toolchain(
    name = "sp1_rust_toolchain",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
    target_compatible_with = [
        "@platforms//cpu:riscv32",
        "@platforms//os:none",
        "@rules_monorepo//rules_monorepo_rust/zkvm:sp1",
    ],
    toolchain = ":sp1_rust_toolchain_impl",
    toolchain_type = "@rules_rust//rust:toolchain_type",
)

toolchain(
    name = "risc0_cc_toolchain",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
    target_compatible_with = [
        "@platforms//cpu:riscv32",
        "@platforms//os:none",
        "@rules_monorepo//rules_monorepo_rust/zkvm:risc0",
    ],
    toolchain = "@risc0_zkvm_c//:risc0_cc_toolchain_impl",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

risc0_support_toolchain(
    name = "risc0_support_toolchain_impl",
    program_binary = "@rules_monorepo//rules_monorepo_rust/zkvm:risc0_program_binary",
    v1compat = "@risc0_zkvm_v1compat//:elfs/v1compat.elf",
)

toolchain(
    name = "risc0_support_toolchain",
    toolchain = ":risc0_support_toolchain_impl",
    toolchain_type = "@rules_monorepo//rules_monorepo_rust/zkvm:risc0_support_toolchain_type",
)
