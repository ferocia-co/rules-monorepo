"""Bzlmod extension provisioning the supported zkVM vendor toolchains."""

load(":repositories.bzl", "risc0_c_repository", "risc0_rust_repository", "risc0_v1compat_elf_repository", "sp1_rust_repository", "zkvm_toolchain_hub_repository")

def _zkvm_toolchains_impl(_ctx):
    risc0_rust_repository(name = "risc0_zkvm_rust")
    risc0_c_repository(name = "risc0_zkvm_c")
    risc0_v1compat_elf_repository(name = "risc0_zkvm_v1compat")
    sp1_rust_repository(name = "sp1_zkvm_rust")
    zkvm_toolchain_hub_repository(name = "zkvm_toolchains")

zkvm_toolchains = module_extension(
    doc = "Creates an opt-in toolchain hub backed by checksum-pinned Linux x86_64 RISC0 and SP1 repositories.",
    implementation = _zkvm_toolchains_impl,
)
