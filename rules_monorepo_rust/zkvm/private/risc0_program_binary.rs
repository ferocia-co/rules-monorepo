// Copyright 2025-2026 RISC Zero, Inc.
// Copyright 2026 rules_monorepo contributors
//
// Licensed under the Apache License, Version 2.0. See ../NOTICE.risc0.
//
// This is the minimal host-side encoding performed by
// risc0_binfmt::ProgramBinary::new(user_elf, V1COMPAT_ELF).encode() at 3.0.5.

use std::{env, fs, io, path::Path};

const MAGIC: &[u8] = b"R0BF";
const BINARY_FORMAT_VERSION: u32 = 1;

// ProgramBinaryHeader::default().encode() under risc0-binfmt 3.0.5. The inner
// eight bytes are postcard's encoding of AbiVersion(V1Compat, 1.0.0).
const DEFAULT_HEADER: &[u8] = &[
    1, 0, 0, 0, // one key-value pair
    8, 0, 0, 0, // encoded pair length
    0, 0, 5, b'1', b'.', b'0', b'.', b'0',
];

struct ProgramBinary<'a> {
    user_elf: &'a [u8],
    kernel_elf: &'a [u8],
}

impl<'a> ProgramBinary<'a> {
    fn new(user_elf: &'a [u8], kernel_elf: &'a [u8]) -> Self {
        Self {
            user_elf,
            kernel_elf,
        }
    }

    fn encode(&self) -> io::Result<Vec<u8>> {
        let user_len = u32::try_from(self.user_elf.len()).map_err(|_| {
            io::Error::new(io::ErrorKind::InvalidInput, "user ELF exceeds u32 length")
        })?;
        let mut encoded = Vec::with_capacity(
            MAGIC.len() + 12 + DEFAULT_HEADER.len() + self.user_elf.len() + self.kernel_elf.len(),
        );
        encoded.extend_from_slice(MAGIC);
        encoded.extend_from_slice(&BINARY_FORMAT_VERSION.to_le_bytes());
        encoded.extend_from_slice(&(DEFAULT_HEADER.len() as u32).to_le_bytes());
        encoded.extend_from_slice(DEFAULT_HEADER);
        encoded.extend_from_slice(&user_len.to_le_bytes());
        encoded.extend_from_slice(self.user_elf);
        encoded.extend_from_slice(self.kernel_elf);
        Ok(encoded)
    }
}

fn combine(user_elf: &Path, kernel_elf: &Path, output: &Path) -> io::Result<()> {
    let user = fs::read(user_elf)?;
    let kernel = fs::read(kernel_elf)?;
    fs::write(output, ProgramBinary::new(&user, &kernel).encode()?)
}

fn main() -> io::Result<()> {
    let args: Vec<_> = env::args_os().skip(1).collect();
    if args.len() != 3 {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "usage: risc0_program_binary USER_ELF V1COMPAT_ELF OUTPUT",
        ));
    }
    combine(
        Path::new(&args[0]),
        Path::new(&args[1]),
        Path::new(&args[2]),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_complete_upstream_risc0_binfmt_3_0_5_golden() {
        let user = b"guest-fixture";
        let kernel = b"kernel-fixture";
        let encoded = ProgramBinary::new(user, kernel).encode().unwrap();
        let golden = include_str!("testdata/program_binary_3_0_5.hex")
            .split_ascii_whitespace()
            .map(|byte| u8::from_str_radix(byte, 16).unwrap())
            .collect::<Vec<_>>();
        assert_eq!(encoded, golden);
    }
}
