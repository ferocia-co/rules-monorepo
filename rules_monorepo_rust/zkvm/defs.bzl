"""Public rules for compiling RISC0 and SP1 guest programs."""

ZkvmGuestInfo = provider(
    doc = "A compiled zkVM guest artifact and its compiler contract.",
    fields = {
        "elf": "The combined RISC0 program binary or transitioned SP1 ELF File.",
        "proof_system": "The proof system name: risc0 or sp1.",
        "target_triple": "The exact vendor Rust target triple.",
    },
)

_RISC0_PLATFORM = str(Label("//rules_monorepo_rust/zkvm:risc0_guest_platform"))
_SP1_PLATFORM = str(Label("//rules_monorepo_rust/zkvm:sp1_guest_platform"))
_RISC0_SUPPORT_TOOLCHAIN = str(Label("//rules_monorepo_rust/zkvm:risc0_support_toolchain_type"))

def _risc0_transition_impl(_settings, _attr):
    return {
        "//command_line_option:compilation_mode": "opt",
        "//command_line_option:platforms": _RISC0_PLATFORM,
    }

def _sp1_transition_impl(_settings, _attr):
    return {
        "//command_line_option:compilation_mode": "opt",
        "//command_line_option:platforms": _SP1_PLATFORM,
    }

_risc0_transition = transition(
    implementation = _risc0_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:compilation_mode",
        "//command_line_option:platforms",
    ],
)

_sp1_transition = transition(
    implementation = _sp1_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:compilation_mode",
        "//command_line_option:platforms",
    ],
)

def _transitioned_binary(ctx):
    targets = ctx.attr.binary
    if len(targets) != 1:
        fail("binary transition must produce exactly one target", attr = "binary")
    return targets[0]

def _sp1_guest_impl(ctx):
    elf = _transitioned_binary(ctx)[DefaultInfo].files_to_run.executable
    if elf == None:
        fail("binary must provide an executable", attr = "binary")
    return [
        DefaultInfo(files = depset([elf])),
        ZkvmGuestInfo(
            elf = elf,
            proof_system = "sp1",
            target_triple = "riscv32im-succinct-zkvm-elf",
        ),
    ]

def _risc0_guest_impl(ctx):
    user_elf = _transitioned_binary(ctx)[DefaultInfo].files_to_run.executable
    if user_elf == None:
        fail("binary must provide an executable", attr = "binary")
    support = ctx.toolchains[_RISC0_SUPPORT_TOOLCHAIN].risc0
    output = ctx.actions.declare_file(ctx.label.name + ".bin")
    ctx.actions.run(
        arguments = [user_elf.path, support.v1compat.path, output.path],
        executable = support.program_binary,
        inputs = depset([user_elf, support.v1compat]),
        mnemonic = "Risc0ProgramBinary",
        outputs = [output],
        progress_message = "Combining RISC0 guest %{label}",
        tools = [support.program_binary],
    )
    return [
        DefaultInfo(files = depset([output])),
        ZkvmGuestInfo(
            elf = output,
            proof_system = "risc0",
            target_triple = "riscv32im-risc0-zkvm-elf",
        ),
    ]

_COMMON_ATTRS = {
    "_allowlist_function_transition": attr.label(
        default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
    ),
}

_RISC0_ATTRS = dict(_COMMON_ATTRS)
_RISC0_ATTRS.update({
    "binary": attr.label(cfg = _risc0_transition, executable = True, mandatory = True),
})

_SP1_ATTRS = dict(_COMMON_ATTRS)
_SP1_ATTRS.update({
    "binary": attr.label(cfg = _sp1_transition, executable = True, mandatory = True),
})

risc0_guest = rule(
    doc = "Compiles an opt RISC0 guest and combines it with the pinned v1compat kernel.",
    implementation = _risc0_guest_impl,
    attrs = _RISC0_ATTRS,
    toolchains = [_RISC0_SUPPORT_TOOLCHAIN],
)

sp1_guest = rule(
    doc = "Compiles an opt SP1 guest and returns the transitioned ELF.",
    implementation = _sp1_guest_impl,
    attrs = _SP1_ATTRS,
)
