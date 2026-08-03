"""Analysis tests for public zkVM guest providers and actions."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load(":defs.bzl", "ZkvmGuestInfo", "risc0_guest", "sp1_guest")

def _fixture_executable_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name + ".elf")
    ctx.actions.write(output, "fixture", is_executable = True)
    return [DefaultInfo(executable = output)]

_fixture_executable = rule(
    implementation = _fixture_executable_impl,
    executable = True,
)

def _sp1_provider_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[ZkvmGuestInfo]
    asserts.equals(env, "sp1", info.proof_system)
    asserts.equals(env, "riscv32im-succinct-zkvm-elf", info.target_triple)
    asserts.true(env, info.elf.basename.endswith(".elf"))
    return analysistest.end(env)

sp1_provider_test = analysistest.make(_sp1_provider_test_impl)

def _risc0_provider_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[ZkvmGuestInfo]
    asserts.equals(env, "risc0", info.proof_system)
    asserts.equals(env, "riscv32im-risc0-zkvm-elf", info.target_triple)
    asserts.true(env, info.elf.basename.endswith(".bin"))
    actions = analysistest.target_actions(env)
    asserts.equals(env, 1, len(actions))
    asserts.equals(env, "Risc0ProgramBinary", actions[0].mnemonic)
    return analysistest.end(env)

risc0_provider_test = analysistest.make(_risc0_provider_test_impl)

def zkvm_rule_tests():
    _fixture_executable(name = "zkvm_fixture_binary")
    sp1_guest(
        name = "zkvm_sp1_fixture",
        binary = ":zkvm_fixture_binary",
        testonly = True,
    )
    risc0_guest(
        name = "zkvm_risc0_fixture",
        binary = ":zkvm_fixture_binary",
        testonly = True,
    )
    sp1_provider_test(
        name = "sp1_provider_test",
        target_under_test = ":zkvm_sp1_fixture",
    )
    risc0_provider_test(
        name = "risc0_provider_test",
        target_under_test = ":zkvm_risc0_fixture",
    )
    native.test_suite(
        name = "zkvm_rule_tests",
        tests = [
            ":risc0_provider_test",
            ":sp1_provider_test",
        ],
    )
