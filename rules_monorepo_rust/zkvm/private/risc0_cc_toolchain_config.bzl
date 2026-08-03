"""Hermetic C toolchain configuration for the RISC0 RV32IM guest target."""

load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load(
    "@rules_cc//cc:cc_toolchain_config_lib.bzl",
    "feature",
    "flag_group",
    "flag_set",
    "tool_path",
)
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/toolchains:cc_toolchain_config_info.bzl", "CcToolchainConfigInfo")

_COMPILE_ACTIONS = [
    ACTION_NAMES.assemble,
    ACTION_NAMES.c_compile,
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.preprocess_assemble,
]

def _risc0_cc_toolchain_config_impl(ctx):
    target_flags = feature(
        name = "risc0_rv32im_target_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = _COMPILE_ACTIONS,
                flag_groups = [
                    flag_group(flags = [
                        "-march=rv32im",
                        "-mabi=ilp32",
                        "-ffunction-sections",
                        "-fdata-sections",
                    ]),
                ],
            ),
        ],
    )
    tools = {
        "ar": "bin/riscv32-unknown-elf-ar",
        "cpp": "bin/riscv32-unknown-elf-cpp",
        "gcc": "bin/riscv32-unknown-elf-gcc",
        "gcov": "bin/riscv32-unknown-elf-gcov",
        "ld": "bin/riscv32-unknown-elf-ld",
        "nm": "bin/riscv32-unknown-elf-nm",
        "objcopy": "bin/riscv32-unknown-elf-objcopy",
        "objdump": "bin/riscv32-unknown-elf-objdump",
        "strip": "bin/riscv32-unknown-elf-strip",
    }
    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        abi_libc_version = "unknown",
        abi_version = "ilp32",
        compiler = "gcc",
        features = [target_flags],
        host_system_name = "x86_64-unknown-linux-gnu",
        target_cpu = "riscv32",
        target_libc = "newlib",
        target_system_name = "riscv32im-risc0-zkvm-elf",
        tool_paths = [
            tool_path(name = name, path = path)
            for name, path in tools.items()
        ],
        toolchain_identifier = "risc0-riscv32im-gcc-2024.01.05",
    )

risc0_cc_toolchain_config = rule(
    implementation = _risc0_cc_toolchain_config_impl,
    provides = [CcToolchainConfigInfo],
)
