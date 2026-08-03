// Run only through the pinned Cargo command documented in README.md. This is
// deliberately not part of the hermetic Bazel runtime encoder.

use risc0_binfmt::ProgramBinary;

fn main() {
    let encoded = ProgramBinary::new(b"guest-fixture", b"kernel-fixture").encode();
    for chunk in encoded.chunks(16) {
        println!(
            "{}",
            chunk
                .iter()
                .map(|byte| format!("{byte:02x}"))
                .collect::<Vec<_>>()
                .join(" ")
        );
    }
}
